"""``/admin/api/competitions``: the whole list and CRUD (contracts/admin-api.md)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, IfMatch, Now, set_etag
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import competitions as service
from app.services.admin import lists

router = APIRouter(prefix="/admin/api/competitions", tags=["competitions"], dependencies=[Depends(require_editor)])

_NOT_FOUND = _docs.not_found("competition_not_found")


@router.get(
    "",
    response_model=Envelope[list[a.AdminCompetition]],
    dependencies=[Depends(ETag("admin_competitions", ("competitions",)))],
    responses={
        200: {"description": "Competitions", **_docs.ok_example("competitions_ok", [ex.COMPETITION], _docs.LIST_META)},
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
    },
    summary="Every competition, by priority (nulls last), then name",
)
async def list_competitions(session: Db) -> Envelope[list[a.AdminCompetition]]:
    return ok(await lists.competitions(session))


@router.get(
    "/{competition_id}",
    response_model=Envelope[a.AdminCompetition],
    responses={
        200: {
            "description": "The competition, with its `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("competition_ok", ex.COMPETITION),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
    },
    summary="One competition",
)
async def get_competition(competition_id: IdPath, response: Response, session: Db) -> Envelope[a.AdminCompetition]:
    competition = await service.get(session, competition_id)
    set_etag(response, await service.version(session, competition))
    return ok(await service.view(session, competition))


@router.post(
    "",
    status_code=201,
    response_model=Envelope[a.AdminCompetition],
    responses={
        201: {"description": "Created", **ETAG_HEADER, **_docs.ok_example("competition_ok", ex.COMPETITION)},
        **_docs.AUTHED,
        409: _docs.ALREADY_EXISTS,
        422: _docs.VALIDATION,
    },
    summary="Create a competition (takes no `If-Match`)",
)
async def create_competition(
    body: a.CompetitionCreate, response: Response, session: Db, admin: Editor
) -> Envelope[a.AdminCompetition]:
    competition = await service.create(session, admin, body)
    await session.commit()
    set_etag(response, await service.version(session, competition))
    return ok(await service.view(session, competition))


@router.patch(
    "/{competition_id}",
    response_model=Envelope[a.AdminCompetition],
    responses={
        200: {
            "description": "The saved competition, with its new `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("competition_ok", ex.COMPETITION),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.CONFLICT_OR_EXISTS,
        422: _docs.VALIDATION,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Update a competition",
)
async def patch_competition(
    competition_id: IdPath,
    body: a.CompetitionPatch,
    response: Response,
    session: Db,
    admin: Editor,
    now: Now,
    if_match: IfMatch = None,
) -> Envelope[a.AdminCompetition]:
    competition = await service.update(session, admin, competition_id, body, if_match, now)
    await session.commit()
    set_etag(response, await service.version(session, competition))
    return ok(await service.view(session, competition))


@router.delete(
    "/{competition_id}",
    response_model=Envelope[None],
    responses={**_docs.AUTHED, 404: _NOT_FOUND, 409: _docs.IN_USE_OR_CONFLICT, 428: _docs.PRECONDITION_REQUIRED},
    summary="Delete a competition that nothing references",
)
async def delete_competition(
    competition_id: IdPath, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[None]:
    await service.remove(session, admin, competition_id, if_match, now)
    await session.commit()
    return ok(None)
