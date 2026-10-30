"""The shared write rules every admin mutation follows (T022, R6, SC-002)."""

from __future__ import annotations

import pytest
from sqlalchemy import select, update

from app.db.models import AuditLog, Channel, Match, Team
from tests.admin.helpers import (
    ADMIN,
    audit_rows,
    changed_datasets,
    create,
    dataset_versions,
    if_match,
    new_match,
    patch_match,
)

TEAMS = f"{ADMIN}/teams"
MATCHES = f"{ADMIN}/matches"


# --- 428 and 409 ---------------------------------------------------------------------------------------


async def test_patch_and_delete_without_if_match_are_428_and_write_nothing(editor_client, session):
    team = await create(editor_client, TEAMS, {"name": "فريق"})
    match = await new_match(editor_client)
    before = await dataset_versions(session)
    audits = len(await audit_rows(session, "teams")) + len(await audit_rows(session, "matches"))

    responses = [
        await editor_client.patch(f"{TEAMS}/{team['id']}", json={"name": "جديد"}),
        await editor_client.delete(f"{TEAMS}/{team['id']}"),
        await editor_client.patch(f"{MATCHES}/{match['id']}", json={"fields": {"stadium": "ملعب"}}),
    ]

    for resp in responses:
        assert resp.status_code == 428
        assert resp.json()["error"]["code"] == "precondition_required"
    assert await dataset_versions(session) == before
    assert len(await audit_rows(session, "teams")) + len(await audit_rows(session, "matches")) == audits
    assert (await editor_client.get(f"{TEAMS}/{team['id']}")).json()["data"]["name"] == "فريق"


async def test_a_stale_if_match_is_409_naming_the_admin_who_changed_it(editor_client, make_admin):
    team = await create(editor_client, TEAMS, {"name": "فريق"})
    first = await editor_client.patch(
        f"{TEAMS}/{team['id']}", json={"stadium": "ملعب"}, headers=if_match(team["_etag"])
    )

    stale = await editor_client.patch(
        f"{TEAMS}/{team['id']}", json={"stadium": "ملعب آخر"}, headers=if_match(team["_etag"])
    )

    assert stale.status_code == 409
    error, meta = stale.json()["error"], stale.json()["meta"]
    assert error["code"] == "edit_conflict"
    assert meta["current_etag"] == first.headers["etag"]
    assert meta["changed_by"] == {"kind": "admin", "name": editor_client.admin.name}
    assert meta["changed_at"]
    assert (await editor_client.get(f"{TEAMS}/{team['id']}")).json()["data"]["stadium"] == "ملعب"


async def test_an_importers_change_makes_the_open_copy_stale_and_names_the_source(editor_client, session):
    team = await create(editor_client, TEAMS, {"name": "فريق"})
    await session.execute(update(Team).where(Team.id == team["id"]).values(stadium="ملعب المستورد"))
    session.add(AuditLog(source="ysscores", entity="teams", entity_id=team["id"], action="update", diff={}))
    await session.flush()

    resp = await editor_client.patch(f"{TEAMS}/{team['id']}", json={"name": "جديد"}, headers=if_match(team["_etag"]))

    assert resp.status_code == 409
    assert resp.json()["meta"]["changed_by"] == {"kind": "source", "name": "ysscores"}


async def test_a_snapshot_only_row_has_no_changed_by(editor_client, session):
    team_id = await session.scalar(select(Team.id).limit(1))
    stale = (await editor_client.get(f"{TEAMS}/{team_id}")).headers["etag"]
    await session.execute(update(Team).where(Team.id == team_id).values(stadium="عُدّل خارج الـ API"))
    await session.flush()

    resp = await editor_client.patch(f"{TEAMS}/{team_id}", json={"name": "x"}, headers=if_match(stale))

    assert resp.status_code == 409
    assert resp.json()["meta"]["changed_by"] is None
    assert resp.json()["meta"]["changed_at"] is None


async def test_an_if_match_for_another_entity_is_a_conflict(editor_client):
    one = await create(editor_client, TEAMS, {"name": "فريق 1"})
    two = await create(editor_client, TEAMS, {"name": "فريق 2"})

    resp = await editor_client.patch(f"{TEAMS}/{two['id']}", json={"name": "x"}, headers=if_match(one["_etag"]))

    assert resp.status_code == 409


# --- audit and locks -------------------------------------------------------------------------------------


async def test_the_audit_diff_holds_only_the_fields_that_changed(editor_client, session):
    team = await create(editor_client, TEAMS, {"name": "فريق", "country": "مصر"})

    await editor_client.patch(
        f"{TEAMS}/{team['id']}",
        json={"name": "فريق", "country": "مصر", "stadium": "ملعب"},
        headers=if_match(team["_etag"]),
    )

    update_row = (await audit_rows(session, "teams", team["id"]))[-1]
    assert update_row.action == "update"
    assert update_row.diff == {"stadium": [None, "ملعب"]}


async def test_the_audit_row_names_the_admin_and_no_source(editor_client, session):
    team = await create(editor_client, TEAMS, {"name": "فريق"})

    row = (await audit_rows(session, "teams", team["id"]))[0]

    assert row.admin_user_id == editor_client.admin.id
    assert row.source is None


async def test_links_and_slots_are_audited_under_their_own_keys(editor_client, session):
    match = await new_match(editor_client)
    channel_id = await session.scalar(select(Channel.id).where(Channel.deleted_at.is_(None)).limit(1))

    resp = await patch_match(
        editor_client,
        match,
        {"channels": [{"channel_id": channel_id}], "broadcasts": [{"slot": 1, "label": "ON Sport 1"}]},
    )

    assert resp.status_code == 200, resp.text
    diff = (await audit_rows(session, "matches", match["id"]))[-1].diff
    assert diff["channels"]["added"] == [
        {"channel_id": channel_id, "is_hidden": False, "commentator_id": None, "commentator2_id": None}
    ]
    assert diff["broadcasts"] == {"1": [None, {"label": "ON Sport 1", "logo_asset_id": None, "commentator_id": None}]}
    assert "stadium" not in diff


async def test_locked_fields_gain_only_the_changed_lockable_fields(editor_client):
    match = await new_match(editor_client, stadium="ملعب")

    resp = await patch_match(
        editor_client,
        match,
        {"fields": {"stadium": "ملعب", "competition_stage": "الجولة 3"}},  # the stadium is sent unchanged
    )

    assert resp.json()["data"]["locked_fields"] == ["competition_stage"]


async def test_a_second_edit_adds_to_the_locks(editor_client):
    match = await new_match(editor_client)
    first = await patch_match(editor_client, match, {"fields": {"stadium": "ملعب"}})
    match["_etag"] = first.headers["etag"]

    second = await patch_match(editor_client, match, {"fields": {"competition_stage": "نهائي"}})

    assert second.json()["data"]["locked_fields"] == ["competition_stage", "stadium"]


# --- the response and no-ops -----------------------------------------------------------------------------


async def test_the_response_etag_equals_a_fresh_get(editor_client):
    match = await new_match(editor_client)

    patched = await patch_match(editor_client, match, {"fields": {"stadium": "ملعب"}})
    fresh = await editor_client.get(f"{MATCHES}/{match['id']}")

    assert patched.headers["etag"] == fresh.headers["etag"]
    assert patched.headers["etag"] != match["_etag"]


async def test_a_patch_that_changes_nothing_writes_nothing(editor_client, session):
    team = await create(editor_client, TEAMS, {"name": "فريق", "stadium": "ملعب"})
    before = await dataset_versions(session)
    audits = len(await audit_rows(session, "teams", team["id"]))

    resp = await editor_client.patch(f"{TEAMS}/{team['id']}", json={"stadium": "ملعب"}, headers=if_match(team["_etag"]))

    assert resp.status_code == 200
    assert resp.headers["etag"] == team["_etag"]
    assert await dataset_versions(session) == before
    assert len(await audit_rows(session, "teams", team["id"])) == audits


# --- the dataset bump table (R6) ---------------------------------------------------------------------------


async def test_match_fields_bump_matches_only(editor_client, session):
    match = await new_match(editor_client)
    before = await dataset_versions(session)

    await patch_match(editor_client, match, {"fields": {"stadium": "ملعب"}})

    assert await changed_datasets(session, before) == {"matches"}


async def test_a_kickoff_change_bumps_matches_and_live(editor_client, session):
    match = await new_match(editor_client)
    before = await dataset_versions(session)

    await patch_match(editor_client, match, {"fields": {"kickoff_at": "2026-10-31T19:00:00Z"}})

    assert await changed_datasets(session, before) == {"matches", "live"}


async def test_a_status_change_bumps_matches_and_live(editor_client, session):
    match = await new_match(editor_client)
    before = await dataset_versions(session)

    await patch_match(editor_client, match, {"status": {"set": {"status": "postponed"}}})

    assert await changed_datasets(session, before) == {"matches", "live"}


async def test_channel_links_and_broadcaster_slots_bump_matches_only(editor_client, session):
    match = await new_match(editor_client)
    channel_id = await session.scalar(select(Channel.id).where(Channel.deleted_at.is_(None)).limit(1))
    before = await dataset_versions(session)

    await patch_match(
        editor_client,
        match,
        {"channels": [{"channel_id": channel_id}], "broadcasts": [{"slot": 2, "label": "قناة"}]},
    )

    assert await changed_datasets(session, before) == {"matches"}


@pytest.mark.parametrize(
    ("path", "body", "patch", "expected"),
    [
        (TEAMS, {"name": "فريق"}, {"stadium": "ملعب"}, {"teams", "matches"}),
        (f"{ADMIN}/competitions", {"name": "بطولة جديدة"}, {"priority": 7}, {"competitions", "matches"}),
        (f"{ADMIN}/commentators", {"name": "معلق جديد"}, {"name": "معلق آخر"}, {"commentators", "matches"}),
    ],
)
async def test_an_entity_edit_bumps_its_datasets_and_matches(editor_client, session, path, body, patch, expected):
    entity = await create(editor_client, path, body)
    before = await dataset_versions(session)

    resp = await editor_client.patch(f"{path}/{entity['id']}", json=patch, headers=if_match(entity["_etag"]))

    assert resp.status_code == 200
    assert await changed_datasets(session, before) == expected


async def test_a_satellite_edit_bumps_satellites_channels_and_matches(editor_client, session):
    satellite = await create(
        editor_client,
        f"{ADMIN}/satellites",
        {"slug": "bump-sat", "name_en": "Bump", "name_ar": "قمر", "orbital_position": 5.0},
    )
    before = await dataset_versions(session)

    await editor_client.patch(
        f"{ADMIN}/satellites/{satellite['id']}", json={"priority": 3}, headers=if_match(satellite["_etag"])
    )

    assert await changed_datasets(session, before) == {"satellites", "channels", "matches"}


async def test_a_channel_edit_bumps_channels_satellites_and_matches(editor_client, session):
    channel = await create(editor_client, f"{ADMIN}/channels", {"kind": "platform", "name": "منصة بث"})
    before = await dataset_versions(session)

    await editor_client.patch(
        f"{ADMIN}/channels/{channel['id']}", json={"sort_order": 9}, headers=if_match(channel["_etag"])
    )

    assert await changed_datasets(session, before) == {"channels", "satellites", "matches"}


async def test_a_hidden_name_bumps_matches(editor_client, session):
    before = await dataset_versions(session)

    resp = await editor_client.post(f"{ADMIN}/hidden-channel-names", json={"name": "قناة مخفية"})

    assert resp.status_code == 201
    assert await changed_datasets(session, before) == {"matches"}


async def test_dataset_bumps_are_the_last_statement_so_a_refused_write_bumps_nothing(editor_client, session):
    match = await new_match(editor_client)
    before = await dataset_versions(session)

    resp = await patch_match(editor_client, match, {"status": {"set": {"status": "postponed", "minute": "5"}}})

    assert resp.status_code == 422
    assert await dataset_versions(session) == before
    stored = await session.scalar(select(Match.status).where(Match.id == match["id"]))
    assert stored == "scheduled"
