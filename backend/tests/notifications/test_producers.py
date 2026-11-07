"""The producers: match start, goals, corrections and the final score (T024, contracts/push-pipeline.md)."""

from __future__ import annotations

from datetime import timedelta
from types import SimpleNamespace

from sqlalchemy import select

from app.db.models import MatchLiveState, NotificationOutbox
from app.notifications.producers import record_poll
from tests import support


def _live_state(session, match_id: int, memory: dict | None = None) -> MatchLiveState:
    row = MatchLiveState(match_id=match_id, push_memory=memory or {})
    session.add(row)
    session.flush()
    return row


def _bag(session, now, *, status="live", status_source="feed", kickoff_in=timedelta(minutes=-5), home=1, away=0):
    bag = support.create_match_sync(session, now, status=status, status_source=status_source, kickoff_in=kickoff_in)
    if home is not None and away is not None:
        bag.match.home_score = home
        bag.match.away_score = away
        session.flush()
    return bag


def _reading(source: str, home: int | None, away: int | None):
    return SimpleNamespace(source=source, score=None if home is None else SimpleNamespace(home=home, away=away))


def _rows(session, row_type: str | None = None) -> list[NotificationOutbox]:
    query = select(NotificationOutbox).order_by(NotificationOutbox.id)
    if row_type is not None:
        query = query.where(NotificationOutbox.type == row_type)
    return list(session.scalars(query.execution_options(populate_existing=True)))


def test_a_live_feed_match_within_fifteen_minutes_announces_the_start_once(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    _live_state(sync_session, bag.match.id, {"home": 0, "away": 0, "generation": 0})

    record_poll(sync_session, bag.match, [_reading("filgoal", 0, 0)], frozen_now)
    record_poll(sync_session, bag.match, [_reading("filgoal", 0, 0)], frozen_now + timedelta(minutes=1))

    rows = _rows(sync_session, "match_started")
    assert len(rows) == 1
    assert rows[0].audience == {"kind": "match_core", "match_id": bag.match.id}
    state = sync_session.get(MatchLiveState, bag.match.id)
    assert state is not None and state.push_memory["live_seen"] is True


def test_a_match_already_in_play_on_its_first_evaluation_only_sets_the_flag(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    _live_state(sync_session, bag.match.id)

    record_poll(sync_session, bag.match, [_reading("filgoal", 1, 0)], frozen_now)

    assert _rows(sync_session, "match_started") == []
    assert _rows(sync_session, "goal") == []
    state = sync_session.get(MatchLiveState, bag.match.id, populate_existing=True)
    assert state is not None
    assert state.push_memory["home"] == 1
    assert state.push_memory["live_seen"] is True


def test_a_late_start_is_not_announced(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now, kickoff_in=timedelta(minutes=-20))
    _live_state(sync_session, bag.match.id, {"home": 0, "away": 0, "generation": 0})

    record_poll(sync_session, bag.match, [_reading("filgoal", 0, 0)], frozen_now)

    assert _rows(sync_session, "match_started") == []


def test_a_goal_passes_the_bar_and_writes_one_row(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now)
    _live_state(sync_session, bag.match.id, {"home": 0, "away": 0, "generation": 0, "live_seen": True})

    record_poll(
        sync_session,
        bag.match,
        [_reading("filgoal", 1, 0), _reading("yallakora", 1, 0)],
        frozen_now,
    )

    [row] = _rows(sync_session, "goal")
    assert row.dedupe_key == f"goal:{bag.match.id}:0:home:1"
    assert row.payload == {"match_id": bag.match.id, "side": "home", "home": 1, "away": 0, "generation": 0}


def test_a_manual_status_or_a_locked_score_moves_the_baseline_and_sends_no_goal(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now, status_source="manual", home=2, away=0)
    _live_state(sync_session, bag.match.id, {"home": 0, "away": 0, "generation": 0, "live_seen": True})

    record_poll(sync_session, bag.match, [_reading("filgoal", 2, 0), _reading("yallakora", 2, 0)], frozen_now)

    assert _rows(sync_session, "goal") == []
    state = sync_session.get(MatchLiveState, bag.match.id, populate_existing=True)
    assert state is not None and (state.push_memory["home"], state.push_memory["away"]) == (2, 0)


def test_the_feed_finish_writes_final_score_once(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now, status="finished", home=3, away=2)
    _live_state(sync_session, bag.match.id, {"home": 1, "away": 1, "generation": 0, "live_seen": True})

    record_poll(sync_session, bag.match, [_reading("filgoal", 3, 2)], frozen_now)
    record_poll(sync_session, bag.match, [_reading("filgoal", 3, 2)], frozen_now + timedelta(minutes=1))

    [row] = _rows(sync_session, "final_score")
    assert row.dedupe_key == f"final_score:{bag.match.id}"


def test_a_clock_estimate_never_finishes_or_announces(sync_session, frozen_now):
    bag = _bag(
        sync_session,
        frozen_now,
        status="scheduled",
        status_source="clock",
        kickoff_in=timedelta(minutes=-200),
        home=None,
        away=None,
    )

    record_poll(sync_session, bag.match, [], frozen_now)

    assert _rows(sync_session) == []


async def test_an_editor_lowering_a_score_nobody_heard_sends_no_correction(session, frozen_now):
    from app.notifications.producers import record_editor_status

    bag = await support.create_match(session, frozen_now, status="live", status_source="feed")
    bag.match.home_score = 1
    bag.match.away_score = 0
    await session.flush()
    state = MatchLiveState(match_id=bag.match.id, push_memory={"home": 2, "away": 0, "generation": 0})
    session.add(state)
    await session.flush()

    await record_editor_status(session, bag.match, frozen_now)

    assert list(await session.scalars(select(NotificationOutbox))) == []
    await session.refresh(state)
    assert (state.push_memory["home"], state.push_memory["away"]) == (1, 0)


async def test_an_editor_lowering_a_sent_score_corrects_it_and_bumps_the_generation(session, frozen_now):
    from app.notifications.producers import record_editor_status

    bag = await support.create_match(session, frozen_now, status="live", status_source="feed")
    bag.match.home_score = 1
    bag.match.away_score = 0
    await session.flush()
    state = MatchLiveState(match_id=bag.match.id, push_memory={"home": 2, "away": 0, "generation": 0})
    session.add(state)
    session.add(
        NotificationOutbox(
            type="goal",
            dedupe_key=f"goal:{bag.match.id}:0:home:2",
            payload={"match_id": bag.match.id, "side": "home", "home": 2, "away": 0, "generation": 0},
            audience={"kind": "match_core", "match_id": bag.match.id},
            due_at=frozen_now,
            status="sent",
            sent=10,
        )
    )
    await session.flush()

    await record_editor_status(session, bag.match, frozen_now)

    rows = list(await session.scalars(select(NotificationOutbox)))
    [correction] = [row for row in rows if row.type == "goal" and row.status == "pending"]
    assert correction.dedupe_key == f"goal_correction:{bag.match.id}:0"
    assert correction.payload["kind"] == "correction"
    await session.refresh(state)
    assert state.push_memory["generation"] == 1
    assert (state.push_memory["home"], state.push_memory["away"]) == (1, 0)


async def test_an_editor_finishing_a_match_adds_the_final_score(session, frozen_now):
    from app.notifications.producers import record_editor_status

    bag = await support.create_match(session, frozen_now, status="finished", status_source="manual")
    bag.match.home_score = 2
    bag.match.away_score = 1
    await session.flush()
    session.add(MatchLiveState(match_id=bag.match.id, push_memory={"home": 1, "away": 1, "generation": 0}))
    await session.flush()

    await record_editor_status(session, bag.match, frozen_now)

    rows = list(await session.scalars(select(NotificationOutbox)))
    assert [row.dedupe_key for row in rows] == [f"final_score:{bag.match.id}"]
