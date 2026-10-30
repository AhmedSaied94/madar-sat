"""Bulk actions on matches: all or nothing (T025, R8)."""

from __future__ import annotations

from sqlalchemy import select

from app.db.models import Channel, Competition, Match, MatchChannel
from tests.admin.helpers import ADMIN, audit_rows, changed_datasets, dataset_versions, new_match, patch_match

BULK = f"{ADMIN}/matches/bulk"


async def _competition(session) -> Competition:
    return await session.scalar(select(Competition).order_by(Competition.id).limit(1))


async def _channel_ids(session, count: int = 2) -> list[int]:
    rows = await session.scalars(
        select(Channel.id).where(Channel.deleted_at.is_(None)).order_by(Channel.id).limit(count)
    )
    return list(rows.all())


def _items(*matches) -> list[dict]:
    return [{"id": m["id"], "etag": m["_etag"]} for m in matches]


async def _stored(session, match_id: int) -> Match:
    return await session.scalar(select(Match).where(Match.id == match_id).execution_options(populate_existing=True))


async def _links(session, match_id: int) -> dict[int, MatchChannel]:
    rows = await session.scalars(
        select(MatchChannel).where(MatchChannel.match_id == match_id).execution_options(populate_existing=True)
    )
    return {link.channel_id: link for link in rows.all()}


class TestChangeCompetition:
    async def test_every_item_changes_and_each_gets_one_bulk_audit_row(self, editor_client, session):
        competition = await _competition(session)
        one, two = await new_match(editor_client), await new_match(editor_client)
        before = await dataset_versions(session)

        resp = await editor_client.post(
            BULK,
            json={
                "action": "change_competition",
                "items": _items(one, two),
                "competition_id": competition.id,
                "competition_stage": "نصف النهائي",
            },
        )

        assert resp.status_code == 200, resp.text
        for match in (one, two):
            stored = await _stored(session, match["id"])
            assert (stored.competition_id, stored.competition_name, stored.competition_stage) == (
                competition.id,
                competition.name,
                "نصف النهائي",
            )
            rows = await audit_rows(session, "matches", match["id"])
            assert [row.action for row in rows] == ["create", "bulk"]
            assert rows[-1].admin_user_id == editor_client.admin.id
            assert rows[-1].diff["competition_id"] == [None, competition.id]
        assert await changed_datasets(session, before) == {"matches"}

    async def test_the_response_gives_each_matchs_new_etag(self, editor_client, session):
        competition = await _competition(session)
        one, two = await new_match(editor_client), await new_match(editor_client)

        resp = await editor_client.post(
            BULK, json={"action": "change_competition", "items": _items(one, two), "competition_id": competition.id}
        )

        updated = {item["id"]: item["etag"] for item in resp.json()["data"]["updated"]}
        for match in (one, two):
            fresh = await editor_client.get(f"{ADMIN}/matches/{match['id']}")
            assert updated[match["id"]] == fresh.headers["etag"]
            assert updated[match["id"]] != match["_etag"]

    async def test_the_stage_is_left_alone_when_not_sent_and_cleared_when_null(self, editor_client, session):
        competition = await _competition(session)
        match = await new_match(editor_client, competition_stage="الجولة 3")

        kept = await editor_client.post(
            BULK, json={"action": "change_competition", "items": _items(match), "competition_id": competition.id}
        )
        etag = kept.json()["data"]["updated"][0]["etag"]
        cleared = await editor_client.post(
            BULK,
            json={
                "action": "change_competition",
                "items": [{"id": match["id"], "etag": etag}],
                "competition_id": competition.id,
                "competition_stage": None,
            },
        )

        assert cleared.status_code == 200
        stored = await _stored(session, match["id"])
        assert stored.competition_stage is None
        assert (await audit_rows(session, "matches", match["id"]))[1].diff.get("competition_stage") is None

    async def test_an_unknown_competition_is_a_validation_error(self, editor_client):
        match = await new_match(editor_client)

        resp = await editor_client.post(
            BULK, json={"action": "change_competition", "items": _items(match), "competition_id": 2**62}
        )

        assert resp.status_code == 422

    async def test_an_unknown_match_is_match_not_found(self, editor_client, session):
        competition = await _competition(session)

        resp = await editor_client.post(
            BULK,
            json={
                "action": "change_competition",
                "items": [{"id": 2**62, "etag": '"x"'}],
                "competition_id": competition.id,
            },
        )

        assert resp.status_code == 404
        assert resp.json()["error"]["code"] == "match_not_found"


class TestRemoveChannels:
    async def _two_links(self, client, session):
        """A match with an editor-added link and an imported one."""
        editor_added, imported = await _channel_ids(session, 2)
        match = await new_match(client, channels=[{"channel_id": editor_added}])
        session.add(MatchChannel(match_id=match["id"], channel_id=imported, source="ysscores", imported_by="ysscores"))
        await session.flush()
        fresh = await client.get(f"{ADMIN}/matches/{match['id']}")
        return {**match, "_etag": fresh.headers["etag"]}, editor_added, imported

    async def test_an_admin_removes_every_visible_link_by_the_removal_rule(self, admin_client, session):
        match, editor_added, imported = await self._two_links(admin_client, session)

        resp = await admin_client.post(
            BULK, json={"action": "remove_channels", "items": _items(match), "channel_ids": None}
        )

        assert resp.status_code == 200, resp.text
        links = await _links(session, match["id"])
        assert set(links) == {imported}  # the editor's link is gone
        assert (links[imported].source, links[imported].imported_by, links[imported].is_hidden) == (
            "manual",
            "ysscores",
            True,
        )
        assert (await audit_rows(session, "matches", match["id"]))[-1].action == "bulk"

    async def test_only_the_listed_channels_are_removed(self, admin_client, session):
        match, editor_added, imported = await self._two_links(admin_client, session)

        resp = await admin_client.post(
            BULK, json={"action": "remove_channels", "items": _items(match), "channel_ids": [editor_added]}
        )

        assert resp.status_code == 200
        links = await _links(session, match["id"])
        assert set(links) == {imported}
        assert (links[imported].source, links[imported].is_hidden) == ("ysscores", False)

    async def test_an_editor_gets_403_and_nothing_changes(self, editor_client, session):
        match = await new_match(editor_client)
        before = await dataset_versions(session)

        resp = await editor_client.post(
            BULK, json={"action": "remove_channels", "items": [{"id": match["id"], "etag": '"stale"'}]}
        )

        assert resp.status_code == 403
        assert resp.json()["error"]["code"] == "forbidden"
        assert resp.json()["meta"] == {"required_role": "admin"}
        assert await dataset_versions(session) == before


class TestAllOrNothing:
    async def test_one_stale_item_refuses_the_whole_request(self, editor_client, session):
        competition = await _competition(session)
        fresh, stale = await new_match(editor_client), await new_match(editor_client)
        await patch_match(editor_client, stale, {"fields": {"stadium": "ملعب"}})  # now `stale["_etag"]` is old
        before = await dataset_versions(session)

        resp = await editor_client.post(
            BULK,
            json={"action": "change_competition", "items": _items(fresh, stale), "competition_id": competition.id},
        )

        assert resp.status_code == 409
        assert resp.json()["error"]["code"] == "edit_conflict"
        meta = resp.json()["meta"]
        assert meta["stale_ids"] == [stale["id"]]
        assert meta["current_etag"]
        assert meta["changed_by"] == {"kind": "admin", "name": editor_client.admin.name}
        assert (await _stored(session, fresh["id"])).competition_id is None
        assert await dataset_versions(session) == before

    async def test_201_items_are_refused(self, editor_client, session):
        competition = await _competition(session)

        resp = await editor_client.post(
            BULK,
            json={
                "action": "change_competition",
                "items": [{"id": i, "etag": '"x"'} for i in range(1, 202)],
                "competition_id": competition.id,
            },
        )

        assert resp.status_code == 422

    async def test_an_item_without_an_etag_is_428(self, editor_client, session):
        competition = await _competition(session)
        match = await new_match(editor_client)

        resp = await editor_client.post(
            BULK,
            json={"action": "change_competition", "items": [{"id": match["id"]}], "competition_id": competition.id},
        )

        assert resp.status_code == 428
        assert resp.json()["error"]["code"] == "precondition_required"

    async def test_the_same_match_twice_is_refused(self, editor_client, session):
        competition = await _competition(session)
        match = await new_match(editor_client)

        resp = await editor_client.post(
            BULK,
            json={
                "action": "change_competition",
                "items": _items(match, match),
                "competition_id": competition.id,
            },
        )

        assert resp.status_code == 422

    async def test_no_items_and_an_unknown_action_are_refused(self, editor_client):
        empty = await editor_client.post(BULK, json={"action": "change_competition", "items": [], "competition_id": 1})
        unknown = await editor_client.post(BULK, json={"action": "delete", "items": []})

        assert empty.status_code == 422
        assert unknown.status_code == 422
