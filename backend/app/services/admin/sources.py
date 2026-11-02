"""A13's source health, pause, resume, run and run history (research R12, contracts/admin-api.md).

Health is read from ``import_runs`` (last 24 h) and from the job locks in Redis; pause, resume and
run are audited through D2's writer, and pause and resume bump the ``sources`` dataset so the
existing ``ETag("admin_sources", ("sources",))`` changes. The runs list and run detail take their
``ETag`` from ``sources`` too.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timedelta
from typing import Any, cast

import redis.asyncio as aioredis
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.errors import EntityNotFound, run_in_progress, source_not_runnable
from app.auth.roles import AuthedAdmin
from app.db.models import ImportRun, Source
from app.schemas import admin as a
from app.services.admin import lists, writer
from app.settings import get_settings

log = logging.getLogger("madar.admin")

ENTITY = "source"
WINDOW = timedelta(hours=24)
SPARKLINE_POINTS = 24
RUNS_MAX_LIMIT = 50


def _redis() -> aioredis.Redis:
    return cast(aioredis.Redis, aioredis.from_url(get_settings().redis_url))  # type: ignore[no-untyped-call]


def run_row(run: ImportRun) -> a.ImportRunRow:
    return a.ImportRunRow(
        id=run.id,
        status=run.status,
        started_at=run.started_at,
        finished_at=run.finished_at,
        items_found=run.items_found,
        items_upserted=run.items_upserted,
        http_errors=run.http_errors,
        error=run.error,
    )


def _paused(source: Source, now: datetime) -> bool:
    return (
        not source.is_enabled
        or source.breaker_opened_at is not None
        or (source.paused_until is not None and source.paused_until > now)
    )


def _health(
    source: Source,
    now: datetime,
    last_run: ImportRun | None,
    window_runs: list[ImportRun],
    running: bool,
) -> a.SourceHealth:
    failures = sum(1 for run in window_runs if run.status == "failed")
    rate = (failures / len(window_runs)) if window_runs else None
    return a.SourceHealth(
        name=source.name,
        kind=source.kind,
        is_enabled=source.is_enabled,
        breaker="open" if source.breaker_opened_at is not None else "closed",
        breaker_opened_at=source.breaker_opened_at,
        consecutive_failures=source.consecutive_failures,
        paused=_paused(source, now),
        last_success_at=source.last_success_at,
        last_run=run_row(last_run) if last_run is not None else None,
        items_24h=[run.items_found for run in window_runs[-SPARKLINE_POINTS:]],
        error_rate_24h=rate,
        running=running,
    )


async def health(session: AsyncSession, now: datetime, name: str | None = None) -> list[a.SourceHealth]:
    """Every source's health, or one source's (``None`` when it doesn't exist)."""
    query = select(Source).order_by(Source.name)
    if name is not None:
        query = query.where(Source.name == name)
    sources = list((await session.scalars(query)).all())
    if not sources:
        return []

    names = [source.name for source in sources]
    since = now - WINDOW
    runs = list(
        (
            await session.scalars(
                select(ImportRun)
                .where(ImportRun.source.in_(names), ImportRun.started_at >= since)
                .order_by(ImportRun.started_at, ImportRun.id)
            )
        ).all()
    )
    newest_ids = select(func.max(ImportRun.id)).where(ImportRun.source.in_(names)).group_by(ImportRun.source)
    latest = {
        run.source: run for run in (await session.scalars(select(ImportRun).where(ImportRun.id.in_(newest_ids)))).all()
    }
    by_source: dict[str, list[ImportRun]] = {source_name: [] for source_name in names}
    for run in runs:
        by_source[run.source].append(run)

    running = await _running(names)
    return [
        _health(source, now, latest.get(source.name), by_source[source.name], source.name in running)
        for source in sources
    ]


async def _running(names: list[str]) -> set[str]:
    """``EXISTS lock:fetch:<name> OR lock:ingest:<name>``; a Redis outage reports nothing running."""
    if not names:
        return set()
    client = _redis()
    try:
        async with client.pipeline(transaction=False) as pipe:
            for name in names:
                pipe.exists(f"lock:fetch:{name}", f"lock:ingest:{name}")
            answers = await pipe.execute()
        return {name for name, held in zip(names, answers, strict=True) if held}
    except Exception:  # noqa: BLE001
        log.warning("source_locks_unavailable")
        return set()
    finally:
        await client.aclose()


async def get(session: AsyncSession, name: str) -> Source:
    source = await session.get(Source, name)
    if source is None:
        raise EntityNotFound("source_not_found")
    return source


def _bridge_configured() -> bool:
    """``legacy`` runs only when the Sat Air bridge is configured (contracts/admin-api.md)."""
    return bool(os.environ.get("SATAIR_FIREBASE_PROJECT_ID") and os.environ.get("SATAIR_FIREBASE_API_KEY"))


async def check_runnable(session: AsyncSession, name: str) -> Source:
    """The source, if a run makes sense now: runnable kind, and its lock is free."""
    source = await get(session, name)
    if source.kind == "internal" and not (source.name == "legacy" and _bridge_configured()):
        raise source_not_runnable()
    if await _lock_held(source.name):
        raise run_in_progress()
    return source


async def _lock_held(name: str) -> bool:
    client = _redis()
    try:
        return bool(await client.exists(f"lock:fetch:{name}", f"lock:ingest:{name}"))
    except Exception:  # noqa: BLE001 - a Redis outage must not block «تشغيل الآن»
        log.warning("source_locks_unavailable")
        return False
    finally:
        await client.aclose()


async def run(session: AsyncSession, admin: AuthedAdmin, name: str, now: datetime) -> a.SourceHealth:
    """Audit and return the source's health; the router queues the manual run after the commit."""
    await check_runnable(session, name)
    writer.add_audit(session, admin, ENTITY, None, "update", {"run": [None, now.isoformat()]})
    await writer.bump_datasets(session, ("sources",))
    await session.flush()
    [item] = await health(session, now, name)
    return item


async def pause(session: AsyncSession, admin: AuthedAdmin, name: str, now: datetime) -> a.SourceHealth:
    source = await get(session, name)
    if source.is_enabled:
        source.is_enabled = False
        source.updated_at = now
        writer.add_audit(session, admin, ENTITY, None, "update", {"is_enabled": [True, False]})
        await writer.bump_datasets(session, ("sources",))
    await session.flush()
    [item] = await health(session, now, name)
    return item


async def resume(session: AsyncSession, admin: AuthedAdmin, name: str, now: datetime) -> a.SourceHealth:
    """Re-enable, reset the four health fields, audit and bump; the router queues one manual run."""
    source = await get(session, name)
    diff: dict[str, list[Any]] = {
        "is_enabled": [source.is_enabled, True],
        "consecutive_failures": [source.consecutive_failures, 0],
        "breaker_opened_at": [
            source.breaker_opened_at.isoformat() if source.breaker_opened_at else None,
            None,
        ],
        "paused_until": [source.paused_until.isoformat() if source.paused_until else None, None],
    }
    source.is_enabled = True
    source.consecutive_failures = 0
    source.breaker_opened_at = None
    source.paused_until = None
    source.updated_at = now
    if any(before != after for before, after in diff.values()):
        writer.add_audit(session, admin, ENTITY, None, "update", diff)
        await writer.bump_datasets(session, ("sources",))
    await session.flush()
    [item] = await health(session, now, name)
    return item


async def runs(
    session: AsyncSession, name: str, cursor: str | None, limit: int
) -> tuple[list[a.ImportRunRow], str | None]:
    """Newest first, keyset by id."""
    await get(session, name)
    query = select(ImportRun).where(ImportRun.source == name).order_by(ImportRun.id.desc())
    if cursor is not None:
        [last_id] = lists.decode_cursor(cursor, 1)
        query = query.where(ImportRun.id < last_id)
    found = list((await session.scalars(query.limit(limit + 1))).all())
    rows = found[:limit]
    next_cursor = lists.encode_cursor([rows[-1].id]) if len(found) > limit else None
    return [run_row(run) for run in rows], next_cursor


async def run_detail(session: AsyncSession, run_id: int) -> a.ImportRunDetail:
    run = await session.get(ImportRun, run_id)
    if run is None:
        raise EntityNotFound("import_run_not_found")
    return a.ImportRunDetail(
        **run_row(run).model_dump(),
        raw_path=run.raw_path,
        log=run.log,
        log_available=run.log is not None,
    )


async def count_placeholders(session: AsyncSession) -> int:
    """A2's tile: channels with ``placeholder_source`` that are not deleted."""
    from app.db.models import Channel

    return int(
        await session.scalar(
            select(func.count(Channel.id)).where(Channel.placeholder_source.is_not(None), Channel.deleted_at.is_(None))
        )
        or 0
    )
