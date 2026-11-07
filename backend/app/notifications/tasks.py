"""The notifications Celery tasks: schedule, dispatch and prune (contracts/pipelines-and-ops.md).

Every task runs on the D2 base class (bound, backoff, jitter, bounded retries). The scheduler takes
``lock:notifications:schedule`` so two beats cannot double-schedule; the dispatcher's own claim is
``SKIP LOCKED``, which is what makes two workers safe.
"""

from __future__ import annotations

import logging
from datetime import UTC, datetime
from typing import Any

import redis

from app.workers import task
from app.workers.base import Retryable
from app.workers.config import get_worker_settings
from app.workers.locks import redis_lock

log = logging.getLogger("madar.notifications")

SCHEDULE_LOCK_TTL = 4 * 60
DISPATCH_LOCK_TTL = 4 * 60


def now_utc() -> datetime:
    return datetime.now(UTC)


def redis_client() -> redis.Redis:
    return redis.Redis.from_url(get_worker_settings().broker_url)


@task(name="notifications.schedule_reminders")
def schedule_reminders(self: Any) -> dict[str, Any]:
    from app.db.session import SyncSession
    from app.notifications.scheduler import schedule_reminders as run_schedule

    now = now_utc()
    with redis_lock("lock:notifications:schedule", SCHEDULE_LOCK_TTL, client=redis_client()) as acquired:
        if not acquired:
            log.info("skipped", extra={"task": "notifications.schedule_reminders", "why": "lock_held"})
            return {"skipped": True}

        with SyncSession() as session:
            report = run_schedule(session, now)
            session.commit()

        if report.due_now:
            dispatch_due.apply_async(queue="notifications")
        log.info("scheduled", extra={"scheduled": report.scheduled, "cancelled": report.cancelled})
        return {"scheduled": report.scheduled, "cancelled": report.cancelled, "due_now": report.due_now}


@task(name="notifications.dispatch_due")
def dispatch_due(self: Any) -> dict[str, Any]:
    from app.db.session import SyncSession
    from app.notifications.dispatcher import dispatch_due as run_dispatch
    from app.notifications.dispatcher import mark_failed
    from app.notifications.sender import FcmSender

    now = now_utc()
    with redis_lock("lock:notifications:dispatch", DISPATCH_LOCK_TTL, client=redis_client()) as acquired:
        if not acquired:
            log.info("skipped", extra={"task": "notifications.dispatch_due", "why": "lock_held"})
            return {"skipped": True}

        sender = FcmSender.from_settings()
        with SyncSession() as session:
            report = run_dispatch(session, sender, now, sender.pwa_origin)
            if report.retry_row_id is not None:
                if self.request.retries < self.max_retries:
                    raise Retryable("a page failed to send; retrying from the cursor")
                mark_failed(session, report.retry_row_id)
                log.error("dispatch_failed", extra={"row": report.retry_row_id})
        # The turn ended with work still due (its budget or its 50 s): take the next turn now (R8).
        if report.requeued:
            dispatch_due.apply_async(queue="notifications")
        return {
            "claimed": len(report.claimed),
            "sent": report.sent,
            "failed": report.failed,
            "cancelled": report.cancelled,
            "deferred": report.deferred,
        }


@task(name="notifications.prune_outbox")
def prune_outbox(self: Any) -> dict[str, Any]:
    from app.db.session import SyncSession
    from app.notifications.dispatcher import prune_outbox as run_prune

    del self
    with SyncSession() as session:
        removed = run_prune(session, now_utc())
        session.commit()
    log.info("pruned", extra={"removed": removed})
    return {"removed": removed}
