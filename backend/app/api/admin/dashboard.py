"""``/admin/api/dashboard``: A2 (contracts/admin-api.md)."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Now
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import dashboard as service

router = APIRouter(prefix="/admin/api", tags=["dashboard"], dependencies=[Depends(require_editor)])


@router.get(
    "/dashboard",
    response_model=Envelope[a.Dashboard],
    responses={
        200: {
            "description": "The dashboard, with its `ETag` (a 60 s bucket for `recent_changes`)",
            **ETAG_HEADER,
            **_docs.ok_example("dashboard_ok", ex.DASHBOARD),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        422: _docs.VALIDATION,
    },
    summary="A2: today's matches without a channel, placeholders, sources and recent changes",
    dependencies=[Depends(ETag("admin_dashboard", ("matches", "channels", "sources"), bucket_s=60))],
)
async def get_dashboard(
    session: Db,
    now: Now,
    from_dt: Annotated[datetime, Query(alias="from", description="UTC; `to - from` is at most 2 days")],
    to_dt: Annotated[datetime, Query(alias="to")],
) -> Envelope[a.Dashboard]:
    return ok(await service.dashboard(session, now, from_dt, to_dt))
