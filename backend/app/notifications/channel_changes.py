"""Channel changes: one push per direction, per channel, per match, netted when the hold ends (research R5).

A writer calls :func:`report_link_change` in its own transaction: A4's ``reconcile_links`` (through the
async twin) and an importer's ``upsert``/``livesoccertv_links`` (Lane B2, through the sync one). Nothing
here sends; the dispatcher owns delivery.

Inside the window (kickoff − 6 h to a final state) a change is recorded and, if none is pending yet, one
``channels_updated`` row waits five minutes. Before the window only a match's first visible channel is
announced, to followers of that match alone. At first dispatch the unannounced changes are netted
against the links visible now, so a hidden name or a placeholder never goes out, and a retry sends the
same stored message.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import Session

from app.db.models import Match, MatchChannelChange, NotificationOutbox

HOLD = timedelta(minutes=5)
WINDOW_BEFORE = timedelta(hours=6)
FINAL_STATUSES = ("finished", "cancelled", "abandoned")
ACTION = {"added": "added", "removed": "removed"}


def _change_values(match_id: int, channel_id: int, action: str, source: str, now: datetime) -> dict[str, Any]:
    return {
        "match_id": match_id,
        "channel_id": channel_id,
        "action": action,
        "source": source,
        "created_at": now,
    }


def _outbox_values(match_id: int, first_change_id: int, *, first_channels: bool, now: datetime) -> dict[str, Any]:
    return {
        "type": "channels_updated",
        "dedupe_key": f"channels_updated:{match_id}:{first_change_id}",
        "payload": {"match_id": match_id, "first_channels": True} if first_channels else {"match_id": match_id},
        "audience": {"kind": "match_only", "match_id": match_id}
        if first_channels
        else {"kind": "match_followers", "match_id": match_id},
        "due_at": now + HOLD,
        "status": "pending",
    }


# --- Sync: an importer's call (Lane B2) --------------------------------------------------------------


def report_link_change(
    session: Session, match_id: int, channel_id: int, action: str, source: str, now: datetime
) -> int:
    """Record one change and, when needed, the pending push. Returns the rows written (0, 1 or 2)."""
    if action not in ACTION:
        raise ValueError(f"a link change is added or removed, not {action!r}")
    match = session.get(Match, match_id)
    if match is None or match.kickoff_at is None or match.status in FINAL_STATUSES:
        return 0

    inside = now >= match.kickoff_at - WINDOW_BEFORE
    if not inside and action == "removed":
        return 0
    if not inside and _had_visible_link(session, match_id, channel_id):
        return 0

    inserted = session.execute(
        insert(MatchChannelChange)
        .values(**_change_values(match_id, channel_id, action, source, now))
        .on_conflict_do_nothing(index_elements=["match_id", "channel_id", "action"])
        .returning(MatchChannelChange.id)
    ).scalar()
    if inserted is None:
        return 0
    if _pending(session, match_id) is not None:
        return 1
    session.execute(
        insert(NotificationOutbox)
        .values(**_outbox_values(match_id, int(inserted), first_channels=not inside, now=now))
        .on_conflict_do_nothing(index_elements=["dedupe_key"])
    )
    return 2


def _had_visible_link(session: Session, match_id: int, channel_id: int) -> bool:
    from app.notifications.dispatcher import visible_links

    return any(link.channel_id != channel_id for link in visible_links(session, match_id))


def _pending(session: Session, match_id: int) -> int | None:
    rows = session.execute(
        select(NotificationOutbox.id).where(
            NotificationOutbox.type == "channels_updated",
            NotificationOutbox.status.in_(("pending", "sending")),
            NotificationOutbox.audience["match_id"].astext == str(match_id),
        )
    ).first()
    return None if rows is None else int(rows[0])


# --- Async: A4's save (the admin API) ----------------------------------------------------------------


async def report_link_change_async(
    session: AsyncSession, match_id: int, channel_id: int, action: str, source: str, now: datetime
) -> int:
    if action not in ACTION:
        raise ValueError(f"a link change is added or removed, not {action!r}")
    match = await session.get(Match, match_id)
    if match is None or match.kickoff_at is None or match.status in FINAL_STATUSES:
        return 0

    inside = now >= match.kickoff_at - WINDOW_BEFORE
    if not inside and action == "removed":
        return 0
    if not inside and await _had_visible_link_async(session, match_id, channel_id):
        return 0

    inserted = (
        await session.execute(
            insert(MatchChannelChange)
            .values(**_change_values(match_id, channel_id, action, source, now))
            .on_conflict_do_nothing(index_elements=["match_id", "channel_id", "action"])
            .returning(MatchChannelChange.id)
        )
    ).scalar()
    if inserted is None:
        return 0
    if await _pending_async(session, match_id) is not None:
        return 1
    await session.execute(
        insert(NotificationOutbox)
        .values(**_outbox_values(match_id, int(inserted), first_channels=not inside, now=now))
        .on_conflict_do_nothing(index_elements=["dedupe_key"])
    )
    return 2


async def _had_visible_link_async(session: AsyncSession, match_id: int, channel_id: int) -> bool:
    """The dispatcher's visibility rule, read through the ORM so it runs on the async session too."""
    from app.db.models import Channel, MatchChannel
    from app.services.common import hidden_names, visible_link

    found = await session.execute(
        select(MatchChannel.channel_id)
        .join(Channel, Channel.id == MatchChannel.channel_id)
        .where(
            MatchChannel.match_id == match_id,
            MatchChannel.channel_id != channel_id,
            visible_link(MatchChannel, Channel, hidden_names()),
        )
    )
    return found.first() is not None


async def _pending_async(session: AsyncSession, match_id: int) -> int | None:
    row = await session.scalar(
        select(NotificationOutbox.id).where(
            NotificationOutbox.type == "channels_updated",
            NotificationOutbox.status.in_(("pending", "sending")),
            NotificationOutbox.audience["match_id"].astext == str(match_id),
        )
    )
    return None if row is None else int(row)


# --- At first dispatch: net the unannounced changes --------------------------------------------------


def net_pending(session: Session, match_id: int, now: datetime) -> tuple[list[Any], list[Any]]:
    """``(added, removed)`` visible now, with each change marked announced (one transaction).

    A retry reads the lists stored on the payload instead, so it never nets a second time.
    """
    from app.notifications.dispatcher import visible_links

    visible = {link.channel_id: link for link in visible_links(session, match_id)}
    changes = list(
        session.scalars(
            select(MatchChannelChange)
            .where(MatchChannelChange.match_id == match_id, MatchChannelChange.announced_at.is_(None))
            .order_by(MatchChannelChange.id)
        )
    )
    # Both directions for one channel cancel when it isn't there any more: an add that was undone is
    # nothing to tell (T025). Where the link is visible now, the raise is the news.
    both = {change.channel_id for change in changes if change.action == "added"} & {
        change.channel_id for change in changes if change.action == "removed"
    }
    added: list[Any] = []
    removed: list[Any] = []
    for change in changes:
        change.announced_at = now
        link = visible.get(change.channel_id)
        if change.action == "added" and link is not None:
            added.append(link)
        elif change.action == "removed" and change.channel_id in both:
            continue
        elif change.action == "removed" and link is None:
            view = _channel_view(session, change.channel_id)
            if view is not None:
                removed.append(view)
    return added, removed


def _channel_view(session: Session, channel_id: int) -> Any:
    """A removed channel, unless a hidden name, a placeholder or a delete means fans never knew it."""
    from app.db.models import Channel, Satellite
    from app.notifications.messages import VisibleLink
    from app.services.common import hidden_names

    row = session.execute(
        select(Channel, Satellite)
        .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
        .where(
            Channel.id == channel_id,
            Channel.deleted_at.is_(None),
            Channel.placeholder_source.is_(None),
            Channel.name_norm.not_in(hidden_names()),
            func.ar_normalize(func.coalesce(Channel.display_name, "")).not_in(hidden_names()),
        )
    ).first()
    if row is None:
        return None
    channel, satellite = row
    return VisibleLink(
        channel_id=channel.id,
        name=channel.display_name or channel.name,
        access=channel.access,
        sort_order=channel.sort_order,
        show_in_match=channel.show_in_match,
        satellite_id=channel.satellite_id,
        satellite_slug=satellite.slug if satellite is not None else None,
        satellite_name=satellite.name_ar if satellite is not None else None,
    )


def prune_announced(session: Session, cutoff: datetime) -> int:
    """Announced changes older than 30 days go with ``prune_outbox`` (research R5)."""
    from sqlalchemy import delete

    result = session.execute(
        delete(MatchChannelChange).where(
            MatchChannelChange.announced_at.is_not(None), MatchChannelChange.announced_at < cutoff
        )
    )
    return int(getattr(result, "rowcount", 0) or 0)


__all__ = [
    "HOLD",
    "net_pending",
    "prune_announced",
    "report_link_change",
    "report_link_change_async",
]
