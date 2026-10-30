"""Teams: read, create, update and delete (contracts/admin-api.md, "Teams, competitions, …")."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound
from app.auth.roles import AuthedAdmin
from app.db.models import Competition, DeviceFollow, Match, Team, TeamCompetition, TeamExternalId
from app.schemas import admin as a
from app.services.admin import refs, versions, writer
from app.services.admin.common import asset_urls, refuse_if_in_use, sent, url_of

ENTITY = "teams"
NOT_FOUND = "team_not_found"
COLUMNS = ("name", "country", "logo_asset_id", "stadium", "primary_competition_id")


async def get(session: AsyncSession, team_id: int) -> Team:
    team = await session.get(Team, team_id)
    if team is None:
        raise EntityNotFound(NOT_FOUND)
    return team


async def competition_ids(session: AsyncSession, team_id: int) -> list[int]:
    rows = await session.scalars(select(TeamCompetition.competition_id).where(TeamCompetition.team_id == team_id))
    return sorted(rows.all())


async def view(session: AsyncSession, team: Team) -> a.AdminTeam:
    external = await session.execute(
        select(TeamExternalId.source, TeamExternalId.external_id)
        .where(TeamExternalId.team_id == team.id)
        .order_by(TeamExternalId.source, TeamExternalId.external_id)
    )
    urls = await asset_urls(session, [team.logo_asset_id])
    return a.AdminTeam(
        id=team.id,
        sport=team.sport,
        name=team.name,
        country=team.country,
        logo_asset_id=team.logo_asset_id,
        logo=url_of(urls, team.logo_asset_id),
        stadium=team.stadium,
        primary_competition_id=team.primary_competition_id,
        competition_ids=await competition_ids(session, team.id),
        external_ids=[a.ExternalId(source=source, external_id=external_id) for source, external_id in external],
    )


async def version(session: AsyncSession, team: Team) -> str:
    return await versions.team_version(session, team)


async def _check_refs(
    session: AsyncSession,
    *,
    logo_asset_id: int | None,
    primary_competition_id: int | None,
    competition_ids: list[int] | None,
) -> None:
    errors = await refs.missing_refs(
        session,
        [
            (Competition, [primary_competition_id], ["primary_competition_id"]),
            (Competition, competition_ids or [], ["competition_ids"]),
        ],
    )
    errors += await refs.missing_assets(session, [(logo_asset_id, refs.IMAGE_KINDS, ["logo_asset_id"])])
    refs.raise_if_any(errors)


async def _set_competitions(session: AsyncSession, team_id: int, wanted: list[int]) -> None:
    await session.execute(delete(TeamCompetition).where(TeamCompetition.team_id == team_id))
    session.add_all(TeamCompetition(team_id=team_id, competition_id=cid) for cid in sorted(set(wanted)))


async def create(session: AsyncSession, admin: AuthedAdmin, body: a.TeamCreate) -> Team:
    await _check_refs(
        session,
        logo_asset_id=body.logo_asset_id,
        primary_competition_id=body.primary_competition_id,
        competition_ids=body.competition_ids,
    )
    team = Team(
        sport=body.sport.value,
        name=body.name,
        country=body.country,
        logo_asset_id=body.logo_asset_id,
        stadium=body.stadium,
        primary_competition_id=body.primary_competition_id,
    )
    session.add(team)
    await writer.flush(session)
    await _set_competitions(session, team.id, body.competition_ids)
    wanted = sorted(set(body.competition_ids))
    await writer.save_create(
        session,
        admin,
        entity=ENTITY,
        row=team,
        datasets=writer.TEAM_CHANGED,
        extra_diff={"competition_ids": [[], wanted]} if wanted else None,
    )
    return team


async def update(
    session: AsyncSession,
    admin: AuthedAdmin,
    team_id: int,
    body: a.TeamPatch,
    if_match: str | None,
    now: datetime,
) -> Team:
    team = await writer.lock_and_check(session, Team, team_id, NOT_FOUND, ENTITY, if_match)
    changes = sent(body)
    if changes.get("name", "") is None:
        refs.raise_if_any([refs.field_error(["name"], "null_not_allowed")])

    await _check_refs(
        session,
        logo_asset_id=changes.get("logo_asset_id"),
        primary_competition_id=changes.get("primary_competition_id"),
        competition_ids=changes.get("competition_ids"),
    )

    before = versions.row_state(team)
    for column in COLUMNS:
        if column in changes:
            setattr(team, column, changes[column])

    extra: dict[str, list[list[int]]] = {}
    if changes.get("competition_ids") is not None:
        old = await competition_ids(session, team.id)
        new = sorted(set(changes["competition_ids"]))
        if old != new:
            await _set_competitions(session, team.id, new)
            extra["competition_ids"] = [old, new]

    await writer.save_update(
        session,
        admin,
        entity=ENTITY,
        row=team,
        before=before,
        datasets=writer.TEAM_CHANGED,
        now=now,
        extra_diff=extra,
    )
    return team


async def remove(session: AsyncSession, admin: AuthedAdmin, team_id: int, if_match: str | None, now: datetime) -> None:
    team = await writer.lock_and_check(session, Team, team_id, NOT_FOUND, ENTITY, if_match)
    await refuse_if_in_use(
        session,
        {
            "matches": select(Match.id).where(or_(Match.home_team_id == team.id, Match.away_team_id == team.id)),
            "follows": select(DeviceFollow.device_id).where(DeviceFollow.team_id == team.id),
        },
    )
    await writer.save_delete(session, admin, entity=ENTITY, row=team, datasets=writer.TEAM_CHANGED, now=now)
