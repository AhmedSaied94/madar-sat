"""A8's new channel filters and A5's missing-logo filter (T028)."""

from __future__ import annotations

import pytest

from app.db.models import Channel, Team
from tests.admin.helpers import ADMIN, create, if_match

CHANNELS = f"{ADMIN}/channels"
TUNING = {"mhz": 11843, "pol": "H", "sr": 27500}


async def test_the_placeholder_filter_lists_only_placeholders_with_their_source(editor_client, session):
    placeholder = Channel(
        kind="platform", name="filter placeholder", placeholder_source="livesoccertv", locked_fields=[]
    )
    normal = Channel(kind="platform", name="filter normal", locked_fields=[])
    session.add_all([placeholder, normal])
    await session.flush()

    response = await editor_client.get("/admin/api/channels", params={"placeholder": "true"})

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert [row["id"] for row in data] == [placeholder.id]
    assert data[0]["placeholder_source"] == "livesoccertv"


async def test_the_show_in_match_filter(editor_client, session):
    shown = Channel(kind="platform", name="filter shown", show_in_match=True, locked_fields=[])
    hidden = Channel(kind="platform", name="filter hidden", show_in_match=False, locked_fields=[])
    session.add_all([shown, hidden])
    await session.flush()

    yes = await editor_client.get("/admin/api/channels", params={"show_in_match": "true"})
    no = await editor_client.get("/admin/api/channels", params={"show_in_match": "false"})

    shown_ids = [row["id"] for row in yes.json()["data"]]
    hidden_ids = [row["id"] for row in no.json()["data"]]
    assert shown.id in shown_ids
    assert hidden.id not in shown_ids
    assert hidden.id in hidden_ids
    assert shown.id not in hidden_ids


# --- B1-R2-2: a platform placeholder becomes a satellite channel (A-R1-5) ---------------------------


async def _placeholder(session) -> Channel:
    """What the LiveSoccerTV importer creates: a hidden platform channel with no access."""
    row = Channel(
        kind="platform",
        name="placeholder to complete",
        country="مصر",
        placeholder_source="livesoccertv",
        locked_fields=[],
    )
    session.add(row)
    await session.flush()
    return row


async def _satellite(client) -> dict:
    return await create(
        client,
        f"{ADMIN}/satellites",
        {"slug": "complete-sat", "name_en": "Complete sat", "name_ar": "قمر الإكمال", "orbital_position": 7.0},
    )


async def _etag(client, channel_id: int) -> str:
    return (await client.get(f"{CHANNELS}/{channel_id}")).headers["etag"]


async def test_a_platform_placeholder_becomes_a_satellite_channel(editor_client, session):
    placeholder = await _placeholder(session)
    satellite = await _satellite(editor_client)

    response = await editor_client.patch(
        f"{CHANNELS}/{placeholder.id}",
        json={
            "kind": "satellite",
            "satellite_id": satellite["id"],
            "access": "free",
            "frequency": TUNING,
            "show_in_match": True,
        },
        headers=if_match(await _etag(editor_client, placeholder.id)),
    )

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert (data["kind"], data["satellite_id"], data["access"], data["frequency"]) == (
        "satellite",
        satellite["id"],
        "free",
        TUNING,
    )
    assert data["placeholder_source"] is None  # shown on match pages: no longer a placeholder
    await session.refresh(placeholder)
    assert placeholder.kind == "satellite"
    assert placeholder.frequency_mhz == TUNING["mhz"]


async def test_a_satellite_kind_needs_a_satellite_and_access(editor_client, session):
    placeholder = await _placeholder(session)

    response = await editor_client.patch(
        f"{CHANNELS}/{placeholder.id}",
        json={"kind": "satellite", "frequency": TUNING},
        headers=if_match(await _etag(editor_client, placeholder.id)),
    )

    assert response.status_code == 422
    errors = response.json()["meta"]["errors"]
    assert {"loc": ["body", "satellite_id"], "type": "required"} in errors
    assert {"loc": ["body", "access"], "type": "required"} in errors
    await session.refresh(placeholder)
    assert placeholder.kind == "platform"


async def test_a_placeholder_moved_to_a_satellite_needs_a_frequency_or_a_note(editor_client, session):
    placeholder = await _placeholder(session)
    satellite = await _satellite(editor_client)
    body = {"kind": "satellite", "satellite_id": satellite["id"], "access": "free"}

    bare = await editor_client.patch(
        f"{CHANNELS}/{placeholder.id}", json=body, headers=if_match(await _etag(editor_client, placeholder.id))
    )
    noted = await editor_client.patch(
        f"{CHANNELS}/{placeholder.id}",
        json={**body, "frequency_note": "التردد على الموقع"},
        headers=if_match(await _etag(editor_client, placeholder.id)),
    )

    assert bare.status_code == 422
    assert {"loc": ["body", "frequency"], "type": "required"} in bare.json()["meta"]["errors"]
    assert noted.status_code == 200, noted.text
    assert noted.json()["data"]["kind"] == "satellite"


async def test_a_platform_kind_refuses_a_satellite_and_a_tuning_until_they_are_cleared(editor_client):
    satellite = await _satellite(editor_client)
    channel = await create(
        editor_client,
        CHANNELS,
        {
            "kind": "satellite",
            "name": "قناة تعود منصة",
            "satellite_id": satellite["id"],
            "access": "free",
            "frequency": TUNING,
        },
    )

    refused = await editor_client.patch(
        f"{CHANNELS}/{channel['id']}", json={"kind": "platform"}, headers=if_match(channel["_etag"])
    )
    cleared = await editor_client.patch(
        f"{CHANNELS}/{channel['id']}",
        json={"kind": "platform", "satellite_id": None, "frequency": None},
        headers=if_match(channel["_etag"]),
    )

    assert refused.status_code == 422
    assert {"loc": ["body", "satellite_id"], "type": "not_allowed"} in refused.json()["meta"]["errors"]
    assert cleared.status_code == 200, cleared.text
    assert cleared.json()["data"]["kind"] == "platform"


@pytest.mark.parametrize("kind", [None, "radio"], ids=["null", "unknown"])
async def test_the_kind_is_one_of_the_three_and_never_null(editor_client, session, kind):
    placeholder = await _placeholder(session)

    response = await editor_client.patch(
        f"{CHANNELS}/{placeholder.id}",
        json={"kind": kind},
        headers=if_match(await _etag(editor_client, placeholder.id)),
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


async def test_the_team_missing_logo_filter(editor_client, session):
    without = Team(name="filter team without logo")
    session.add(without)
    await session.flush()

    response = await editor_client.get("/admin/api/teams", params={"missing_logo": "true"})

    assert response.status_code == 200, response.text
    rows = response.json()["data"]
    assert without.id in [row["id"] for row in rows]
    assert all(row["logo"] is None for row in rows)
