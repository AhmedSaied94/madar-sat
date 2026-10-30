"""Access JWTs and rotating refresh tokens (research R2).

The access token is a short-lived HS256 JWT in the response body only. A refresh token is an
opaque random string, stored server-side only as its SHA-256, in a family: every use rotates it,
and presenting one that was already rotated or revoked revokes the whole family.

Time always comes from the caller (the request's ``get_now``), never from the clock here, so a
test with a frozen clock gets the same answers as production.
"""

from __future__ import annotations

import hashlib
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta

import jwt
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import AdminRefreshToken, AdminUser
from app.settings import get_settings

ACCESS_TTL = timedelta(minutes=15)
REFRESH_TTL = timedelta(days=14)
ALGORITHM = "HS256"
MIN_SECRET_BYTES = 32
ROLES = ("editor", "admin")


class TokenError(Exception):
    """Base of the access-token failures."""


class TokenExpired(TokenError):
    """A well-signed access token past its ``exp``."""


class InvalidToken(TokenError):
    """Malformed, wrongly signed, an unexpected algorithm, or missing claims."""


class RefreshInvalid(Exception):
    """Unknown, expired, revoked or reused refresh token, or its admin is gone or deactivated."""


@dataclass(frozen=True)
class AccessClaims:
    admin_id: int
    role: str
    issued_at: datetime
    expires_at: datetime


def signing_key() -> str:
    """The HS256 key from ``ADMIN_JWT_SECRET``; refuses a missing or short one."""
    secret = get_settings().admin_jwt_secret
    value = secret.get_secret_value() if secret is not None else ""
    if len(value.encode()) < MIN_SECRET_BYTES:
        raise RuntimeError(f"ADMIN_JWT_SECRET must be set and at least {MIN_SECRET_BYTES} bytes long")
    return value


def issue_access_token(admin_id: int, role: str, now: datetime) -> str:
    claims = {
        "sub": str(admin_id),
        "role": role,
        "iat": int(now.timestamp()),
        "exp": int((now + ACCESS_TTL).timestamp()),
    }
    return jwt.encode(claims, signing_key(), algorithm=ALGORITHM)


def decode_access_token(token: str, now: datetime) -> AccessClaims:
    """Verify the signature, then the expiry against ``now``. Only HS256 is accepted (never ``none``)."""
    try:
        claims = jwt.decode(
            token,
            signing_key(),
            algorithms=[ALGORITHM],
            options={"require": ["sub", "role", "iat", "exp"], "verify_exp": False, "verify_iat": False},
        )
        admin_id = int(claims["sub"])
        role = str(claims["role"])
        issued_at = datetime.fromtimestamp(int(claims["iat"]), tz=now.tzinfo)
        expires_at = datetime.fromtimestamp(int(claims["exp"]), tz=now.tzinfo)
    except (jwt.InvalidTokenError, ValueError, TypeError, OverflowError) as exc:
        raise InvalidToken from exc
    if role not in ROLES:
        raise InvalidToken
    if expires_at <= now:
        raise TokenExpired
    return AccessClaims(admin_id=admin_id, role=role, issued_at=issued_at, expires_at=expires_at)


def hash_refresh_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


def _new_refresh_token() -> tuple[str, str]:
    raw = secrets.token_urlsafe(32)
    return raw, hash_refresh_token(raw)


async def issue_refresh_token(
    session: AsyncSession, admin_id: int, now: datetime, family_id: uuid.UUID | None = None
) -> tuple[str, AdminRefreshToken]:
    """Start a refresh token (a new family unless ``family_id`` is given). Returns ``(raw, row)``."""
    raw, token_hash = _new_refresh_token()
    row = AdminRefreshToken(
        admin_user_id=admin_id,
        token_hash=token_hash,
        family_id=family_id or uuid.uuid4(),
        expires_at=now + REFRESH_TTL,
    )
    session.add(row)
    await session.flush()
    return raw, row


async def rotate_refresh_token(session: AsyncSession, raw: str, now: datetime) -> tuple[AdminUser, str]:
    """Exchange a refresh token for a new one in the same family. Returns ``(admin, new_raw)``.

    The row is locked (``FOR UPDATE``) so two requests with one token can't both succeed. Reuse of a
    rotated or revoked token revokes the whole family; that revocation is committed here, before
    ``RefreshInvalid`` is raised, because the caller rolls back on an error.
    """
    row = await session.scalar(
        select(AdminRefreshToken).where(AdminRefreshToken.token_hash == hash_refresh_token(raw)).with_for_update()
    )
    if row is None:
        raise RefreshInvalid
    if row.revoked_at is not None or row.replaced_by_id is not None:
        await session.execute(
            update(AdminRefreshToken)
            .where(AdminRefreshToken.family_id == row.family_id, AdminRefreshToken.revoked_at.is_(None))
            .values(revoked_at=now)
        )
        await session.commit()
        raise RefreshInvalid
    if row.expires_at <= now:
        raise RefreshInvalid

    admin = await session.get(AdminUser, row.admin_user_id)
    if admin is None or not admin.is_active:
        raise RefreshInvalid

    new_raw, new_row = await issue_refresh_token(session, admin.id, now, family_id=row.family_id)
    row.revoked_at = now
    row.replaced_by_id = new_row.id
    await session.flush()
    return admin, new_raw


async def revoke_refresh_token(session: AsyncSession, raw: str, now: datetime) -> None:
    """Revoke one token (logout). An unknown or already revoked token is not an error."""
    await session.execute(
        update(AdminRefreshToken)
        .where(AdminRefreshToken.token_hash == hash_refresh_token(raw), AdminRefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )
