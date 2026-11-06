"""Per-host token buckets in Redis, one atomic Lua script (T056/T069, R14, FR-020).

The bucket is a hash at ``ratelimit:<host>`` holding the tokens left and the last refill time. A
caller asks for one token; ``take`` returns ``False`` when none is left, so the fetch task can
retry later with backoff instead of blocking a worker. Keys expire after an hour idle
(data-model §Redis keys).
"""

from __future__ import annotations

import math
import time
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Protocol

import redis


@dataclass(frozen=True, slots=True)
class Bucket:
    """A burst of ``capacity`` requests, then one more every ``refill_seconds``."""

    capacity: int
    refill_seconds: float


YSSCORES_BUCKET = Bucket(capacity=2, refill_seconds=4.0)
FIREBASE_BUCKET = Bucket(capacity=5, refill_seconds=1.0)
# R14: one request every four seconds to LiveSoccerTV, never a burst.
LIVESOCCERTV_BUCKET = Bucket(capacity=1, refill_seconds=4.0)
# D5 R3: the live poller and the `yallakora` importer spend one bucket per host, through one key.
FILGOAL_BUCKET = Bucket(capacity=2, refill_seconds=4.0)
YALLAKORA_BUCKET = Bucket(capacity=2, refill_seconds=4.0)
# Spec 031 FR-015: the other live hosts' rate. One list page and `LIVE_PAGE_CAP_GOAL` (4) match pages a
# minute need 5 of its 15 tokens, which leaves room for retries.
GOAL_BUCKET = Bucket(capacity=2, refill_seconds=4.0)
# D6 R21: one request every 700 ms to sporteventz, and never a burst.
SPORTEVENTZ_BUCKET = Bucket(capacity=1, refill_seconds=0.7)

DEFAULT_LIMITS: Mapping[str, Bucket] = {
    "www.ysscores.com": YSSCORES_BUCKET,
    "firestore.googleapis.com": FIREBASE_BUCKET,
    "www.livesoccertv.com": LIVESOCCERTV_BUCKET,
    "www.filgoal.com": FILGOAL_BUCKET,
    "www.yallakora.com": YALLAKORA_BUCKET,
    "www.goal.com": GOAL_BUCKET,
    "www.sporteventz.com": SPORTEVENTZ_BUCKET,
}

TTL_SECONDS = 3600

# KEYS[1] = bucket, ARGV = capacity, refill_seconds, now (float seconds), ttl.
# Returns 1 when a token was taken, 0 when the bucket is empty. Redis runs scripts atomically,
# so two concurrent callers can never take the last token twice.
_BUCKET_LUA = """
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill = tonumber(ARGV[2])
local now = tonumber(ARGV[3])
local ttl = tonumber(ARGV[4])

local data = redis.call('HMGET', key, 'tokens', 'ts')
local tokens = tonumber(data[1])
local ts = tonumber(data[2])
if tokens == nil or ts == nil then
  tokens = capacity
  ts = now
end

local elapsed = math.max(0, now - ts)
tokens = math.min(capacity, tokens + elapsed / refill)

local allowed = 0
-- Epsilon: the timestamps are floats, and 0.2 + 0.8 must count as one token.
if tokens >= 1 - 1e-6 then
  tokens = tokens - 1
  allowed = 1
end

redis.call('HSET', key, 'tokens', string.format('%.6f', tokens), 'ts', string.format('%.6f', now))
redis.call('EXPIRE', key, ttl)
return allowed
"""


class TokenBucket(Protocol):
    def take(self, host: str, now: float | None = None) -> bool: ...


class RateLimiter:
    """The token bucket over a Redis client; hosts without a bucket are not limited."""

    def __init__(
        self,
        client: redis.Redis,
        limits: Mapping[str, Bucket] = DEFAULT_LIMITS,
        ttl_seconds: int = TTL_SECONDS,
    ) -> None:
        self._client = client
        self._limits = dict(limits)
        self._ttl = ttl_seconds
        self._script = client.register_script(_BUCKET_LUA)

    def take(self, host: str, now: float | None = None) -> bool:
        bucket = self._limits.get(host)
        if bucket is None:
            return True
        timestamp = time.time() if now is None else now
        result = self._script(
            keys=[f"ratelimit:{host}"],
            args=[bucket.capacity, f"{bucket.refill_seconds:.6f}", f"{timestamp:.6f}", self._ttl],
        )
        return bool(int(result))


def seconds_until_token(bucket: Bucket) -> int:
    """How long a caller should wait for the next token, rounded up (used in log lines)."""
    return math.ceil(bucket.refill_seconds)
