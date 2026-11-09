"""Admin accounts, managed from the CLI until the admin app's A16 screen (D6) (research R1).

Every change writes an ``audit_log`` row with both actor columns NULL (a system action) and
never a password or hash in its diff.
"""

from __future__ import annotations

from typing import Any

from email_validator import EmailNotValidError, validate_email
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.auth.passwords import MAX_LENGTH, MIN_LENGTH, hash_password
from app.db.models import AdminRefreshToken, AdminUser, AuditLog

ROLES = ("editor", "admin")
MAX_EMAIL_LENGTH = 254  # ck_admin_users_email_len
MAX_NAME_LENGTH = 80  # ck_admin_users_name_len


class AdminError(Exception):
    """A request the CLI refuses; the message is safe to print (it never holds a password)."""


def validate_password(password: str) -> None:
    if not MIN_LENGTH <= len(password) <= MAX_LENGTH:
        raise AdminError(f"the password must be {MIN_LENGTH} to {MAX_LENGTH} characters long")


def _clean_email(email: str) -> str:
    try:
        normalized = validate_email(email.strip(), check_deliverability=False).normalized
    except EmailNotValidError as exc:
        raise AdminError(f"not a valid email address: {exc}") from exc
    if len(normalized) > MAX_EMAIL_LENGTH:
        raise AdminError(f"the email must be at most {MAX_EMAIL_LENGTH} characters long")
    return normalized.lower()


def find_admin(session: Session, email: str) -> AdminUser | None:
    return session.scalar(select(AdminUser).where(func.lower(AdminUser.email) == email.strip().lower()))


def _require_admin(session: Session, email: str) -> AdminUser:
    admin = find_admin(session, email)
    if admin is None:
        raise AdminError("no admin has that email")
    return admin


def _audit(session: Session, admin: AdminUser, action: str, diff: dict[str, Any]) -> None:
    session.add(
        AuditLog(admin_user_id=None, source=None, entity="admin_users", entity_id=admin.id, action=action, diff=diff)
    )


def revoke_refresh_tokens(session: Session, admin_id: int) -> None:
    """End every session of the admin."""
    session.execute(
        update(AdminRefreshToken)
        .where(AdminRefreshToken.admin_user_id == admin_id, AdminRefreshToken.revoked_at.is_(None))
        .values(revoked_at=func.now())
    )


async def revoke_refresh_tokens_async(session: AsyncSession, admin_id: int, *, keep_family_id: Any = None) -> None:
    """The async twin of :func:`revoke_refresh_tokens`; ``keep_family_id`` keeps the caller's session."""
    statement = update(AdminRefreshToken).where(
        AdminRefreshToken.admin_user_id == admin_id, AdminRefreshToken.revoked_at.is_(None)
    )
    if keep_family_id is not None:
        statement = statement.where(AdminRefreshToken.family_id != keep_family_id)
    await session.execute(statement.values(revoked_at=func.now()))


def create_admin(session: Session, email: str, name: str, role: str, password: str) -> AdminUser:
    clean_email = _clean_email(email)
    clean_name = name.strip()
    if not 1 <= len(clean_name) <= MAX_NAME_LENGTH:
        raise AdminError(f"the name must be 1 to {MAX_NAME_LENGTH} characters long")
    if role not in ROLES:
        raise AdminError(f"the role must be one of: {', '.join(ROLES)}")
    validate_password(password)
    if find_admin(session, clean_email) is not None:
        raise AdminError("an admin with that email already exists")

    admin = AdminUser(email=clean_email, name=clean_name, role=role, password_hash=hash_password(password))
    session.add(admin)
    session.flush()
    _audit(session, admin, "create", {"email": [None, clean_email], "name": [None, clean_name], "role": [None, role]})
    return admin


def set_password(session: Session, email: str, password: str) -> AdminUser:
    """Replace the password and end every session of that admin."""
    validate_password(password)
    admin = _require_admin(session, email)
    admin.password_hash = hash_password(password)
    # A password set from the CLI is the owner's, not a temporary one (research R19).
    admin.must_change_password = False
    revoke_refresh_tokens(session, admin.id)
    _audit(session, admin, "update", {"password": "changed"})
    return admin


def deactivate(session: Session, email: str) -> AdminUser:
    """Switch the account off and end every session of that admin."""
    admin = _require_admin(session, email)
    revoke_refresh_tokens(session, admin.id)
    if admin.is_active:
        admin.is_active = False
        _audit(session, admin, "update", {"is_active": [True, False]})
    return admin
