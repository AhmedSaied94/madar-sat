"""Admin auth routes: declared on D1 (shapes frozen in contracts/admin-auth-v1.md), implemented on D2.

D2 changes no request, response, cookie, header or error code of the D1 declaration (FR-001). The
OpenAPI keeps the named examples so the A1 mock is generated from the same spec.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from fastapi import APIRouter, Cookie, Depends, Header, Request, Response
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_now
from app.api.envelope import Envelope, ok
from app.api.errors import ApiError
from app.auth import passwords
from app.auth.csrf import CSRF_COOKIE, csrf_matches, new_csrf_value
from app.auth.limits import LoginLimiter, client_ip, get_redis
from app.auth.roles import AuthedAdmin, require_editor
from app.auth.tokens import (
    ACCESS_TTL,
    REFRESH_TTL,
    RefreshInvalid,
    issue_access_token,
    issue_refresh_token,
    revoke_refresh_token,
    rotate_refresh_token,
)
from app.db.models import AdminUser as AdminRow
from app.db.session import get_session
from app.schemas.admin import AdminUser, LoginRequest, Session

router = APIRouter(prefix="/admin/api/auth", tags=["auth"])

REFRESH_COOKIE = "madar_refresh"
REFRESH_PATH = "/admin/api/auth"
COOKIE_MAX_AGE = int(REFRESH_TTL.total_seconds())  # 1209600

_LOGIN_OK = {
    "value": {
        "success": True,
        "data": {
            "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIzIn0.signature",
            "token_type": "Bearer",
            "expires_in": 900,
            "admin": {"id": 3, "email": "editor@example.com", "name": "محرر", "role": "editor"},
        },
        "error": None,
        "meta": {"generated_at": "2026-10-29T13:00:00Z"},
    }
}

_INVALID_CREDENTIALS = {
    "value": {
        "success": False,
        "data": None,
        "error": {"code": "invalid_credentials", "message": "invalid credentials"},
        "meta": {"attempts_remaining": 3},
    }
}

_ACCOUNT_LOCKED = {
    "value": {
        "success": False,
        "data": None,
        "error": {"code": "account_locked", "message": "account locked"},
        "meta": {"retry_after_s": 872},
    }
}

_VALIDATION_ERROR = {
    "value": {
        "success": False,
        "data": None,
        "error": {"code": "validation_error", "message": "invalid request"},
        "meta": {"errors": [{"loc": ["body", "email"], "type": "value_error"}]},
    }
}

_REFRESH_INVALID = {
    "value": {
        "success": False,
        "data": None,
        "error": {"code": "refresh_invalid", "message": "refresh invalid"},
        "meta": {},
    }
}
_CSRF_FAILED = {
    "value": {"success": False, "data": None, "error": {"code": "csrf_failed", "message": "csrf failed"}, "meta": {}}
}
_UNAUTHENTICATED = {
    "value": {
        "success": False,
        "data": None,
        "error": {"code": "unauthenticated", "message": "unauthenticated"},
        "meta": {},
    }
}
_ME_OK = {
    "value": {
        "success": True,
        "data": {"id": 3, "email": "editor@example.com", "name": "محرر", "role": "editor"},
        "error": None,
        "meta": {"generated_at": "2026-10-29T13:00:00Z"},
    }
}


def _example(example: dict[str, Any]) -> dict[str, Any]:
    return {"content": {"application/json": {"examples": example}}}


# contracts/admin-auth-v1.md "Cookies". OpenAPI keys headers by name, so one Set-Cookie
# entry describes both cookies.
_SETS_COOKIES = {
    "headers": {
        "Set-Cookie": {
            "description": (
                "madar_refresh=<opaque>; HttpOnly; Secure; SameSite=Strict; Path=/admin/api/auth; Max-Age=1209600 "
                "and madar_csrf=<value>; Secure; SameSite=Strict; Path=/; Max-Age=1209600 (readable by JS)"
            ),
            "schema": {"type": "string"},
        }
    }
}
_CLEARS_COOKIES = {
    "headers": {
        "Set-Cookie": {"description": "Clears madar_refresh and madar_csrf (Max-Age=0)", "schema": {"type": "string"}}
    }
}
_REFRESH_COOKIE = Cookie(None, alias="madar_refresh", description="Opaque refresh token (HttpOnly)")
_CSRF_COOKIE = Cookie(None, alias="madar_csrf", description="CSRF value; echo it in X-CSRF-Token")
_CSRF_HEADER = Header(None, alias="X-CSRF-Token", description="Must equal the madar_csrf cookie")


def _check_csrf(cookie: str | None, header: str | None) -> None:
    if not csrf_matches(cookie, header):
        raise ApiError(403, "csrf_failed")


def _session_of(admin: AdminRow, now: datetime) -> Session:
    """The login and refresh body. The access token is in the body only, never in a cookie (FR-034)."""
    return Session(
        access_token=issue_access_token(admin.id, admin.role, now),
        expires_in=int(ACCESS_TTL.total_seconds()),
        admin=AdminUser(id=admin.id, email=admin.email, name=admin.name, role=admin.role),
    )


def _set_session_cookies(response: Response, refresh_token: str) -> None:
    """contracts/admin-auth-v1.md "Cookies": the refresh cookie is HttpOnly and scoped to the auth routes;
    the CSRF value is readable by the admin app's JS and changes on every refresh."""
    response.set_cookie(
        REFRESH_COOKIE,
        refresh_token,
        max_age=COOKIE_MAX_AGE,
        path=REFRESH_PATH,
        secure=True,
        httponly=True,
        samesite="strict",
    )
    response.set_cookie(CSRF_COOKIE, new_csrf_value(), max_age=COOKIE_MAX_AGE, path="/", secure=True, samesite="strict")


@router.post(
    "/login",
    response_model=Envelope[Session],
    responses={
        200: {"description": "Login success; sets both cookies", **_SETS_COOKIES, **_example({"login_ok": _LOGIN_OK})},
        401: {"description": "Invalid credentials", **_example({"invalid_credentials": _INVALID_CREDENTIALS})},
        429: {"description": "Temporarily locked", **_example({"account_locked": _ACCOUNT_LOCKED})},
        422: {"description": "Validation error", **_example({"validation_error": _VALIDATION_ERROR})},
    },
    summary="Log in",
)
async def login(
    body: LoginRequest,
    request: Request,
    response: Response,
    session: AsyncSession = Depends(get_session),
    redis: Any = Depends(get_redis),
    now: datetime = Depends(get_now),
) -> Envelope[Session]:
    limiter = LoginLimiter(redis)
    email, ip = str(body.email), client_ip(request)

    retry_after = await limiter.locked_for(email, ip)
    if retry_after is not None:
        raise ApiError(
            429, "account_locked", meta={"retry_after_s": retry_after}, headers={"Retry-After": str(retry_after)}
        )

    admin = await session.scalar(select(AdminRow).where(func.lower(AdminRow.email) == email.lower()))
    if admin is None or not admin.is_active:
        # Same cost as a real check, so response time doesn't say which emails exist.
        passwords.burn_verify(body.password)
        verdict = passwords.Verification(ok=False)
    else:
        verdict = passwords.verify_password(admin.password_hash, body.password)
    if admin is None or not admin.is_active or not verdict.ok:
        remaining = await limiter.record_failure(email, ip)
        raise ApiError(401, "invalid_credentials", meta={"attempts_remaining": remaining})

    await limiter.clear(email, ip)
    if verdict.new_hash is not None:
        admin.password_hash = verdict.new_hash
    admin.last_login_at = now
    refresh_token, _ = await issue_refresh_token(session, admin.id, now)
    await session.commit()

    _set_session_cookies(response, refresh_token)
    return ok(_session_of(admin, now))


@router.post(
    "/refresh",
    response_model=Envelope[Session],
    responses={
        200: {
            "description": "Refreshed session; rotates both cookies",
            **_SETS_COOKIES,
            **_example({"login_ok": _LOGIN_OK}),
        },
        401: {"description": "Refresh token invalid or reused", **_example({"refresh_invalid": _REFRESH_INVALID})},
        403: {"description": "CSRF header missing or mismatched", **_example({"csrf_failed": _CSRF_FAILED})},
    },
    summary="Refresh",
)
async def refresh(
    response: Response,
    madar_refresh: str | None = _REFRESH_COOKIE,
    madar_csrf: str | None = _CSRF_COOKIE,
    x_csrf_token: str | None = _CSRF_HEADER,
    session: AsyncSession = Depends(get_session),
    now: datetime = Depends(get_now),
) -> Envelope[Session]:
    _check_csrf(madar_csrf, x_csrf_token)
    if not madar_refresh:
        raise ApiError(401, "refresh_invalid")
    try:
        admin, new_token = await rotate_refresh_token(session, madar_refresh, now)
    except RefreshInvalid:
        raise ApiError(401, "refresh_invalid") from None
    await session.commit()

    _set_session_cookies(response, new_token)
    return ok(_session_of(admin, now))


@router.post(
    "/logout",
    response_model=Envelope[None],
    responses={
        200: {"description": "Logged out; the refresh token is revoked", **_CLEARS_COOKIES},
        403: {"description": "CSRF header missing or mismatched", **_example({"csrf_failed": _CSRF_FAILED})},
    },
    summary="Log out",
)
async def logout(
    response: Response,
    madar_refresh: str | None = _REFRESH_COOKIE,
    madar_csrf: str | None = _CSRF_COOKIE,
    x_csrf_token: str | None = _CSRF_HEADER,
    session: AsyncSession = Depends(get_session),
    now: datetime = Depends(get_now),
) -> Envelope[None]:
    _check_csrf(madar_csrf, x_csrf_token)
    if madar_refresh:
        await revoke_refresh_token(session, madar_refresh, now)
        await session.commit()

    response.delete_cookie(REFRESH_COOKIE, path=REFRESH_PATH, secure=True, httponly=True, samesite="strict")
    response.delete_cookie(CSRF_COOKIE, path="/", secure=True, samesite="strict")
    return ok(None)


@router.get(
    "/me",
    response_model=Envelope[AdminUser],
    responses={
        200: {"description": "Current admin", **_example({"me": _ME_OK})},
        401: {"description": "Unauthenticated", **_example({"unauthenticated": _UNAUTHENTICATED})},
    },
    summary="Current admin",
)
async def me(admin: AuthedAdmin = Depends(require_editor)) -> Envelope[AdminUser]:
    return ok(AdminUser(id=admin.id, email=admin.email, name=admin.name, role=admin.role))
