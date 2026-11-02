"""The notifications Celery tasks: the lock, the dispatcher's failure path and the prune (B1-R1-4, -6).

The task functions are called through ``.run()`` with the test's transaction handed in place of
``SyncSession``, a real Redis for the lock and the frozen clock, so the wiring is exercised without
a broker.
"""

from __future__ import annotations

import os
from datetime import timedelta
from typing import Any

import pytest
import redis
from sqlalchemy import select

from app.db.models import NotificationOutbox
from app.notifications import tasks
from app.notifications.sender import FcmSender
from app.workers.base import Retryable
from tests import support
from tests.support import FakePushSender

TEST_REDIS_URL = os.environ.get("TEST_REDIS_URL", "redis://localhost:6380/0")


class _SharedSession:
    """Hands the test's transaction to a task instead of opening (and closing) its own."""

    def __init__(self, session: Any) -> None:
        self._session = session

    def __call__(self) -> _SharedSession:
        return self

    def __enter__(self) -> Any:
        return self._session

    def __exit__(self, *exc: object) -> bool:
        return False


class _Held:
    """A lock context that always answers ``False`` (someone else holds it)."""

    def __enter__(self) -> bool:
        return False

    def __exit__(self, *exc: object) -> bool:
        return False


@pytest.fixture
def wired(monkeypatch, sync_session, frozen_now):
    """The tasks on the test's session, the frozen clock and the test Redis."""
    from app.db import session as db_session

    monkeypatch.setattr(db_session, "SyncSession", _SharedSession(sync_session))
    monkeypatch.setattr(tasks, "now_utc", lambda: frozen_now)
    monkeypatch.setattr(tasks, "redis_client", lambda: redis.Redis.from_url(TEST_REDIS_URL))
    return frozen_now


def _row(session, match, now, *, suffix: str = "") -> NotificationOutbox:
    outbox = NotificationOutbox(
        type="kickoff_reminder",
        dedupe_key=f"kickoff_reminder:{match.id}{suffix}",
        payload={"match_id": match.id, "kickoff_at": match.kickoff_at.isoformat() if match.kickoff_at else None},
        audience={"kind": "match_followers", "match_id": match.id},
        due_at=now,
        status="pending",
    )
    session.add(outbox)
    session.flush()
    return outbox


def _follower(session, now, **kwargs):
    bag = support.create_match_sync(session, now, **kwargs)
    device = support.new_device(session, token=f"tok-{bag.match.id}", push_token=f"push-{bag.match.id}")
    support.follow(session, device, team=bag.home.id)
    return bag, device


def _failing_sender(monkeypatch) -> FakePushSender:
    sender = FakePushSender(fail_every_page=True)
    monkeypatch.setattr(FcmSender, "from_settings", classmethod(lambda cls: sender))
    return sender


def test_schedule_reminders_creates_the_row_and_queues_the_dispatch(wired, sync_session, monkeypatch):
    _follower(sync_session, wired, kickoff_in=timedelta(minutes=7))
    queued: list[str] = []
    monkeypatch.setattr(tasks.dispatch_due, "apply_async", lambda **kwargs: queued.append(kwargs.get("queue", "")))

    result = tasks.schedule_reminders.run()

    assert result["scheduled"] == 1
    assert result["due_now"] == 1
    assert queued == ["notifications"]
    [row] = sync_session.execute(select(NotificationOutbox)).scalars()
    assert row.status == "pending"


def test_schedule_reminders_skips_while_the_lock_is_held(wired, sync_session, monkeypatch):
    _follower(sync_session, wired)
    monkeypatch.setattr(tasks, "redis_lock", lambda *args, **kwargs: _Held())

    result = tasks.schedule_reminders.run()

    assert result == {"skipped": True}
    assert sync_session.execute(select(NotificationOutbox)).scalars().all() == []


def test_dispatch_due_sends_a_due_row(wired, sync_session, monkeypatch):
    bag, device = _follower(sync_session, wired)
    _row(sync_session, bag.match, wired)
    sender = FakePushSender()
    monkeypatch.setattr(FcmSender, "from_settings", classmethod(lambda cls: sender))

    result = tasks.dispatch_due.run()

    assert result["sent"] == 1
    assert sender.tokens_sent == [device.push_token]


def test_dispatch_due_marks_the_row_failed_when_its_retries_are_exhausted(wired, sync_session, monkeypatch):
    """A row released to ``pending`` must still end ``failed`` at the task layer (B1-R1-4)."""
    bag, _ = _follower(sync_session, wired)
    outbox = _row(sync_session, bag.match, wired)
    _failing_sender(monkeypatch)

    task = tasks.dispatch_due
    task.push_request(retries=task.max_retries)
    try:
        result = task.run()
    finally:
        task.pop_request()

    assert result["sent"] == 0
    sync_session.refresh(outbox)
    assert outbox.status == "failed"


def test_dispatch_due_raises_retryable_while_attempts_remain(wired, sync_session, monkeypatch):
    bag, _ = _follower(sync_session, wired)
    outbox = _row(sync_session, bag.match, wired)
    _failing_sender(monkeypatch)

    with pytest.raises(Retryable):
        tasks.dispatch_due.run()

    sync_session.refresh(outbox)
    assert outbox.status == "pending"


def test_prune_outbox_deletes_old_finished_rows(wired, sync_session):
    bag, _ = _follower(sync_session, wired)
    old = _row(sync_session, bag.match, wired - timedelta(days=31))
    old.status = "sent"
    old.sent_at = wired - timedelta(days=31)
    fresh = _row(sync_session, bag.match, wired, suffix="-fresh")
    fresh.status = "sent"
    fresh.sent_at = wired
    sync_session.flush()

    result = tasks.prune_outbox.run()

    assert result["removed"] == 1
    assert set(sync_session.execute(select(NotificationOutbox.id)).scalars()) == {fresh.id}


def test_the_schedule_holds_one_row_per_match(wired, sync_session, monkeypatch):
    _follower(sync_session, wired)
    monkeypatch.setattr(tasks.dispatch_due, "apply_async", lambda **kwargs: None)

    tasks.schedule_reminders.run()
    tasks.schedule_reminders.run()

    assert len(sync_session.execute(select(NotificationOutbox)).scalars().all()) == 1
