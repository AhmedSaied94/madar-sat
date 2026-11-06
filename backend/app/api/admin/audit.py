"""``/admin/api/audit``: A17, the read side of the log (contracts/admin-api.md).

Read-only (FR-026): the two ``GET``s and nothing else. Admin role only; the ``ETag`` is a 30 s
bucket over every dataset because six writers add audit rows and not all bump a name (research R20).
"""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, IdPath
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.auth.roles import require_admin
from app.db.models import DATASET_NAMES
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import audit as service

router = APIRouter(prefix="/admin/api/audit", tags=["audit"], dependencies=[Depends(require_admin)])

_NOT_FOUND = _docs.not_found("audit_not_found")
_LIMIT = Annotated[int, Query(ge=1, le=100, description="Page size; the default is 50")]
_NAME = Annotated[str | None, Query(min_length=1, max_length=64)]


@router.get(
    "",
    response_model=Envelope[list[a.AuditRow]],
    responses={
        200: {
            "description": "Newest first, with the list's `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("audit_ok", [ex.AUDIT_ROW], _docs.PAGE_META),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        422: _docs.VALIDATION,
    },
    summary="A17: the audit log, by actor, entity or window",
    dependencies=[Depends(ETag("admin_audit", DATASET_NAMES, bucket_s=30))],
)
async def list_audit_entries(
    session: Db,
    admin_user_id: Annotated[int | None, Query(ge=1)] = None,
    source: _NAME = None,
    entity: _NAME = None,
    entity_id: Annotated[int | None, Query(ge=1, le=2**63 - 1)] = None,
    from_dt: Annotated[datetime | None, Query(alias="from")] = None,
    to_dt: Annotated[datetime | None, Query(alias="to")] = None,
    cursor: Annotated[str | None, Query(max_length=200)] = None,
    limit: _LIMIT = 50,
) -> Envelope[list[a.AuditRow]]:
    items, next_cursor = await service.entries(
        session,
        admin_user_id=admin_user_id,
        source=source,
        entity=entity,
        entity_id=entity_id,
        from_dt=from_dt,
        to_dt=to_dt,
        cursor=cursor,
        limit=limit,
    )
    return ok(items, {"next_cursor": next_cursor})


@router.get(
    "/{audit_id}",
    response_model=Envelope[a.AuditDetail],
    responses={
        200: {
            "description": "The row, its stored `diff` and the push it started",
            **_docs.ok_example("audit_detail_ok", ex.AUDIT_DETAIL),
        },
        **_docs.AUTHED,
        404: _NOT_FOUND,
    },
    summary="A17: one entry with its diff and its notification",
)
async def get_audit_entry(audit_id: IdPath, session: Db) -> Envelope[a.AuditDetail]:
    return ok(await service.entry(session, audit_id))
