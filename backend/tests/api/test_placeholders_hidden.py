"""Placeholders are hidden from every public read until an editor shows them (T024)."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import func, select

from app.db.models import AuditLog, Channel, MatchChannel, Satellite
from tests import support


async def _placeholder_match(session, now, *, with_satellite=False):
    bag = await support.create_match(session, now, links=False)
    satellite = None
    if with_satellite:
        satellite = Satellite(
            slug=f"placeholder-sat-{bag.match.id}",
            name_en="Sat",
            name_ar="سات",
            kind="satellite",
            orbital_position=7.0,
        )
        session.add(satellite)
        await session.flush()
    channel = Channel(
        kind="platform",
        name=f"beIN placeholder {bag.match.id}",
        show_in_match=False,
        placeholder_source="livesoccertv",
        locked_fields=[],
    )
    session.add(channel)
    await session.flush()
    session.add(MatchChannel(match_id=bag.match.id, channel_id=channel.id, source="livesoccertv"))
    await session.flush()
    return bag, channel, satellite


def _window(now):
    return {"from": (now - timedelta(hours=1)).isoformat(), "to": (now + timedelta(hours=6)).isoformat()}


async def test_a_placeholder_is_absent_from_every_public_read(public_client, session, frozen_now):
    bag, channel, satellite = await _placeholder_match(session, frozen_now)

    listing = await public_client.get("/v1/matches", params=_window(frozen_now))
    detail = await public_client.get(f"/v1/matches/{bag.match.id}")
    by_channel = await public_client.get(f"/v1/channels/{channel.id}")
    by_satellite = await public_client.get(f"/v1/satellites/{satellite.id}/channels") if satellite else None

    assert listing.status_code == 200
    assert channel.name not in listing.text
    assert detail.status_code == 200
    assert detail.json()["data"]["broadcast"]["channel_count"] == 0
    assert by_channel.status_code == 404
    if by_satellite is not None:
        assert by_satellite.status_code == 200
        assert channel.name not in by_satellite.text


async def test_an_editor_showing_it_makes_it_public_and_clears_the_marker(
    editor_client, public_client, session, frozen_now
):
    bag, channel, _ = await _placeholder_match(session, frozen_now)
    etag = (await editor_client.get(f"/admin/api/channels/{channel.id}")).headers["etag"]

    saved = await editor_client.patch(
        f"/admin/api/channels/{channel.id}",
        json={"show_in_match": True},
        headers={"If-Match": etag},
    )

    assert saved.status_code == 200, saved.text
    assert saved.json()["data"]["placeholder_source"] is None
    await session.refresh(channel)
    assert channel.placeholder_source is None
    audits = await session.scalar(
        select(func.count(AuditLog.id)).where(AuditLog.entity == "channels", AuditLog.entity_id == channel.id)
    )
    assert audits == 1

    detail = await public_client.get(f"/v1/matches/{bag.match.id}")
    assert channel.name in detail.text
    assert (await public_client.get(f"/v1/channels/{channel.id}")).status_code == 200
