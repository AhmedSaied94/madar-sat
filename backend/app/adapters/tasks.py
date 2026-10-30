"""The ingestion tasks: fetch → message → ingest, prune, and the post-commit logo queue (T075, R15).

The fetch half runs on the owner's home box, which has Redis and nothing else: importing this
module, building the fetcher and running ``adapters.fetch`` never touch ``app.db`` or
``app.settings`` (FR-028, research R21). ``ingest``, ``prune_raw_pages`` and the media task import
the database and the pipeline inside their bodies, so the home box never loads them.

``fetch`` takes ``lock:fetch:<source>``, fetches, parses and sends one versioned ``ScrapeResult``
to ``imports``. ``ingest`` takes ``lock:ingest:<source>``, saves the raw pages, writes the
``import_runs`` row, normalizes, resolves, upserts, bumps once, and queues logo rehosts after the
commit.
"""

from __future__ import annotations

import logging
import secrets
import socket
from collections.abc import Sequence
from datetime import UTC, date, datetime
from typing import Any

import redis

from app.adapters.base import DateWindow, SourceAdapter
from app.adapters.config import get_adapter_settings
from app.adapters.fetcher import HttpFetcher
from app.adapters.messages import ScrapeResult
from app.adapters.ratelimit import RateLimiter
from app.adapters.satair_bridge import BridgeNotConfigured, LayoutChanged, SatairBridgeAdapter
from app.adapters.ysscores import YsscoresAdapter
from app.domain.time import CAIRO
from app.workers import app as celery_app
from app.workers import task
from app.workers.config import get_worker_settings
from app.workers.locks import redis_lock

log = logging.getLogger(__name__)

FETCH_LOCK_TTL = 30 * 60
INGEST_LOCK_TTL = 60 * 60
FETCH_EXPIRES = 2 * 60 * 60  # a box that was offline must not replay a stale fetch (R21)
LOGO_QUEUE = "media"
INGEST_QUEUE = "imports"
PRUNE_QUEUE = "maintenance"


class IngestionRouter:
    """Where each ingestion task belongs (contracts/ingestion.md §Queues).

    ``adapters.fetch`` is the one task whose queue depends on its argument: ysscores is fetched by
    the home box (``scrape_home``) unless ``YSSCORES_FETCH_QUEUE`` says VPS-2, and the bridge
    always runs on VPS-2. Registered here, so an on-demand ``celery call`` lands on the same queue
    as the beat entry.
    """

    def route_for_task(
        self,
        name: str,
        args: tuple[Any, ...] | None = None,
        kwargs: dict[str, Any] | None = None,
        options: dict[str, Any] | None = None,
        task: Any = None,
        **kw: Any,
    ) -> dict[str, str] | None:
        if name == "adapters.fetch":
            source = (args[0] if args else (kwargs or {}).get("source")) or ""
            if source == "legacy":
                return {"queue": "scrape"}
            if source == "ysscores":
                return {"queue": get_adapter_settings().ysscores_fetch_queue}
            return None
        routes = {
            "adapters.ingest": INGEST_QUEUE,
            "adapters.prune_raw_pages": PRUNE_QUEUE,
            "adapters.rehost_logo": LOGO_QUEUE,
        }
        queue = routes.get(name)
        return {"queue": queue} if queue else None


# The worker imports this module through ``include``, before it publishes anything.
celery_app.conf.task_routes = (IngestionRouter(),)


def now_utc() -> datetime:
    return datetime.now(UTC)


def run_id(source: str, started_at: datetime) -> str:
    """``2026-10-31T03:00:00Z-ysscores-7f3a`` (contracts/ingestion.md)."""
    return f"{started_at.strftime('%Y-%m-%dT%H:%M:%SZ')}-{source}-{secrets.token_hex(2)}"


def redis_client() -> redis.Redis:
    return redis.Redis.from_url(get_worker_settings().broker_url)


def http_fetcher() -> HttpFetcher:
    """The one HTTP client the adapters use; a seam the tests replace with a mock transport."""
    return HttpFetcher(
        limiter=RateLimiter(client=redis_client()), user_agent=get_adapter_settings().require_user_agent()
    )


def adapter_for(source: str, fetcher: HttpFetcher | None = None) -> SourceAdapter:
    if source == "ysscores":
        return YsscoresAdapter(fetcher=fetcher)
    if source == "legacy":
        return SatairBridgeAdapter(fetcher=fetcher)
    raise ValueError(f"unknown source {source!r}")


def send_ingest(result: ScrapeResult) -> None:
    ingest.apply_async(args=[result.as_task_arg()], queue=INGEST_QUEUE)


@task(name="adapters.fetch", expires=FETCH_EXPIRES)
def fetch(self: Any, source: str, start: str | None = None) -> dict[str, Any]:
    """Fetch and parse one source, then hand a ``ScrapeResult`` to ``ingest`` (R15, R16, R19)."""
    started = now_utc()
    today = date.fromisoformat(start) if start else datetime.now(CAIRO).date()
    with redis_lock(f"lock:fetch:{source}", FETCH_LOCK_TTL, client=redis_client()) as acquired:
        if not acquired:
            log.info("skipped", extra={"task": "adapters.fetch", "source": source, "why": "lock_held"})
            return {"source": source, "skipped": True}

        fetcher = http_fetcher()
        pages = []
        try:
            adapter = adapter_for(source, fetcher)
            window = DateWindow.next_days(today=today)
            pages = list(adapter.fetch(window))
            items = [item for page in pages for item in adapter.parse(page)]
            result = ScrapeResult.build(
                source=source,
                run_id=run_id(source, started),
                started_at=started,
                finished_at=now_utc(),
                fetched_on=socket.gethostname(),
                pages=pages,
                items=items,
            )
        except LayoutChanged as exc:
            result = _failed(source, started, pages, http_errors=0, error="layout_changed")
            log.warning("layout_changed", extra={"source": source, "why": str(exc)})
        except BridgeNotConfigured:
            result = _failed(source, started, pages, http_errors=0, error="bridge_not_configured")
            log.error("bridge_not_configured", extra={"source": source})
        finally:
            fetcher.close()

        send_ingest(result)
        log.info(
            "fetched",
            extra={"source": source, "pages": len(result.pages), "items": len(result.items), "run": result.run_id},
        )
        return {"source": source, "run_id": result.run_id, "pages": len(result.pages), "items": len(result.items)}


def _failed(source: str, started: datetime, pages: Sequence[Any], *, http_errors: int, error: str) -> ScrapeResult:
    """A failed fetch still travels, with the pages it did collect, so the run row records it (R15)."""
    return ScrapeResult.build(
        source=source,
        run_id=run_id(source, started),
        started_at=started,
        finished_at=now_utc(),
        fetched_on=socket.gethostname(),
        pages=list(pages),
        items=[],
        http_errors=http_errors,
        error=error,
    )


@task(name="adapters.ingest")
def ingest(self: Any, result: dict[str, Any]) -> dict[str, Any]:
    """Save the pages, write the run row, then normalize, resolve and upsert (R15, R18)."""
    # Imported here: the home box never runs this task, so it never loads the database.
    from app.adapters.raw_store import RawStore
    from app.adapters.upsert import UpsertPipeline
    from app.db.models import ImportRun
    from app.db.session import SyncSession
    from app.settings import get_settings

    data = ScrapeResult.model_validate(result)  # an unknown schema raises here, loudly
    with redis_lock(f"lock:ingest:{data.source}", INGEST_LOCK_TTL, client=redis_client()) as acquired:
        if not acquired:
            log.info("skipped", extra={"task": "adapters.ingest", "source": data.source, "why": "lock_held"})
            return {"source": data.source, "skipped": True}

        settings = get_settings()
        store = RawStore(get_adapter_settings().raw_root)
        with SyncSession() as session:
            run = ImportRun(
                source=data.source,
                started_at=data.started_at,
                items_found=len(data.items),
                http_errors=data.http_errors,
                error=data.error,
                status="running",
            )
            session.add(run)
            session.commit()

            run_dir = store.save(
                source=data.source,
                run_day=data.started_at.date(),
                run_id=data.run_id,
                pages=data.raw_pages(),
                run_info={"counts": {"items_found": len(data.items), "http_errors": data.http_errors}},
            )
            run.raw_path = str(run_dir)

            adapter = adapter_for(data.source)
            outcome = None
            if data.error or not data.pages:
                run.status = "failed"
            elif _source_is_paused(session, data.source):
                run.status = "succeeded"
                log.info("source_paused", extra={"source": data.source, "run": data.run_id})
            else:
                normalized = [adapter.normalize(item) for item in data.items]
                pipeline = UpsertPipeline(session, source=data.source, media_hosts=settings.media_rehost_allowed_hosts)
                outcome = pipeline.run(normalized)
                run.status = "partial" if outcome.skipped else "succeeded"
                run.items_upserted = outcome.items_upserted
                run.matches_imported = outcome.items_upserted
                run.items_found = outcome.items_found

            _write_run_json(store, run_dir, data, outcome)
            session.commit()
            jobs = outcome.logo_jobs if outcome is not None else []
            log.info(
                "ingested",
                extra={
                    "source": data.source,
                    "run": data.run_id,
                    "status": run.status,
                    "upserted": run.items_upserted,
                    "skipped": len(outcome.skipped) if outcome else 0,
                },
            )

        # After the commit: a worker that dies here only loses a logo, never a fixture (R20).
        if jobs:
            from app.adapters.media_tasks import rehost_logo

            for job in jobs:
                rehost_logo.apply_async(args=[job.entity, job.entity_id, job.url, job.source], queue=LOGO_QUEUE)
        return {
            "source": data.source,
            "run_id": data.run_id,
            "status": run.status,
            "items_upserted": run.items_upserted,
            "logo_jobs": len(jobs),
        }


def _source_is_paused(session: Any, source: str) -> bool:
    """``sources.is_enabled`` / ``paused_until``: read here, on VPS-2, because the box has no database."""
    from sqlalchemy import select

    from app.db.models import Source

    row = session.execute(select(Source.is_enabled, Source.paused_until).where(Source.name == source)).first()
    if row is None:
        return False
    enabled, paused_until = row
    if not enabled:
        return True
    return bool(paused_until is not None and paused_until > now_utc())


def _write_run_json(store: Any, run_dir: Any, data: ScrapeResult, outcome: Any) -> None:
    """``run.json`` beside the pages: counts, skipped items and unresolved names (R15)."""
    import json

    info = {
        "counts": {
            "items_found": outcome.items_found if outcome is not None else len(data.items),
            "items_upserted": outcome.items_upserted if outcome is not None else 0,
            "http_errors": data.http_errors,
            "created": outcome.created if outcome is not None else 0,
            "updated": outcome.updated if outcome is not None else 0,
            "unchanged": outcome.unchanged if outcome is not None else 0,
        },
        "skipped": outcome.skipped if outcome is not None else [],
        "unresolved": outcome.unresolved if outcome is not None else [],
        "error": data.error,
    }
    (run_dir / "run.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")


@task(name="adapters.prune_raw_pages")
def prune_raw_pages(self: Any) -> dict[str, Any]:
    """Delete raw run folders older than 5 days (constitution VII)."""
    from app.adapters.raw_store import RawStore

    removed = RawStore(get_adapter_settings().raw_root).prune_raw_pages()
    log.info("pruned_raw_pages", extra={"removed": removed})
    return {"removed": removed}
