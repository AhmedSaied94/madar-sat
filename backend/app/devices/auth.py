"""The ``DeviceAuth`` dependency (research R2).

One dependency parses ``Authorization: Device <token>``, hashes it and loads the device. Missing,
malformed and unknown are one answer, ``401 unauthenticated``, so nothing leaks. ``last_seen_at``
is refreshed at most once an hour.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Annotated

from fastapi import Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_now
from app.api.errors import unauthenticated
from app.db.models import Device
from app.db.session import get_session
from app.devices.tokens import parse_header, token_hash

LAST_SEEN_INTERVAL = timedelta(hours=1)


def token_of(request: Request) -> str | None:
    """The device token carried by the request, if the header parses. Never raises."""
    return parse_header(request.headers.get("authorization"))


async def device_for_hash(session: AsyncSession, hashed: str) -> Device | None:
    return (await session.execute(select(Device).where(Device.token_hash == hashed))).scalar_one_or_none()


async def device_auth(
    request: Request,
    session: Annotated[AsyncSession, Depends(get_session)],
    now: Annotated[datetime, Depends(get_now)],
) -> Device:
    """The device behind ``Authorization: Device <token>``; ``401`` for anything else."""
    token = token_of(request)
    if token is None:
        raise unauthenticated()
    device = await device_for_hash(session, token_hash(token))
    if device is None:
        raise unauthenticated()
    if device.last_seen_at is None or device.last_seen_at < now - LAST_SEEN_INTERVAL:
        device.last_seen_at = now
    return device


DeviceDep = Annotated[Device, Depends(device_auth)]
