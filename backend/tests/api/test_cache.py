"""The response cache: hit, version invalidation, size cap, fail-open and 304 (T022)."""

from __future__ import annotations

from sqlalchemy import update

from app.api import cache
from app.db.models import DatasetVersion, Satellite
from app.settings import get_settings


async def test_a_second_identical_read_is_served_from_the_etag_key(public_client, redis_client, monkeypatch):
    first = await public_client.get("/v1/satellites")
    assert first.status_code == 200
    etag = first.headers["etag"]
    assert await redis_client.exists(f"rc:{etag}")

    # The route's query must not run on a hit: make it explode if it does.
    async def boom(*args, **kwargs):
        raise AssertionError("the database query ran on a cache hit")

    monkeypatch.setattr("app.services.satellites.list_satellites", boom)
    second = await public_client.get("/v1/satellites")

    assert second.status_code == 200
    assert second.json() == first.json()


async def test_bumping_a_dataset_the_route_reads_misses_and_returns_the_new_data(public_client, session, redis_client):
    first = await public_client.get("/v1/satellites")
    old_etag = first.headers["etag"]
    assert await redis_client.exists(f"rc:{old_etag}")

    satellite = Satellite(slug="cache-test-sat", name_en="Cache", name_ar="كاش", kind="satellite", orbital_position=1.0)
    session.add(satellite)
    await session.flush()
    await session.execute(update(DatasetVersion).values(version=DatasetVersion.version + 1))

    second = await public_client.get("/v1/satellites")

    assert second.status_code == 200
    assert second.headers["etag"] != old_etag
    assert "cache-test-sat" in second.text


async def test_bumping_an_unrelated_dataset_still_hits(public_client, session, redis_client, monkeypatch):
    first = await public_client.get("/v1/satellites")
    await session.execute(update(DatasetVersion).where(DatasetVersion.name == "rights_holders").values(version=99))

    async def boom(*args, **kwargs):
        raise AssertionError("the database query ran on a cache hit")

    monkeypatch.setattr("app.services.satellites.list_satellites", boom)
    second = await public_client.get("/v1/satellites")

    assert second.status_code == 200
    assert second.headers["etag"] == first.headers["etag"]


async def test_a_body_over_the_cap_is_not_stored(public_client, redis_client, monkeypatch):
    monkeypatch.setattr(get_settings(), "response_cache_max_bytes", 10)

    response = await public_client.get("/v1/satellites")

    assert response.status_code == 200
    assert not await redis_client.exists(f"rc:{response.headers['etag']}")


async def test_redis_down_still_serves_from_the_database(public_client, monkeypatch):
    def broken():
        raise ConnectionError("redis is down")

    monkeypatch.setattr(cache, "_client", broken)

    response = await public_client.get("/v1/satellites")

    assert response.status_code == 200
    assert response.json()["success"] is True


async def test_device_responses_are_never_cached(device_client, redis_client):
    response = await device_client.put("/v1/devices/me", json={"app_version": "0.5.0"})

    assert response.status_code == 200
    assert response.headers["cache-control"] == "no-store"
    assert "etag" not in response.headers
    assert [key async for key in redis_client.scan_iter(match="rc:*")] == []


async def test_a_matching_if_none_match_is_still_a_304(public_client):
    first = await public_client.get("/v1/satellites")
    etag = first.headers["etag"]

    response = await public_client.get("/v1/satellites", headers={"If-None-Match": etag})

    assert response.status_code == 304
    assert response.headers["etag"] == etag


def test_the_ttls_follow_the_system_design():
    assert cache.ttl_for("matches") == 60
    assert cache.ttl_for("match_detail") == 15
    assert cache.ttl_for("channel") == 300
    assert cache.ttl_for("competitions") == 3600
    assert cache.ttl_for("admin_sources") is None
