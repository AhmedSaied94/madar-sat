"""Teams, competitions, satellites, channels and commentators: CRUD, audit, locks, rules (T026)."""

from __future__ import annotations

import pytest
from sqlalchemy import func, select

from app.db.models import Channel, Commentator, Competition, Match, Satellite, Team
from tests.admin.helpers import ADMIN, audit_rows, create, dataset_versions, if_match

TEAMS = f"{ADMIN}/teams"
COMPETITIONS = f"{ADMIN}/competitions"
SATELLITES = f"{ADMIN}/satellites"
CHANNELS = f"{ADMIN}/channels"
COMMENTATORS = f"{ADMIN}/commentators"

LABELS = ["Mega Share", "Apollo", "VIP", "ليست مكسورة", "BISS"]


def _satellite_body(slug="test-sat-1", **extra):
    return {"slug": slug, "name_en": f"Test {slug}", "name_ar": "قمر تجريبي", "orbital_position": 12.5, **extra}


async def _satellite(client, slug="test-sat-1"):
    return await create(client, SATELLITES, _satellite_body(slug))


def _channel_body(satellite_id, name="قناة اختبار", **extra):
    return {
        "kind": "satellite",
        "name": name,
        "satellite_id": satellite_id,
        "access": "free",
        "frequency": {"mhz": 11843, "pol": "H", "sr": 27500},
        **extra,
    }


# --- Teams --------------------------------------------------------------------------------------------


class TestTeams:
    async def test_create_read_update_delete_with_audit_and_dataset_bumps(self, editor_client, session):
        before = await dataset_versions(session)

        team = await create(editor_client, TEAMS, {"name": "فريق اختبار", "country": "مصر"})
        assert (await dataset_versions(session))["teams"] == before["teams"] + 1
        assert (await dataset_versions(session))["matches"] == before["matches"] + 1
        created = (await audit_rows(session, "teams", team["id"]))[0]
        assert created.action == "create"
        assert created.admin_user_id == editor_client.admin.id
        assert created.diff["name"] == [None, "فريق اختبار"]

        got = await editor_client.get(f"{TEAMS}/{team['id']}")
        assert got.headers["etag"] == team["_etag"]

        patched = await editor_client.patch(
            f"{TEAMS}/{team['id']}", json={"name": "فريق جديد"}, headers=if_match(team["_etag"])
        )
        assert patched.status_code == 200
        assert patched.headers["etag"] != team["_etag"]
        assert patched.json()["data"]["name"] == "فريق جديد"
        updated = (await audit_rows(session, "teams", team["id"]))[-1]
        assert updated.action == "update"
        assert updated.diff == {"name": ["فريق اختبار", "فريق جديد"]}

        deleted = await editor_client.delete(f"{TEAMS}/{team['id']}", headers=if_match(patched.headers["etag"]))
        assert deleted.status_code == 200
        assert deleted.json()["data"] is None
        assert (await editor_client.get(f"{TEAMS}/{team['id']}")).json()["error"]["code"] == "team_not_found"

    async def test_competition_ids_are_replaced_and_part_of_the_version(self, editor_client, session):
        competition_ids = list((await session.scalars(select(Competition.id).limit(2))).all())
        team = await create(editor_client, TEAMS, {"name": "فريق بمسابقات", "competition_ids": competition_ids[:1]})
        assert team["competition_ids"] == competition_ids[:1]

        patched = await editor_client.patch(
            f"{TEAMS}/{team['id']}", json={"competition_ids": competition_ids}, headers=if_match(team["_etag"])
        )

        assert patched.status_code == 200
        assert patched.json()["data"]["competition_ids"] == sorted(competition_ids)
        assert patched.headers["etag"] != team["_etag"]

    async def test_an_unknown_competition_is_a_validation_error_naming_the_field(self, editor_client):
        resp = await editor_client.post(TEAMS, json={"name": "فريق", "primary_competition_id": 2**62})

        assert resp.status_code == 422
        assert resp.json()["error"]["code"] == "validation_error"
        assert {"loc": ["body", "primary_competition_id"], "type": "not_found"} in resp.json()["meta"]["errors"]

    async def test_a_team_in_a_match_cannot_be_deleted(self, editor_client, session):
        team_id = await session.scalar(select(Match.home_team_id).where(Match.home_team_id.is_not(None)).limit(1))
        etag = (await editor_client.get(f"{TEAMS}/{team_id}")).headers["etag"]

        resp = await editor_client.delete(f"{TEAMS}/{team_id}", headers=if_match(etag))

        assert resp.status_code == 409
        assert resp.json()["error"]["code"] == "in_use"
        assert resp.json()["meta"]["usage"]["matches"] >= 1
        assert await session.get(Team, team_id) is not None

    async def test_a_name_cannot_be_set_to_null(self, editor_client):
        team = await create(editor_client, TEAMS, {"name": "فريق"})

        resp = await editor_client.patch(f"{TEAMS}/{team['id']}", json={"name": None}, headers=if_match(team["_etag"]))

        assert resp.status_code == 422

    async def test_an_unknown_id_is_team_not_found(self, editor_client):
        for resp in (
            await editor_client.get(f"{TEAMS}/{2**62}"),
            await editor_client.patch(f"{TEAMS}/{2**62}", json={"name": "x"}, headers=if_match('"abc"')),
            await editor_client.delete(f"{TEAMS}/{2**62}", headers=if_match('"abc"')),
        ):
            assert resp.status_code == 404
            assert resp.json()["error"]["code"] == "team_not_found"


# --- Competitions -------------------------------------------------------------------------------------


class TestCompetitions:
    async def test_crud_is_audited_and_bumps_competitions_and_matches(self, editor_client, session):
        before = await dataset_versions(session)

        competition = await create(editor_client, COMPETITIONS, {"name": "بطولة اختبار", "priority": 90})
        patched = await editor_client.patch(
            f"{COMPETITIONS}/{competition['id']}", json={"priority": 80}, headers=if_match(competition["_etag"])
        )

        assert patched.status_code == 200
        after = await dataset_versions(session)
        assert after["competitions"] == before["competitions"] + 2
        assert after["matches"] == before["matches"] + 2
        assert (await audit_rows(session, "competitions", competition["id"]))[-1].diff == {"priority": [90, 80]}

        deleted = await editor_client.delete(
            f"{COMPETITIONS}/{competition['id']}", headers=if_match(patched.headers["etag"])
        )
        assert deleted.status_code == 200

    async def test_the_same_name_in_the_same_sport_already_exists(self, editor_client):
        await create(editor_client, COMPETITIONS, {"name": "بطولة مكررة"})

        resp = await editor_client.post(COMPETITIONS, json={"name": "بطولة  مكررة"})

        assert resp.status_code == 409
        assert resp.json()["error"]["code"] == "already_exists"
        assert resp.json()["meta"]["field"] == "name"

    async def test_a_competition_with_matches_is_in_use(self, editor_client, session):
        competition_id = await session.scalar(select(Match.competition_id).where(Match.competition_id.is_not(None)))
        etag = (await editor_client.get(f"{COMPETITIONS}/{competition_id}")).headers["etag"]

        resp = await editor_client.delete(f"{COMPETITIONS}/{competition_id}", headers=if_match(etag))

        assert resp.status_code == 409
        assert resp.json()["meta"]["usage"]["matches"] >= 1

    async def test_the_list_is_ordered_by_priority_with_nulls_last(self, editor_client):
        await create(editor_client, COMPETITIONS, {"name": "بلا أولوية"})

        items = (await editor_client.get(COMPETITIONS)).json()["data"]

        priorities = [item["priority"] for item in items]
        ranked = [p for p in priorities if p is not None]
        assert ranked == sorted(ranked)
        assert priorities[: len(ranked)] == ranked  # every null comes after every number


# --- Satellites ---------------------------------------------------------------------------------------


class TestSatellites:
    async def test_crud(self, editor_client):
        satellite = await _satellite(editor_client)

        patched = await editor_client.patch(
            f"{SATELLITES}/{satellite['id']}",
            json={"best_frequency": {"mhz": 11996, "pol": "V", "sr": 27500}},
            headers=if_match(satellite["_etag"]),
        )

        assert patched.status_code == 200
        assert patched.json()["data"]["best_frequency"] == {"mhz": 11996, "pol": "V", "sr": 27500}
        deleted = await editor_client.delete(
            f"{SATELLITES}/{satellite['id']}", headers=if_match(patched.headers["etag"])
        )
        assert deleted.status_code == 200

    async def test_a_second_satellite_with_the_slug_already_exists(self, editor_client):
        await _satellite(editor_client, "dup-sat")

        resp = await editor_client.post(SATELLITES, json=_satellite_body("dup-sat", name_en="Another"))

        assert resp.status_code == 409
        assert resp.json()["meta"] == {"field": "slug"}

    async def test_reception_url_must_be_https(self, editor_client):
        resp = await editor_client.post(
            SATELLITES, json=_satellite_body("http-sat", reception_url="http://example.com/how-to")
        )

        assert resp.status_code == 422

    async def test_a_satellite_needs_an_orbital_position_and_a_terrestrial_row_has_none(self, editor_client):
        no_orbit = _satellite_body("no-orbit")
        del no_orbit["orbital_position"]
        assert (await editor_client.post(SATELLITES, json=no_orbit)).status_code == 422
        assert (
            await editor_client.post(SATELLITES, json=_satellite_body("tv-with-orbit", kind="terrestrial"))
        ).status_code == 422

    async def test_a_frequency_outside_the_base_domain_is_a_validation_error(self, editor_client):
        resp = await editor_client.post(
            SATELLITES, json=_satellite_body("bad-freq", best_frequency={"mhz": 99999, "pol": "H", "sr": 27500})
        )

        assert resp.status_code == 422
        assert {"loc": ["body", "best_frequency", "mhz"], "type": "out_of_range"} in resp.json()["meta"]["errors"]

    async def test_a_satellite_with_channels_is_in_use(self, editor_client, session):
        satellite_id = await session.scalar(select(Channel.satellite_id).where(Channel.satellite_id.is_not(None)))
        etag = (await editor_client.get(f"{SATELLITES}/{satellite_id}")).headers["etag"]

        resp = await editor_client.delete(f"{SATELLITES}/{satellite_id}", headers=if_match(etag))

        assert resp.status_code == 409
        assert resp.json()["error"]["code"] == "in_use"
        assert resp.json()["meta"]["usage"]["channels"] >= 1
        assert await session.get(Satellite, satellite_id) is not None


# --- Channels -----------------------------------------------------------------------------------------


class TestChannels:
    async def test_create_update_and_soft_delete(self, editor_client, session):
        satellite = await _satellite(editor_client)
        channel = await create(editor_client, CHANNELS, _channel_body(satellite["id"]))
        assert channel["frequency"] == {"mhz": 11843, "pol": "H", "sr": 27500}

        patched = await editor_client.patch(
            f"{CHANNELS}/{channel['id']}", json={"sort_order": 5}, headers=if_match(channel["_etag"])
        )
        assert patched.status_code == 200

        deleted = await editor_client.delete(f"{CHANNELS}/{channel['id']}", headers=if_match(patched.headers["etag"]))
        assert deleted.status_code == 200
        query = select(Channel).where(Channel.id == channel["id"]).execution_options(populate_existing=True)
        row = await session.scalar(query)
        assert row is not None and row.deleted_at is not None
        assert (await editor_client.get(f"{CHANNELS}/{channel['id']}")).json()["error"]["code"] == "channel_not_found"

    async def test_a_soft_deleted_channel_is_gone_from_v1(self, editor_client, public_client):
        satellite = await _satellite(editor_client)
        channel = await create(editor_client, CHANNELS, _channel_body(satellite["id"], "قناة ستحذف"))
        await editor_client.delete(f"{CHANNELS}/{channel['id']}", headers=if_match(channel["_etag"]))

        resp = await public_client.get(f"/v1/channels/{channel['id']}")

        assert resp.status_code == 404
        assert resp.json()["error"]["code"] == "channel_not_found"

    async def test_an_editors_change_locks_the_fields_it_changed(self, editor_client, session):
        satellite = await _satellite(editor_client)
        channel = await create(editor_client, CHANNELS, _channel_body(satellite["id"]))

        resp = await editor_client.patch(
            f"{CHANNELS}/{channel['id']}",
            json={"name": "اسم جديد", "access": "free", "sort_order": 3},  # access is sent unchanged
            headers=if_match(channel["_etag"]),
        )

        assert resp.status_code == 200
        assert resp.json()["data"]["locked_fields"] == ["name", "sort_order"]

    async def test_the_kind_decides_the_fields(self, editor_client):
        satellite = await _satellite(editor_client)
        no_satellite = {"kind": "satellite", "name": "بلا قمر", "access": "free"}
        platform_with_satellite = {"kind": "platform", "name": "منصة", "satellite_id": satellite["id"]}
        terrestrial_with_tuning = _channel_body(satellite["id"], "أرضية", kind="terrestrial")

        for body in (no_satellite, platform_with_satellite, terrestrial_with_tuning):
            resp = await editor_client.post(CHANNELS, json=body)
            assert resp.status_code == 422, body
            assert resp.json()["error"]["code"] == "validation_error"

    async def test_a_platform_has_no_satellite(self, editor_client):
        platform = await create(editor_client, CHANNELS, {"kind": "platform", "name": "منصة بث", "country": "مصر"})

        assert platform["satellite_id"] is None

    async def test_the_same_carriage_twice_already_exists(self, editor_client):
        satellite = await _satellite(editor_client)
        await create(editor_client, CHANNELS, _channel_body(satellite["id"]))

        resp = await editor_client.post(CHANNELS, json=_channel_body(satellite["id"]))

        assert resp.status_code == 409
        assert resp.json()["error"]["code"] == "already_exists"
        assert resp.json()["meta"]["field"] == "carriage"

    async def test_an_unknown_satellite_is_a_validation_error(self, editor_client):
        resp = await editor_client.post(CHANNELS, json=_channel_body(2**62))

        assert resp.status_code == 422
        assert {"loc": ["body", "satellite_id"], "type": "not_found"} in resp.json()["meta"]["errors"]


# --- Commentators -------------------------------------------------------------------------------------


class TestCommentators:
    async def test_crud(self, editor_client):
        commentator = await create(editor_client, COMMENTATORS, {"name": "معلق اختبار"})
        assert commentator["usage"] == {"matches": 0, "match_channels": 0}

        patched = await editor_client.patch(
            f"{COMMENTATORS}/{commentator['id']}", json={"name": "معلق آخر"}, headers=if_match(commentator["_etag"])
        )

        assert patched.status_code == 200
        deleted = await editor_client.delete(
            f"{COMMENTATORS}/{commentator['id']}", headers=if_match(patched.headers["etag"])
        )
        assert deleted.status_code == 200

    async def test_a_commentator_in_use_cannot_be_deleted(self, editor_client, session):
        commentator_id = await session.scalar(select(Match.commentator_id).where(Match.commentator_id.is_not(None)))
        if commentator_id is None:
            pytest.skip("the synthetic snapshot has no commentated match")
        etag = (await editor_client.get(f"{COMMENTATORS}/{commentator_id}")).headers["etag"]

        resp = await editor_client.delete(f"{COMMENTATORS}/{commentator_id}", headers=if_match(etag))

        assert resp.status_code == 409
        assert resp.json()["meta"]["usage"]["matches"] >= 1
        assert await session.get(Commentator, commentator_id) is not None

    async def test_the_same_name_already_exists(self, editor_client):
        await create(editor_client, COMMENTATORS, {"name": "معلق مكرر"})

        resp = await editor_client.post(COMMENTATORS, json={"name": "معلق مكرر"})

        assert resp.status_code == 409
        assert resp.json()["meta"]["field"] == "name"


# --- Content rule: no card-sharing labels in anything that reaches /v1 --------------------------------


class TestCardSharingLabels:
    @pytest.mark.parametrize("label", LABELS)
    @pytest.mark.parametrize(
        ("path", "field", "extra"),
        [
            (TEAMS, "name", {}),
            (TEAMS, "stadium", {"name": "فريق"}),
            (COMPETITIONS, "name", {}),
            (COMMENTATORS, "name", {}),
        ],
    )
    async def test_a_free_text_field_with_a_label_is_refused_and_nothing_is_stored(
        self, editor_client, session, path, field, extra, label
    ):
        before = await dataset_versions(session)

        resp = await editor_client.post(path, json={**extra, field: f"قناة {label} مباشر"})

        assert resp.status_code == 422
        assert resp.json()["error"]["code"] == "validation_error"
        assert {"loc": ["body", field], "type": "card_sharing_label"} in resp.json()["meta"]["errors"]
        assert await dataset_versions(session) == before

    @pytest.mark.parametrize("label", LABELS)
    @pytest.mark.parametrize("field", ["name", "display_name", "provider", "package"])
    async def test_a_channel_text_field_with_a_label_is_refused(self, editor_client, label, field):
        satellite = await _satellite(editor_client)
        body = _channel_body(satellite["id"], "قناة", **({} if field == "name" else {field: "x"}))
        body[field] = f"{label} HD"

        resp = await editor_client.post(CHANNELS, json=body)

        assert resp.status_code == 422
        assert {"loc": ["body", field], "type": "card_sharing_label"} in resp.json()["meta"]["errors"]

    @pytest.mark.parametrize("label", LABELS)
    async def test_a_satellite_name_with_a_label_is_refused(self, editor_client, label):
        resp = await editor_client.post(SATELLITES, json=_satellite_body("label-sat", name_en=f"{label} 1"))

        assert resp.status_code == 422

    @pytest.mark.parametrize("name", ["Apollon", "Guinea-Bissau", "فيبر"])
    async def test_look_alike_words_pass(self, editor_client, name):
        assert (await editor_client.post(TEAMS, json={"name": name})).status_code == 201

    async def test_a_label_in_a_patch_is_refused_too(self, editor_client):
        team = await create(editor_client, TEAMS, {"name": "فريق"})

        resp = await editor_client.patch(
            f"{TEAMS}/{team['id']}", json={"stadium": "VIP stadium"}, headers=if_match(team["_etag"])
        )

        assert resp.status_code == 422


async def test_no_stored_text_holds_a_label_after_these_writes(editor_client, session):
    """The D1 scan the importers and loaders are held to also holds for admin writes."""
    from app.etl.checks import scan_card_sharing_labels

    await create(editor_client, TEAMS, {"name": "فريق نظيف"})
    await editor_client.post(TEAMS, json={"name": "Mega Share FC"})

    hits = await session.run_sync(lambda sync_session: scan_card_sharing_labels(sync_session))

    assert [hit for hit in hits if hit.table == "teams"] == []
    assert (await session.scalar(select(func.count()).select_from(Team).where(Team.name == "Mega Share FC"))) == 0
