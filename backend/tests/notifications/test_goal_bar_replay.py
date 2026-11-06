"""The 2026-11-04 capture replayed through ``decide`` and the goal bar (D6 T021, research R1).

The numbers are the contract's: 58 goal messages and 0 corrections over the whole capture; Mouloudia
Alger's real 1–0 at +240 s and its false 2–0 never; Porto v Napoli's 2–1, 3–1 and 4–1 at +495 s,
+580 s and +116 s as the slower source catches up. They were measured on the rules in
``contracts/push-pipeline.md`` and are not to be updated to match the code.

The layers below are D5's own replay (``tests/live/test_replay.py``): the same committed timelines,
the same side builders and the same ``decide``/``_next_state``. Only ``evaluate`` is new. A pin's
delay counts from the first poll whose readings showed the score, which is what the research timed.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any

import pytest

from app.live.crosscheck import decide
from app.live.types import LiveState
from app.notifications.goal_bar import GoalMessage, Reading, evaluate
from tests.live.test_replay import (
    DISAGREE_AFTER,
    DROP_HOLD,
    FULLTIME_HOLD,
    POLLS,
    TIMELINES,
    _filgoal_side,
    _next_state,
    _yallakora_side,
)

MOULOUDIA = "376088"
PORTO_NAPOLI = "378944"

HOLD = timedelta(minutes=3)


@dataclass
class Replayed:
    """One match's messages and the first poll each score was shown at."""

    match: dict[str, Any]
    messages: list[tuple[datetime, GoalMessage]] = field(default_factory=list)
    first_seen: dict[tuple[int, int], datetime] = field(default_factory=dict)

    def goals(self) -> list[tuple[datetime, GoalMessage]]:
        return [(at, message) for at, message in self.messages if message.kind == "goal"]

    def corrections(self) -> list[tuple[datetime, GoalMessage]]:
        return [(at, message) for at, message in self.messages if message.kind == "correction"]

    def delay(self, at: datetime, score: tuple[int, int]) -> timedelta:
        return at - self.first_seen[score]


def _replay(match: dict[str, Any]) -> Replayed:
    result = Replayed(match)
    state = LiveState(match_id=1, status="scheduled", period=None)
    memory: dict[str, Any] = {}
    for now in POLLS:
        sides = {"filgoal": _filgoal_side(match, now), "yallakora": _yallakora_side(match, now)}
        decision = decide(
            state,
            sides,
            now,
            drop_hold=DROP_HOLD,
            disagree_after=DISAGREE_AFTER,
            fulltime_hold=FULLTIME_HOLD,
        )
        state = _next_state(state, decision)
        readings = [
            Reading(
                source=source,
                home=side.reading.score.home,
                away=side.reading.score.away,
                home_pen=side.reading.score.home_pen,
                away_pen=side.reading.score.away_pen,
            )
            for source, side in sides.items()
            if side.reading is not None and side.reading.score is not None
        ]
        for reading in readings:
            result.first_seen.setdefault((reading.home, reading.away), now)
        accepted = None if state.confirmed is None else (state.confirmed.home, state.confirmed.away)
        if state.status == "penalties":
            continue
        memory, messages = evaluate(memory, accepted, readings, now, held_for=HOLD)
        result.messages.extend((now, message) for message in messages)
    return result


@pytest.fixture(scope="module")
def replayed() -> dict[str, Replayed]:
    return {match["filgoal_id"]: _replay(match) for match in TIMELINES["matches"]}


def test_the_whole_capture_gives_the_pinned_goal_count(replayed):
    goals = sum(len(result.goals()) for result in replayed.values())

    assert goals == 58


def test_the_whole_capture_asks_for_no_correction(replayed):
    corrections = sum(len(result.corrections()) for result in replayed.values())

    assert corrections == 0


def test_mouloudia_gets_only_its_real_goal(replayed):
    """The feed flipped between 1–0 and 2–0; the false 2–0 was never held for three minutes."""
    result = replayed[MOULOUDIA]

    assert [(at, (message.home, message.away)) for at, message in result.goals()] == [
        (result.first_seen[(1, 0)] + timedelta(seconds=240), (1, 0))
    ]
    assert all(message.home != 2 for _, message in result.messages)


def test_mouloudia_sends_its_goal_within_the_hold_and_one_poll(replayed):
    """+240 s: three minutes of hold on a one-minute poll beat, and not a second more."""
    result = replayed[MOULOUDIA]
    ((at, _),) = result.goals()

    assert result.delay(at, (1, 0)) == timedelta(seconds=240)


def test_porto_napoli_sends_each_rise_as_the_slower_source_catches_up(replayed):
    """One message per rise, never one 4–1: 2–1, 3–1 and 4–1 replace each other on the device."""
    result = replayed[PORTO_NAPOLI]
    scores = [(message.home, message.away) for _, message in result.goals()]

    assert [score for score in scores if score in {(2, 1), (3, 1), (4, 1)}] == [(2, 1), (3, 1), (4, 1)]


@pytest.mark.parametrize(("score", "seconds"), [((2, 1), 495), ((3, 1), 580), ((4, 1), 116)])
def test_porto_napoli_delays_are_the_ones_research_measured(replayed, score, seconds):
    result = replayed[PORTO_NAPOLI]
    at = next(at for at, message in result.goals() if (message.home, message.away) == score)

    assert result.delay(at, score) == timedelta(seconds=seconds)


def test_every_message_is_a_goal_or_a_correction(replayed):
    kinds = {message.kind for result in replayed.values() for _, message in result.messages}

    assert kinds <= {"goal", "correction"}
