"""Admin auth routes — declared on D1, implemented on D2.

Every handler answers ``501 not_implemented`` in the envelope; the OpenAPI declares the
request/response shapes and named examples of contracts/admin-auth-v1.md so the A1 mock
can be generated from the frozen spec.
"""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Cookie, Header

from app.api.envelope import Envelope
from app.api.errors import ApiError
from app.schemas.admin import AdminUser, LoginRequest, Session

router = APIRouter(prefix="/admin/api/auth", tags=["auth"])

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


@router.post(
    "/login",
    response_model=Envelope[Session],
    responses={
        200: {"description": "Login success; sets both cookies", **_SETS_COOKIES, **_example({"login_ok": _LOGIN_OK})},
        401: {"description": "Invalid credentials", **_example({"invalid_credentials": _INVALID_CREDENTIALS})},
        429: {"description": "Temporarily locked", **_example({"account_locked": _ACCOUNT_LOCKED})},
        422: {"description": "Validation error", **_example({"validation_error": _VALIDATION_ERROR})},
    },
    summary="Log in (501 on D1)",
)
async def login(body: LoginRequest) -> Envelope[Session]:
    raise ApiError(501, "not_implemented")


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
    summary="Refresh (501 on D1)",
)
async def refresh(
    madar_refresh: str | None = _REFRESH_COOKIE,
    madar_csrf: str | None = _CSRF_COOKIE,
    x_csrf_token: str | None = _CSRF_HEADER,
) -> Envelope[Session]:
    raise ApiError(501, "not_implemented")


@router.post(
    "/logout",
    response_model=Envelope[None],
    responses={
        200: {"description": "Logged out; the refresh token is revoked", **_CLEARS_COOKIES},
        403: {"description": "CSRF header missing or mismatched", **_example({"csrf_failed": _CSRF_FAILED})},
    },
    summary="Log out (501 on D1)",
)
async def logout(
    madar_refresh: str | None = _REFRESH_COOKIE,
    madar_csrf: str | None = _CSRF_COOKIE,
    x_csrf_token: str | None = _CSRF_HEADER,
) -> Envelope[None]:
    raise ApiError(501, "not_implemented")


@router.get(
    "/me",
    response_model=Envelope[AdminUser],
    responses={
        200: {"description": "Current admin", **_example({"me": _ME_OK})},
        401: {"description": "Unauthenticated", **_example({"unauthenticated": _UNAUTHENTICATED})},
    },
    summary="Current admin (501 on D1)",
)
async def me() -> Envelope[AdminUser]:
    raise ApiError(501, "not_implemented")
