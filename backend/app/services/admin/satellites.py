"""Satellites: read, create, update and delete."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound
from app.auth.roles import AuthedAdmin
from app.db.models import Channel, RightsHolderCarriageSatellite, Satellite
from app.schemas import admin as a
from app.schemas.public import Frequency, Polarization
from app.services.admin import refs, versions, writer
from app.services.admin.common import asset_urls, refuse_if_in_use, sent, tuning_errors, url_of

ENTITY = "satellites"
NOT_FOUND = "satellite_not_found"
PLAIN_COLUMNS = ("slug", "name_en", "name_ar", "logo_asset_id", "reception_url", "priority")


async def get(session: AsyncSession, satellite_id: int) -> Satellite:
    satellite = await session.get(Satellite, satellite_id)
    if satellite is None:
        raise EntityNotFound(NOT_FOUND)
    return satellite


def _frequency(mhz: int | None, pol: str | None, sr: int | None) -> Frequency | None:
    if mhz is None or pol is None or sr is None:
        return None
    return Frequency(mhz=mhz, pol=Polarization(pol), sr=sr)


def to_view(satellite: Satellite, logo: str | None) -> a.AdminSatellite:
    orbit = satellite.orbital_position
    return a.AdminSatellite(
        id=satellite.id,
        slug=satellite.slug,
        kind=satellite.kind,
        name_en=satellite.name_en,
        name_ar=satellite.name_ar,
        orbital_position=float(orbit) if orbit is not None else None,
        logo_asset_id=satellite.logo_asset_id,
        logo=logo,
        best_frequency=_frequency(
            satellite.best_frequency_mhz, satellite.best_polarization, satellite.best_symbol_rate
        ),
        worst_frequency=_frequency(
            satellite.worst_frequency_mhz, satellite.worst_polarization, satellite.worst_symbol_rate
        ),
        reception_url=satellite.reception_url,
        priority=satellite.priority,
        etag=versions.row_version(satellite),
    )


async def view(session: AsyncSession, satellite: Satellite) -> a.AdminSatellite:
    urls = await asset_urls(session, [satellite.logo_asset_id])
    return to_view(satellite, url_of(urls, satellite.logo_asset_id))


async def version(session: AsyncSession, satellite: Satellite) -> str:
    return versions.row_version(satellite)


def _set_tuning(satellite: Satellite, prefix: str, frequency: Frequency | None) -> None:
    setattr(satellite, f"{prefix}_frequency_mhz", frequency.mhz if frequency else None)
    setattr(satellite, f"{prefix}_polarization", frequency.pol.value if frequency else None)
    setattr(satellite, f"{prefix}_symbol_rate", frequency.sr if frequency else None)


async def _check(
    session: AsyncSession,
    *,
    logo_asset_id: int | None,
    best: Frequency | None,
    worst: Frequency | None,
) -> None:
    errors = await refs.missing_assets(session, [(logo_asset_id, refs.IMAGE_KINDS, ["logo_asset_id"])])
    errors += tuning_errors(best, ["best_frequency"]) + tuning_errors(worst, ["worst_frequency"])
    refs.raise_if_any(errors)


async def create(session: AsyncSession, admin: AuthedAdmin, body: a.SatelliteCreate) -> Satellite:
    await _check(session, logo_asset_id=body.logo_asset_id, best=body.best_frequency, worst=body.worst_frequency)
    satellite = Satellite(
        slug=body.slug,
        kind=body.kind,
        name_en=body.name_en,
        name_ar=body.name_ar,
        orbital_position=Decimal(str(body.orbital_position)) if body.orbital_position is not None else None,
        logo_asset_id=body.logo_asset_id,
        reception_url=body.reception_url,
        priority=body.priority,
    )
    _set_tuning(satellite, "best", body.best_frequency)
    _set_tuning(satellite, "worst", body.worst_frequency)
    session.add(satellite)
    await writer.save_create(session, admin, entity=ENTITY, row=satellite, datasets=writer.SATELLITE_CHANGED)
    return satellite


async def update(
    session: AsyncSession,
    admin: AuthedAdmin,
    satellite_id: int,
    body: a.SatellitePatch,
    if_match: str | None,
    now: datetime,
) -> Satellite:
    satellite = await writer.lock_and_check(session, Satellite, satellite_id, NOT_FOUND, ENTITY, if_match)
    changes = sent(body)
    errors = [
        refs.field_error([name], "null_not_allowed")
        for name in ("slug", "name_en", "name_ar")
        if name in changes and changes[name] is None
    ]
    if "orbital_position" in changes and (changes["orbital_position"] is None) == (satellite.kind == "satellite"):
        errors.append(
            refs.field_error(["orbital_position"], "required" if satellite.kind == "satellite" else "not_allowed")
        )
    refs.raise_if_any(errors)
    await _check(
        session,
        logo_asset_id=changes.get("logo_asset_id"),
        best=changes.get("best_frequency"),
        worst=changes.get("worst_frequency"),
    )

    before = versions.row_state(satellite)
    for column in PLAIN_COLUMNS:
        if column in changes:
            setattr(satellite, column, changes[column])
    if "orbital_position" in changes:
        orbit: Any = changes["orbital_position"]
        satellite.orbital_position = Decimal(str(orbit)) if orbit is not None else None
    if "best_frequency" in changes:
        _set_tuning(satellite, "best", changes["best_frequency"])
    if "worst_frequency" in changes:
        _set_tuning(satellite, "worst", changes["worst_frequency"])

    await writer.save_update(
        session,
        admin,
        entity=ENTITY,
        row=satellite,
        before=before,
        datasets=writer.SATELLITE_CHANGED,
        now=now,
    )
    return satellite


async def remove(
    session: AsyncSession, admin: AuthedAdmin, satellite_id: int, if_match: str | None, now: datetime
) -> None:
    satellite = await writer.lock_and_check(session, Satellite, satellite_id, NOT_FOUND, ENTITY, if_match)
    await refuse_if_in_use(
        session,
        {
            "channels": select(Channel.id).where(Channel.satellite_id == satellite.id),
            "rights": select(RightsHolderCarriageSatellite.carriage_id).where(
                RightsHolderCarriageSatellite.satellite_id == satellite.id
            ),
        },
    )
    await writer.save_delete(session, admin, entity=ENTITY, row=satellite, datasets=writer.SATELLITE_CHANGED, now=now)
