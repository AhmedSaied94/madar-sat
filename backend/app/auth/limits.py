"""Login limiting per email + client IP, in Redis (research R3, data-model "Redis keys").

- ``auth:fail:<h>:<ip>``: a sorted set of failure times, trimmed to the last 15 minutes.
- ``auth:lock:<h>:<ip>``: set (``EX 900``) by the fifth failure; while it exists, login answers
  ``429 account_locked`` and its TTL is ``retry_after_s``.

``<h>`` is the first 32 hex characters of ``sha256(lower(email))``, so no key holds an email.
An unknown email is counted exactly like a known one, so the responses reveal nothing.
"""

from __future__ import annotations

import hashlib
import ipaddress
import secrets
import time
from collections.abc import AsyncIterator

import redis.asyncio as aioredis
from fastapi import Request

from app.settings import get_settings

MAX_FAILURES = 5
WINDOW_S = 15 * 60
LOCK_S = 15 * 60
# Caddy on wg0 (infra): the only peer whose X-Forwarded-For we believe.
TRUSTED_PROXY = "10.8.0.1"


def email_hash(email: str) -> str:
    return hashlib.sha256(email.lower().encode()).hexdigest()[:32]


def client_ip(request: Request) -> str:
    """The caller's address: ``X-Forwarded-For`` counts only when the request comes from the proxy.

    Uvicorn runs with ``--proxy-headers --forwarded-allow-ips=10.8.0.1`` and so already rewrites
    ``request.client`` in production; this keeps the same rule where it doesn't (and in tests).
    The right-most hop that isn't the proxy is the one Caddy appended; anything left of it is
    client-controlled.
    """
    peer = request.client.host if request.client else "unknown"
    if peer != TRUSTED_PROXY:
        return peer
    hops = [hop.strip() for hop in request.headers.get("x-forwarded-for", "").split(",") if hop.strip()]
    for hop in reversed(hops):
        if hop == TRUSTED_PROXY:
            continue
        try:
            return str(ipaddress.ip_address(hop))
        except ValueError:
            return peer
    return peer


async def get_redis() -> AsyncIterator[aioredis.Redis]:
    """FastAPI dependency: one Redis client per request."""
    client = aioredis.from_url(get_settings().redis_url)  # type: ignore[no-untyped-call]
    try:
        yield client
    finally:
        await client.aclose()


class LoginLimiter:
    def __init__(self, redis: aioredis.Redis) -> None:
        self._redis = redis

    @staticmethod
    def _keys(email: str, ip: str) -> tuple[str, str]:
        suffix = f"{email_hash(email)}:{ip}"
        return f"auth:fail:{suffix}", f"auth:lock:{suffix}"

    async def locked_for(self, email: str, ip: str) -> int | None:
        """Seconds until the lock ends, or ``None`` when this email + IP isn't locked."""
        _, lock_key = self._keys(email, ip)
        ttl = int(await self._redis.ttl(lock_key))
        return max(ttl, 1) if ttl >= 0 else None

    async def record_failure(self, email: str, ip: str) -> int:
        """Count one failed login. Returns ``attempts_remaining`` (0 when this one locked the account)."""
        fail_key, lock_key = self._keys(email, ip)
        now = time.time()
        async with self._redis.pipeline(transaction=True) as pipe:
            pipe.zremrangebyscore(fail_key, 0, now - WINDOW_S)
            pipe.zadd(fail_key, {f"{now}:{secrets.token_hex(4)}": now})
            pipe.zcard(fail_key)
            pipe.expire(fail_key, WINDOW_S)
            _, _, count, _ = await pipe.execute()
        if int(count) >= MAX_FAILURES:
            await self._redis.set(lock_key, "1", ex=LOCK_S)
            return 0
        return MAX_FAILURES - int(count)

    async def clear(self, email: str, ip: str) -> None:
        fail_key, lock_key = self._keys(email, ip)
        await self._redis.delete(fail_key, lock_key)
