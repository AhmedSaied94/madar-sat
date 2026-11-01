"""``/admin/api/competitions/order`` and ``/satellites/order``: A6 and A7 (contracts/admin-api.md)."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, Now
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import ordering as service

router = APIRouter(prefix="/admin/api", tags=["ordering"], dependencies=[Depends(require_editor)])

_RESPONSES = {
    200: {
        "description": "The new order, with each row's new `ETag`",
        **ETAG_HEADER,
        **_docs.ok_example("order_ok", ex.BULK_RESULT),
    },
    **_docs.AUTHED,
    409: _docs.EDIT_CONFLICT,
    422: _docs.VALIDATION,
    428: _docs.PRECONDITION_REQUIRED,
}


@router.put(
    "/competitions/order",
    response_model=Envelope[a.BulkResult],
    responses=_RESPONSES,
    summary="A6: set the competition order (each row carries its version)",
)
async def order_competitions(body: a.OrderRequest, session: Db, admin: Editor, now: Now) -> Envelope[a.BulkResult]:
    result = await service.reorder(session, admin, "competitions", body, now)
    await session.commit()
    return ok(result)


@router.put(
    "/satellites/order",
    response_model=Envelope[a.BulkResult],
    responses=_RESPONSES,
    summary="A7: set the satellite order (each row carries its version)",
)
async def order_satellites(body: a.OrderRequest, session: Db, admin: Editor, now: Now) -> Envelope[a.BulkResult]:
    result = await service.reorder(session, admin, "satellites", body, now)
    await session.commit()
    return ok(result)
