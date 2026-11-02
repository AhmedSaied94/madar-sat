"""Rate limits on ``/v1`` (research R11, constitution V).

A short dependency on every public router only (the admin app has none). The window is two fixed
buckets, weighted: memory per key is one counter, and the limit is enforced to within a minute.

The key is the device token's hash **only when that hash belongs to a live device**, otherwise the
trusted client IP. A client that sends a fresh made-up token on every request therefore cannot
escape the IP limit. ``/healthz`` is exempt. Redis down → allow: a cache outage never takes the API
down.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Annotated, cast

import redis.asyncio as aioredis
from fastapi import Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_now
from app.api.errors import ApiError, rate_limited
from app.auth.limits import client_ip
from app.db.models import Device
from app.db.session import get_session
from app.devices.tokens import parse_header, token_hash
from app.settings import get_settings

log = logging.getLogger("madar.ratelimit")

VALID_HASH_TTL_S = 10 * 60
INVALID_HASH_TTL_S = 60
REGISTER_WINDOW_S = 10 * 60
HEALTH_PATH = "/healthz"


def _client() -> aioredis.Redis:
    return cast(aioredis.Redis, aioredis.from_url(get_settings().redis_url))  # type: ignore[no-untyped-call]


async def _valid_device_hash(client: aioredis.Redis, session: AsyncSession, hashed: str) -> bool:
    """Whether ``hashed`` belongs to a live device, cached in Redis (10 min valid, 60 s invalid).

    Rotating or deleting a device deletes ``dv:<hash>`` (``app.devices.service``), so a revoked
    token stops counting as valid at once instead of when the cache expires.
    """
    key = f"dv:{hashed}"
    cached = await client.get(key)
    if cached == b"1":
        return True
    if cached == b"0":
        return False
    found = (await session.execute(select(Device.id).where(Device.token_hash == hashed))).first() is not None
    await client.set(key, "1" if found else "0", ex=VALID_HASH_TTL_S if found else INVALID_HASH_TTL_S)
    return found


async def _window(client: aioredis.Redis, prefix: str, window_s: int, limit: int, now: datetime) -> int | None:
    """Count one request; returns ``retry_after_s`` when over the limit, else ``None``."""
    stamp = now.timestamp()
    slot = int(stamp // window_s)
    key = f"{prefix}:{slot}"
    count = int(await client.incr(key))
    await client.expire(key, window_s * 2)
    previous = int(await client.get(f"{prefix}:{slot - 1}") or 0)
    elapsed = stamp - slot * window_s
    weighted = count + previous * max(1.0 - elapsed / window_s, 0.0)
    if weighted > limit:
        return max(int(window_s - elapsed), 1)
    return None


async def rate_limit(
    request: Request,
    session: Annotated[AsyncSession, Depends(get_session)],
    now: Annotated[datetime, Depends(get_now)],
) -> None:
    """Enforce the per-device, per-IP and register windows; ``429 rate_limited`` over a limit."""
    settings = get_settings()
    if request.url.path == HEALTH_PATH:
        return

    client = None
    try:
        client = _client()
        ip = client_ip(request)
        token = parse_header(request.headers.get("authorization"))
        hashed = token_hash(token) if token else None
        verified = await _valid_device_hash(client, session, hashed) if hashed else False

        retry: int | None = None
        if request.method == "POST" and request.url.path == "/v1/devices":
            retry = await _window(
                client, f"rl:reg:{ip}", REGISTER_WINDOW_S, settings.rate_limit_register_per_10min, now
            )
        if retry is None:
            if verified and hashed is not None:
                retry = await _window(client, f"rl:d:{hashed[:16]}", 60, settings.rate_limit_device_per_min, now)
            else:
                retry = await _window(client, f"rl:ip:{ip}", 60, settings.rate_limit_ip_per_min, now)
        if retry is not None:
            raise rate_limited(retry)
    except ApiError:
        raise
    except Exception:  # noqa: BLE001 - Redis down must never refuse a request
        log.warning("ratelimit_unavailable")
    finally:
        if client is not None:
            await client.aclose()
