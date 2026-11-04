"""The cross-check as one pure function (SD §6.7, the table; 005 contracts/live-pipeline.md).

A new score goes out only when both sources show it, or, with one source usable, when that source
shows it in two polls in a row. Status and minute come from FilGoal when it's usable, otherwise from
YallaKora, and need no second source.

A cycle passes ``unavailable`` only for a source that is down or failed validation. A source that
merely failed this cycle, below ``LIVE_DOWN_AFTER_FAILURES``, comes in as ``not_covering``: it has
nothing to say this time, and one bad request must not send a match to the clock.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from app.live.types import FINAL_STATUSES, Candidate, Decision, LiveState, Score, SideInput, SourceReading

SINGLE_SOURCE_POLLS = 2
BOTH_DOWN = "both_down"

# How far through a match a state is, for spotting a status that moves backwards.
_RANKS: dict[tuple[str, str | None], int] = {
    ("scheduled", None): 0,
    ("postponed", None): 0,
    ("live", "1H"): 1,
    ("live", None): 1,
    ("halftime", None): 2,
    ("live", "2H"): 3,
    ("extra_time", "ET1"): 4,
    ("extra_time", None): 4,
    ("extra_time", "ET2"): 5,
    ("penalties", None): 6,
}
_FINAL_RANK = 7


def _rank(status: str | None, period: str | None) -> int:
    if status in FINAL_STATUSES:
        return _FINAL_RANK
    return _RANKS.get((status or "scheduled", period), _RANKS.get((status or "scheduled", None), 0))


def disagree_key(match_id: int) -> str:
    return f"disagree:{match_id}"


def _next_candidate(state: LiveState, score: Score, source: str, now: datetime) -> Candidate:
    """The same score from the same source counts another poll; anything else starts over."""
    held = state.candidate
    if held is not None and held.score == score and held.source == source:
        return Candidate(score, source, held.first_seen_at, held.polls + 1)
    return Candidate(score, source, now, 1)


def _is_baseline(state: LiveState, score: Score) -> bool:
    """A match's first 0–0 is the starting point, not news: nothing can be wrong by showing it."""
    return state.confirmed is None and score.is_nil


def _settled(state: LiveState, *, confirm: Score | None = None) -> Decision:
    return Decision(confirm=confirm, close_problems=(disagree_key(state.match_id), BOTH_DOWN))


def _one_source(state: LiveState, reading: SourceReading, now: datetime) -> Decision:
    score = reading.score
    if score is None or score == state.confirmed:
        return _settled(state)
    if _is_baseline(state, score):
        return _settled(state, confirm=score)
    candidate = _next_candidate(state, score, reading.source, now)
    if candidate.polls >= SINGLE_SOURCE_POLLS:
        return _settled(state, confirm=score)
    return Decision(
        candidate=candidate,
        disagreement_since=state.disagreement_since,
        hold_goal_events=True,
        close_problems=(BOTH_DOWN,),
    )


def _two_sources(
    state: LiveState, primary: SourceReading, other: SourceReading, now: datetime, wait: timedelta
) -> Decision:
    first, second = primary.score, other.score
    if first == second:
        if first is None or first == state.confirmed:
            return _settled(state)
        return _settled(state, confirm=first)
    # Exactly one may have no score yet: it simply hasn't updated.
    if first is None or second is None:
        shown = first if first is not None else second
        assert shown is not None  # first != second, so one of them has a score
        if shown == state.confirmed:
            return _settled(state)
        if _is_baseline(state, shown):
            return _settled(state, confirm=shown)
        source = primary.source if first is not None else other.source
        return _waiting(state, shown, source, now, wait)
    # The two differ. The one that moved away from the confirmed score is the candidate.
    if first == state.confirmed:
        return _waiting(state, second, other.source, now, wait)
    return _waiting(state, first, primary.source, now, wait)


def _waiting(state: LiveState, score: Score, source: str, now: datetime, wait: timedelta) -> Decision:
    candidate = _next_candidate(state, score, source, now)
    since = state.disagreement_since
    opened: tuple[str, ...] = ()
    if since is not None or now - candidate.first_seen_at >= wait:
        since = since or now
        opened = (disagree_key(state.match_id),)
    return Decision(
        candidate=candidate,
        disagreement_since=since,
        hold_goal_events=True,
        open_problems=opened,
        close_problems=(BOTH_DOWN,),
    )


def _with_status(state: LiveState, reading: SourceReading, decision: Decision) -> Decision:
    """Adds the status to write: a backward move needs two polls, and a final state waits for its score."""
    status, period = reading.status, reading.period
    moves_back = _rank(status, period) < _rank(state.status, state.period)
    if moves_back and state.previous_status != (status, period):
        return decision
    pending = decision.candidate is not None and decision.disagreement_since is None
    if status in FINAL_STATUSES and pending:
        return decision
    return Decision(
        write_status=True,
        status=status,
        period=period,
        minute=reading.minute,
        status_label=reading.status_label,
        status_reading=reading,
        confirm=decision.confirm,
        candidate=decision.candidate,
        disagreement_since=decision.disagreement_since,
        hold_goal_events=decision.hold_goal_events,
        open_problems=decision.open_problems,
        close_problems=decision.close_problems,
    )


def decide(
    state: LiveState,
    filgoal: SideInput,
    yallakora: SideInput,
    now: datetime,
    *,
    wait: timedelta,
) -> Decision:
    """What one poll means for one match. Pure, so every row of the table is a plain test."""
    if filgoal.kind == "unavailable" and yallakora.kind == "unavailable":
        return Decision(fallback=True, open_problems=(BOTH_DOWN,))
    readings = [side.reading for side in (filgoal, yallakora) if side.kind == "valid" and side.reading is not None]
    if not readings:
        # Nobody has this match right now, and at least one source is up: nothing changes. A feed
        # row left like this reaches the watchdog, so it can't stay stale.
        return Decision(
            candidate=state.candidate,
            disagreement_since=state.disagreement_since,
            hold_goal_events=state.candidate is not None,
        )
    primary = readings[0]
    decision = (
        _two_sources(state, primary, readings[1], now, wait) if len(readings) == 2 else _one_source(state, primary, now)
    )
    return _with_status(state, primary, decision)
