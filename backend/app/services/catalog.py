"""``/v1/competitions`` and ``/v1/rights-holders`` read queries."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import (
    Competition,
    MediaAsset,
    RightsHolder,
    RightsHolderCarriage,
    RightsHolderCarriageSatellite,
    RightsHolderCompetition,
    RightsHolderFrequency,
    Satellite,
)
from app.schemas import public as s
from app.services.common import media_url


async def list_competitions(session: AsyncSession) -> list[s.Competition]:
    rows = await session.execute(
        select(Competition, MediaAsset.path)
        .outerjoin(MediaAsset, MediaAsset.id == Competition.logo_asset_id)
        .order_by(Competition.priority.asc().nulls_last(), Competition.name.asc())
    )
    return [s.Competition(id=c.id, sport=c.sport, name=c.name, logo=media_url(p), priority=c.priority) for c, p in rows]


async def get_competition(session: AsyncSession, competition_id: int) -> s.CompetitionDetail | None:
    row = (
        await session.execute(
            select(Competition, MediaAsset.path)
            .outerjoin(MediaAsset, MediaAsset.id == Competition.logo_asset_id)
            .where(Competition.id == competition_id)
        )
    ).first()
    if row is None:
        return None
    c, logo_path = row

    rh_rows = await session.execute(
        select(RightsHolder.id, RightsHolder.name, MediaAsset.path)
        .join(RightsHolderCompetition, RightsHolderCompetition.rights_holder_id == RightsHolder.id)
        .outerjoin(MediaAsset, MediaAsset.id == RightsHolder.logo_asset_id)
        .where(RightsHolderCompetition.competition_id == competition_id)
        .order_by(RightsHolder.name)
    )
    return s.CompetitionDetail(
        id=c.id,
        sport=c.sport,
        name=c.name,
        logo=media_url(logo_path),
        priority=c.priority,
        rights_holders=[s.NamedRef(id=r[0], name=r[1], logo=media_url(r[2])) for r in rh_rows],
    )


async def list_rights_holders(
    session: AsyncSession,
    satellite_id: int | None = None,
    competition_id: int | None = None,
) -> list[s.RightsHolder]:
    conditions = []
    if satellite_id is not None:
        conditions.append(
            RightsHolder.id.in_(
                select(RightsHolderCarriage.rights_holder_id)
                .join(
                    RightsHolderCarriageSatellite, RightsHolderCarriageSatellite.carriage_id == RightsHolderCarriage.id
                )
                .where(RightsHolderCarriageSatellite.satellite_id == satellite_id)
            )
        )
    if competition_id is not None:
        conditions.append(
            RightsHolder.id.in_(
                select(RightsHolderCompetition.rights_holder_id).where(
                    RightsHolderCompetition.competition_id == competition_id
                )
            )
        )
    rows = await session.execute(
        select(RightsHolder, MediaAsset.path)
        .outerjoin(MediaAsset, MediaAsset.id == RightsHolder.logo_asset_id)
        .where(*conditions)
        .order_by(RightsHolder.sort_order.asc().nulls_last(), RightsHolder.id.asc())
    )
    return [s.RightsHolder(id=r.id, name=r.name, logo=media_url(p), sort_order=r.sort_order) for r, p in rows]


async def get_rights_holder(session: AsyncSession, rights_holder_id: int) -> s.RightsHolderDetail | None:
    row = (
        await session.execute(
            select(RightsHolder, MediaAsset.path)
            .outerjoin(MediaAsset, MediaAsset.id == RightsHolder.logo_asset_id)
            .where(RightsHolder.id == rights_holder_id)
        )
    ).first()
    if row is None:
        return None
    rh, logo_path = row

    comp_rows = await session.execute(
        select(Competition.id, Competition.name, MediaAsset.path)
        .join(RightsHolderCompetition, RightsHolderCompetition.competition_id == Competition.id)
        .outerjoin(MediaAsset, MediaAsset.id == Competition.logo_asset_id)
        .where(RightsHolderCompetition.rights_holder_id == rights_holder_id)
        .order_by(Competition.name)
    )
    competitions = [s.NamedRef(id=r[0], name=r[1], logo=media_url(r[2])) for r in comp_rows]

    carriage_rows = await session.execute(
        select(RightsHolderCarriage)
        .where(RightsHolderCarriage.rights_holder_id == rights_holder_id)
        .order_by(RightsHolderCarriage.position)
    )
    carriage_list = list(carriage_rows.scalars())
    carriage_ids = [c.id for c in carriage_list]

    # Satellites and frequencies for every carriage: one query each, not one per carriage.
    satellites: dict[int, list[s.SatelliteRef]] = {cid: [] for cid in carriage_ids}
    sat_rows = await session.execute(
        select(RightsHolderCarriageSatellite.carriage_id, Satellite)
        .join(Satellite, Satellite.id == RightsHolderCarriageSatellite.satellite_id)
        .where(RightsHolderCarriageSatellite.carriage_id.in_(carriage_ids))
        .order_by(Satellite.orbital_position)
    )
    for carriage_id, st in sat_rows:
        satellites[carriage_id].append(
            s.SatelliteRef(
                id=st.id,
                slug=st.slug,
                name_ar=st.name_ar,
                name_en=st.name_en,
                orbital_position=float(st.orbital_position) if st.orbital_position is not None else None,
            )
        )
    frequencies: dict[int, list[s.RightsHolderFrequency]] = {cid: [] for cid in carriage_ids}
    freq_rows = await session.execute(
        select(RightsHolderFrequency)
        .where(RightsHolderFrequency.carriage_id.in_(carriage_ids))
        .order_by(RightsHolderFrequency.is_primary.desc(), RightsHolderFrequency.id)
    )
    for f in freq_rows.scalars():
        frequencies[f.carriage_id].append(
            s.RightsHolderFrequency(mhz=f.frequency_mhz, pol=f.polarization, sr=f.symbol_rate, is_primary=f.is_primary)
        )

    carriages = [
        s.RightsHolderCarriage(
            id=carriage.id,
            access=carriage.access,
            beam=carriage.beam,
            satellites=satellites[carriage.id],
            frequencies=frequencies[carriage.id],
        )
        for carriage in carriage_list
    ]

    return s.RightsHolderDetail(
        id=rh.id,
        name=rh.name,
        logo=media_url(logo_path),
        sort_order=rh.sort_order,
        competitions=competitions,
        carriages=carriages,
    )
