"""The notifications log, reach, composer, cancel, test send and test device (T006, admin-api)."""

from __future__ import annotations

import uuid
from datetime import timedelta

from sqlalchemy import select

from app.db.models import AdminUser, DatasetVersion, Device, DeviceFollow, NotificationOutbox
from tests.admin.helpers import ADMIN, audit_rows, if_match

LOG = f"{ADMIN}/notifications"
ANNOUNCEMENT = f"{LOG}/announcements"
TEST_DEVICE = f"{LOG}/test-device"


async def _device(session, *, token: str | None = None, prefs: dict | None = None, platform: str = "android") -> Device:
    from hashlib import sha256

    install_id = uuid.uuid4()
    device = Device(
        install_id=install_id,
        token_hash=sha256(install_id.hex.encode()).hexdigest(),
        platform=platform,
        push_token=token,
        prefs=prefs or {},
        satellite_ids=[],
    )
    session.add(device)
    await session.flush()
    return device


def _announcement(**overrides) -> dict:
    body = {
        "title": "مباراة الليلة",
        "body": "الأهلي × الزمالك في الثامنة",
        "target": {"type": "none", "id": None},
        "audience": {"kind": "all", "id": None},
        "send_at": None,
    }
    body.update(overrides)
    return body


async def _outbox(session, key_prefix: str) -> list[NotificationOutbox]:
    rows = await session.scalars(
        select(NotificationOutbox)
        .where(NotificationOutbox.dedupe_key.like(f"{key_prefix}%"))
        .execution_options(populate_existing=True)
    )
    return list(rows.all())


# --- The log --------------------------------------------------------------------------------------


async def test_the_log_is_newest_first_with_a_cursor_and_an_etag(admin_client, session, frozen_now):
    for index in range(3):
        session.add(
            NotificationOutbox(
                type="goal",
                dedupe_key=f"goal:1:{index}:home:{index}",
                payload={"match_id": 1, "side": "home", "home": index, "away": 0, "generation": index},
                audience={"kind": "match_core", "match_id": 1},
                due_at=frozen_now,
                status="sent",
                sent=index,
                failed=2,
            )
        )
    await session.flush()

    first = await admin_client.get(LOG)
    assert first.status_code == 200
    assert first.headers["etag"]
    body = first.json()["data"]
    assert [row["sent"] for row in body] == [2, 1, 0]
    assert body[0]["recipients"] == 4
    assert body[0]["target"]["kind"] == "match_core"

    not_modified = await admin_client.get(LOG, headers={"If-None-Match": first.headers["etag"]})
    assert not_modified.status_code == 304

    page = await admin_client.get(LOG, params={"limit": 2})
    cursor = page.json()["meta"]["next_cursor"]
    assert cursor
    rest = await admin_client.get(LOG, params={"limit": 2, "cursor": cursor})
    assert [row["sent"] for row in rest.json()["data"]] == [0]


async def test_the_log_filters_and_describes_a_test_and_a_correction(admin_client, session, frozen_now):
    session.add_all(
        [
            NotificationOutbox(
                type="goal",
                dedupe_key="goal_correction:1:2",
                payload={"match_id": 1, "kind": "correction", "home": 2, "away": 1, "generation": 2},
                audience={"kind": "match_core", "match_id": 1},
                due_at=frozen_now,
                status="cancelled",
                error="late",
                sent=3,
                failed=0,
            ),
            NotificationOutbox(
                type="announcement",
                dedupe_key="test:abc",
                payload={"title": "t", "body": "b", "route": "/"},
                audience={"kind": "device", "device_id": 9},
                due_at=frozen_now,
                status="sent",
                sent=1,
                failed=0,
            ),
        ]
    )
    await session.flush()

    only_goals = (await admin_client.get(LOG, params={"type": "goal"})).json()["data"]
    assert len(only_goals) == 1
    assert only_goals[0]["is_correction"] is True
    assert only_goals[0]["error"] == "late"


async def test_a_test_row_is_marked_and_the_audience_all_has_no_label(admin_client, session, frozen_now):
    session.add_all(
        [
            NotificationOutbox(
                type="announcement",
                dedupe_key="test:xyz",
                payload={"title": "t", "body": "b", "route": "/"},
                audience={"kind": "device", "device_id": 9},
                due_at=frozen_now,
                status="sent",
                sent=1,
                failed=0,
            ),
            NotificationOutbox(
                type="announcement",
                dedupe_key="announcement:xyz",
                payload={"title": "t", "body": "b", "route": "/"},
                audience={"kind": "all"},
                due_at=frozen_now,
                status="sent",
                sent=5,
                failed=0,
            ),
        ]
    )
    await session.flush()

    rows = (await admin_client.get(LOG)).json()["data"]
    by_test = {row["is_test"]: row for row in rows}
    assert by_test[True]["target"]["kind"] == "device"
    assert by_test[False]["target"]["label"] is None


async def test_a_pending_row_shows_its_live_reach(admin_client, session, frozen_now, make_match):
    bag = await make_match(frozen_now)
    follower = await _device(session, token="follower")
    await _device(session, token="stranger")
    session.add(DeviceFollow(device_id=follower.id, match_id=bag.match.id))
    await session.flush()
    session.add(
        NotificationOutbox(
            type="announcement",
            dedupe_key="announcement:pending",
            payload={"title": "t", "body": "b", "route": "/match/1"},
            audience={"kind": "match_core", "match_id": bag.match.id},
            due_at=frozen_now,
            status="pending",
        )
    )
    await session.flush()

    [row] = (await admin_client.get(LOG)).json()["data"]
    assert row["recipients"] == 1


# --- Reach ------------------------------------------------------------------------------------------


async def test_reach_counts_each_kind(admin_client, session, frozen_now, make_match):
    bag = await make_match(frozen_now)
    by_match, by_team, by_competition, _ = (
        await _device(session, token="m"),
        await _device(session, token="t"),
        await _device(session, token="c"),
        await _device(session, token="none"),
    )
    session.add_all(
        [
            DeviceFollow(device_id=by_match.id, match_id=bag.match.id),
            DeviceFollow(device_id=by_team.id, team_id=bag.home.id),
            DeviceFollow(device_id=by_competition.id, competition_id=bag.competition.id),
        ]
    )
    await session.flush()

    async def devices(params):
        resp = await admin_client.get(f"{LOG}/reach", params=params)
        assert resp.status_code == 200, resp.text
        return resp.json()["data"]["devices"]

    assert await devices({"kind": "all"}) == 4
    assert await devices({"kind": "match", "id": bag.match.id}) == 1
    assert await devices({"kind": "team", "id": bag.home.id}) == 1
    assert await devices({"kind": "competition", "id": bag.competition.id}) == 1


async def test_reach_honours_the_type_switch_and_the_master_switch(admin_client, session):
    await _device(session, token="on")
    await _device(session, token="off", prefs={"enabled": False})
    await _device(session, token="type-off", prefs={"types": {"announcement": {"on": False}}})
    await session.flush()

    resp = await admin_client.get(f"{LOG}/reach", params={"kind": "all"})
    assert resp.json()["data"]["devices"] == 1


# --- The composer -----------------------------------------------------------------------------------


async def test_an_announcement_queues_a_row_with_a_built_route(admin_client, session, frozen_now, make_match):
    bag = await make_match(frozen_now)

    resp = await admin_client.post(
        ANNOUNCEMENT,
        json=_announcement(
            target={"type": "match", "id": bag.match.id}, audience={"kind": "match", "id": bag.match.id}
        ),
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()["data"]
    assert data["type"] == "announcement"
    assert data["status"] == "pending"
    assert data["target"]["kind"] == "match_core"
    assert data["target"]["label"] == f"{bag.home.name} × {bag.away.name}"
    assert data["is_test"] is False

    [row] = await _outbox(session, "announcement:")
    assert row.payload["route"] == f"/match/{bag.match.id}"
    assert row.audience == {"kind": "match_core", "match_id": bag.match.id}
    assert row.audit_log_id is not None
    [audit] = await audit_rows(session, "notification_outbox", row.id)
    assert audit.id == row.audit_log_id


async def test_the_composer_refuses_bad_text_a_past_time_and_a_free_route(admin_client, session, frozen_now):
    too_long_title = await admin_client.post(ANNOUNCEMENT, json=_announcement(title="x" * 66))
    assert too_long_title.status_code == 422

    too_long_body = await admin_client.post(ANNOUNCEMENT, json=_announcement(body="x" * 181))
    assert too_long_body.status_code == 422

    label = await admin_client.post(ANNOUNCEMENT, json=_announcement(title="بث VIP"))
    assert label.status_code == 422
    assert label.json()["error"]["code"] == "text_not_allowed"

    past = await admin_client.post(ANNOUNCEMENT, json=_announcement(send_at="2026-01-01T00:00:00Z"))
    assert past.status_code == 422
    assert past.json()["error"]["code"] == "send_at_in_past"

    free_route = await admin_client.post(
        ANNOUNCEMENT, json={**_announcement(), "route": "https://example.com/anything"}
    )
    assert free_route.status_code == 422


async def test_an_unknown_target_or_audience_is_404(admin_client, session):
    missing_target = await admin_client.post(ANNOUNCEMENT, json=_announcement(target={"type": "match", "id": 999999}))
    assert missing_target.status_code == 404
    assert missing_target.json()["error"]["code"] == "match_not_found"

    missing_audience = await admin_client.post(
        ANNOUNCEMENT, json=_announcement(audience={"kind": "competition", "id": 999999})
    )
    assert missing_audience.status_code == 404
    assert missing_audience.json()["error"]["code"] == "competition_not_found"


async def test_a_scheduled_announcement_keeps_its_send_at(admin_client, session, frozen_now):
    later = frozen_now + timedelta(hours=2)
    resp = await admin_client.post(ANNOUNCEMENT, json=_announcement(send_at=later.isoformat()))
    assert resp.status_code == 201, resp.text
    [row] = await _outbox(session, "announcement:")
    assert row.due_at == later


async def test_an_editor_may_read_the_log_and_nothing_else(editor_client, session, frozen_now):
    assert (await editor_client.get(LOG)).status_code == 200
    assert (await editor_client.get(f"{LOG}/reach", params={"kind": "all"})).status_code == 403
    assert (await editor_client.post(ANNOUNCEMENT, json=_announcement())).status_code == 403
    assert (await editor_client.get(TEST_DEVICE)).status_code == 403


# --- Cancel -----------------------------------------------------------------------------------------


async def test_cancel_needs_if_match(admin_client, session, frozen_now):
    resp = await admin_client.post(ANNOUNCEMENT, json=_announcement())
    assert resp.status_code == 201, resp.text
    notification_id = resp.json()["data"]["id"]

    without = await admin_client.post(f"{LOG}/{notification_id}/cancel")
    assert without.status_code == 428


async def test_cancel_sets_cancelled_and_admin(admin_client, session, frozen_now):
    resp = await admin_client.post(ANNOUNCEMENT, json=_announcement())
    notification_id = resp.json()["data"]["id"]
    [row] = await _outbox(session, "announcement:")
    from app.services.admin.notifications import row_version

    cancelled = await admin_client.post(f"{LOG}/{notification_id}/cancel", headers=if_match(row_version(row)))
    assert cancelled.status_code == 200, cancelled.text
    assert cancelled.json()["data"]["status"] == "cancelled"
    assert cancelled.json()["data"]["error"] == "admin"

    again = await admin_client.post(f"{LOG}/{notification_id}/cancel", headers=if_match(cancelled.headers["etag"]))
    assert again.status_code == 409
    assert again.json()["error"]["code"] == "notification_not_cancellable"


async def test_cancel_takes_the_version_from_the_log_row(admin_client, session, frozen_now):
    """B1-R1-2: A15 only has the log, so each row's ``etag`` must be the version cancel compares."""
    created = await admin_client.post(ANNOUNCEMENT, json=_announcement())
    assert created.status_code == 201, created.text
    notification_id = created.json()["data"]["id"]

    log = await admin_client.get(LOG)
    assert log.status_code == 200, log.text
    row = next(item for item in log.json()["data"] if item["id"] == notification_id)
    assert row["etag"] != log.headers["etag"]
    assert created.json()["data"]["etag"] == row["etag"]

    refused = await admin_client.post(f"{LOG}/{notification_id}/cancel", headers=if_match(log.headers["etag"]))
    assert refused.status_code == 409
    assert refused.json()["error"]["code"] == "edit_conflict"

    cancelled = await admin_client.post(f"{LOG}/{notification_id}/cancel", headers=if_match(row["etag"]))
    assert cancelled.status_code == 200, cancelled.text
    assert cancelled.json()["data"]["status"] == "cancelled"
    assert cancelled.json()["data"]["etag"] == cancelled.headers["etag"]


async def test_cancel_refuses_a_sent_row(admin_client, session, frozen_now):
    session.add(
        NotificationOutbox(
            type="announcement",
            dedupe_key="announcement:sent",
            payload={"title": "t", "body": "b", "route": "/"},
            audience={"kind": "all"},
            due_at=frozen_now,
            status="sent",
            sent=1,
        )
    )
    await session.flush()
    [row] = await _outbox(session, "announcement:")
    from app.services.admin.notifications import row_version

    resp = await admin_client.post(f"{LOG}/{row.id}/cancel", headers=if_match(row_version(row)))
    assert resp.status_code == 409
    assert resp.json()["error"]["code"] == "notification_not_cancellable"


# --- Test send and the test device ------------------------------------------------------------------


def _test_body() -> dict:
    return {
        "title": "تجربة",
        "body": "رسالة تجربة",
        "target": {"type": "none", "id": None},
    }


async def test_a_test_send_needs_a_saved_device(admin_client):
    resp = await admin_client.post(f"{LOG}/test", json=_test_body())
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "test_device_not_set"


async def test_a_test_send_needs_a_token_on_that_device(admin_client, session):
    account = await session.get(AdminUser, admin_client.admin.id)
    assert account is not None
    device = await _device(session, token=None)
    account.test_device_id = device.id
    await session.flush()

    resp = await admin_client.post(f"{LOG}/test", json=_test_body())
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "test_device_no_token"


async def test_a_test_send_goes_to_the_device_with_prefs_ignored(admin_client, session, frozen_now):
    account = await session.get(AdminUser, admin_client.admin.id)
    assert account is not None
    device = await _device(session, token="mine", prefs={"enabled": False})
    account.test_device_id = device.id
    await session.flush()

    resp = await admin_client.post(f"{LOG}/test", json=_test_body())
    assert resp.status_code == 201, resp.text
    assert resp.json()["data"]["is_test"] is True
    [row] = await _outbox(session, "test:")
    assert row.audience == {"kind": "device", "device_id": device.id}


async def test_the_test_device_is_read_set_and_versioned(admin_client, session, frozen_now):
    account = await session.get(AdminUser, admin_client.admin.id)
    assert account is not None
    first = await admin_client.get(TEST_DEVICE)
    assert first.status_code == 200
    assert first.json()["data"] is None
    tag = first.headers["etag"]

    device = await _device(session, token="mine")
    put = await admin_client.put(TEST_DEVICE, json={"device_id": device.id}, headers=if_match(tag))
    assert put.status_code == 200, put.text
    assert put.json()["data"]["device_id"] == device.id
    assert put.json()["data"]["has_push_token"] is True

    # A login does not make the saved device stale: the version hashes only test_device_id.
    account.last_login_at = frozen_now
    await session.flush()
    again = await admin_client.put(TEST_DEVICE, json={"device_id": device.id}, headers=if_match(put.headers["etag"]))
    assert again.status_code == 200, again.text

    stale = await admin_client.put(TEST_DEVICE, json={"device_id": device.id}, headers=if_match(tag))
    assert stale.status_code == 409
    assert stale.json()["error"]["code"] == "edit_conflict"


async def test_the_test_device_put_requires_if_match_and_a_real_device(admin_client, session):
    without = await admin_client.put(TEST_DEVICE, json={"device_id": 1})
    assert without.status_code == 428

    tag = (await admin_client.get(TEST_DEVICE)).headers["etag"]
    missing = await admin_client.put(TEST_DEVICE, json={"device_id": 999999}, headers=if_match(tag))
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "device_not_found"


async def test_the_test_device_write_is_audited_and_bumps_the_dataset(admin_client, session):
    device = await _device(session, token="mine")
    tag = (await admin_client.get(TEST_DEVICE)).headers["etag"]
    before = await session.scalar(select(DatasetVersion.version).where(DatasetVersion.name == "admin_users"))

    resp = await admin_client.put(TEST_DEVICE, json={"device_id": device.id}, headers=if_match(tag))
    assert resp.status_code == 200

    [audit] = await audit_rows(session, "admin_users", admin_client.admin.id)
    assert list(audit.diff) == ["test_device_id"]
    after = await session.scalar(select(DatasetVersion.version).where(DatasetVersion.name == "admin_users"))
    assert after == before + 1
