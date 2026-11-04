"""``/v1/live`` read query."""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import Select, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Match
from app.domain.status import derive_status
from app.schemas import public as s
from app.services.matches import match_score

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
            Match.kickoff_at.between(now - FEED_WINDOW_BEFORE, now + WINDOW_AFTER),
            or_(Match.kickoff_at >= now - WINDOW_BEFORE, Match.status_source == "feed"),
            Match.status.not_in(SETTLED_STATUSES),
        )
        .order_by(Match.kickoff_at.asc(), Match.id.asc())
    )


async def list_live(session: AsyncSession, now: datetime) -> list[s.LiveState]:
    rows = await session.execute(live_window_query(now))
    result: list[s.LiveState] = []
    for m in rows.scalars():
        d = derive_status(m, now)
        result.append(
            s.LiveState(
                match_id=m.id,
                status=d.status,
                estimated=d.estimated,
                period=m.period if not d.estimated else None,
                minute=m.minute if not d.estimated else None,
                score=match_score(m) if not d.estimated else None,
                status_label=m.status_label,
                status_updated_at=m.status_updated_at,
            )
        )
    return result
