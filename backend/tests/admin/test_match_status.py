"""Manual match status: set, clear, locks and what /v1 serves (T024, FR-011)."""

from __future__ import annotations

from sqlalchemy import select

from app.db.models import Match
from tests.admin.helpers import ADMIN, changed_datasets, dataset_versions, locks, new_match, patch_match

# 17:00Z is an hour before the frozen "now" (18:00Z), inside both /v1/matches and the /v1/live window.
STARTED = "2026-10-28T17:00:00Z"
WINDOW = {"from": "2026-10-28T00:00:00Z", "to": "2026-10-29T00:00:00Z"}
LIVE_1_0 = {"set": {"status": "live", "period": "2H", "minute": "67", "score": {"home": 1, "away": 0}}}


async def _started_match(client, **extra):
    return await new_match(client, kickoff_at=STARTED, match_date="2026-10-28", **extra)


async def _stored(session, match_id: int) -> Match:
    return await session.scalar(select(Match).where(Match.id == match_id).execution_options(populate_existing=True))


async def _in_v1(public_client, match_id: int) -> dict:
    listed = await public_client.get("/v1/matches", params=WINDOW)
    return next(row for row in listed.json()["data"] if row["id"] == match_id)


class TestSet:
    async def test_setting_live_1_0_stores_a_manual_status_and_locks_what_changed(
        self, editor_client, session, frozen_now
    ):
        match = await _started_match(editor_client)
        before = await dataset_versions(session)

        resp = await patch_match(editor_client, match, {"status": LIVE_1_0})

        assert resp.status_code == 200, resp.text
        data = resp.json()["data"]
        assert data["status"] == {
            "status": "live",
            "status_source": "manual",
            "estimated": False,
            "period": "2H",
            "minute": "67",
            "score": {"home": 1, "away": 0, "home_pen": None, "away_pen": None},
            "status_label": None,
            "status_updated_at": "2026-10-28T18:00:00Z",
        }
        assert data["locked_fields"] == locks("away_score", "home_score", "status")
        assert await changed_datasets(session, before) == {"matches", "live"}
        stored = await _stored(session, match["id"])
        assert (stored.status_source, stored.status, stored.home_score, stored.away_score) == ("manual", "live", 1, 0)
        assert stored.status_updated_at == frozen_now

    async def test_v1_serves_the_manual_status_as_not_estimated(self, editor_client, public_client):
        match = await _started_match(editor_client)
        await patch_match(editor_client, match, {"status": LIVE_1_0})

        row = await _in_v1(public_client, match["id"])
        live = await public_client.get("/v1/live")
        detail = await public_client.get(f"/v1/matches/{match['id']}")

        assert (row["status"], row["estimated"], row["minute"]) == ("live", False, "67")
        assert row["score"]["home"] == 1 and row["score"]["away"] == 0
        state = next(item for item in live.json()["data"] if item["match_id"] == match["id"])
        assert (state["status"], state["estimated"]) == ("live", False)
        assert state["score"]["home"] == 1
        assert detail.status_code == 200

    async def test_only_the_changed_fields_are_locked(self, editor_client):
        match = await _started_match(editor_client)

        resp = await patch_match(
            editor_client, match, {"status": {"set": {"status": "postponed", "status_label": "الأمطار"}}}
        )

        assert resp.json()["data"]["locked_fields"] == locks("status")
        assert resp.json()["data"]["status"]["status_label"] == "الأمطار"

    async def test_setting_the_same_status_again_changes_nothing(self, editor_client, session):
        match = await _started_match(editor_client)
        first = await patch_match(editor_client, match, {"status": LIVE_1_0})
        match["_etag"] = first.headers["etag"]
        before = await dataset_versions(session)

        again = await patch_match(editor_client, match, {"status": LIVE_1_0})

        assert again.headers["etag"] == first.headers["etag"]
        assert await dataset_versions(session) == before

    async def test_a_score_change_updates_the_score_and_the_timestamp(self, editor_client, session):
        match = await _started_match(editor_client)
        first = await patch_match(editor_client, match, {"status": LIVE_1_0})
        match["_etag"] = first.headers["etag"]

        second = await patch_match(
            editor_client, match, {"status": {"set": {**LIVE_1_0["set"], "score": {"home": 2, "away": 0}}}}
        )

        assert second.json()["data"]["status"]["score"]["home"] == 2

    async def test_finished_with_penalties_stores_them(self, editor_client):
        match = await _started_match(editor_client)

        resp = await patch_match(
            editor_client,
            match,
            {"status": {"set": {"status": "finished", "score": {"home": 1, "away": 1, "home_pen": 4, "away_pen": 3}}}},
        )

        assert resp.json()["data"]["status"]["score"] == {"home": 1, "away": 1, "home_pen": 4, "away_pen": 3}
        assert resp.json()["data"]["locked_fields"] == locks(
            "away_pen", "away_score", "home_pen", "home_score", "status"
        )


class TestRefusals:
    async def test_a_score_on_postponed_is_a_validation_error_with_the_field(self, editor_client, session):
        match = await _started_match(editor_client)
        before = await dataset_versions(session)

        resp = await patch_match(
            editor_client, match, {"status": {"set": {"status": "postponed", "score": {"home": 1, "away": 0}}}}
        )

        assert resp.status_code == 422
        assert resp.json()["error"]["code"] == "validation_error"
        assert {"loc": ["body", "status", "set", "score"], "type": "not_allowed"} in resp.json()["meta"]["errors"]
        assert await dataset_versions(session) == before
        assert (await _stored(session, match["id"])).status_source == "clock"

    async def test_every_bad_field_is_listed(self, editor_client):
        match = await _started_match(editor_client)

        resp = await patch_match(
            editor_client,
            match,
            {
                "status": {
                    "set": {"status": "halftime", "period": "1H", "minute": "45", "score": {"home": 0, "away": 0}}
                }
            },
        )

        fields = {tuple(e["loc"]) for e in resp.json()["meta"]["errors"]}
        assert fields == {("body", "status", "set", "period"), ("body", "status", "set", "minute")}

    async def test_live_needs_a_score(self, editor_client):
        match = await _started_match(editor_client)

        resp = await patch_match(editor_client, match, {"status": {"set": {"status": "live"}}})

        assert {"loc": ["body", "status", "set", "score"], "type": "required"} in resp.json()["meta"]["errors"]

    async def test_a_minute_must_match_the_pattern(self, editor_client):
        match = await _started_match(editor_client)

        resp = await patch_match(editor_client, match, {"status": {"set": {**LIVE_1_0["set"], "minute": "45+"}}})

        assert resp.status_code == 422

    async def test_set_and_clear_together_or_neither_are_refused(self, editor_client):
        match = await _started_match(editor_client)

        both = await patch_match(editor_client, match, {"status": {"set": LIVE_1_0["set"], "clear": True}})
        neither = await patch_match(editor_client, match, {"status": {}})

        assert both.status_code == 422
        assert neither.status_code == 422


class TestClear:
    async def test_clearing_returns_the_match_to_the_clock_and_unlocks_the_status_fields(
        self, editor_client, public_client, session
    ):
        match = await _started_match(editor_client)
        set_resp = await patch_match(editor_client, match, {"status": LIVE_1_0})
        match["_etag"] = set_resp.headers["etag"]
        before = await dataset_versions(session)

        resp = await patch_match(editor_client, match, {"status": {"clear": True}})

        assert resp.status_code == 200, resp.text
        status = resp.json()["data"]["status"]
        assert status["status_source"] == "clock"
        assert (status["period"], status["minute"], status["score"]) == (None, None, None)
        assert resp.json()["data"]["locked_fields"] == locks()
        assert await changed_datasets(session, before) == {"matches", "live"}

        stored = await _stored(session, match["id"])
        assert (stored.status_source, stored.status) == ("clock", "scheduled")
        assert (stored.home_score, stored.away_score, stored.home_pen, stored.away_pen) == (None, None, None, None)
        assert (stored.minute, stored.period, stored.status_label, stored.status_updated_at) == (None, None, None, None)

        row = await _in_v1(public_client, match["id"])
        assert (row["status"], row["estimated"], row["score"]) == ("live", True, None)  # derived from the clock again

    async def test_clearing_keeps_the_other_locks(self, editor_client):
        match = await _started_match(editor_client)
        first = await patch_match(editor_client, match, {"fields": {"stadium": "ملعب"}, "status": LIVE_1_0})
        match["_etag"] = first.headers["etag"]

        cleared = await patch_match(editor_client, match, {"status": {"clear": True}})

        assert cleared.json()["data"]["locked_fields"] == locks("stadium")

    async def test_clearing_a_clock_match_changes_nothing(self, editor_client, session):
        match = await _started_match(editor_client)
        before = await dataset_versions(session)

        resp = await patch_match(editor_client, match, {"status": {"clear": True}})

        assert resp.status_code == 200
        assert resp.headers["etag"] == match["_etag"]
        assert await dataset_versions(session) == before


async def test_the_a4_view_of_a_clock_match_shows_the_estimated_state_without_a_score(editor_client):
    match = await _started_match(editor_client)

    data = (await editor_client.get(f"{ADMIN}/matches/{match['id']}")).json()["data"]

    assert data["status"]["status_source"] == "clock"
    assert (data["status"]["status"], data["status"]["estimated"], data["status"]["score"]) == ("live", True, None)


# --- D6: an editor's save produces the push rows (T024, FR-009) ---------------------------------------


async def test_finishing_a_match_by_hand_queues_final_score(editor_client, session):
    from app.db.models import NotificationOutbox

    match = await _started_match(editor_client)
    resp = await patch_match(
        editor_client,
        match,
        {"status": {"set": {"status": "live", "score": {"home": 1, "away": 0}}}},
    )
    assert resp.status_code == 200, resp.text
    match = {**match, "_etag": resp.headers["etag"]}
    resp = await patch_match(
        editor_client, match, {"status": {"set": {"status": "finished", "score": {"home": 2, "away": 1}}}}
    )
    assert resp.status_code == 200, resp.text

    rows = list(await session.scalars(select(NotificationOutbox)))
    assert [row.type for row in rows] == ["final_score"]
    assert rows[0].dedupe_key == f"final_score:{match['id']}"


async def test_lowering_a_pushed_score_by_hand_queues_a_correction(editor_client, session, frozen_now):
    from app.db.models import MatchLiveState, NotificationOutbox

    match = await _started_match(editor_client)
    resp = await patch_match(
        editor_client, match, {"status": {"set": {"status": "live", "score": {"home": 2, "away": 0}}}}
    )
    assert resp.status_code == 200, resp.text
    match = {**match, "_etag": resp.headers["etag"]}
    session.add(MatchLiveState(match_id=match["id"], push_memory={"home": 2, "away": 0, "generation": 0}))
    session.add(
        NotificationOutbox(
            type="goal",
            dedupe_key=f"goal:{match['id']}:0:home:2",
            payload={"match_id": match["id"], "side": "home", "home": 2, "away": 0, "generation": 0},
            audience={"kind": "match_core", "match_id": match["id"]},
            due_at=frozen_now,
            status="sent",
            sent=5,
        )
    )
    await session.flush()

    resp = await patch_match(
        editor_client, match, {"status": {"set": {"status": "live", "score": {"home": 1, "away": 0}}}}
    )
    assert resp.status_code == 200, resp.text

    rows = list(await session.scalars(select(NotificationOutbox)))
    corrections = [row for row in rows if row.payload.get("kind") == "correction"]
    assert [row.dedupe_key for row in corrections] == [f"goal_correction:{match['id']}:0"]


async def test_adding_and_removing_a_link_queues_one_channel_change_row(editor_client, session, frozen_now):
    from app.db.models import NotificationOutbox

    match = await new_match(editor_client, kickoff_at="2026-10-28T20:00:00Z", match_date="2026-10-28")
    channel_id = await session.scalar(select(Match.id))  # any id the picker accepts is checked by the API
    del channel_id
    from app.db.models import Channel

    channel = await session.scalar(select(Channel).limit(1))

    resp = await patch_match(editor_client, match, {"channels": [{"channel_id": channel.id}]})
    assert resp.status_code == 200, resp.text

    rows = list(await session.scalars(select(NotificationOutbox)))
    assert [row.type for row in rows] == ["channels_updated"]
    assert rows[0].audience == {"kind": "match_followers", "match_id": match["id"]}
