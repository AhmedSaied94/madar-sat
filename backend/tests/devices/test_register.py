"""``POST /v1/devices``: 201, rotation and validation (research R1, T015)."""

from __future__ import annotations

from uuid import uuid4

from sqlalchemy import func, select

from app.db.models import Device, DeviceFollow
from app.devices.tokens import token_hash


async def test_register_returns_201_with_a_43_character_base64url_token(public_client):
    response = await public_client.post("/v1/devices", json={"install_id": str(uuid4()), "platform": "android"})

    assert response.status_code == 201, response.text
    data = response.json()["data"]
    assert data["device_id"] > 0
    token = data["device_token"]
    assert len(token) == 43
    assert all(char.isalnum() or char in "-_" for char in token)


async def test_only_the_sha256_of_the_token_is_stored_and_it_is_never_logged(public_client, session, caplog):
    response = await public_client.post("/v1/devices", json={"install_id": str(uuid4()), "platform": "web"})
    token = response.json()["data"]["device_token"]

    stored = (await session.execute(select(Device.token_hash))).scalars().all()
    assert token_hash(token) in stored
    assert token not in {row for row in stored}
    assert all(row != token for row in stored)
    assert token not in caplog.text


async def test_the_same_install_id_keeps_the_device_and_its_follows_and_rotates_the_token(
    public_client, device_client, session, make_match, frozen_now
):
    bag = await make_match(frozen_now)
    first_id = device_client.device_id
    first_token = device_client.device_token
    put = await device_client.put("/v1/devices/me/follows", json={"teams": [bag.home.id]})
    assert put.status_code == 200, put.text

    install_id = await session.scalar(select(Device.install_id).where(Device.id == first_id))
    again = await public_client.post("/v1/devices", json={"install_id": str(install_id), "platform": "android"})

    assert again.status_code == 201, again.text
    data = again.json()["data"]
    assert data["device_id"] == first_id
    assert data["device_token"] != first_token

    old = await public_client.put(
        "/v1/devices/me", json={"app_version": "0.4.0"}, headers={"Authorization": f"Device {first_token}"}
    )
    assert old.status_code == 401
    assert old.json()["error"]["code"] == "unauthenticated"

    follows = await session.scalar(select(func.count(DeviceFollow.device_id)).where(DeviceFollow.device_id == first_id))
    assert follows == 1


async def test_a_bad_platform_or_install_id_is_a_422(public_client):
    bad_platform = await public_client.post("/v1/devices", json={"install_id": str(uuid4()), "platform": "desktop"})
    bad_install = await public_client.post("/v1/devices", json={"install_id": "not-a-uuid", "platform": "android"})

    assert bad_platform.status_code == 422
    assert bad_platform.json()["error"]["code"] == "validation_error"
    assert bad_install.status_code == 422
