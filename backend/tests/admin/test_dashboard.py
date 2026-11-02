"""A2: the dashboard (T026)."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import update

from app.db.models import AuditLog, Channel, DatasetVersion
from app.services.admin import writer
from tests import support


def _window(now, hours: int = 24):
    return {"from": (now - timedelta(hours=1)).isoformat(), "to": (now + timedelta(hours=hours)).isoformat()}


async def test_matches_without_a_visible_channel_are_grouped_by_priority_then_kickoff(
    editor_client, session, frozen_now
):
    low = await support.create_match(
        session, frozen_now, links=False, competition_priority=1, kickoff_in=timedelta(minutes=40)
    )
    high = await support.create_match(
        session, frozen_now, links=False, competition_priority=1, kickoff_in=timedelta(minutes=10)
    )
    later = await support.create_match(
        session, frozen_now, links=False, competition_priority=3, kickoff_in=timedelta(minutes=20)
    )
    served = await support.create_match(session, frozen_now, competition_priority=9)

    response = await editor_client.get("/admin/api/dashboard", params=_window(frozen_now))

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    groups = data["missing_channels"]
    # One group per competition, ordered by priority; rows inside a priority by kickoff.
    assert [group["competition"]["priority"] for group in groups] == [1, 1, 3]
    assert [match["id"] for group in groups for match in group["matches"]] == [
        high.match.id,
        low.match.id,
        later.match.id,
    ]
    assert data["missing_channels_count"] == 3
    assert served.match.id not in [match["id"] for group in groups for match in group["matches"]]


async def test_placeholders_and_sources_are_counted(editor_client, session, frozen_now):
    placeholder = Channel(kind="platform", name="A2 placeholder", placeholder_source="livesoccertv", locked_fields=[])
    gone = Channel(
        kind="platform", name="A2 deleted", placeholder_source="livesoccertv", deleted_at=frozen_now, locked_fields=[]
    )
    session.add_all([placeholder, gone])
    await session.flush()

    data = (await editor_client.get("/admin/api/dashboard", params=_window(frozen_now))).json()["data"]
    sources = (await editor_client.get("/admin/api/sources")).json()["data"]

    assert data["placeholders_to_complete"] == 1
    assert data["sources"] == sources


async def test_recent_changes_are_the_last_ten_audit_entries(editor_client, session, frozen_now):
    admin = editor_client.admin
    for index in range(12):
        writer.add_audit(session, admin, "match", index, "update", {"index": [None, index]})
    await session.flush()

    data = (await editor_client.get("/admin/api/dashboard", params=_window(frozen_now))).json()["data"]

    assert len(data["recent_changes"]) == 10
    assert data["recent_changes"][0]["entity_id"] == 11
    assert data["recent_changes"][0]["by"]["kind"] == "admin"


async def test_a_window_over_two_days_is_422(editor_client, frozen_now):
    params = {
        "from": frozen_now.isoformat(),
        "to": (frozen_now + timedelta(days=3)).isoformat(),
    }
    response = await editor_client.get("/admin/api/dashboard", params=params)

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


async def test_the_etag_follows_the_data_and_a_minute(editor_client, session, frozen_now):
    first = await editor_client.get("/admin/api/dashboard", params=_window(frozen_now))
    second = await editor_client.get("/admin/api/dashboard", params=_window(frozen_now))
    assert first.headers["etag"] == second.headers["etag"]

    await session.execute(
        update(DatasetVersion).where(DatasetVersion.name == "matches").values(version=DatasetVersion.version + 1)
    )
    third = await editor_client.get("/admin/api/dashboard", params=_window(frozen_now))

    assert third.headers["etag"] != first.headers["etag"]


_ = AuditLog
