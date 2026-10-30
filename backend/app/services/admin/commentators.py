"""Commentators: read, create, update and delete."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound
from app.auth.roles import AuthedAdmin
from app.db.models import Commentator, DeviceFollow, Match, MatchChannel, MatchCustomBroadcast
from app.schemas import admin as a
from app.services.admin import refs, versions, writer
from app.services.admin.common import asset_urls, count, refuse_if_in_use, sent, url_of

ENTITY = "commentators"
NOT_FOUND = "commentator_not_found"
COLUMNS = ("name", "photo_asset_id", "audio_asset_id")


async def get(session: AsyncSession, commentator_id: int) -> Commentator:
    commentator = await session.get(Commentator, commentator_id)
    if commentator is None:
        raise EntityNotFound(NOT_FOUND)
    return commentator


async def usage(session: AsyncSession, commentator_id: int) -> a.CommentatorUsage:
    return a.CommentatorUsage(
        matches=await count(session, select(Match.id).where(Match.commentator_id == commentator_id)),
        match_channels=await count(
            session,
            select(MatchChannel.match_id).where(
                or_(MatchChannel.commentator_id == commentator_id, MatchChannel.commentator2_id == commentator_id)
            ),
        ),
    )


async def view(session: AsyncSession, commentator: Commentator) -> a.AdminCommentator:
    urls = await asset_urls(session, [commentator.photo_asset_id, commentator.audio_asset_id])
    return a.AdminCommentator(
        id=commentator.id,
        name=commentator.name,
        photo_asset_id=commentator.photo_asset_id,
        photo=url_of(urls, commentator.photo_asset_id),
        audio_asset_id=commentator.audio_asset_id,
        audio=url_of(urls, commentator.audio_asset_id),
        usage=await usage(session, commentator.id),
    )


async def version(session: AsyncSession, commentator: Commentator) -> str:
    return versions.row_version(commentator)


async def _check_assets(session: AsyncSession, photo_asset_id: int | None, audio_asset_id: int | None) -> None:
    refs.raise_if_any(
        await refs.missing_assets(
            session,
            [
                (photo_asset_id, refs.IMAGE_KINDS, ["photo_asset_id"]),
                (audio_asset_id, refs.AUDIO_KINDS, ["audio_asset_id"]),
            ],
        )
    )


async def create(session: AsyncSession, admin: AuthedAdmin, body: a.CommentatorCreate) -> Commentator:
    await _check_assets(session, body.photo_asset_id, body.audio_asset_id)
    commentator = Commentator(name=body.name, photo_asset_id=body.photo_asset_id, audio_asset_id=body.audio_asset_id)
    session.add(commentator)
    await writer.save_create(session, admin, entity=ENTITY, row=commentator, datasets=writer.COMMENTATOR_CHANGED)
    return commentator


async def update(
    session: AsyncSession,
    admin: AuthedAdmin,
    commentator_id: int,
    body: a.CommentatorPatch,
    if_match: str | None,
    now: datetime,
) -> Commentator:
    commentator = await writer.lock_and_check(session, Commentator, commentator_id, NOT_FOUND, ENTITY, if_match)
    changes = sent(body)
    if changes.get("name", "") is None:
        refs.raise_if_any([refs.field_error(["name"], "null_not_allowed")])
    await _check_assets(session, changes.get("photo_asset_id"), changes.get("audio_asset_id"))

    before = versions.row_state(commentator)
    for column in COLUMNS:
        if column in changes:
            setattr(commentator, column, changes[column])
    await writer.save_update(
        session,
        admin,
        entity=ENTITY,
        row=commentator,
        before=before,
        datasets=writer.COMMENTATOR_CHANGED,
        now=now,
    )
    return commentator


async def remove(
    session: AsyncSession, admin: AuthedAdmin, commentator_id: int, if_match: str | None, now: datetime
) -> None:
    commentator = await writer.lock_and_check(session, Commentator, commentator_id, NOT_FOUND, ENTITY, if_match)
    await refuse_if_in_use(
        session,
        {
            "matches": select(Match.id).where(Match.commentator_id == commentator.id),
            "match_channels": select(MatchChannel.match_id).where(
                or_(MatchChannel.commentator_id == commentator.id, MatchChannel.commentator2_id == commentator.id)
            ),
            "broadcasts": select(MatchCustomBroadcast.match_id).where(
                MatchCustomBroadcast.commentator_id == commentator.id
            ),
            "follows": select(DeviceFollow.device_id).where(DeviceFollow.commentator_id == commentator.id),
        },
    )
    await writer.save_delete(
        session, admin, entity=ENTITY, row=commentator, datasets=writer.COMMENTATOR_CHANGED, now=now
    )
