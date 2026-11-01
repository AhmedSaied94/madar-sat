"""``PUT /v1/devices/me`` and ``DELETE /v1/devices/me`` (T017)."""

from __future__ import annotations

from sqlalchemy import func, select

from app.db.models import Device, DeviceFollow


async def test_every_field_is_stored(device_client, session, make_match, frozen_now):
    bag = await make_match(frozen_now)
    body = {
        "push_token": "fcm-token-1",
        "app_version": "0.3.0+31",
        "tz": "Africa/Cairo",
        "locale": "ar-EG",
        "satellite_ids": [bag.satellites[0].id],
        "prefs": {"types": {"kickoff_reminder": {"on": True, "lead_min": 30}}},
    }
    response = await device_client.put("/v1/devices/me", json=body)

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["has_push_token"] is True
    assert data["app_version"] == "0.3.0+31"
    assert (data["tz"], data["locale"]) == ("Africa/Cairo", "ar-EG")
    assert data["satellite_ids"] == [bag.satellites[0].id]
    assert data["prefs"]["types"]["kickoff_reminder"] == {"on": True, "lead_min": 30}
    assert "device_token" not in data and "token_hash" not in data


async def test_the_length_rules_and_the_time_zone_are_validated(device_client):
    cases = [
        ({"push_token": "x" * 4097}, None),
        ({"push_token": ""}, None),
        ({"push_token": "   "}, None),
        ({"push_token": "a\x00b"}, None),
        ({"app_version": "x" * 33}, None),
        ({"locale": "x" * 17}, None),
        ({"tz": "Mars/Olympus"}, None),
        ({"satellite_ids": list(range(1, 34))}, None),
        ({"satellite_ids": [999999]}, "unknown_satellite"),
    ]
    for body, code in cases:
        response = await device_client.put("/v1/devices/me", json=body)
        assert response.status_code == 422, (body, response.text)
        assert response.json()["error"]["code"] == (code or "validation_error")


async def test_an_empty_push_token_is_refused_and_leaves_the_stored_one(device_client):
    """An empty token would join every audience and fail the whole page at FCM (B1-R1-1)."""
    first = await device_client.put("/v1/devices/me", json={"push_token": "kept-token"})
    assert first.status_code == 200, first.text

    response = await device_client.put("/v1/devices/me", json={"push_token": ""})

    assert response.status_code == 422
    current = await device_client.put("/v1/devices/me", json={"locale": "ar-EG"})
    assert current.json()["data"]["has_push_token"] is True


async def test_an_unknown_satellite_names_the_ids(device_client):
    response = await device_client.put("/v1/devices/me", json={"satellite_ids": [999999, 888888]})

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "unknown_satellite"
    assert response.json()["meta"]["unknown"] == [999999, 888888]


async def test_an_omitted_field_is_unchanged_and_null_clears(device_client):
    first = await device_client.put(
        "/v1/devices/me", json={"push_token": "token-a", "app_version": "0.3.0", "locale": "ar-EG"}
    )
    assert first.status_code == 200, first.text

    second = await device_client.put("/v1/devices/me", json={"app_version": "0.4.0"})
    data = second.json()["data"]
    assert data["has_push_token"] is True
    assert (data["app_version"], data["locale"]) == ("0.4.0", "ar-EG")

    cleared = await device_client.put("/v1/devices/me", json={"push_token": None, "locale": None})
    data = cleared.json()["data"]
    assert data["has_push_token"] is False
    assert data["locale"] is None
    assert data["app_version"] == "0.4.0"


async def test_a_push_token_moves_to_the_device_that_sends_it(device_client, session, frozen_now):
    from uuid import uuid4

    from app.devices.tokens import new_token, token_hash

    other = Device(
        install_id=uuid4(),
        token_hash=token_hash(new_token()),
        platform="android",
        push_token="shared-token",
        prefs={},
        satellite_ids=[],
        last_seen_at=frozen_now,
    )
    session.add(other)
    await session.flush()

    await device_client.put("/v1/devices/me", json={"push_token": "shared-token"})

    await session.refresh(other)
    me = await session.get(Device, device_client.device_id)
    assert me is not None and me.push_token == "shared-token"
    assert other.push_token is None


async def test_prefs_defaults_are_filled_on_read(device_client):
    response = await device_client.put("/v1/devices/me", json={})

    types = response.json()["data"]["prefs"]["types"]
    assert set(types) == {
        "kickoff_reminder",
        "goal",
        "final_score",
        "match_started",
        "channels_updated",
        "frequency_changed",
        "announcement",
    }
    assert types["kickoff_reminder"] == {"on": True, "lead_min": 15}
    assert types["match_started"] == {"on": False, "lead_min": None}


async def test_an_unknown_pref_type_is_refused(device_client):
    response = await device_client.put("/v1/devices/me", json={"prefs": {"types": {"not_a_type": {"on": True}}}})
    assert response.status_code == 422


async def test_delete_removes_the_device_and_its_follows_and_kills_the_token(
    device_client, session, make_match, frozen_now
):

    bag = await make_match(frozen_now)
    device_id = device_client.device_id
    token = device_client.device_token
    follow = await device_client.put("/v1/devices/me/follows", json={"competitions": [bag.competition.id]})
    assert follow.status_code == 200, follow.text

    response = await device_client.delete("/v1/devices/me")
    assert response.status_code == 204
    assert response.headers["cache-control"] == "no-store"

    assert await session.get(Device, device_id) is None
    assert (
        await session.scalar(select(func.count(DeviceFollow.device_id)).where(DeviceFollow.device_id == device_id)) == 0
    )

    gone = await device_client.put("/v1/devices/me", json={}, headers={"Authorization": f"Device {token}"})
    assert gone.status_code == 401
