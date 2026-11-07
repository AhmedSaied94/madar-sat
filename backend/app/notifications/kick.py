"""Queueing the dispatcher from the producer's side (research R3).

A poll or an admin save that wrote a row due now should not wait for the every-minute beat. Both call
this after their commit: it looks for one pending row that is due and, only then, queues
``notifications.dispatch_due``. The beat stays the backstop if the broker is down.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.db.models import NotificationOutbox


def _pending_due(session: Session, now: datetime) -> bool:
    return (
        session.execute(
            select(NotificationOutbox.id)
            .where(NotificationOutbox.status == "pending", NotificationOutbox.due_at <= now)
            .limit(1)
        ).first()
        is not None
    )


async def _pending_due_async(session: AsyncSession, now: datetime) -> bool:
    return (
        await session.scalar(
            select(NotificationOutbox.id)
            .where(NotificationOutbox.status == "pending", NotificationOutbox.due_at <= now)
            .limit(1)
        )
        is not None
    )


def _queue() -> None:
    from app.workers import app as celery_app

    celery_app.send_task("notifications.dispatch_due", queue="notifications")


def kick_if_due(session: Session, now: datetime) -> bool:
    """Queue one dispatch run when something is due; returns whether it queued."""
    if not _pending_due(session, now):
        return False
    _queue()
    return True


async def kick_if_due_async(session: AsyncSession, now: datetime) -> bool:
    if not await _pending_due_async(session, now):
        return False
    _queue()
    return True


__all__ = ["kick_if_due", "kick_if_due_async"]
