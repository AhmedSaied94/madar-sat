"""Per-type lateness, the audience defaults and the off switch (D6 T022, FR-017, FR-019, FR-021, research R9/R10)."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta

from app.notifications.policy import (
    DEFAULT_ON,
    KNOWN_TYPES,
    Cancel,
    Send,
    decide,
    default_on,
    parse_types_off,
)

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
GOAL = {"match_id": 48213, "side": "home", "home": 2, "away": 1, "generation": 0}


def _decide(
    row_type: str,
    *,
    due: datetime = NOW,
    status: str | None = "live",
    payload: dict[str, object] | None = None,
    current: tuple[int, int] | None = None,
    scheduled: bool = False,
    is_test: bool = False,
):
    return decide(row_type, due, NOW, status, payload or {}, current, scheduled, is_test)


def test_a_goal_within_fifteen_minutes_goes_out():
    assert _decide("goal", due=NOW - timedelta(minutes=15), payload=GOAL, current=(2, 1)) == Send()


def test_a_goal_older_than_fifteen_minutes_is_late():
    assert _decide("goal", due=NOW - timedelta(minutes=15, seconds=1), payload=GOAL, current=(2, 1)) == Cancel("late")


def test_a_goal_for_a_finished_match_is_cancelled():
    assert _decide("goal", status="finished", payload=GOAL, current=(2, 1)) == Cancel("match_finished")


def test_a_goals_side_that_fell_below_the_row_is_cancelled():
    assert _decide("goal", payload=GOAL, current=(1, 1)) == Cancel("score_fell")
    assert _decide("goal", payload={**GOAL, "side": "away"}, current=(2, 0)) == Cancel("score_fell")


def test_a_goal_whose_side_still_shows_the_row_goes_out():
    assert _decide("goal", payload=GOAL, current=(2, 1)) == Send()
    assert _decide("goal", payload=GOAL, current=(3, 2)) == Send()
    assert _decide("goal", payload=GOAL, current=None) == Send()


def test_a_match_started_within_fifteen_minutes_goes_out():
    assert _decide("match_started", due=NOW - timedelta(minutes=15)) == Send()


def test_a_match_started_older_than_fifteen_minutes_is_late():
    assert _decide("match_started", due=NOW - timedelta(minutes=15, seconds=1)) == Cancel("late")


def test_a_match_started_for_a_finished_match_is_cancelled():
    assert _decide("match_started", status="finished") == Cancel("match_finished")


def test_a_final_score_within_two_hours_goes_out():
    assert _decide("final_score", due=NOW - timedelta(hours=2), status="finished") == Send()


def test_a_final_score_older_than_two_hours_is_late():
    assert _decide("final_score", due=NOW - timedelta(hours=2, seconds=1), status="finished") == Cancel("late")


def test_a_correction_follows_the_two_hour_limit_and_ignores_the_current_score():
    """FR-009: a correction exists to replace a wrong score, so a lower current score is its whole point."""
    correction = {"match_id": 48213, "kind": "correction", "home": 1, "away": 1, "generation": 1}

    assert (
        _decide("goal", due=NOW - timedelta(hours=2), status="finished", payload=correction, current=(0, 0)) == Send()
    )
    assert _decide("goal", due=NOW - timedelta(hours=2, seconds=1), payload=correction) == Cancel("late")


def test_channel_changes_stop_once_the_match_has_finished():
    assert _decide("channels_updated", payload={"match_id": 1}, status="finished") == Cancel("match_finished")
    assert _decide("channels_updated", due=NOW - timedelta(hours=10), payload={"match_id": 1}) == Send()


def test_a_scheduled_announcement_over_two_hours_late_is_cancelled():
    assert _decide("announcement", due=NOW - timedelta(hours=2), scheduled=True) == Send()
    assert _decide("announcement", due=NOW - timedelta(hours=2, seconds=1), scheduled=True) == Cancel("late")


def test_an_unscheduled_announcement_has_no_lateness_limit():
    assert _decide("announcement", due=NOW - timedelta(days=1), scheduled=False) == Send()


def test_a_reminder_stops_at_its_kickoff():
    """Today's rule, unchanged: a kickoff that has passed cancels the reminder."""
    passed = {"match_id": 1, "kickoff_at": NOW.isoformat()}
    later = {"match_id": 1, "kickoff_at": (NOW + timedelta(minutes=5)).isoformat()}

    assert _decide("kickoff_reminder", due=NOW - timedelta(minutes=1), status="scheduled", payload=passed) == Cancel(
        "late"
    )
    assert _decide("kickoff_reminder", status="scheduled", payload=later) == Send()


def test_a_test_send_never_goes_late():
    assert _decide("goal", due=NOW - timedelta(days=1), status="finished", payload=GOAL, is_test=True) == Send()
    assert _decide("announcement", due=NOW - timedelta(days=1), scheduled=True, is_test=True) == Send()


def test_an_unknown_type_is_never_cancelled():
    assert _decide("something_else", due=NOW - timedelta(days=30)) == Send()


def test_the_type_defaults_are_sd_6_8s():
    assert DEFAULT_ON == {
        "kickoff_reminder": True,
        "match_started": False,
        "goal": True,
        "final_score": True,
        "channels_updated": True,
        "frequency_changed": True,
        "announcement": True,
    }
    assert default_on("match_started") is False
    assert all(default_on(row_type) is True for row_type in KNOWN_TYPES - {"match_started"})


def test_an_unknown_type_defaults_on():
    """The audience query's COALESCE defaults to true for a name it doesn't know."""
    assert default_on("a_type_that_comes_later") is True


def test_a_correction_reads_the_goal_switch():
    """The correction stays under type ``goal`` (research R4), so no separate preference exists."""
    assert KNOWN_TYPES == set(DEFAULT_ON)
    assert default_on("goal") is True


def test_the_off_switch_parses_the_names_it_knows():
    assert parse_types_off("goal,match_started") == frozenset({"goal", "match_started"})
    assert parse_types_off(" goal , match_started ,") == frozenset({"goal", "match_started"})
    assert parse_types_off("goal,goal") == frozenset({"goal"})
    assert parse_types_off("") == frozenset()


def test_an_unknown_name_in_the_off_switch_is_ignored_and_logged(caplog):
    with caplog.at_level(logging.ERROR, logger="madar.notifications"):
        parsed = parse_types_off("goal,goals")

    assert parsed == frozenset({"goal"})
    assert any("goals" in record.getMessage() or "goals" in str(record.__dict__) for record in caplog.records)


def test_the_off_switch_covers_every_type_including_the_reminder():
    assert parse_types_off(",".join(sorted(KNOWN_TYPES))) == KNOWN_TYPES
