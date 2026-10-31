"""Competitions: read, create, update and delete."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import select, union
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound
from app.auth.roles import AuthedAdmin
from app.db.models import Competition, DeviceFollow, Match, RightsHolderCompetition, Team, TeamCompetition
from app.schemas import admin as a
from app.services.admin import refs, versions, writer
from app.services.admin.common import asset_urls, refuse_if_in_use, sent, url_of

ENTITY = "competitions"
NOT_FOUND = "competition_not_found"
COLUMNS = ("name", "logo_asset_id", "priority")


async def get(session: AsyncSession, competition_id: int) -> Competition:
    competition = await session.get(Competition, competition_id)
    if competition is None:
        raise EntityNotFound(NOT_FOUND)
    return competition


def to_view(competition: Competition, logo: str | None) -> a.AdminCompetition:
    return a.AdminCompetition(
        id=competition.id,
        sport=competition.sport,
        name=competition.name,
        logo_asset_id=competition.logo_asset_id,
        logo=logo,
        priority=competition.priority,
    )


async def view(session: AsyncSession, competition: Competition) -> a.AdminCompetition:
    urls = await asset_urls(session, [competition.logo_asset_id])
    return to_view(competition, url_of(urls, competition.logo_asset_id))


async def version(session: AsyncSession, competition: Competition) -> str:
    return versions.row_version(competition)


async def _check_logo(session: AsyncSession, logo_asset_id: int | None) -> None:
    refs.raise_if_any(await refs.missing_assets(session, [(logo_asset_id, refs.IMAGE_KINDS, ["logo_asset_id"])]))


async def create(session: AsyncSession, admin: AuthedAdmin, body: a.CompetitionCreate) -> Competition:
    await _check_logo(session, body.logo_asset_id)
    competition = Competition(
        sport=body.sport.value, name=body.name, logo_asset_id=body.logo_asset_id, priority=body.priority
    )
    session.add(competition)
    await writer.save_create(session, admin, entity=ENTITY, row=competition, datasets=writer.COMPETITION_CHANGED)
    return competition


async def update(
    session: AsyncSession,
    admin: AuthedAdmin,
    competition_id: int,
    body: a.CompetitionPatch,
    if_match: str | None,
    now: datetime,
) -> Competition:
    competition = await writer.lock_and_check(session, Competition, competition_id, NOT_FOUND, ENTITY, if_match)
    changes = sent(body)
    if changes.get("name", "") is None:
        refs.raise_if_any([refs.field_error(["name"], "null_not_allowed")])
    await _check_logo(session, changes.get("logo_asset_id"))

    before = versions.row_state(competition)
    for column in COLUMNS:
        if column in changes:
            setattr(competition, column, changes[column])
    await writer.save_update(
        session,
        admin,
        entity=ENTITY,
        row=competition,
        before=before,
        datasets=writer.COMPETITION_CHANGED,
        now=now,
    )
    return competition


async def remove(
    session: AsyncSession, admin: AuthedAdmin, competition_id: int, if_match: str | None, now: datetime
) -> None:
    competition = await writer.lock_and_check(session, Competition, competition_id, NOT_FOUND, ENTITY, if_match)
    team_ids = union(
        select(Team.id).where(Team.primary_competition_id == competition.id),
        select(TeamCompetition.team_id).where(TeamCompetition.competition_id == competition.id),
    )
    await refuse_if_in_use(
        session,
        {
            "matches": select(Match.id).where(Match.competition_id == competition.id),
            "teams": team_ids,
            "follows": select(DeviceFollow.device_id).where(DeviceFollow.competition_id == competition.id),
            # The cascade in 0001 would delete these silently (B1-R1-6).
            "rights_holders": select(RightsHolderCompetition.rights_holder_id).where(
                RightsHolderCompetition.competition_id == competition.id
            ),
        },
    )
    await writer.save_delete(
        session, admin, entity=ENTITY, row=competition, datasets=writer.COMPETITION_CHANGED, now=now
    )
