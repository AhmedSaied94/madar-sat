"""``/admin/api/rights-holders``: A9 (005 contracts/admin-api.md)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, IfMatch, Now, set_etag
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.api.errors import NotModified, forbidden
from app.api.etag import if_none_match
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.schemas import admin_queue as q
from app.services.admin import ordering
from app.services.admin import rights_holders as service

router = APIRouter(prefix="/admin/api/rights-holders", tags=["rights-holders"], dependencies=[Depends(require_editor)])

_NOT_FOUND = _docs.not_found("rights_holder_not_found")


@router.get(
    "",
    response_model=Envelope[list[q.AdminRightsHolderRow]],
    responses={
        200: {
            "description": "Rights holders, with the list's `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("rights_holders_ok", [ex.RIGHTS_HOLDER_ROW], _docs.LIST_META),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
    },
    summary="A9: every rights holder, by `sort_order` (nulls last), then name",
    # The rows also show competition and satellite names, so their renames change the tag too.
    dependencies=[Depends(ETag("admin_rights_holders", ("rights_holders", "competitions", "satellites")))],
)
async def list_rights_holders(session: Db) -> Envelope[list[q.AdminRightsHolderRow]]:
    rows = await service.list_rows(session)
    return ok(rows, {"count": len(rows)})


@router.post(
    "/reorder",
    response_model=Envelope[a.BulkResult],
    responses={
        200: {
            "description": "The new order, with each row's new `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("order_ok", ex.BULK_RESULT),
        },
        **_docs.AUTHED,
        409: _docs.EDIT_CONFLICT,
        422: _docs.VALIDATION,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="A9: set the order (each row carries its version)",
)
async def reorder_rights_holders(body: a.OrderRequest, session: Db, admin: Editor, now: Now) -> Envelope[a.BulkResult]:
    result = await ordering.reorder(session, admin, "rights_holders", body, now)
    await session.commit()
    return ok(result)


@router.get(
    "/{holder_id}",
    response_model=Envelope[q.AdminRightsHolder],
    responses={
        200: {
            "description": "The full editor shape, with its `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("rights_holder_ok", ex.RIGHTS_HOLDER),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        404: _NOT_FOUND,
    },
    summary="One rights holder",
)
async def get_rights_holder(
    holder_id: IdPath, request: Request, response: Response, session: Db
) -> Envelope[q.AdminRightsHolder]:
    holder = await service.get(session, holder_id)
    etag = await service.version(session, holder)
    if if_none_match(request.headers.get("if-none-match"), etag):
        raise NotModified(etag)
    set_etag(response, etag)
    return ok(await service.view(session, holder))


@router.post(
    "",
    status_code=201,
    response_model=Envelope[q.AdminRightsHolder],
    responses={
        201: {"description": "Created", **ETAG_HEADER, **_docs.ok_example("rights_holder_ok", ex.RIGHTS_HOLDER)},
        **_docs.AUTHED,
        422: _docs.VALIDATION,
    },
    summary="Create a rights holder (takes no `If-Match`)",
)
async def create_rights_holder(
    body: q.RightsHolderCreate, response: Response, session: Db, admin: Editor
) -> Envelope[q.AdminRightsHolder]:
    holder = await service.create(session, admin, body)
    await session.commit()
    set_etag(response, await service.version(session, holder))
    return ok(await service.view(session, holder))


@router.patch(
    "/{holder_id}",
    response_model=Envelope[q.AdminRightsHolder],
    responses={
        200: {
            "description": "The saved holder, with its new `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("rights_holder_ok", ex.RIGHTS_HOLDER),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
        409: _docs.EDIT_CONFLICT,
        422: _docs.VALIDATION,
        428: _docs.PRECONDITION_REQUIRED,
    },
    summary="Update a rights holder; `competition_ids` and `carriages`, if sent, replace the whole list",
)
async def patch_rights_holder(
    holder_id: IdPath,
    body: q.RightsHolderPatch,
    response: Response,
    session: Db,
    admin: Editor,
    now: Now,
    if_match: IfMatch = None,
) -> Envelope[q.AdminRightsHolder]:
    holder = await service.update(session, admin, holder_id, body, if_match, now)
    await session.commit()
    set_etag(response, await service.version(session, holder))
    return ok(await service.view(session, holder))


@router.delete(
    "/{holder_id}",
    response_model=Envelope[None],
    responses={**_docs.AUTHED, 404: _NOT_FOUND, 409: _docs.EDIT_CONFLICT, 428: _docs.PRECONDITION_REQUIRED},
    summary="Delete a rights holder and its carriages (admin role)",
)
async def delete_rights_holder(
    holder_id: IdPath, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[None]:
    if admin.role != "admin":
        raise forbidden("admin")
    await service.remove(session, admin, holder_id, if_match, now)
    await session.commit()
    return ok(None)
