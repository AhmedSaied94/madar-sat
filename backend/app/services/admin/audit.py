"""The audit log: A17's read side (contracts/admin-api.md, research R20).

Read-only (FR-026). ``audit_log`` has no dataset version of its own — six writers add rows and not
all bump a name — so the route's ``ETag`` is a 30 s bucket over every dataset (R20).
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound
from app.db.models import AdminUser, AuditLog, NotificationOutbox
from app.schemas import admin as a
from app.services.admin import lists

NOT_FOUND = "audit_not_found"


def _actor(entry: AuditLog, admin_name: str | None) -> a.AuditActor:
    """An admin, the importer named by ``source``, or the system with neither (contracts/admin-api)."""
    if entry.admin_user_id is not None:
        return a.AuditActor(kind="admin", id=entry.admin_user_id, name=admin_name)
    if entry.source is not None:
        return a.AuditActor(kind="importer", id=None, name=entry.source)
    return a.AuditActor(kind="system", id=None, name=None)


def _stored_diff(entry: AuditLog) -> dict[str, Any]:
    """``diff`` exactly as stored: old shapes, scalars and lists alike (R20)."""
    return dict(entry.diff or {})


def _row(entry: AuditLog, admin_name: str | None, notified: set[int]) -> a.AuditRow:
    return a.AuditRow(
        id=entry.id,
        created_at=entry.created_at,
        actor=_actor(entry, admin_name),
        entity=entry.entity,
        entity_id=entry.entity_id,
        action=entry.action,
        summary_fields=list(_stored_diff(entry)),
        has_notification=entry.id in notified,
    )


async def _notified(session: AsyncSession, ids: list[int]) -> set[int]:
    """The audit ids that a push was keyed on (``notification_outbox.audit_log_id``)."""
    if not ids:
        return set()
    rows = await session.scalars(
        select(NotificationOutbox.audit_log_id).where(NotificationOutbox.audit_log_id.in_(ids))
    )
    return {row for row in rows if row is not None}


def _cursor_condition(cursor: list[Any]) -> Any:
    stamp = datetime.fromisoformat(str(cursor[0]))
    return or_(
        AuditLog.created_at < stamp,
        and_(AuditLog.created_at == stamp, AuditLog.id < int(cursor[1])),
    )


async def entries(
    session: AsyncSession,
    *,
    admin_user_id: int | None,
    source: str | None,
    entity: str | None,
    entity_id: int | None,
    from_dt: datetime | None,
    to_dt: datetime | None,
    cursor: str | None,
    limit: int,
) -> tuple[list[a.AuditRow], str | None]:
    """Newest first by ``(created_at, id)``; the filters use the base schema's two indexes."""
    query = select(AuditLog, AdminUser.name).outerjoin(AdminUser, AdminUser.id == AuditLog.admin_user_id)
    if admin_user_id is not None:
        query = query.where(AuditLog.admin_user_id == admin_user_id)
    if source is not None:
        query = query.where(AuditLog.source == source)
    if entity is not None:
        query = query.where(AuditLog.entity == entity)
    if entity_id is not None:
        query = query.where(AuditLog.entity_id == entity_id)
    if from_dt is not None:
        query = query.where(AuditLog.created_at >= from_dt)
    if to_dt is not None:
        query = query.where(AuditLog.created_at <= to_dt)
    if cursor is not None:
        query = query.where(_cursor_condition(lists.decode_cursor(cursor, 2)))

    found = (
        await session.execute(query.order_by(AuditLog.created_at.desc(), AuditLog.id.desc()).limit(limit + 1))
    ).all()
    more = len(found) > limit
    page = found[:limit]
    notified = await _notified(session, [entry.id for entry, _ in page])
    next_cursor = lists.encode_cursor([page[-1][0].created_at.isoformat(), page[-1][0].id]) if more and page else None
    return [_row(entry, name, notified) for entry, name in page], next_cursor


async def entry(session: AsyncSession, entry_id: int) -> a.AuditDetail:
    """One row with its stored diff and the push it started, or ``404 audit_not_found``."""
    found = (
        await session.execute(
            select(AuditLog, AdminUser.name)
            .outerjoin(AdminUser, AdminUser.id == AuditLog.admin_user_id)
            .where(AuditLog.id == entry_id)
        )
    ).first()
    if found is None:
        raise EntityNotFound(NOT_FOUND)
    row, admin_name = found
    outbox = (
        await session.scalars(
            select(NotificationOutbox)
            .where(NotificationOutbox.audit_log_id == row.id)
            .order_by(NotificationOutbox.id.desc())
            .limit(1)
        )
    ).first()
    notification = (
        a.AuditNotification(
            id=outbox.id,
            type=outbox.type,
            status=outbox.status,
            sent=outbox.sent,
            failed=outbox.failed,
        )
        if outbox is not None
        else None
    )
    return a.AuditDetail(
        **_row(row, admin_name, {row.id} if outbox is not None else set()).model_dump(),
        diff=_stored_diff(row),
        notification=notification,
    )
