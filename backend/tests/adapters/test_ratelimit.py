"""The per-host token bucket: rates, bursts, atomicity and expiry (T056, R14)."""

from __future__ import annotations

import os
from concurrent.futures import ThreadPoolExecutor

import pytest
import redis

from app.adapters.ratelimit import FIREBASE_BUCKET, YSSCORES_BUCKET, Bucket, RateLimiter


@pytest.fixture
def client() -> redis.Redis:
    r = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
    r.flushdb()
    yield r
    r.flushdb()
    r.close()


@pytest.fixture
def limiter(client: redis.Redis) -> RateLimiter:
    return RateLimiter(client=client)


def test_ysscores_allows_one_request_per_four_seconds_with_a_burst_of_two(limiter: RateLimiter) -> None:
    assert YSSCORES_BUCKET == Bucket(capacity=2, refill_seconds=4.0)
    assert limiter.take("www.ysscores.com", now=1_000.0) is True
    assert limiter.take("www.ysscores.com", now=1_000.0) is True  # the burst
    assert limiter.take("www.ysscores.com", now=1_000.0) is False
    assert limiter.take("www.ysscores.com", now=1_003.0) is False  # not yet a full token
    assert limiter.take("www.ysscores.com", now=1_004.0) is True


def test_firestore_allows_five_requests_per_second(limiter: RateLimiter) -> None:
    assert FIREBASE_BUCKET == Bucket(capacity=5, refill_seconds=1.0)
    allowed = sum(limiter.take("firestore.googleapis.com", now=2_000.0) for _ in range(6))
    assert allowed == 5
    assert limiter.take("firestore.googleapis.com", now=2_000.2) is False
    assert limiter.take("firestore.googleapis.com", now=2_001.0) is True


def test_each_host_has_its_own_bucket(limiter: RateLimiter) -> None:
    assert limiter.take("www.ysscores.com", now=3_000.0) is True
    assert limiter.take("www.ysscores.com", now=3_000.0) is True
    assert limiter.take("firestore.googleapis.com", now=3_000.0) is True


def test_the_bucket_is_atomic_under_concurrent_callers(client: redis.Redis) -> None:
    # One token: exactly one of two simultaneous callers may take it.
    limiter = RateLimiter(client=client, limits={"race.example": Bucket(capacity=1, refill_seconds=60.0)})
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: limiter.take("race.example", now=4_000.0), range(2)))
    assert sorted(results) == [False, True]


def test_the_bucket_expires_after_an_hour_idle(client: redis.Redis) -> None:
    limiter = RateLimiter(client=client)
    limiter.take("www.ysscores.com", now=5_000.0)
    ttl = client.ttl("ratelimit:www.ysscores.com")
    assert 0 < ttl <= 3600
    # A bucket that expired starts full again.
    client.delete("ratelimit:www.ysscores.com")
    assert limiter.take("www.ysscores.com", now=9_000.0) is True
    assert limiter.take("www.ysscores.com", now=9_000.0) is True


def test_an_unknown_host_is_not_limited(client: redis.Redis) -> None:
    limiter = RateLimiter(client=client)
    assert all(limiter.take("unknown.example", now=6_000.0) for _ in range(10))
