"""Writing a decision on PostgreSQL (T026): the constraints are part of what's being tested."""

from __future__ import annotations

from dataclasses import replace
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import (
    AuditLog,
    LiveProblem,
    MatchEvent,
    MatchLineup,
    MatchLiveState,
    MatchSourceReading,
    MatchStats,
)
from app.live.apply import apply_decision as apply_with_limits
from app.live.apply import load_state, to_clock
from app.live.problems import close_problem, open_problem
from app.live.types import Decision, Event, Lineups, LineupSide, Peak, Score
from tests.live.helpers import make_match, make_reading, version

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
KICKOFF = NOW - timedelta(minutes=30)
GOAL = Event("g1", "goal", "home", "23", "لاعب")
RED = Event("r1", "red_card", "away", "40", "لاعب آخر")
PLAYER = {"name": "لاعب", "number": 9, "position": "مهاجم", "is_starter": True}
DROP_HOLD = timedelta(minutes=5)
STUCK_AFTER = timedelta(minutes=150)


def apply_decision(session, match, decision, **values):
    return apply_with_limits(session, match, decision, drop_hold=DROP_HOLD, stuck_after=STUCK_AFTER, **values)


def _event_ids(session, match) -> set[str]:
    return {row.external_id for row in session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id))}


def status_decision(score: Score | None = None, *, status="live", period="1H", minute="23", **more) -> Decision:
    return Decision(
        write_status=True,
        status=status,
        period=period,
        minute=minute,
        status_label="الشوط الاول",
        confirm=score,
        **more,
    )


def test_a_started_match_moves_from_clock_to_feed(sync_session):
    match = make_match(sync_session, KICKOFF)
    before = version(sync_session, "live")

    changed = apply_decision(sync_session, match, status_decision(Score(0, 0)), readings=[make_reading()], now=NOW)
    sync_session.flush()

    assert changed is True
    assert (match.status_source, match.status, match.period, match.minute) == ("feed", "live", "1H", "23")
    assert (match.home_score, match.away_score) == (0, 0)
    assert match.status_updated_at == NOW
    assert version(sync_session, "live") == before + 1


def test_a_scheduled_reading_leaves_a_clock_row_on_the_clock(sync_session):
    match = make_match(sync_session, KICKOFF)
    before = version(sync_session, "live")

    changed = apply_decision(
        sync_session,
        match,
        status_decision(status="scheduled", period=None, minute=None),
        readings=[make_reading(status="scheduled")],
        now=NOW,
    )
    sync_session.flush()

    assert changed is False
    assert match.status_source == "clock"
    assert version(sync_session, "live") == before


def test_a_fallback_clears_the_row_meets_the_constraint_and_keeps_the_score_in_memory(sync_session):
    match = make_match(sync_session, KICKOFF)
    apply_decision(sync_session, match, status_decision(Score(2, 1)), readings=[make_reading()], now=NOW)
    sync_session.flush()

    changed = apply_decision(sync_session, match, Decision(fallback=True), readings=[], now=NOW)
    sync_session.flush()  # ck_matches_clock_no_score would raise here

    assert changed is True
    assert (match.status_source, match.status, match.minute, match.period) == ("clock", "scheduled", None, None)
    assert (match.home_score, match.away_score, match.status_label) == (None, None, None)
    state = sync_session.get(MatchLiveState, match.id)
    assert (state.confirmed_home, state.confirmed_away) == (2, 1)


def test_recovery_restores_the_score_through_the_rules(sync_session):
    match = make_match(sync_session, KICKOFF)
    apply_decision(sync_session, match, status_decision(Score(2, 1)), readings=[make_reading()], now=NOW)
    apply_decision(sync_session, match, Decision(fallback=True), readings=[], now=NOW)
    sync_session.flush()

    apply_decision(sync_session, match, status_decision(), readings=[make_reading(score=Score(2, 1))], now=NOW)
    sync_session.flush()

    assert (match.status_source, match.home_score, match.away_score) == ("feed", 2, 1)


def test_a_manual_row_is_untouched(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="manual", status="live", home_score=1, away_score=1)
    before = version(sync_session, "live")

    changed = apply_decision(
        sync_session,
        match,
        status_decision(Score(5, 5), status="finished", period=None),
        readings=[make_reading()],
        now=NOW,
    )
    sync_session.flush()

    assert changed is False
    assert (match.status_source, match.status, match.home_score, match.away_score) == ("manual", "live", 1, 1)
    assert version(sync_session, "live") == before


def test_a_fallback_leaves_a_manual_row(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="manual", status="live", home_score=1, away_score=1)

    assert apply_decision(sync_session, match, Decision(fallback=True), readings=[], now=NOW) is False
    assert match.status_source == "manual"


def test_a_locked_score_field_is_skipped_on_its_own(sync_session):
    match = make_match(
        sync_session,
        KICKOFF,
        status_source="feed",
        status="live",
        home_score=3,
        away_score=0,
        locked_fields=["home_score"],
    )

    apply_decision(sync_session, match, status_decision(Score(1, 1)), readings=[make_reading()], now=NOW)
    sync_session.flush()

    assert (match.home_score, match.away_score) == (3, 1)


def test_a_locked_status_keeps_the_status_and_still_takes_the_score(sync_session):
    match = make_match(
        sync_session,
        KICKOFF,
        status_source="feed",
        status="halftime",
        home_score=0,
        away_score=0,
        locked_fields=["status"],
    )

    apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[make_reading()], now=NOW)
    sync_session.flush()

    assert match.status == "halftime"
    assert (match.home_score, match.away_score) == (1, 0)


def test_a_locked_field_never_breaks_the_score_pair(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="feed", status="live", locked_fields=["home_score"])

    apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[make_reading()], now=NOW)
    sync_session.flush()  # ck_matches_scores_pair would raise here

    assert (match.home_score, match.away_score) == (None, None)


def test_a_fallback_leaves_a_locked_row(sync_session):
    match = make_match(
        sync_session, KICKOFF, status_source="feed", status="live", home_score=1, away_score=0, locked_fields=["status"]
    )

    assert to_clock(match, NOW, stuck_after=STUCK_AFTER) is False
    assert match.status_source == "feed"


def test_a_goal_event_waits_for_the_score_that_holds_it_and_others_do_not(sync_session):
    match = make_match(sync_session, KICKOFF)

    apply_decision(sync_session, match, status_decision(), readings=[make_reading(events=(GOAL, RED))], now=NOW)
    sync_session.flush()

    assert _event_ids(sync_session, match) == {"r1"}

    apply_decision(
        sync_session, match, status_decision(Score(1, 0)), readings=[make_reading(events=(GOAL, RED))], now=NOW
    )
    sync_session.flush()

    assert _event_ids(sync_session, match) == {"g1", "r1"}


def test_events_are_idempotent(sync_session):
    match = make_match(sync_session, KICKOFF)
    reading = make_reading(events=(GOAL,))
    apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[reading], now=NOW)
    sync_session.flush()
    before = version(sync_session, "live")

    changed = apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[reading], now=NOW)
    sync_session.flush()

    assert changed is False
    assert version(sync_session, "live") == before
    assert len(sync_session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id)).all()) == 1


def _with_events(session, match, *events, score=Score(1, 0)):
    apply_decision(session, match, status_decision(score), readings=[make_reading(events=events)], now=NOW)
    session.flush()


def _reads_none(session, match, at, *, score=Score(1, 0), source="filgoal"):
    return apply_decision(session, match, status_decision(score), readings=[make_reading(source, events=())], now=at)


def test_a_missing_event_stays_under_the_hold_and_goes_at_it(sync_session):
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, RED)
    before = version(sync_session, "live")

    assert _reads_none(sync_session, match, NOW + timedelta(seconds=1)) is False
    sync_session.flush()
    assert _event_ids(sync_session, match) == {"r1"}
    row = sync_session.scalar(select(MatchEvent).where(MatchEvent.match_id == match.id))
    assert row.missing_since == NOW + timedelta(seconds=1)
    assert version(sync_session, "live") == before

    assert _reads_none(sync_session, match, NOW + timedelta(seconds=1) + DROP_HOLD - timedelta(seconds=1)) is False
    sync_session.flush()
    assert _event_ids(sync_session, match) == {"r1"}

    assert _reads_none(sync_session, match, NOW + timedelta(seconds=1) + DROP_HOLD) is True
    sync_session.flush()
    assert _event_ids(sync_session, match) == set()
    assert version(sync_session, "live") == before + 1


def test_an_event_coming_back_clears_its_absence_and_the_hold_starts_again(sync_session):
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, RED)
    _reads_none(sync_session, match, NOW + timedelta(minutes=1))
    sync_session.flush()
    before = version(sync_session, "live")

    changed = apply_decision(
        sync_session,
        match,
        status_decision(Score(1, 0)),
        readings=[make_reading(events=(RED,))],
        now=NOW + timedelta(minutes=2),
    )
    sync_session.flush()

    assert changed is False
    assert version(sync_session, "live") == before
    assert sync_session.scalar(select(MatchEvent).where(MatchEvent.match_id == match.id)).missing_since is None

    _reads_none(sync_session, match, NOW + timedelta(minutes=3))
    _reads_none(sync_session, match, NOW + timedelta(minutes=7))
    sync_session.flush()
    assert _event_ids(sync_session, match) == {"r1"}


def test_a_goal_the_score_still_needs_stays_past_the_hold_until_the_score_drops(sync_session):
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, GOAL)

    _reads_none(sync_session, match, NOW + timedelta(minutes=1))
    _reads_none(sync_session, match, NOW + timedelta(minutes=7))
    sync_session.flush()
    assert _event_ids(sync_session, match) == {"g1"}

    _reads_none(sync_session, match, NOW + timedelta(minutes=8), score=Score(0, 0))
    sync_session.flush()
    assert _event_ids(sync_session, match) == set()


def test_a_goal_past_what_the_score_needs_goes_at_the_hold(sync_session):
    second = Event("g2", "goal", "home", "30", "لاعب")
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, GOAL, second, score=Score(2, 0))

    _reads_none(sync_session, match, NOW + timedelta(minutes=1), score=Score(1, 0))
    _reads_none(sync_session, match, NOW + timedelta(minutes=7), score=Score(1, 0))
    sync_session.flush()

    assert len(_event_ids(sync_session, match)) == 1


def _reads_events(session, match, at, *events, score=Score(1, 0)):
    changed = apply_decision(session, match, status_decision(score), readings=[make_reading(events=events)], now=at)
    session.flush()
    return changed


REPLACED = Event("g1-corrected", "goal", "home", "23", "لاعب معروف")
NEXT_GOAL = Event("g2", "goal", "home", "30", "لاعب")


def test_a_goal_whose_id_changes_at_the_same_score_is_replaced_in_one_poll(sync_session):
    """Goal.com's event ID hashes the scorer, so filling one in looks like a new goal (B1-R1-2)."""
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, GOAL)

    _reads_events(sync_session, match, NOW + timedelta(minutes=1), REPLACED)
    assert _event_ids(sync_session, match) == {"g1"}

    assert _reads_events(sync_session, match, NOW + timedelta(minutes=1) + DROP_HOLD, REPLACED) is True
    assert _event_ids(sync_session, match) == {"g1-corrected"}


def test_a_replaced_goal_is_not_shown_alongside_its_replacement_at_two_nil(sync_session):
    """The source lists two goals now, and the one still stored is one of them under another ID."""
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, GOAL)

    _reads_events(sync_session, match, NOW + timedelta(minutes=1), REPLACED, NEXT_GOAL, score=Score(2, 0))
    assert _event_ids(sync_session, match) == {"g1"}

    _reads_events(sync_session, match, NOW + timedelta(minutes=1) + DROP_HOLD, REPLACED, NEXT_GOAL, score=Score(2, 0))
    assert _event_ids(sync_session, match) == {"g1-corrected", "g2"}


def test_a_lost_goal_stays_with_the_score_and_the_next_goal_lands_beside_it(sync_session):
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, GOAL)

    _reads_events(sync_session, match, NOW + timedelta(minutes=1), NEXT_GOAL, score=Score(2, 0))
    _reads_events(sync_session, match, NOW + timedelta(minutes=1) + DROP_HOLD, NEXT_GOAL, score=Score(2, 0))

    assert _event_ids(sync_session, match) == {"g1", "g2"}


def test_a_goal_that_comes_back_lets_the_one_waiting_behind_it_land(sync_session):
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, GOAL)

    _reads_events(sync_session, match, NOW + timedelta(minutes=1), NEXT_GOAL, score=Score(2, 0))
    _reads_events(sync_session, match, NOW + timedelta(minutes=2), GOAL, NEXT_GOAL, score=Score(2, 0))

    assert _event_ids(sync_session, match) == {"g1", "g2"}
    rows = sync_session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id)).all()
    assert {row.missing_since for row in rows} == {None}


def test_a_missing_goal_holds_back_only_its_own_side(sync_session):
    away_goal = Event("a1", "goal", "away", "31", "لاعب")
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, GOAL)

    _reads_events(sync_session, match, NOW + timedelta(minutes=1), away_goal, score=Score(1, 1))

    assert _event_ids(sync_session, match) == {"g1", "a1"}


def test_a_page_with_no_events_field_is_not_an_absence(sync_session):
    match = make_match(sync_session, KICKOFF)
    _with_events(sync_session, match, RED)

    apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[make_reading()], now=NOW)
    sync_session.flush()

    assert sync_session.scalar(select(MatchEvent).where(MatchEvent.match_id == match.id)).missing_since is None


def test_each_source_keeps_its_own_events(sync_session):
    match = make_match(sync_session, KICKOFF)
    goal_com = make_reading("goal", events=(Event("h1", "goal", "home", "23", "لاعب"),))
    apply_decision(
        sync_session,
        match,
        status_decision(Score(1, 0)),
        readings=[make_reading(events=(GOAL,)), goal_com],
        now=NOW,
    )
    sync_session.flush()

    rows = sync_session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id)).all()
    assert {(row.source, row.external_id) for row in rows} == {("filgoal", "g1"), ("goal", "h1")}


def test_a_lineup_comes_from_the_first_source_that_has_one_and_does_not_alternate(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="feed", status="live", home_score=0, away_score=0)
    theirs = Lineups(LineupSide("3-5-2", (PLAYER,)), LineupSide("4-4-2", (PLAYER,)))
    ours = Lineups(LineupSide("4-3-3", (PLAYER,)), None)

    apply_decision(
        sync_session, match, status_decision(Score(0, 0)), readings=[make_reading("goal", lineups=theirs)], now=NOW
    )
    sync_session.flush()
    assert sync_session.get(MatchLineup, (match.id, "home")).source == "goal"

    both = [make_reading("filgoal", lineups=ours), make_reading("goal", lineups=theirs)]
    apply_decision(sync_session, match, status_decision(Score(0, 0)), readings=both, now=NOW)
    sync_session.flush()
    home = sync_session.get(MatchLineup, (match.id, "home"))
    assert (home.source, home.formation) == ("filgoal", "4-3-3")
    before = version(sync_session, "live")

    assert apply_decision(sync_session, match, status_decision(Score(0, 0)), readings=both, now=NOW) is False
    sync_session.flush()
    assert version(sync_session, "live") == before
    assert sync_session.get(MatchLineup, (match.id, "home")).source == "filgoal"


def test_a_lower_source_never_overwrites_a_lineup_a_higher_source_stored(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="feed", status="live", home_score=0, away_score=0)
    ours = Lineups(LineupSide("4-3-3", (PLAYER,)), None)
    theirs = Lineups(LineupSide("3-5-2", (PLAYER,)), None)
    apply_decision(
        sync_session, match, status_decision(Score(0, 0)), readings=[make_reading("filgoal", lineups=ours)], now=NOW
    )
    sync_session.flush()

    # FilGoal's request failed this poll, so only Goal.com has a lineup to offer.
    apply_decision(
        sync_session, match, status_decision(Score(0, 0)), readings=[make_reading("goal", lineups=theirs)], now=NOW
    )
    sync_session.flush()

    home = sync_session.get(MatchLineup, (match.id, "home"))
    assert (home.source, home.formation) == ("filgoal", "4-3-3")


def _stats_reading(stats):
    return replace(make_reading("goal"), stats=stats)


def test_stats_are_stored_only_on_change_and_move_no_dataset(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="feed", status="live", home_score=0, away_score=0)
    first = ({"type": "POSSESSION", "home": 55, "away": 45},)
    second = ({"type": "POSSESSION", "home": 60, "away": 40},)
    apply_decision(sync_session, match, status_decision(Score(0, 0)), readings=[_stats_reading(None)], now=NOW)
    sync_session.flush()
    before = version(sync_session, "live")

    changed = apply_decision(
        sync_session, match, status_decision(Score(0, 0)), readings=[_stats_reading(first)], now=NOW
    )
    sync_session.flush()
    assert changed is False
    row = sync_session.get(MatchStats, (match.id, "goal"))
    assert (row.stats, row.updated_at) == (list(first), NOW)
    assert version(sync_session, "live") == before

    later = NOW + timedelta(minutes=1)
    apply_decision(sync_session, match, status_decision(Score(0, 0)), readings=[_stats_reading(first)], now=later)
    sync_session.flush()
    assert row.updated_at == NOW

    apply_decision(sync_session, match, status_decision(Score(0, 0)), readings=[_stats_reading(second)], now=later)
    sync_session.flush()
    assert (row.stats, row.updated_at) == (list(second), later)
    assert version(sync_session, "live") == before


def test_a_page_with_no_stats_leaves_them(sync_session):
    match = make_match(sync_session, KICKOFF)
    first = ({"type": "POSSESSION", "home": 55, "away": 45},)
    apply_decision(sync_session, match, status_decision(), readings=[_stats_reading(first)], now=NOW)
    sync_session.flush()

    apply_decision(sync_session, match, status_decision(), readings=[_stats_reading(None)], now=NOW)
    sync_session.flush()

    assert sync_session.get(MatchStats, (match.id, "goal")).stats == list(first)


def test_a_manual_row_still_takes_events_and_never_its_score(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="manual", status="live", home_score=1, away_score=0)

    apply_decision(sync_session, match, status_decision(Score(3, 0)), readings=[make_reading(events=(RED,))], now=NOW)
    sync_session.flush()

    assert (match.home_score, match.away_score) == (1, 0)
    assert _event_ids(sync_session, match) == {"r1"}


# ------------------------------------------------------------------------------------- the peak minute


def _read(session, match, at=NOW, **values):
    apply_decision(session, match, status_decision(), readings=[make_reading(score=Score(0, 0), **values)], now=at)
    session.flush()
    return session.get(MatchSourceReading, (match.id, values.get("source", "filgoal")))


def test_the_peak_counts_stoppage_time_and_keeps_its_period(sync_session):
    match = make_match(sync_session, KICKOFF)

    row = _read(sync_session, match, period="2H", minute="90+3")

    assert (row.peak_minute, row.peak_period) == (93, "2H")


def test_the_peak_never_goes_down_and_keeps_the_period_that_set_it(sync_session):
    match = make_match(sync_session, KICKOFF)
    _read(sync_session, match, period="1H", minute="45+8")

    row = _read(sync_session, match, period="2H", minute="47")
    assert (row.peak_minute, row.peak_period) == (53, "1H")

    row = _read(sync_session, match, period="2H", minute="104")
    assert (row.peak_minute, row.peak_period) == (104, "2H")

    row = _read(sync_session, match, period="2H", minute="46")
    assert (row.peak_minute, row.peak_period) == (104, "2H")


@pytest.mark.parametrize(
    ("status", "period", "minute"),
    [("halftime", None, "60"), ("finished", None, "99")],
)
def test_only_live_and_extra_time_readings_set_the_peak(sync_session, status, period, minute):
    match = make_match(sync_session, KICKOFF)
    _read(sync_session, match, period="1H", minute="40")

    row = _read(sync_session, match, status=status, period=period, minute=minute)

    assert (row.peak_minute, row.peak_period) == (40, "1H")


def test_extra_time_sets_the_peak(sync_session):
    match = make_match(sync_session, KICKOFF)

    row = _read(sync_session, match, status="extra_time", period="ET1", minute="105+1")

    assert (row.peak_minute, row.peak_period) == (106, "ET1")


def test_an_unknown_status_leaves_the_peak_and_clears_the_rest(sync_session):
    match = make_match(sync_session, KICKOFF)
    _read(sync_session, match, period="2H", minute="70")
    unknown = replace(make_reading(score=Score(0, 0), status=None, period=None, minute=None), unknown_status="جديد")

    apply_decision(sync_session, match, status_decision(), readings=[unknown], now=NOW)
    sync_session.flush()

    row = sync_session.get(MatchSourceReading, (match.id, "filgoal"))
    assert (row.status, row.minute, row.peak_minute, row.peak_period) == (None, None, 70, "2H")


def test_a_peak_change_alone_is_not_a_changed_reading(sync_session):
    match = make_match(sync_session, KICKOFF)
    _read(sync_session, match, period="2H", minute="70")
    row = sync_session.get(MatchSourceReading, (match.id, "filgoal"))
    row.peak_minute = 60
    sync_session.flush()

    row = _read(sync_session, match, at=NOW + timedelta(minutes=1), period="2H", minute="70")

    assert (row.peak_minute, row.changed_at) == (70, NOW)


def test_a_list_reading_without_events_leaves_the_events(sync_session):
    match = make_match(sync_session, KICKOFF)
    apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[make_reading(events=(GOAL,))], now=NOW)
    sync_session.flush()

    apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[make_reading(events=None)], now=NOW)
    sync_session.flush()

    assert len(sync_session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id)).all()) == 1


def test_lineups_are_written_and_a_repeat_changes_nothing(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="feed", status="live", home_score=0, away_score=0)
    lineups = Lineups(LineupSide("4-3-3", (PLAYER,)), None)

    assert (
        apply_decision(
            sync_session, match, status_decision(Score(0, 0)), readings=[make_reading(lineups=lineups)], now=NOW
        )
        is True
    )
    sync_session.flush()

    assert (
        apply_decision(
            sync_session, match, status_decision(Score(0, 0)), readings=[make_reading(lineups=lineups)], now=NOW
        )
        is False
    )
    row = sync_session.get(MatchLineup, (match.id, "home"))
    assert (row.formation, row.players) == ("4-3-3", [PLAYER])
    assert sync_session.get(MatchLineup, (match.id, "away")) is None


def test_live_moves_and_matches_does_not_and_nothing_is_audited(sync_session):
    match = make_match(sync_session, KICKOFF)
    matches_before = version(sync_session, "matches")
    audits_before = len(sync_session.scalars(select(AuditLog)).all())

    apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[make_reading()], now=NOW)
    sync_session.flush()

    assert version(sync_session, "matches") == matches_before
    assert len(sync_session.scalars(select(AuditLog)).all()) == audits_before


@pytest.mark.parametrize("status", ["postponed", "cancelled", "abandoned"])
def test_a_match_not_being_played_leaves_the_clock_without_a_score(sync_session, status):
    match = make_match(sync_session, NOW + timedelta(minutes=5))

    changed = apply_decision(
        sync_session,
        match,
        status_decision(status=status, period=None, minute=None),
        readings=[make_reading(status=status)],
        now=NOW,
    )
    sync_session.flush()

    assert changed is True
    assert (match.status_source, match.status, match.home_score) == ("feed", status, None)


def test_readings_keep_their_last_change_time(sync_session):
    match = make_match(sync_session, KICKOFF)
    later = NOW + timedelta(seconds=60)
    apply_decision(sync_session, match, status_decision(), readings=[make_reading(score=Score(0, 0))], now=NOW)
    sync_session.flush()

    apply_decision(sync_session, match, status_decision(), readings=[make_reading(score=Score(0, 0))], now=later)
    sync_session.flush()

    row = sync_session.get(MatchSourceReading, (match.id, "filgoal"))
    assert (row.read_at, row.changed_at) == (later, NOW)


def test_the_memory_round_trips_through_load_state(sync_session):
    match = make_match(sync_session, KICKOFF)
    decision = status_decision(
        Score(1, 0),
        drop_since=NOW - timedelta(minutes=1),
        status_drop_since=NOW - timedelta(minutes=2),
        score_first_source="yallakora",
        score_changed_at=NOW - timedelta(minutes=3),
        fulltime_source="goal",
        fulltime_since=NOW - timedelta(minutes=4),
        finish_wait_since=NOW - timedelta(minutes=5),
        disagreement_since=NOW - timedelta(minutes=6),
    )
    apply_decision(sync_session, match, decision, readings=[make_reading(period="2H", minute="90+3")], now=NOW)
    sync_session.flush()

    state = load_state(sync_session, match)

    assert state.confirmed == Score(1, 0)
    assert (state.status, state.period, state.minute, state.status_label) == ("live", "1H", "23", "الشوط الاول")
    assert state.drop_since == NOW - timedelta(minutes=1)
    assert state.status_drop_since == NOW - timedelta(minutes=2)
    assert state.score_first_source == "yallakora"
    assert state.score_changed_at == NOW - timedelta(minutes=3)
    assert state.fulltime_source == "goal"
    assert state.fulltime_since == NOW - timedelta(minutes=4)
    assert state.finish_wait_since == NOW - timedelta(minutes=5)
    assert state.disagreement_since == NOW - timedelta(minutes=6)
    assert state.peaks == {"filgoal": Peak(93, "2H")}


def test_a_problem_alerts_once_while_open_and_once_on_recovery(sync_session):
    assert "filgoal" in open_problem(sync_session, "format:filgoal", NOW, raw_ref="/srv/raw/live_poller/x")
    assert open_problem(sync_session, "format:filgoal", NOW + timedelta(seconds=60)) is None

    row = sync_session.get(LiveProblem, "format:filgoal")
    assert (row.alerted_at, row.closed_at, row.raw_ref) == (NOW, None, "/srv/raw/live_poller/x")

    assert close_problem(sync_session, "format:filgoal", NOW + timedelta(seconds=120)) is not None
    assert close_problem(sync_session, "format:filgoal", NOW + timedelta(seconds=180)) is None

    assert open_problem(sync_session, "format:filgoal", NOW + timedelta(seconds=240)) is not None
    sync_session.expire_all()
    assert sync_session.get(LiveProblem, "format:filgoal").closed_at is None


def test_the_alert_text_names_the_saved_page(sync_session):
    text = open_problem(sync_session, "format:yallakora", NOW, raw_ref="/srv/raw/live_poller/2026-11-04/9")

    assert "yallakora" in text
    assert "/srv/raw/live_poller/2026-11-04/9" in text


def test_closing_a_problem_that_never_opened_says_nothing(sync_session):
    assert close_problem(sync_session, "both_down", NOW) is None


@pytest.mark.parametrize(
    ("key", "subject"), [("unknown_status:goal", "goal"), ("stuck:7", "7")], ids=["unknown_status", "stuck"]
)
def test_the_new_problems_open_close_and_open_again(sync_session, key, subject):
    assert subject in open_problem(sync_session, key, NOW)
    assert open_problem(sync_session, key, NOW + timedelta(seconds=60)) is None

    assert subject in close_problem(sync_session, key, NOW + timedelta(seconds=120))

    assert subject in open_problem(sync_session, key, NOW + timedelta(seconds=180))
    sync_session.expire_all()
    row = sync_session.get(LiveProblem, key)
    assert (row.opened_at, row.closed_at) == (NOW + timedelta(seconds=180), None)


def test_a_match_never_read_starts_with_an_empty_memory(sync_session):
    match = make_match(sync_session, KICKOFF)

    state = load_state(sync_session, match)

    assert (state.confirmed, state.score_changed_at, state.peaks) == (None, None, {})


def test_a_source_with_no_peak_has_no_entry(sync_session):
    match = make_match(sync_session, KICKOFF)
    apply_decision(sync_session, match, status_decision(), readings=[make_reading(status="scheduled")], now=NOW)
    sync_session.flush()

    assert load_state(sync_session, match).peaks == {}


def test_the_old_candidate_column_is_cleared_and_not_read(sync_session):
    match = make_match(sync_session, KICKOFF)
    sync_session.add(MatchLiveState(match_id=match.id, updated_at=NOW, candidate={"home": 9, "away": 9}))
    sync_session.flush()

    apply_decision(sync_session, match, status_decision(Score(1, 0)), readings=[make_reading()], now=NOW)
    sync_session.flush()

    assert sync_session.get(MatchLiveState, match.id).candidate is None


def test_a_postponed_row_never_goes_to_the_clock(sync_session):
    match = make_match(sync_session, KICKOFF, status_source="feed", status="postponed", status_label="تأجيل")
    before = version(sync_session, "live")

    assert to_clock(match, NOW, stuck_after=STUCK_AFTER) is False
    changed = apply_decision(sync_session, match, Decision(fallback=True), readings=[], now=NOW)
    sync_session.flush()

    assert changed is False
    assert (match.status_source, match.status, match.status_label) == ("feed", "postponed", "تأجيل")
    assert version(sync_session, "live") == before


def test_a_held_final_status_leaves_status_and_minute_as_they_were(sync_session):
    match = make_match(
        sync_session,
        KICKOFF,
        status_source="feed",
        status="live",
        period="2H",
        minute="90+3",
        status_label="الشوط الثاني",
        home_score=1,
        away_score=1,
    )
    before = version(sync_session, "live")
    held = Decision(
        write_status=True,
        status="live",
        period="2H",
        minute="90+3",
        status_label="الشوط الثاني",
        fulltime_source="filgoal",
        fulltime_since=NOW,
    )

    apply_decision(
        sync_session,
        match,
        held,
        readings=[make_reading("filgoal", Score(1, 1), status="finished", period=None, minute=None, label="انتهت")],
        now=NOW,
    )
    sync_session.flush()

    assert (match.status, match.minute, match.home_score, match.away_score) == ("live", "90+3", 1, 1)
    assert version(sync_session, "live") == before
    assert sync_session.get(MatchLiveState, match.id).fulltime_source == "filgoal"


# -------------------------------------------------------------------------------- the clock past + 150


LATE = NOW - STUCK_AFTER - timedelta(minutes=1)
ON_TIME = NOW - STUCK_AFTER + timedelta(minutes=1)


@pytest.mark.parametrize(
    ("status", "period"),
    [("live", "2H"), ("extra_time", "ET1"), ("extra_time", None), ("penalties", None)],
)
def test_the_clock_refuses_a_row_past_the_limit_that_reached_the_second_half(sync_session, status, period):
    match = make_match(
        sync_session, LATE, status_source="feed", status=status, period=period, home_score=1, away_score=2
    )

    assert to_clock(match, NOW, stuck_after=STUCK_AFTER) is False
    assert (match.status_source, match.status, match.home_score, match.away_score) == ("feed", status, 1, 2)


@pytest.mark.parametrize(
    ("kickoff", "status", "period"),
    [
        (ON_TIME, "live", "2H"),
        (LATE, "live", "1H"),
        (LATE, "halftime", None),
        (LATE, "live", None),
    ],
    ids=["before_the_limit", "first_half", "halftime", "no_period"],
)
def test_the_clock_still_takes_a_row_otherwise(sync_session, kickoff, status, period):
    match = make_match(
        sync_session, kickoff, status_source="feed", status=status, period=period, home_score=1, away_score=2
    )

    assert to_clock(match, NOW, stuck_after=STUCK_AFTER) is True
    assert (match.status_source, match.status, match.home_score) == ("clock", "scheduled", None)


def test_a_fallback_past_the_limit_keeps_the_row_and_bumps_nothing(sync_session):
    match = make_match(sync_session, LATE, status_source="feed", status="live", period="2H", home_score=1, away_score=2)
    before = version(sync_session, "live")

    assert apply_decision(sync_session, match, Decision(fallback=True), readings=[], now=NOW) is False
    sync_session.flush()

    assert (match.status_source, match.status, match.period, match.home_score) == ("feed", "live", "2H", 1)
    assert version(sync_session, "live") == before
