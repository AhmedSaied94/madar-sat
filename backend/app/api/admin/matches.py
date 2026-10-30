"""``/admin/api/matches``: the A3 list, the A4 editor's match, create, patch and bulk (contracts/admin-api.md)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, IfMatch, Now, set_etag
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.schemas.public import Status
from app.services.admin import bulk as bulk_service
from app.services.admin import match_list, match_view, versions
from app.services.admin import matches as service

router = APIRouter(prefix="/admin/api/matches", tags=["matches"], dependencies=[Depends(require_editor)])

# The A3 list shows derived statuses and joined names, so it follows these datasets.
LIST_DATASETS = ("matches", "live", "channels", "satellites", "competitions", "teams", "commentators")
_WRITE_ERRORS: dict[int | str, dict[str, Any]] = {
    401: _docs.UNAUTHENTICATED,
    403: _docs.FORBIDDEN,
    404: _docs.not_found("match_not_found"),
    409: _docs.EDIT_CONFLICT,
    422: _docs.VALIDATION_STATUS,
    428: _docs.MATCH_PRECONDITION_REQUIRED,
}


@router.get(
    "",
    response_model=Envelope[list[a.AdminMatchRow]],
    dependencies=[Depends(ETag("admin_matches", LIST_DATASETS, bucket_s=60))],
    responses={
        200: {"description": "The window's matches", **_docs.ok_example("matches_ok", [ex.MATCH_ROW], _docs.LIST_META)},
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        422: _docs.VALIDATION,
    },
    summary="A3: the matches of a window of at most 8 days",
)
async def list_matches(
    session: Db,
    now: Now,
    from_dt: Annotated[datetime, Query(alias="from", description="UTC; `to - from` is at most 8 days")],
    to_dt: Annotated[datetime, Query(alias="to")],
    competition_id: Annotated[int | None, Query(ge=1, le=2**63 - 1)] = None,
    source: Annotated[
        str | None,
        Query(
            pattern=r"^[a-z][a-z0-9_]*$", max_length=64, description="A `sources.name`: the creator or any external id"
        ),
    ] = None,
    missing_channels: Annotated[bool | None, Query(description="No visible link and no manual broadcaster")] = None,
    status: Annotated[Status | None, Query(description="The derived status the app would show")] = None,
) -> Envelope[list[a.AdminMatchRow]]:
    rows = await match_list.list_rows(
        session,
        now,
        from_dt,
        to_dt,
        competition_id=competition_id,
        source=source,
        missing_channels=missing_channels,
        status=status.value if status else None,
    )
    return ok(rows, {"count": len(rows)})


@router.get(
    "/{match_id}",
    response_model=Envelope[a.AdminMatch],
    responses={
        200: {"description": "The match, with its `ETag`", **ETAG_HEADER, **_docs.example(match_ok=_docs.MATCH_OK)},
        401: _docs.UNAUTHENTICATED,
        403: _docs.FORBIDDEN,
        404: _docs.not_found("match_not_found"),
    },
    summary="A4: one match",
)
async def get_match(match_id: IdPath, response: Response, session: Db, now: Now) -> Envelope[a.AdminMatch]:
    match = await match_view.get(session, match_id)
    set_etag(response, await versions.match_version(session, match))
    return ok(await match_view.view(session, match, now))


@router.post(
    "",
    status_code=201,
    response_model=Envelope[a.AdminMatch],
    responses={
        201: {
            "description": "Created with `source = manual`; takes no `If-Match`",
            **ETAG_HEADER,
            **_docs.example(match_ok=_docs.MATCH_OK),
        },
        **_docs.AUTHED,
        422: _docs.VALIDATION,
    },
    summary="Create a match",
)
async def create_match(
    body: a.MatchCreate, response: Response, session: Db, admin: Editor, now: Now
) -> Envelope[a.AdminMatch]:
    match = await service.create(session, admin, body, now)
    await session.commit()
    set_etag(response, await versions.match_version(session, match))
    return ok(await match_view.view(session, match, now))


@router.post(
    "/bulk",
    response_model=Envelope[a.BulkResult],
    responses={
        200: {"description": "Every item changed", **_docs.ok_example("bulk_ok", ex.BULK_RESULT)},
        **_docs.AUTHED,
        403: _docs.FORBIDDEN_REMOVE_CHANNELS,
        409: _docs.EDIT_CONFLICT,
        422: _docs.VALIDATION,
    },
    summary="Change the competition of, or remove channels from, many matches (all or nothing)",
)
async def bulk(body: a.BulkRequest, session: Db, admin: Editor, now: Now) -> Envelope[a.BulkResult]:
    result = await bulk_service.run(session, admin, body, now)
    await session.commit()
    return ok(result)


@router.patch(
    "/{match_id}",
    response_model=Envelope[a.AdminMatch],
    responses={
        200: {
            "description": "The saved match, with its new `ETag`",
            **ETAG_HEADER,
            **_docs.example(match_ok=_docs.MATCH_OK),
        },
        **_WRITE_ERRORS,
    },
    summary="A4: save the fields, broadcasters, links and status together",
)
async def patch_match(
    match_id: IdPath,
    body: a.MatchPatch,
    response: Response,
    session: Db,
    admin: Editor,
    now: Now,
    if_match: IfMatch = None,
) -> Envelope[a.AdminMatch]:
    match = await service.update(session, admin, match_id, body, if_match, now)
    await session.commit()
    set_etag(response, await versions.match_version(session, match))
    return ok(await match_view.view(session, match, now))
