"""``/admin/api/unresolved-names``: A13's queue (005 contracts/admin-api.md)."""

from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Depends, Query

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, IfMatch, Now
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.auth.roles import require_editor
from app.schemas import admin_examples as ex
from app.schemas import admin_queue as q
from app.services.admin import unresolved_names as service

router = APIRouter(
    prefix="/admin/api/unresolved-names", tags=["unresolved-names"], dependencies=[Depends(require_editor)]
)

_NOT_FOUND = _docs.not_found("unresolved_name_not_found")
_ALIAS_CONFLICT = _docs.error_value("alias_conflict")
_NAME = r"^[a-z][a-z0-9_]{0,63}$"
_DECISION_RESPONSES: dict[int | str, dict[str, Any]] = {
    200: {"description": "The decided row, with its new `etag`", **_docs.ok_example("name_ok", ex.UNRESOLVED_NAME)},
    **_docs.AUTHED,
    404: _NOT_FOUND,
    409: _docs.EDIT_CONFLICT,
    428: _docs.PRECONDITION_REQUIRED,
}


@router.get(
    "",
    response_model=Envelope[list[q.UnresolvedNameRow]],
    responses={
        200: {
            "description": "Names, newest sighting first. `meta.open_count` is every open row, whatever the filters",
            **ETAG_HEADER,
            **_docs.ok_example(
                "names_ok", [ex.UNRESOLVED_NAME], {**_docs.LIST_META, "next_cursor": None, "open_count": 1}
            ),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        422: _docs.VALIDATION,
    },
    summary="A13: the names the importers couldn't match",
    dependencies=[Depends(ETag("admin_unresolved_names", ("unresolved_names",)))],
)
async def list_names(
    session: Db,
    source: Annotated[str | None, Query(max_length=64, pattern=_NAME)] = None,
    kind: q.UnresolvedKind | None = None,
    state: q.UnresolvedState = "open",
    cursor: Annotated[str | None, Query(max_length=400)] = None,
    limit: Annotated[int, Query(ge=1, le=service.MAX_LIMIT)] = service.DEFAULT_LIMIT,
) -> Envelope[list[q.UnresolvedNameRow]]:
    rows, next_cursor, open_count = await service.list_names(
        session, source=source, kind=kind, state=state, cursor=cursor, limit=limit
    )
    return ok(rows, {"count": len(rows), "next_cursor": next_cursor, "open_count": open_count})


@router.post(
    "/{name_id}/map",
    response_model=Envelope[q.UnresolvedNameRow],
    responses={
        **_DECISION_RESPONSES,
        404: _docs.error_response(
            "Unknown row or target",
            unresolved_name_not_found=_docs.error_value("unresolved_name_not_found"),
            team_not_found=_docs.error_value("team_not_found"),
        ),
        409: _docs.error_response(
            "`If-Match` is stale, the row isn't open, or the alias already points elsewhere",
            edit_conflict=_docs.error_value("edit_conflict"),
            alias_conflict=_ALIAS_CONFLICT,
        ),
        422: _docs.VALIDATION,
    },
    summary="Map a name to an entity: writes the alias, used from the next run",
)
async def map_name(
    name_id: IdPath, body: q.UnresolvedMap, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[q.UnresolvedNameRow]:
    row = await service.map_name(session, admin, name_id, body, if_match, now)
    await session.commit()
    return ok(row)


@router.post(
    "/{name_id}/ignore",
    response_model=Envelope[q.UnresolvedNameRow],
    responses=_DECISION_RESPONSES,
    summary="Ignore a name; later runs don't reopen it",
)
async def ignore_name(
    name_id: IdPath, session: Db, admin: Editor, now: Now, if_match: IfMatch = None
) -> Envelope[q.UnresolvedNameRow]:
    row = await service.ignore_name(session, admin, name_id, if_match, now)
    await session.commit()
    return ok(row)
