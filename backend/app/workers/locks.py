"""A Redis ``SET NX EX`` lock so two runs of one job never overlap (constitution VII)."""

from __future__ import annotations

import secrets
from collections.abc import Iterator
from contextlib import contextmanager

import redis

from app.workers.config import get_worker_settings

# Delete the key only if it still holds our token: the lock may have expired and been
# taken by another worker while we ran.
_RELEASE = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end"


@contextmanager
def redis_lock(name: str, ttl: int, client: redis.Redis | None = None) -> Iterator[bool]:
    """Yield ``True`` when the lock was taken, ``False`` when someone else holds it.

    ``ttl`` (seconds) is the safety net: a crashed worker cannot hold the lock for longer.
    The body must check the yielded value and skip its work on ``False``.
    """
    own = client is None
    conn = client or redis.Redis.from_url(get_worker_settings().broker_url)
    token = secrets.token_hex(16)
    acquired = bool(conn.set(name, token, nx=True, ex=ttl))
    try:
        yield acquired
    finally:
        try:
            if acquired:
                conn.eval(_RELEASE, 1, name, token)
        finally:
            if own:
                conn.close()
