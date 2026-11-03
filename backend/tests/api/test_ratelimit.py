"""Rate limits on /v1: device vs IP, windows, fail-open and the healthz exemption (T023).

D4 adds the env-only allowlist for the load-test window (research R3, FR-007): an exact client IP
skips the limiter, everybody else keeps theirs, and a non-empty list is loud at startup.
"""

from __future__ import annotations

import logging
from uuid import uuid4

from fastapi import Request

from app.api import ratelimit
from app.auth.limits import client_ip
from app.devices.tokens import token_hash
from app.settings import get_settings


def _tighten(monkeypatch, *, device: int = 120, ip: int = 600, register: int = 30) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "rate_limit_device_per_min", device)
    monkeypatch.setattr(settings, "rate_limit_ip_per_min", ip)
    monkeypatch.setattr(settings, "rate_limit_register_per_10min", register)


async def test_over_the_ip_limit_is_429_with_retry_after_and_meta(public_client, monkeypatch):
    _tighten(monkeypatch, ip=2)

    answers = [await public_client.get("/v1/satellites") for _ in range(3)]

    assert [answer.status_code for answer in answers] == [200, 200, 429]
    refused = answers[-1]
    assert refused.json()["error"]["code"] == "rate_limited"
    assert int(refused.headers["retry-after"]) >= 1
    assert refused.json()["meta"]["retry_after_s"] == int(refused.headers["retry-after"])


async def test_a_verified_token_is_counted_per_device_not_per_ip(public_client, device_client, monkeypatch):
    _tighten(monkeypatch, device=2, ip=3)
    # The device client's header is verified; one IP limit would refuse its second call.
    for _ in range(2):
        assert (await device_client.get("/v1/satellites")).status_code == 200
    assert (await device_client.get("/v1/satellites")).status_code == 429

    # The same IP, no device header: its own bucket, still fresh.
    public_client.headers.pop("authorization", None)
    assert (await public_client.get("/v1/satellites")).status_code == 200


async def test_a_made_up_token_each_time_still_hits_the_ip_limit(public_client, monkeypatch):
    _tighten(monkeypatch, ip=2)
    statuses = []
    for _ in range(4):
        token = uuid4().hex + uuid4().hex
        response = await public_client.get("/v1/satellites", headers={"Authorization": f"Device {token}"})
        statuses.append(response.status_code)

    assert statuses == [200, 200, 429, 429]


async def test_the_token_is_verified_against_the_database_at_most_once_per_ten_minutes(
    redis_client, device_client, monkeypatch
):
    from sqlalchemy import event

    from app.db.session import async_engine

    hashed = token_hash(device_client.device_token)
    assert await redis_client.exists(f"dv:{hashed}")

    calls = 0

    def before(conn, cursor, statement, parameters, context, executemany):  # noqa: ANN001
        nonlocal calls
        if "devices" in statement and "token_hash" in statement:
            calls += 1

    target = async_engine.sync_engine
    event.listen(target, "before_cursor_execute", before)
    try:
        await redis_client.delete(f"dv:{hashed}")  # the cache is cold
        for _ in range(3):
            assert (await device_client.get("/v1/satellites")).status_code == 200
    finally:
        event.remove(target, "before_cursor_execute", before)

    assert calls == 1


async def test_rotating_a_device_drops_its_cached_hash(device_client, session, redis_client):
    from sqlalchemy import select

    from app.db.models import Device

    old_hash = token_hash(device_client.device_token)
    assert await redis_client.exists(f"dv:{old_hash}")
    install_id = await session.scalar(select(Device.install_id).where(Device.id == device_client.device_id))

    register = await device_client.post("/v1/devices", json={"install_id": str(install_id), "platform": "android"})

    assert register.status_code == 201
    assert not await redis_client.exists(f"dv:{old_hash}")
    assert await redis_client.exists(f"dv:{token_hash(register.json()['data']['device_token'])}")


async def test_the_register_window_is_its_own(public_client, monkeypatch):
    _tighten(monkeypatch, register=2)

    answers = [
        await public_client.post("/v1/devices", json={"install_id": str(uuid4()), "platform": "android"})
        for _ in range(3)
    ]

    assert [answer.status_code for answer in answers] == [201, 201, 429]
    assert answers[-1].json()["error"]["code"] == "rate_limited"


def test_x_forwarded_for_counts_only_from_caddys_address():
    def request(peer: str, forwarded: str | None) -> Request:
        headers = [(b"x-forwarded-for", forwarded.encode())] if forwarded else []
        return Request(
            {
                "type": "http",
                "client": (peer, 5000),
                "headers": headers,
                "method": "GET",
                "path": "/v1/matches",
            }
        )

    assert client_ip(request("203.0.113.9", "198.51.100.1")) == "203.0.113.9"
    assert client_ip(request("10.8.0.1", "198.51.100.1, 203.0.113.9")) == "203.0.113.9"
    assert client_ip(request("10.8.0.1", "not-an-ip")) == "10.8.0.1"


async def test_healthz_is_exempt(public_client, monkeypatch):
    _tighten(monkeypatch, ip=1)

    for _ in range(3):
        assert (await public_client.get("/healthz")).status_code == 200


async def test_redis_down_allows_every_request(public_client, monkeypatch):
    def broken():
        raise ConnectionError("redis is down")

    monkeypatch.setattr(ratelimit, "_client", broken)

    assert (await public_client.get("/v1/satellites")).status_code == 200


async def test_the_admin_app_has_no_rate_limit(anon_admin_client, monkeypatch):
    _tighten(monkeypatch, ip=1)

    for _ in range(3):
        assert (await anon_admin_client.get("/admin/api/sources")).status_code == 401


# --- D4 T002: RATE_LIMIT_EXEMPT_IPS ---------------------------------------------------------------


def _exempt(monkeypatch, *ips: str) -> None:
    monkeypatch.setattr(get_settings(), "rate_limit_exempt_ips", list(ips))


def _trust(monkeypatch, *peers: str) -> None:
    monkeypatch.setattr(get_settings(), "trusted_proxies", list(peers))


async def test_an_empty_allowlist_exempts_nobody(public_client, monkeypatch):
    _exempt(monkeypatch)
    _tighten(monkeypatch, ip=1)

    answers = [await public_client.get("/v1/satellites") for _ in range(2)]

    assert [answer.status_code for answer in answers] == [200, 429]


async def test_an_exempt_ip_is_never_limited_while_another_still_is(public_client, monkeypatch):
    # The test client's peer is 127.0.0.1, so trusting it lets the header name the client.
    _trust(monkeypatch, "127.0.0.1")
    _exempt(monkeypatch, "203.0.113.7")
    _tighten(monkeypatch, ip=1)
    exempt = {"X-Forwarded-For": "203.0.113.7"}

    for _ in range(5):
        assert (await public_client.get("/v1/satellites", headers=exempt)).status_code == 200

    other = [await public_client.get("/v1/satellites", headers={"X-Forwarded-For": "198.51.100.9"}) for _ in range(2)]
    assert [answer.status_code for answer in other] == [200, 429]
    assert int(other[-1].headers["retry-after"]) >= 1


async def test_a_forged_allowlist_claim_from_an_untrusted_peer_is_limited(public_client, monkeypatch):
    _exempt(monkeypatch, "203.0.113.7")
    _tighten(monkeypatch, ip=1)
    # trusted_proxies keeps its default (10.8.0.1), so the test peer's header is not believed.
    forged = {"X-Forwarded-For": "203.0.113.7"}

    answers = [await public_client.get("/v1/satellites", headers=forged) for _ in range(2)]

    assert [answer.status_code for answer in answers] == [200, 429]


async def test_each_exempt_request_logs_at_debug_and_the_summary_once_a_minute(public_client, monkeypatch, caplog):
    _exempt(monkeypatch, "127.0.0.1")
    _tighten(monkeypatch, ip=1)
    monkeypatch.setattr(ratelimit, "_EXEMPT_SUMMARY", {})

    with caplog.at_level(logging.DEBUG, logger="madar.ratelimit"):
        for _ in range(3):
            assert (await public_client.get("/v1/satellites")).status_code == 200

    debug = [
        record for record in caplog.records if record.levelno == logging.DEBUG and "ratelimit.exempt" in record.msg
    ]
    info = [record for record in caplog.records if record.levelno == logging.INFO and "ratelimit.exempt" in record.msg]
    # The frozen clock keeps all three in the same minute, so one summary covers them.
    assert len(debug) == 3
    assert len(info) == 1


def test_a_non_empty_allowlist_warns_at_startup(monkeypatch, caplog):
    from app.public import create_app

    _exempt(monkeypatch, "203.0.113.7")

    with caplog.at_level(logging.WARNING, logger="madar.ratelimit"):
        create_app()

    warnings = [record for record in caplog.records if record.levelno == logging.WARNING]
    assert any("ratelimit.exempt_enabled" in record.msg and "203.0.113.7" in record.getMessage() for record in warnings)


def test_an_empty_allowlist_is_silent_at_startup(monkeypatch, caplog):
    from app.public import create_app

    _exempt(monkeypatch)

    with caplog.at_level(logging.WARNING, logger="madar.ratelimit"):
        create_app()

    assert not [record for record in caplog.records if "ratelimit.exempt_enabled" in record.msg]
