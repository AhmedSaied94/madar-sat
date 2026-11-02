"""The follow set: replaced whole, atomically, under a device row lock (research R5).

One row per target in ``device_follows`` (D1's check keeps exactly one target column set). The
caller sends the whole set; unknown ids are refused by kind and nothing changes.
"""

from __future__ import annotations

from typing import Any

from sqlalchemy import delete, insert, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound, too_many_follows, unknown_follow_target
from app.db.models import Channel, Commentator, Competition, Device, Match, Team
from app.schemas import public as s

MAX_FOLLOWS = 500

# kind -> (model, extra visibility condition)
_KINDS: dict[str, tuple[Any, bool]] = {
    "teams": (Team, False),
    "competitions": (Competition, False),
    "matches": (Match, False),
    "channels": (Channel, True),
    "commentators": (Commentator, False),
}

_KIND_COLUMNS = {
    "teams": "team_id",
    "competitions": "competition_id",
    "matches": "match_id",
    "channels": "channel_id",
    "commentators": "commentator_id",
}


async def load(session: AsyncSession, device_id: int) -> s.FollowSet:
    """The stored set, grouped by kind."""
    from app.db.models import DeviceFollow

    rows = (await session.execute(select(DeviceFollow).where(DeviceFollow.device_id == device_id))).scalars()
    grouped: dict[str, list[int]] = dict.fromkeys(_KINDS, [])
    for row in rows:
        for kind in _KINDS:
            value = getattr(row, _KIND_COLUMNS[kind])
            if value is not None:
                grouped[kind].append(value)
                break
    return s.FollowSet(**grouped)


async def replace(session: AsyncSession, device_id: int, body: s.FollowSet) -> s.FollowSet:
    """Replace the device's whole follow set in one transaction (``SELECT … FOR UPDATE`` first)."""
    from app.db.models import DeviceFollow

    wanted = body.collapsed()
    if sum(len(ids) for ids in wanted.values()) > MAX_FOLLOWS:
        raise too_many_follows(MAX_FOLLOWS)

    # Serialises two concurrent PUTs from one device: the second waits, then replaces the first.
    device = await session.get(Device, device_id, with_for_update=True)
    if device is None:  # the device was deleted between authentication and this write
        raise EntityNotFound("device_not_found")

    unknown: dict[str, list[int]] = {}
    for kind, ids in wanted.items():
        model, live_only = _KINDS[kind]
        if not ids:
            continue
        query = select(model.id).where(model.id.in_(ids))
        if live_only:
            query = query.where(model.deleted_at.is_(None))
        found = set((await session.scalars(query)).all())
        missing = [item for item in ids if item not in found]
        if missing:
            unknown[kind] = missing
    if unknown:
        raise unknown_follow_target(unknown)

    await session.execute(delete(DeviceFollow).where(DeviceFollow.device_id == device_id))
    for kind, ids in wanted.items():
        if ids:
            # One multi-row INSERT per kind: a partially-NULL composite key trips SQLAlchemy's
            # executemany path (2.1.6), and 500 single inserts would be needlessly slow.
            await session.execute(
                insert(DeviceFollow).values(
                    [{"device_id": device_id, _KIND_COLUMNS[kind]: target_id} for target_id in ids]
                )
            )
    await session.flush()
    return s.FollowSet(**wanted)
