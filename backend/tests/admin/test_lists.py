"""The A3 list, the pickers and the small lists (T027, R9)."""

from __future__ import annotations

from urllib.parse import quote

from sqlalchemy import func, select

from app.db.models import Channel, MatchChannel, MatchExternalId, Satellite
from tests.admin.helpers import (
    ADMIN,
    audit_rows,
    changed_datasets,
    create,
    dataset_versions,
    make_asset,
    new_match,
    patch_match,
)

MATCHES = f"{ADMIN}/matches"
DAY = {"from": "2026-10-31T00:00:00Z", "to": "2026-11-01T00:00:00Z"}


async def _ids(client, params: dict) -> list[int]:
    resp = await client.get(MATCHES, params={**DAY, **params})
    assert resp.status_code == 200, resp.text
    return [row["id"] for row in resp.json()["data"]]


# --- GET /matches -------------------------------------------------------------------------------------------


class TestMatchList:
    async def test_a_window_over_8_days_is_refused(self, editor_client):
        resp = await editor_client.get(MATCHES, params={"from": "2026-10-01T00:00:00Z", "to": "2026-10-10T00:00:00Z"})

        assert resp.status_code == 422
        assert resp.json()["error"]["code"] == "validation_error"

    async def test_8_days_and_a_reversed_window(self, editor_client):
        ok = await editor_client.get(MATCHES, params={"from": "2026-10-01T00:00:00Z", "to": "2026-10-09T00:00:00Z"})
        reversed_ = await editor_client.get(MATCHES, params={"from": DAY["to"], "to": DAY["from"]})

        assert ok.status_code == 200
        assert reversed_.status_code == 422

    async def test_a_row_has_the_a3_fields(self, editor_client):
        match = await new_match(editor_client, stadium="ملعب")

        row = next(r for r in (await editor_client.get(MATCHES, params=DAY)).json()["data"] if r["id"] == match["id"])

        assert row["status"] == "scheduled" and row["estimated"] is False and row["score"] is None
        assert row["competition"]["name"] == "بطولة اختبار"
        assert (row["home"]["name"], row["away"]["name"]) == ("فريق أ", "فريق ب")
        assert (row["channel_count"], row["broadcaster_count"], row["missing_channels"]) == (0, 0, True)
        assert row["sources"] == ["manual"]
        assert row["locked"] is True  # a create locks the fields the editor supplied (B1-R1-4)
        assert row["etag"] == (await editor_client.get(f"{MATCHES}/{match['id']}")).headers["etag"]

    async def test_missing_channels_means_no_visible_link_and_no_manual_broadcaster(self, editor_client, session):
        channel_id = await session.scalar(select(Channel.id).where(Channel.deleted_at.is_(None)).order_by(Channel.id))
        bare = await new_match(editor_client)
        with_channel = await new_match(editor_client, channels=[{"channel_id": channel_id}])
        with_slot = await new_match(editor_client, broadcasts=[{"slot": 1, "label": "ON Sport 1"}])
        hidden_only = await new_match(editor_client, channels=[{"channel_id": channel_id, "is_hidden": True}])

        missing = await _ids(editor_client, {"missing_channels": "true"})
        complete = await _ids(editor_client, {"missing_channels": "false"})

        assert bare["id"] in missing and hidden_only["id"] in missing
        assert with_channel["id"] in complete and with_slot["id"] in complete
        assert not {with_channel["id"], with_slot["id"]} & set(missing)

    async def test_the_competition_filter(self, editor_client):
        cup = await create(editor_client, f"{ADMIN}/competitions", {"name": "كأس الاختبار"})
        in_cup = await new_match(editor_client, competition_id=cup["id"], competition_name=None)
        other = await new_match(editor_client)

        ids = await _ids(editor_client, {"competition_id": cup["id"]})

        assert in_cup["id"] in ids and other["id"] not in ids

    async def test_the_source_filter_matches_the_creator_or_any_external_id(self, editor_client, session):
        created_here = await new_match(editor_client)
        imported = await new_match(editor_client)
        session.add(MatchExternalId(source="ysscores", external_id="ext-1", match_id=imported["id"]))
        await session.flush()

        by_creator = await _ids(editor_client, {"source": "manual"})
        by_external = await _ids(editor_client, {"source": "ysscores"})

        assert created_here["id"] in by_creator
        assert imported["id"] in by_external and created_here["id"] not in by_external
        row = next(
            r for r in (await editor_client.get(MATCHES, params=DAY)).json()["data"] if r["id"] == imported["id"]
        )
        assert row["sources"] == ["manual", "ysscores"]

    async def test_the_status_filter_uses_the_derived_status(self, editor_client):
        past = await new_match(editor_client, kickoff_at="2026-10-28T10:00:00Z", match_date="2026-10-28")
        future = await new_match(editor_client)
        window = {"from": "2026-10-28T00:00:00Z", "to": "2026-11-01T00:00:00Z"}

        finished = await editor_client.get(MATCHES, params={**window, "status": "finished"})
        scheduled = await editor_client.get(MATCHES, params={**window, "status": "scheduled"})

        finished_ids = {r["id"] for r in finished.json()["data"]}
        assert past["id"] in finished_ids and future["id"] not in finished_ids
        row = next(r for r in finished.json()["data"] if r["id"] == past["id"])
        assert row["estimated"] is True and row["score"] is None
        assert future["id"] in {r["id"] for r in scheduled.json()["data"]}

    async def test_order_is_competition_priority_nulls_last_then_kickoff(self, editor_client):
        first = await create(editor_client, f"{ADMIN}/competitions", {"name": "أولى", "priority": 1})
        second = await create(editor_client, f"{ADMIN}/competitions", {"name": "ثانية", "priority": 2})
        late_first = await new_match(
            editor_client, competition_id=first["id"], competition_name=None, kickoff_at="2026-10-31T20:00:00Z"
        )
        early_first = await new_match(
            editor_client, competition_id=first["id"], competition_name=None, kickoff_at="2026-10-31T10:00:00Z"
        )
        in_second = await new_match(
            editor_client, competition_id=second["id"], competition_name=None, kickoff_at="2026-10-31T08:00:00Z"
        )
        text_only = await new_match(editor_client, kickoff_at="2026-10-31T07:00:00Z")
        mine = [early_first["id"], late_first["id"], in_second["id"], text_only["id"]]

        ids = [i for i in await _ids(editor_client, {}) if i in mine]

        assert ids == mine

    async def test_the_list_has_a_weak_etag_and_answers_304(self, editor_client):
        await new_match(editor_client)
        first = await editor_client.get(MATCHES, params=DAY)

        again = await editor_client.get(MATCHES, params=DAY, headers={"If-None-Match": first.headers["etag"]})

        assert first.headers["etag"].startswith("W/")
        assert again.status_code == 304

    async def test_an_edit_makes_the_list_etag_stale(self, editor_client):
        match = await new_match(editor_client)
        first = await editor_client.get(MATCHES, params=DAY)
        await patch_match(editor_client, match, {"fields": {"stadium": "ملعب"}})

        again = await editor_client.get(MATCHES, params=DAY, headers={"If-None-Match": first.headers["etag"]})

        assert again.status_code == 200


# --- pickers and pages ----------------------------------------------------------------------------------------


class TestTeamPicker:
    async def test_search_returns_the_top_matches_with_a_prefix_match_first(self, editor_client):
        contains = await create(editor_client, f"{ADMIN}/teams", {"name": "نادي الاهلي الرياضي"})
        prefix = await create(editor_client, f"{ADMIN}/teams", {"name": "الأهلي بنغازي"})
        await create(editor_client, f"{ADMIN}/teams", {"name": "الزمالك"})

        resp = await editor_client.get(f"{ADMIN}/teams", params={"q": "الاهلي"})

        ids = [t["id"] for t in resp.json()["data"]]
        assert ids.index(prefix["id"]) < ids.index(contains["id"])
        assert resp.json()["meta"]["next_cursor"] is None
        assert len(ids) <= 20

    async def test_an_item_tells_same_name_teams_apart(self, editor_client, session):
        competition = await create(editor_client, f"{ADMIN}/competitions", {"name": "دوري التمييز"})
        other = await create(editor_client, f"{ADMIN}/competitions", {"name": "كأس التمييز"})
        logo = await make_asset(session, "team-logo")
        team = await create(
            editor_client,
            f"{ADMIN}/teams",
            {
                "name": "فريق التمييز",
                "country": "مصر",
                "logo_asset_id": logo,
                "primary_competition_id": competition["id"],
                "competition_ids": [competition["id"], other["id"]],
            },
        )

        item = next(
            t
            for t in (await editor_client.get(f"{ADMIN}/teams", params={"q": "فريق التمييز"})).json()["data"]
            if t["id"] == team["id"]
        )

        assert item["country"] == "مصر"
        assert item["logo"].endswith("/logos/team-logo")
        assert item["primary_competition"] == {"id": competition["id"], "name": "دوري التمييز"}
        assert {c["id"] for c in item["competitions"]} == {competition["id"], other["id"]}

    async def test_a_query_over_64_characters_is_refused(self, editor_client):
        resp = await editor_client.get(f"{ADMIN}/teams", params={"q": "ا" * 65})

        assert resp.status_code == 422

    async def test_paging_is_stable_while_rows_are_inserted(self, editor_client):
        for name in ("ألف", "باء", "تاء", "ثاء"):
            await create(editor_client, f"{ADMIN}/teams", {"name": f"صفحة {name}"})
        first = (await editor_client.get(f"{ADMIN}/teams", params={"limit": 2})).json()
        cursor = first["meta"]["next_cursor"]
        assert cursor and len(first["data"]) == 2

        await create(editor_client, f"{ADMIN}/teams", {"name": "!!! قبل كل شيء"})  # sorts before page 1
        second = (await editor_client.get(f"{ADMIN}/teams", params={"limit": 2, "cursor": cursor})).json()

        seen = {t["id"] for t in first["data"]}
        assert not seen & {t["id"] for t in second["data"]}
        assert [t["name"] for t in second["data"]] == sorted(t["name"] for t in second["data"])

    async def test_the_last_page_has_no_cursor_and_a_bad_cursor_is_refused(self, editor_client):
        bad = await editor_client.get(f"{ADMIN}/teams", params={"cursor": "not-a-cursor"})
        everything = await editor_client.get(f"{ADMIN}/teams", params={"limit": 100})

        assert bad.status_code == 422
        assert everything.status_code == 200

    async def test_limit_over_100_is_refused(self, editor_client):
        assert (await editor_client.get(f"{ADMIN}/teams", params={"limit": 101})).status_code == 422

    async def test_the_missing_logo_filter(self, editor_client, session):
        logo = await make_asset(session, "has-logo")
        with_logo = await create(editor_client, f"{ADMIN}/teams", {"name": "فريق بشعار", "logo_asset_id": logo})
        without = await create(editor_client, f"{ADMIN}/teams", {"name": "فريق بلا شعار"})

        missing = await editor_client.get(f"{ADMIN}/teams", params={"missing_logo": "true", "q": "فريق"})

        ids = {t["id"] for t in missing.json()["data"]}
        assert without["id"] in ids and with_logo["id"] not in ids


class TestChannelsAndCommentators:
    async def test_channels_filter_by_satellite_category_kind_access_and_logo(self, editor_client, session):
        satellite = await session.scalar(select(Satellite).join(Channel, Channel.satellite_id == Satellite.id).limit(1))

        by_satellite = await editor_client.get(f"{ADMIN}/channels", params={"satellite_id": satellite.id, "limit": 100})
        by_kind = await editor_client.get(f"{ADMIN}/channels", params={"kind": "platform", "limit": 100})
        by_access = await editor_client.get(f"{ADMIN}/channels", params={"access": "free", "limit": 100})
        by_category = await editor_client.get(f"{ADMIN}/channels", params={"category": "sports", "limit": 100})
        no_logo = await editor_client.get(f"{ADMIN}/channels", params={"missing_logo": "true", "limit": 100})

        assert {c["satellite_id"] for c in by_satellite.json()["data"]} == {satellite.id}
        assert {c["kind"] for c in by_kind.json()["data"]} == {"platform"}
        assert {c["access"] for c in by_access.json()["data"]} == {"free"}
        assert {c["category"] for c in by_category.json()["data"]} == {"sports"}
        assert all(c["logo"] is None for c in no_logo.json()["data"])

    async def test_platforms_without_a_satellite_are_in_the_unfiltered_pages(self, editor_client):
        platform = await create(editor_client, f"{ADMIN}/channels", {"kind": "platform", "name": "منصة بلا قمر"})
        seen: list[int] = []
        cursor = None
        while True:
            params = {"limit": 100, **({"cursor": cursor} if cursor else {})}
            page = (await editor_client.get(f"{ADMIN}/channels", params=params)).json()
            seen += [c["id"] for c in page["data"]]
            cursor = page["meta"]["next_cursor"]
            if not cursor:
                break

        assert platform["id"] in seen
        assert len(seen) == len(set(seen))

    async def test_channel_pages_follow_sort_order_with_nulls_last(self, editor_client):
        page = (await editor_client.get(f"{ADMIN}/channels", params={"limit": 100})).json()["data"]

        orders = [c["sort_order"] for c in page]
        numbers = [o for o in orders if o is not None]
        assert numbers == sorted(numbers)
        assert orders[: len(numbers)] == numbers

    async def test_a_deleted_channel_is_not_listed(self, editor_client):
        channel = await create(editor_client, f"{ADMIN}/channels", {"kind": "platform", "name": "منصة ستحذف"})
        await editor_client.delete(f"{ADMIN}/channels/{channel['id']}", headers={"If-Match": channel["_etag"]})

        found = await editor_client.get(f"{ADMIN}/channels", params={"q": "منصة ستحذف"})

        assert channel["id"] not in {c["id"] for c in found.json()["data"]}

    async def test_commentators_search_and_page(self, editor_client):
        for name in ("معلق ألف", "معلق باء", "معلق تاء"):
            await create(editor_client, f"{ADMIN}/commentators", {"name": name})

        found = await editor_client.get(f"{ADMIN}/commentators", params={"q": "معلق باء"})
        page = (await editor_client.get(f"{ADMIN}/commentators", params={"limit": 2})).json()

        assert found.json()["data"][0]["name"] == "معلق باء"
        assert found.json()["data"][0]["usage"] == {"matches": 0, "match_channels": 0}
        assert len(page["data"]) == 2 and page["meta"]["next_cursor"]


# --- small lists -------------------------------------------------------------------------------------------------


async def test_broadcast_presets_and_sources_are_read_only_lists(editor_client):
    presets = await editor_client.get(f"{ADMIN}/broadcast-presets")
    sources = await editor_client.get(f"{ADMIN}/sources")

    assert presets.status_code == 200 and isinstance(presets.json()["data"], list)
    names = {s["name"] for s in sources.json()["data"]}
    assert {"manual", "ysscores"} <= names
    # D3 replaced the item with its health (contracts/admin-api.md §Sources).
    assert set(sources.json()["data"][0]) == {
        "name",
        "kind",
        "is_enabled",
        "breaker",
        "breaker_opened_at",
        "consecutive_failures",
        "paused",
        "last_success_at",
        "last_run",
        "items_24h",
        "error_rate_24h",
        "running",
    }
    assert (await editor_client.post(f"{ADMIN}/sources", json={})).status_code == 405


async def test_a_preset_lists_the_asset_id_the_editor_saves_in_a_slot(editor_client, session):
    """A4 saves a slot's `logo_asset_id`; the preset list has to carry it (B1-R2-8, A-R2-2)."""
    from app.db.models import BroadcastPreset

    asset_id = await make_asset(session, "preset-logo")
    session.add(BroadcastPreset(name="قناة البث التجريبية", logo_asset_id=asset_id))
    await session.flush()

    resp = await editor_client.get(f"{ADMIN}/broadcast-presets")

    assert resp.status_code == 200, resp.text
    row = next(r for r in resp.json()["data"] if r["name"] == "قناة البث التجريبية")
    assert row["logo_asset_id"] == asset_id
    assert row["logo"]  # the URL is still there for the preview


class TestHiddenNames:
    async def test_adding_stores_the_normalized_name_then_is_idempotent(self, editor_client, session):
        before = await dataset_versions(session)

        first = await editor_client.post(f"{ADMIN}/hidden-channel-names", json={"name": "  أبو ظبي الرياضية  "})
        second = await editor_client.post(f"{ADMIN}/hidden-channel-names", json={"name": "  أبو ظبي الرياضية  "})

        normalized = await session.scalar(select(func.ar_normalize("  أبو ظبي الرياضية  ")))
        assert (first.status_code, second.status_code) == (201, 200)
        assert first.json()["data"] == {"name": normalized} == second.json()["data"]
        assert await changed_datasets(session, before) == {"matches", "channels"}
        rows = await audit_rows(session, "hidden_channel_names")
        assert len(rows) == 1  # the repeat wrote nothing
        assert (rows[0].action, rows[0].entity_id, rows[0].diff) == ("create", None, {"name": [None, normalized]})

        listed = await editor_client.get(f"{ADMIN}/hidden-channel-names")
        assert {"name": normalized} in listed.json()["data"]

    async def test_removing_takes_the_url_encoded_name_then_404s(self, editor_client, session):
        posted = await editor_client.post(f"{ADMIN}/hidden-channel-names", json={"name": "قناة للإخفاء"})
        name = posted.json()["data"]["name"]
        before = await dataset_versions(session)

        removed = await editor_client.delete(f"{ADMIN}/hidden-channel-names/{quote(name, safe='')}")
        again = await editor_client.delete(f"{ADMIN}/hidden-channel-names/{quote(name, safe='')}")

        assert removed.status_code == 200 and removed.json()["data"] is None
        assert (again.status_code, again.json()["error"]["code"]) == (404, "hidden_name_not_found")
        assert await changed_datasets(session, before) == {"matches", "channels"}
        rows = await audit_rows(session, "hidden_channel_names")
        assert [r.action for r in rows] == ["create", "delete"]

    async def test_a_hidden_name_marks_matching_channels_hidden_by_name(self, editor_client, session):
        channel = await session.scalar(select(Channel).where(Channel.deleted_at.is_(None)).order_by(Channel.id))
        match = await new_match(editor_client, channels=[{"channel_id": channel.id}])
        assert match["channels"][0]["hidden_by_name"] is False

        await editor_client.post(f"{ADMIN}/hidden-channel-names", json={"name": channel.name})

        data = (await editor_client.get(f"{MATCHES}/{match['id']}")).json()["data"]
        assert data["channels"][0]["hidden_by_name"] is True
        assert data["channels"][0]["is_hidden"] is False

    async def test_an_empty_name_is_refused(self, editor_client):
        assert (await editor_client.post(f"{ADMIN}/hidden-channel-names", json={"name": ""})).status_code == 422

    async def test_a_hidden_name_changes_the_satellite_etags(self, editor_client, public_client, session):
        """B1-R1-5: /v1/satellites filters by hidden names, so its version must move with them."""
        satellite = await session.scalar(select(Satellite).order_by(Satellite.id))
        list_path = "/v1/satellites"
        channels_path = f"/v1/satellites/{satellite.id}/channels"
        before = [(await public_client.get(path)).headers["etag"] for path in (list_path, channels_path)]

        posted = await editor_client.post(f"{ADMIN}/hidden-channel-names", json={"name": "قناة تختفي"})
        after_add = [(await public_client.get(path)).headers["etag"] for path in (list_path, channels_path)]

        await editor_client.delete(f"{ADMIN}/hidden-channel-names/{quote(posted.json()['data']['name'], safe='')}")
        after_remove = [(await public_client.get(path)).headers["etag"] for path in (list_path, channels_path)]

        assert after_add[0] != before[0] and after_add[1] != before[1]
        assert after_remove[0] != after_add[0] and after_remove[1] != after_add[1]


async def test_a_link_row_for_a_deleted_channel_is_not_shown_in_the_editor(editor_client, session):
    channel = await create(editor_client, f"{ADMIN}/channels", {"kind": "platform", "name": "منصة مؤقتة"})
    match = await new_match(editor_client, channels=[{"channel_id": channel["id"]}])
    await editor_client.delete(f"{ADMIN}/channels/{channel['id']}", headers={"If-Match": channel["_etag"]})

    data = (await editor_client.get(f"{MATCHES}/{match['id']}")).json()["data"]

    assert data["channels"] == []
    assert (
        await session.scalar(select(func.count()).select_from(MatchChannel).where(MatchChannel.match_id == match["id"]))
        == 1
    )
