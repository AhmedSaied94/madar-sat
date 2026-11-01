"""The device token dependency: one identical 401, own device only, hourly ``last_seen_at`` (T016)."""

from __future__ import annotations

from datetime import timedelta
from uuid import uuid4

from sqlalchemy import select

from app.db.models import Device
from app.devices.tokens import new_token, token_hash


async def test_every_bad_header_answers_the_same_unauthenticated_body(public_client, session):
    device = Device(
        install_id=uuid4(), token_hash=token_hash(new_token()), platform="android", prefs={}, satellite_ids=[]
    )
    session.add(device)
    await session.flush()

    answers = []
    for headers in (
        {},
        {"Authorization": "Bearer something"},
        {"Authorization": "Device"},
        {"Authorization": "Device " + "x" * 43},
        {"Authorization": "Device " + new_token()},
    ):
        response = await public_client.put("/v1/devices/me", json={}, headers=headers)
        assert response.status_code == 401
        answers.append(response.json())

    assert all(answer["error"] == {"code": "unauthenticated", "message": "unauthenticated"} for answer in answers)
    assert all(answer["success"] is False and answer["data"] is None for answer in answers)


async def test_a_valid_token_reaches_only_its_own_device(public_client, session, frozen_now):
    mine = Device(
        install_id=uuid4(),
        token_hash=token_hash(new_token()),
        platform="android",
        prefs={},
        satellite_ids=[],
        last_seen_at=frozen_now,
    )
    other = Device(
        install_id=uuid4(),
        token_hash=token_hash(new_token()),
        platform="android",
        prefs={},
        satellite_ids=[],
        last_seen_at=frozen_now,
    )
    session.add_all([mine, other])
    await session.flush()
    token = "my-device-token"
    mine.token_hash = token_hash(token)
    await session.flush()

    response = await public_client.put(
        "/v1/devices/me", json={"app_version": "0.3.1"}, headers={"Authorization": f"Device {token}"}
    )

    assert response.status_code == 200, response.text
    assert response.json()["data"]["device_id"] == mine.id
    await session.refresh(mine)
    assert mine.app_version == "0.3.1"
    assert other.app_version is None


async def test_last_seen_at_is_touched_at_most_once_an_hour(public_client, session, frozen_now):
    token = new_token()
    device = Device(
        install_id=uuid4(),
        token_hash=token_hash(token),
        platform="android",
        prefs={},
        satellite_ids=[],
        last_seen_at=frozen_now - timedelta(minutes=30),
    )
    session.add(device)
    await session.flush()
    headers = {"Authorization": f"Device {token}"}

    await public_client.put("/v1/devices/me", json={}, headers=headers)
    fresh = await session.scalar(select(Device.last_seen_at).where(Device.id == device.id))
    assert fresh == frozen_now - timedelta(minutes=30)

    device.last_seen_at = frozen_now - timedelta(hours=2)
    await session.flush()
    await public_client.put("/v1/devices/me", json={}, headers=headers)
    touched = await session.scalar(select(Device.last_seen_at).where(Device.id == device.id))
    assert touched == frozen_now
