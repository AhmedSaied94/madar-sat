"""Which of our matches a reading is about (research R7, spec FR-022a).

A wrong link publishes another match's score, so both teams must resolve, in that order, and exactly
one match must have them with a kickoff within 45 minutes. A row with no time of its own, as FilGoal's is
once a match starts, needs that one match inside the poll window instead. Anything less isn't linked.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.adapters.resolve import resolve_team
from app.db.models import Match, MatchExternalId
from app.live.types import FINAL_STATUSES, SourceReading

log = logging.getLogger(__name__)

KICKOFF_TOLERANCE = timedelta(minutes=45)
RecordUnresolved = Callable[..., Any]


def _queue_nothing(_session: Session, **_values: Any) -> None:
    return None


def _team_id(session: Session, reading: SourceReading, name: str, record: RecordUnresolved) -> int | None:
    resolved = resolve_team(
        session, external_id=None, name=name, competition_name=reading.competition, source=reading.source
    )
    if resolved.entity_id is None:
        record(
            session,
            source=reading.source,
            kind="team",
            name=name,
            competition=reading.competition,
            context={"home": reading.home, "away": reading.away, "external_id": reading.external_id},
        )
    team_id: int | None = resolved.entity_id
    return team_id


def link_reading(
    session: Session,
    reading: SourceReading,
    *,
    record_unresolved: RecordUnresolved,
    window: tuple[datetime, datetime],
) -> int | None:
    """The match id, writing the external id on a new link. A row outside ``window`` isn't looked up."""
    known = session.scalar(
        select(MatchExternalId.match_id).where(
            MatchExternalId.source == reading.source, MatchExternalId.external_id == reading.external_id
        )
    )
    if known is not None:
        return known
    kickoff = reading.kickoff_at
    if kickoff is not None and not window[0] <= kickoff <= window[1]:
        return None
    # A list keeps yesterday's results with no time on them: worth linking, but not worth an editor's queue.
    record = _queue_nothing if kickoff is None and reading.status in FINAL_STATUSES else record_unresolved
    home = _team_id(session, reading, reading.home, record)
    away = _team_id(session, reading, reading.away, record)
    if home is None or away is None:
        return None
    earliest, latest = window if kickoff is None else (kickoff - KICKOFF_TOLERANCE, kickoff + KICKOFF_TOLERANCE)
    found = session.scalars(
        select(Match.id)
        .where(Match.home_team_id == home, Match.away_team_id == away, Match.kickoff_at.between(earliest, latest))
        .limit(2)
    ).all()
    if len(found) != 1:
        log.info(
            "live_not_linked",
            extra={"source": reading.source, "external_id": reading.external_id, "matches": len(found)},
        )
        return None
    session.execute(
        insert(MatchExternalId)
        .values(source=reading.source, external_id=reading.external_id, match_id=found[0], url=reading.page_path)
        .on_conflict_do_nothing()
    )
    return found[0]
