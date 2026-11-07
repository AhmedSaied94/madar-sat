"""Every push type at dispatch: order, budget, audiences, off switches and lateness (T027)."""

from __future__ import annotations

from datetime import timedelta
from typing import Any
from uuid import uuid4

from sqlalchemy import text

from app.db.models import Device, NotificationOutbox
from app.notifications.dispatcher import PAGES_PER_TURN, dispatch_due
from tests import support
from tests.support import FakePushSender


def _row(
    session,
    now,
    *,
    row_type: str = "goal",
    match_id: int,
    payload: dict[str, Any] | None = None,
    audience: dict[str, Any] | None = None,
    due_at=None,
    status: str = "pending",
) -> NotificationOutbox:
    outbox = NotificationOutbox(
        type=row_type,
        dedupe_key=f"{row_type}:{match_id}:{uuid4().hex}",
        payload={"match_id": match_id, **(payload or {})},
        audience=audience or {"kind": "match_core", "match_id": match_id},
        due_at=due_at or now,
        status=status,
    )
    session.add(outbox)
    session.flush()
    return outbox


def _follower(session, bag, **follow) -> Device:
    device = support.new_device(session, token=f"tok-{bag.match.id}-{len(session.new)}", push_token=None)
    device.push_token = f"push-{bag.match.id}-{device.id}"
    support.follow(session, device, **follow)
    return device


def _bag(session, now, **kwargs):
    return support.create_match_sync(session, now, **kwargs)


# --- order and budget ---------------------------------------------------------------------------------


def test_a_goal_goes_before_an_older_announcement(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    device = _follower(sync_session, bag, match=bag.match.id)
    _row(
        sync_session,
        frozen_now,
        row_type="announcement",
        match_id=bag.match.id,
        payload={"title": "خبر", "body": "نص", "route": "/"},
        audience={"kind": "all"},
        due_at=frozen_now - timedelta(minutes=10),
    )
    _row(
        sync_session,
        frozen_now,
        row_type="goal",
        match_id=bag.match.id,
        payload={"side": "home", "home": 1, "away": 0, "generation": 0},
    )
    sender = FakePushSender()

    dispatch_due(sync_session, sender, frozen_now)

    assert [page[0].data["type"] for page in sender.pages] == ["goal", "announcement"]
    assert device.push_token in sender.tokens_sent


def test_a_row_sends_twenty_pages_then_returns_to_pending_with_its_cursor(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    sync_session.execute(
        text(
            "INSERT INTO devices (install_id, token_hash, platform, push_token, prefs) "
            "SELECT gen_random_uuid(), md5(g::text), 'android', 'push-' || g, '{}'::jsonb "
            "FROM generate_series(1, 10000) AS g"
        )
    )
    sync_session.execute(
        text("INSERT INTO device_follows (device_id, team_id) SELECT id, :team FROM devices"), {"team": bag.home.id}
    )
    row = _row(
        sync_session,
        frozen_now,
        row_type="announcement",
        match_id=bag.match.id,
        payload={"title": "خبر", "body": "نص", "route": "/"},
        audience={"kind": "all"},
    )
    sender = FakePushSender()

    first = dispatch_due(sync_session, sender, frozen_now)

    assert first.deferred == 1
    assert first.requeued is True
    assert len(sender.pages) == PAGES_PER_TURN
    sync_session.refresh(row)
    assert row.status == "pending"
    last_id = sync_session.scalar(text("SELECT max(id) FROM devices WHERE push_token LIKE 'push-%'"))
    assert row.cursor_device_id == last_id

    second = dispatch_due(sync_session, sender, frozen_now)

    assert second.sent == 1
    assert len(sender.pages) == PAGES_PER_TURN
    assert len({message.token for page in sender.pages for message in page}) == 10000


def test_the_run_stops_at_its_time_limit_and_queues_itself(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    _follower(sync_session, bag, match=bag.match.id)
    for index in range(3):
        _row(
            sync_session,
            frozen_now,
            row_type="announcement",
            match_id=bag.match.id,
            payload={"title": f"خبر {index}", "body": "نص", "route": "/"},
            audience={"kind": "all"},
        )
    ticks = iter([0.0, 0.0, 0.0, 60.0, 60.0])

    report = dispatch_due(sync_session, FakePushSender(), frozen_now, monotonic=lambda: next(ticks))

    assert report.requeued is True
    assert len(report.claimed) < 3


# --- audiences ------------------------------------------------------------------------------------------


def _followers(session, bag) -> dict[str, Device]:
    by_match = support.new_device(session, token="m", push_token="push-m")
    support.follow(session, by_match, match=bag.match.id)
    by_team = support.new_device(session, token="t", push_token="push-t")
    support.follow(session, by_team, team=bag.home.id)
    by_competition = support.new_device(session, token="c", push_token="push-c")
    support.follow(session, by_competition, competition=bag.competition.id)
    from app.db.models import DeviceFollow

    by_channel = support.new_device(session, token="ch", push_token="push-bag")
    session.add(DeviceFollow(device_id=by_channel.id, channel_id=bag.channels[0].id))
    session.flush()
    unrelated = support.new_device(session, token="u", push_token="push-u")  # follows nothing
    return {
        "match": by_match,
        "team": by_team,
        "competition": by_competition,
        "channel": by_channel,
        "unrelated": unrelated,
    }


def test_each_audience_kind_reaches_its_own_followers(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    followers = _followers(sync_session, bag)

    cases = {
        "match_core": ({"kind": "match_core", "match_id": bag.match.id}, {"match", "team"}),
        "match_only": ({"kind": "match_only", "match_id": bag.match.id}, {"match"}),
        "channel": ({"kind": "channel", "channel_id": bag.channels[0].id}, {"channel"}),
        "team": ({"kind": "team", "team_id": bag.home.id}, {"match", "team"}),
        "competition": ({"kind": "competition", "competition_id": bag.competition.id}, {"match", "competition"}),
    }
    for kind, (audience, _owners) in cases.items():
        _row(
            sync_session,
            frozen_now,
            row_type="announcement",
            match_id=bag.match.id,
            payload={"title": kind, "body": "نص", "route": "/"},
            audience=audience,
        )

    sender = FakePushSender()
    dispatch_due(sync_session, sender, frozen_now)

    sent = set(sender.tokens_sent)
    for kind, (_audience, owners) in cases.items():
        assert {followers[owner].push_token for owner in owners} <= sent, kind
    assert followers["unrelated"].push_token not in sent


def test_an_all_audience_needs_no_follow_and_honours_the_switches(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    on = support.new_device(sync_session, token="on", push_token="push-on")
    master_off = support.new_device(sync_session, token="off", push_token="push-off", prefs={"enabled": False})
    type_off = support.new_device(
        sync_session, token="type-off", push_token="push-type-off", prefs={"types": {"announcement": {"on": False}}}
    )
    _row(
        sync_session,
        frozen_now,
        row_type="announcement",
        match_id=bag.match.id,
        payload={"title": "خبر", "body": "نص", "route": "/"},
        audience={"kind": "all"},
    )
    sender = FakePushSender()

    dispatch_due(sync_session, sender, frozen_now)

    assert sender.tokens_sent == [on.push_token]
    assert master_off.push_token not in sender.tokens_sent
    assert type_off.push_token not in sender.tokens_sent


def test_match_started_is_off_by_default_and_a_correction_reads_the_goal_switch(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    default = support.new_device(sync_session, token="d", push_token="push-default")
    support.follow(sync_session, default, match=bag.match.id)
    goal_off = support.new_device(
        sync_session, token="g", push_token="push-goal-off", prefs={"types": {"goal": {"on": False}}}
    )
    support.follow(sync_session, goal_off, match=bag.match.id)

    _row(sync_session, frozen_now, row_type="match_started", match_id=bag.match.id)
    _row(
        sync_session,
        frozen_now,
        row_type="goal",
        match_id=bag.match.id,
        payload={"kind": "correction", "home": 1, "away": 0, "generation": 0},
        audience={"kind": "match_core", "match_id": bag.match.id},
    )
    sender = FakePushSender()

    dispatch_due(sync_session, sender, frozen_now)

    assert sender.tokens_sent == [default.push_token]


def test_a_test_send_ignores_prefs(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    device = support.new_device(sync_session, token="d", push_token="push-device", prefs={"enabled": False})
    _row(
        sync_session,
        frozen_now,
        row_type="announcement",
        match_id=bag.match.id,
        payload={"title": "تجربة", "body": "نص", "route": "/"},
        audience={"kind": "device", "device_id": device.id},
    )

    dispatch_due(sync_session, FakePushSender(), frozen_now)

    [row] = list(sync_session.scalars(__import__("sqlalchemy").select(NotificationOutbox)))
    assert row.status == "sent"
    assert row.sent == 1


# --- the switches and lateness ---------------------------------------------------------------------------


def test_push_types_off_cancels_with_its_reason(sync_session, frozen_now, monkeypatch):
    bag = _bag(sync_session, frozen_now)
    _follower(sync_session, bag, match=bag.match.id)
    _row(
        sync_session,
        frozen_now,
        row_type="goal",
        match_id=bag.match.id,
        payload={"side": "home", "home": 1, "away": 0, "generation": 0},
    )
    from app.settings import get_settings

    monkeypatch.setattr(get_settings(), "push_types_off", "goal", raising=False)
    sender = FakePushSender()

    report = dispatch_due(sync_session, sender, frozen_now)

    assert report.cancelled == 1
    assert sender.pages == []
    [row] = list(sync_session.scalars(__import__("sqlalchemy").select(NotificationOutbox)))
    assert row.error == "type_off"


def test_lateness_and_the_finished_match(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    early = timedelta(minutes=16)
    _row(
        sync_session,
        frozen_now,
        row_type="goal",
        match_id=bag.match.id,
        payload={"side": "home", "home": 1, "away": 0, "generation": 0},
        due_at=frozen_now - early,
    )
    _row(sync_session, frozen_now, row_type="match_started", match_id=bag.match.id, due_at=frozen_now - early)

    dispatch_due(sync_session, FakePushSender(), frozen_now)

    rows = list(sync_session.scalars(__import__("sqlalchemy").select(NotificationOutbox)))
    assert [(row.status, row.error) for row in rows] == [("cancelled", "late"), ("cancelled", "late")]


def test_a_goal_whose_side_fell_below_the_row_says_score_fell(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    bag.match.status_source = "feed"
    bag.match.home_score = 0
    bag.match.away_score = 0
    sync_session.flush()
    _row(
        sync_session,
        frozen_now,
        row_type="goal",
        match_id=bag.match.id,
        payload={"side": "home", "home": 1, "away": 0, "generation": 0},
    )

    dispatch_due(sync_session, FakePushSender(), frozen_now)

    [row] = list(sync_session.scalars(__import__("sqlalchemy").select(NotificationOutbox)))
    assert row.error == "score_fell"


def test_channels_updated_after_the_match_finished_is_cancelled(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now, status="finished", status_source="feed", kickoff_in=timedelta(minutes=-120))
    _row(
        sync_session,
        frozen_now,
        row_type="channels_updated",
        match_id=bag.match.id,
        payload={"added": [bag.channels[0].id], "removed": []},
        audience={"kind": "match_followers", "match_id": bag.match.id},
    )

    dispatch_due(sync_session, FakePushSender(), frozen_now)

    [row] = list(sync_session.scalars(__import__("sqlalchemy").select(NotificationOutbox)))
    assert row.error == "match_finished"
