"""Login limiting per email + client IP, in Redis (research R3, data-model "Redis keys").

- ``auth:fail:<h>:<ip>``: a sorted set of failure times, trimmed to the last 15 minutes.
- ``auth:lock:<h>:<ip>``: set (``EX 900``) by the fifth failure; while it exists, login answers
  ``429 account_locked`` and its TTL is ``retry_after_s``.

``<h>`` is the first 32 hex characters of ``sha256(lower(email))``, so no key holds an email.
An unknown email is counted exactly like a known one, so the responses reveal nothing.

The attempt is reserved *before* the password is checked, in one Lua script, so a burst of parallel
requests can't all pass the lock check and get their password verified (FR-003, SC-003).
"""

from __future__ import annotations

import hashlib
import ipaddress
import secrets
import time
from collections.abc import AsyncIterator
from dataclasses import dataclass

import redis.asyncio as aioredis
from fastapi import Request

from app.settings import get_settings

MAX_FAILURES = 5
WINDOW_S = 15 * 60
LOCK_S = 15 * 60
# Caddy on wg0 (infra): the only peer whose X-Forwarded-For we believe.
TRUSTED_PROXY = "10.8.0.1"

# One attempt, counted and locked atomically: five failures in the window lock the email + IP.
_RESERVE = """
local fail_key, lock_key = KEYS[1], KEYS[2]
local now = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local max_failures = tonumber(ARGV[3])
local lock_s = tonumber(ARGV[4])
redis.call('ZREMRANGEBYSCORE', fail_key, 0, now - window)
redis.call('ZADD', fail_key, now, ARGV[5])
local count = redis.call('ZCARD', fail_key)
redis.call('EXPIRE', fail_key, window)
if count >= max_failures then
  redis.call('SET', lock_key, '1', 'EX', lock_s)
end
local ttl = redis.call('TTL', lock_key)
if ttl < 0 then ttl = lock_s end
return {count, ttl}
"""


@dataclass(frozen=True)
class Attempt:
    """One reserved login attempt: whether the password may be checked, and what to answer when not."""

    allowed: bool
    attempts_remaining: int
    retry_after_s: int


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

    async def reserve(self, email: str, ip: str) -> Attempt:
        """Count one attempt and decide whether the password may be checked at all.

        The count, the lock and their TTLs are written in one script, so two requests arriving
        together can't both read a count below the limit. The sixth attempt is refused here, before
        the admin lookup and the hash check; a success must call :meth:`clear`.
        """
        fail_key, lock_key = self._keys(email, ip)
        now = time.time()
        count, ttl = await self._redis.execute_command(  # type: ignore[no-untyped-call]  # redis' stubs
            "EVAL",
            _RESERVE,
            2,
            fail_key,
            lock_key,
            f"{now:.6f}",
            str(WINDOW_S),
            str(MAX_FAILURES),
            str(LOCK_S),
            f"{now:.6f}:{secrets.token_hex(4)}",
        )
        count = int(count)
        return Attempt(
            allowed=count <= MAX_FAILURES,
            attempts_remaining=max(MAX_FAILURES - count, 0),
            retry_after_s=max(int(ttl), 1),
        )

    async def clear(self, email: str, ip: str) -> None:
        fail_key, lock_key = self._keys(email, ip)
        await self._redis.delete(fail_key, lock_key)
