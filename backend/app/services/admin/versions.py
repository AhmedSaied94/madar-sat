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
    RightsHolder,
    RightsHolderCarriage,
    RightsHolderCarriageSatellite,
    RightsHolderCompetition,
    RightsHolderFrequency,
    Satellite,
    Team,
    TeamCompetition,
    UnresolvedName,
)

# ``frequency_changed_at`` moves when a hold ends, which is the dispatcher's doing, not an editor's:
# hashing it would make an open A8 stale for something nobody there did (research R6).
NOT_HASHED = frozenset({"created_at", "updated_at", "frequency_changed_at"})
# The poller writes these every minute; hashing them would fail any open editor's save (research R14).
MATCH_CLOCK_COLUMNS = frozenset({"minute", "period", "status_updated_at"})
# An unresolved name is seen again on every run; only a decision about it makes a copy stale.
UNRESOLVED_DECISION_COLUMNS = ("id", "kind", "name_norm", "competition_norm", "state", "target_id")
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
    own = {key: value for key, value in row_state(match).items() if key not in MATCH_CLOCK_COLUMNS}
    return {
        "match": own,
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


async def match_versions(session: AsyncSession, matches: Iterable[Match]) -> dict[int, str]:
    """The current version of each match, in three queries: the A3 list shows one per row (A-F3)."""
    rows = list(matches)
    if not rows:
        return {}
    ids = [match.id for match in rows]
    links: dict[int, list[MatchChannel]] = {match_id: [] for match_id in ids}
    slots: dict[int, list[MatchCustomBroadcast]] = {match_id: [] for match_id in ids}
    for link in await session.scalars(select(MatchChannel).where(MatchChannel.match_id.in_(ids))):
        links[link.match_id].append(link)
    for slot in await session.scalars(select(MatchCustomBroadcast).where(MatchCustomBroadcast.match_id.in_(ids))):
        slots[slot.match_id].append(slot)
    return {match.id: etag_of(match_state(match, links[match.id], slots[match.id])) for match in rows}


async def team_version(session: AsyncSession, team: Team) -> str:
    query = select(TeamCompetition.competition_id).where(TeamCompetition.team_id == team.id)
    return etag_of(team_state(team, (await session.scalars(query)).all()))


def row_version(row: Competition | Satellite | Channel | Commentator) -> str:
    return etag_of(row_state(row))


def unresolved_version(row: UnresolvedName) -> str:
    return etag_of({column: getattr(row, column) for column in UNRESOLVED_DECISION_COLUMNS})


def rights_holder_state(
    holder: RightsHolder,
    competition_ids: Iterable[int],
    carriages: Iterable[RightsHolderCarriage],
    satellite_ids: Mapping[int, Iterable[int]],
    frequencies: Mapping[int, Iterable[RightsHolderFrequency]],
) -> dict[str, Any]:
    return {
        "holder": row_state(holder),
        "competition_ids": sorted(set(competition_ids)),
        "carriages": rights_holder_carriages_state(carriages, satellite_ids, frequencies),
    }


def rights_holder_carriages_state(
    carriages: Iterable[RightsHolderCarriage],
    satellite_ids: Mapping[int, Iterable[int]],
    frequencies: Mapping[int, Iterable[RightsHolderFrequency]],
) -> list[dict[str, Any]]:
    """The carriages by position, without their generated ids: replacing a list with itself changes nothing."""
    return [
        {
            "access": carriage.access,
            "beam": carriage.beam,
            "package": carriage.package,
            "satellite_ids": sorted(set(satellite_ids.get(carriage.id, ()))),
            "frequencies": sorted(
                (
                    {
                        "frequency_mhz": item.frequency_mhz,
                        "polarization": item.polarization,
                        "symbol_rate": item.symbol_rate,
                        "is_primary": bool(item.is_primary),
                    }
                    for item in frequencies.get(carriage.id, ())
                ),
                key=lambda item: (item["frequency_mhz"], item["polarization"], item["symbol_rate"]),
            ),
        }
        for carriage in sorted(carriages, key=lambda carriage: carriage.position)
    ]


async def rights_holder_states(session: AsyncSession, holders: Iterable[RightsHolder]) -> dict[int, dict[str, Any]]:
    """Each holder's state, in four queries: the A9 list shows a version per row."""
    rows = list(holders)
    ids = [holder.id for holder in rows]
    if not ids:
        return {}
    competition_ids: dict[int, list[int]] = {holder_id: [] for holder_id in ids}
    link_rows = await session.execute(
        select(RightsHolderCompetition.rights_holder_id, RightsHolderCompetition.competition_id).where(
            RightsHolderCompetition.rights_holder_id.in_(ids)
        )
    )
    for holder_id, competition_id in link_rows:
        competition_ids[holder_id].append(competition_id)
    # populate_existing: a replaced list is re-read, never served from what the session already holds.
    carriage_rows = await session.scalars(
        select(RightsHolderCarriage)
        .where(RightsHolderCarriage.rights_holder_id.in_(ids))
        .execution_options(populate_existing=True)
    )
    carriages: dict[int, list[RightsHolderCarriage]] = {holder_id: [] for holder_id in ids}
    for carriage in carriage_rows:
        carriages[carriage.rights_holder_id].append(carriage)
    carriage_ids = [carriage.id for rows_of in carriages.values() for carriage in rows_of]
    satellite_ids: dict[int, list[int]] = {}
    frequencies: dict[int, list[RightsHolderFrequency]] = {}
    if carriage_ids:
        satellite_rows = await session.execute(
            select(RightsHolderCarriageSatellite.carriage_id, RightsHolderCarriageSatellite.satellite_id).where(
                RightsHolderCarriageSatellite.carriage_id.in_(carriage_ids)
            )
        )
        for carriage_id, satellite_id in satellite_rows:
            satellite_ids.setdefault(carriage_id, []).append(satellite_id)
        frequency_rows = await session.scalars(
            select(RightsHolderFrequency)
            .where(RightsHolderFrequency.carriage_id.in_(carriage_ids))
            .execution_options(populate_existing=True)
        )
        for item in frequency_rows:
            frequencies.setdefault(item.carriage_id, []).append(item)
    return {
        holder.id: rights_holder_state(
            holder, competition_ids[holder.id], carriages[holder.id], satellite_ids, frequencies
        )
        for holder in rows
    }


async def version_of(session: AsyncSession, row: Base) -> str:
    """The current version of any admin entity."""
    if isinstance(row, Match):
        return await match_version(session, row)
    if isinstance(row, Team):
        return await team_version(session, row)
    if isinstance(row, UnresolvedName):
        return unresolved_version(row)
    if isinstance(row, RightsHolder):
        return etag_of((await rights_holder_states(session, [row]))[row.id])
    return etag_of(row_state(row))


def matches_etag(header: str | None, current: str) -> bool:
    """``If-Match`` equality. Strong comparison; a list of tags or ``*`` is not accepted."""
    return header is not None and header.strip() == current


__all__ = [
    "etag_of",
    "match_state",
    "match_version",
    "match_versions",
    "matches_etag",
    "rights_holder_carriages_state",
    "rights_holder_state",
    "rights_holder_states",
    "row_state",
    "row_version",
    "team_state",
    "team_version",
    "unresolved_version",
    "version_of",
]
