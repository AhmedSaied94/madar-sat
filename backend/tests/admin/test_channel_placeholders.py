"""A8's new channel filters and A5's missing-logo filter (T028)."""

from __future__ import annotations

from app.db.models import Channel, Team


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


async def test_the_team_missing_logo_filter(editor_client, session):
    without = Team(name="filter team without logo")
    session.add(without)
    await session.flush()

    response = await editor_client.get("/admin/api/teams", params={"missing_logo": "true"})

    assert response.status_code == 200, response.text
    rows = response.json()["data"]
    assert without.id in [row["id"] for row in rows]
    assert all(row["logo"] is None for row in rows)
