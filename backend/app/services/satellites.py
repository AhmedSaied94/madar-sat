"""``/v1/satellites`` and ``/v1/satellites/{id}/channels`` read queries."""

from __future__ import annotations

from sqlalchemy import String, false, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Channel, MediaAsset, Satellite
from app.domain.arabic import ar_normalize
from app.schemas import public as s
from app.services.common import hidden_names, media_url


def _satellite_frequency(mhz: int | None, pol: str | None, sr: int | None) -> s.Frequency | None:
    if mhz is None:
        return None
    return s.Frequency(mhz=mhz, pol=pol, sr=sr)


async def list_satellites(session: AsyncSession) -> list[s.Satellite]:
    sat_rows = (
        await session.execute(
            select(Satellite, MediaAsset.path)
            .outerjoin(MediaAsset, MediaAsset.id == Satellite.logo_asset_id)
            .order_by(Satellite.priority.asc().nulls_last(), Satellite.orbital_position.asc())
        )
    ).all()

    # Visible carriage counts, batched in one query.
    count_rows = await session.execute(
        select(
            Channel.satellite_id,
            func.count(Channel.id),
        )
        .where(
            Channel.satellite_id.is_not(None),
            Channel.deleted_at.is_(None),
            Channel.name_norm.not_in(hidden_names()),
            func.ar_normalize(func.coalesce(Channel.display_name, "")).not_in(hidden_names()),
        )
        .group_by(Channel.satellite_id)
    )
    counts = {r[0]: r[1] for r in count_rows}

    result: list[s.Satellite] = []
    for sat, logo_path in sat_rows:
        result.append(
            s.Satellite(
                id=sat.id,
                slug=sat.slug,
                name_ar=sat.name_ar,
                name_en=sat.name_en,
                orbital_position=float(sat.orbital_position) if sat.orbital_position is not None else None,
                kind=sat.kind,
                logo=media_url(logo_path),
                channel_count=counts.get(sat.id, 0),
                best_frequency=_satellite_frequency(
                    sat.best_frequency_mhz, sat.best_polarization, sat.best_symbol_rate
                ),
                worst_frequency=_satellite_frequency(
                    sat.worst_frequency_mhz, sat.worst_polarization, sat.worst_symbol_rate
                ),
                reception_url=sat.reception_url,
            )
        )
    return result


async def list_satellite_channels(
    session: AsyncSession,
    satellite_id: int,
    category: str | None = None,
    q: str | None = None,
) -> list[s.ChannelCarriage] | None:
    sat = (await session.execute(select(Satellite.id).where(Satellite.id == satellite_id))).first()
    if sat is None:
        return None

    conditions = [Channel.satellite_id == satellite_id, Channel.deleted_at.is_(None)]
    if category:
        conditions.append(Channel.category == category)
    if q:
        # ar_normalize turns punctuation (LIKE's "%" and "_" included) into spaces, so a
        # query of symbols alone is empty and must match nothing, not every channel.
        normalized = ar_normalize(q)
        matches_q = Channel.name_norm.contains(normalized, autoescape=True) if normalized else false()
        digits = q.strip()
        if digits.isascii() and digits.isdigit():
            matches_q |= func.cast(Channel.frequency_mhz, String).startswith(digits, autoescape=True)
        conditions.append(matches_q)

    rows = await session.execute(
        select(Channel, Satellite, MediaAsset.path)
        .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
        .outerjoin(MediaAsset, MediaAsset.id == Channel.logo_asset_id)
        .where(*conditions)
        .order_by(Channel.sort_order.asc().nulls_last(), Channel.name.asc())
    )
    result: list[s.ChannelCarriage] = []
    for ch, sref, logo_path in rows:
        result.append(_carriage(ch, sref, logo_path))
    return result


def _satellite_ref(sat: Satellite | None) -> s.SatelliteRef | None:
    if sat is None:  # platform channels have no satellite
        return None
    return s.SatelliteRef(
        id=sat.id,
        slug=sat.slug,
        name_ar=sat.name_ar,
        name_en=sat.name_en,
        orbital_position=float(sat.orbital_position) if sat.orbital_position is not None else None,
    )


def _carriage(ch: Channel, sat: Satellite | None, logo_path: str | None) -> s.ChannelCarriage:
    return s.ChannelCarriage(
        id=ch.id,
        kind=ch.kind,
        name=ch.name,
        display_name=ch.display_name,
        logo=media_url(logo_path),
        category=ch.category,
        satellite=_satellite_ref(sat),
        frequency=_satellite_frequency(ch.frequency_mhz, ch.polarization, ch.symbol_rate),
        frequency_note=ch.frequency_note,
        access=ch.access,
        provider=ch.provider,
        package=ch.package,
        beam=ch.beam,
        country=ch.country,
        frequency_changed_at=ch.frequency_changed_at,
    )
