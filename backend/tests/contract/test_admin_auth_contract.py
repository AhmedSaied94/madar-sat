"""Admin auth contract: 501 stubs, declared shapes and examples, public/admin separation (T018)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parents[2]
ADMIN_DOC = json.loads((BACKEND / "openapi" / "admin.json").read_text(encoding="utf-8"))

AUTH_ROUTES = {
    ("POST", "/admin/api/auth/login"),
    ("POST", "/admin/api/auth/refresh"),
    ("POST", "/admin/api/auth/logout"),
    ("GET", "/admin/api/auth/me"),
}
ADMIN_ROUTES = AUTH_ROUTES | {("GET", "/admin/api/healthz")}


def _examples(operation: dict, status: str) -> dict:
    return operation["responses"][status]["content"]["application/json"]["examples"]


def _operations(doc: dict) -> set[tuple[str, str]]:
    return {(method.upper(), path) for path, ops in doc["paths"].items() for method in ops}


def test_admin_app_exposes_only_the_five_routes():
    from app.admin import app

    # The live schema walks included routers (FastAPI wraps them, so app.routes doesn't).
    assert _operations(app.openapi()) == ADMIN_ROUTES
    assert _operations(ADMIN_DOC) == ADMIN_ROUTES


@pytest.mark.asyncio
@pytest.mark.parametrize(("method", "path"), sorted(AUTH_ROUTES))
async def test_each_auth_route_is_501_on_d1(admin_client, method, path):
    body = {"email": "editor@example.com", "password": "x"} if path.endswith("/login") else None
    resp = await admin_client.request(method, path, json=body)
    assert resp.status_code == 501
    assert resp.json()["success"] is False
    assert resp.json()["error"]["code"] == "not_implemented"


@pytest.mark.asyncio
async def test_admin_healthz(admin_client):
    resp = await admin_client.get("/admin/api/healthz")
    assert resp.status_code == 200
    assert resp.json()["data"] == {"db": "ok", "redis": "ok"}


def test_login_declares_the_named_examples_with_their_values():
    login = ADMIN_DOC["paths"]["/admin/api/auth/login"]["post"]
    assert set(_examples(login, "200")) == {"login_ok"}
    assert _examples(login, "200")["login_ok"]["value"]["data"]["token_type"] == "Bearer"

    invalid = _examples(login, "401")["invalid_credentials"]["value"]
    assert invalid["error"]["code"] == "invalid_credentials"
    assert invalid["meta"]["attempts_remaining"] == 3

    locked = _examples(login, "429")["account_locked"]["value"]
    assert locked["error"]["code"] == "account_locked"
    assert locked["meta"]["retry_after_s"] == 872

    validation = _examples(login, "422")["validation_error"]["value"]
    assert validation["error"]["code"] == "validation_error"


def test_login_request_shape():
    schemas = ADMIN_DOC["components"]["schemas"]
    body_ref = ADMIN_DOC["paths"]["/admin/api/auth/login"]["post"]["requestBody"]["content"]["application/json"]
    assert body_ref["schema"]["$ref"].endswith("/LoginRequest")
    login = schemas["LoginRequest"]
    assert set(login["required"]) == {"email", "password"}
    assert login["properties"]["email"]["format"] == "email"
    assert login["properties"]["email"]["maxLength"] == 254
    assert (login["properties"]["password"]["minLength"], login["properties"]["password"]["maxLength"]) == (1, 256)


def test_session_and_admin_user_shapes():
    schemas = ADMIN_DOC["components"]["schemas"]
    session = schemas["Session"]
    assert set(session["required"]) == {"access_token", "token_type", "expires_in", "admin"}
    assert session["properties"]["token_type"]["const"] == "Bearer"
    assert set(schemas["AdminUser"]["required"]) == {"id", "email", "name", "role"}
    assert set(schemas["AdminRole"]["enum"]) == {"editor", "admin"}


@pytest.mark.parametrize("route", ["refresh", "logout"])
def test_refresh_and_logout_declare_cookies_and_csrf_header(route):
    op = ADMIN_DOC["paths"][f"/admin/api/auth/{route}"]["post"]
    params = {(p["in"], p["name"]) for p in op["parameters"]}
    assert {("cookie", "madar_refresh"), ("cookie", "madar_csrf"), ("header", "X-CSRF-Token")} <= params
    assert "Set-Cookie" in op["responses"]["200"]["headers"]
    assert "csrf_failed" in _examples(op, "403")


def test_login_sets_both_cookies():
    headers = ADMIN_DOC["paths"]["/admin/api/auth/login"]["post"]["responses"]["200"]["headers"]
    description = headers["Set-Cookie"]["description"]
    assert "madar_refresh" in description and "HttpOnly" in description and "Path=/admin/api/auth" in description
    assert "madar_csrf" in description


@pytest.mark.asyncio
async def test_public_app_has_no_admin_route(public_client):
    from app.public import app

    assert not [op for op in _operations(app.openapi()) if op[1].startswith("/admin")]
    resp = await public_client.post("/admin/api/auth/login", json={"email": "a@b.co", "password": "x"})
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "not_found"


def test_importing_the_public_app_never_loads_admin_modules():
    # A fresh interpreter: this test process has already imported app.admin.
    probe = (
        "import sys, app.public; print(sorted(m for m in sys.modules if m.startswith(('app.admin', 'app.api.admin'))))"
    )
    out = subprocess.run(  # noqa: S603 - fixed argv, no shell
        [sys.executable, "-c", probe], cwd=BACKEND, env=os.environ.copy(), capture_output=True, text=True, check=True
    )
    assert out.stdout.strip() == "[]"
