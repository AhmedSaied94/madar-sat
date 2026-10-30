"""``/admin/api/teams``: the team picker, paged browsing and CRUD (contracts/admin-api.md)."""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, IfMatch, Now, set_etag
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import lists
from app.services.admin import teams as service

router = APIRouter(prefix="/admin/api/teams", tags=["teams"], dependencies=[Depends(require_editor)])

_NOT_FOUND = _docs.not_found("team_not_found")


@router.get(
    "",
    response_model=Envelope[list[a.TeamItem]],
    responses={
        200: {"description": "Teams", **_docs.ok_example("teams_ok", [ex.TEAM_ITEM], _docs.PAGE_META)},
        **_docs.AUTHED,
        422: _docs.VALIDATION,
    },
    summary="Search teams (top 20 by similarity) or page through them",
)
async def list_teams(
    session: Db,
    q: Annotated[str | None, Query(min_length=1, max_length=a.MAX_QUERY_LENGTH)] = None,
    competition_id: Annotated[int | None, Query(ge=1, le=2**63 - 1)] = None,
    missing_logo: bool | None = None,
    cursor: Annotated[str | None, Query(max_length=200)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> Envelope[list[a.TeamItem]]:
    items, next_cursor = await lists.teams(session, q, competition_id, missing_logo, cursor, limit)
    return ok(items, {"next_cursor": next_cursor})


@router.get(
    "/{team_id}",
    response_model=Envelope[a.AdminTeam],
    responses={
        200: {"description": "The team, with its `ETag`", **ETAG_HEADER, **_docs.ok_example("team_ok", ex.TEAM)},
        **_docs.AUTHED,
        404: _NOT_FOUND,
    },
    summary="One team",
)
async def get_team(team_id: IdPath, response: Response, session: Db) -> Envelope[a.AdminTeam]:
    team = await service.get(session, team_id)
    set_etag(response, await service.version(session, team))
    return ok(await service.view(session, team))


@router.post(
    "",
    status_code=201,
    response_model=Envelope[a.AdminTeam],
    responses={
        201: {"description": "Created", **ETAG_HEADER, **_docs.ok_example("team_ok", ex.TEAM)},
        **_docs.AUTHED,
        422: _docs.VALIDATION,
    },
    summary="Create a team (takes no `If-Match`)",
)
async def create_team(body: a.TeamCreate, response: Response, session: Db, admin: Editor) -> Envelope[a.AdminTeam]:
    team = await service.create(session, admin, body)
    await session.commit()
    set_etag(response, await service.version(session, team))
    return ok(await service.view(session, team))


@router.patch(
    "/{team_id}",
    response_model=Envelope[a.AdminTeam],
    responses={
        200: {
            "description": "The saved team, with its new `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("team_ok", ex.TEAM),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.CONFLICT_OR_EXISTS,
        422: _docs.VALIDATION,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Update a team",
)
async def patch_team(
    team_id: IdPath,
    body: a.TeamPatch,
    response: Response,
    session: Db,
    admin: Editor,
    now: Now,
    if_match: IfMatch = None,
) -> Envelope[a.AdminTeam]:
    team = await service.update(session, admin, team_id, body, if_match, now)
    await session.commit()
    set_etag(response, await service.version(session, team))
    return ok(await service.view(session, team))


@router.delete(
    "/{team_id}",
    response_model=Envelope[None],
    responses={
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.IN_USE_OR_CONFLICT,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Delete a team that no match or follow references",
)
async def delete_team(
    team_id: IdPath, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[None]:
    await service.remove(session, admin, team_id, if_match, now)
    await session.commit()
    return ok(None)
