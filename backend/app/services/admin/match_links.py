"""A match's channel links and broadcaster slots: validation and reconciliation (research R7).

The editor sends the full desired lists. Links are compared with the stored ones by ``channel_id``:

* a new link is inserted with ``source = 'manual'`` and ``imported_by = NULL``;
* a link whose hidden flag or commentators changed becomes ``source = 'manual'`` (``imported_by`` keeps
  the importer that first brought it);
* a link left out is deleted when an editor added it (``imported_by IS NULL``), and otherwise kept as a
  hidden ``manual`` link, so no importer adds it back.

Links to soft-deleted channels are not shown in the editor, so they are never touched here.
"""

from __future__ import annotations

from collections.abc import Sequence
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Channel, Commentator, MatchChannel, MatchCustomBroadcast
from app.schemas import admin as a
from app.services.admin import refs

Error = dict[str, Any]
LINK_FIELDS = ("is_hidden", "commentator_id", "commentator2_id")
SLOT_FIELDS = ("label", "logo_asset_id", "commentator_id")


async def _existing(session: AsyncSession, model: Any, ids: set[int], extra: Any = None) -> set[int]:
    if not ids:
        return set()
    query = select(model.id).where(model.id.in_(ids))
    if extra is not None:
        query = query.where(extra)
    return set((await session.scalars(query)).all())


async def link_errors(session: AsyncSession, links: Sequence[a.ChannelLinkInput]) -> list[Error]:
    """Duplicates, unknown or deleted channels and unknown commentators, each with its position."""
    errors: list[Error] = []
    seen: set[int] = set()
    for index, link in enumerate(links):
        if link.channel_id in seen:
            errors.append(refs.field_error(["channels", index, "channel_id"], "duplicate"))
        seen.add(link.channel_id)

    live = await _existing(session, Channel, seen, Channel.deleted_at.is_(None))
    commentator_ids = {c for link in links for c in (link.commentator_id, link.commentator2_id) if c is not None}
    known = await _existing(session, Commentator, commentator_ids)
    for index, link in enumerate(links):
        if link.channel_id not in live:
            errors.append(refs.field_error(["channels", index, "channel_id"], "not_found"))
        for field in ("commentator_id", "commentator2_id"):
            value = getattr(link, field)
            if value is not None and value not in known:
                errors.append(refs.field_error(["channels", index, field], "not_found"))
    return errors


async def slot_errors(session: AsyncSession, slots: Sequence[a.BroadcastSlotInput]) -> list[Error]:
    errors: list[Error] = []
    seen: set[int] = set()
    for index, slot in enumerate(slots):
        if slot.slot in seen:
            errors.append(refs.field_error(["broadcasts", index, "slot"], "duplicate"))
        seen.add(slot.slot)
        errors += await refs.missing_assets(
            session, [(slot.logo_asset_id, refs.IMAGE_KINDS, ["broadcasts", index, "logo_asset_id"])]
        )
    known = await _existing(session, Commentator, {s.commentator_id for s in slots if s.commentator_id is not None})
    for index, slot in enumerate(slots):
        if slot.commentator_id is not None and slot.commentator_id not in known:
            errors.append(refs.field_error(["broadcasts", index, "commentator_id"], "not_found"))
    return errors


async def reconcile_links(
    session: AsyncSession,
    match_id: int,
    desired: Sequence[a.ChannelLinkInput],
    now: datetime | None = None,
) -> dict[str, list[dict[str, Any]]]:
    """Apply the desired links; returns the audit diff (``added``, ``removed``, ``changed``; empty when none).

    Each add and remove, and each change of ``is_hidden``, is also reported to the push producers, which
    keep their own pending row (FR-010, research R5).
    """
    stored = {
        link.channel_id: link
        for link in (await session.scalars(select(MatchChannel).where(MatchChannel.match_id == match_id))).all()
    }
    live = await _existing(session, Channel, set(stored), Channel.deleted_at.is_(None))
    wanted = {link.channel_id: link for link in desired}
    added: list[dict[str, Any]] = []
    removed: list[dict[str, Any]] = []
    changed: list[dict[str, Any]] = []

    for channel_id in sorted(wanted):
        item, link = wanted[channel_id], stored.get(channel_id)
        if link is None:
            session.add(
                MatchChannel(
                    match_id=match_id,
                    channel_id=channel_id,
                    source="manual",
                    imported_by=None,
                    is_hidden=item.is_hidden,
                    commentator_id=item.commentator_id,
                    commentator2_id=item.commentator2_id,
                )
            )
            added.append(
                {
                    "channel_id": channel_id,
                    "is_hidden": item.is_hidden,
                    "commentator_id": item.commentator_id,
                    "commentator2_id": item.commentator2_id,
                }
            )
            continue
        edits = {f: [getattr(link, f), getattr(item, f)] for f in LINK_FIELDS if getattr(link, f) != getattr(item, f)}
        if edits:
            for field, (_, new) in edits.items():
                setattr(link, field, new)
            if link.source != "manual":
                edits["source"] = [link.source, "manual"]
                link.source = "manual"
            changed.append({"channel_id": channel_id, "fields": edits})

    for channel_id in sorted(set(stored) & live - set(wanted)):
        link = stored[channel_id]
        if link.imported_by is None:
            await session.delete(link)
            removed.append({"channel_id": channel_id})
            continue
        edits = {}
        if not link.is_hidden:
            edits["is_hidden"] = [False, True]
            link.is_hidden = True
        if link.source != "manual":
            edits["source"] = [link.source, "manual"]
            link.source = "manual"
        if edits:
            changed.append({"channel_id": channel_id, "fields": edits})

    await _report_changes(session, match_id, added, removed, changed, now)
    return {key: value for key, value in (("added", added), ("removed", removed), ("changed", changed)) if value}


async def _report_changes(
    session: AsyncSession,
    match_id: int,
    added: Sequence[dict[str, Any]],
    removed: Sequence[dict[str, Any]],
    changed: Sequence[dict[str, Any]],
    now: datetime | None,
) -> None:
    """One row per direction per channel; a hidden flag moving counts as one too (research R5)."""
    from app.notifications.channel_changes import report_link_change_async

    moment = now or datetime.now(UTC)
    for item in added:
        await report_link_change_async(session, match_id, int(item["channel_id"]), "added", "admin", moment)
    for item in removed:
        await report_link_change_async(session, match_id, int(item["channel_id"]), "removed", "admin", moment)
    for item in changed:
        edits = item.get("fields") or {}
        if "is_hidden" not in edits:
            continue
        hidden = edits["is_hidden"][1]
        action = "removed" if hidden else "added"
        await report_link_change_async(session, match_id, int(item["channel_id"]), action, "admin", moment)


async def remove_all_visible(
    session: AsyncSession, match_id: int, channel_ids: Sequence[int] | None, hidden_names: Any
) -> dict[str, list[dict[str, Any]]]:
    """Bulk ``remove_channels``: the removal rule above for every visible link (or only ``channel_ids``)."""
    from app.services.common import visible_link

    query = (
        select(MatchChannel)
        .join(Channel, Channel.id == MatchChannel.channel_id)
        .where(MatchChannel.match_id == match_id, visible_link(MatchChannel, Channel, hidden_names))
    )
    if channel_ids is not None:
        query = query.where(MatchChannel.channel_id.in_(channel_ids))
    links = (await session.scalars(query)).all()
    removed: list[dict[str, Any]] = []
    changed: list[dict[str, Any]] = []
    for link in sorted(links, key=lambda link: link.channel_id):
        if link.imported_by is None:
            await session.delete(link)
            removed.append({"channel_id": link.channel_id})
            continue
        edits: dict[str, Any] = {"is_hidden": [False, True]}
        link.is_hidden = True
        if link.source != "manual":
            edits["source"] = [link.source, "manual"]
            link.source = "manual"
        changed.append({"channel_id": link.channel_id, "fields": edits})
    return {key: value for key, value in (("removed", removed), ("changed", changed)) if value}


async def reconcile_slots(
    session: AsyncSession, match_id: int, desired: Sequence[a.BroadcastSlotInput]
) -> dict[str, list[Any]]:
    """Apply the desired slots (a slot not sent is cleared); returns ``{slot: [old, new]}`` for what changed."""
    stored = {
        slot.slot: slot
        for slot in (
            await session.scalars(select(MatchCustomBroadcast).where(MatchCustomBroadcast.match_id == match_id))
        ).all()
    }
    wanted = {slot.slot: slot for slot in desired}
    diff: dict[str, list[Any]] = {}

    for number in sorted(wanted):
        item, row = wanted[number], stored.get(number)
        new = {f: getattr(item, f) for f in SLOT_FIELDS}
        if row is None:
            session.add(MatchCustomBroadcast(match_id=match_id, slot=number, **new))
            diff[str(number)] = [None, new]
            continue
        old = {f: getattr(row, f) for f in SLOT_FIELDS}
        if old != new:
            for field, value in new.items():
                setattr(row, field, value)
            diff[str(number)] = [old, new]

    for cleared in sorted(set(stored) - set(wanted)):
        row = stored[cleared]
        diff[str(cleared)] = [{f: getattr(row, f) for f in SLOT_FIELDS}, None]
        await session.delete(row)
    return diff
