"""``/admin/api/commentators``: the commentator picker, paged browsing and CRUD (contracts/admin-api.md)."""

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
from app.services.admin import commentators as service
from app.services.admin import lists

router = APIRouter(prefix="/admin/api/commentators", tags=["commentators"], dependencies=[Depends(require_editor)])

_NOT_FOUND = _docs.not_found("commentator_not_found")


@router.get(
    "",
    response_model=Envelope[list[a.AdminCommentator]],
    responses={
        200: {
            "description": "Commentators, with the list's `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("commentators_ok", [ex.COMMENTATOR], _docs.PAGE_META),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        422: _docs.VALIDATION,
    },
    summary="Search commentators (top 20 by similarity) or page through them",
    # `usage` counts `matches.commentator_id` and `match_channels`, so assigning one moves the list
    # (B1-R2-2).
    dependencies=[Depends(ETag("admin_commentators", ("commentators", "matches")))],
)
async def list_commentators(
    session: Db,
    q: Annotated[str | None, Query(min_length=1, max_length=a.MAX_QUERY_LENGTH, pattern=NO_NUL_PATTERN)] = None,
    cursor: Annotated[str | None, Query(max_length=200)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> Envelope[list[a.AdminCommentator]]:
    items, next_cursor = await lists.commentators(session, q, cursor, limit)
    return ok(items, {"next_cursor": next_cursor})


@router.get(
    "/{commentator_id}",
    response_model=Envelope[a.AdminCommentator],
    responses={
        200: {
            "description": "The commentator, with its `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("commentator_ok", ex.COMMENTATOR),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
    },
    summary="One commentator",
)
async def get_commentator(commentator_id: IdPath, response: Response, session: Db) -> Envelope[a.AdminCommentator]:
    commentator = await service.get(session, commentator_id)
    set_etag(response, await service.version(session, commentator))
    return ok(await service.view(session, commentator))


@router.post(
    "",
    status_code=201,
    response_model=Envelope[a.AdminCommentator],
    responses={
        201: {"description": "Created", **ETAG_HEADER, **_docs.ok_example("commentator_ok", ex.COMMENTATOR)},
        **_docs.AUTHED,
        409: _docs.ALREADY_EXISTS,
        422: _docs.VALIDATION,
    },
    summary="Create a commentator (takes no `If-Match`)",
)
async def create_commentator(
    body: a.CommentatorCreate, response: Response, session: Db, admin: Editor
) -> Envelope[a.AdminCommentator]:
    commentator = await service.create(session, admin, body)
    await session.commit()
    set_etag(response, await service.version(session, commentator))
    return ok(await service.view(session, commentator))


@router.patch(
    "/{commentator_id}",
    response_model=Envelope[a.AdminCommentator],
    responses={
        200: {
            "description": "The saved commentator, with its new `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("commentator_ok", ex.COMMENTATOR),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.CONFLICT_OR_EXISTS,
        422: _docs.VALIDATION,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Update a commentator",
)
async def patch_commentator(
    commentator_id: IdPath,
    body: a.CommentatorPatch,
    response: Response,
    session: Db,
    admin: Editor,
    now: Now,
    if_match: IfMatch = None,
) -> Envelope[a.AdminCommentator]:
    commentator = await service.update(session, admin, commentator_id, body, if_match, now)
    await session.commit()
    set_etag(response, await service.version(session, commentator))
    return ok(await service.view(session, commentator))


@router.delete(
    "/{commentator_id}",
    response_model=Envelope[None],
    responses={**_docs.AUTHED, 404: _NOT_FOUND, 409: _docs.IN_USE_OR_CONFLICT, 428: _docs.PRECONDITION_REQUIRED},
    summary="Delete a commentator that no match references",
)
async def delete_commentator(
    commentator_id: IdPath, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[None]:
    await service.remove(session, admin, commentator_id, if_match, now)
    await session.commit()
    return ok(None)
