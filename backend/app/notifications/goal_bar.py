"""The goal bar: memory + this poll's readings + ``now`` → the new memory and the goals due.

Pure: no database, no settings, no clock beyond the ``now`` it is given. The contract is
``specs/006-d06-notifications-and-live-center/contracts/push-pipeline.md`` ("The goal bar"), and the
rules below it are numbered as they are there:

1. No accepted score: nothing to judge, so nothing is sent (FR-002).
2. Empty memory: this is the first evaluation, so it stores the accepted score as the baseline with
   generation 0 and sends nothing. Switching the producer on therefore pushes no old score (FR-002).
3. An accepted score below what was pushed on either side: the correction runs first, carrying the
   accepted score and the generation it corrects, and the rest goes on from the corrected score. This
   holds under a manual status or a locked score too, because followers were told a score that is now
   wrong (FR-009). Whether a row is worth writing is the producer's guard — it writes the correction
   only if this generation's goal or final row was actually sent (research R9) — while the memory
   moves to the new generation either way.
4. A manual status or a locked score: no goal is sent, and the baseline moves to the accepted score
   (FR-006).
5. Per side, from the readings that carry a score:

   - 2 or more: ``bar = max(pushed, min(second highest, accepted))``. Two sources are enough even when
     a third is slower (research R1, FR-004), and the floor is what stops a slower source from talking
     a score already pushed back down — that is the correction's job, and only its own.
   - exactly 1: the lowest value above ``pushed`` that the source has shown without a break for
     ``held_for``. A rise does not lift that floor (a source showing 2–0 has also shown 1–0), while a
     value at or below ``pushed`` clears the hold. This is the capture's Mouloudia case: the feed
     flipped between 1–0 and 2–0, and the held 1–0 is true where the never-held 2–0 is not (FR-004).
   - none: the hold is cleared and nothing passes.

6. Each side whose bar is above ``pushed`` adds one message. Every message carries the bar's score,
   not the accepted one, and ``pushed`` becomes that score (FR-005). A side that just pushed clears
   its hold, so the next rise holds from where it was pushed.

The shoot-out's own count is never read: ``home_pen`` and ``away_pen`` are carried only so a caller
can pass a stored score unchanged, and the bar doesn't run while ``status`` is ``penalties`` (FR-006).
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Literal

HELD_FOR = timedelta(minutes=3)
PENALTIES = "penalties"

Side = Literal["home", "away"]
Kind = Literal["goal", "correction"]
SIDES: tuple[Side, ...] = ("home", "away")


@dataclass(frozen=True, slots=True)
class Reading:
    """One source's score this poll. ``home_pen``/``away_pen`` are never read by the bar."""

    source: str
    home: int | None
    away: int | None
    home_pen: int | None = None
    away_pen: int | None = None


@dataclass(frozen=True, slots=True)
class GoalMessage:
    """One push the caller must write: a goal for one side, or a correction of a pushed score."""

    kind: Kind
    side: Side | None
    home: int
    away: int
    generation: int
    value: int

    def dedupe_key(self, match_id: int) -> str:
        """The outbox key (research R4): a correction keys on the generation it corrects."""
        if self.kind == "correction":
            return f"goal_correction:{match_id}:{self.generation}"
        return f"goal:{match_id}:{self.generation}:{self.side}:{self.value}"


def evaluate(
    memory: Mapping[str, Any],
    accepted: tuple[int, int] | None,
    readings: Sequence[Reading],
    now: datetime,
    held_for: timedelta = HELD_FOR,
    *,
    manual: bool = False,
    status: str | None = None,
) -> tuple[dict[str, Any], list[GoalMessage]]:
    """Return ``(new_memory, messages)``. ``memory`` is never mutated; the result is JSON-safe.

    ``manual`` says the match holds a manual status or a locked score. ``status`` lets a shoot-out
    short-circuit the bar; a caller that doesn't pass it can't mis-judge one, because a shoot-out
    leaves ``home`` and ``away`` alone.
    """
    state = dict(memory)
    if accepted is None or status == PENALTIES:
        return state, []
    if state.get("home") is None or state.get("away") is None:
        return _baseline(state, accepted), []

    pushed = (int(state["home"]), int(state["away"]))
    generation = int(state.get("generation") or 0)
    held = _copy_held(state.get("held"))
    messages: list[GoalMessage] = []

    if accepted[0] < pushed[0] or accepted[1] < pushed[1]:
        # Rule 3: the correction carries the generation it corrects; the next goal uses the new one.
        messages.append(GoalMessage("correction", None, accepted[0], accepted[1], generation, 0))
        generation += 1
        pushed = accepted
        held = {}

    if manual:
        state.update({"home": accepted[0], "away": accepted[1], "generation": generation, "held": {}})
        return state, messages

    bars = {"home": pushed[0], "away": pushed[1]}
    for index, side in enumerate(SIDES):
        values = _values(readings, side)
        if len(values) >= 2:
            bars[side] = max(pushed[index], min(values[-2], accepted[index]))
            held.pop(side, None)
        elif len(values) == 1:
            value = values[0]
            if value <= pushed[index]:
                held.pop(side, None)
                continue
            previous = held.get(side)
            since = None if previous is None else _since(previous)
            if previous is None or since is None or value < int(previous["value"]):
                held[side] = {"value": value, "since": now.isoformat()}
            elif now - since >= held_for:
                bars[side] = min(int(previous["value"]), accepted[index])
        else:
            held.pop(side, None)

    for index, side in enumerate(SIDES):
        if bars[side] > pushed[index]:
            messages.append(GoalMessage("goal", side, bars["home"], bars["away"], generation, bars[side]))
            held.pop(side, None)

    state.update({"home": bars["home"], "away": bars["away"], "generation": generation, "held": held})
    return state, messages


def _baseline(state: dict[str, Any], accepted: tuple[int, int]) -> dict[str, Any]:
    """Rule 2: the first evaluation remembers the score and says nothing."""
    state.update(
        {
            "home": accepted[0],
            "away": accepted[1],
            "generation": int(state.get("generation") or 0),
            "held": {},
        }
    )
    return state


def _values(readings: Sequence[Reading], side: Side) -> list[int]:
    """One side's scores, sorted. A reading without both sides is not a score."""
    values: list[int] = []
    for reading in readings:
        home, away = reading.home, reading.away
        if home is None or away is None:
            continue
        values.append(home if side == "home" else away)
    return sorted(values)


def _copy_held(stored: object) -> dict[str, dict[str, Any]]:
    if not isinstance(stored, dict):
        return {}
    return {side: dict(value) for side, value in stored.items() if isinstance(value, dict)}


def _since(held: Mapping[str, Any]) -> datetime | None:
    """The hold's start; ``None`` for a stored value that doesn't parse, so the hold starts again."""
    try:
        return datetime.fromisoformat(str(held["since"]))
    except (KeyError, ValueError):
        return None
