"""The A3 list: the matches of a window of at most 8 days, as editors need to see them (research R9).

Each row shows the status the app would show (derived for clock rows, with ``estimated``), how many
channels and manual broadcasters it has, and whether anything is missing. Ordered by competition
priority (nulls last), then kickoff.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.api.errors import validation_failed
from app.db.models import Commentator, Competition, Match, MatchCustomBroadcast, MatchExternalId, Team
from app.domain.status import derive_status
from app.domain.time import validate_window
from app.schemas import admin as a
from app.schemas import public as s
from app.services.admin.common import asset_urls, url_of
from app.services.matches import fetch_visible_channels, match_score, tbd_dates

logger = logging.getLogger("madar.admin")


def check_window(from_dt: datetime, to_dt: datetime) -> None:
    try:
        validate_window(from_dt, to_dt)
    except ValueError as exc:
        logger.info("admin match list refused: %s", exc)
        raise validation_failed([{"loc": ["query", "to"], "type": "window"}]) from None


async def list_rows(
    session: AsyncSession,
    now: datetime,
    from_dt: datetime,
    to_dt: datetime,
    *,
    competition_id: int | None = None,
    source: str | None = None,
    missing_channels: bool | None = None,
    status: str | None = None,
) -> list[a.AdminMatchRow]:
    check_window(from_dt, to_dt)
    conditions: list[Any] = [
        or_(
            and_(Match.kickoff_at.is_not(None), Match.kickoff_at >= from_dt, Match.kickoff_at < to_dt),
            and_(Match.time_tbd.is_(True), Match.match_date.in_(tbd_dates(from_dt, to_dt))),
        )
    ]
    if competition_id is not None:
        conditions.append(Match.competition_id == competition_id)
    if source is not None:
        conditions.append(
            or_(
                Match.source == source,
                Match.id.in_(select(MatchExternalId.match_id).where(MatchExternalId.source == source)),
            )
        )

    home_team, away_team = aliased(Team), aliased(Team)
    found = (
        await session.execute(
            select(
                Match,
                Competition.priority,
                Competition.logo_asset_id,
                home_team.logo_asset_id,
                away_team.logo_asset_id,
                Commentator.name,
            )
            .outerjoin(Competition, Competition.id == Match.competition_id)
            .outerjoin(home_team, home_team.id == Match.home_team_id)
            .outerjoin(away_team, away_team.id == Match.away_team_id)
            .outerjoin(Commentator, Commentator.id == Match.commentator_id)
            .where(*conditions)
            .order_by(Competition.priority.asc().nulls_last(), Match.kickoff_at.asc().nulls_last(), Match.id)
        )
    ).all()

    match_ids = [row[0].id for row in found]
    visible = await fetch_visible_channels(session, match_ids)
    broadcasters = await _count_by_match(session, match_ids)
    sources = await _sources_by_match(session, match_ids)
    urls = await asset_urls(
        session,
        [asset for row in found for asset in (row[0].home_logo_asset_id, row[0].away_logo_asset_id, *row[2:5])],
    )

    rows: list[a.AdminMatchRow] = []
    for match, priority, competition_logo, home_logo, away_logo, commentator_name in found:
        derived = derive_status(match, now)
        channel_count = len(visible.get(match.id, []))
        broadcaster_count = broadcasters.get(match.id, 0)
        missing = channel_count == 0 and broadcaster_count == 0
        if status is not None and derived.status != status:
            continue
        if missing_channels is not None and missing != missing_channels:
            continue
        rows.append(
            a.AdminMatchRow(
                id=match.id,
                match_date=match.match_date,
                kickoff_at=match.kickoff_at,
                time_tbd=match.time_tbd,
                status=s.Status(derived.status),
                estimated=derived.estimated,
                score=None if derived.estimated else match_score(match),
                competition=s.CompetitionRef(
                    id=match.competition_id,
                    name=match.competition_name,
                    logo=url_of(urls, competition_logo),
                    stage=match.competition_stage,
                    priority=priority,
                ),
                home=s.TeamRef(
                    id=match.home_team_id,
                    name=match.home_team_name,
                    logo=url_of(urls, match.home_logo_asset_id or home_logo),
                ),
                away=s.TeamRef(
                    id=match.away_team_id,
                    name=match.away_team_name,
                    logo=url_of(urls, match.away_logo_asset_id or away_logo),
                ),
                channel_count=channel_count,
                broadcaster_count=broadcaster_count,
                missing_channels=missing,
                commentator=(
                    a.IdName(id=match.commentator_id, name=commentator_name or "")
                    if match.commentator_id is not None
                    else None
                ),
                sources=[match.source, *sorted(sources.get(match.id, set()) - {match.source})],
                locked=bool(match.locked_fields),
            )
        )
    return rows


async def _count_by_match(session: AsyncSession, match_ids: list[int]) -> dict[int, int]:
    if not match_ids:
        return {}
    rows = await session.execute(
        select(MatchCustomBroadcast.match_id, func.count())
        .where(MatchCustomBroadcast.match_id.in_(match_ids))
        .group_by(MatchCustomBroadcast.match_id)
    )
    return {match_id: count for match_id, count in rows}


async def _sources_by_match(session: AsyncSession, match_ids: list[int]) -> dict[int, set[str]]:
    if not match_ids:
        return {}
    rows = await session.execute(
        select(MatchExternalId.match_id, MatchExternalId.source).where(MatchExternalId.match_id.in_(match_ids))
    )
    result: dict[int, set[str]] = {}
    for match_id, source in rows:
        result.setdefault(match_id, set()).add(source)
    return result
