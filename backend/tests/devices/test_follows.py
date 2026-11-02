"""``PUT /v1/devices/me/follows``: replaced whole, atomic, capped (research R5, T018)."""

from __future__ import annotations

import asyncio
from uuid import uuid4

from sqlalchemy import func, select

from app.db.models import DeviceFollow


async def test_a_follow_set_is_stored_exactly_and_returned(device_client, make_match, frozen_now):
    bag = await make_match(frozen_now)
    body = {
        "teams": [bag.home.id],
        "competitions": [bag.competition.id],
        "matches": [bag.match.id],
        "channels": [],
        "commentators": [],
    }

    response = await device_client.put("/v1/devices/me/follows", json=body)

    assert response.status_code == 200, response.text
    assert response.json()["data"] == body


async def test_a_second_put_replaces_the_set(device_client, make_match, frozen_now):
    bag = await make_match(frozen_now)
    first = await device_client.put("/v1/devices/me/follows", json={"teams": [bag.home.id]})
    assert first.status_code == 200

    second = await device_client.put("/v1/devices/me/follows", json={"competitions": [bag.competition.id]})

    assert second.json()["data"]["teams"] == []
    assert second.json()["data"]["competitions"] == [bag.competition.id]


async def test_unknown_ids_are_listed_by_kind_and_nothing_changes(device_client, session, make_match, frozen_now):
    bag = await make_match(frozen_now)
    await device_client.put("/v1/devices/me/follows", json={"teams": [bag.home.id]})
    device_id = device_client.device_id

    response = await device_client.put(
        "/v1/devices/me/follows",
        json={"teams": [bag.home.id, 999999], "competitions": [888888], "matches": []},
    )

    assert response.status_code == 422
    payload = response.json()
    assert payload["error"]["code"] == "unknown_follow_target"
    assert payload["meta"]["unknown"] == {"teams": [999999], "competitions": [888888]}
    stored = await session.scalar(select(func.count(DeviceFollow.device_id)).where(DeviceFollow.device_id == device_id))
    assert stored == 1  # the old set is untouched


async def test_more_than_500_ids_is_refused(device_client, make_match, frozen_now):
    await make_match(frozen_now)
    response = await device_client.put(
        "/v1/devices/me/follows",
        json={"teams": list(range(10**6, 10**6 + 501))},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "too_many_follows"
    assert response.json()["meta"]["max"] == 500


async def test_duplicates_are_collapsed(device_client, make_match, frozen_now):
    bag = await make_match(frozen_now)
    response = await device_client.put(
        "/v1/devices/me/follows", json={"teams": [bag.home.id, bag.home.id, bag.away.id]}
    )

    assert response.status_code == 200, response.text
    assert response.json()["data"]["teams"] == [bag.home.id, bag.away.id]


async def test_two_concurrent_puts_end_with_one_of_the_two_sets(_prepare_database):
    """Two real connections: the device row lock serialises them, so the result is never a mix."""
    from httpx import ASGITransport, AsyncClient

    from app.db.models import Competition, Device, Team
    from app.db.session import SyncSession
    from app.devices.tokens import new_token, token_hash
    from app.public import app

    token = new_token()
    with SyncSession() as setup:
        device = Device(
            install_id=uuid4(),
            token_hash=token_hash(token),
            platform="android",
            prefs={},
            satellite_ids=[],
        )
        team_a = Team(name=f"team-a-{uuid4().hex[:6]}")
        team_b = Team(name=f"team-b-{uuid4().hex[:6]}")
        competition_a = Competition(name=f"comp-a-{uuid4().hex[:6]}")
        competition_b = Competition(name=f"comp-b-{uuid4().hex[:6]}")
        setup.add_all([device, team_a, team_b, competition_a, competition_b])
        setup.commit()
        ids = {
            "device": device.id,
            "teams": [team_a.id, team_b.id],
            "competitions": [competition_a.id, competition_b.id],
        }

    try:
        transport = ASGITransport(app=app, client=("127.0.0.1", 50000))
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            headers = {"Authorization": f"Device {token}"}
            first, second = await asyncio.gather(
                client.put("/v1/devices/me/follows", json={"teams": [ids["teams"][0]]}, headers=headers),
                client.put("/v1/devices/me/follows", json={"competitions": [ids["competitions"][1]]}, headers=headers),
            )
        assert {first.status_code, second.status_code} == {200}

        with SyncSession() as after:
            rows = after.execute(
                select(DeviceFollow.team_id, DeviceFollow.competition_id).where(DeviceFollow.device_id == ids["device"])
            ).all()
        assert len(rows) == 1
        assert rows[0] in {(ids["teams"][0], None), (None, ids["competitions"][1])}
    finally:
        from sqlalchemy import delete

        with SyncSession() as cleanup:
            cleanup.execute(delete(Device).where(Device.id == ids["device"]))
            cleanup.execute(delete(Team).where(Team.id.in_(ids["teams"])))
            cleanup.execute(delete(Competition).where(Competition.id.in_(ids["competitions"])))
            cleanup.commit()
