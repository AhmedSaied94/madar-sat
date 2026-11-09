"""The goal bar's table tests (D6 T020, contracts/push-pipeline.md "The goal bar", FR-002/FR-005/FR-006/FR-009)."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta

from app.notifications.goal_bar import Reading, evaluate

NOW = datetime(2026, 11, 4, 19, 0, tzinfo=UTC)


def _memory(
    home: int = 0,
    away: int = 0,
    generation: int = 0,
    held: dict[str, object] | None = None,
    live_seen: bool = True,
) -> dict[str, object]:
    return {"home": home, "away": away, "generation": generation, "live_seen": live_seen, "held": held or {}}


def _baseline(home: int = 0, away: int = 0) -> dict[str, object]:
    """A match the bar already has a baseline for: 0–0 pushed, generation 0."""
    return _memory(home, away)


def test_with_no_accepted_score_nothing_is_sent_and_memory_is_untouched():
    memory = _memory(1, 0)

    new, messages = evaluate(memory, None, [Reading("filgoal", 2, 0)], NOW)

    assert messages == []
    assert new == memory


def test_the_first_evaluation_stores_a_baseline_and_sends_nothing():
    """FR-002: switching the producer on pushes nothing for state that already exists."""
    new, messages = evaluate({}, (2, 1), [Reading("filgoal", 3, 1)], NOW)

    assert messages == []
    assert new["home"] == 2
    assert new["away"] == 1
    assert new["generation"] == 0
    assert new["held"] == {}


def test_a_manual_status_moves_the_baseline_and_sends_no_goal():
    """FR-006: while a manual status or a locked score holds, no goal pushes."""
    new, messages = evaluate(
        _baseline(0, 0),
        (1, 0),
        [Reading("filgoal", 2, 0), Reading("yallakora", 2, 0)],
        NOW,
        manual=True,
    )

    assert messages == []
    assert (new["home"], new["away"]) == (1, 0)


def test_a_manual_status_still_sends_a_correction_first():
    """FR-009: the followers were told a score, so lowering the baseline under them is corrected."""
    new, messages = evaluate(_baseline(2, 1), (1, 1), [Reading("filgoal", 1, 1)], NOW, manual=True)

    assert [message.kind for message in messages] == ["correction"]
    assert (messages[0].home, messages[0].away) == (1, 1)
    assert new["generation"] == 1
    assert (new["home"], new["away"]) == (1, 1)


def test_the_pushed_floor_stops_two_sources_talking_a_score_back():
    """The contract's pin: pushed 2–0 with readings 2–1 and 1–1 gives 2–1, never 1–1."""
    new, messages = evaluate(
        _baseline(2, 0),
        (2, 1),
        [Reading("filgoal", 2, 1), Reading("yallakora", 1, 1)],
        NOW,
    )

    assert [(message.side, message.home, message.away) for message in messages] == [("away", 2, 1)]
    assert (new["home"], new["away"]) == (2, 1)


def test_two_sources_take_the_second_highest_capped_at_accepted():
    """FR-004: a rise two sources show goes out; the bar is the second highest, never the accepted score."""
    new, messages = evaluate(
        _baseline(0, 0),
        (2, 0),
        [Reading("filgoal", 3, 0), Reading("yallakora", 2, 0)],
        NOW,
    )

    assert [(message.side, message.home, message.away) for message in messages] == [("home", 2, 0)]
    assert (new["home"], new["away"]) == (2, 0)


def test_two_sources_at_the_pushed_score_send_nothing():
    _, messages = evaluate(_baseline(2, 1), (2, 1), [Reading("filgoal", 2, 1), Reading("yallakora", 2, 1)], NOW)

    assert messages == []


def test_one_source_sends_nothing_before_three_minutes():
    """FR-004: a lone source's word waits for an unbroken 3-minute hold."""
    held, messages = evaluate(_baseline(0, 0), (1, 0), [Reading("filgoal", 1, 0)], NOW)
    assert messages == []
    assert held["held"]["home"] == {"value": 1, "since": NOW.isoformat()}

    _, messages = evaluate(held, (1, 0), [Reading("filgoal", 1, 0)], NOW + timedelta(minutes=2, seconds=59))
    assert messages == []

    new, messages = evaluate(held, (1, 0), [Reading("filgoal", 1, 0)], NOW + timedelta(minutes=3))
    assert [(message.side, message.home, message.away) for message in messages] == [("home", 1, 0)]
    assert (new["home"], new["away"]) == (1, 0)
    assert new["held"] == {}


def test_a_break_restarts_the_hold():
    held, _ = evaluate(_baseline(0, 0), (1, 0), [Reading("filgoal", 1, 0)], NOW)

    held, messages = evaluate(held, (0, 0), [Reading("filgoal", 0, 0)], NOW + timedelta(minutes=1))
    assert messages == []
    assert held["held"] == {}

    held, messages = evaluate(held, (1, 0), [Reading("filgoal", 1, 0)], NOW + timedelta(minutes=2))
    assert messages == []
    _, messages = evaluate(held, (1, 0), [Reading("filgoal", 1, 0)], NOW + timedelta(minutes=4, seconds=59))
    assert messages == []
    _, messages = evaluate(held, (1, 0), [Reading("filgoal", 1, 0)], NOW + timedelta(minutes=5))
    assert len(messages) == 1


def test_a_rise_on_a_lone_source_does_not_lift_the_held_floor():
    """The capture's Mouloudia: a source flipping 1–0/2–0 holds 1–0, so the false 2–0 never passes."""
    held, messages = evaluate(_baseline(0, 0), (1, 0), [Reading("filgoal", 1, 0)], NOW)
    assert messages == []

    held, messages = evaluate(held, (2, 0), [Reading("filgoal", 2, 0)], NOW + timedelta(minutes=1))
    assert messages == []
    assert held["held"]["home"] == {"value": 1, "since": NOW.isoformat()}

    _, messages = evaluate(held, (2, 0), [Reading("filgoal", 2, 0)], NOW + timedelta(minutes=3))
    assert [(message.side, message.home, message.away) for message in messages] == [("home", 1, 0)]


def test_two_sources_replace_a_hold_at_once():
    held, _ = evaluate(_baseline(0, 0), (2, 0), [Reading("filgoal", 2, 0)], NOW)

    _, messages = evaluate(
        held,
        (2, 0),
        [Reading("filgoal", 2, 0), Reading("yallakora", 2, 0)],
        NOW + timedelta(minutes=1),
    )

    assert [(message.home, message.away) for message in messages] == [(2, 0)]


def test_one_message_per_side_and_all_carry_the_bars_score():
    """FR-005: one message per team per rise, and the bar's score, not the accepted one."""
    new, messages = evaluate(
        _baseline(1, 1),
        (3, 3),
        [Reading("filgoal", 2, 2), Reading("yallakora", 3, 3)],
        NOW,
    )

    assert sorted((message.side, message.home, message.away) for message in messages) == [
        ("away", 2, 2),
        ("home", 2, 2),
    ]
    assert (new["home"], new["away"]) == (2, 2)


def test_a_correction_bumps_the_generation_and_a_goal_scored_again_gets_a_new_key():
    """FR-009 and research R4: the generation rises with each correction."""
    new, messages = evaluate(_baseline(2, 1), (1, 1), [Reading("filgoal", 1, 1)], NOW)

    assert [(message.kind, message.home, message.away) for message in messages] == [("correction", 1, 1)]
    assert messages[0].dedupe_key(48213) == "goal_correction:48213:0"
    assert new["generation"] == 1

    _, messages = evaluate(
        new,
        (2, 1),
        [Reading("filgoal", 2, 1), Reading("yallakora", 2, 1)],
        NOW + timedelta(minutes=1),
    )

    assert [message.kind for message in messages] == ["goal"]
    assert messages[0].dedupe_key(48213) == "goal:48213:1:home:2"


def test_the_goal_key_names_the_side_and_the_value():
    """FR-005: the key must not depend on the minute, and must let a goal scored again push."""
    _, messages = evaluate(
        _baseline(0, 0),
        (0, 1),
        [Reading("filgoal", 0, 1), Reading("yallakora", 0, 1)],
        NOW,
    )

    assert messages[0].dedupe_key(7) == "goal:7:0:away:1"


def test_penalties_do_nothing():
    """A shoot-out changes home_pen/away_pen, never home/away; the bar doesn't run while status is penalties."""
    memory = _baseline(1, 1)
    readings = [Reading("filgoal", 1, 1, home_pen=4, away_pen=3), Reading("yallakora", 1, 1, home_pen=4, away_pen=3)]

    new, messages = evaluate(memory, (1, 1), readings, NOW, status="penalties")

    assert messages == []
    assert new == memory


def test_the_shootouts_own_count_never_passes_the_bar():
    """FR-006: the bar judges home and away only, whatever the shoot-out shows."""
    new, messages = evaluate(
        _baseline(1, 1),
        (1, 1),
        [Reading("filgoal", 1, 1, home_pen=4, away_pen=3), Reading("yallakora", 1, 1, home_pen=4, away_pen=3)],
        NOW,
    )

    assert messages == []
    assert (new["home"], new["away"]) == (1, 1)


def test_the_memory_is_json_safe():
    """match_live_state.push_memory is JSONB (research R2)."""
    held, _ = evaluate(_baseline(0, 0), (1, 0), [Reading("filgoal", 1, 0)], NOW)

    assert json.loads(json.dumps(held)) == held


def test_live_seen_is_carried_through_untouched():
    """The producer sets live_seen for match_started; the bar never rewrites it."""
    memory = {"home": 0, "away": 0, "generation": 0, "live_seen": True, "held": {}}

    new, _ = evaluate(memory, (1, 0), [Reading("filgoal", 1, 0), Reading("yallakora", 1, 0)], NOW)

    assert new["live_seen"] is True
