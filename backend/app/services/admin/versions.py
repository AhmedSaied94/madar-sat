"""Entity versions: the strong ``ETag`` that ``If-Match`` is checked against (research R5).

A version is the first 32 hex characters of the SHA-256 of the entity's own stored state as
canonical JSON (sorted keys, sorted rows), in quotes. It is computed on GET and again under the
row lock when a write arrives, so any writer's change (an editor, an importer, the media worker)
makes an open editor's copy stale. Joined data such as a team's name on a match is not part of it.
"""

from __future__ import annotations

import hashlib
import json
from collections.abc import Iterable, Mapping
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from sqlalchemy import inspect, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import (
    Base,
    Channel,
    Commentator,
    Competition,
    Match,
    MatchChannel,
    MatchCustomBroadcast,
    Satellite,
    Team,
    TeamCompetition,
)

NOT_HASHED = frozenset({"created_at", "updated_at"})
# Order is not meaningful in these array columns, so they are compared as sets.
SET_COLUMNS = frozenset({"locked_fields"})
LINK_COLUMNS = ("channel_id", "source", "imported_by", "is_hidden", "commentator_id", "commentator2_id")
SLOT_COLUMNS = ("slot", "label", "logo_asset_id", "commentator_id")


def _plain(value: Any) -> Any:
    """A JSON-safe value that doesn't depend on the driver's types."""
    if isinstance(value, datetime):
        return value.astimezone(UTC).isoformat()
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return format(value.normalize(), "f")
    if isinstance(value, UUID):
        return str(value)
    return value


def row_state(row: Base) -> dict[str, Any]:
    """The row's own stored columns, minus timestamps and generated columns."""
    state: dict[str, Any] = {}
    for attr in inspect(type(row)).column_attrs:
        column = attr.columns[0]
        if attr.key in NOT_HASHED or column.computed is not None:
            continue
        value = getattr(row, attr.key)
        if attr.key in SET_COLUMNS:
            value = sorted(value or [])
        state[attr.key] = _plain(value)
    return state


def match_state(match: Match, links: Iterable[MatchChannel], slots: Iterable[MatchCustomBroadcast]) -> dict[str, Any]:
    return {
        "match": row_state(match),
        "links": sorted(
            ({column: getattr(link, column) for column in LINK_COLUMNS} for link in links),
            key=lambda link: link["channel_id"],
        ),
        "slots": sorted(
            ({column: getattr(slot, column) for column in SLOT_COLUMNS} for slot in slots),
            key=lambda slot: slot["slot"],
        ),
    }


def team_state(team: Team, competition_ids: Iterable[int]) -> dict[str, Any]:
    return {"team": row_state(team), "competition_ids": sorted(set(competition_ids))}


def etag_of(state: Mapping[str, Any]) -> str:
    canonical = json.dumps(state, sort_keys=True, separators=(",", ":"), default=_plain)
    return f'"{hashlib.sha256(canonical.encode()).hexdigest()[:32]}"'


# --- Loaders: the version of what is stored right now ------------------------------


async def match_version(session: AsyncSession, match: Match) -> str:
    links = (await session.scalars(select(MatchChannel).where(MatchChannel.match_id == match.id))).all()
    slots = (await session.scalars(select(MatchCustomBroadcast).where(MatchCustomBroadcast.match_id == match.id))).all()
    return etag_of(match_state(match, links, slots))


async def team_version(session: AsyncSession, team: Team) -> str:
    query = select(TeamCompetition.competition_id).where(TeamCompetition.team_id == team.id)
    return etag_of(team_state(team, (await session.scalars(query)).all()))


def row_version(row: Competition | Satellite | Channel | Commentator) -> str:
    return etag_of(row_state(row))


async def version_of(session: AsyncSession, row: Base) -> str:
    """The current version of any admin entity."""
    if isinstance(row, Match):
        return await match_version(session, row)
    if isinstance(row, Team):
        return await team_version(session, row)
    return etag_of(row_state(row))


def matches_etag(header: str | None, current: str) -> bool:
    """``If-Match`` equality. Strong comparison; a list of tags or ``*`` is not accepted."""
    return header is not None and header.strip() == current


__all__ = [
    "etag_of",
    "match_state",
    "match_version",
    "matches_etag",
    "row_state",
    "row_version",
    "team_state",
    "team_version",
    "version_of",
]
