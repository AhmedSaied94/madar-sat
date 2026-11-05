"""Every admin route is behind the role dependency, and none is reachable on the public app (R4, T019)."""

from __future__ import annotations

import re
from collections.abc import Iterator
from typing import Any

import pytest
from fastapi.dependencies.models import Dependant
from fastapi.routing import APIRoute, iter_route_contexts

EXEMPT_PREFIXES = ("/admin/api/auth/",)
EXEMPT_PATHS = {"/admin/api/healthz"}


def _walk(dependant: Dependant) -> Iterator[Any]:
    for sub in dependant.dependencies:
        yield sub.call
        yield from _walk(sub)


def _admin_routes() -> list[tuple[str, str, set[str]]]:
    """``(method, path, roles required)`` for every API route of the admin app."""
    from app.admin import app

    found = []
    for context in iter_route_contexts(app.routes):
        if not isinstance(context.original_route, APIRoute):
            continue
        roles = {call.required_role for call in _walk(context.dependant) if hasattr(call, "required_role")}
        for method in sorted(context.methods or ()):
            found.append((method, context.path_format, roles))
    return found


def _concrete(path: str) -> str:
    return re.sub(r"\{name\}", "x", re.sub(r"\{[a-z_]+\}", "1", path))


def _protected() -> list[tuple[str, str, set[str]]]:
    return [
        (method, path, roles)
        for method, path, roles in _admin_routes()
        if path not in EXEMPT_PATHS and not path.startswith(EXEMPT_PREFIXES)
    ]


def test_the_walk_finds_the_contract_routes():
    protected = _protected()

    assert len(protected) >= 36  # contracts/admin-api.md: matches, five entities, A4 lists, media
    assert ("PATCH", "/admin/api/matches/{match_id}", {"editor"}) in protected


def test_every_route_but_auth_and_healthz_has_the_role_dependency():
    missing = [f"{method} {path}" for method, path, roles in _protected() if not roles]

    assert missing == []


def test_every_contract_route_asks_for_the_editor_role():
    # `admin` covers `editor`; the admin-only actions (bulk remove_channels, deleting a rights holder) are
    # checked in their handlers.
    wrong = [f"{method} {path}: {roles}" for method, path, roles in _protected() if roles != {"editor"}]

    assert wrong == []


@pytest.mark.parametrize(("method", "path"), sorted({(m, _concrete(p)) for m, p, _ in _protected()}))
async def test_no_credentials_is_401_on_every_route(anon_admin_client, redis_client, method, path):
    resp = await anon_admin_client.request(method, path)

    assert resp.status_code == 401, (method, path, resp.text)
    assert resp.json()["error"]["code"] == "unauthenticated"


async def test_an_editor_cannot_remove_channels_in_bulk(editor_client):
    body = {"action": "remove_channels", "items": [{"id": 1, "etag": '"x"'}], "channel_ids": None}

    resp = await editor_client.post("/admin/api/matches/bulk", json=body)

    assert resp.status_code == 403
    assert resp.json()["error"]["code"] == "forbidden"
    assert resp.json()["meta"] == {"required_role": "admin"}


async def test_an_admin_passes_the_remove_channels_role_check(admin_client):
    body = {"action": "remove_channels", "items": [{"id": 999999999, "etag": '"x"'}], "channel_ids": None}

    resp = await admin_client.post("/admin/api/matches/bulk", json=body)

    assert resp.status_code != 403  # it gets as far as the (unknown) match


def test_no_admin_path_is_declared_on_the_public_app():
    from app.public import app

    paths = app.openapi()["paths"]
    assert [path for path in paths if path.startswith("/admin")] == []


@pytest.mark.parametrize(("method", "path"), sorted({(m, _concrete(p)) for m, p, _ in _protected()}))
async def test_every_admin_route_is_a_404_on_the_public_app(public_client, method, path):
    resp = await public_client.request(method, path)

    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "not_found"
