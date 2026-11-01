"""Every admin list returns an ``ETag`` and answers ``If-None-Match`` with 304 (B1-R1-3, constitution VI).

Six lists had neither. Each test here fails if the route loses its ``Depends(ETag(...))``, and the
writable ones also prove that an edit through the API moves the version.
"""

from __future__ import annotations

import pytest
from fastapi.routing import APIRoute

from app.api.deps import ETag
from tests.admin.helpers import ADMIN, create, new_match, patch_match

TEAMS = f"{ADMIN}/teams"
CHANNELS = f"{ADMIN}/channels"
COMMENTATORS = f"{ADMIN}/commentators"
PRESETS = f"{ADMIN}/broadcast-presets"
HIDDEN = f"{ADMIN}/hidden-channel-names"
SOURCES = f"{ADMIN}/sources"


async def _etag(client, path: str) -> str:
    response = await client.get(path)
    assert response.status_code == 200, response.text
    assert "ETag" in response.headers, f"{path} sends no ETag"
    return response.headers["etag"]


async def _assert_revalidates(client, path: str) -> None:
    etag = await _etag(client, path)
    again = await client.get(path, headers={"If-None-Match": etag})
    assert again.status_code == 304, f"{path} answered {again.status_code} for its own ETag"


async def _assert_changes(client, path: str, edit) -> None:
    before = await _etag(client, path)
    await edit()
    after = await _etag(client, path)
    assert after != before, f"an edit did not change the ETag of {path}"


@pytest.mark.parametrize("path", [PRESETS, SOURCES])
async def test_a_read_only_list_answers_304_for_its_own_etag(editor_client, path):
    await _assert_revalidates(editor_client, path)


async def test_the_team_list_etag_follows_a_team_change(editor_client):
    await _assert_revalidates(editor_client, TEAMS)
    await _assert_changes(editor_client, TEAMS, lambda: create(editor_client, TEAMS, {"name": "فريق إي تاج"}))


async def test_the_channel_list_etag_follows_a_channel_change(editor_client):
    async def new_channel():
        satellite = await create(
            editor_client,
            f"{ADMIN}/satellites",
            {"name_ar": "قمر إي تاج", "name_en": "etag sat", "slug": "etag-sat", "orbital_position": 7.0},
        )
        await create(
            editor_client,
            CHANNELS,
            {
                "kind": "satellite",
                "name": "قناة إي تاج",
                "satellite_id": satellite["id"],
                "access": "free",
                "frequency": {"mhz": 11843, "pol": "H", "sr": 27500},
            },
        )

    await _assert_revalidates(editor_client, CHANNELS)
    await _assert_changes(editor_client, CHANNELS, new_channel)


async def test_the_commentator_list_etag_follows_a_commentator_change(editor_client):
    await _assert_revalidates(editor_client, COMMENTATORS)
    await _assert_changes(
        editor_client, COMMENTATORS, lambda: create(editor_client, COMMENTATORS, {"name": "معلق إي تاج"})
    )


async def test_the_hidden_name_list_etag_follows_a_hidden_name_change(editor_client):
    await _assert_revalidates(editor_client, HIDDEN)
    await _assert_changes(editor_client, HIDDEN, lambda: editor_client.post(HIDDEN, json={"name": "قناة تخفى دائماً"}))


async def test_the_commentator_list_etag_follows_a_match_assignment(editor_client):
    """`usage` counts `matches`, so assigning a commentator must move the list (B1-R2-2)."""
    commentator = await create(editor_client, COMMENTATORS, {"name": "معلق الإسناد"})
    path = f"{COMMENTATORS}?q=معلق الإسناد"
    before = await _etag(editor_client, path)
    assert (await editor_client.get(path)).json()["data"][0]["usage"]["matches"] == 0

    match = await new_match(editor_client)
    resp = await patch_match(editor_client, match, {"fields": {"commentator_id": commentator["id"]}})
    assert resp.status_code == 200, resp.text

    after = await _etag(editor_client, path)
    assert after != before, "assigning a commentator left the list's ETag unchanged"
    refreshed = await editor_client.get(path, headers={"If-None-Match": before})
    assert refreshed.status_code == 200, "the list answered 304 with a stale usage"
    assert refreshed.json()["data"][0]["usage"]["matches"] == 1


def _etag_dependencies(route: APIRoute) -> bool:
    def has_etag(dependant) -> bool:
        return any(isinstance(d.call, ETag) for d in dependant.dependencies) or any(
            has_etag(d) for d in dependant.dependencies
        )

    return has_etag(route.dependant)


def test_every_route_that_answers_304_declares_it():
    """The OpenAPI document is the contract: a GET that can answer 304 must say so (B1-R2-4)."""
    from app.admin import app

    spec = app.openapi()
    missing = []
    for route in app.routes:
        if not isinstance(route, APIRoute) or "GET" not in route.methods or not _etag_dependencies(route):
            continue
        operation = spec["paths"][route.path_format]["get"]
        if "304" not in operation["responses"]:
            missing.append(route.path_format)
        if "ETag" not in operation["responses"]["200"].get("headers", {}):
            missing.append(f"{route.path_format} (200 has no ETag header)")
    assert missing == []
