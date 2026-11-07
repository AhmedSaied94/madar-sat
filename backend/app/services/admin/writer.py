"""The one unit of work behind every admin mutation (research R6, FR-009, FR-010).

A handler runs the same steps in one transaction, in this order:

1. ``lock_row``: ``SELECT … FOR UPDATE`` on the entity row (404 when it is gone);
2. ``require_version``: ``428`` without ``If-Match``, ``409 edit_conflict`` when it differs from the
   version recomputed under the lock;
3. apply the validated change to the row (the handler's own code);
4. ``save_update`` / ``save_create`` / ``save_delete``: diff the row's state before and after, add the
   changed lockable columns to ``locked_fields``, write the ``audit_log`` row and bump the datasets
   as the last statement;
5. the handler commits and answers with the new version.

An update that changes nothing writes nothing: no audit row, no lock, no dataset bump.
"""

from __future__ import annotations

import re
from collections.abc import Awaitable, Callable, Iterable, Mapping
from datetime import datetime
from typing import Any, TypeVar

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import (
    ApiError,
    EntityNotFound,
    already_exists,
    edit_conflict,
    precondition_required,
    validation_failed,
)
from app.auth.roles import AuthedAdmin
from app.db.models import AdminUser, AuditLog, Base, DatasetVersion
from app.services.admin import versions

T = TypeVar("T", bound=Base)

# Not part of the audit diff: bookkeeping that follows from the change, not a change an editor made.
AUDIT_IGNORED = frozenset({"locked_fields", "status_updated_at"})

# Datasets each kind of change bumps (research R6).
MATCH_CHANGED = ("matches",)
MATCH_KICKOFF_CHANGED = ("matches", "live")
MATCH_STATUS_CHANGED = ("matches", "live")
TEAM_CHANGED = ("teams", "matches")
COMPETITION_CHANGED = ("competitions", "matches")
SATELLITE_CHANGED = ("satellites", "channels", "matches")
CHANNEL_CHANGED = ("channels", "satellites", "matches")
COMMENTATOR_CHANGED = ("commentators", "matches")
# A hidden name changes what the match, satellite and channel lists show (R6, amended 2026-10-31).
HIDDEN_NAME_CHANGED = ("matches", "channels")


# Unique indexes of the base schema and the field an editor would have to change.
UNIQUE_FIELDS = {
    "satellites_slug_key": "slug",
    "satellites_name_en_key": "name_en",
    "competitions_sport_name_norm_key": "name",
    "channels_carriage_key": "carriage",
    "channels_platform_key": "name",
    "commentators_name_norm_key": "name",
}
_CONSTRAINT = re.compile(r'constraint "([^"]+)"')


def integrity_error(exc: IntegrityError) -> ApiError:
    """The API error for a constraint the services didn't catch first (a race, or a rule they don't mirror)."""
    message = str(exc.orig)
    match = _CONSTRAINT.search(message)
    name = match.group(1) if match else ""
    if name in UNIQUE_FIELDS:
        return already_exists(UNIQUE_FIELDS[name])
    reason = "not_found" if "foreign key" in message else "constraint"
    return validation_failed([{"loc": ["body"], "type": reason}])


async def flush(session: AsyncSession) -> None:
    """Flush pending changes; a violated constraint rolls the transaction back and becomes a 409/422."""
    try:
        await session.flush()
    except IntegrityError as exc:
        await session.rollback()
        raise integrity_error(exc) from None


async def lock_row(session: AsyncSession, model: type[T], row_id: int, not_found: str) -> T:
    """Lock and load one row, discarding any copy the session already holds."""
    row = await session.get(model, row_id, with_for_update=True, populate_existing=True)
    if row is None:
        raise EntityNotFound(not_found)
    return row


async def last_change(session: AsyncSession, entity: str, entity_id: int) -> tuple[dict[str, str] | None, str | None]:
    """``(changed_by, changed_at)`` from the entity's latest audit row; ``(None, None)`` without one."""
    latest = (
        await session.execute(
            select(AuditLog.source, AuditLog.created_at, AdminUser.name)
            .outerjoin(AdminUser, AdminUser.id == AuditLog.admin_user_id)
            .where(AuditLog.entity == entity, AuditLog.entity_id == entity_id)
            .order_by(AuditLog.id.desc())
            .limit(1)
        )
    ).first()
    if latest is None:
        return None, None
    source, created_at, admin_name = latest
    changed_by: dict[str, str] | None = None
    if source is not None:
        changed_by = {"kind": "source", "name": source}
    elif admin_name is not None:
        changed_by = {"kind": "admin", "name": admin_name}
    return changed_by, created_at.isoformat()


async def require_version(session: AsyncSession, row: Base, entity: str, if_match: str | None) -> None:
    """Compare ``If-Match`` with the version recomputed under the row lock."""
    if if_match is None:
        raise precondition_required()
    current = await versions.version_of(session, row)
    if not versions.matches_etag(if_match, current):
        changed_by, changed_at = await last_change(session, entity, row.id)  # type: ignore[attr-defined]
        raise edit_conflict(current, changed_by, changed_at)


async def lock_and_check(
    session: AsyncSession, model: type[T], row_id: int, not_found: str, entity: str, if_match: str | None
) -> T:
    """Steps 1 and 2. A missing header is refused before any query: nothing is read or written."""
    if if_match is None:
        raise precondition_required()
    row = await lock_row(session, model, row_id, not_found)
    await require_version(session, row, entity, if_match)
    return row


def diff_state(before: Mapping[str, Any], after: Mapping[str, Any]) -> dict[str, list[Any]]:
    """``{field: [old, new]}`` for the fields whose value changed."""
    return {
        key: [before.get(key), value]
        for key, value in after.items()
        if key not in AUDIT_IGNORED and before.get(key) != value
    }


def lock_changed_fields(row: Any, changed: Iterable[str], lockable: frozenset[str]) -> None:
    """Protect the lockable columns an editor changed from the importers."""
    add = set(changed) & lockable
    if add:
        row.locked_fields = sorted(set(row.locked_fields or []) | add)


def add_audit(
    session: AsyncSession,
    admin: AuthedAdmin | None,
    entity: str,
    entity_id: int | None,
    action: str,
    diff: Mapping[str, Any],
) -> AuditLog:
    """Add the audit row and return it, so a ``then`` step can key a push on its id (R20)."""
    row = AuditLog(
        admin_user_id=admin.id if admin is not None else None,
        source=None,
        entity=entity,
        entity_id=entity_id,
        action=action,
        diff=dict(diff),
    )
    session.add(row)
    return row


async def bump_datasets(session: AsyncSession, names: Iterable[str]) -> None:
    """``version = version + 1`` for each dataset; the last statement of the transaction."""
    wanted = sorted(set(names))
    if not wanted:
        return
    await flush(session)
    await session.execute(
        update(DatasetVersion)
        .where(DatasetVersion.name.in_(wanted))
        .values(version=DatasetVersion.version + 1, updated_at=func.now())
    )


def _touch(row: Any, now: datetime) -> None:
    if hasattr(row, "updated_at"):
        row.updated_at = now


async def save_update(
    session: AsyncSession,
    admin: AuthedAdmin,
    *,
    entity: str,
    row: Base,
    before: Mapping[str, Any],
    datasets: Iterable[str] | Callable[[set[str]], Iterable[str]],
    now: datetime,
    lockable: frozenset[str] = frozenset(),
    extra_diff: Mapping[str, Any] | None = None,
    action: str = "update",
    then: Callable[[AuditLog], Awaitable[None]] | None = None,
) -> bool:
    """Step 4: returns whether anything changed.

    ``before`` is ``versions.row_state(row)`` taken before the edit. ``datasets`` is the list to bump, or a
    function of the changed diff keys (a match bumps ``live`` only when its kickoff or status changed).
    ``then`` runs after the audit row is flushed and before the bump, so a push keyed on that audit row
    exists before the datasets move, and never runs when nothing changed.
    """
    await flush(session)
    diff: dict[str, Any] = diff_state(before, versions.row_state(row))
    changed_columns = set(diff)
    diff.update(extra_diff or {})
    if not diff:
        return False

    lock_changed_fields(row, changed_columns, lockable)
    _touch(row, now)
    audit = add_audit(session, admin, entity, row.id, action, diff)  # type: ignore[attr-defined]
    await flush(session)
    if then is not None:
        await then(audit)
    await bump_datasets(session, datasets(set(diff)) if callable(datasets) else datasets)
    return True


async def save_create(
    session: AsyncSession,
    admin: AuthedAdmin,
    *,
    entity: str,
    row: Base,
    datasets: Iterable[str],
    extra_diff: Mapping[str, Any] | None = None,
) -> None:
    """A created row: every non-null column is a change from nothing."""
    await flush(session)
    diff: dict[str, Any] = {
        key: [None, value]
        for key, value in versions.row_state(row).items()
        if key not in AUDIT_IGNORED and value not in (None, [])
    }
    diff.update(extra_diff or {})
    add_audit(session, admin, entity, row.id, "create", diff)  # type: ignore[attr-defined]
    await bump_datasets(session, datasets)


async def save_delete(
    session: AsyncSession,
    admin: AuthedAdmin,
    *,
    entity: str,
    row: Base,
    datasets: Iterable[str],
    now: datetime,
    soft: bool = False,
) -> None:
    """Audit the row, delete it (``deleted_at = now`` when ``soft``), then bump the datasets."""
    state = versions.row_state(row)
    diff = {key: [value, None] for key, value in state.items() if key not in AUDIT_IGNORED and value not in (None, [])}
    add_audit(session, admin, entity, row.id, "delete", diff)  # type: ignore[attr-defined]
    if soft:
        row.deleted_at = now  # type: ignore[attr-defined]
        _touch(row, now)
    else:
        await session.delete(row)
    await bump_datasets(session, datasets)
