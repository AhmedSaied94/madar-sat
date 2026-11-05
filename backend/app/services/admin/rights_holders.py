"""A9: rights holders. ``competitions`` and ``carriages``, when sent, replace the whole list atomically.

"Exactly one primary per carriage with frequencies" is enforced here, not by an index, because
snapshot rows aren't guaranteed to meet it (005 admin-api). A save that changes nothing writes
nothing, so carriages keep their ids.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import datetime
from typing import Any

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound
from app.auth.roles import AuthedAdmin
from app.db.models import (
    Competition,
    RightsHolder,
    RightsHolderCarriage,
    RightsHolderCarriageSatellite,
    RightsHolderCompetition,
    RightsHolderFrequency,
    Satellite,
)
from app.schemas import admin_queue as q
from app.services.admin import refs, versions, writer
from app.services.admin.common import MHZ_RANGE, SYMBOL_RATE_RANGE, asset_urls, sent, url_of

ENTITY = "rights_holder"
NOT_FOUND = "rights_holder_not_found"
DATASETS = ("rights_holders", "competitions")


async def get(session: AsyncSession, holder_id: int) -> RightsHolder:
    holder = await session.get(RightsHolder, holder_id, populate_existing=True)
    if holder is None:
        raise EntityNotFound(NOT_FOUND)
    return holder


async def version(session: AsyncSession, holder: RightsHolder) -> str:
    return await versions.version_of(session, holder)


async def view(session: AsyncSession, holder: RightsHolder) -> q.AdminRightsHolder:
    state = (await versions.rights_holder_states(session, [holder]))[holder.id]
    urls = await asset_urls(session, [holder.logo_asset_id])
    return q.AdminRightsHolder(
        id=holder.id,
        name=holder.name,
        logo_asset_id=holder.logo_asset_id,
        logo=url_of(urls, holder.logo_asset_id),
        sort_order=holder.sort_order,
        competition_ids=state["competition_ids"],
        carriages=state["carriages"],
        etag=versions.etag_of(state),
    )


async def list_rows(session: AsyncSession) -> list[q.AdminRightsHolderRow]:
    """Every holder, by ``sort_order`` (nulls last), then name."""
    holders = list(
        (
            await session.scalars(
                select(RightsHolder).order_by(
                    RightsHolder.sort_order.asc().nulls_last(), RightsHolder.name, RightsHolder.id
                )
            )
        ).all()
    )
    if not holders:
        return []
    ids = [holder.id for holder in holders]
    states = await versions.rights_holder_states(session, holders)
    urls = await asset_urls(session, [holder.logo_asset_id for holder in holders])
    competitions: dict[int, list[str]] = {holder_id: [] for holder_id in ids}
    competition_rows = await session.execute(
        select(RightsHolderCompetition.rights_holder_id, Competition.name)
        .join(Competition, Competition.id == RightsHolderCompetition.competition_id)
        .where(RightsHolderCompetition.rights_holder_id.in_(ids))
        .order_by(Competition.name)
    )
    for holder_id, name in competition_rows:
        competitions[holder_id].append(name)
    satellites: dict[int, list[str]] = {holder_id: [] for holder_id in ids}
    satellite_rows = await session.execute(
        select(RightsHolderCarriage.rights_holder_id, Satellite.name_ar)
        .join(RightsHolderCarriageSatellite, RightsHolderCarriageSatellite.carriage_id == RightsHolderCarriage.id)
        .join(Satellite, Satellite.id == RightsHolderCarriageSatellite.satellite_id)
        .where(RightsHolderCarriage.rights_holder_id.in_(ids))
        .distinct()
        .order_by(RightsHolderCarriage.rights_holder_id, Satellite.name_ar)
    )
    for holder_id, name in satellite_rows:
        satellites[holder_id].append(name)
    return [
        q.AdminRightsHolderRow(
            id=holder.id,
            name=holder.name,
            logo=url_of(urls, holder.logo_asset_id),
            sort_order=holder.sort_order,
            competitions=competitions[holder.id],
            satellites=satellites[holder.id],
            etag=versions.etag_of(states[holder.id]),
        )
        for holder in holders
    ]


# --- Validation ---------------------------------------------------------------------------------


def _carriage_errors(carriages: Sequence[q.RightsHolderCarriageInput]) -> list[dict[str, Any]]:
    errors: list[dict[str, Any]] = []
    for index, carriage in enumerate(carriages):
        loc: list[str | int] = ["carriages", index, "frequencies"]
        if carriage.frequencies and sum(item.is_primary for item in carriage.frequencies) != 1:
            errors.append(refs.field_error(loc, "exactly_one_primary"))
        for position, item in enumerate(carriage.frequencies):
            if not MHZ_RANGE[0] <= item.frequency_mhz <= MHZ_RANGE[1]:
                errors.append(refs.field_error([*loc, position, "frequency_mhz"], "out_of_range"))
            if not SYMBOL_RATE_RANGE[0] <= item.symbol_rate <= SYMBOL_RATE_RANGE[1]:
                errors.append(refs.field_error([*loc, position, "symbol_rate"], "out_of_range"))
    return errors


async def _validate(
    session: AsyncSession,
    logo_asset_id: int | None,
    competition_ids: Sequence[int] | None,
    carriages: Sequence[q.RightsHolderCarriageInput] | None,
) -> None:
    errors = _carriage_errors(carriages or ())
    errors += await refs.missing_assets(session, [(logo_asset_id, refs.IMAGE_KINDS, ["logo_asset_id"])])
    errors += await refs.missing_refs(
        session,
        [
            (Competition, competition_ids or (), ["competition_ids"]),
            (Satellite, [i for c in carriages or () for i in c.satellite_ids], ["carriages", "satellite_ids"]),
        ],
    )
    refs.raise_if_any(errors)


# --- Writes -------------------------------------------------------------------------------------


def _carriages_state(carriages: Sequence[q.RightsHolderCarriageInput]) -> list[dict[str, Any]]:
    """The same shape as ``versions.rights_holder_carriages_state``, for what was sent."""
    return [
        {
            "access": carriage.access.value,
            "beam": carriage.beam.value if carriage.beam is not None else None,
            "package": carriage.package,
            "satellite_ids": sorted(set(carriage.satellite_ids)),
            "frequencies": sorted(
                (
                    {
                        "frequency_mhz": item.frequency_mhz,
                        "polarization": item.polarization.value,
                        "symbol_rate": item.symbol_rate,
                        "is_primary": item.is_primary,
                    }
                    for item in carriage.frequencies
                ),
                key=lambda item: (item["frequency_mhz"], item["polarization"], item["symbol_rate"]),
            ),
        }
        for carriage in carriages
    ]


async def _replace_competitions(session: AsyncSession, holder_id: int, competition_ids: Sequence[int]) -> None:
    await session.execute(delete(RightsHolderCompetition).where(RightsHolderCompetition.rights_holder_id == holder_id))
    session.add_all(
        RightsHolderCompetition(rights_holder_id=holder_id, competition_id=competition_id)
        for competition_id in sorted(set(competition_ids))
    )
    await writer.flush(session)


async def _replace_carriages(session: AsyncSession, holder_id: int, state: Sequence[dict[str, Any]]) -> None:
    # The database cascades the satellites and frequencies of each deleted carriage.
    await session.execute(delete(RightsHolderCarriage).where(RightsHolderCarriage.rights_holder_id == holder_id))
    for position, item in enumerate(state):
        carriage = RightsHolderCarriage(
            rights_holder_id=holder_id,
            position=position,
            access=item["access"],
            beam=item["beam"],
            package=item["package"],
        )
        session.add(carriage)
        await writer.flush(session)
        session.add_all(
            RightsHolderCarriageSatellite(carriage_id=carriage.id, satellite_id=satellite_id)
            for satellite_id in item["satellite_ids"]
        )
        session.add_all(
            RightsHolderFrequency(carriage_id=carriage.id, **frequency) for frequency in item["frequencies"]
        )
        await writer.flush(session)


async def create(session: AsyncSession, admin: AuthedAdmin, body: q.RightsHolderCreate) -> RightsHolder:
    await _validate(session, body.logo_asset_id, body.competition_ids, body.carriages)
    holder = RightsHolder(name=body.name, logo_asset_id=body.logo_asset_id)
    session.add(holder)
    await writer.flush(session)
    competition_ids = sorted(set(body.competition_ids))
    state = _carriages_state(body.carriages)
    await _replace_competitions(session, holder.id, competition_ids)
    await _replace_carriages(session, holder.id, state)
    await writer.save_create(
        session,
        admin,
        entity=ENTITY,
        row=holder,
        datasets=DATASETS,
        extra_diff={"competition_ids": [[], competition_ids], "carriages": [[], state]},
    )
    return holder


async def update(
    session: AsyncSession,
    admin: AuthedAdmin,
    holder_id: int,
    body: q.RightsHolderPatch,
    if_match: str | None,
    now: datetime,
) -> RightsHolder:
    holder = await writer.lock_and_check(session, RightsHolder, holder_id, NOT_FOUND, ENTITY, if_match)
    changes = sent(body)
    for column in ("name", "competition_ids", "carriages"):
        if column in changes and changes[column] is None:
            refs.raise_if_any([refs.field_error([column], "null_not_allowed")])
    await _validate(session, changes.get("logo_asset_id"), changes.get("competition_ids"), changes.get("carriages"))

    current = (await versions.rights_holder_states(session, [holder]))[holder.id]
    before = versions.row_state(holder)
    for column in ("name", "logo_asset_id"):
        if column in changes:
            setattr(holder, column, changes[column])

    extra: dict[str, Any] = {}
    if "competition_ids" in changes:
        wanted = sorted(set(changes["competition_ids"]))
        if wanted != current["competition_ids"]:
            await _replace_competitions(session, holder.id, wanted)
            extra["competition_ids"] = [current["competition_ids"], wanted]
    if "carriages" in changes:
        state = _carriages_state(changes["carriages"])
        if state != current["carriages"]:
            await _replace_carriages(session, holder.id, state)
            extra["carriages"] = [current["carriages"], state]

    await writer.save_update(
        session, admin, entity=ENTITY, row=holder, before=before, datasets=DATASETS, now=now, extra_diff=extra
    )
    return holder


async def remove(
    session: AsyncSession, admin: AuthedAdmin, holder_id: int, if_match: str | None, now: datetime
) -> None:
    holder = await writer.lock_and_check(session, RightsHolder, holder_id, NOT_FOUND, ENTITY, if_match)
    await writer.save_delete(session, admin, entity=ENTITY, row=holder, datasets=DATASETS, now=now)
