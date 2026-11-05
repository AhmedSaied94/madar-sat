"""Writes one ``Decision`` for one match. The caller owns the transaction (SD §6.7, research R5, R6).

``manual`` wins until cleared, and ``locked_fields`` are skipped per field. The ``live`` version is
the last write and only moves when something a client reads changed. Nothing here is audited and no
outbox row is written on D5 (FR-014).
"""

from __future__ import annotations

import logging
from collections import Counter
from collections.abc import Sequence
from dataclasses import replace
from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.adapters.health import bump_datasets
from app.db.models import Match, MatchEvent, MatchLineup, MatchLiveState, MatchSourceReading, MatchStats
from app.domain.lockable import STATUS_COLUMNS
from app.domain.status import STATUS_POSTPONED
from app.live.crosscheck import next_peak
from app.live.types import GOAL_TYPES, SOURCES, Decision, Event, LineupSide, LiveState, Peak, Score, SourceReading

log = logging.getLogger(__name__)

LIVE_DATASET = "live"
_SECOND_HALF_ON = frozenset({"extra_time", "penalties"})


def load_state(session: Session, match: Match) -> LiveState:
    """What ``decide`` needs to remember, from the row, ``match_live_state`` and each source's peak."""
    peaks = {
        row.source: Peak(row.peak_minute, row.peak_period)
        for row in session.scalars(
            select(MatchSourceReading).where(
                MatchSourceReading.match_id == match.id, MatchSourceReading.peak_minute.is_not(None)
            )
        )
        if row.peak_minute is not None
    }
    row = session.get(MatchLiveState, match.id)
    stored = LiveState(
        match_id=match.id,
        status=match.status,
        period=match.period,
        minute=match.minute,
        status_label=match.status_label,
        peaks=peaks,
    )
    if row is None:
        return stored
    return replace(
        stored,
        confirmed=_confirmed(row),
        drop_since=row.drop_since,
        status_drop_since=row.status_drop_since,
        score_first_source=row.score_first_source,
        score_changed_at=row.score_changed_at,
        fulltime_source=row.fulltime_source,
        fulltime_since=row.fulltime_since,
        finish_wait_since=row.finish_wait_since,
        disagreement_since=row.disagreement_since,
    )


def reached_second_half(match: Match) -> bool:
    """Second half, extra time or penalties. ``live`` with no period says nothing about the half."""
    return match.status in _SECOND_HALF_ON or (match.status == "live" and match.period == "2H")


def to_clock(match: Match, now: datetime, *, stuck_after: timedelta) -> bool:
    """Back to the clock estimate, leaving ``match_live_state`` with the score. ``True`` when it moved.

    Only a ``feed`` row moves. A locked status or score stays too: a person answered for it, and
    ``ck_matches_clock_no_score`` couldn't hold while keeping it. A postponed match stays as stored:
    the clock would show a match that never kicked off as live, then finished. Past the stuck limit, a
    match that reached its second half is finished by the watchdog instead (FR-010): it must not lose its
    score or go back to scheduled.
    """
    if match.status_source != "feed" or match.status == STATUS_POSTPONED:
        return False
    if STATUS_COLUMNS & set(match.locked_fields or ()):
        log.info("live_fallback_skipped", extra={"match_id": match.id, "why": "locked"})
        return False
    if match.kickoff_at is not None and match.kickoff_at < now - stuck_after and reached_second_half(match):
        log.info("live_fallback_skipped", extra={"match_id": match.id, "why": "past_stuck_limit"})
        return False
    match.status_source = "clock"
    match.status = "scheduled"
    match.period = match.minute = match.status_label = None
    match.home_score = match.away_score = match.home_pen = match.away_pen = None
    match.status_updated_at = now
    return True


def _write_memory(row: MatchLiveState, decision: Decision, now: datetime) -> None:
    if decision.confirm is not None:
        row.confirmed_home = decision.confirm.home
        row.confirmed_away = decision.confirm.away
        row.confirmed_home_pen = decision.confirm.home_pen
        row.confirmed_away_pen = decision.confirm.away_pen
    row.candidate = None  # the column stays for rollback (0008)
    row.drop_since = decision.drop_since
    row.status_drop_since = decision.status_drop_since
    row.score_first_source = decision.score_first_source
    row.score_changed_at = decision.score_changed_at
    row.fulltime_source = decision.fulltime_source
    row.fulltime_since = decision.fulltime_since
    row.finish_wait_since = decision.finish_wait_since
    row.disagreement_since = decision.disagreement_since
    row.updated_at = now


def _store_readings(session: Session, match_id: int, readings: Sequence[SourceReading], now: datetime) -> None:
    for reading in readings:
        score = reading.score
        values = {
            "status": reading.status,
            "period": reading.period,
            "minute": reading.minute,
            "home_score": score.home if score else None,
            "away_score": score.away if score else None,
            "home_pen": score.home_pen if score else None,
            "away_pen": score.away_pen if score else None,
        }
        row = session.get(MatchSourceReading, (match_id, reading.source))
        if row is None:
            peak = next_peak(None, reading)
            session.add(
                MatchSourceReading(
                    match_id=match_id,
                    source=reading.source,
                    read_at=now,
                    changed_at=now,
                    peak_minute=peak.minute if peak is not None else None,
                    peak_period=peak.period if peak is not None else None,
                    **values,
                )
            )
            continue
        row.read_at = now
        peak = next_peak(Peak(row.peak_minute, row.peak_period) if row.peak_minute is not None else None, reading)
        if peak is not None:
            row.peak_minute, row.peak_period = peak.minute, peak.period
        if any(getattr(row, name) != value for name, value in values.items()):
            row.changed_at = now
            for name, value in values.items():
                setattr(row, name, value)


def _write_status(match: Match, decision: Decision, now: datetime) -> bool:
    """``True`` when a column changed. A clock row only leaves the clock for a state it can't show."""
    if not decision.write_status or "status" in (match.locked_fields or ()):
        return False
    if match.status_source == "clock" and decision.status == "scheduled":
        return False
    values = {
        "status_source": "feed",
        "status": decision.status,
        "period": decision.period,
        "minute": decision.minute,
        "status_label": decision.status_label,
    }
    if all(getattr(match, name) == value for name, value in values.items()):
        return False
    for name, value in values.items():
        setattr(match, name, value)
    match.status_updated_at = now
    return True


def _write_pair(match: Match, fields: tuple[str, str], values: tuple[int | None, int | None], locked: set[str]) -> bool:
    """One pair, skipping a locked field. ``ck_matches_scores_pair`` wants both or neither set."""
    target = tuple(
        getattr(match, field) if field in locked else value for field, value in zip(fields, values, strict=True)
    )
    if (target[0] is None) != (target[1] is None):
        return False
    changed = False
    for field, value in zip(fields, target, strict=True):
        if getattr(match, field) != value:
            setattr(match, field, value)
            changed = True
    return changed


def _write_score(match: Match, score: Score | None) -> bool:
    """The confirmed score onto a feed row, the only kind allowed one. ``True`` when a column changed."""
    if match.status_source != "feed" or score is None:
        return False
    locked = set(match.locked_fields or ())
    goals = _write_pair(match, ("home_score", "away_score"), (score.home, score.away), locked)
    pens = _write_pair(match, ("home_pen", "away_pen"), (score.home_pen, score.away_pen), locked)
    return goals or pens


def _score_side(score: Score, side: str) -> int:
    return score.home if side == "home" else score.away


def _event_gone(row: MatchEvent, stored: Counter[str], listed: Counter[str], accepted: Score | None) -> bool:
    """A goal stays while the score needs it and nothing the source lists can stand in for it (FR-011)."""
    if row.type not in GOAL_TYPES or accepted is None:
        return True
    score = _score_side(accepted, row.side)
    return stored[row.side] > score or listed[row.side] >= score


def _write_events(
    session: Session, match_id: int, reading: SourceReading, accepted: Score | None, now: datetime, hold: timedelta
) -> bool:
    """Diff by the source's event id: idempotent. A missing event goes after ``hold``, a goal with the score.

    A source can give a goal a new ID, as Goal.com does when a scorer is filled in. So while a side has a goal
    inside its hold, that side's new goals wait: the two may be one goal, and must never show together.
    """
    if reading.events is None:
        return False
    rows = session.scalars(
        select(MatchEvent).where(MatchEvent.match_id == match_id, MatchEvent.source == reading.source)
    ).all()
    existing = {row.external_id: row for row in rows}
    wanted = {event.external_id: event for event in reading.events}
    stored = Counter(row.side for row in rows if row.type in GOAL_TYPES)
    listed = Counter(event.side for event in wanted.values() if event.type in GOAL_TYPES)
    held_sides: set[str] = set()
    changed = False
    for external_id, row in existing.items():
        if external_id in wanted:
            row.missing_since = None
            continue
        row.missing_since = row.missing_since or now
        if now - row.missing_since < hold:
            if row.type in GOAL_TYPES:
                held_sides.add(row.side)
        elif _event_gone(row, stored, listed, accepted):
            if row.type in GOAL_TYPES:
                stored[row.side] -= 1
            session.delete(row)
            changed = True
    for external_id, event in wanted.items():
        row_for_event = existing.get(external_id)
        if row_for_event is None and event.type in GOAL_TYPES:
            if accepted is None or event.side in held_sides or stored[event.side] >= _score_side(accepted, event.side):
                continue  # the score hasn't got this far, or this may be the goal being held
            stored[event.side] += 1
        changed |= _write_event(session, match_id, reading.source, row_for_event, event)
    return changed


def _write_event(session: Session, match_id: int, source: str, row: MatchEvent | None, event: Event) -> bool:
    if row is None:
        session.add(
            MatchEvent(
                match_id=match_id,
                source=source,
                external_id=event.external_id,
                side=event.side,
                type=event.type,
                minute=event.minute,
                player_name=event.player,
            )
        )
        return True
    if (row.side, row.type, row.minute, row.player_name) == (event.side, event.type, event.minute, event.player):
        return False
    row.side, row.type, row.minute, row.player_name = event.side, event.type, event.minute, event.player
    return True


def _rank(source: str) -> int:
    return SOURCES.index(source) if source in SOURCES else len(SOURCES)


def _write_side(
    session: Session, match_id: int, side: str, value: LineupSide | None, source: str, now: datetime
) -> bool:
    if value is None:
        return False
    players = list(value.players)
    row = session.get(MatchLineup, (match_id, side))
    if row is None:
        session.add(
            MatchLineup(
                match_id=match_id, side=side, formation=value.formation, players=players, source=source, updated_at=now
            )
        )
        return True
    if _rank(row.source) < _rank(source):
        return False  # stored by a source earlier in the order, which keeps it even when its request failed
    if (row.formation, row.players, row.source) == (value.formation, players, source):
        return False
    row.formation, row.players, row.source, row.updated_at = value.formation, players, source, now
    return True


def _write_lineups(session: Session, match_id: int, readings: Sequence[SourceReading], now: datetime) -> bool:
    """From the first source in order that has any, so two sources don't overwrite each other each poll (R9)."""
    with_lineups = [
        reading
        for reading in readings
        if reading.lineups is not None and (reading.lineups.home is not None or reading.lineups.away is not None)
    ]
    if not with_lineups:
        return False
    reading = min(with_lineups, key=lambda item: _rank(item.source))
    assert reading.lineups is not None  # filtered above
    home = _write_side(session, match_id, "home", reading.lineups.home, reading.source, now)
    away = _write_side(session, match_id, "away", reading.lineups.away, reading.source, now)
    return home or away


def _write_stats(session: Session, match_id: int, reading: SourceReading, now: datetime) -> None:
    """Only on change, and no client reads them, so no dataset moves (R10)."""
    if reading.stats is None:
        return
    stats = list(reading.stats)
    row = session.get(MatchStats, (match_id, reading.source))
    if row is None:
        session.add(MatchStats(match_id=match_id, source=reading.source, stats=stats, updated_at=now))
    elif row.stats != stats:
        row.stats, row.updated_at = stats, now


def _confirmed(row: MatchLiveState) -> Score | None:
    if row.confirmed_home is None or row.confirmed_away is None:
        return None
    return Score(row.confirmed_home, row.confirmed_away, row.confirmed_home_pen, row.confirmed_away_pen)


def apply_decision(
    session: Session,
    match: Match,
    decision: Decision,
    *,
    readings: Sequence[SourceReading],
    now: datetime,
    drop_hold: timedelta,
    stuck_after: timedelta,
    has_page_slot: bool = False,
) -> bool:
    """Store the readings and the memory, then write the row, events, lineups and stats.

    A fallback leaves the memory alone: the accepted score must be there on recovery. Returns ``True``
    when the ``live`` version moved.
    """
    row = session.get(MatchLiveState, match.id)
    if row is None:
        row = MatchLiveState(match_id=match.id, updated_at=now)
        session.add(row)
    row.has_page_slot = has_page_slot
    _store_readings(session, match.id, readings, now)
    if readings:
        row.last_reading_at = now
    if not decision.fallback:
        _write_memory(row, decision, now)

    changed = False
    if match.status_source != "manual":
        if decision.fallback:
            changed = to_clock(match, now, stuck_after=stuck_after)
        else:
            changed = _write_status(match, decision, now)
            changed = _write_score(match, _confirmed(row)) or changed
    accepted = _confirmed(row)
    for reading in readings:
        changed = _write_events(session, match.id, reading, accepted, now, drop_hold) or changed
        _write_stats(session, match.id, reading, now)
    changed = _write_lineups(session, match.id, readings, now) or changed
    if changed:
        bump_datasets(session, [LIVE_DATASET])
    return changed
