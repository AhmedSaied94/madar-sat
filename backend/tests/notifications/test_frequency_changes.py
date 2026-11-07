"""Frequency changes: the diff, the five-minute hold, the history row (T026, research R6)."""

from __future__ import annotations

from datetime import timedelta
from typing import Any
from uuid import uuid4

from sqlalchemy import select

from app.db.models import (
    Channel,
    ChannelFrequencyChange,
    DatasetVersion,
    Device,
    DeviceFollow,
    NotificationOutbox,
    Satellite,
)
from app.notifications.dispatcher import dispatch_due
from app.notifications.producers import frequency_diff
from app.services.admin import versions
from tests.admin.helpers import ADMIN, create, if_match
from tests.support import FakePushSender

CHANNELS = f"{ADMIN}/channels"


def _tuning(mhz: int = 11766, pol: str = "H", sr: int = 27500) -> dict[str, Any]:
    return {"frequency_mhz": mhz, "polarization": pol, "symbol_rate": sr}


def test_the_diff_needs_two_complete_tunings_that_differ():
    assert frequency_diff(_tuning(), _tuning(11843)) == (
        {"mhz": 11766, "pol": "H", "sr": 27500},
        {"mhz": 11843, "pol": "H", "sr": 27500},
    )
    assert frequency_diff(_tuning(), _tuning()) is None
    assert frequency_diff(_tuning(), {**_tuning(), "frequency_mhz": None}) is None
    assert frequency_diff({"frequency_note": "UHF 32"}, {"frequency_note": "UHF 40"}) is None
    # A satellite move with the same tuning is not a change.
    assert frequency_diff({**_tuning(), "satellite_id": 1}, {**_tuning(), "satellite_id": 2}) is None
    # A move with new tuning is.
    assert frequency_diff({**_tuning(), "satellite_id": 1}, {**_tuning(11843), "satellite_id": 2}) is not None


def _satellite(session) -> int:
    satellite = Satellite(
        slug=f"sat-{uuid4().hex[:10]}",
        name_en=f"Satellite {uuid4().hex[:6]}",
        name_ar="نايل سات",
        kind="satellite",
        orbital_position=-7.0,
    )
    session.add(satellite)
    return satellite


def _channel_row(session, *, mhz: int = 11766) -> Channel:
    satellite = _satellite(session)
    session.flush()
    channel = Channel(
        kind="satellite",
        name=f"قناة {uuid4().hex[:6]}",
        satellite_id=satellite.id,
        access="free",
        frequency_mhz=mhz,
        polarization="H",
        symbol_rate=27500,
        locked_fields=[],
    )
    session.add(channel)
    session.flush()
    return channel


def _row(session, channel: Channel, now, *, old: dict[str, Any] | None = None) -> NotificationOutbox:
    outbox = NotificationOutbox(
        type="frequency_changed",
        dedupe_key=f"frequency_changed:{channel.id}:{uuid4().hex}",
        payload={"channel_id": channel.id, "old": old or {"mhz": 11766, "pol": "H", "sr": 27500}},
        audience={"kind": "channel", "channel_id": channel.id},
        due_at=now,
        status="pending",
        audit_log_id=None,
    )
    session.add(outbox)
    session.flush()
    return outbox


def _follower(session, channel: Channel) -> Device:
    device = Device(
        install_id=uuid4(),
        token_hash=uuid4().hex,
        platform="android",
        push_token=f"push-{uuid4().hex[:8]}",
        prefs={},
        satellite_ids=[],
    )
    session.add(device)
    session.flush()
    session.add(DeviceFollow(device_id=device.id, channel_id=channel.id))
    session.flush()
    return device


async def test_a_changed_frequency_queues_one_pending_row_keyed_on_the_save(editor_client, session, frozen_now):
    satellite = _satellite(session)
    await session.flush()
    channel = await create(
        editor_client,
        CHANNELS,
        {
            "kind": "satellite",
            "name": f"قناة {uuid4().hex[:6]}",
            "satellite_id": satellite.id,
            "access": "free",
            "frequency": {"mhz": 11766, "pol": "H", "sr": 27500},
        },
    )
    assert list(await session.scalars(select(NotificationOutbox))) == []

    resp = await editor_client.patch(
        f"{CHANNELS}/{channel['id']}",
        json={"frequency": {"mhz": 11843, "pol": "H", "sr": 27500}},
        headers=if_match(channel["_etag"]),
    )
    assert resp.status_code == 200, resp.text

    [row] = list(await session.scalars(select(NotificationOutbox)))
    assert row.type == "frequency_changed"
    assert row.audience == {"kind": "channel", "channel_id": channel["id"]}
    assert row.payload["old"] == {"mhz": 11766, "pol": "H", "sr": 27500}
    assert row.audit_log_id is not None
    assert row.dedupe_key.endswith(f":{row.audit_log_id}")
    assert row.due_at == frozen_now + timedelta(minutes=5)


async def test_a_save_that_changes_nothing_and_a_created_frequency_queue_nothing(editor_client, session):
    satellite = _satellite(session)
    await session.flush()
    payload = {
        "kind": "satellite",
        "name": f"قناة {uuid4().hex[:6]}",
        "satellite_id": satellite.id,
        "access": "free",
        "frequency": {"mhz": 11766, "pol": "H", "sr": 27500},
    }
    channel = await create(editor_client, CHANNELS, payload)
    assert list(await session.scalars(select(NotificationOutbox))) == []

    resp = await editor_client.patch(
        f"{CHANNELS}/{channel['id']}", json={"sort_order": 3}, headers=if_match(channel["_etag"])
    )
    assert resp.status_code == 200
    assert list(await session.scalars(select(NotificationOutbox))) == []


def test_a_hold_that_ends_writes_the_history_and_sends(sync_session, frozen_now):
    channel = _channel_row(sync_session)
    device = _follower(sync_session, channel)
    row = _row(sync_session, channel, frozen_now)
    channel.frequency_mhz = 11843  # the hold ends with the new value still set
    sync_session.flush()
    sender = FakePushSender()

    report = dispatch_due(sync_session, sender, frozen_now)

    assert report.sent == 1
    assert sender.tokens_sent == [device.push_token]
    [history] = list(sync_session.scalars(select(ChannelFrequencyChange)))
    assert (history.old_frequency_mhz, history.new_frequency_mhz) == (11766, channel.frequency_mhz)
    assert history.outbox_id == row.id
    sync_session.refresh(channel)
    assert channel.frequency_changed_at == frozen_now


def test_a_typo_fixed_inside_the_hold_sends_nothing_and_leaves_no_history(sync_session, frozen_now):
    channel = _channel_row(sync_session, mhz=11766)
    _follower(sync_session, channel)
    _row(sync_session, channel, frozen_now, old={"mhz": 11766, "pol": "H", "sr": 27500})
    channel.frequency_mhz = 11766  # set back before the hold ends
    sync_session.flush()

    report = dispatch_due(sync_session, FakePushSender(), frozen_now)

    assert report.cancelled == 1
    [row] = list(sync_session.scalars(select(NotificationOutbox)))
    assert row.status == "cancelled"
    assert row.error == "no_net_change"
    assert list(sync_session.scalars(select(ChannelFrequencyChange))) == []
    sync_session.refresh(channel)
    assert channel.frequency_changed_at is None


def test_a_later_change_pushes_again_after_a_cancel(sync_session, frozen_now):
    channel = _channel_row(sync_session)
    _follower(sync_session, channel)
    cancelled = _row(sync_session, channel, frozen_now)
    cancelled.status = "cancelled"
    cancelled.error = "no_net_change"
    channel.frequency_mhz = 11843
    sync_session.flush()
    _row(sync_session, channel, frozen_now)

    report = dispatch_due(sync_session, FakePushSender(), frozen_now)

    assert report.sent == 1
    assert len(list(sync_session.scalars(select(ChannelFrequencyChange)))) == 1


def test_the_hold_ending_does_not_change_the_channels_version(sync_session, frozen_now):
    """``frequency_changed_at`` joins ``NOT_HASHED``, so an open A8 isn't stale for the dispatcher's work."""
    channel = _channel_row(sync_session)
    before = versions.row_version(channel)

    channel.frequency_changed_at = frozen_now
    sync_session.flush()

    assert versions.row_version(channel) == before


def test_the_history_row_is_written_once_even_if_the_row_is_seen_twice(sync_session, frozen_now):
    channel = _channel_row(sync_session)
    _follower(sync_session, channel)
    row = _row(sync_session, channel, frozen_now)

    dispatch_due(sync_session, FakePushSender(), frozen_now)
    # A re-delivered claim cannot write a second history row: the unique outbox id holds.
    from sqlalchemy.dialects.postgresql import insert

    sync_session.execute(
        insert(ChannelFrequencyChange)
        .values(
            channel_id=channel.id,
            old_frequency_mhz=11766,
            new_frequency_mhz=11843,
            old_polarization="H",
            new_polarization="H",
            old_symbol_rate=27500,
            new_symbol_rate=27500,
            source="admin",
            outbox_id=row.id,
            detected_at=frozen_now,
        )
        .on_conflict_do_nothing(index_elements=["outbox_id"])
    )

    assert len(list(sync_session.scalars(select(ChannelFrequencyChange)))) == 1


def test_the_off_switch_still_writes_the_history(sync_session, frozen_now, monkeypatch):
    channel = _channel_row(sync_session)
    _follower(sync_session, channel)
    _row(sync_session, channel, frozen_now)
    channel.frequency_mhz = 11843
    sync_session.flush()

    from app.settings import get_settings

    settings = get_settings()
    monkeypatch.setattr(settings, "push_types_off", "frequency_changed", raising=False)

    report = dispatch_due(sync_session, FakePushSender(), frozen_now)

    assert report.cancelled == 1
    [row] = list(sync_session.scalars(select(NotificationOutbox)))
    assert row.error == "type_off"
    assert len(list(sync_session.scalars(select(ChannelFrequencyChange)))) == 1


def test_an_importers_frequency_never_reaches_the_producer(sync_session, frozen_now):
    """Only ``channels.update`` calls the producer: the snapshot loader and importers don't (R6)."""
    _channel_row(sync_session)
    sync_session.flush()

    assert list(sync_session.scalars(select(NotificationOutbox))) == []
    assert list(sync_session.scalars(select(DatasetVersion).where(DatasetVersion.name == "channels")))


def test_the_kick_only_queues_when_something_is_due(sync_session, frozen_now, monkeypatch):
    from app.notifications import kick

    queued: list[str] = []
    monkeypatch.setattr(kick, "_queue", lambda: queued.append("dispatch"))
    assert kick.kick_if_due(sync_session, frozen_now) is False

    channel = _channel_row(sync_session)
    _row(sync_session, channel, frozen_now)

    assert kick.kick_if_due(sync_session, frozen_now) is True
    assert queued == ["dispatch"]


async def test_the_async_kick_only_queues_when_something_is_due(session, frozen_now, monkeypatch):
    from app.notifications import kick

    queued: list[str] = []
    monkeypatch.setattr(kick, "_queue", lambda: queued.append("dispatch"))
    assert await kick.kick_if_due_async(session, frozen_now) is False

    session.add(
        NotificationOutbox(
            type="announcement",
            dedupe_key="announcement:kick",
            payload={"title": "t", "body": "b", "route": "/"},
            audience={"kind": "all"},
            due_at=frozen_now - timedelta(minutes=1),
            status="pending",
        )
    )
    await session.flush()

    assert await kick.kick_if_due_async(session, frozen_now) is True
    assert queued == ["dispatch"]
