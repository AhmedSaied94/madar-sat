"""An admin edit reaches /v1 on the very next conditional request (T029, R11, FR-014)."""

from __future__ import annotations

from sqlalchemy import select

from app.db.models import Channel
from tests.admin.helpers import new_match, patch_match

STARTED = "2026-10-28T17:00:00Z"  # an hour before the frozen "now", inside the /v1/live window
WINDOW = {"from": "2026-10-28T00:00:00Z", "to": "2026-10-29T00:00:00Z"}


async def _started_match(client):
    return await new_match(client, kickoff_at=STARTED, match_date="2026-10-28")


async def _conditional(public_client, path: str, etag: str, params: dict | None = None):
    return await public_client.get(path, params=params, headers={"If-None-Match": etag})


async def test_the_untouched_etag_still_answers_304(editor_client, public_client):
    """The control: without an edit, the old ETag is current."""
    await _started_match(editor_client)
    first = await public_client.get("/v1/matches", params=WINDOW)

    again = await _conditional(public_client, "/v1/matches", first.headers["etag"], WINDOW)

    assert again.status_code == 304


async def test_a_kickoff_change_reaches_matches_and_live(editor_client, public_client):
    match = await _started_match(editor_client)
    matches_etag = (await public_client.get("/v1/matches", params=WINDOW)).headers["etag"]
    live_etag = (await public_client.get("/v1/live")).headers["etag"]

    await patch_match(editor_client, match, {"fields": {"kickoff_at": "2026-10-28T17:30:00Z"}})

    matches = await _conditional(public_client, "/v1/matches", matches_etag, WINDOW)
    live = await _conditional(public_client, "/v1/live", live_etag)
    assert matches.status_code == 200
    changed = next(row for row in matches.json()["data"] if row["id"] == match["id"])
    assert changed["kickoff_at"] == "2026-10-28T17:30:00Z"
    assert live.status_code == 200
    assert matches.headers["etag"] != matches_etag
    assert live.headers["etag"] != live_etag


async def test_a_channel_change_reaches_matches(editor_client, public_client, session):
    channel_id = await session.scalar(select(Channel.id).where(Channel.deleted_at.is_(None)).order_by(Channel.id))
    match = await _started_match(editor_client)
    first = await public_client.get("/v1/matches", params=WINDOW)

    await patch_match(editor_client, match, {"channels": [{"channel_id": channel_id}]})

    after = await _conditional(public_client, "/v1/matches", first.headers["etag"], WINDOW)
    assert after.status_code == 200
    row = next(row for row in after.json()["data"] if row["id"] == match["id"])
    assert row["broadcast"]["channel_count"] == 1


async def test_a_hidden_link_is_not_shown_in_v1(editor_client, public_client, session):
    channel_id = await session.scalar(select(Channel.id).where(Channel.deleted_at.is_(None)).order_by(Channel.id))
    match = await _started_match(editor_client)
    shown = await patch_match(editor_client, match, {"channels": [{"channel_id": channel_id}]})
    match["_etag"] = shown.headers["etag"]
    first = await public_client.get("/v1/matches", params=WINDOW)

    await patch_match(editor_client, match, {"channels": [{"channel_id": channel_id, "is_hidden": True}]})

    after = await _conditional(public_client, "/v1/matches", first.headers["etag"], WINDOW)
    row = next(row for row in after.json()["data"] if row["id"] == match["id"])
    assert after.status_code == 200
    assert row["broadcast"]["channel_count"] == 0


async def test_a_manual_status_reaches_matches_and_live(editor_client, public_client):
    match = await _started_match(editor_client)
    matches_etag = (await public_client.get("/v1/matches", params=WINDOW)).headers["etag"]
    live_etag = (await public_client.get("/v1/live")).headers["etag"]

    await patch_match(
        editor_client,
        match,
        {"status": {"set": {"status": "live", "minute": "30", "score": {"home": 1, "away": 1}}}},
    )

    matches = await _conditional(public_client, "/v1/matches", matches_etag, WINDOW)
    live = await _conditional(public_client, "/v1/live", live_etag)
    assert matches.status_code == 200
    assert live.status_code == 200
    row = next(row for row in matches.json()["data"] if row["id"] == match["id"])
    assert (row["status"], row["estimated"], row["minute"]) == ("live", False, "30")
    state = next(item for item in live.json()["data"] if item["match_id"] == match["id"])
    assert (state["status"], state["estimated"]) == ("live", False)


async def test_clearing_the_status_reaches_v1_too(editor_client, public_client):
    match = await _started_match(editor_client)
    live = await patch_match(
        editor_client, match, {"status": {"set": {"status": "finished", "score": {"home": 3, "away": 0}}}}
    )
    match["_etag"] = live.headers["etag"]
    matches_etag = (await public_client.get("/v1/matches", params=WINDOW)).headers["etag"]

    await patch_match(editor_client, match, {"status": {"clear": True}})

    after = await _conditional(public_client, "/v1/matches", matches_etag, WINDOW)
    assert after.status_code == 200
    row = next(row for row in after.json()["data"] if row["id"] == match["id"])
    assert (row["status"], row["estimated"], row["score"]) == ("live", True, None)
