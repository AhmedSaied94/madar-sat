"""Writing a decision on PostgreSQL (T026): the constraints are part of what's being tested."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import AuditLog, LiveProblem, MatchEvent, MatchLineup, MatchLiveState, MatchSourceReading
from app.live.apply import apply_decision, load_state, to_clock
from app.live.problems import close_problem, open_problem
from app.live.types import Candidate, Decision, Event, Lineups, LineupSide, Score
from tests.live.helpers import make_match, make_reading, version

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
KICKOFF = NOW - timedelta(minutes=30)
GOAL = Event("g1", "goal", "home", "23", "لاعب")
RED = Event("r1", "red_card", "away", "40", "لاعب آخر")
PLAYER = {"name": "لاعب", "number": 9, "position": "مهاجم", "is_starter": True}


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

    assert to_clock(match, NOW) is False
    assert match.status_source == "feed"


def test_goal_events_are_held_while_pending_and_others_are_not(sync_session):
    match = make_match(sync_session, KICKOFF)
    pending = Candidate(Score(1, 0), "filgoal", NOW, 1)
    decision = status_decision(candidate=pending, hold_goal_events=True)

    apply_decision(sync_session, match, decision, readings=[make_reading(events=(GOAL, RED))], now=NOW)
    sync_session.flush()

    rows = sync_session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id)).all()
    assert [row.external_id for row in rows] == ["r1"]

    apply_decision(
        sync_session, match, status_decision(Score(1, 0)), readings=[make_reading(events=(GOAL, RED))], now=NOW
    )
    sync_session.flush()

    assert {
        row.external_id for row in sync_session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id))
    } == {"g1", "r1"}


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


def test_a_removed_event_is_deleted_and_a_held_goal_stays(sync_session):
    match = make_match(sync_session, KICKOFF)
    apply_decision(
        sync_session, match, status_decision(Score(1, 0)), readings=[make_reading(events=(GOAL, RED))], now=NOW
    )
    sync_session.flush()

    held = status_decision(candidate=Candidate(Score(0, 0), "filgoal", NOW, 1), hold_goal_events=True)
    apply_decision(sync_session, match, held, readings=[make_reading(events=())], now=NOW)
    sync_session.flush()
    assert {
        row.external_id for row in sync_session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id))
    } == {"g1"}

    apply_decision(sync_session, match, status_decision(Score(0, 0)), readings=[make_reading(events=())], now=NOW)
    sync_session.flush()
    assert sync_session.scalars(select(MatchEvent).where(MatchEvent.match_id == match.id)).all() == []


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
    candidate = Candidate(Score(2, 0), "yallakora", NOW, 2)
    apply_decision(
        sync_session,
        match,
        status_decision(Score(1, 0), candidate=candidate, hold_goal_events=True, disagreement_since=NOW),
        readings=[make_reading()],
        now=NOW,
    )
    sync_session.flush()

    state = load_state(sync_session, match, "filgoal")

    assert state.confirmed == Score(1, 0)
    assert state.candidate == candidate
    assert state.disagreement_since == NOW
    assert state.previous_status == ("live", "1H")
    assert (state.status, state.period) == ("live", "1H")


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
