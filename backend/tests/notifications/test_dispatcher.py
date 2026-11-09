"""The dispatcher: claim, audience, pages, cursor resume and UNREGISTERED cleanup (T020)."""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from sqlalchemy import delete, select, text

from app.db.models import Device, NotificationOutbox
from app.notifications.dispatcher import MAX_ATTEMPTS, claim, dispatch_due, mark_failed, reclaim_stuck
from tests import support
from tests.support import FakePushSender


def _row(session, match, *, due_at, status: str = "pending") -> NotificationOutbox:
    outbox = NotificationOutbox(
        type="kickoff_reminder",
        dedupe_key=f"kickoff_reminder:{match.id}-{status}-{due_at.isoformat()}",
        payload={
            "match_id": match.id,
            "kickoff_at": match.kickoff_at.isoformat() if match.kickoff_at else None,
        },
        audience={"kind": "match_followers", "match_id": match.id},
        due_at=due_at,
        status=status,
    )
    session.add(outbox)
    session.flush()
    return outbox


def _bag_with_follower(session, now, **kwargs) -> tuple[Any, Device]:
    bag = support.create_match_sync(session, now, **kwargs)
    device = support.new_device(session, token=f"tok-{bag.match.id}", push_token=f"push-{bag.match.id}")
    support.follow(session, device, team=bag.home.id)
    return bag, device


def test_two_sessions_claim_disjoint_rows(_prepare_database, frozen_now):
    """While one connection holds rows with ``FOR UPDATE``, the other's claim skips them."""
    from app.db.session import SyncSession

    with SyncSession() as setup:
        for index in range(3):
            setup.add(
                NotificationOutbox(
                    type="kickoff_reminder",
                    dedupe_key=f"claim-test-{index}-{frozen_now.isoformat()}",
                    payload={"match_id": 1},
                    audience={"kind": "match_followers", "match_id": 1},
                    due_at=frozen_now,
                    status="pending",
                )
            )
        setup.commit()

    first = SyncSession()
    second = SyncSession()
    try:
        locked = set(
            first.execute(
                select(NotificationOutbox.id)
                .where(NotificationOutbox.dedupe_key.like("claim-test-%"))
                .with_for_update(skip_locked=True)
                .limit(1)
            )
            .scalars()
            .all()
        )
        claimed = {
            row_id
            for row_id in claim(second, frozen_now, limit=10)
            if second.get(NotificationOutbox, row_id).dedupe_key.startswith("claim-test-")  # type: ignore[union-attr]
        }
        assert locked
        assert claimed
        assert locked.isdisjoint(claimed)
    finally:
        first.rollback()
        first.close()
        second.rollback()
        second.close()
        with SyncSession() as cleanup:
            cleanup.execute(delete(NotificationOutbox).where(NotificationOutbox.dedupe_key.like("claim-test-%")))
            cleanup.commit()


def test_a_device_following_team_competition_and_match_gets_exactly_one_message(sync_session, frozen_now):
    bag, device = _bag_with_follower(sync_session, frozen_now)
    support.follow(sync_session, device, competition=bag.competition.id)
    support.follow(sync_session, device, match=bag.match.id)
    support.follow(sync_session, device, team=bag.away.id)
    _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender()

    report = dispatch_due(sync_session, sender, frozen_now)

    assert report.sent == 1
    assert sender.tokens_sent == [device.push_token]


def test_1200_devices_are_three_calls_of_at_most_500(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now)
    sync_session.execute(
        text(
            "INSERT INTO devices (install_id, token_hash, platform, push_token, prefs) "
            "SELECT gen_random_uuid(), md5(g::text), 'android', 'push-' || g, '{}'::jsonb "
            "FROM generate_series(1, 1200) AS g"
        )
    )
    sync_session.execute(
        text(
            "INSERT INTO device_follows (device_id, team_id) "
            "SELECT id, :team FROM devices WHERE push_token LIKE 'push-%'"
        ),
        {"team": bag.home.id},
    )
    _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender()

    report = dispatch_due(sync_session, sender, frozen_now)

    assert [len(page) for page in sender.pages] == [500, 500, 200]
    assert report.sent == 1
    outbox = sync_session.execute(select(NotificationOutbox)).scalar_one()
    assert outbox.sent == 1200


def test_an_unregistered_token_is_cleared(sync_session, frozen_now):
    bag, device = _bag_with_follower(sync_session, frozen_now)
    _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender({str(device.push_token): "UNREGISTERED"})

    dispatch_due(sync_session, sender, frozen_now)

    sync_session.refresh(device)
    assert device.push_token is None


def test_a_failed_page_resumes_at_the_cursor_without_resending_page_one(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now)
    sync_session.execute(
        text(
            "INSERT INTO devices (install_id, token_hash, platform, push_token, prefs) "
            "SELECT gen_random_uuid(), md5(g::text), 'ios', 'push-' || g, '{}'::jsonb "
            "FROM generate_series(1, 600) AS g"
        )
    )
    sync_session.execute(
        text(
            "INSERT INTO device_follows (device_id, team_id) "
            "SELECT id, :team FROM devices WHERE push_token LIKE 'push-%'"
        ),
        {"team": bag.home.id},
    )
    _row(sync_session, bag.match, due_at=frozen_now)
    failing = FakePushSender(fail_page=2)

    report = dispatch_due(sync_session, failing, frozen_now)
    assert report.retry_row_id is not None
    first_page = {message.token for message in failing.pages[0]}

    resume = FakePushSender()
    dispatch_due(sync_session, resume, frozen_now)

    resent = {message.token for page in resume.pages for message in page}
    assert first_page.isdisjoint(resent)
    assert len(resent) == 100


def test_a_type_switched_off_is_not_sent(sync_session, frozen_now):
    bag, device = _bag_with_follower(sync_session, frozen_now)
    device.prefs = {"types": {"kickoff_reminder": {"on": False}}}
    sync_session.flush()
    _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender()

    dispatch_due(sync_session, sender, frozen_now)

    assert sender.pages == []
    outbox = sync_session.execute(select(NotificationOutbox)).scalar_one()
    assert outbox.status == "sent"


def test_a_row_stuck_in_sending_returns_to_pending(sync_session, frozen_now):
    bag, _ = _bag_with_follower(sync_session, frozen_now)
    outbox = _row(sync_session, bag.match, due_at=frozen_now, status="sending")
    outbox.claimed_at = frozen_now - timedelta(minutes=11)
    sync_session.flush()

    reclaim_stuck(sync_session, frozen_now)

    sync_session.refresh(outbox)
    assert outbox.status == "pending"


def test_a_match_cancelled_while_queued_sends_nothing(sync_session, frozen_now):
    bag, _ = _bag_with_follower(sync_session, frozen_now)
    _row(sync_session, bag.match, due_at=frozen_now)
    bag.match.status = "cancelled"
    bag.match.status_source = "feed"
    sync_session.flush()
    sender = FakePushSender()

    report = dispatch_due(sync_session, sender, frozen_now)

    assert report.cancelled == 1
    assert sender.pages == []
    outbox = sync_session.execute(select(NotificationOutbox)).scalar_one()
    assert outbox.status == "cancelled"


def test_sent_failed_and_sent_at_are_recorded(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now)
    ok = support.new_device(sync_session, token="ok-token", push_token="ok-push")
    broken = support.new_device(sync_session, token="bad-token", push_token="bad-push")
    support.follow(sync_session, ok, team=bag.home.id)
    support.follow(sync_session, broken, team=bag.home.id)
    _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender({"bad-push": "failed"})

    dispatch_due(sync_session, sender, frozen_now)

    outbox = sync_session.execute(select(NotificationOutbox)).scalar_one()
    assert (outbox.status, outbox.sent, outbox.failed) == ("sent", 1, 1)
    assert outbox.sent_at == frozen_now


# --- B1-R1-1: one empty push token must never block the queue -------------------------------------


def test_an_empty_push_token_is_not_in_the_audience_and_delays_nobody(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now)
    good = support.new_device(sync_session, token="good-token", push_token="good-push")
    empty = support.new_device(sync_session, token="empty-token", push_token="")
    support.follow(sync_session, good, team=bag.home.id)
    support.follow(sync_session, empty, team=bag.home.id)
    _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender()

    report = dispatch_due(sync_session, sender, frozen_now)

    assert sender.tokens_sent == ["good-push"]
    assert report.sent == 1
    outbox = sync_session.execute(select(NotificationOutbox)).scalar_one()
    assert outbox.status == "sent"


def test_a_failed_page_releases_every_claimed_row_it_did_not_process(sync_session, frozen_now):
    """A whole-call failure must not strand the rows behind it in ``sending`` for 10 minutes."""
    bags = [support.create_match_sync(sync_session, frozen_now) for _ in range(3)]
    for bag in bags:
        device = support.new_device(sync_session, token=f"tok-{bag.match.id}", push_token=f"push-{bag.match.id}")
        support.follow(sync_session, device, team=bag.home.id)
        _row(sync_session, bag.match, due_at=frozen_now)

    report = dispatch_due(sync_session, FakePushSender(fail_page=1), frozen_now)

    assert report.retry_row_id is not None
    statuses = list(sync_session.execute(select(NotificationOutbox.status)).scalars())
    assert statuses == ["pending", "pending", "pending"]


# --- B1-R1-4: a row whose retries are used up ends ``failed`` -------------------------------------


def test_a_row_that_always_fails_ends_failed_after_the_retry_limit(sync_session, frozen_now):
    bag, _ = _bag_with_follower(sync_session, frozen_now)
    outbox = _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender(fail_every_page=True)

    for _ in range(MAX_ATTEMPTS):
        report = dispatch_due(sync_session, sender, frozen_now)
        assert report.failed_row_id is None or report.failed_row_id == outbox.id

    sync_session.refresh(outbox)
    assert outbox.status == "failed"
    assert outbox.attempts == MAX_ATTEMPTS

    later = dispatch_due(sync_session, sender, frozen_now)
    assert later.claimed == []


def test_mark_failed_matches_a_row_that_was_released_to_pending(sync_session, frozen_now):
    bag, _ = _bag_with_follower(sync_session, frozen_now)
    outbox = _row(sync_session, bag.match, due_at=frozen_now)

    mark_failed(sync_session, outbox.id)

    sync_session.refresh(outbox)
    assert outbox.status == "failed"


# --- B1-R1-5: a late reminder is cancelled, never sent as "in one minute" --------------------------


def test_a_match_that_kicked_off_45_minutes_ago_is_cancelled(sync_session, frozen_now):
    bag, _ = _bag_with_follower(sync_session, frozen_now, kickoff_in=timedelta(minutes=-45))
    _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender()

    report = dispatch_due(sync_session, sender, frozen_now)

    assert report.cancelled == 1
    assert sender.pages == []
    outbox = sync_session.execute(select(NotificationOutbox)).scalar_one()
    assert outbox.status == "cancelled"


def test_a_live_or_finished_match_is_cancelled(sync_session, frozen_now):
    for status in ("live", "finished"):
        bag, _ = _bag_with_follower(sync_session, frozen_now, status=status, status_source="feed")
        _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender()

    report = dispatch_due(sync_session, sender, frozen_now)

    assert report.cancelled == 2
    assert sender.pages == []


# --- B1-R2-1: a transient per-message failure is retried, never recorded as ``sent`` --------------


def test_a_page_of_transient_failures_does_not_end_sent_and_the_next_dispatch_delivers_it(sync_session, frozen_now):
    """FCM is down at reminder time: nobody got it, so the row stays open and the next beat sends it."""
    bag, device = _bag_with_follower(sync_session, frozen_now)
    outbox = _row(sync_session, bag.match, due_at=frozen_now)
    outage = FakePushSender({str(device.push_token): "retryable"})

    report = dispatch_due(sync_session, outage, frozen_now)

    assert report.retry_row_id == outbox.id
    assert report.sent == 0
    sync_session.refresh(outbox)
    assert (outbox.status, outbox.sent, outbox.failed, outbox.attempts) == ("pending", 0, 0, 1)

    recovered = FakePushSender()
    report = dispatch_due(sync_session, recovered, frozen_now)

    assert report.sent == 1
    assert recovered.tokens_sent == [device.push_token]
    sync_session.refresh(outbox)
    assert (outbox.status, outbox.sent, outbox.failed) == ("sent", 1, 0)


def test_a_page_that_stays_unreachable_ends_failed_after_the_attempt_budget(sync_session, frozen_now):
    bag, device = _bag_with_follower(sync_session, frozen_now)
    outbox = _row(sync_session, bag.match, due_at=frozen_now)
    outage = FakePushSender({str(device.push_token): "retryable"})

    for _ in range(MAX_ATTEMPTS):
        dispatch_due(sync_session, outage, frozen_now)

    sync_session.refresh(outbox)
    assert (outbox.status, outbox.attempts, outbox.sent) == ("failed", MAX_ATTEMPTS, 0)
    assert dispatch_due(sync_session, outage, frozen_now).claimed == []


def test_a_transient_failure_on_page_two_resumes_there_and_never_resends_page_one(sync_session, frozen_now):
    bag = support.create_match_sync(sync_session, frozen_now)
    sync_session.execute(
        text(
            "INSERT INTO devices (install_id, token_hash, platform, push_token, prefs) "
            "SELECT gen_random_uuid(), md5(g::text), 'ios', 'push-' || g, '{}'::jsonb "
            "FROM generate_series(1, 600) AS g"
        )
    )
    sync_session.execute(
        text(
            "INSERT INTO device_follows (device_id, team_id) "
            "SELECT id, :team FROM devices WHERE push_token LIKE 'push-%'"
        ),
        {"team": bag.home.id},
    )
    outbox = _row(sync_session, bag.match, due_at=frozen_now)
    second_page = {f"push-{n}": "retryable" for n in range(501, 601)}
    outage = FakePushSender(second_page)

    report = dispatch_due(sync_session, outage, frozen_now)

    assert report.retry_row_id == outbox.id
    sync_session.refresh(outbox)
    assert (outbox.status, outbox.sent, outbox.failed) == ("pending", 500, 0)
    first_page = {message.token for message in outage.pages[0]}

    resume = FakePushSender()
    dispatch_due(sync_session, resume, frozen_now)

    resent = {message.token for page in resume.pages for message in page}
    assert first_page.isdisjoint(resent)
    assert resent == set(second_page)
    sync_session.refresh(outbox)
    assert (outbox.status, outbox.sent, outbox.failed) == ("sent", 600, 0)


def test_a_device_that_got_the_message_is_never_sent_it_again_when_another_stays_unreachable(sync_session, frozen_now):
    """A page that delivered to some cannot be retried whole; the unreachable remainder is counted failed."""
    bag = support.create_match_sync(sync_session, frozen_now)
    reached = support.new_device(sync_session, token="tok-reached", push_token="push-reached")
    cut_off = support.new_device(sync_session, token="tok-cut-off", push_token="push-cut-off")
    support.follow(sync_session, reached, team=bag.home.id)
    support.follow(sync_session, cut_off, team=bag.home.id)
    outbox = _row(sync_session, bag.match, due_at=frozen_now)
    sender = FakePushSender({"push-cut-off": "retryable"})

    report = dispatch_due(sync_session, sender, frozen_now)

    assert report.retry_row_id is None
    sync_session.refresh(outbox)
    assert (outbox.status, outbox.sent, outbox.failed) == ("sent", 1, 1)
    assert sorted(sender.tokens_sent) == ["push-cut-off", "push-reached"]
    assert dispatch_due(sync_session, sender, frozen_now).claimed == []


def test_a_live_type_is_claimed_before_an_older_announcement(sync_session, frozen_now):
    """R8: a big send must not hold a goal, so priority beats due time in the claim order."""
    session = sync_session
    session.execute(
        text(
            "INSERT INTO notification_outbox (type, dedupe_key, payload, audience, due_at, status) VALUES "
            "('announcement', 'announcement:old', '{}', '{}', :earlier, 'pending'), "
            "('goal', 'goal:1:0:home:1', '{}', '{}', :now, 'pending')"
        ),
        {"now": frozen_now, "earlier": frozen_now - timedelta(minutes=5)},
    )
    session.flush()

    claimed = claim(session, frozen_now, limit=1)

    row = session.get(NotificationOutbox, claimed[0])
    assert row is not None and row.type == "goal"
