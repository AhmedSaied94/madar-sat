"""Envelope, ETag, health, CORS and error contract of every FR-008 route (T016).

Schema conformance (schemathesis over ``openapi/public.json``) is in ``test_public_schema.py``.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest
from sqlalchemy import text

from app.db.session import SyncSession

WINDOW = "from=2026-10-28T00:00:00Z&to=2026-10-29T00:00:00Z"

# (route template, table whose lowest live id fills the template, `<entity>_not_found` code)
DETAIL_ROUTES = [
    ("/v1/matches/{match_id}", "matches", "match_not_found"),
    ("/v1/satellites/{satellite_id}/channels", "satellites", "satellite_not_found"),
    ("/v1/channels/{channel_id}", "channels", "channel_not_found"),
    ("/v1/competitions/{competition_id}", "competitions", "competition_not_found"),
    ("/v1/teams/{team_id}", "teams", "team_not_found"),
    ("/v1/rights-holders/{rights_holder_id}", "rights_holders", "rights_holder_not_found"),
    ("/v1/commentators/{commentator_id}", "commentators", "commentator_not_found"),
]
LIST_ROUTES = [
    f"/v1/matches?{WINDOW}",
    "/v1/live",
    "/v1/satellites",
    "/v1/competitions",
    "/v1/teams?q=a",
    "/v1/rights-holders",
]
MISSING_ID = 2**63 - 1  # the largest valid id (bigint): validates, then 404s

# D3's device routes: the same envelope, but `Cache-Control: no-store` and never an ETag
# (contracts/public-devices.md). Their auth, validation and rotation are in tests/devices/.
DEVICE_ROUTES = ["/v1/devices", "/v1/devices/me", "/v1/devices/me/follows"]


def _fill(template: str, entity_id: int) -> str:
    return re.sub(r"\{\w+\}", str(entity_id), template)


@pytest.fixture(scope="module")
def fr008_paths(loaded_snapshot: None) -> list[str]:
    """One concrete URL per FR-008 route, with ids taken from the loaded fixture."""
    paths = list(LIST_ROUTES)
    with SyncSession() as s:
        for template, table, _ in DETAIL_ROUTES:
            # Table names come from the constant list above, never from input.
            live_only = " WHERE deleted_at IS NULL" if table == "channels" else ""
            entity_id = s.execute(text(f"SELECT min(id) FROM {table}{live_only}")).scalar_one()  # noqa: S608
            assert entity_id is not None, f"fixture has no {table}"
            paths.append(_fill(template, entity_id))
    return paths


def test_fr008_route_list_matches_contract() -> None:
    doc = json.loads((Path(__file__).resolve().parents[2] / "openapi" / "public.json").read_text(encoding="utf-8"))
    declared = {p for p in doc["paths"] if p.startswith("/v1/")}
    covered = {r.split("?")[0] for r in LIST_ROUTES} | {t for t, _, _ in DETAIL_ROUTES} | set(DEVICE_ROUTES)
    assert declared == covered


@pytest.mark.asyncio
async def test_envelope_on_every_fr008_route(public_client, fr008_paths):
    for path in fr008_paths:
        resp = await public_client.get(path)
        assert resp.status_code == 200, (path, resp.text)
        body = resp.json()
        assert set(body) == {"success", "data", "error", "meta"}, path
        assert body["success"] is True, path
        assert body["data"] is not None, path
        assert body["error"] is None, path
        assert "generated_at" in body["meta"], path


@pytest.mark.asyncio
async def test_etag_and_304_on_every_fr008_route(public_client, fr008_paths):
    for path in fr008_paths:
        resp = await public_client.get(path)
        etag = resp.headers.get("ETag")
        assert etag and etag.startswith('W/"'), path
        assert resp.headers.get("Cache-Control") == "no-cache", path

        assert "Accept-Encoding" in resp.headers.get("Vary", ""), path

        resp2 = await public_client.get(path, headers={"If-None-Match": f'W/"ffffffffffffffff", {etag}'})
        assert resp2.status_code == 304, path
        assert resp2.content == b"", path
        assert "content-type" not in resp2.headers, path
        assert resp2.headers.get("ETag") == etag, path
        assert resp2.headers.get("Cache-Control") == "no-cache", path
        assert "Accept-Encoding" in resp2.headers.get("Vary", ""), path


@pytest.mark.asyncio
async def test_dataset_bump_invalidates_etag(public_client):
    resp = await public_client.get("/v1/satellites")
    etag = resp.headers["ETag"]

    with SyncSession() as s:
        s.execute(text("UPDATE dataset_versions SET version = version + 1 WHERE name = 'satellites'"))
        s.commit()

    resp2 = await public_client.get("/v1/satellites", headers={"If-None-Match": etag})
    assert resp2.status_code == 200
    assert resp2.headers["ETag"] != etag


@pytest.mark.asyncio
async def test_healthz_ok_and_304(public_client):
    resp = await public_client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json()["data"] == {"db": "ok", "redis": "ok"}
    etag = resp.headers["ETag"]
    assert etag.startswith('W/"') and len(etag) == len('W/""') + 16

    resp2 = await public_client.get("/healthz", headers={"If-None-Match": etag})
    assert resp2.status_code == 304


@pytest.mark.asyncio
async def test_healthz_force_fail(public_client, monkeypatch):
    from app.settings import get_settings

    monkeypatch.setattr(get_settings(), "healthz_force_fail", True)
    resp = await public_client.get("/healthz")
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "unhealthy"
    assert "ETag" not in resp.headers


@pytest.mark.asyncio
async def test_cors_allows_only_configured_origins(public_client):
    resp = await public_client.get("/v1/satellites", headers={"Origin": "https://madar.web.app"})
    assert resp.headers.get("Access-Control-Allow-Origin") == "https://madar.web.app"
    assert "ETag" in resp.headers.get("Access-Control-Expose-Headers", "")

    resp2 = await public_client.get("/v1/satellites", headers={"Origin": "https://evil.example"})
    assert "Access-Control-Allow-Origin" not in resp2.headers

    preflight = await public_client.options(
        "/v1/satellites",
        headers={
            "Origin": "https://madar.web.app",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "If-None-Match",
        },
    )
    assert preflight.status_code == 200
    assert "GET" in preflight.headers["Access-Control-Allow-Methods"]


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "path",
    [
        "/v1/matches?from=2026-10-01T00:00:00Z&to=2026-10-20T00:00:00Z",  # window > 8 days
        f"/v1/matches?{WINDOW}&satellite_ids={','.join(str(i) for i in range(1, 34))}",  # 33 ids
        f"/v1/matches?{WINDOW}&my_satellite_ids={','.join(str(i) for i in range(1, 34))}",
        f"/v1/matches?{WINDOW}&satellite_ids=1,x",
        f"/v1/matches?{WINDOW}&status=bogus",
        f"/v1/satellites/1/channels?q={'a' * 65}",  # q > 64
        f"/v1/teams?q={'a' * 65}",
        "/v1/teams?q=a&limit=51",
        "/v1/teams?q=a%00b",  # a NUL never reaches asyncpg; the guard answers 422 (B1-R2-1)
        "/v1/satellites/1/channels?q=a%00b",
        "/v1/teams?q=a&cursor=%E2%9C%93",
        "/v1/channels/0",
        f"/v1/channels/{2**63}",  # past PostgreSQL bigint
        f"/v1/matches?{WINDOW}&satellite_ids={2**63}",
    ],
)
async def test_validation_errors(public_client, path):
    resp = await public_client.get(path)
    assert resp.status_code == 422, (path, resp.text)
    body = resp.json()
    assert body["success"] is False
    assert body["error"]["code"] == "validation_error"
    errors = body["meta"]["errors"]
    assert errors and all(set(e) == {"loc", "type"} for e in errors), errors


@pytest.mark.asyncio
@pytest.mark.parametrize(("template", "code"), [(t, c) for t, _, c in DETAIL_ROUTES])
async def test_entity_not_found(public_client, template, code):
    resp = await public_client.get(_fill(template, MISSING_ID))
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == code


@pytest.mark.asyncio
async def test_unknown_route_and_method(public_client):
    resp = await public_client.get("/v1/nonexistent")
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "not_found"

    resp = await public_client.post("/v1/satellites")
    assert resp.status_code == 405
    assert resp.json()["error"]["code"] == "method_not_allowed"


@pytest.mark.asyncio
async def test_internal_error_has_no_traceback(loaded_snapshot, monkeypatch):
    from httpx import ASGITransport, AsyncClient

    from app.public import app
    from app.services import live

    async def _boom(*_args: object, **_kwargs: object) -> None:
        raise RuntimeError("secret detail that must not leak")

    monkeypatch.setattr(live, "list_live", _boom)
    # Starlette re-raises after answering; we only care about what the client got.
    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/v1/live")
    assert resp.status_code == 500
    assert resp.json()["error"]["code"] == "internal_error"
    assert "Traceback" not in resp.text
    assert "secret detail" not in resp.text


@pytest.mark.asyncio
async def test_error_bodies_never_contain_traceback(public_client):
    for path in ("/v1/matches/2147483647", "/v1/matches?from=x&to=y", "/v1/nonexistent", "/v1/channels/0"):
        resp = await public_client.get(path)
        assert "Traceback" not in resp.text, path
