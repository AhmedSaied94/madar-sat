"""A8: ``GET channels/{id}/frequency-changes`` — what followers were told (T017)."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import update

from app.db.models import AuditLog, Channel, ChannelFrequencyChange, DatasetVersion
from app.services.admin import writer
from tests.admin.helpers import ADMIN

CHANNELS = f"{ADMIN}/channels"

OLD = (11766, "H", 27500)
NEW = (11843, "H", 27500)


async def channel(session, name: str = "قناة التاريخ") -> Channel:
    row = Channel(kind="platform", name=name, locked_fields=[])
    session.add(row)
    await session.flush()
    return row


def change(
    channel_id: int,
    detected_at,
    *,
    old: tuple[int, str, int] = OLD,
    new: tuple[int, str, int] = NEW,
    source: str = "admin",
    audit_log_id: int | None = None,
) -> ChannelFrequencyChange:
    return ChannelFrequencyChange(
        channel_id=channel_id,
        old_frequency_mhz=old[0],
        old_polarization=old[1],
        old_symbol_rate=old[2],
        new_frequency_mhz=new[0],
        new_polarization=new[1],
        new_symbol_rate=new[2],
        source=source,
        audit_log_id=audit_log_id,
        detected_at=detected_at,
    )


async def test_the_actor_comes_from_the_rows_own_audit_entry(editor_client, session, frozen_now):
    row = await channel(session)
    entry = writer.add_audit(
        session, editor_client.admin, "channels", row.id, "update", {"frequency_mhz": [11766, 11843]}
    )
    await session.flush()
    # The outbox row was pruned (``outbox_id`` is null); the history still names the admin.
    session.add(change(row.id, frozen_now, audit_log_id=entry.id))
    await session.flush()

    response = await editor_client.get(f"{CHANNELS}/{row.id}/frequency-changes")

    assert response.status_code == 200, response.text
    assert response.headers["etag"]
    [item] = response.json()["data"]
    assert item["old"] == "11766 H 27500"
    assert item["new"] == "11843 H 27500"
    assert item["source"] == "admin"
    assert item["actor"] == "محرر"
    assert item["detected_at"].startswith("2026-10-28T18:00:00")


async def test_an_importers_change_stays_null_and_unattributed_changes_too(editor_client, session, frozen_now):
    row = await channel(session)
    importer = AuditLog(source="ysscores", entity="channels", entity_id=row.id, action="update", diff={})
    session.add(importer)
    await session.flush()
    session.add_all(
        [
            change(row.id, frozen_now - timedelta(hours=2), source="ysscores", audit_log_id=importer.id),
            change(row.id, frozen_now - timedelta(hours=1), source="legacy", audit_log_id=None),
        ]
    )
    await session.flush()

    data = (await editor_client.get(f"{CHANNELS}/{row.id}/frequency-changes")).json()["data"]

    assert [(item["source"], item["actor"]) for item in data] == [("legacy", None), ("ysscores", None)]


async def test_the_newest_hundred_are_returned_newest_first(editor_client, session, frozen_now):
    row = await channel(session)
    for index in range(101):
        session.add(
            change(
                row.id,
                frozen_now - timedelta(minutes=index),
                old=(11700 + index, "H", 27500),
                new=(11800 + index, "H", 27500),
            )
        )
    await session.flush()

    data = (await editor_client.get(f"{CHANNELS}/{row.id}/frequency-changes")).json()["data"]

    assert len(data) == 100
    assert data[0]["old"] == "11700 H 27500"
    assert data[-1]["old"] == "11799 H 27500"
    stamps = [item["detected_at"] for item in data]
    assert stamps == sorted(stamps, reverse=True)


async def test_an_unknown_or_deleted_channel_is_404(editor_client, session, frozen_now):
    unknown = await editor_client.get(f"{CHANNELS}/999999/frequency-changes")
    assert unknown.status_code == 404
    assert unknown.json()["error"]["code"] == "channel_not_found"

    gone = Channel(kind="platform", name="قناة محذوفة", locked_fields=[], deleted_at=frozen_now)
    session.add(gone)
    await session.flush()
    deleted = await editor_client.get(f"{CHANNELS}/{gone.id}/frequency-changes")
    assert deleted.status_code == 404
    assert deleted.json()["error"]["code"] == "channel_not_found"


async def test_the_etag_moves_with_the_channels_dataset(editor_client, session):
    row = await channel(session)
    first = await editor_client.get(f"{CHANNELS}/{row.id}/frequency-changes")
    second = await editor_client.get(f"{CHANNELS}/{row.id}/frequency-changes")
    assert first.headers["etag"] == second.headers["etag"]

    await session.execute(
        update(DatasetVersion).where(DatasetVersion.name == "channels").values(version=DatasetVersion.version + 1)
    )
    moved = await editor_client.get(f"{CHANNELS}/{row.id}/frequency-changes")
    assert moved.headers["etag"] != first.headers["etag"]


async def test_it_needs_a_signed_in_staff_account(anon_admin_client):
    response = await anon_admin_client.get(f"{CHANNELS}/1/frequency-changes")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthenticated"
