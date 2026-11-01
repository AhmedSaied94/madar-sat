"""Lists for the admin app: whole lists, searchable pickers and keyset pages (research R9).

A picker (``q`` set) returns the top 20 by ``pg_trgm`` similarity on ``ar_normalize(q)`` with a prefix
match first, and no cursor. Without ``q``, teams, channels and commentators page by an opaque keyset
cursor, which stays stable while importers insert rows (an offset would not).
"""

from __future__ import annotations

import base64
import json
from collections.abc import Sequence
from dataclasses import dataclass
from typing import Any

from sqlalchemy import ColumnElement, Select, and_, func, or_, select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound, validation_failed
from app.auth.roles import AuthedAdmin
from app.db.models import (
    BroadcastPreset,
    Channel,
    Commentator,
    Competition,
    HiddenChannelName,
    Satellite,
    Team,
    TeamCompetition,
)
from app.schemas import admin as a
from app.services.admin import channels as channel_service
from app.services.admin import commentators as commentator_service
from app.services.admin import competitions as competition_service
from app.services.admin import satellites as satellite_service
from app.services.admin import writer
from app.services.admin.common import asset_urls, url_of

PICKER_SIZE = 20


# --- Cursors ------------------------------------------------------------------------


def encode_cursor(values: Sequence[Any]) -> str:
    return base64.urlsafe_b64encode(json.dumps(list(values)).encode()).decode().rstrip("=")


def decode_cursor(raw: str, size: int) -> list[Any]:
    """The values behind a cursor, or ``422`` for one this API didn't issue."""
    try:
        values = json.loads(base64.urlsafe_b64decode(raw + "=" * (-len(raw) % 4)))
    except ValueError:
        values = None
    if not isinstance(values, list) or len(values) != size:
        raise validation_failed([{"loc": ["query", "cursor"], "type": "invalid_cursor"}])
    return values


def _picker(q: str) -> ColumnElement[str]:
    return func.ar_normalize(q)


def _search(model: Any, q: str) -> tuple[ColumnElement[bool], list[ColumnElement[Any]]]:
    """``(where, order_by)`` for a picker over ``model.name_norm``."""
    wanted = _picker(q)
    prefix = func.starts_with(model.name_norm, wanted)
    return (
        or_(model.name_norm.op("%")(wanted), prefix),
        [prefix.desc(), func.similarity(model.name_norm, wanted).desc(), model.id],
    )


# --- Competitions and satellites: whole lists -----------------------------------------


async def competitions(session: AsyncSession) -> list[a.AdminCompetition]:
    rows = (
        await session.scalars(select(Competition).order_by(Competition.priority.asc().nulls_last(), Competition.name))
    ).all()
    urls = await asset_urls(session, [row.logo_asset_id for row in rows])
    return [competition_service.to_view(row, url_of(urls, row.logo_asset_id)) for row in rows]


async def satellites(session: AsyncSession) -> list[a.AdminSatellite]:
    rows = (
        await session.scalars(select(Satellite).order_by(Satellite.priority.asc().nulls_last(), Satellite.id))
    ).all()
    urls = await asset_urls(session, [row.logo_asset_id for row in rows])
    return [satellite_service.to_view(row, url_of(urls, row.logo_asset_id)) for row in rows]


# --- Teams ----------------------------------------------------------------------------


async def teams(
    session: AsyncSession,
    q: str | None,
    competition_id: int | None,
    missing_logo: bool | None,
    cursor: str | None,
    limit: int,
) -> tuple[list[a.TeamItem], str | None]:
    query: Select[Any] = select(Team)
    if competition_id is not None:
        member = select(TeamCompetition.team_id).where(TeamCompetition.competition_id == competition_id)
        query = query.where(or_(Team.primary_competition_id == competition_id, Team.id.in_(member)))
    if missing_logo is not None:
        query = query.where(Team.logo_asset_id.is_(None) if missing_logo else Team.logo_asset_id.is_not(None))

    next_cursor: str | None = None
    if q is not None:
        where, order = _search(Team, q)
        rows = (await session.scalars(query.where(where).order_by(*order).limit(PICKER_SIZE))).all()
    else:
        if cursor is not None:
            name_norm, last_id = decode_cursor(cursor, 2)
            query = query.where(tuple_(Team.name_norm, Team.id) > tuple_(name_norm, last_id))
        found = (await session.scalars(query.order_by(Team.name_norm, Team.id).limit(limit + 1))).all()
        rows = found[:limit]
        if len(found) > limit:
            next_cursor = encode_cursor([rows[-1].name_norm, rows[-1].id])
    return await _team_items(session, rows), next_cursor


async def _team_items(session: AsyncSession, rows: Sequence[Team]) -> list[a.TeamItem]:
    team_ids = [row.id for row in rows]
    member = await session.execute(
        select(TeamCompetition.team_id, Competition.id, Competition.name)
        .join(Competition, Competition.id == TeamCompetition.competition_id)
        .where(TeamCompetition.team_id.in_(team_ids))
        .order_by(Competition.priority.asc().nulls_last(), Competition.name)
    )
    by_team: dict[int, list[a.IdName]] = {}
    for team_id, competition_id, name in member:
        by_team.setdefault(team_id, []).append(a.IdName(id=competition_id, name=name))

    primary_ids = {row.primary_competition_id for row in rows if row.primary_competition_id is not None}
    primary_names = (
        dict(
            (
                await session.execute(select(Competition.id, Competition.name).where(Competition.id.in_(primary_ids)))
            ).all()
        )
        if primary_ids
        else {}
    )
    urls = await asset_urls(session, [row.logo_asset_id for row in rows])
    return [
        a.TeamItem(
            id=row.id,
            name=row.name,
            country=row.country,
            logo=url_of(urls, row.logo_asset_id),
            primary_competition=(
                a.IdName(id=row.primary_competition_id, name=primary_names[row.primary_competition_id])
                if row.primary_competition_id in primary_names
                else None
            ),
            competitions=by_team.get(row.id, []),
        )
        for row in rows
    ]


# --- Channels -------------------------------------------------------------------------


@dataclass(frozen=True)
class ChannelFilters:
    satellite_id: int | None = None
    category: str | None = None
    kind: str | None = None
    access: str | None = None
    missing_logo: bool | None = None
    placeholder: bool | None = None
    show_in_match: bool | None = None


async def channels(
    session: AsyncSession, q: str | None, filters: ChannelFilters, cursor: str | None, limit: int
) -> tuple[list[a.ChannelItem], str | None]:
    query: Any = select(Channel, channel_service.hidden_by_name().label("hidden")).where(Channel.deleted_at.is_(None))
    for column, value in (
        (Channel.satellite_id, filters.satellite_id),
        (Channel.category, filters.category),
        (Channel.kind, filters.kind),
        (Channel.access, filters.access),
        (Channel.show_in_match, filters.show_in_match),
    ):
        if value is not None:
            query = query.where(column == value)
    if filters.placeholder is not None:
        # An importer's placeholder (research R18); A8 completes them before they reach /v1.
        query = query.where(
            Channel.placeholder_source.is_not(None) if filters.placeholder else Channel.placeholder_source.is_(None)
        )
    if filters.missing_logo is not None:
        query = query.where(
            Channel.logo_asset_id.is_(None) if filters.missing_logo else Channel.logo_asset_id.is_not(None)
        )

    next_cursor: str | None = None
    if q is not None:
        where, order = _search(Channel, q)
        rows = (await session.execute(query.where(where).order_by(*order).limit(PICKER_SIZE))).all()
    else:
        if cursor is not None:
            sort_order, last_id = decode_cursor(cursor, 2)
            if sort_order is None:
                query = query.where(and_(Channel.sort_order.is_(None), Channel.id > last_id))
            else:
                query = query.where(
                    or_(
                        Channel.sort_order > sort_order,
                        and_(Channel.sort_order == sort_order, Channel.id > last_id),
                        Channel.sort_order.is_(None),
                    )
                )
        found = (
            await session.execute(query.order_by(Channel.sort_order.asc().nulls_last(), Channel.id).limit(limit + 1))
        ).all()
        rows = found[:limit]
        if len(found) > limit:
            last = rows[-1][0]
            next_cursor = encode_cursor([last.sort_order, last.id])

    urls = await asset_urls(session, [channel.logo_asset_id for channel, _ in rows])
    items = [
        channel_service.to_item(channel, bool(hidden), url_of(urls, channel.logo_asset_id)) for channel, hidden in rows
    ]
    return items, next_cursor


# --- Commentators ---------------------------------------------------------------------


async def commentators(
    session: AsyncSession, q: str | None, cursor: str | None, limit: int
) -> tuple[list[a.AdminCommentator], str | None]:
    query: Select[Any] = select(Commentator)
    next_cursor: str | None = None
    if q is not None:
        where, order = _search(Commentator, q)
        rows = (await session.scalars(query.where(where).order_by(*order).limit(PICKER_SIZE))).all()
    else:
        if cursor is not None:
            name_norm, last_id = decode_cursor(cursor, 2)
            query = query.where(tuple_(Commentator.name_norm, Commentator.id) > tuple_(name_norm, last_id))
        found = (await session.scalars(query.order_by(Commentator.name_norm, Commentator.id).limit(limit + 1))).all()
        rows = found[:limit]
        if len(found) > limit:
            next_cursor = encode_cursor([rows[-1].name_norm, rows[-1].id])

    urls = await asset_urls(session, [row.photo_asset_id for row in rows] + [row.audio_asset_id for row in rows])
    items = [
        a.AdminCommentator(
            id=row.id,
            name=row.name,
            photo_asset_id=row.photo_asset_id,
            photo=url_of(urls, row.photo_asset_id),
            audio_asset_id=row.audio_asset_id,
            audio=url_of(urls, row.audio_asset_id),
            usage=await commentator_service.usage(session, row.id),
        )
        for row in rows
    ]
    return items, next_cursor


# --- Small read-only lists ------------------------------------------------------------


async def broadcast_presets(session: AsyncSession) -> list[a.BroadcastPreset]:
    rows = (await session.scalars(select(BroadcastPreset).order_by(BroadcastPreset.name))).all()
    urls = await asset_urls(session, [row.logo_asset_id for row in rows])
    return [
        a.BroadcastPreset(
            id=row.id, name=row.name, logo_asset_id=row.logo_asset_id, logo=url_of(urls, row.logo_asset_id)
        )
        for row in rows
    ]


async def hidden_names(session: AsyncSession) -> list[a.HiddenChannelName]:
    names = (await session.scalars(select(HiddenChannelName.name).order_by(HiddenChannelName.name))).all()
    return [a.HiddenChannelName(name=name) for name in names]


# --- Hidden channel names: «إخفاء دائماً» and «إظهار» ----------------------------------

ENTITY = "hidden_channel_names"


async def add_hidden_name(session: AsyncSession, admin: AuthedAdmin, name: str) -> tuple[str, bool]:
    """Store ``ar_normalize(name)``. Returns ``(normalized, created)``; adding an existing name changes nothing."""
    normalized = str(await session.scalar(select(func.ar_normalize(name))))
    if not normalized:
        raise validation_failed([{"loc": ["body", "name"], "type": "empty_after_normalizing"}])
    if await session.get(HiddenChannelName, normalized) is not None:
        return normalized, False
    session.add(HiddenChannelName(name=normalized))
    await writer.flush(session)
    writer.add_audit(session, admin, ENTITY, None, "create", {"name": [None, normalized]})
    await writer.bump_datasets(session, writer.HIDDEN_NAME_CHANGED)
    return normalized, True


async def remove_hidden_name(session: AsyncSession, admin: AuthedAdmin, name: str) -> None:
    normalized = str(await session.scalar(select(func.ar_normalize(name))))
    row = await session.get(HiddenChannelName, normalized)
    if row is None:
        raise EntityNotFound("hidden_name_not_found")
    await session.delete(row)
    writer.add_audit(session, admin, ENTITY, None, "delete", {"name": [normalized, None]})
    await writer.bump_datasets(session, writer.HIDDEN_NAME_CHANGED)
