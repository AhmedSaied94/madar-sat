"""``/admin/api/sources`` and ``/admin/api/import-runs``: A13 (contracts/admin-api.md).

Pause, resume and «تشغيل الآن» take no ``If-Match``: each sets a state rather than editing a
representation, so a stale copy cannot exist and repeating one is harmless. They are audited, and
pause and resume bump the ``sources`` dataset so the list's ``ETag`` changes.
"""

from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Depends, Path, Query, Request, Response

from app.api.admin import _docs
from app.api.admin._common import ETAG_HEADER, Db, Editor, IdPath, Now
from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.api.errors import NotModified, validator_headers
from app.api.etag import compute_etag, if_none_match
from app.auth.roles import require_editor
from app.schemas import admin as a
from app.schemas import admin_examples as ex
from app.services.admin import sources as service

router = APIRouter(prefix="/admin/api", tags=["sources"], dependencies=[Depends(require_editor)])

_SOURCE_NOT_FOUND = _docs.not_found("source_not_found")
_RUN_NOT_FOUND = _docs.not_found("import_run_not_found")
_NAME = r"^[a-z][a-z0-9_]{0,63}$"
SourceName = Annotated[str, Path(min_length=1, max_length=64, pattern=_NAME)]
RAW_PAGE_MAX = 999

_SOURCE_RESPONSES: dict[int | str, dict[str, Any]] = {
    200: {"description": "The source's health", **_docs.ok_example("source_health_ok", ex.SOURCE_HEALTH)},
    **_docs.AUTHED,
    404: _SOURCE_NOT_FOUND,
}


def send_manual_run(name: str) -> None:
    """Queue ``adapters.schedule_fetch`` by name, so ``api-admin`` imports no adapter code (R12)."""
    from app.workers import app as celery_app

    celery_app.send_task("adapters.schedule_fetch", args=[name], kwargs={"manual": True}, queue="imports")


@router.get(
    "/sources",
    response_model=Envelope[list[a.SourceHealth]],
    responses={
        200: {
            "description": "Sources with their health, and the list's `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("sources_ok", [ex.SOURCE_HEALTH], _docs.LIST_META),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
    },
    summary="A13: every source's health (breaker, pause, running, 24 h counts)",
    dependencies=[Depends(ETag("admin_sources", ("sources",)))],
)
async def list_sources(session: Db, now: Now) -> Envelope[list[a.SourceHealth]]:
    return ok(await service.health(session, now))


@router.post(
    "/sources/{name}/run",
    status_code=202,
    response_model=Envelope[a.SourceRunQueued],
    responses={
        202: {"description": "Queued on `imports`"},
        **_docs.AUTHED,
        404: _SOURCE_NOT_FOUND,
        409: {"description": "`409 run_in_progress` or `409 source_not_runnable`"},
    },
    summary="A13: «تشغيل الآن» — queue one manual run through `adapters.schedule_fetch`",
)
async def run_source(name: SourceName, session: Db, admin: Editor, now: Now) -> Envelope[a.SourceRunQueued]:
    await service.run(session, admin, name, now)
    await session.commit()
    send_manual_run(name)
    return ok(a.SourceRunQueued(queued=True))


@router.post(
    "/sources/{name}/pause",
    response_model=Envelope[a.SourceHealth],
    responses={**_SOURCE_RESPONSES},
    summary="A13: pause a source (audited; bumps `sources`)",
)
async def pause_source(name: SourceName, session: Db, admin: Editor, now: Now) -> Envelope[a.SourceHealth]:
    item = await service.pause(session, admin, name, now)
    await session.commit()
    return ok(item)


@router.post(
    "/sources/{name}/resume",
    response_model=Envelope[a.SourceHealth],
    responses={**_SOURCE_RESPONSES},
    summary="A13: resume a source, reset the breaker and queue one manual run",
)
async def resume_source(name: SourceName, session: Db, admin: Editor, now: Now) -> Envelope[a.SourceHealth]:
    item = await service.resume(session, admin, name, now)
    await session.commit()
    # The live poller has no importer to run: the next scheduler tick picks it up.
    if item.kind not in service.LIVE_KINDS:
        send_manual_run(name)
    return ok(item)


@router.get(
    "/sources/{name}/runs",
    response_model=Envelope[list[a.ImportRunRow]],
    responses={
        200: {
            "description": "Runs, newest first, with the list's `ETag`",
            **ETAG_HEADER,
            **_docs.ok_example("source_runs_ok", [ex.IMPORT_RUN_ROW], {**_docs.LIST_META, "next_cursor": None}),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        404: _SOURCE_NOT_FOUND,
    },
    summary="A13: a source's run history (keyset cursor)",
    dependencies=[Depends(ETag("admin_source_runs", ("sources",)))],
)
async def list_source_runs(
    name: SourceName,
    session: Db,
    cursor: Annotated[str | None, Query(max_length=200)] = None,
    limit: Annotated[int, Query(ge=1, le=service.RUNS_MAX_LIMIT)] = 20,
) -> Envelope[list[a.ImportRunRow]]:
    rows, next_cursor = await service.runs(session, name, cursor, limit)
    return ok(rows, {"next_cursor": next_cursor})


@router.get(
    "/import-runs/{run_id}",
    response_model=Envelope[a.ImportRunDetail],
    responses={
        200: {
            "description": "The run and its compact log",
            **ETAG_HEADER,
            **_docs.ok_example("import_run_ok", ex.IMPORT_RUN_DETAIL),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        404: _RUN_NOT_FOUND,
    },
    summary="A13: one run with the log written by ingest",
    dependencies=[Depends(ETag("admin_import_run", ("sources",)))],
)
async def get_import_run(run_id: IdPath, session: Db) -> Envelope[a.ImportRunDetail]:
    return ok(await service.run_detail(session, run_id))


@router.get(
    "/import-runs/{run_id}/raw",
    response_model=Envelope[a.RawPage],
    responses={
        200: {
            "description": "`pending` (poll again, up to 10 s), `ready` or `gone` (pruned, or none was saved)",
            **ETAG_HEADER,
            **_docs.ok_example("raw_page_ok", ex.RAW_PAGE),
        },
        **_docs.AUTHED,
        304: _docs.NOT_MODIFIED,
        404: _RUN_NOT_FOUND,
        422: _docs.VALIDATION,
    },
    summary="A13: a run's saved page as inert text; the path comes from the run, never the request",
)
async def get_import_run_raw(
    run_id: IdPath,
    request: Request,
    response: Response,
    session: Db,
    page: Annotated[int, Query(ge=0, le=RAW_PAGE_MAX)] = 0,
) -> Envelope[a.RawPage]:
    item = await service.raw_page(session, run_id, page)
    # Built from the state, so a `pending` tag never matches a `ready` one.
    etag = compute_etag("admin_import_run_raw", {"page": page, "state": item.state}, {}, path=request.url.path)
    if if_none_match(request.headers.get("if-none-match"), etag):
        raise NotModified(etag)
    response.headers.update(validator_headers(etag))
    return ok(item)
