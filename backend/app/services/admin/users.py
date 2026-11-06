"""Staff accounts: A16's list, create, edit and password reset (contracts/admin-api.md).

The writer's generic path diffs ``versions.row_state(row)``, which hashes every stored column, so it
would put ``password_hash`` into ``audit_log``. Every write here therefore builds its own diff over
the allowlist ``STATE`` and calls ``writer.add_audit``; ``versions.row_state`` is only ever read to
compute an ``ETag``, never to write an audit row (research R19).
"""

from __future__ import annotations

import secrets
from collections.abc import Iterable
from typing import Any

import redis.asyncio as aioredis
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import ApiError
from app.auth.admins import revoke_refresh_tokens_async
from app.auth.limits import LoginLimiter
from app.auth.passwords import hash_password
from app.auth.roles import AuthedAdmin
from app.db.models import AdminUser
from app.schemas import admin as a
from app.services.admin import refs, versions, writer

ENTITY = "admin_users"
NOT_FOUND = "admin_user_not_found"

# What an admin may change, and what an audit row may show: never ``password_hash`` or the flag (R19).
STATE = ("email", "name", "role", "is_active")

# 12 bytes of ``secrets`` give 16 URL-safe characters, so a temporary password clears the 12 minimum.
TEMPORARY_PASSWORD_BYTES = 12

_ADMIN_ROLE = "admin"


def temporary_password() -> str:
    """A one-time password from ``secrets``; returned once with ``no-store`` and never logged (R19)."""
    return secrets.token_urlsafe(TEMPORARY_PASSWORD_BYTES)


def state(user: AdminUser) -> dict[str, Any]:
    """The allowlist an audit row and a diff may look at."""
    return {name: getattr(user, name) for name in STATE}


def version(user: AdminUser) -> str:
    """The account's ``ETag``: the row's stored version, the same one ``lock_and_check`` compares."""
    return versions.etag_of(versions.row_state(user))


def to_row(user: AdminUser, locked_for_s: int | None) -> a.AdminUserRow:
    return a.AdminUserRow(
        id=user.id,
        email=user.email,
        name=user.name,
        role=a.AdminRole(user.role),
        is_active=user.is_active,
        locked_for_s=locked_for_s,
        last_login_at=user.last_login_at,
        must_change_password=user.must_change_password,
    )


async def _lock_ttls(redis: aioredis.Redis, emails: Iterable[str]) -> list[int | None]:
    """Seconds left on each account's lock, in one round trip (``None`` when it isn't locked)."""
    wanted = list(emails)
    if not wanted:
        return []
    pipeline = redis.pipeline()
    for email in wanted:
        pipeline.ttl(LoginLimiter.account_lock_key(email))
    ttls: list[Any] = await pipeline.execute()
    # -1: a key with no expiry; -2: no key at all. Neither is a lock.
    return [max(int(ttl), 1) if int(ttl) >= 0 else None for ttl in ttls]


async def accounts(session: AsyncSession, redis: aioredis.Redis) -> list[a.AdminUserRow]:
    """Every account, by id; the list is small, so it has no cursor."""
    rows = list((await session.scalars(select(AdminUser).order_by(AdminUser.id))).all())
    ttls = await _lock_ttls(redis, [row.email for row in rows])
    return [to_row(row, locked) for row, locked in zip(rows, ttls, strict=True)]


async def _email_taken(session: AsyncSession, email: str) -> bool:
    return await session.scalar(select(AdminUser.id).where(func.lower(AdminUser.email) == email.lower())) is not None


async def create(session: AsyncSession, admin: AuthedAdmin, body: a.UserCreate) -> tuple[AdminUser, str]:
    """A new account with a temporary password; it starts active and unflagged."""
    email = str(body.email).strip().lower()
    if await _email_taken(session, email):
        raise ApiError(409, "email_taken")

    password = temporary_password()
    user = AdminUser(
        email=email,
        name=body.name.strip(),
        role=body.role.value,
        password_hash=hash_password(password),
        is_active=True,
        must_change_password=False,
    )
    session.add(user)
    try:
        await session.flush()
    except IntegrityError:
        # The unique index is ``lower(email)``: the pre-check lost a race, and nothing was written.
        await session.rollback()
        raise ApiError(409, "email_taken") from None

    writer.add_audit(
        session,
        admin,
        ENTITY,
        user.id,
        "create",
        {"email": [None, email], "name": [None, user.name], "role": [None, user.role], "is_active": [None, True]},
    )
    await writer.bump_datasets(session, (ENTITY,))
    return user, password


async def _active_admins(session: AsyncSession) -> int:
    return int(
        await session.scalar(
            select(func.count())
            .select_from(AdminUser)
            .where(AdminUser.role == _ADMIN_ROLE, AdminUser.is_active.is_(True))
        )
        or 0
    )


async def update(
    session: AsyncSession,
    admin: AuthedAdmin,
    user_id: int,
    body: a.UserPatch,
    if_match: str | None,
) -> AdminUser:
    """Rename, change the role or switch an account on/off; the diff is the allowlist, never the hash."""
    user = await writer.lock_and_check(session, AdminUser, user_id, NOT_FOUND, ENTITY, if_match)
    changes = body.model_dump(exclude_unset=True)
    nulls = [refs.field_error([name], "null_not_allowed") for name, value in changes.items() if value is None]
    refs.raise_if_any(nulls)

    before = state(user)
    after = {
        "email": before["email"],
        "name": str(changes.get("name", before["name"])).strip(),
        "role": _text(changes.get("role", before["role"])),
        "is_active": bool(changes.get("is_active", before["is_active"])),
    }
    if not after["name"]:
        refs.raise_if_any([refs.field_error(["name"], "empty")])

    # The system keeps one active admin: that answer is more useful than "not yourself", and it is
    # the only way this code is reachable at all (an admin acting on the sole admin is that admin).
    loses_admin = (
        before["role"] == _ADMIN_ROLE
        and before["is_active"]
        and (after["role"] != _ADMIN_ROLE or not after["is_active"])
    )
    if loses_admin and await _active_admins(session) <= 1:
        raise ApiError(409, "last_admin")
    if user.id == admin.id and (after["role"] != before["role"] or not after["is_active"]):
        raise ApiError(409, "cannot_change_self")

    user.name = after["name"]
    user.role = after["role"]
    user.is_active = after["is_active"]
    if before["is_active"] and not after["is_active"]:
        await revoke_refresh_tokens_async(session, user.id)

    diff = {name: [before[name], after[name]] for name in STATE if before[name] != after[name]}
    if not diff:
        return user
    writer.add_audit(session, admin, ENTITY, user.id, "update", diff)
    await writer.bump_datasets(session, (ENTITY,))
    return user


async def reset_password(
    session: AsyncSession, admin: AuthedAdmin, user_id: int, if_match: str | None
) -> tuple[AdminUser, str]:
    """A temporary password, every session revoked; the audit row holds only ``{"password": "changed"}``."""
    user = await writer.lock_and_check(session, AdminUser, user_id, NOT_FOUND, ENTITY, if_match)
    password = temporary_password()
    user.password_hash = hash_password(password)
    user.must_change_password = True
    await revoke_refresh_tokens_async(session, user.id)
    writer.add_audit(session, admin, ENTITY, user.id, "update", {"password": "changed"})
    await writer.bump_datasets(session, (ENTITY,))
    return user, password


def _text(value: Any) -> str:
    """A ``StrEnum`` member or a plain string as the text column stores it."""
    return value.value if hasattr(value, "value") else str(value)
