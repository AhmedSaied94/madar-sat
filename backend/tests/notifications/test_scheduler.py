"""The reminder scheduler: one row per followed match, moved while pending, cancelled when dead (T019)."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import func, select

from app.db.models import NotificationOutbox
from app.notifications.scheduler import schedule_reminders
from tests import support


def _followed(session, now, **kwargs):
    bag = support.create_match_sync(session, now, **kwargs)
    device = support.new_device(session)
    support.follow(session, device, team=bag.home.id)
    return bag


def _rows(session, match_id: int):
    return list(
        (
            session.execute(
                select(NotificationOutbox).where(NotificationOutbox.dedupe_key == f"kickoff_reminder:{match_id}")
            )
        )
        .scalars()
        .all()
    )


def test_a_followed_match_20_minutes_ahead_gets_one_row_due_at_kickoff_minus_15(sync_session, frozen_now):
    bag = _followed(sync_session, frozen_now, kickoff_in=timedelta(minutes=20))

    report = schedule_reminders(sync_session, frozen_now)

    assert report.scheduled == 1
    rows = _rows(sync_session, bag.match.id)
    assert len(rows) == 1
    row = rows[0]
    assert row.type == "kickoff_reminder"
    assert row.status == "pending"
    assert row.payload["match_id"] == bag.match.id
    assert row.audience == {"kind": "match_followers", "match_id": bag.match.id}
    assert row.due_at == bag.match.kickoff_at - timedelta(minutes=15)


def test_running_twice_still_leaves_one_row(sync_session, frozen_now):
    bag = _followed(sync_session, frozen_now)

    schedule_reminders(sync_session, frozen_now)
    schedule_reminders(sync_session, frozen_now)

    assert len(_rows(sync_session, bag.match.id)) == 1


def test_an_unfollowed_match_gets_none(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now)
    support.new_device(sync_session)  # a device exists, but follows nothing

    schedule_reminders(sync_session, frozen_now)

    assert _rows(sync_session, bag.match.id) == []


def test_a_moved_kickoff_moves_a_pending_row(sync_session, frozen_now):
    bag = _followed(sync_session, frozen_now)
    schedule_reminders(sync_session, frozen_now)

    bag.match.kickoff_at = frozen_now + timedelta(minutes=40)
    sync_session.flush()
    schedule_reminders(sync_session, frozen_now)

    rows = _rows(sync_session, bag.match.id)
    assert len(rows) == 1
    assert rows[0].due_at == frozen_now + timedelta(minutes=25)


def test_a_moved_kickoff_after_sending_leaves_the_row_and_creates_no_second(sync_session, frozen_now):
    bag = _followed(sync_session, frozen_now)
    schedule_reminders(sync_session, frozen_now)
    [row] = _rows(sync_session, bag.match.id)
    row.status = "sent"
    row.sent_at = frozen_now
    sync_session.flush()

    bag.match.kickoff_at = frozen_now + timedelta(minutes=60)
    sync_session.flush()
    schedule_reminders(sync_session, frozen_now)

    rows = _rows(sync_session, bag.match.id)
    assert len(rows) == 1
    assert rows[0].status == "sent"
    assert rows[0].due_at == frozen_now + timedelta(minutes=5)  # the old kickoff − 15, untouched


def test_tbd_postponed_cancelled_and_past_24_hours_are_cancelled(sync_session, frozen_now):
    bags = {
        "tbd": _followed(sync_session, frozen_now),
        "postponed": _followed(sync_session, frozen_now),
        "cancelled": _followed(sync_session, frozen_now),
        "far": _followed(sync_session, frozen_now),
    }
    schedule_reminders(sync_session, frozen_now)
    bags["tbd"].match.time_tbd = True
    bags["tbd"].match.kickoff_at = None
    bags["postponed"].match.status = "postponed"
    bags["postponed"].match.status_source = "feed"
    bags["cancelled"].match.status = "cancelled"
    bags["cancelled"].match.status_source = "feed"
    bags["far"].match.kickoff_at = frozen_now + timedelta(hours=30)
    sync_session.flush()

    report = schedule_reminders(sync_session, frozen_now)

    assert report.cancelled == 4
    for bag in bags.values():
        assert [row.status for row in _rows(sync_session, bag.match.id)] == ["cancelled"]


def test_a_match_created_7_minutes_before_kickoff_is_due_now(sync_session, frozen_now):
    bag = _followed(sync_session, frozen_now, kickoff_in=timedelta(minutes=7))

    schedule_reminders(sync_session, frozen_now)

    [row] = _rows(sync_session, bag.match.id)
    assert row.due_at == frozen_now


def test_a_kickoff_in_the_past_is_never_scheduled(sync_session, frozen_now):
    bag = _followed(sync_session, frozen_now, kickoff_in=timedelta(minutes=-5))

    report = schedule_reminders(sync_session, frozen_now)

    assert report.scheduled == 0
    assert _rows(sync_session, bag.match.id) == []
    assert sync_session.scalar(select(func.count(NotificationOutbox.id))) == 0
