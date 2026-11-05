"""The public response cache, keyed by D1's ETag (research R10).

The ETag already holds the route, the canonical query and the dataset versions the route reads, so
``rc:<etag>`` is the exact cache identity and nothing else can drift from it. A write bumps a
version, so the next read computes a new tag and misses: no key is ever deleted by scan
(constitution VI). Redis errors fall through to the database and never become a 5xx.
"""

from __future__ import annotations

import logging
from collections.abc import Mapping
from typing import cast

import redis.asyncio as aioredis
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import Response

from app.settings import get_settings

log = logging.getLogger("madar.cache")

# SD §6.3.2's TTLs. A route id that isn't here is not cached (the admin app's routes included).
TTL_S: Mapping[str, int] = {
    "matches": 60,
    "match_detail": 15,
    "live": 15,
    "channel": 300,
    "satellites": 300,
    "satellite_channels": 300,
    "teams": 300,
    "team_detail": 300,
    "competitions": 3600,
    "competition_detail": 300,
    "rights_holders": 3600,
    "rights_holder_detail": 3600,
    "commentators": 300,
    "commentator_detail": 300,
}


class CachedResponse(Exception):
    """A hit: the stored envelope, answered with the same validator headers as the built one."""

    def __init__(self, etag: str, body: bytes) -> None:
        super().__init__(etag)
        self.etag = etag
        self.body = body


def ttl_for(route_id: str) -> int | None:
    return TTL_S.get(route_id)


def _client() -> aioredis.Redis:
    return cast(aioredis.Redis, aioredis.from_url(get_settings().redis_url))  # type: ignore[no-untyped-call]


async def lookup(etag: str) -> bytes | None:
    """The stored body for ``etag``, if any. Fail-open: a Redis error is a miss."""
    settings = get_settings()
    if not settings.response_cache_enabled:
        return None
    client = None
    try:
        client = _client()
        body = await client.get(f"rc:{etag}")
        if body is not None:
            log.info("cache_hit", extra={"etag": etag})
            return bytes(body)
        log.info("cache_miss", extra={"etag": etag})
        return None
    except Exception:  # noqa: BLE001 - the database is the fallback, never a 5xx
        log.warning("cache_lookup_failed", extra={"etag": etag})
        return None
    finally:
        if client is not None:
            await client.aclose()


async def store(etag: str, body: bytes, ttl: int | None) -> None:
    """Store the serialized envelope, skipping bodies over ``RESPONSE_CACHE_MAX_BYTES``."""
    settings = get_settings()
    if not settings.response_cache_enabled or ttl is None:
        return
    if len(body) > settings.response_cache_max_bytes:
        log.info("cache_skip_large", extra={"etag": etag, "bytes": len(body)})
        return
    client = None
    try:
        client = _client()
        await client.set(f"rc:{etag}", body, ex=ttl)
    except Exception:  # noqa: BLE001
        log.warning("cache_store_failed", extra={"etag": etag})
    finally:
        if client is not None:
            await client.aclose()


class ResponseCacheMiddleware(BaseHTTPMiddleware):
    """Stores each cacheable public ``200`` under its ETag (the ETag dependency already looked it up)."""

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        response = await call_next(request)
        ttl = getattr(request.state, "cache_ttl", None)
        etag = response.headers.get("etag")
        if request.method != "GET" or ttl is None or etag is None or response.status_code != 200:
            return response
        body = b"".join([chunk async for chunk in response.body_iterator])  # type: ignore[attr-defined]
        await store(etag, body, ttl)
        headers = {key: value for key, value in response.headers.items() if key.lower() != "content-length"}
        return Response(content=body, status_code=200, headers=headers, media_type=response.media_type)
