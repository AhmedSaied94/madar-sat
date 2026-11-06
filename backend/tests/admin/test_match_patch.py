"""The A4 editor's save: fields, broadcasters, links and create (T023, R7, the link lifecycle)."""

from __future__ import annotations

import pytest
from sqlalchemy import select

from app.db.models import Channel, Commentator, Competition, Match, MatchChannel, MatchCustomBroadcast, Team
from tests.admin.helpers import ADMIN, audit_rows, if_match, make_asset, match_body, new_match, patch_match

MATCHES = f"{ADMIN}/matches"


async def _channel_ids(session, count: int = 3) -> list[int]:
    ids = await session.scalars(
        select(Channel.id).where(Channel.deleted_at.is_(None)).order_by(Channel.id).limit(count)
    )
    return list(ids.all())


async def _links(session, match_id: int) -> dict[int, MatchChannel]:
    rows = await session.scalars(
        select(MatchChannel).where(MatchChannel.match_id == match_id).execution_options(populate_existing=True)
    )
    return {link.channel_id: link for link in rows.all()}


async def _refresh(client, match: dict) -> dict:
    """The match's current ``ETag``, for a test that changed rows behind the API's back."""
    resp = await client.get(f"{MATCHES}/{match['id']}")
    return {**resp.json()["data"], "_etag": resp.headers["etag"]}


# --- fields ----------------------------------------------------------------------------------------------


class TestFields:
    async def test_a_kickoff_is_a_utc_instant_and_the_date_follows_cairo(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"fields": {"kickoff_at": "2026-10-31T22:30:00Z"}})

        data = resp.json()["data"]
        assert data["kickoff_at"] == "2026-10-31T22:30:00Z"
        assert data["match_date"] == "2026-11-01"  # 00:30 in Cairo
        assert data["time_tbd"] is False

    async def test_time_tbd_keeps_a_date_and_drops_the_kickoff(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"fields": {"time_tbd": True, "match_date": "2026-11-02"}})

        data = resp.json()["data"]
        assert (data["kickoff_at"], data["time_tbd"], data["match_date"]) == (None, True, "2026-11-02")

    async def test_a_date_that_disagrees_with_the_kickoff_is_refused(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(
            editor_client, match, {"fields": {"kickoff_at": "2026-10-31T18:00:00Z", "match_date": "2026-11-05"}}
        )

        assert resp.status_code == 422
        assert {"loc": ["body", "fields", "match_date"], "type": "match_date_mismatch"} in resp.json()["meta"]["errors"]

    async def test_time_tbd_false_without_a_kickoff_is_refused(self, editor_client):
        match = await new_match(editor_client, kickoff_at=None, time_tbd=True)

        resp = await patch_match(editor_client, match, {"fields": {"time_tbd": False}})

        assert resp.status_code == 422

    async def test_kickoff_and_time_tbd_together_are_refused(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(
            editor_client, match, {"fields": {"kickoff_at": "2026-10-31T18:00:00Z", "time_tbd": True}}
        )

        assert resp.status_code == 422

    async def test_a_team_by_id_takes_its_name_and_clears_the_old_match_logo(self, editor_client, session):
        team = await session.scalar(select(Team).limit(1))
        team.logo_asset_id = await make_asset(session)
        await session.flush()
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"fields": {"home": {"team_id": team.id}}})

        home = resp.json()["data"]["home"]
        assert home["team_id"] == team.id
        assert home["name"] == team.name
        assert home["logo"] is not None  # the team's own logo shows

    async def test_a_team_as_text_has_no_id(self, editor_client, session):
        team_id = await session.scalar(select(Team.id).limit(1))
        match = await new_match(editor_client, home={"team_id": team_id})

        resp = await patch_match(editor_client, match, {"fields": {"home": {"name": "فريق بلا ربط"}}})

        home = resp.json()["data"]["home"]
        assert (home["team_id"], home["name"], home["logo_asset_id"]) == (None, "فريق بلا ربط", None)

    @pytest.mark.parametrize("team", [{}, {"team_id": 1, "name": "x"}])
    async def test_a_team_needs_exactly_one_of_id_or_name(self, editor_client, team):
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"fields": {"home": team}})

        assert resp.status_code == 422

    async def test_an_unknown_team_is_a_validation_error(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"fields": {"away": {"team_id": 2**62}}})

        assert resp.status_code == 422
        assert {"loc": ["body", "fields", "away", "team_id"], "type": "not_found"} in resp.json()["meta"]["errors"]

    async def test_a_competition_by_id_takes_its_name(self, editor_client, session):
        competition = await session.scalar(select(Competition).limit(1))
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"fields": {"competition_id": competition.id}})

        data = resp.json()["data"]
        assert (data["competition_id"], data["competition_name"]) == (competition.id, competition.name)

    async def test_a_competition_name_alone_is_text_only(self, editor_client, session):
        competition_id = await session.scalar(select(Competition.id).limit(1))
        match = await new_match(editor_client, competition_id=competition_id, competition_name=None)

        resp = await patch_match(editor_client, match, {"fields": {"competition_name": "بطولة ودية"}})

        data = resp.json()["data"]
        assert (data["competition_id"], data["competition_name"]) == (None, "بطولة ودية")

    async def test_a_new_match_needs_a_competition(self, editor_client):
        resp = await editor_client.post(MATCHES, json=match_body(competition_name=None))

        assert resp.status_code == 422

    @pytest.mark.parametrize(("field", "cap"), [("competition_stage", 80), ("stadium", 120)])
    async def test_stage_and_stadium_stop_at_their_caps(self, editor_client, field, cap):
        match = await new_match(editor_client)

        at_cap = await patch_match(editor_client, match, {"fields": {field: "ا" * cap}})
        match["_etag"] = at_cap.headers["etag"]
        over = await patch_match(editor_client, match, {"fields": {field: "ا" * (cap + 1)}})

        assert at_cap.status_code == 200
        assert over.status_code == 422

    async def test_a_field_set_to_null_is_cleared(self, editor_client):
        match = await new_match(editor_client, stadium="ملعب", competition_stage="الجولة 1")

        resp = await patch_match(editor_client, match, {"fields": {"stadium": None, "competition_stage": None}})

        data = resp.json()["data"]
        assert (data["stadium"], data["competition_stage"]) == (None, None)

    async def test_an_unknown_commentator_is_a_validation_error(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"fields": {"commentator_id": 2**62}})

        assert resp.status_code == 422

    async def test_an_unknown_key_is_refused(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"fields": {"is_live": True}})

        assert resp.status_code == 422

    async def test_an_unknown_match_is_match_not_found(self, editor_client):
        resp = await editor_client.patch(f"{MATCHES}/{2**62}", json={}, headers=if_match('"x"'))

        assert resp.status_code == 404
        assert resp.json()["error"]["code"] == "match_not_found"


# --- broadcasters -------------------------------------------------------------------------------------------


class TestBroadcasts:
    async def test_the_list_is_the_full_desired_state_and_a_missing_slot_is_cleared(self, editor_client, session):
        match = await new_match(
            editor_client, broadcasts=[{"slot": 1, "label": "ON Sport 1"}, {"slot": 2, "label": "الكأس"}]
        )
        assert [b["slot"] for b in match["broadcasts"]] == [1, 2]

        resp = await patch_match(editor_client, match, {"broadcasts": [{"slot": 2, "label": "الكأس"}]})

        assert [b["slot"] for b in resp.json()["data"]["broadcasts"]] == [2]
        rows = await session.scalars(select(MatchCustomBroadcast).where(MatchCustomBroadcast.match_id == match["id"]))
        assert [row.slot for row in rows.all()] == [2]

    async def test_an_empty_list_clears_both_slots(self, editor_client):
        match = await new_match(editor_client, broadcasts=[{"slot": 1, "label": "ON Sport 1"}])

        resp = await patch_match(editor_client, match, {"broadcasts": []})

        assert resp.json()["data"]["broadcasts"] == []

    async def test_saving_slots_locks_broadcasts_against_importers(self, editor_client):
        """Slots aren't columns, so ``lock_changed_fields`` misses them (research R23)."""
        match = await new_match(editor_client, broadcasts=[{"slot": 1, "label": "ON Sport 1"}])

        assert match["locked_fields"] is not None
        assert "broadcasts" in match["locked_fields"]

    async def test_a_section_left_out_is_untouched(self, editor_client):
        match = await new_match(editor_client, broadcasts=[{"slot": 1, "label": "ON Sport 1"}])

        resp = await patch_match(editor_client, match, {"fields": {"stadium": "ملعب"}})

        assert [b["label"] for b in resp.json()["data"]["broadcasts"]] == ["ON Sport 1"]

    async def test_a_slot_can_carry_a_commentator(self, editor_client, session):
        commentator_id = await session.scalar(select(Commentator.id).limit(1))
        match = await new_match(editor_client)

        resp = await patch_match(
            editor_client, match, {"broadcasts": [{"slot": 1, "label": "قناة", "commentator_id": commentator_id}]}
        )

        assert resp.json()["data"]["broadcasts"][0]["commentator_id"] == commentator_id

    async def test_slot_3_and_a_repeated_slot_are_refused(self, editor_client):
        match = await new_match(editor_client)

        three = await patch_match(editor_client, match, {"broadcasts": [{"slot": 3, "label": "x"}]})
        repeated = await patch_match(
            editor_client, match, {"broadcasts": [{"slot": 1, "label": "x"}, {"slot": 1, "label": "y"}]}
        )

        assert three.status_code == 422
        assert repeated.status_code == 422
        assert {"loc": ["body", "broadcasts", 1, "slot"], "type": "duplicate"} in repeated.json()["meta"]["errors"]


# --- links: the lifecycle -----------------------------------------------------------------------------------


class TestLinks:
    async def test_a_new_link_is_manual_with_no_importer(self, editor_client, session):
        channel_id = (await _channel_ids(session, 1))[0]
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"channels": [{"channel_id": channel_id}]})

        link = (await _links(session, match["id"]))[channel_id]
        assert (link.source, link.imported_by, link.is_hidden) == ("manual", None, False)
        assert [c["channel_id"] for c in resp.json()["data"]["channels"]] == [channel_id]

    async def test_a_changed_hidden_flag_or_commentator_makes_an_imported_link_manual(self, editor_client, session):
        first, second = await _channel_ids(session, 2)
        commentator_id = await session.scalar(select(Commentator.id).limit(1))
        match = await new_match(editor_client)
        session.add_all(
            MatchChannel(match_id=match["id"], channel_id=c, source="ysscores", imported_by="ysscores")
            for c in (first, second)
        )
        await session.flush()
        match = await _refresh(editor_client, match)

        resp = await patch_match(
            editor_client,
            match,
            {
                "channels": [
                    {"channel_id": first, "is_hidden": True},
                    {"channel_id": second, "commentator_id": commentator_id},
                ]
            },
        )

        assert resp.status_code == 200
        links = await _links(session, match["id"])
        assert (links[first].source, links[first].imported_by, links[first].is_hidden) == ("manual", "ysscores", True)
        assert (links[second].source, links[second].commentator_id) == ("manual", commentator_id)

    async def test_an_untouched_imported_link_stays_the_importers(self, editor_client, session):
        first, second = await _channel_ids(session, 2)
        match = await new_match(editor_client)
        session.add_all(
            MatchChannel(match_id=match["id"], channel_id=c, source="ysscores", imported_by="ysscores")
            for c in (first, second)
        )
        await session.flush()
        match = await _refresh(editor_client, match)

        await patch_match(
            editor_client,
            match,
            {"channels": [{"channel_id": first, "is_hidden": True}, {"channel_id": second}]},
        )

        assert (await _links(session, match["id"]))[second].source == "ysscores"

    async def test_a_left_out_editor_link_is_deleted(self, editor_client, session):
        first, second = await _channel_ids(session, 2)
        match = await new_match(editor_client, channels=[{"channel_id": first}, {"channel_id": second}])

        resp = await patch_match(editor_client, match, {"channels": [{"channel_id": second}]})

        assert resp.status_code == 200
        assert set(await _links(session, match["id"])) == {second}

    async def test_a_left_out_imported_link_is_kept_hidden_and_manual(self, editor_client, session):
        first, second = await _channel_ids(session, 2)
        match = await new_match(editor_client, channels=[{"channel_id": second}])
        session.add(MatchChannel(match_id=match["id"], channel_id=first, source="ysscores", imported_by="ysscores"))
        await session.flush()
        match = await _refresh(editor_client, match)

        resp = await patch_match(editor_client, match, {"channels": [{"channel_id": second}]})

        assert resp.status_code == 200
        link = (await _links(session, match["id"]))[first]
        assert (link.source, link.imported_by, link.is_hidden) == ("manual", "ysscores", True)
        listed = {c["channel_id"]: c for c in resp.json()["data"]["channels"]}
        assert listed[first]["is_hidden"] is True

    async def test_showing_a_hidden_manual_link_again_keeps_it_manual(self, editor_client, session):
        first = (await _channel_ids(session, 1))[0]
        match = await new_match(editor_client)
        session.add(
            MatchChannel(
                match_id=match["id"], channel_id=first, source="manual", imported_by="ysscores", is_hidden=True
            )
        )
        await session.flush()
        match = await _refresh(editor_client, match)

        await patch_match(editor_client, match, {"channels": [{"channel_id": first, "is_hidden": False}]})

        link = (await _links(session, match["id"]))[first]
        assert (link.source, link.is_hidden) == ("manual", False)

    @pytest.mark.parametrize(
        "link",
        [
            {"commentator2_id": 1},  # a second commentator needs a first
            {"commentator_id": 1, "commentator2_id": 1},  # and a different one
        ],
    )
    async def test_commentator_2_needs_a_different_commentator_1(self, editor_client, session, link):
        channel_id = (await _channel_ids(session, 1))[0]
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"channels": [{"channel_id": channel_id, **link}]})

        assert resp.status_code == 422

    async def test_301_links_are_refused(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"channels": [{"channel_id": i} for i in range(1, 302)]})

        assert resp.status_code == 422

    async def test_300_links_pass_the_size_limit_and_fail_on_their_unknown_ids(self, editor_client):
        match = await new_match(editor_client)

        resp = await patch_match(editor_client, match, {"channels": [{"channel_id": 2**62 + i} for i in range(300)]})

        assert resp.status_code == 422
        assert {"loc": ["body", "channels", 0, "channel_id"], "type": "not_found"} in resp.json()["meta"]["errors"]

    async def test_an_unknown_deleted_or_repeated_channel_is_refused(self, editor_client, session):
        channel_id = (await _channel_ids(session, 1))[0]
        match = await new_match(editor_client)

        resp = await patch_match(
            editor_client, match, {"channels": [{"channel_id": channel_id}, {"channel_id": channel_id}]}
        )

        assert resp.status_code == 422
        assert {"loc": ["body", "channels", 1, "channel_id"], "type": "duplicate"} in resp.json()["meta"]["errors"]


# --- the content rule ---------------------------------------------------------------------------------------


@pytest.mark.parametrize("label", ["VIP", "ليست مكسورة", "Mega Share"])
@pytest.mark.parametrize(
    ("section", "payload", "loc"),
    [
        ("fields", {"stadium": "{}"}, ["body", "fields", "stadium"]),
        ("fields", {"competition_stage": "{}"}, ["body", "fields", "competition_stage"]),
        ("fields", {"home": {"name": "{}"}}, ["body", "fields", "home", "name"]),
        ("broadcasts", [{"slot": 1, "label": "{}"}], ["body", "broadcasts", 0, "label"]),
        ("status", {"set": {"status": "postponed", "status_label": "{}"}}, ["body", "status", "set", "status_label"]),
    ],
)
async def test_a_card_sharing_label_is_refused_naming_the_field_and_nothing_is_written(
    editor_client, session, section, payload, loc, label
):
    match = await new_match(editor_client)
    audits = len(await audit_rows(session, "matches", match["id"]))

    def fill(value):
        if isinstance(value, str):
            return value.replace("{}", f"{label} مباشر")
        if isinstance(value, list):
            return [fill(item) for item in value]
        if isinstance(value, dict):
            return {key: fill(item) for key, item in value.items()}
        return value

    resp = await patch_match(editor_client, match, {section: fill(payload)})

    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "validation_error"
    assert {"loc": loc, "type": "card_sharing_label"} in resp.json()["meta"]["errors"]
    assert len(await audit_rows(session, "matches", match["id"])) == audits
    stored = await session.scalar(select(Match.stadium).where(Match.id == match["id"]))
    assert stored is None


# --- create ---------------------------------------------------------------------------------------------------


class TestCreate:
    async def test_a_match_is_created_manual_with_an_etag_and_an_audit_row(self, editor_client, session):
        resp = await editor_client.post(MATCHES, json=match_body(stadium="ملعب"))

        assert resp.status_code == 201
        data = resp.json()["data"]
        assert data["source"] == "manual"
        assert data["status"]["status_source"] == "clock"
        assert data["status"]["status"] == "scheduled"
        assert resp.headers["etag"] == (await editor_client.get(f"{MATCHES}/{data['id']}")).headers["etag"]
        audit = (await audit_rows(session, "matches", data["id"]))[0]
        assert (audit.action, audit.admin_user_id) == ("create", editor_client.admin.id)
        assert audit.diff["stadium"] == [None, "ملعب"]

    async def test_it_takes_links_and_slots_in_the_same_request(self, editor_client, session):
        channel_id = (await _channel_ids(session, 1))[0]

        resp = await editor_client.post(
            MATCHES,
            json=match_body(channels=[{"channel_id": channel_id}], broadcasts=[{"slot": 1, "label": "ON Sport 1"}]),
        )

        data = resp.json()["data"]
        assert [c["channel_id"] for c in data["channels"]] == [channel_id]
        assert [b["label"] for b in data["broadcasts"]] == ["ON Sport 1"]

    async def test_a_tbd_match_needs_a_date_and_no_kickoff(self, editor_client):
        resp = await editor_client.post(MATCHES, json=match_body(kickoff_at=None, time_tbd=True))

        assert resp.status_code == 201
        data = resp.json()["data"]
        assert (data["kickoff_at"], data["time_tbd"], data["match_date"]) == (None, True, "2026-10-31")

    @pytest.mark.parametrize("missing", ["match_date", "home", "away", "kickoff_at"])
    async def test_the_required_parts_are_required(self, editor_client, missing):
        body = match_body()
        del body[missing]

        resp = await editor_client.post(MATCHES, json=body)

        assert resp.status_code == 422

    async def test_a_new_match_is_in_the_a3_window(self, editor_client):
        created = (await editor_client.post(MATCHES, json=match_body())).json()["data"]

        listed = await editor_client.get(MATCHES, params={"from": "2026-10-31T00:00:00Z", "to": "2026-11-01T00:00:00Z"})

        assert created["id"] in {row["id"] for row in listed.json()["data"]}

    async def test_the_supplied_fields_are_locked(self, editor_client, session):
        """A created match protects what the editor typed; otherwise the next import can take it over."""
        home = await session.scalar(select(Team).where(Team.legacy_id == "team-zamalek"))
        away = await session.scalar(select(Team).where(Team.legacy_id == "team-city"))

        created = await new_match(editor_client, home={"team_id": home.id}, away={"team_id": away.id})

        row = await session.get(Match, created["id"], populate_existing=True)
        assert set(row.locked_fields) >= {
            "kickoff_at",
            "competition_name",
            "home_team_id",
            "home_team_name",
            "away_team_id",
            "away_team_name",
        }
        audit = (await audit_rows(session, "matches", created["id"]))[0]
        assert audit.diff["locked_fields"][1] == row.locked_fields


async def test_an_import_cannot_move_a_kickoff_of_a_match_created_through_the_api(
    parallel_admin_client, committed_editor, session
):
    """B1-R1-4, end to end: the ysscores probe finds the new match and leaves its kickoff alone.

    The API write and the importer must see each other, so the create goes through the real session
    dependency and the importer commits on its own connection. Both rows are removed afterwards as a
    superuser would (``matches_forbid_delete`` blocks ordinary deletes), because a committed match
    would otherwise leak into this session's database.
    """
    from datetime import UTC, datetime

    from sqlalchemy.orm import Session

    from app.adapters.base import NormalizedFixture
    from app.adapters.upsert import UpsertPipeline
    from app.auth.tokens import issue_access_token
    from app.db.session import sync_engine

    _, admin_id = committed_editor
    token = issue_access_token(admin_id, "editor", datetime.now(UTC))
    home = await session.scalar(select(Team).where(Team.legacy_id == "team-zamalek"))
    away = await session.scalar(select(Team).where(Team.legacy_id == "team-city"))
    kickoff = datetime(2031, 1, 1, 18, 0, tzinfo=UTC)
    body = match_body(
        kickoff_at="2031-01-01T18:00:00Z",
        match_date="2031-01-01",
        home={"team_id": home.id},
        away={"team_id": away.id},
    )

    created = await parallel_admin_client.post(MATCHES, json=body, headers={"Authorization": f"Bearer {token}"})
    assert created.status_code == 201, created.text
    match_id = created.json()["data"]["id"]

    try:
        item = NormalizedFixture(
            match_date=kickoff.date(),
            kickoff_at=kickoff.replace(minute=20),  # within the ±45-minute probe window
            time_tbd=False,
            home="الزمالك",
            away="مان سيتي",
            competition="الدوري المصري الممتاز",
            external_id="ys-locked-create-1",
        )
        # A committed importer: the test's own transaction must not hold the row, or the cleanup
        # below would wait for a lock it can never get.
        with Session(bind=sync_engine) as importer:
            UpsertPipeline(importer, source="ysscores", media_hosts=["imgs.ysscores.com"]).run([item])
            importer.commit()

        kept = await session.get(Match, match_id, populate_existing=True)
        assert kept.kickoff_at == kickoff
        assert "kickoff_at" in kept.locked_fields
    finally:
        _delete_match(match_id)


def _delete_match(match_id: int) -> None:
    """Remove a committed test match a normal DELETE can't (``matches_forbid_delete``)."""
    from sqlalchemy import text

    from app.db.models import MatchChannel, MatchCustomBroadcast, MatchExternalId
    from app.db.session import SyncSession

    with SyncSession() as cleanup:
        try:
            cleanup.execute(text("SET session_replication_role = replica"))
            for model in (MatchChannel, MatchCustomBroadcast, MatchExternalId):
                cleanup.execute(model.__table__.delete().where(model.match_id == match_id))
            cleanup.execute(Match.__table__.delete().where(Match.id == match_id))
        finally:
            # A session GUC survives the commit, and the pooled connection is reused by the next test:
            # leaving `replica` here would silently disable every trigger for that test.
            cleanup.execute(text("SET session_replication_role = DEFAULT"))
            cleanup.commit()
