"""Device registration, update and delete (research R1, R2, R3, R4).

Registration is an upsert on ``install_id``: a known install id keeps its ``device_id``, its
follows and its settings, and gets a new token (the old one stops working at once). Every response
carries ``Cache-Control: no-store`` from the router, and no response ever holds the token again.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import cast

import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy import update as sa_update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import unknown_satellite
from app.db.models import Device, Satellite
from app.devices.tokens import new_token, token_hash
from app.schemas import public as s
from app.settings import get_settings

log = logging.getLogger("madar.devices")

VALID_HASH_TTL_S = 10 * 60


def view(device: Device) -> s.Device:
    """The response: what the server stores, without the token or its hash."""
    return s.Device(
        device_id=device.id,
        platform=device.platform,
        app_version=device.app_version,
        tz=device.tz,
        locale=device.locale,
        satellite_ids=list(device.satellite_ids or []),
        has_push_token=device.push_token is not None,
        prefs=s.NotificationPrefs.with_defaults(device.prefs),
    )


async def register(session: AsyncSession, body: s.DeviceRegister, now: datetime) -> tuple[Device, str]:
    """Register or rotate; returns the row and the new token (the only time it is ever returned)."""
    token = new_token()
    hashed = token_hash(token)
    device = (await session.execute(select(Device).where(Device.install_id == body.install_id))).scalar_one_or_none()
    if device is None:
        device = Device(
            install_id=body.install_id,
            token_hash=hashed,
            platform=body.platform,
            prefs={},
            satellite_ids=[],
            last_seen_at=now,
        )
        session.add(device)
    else:
        await forget_valid_hash(device.token_hash)
        device.token_hash = hashed
        device.platform = body.platform
    await session.flush()
    await remember_valid_hash(hashed)
    return device, token


async def update(session: AsyncSession, device: Device, body: s.DeviceUpdate) -> Device:
    """Apply the fields the request sent; an omitted field is unchanged and ``null`` clears it."""
    sent = body.model_fields_set
    if "push_token" in sent:
        if body.push_token is not None:
            # A push token identifies one installation: it moves here, the old holder loses it.
            await session.execute(
                sa_update(Device)
                .where(Device.push_token == body.push_token, Device.id != device.id)
                .values(push_token=None)
            )
        device.push_token = body.push_token
    if "app_version" in sent:
        device.app_version = body.app_version
    if "tz" in sent:
        device.tz = body.tz
    if "locale" in sent:
        device.locale = body.locale
    if "satellite_ids" in sent:
        device.satellite_ids = await _known_satellites(session, body.satellite_ids or [])
    if "prefs" in sent:
        device.prefs = body.prefs.model_dump(mode="json") if body.prefs is not None else {}
    await session.flush()
    return device


async def remove(session: AsyncSession, device: Device) -> None:
    """Delete the device; its follows cascade and its token stops working."""
    await forget_valid_hash(device.token_hash)
    await session.delete(device)


async def _known_satellites(session: AsyncSession, ids: list[int]) -> list[int]:
    """De-duplicate and keep the order, refusing ids that don't exist (``422 unknown_satellite``)."""
    wanted = list(dict.fromkeys(ids))
    if not wanted:
        return []
    found = set((await session.scalars(select(Satellite.id).where(Satellite.id.in_(wanted)))).all())
    missing = [sat_id for sat_id in wanted if sat_id not in found]
    if missing:
        raise unknown_satellite(missing)
    return wanted


def _redis() -> aioredis.Redis:
    return cast(aioredis.Redis, aioredis.from_url(get_settings().redis_url))  # type: ignore[no-untyped-call]


async def remember_valid_hash(hashed: str) -> None:
    """``dv:<hash>``: the rate limiter's cache of live device tokens (research R11); fail-open."""
    client = _redis()
    try:
        await client.set(f"dv:{hashed}", "1", ex=VALID_HASH_TTL_S)
    except Exception:  # noqa: BLE001 - a Redis outage must never refuse a registration
        log.warning("valid_hash_cache_write_failed")
    finally:
        await client.aclose()


async def forget_valid_hash(hashed: str) -> None:
    """Drop the cached hash on rotate and delete, so a revoked token stops counting as valid at once."""
    client = _redis()
    try:
        await client.delete(f"dv:{hashed}")
    except Exception:  # noqa: BLE001
        log.warning("valid_hash_cache_delete_failed")
    finally:
        await client.aclose()
