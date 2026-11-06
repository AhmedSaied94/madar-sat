"""A2's dashboard: what today is missing (research R24, contracts/admin-api.md).

``recent_changes`` comes from ``audit_log``, which has no dataset version, so the route's ``ETag``
carries a 60 s bucket on top of ``matches``, ``channels`` and ``sources``.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import validation_failed
from app.db.models import AdminUser, AuditLog, Channel, Competition, Match, MatchChannel
from app.schemas import admin as a
from app.services.admin import sources as source_service
from app.services.common import hidden_names, visible_link
from app.services.matches import MATCH_SPORT

MAX_SPAN = timedelta(days=2)
RECENT_CHANGES = 10


def check_window(from_dt: datetime, to_dt: datetime) -> None:
    """The dashboard shows at most two days (contracts/admin-api.md)."""
    if from_dt.tzinfo is None or to_dt.tzinfo is None or from_dt >= to_dt or to_dt - from_dt > MAX_SPAN:
        raise validation_failed([{"loc": ["query", "to"], "type": "window"}])


async def dashboard(session: AsyncSession, now: datetime, from_dt: datetime, to_dt: datetime) -> a.Dashboard:
    check_window(from_dt, to_dt)

    visible = (
        select(MatchChannel.match_id)
        .join(Channel, Channel.id == MatchChannel.channel_id)
        .where(visible_link(MatchChannel, Channel, hidden_names()))
    )
    rows = (
        await session.execute(
            select(Match, Competition.priority)
            .outerjoin(Competition, Competition.id == Match.competition_id)
            .where(
                # FR-039: another sport has its own channels and never counts as missing here (R12).
                Match.sport == MATCH_SPORT,
                Match.kickoff_at.is_not(None),
                Match.kickoff_at >= from_dt,
                Match.kickoff_at < to_dt,
                Match.id.not_in(visible),
            )
            .order_by(Competition.priority.asc().nulls_last(), Match.kickoff_at.asc(), Match.id)
        )
    ).all()

    groups: list[a.DashboardGroup] = []
    for match, priority in rows:
        key = match.competition_id
        if not groups or groups[-1].competition.id != key:
            groups.append(
                a.DashboardGroup(
                    competition=a.DashboardCompetition(
                        id=match.competition_id, name=match.competition_name, priority=priority
                    ),
                    matches=[],
                )
            )
        groups[-1].matches.append(
            a.DashboardMatch(
                id=match.id,
                kickoff_at=match.kickoff_at,
                home=match.home_team_name,
                away=match.away_team_name,
            )
        )

    changes = (
        await session.execute(
            select(AuditLog, AdminUser.name)
            .outerjoin(AdminUser, AdminUser.id == AuditLog.admin_user_id)
            .order_by(AuditLog.id.desc())
            .limit(RECENT_CHANGES)
        )
    ).all()
    recent = [
        a.RecentChange(
            at=entry.created_at,
            by=a.ChangedBy(
                kind="source" if entry.source is not None else "admin",
                name=entry.source or admin_name or "system",
            ),
            entity=entry.entity,
            entity_id=entry.entity_id,
            action=entry.action,
        )
        for entry, admin_name in changes
    ]

    return a.Dashboard(
        missing_channels=groups,
        missing_channels_count=sum(len(group.matches) for group in groups),
        placeholders_to_complete=await source_service.count_placeholders(session),
        sources=await source_service.health(session, now),
        recent_changes=recent,
    )
