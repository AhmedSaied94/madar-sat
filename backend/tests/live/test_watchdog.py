"""The watchdog keeps a feed row honest when the worker is gone (T027, research R6)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest

from app.db.models import LiveProblem, MatchLiveState
from app.domain.status import derive_status
from app.live.config import LiveSettings
from app.live.problems import open_problem
from app.live.watchdog import pause_feed_rows, run_watchdog
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


@pytest.mark.parametrize(
    "kickoff_ago",
    [timedelta(minutes=40), timedelta(minutes=SETTINGS.hard_limit_min + 1)],
    ids=["no_reading", "past_limit"],
)
def test_a_postponed_row_stays_as_stored_with_no_false_alert(sync_session, kickoff_ago):
    match = make_match(sync_session, NOW - kickoff_ago, status_source="feed", status="postponed", status_label="تأجيل")
    before = version(sync_session, "live")

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    sync_session.flush()

    assert (match.status_source, match.status, match.status_label) == ("feed", "postponed", "تأجيل")
    assert sync_session.get(LiveProblem, f"stale:{match.id}") is None
    assert version(sync_session, "live") == before
    assert (derive_status(match, NOW).status, derive_status(match, NOW).estimated) == ("postponed", False)


def test_a_pause_leaves_a_postponed_row_as_stored(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=40), status_source="feed", status="postponed")

    assert pause_feed_rows(sync_session, NOW) is False
    assert (match.status_source, match.status) == ("feed", "postponed")


def test_a_disagreement_that_never_settles_ends_on_the_clock_at_the_hard_limit(sync_session):
    """The sources stayed apart at full time: no final score is published, and no score shows at all."""
    match = make_match(sync_session, NOW - timedelta(minutes=SETTINGS.hard_limit_min + 1), **FEED)
    _with_reading(sync_session, match, NOW - timedelta(seconds=30))
    state = sync_session.get(MatchLiveState, match.id)
    state.candidate = {"home": 2, "away": 0, "source": "filgoal", "first_seen_at": NOW.isoformat(), "polls": 9}
    state.disagreement_since = NOW - timedelta(minutes=30)
    open_problem(sync_session, f"disagree:{match.id}", NOW - timedelta(minutes=30))
    sync_session.flush()

    alerts = run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.flush()

    assert (match.status_source, match.home_score) == ("clock", None)
    assert (derive_status(match, NOW).status, derive_status(match, NOW).estimated) == ("finished", True)
    assert sync_session.get(LiveProblem, f"stale:{match.id}").closed_at is None
    assert sync_session.get(LiveProblem, f"disagree:{match.id}").closed_at is None
    assert len(alerts) == 1
