"""A17: the audit log — actors, filters, cursor, detail and its read-only nature (T017)."""

from __future__ import annotations

from datetime import timedelta

import pytest
from sqlalchemy import update

from app.db.models import AuditLog, DatasetVersion, NotificationOutbox
from app.services.admin import writer
from tests.admin.helpers import ADMIN

AUDIT = f"{ADMIN}/audit"


@pytest.fixture(scope="session", autouse=True)
def _audit_router_on_the_admin_app():
    """T017's router is registered here because ``app/admin.py`` belongs to another task."""
    from app.admin import app
    from app.api.admin import audit as audit_api

    if not any(getattr(route, "path", None) == AUDIT for route in app.routes):
        app.include_router(audit_api.router)


async def test_an_importer_entry_is_named_after_its_source_and_the_system_has_no_name(admin_client, session):
    session.add(
        AuditLog(
            source="ysscores",
            entity="channel",
            entity_id=900001,
            action="update",
            diff={"frequency_mhz": [11766, 11843]},
        )
    )
    session.add(AuditLog(admin_user_id=None, source=None, entity="channel", entity_id=900002, action="update", diff={}))
    await session.flush()

    importer = await admin_client.get(AUDIT, params={"entity": "channel", "entity_id": 900001})
    assert importer.status_code == 200, importer.text
    [entry] = importer.json()["data"]
    assert entry["actor"] == {"kind": "importer", "id": None, "name": "ysscores"}

    system = await admin_client.get(AUDIT, params={"entity": "channel", "entity_id": 900002})
    [entry] = system.json()["data"]
    assert entry["actor"] == {"kind": "system", "id": None, "name": None}
    assert entry["summary_fields"] == []


async def test_the_actor_is_the_admin_and_a_linked_push_is_flagged(admin_client, session, frozen_now):
    entry = writer.add_audit(session, admin_client.admin, "channel", 412, "update", {"frequency_mhz": [11766, 11843]})
    await session.flush()
    outbox = NotificationOutbox(
        type="frequency_changed",
        dedupe_key="audit-detail-1",
        payload={"kind": "correction"},
        audience={"kind": "channel", "id": 412},
        due_at=frozen_now,
        status="sent",
        sent=118,
        audit_log_id=entry.id,
    )
    session.add(outbox)
    await session.flush()

    listed = await admin_client.get(AUDIT, params={"admin_user_id": admin_client.admin.id})

    assert listed.status_code == 200, listed.text
    assert listed.headers["etag"]
    [row] = listed.json()["data"]
    assert row["actor"] == {"kind": "admin", "id": admin_client.admin.id, "name": "مدير"}
    assert row["entity"] == "channel"
    assert row["entity_id"] == 412
    assert row["action"] == "update"
    assert row["summary_fields"] == ["frequency_mhz"]
    assert row["has_notification"] is True

    detail = await admin_client.get(f"{AUDIT}/{entry.id}")
    assert detail.status_code == 200, detail.text
    data = detail.json()["data"]
    assert data["diff"] == {"frequency_mhz": [11766, 11843]}
    assert data["notification"] == {
        "id": outbox.id,
        "type": "frequency_changed",
        "status": "sent",
        "sent": 118,
        "failed": 0,
    }
    assert data["has_notification"] is True


async def test_an_unlinked_entry_has_no_notification_and_keeps_an_old_diff_shape(admin_client, session):
    entry = writer.add_audit(session, admin_client.admin, "admin_users", 3, "update", {"password": "changed"})
    await session.flush()

    detail = await admin_client.get(f"{AUDIT}/{entry.id}")

    data = detail.json()["data"]
    assert data["diff"] == {"password": "changed"}
    assert data["notification"] is None
    assert data["has_notification"] is False


async def test_the_cursor_walks_backwards_in_pages(admin_client, session):
    for index in range(3):
        writer.add_audit(session, admin_client.admin, "team", index + 1, "update", {"index": [None, index]})
    await session.flush()
    actor = {"admin_user_id": admin_client.admin.id, "limit": 2}

    first = await admin_client.get(AUDIT, params=actor)
    assert first.status_code == 200, first.text
    assert len(first.json()["data"]) == 2
    cursor = first.json()["meta"]["next_cursor"]
    assert cursor

    second = await admin_client.get(AUDIT, params={**actor, "cursor": cursor})
    assert len(second.json()["data"]) == 1
    assert second.json()["meta"]["next_cursor"] is None

    ids = [row["id"] for row in first.json()["data"]] + [row["id"] for row in second.json()["data"]]
    assert ids == sorted(ids, reverse=True)

    invalid = await admin_client.get(AUDIT, params={**actor, "cursor": "not-a-cursor"})
    assert invalid.status_code == 422
    assert invalid.json()["error"]["code"] == "validation_error"


async def test_the_window_and_entity_filters_narrow_the_log(admin_client, session, frozen_now):
    old = AuditLog(
        admin_user_id=admin_client.admin.id,
        entity="match",
        entity_id=7001,
        action="update",
        diff={"stadium": [None, "استاد"]},
        created_at=frozen_now - timedelta(days=3),
    )
    recent = AuditLog(
        admin_user_id=admin_client.admin.id,
        entity="match",
        entity_id=7002,
        action="update",
        diff={"stadium": [None, "استاد آخر"]},
        created_at=frozen_now - timedelta(hours=1),
    )
    session.add_all([old, recent])
    await session.flush()

    window = await admin_client.get(
        AUDIT,
        params={
            "entity": "match",
            "from": (frozen_now - timedelta(days=1)).isoformat(),
            "to": frozen_now.isoformat(),
        },
    )
    assert [row["entity_id"] for row in window.json()["data"]] == [7002]

    both = await admin_client.get(AUDIT, params={"entity": "match", "entity_id": 7001})
    assert [row["id"] for row in both.json()["data"]] == [old.id]


async def test_the_etag_is_a_bucket_over_the_content_datasets(admin_client, session):
    first = await admin_client.get(AUDIT)
    second = await admin_client.get(AUDIT)
    assert first.headers["etag"] == second.headers["etag"]

    await session.execute(
        update(DatasetVersion).where(DatasetVersion.name == "teams").values(version=DatasetVersion.version + 1)
    )
    moved = await admin_client.get(AUDIT)
    assert moved.headers["etag"] != first.headers["etag"]


async def test_the_log_is_read_only(admin_client):
    created = await admin_client.post(AUDIT, json={})
    assert created.status_code == 405
    assert created.json()["error"]["code"] == "method_not_allowed"


async def test_an_editor_gets_403(editor_client):
    assert (await editor_client.get(AUDIT)).status_code == 403


async def test_a_missing_entry_is_404(admin_client):
    response = await admin_client.get(f"{AUDIT}/999999")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "audit_not_found"


async def test_the_page_size_is_capped_at_a_hundred(admin_client):
    assert (await admin_client.get(AUDIT, params={"limit": 100})).status_code == 200
    assert (await admin_client.get(AUDIT, params={"limit": 101})).status_code == 422
