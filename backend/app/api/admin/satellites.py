"""``/admin/api/satellites``: the whole list and CRUD (contracts/admin-api.md)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, IfMatch, Now, set_etag
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import lists
from app.services.admin import satellites as service

router = APIRouter(prefix="/admin/api/satellites", tags=["satellites"], dependencies=[Depends(require_editor)])

_NOT_FOUND = _docs.not_found("satellite_not_found")


@router.get(
    "",
    response_model=Envelope[list[a.AdminSatellite]],
    dependencies=[Depends(ETag("admin_satellites", ("satellites",)))],
    responses={
        200: {
            "description": "Satellites, with the list's `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("satellites_ok", [ex.SATELLITE], _docs.LIST_META),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
    },
    summary="Every satellite, by priority",
)
async def list_satellites(session: Db) -> Envelope[list[a.AdminSatellite]]:
    return ok(await lists.satellites(session))


@router.get(
    "/{satellite_id}",
    response_model=Envelope[a.AdminSatellite],
    responses={
        200: {
            "description": "The satellite, with its `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("satellite_ok", ex.SATELLITE),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
    },
    summary="One satellite",
)
async def get_satellite(satellite_id: IdPath, response: Response, session: Db) -> Envelope[a.AdminSatellite]:
    satellite = await service.get(session, satellite_id)
    set_etag(response, await service.version(session, satellite))
    return ok(await service.view(session, satellite))


@router.post(
    "",
    status_code=201,
    response_model=Envelope[a.AdminSatellite],
    responses={
        201: {"description": "Created", **ETAG_HEADER, **_docs.ok_example("satellite_ok", ex.SATELLITE)},
        **_docs.AUTHED,
        409: _docs.ALREADY_EXISTS,
        422: _docs.VALIDATION,
    },
    summary="Create a satellite (takes no `If-Match`)",
)
async def create_satellite(
    body: a.SatelliteCreate, response: Response, session: Db, admin: Editor
) -> Envelope[a.AdminSatellite]:
    satellite = await service.create(session, admin, body)
    await session.commit()
    set_etag(response, await service.version(session, satellite))
    return ok(await service.view(session, satellite))


@router.patch(
    "/{satellite_id}",
    response_model=Envelope[a.AdminSatellite],
    responses={
        200: {
            "description": "The saved satellite, with its new `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("satellite_ok", ex.SATELLITE),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.CONFLICT_OR_EXISTS,
        422: _docs.VALIDATION,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Update a satellite",
)
async def patch_satellite(
    satellite_id: IdPath,
    body: a.SatellitePatch,
    response: Response,
    session: Db,
    admin: Editor,
    now: Now,
    if_match: IfMatch = None,
) -> Envelope[a.AdminSatellite]:
    satellite = await service.update(session, admin, satellite_id, body, if_match, now)
    await session.commit()
    set_etag(response, await service.version(session, satellite))
    return ok(await service.view(session, satellite))


@router.delete(
    "/{satellite_id}",
    response_model=Envelope[None],
    responses={**_docs.AUTHED, 404: _NOT_FOUND, 409: _docs.IN_USE_OR_CONFLICT, 428: _docs.PRECONDITION_REQUIRED},
    summary="Delete a satellite that no channel references",
)
async def delete_satellite(
    satellite_id: IdPath, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[None]:
    await service.remove(session, admin, satellite_id, if_match, now)
    await session.commit()
    return ok(None)
