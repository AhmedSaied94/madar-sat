"""The poller's Celery tasks: thin wrappers over ``cycle`` and ``watchdog`` (contracts, Tasks).

The database and the settings are imported inside each task: every worker imports this module,
and the home box has no database.
"""

from __future__ import annotations

import logging
import time
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any

import redis

from app.adapters.alerts import send_alert
from app.adapters.config import get_adapter_settings
from app.adapters.fetcher import HttpFetcher
from app.adapters.ratelimit import RateLimiter
from app.live.backoff import Backoff, PageHashes
from app.live.config import get_live_settings
from app.workers import task
from app.workers.base import Retryable
from app.workers.config import get_worker_settings
from app.workers.locks import redis_lock

log = logging.getLogger(__name__)

LIVE_QUEUE = "live"
POLL_LOCK_TTL_S = 90
SHORT_LOCK_TTL_S = 110
LONG_LOCK_TTL_S = 600
# A cycle has 60 s, so it can't sit waiting for a token; what's left is logged as skipped.
TOKEN_WAIT_S = 2.0
_OUT_OF_TOKENS = "rate limit reached"


def _redis() -> redis.Redis:
    return redis.Redis.from_url(get_worker_settings().broker_url)


def _now() -> datetime:
    return datetime.now(UTC)


def _fetch_with(fetcher: HttpFetcher) -> Callable[[str, str], Any]:
    from app.live.cycle import OutOfTokens

    def fetch(url: str, host: str) -> Any:
        try:
            return fetcher.get(url, allowed_hosts=frozenset({host}))
        except Retryable as exc:
            # B2's fetcher raises one exception for both; only this one isn't the host's doing.
            if str(exc).startswith(_OUT_OF_TOKENS):
                raise OutOfTokens(str(exc)) from exc
            raise

    return fetch


def _kick_dispatch() -> None:
    """Queue one dispatch run after a poll that wrote a push row (research R3)."""
    from app.notifications.tasks import dispatch_due

    dispatch_due.apply_async(queue="notifications")


def _deps(client: redis.Redis, fetcher: HttpFetcher) -> Any:
    from app.adapters.health import record_live_cycle
    from app.adapters.raw_store import RawStore
    from app.adapters.unresolved import record_unresolved
    from app.db.session import SyncSession
    from app.live.cycle import Deps

    return Deps(
        session_factory=SyncSession,
        fetch=_fetch_with(fetcher),
        backoff=Backoff(client),
        hashes=PageHashes(client),
        raw_store=RawStore(get_adapter_settings().raw_root),
        alert=send_alert,
        settings=get_live_settings(),
        record_unresolved=record_unresolved,
        record_live_cycle=record_live_cycle,
        clock=_now,
        monotonic=time.monotonic,
        kick_dispatch=_kick_dispatch,
    )


def _fetcher(client: redis.Redis) -> HttpFetcher:
    return HttpFetcher(RateLimiter(client), get_adapter_settings().require_user_agent(), wait_budget=TOKEN_WAIT_S)


@task(name="live.scheduler", queue=LIVE_QUEUE)
def live_scheduler(self: Any) -> dict[str, Any]:
    """Every 60 s. No match or paused: no request at all, so a quiet day costs nothing."""
    from app.db.session import SyncSession
    from app.live.cycle import has_work_in

    client = _redis()
    try:
        with redis_lock("lock:live:scheduler", SHORT_LOCK_TTL_S, client=client) as acquired:
            if not acquired:
                return {"skipped": "lock_held"}
            if not has_work_in(SyncSession, _now(), stuck_after=get_live_settings().stuck_after):
                return {"queued": False}
        live_poll.apply_async(queue=LIVE_QUEUE)
        return {"queued": True}
    finally:
        client.close()


@task(name="live.poll", queue=LIVE_QUEUE, autoretry_for=(), max_retries=0)
def live_poll(self: Any) -> dict[str, Any]:
    """One cycle. An overlap exits, and the next cycle is its retry."""
    from app.live.cycle import run_cycle

    client = _redis()
    try:
        with redis_lock("lock:live:poll", POLL_LOCK_TTL_S, client=client) as acquired:
            if not acquired:
                log.info("skipped", extra={"task": "live.poll", "why": "lock_held"})
                return {"skipped": "lock_held"}
            with _fetcher(client) as fetcher:
                result: dict[str, Any] = run_cycle(_deps(client, fetcher))
                return result
    finally:
        client.close()


@task(name="live.watchdog", queue="maintenance")
def live_watchdog(self: Any) -> dict[str, Any]:
    """Every 2 min, on a queue that survives ``worker-live`` dying, or a capture dying (research R6, R12)."""
    from app.db.session import SyncSession
    from app.live.capture import check_heartbeat
    from app.live.watchdog import run_watchdog

    client = _redis()
    try:
        with redis_lock("lock:live:watchdog", SHORT_LOCK_TTL_S, client=client) as acquired:
            if not acquired:
                return {"skipped": "lock_held"}
            with SyncSession() as session, session.begin():
                alerts = run_watchdog(session, _now(), get_live_settings())
            check_heartbeat(client, _now(), send_alert)
    finally:
        client.close()
    for text in alerts:
        send_alert(text)
    return {"alerts": len(alerts)}


@task(name="live.prune_runs", queue="maintenance")
def live_prune_runs(self: Any) -> dict[str, Any]:
    from app.db.session import SyncSession
    from app.live.cycle import delete_old_runs

    client = _redis()
    try:
        with redis_lock("lock:live:prune", LONG_LOCK_TTL_S, client=client) as acquired:
            if not acquired:
                return {"skipped": "lock_held"}
            with SyncSession() as session, session.begin():
                return {"deleted": delete_old_runs(session, _now())}
    finally:
        client.close()


@task(name="live.check_robots", queue=LIVE_QUEUE)
def live_check_robots(self: Any) -> dict[str, Any]:
    """Daily. A changed ``robots.txt`` opens a problem and changes nothing else (research R4)."""
    from app.db.session import SyncSession
    from app.live.robots_check import check_robots

    client = _redis()
    try:
        with redis_lock("lock:live:robots", LONG_LOCK_TTL_S, client=client) as acquired:
            if not acquired:
                return {"skipped": "lock_held"}
            with _fetcher(client) as fetcher:
                fetch = _fetch_with(fetcher)
                with SyncSession() as session, session.begin():
                    alerts = check_robots(session, fetch, _now(), goal_enabled=get_live_settings().goal_enabled)
    finally:
        client.close()
    for text in alerts:
        send_alert(text)
    return {"alerts": len(alerts)}
