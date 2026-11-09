"""The producers: match start, goals, corrections and the final score (T024, contracts/push-pipeline.md)."""

from __future__ import annotations

from datetime import datetime, timedelta
from types import SimpleNamespace

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Match, MatchLiveState, NotificationOutbox
from app.live import cycle
from app.live.config import LiveSettings
from app.live.types import Score, SideInput
from app.notifications.producers import record_poll
from tests import support
from tests.live.helpers import make_reading


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

    record_poll(sync_session, bag.match, [_reading("filgoal", 3, 2)], frozen_now, status_before="live")
    record_poll(
        sync_session, bag.match, [_reading("filgoal", 3, 2)], frozen_now + timedelta(minutes=1), status_before="live"
    )

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


# --- Through the poller's own unit of work (``cycle._apply_match``), with nothing seeded -----------


@pytest.fixture
def factory(_prepare_database):
    """Sessions over one connection in a transaction: each poll commits to a savepoint, then all rolls back."""
    from app.db.session import sync_engine

    with sync_engine.connect() as conn:
        trans = conn.begin()
        try:
            yield lambda: Session(
                bind=conn, join_transaction_mode="create_savepoint", autoflush=False, expire_on_commit=False
            )
        finally:
            trans.rollback()


class Poller:
    """``cycle._apply_match`` with the two list sources agreeing, as one poll of the live cycle does."""

    def __init__(self, factory):
        self.factory = factory
        self.kicked: list[datetime] = []

    def deps(self):
        return SimpleNamespace(
            session_factory=self.factory,
            settings=LiveSettings(),
            alert=lambda text: True,
            kick_dispatch=lambda: self.kicked.append(self._now),
        )

    def poll(self, match_id: int, now, *, status="live", home=0, away=0, sources=("filgoal", "yallakora")):
        self._now = now
        score = None if home is None else Score(home, away)
        sides = {
            source: SideInput.valid(
                make_reading(
                    source,
                    score,
                    external_id=f"{source}-{match_id}",
                    status=status,
                    period="1H" if status == "live" else None,
                    minute="1" if status == "live" else None,
                    label=None,
                )
            )
            for source in sources
        }
        return cycle._apply_match(self.deps(), match_id, sides, False, now, None)

    def rows(self, row_type: str | None = None) -> list[NotificationOutbox]:
        with self.factory() as session:
            query = select(NotificationOutbox).order_by(NotificationOutbox.id)
            if row_type is not None:
                query = query.where(NotificationOutbox.type == row_type)
            return list(session.scalars(query))

    def match(self, match_id: int) -> Match:
        with self.factory() as session:
            return session.get(Match, match_id)

    def memory(self, match_id: int) -> dict:
        with self.factory() as session:
            state = session.get(MatchLiveState, match_id)
            return dict(state.push_memory or {}) if state is not None else {}


@pytest.fixture
def poller(factory):
    return Poller(factory)


def _scheduled_match(factory, now, *, kickoff_in=timedelta(minutes=10)) -> int:
    with factory() as session, session.begin():
        bag = support.create_match_sync(session, now, kickoff_in=kickoff_in)
        return bag.match.id


def test_a_normal_kickoff_announces_match_started_once(poller, factory, frozen_now):
    """B1-R1-1 (US1 scenario 6, FR-003): scheduled polls with no score, then the feed says live 0–0."""
    kickoff = frozen_now + timedelta(minutes=10)
    match_id = _scheduled_match(factory, frozen_now)

    poller.poll(match_id, frozen_now, status="scheduled", home=None)
    poller.poll(match_id, frozen_now + timedelta(minutes=5), status="scheduled", home=None)
    assert poller.rows() == []
    assert poller.match(match_id).status == "scheduled"

    poller.poll(match_id, kickoff + timedelta(minutes=1))
    poller.poll(match_id, kickoff + timedelta(minutes=2))

    match = poller.match(match_id)
    assert (match.status, match.status_source) == ("live", "feed")
    [started] = poller.rows("match_started")
    assert started.dedupe_key == f"match_started:{match_id}"
    assert started.audience == {"kind": "match_core", "match_id": match_id}
    assert poller.rows("goal") == []
    assert poller.memory(match_id)["live_seen"] is True


def test_a_match_first_seen_at_thirty_minutes_is_a_silent_baseline(poller, factory, frozen_now):
    """B1-R1-1: the producers' first look at a match already in play announces nothing."""
    match_id = _scheduled_match(factory, frozen_now, kickoff_in=timedelta(minutes=-30))

    poller.poll(match_id, frozen_now, home=1, away=0)
    poller.poll(match_id, frozen_now + timedelta(minutes=1), home=1, away=0)

    assert poller.match(match_id).status == "live"
    assert poller.rows() == []


# --- B1-R1-5: the cases T024 names, each written to fail when its rule flips ---------------------


def _goal_row(session, match_id: int, key: str, status: str, now) -> NotificationOutbox:
    row = NotificationOutbox(
        type="goal",
        dedupe_key=key,
        payload={"match_id": match_id, "side": "home", "home": 2, "away": 0, "generation": 0},
        audience={"kind": "match_core", "match_id": match_id},
        due_at=now,
        status=status,
    )
    session.add(row)
    session.flush()
    return row


def _poller_correction_case(sync_session, now, *, heard: str | None) -> tuple[int, list[NotificationOutbox]]:
    """2–0 was pushed in generation 0, and both sources now agree on 1–0."""
    bag = _bag(sync_session, now, home=1, away=0)
    _live_state(sync_session, bag.match.id, {"home": 2, "away": 0, "generation": 0, "live_seen": True})
    if heard is not None:
        _goal_row(sync_session, bag.match.id, f"goal:{bag.match.id}:0:home:2", heard, now)

    record_poll(sync_session, bag.match, [_reading("filgoal", 1, 0), _reading("yallakora", 1, 0)], now)

    corrections = [row for row in _rows(sync_session, "goal") if (row.payload or {}).get("kind") == "correction"]
    return bag.match.id, corrections


def test_the_poller_corrects_a_score_its_followers_heard(sync_session, frozen_now):
    match_id, corrections = _poller_correction_case(sync_session, frozen_now, heard="sent")

    [correction] = corrections
    assert correction.dedupe_key == f"goal_correction:{match_id}:0"
    assert (correction.payload["home"], correction.payload["away"]) == (1, 0)
    memory = sync_session.get(MatchLiveState, match_id, populate_existing=True).push_memory
    assert (memory["home"], memory["away"], memory["generation"]) == (1, 0, 1)


def test_the_poller_never_corrects_a_score_nobody_was_sent(sync_session, frozen_now):
    """The goal of this generation is still pending (or was never written): nobody heard 2–0 (R9)."""
    for heard in ("pending", None):
        match_id, corrections = _poller_correction_case(sync_session, frozen_now, heard=heard)
        assert corrections == [], heard
        memory = sync_session.get(MatchLiveState, match_id, populate_existing=True).push_memory
        assert (memory["home"], memory["away"], memory["generation"]) == (1, 0, 1), heard


def test_a_locked_score_moves_the_baseline_and_sends_no_goal(sync_session, frozen_now):
    bag = _bag(sync_session, frozen_now, home=2, away=0)
    bag.match.locked_fields = ["home_score"]
    sync_session.flush()
    _live_state(sync_session, bag.match.id, {"home": 0, "away": 0, "generation": 0, "live_seen": True})

    record_poll(sync_session, bag.match, [_reading("filgoal", 2, 0), _reading("yallakora", 2, 0)], frozen_now)

    assert _rows(sync_session, "goal") == []
    memory = sync_session.get(MatchLiveState, bag.match.id, populate_existing=True).push_memory
    assert (memory["home"], memory["away"]) == (2, 0)


def test_no_final_score_for_an_abandoned_postponed_or_cancelled_match(sync_session, frozen_now):
    for status in ("abandoned", "postponed", "cancelled"):
        bag = _bag(sync_session, frozen_now, status=status, home=1, away=1)
        _live_state(sync_session, bag.match.id, {"home": 1, "away": 1, "generation": 0, "live_seen": True})

        record_poll(sync_session, bag.match, [_reading("filgoal", 1, 1)], frozen_now, status_before="live")

    assert _rows(sync_session, "final_score") == []


def _live_one_nil(poller, factory, now) -> int:
    """A feed match polled from kickoff to 1–0 at 80′."""
    match_id = _scheduled_match(factory, now, kickoff_in=timedelta(minutes=-80))
    poller.poll(match_id, now, home=0, away=0)
    poller.poll(match_id, now + timedelta(minutes=1), home=1, away=0)
    assert poller.match(match_id).status == "live"
    return match_id


def _watchdog_finish(factory, match_id: int, now) -> None:
    from app.live.watchdog import _finish

    with factory() as session, session.begin():
        _finish(session, session.get(Match, match_id, with_for_update=True), now)


def test_a_watchdog_finish_gets_no_final_score_even_from_a_later_poll(poller, factory, frozen_now):
    """FR-007: the limit's finish is not news. A poll that reads the row after it doesn't make it news."""
    match_id = _live_one_nil(poller, factory, frozen_now)
    _watchdog_finish(factory, match_id, frozen_now + timedelta(minutes=2))
    assert poller.match(match_id).status == "finished"

    poller.poll(match_id, frozen_now + timedelta(minutes=3), home=1, away=0)

    assert poller.match(match_id).status == "finished"
    assert poller.rows("final_score") == []


def test_a_later_poll_of_a_finished_row_writes_no_second_final_score(poller, factory, frozen_now):
    match_id = _live_one_nil(poller, factory, frozen_now)
    poller.poll(match_id, frozen_now + timedelta(minutes=20), status="finished", home=1, away=0)
    [final] = poller.rows("final_score")

    # Even with the first row gone (the 30-day prune frees its key), a later poll of the row is no finish.
    with factory() as session, session.begin():
        session.delete(session.get(NotificationOutbox, final.id))
    poller.poll(match_id, frozen_now + timedelta(minutes=21), status="finished", home=1, away=0)

    assert poller.rows("final_score") == []


async def test_an_editor_finish_over_a_finish_at_the_limit_gives_one_final_score(session, frozen_now):
    """FR-007: the watchdog's finish sent nothing; the editor's finish with a real score sends one."""
    from app.live.watchdog import _finish
    from app.notifications.producers import record_editor_status

    bag = await support.create_match(session, frozen_now, status="live", status_source="feed")
    bag.match.home_score, bag.match.away_score = 2, 1
    session.add(MatchLiveState(match_id=bag.match.id, push_memory={"home": 2, "away": 1, "generation": 0}))
    await session.flush()
    await session.run_sync(lambda sync: _finish(sync, sync.get(Match, bag.match.id), frozen_now))
    assert list(await session.scalars(select(NotificationOutbox))) == []

    bag.match.status, bag.match.status_source = "finished", "manual"
    await session.flush()
    await record_editor_status(session, bag.match, frozen_now)
    await record_editor_status(session, bag.match, frozen_now + timedelta(minutes=1))

    rows = list(await session.scalars(select(NotificationOutbox)))
    assert [row.dedupe_key for row in rows] == [f"final_score:{bag.match.id}"]


def test_a_retried_or_overlapping_poll_writes_a_goal_once(poller, factory, frozen_now):
    """SC-003: the same poll again, and a poll that read the memory before the goal, add nothing."""
    match_id = _scheduled_match(factory, frozen_now, kickoff_in=timedelta(minutes=-30))
    poller.poll(match_id, frozen_now, home=0, away=0)  # the baseline
    before_goal = poller.memory(match_id)

    poller.poll(match_id, frozen_now + timedelta(minutes=1), home=1, away=0)
    poller.poll(match_id, frozen_now + timedelta(minutes=1), home=1, away=0)  # the task retried
    assert len(poller.rows("goal")) == 1

    # An overlapping poll that still holds the memory from before the goal reaches the same key.
    with factory() as session, session.begin():
        session.get(MatchLiveState, match_id).push_memory = before_goal
    poller.poll(match_id, frozen_now + timedelta(minutes=2), home=1, away=0)

    [goal] = poller.rows("goal")
    assert goal.dedupe_key == f"goal:{match_id}:0:home:1"


def test_kick_dispatch_runs_only_after_the_poll_committed(factory, frozen_now):
    """The dispatcher is queued once the row is committed, never from inside the poll's transaction."""
    sessions: list[Session] = []

    def tracking_factory() -> Session:
        session = factory()
        sessions.append(session)
        return session

    poller = Poller(tracking_factory)
    seen: list[tuple[bool, int]] = []

    def kick() -> None:
        open_transactions = any(session.in_transaction() for session in sessions)
        with factory() as check:
            seen.append((open_transactions, len(list(check.scalars(select(NotificationOutbox.id))))))

    match_id = _scheduled_match(factory, frozen_now, kickoff_in=timedelta(minutes=-30))
    poller.deps = lambda: SimpleNamespace(  # type: ignore[method-assign]
        session_factory=tracking_factory, settings=LiveSettings(), alert=lambda text: True, kick_dispatch=kick
    )
    poller.poll(match_id, frozen_now, home=0, away=0)
    assert seen == []  # a baseline writes no row, so nothing is queued

    poller.poll(match_id, frozen_now + timedelta(minutes=1), home=1, away=0)

    assert seen == [(False, 1)]
