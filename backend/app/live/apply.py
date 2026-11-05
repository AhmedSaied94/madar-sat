"""Writes one ``Decision`` for one match. The caller owns the transaction (SD §6.7, research R5, R6).

``manual`` wins until cleared, and ``locked_fields`` are skipped per field. The ``live`` version is
the last write and only moves when something a client reads changed. Nothing here is audited and no
outbox row is written on D5 (FR-014).
"""

from __future__ import annotations

import logging
from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.adapters.health import bump_datasets
from app.db.models import Match, MatchEvent, MatchLineup, MatchLiveState, MatchSourceReading
from app.domain.lockable import STATUS_COLUMNS
from app.domain.status import STATUS_POSTPONED
from app.live.types import GOAL_TYPES, SOURCES, Candidate, Decision, Event, LineupSide, LiveState, Score, SourceReading

log = logging.getLogger(__name__)

LIVE_DATASET = "live"


def _last_primary(session: Session, match_id: int) -> MatchSourceReading | None:
    """The reading status came from in the last poll: every source read in one poll shares its ``read_at``."""
    rows = {
        row.source: row
        for row in session.scalars(select(MatchSourceReading).where(MatchSourceReading.match_id == match_id))
    }
    if not rows:
        return None
    latest = max(row.read_at for row in rows.values())
    return next(rows[source] for source in SOURCES if source in rows and rows[source].read_at == latest)


def load_state(session: Session, match: Match) -> LiveState:
    """What ``decide`` needs to remember, from ``match_live_state`` and the last poll's primary reading."""
    row = session.get(MatchLiveState, match.id)
    previous = _last_primary(session, match.id)
    confirmed = None
    if row is not None and row.confirmed_home is not None and row.confirmed_away is not None:
        confirmed = Score(row.confirmed_home, row.confirmed_away, row.confirmed_home_pen, row.confirmed_away_pen)
    return LiveState(
        match_id=match.id,
        status=match.status,
        period=match.period,
        confirmed=confirmed,
        candidate=Candidate.from_json(row.candidate) if row is not None and row.candidate else None,
        disagreement_since=row.disagreement_since if row is not None else None,
        previous_status=(previous.status, previous.period) if previous is not None else None,
        previous_primary=previous.source if previous is not None else None,
    )


def to_clock(match: Match, now: datetime) -> bool:
    """Back to the clock estimate, leaving ``match_live_state`` with the score. ``True`` when it moved.

    Only a ``feed`` row moves. A locked status or score stays too: a person answered for it, and
    ``ck_matches_clock_no_score`` couldn't hold while keeping it. A postponed match stays as stored:
    the clock would show a match that never kicked off as live, then finished.
    """
    if match.status_source != "feed" or match.status == STATUS_POSTPONED:
        return False
    if STATUS_COLUMNS & set(match.locked_fields or ()):
        log.info("live_fallback_skipped", extra={"match_id": match.id, "why": "locked"})
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
    row.candidate = decision.candidate.as_json() if decision.candidate is not None else None
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
            session.add(
                MatchSourceReading(match_id=match_id, source=reading.source, read_at=now, changed_at=now, **values)
            )
            continue
        row.read_at = now
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


def _write_events(session: Session, match_id: int, reading: SourceReading, hold_goals: bool) -> bool:
    """Diff by the source's event id: idempotent. A held goal neither appears nor disappears."""
    if reading.events is None:
        return False
    existing = {
        row.external_id: row
        for row in session.scalars(
            select(MatchEvent).where(MatchEvent.match_id == match_id, MatchEvent.source == reading.source)
        )
    }
    wanted = {event.external_id: event for event in reading.events}
    changed = False
    for external_id, row in existing.items():
        if external_id not in wanted and not (hold_goals and row.type in GOAL_TYPES):
            session.delete(row)
            changed = True
    for external_id, event in wanted.items():
        if hold_goals and event.type in GOAL_TYPES:
            continue
        changed |= _write_event(session, match_id, reading.source, existing.get(external_id), event)
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
    if (row.formation, row.players, row.source) == (value.formation, players, source):
        return False
    row.formation, row.players, row.source, row.updated_at = value.formation, players, source, now
    return True


def _write_lineups(session: Session, match_id: int, reading: SourceReading, now: datetime) -> bool:
    if reading.lineups is None:
        return False
    home = _write_side(session, match_id, "home", reading.lineups.home, reading.source, now)
    away = _write_side(session, match_id, "away", reading.lineups.away, reading.source, now)
    return home or away


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
    has_page_slot: bool = False,
) -> bool:
    """Store the readings and the memory, then write the row, events and lineups.

    A fallback leaves the memory alone: the confirmed score must be there on recovery, and a pending
    goal stays pending. Returns ``True`` when the ``live`` version moved.
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
            changed = to_clock(match, now)
        else:
            changed = _write_status(match, decision, now)
            changed = _write_score(match, _confirmed(row)) or changed
    for reading in readings:
        changed = _write_events(session, match.id, reading, decision.hold_goal_events) or changed
        changed = _write_lineups(session, match.id, reading, now) or changed
    if changed:
        bump_datasets(session, [LIVE_DATASET])
    return changed
