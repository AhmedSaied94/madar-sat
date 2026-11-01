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

import httpx
import redis

from app.adapters.base import DateWindow, LayoutChanged, SourceAdapter
from app.adapters.config import get_adapter_settings
from app.adapters.fetcher import FetchError, HttpFetcher
from app.adapters.livesoccertv import (
    NAME as LIVESOCCERTV,
)
from app.adapters.livesoccertv import (
    LivesoccertvAdapter,
    LivesoccertvTarget,
    plan_targets,
    store_plan_log,
    targets_from_args,
)
from app.adapters.messages import KIND_BROADCASTS, KIND_FIXTURES, Kind, MessageTooLarge, ScrapeResult
from app.adapters.ratelimit import RateLimiter
from app.adapters.satair_bridge import BridgeNotConfigured, SatairBridgeAdapter
from app.adapters.ysscores import YsscoresAdapter
from app.domain.time import CAIRO
from app.workers import app as celery_app
from app.workers import task
from app.workers.base import Retryable
from app.workers.config import get_worker_settings
from app.workers.locks import redis_lock

log = logging.getLogger(__name__)

FETCH_LOCK_TTL = 30 * 60
INGEST_LOCK_TTL = 60 * 60
FETCH_EXPIRES = 2 * 60 * 60  # a box that was offline must not replay a stale fetch (R21)
LOGO_QUEUE = "media"
INGEST_QUEUE = "imports"
IMPORT_SCHEDULE_QUEUE = "imports"
PRUNE_QUEUE = "maintenance"
HEARTBEAT_QUEUES = ("maintenance", "imports", "notifications")
# The compact run log A13 reads from VPS-1; ``import_runs.log`` is 0005's column (R12, T060).
MAX_LOG_BYTES = 64 * 1024
MAX_LOG_ITEMS = 20


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
            if source == "livesoccertv":
                return {"queue": get_adapter_settings().livesoccertv_fetch_queue}
            return None
        if name == "ops.heartbeat":
            queue = (args[0] if args else (kwargs or {}).get("queue")) or ""
            return {"queue": queue} if queue in HEARTBEAT_QUEUES else None
        routes = {
            "adapters.schedule_fetch": IMPORT_SCHEDULE_QUEUE,
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
    if source == LIVESOCCERTV:
        return LivesoccertvAdapter(fetcher=fetcher)
    raise ValueError(f"unknown source {source!r}")


def send_ingest(result: ScrapeResult) -> None:
    ingest.apply_async(args=[result.as_task_arg()], queue=INGEST_QUEUE)


@task(name="adapters.fetch", expires=FETCH_EXPIRES)
def fetch(
    self: Any, source: str, start: str | None = None, targets: list[dict[str, Any]] | None = None
) -> dict[str, Any]:
    """Fetch and parse one source, then hand a ``ScrapeResult`` to ``ingest`` (R15, R16, R19).

    LiveSoccerTV gets its targets from ``adapters.schedule_fetch``: the home box has no database to
    plan with, so a fetch without targets is a no-op (R14).
    """
    started = now_utc()
    with redis_lock(f"lock:fetch:{source}", FETCH_LOCK_TTL, client=redis_client()) as acquired:
        if not acquired:
            log.info("skipped", extra={"task": "adapters.fetch", "source": source, "why": "lock_held"})
            return {"source": source, "skipped": True}

        # The setup is inside the guard too: a missing `SCRAPE_USER_AGENT`, a bad `start` or an
        # unknown source is a failed run, and it still owes the `import_runs` row (B2-R3-1).
        fetcher: HttpFetcher | None = None
        adapter: SourceAdapter | None = None
        pages: list[Any] = []
        planned: list[LivesoccertvTarget] = []
        kind = KIND_BROADCASTS if source == LIVESOCCERTV else KIND_FIXTURES
        try:
            if source == LIVESOCCERTV:
                planned = targets_from_args(targets)
                if not planned:
                    log.info("skipped", extra={"task": "adapters.fetch", "source": source, "why": "no_targets"})
                    return {"source": source, "skipped": True, "why": "no_targets"}
            today = date.fromisoformat(start) if start else datetime.now(CAIRO).date()
            fetcher = http_fetcher()
            adapter = adapter_for(source, fetcher)
            window = DateWindow.next_days(today=today)
            if source == LIVESOCCERTV:
                assert isinstance(adapter, LivesoccertvAdapter)
                pages = list(adapter.fetch(window, targets=planned))
                items: list[Any] = list(adapter.items)
                unmatched = list(adapter.unmatched)
            else:
                pages = list(adapter.fetch(window))
                items = [item for page in pages for item in adapter.parse(page)]
                unmatched = []
            result = ScrapeResult.build(
                source=source,
                run_id=run_id(source, started),
                started_at=started,
                finished_at=now_utc(),
                fetched_on=socket.gethostname(),
                pages=pages,
                items=items,
                kind=kind,
                targets=len(planned) if source == LIVESOCCERTV else None,
                unmatched=unmatched,
            )
        except LayoutChanged as exc:
            # Every adapter's layout change lands here, with the pages it did fetch (B2-R1-9).
            result = _failed(
                source,
                started,
                _pages_of(adapter),
                http_errors=_http_errors_of(fetcher),
                error="layout_changed",
                kind=kind,
                targets=len(planned),
            )
            log.warning("layout_changed", extra={"source": source, "why": str(exc), "pages": len(_pages_of(adapter))})
        except BridgeNotConfigured:
            result = _failed(
                source, started, _pages_of(adapter), http_errors=0, error="bridge_not_configured", kind=kind
            )
            log.error("bridge_not_configured", extra={"source": source})
        except Retryable as exc:
            if self.request.retries < self.max_retries:
                raise  # Celery backs off and runs the fetch again (403, 429, 5xx, an empty bucket)
            result = _failed(
                source,
                started,
                _pages_of(adapter),
                http_errors=_http_errors_of(fetcher),
                error="retries_exhausted",
                kind=kind,
                targets=len(planned),
            )
            log.error("retries_exhausted", extra={"source": source, "why": str(exc)})
        except httpx.TransportError as exc:
            # `autoretry_for` retries these; the last attempt still owes the run row (B2-R2-6).
            if self.request.retries < self.max_retries:
                raise
            log.error("transport_error", extra={"source": source, "why": repr(exc)})
            _send_failure(
                source, started, _pages_of(adapter), _http_errors_of(fetcher), "transport_error", kind, len(planned)
            )
            raise
        except FetchError as exc:
            # A 404/400, a host off the allowlist, an oversized body or too many redirects: no retry.
            result = _failed(
                source,
                started,
                _pages_of(adapter),
                http_errors=_http_errors_of(fetcher),
                error="fetch_failed",
                kind=kind,
                targets=len(planned),
            )
            log.error("fetch_failed", extra={"source": source, "why": str(exc), "status": exc.status})
        except Exception as exc:
            # A bug, a pydantic ValidationError, a message over its cap, a missing setting: the run
            # row must say so.
            log.error("fetch_error", extra={"source": source, "why": repr(exc)}, exc_info=True)
            _send_failure(
                source, started, _pages_of(adapter), _http_errors_of(fetcher), "fetch_error", kind, len(planned)
            )
            raise
        finally:
            if fetcher is not None:
                fetcher.close()

        send_ingest(result)
        log.info(
            "fetched",
            extra={"source": source, "pages": len(result.pages), "items": len(result.items), "run": result.run_id},
        )
        return {"source": source, "run_id": result.run_id, "pages": len(result.pages), "items": len(result.items)}


def _pages_of(adapter: SourceAdapter | None) -> list[Any]:
    return list(adapter.pages) if adapter is not None else []


def _http_errors_of(fetcher: HttpFetcher | None) -> int:
    return fetcher.http_errors if fetcher is not None else 0


def _failed(
    source: str,
    started: datetime,
    pages: Sequence[Any],
    *,
    http_errors: int,
    error: str,
    kind: Kind = KIND_FIXTURES,
    targets: int = 0,
) -> ScrapeResult:
    """A failed fetch still travels, with the pages it did collect, so the run row records it (R15).

    The pages are dropped when they would trip the message's caps: the failure is what must arrive
    (B2-R2-6).
    """
    for candidates in (list(pages), []):
        try:
            return ScrapeResult.build(
                source=source,
                run_id=run_id(source, started),
                started_at=started,
                finished_at=now_utc(),
                fetched_on=socket.gethostname(),
                pages=candidates,
                items=[],
                http_errors=http_errors,
                error=error,
                kind=kind,
                targets=targets if kind == KIND_BROADCASTS else None,
            )
        except MessageTooLarge:
            log.warning(
                "failed_result_too_large",
                extra={"source": source, "error": error, "pages": len(candidates)},
            )
            continue
    raise RuntimeError("a failed result with no pages cannot exceed the caps")  # unreachable


def _send_failure(
    source: str,
    started: datetime,
    pages: Sequence[Any],
    http_errors: int,
    error: str,
    kind: Kind = KIND_FIXTURES,
    targets: int = 0,
) -> None:
    """Record a failure on a path that re-raises, so Celery still sees the error (B2-R2-6)."""
    send_ingest(_failed(source, started, pages, http_errors=http_errors, error=error, kind=kind, targets=targets))


@task(name="adapters.ingest")
def ingest(self: Any, result: dict[str, Any]) -> dict[str, Any]:
    """Save the pages, write the run row, then normalize, resolve and upsert (R15, R18)."""
    # Imported here: the home box never runs this task, so it never loads the database.
    from app.adapters import health
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
            outcome = None
            links = None
            jobs: list[Any] = []
            health_outcome = health.HealthOutcome()

            try:
                run_dir = store.save(
                    source=data.source,
                    run_day=data.started_at.date(),
                    run_id=data.run_id,
                    pages=data.raw_pages(),
                    run_info={"counts": {"items_found": len(data.items), "http_errors": data.http_errors}},
                )
                run.raw_path = str(run_dir)

                adapter = adapter_for(data.source)
                if data.error or (not data.pages and data.kind == "fixtures"):
                    run.status = "failed"
                elif _source_is_paused(session, data.source):
                    run.status = "succeeded"
                    log.info("source_paused", extra={"source": data.source, "run": data.run_id})
                elif data.kind == KIND_BROADCASTS:
                    links = _ingest_broadcasts(session, data, run)
                else:
                    pipeline = UpsertPipeline(
                        session, source=data.source, media_hosts=settings.media_rehost_allowed_hosts
                    )
                    # Normalising runs per item inside its savepoint: a bad value skips one item (B2-R1-12).
                    outcome = pipeline.run(data.items, normalize=adapter.normalize)  # type: ignore[arg-type]
                    run.status = "partial" if outcome.skipped else "succeeded"
                    run.items_upserted = outcome.items_upserted
                    run.matches_imported = outcome.items_upserted
                    run.items_found = outcome.items_found

                # Every run counts: a failed fetch is exactly what opens the breaker (R17).
                health_outcome = health.record_run(
                    session,
                    source=data.source,
                    status=run.status,
                    items_found=run.items_found,
                    finished_at=now_utc(),
                    pages=len(data.pages),
                    targets=data.targets or 0,
                    bump=False,
                )
                _write_run_json(store, run_dir, data, outcome, links=links, health_outcome=health_outcome)
                run.finished_at = now_utc()
                _write_compact_log(session, run, data, outcome, links, health_outcome)
                # The dataset bumps are the transaction's last statement (constitution VI, VII).
                bumped = ["sources"]
                if links is not None:
                    bumped.extend(links.datasets)
                health.bump_datasets(session, bumped)
                session.commit()
                jobs = outcome.logo_jobs if outcome is not None else []
            except Exception as exc:
                # A full disk, a refused write, a bug: the run must not stay `running` (B2-R1-12).
                session.rollback()
                failed = session.get(ImportRun, run.id)
                if failed is not None:
                    failed.status = "failed"
                    failed.error = f"{type(exc).__name__}: {exc}"[:500]
                    failed.finished_at = now_utc()
                    session.commit()
                log.error(
                    "ingest_failed",
                    extra={"source": data.source, "run": data.run_id, "why": repr(exc)},
                    exc_info=True,
                )
                raise

            log.info(
                "ingested",
                extra={
                    "source": data.source,
                    "run": data.run_id,
                    "kind": data.kind,
                    "status": run.status,
                    "upserted": run.items_upserted,
                    "skipped": len(outcome.skipped) if outcome else len(links.skipped) if links else 0,
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
            "kind": data.kind,
            "status": run.status,
            "items_upserted": run.items_upserted,
            "logo_jobs": len(jobs),
        }


def _ingest_broadcasts(session: Any, data: ScrapeResult, run: Any) -> Any:
    """Link one match's broadcasters per item, count what changed, and fill the run row (R15, R18)."""
    from app.adapters.livesoccertv_links import apply_broadcasts
    from app.adapters.messages import BroadcastItem

    total = _AggregateLinks()
    changed = 0
    for item in data.items:
        if not isinstance(item, BroadcastItem):
            raise ValueError(f"a broadcasts message carries a {type(item).__name__}")
        outcome = apply_broadcasts(session, match_id=item.match_id, channels=item.channels, bump=False)
        total.merge(outcome)
        if outcome.added or outcome.removed:
            changed += 1
    run.items_upserted = changed
    run.matches_imported = len(data.items)
    run.items_found = len(data.items)
    run.status = "partial" if data.unmatched else "succeeded"
    return total


class _AggregateLinks:
    """One run's totals over its matches, in the same shape as one match's outcome."""

    def __init__(self) -> None:
        self.added: list[int] = []
        self.removed: list[int] = []
        self.placeholders_created: list[str] = []
        self.skipped: list[dict[str, str]] = []
        self.datasets: list[str] = []

    def merge(self, outcome: Any) -> None:
        self.added.extend(outcome.added)
        self.removed.extend(outcome.removed)
        self.placeholders_created.extend(outcome.placeholders_created)
        self.skipped.extend(outcome.skipped)
        for name in outcome.datasets:
            if name not in self.datasets:
                self.datasets.append(name)


def _source_is_paused(session: Any, source: str) -> bool:
    """``is_enabled``, ``paused_until`` or an open breaker, read here, on VPS-2 (R17)."""
    from app.adapters.health import source_is_paused

    return source_is_paused(session, source)


def _write_run_json(
    store: Any, run_dir: Any, data: ScrapeResult, outcome: Any, *, links: Any = None, health_outcome: Any = None
) -> None:
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
            "links_added": len(links.added) if links is not None else 0,
            "links_removed": len(links.removed) if links is not None else 0,
        },
        "skipped": (outcome.skipped if outcome is not None else list(links.skipped) if links is not None else []),
        "unresolved": outcome.unresolved if outcome is not None else [],
        "postponed": outcome.postponed if outcome is not None else [],
        "unmatched": [item.model_dump() for item in data.unmatched],
        "placeholders_created": list(links.placeholders_created) if links is not None else [],
        "health": health_outcome.as_log() if health_outcome is not None else {},
        "error": data.error,
    }
    (run_dir / "run.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")


def _compact_log(
    data: ScrapeResult,
    outcome: Any,
    links: Any,
    health_outcome: Any,
    plan_log: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """The A13 run detail: counts, a bounded list of what was skipped, and the plan's coverage."""
    payload: dict[str, Any] = {
        "kind": data.kind,
        "counts": {
            "items_found": len(data.items),
            "items_upserted": outcome.items_upserted if outcome is not None else 0,
            "http_errors": data.http_errors,
            "targets": data.targets or 0,
            "links_added": len(links.added) if links is not None else 0,
            "links_removed": len(links.removed) if links is not None else 0,
        },
        "placeholders_created": list(links.placeholders_created) if links is not None else [],
        "skipped": _bounded(
            outcome.skipped if outcome is not None else list(links.skipped) if links is not None else []
        ),
        "unresolved": _bounded(outcome.unresolved if outcome is not None else []),
        "unmatched": _bounded([item.model_dump() for item in data.unmatched]),
        "health": health_outcome.as_log() if health_outcome is not None else {},
    }
    if plan_log:
        payload["plan"] = plan_log
    if data.error:
        payload["error"] = data.error
    return _fit(payload)


def _bounded(items: Any) -> dict[str, Any]:
    """A list capped at ``MAX_LOG_ITEMS``, with the real count kept."""
    listed = list(items)
    return {"count": len(listed), "items": listed[:MAX_LOG_ITEMS]}


def _fit(payload: dict[str, Any]) -> dict[str, Any]:
    """Shrink a log that would pass 64 KB: counts first, lists last (T060)."""
    import json

    if len(json.dumps(payload, ensure_ascii=False, default=str).encode("utf-8")) <= MAX_LOG_BYTES:
        return payload
    for key in ("skipped", "unresolved", "unmatched"):
        section = payload.get(key)
        if isinstance(section, dict) and section.get("items"):
            section["items"] = []
            section["truncated"] = True
            if len(json.dumps(payload, ensure_ascii=False, default=str).encode("utf-8")) <= MAX_LOG_BYTES:
                return payload
    payload["placeholders_created"] = payload.get("placeholders_created", [])[:MAX_LOG_ITEMS]
    payload["truncated"] = True
    return payload


def _write_compact_log(
    session: Any, run: Any, data: ScrapeResult, outcome: Any, links: Any, health_outcome: Any
) -> None:
    """``import_runs.log``: the compact run detail A13 reads from VPS-1 (T060, R12)."""
    import json

    from sqlalchemy import text

    plan_log = None
    if data.kind == "broadcasts":
        from app.adapters.livesoccertv import last_plan_log

        plan_log = last_plan_log()
    payload = _compact_log(data, outcome, links, health_outcome, plan_log)
    session.execute(
        text("UPDATE import_runs SET log = CAST(:log AS jsonb) WHERE id = :id"),
        {"log": json.dumps(payload, ensure_ascii=False, default=str), "id": run.id},
    )


@task(name="adapters.prune_raw_pages")
def prune_raw_pages(self: Any) -> dict[str, Any]:
    """Delete raw run folders older than 5 days (constitution VII)."""
    from app.adapters.raw_store import RawStore

    removed = RawStore(get_adapter_settings().raw_root).prune_raw_pages()
    log.info("pruned_raw_pages", extra={"removed": removed})
    return {"removed": removed}


@task(name="adapters.schedule_fetch")
def schedule_fetch(self: Any, source: str, manual: bool = False, window: str = "default") -> dict[str, Any]:
    """Apply the pause and the breaker, plan LiveSoccerTV, then send one fetch (R14, R17).

    Every beat entry goes through here instead of calling ``adapters.fetch``: the home box has no
    database, so only VPS-2 can see that a source is paused or its breaker is open. A manual run
    (A13's «تشغيل الآن») ignores both and does not resume the source.
    """
    from app.adapters import health
    from app.db.session import SyncSession

    if not manual:
        with SyncSession() as session:
            if health.source_is_paused(session, source):
                log.info("skipped", extra={"task": "adapters.schedule_fetch", "source": source, "why": "paused"})
                return {"source": source, "skipped": True, "why": "paused"}

    if source == LIVESOCCERTV:
        with SyncSession() as session:
            plan = plan_targets(session, now=now_utc(), window=window)
        if not plan.targets:
            log.info("skipped", extra={"task": "adapters.schedule_fetch", "source": source, "why": "no_targets"})
            return {"source": source, "skipped": True, "why": "no_targets", **plan.log_payload()}
        payload = plan.log_payload()
        store_plan_log(payload)
        queue = get_adapter_settings().livesoccertv_fetch_queue
        fetch.apply_async(
            args=[source],
            kwargs={"targets": [target.as_task_arg() for target in plan.targets]},
            queue=queue,
        )
        log.info("scheduled", extra={"source": source, "targets": len(plan.targets), "queue": queue})
        return {"source": source, "planned": len(plan.targets), "queue": queue, **payload}

    source_queue: str | None = {
        "ysscores": get_adapter_settings().ysscores_fetch_queue,
        "legacy": "scrape",
    }.get(source)
    if source_queue is None:
        raise ValueError(f"unknown source {source!r}")
    fetch.apply_async(args=[source], queue=source_queue)
    log.info("scheduled", extra={"source": source, "queue": source_queue})
    return {"source": source, "queue": source_queue}


@task(name="ops.heartbeat")
def heartbeat(self: Any, queue: str) -> dict[str, Any]:
    """Push to the queue's Uptime Kuma monitor, so a dead worker goes quiet (R20).

    A missing URL leaves the queue unmonitored; a failed push is logged and never raised.
    """
    url = get_adapter_settings().kuma_push_url(queue)
    if not url:
        log.info("heartbeat_skipped", extra={"queue": queue, "why": "no_url"})
        return {"queue": queue, "sent": False}
    try:
        with httpx.Client(timeout=httpx.Timeout(5.0), follow_redirects=False) as client:
            response = client.get(url, params={"status": "up", "msg": "ok"})
        ok = response.status_code < 400
        if not ok:
            log.warning("heartbeat_rejected", extra={"queue": queue, "status": response.status_code})
        return {"queue": queue, "sent": ok}
    except httpx.HTTPError as exc:
        log.warning("heartbeat_failed", extra={"queue": queue, "why": repr(exc)})
        return {"queue": queue, "sent": False}
