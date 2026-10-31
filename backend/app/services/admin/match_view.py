"""Builds the A4 editor's ``AdminMatch`` from the stored rows (contracts/admin-api.md)."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound
from app.db.models import (
    Channel,
    Match,
    MatchChannel,
    MatchCustomBroadcast,
    MatchExternalId,
    Satellite,
    Team,
)
from app.domain.status import derive_status
from app.schemas import admin as a
from app.schemas import public as s
from app.services.admin import channels as channel_service
from app.services.admin import writer
from app.services.admin.common import asset_urls, url_of
from app.services.matches import match_score

ENTITY = "matches"
NOT_FOUND = "match_not_found"


async def get(session: AsyncSession, match_id: int) -> Match:
    match = await session.get(Match, match_id)
    if match is None:
        raise EntityNotFound(NOT_FOUND)
    return match


def _team(
    team_id: int | None, name: str, match_logo_id: int | None, team_logo_id: int | None, urls: dict[int, str | None]
) -> a.AdminMatchTeam:
    # The match's own logo wins; otherwise the linked team's.
    shown = match_logo_id if match_logo_id is not None else team_logo_id
    return a.AdminMatchTeam(team_id=team_id, name=name, logo_asset_id=match_logo_id, logo=url_of(urls, shown))


def _status(match: Match, now: datetime) -> a.AdminMatchStatus:
    derived = derive_status(match, now)
    shown = not derived.estimated  # an estimated live state never shows a score or a minute
    return a.AdminMatchStatus(
        status=s.Status(derived.status),
        status_source=match.status_source,
        estimated=derived.estimated,
        period=s.Period(match.period) if match.period and shown else None,
        minute=match.minute if shown else None,
        score=match_score(match) if shown else None,
        status_label=match.status_label,
        status_updated_at=match.status_updated_at,
    )


async def _links(session: AsyncSession, match_id: int) -> list[tuple[MatchChannel, Channel, Satellite | None, bool]]:
    """The match's links to live channels, with each channel's satellite and «مخفية دائماً» flag."""
    rows = await session.execute(
        select(MatchChannel, Channel, Satellite, channel_service.hidden_by_name())
        .join(Channel, Channel.id == MatchChannel.channel_id)
        .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
        .where(MatchChannel.match_id == match_id, Channel.deleted_at.is_(None))
        .order_by(Channel.sort_order.asc().nulls_last(), Channel.id)
    )
    return [(link, channel, satellite, bool(hidden)) for link, channel, satellite, hidden in rows]


async def last_change(session: AsyncSession, match_id: int) -> a.LastChange | None:
    changed_by, changed_at = await writer.last_change(session, ENTITY, match_id)
    if changed_by is None or changed_at is None:
        return None
    return a.LastChange(kind=changed_by["kind"], name=changed_by["name"], at=datetime.fromisoformat(changed_at))


async def view(session: AsyncSession, match: Match, now: datetime) -> a.AdminMatch:
    links = await _links(session, match.id)
    slots = (
        await session.scalars(
            select(MatchCustomBroadcast)
            .where(MatchCustomBroadcast.match_id == match.id)
            .order_by(MatchCustomBroadcast.slot)
        )
    ).all()
    external = (
        await session.scalars(
            select(MatchExternalId)
            .where(MatchExternalId.match_id == match.id)
            .order_by(MatchExternalId.source, MatchExternalId.external_id)
        )
    ).all()
    team_logos = dict(
        (
            await session.execute(
                select(Team.id, Team.logo_asset_id).where(
                    Team.id.in_([t for t in (match.home_team_id, match.away_team_id) if t])
                )
            )
        ).all()
    )
    urls = await asset_urls(
        session,
        [
            match.home_logo_asset_id,
            match.away_logo_asset_id,
            *team_logos.values(),
            *(slot.logo_asset_id for slot in slots),
            *(channel.logo_asset_id for _, channel, _, _ in links),
        ],
    )

    return a.AdminMatch(
        id=match.id,
        sport=s.Sport(match.sport),
        match_date=match.match_date,
        kickoff_at=match.kickoff_at,
        time_tbd=match.time_tbd,
        competition_id=match.competition_id,
        competition_name=match.competition_name,
        competition_stage=match.competition_stage,
        home=_team(
            match.home_team_id,
            match.home_team_name,
            match.home_logo_asset_id,
            team_logos.get(match.home_team_id or 0),
            urls,
        ),
        away=_team(
            match.away_team_id,
            match.away_team_name,
            match.away_logo_asset_id,
            team_logos.get(match.away_team_id or 0),
            urls,
        ),
        stadium=match.stadium,
        commentator_id=match.commentator_id,
        status=_status(match, now),
        broadcasts=[
            a.AdminBroadcast(
                slot=slot.slot,
                label=slot.label,
                logo_asset_id=slot.logo_asset_id,
                logo=url_of(urls, slot.logo_asset_id),
                commentator_id=slot.commentator_id,
            )
            for slot in slots
        ],
        channels=[
            a.AdminMatchChannel(
                channel_id=channel.id,
                name=channel.name,
                display_name=channel.display_name,
                kind=s.Kind(channel.kind),
                satellite=(
                    a.AdminSatelliteRef(
                        id=satellite.id,
                        name_ar=satellite.name_ar,
                        name_en=satellite.name_en,
                        orbital_position=float(satellite.orbital_position)
                        if satellite.orbital_position is not None
                        else None,
                    )
                    if satellite is not None
                    else None
                ),
                frequency=channel_service.frequency_of(channel),
                access=s.Access(channel.access) if channel.access else None,
                category=s.Category(channel.category) if channel.category else None,
                logo=url_of(urls, channel.logo_asset_id),
                source=link.source,
                imported_by=link.imported_by,
                is_hidden=link.is_hidden,
                hidden_by_name=hidden,
                commentator_id=link.commentator_id,
                commentator2_id=link.commentator2_id,
            )
            for link, channel, satellite, hidden in links
        ],
        locked_fields=sorted(match.locked_fields or []),
        external_ids=[a.MatchExternalIdItem(source=e.source, external_id=e.external_id, url=e.url) for e in external],
        source=match.source,
        last_change=await last_change(session, match.id),
    )
