"""The live rules as one pure function (031 contracts/live-rules.md, research R2, R3, R5, R6).

A higher score or a later status from any usable source goes out in the first poll that shows it, so a
lagging source can't hold fans back. A lower score or an earlier status waits until no usable source shows
the current one for ``drop_hold``, so a source's glitch can't take a goal away. Full time waits for a second
source or ``fulltime_hold``, because polling ends with it and only a person can undo it.

A cycle passes ``unavailable`` only for a source that is down or failed validation. A source that merely
failed this cycle comes in as ``not_covering``: it has nothing to say this time, and one bad request must not
send a match to the clock. A disabled source has no entry at all.
"""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass, replace
from datetime import datetime, timedelta
from itertools import combinations

from app.live.sources.common import minute_value
from app.live.types import FINAL_STATUSES, SOURCES, Decision, LiveState, Peak, Score, SideInput, SourceReading

ORDER = SOURCES
BOTH_DOWN = "both_down"
# A minute further below its source's peak than this is FilGoal's clock wrapping, not a late answer (R4).
MINUTE_SLACK = 5

FINISHED = "finished"
POSTPONED = "postponed"
EXTRA_STATUSES = frozenset({"extra_time", "penalties"})
PEAK_STATUSES = frozenset({"live", "extra_time"})

# How far through a match a stage is. ``finished`` comes after all of them, and is held back (R5).
_RANKS: dict[tuple[str, str | None], int] = {
    ("scheduled", None): 0,
    (POSTPONED, None): 0,
    ("live", "1H"): 1,
    ("halftime", None): 2,
    ("live", "2H"): 3,
    ("extra_time", "ET1"): 4,
    ("extra_time", None): 4,
    ("extra_time", "ET2"): 5,
    ("penalties", None): 6,
}
_FIRST_HALF = _RANKS[("live", "1H")]


def disagree_key(match_id: int) -> str:
    return f"disagree:{match_id}"


def next_peak(peak: Peak | None, reading: SourceReading) -> Peak | None:
    """A source's highest minute. It never goes down, and FilGoal's clock runs on through half-time (R4)."""
    if reading.status not in PEAK_STATUSES:
        return peak
    value = minute_value(reading.minute)
    if value is None or (peak is not None and value <= peak.minute):
        return peak
    return Peak(value, reading.period)


# ------------------------------------------------------------------------------------------- the score


def _covers(score: Score, other: Score) -> bool:
    """Each side at least the other's, and penalties too when both carry them. 0–2 doesn't cover 1–1."""
    if score.home < other.home or score.away < other.away:
        return False
    if not (score.has_penalties and other.has_penalties):
        return True
    return (score.home_pen or 0) >= (other.home_pen or 0) and (score.away_pen or 0) >= (other.away_pen or 0)


def _adds_to(score: Score, accepted: Score) -> bool:
    """Something new. A list row has no penalties to take away, so their absence adds nothing."""
    if score.goals != accepted.goals:
        return True
    return score.has_penalties and (score.home_pen, score.away_pen) != (accepted.home_pen, accepted.away_pen)


def _same(first: Score, second: Score) -> bool:
    """The same goals, and the same penalties if both carry them."""
    if first.goals != second.goals:
        return False
    return first == second or not (first.has_penalties and second.has_penalties)


def _highest(readings: Sequence[SourceReading]) -> SourceReading:
    """The most goals, then the most penalties. ``max`` keeps the first on a tie, and readings are in ``ORDER``."""

    def weight(reading: SourceReading) -> tuple[int, int]:
        score = reading.score
        assert score is not None  # only readings with a score get here
        return score.home + score.away, (score.home_pen or 0) + (score.away_pen or 0)

    return max(readings, key=weight)


def _counted(state: LiveState, readings: Sequence[SourceReading]) -> list[SourceReading]:
    """Usable readings with a score. A lower one on an unknown row is as if the source had no score (FR-001)."""
    counted = []
    for reading in readings:
        if reading.score is None:
            continue
        if reading.unknown_status is not None:
            lower = state.confirmed is not None and not _covers(reading.score, state.confirmed)
            baseline = state.confirmed is None and reading.score.is_nil
            if lower or baseline:
                continue
        counted.append(reading)
    return counted


@dataclass(frozen=True, slots=True)
class _ScoreStep:
    confirm: Score | None
    drop_since: datetime | None
    first_source: str | None
    changed_at: datetime | None


def _accepted(reading: SourceReading, accepted: Score | None, now: datetime) -> _ScoreStep:
    """A reading without penalties never erases accepted ones (B1-R1-2)."""
    score = reading.score
    assert score is not None  # only readings with a score get here
    if accepted is not None and not score.has_penalties and accepted.has_penalties:
        score = Score(score.home, score.away, accepted.home_pen, accepted.away_pen)
    return _ScoreStep(score, None, reading.source, now)


def _score_step(state: LiveState, counted: Sequence[SourceReading], now: datetime, drop_hold: timedelta) -> _ScoreStep:
    keep = _ScoreStep(None, state.drop_since, state.score_first_source, state.score_changed_at)
    accepted = state.confirmed
    if not counted:
        return keep
    if accepted is None:
        return _accepted(_highest(counted), accepted, now)
    covering = [reading for reading in counted if reading.score is not None and _covers(reading.score, accepted)]
    rises = [reading for reading in covering if reading.score is not None and _adds_to(reading.score, accepted)]
    if rises:
        return _accepted(_highest(rises), accepted, now)
    if covering:
        return replace(keep, drop_since=None)
    since = state.drop_since or now
    if now - since >= drop_hold:
        return _accepted(_highest(counted), accepted, now)
    return replace(keep, drop_since=since)


def _differ(counted: Sequence[SourceReading]) -> bool:
    scores = [reading.score for reading in counted if reading.score is not None]
    return any(not _same(first, second) for first, second in combinations(scores, 2))


# ------------------------------------------------------------------------------------- status and minute


def _rank(status: str | None, period: str | None) -> int:
    key = status or "scheduled"
    return _RANKS.get((key, period), _RANKS.get((key, None), 0))


def _stored_rank(state: LiveState) -> int:
    return _FIRST_HALF if state.status == "live" and state.period is None else _rank(state.status, state.period)


def _reading_rank(reading: SourceReading, stored: int) -> int:
    """``live`` with no period says nothing about the half: it moves a scheduled row, and shows any later stage."""
    if reading.status == "live" and reading.period is None:
        return max(stored, _FIRST_HALF)
    return _rank(reading.status, reading.period)


@dataclass(frozen=True, slots=True)
class _Stage:
    status: str
    period: str | None
    label: str | None
    showing: tuple[SourceReading, ...]  # the readings at this stage, which the minute may come from
    drop_since: datetime | None = None


def _says_only_live(reading: SourceReading) -> bool:
    """«مباشر» with no half: a source saying the match is on, and nothing about how far it's got."""
    return reading.status == "live" and reading.period is None


def _names_the_stage(showing: Sequence[SourceReading]) -> SourceReading:
    """The first at this stage that says which: «مباشر» first in ``ORDER`` mustn't hide what another knows."""
    return next((reading for reading in showing if not _says_only_live(reading)), showing[0])


def _written(readings: Sequence[SourceReading], ranks: Mapping[str, int], rank: int) -> _Stage:
    showing = tuple(reading for reading in readings if ranks[reading.source] == rank)
    first = _names_the_stage(showing)
    assert first.status is not None  # only readings with a known status get here
    return _Stage(first.status, first.period, first.status_label, showing)


def _kept_stage(state: LiveState, showing: tuple[SourceReading, ...]) -> _Stage:
    """No move. The label comes from the first source showing it, and a period fills in if the row had none."""
    if not showing:
        return _Stage(state.status, state.period, state.status_label, ())
    first = _names_the_stage(showing)
    status = POSTPONED if first.status == POSTPONED else state.status
    period = first.period or state.period
    label = state.status_label if _says_only_live(first) and state.status_label else first.status_label
    return _Stage(status, period, label, showing)


def _stage_step(
    state: LiveState,
    known: Sequence[SourceReading],
    now: datetime,
    drop_hold: timedelta,
) -> _Stage:
    """The status table. Full time has its own, and ``cancelled`` and ``postponed`` need the first usable source."""
    first = known[0] if known else None
    readings = [
        reading
        for reading in known
        if reading.status not in FINAL_STATUSES and (reading.status != POSTPONED or reading is first)
    ]
    if not readings:
        return _kept_stage(state, ())
    stored = _stored_rank(state)
    ranks = {reading.source: _reading_rank(reading, stored) for reading in readings}
    latest = max(ranks.values())
    if latest > stored:
        return _written(readings, ranks, latest)
    at_stored = tuple(reading for reading in readings if ranks[reading.source] == stored)
    if at_stored:
        return _kept_stage(state, at_stored)
    if len(readings) != len(known):
        return _kept_stage(state, ())  # a lone full time isn't an earlier stage
    since = state.status_drop_since or now
    if now - since >= drop_hold:
        return _written(readings, ranks, latest)
    return replace(_kept_stage(state, ()), drop_since=since)


def _minute(state: LiveState, showing: Sequence[SourceReading]) -> str | None:
    """From the first source at this stage with a usable minute. None clears it: a frozen one looks current."""
    for reading in showing:
        value = minute_value(reading.minute)
        if value is None:
            continue
        peak = state.peaks.get(reading.source)
        if peak is not None and peak.period == reading.period and value < peak.minute - MINUTE_SLACK:
            continue
        stored = minute_value(state.minute)
        if stored is not None and state.period == reading.period and value < stored:
            return state.minute
        return reading.minute
    return None


# ------------------------------------------------------------------------------------------- full time


@dataclass(frozen=True, slots=True)
class _FullTime:
    met: bool = False
    source: str | None = None
    since: datetime | None = None
    wait_since: datetime | None = None


def _may_be_extra_time(reading: SourceReading) -> bool:
    """No parser maps extra time yet, so an unknown status, or «مباشر» with no half, may be it (B1-R2-1)."""
    return reading.status in EXTRA_STATUSES or reading.unknown_status is not None or _says_only_live(reading)


def _fulltime_step(
    state: LiveState,
    readings: Sequence[SourceReading],
    known: Sequence[SourceReading],
    now: datetime,
    hold: timedelta,
) -> _FullTime:
    """The full-time table, whose first row that applies wins (FR-008)."""
    held = _FullTime(False, state.fulltime_source, state.fulltime_since, state.finish_wait_since)
    showing = [reading for reading in known if reading.status == FINISHED]
    if len(showing) >= 2:
        return replace(held, met=True)
    if any(_may_be_extra_time(reading) for reading in readings):
        return _FullTime()
    if showing:
        source = showing[0].source
        if source != state.fulltime_source or state.fulltime_since is None:
            return _FullTime(False, source, now)
        return replace(held, met=now - state.fulltime_since >= hold)
    if state.fulltime_source is None or any(reading.source == state.fulltime_source for reading in readings):
        return _FullTime()
    return held


def _closing(known: Sequence[SourceReading], fulltime: _FullTime) -> SourceReading | None:
    """The reading that ends the match, if one does. ``cancelled`` and ``abandoned`` need the first usable source."""
    if known and known[0].status in FINAL_STATUSES and known[0].status != FINISHED:
        return known[0]
    if fulltime.met:
        return next((reading for reading in known if reading.status == FINISHED), None)
    return None


# ------------------------------------------------------------------------------------------------ decide


def _nothing_changes(state: LiveState) -> Decision:
    return Decision(
        drop_since=state.drop_since,
        status_drop_since=state.status_drop_since,
        score_first_source=state.score_first_source,
        score_changed_at=state.score_changed_at,
        fulltime_source=state.fulltime_source,
        fulltime_since=state.fulltime_since,
        finish_wait_since=state.finish_wait_since,
        disagreement_since=state.disagreement_since,
    )


def decide(
    state: LiveState,
    sides: Mapping[str, SideInput],
    now: datetime,
    *,
    drop_hold: timedelta,
    disagree_after: timedelta,
    fulltime_hold: timedelta,
) -> Decision:
    """What one poll means for one match. Pure, so every row of the contract is a plain test."""
    if state.status in FINAL_STATUSES:
        return _nothing_changes(state)  # polling has ended, and only a person changes it
    if all(side.kind == "unavailable" for side in sides.values()):
        return Decision(fallback=True, open_problems=(BOTH_DOWN,))
    entries = (sides[source] for source in ORDER if source in sides)
    readings = [side.reading for side in entries if side.kind == "valid" and side.reading is not None]
    if not readings:
        return _nothing_changes(state)  # nobody has this match now, and the watchdog covers a row left like this

    counted = _counted(state, readings)
    score = _score_step(state, counted, now, drop_hold)
    known = [reading for reading in readings if reading.status is not None]
    fulltime = _fulltime_step(state, readings, known, now, fulltime_hold)

    differ = _differ(counted)
    since = state.disagreement_since
    if len(counted) >= 2:
        since = (since or now) if differ else None
    alert = since is not None and now - since >= disagree_after
    opened = (disagree_key(state.match_id),) if alert else ()
    closed = (BOTH_DOWN, disagree_key(state.match_id)) if len(counted) >= 2 and not differ else (BOTH_DOWN,)
    decision = Decision(
        write_status=True,
        confirm=score.confirm,
        drop_since=score.drop_since,
        score_first_source=score.first_source,
        score_changed_at=score.changed_at,
        disagreement_since=since,
        open_problems=opened,
        close_problems=closed,
    )

    closing = _closing(known, fulltime)
    wait_since = fulltime.wait_since
    if closing is not None:
        wait_since = state.finish_wait_since or now
        settled = score.drop_since is None and not differ
        if settled or now - wait_since >= drop_hold:
            # Polling ends here, so a score still in doubt stays for good: the owner hears about it (B1-R1-1).
            if differ:
                decision = replace(decision, open_problems=(disagree_key(state.match_id),))
            return replace(decision, status=closing.status, status_label=closing.status_label)

    stage = _stage_step(state, known, now, drop_hold)
    return replace(
        decision,
        status=stage.status,
        period=stage.period,
        minute=_minute(state, stage.showing),
        status_label=stage.label,
        status_drop_since=stage.drop_since,
        fulltime_source=fulltime.source,
        fulltime_since=fulltime.since,
        finish_wait_since=wait_since,
    )
