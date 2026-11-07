"""``/v1/live`` read query."""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import Select, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Match, MatchEvent
from app.domain.status import STATUS_POSTPONED, derive_status
from app.schemas import public as s
from app.services.match_detail import EVENT_SOURCES
from app.services.matches import MATCH_SPORT, match_score

WINDOW_BEFORE = timedelta(minutes=150)
WINDOW_AFTER = timedelta(minutes=10)
# Extra time and penalties can outlast the start window, so a feed match stays until this limit.
FEED_WINDOW_BEFORE = timedelta(minutes=210)
# Stored statuses no longer live; must match the predicate of matches_live_window_idx.
SETTLED_STATUSES = ("finished", "cancelled", "abandoned")


def live_window_query(now: datetime) -> Select[Match]:
    """Unsettled matches with ``kickoff_at ∈ [now − 150 min, now + 10 min]``, or back to now − 210 min on ``feed``."""
    return (
        select(Match)
        .where(
            # One sport only: /v1/live, the scheduler, the poller and the watchdog share this query (R12).
            Match.sport == MATCH_SPORT,
            Match.kickoff_at.between(now - FEED_WINDOW_BEFORE, now + WINDOW_AFTER),
            or_(Match.kickoff_at >= now - WINDOW_BEFORE, Match.status_source == "feed"),
            Match.status.not_in(SETTLED_STATUSES),
        )
        .order_by(Match.kickoff_at.asc(), Match.id.asc())
    )


def poll_window_query(now: datetime) -> Select[Match]:
    """What the poller reads. A postponed match stays on ``/v1/live`` as stored, but nothing more will come."""
    return live_window_query(now).where(Match.status != STATUS_POSTPONED)


async def event_counts(session: AsyncSession, match_ids: list[int]) -> dict[int, int]:
    """Rows of the one event source ``match_detail`` serves, per match (R13)."""
    if not match_ids:
        return {}
    rows = await session.execute(
        select(MatchEvent.match_id, MatchEvent.source, func.count())
        .where(MatchEvent.match_id.in_(match_ids), MatchEvent.source.in_(EVENT_SOURCES))
        .group_by(MatchEvent.match_id, MatchEvent.source)
    )
    by_match: dict[int, dict[str, int]] = {}
    for match_id, source, count in rows:
        by_match.setdefault(match_id, {})[source] = count
    return {
        match_id: next((counts[source] for source in EVENT_SOURCES if source in counts), 0)
        for match_id, counts in by_match.items()
    }


async def list_live(session: AsyncSession, now: datetime) -> list[s.LiveState]:
    rows = list((await session.execute(live_window_query(now))).scalars())
    counts = await event_counts(session, [m.id for m in rows])
    result: list[s.LiveState] = []
    for m in rows:
        d = derive_status(m, now)
        result.append(
            s.LiveState(
                match_id=m.id,
                status=d.status,
                estimated=d.estimated,
                period=m.period if not d.estimated else None,
                minute=m.minute if not d.estimated else None,
                score=match_score(m) if not d.estimated else None,
                event_count=0 if d.estimated else counts.get(m.id, 0),
                status_label=m.status_label,
                status_updated_at=m.status_updated_at,
            )
        )
    return result
