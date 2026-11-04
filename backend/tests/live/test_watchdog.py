"""The watchdog keeps a feed row honest when the worker is gone (T027, research R6)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from app.db.models import LiveProblem, MatchLiveState
from app.live.config import LiveSettings
from app.live.problems import open_problem
from app.live.watchdog import run_watchdog
from tests.live.helpers import make_match, version

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
SETTINGS = LiveSettings()
FEED = {"status_source": "feed", "status": "live", "home_score": 1, "away_score": 0}


def _with_reading(session, match, read_at):
    session.add(
        MatchLiveState(
            match_id=match.id, last_reading_at=read_at, updated_at=read_at, confirmed_home=1, confirmed_away=0
        )
    )
    session.flush()


def test_a_row_with_no_recent_reading_moves_to_the_clock_and_opens_a_problem(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=40), **FEED)
    _with_reading(sync_session, match, NOW - timedelta(seconds=SETTINGS.stale_after_s + 1))
    before = version(sync_session, "live")

    alerts = run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.flush()

    assert (match.status_source, match.status, match.home_score) == ("clock", "scheduled", None)
    assert sync_session.get(LiveProblem, f"stale:{match.id}").closed_at is None
    assert len(alerts) == 1
    assert str(match.id) in alerts[0]
    assert version(sync_session, "live") == before + 1
    assert sync_session.get(MatchLiveState, match.id).confirmed_home == 1


def test_a_row_with_a_recent_reading_stays(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=40), **FEED)
    _with_reading(sync_session, match, NOW - timedelta(seconds=30))

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status_source == "feed"


def test_a_row_past_the_hard_limit_moves_even_with_a_recent_reading(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=SETTINGS.hard_limit_min + 1), **FEED)
    _with_reading(sync_session, match, NOW - timedelta(seconds=30))

    run_watchdog(sync_session, NOW, SETTINGS)

    assert match.status_source == "clock"


def test_a_row_that_never_had_a_reading_moves(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=40), **FEED)

    run_watchdog(sync_session, NOW, SETTINGS)

    assert match.status_source == "clock"


def test_manual_and_settled_rows_are_left_alone(sync_session):
    manual = make_match(
        sync_session, NOW - timedelta(minutes=300), status_source="manual", status="live", home_score=1, away_score=1
    )
    settled = make_match(
        sync_session, NOW - timedelta(minutes=300), status_source="feed", status="finished", home_score=2, away_score=1
    )

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert manual.status_source == "manual"
    assert settled.status == "finished"


def test_a_locked_row_stays_and_opens_nothing(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=300), locked_fields=["status"], **FEED)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status_source == "feed"
    assert sync_session.get(LiveProblem, f"stale:{match.id}") is None


def test_a_second_run_alerts_no_more(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=40), **FEED)
    assert len(run_watchdog(sync_session, NOW, SETTINGS)) == 1
    sync_session.flush()

    assert run_watchdog(sync_session, NOW + timedelta(minutes=2), SETTINGS) == []
    assert match.status_source == "clock"


def test_a_match_problem_closes_once_the_match_is_long_gone(sync_session):
    old = make_match(
        sync_session, NOW - timedelta(hours=6), status_source="feed", status="finished", home_score=1, away_score=0
    )
    recent = make_match(
        sync_session, NOW - timedelta(minutes=100), status_source="feed", status="finished", home_score=1, away_score=0
    )
    open_problem(sync_session, f"disagree:{old.id}", NOW - timedelta(hours=5))
    open_problem(sync_session, f"disagree:{recent.id}", NOW - timedelta(minutes=10))
    sync_session.flush()

    alerts = run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.expire_all()

    assert len(alerts) == 1
    assert sync_session.get(LiveProblem, f"disagree:{old.id}").closed_at == NOW
    assert sync_session.get(LiveProblem, f"disagree:{recent.id}").closed_at is None
