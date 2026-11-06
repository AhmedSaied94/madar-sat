"""The watchdog keeps a feed row honest when the worker is gone (T027, research R6)."""

from __future__ import annotations

from dataclasses import replace
from datetime import UTC, datetime, timedelta

import pytest

from app.db.models import LiveProblem, LiveSourceState, MatchLiveState, MatchSourceReading
from app.domain.status import derive_status
from app.live.apply import apply_decision, load_state
from app.live.config import LiveSettings
from app.live.crosscheck import decide
from app.live.problems import open_problem
from app.live.types import Score, SideInput
from app.live.watchdog import pause_feed_rows as pause_with_limit
from app.live.watchdog import run_watchdog
from tests.live.helpers import make_match, make_reading, version

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
SETTINGS = LiveSettings()
FEED = {"status_source": "feed", "status": "live", "home_score": 1, "away_score": 0}
SECOND_HALF = {**FEED, "period": "2H", "minute": "72"}
STUCK = NOW - SETTINGS.stuck_after - timedelta(minutes=1)
HARD = NOW - SETTINGS.hard_limit - timedelta(minutes=1)
FRESH = NOW - timedelta(seconds=30)


def pause_feed_rows(session, now):
    return pause_with_limit(session, now, stuck_after=SETTINGS.stuck_after)


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
    match = make_match(sync_session, HARD, **FEED)
    _with_reading(sync_session, match, FRESH)

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


def test_a_disagreement_that_never_reached_the_second_half_ends_on_the_clock_at_the_hard_limit(sync_session):
    match = make_match(sync_session, HARD, **FEED)
    _with_reading(sync_session, match, FRESH)
    sync_session.get(MatchLiveState, match.id).disagreement_since = NOW - timedelta(minutes=30)
    open_problem(sync_session, f"disagree:{match.id}", NOW - timedelta(minutes=30))
    sync_session.flush()

    alerts = run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.flush()

    assert (match.status_source, match.home_score) == ("clock", None)
    assert (derive_status(match, NOW).status, derive_status(match, NOW).estimated) == ("finished", True)
    assert sync_session.get(LiveProblem, f"stale:{match.id}").closed_at is None
    assert sync_session.get(LiveProblem, f"disagree:{match.id}").closed_at is None
    assert len(alerts) == 1


# -------------------------------------------------------------------------- stuck at + 150 (FR-009)


def _source(session, name="filgoal", state="ok"):
    if session.get(LiveSourceState, name) is None:
        session.add(LiveSourceState(source=name, state=state, consecutive_failures=0))
        session.flush()


def _peak(session, match, source="filgoal", *, peak=104, period="2H", read_at=FRESH, state="ok", minute="72"):
    _source(session, source, state)
    session.add(
        MatchSourceReading(
            match_id=match.id,
            source=source,
            status="live",
            period="2H",
            minute=minute,
            home_score=match.home_score,
            away_score=match.away_score,
            peak_minute=peak,
            peak_period=period if peak is not None else None,
            read_at=read_at,
            changed_at=read_at,
        )
    )
    session.flush()


def _stuck_match(session, kickoff=STUCK, **values):
    match = make_match(session, kickoff, **{**SECOND_HALF, **values})
    _with_reading(session, match, FRESH)
    return match


def _quiet(session, match, ago=timedelta(minutes=16)):
    session.get(MatchLiveState, match.id).score_changed_at = NOW - ago
    session.flush()


def test_bristol_city_v_wolves_finishes_on_its_score_at_the_stuck_limit(sync_session):
    """The capture's stuck match: peak 104, FilGoal's clock wrapped back to 72, final score 1–2."""
    match = _stuck_match(sync_session, home_score=1, away_score=2)
    _quiet(sync_session, match)
    _peak(sync_session, match, peak=104, minute="72")
    before = version(sync_session, "live")

    alerts = run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.flush()

    assert (match.status_source, match.status, match.period, match.minute) == ("feed", "finished", None, None)
    assert (match.home_score, match.away_score) == (1, 2)
    assert match.status_updated_at == NOW
    assert match.status_label == "انتهت"
    assert sync_session.get(LiveProblem, f"stuck:{match.id}").closed_at is None
    assert sync_session.get(LiveProblem, f"stale:{match.id}") is None
    assert len(alerts) == 1
    assert str(match.id) in alerts[0]
    assert version(sync_session, "live") == before + 1


def test_a_stuck_match_alerts_once(sync_session):
    match = _stuck_match(sync_session)
    _quiet(sync_session, match)
    _peak(sync_session, match)
    assert len(run_watchdog(sync_session, NOW, SETTINGS)) == 1
    sync_session.flush()

    assert run_watchdog(sync_session, NOW + timedelta(minutes=2), SETTINGS) == []


def test_a_match_with_no_score_change_on_record_counts_as_quiet(sync_session):
    match = _stuck_match(sync_session)
    _peak(sync_session, match)

    run_watchdog(sync_session, NOW, SETTINGS)

    assert match.status == "finished"


def test_a_goal_inside_the_quiet_time_keeps_it_open(sync_session):
    match = _stuck_match(sync_session)
    _quiet(sync_session, match, ago=timedelta(minutes=14))
    _peak(sync_session, match)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert (match.status, match.period) == ("live", "2H")


def test_a_usable_source_below_ninety_keeps_it_open_as_after_a_late_kickoff(sync_session):
    match = _stuck_match(sync_session)
    _quiet(sync_session, match)
    _peak(sync_session, match, peak=104)
    _peak(sync_session, match, "goal", peak=70)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status == "live"


@pytest.mark.parametrize(
    "other",
    [
        {"peak": None},
        {"peak": 70, "state": "down"},
        {"peak": 70, "state": "invalid"},
        {"peak": 70, "read_at": NOW - timedelta(seconds=SETTINGS.stale_after_s + 1)},
    ],
    ids=["no_peak", "down", "invalid", "not_read_lately"],
)
def test_a_source_that_is_not_usable_or_has_no_peak_has_no_say(sync_session, other):
    match = _stuck_match(sync_session)
    _quiet(sync_session, match)
    _peak(sync_session, match, peak=104)
    _peak(sync_session, match, "goal", **other)

    run_watchdog(sync_session, NOW, SETTINGS)

    assert match.status == "finished"


def test_a_failing_source_still_has_a_say(sync_session):
    match = _stuck_match(sync_session)
    _quiet(sync_session, match)
    _peak(sync_session, match, peak=70, state="failing")

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status == "live"


def test_nothing_finishes_before_the_stuck_limit(sync_session):
    match = _stuck_match(sync_session, kickoff=NOW - SETTINGS.stuck_after + timedelta(minutes=1))
    _quiet(sync_session, match)
    _peak(sync_session, match)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status == "live"


@pytest.mark.parametrize(
    "values",
    [
        {"period": "1H"},
        {"status": "halftime", "period": None},
        {"status": "extra_time", "period": "ET1"},
        {"status": "penalties", "period": None},
    ],
    ids=["first_half", "halftime", "extra_time", "penalties"],
)
def test_the_stuck_limit_only_touches_the_second_half(sync_session, values):
    match = _stuck_match(sync_session, **values)
    _quiet(sync_session, match)
    _peak(sync_session, match)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status == values.get("status", "live")


@pytest.mark.parametrize(
    "fields", [{"locked_fields": ["status"]}, {"status_source": "manual"}], ids=["locked", "manual"]
)
def test_a_person_wins_over_the_stuck_limit(sync_session, fields):
    match = _stuck_match(sync_session, **fields)
    _quiet(sync_session, match)
    _peak(sync_session, match)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status == "live"


# ------------------------------------------------------- extra time or a shoot-out no parser knows yet


def _unmapped(source="filgoal", score=Score(1, 1)):
    """A row whose status nobody has seen, as a shoot-out's would be until T035 maps it."""
    return replace(
        make_reading(source, score, status=None, period=None, minute=None, label=None),
        unknown_status="ركلات الترجيح",
    )


def _page_says_only_live(source="yallakora", score=Score(1, 1)):
    """YallaKora's match page says «مباشر», and `_with_list_stage` can't fill it from an unknown list row."""
    return make_reading(source, score, status="live", period=None, minute=None, label="مباشر")


PLAYING_ON = {"unknown_status": _unmapped, "live_with_no_period": _page_says_only_live}


def _poll(session, match, reading, at):
    decision = decide(
        load_state(session, match),
        {reading.source: SideInput.valid(reading)},
        at,
        drop_hold=SETTINGS.drop_hold,
        disagree_after=SETTINGS.disagree_after,
        fulltime_hold=SETTINGS.fulltime_hold,
    )
    apply_decision(
        session,
        match,
        decision,
        readings=[reading],
        now=at,
        drop_hold=SETTINGS.drop_hold,
        stuck_after=SETTINGS.stuck_after,
    )
    session.flush()
    return decision


@pytest.mark.parametrize("reading", PLAYING_ON.values(), ids=PLAYING_ON.keys())
def test_a_quiet_cup_match_on_a_status_no_parser_knows_waits_for_the_hard_limit(sync_session, reading):
    kickoff = NOW - timedelta(minutes=151)
    match = make_match(sync_session, kickoff)
    source = reading().source
    _source(sync_session, source)
    second_half = make_reading(source, Score(1, 1), period="2H", minute="90+6")
    _poll(sync_session, match, second_half, kickoff + timedelta(minutes=110))
    assert (match.status, match.period, match.home_score) == ("live", "2H", 1)

    _poll(sync_session, match, reading(), NOW - timedelta(seconds=30))

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    sync_session.flush()
    assert (match.status, match.period, match.home_score) == ("live", "2H", 1)
    assert sync_session.get(LiveProblem, f"stuck:{match.id}") is None

    late = kickoff + SETTINGS.hard_limit + timedelta(minutes=1)
    _poll(sync_session, match, reading(), late - timedelta(seconds=30))

    assert len(run_watchdog(sync_session, late, SETTINGS)) == 1
    sync_session.flush()
    assert (match.status, match.home_score, match.away_score) == ("finished", 1, 1)
    assert sync_session.get(LiveProblem, f"stuck:{match.id}").closed_at is None


@pytest.mark.parametrize("reading", PLAYING_ON.values(), ids=PLAYING_ON.keys())
def test_an_unknown_stage_over_two_polls_six_minutes_apart_opens_no_move_back(sync_session, reading):
    match = make_match(sync_session, NOW - timedelta(minutes=120))
    source = reading().source
    _poll(sync_session, match, make_reading(source, Score(1, 1), period="2H", minute="88"), NOW - timedelta(minutes=8))

    first = _poll(sync_session, match, reading(), NOW - timedelta(minutes=6))
    second = _poll(sync_session, match, reading(), NOW)

    assert (first.status_drop_since, second.status_drop_since) == (None, None)
    assert sync_session.get(MatchLiveState, match.id).status_drop_since is None
    assert (match.status, match.period) == ("live", "2H")


def _source_read(session, match, source="filgoal", *, status, period, read_at=FRESH, state="ok"):
    _source(session, source, state)
    session.add(
        MatchSourceReading(
            match_id=match.id, source=source, status=status, period=period, read_at=read_at, changed_at=read_at
        )
    )
    session.flush()


@pytest.mark.parametrize("status", [None, "live"], ids=["unknown_status", "live_with_no_period"])
def test_a_fresh_reading_with_no_stage_from_any_usable_source_keeps_the_row_open(sync_session, status):
    match = _stuck_match(sync_session)
    _quiet(sync_session, match)
    _peak(sync_session, match, peak=104)
    _source_read(sync_session, match, "goal", status=status, period=None, state="failing")

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status == "live"


OLD = NOW - timedelta(seconds=SETTINGS.stale_after_s + 1)
NO_SAY = {
    "unknown_but_not_read_lately": {"status": None, "period": None, "read_at": OLD},
    "unknown_on_a_down_source": {"status": None, "period": None, "state": "down"},
    "unknown_on_an_invalid_source": {"status": None, "period": None, "state": "invalid"},
    "live_with_no_period_not_read_lately": {"status": "live", "period": None, "read_at": OLD},
    "second_half": {"status": "live", "period": "2H"},
    "full_time": {"status": "finished", "period": None},
    "halftime": {"status": "halftime", "period": None},
    "scheduled": {"status": "scheduled", "period": None},
}


@pytest.mark.parametrize("values", NO_SAY.values(), ids=NO_SAY.keys())
def test_only_a_fresh_stageless_reading_from_a_usable_source_stops_the_finish(sync_session, values):
    match = _stuck_match(sync_session)
    _quiet(sync_session, match)
    _source_read(sync_session, match, **values)

    assert len(run_watchdog(sync_session, NOW, SETTINGS)) == 1
    assert match.status == "finished"


# ------------------------------------------------------------------------------- the limit at + 210


@pytest.mark.parametrize(
    ("status", "period"),
    [("live", "2H"), ("extra_time", "ET2"), ("extra_time", None), ("penalties", None)],
)
def test_at_the_hard_limit_a_row_that_reached_the_second_half_finishes_on_its_score(sync_session, status, period):
    match = make_match(
        sync_session, HARD, status_source="feed", status=status, period=period, home_score=2, away_score=2
    )
    _with_reading(sync_session, match, FRESH)
    # Everything that would hold it open at + 150: a recent goal and a source below 90.
    _quiet(sync_session, match, ago=timedelta(minutes=1))
    _peak(sync_session, match, peak=70)

    alerts = run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.flush()

    assert (match.status_source, match.status, match.home_score, match.away_score) == ("feed", "finished", 2, 2)
    assert sync_session.get(LiveProblem, f"stuck:{match.id}").closed_at is None
    assert sync_session.get(LiveProblem, f"stale:{match.id}") is None
    assert len(alerts) == 1


@pytest.mark.parametrize(
    ("status", "period"), [("live", "1H"), ("halftime", None), ("live", None)], ids=["first", "halftime", "no_period"]
)
def test_at_the_hard_limit_a_row_that_never_reached_the_second_half_goes_to_the_clock(sync_session, status, period):
    match = make_match(
        sync_session, HARD, status_source="feed", status=status, period=period, home_score=1, away_score=0
    )
    _with_reading(sync_session, match, FRESH)

    run_watchdog(sync_session, NOW, SETTINGS)

    assert (match.status_source, match.status, match.home_score) == ("clock", "scheduled", None)
    assert sync_session.get(LiveProblem, f"stale:{match.id}") is not None
    assert sync_session.get(LiveProblem, f"stuck:{match.id}") is None


# --------------------------------------------------------------------- the clock and the stuck limit


def test_a_stale_row_before_the_stuck_limit_still_goes_to_the_clock(sync_session):
    match = make_match(sync_session, NOW - SETTINGS.stuck_after + timedelta(minutes=1), **SECOND_HALF)
    _with_reading(sync_session, match, NOW - timedelta(seconds=SETTINGS.stale_after_s + 1))

    assert len(run_watchdog(sync_session, NOW, SETTINGS)) == 1
    assert (match.status_source, match.status, match.home_score) == ("clock", "scheduled", None)


@pytest.mark.parametrize(
    "values",
    [{}, {"status": "extra_time", "period": "ET1"}, {"status": "penalties", "period": None}],
    ids=["second_half", "extra_time", "penalties"],
)
def test_a_stale_row_past_the_stuck_limit_keeps_its_status_and_score_with_no_stale_alert(sync_session, values):
    match = make_match(sync_session, STUCK, **{**SECOND_HALF, **values})
    _with_reading(sync_session, match, NOW - timedelta(seconds=SETTINGS.stale_after_s + 1))
    # A source below 90 keeps the stuck step off it, so only ``to_clock`` is being tested.
    _peak(sync_session, match, peak=70)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    sync_session.flush()

    assert (match.status_source, match.status, match.home_score) == ("feed", values.get("status", "live"), 1)
    assert sync_session.get(LiveProblem, f"stale:{match.id}") is None


def test_a_dead_worker_past_the_stuck_limit_ends_in_finished_not_on_the_clock(sync_session):
    match = make_match(sync_session, STUCK, **SECOND_HALF)
    _with_reading(sync_session, match, NOW - timedelta(minutes=30))
    # The readings are old, so no source is usable, and nothing can hold the match open.
    _peak(sync_session, match, peak=70, read_at=NOW - timedelta(minutes=30))

    alerts = run_watchdog(sync_session, NOW, SETTINGS)

    assert (match.status_source, match.status, match.home_score) == ("feed", "finished", 1)
    assert len(alerts) == 1


def test_a_stale_row_past_the_stuck_limit_that_never_reached_the_second_half_goes_to_the_clock(sync_session):
    match = make_match(sync_session, STUCK, **{**FEED, "period": "1H"})
    _with_reading(sync_session, match, NOW - timedelta(seconds=SETTINGS.stale_after_s + 1))

    run_watchdog(sync_session, NOW, SETTINGS)

    assert match.status_source == "clock"


def test_a_pause_past_the_stuck_limit_leaves_a_second_half_row(sync_session):
    match = make_match(sync_session, STUCK, **SECOND_HALF)
    before = version(sync_session, "live")

    assert pause_feed_rows(sync_session, NOW) is False
    sync_session.flush()

    assert (match.status_source, match.status, match.home_score) == ("feed", "live", 1)
    assert version(sync_session, "live") == before


def test_a_pause_before_the_stuck_limit_still_moves_the_row(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=70), **SECOND_HALF)

    assert pause_feed_rows(sync_session, NOW) is True
    assert match.status_source == "clock"


def test_a_stuck_problem_closes_once_the_match_is_long_gone(sync_session):
    match = make_match(
        sync_session, NOW - timedelta(hours=6), status_source="feed", status="finished", home_score=1, away_score=0
    )
    open_problem(sync_session, f"stuck:{match.id}", NOW - timedelta(hours=3))
    sync_session.flush()

    alerts = run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.expire_all()

    assert len(alerts) == 1
    assert sync_session.get(LiveProblem, f"stuck:{match.id}").closed_at == NOW


# ------------------------------------------------------------- a source said full time, then went quiet


def _called_over(session, match, *, read_at=None, since=SETTINGS.fulltime_hold + timedelta(minutes=1)):
    _with_reading(session, match, read_at or NOW - timedelta(seconds=SETTINGS.stale_after_s + 1))
    state = session.get(MatchLiveState, match.id)
    state.fulltime_source, state.fulltime_since = "yallakora", NOW - since
    session.flush()


def test_a_match_a_source_called_over_finishes_on_its_score_when_readings_stop(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=125), **SECOND_HALF)
    _called_over(sync_session, match)
    before = version(sync_session, "live")

    alerts = run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.flush()

    assert (match.status_source, match.status, match.home_score, match.away_score) == ("feed", "finished", 1, 0)
    assert (match.period, match.minute, match.status_updated_at) == (None, None, NOW)
    assert sync_session.get(LiveProblem, f"fulltime:{match.id}").closed_at is None
    assert sync_session.get(LiveProblem, f"stale:{match.id}") is None
    assert len(alerts) == 1
    assert str(match.id) in alerts[0]
    assert version(sync_session, "live") == before + 1


def test_a_match_a_source_called_over_keeps_waiting_out_the_hold_when_readings_stop(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=125), **SECOND_HALF)
    since = SETTINGS.fulltime_hold - timedelta(minutes=3)
    _called_over(sync_session, match, since=since)
    before = version(sync_session, "live")

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    sync_session.flush()

    # A level cup match may be going to extra time, so a quiet source can't end it any sooner than a talking one.
    assert (match.status_source, match.status, match.period, match.home_score) == ("feed", "live", "2H", 1)
    assert sync_session.get(LiveProblem, f"stale:{match.id}") is None
    assert version(sync_session, "live") == before

    later = NOW + timedelta(minutes=3)
    assert len(run_watchdog(sync_session, later, SETTINGS)) == 1
    assert (match.status, match.home_score, match.away_score) == ("finished", 1, 0)


def test_a_match_a_source_called_over_alerts_once(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=125), **SECOND_HALF)
    _called_over(sync_session, match)
    assert len(run_watchdog(sync_session, NOW, SETTINGS)) == 1
    sync_session.flush()

    assert run_watchdog(sync_session, NOW + timedelta(minutes=2), SETTINGS) == []


def test_past_the_hard_limit_with_fresh_readings_a_held_full_time_is_a_stuck_match(sync_session):
    match = make_match(sync_session, HARD, **SECOND_HALF)
    _called_over(sync_session, match, read_at=FRESH)

    alerts = run_watchdog(sync_session, NOW, SETTINGS)

    assert match.status == "finished"
    assert len(alerts) == 1
    assert sync_session.get(LiveProblem, f"stuck:{match.id}").closed_at is None
    assert sync_session.get(LiveProblem, f"fulltime:{match.id}") is None


def test_past_the_hard_limit_with_fresh_readings_a_first_half_row_still_goes_to_the_clock(sync_session):
    match = make_match(sync_session, HARD, **{**FEED, "period": "1H"})
    _called_over(sync_session, match, read_at=FRESH)

    run_watchdog(sync_session, NOW, SETTINGS)

    assert (match.status_source, match.status) == ("clock", "scheduled")
    assert sync_session.get(LiveProblem, f"fulltime:{match.id}") is None


def test_a_match_a_source_called_over_waits_while_readings_still_come(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=125), **SECOND_HALF)
    _called_over(sync_session, match, read_at=FRESH)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert match.status == "live"


def test_a_match_no_source_called_over_still_goes_to_the_clock_when_readings_stop(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=125), **SECOND_HALF)
    _with_reading(sync_session, match, NOW - timedelta(seconds=SETTINGS.stale_after_s + 1))

    run_watchdog(sync_session, NOW, SETTINGS)

    assert (match.status_source, match.status, match.home_score) == ("clock", "scheduled", None)


def test_a_person_wins_over_a_source_calling_it_over(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=125), locked_fields=["status"], **SECOND_HALF)
    _called_over(sync_session, match)

    assert run_watchdog(sync_session, NOW, SETTINGS) == []
    assert (match.status_source, match.status) == ("feed", "live")
    assert sync_session.get(LiveProblem, f"fulltime:{match.id}") is None


def test_the_full_time_problem_closes_once_the_match_is_long_gone(sync_session):
    match = make_match(sync_session, NOW - timedelta(minutes=125), **SECOND_HALF)
    _called_over(sync_session, match)
    run_watchdog(sync_session, NOW, SETTINGS)
    sync_session.flush()

    later = match.kickoff_at + SETTINGS.hard_limit + timedelta(hours=1, minutes=1)
    alerts = run_watchdog(sync_session, later, SETTINGS)

    assert len(alerts) == 1
    assert sync_session.get(LiveProblem, f"fulltime:{match.id}").closed_at == later
