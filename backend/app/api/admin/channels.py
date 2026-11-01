"""``/admin/api/channels``: the channel picker, paged browsing and CRUD (contracts/admin-api.md)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, IfMatch, Now, set_etag
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import NO_NUL_PATTERN
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.schemas.public import Access, Category, Kind
from app.services.admin import channels as service
from app.services.admin import lists

router = APIRouter(prefix="/admin/api/channels", tags=["channels"], dependencies=[Depends(require_editor)])

_NOT_FOUND = _docs.not_found("channel_not_found")


@router.get(
    "",
    response_model=Envelope[list[a.ChannelItem]],
    responses={
        200: {
            "description": "Channels, with the list's `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("channels_ok", [ex.CHANNEL_ITEM], _docs.PAGE_META),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        422: _docs.VALIDATION,
    },
    summary="Search channels (top 20 by similarity) or page through them by `(sort_order, id)`",
    dependencies=[Depends(ETag("admin_channels", ("channels", "satellites")))],
)
async def list_channels(
    session: Db,
    q: Annotated[str | None, Query(min_length=1, max_length=a.MAX_QUERY_LENGTH, pattern=NO_NUL_PATTERN)] = None,
    satellite_id: Annotated[int | None, Query(ge=1, le=2**63 - 1)] = None,
    category: Category | None = None,
    kind: Kind | None = None,
    access: Access | None = None,
    missing_logo: bool | None = None,
    placeholder: bool | None = None,
    show_in_match: bool | None = None,
    cursor: Annotated[str | None, Query(max_length=200)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> Envelope[list[a.ChannelItem]]:
    filters = lists.ChannelFilters(
        satellite_id=satellite_id,
        category=category.value if category else None,
        kind=kind.value if kind else None,
        access=access.value if access else None,
        missing_logo=missing_logo,
        placeholder=placeholder,
        show_in_match=show_in_match,
    )
    items, next_cursor = await lists.channels(session, q, filters, cursor, limit)
    return ok(items, {"next_cursor": next_cursor})


@router.get(
    "/{channel_id}",
    response_model=Envelope[a.AdminChannel],
    responses={
        200: {
            "description": "The channel, with its `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("channel_ok", ex.CHANNEL),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
    },
    summary="One channel",
)
async def get_channel(channel_id: IdPath, response: Response, session: Db) -> Envelope[a.AdminChannel]:
    channel = await service.get(session, channel_id)
    set_etag(response, await service.version(session, channel))
    return ok(await service.view(session, channel))


@router.post(
    "",
    status_code=201,
    response_model=Envelope[a.AdminChannel],
    responses={
        201: {"description": "Created", **ETAG_HEADER, **_docs.ok_example("channel_ok", ex.CHANNEL)},
        **_docs.AUTHED,
        409: _docs.ALREADY_EXISTS,
        422: _docs.VALIDATION,
    },
    summary="Create a channel (takes no `If-Match`)",
)
async def create_channel(
    body: a.ChannelCreate, response: Response, session: Db, admin: Editor
) -> Envelope[a.AdminChannel]:
    channel = await service.create(session, admin, body)
    await session.commit()
    set_etag(response, await service.version(session, channel))
    return ok(await service.view(session, channel))


@router.patch(
    "/{channel_id}",
    response_model=Envelope[a.AdminChannel],
    responses={
        200: {
            "description": "The saved channel, with its new `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("channel_ok", ex.CHANNEL),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.CONFLICT_OR_EXISTS,
        422: _docs.VALIDATION,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Update a channel; the fields it changes are locked against importers",
)
async def patch_channel(
    channel_id: IdPath,
    body: a.ChannelPatch,
    response: Response,
    session: Db,
    admin: Editor,
    now: Now,
    if_match: IfMatch = None,
) -> Envelope[a.AdminChannel]:
    channel = await service.update(session, admin, channel_id, body, if_match, now)
    await session.commit()
    set_etag(response, await service.version(session, channel))
    return ok(await service.view(session, channel))


@router.delete(
    "/{channel_id}",
    response_model=Envelope[None],
    responses={**_docs.AUTHED, 404: _NOT_FOUND, 409: _docs.EDIT_CONFLICT, 428: _docs.PRECONDITION_REQUIRED},
    summary="Soft-delete a channel (`deleted_at`); it disappears from `/v1`",
)
async def delete_channel(
    channel_id: IdPath, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[None]:
    await service.remove(session, admin, channel_id, if_match, now)
    await session.commit()
    return ok(None)
