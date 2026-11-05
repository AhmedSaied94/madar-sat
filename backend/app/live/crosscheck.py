"""The cross-check as one pure function (SD §6.7, the table; 005 contracts/live-pipeline.md).

A new score goes out only when both sources show it, or, with one source usable, when that source
shows it in two polls in a row. Status and minute come from FilGoal when it's usable, otherwise from
YallaKora, and need no second source. A final status is the exception: it ends polling, so it waits
until no candidate or disagreement is open, or a wrong score would stay for good (B1-R1-1).

Penalties are compared only when both sources carry them. When only one does, they go by the
one-source rule, and a source without them never erases confirmed ones.

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


def _adds_nothing(score: Score, confirmed: Score | None) -> bool:
    """The same goals, and no penalties that differ. A list row has no penalties to take away."""
    if confirmed is None or score.goals != confirmed.goals:
        return False
    return not score.has_penalties or score == confirmed


def _held(state: LiveState) -> Decision:
    """The open candidate stays exactly as it is, and with it the wait for a final status."""
    return Decision(
        candidate=state.candidate,
        disagreement_since=state.disagreement_since,
        hold_goal_events=True,
        close_problems=(BOTH_DOWN,),
    )


def _drops_penalties(state: LiveState, score: Score) -> bool:
    """A reading with the same goals and no penalties, while penalties wait: a list row, not an answer."""
    pending = state.candidate
    if pending is None or score.has_penalties:
        return False
    return pending.score.has_penalties and pending.score.goals == score.goals


def _nothing_new(state: LiveState, source: str, score: Score | None = None) -> Decision:
    """A source repeating the confirmed score settles things, unless another source holds a newer one.

    That source may only have failed this poll. The lagging one, alone, is no answer to it. Nor is a
    page-less reading from the source that holds pending penalties: once a final status is written the
    match is never polled again, so dropping them here would lose them for good.
    """
    if state.candidate is not None and state.candidate.source != source:
        return _held(state)
    if score is not None and _drops_penalties(state, score):
        return _held(state)
    return _settled(state)


def _one_source(state: LiveState, reading: SourceReading, now: datetime) -> Decision:
    score = reading.score
    if score is None or _adds_nothing(score, state.confirmed):
        return _nothing_new(state, reading.source, score)
    if _is_baseline(state, score):
        return _settled(state, confirm=score)
    candidate = _next_candidate(state, score, reading.source, now)
    # A disagreement ends only on agreement: a source going quiet isn't the other one conceding.
    if candidate.polls >= SINGLE_SOURCE_POLLS and state.disagreement_since is None:
        return _settled(state, confirm=score)
    return Decision(
        candidate=candidate,
        disagreement_since=state.disagreement_since,
        hold_goal_events=True,
        close_problems=(BOTH_DOWN,),
    )


def _goals_agree(first: Score, second: Score) -> bool:
    """The same goals, and the same penalties if both carry them."""
    if first.goals != second.goals:
        return False
    return first == second or not (first.has_penalties and second.has_penalties)


def _agreed(state: LiveState, shown: Score, *, carrier: str | None, now: datetime) -> Decision:
    """Both show these goals. ``carrier`` is the one source that also has penalties, if only one does."""
    if carrier is None and _drops_penalties(state, shown):
        return _held(state)
    if _adds_nothing(shown, state.confirmed):
        return _settled(state)
    if carrier is None:
        return _settled(state, confirm=shown)
    candidate = _next_candidate(state, shown, carrier, now)
    if candidate.polls >= SINGLE_SOURCE_POLLS:
        return _settled(state, confirm=shown)
    new_goals = state.confirmed is None or state.confirmed.goals != shown.goals
    return Decision(
        confirm=shown.goals if new_goals else None,
        candidate=candidate,
        hold_goal_events=True,
        close_problems=(disagree_key(state.match_id), BOTH_DOWN),
    )


def _two_sources(
    state: LiveState, primary: SourceReading, other: SourceReading, now: datetime, wait: timedelta
) -> Decision:
    first, second = primary.score, other.score
    if first is None and second is None:
        return _settled(state)
    # Exactly one may have no score yet: it simply hasn't updated.
    if first is None or second is None:
        shown = first if first is not None else second
        assert shown is not None  # the case above took both being None
        source = primary.source if first is not None else other.source
        if _adds_nothing(shown, state.confirmed):
            return _nothing_new(state, source, shown)
        if _is_baseline(state, shown):
            return _settled(state, confirm=shown)
        return _waiting(state, shown, source, now, wait)
    if _goals_agree(first, second):
        if first.has_penalties == second.has_penalties:
            return _agreed(state, first, carrier=None, now=now)
        if first.has_penalties:
            return _agreed(state, first, carrier=primary.source, now=now)
        return _agreed(state, second, carrier=other.source, now=now)
    # The two differ. The one that moved away from the confirmed score is the candidate.
    if _adds_nothing(first, state.confirmed):
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
    """Adds the status to write: a backward move needs two polls, and a final state waits for its score.

    Both polls of a backward move count only with this source as the primary: a source that just took
    over because the other failed once may have been lagging all along.
    """
    status, period = reading.status, reading.period
    moves_back = _rank(status, period) < _rank(state.status, state.period)
    said_it_as_primary = state.previous_primary == reading.source and state.previous_status == (status, period)
    if moves_back and not said_it_as_primary:
        return decision
    score_open = decision.candidate is not None or decision.disagreement_since is not None
    if status in FINAL_STATUSES and score_open:
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
