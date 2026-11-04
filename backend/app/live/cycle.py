"""One poll (005 contracts/live-pipeline.md, One cycle). Celery-free, so a fake fetcher can drive it.

Each match gets its own transaction ending in the ``live`` bump, and alerts go out only after that
transaction commits. Source problems are ``format:`` and ``down:``. No outbox row is written (FR-014).
"""

from __future__ import annotations

import logging
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any
from urllib.parse import urlsplit

import httpx
from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.adapters.base import RawPage
from app.adapters.fetcher import FetchError
from app.adapters.health import bump_datasets, source_is_paused
from app.adapters.raw_store import RawStore
from app.db.models import Competition, ImportRun, LiveSourceState, Match, MatchLiveState
from app.domain.time import CAIRO
from app.live.apply import apply_decision, load_state
from app.live.backoff import Backoff, PageHashes
from app.live.config import LiveSettings
from app.live.crosscheck import BOTH_DOWN, decide
from app.live.links import link_reading
from app.live.pick import SlotCandidate, pick_slots
from app.live.problems import sync_problems
from app.live.robots import FILGOAL_HOST, YALLAKORA_HOST, is_allowed
from app.live.sources import filgoal, yallakora
from app.live.types import LayoutChanged, SideInput, SourceReading
from app.live.watchdog import pause_feed_rows
from app.services.live import FEED_WINDOW_BEFORE, WINDOW_AFTER, live_window_query
from app.workers.base import Retryable

log = logging.getLogger(__name__)

POLLER = "live_poller"
CYCLE_DEADLINE_S = 50.0
MAX_LOGGED = 50
USABLE_STATES = frozenset({"ok", "failing"})
HOSTS = {filgoal.SOURCE: FILGOAL_HOST, yallakora.SOURCE: YALLAKORA_HOST}
LIST_PATHS = {filgoal.SOURCE: filgoal.LIST_PATH, yallakora.SOURCE: yallakora.LIST_PATH}


class OutOfTokens(Exception):
    """The shared bucket has nothing left: not the host's fault, so no backoff and no failure."""


Fetch = Callable[[str, str], RawPage]


@dataclass
class Deps:
    session_factory: Callable[[], Session]
    fetch: Fetch  # (url, host)
    backoff: Backoff
    hashes: PageHashes
    raw_store: RawStore
    alert: Callable[[str], bool]
    settings: LiveSettings
    record_unresolved: Callable[..., Any]
    record_live_cycle: Callable[..., Any]
    clock: Callable[[], datetime]
    monotonic: Callable[[], float]


@dataclass
class SourceRead:
    """One source's cycle: what it said, and what became of it."""

    source: str
    outcome: str = "ok"  # ok, failed, invalid or skipped
    readings: dict[str, SourceReading] = field(default_factory=dict)
    pages_to_save: list[RawPage] = field(default_factory=list)
    reason: str | None = None
    pages_read: int = 0


@dataclass(frozen=True, slots=True)
class WindowMatch:
    id: int
    kickoff_at: datetime
    priority: int | None
    has_slot: bool


@dataclass
class CycleLog:
    pages_read: int = 0
    http_failures: int = 0
    skipped: list[str] = field(default_factory=list)
    ignored_event_types: set[str] = field(default_factory=set)
    changed: int = 0
    errors: int = 0


def _send(deps: Deps, texts: Sequence[str]) -> None:
    for text in texts:
        if not deps.alert(text):
            log.warning("live_alert_not_sent", extra={"text": text})


def _window(session: Session, now: datetime) -> list[WindowMatch]:
    rows = session.execute(
        live_window_query(now)
        .with_only_columns(Match.id, Match.kickoff_at, Competition.priority, MatchLiveState.has_page_slot)
        .select_from(Match)
        .outerjoin(Competition, Competition.id == Match.competition_id)
        .outerjoin(MatchLiveState, MatchLiveState.match_id == Match.id)
    ).all()
    return [WindowMatch(row[0], row[1], row[2], bool(row[3])) for row in rows if row[1] is not None]


def paused(session: Session, now: datetime) -> bool:
    return source_is_paused(session, POLLER, now=now)


def _parse_list(source: str, body: bytes, now: datetime) -> list[SourceReading]:
    today = now.astimezone(CAIRO).date()
    return (
        filgoal.parse_list(body, today=today) if source == filgoal.SOURCE else yallakora.parse_list(body, today=today)
    )


def _parse_page(source: str, body: bytes, external_id: str) -> SourceReading:
    if source == yallakora.SOURCE:
        return yallakora.parse_match(body, external_id=external_id)
    reading = filgoal.parse_match(body)
    if reading.external_id != external_id:
        raise LayoutChanged("filgoal: the page is about another match")
    return reading


def _guarded_get(deps: Deps, source: str, path: str) -> RawPage:
    host = HOSTS[source]
    if not is_allowed(host, path):
        raise FetchError(f"{host}{path} is off limits")
    return deps.fetch(f"https://{host}{path}", host)


def _read_list(deps: Deps, source: str, now: datetime, cycle: CycleLog) -> SourceRead:
    read = SourceRead(source)
    host = HOSTS[source]
    if deps.backoff.active(host):
        read.outcome, read.reason = "failed", "backoff"
        return read
    try:
        page = _guarded_get(deps, source, LIST_PATHS[source])
    except OutOfTokens:
        read.outcome, read.reason = "skipped", "out_of_tokens"
        cycle.skipped.append(f"{source}:list")
        return read
    except Retryable as exc:
        deps.backoff.trip(host)
        cycle.http_failures += 1
        read.outcome, read.reason = "failed", str(exc)[:200]
        return read
    except (FetchError, httpx.HTTPError) as exc:
        cycle.http_failures += 1
        read.outcome, read.reason = "failed", str(exc)[:200]
        return read
    deps.backoff.clear(host)
    read.pages_read += 1
    try:
        rows = _parse_list(source, page.body, now)
        if not rows:
            raise LayoutChanged(f"{source}: a list with no matches while one is in the window")
    except LayoutChanged as exc:
        read.outcome, read.reason = "invalid", str(exc)[:200]
        read.pages_to_save.append(page)
        return read
    read.readings = {row.external_id: row for row in rows}
    if deps.hashes.changed(page.url, page.body):
        read.pages_to_save.append(page)
    return read


def _read_pages(
    deps: Deps,
    read: SourceRead,
    slots: Sequence[SlotCandidate],
    linked: dict[int, str],
    deadline: float,
    cycle: CycleLog,
) -> None:
    """Replaces list readings with match pages. A page that fails validation stops the whole source."""
    host = HOSTS[read.source]
    for number, slot in enumerate(slots):
        if deps.monotonic() >= deadline:
            cycle.skipped += [f"{read.source}:{item.match_id}" for item in slots[number:]]
            return
        external_id = linked[slot.match_id]
        assert slot.path is not None  # pick_slots keeps only slots with a path
        try:
            page = _guarded_get(deps, read.source, urlsplit(slot.path).path)
        except OutOfTokens:
            cycle.skipped += [f"{read.source}:{item.match_id}" for item in slots[number:]]
            return
        except Retryable as exc:
            deps.backoff.trip(host)
            cycle.http_failures += 1
            log.info("live_page_blocked", extra={"source": read.source, "why": str(exc)[:200]})
            return
        except (FetchError, httpx.HTTPError) as exc:
            cycle.http_failures += 1
            log.info("live_page_failed", extra={"source": read.source, "why": str(exc)[:200]})
            continue
        read.pages_read += 1
        try:
            reading = _parse_page(read.source, page.body, external_id)
        except LayoutChanged as exc:
            read.outcome, read.reason = "invalid", str(exc)[:200]
            read.pages_to_save.append(page)
            read.readings = {}
            return
        if reading.ignored_event_types:
            cycle.ignored_event_types.update(reading.ignored_event_types)
        read.readings[external_id] = reading
        if deps.hashes.changed(page.url, page.body):
            read.pages_to_save.append(page)


def _link_all(deps: Deps, read: SourceRead, window_ids: set[int], now: datetime) -> dict[int, str]:
    """``match id → external id`` for this source's rows inside the window."""
    bounds = (now - FEED_WINDOW_BEFORE, now + WINDOW_AFTER)
    linked: dict[int, str] = {}
    recorded: list[bool] = []

    def record(session: Session, **values: Any) -> None:
        recorded.append(bool(deps.record_unresolved(session, **values)))

    with deps.session_factory() as session, session.begin():
        for external_id, reading in read.readings.items():
            match_id = link_reading(session, reading, record_unresolved=record, window=bounds)
            if match_id in window_ids and match_id is not None:
                linked[match_id] = external_id
        if any(recorded):
            bump_datasets(session, ["unresolved_names"])
    return linked


def _slots(deps: Deps, read: SourceRead, window: Sequence[WindowMatch], linked: dict[int, str]) -> list[SlotCandidate]:
    host = HOSTS[read.source]
    is_filgoal = read.source == filgoal.SOURCE
    cap = deps.settings.page_cap_filgoal if is_filgoal else deps.settings.page_cap_yallakora
    candidates = [
        SlotCandidate(
            match_id=match.id,
            path=read.readings[linked[match.id]].page_path,
            priority=match.priority,
            kickoff_at=match.kickoff_at,
            has_slot=match.has_slot and is_filgoal,
        )
        for match in window
        if match.id in linked
    ]
    return pick_slots(candidates, host=host, cap=cap)


def _save_raw(deps: Deps, run_id: int, reads: Sequence[SourceRead], now: datetime) -> str | None:
    pages = [page for read in reads for page in read.pages_to_save]
    if not pages:
        return None
    try:
        path = deps.raw_store.save(
            source=POLLER,
            run_day=now.astimezone(CAIRO).date(),
            run_id=str(run_id),
            pages=pages,
            run_info={"page_urls": [page.url for page in pages], "worker": "live"},
        )
    except OSError as exc:
        log.error("live_raw_not_saved", extra={"why": repr(exc)})
        return None
    return str(path)


def _next_state(row: LiveSourceState, outcome: str, down_after: int) -> None:
    if outcome == "failed" or outcome == "invalid":
        row.consecutive_failures += 1
    if outcome == "invalid":
        row.state = "invalid"
    elif outcome == "failed":
        if row.consecutive_failures >= down_after:
            row.state = "down"
        elif row.state != "invalid":
            row.state = "failing"


def _update_sources(deps: Deps, reads: Sequence[SourceRead], raw_ref: str | None, now: datetime) -> dict[str, str]:
    """``live_source_state`` and the ``format:`` / ``down:`` problems, in one transaction."""
    states: dict[str, str] = {}
    texts: list[str] = []
    with deps.session_factory() as session, session.begin():
        changed = False
        for read in reads:
            row = session.get(LiveSourceState, read.source, with_for_update=True)
            if row is None:
                row = LiveSourceState(source=read.source, state="ok", consecutive_failures=0)
                session.add(row)
            before = row.state
            if read.outcome == "ok":
                row.state, row.consecutive_failures, row.last_ok_at = "ok", 0, now
                texts += sync_problems(session, closed=(f"format:{read.source}", f"down:{read.source}"), now=now)
            elif read.outcome != "skipped":
                _next_state(row, read.outcome, deps.settings.down_after_failures)
                opened = []
                if read.outcome == "invalid":
                    opened.append(f"format:{read.source}")
                elif row.state == "down":
                    opened.append(f"down:{read.source}")
                texts += sync_problems(session, opened=opened, now=now, raw_ref=raw_ref)
            states[read.source] = row.state
            changed = changed or before != row.state
        if any(state == "ok" for state in states.values()):
            texts += sync_problems(session, closed=(BOTH_DOWN,), now=now)
        if changed:
            bump_datasets(session, ["sources"])
    _send(deps, texts)
    return states


def _side(read: SourceRead, state: str, external_id: str | None) -> SideInput:
    """A source that merely failed this cycle has nothing to say; only a stopped one is ``unavailable``."""
    if state not in USABLE_STATES:
        return SideInput.unavailable()
    if read.outcome == "ok" and external_id is not None and external_id in read.readings:
        return SideInput.valid(read.readings[external_id])
    return SideInput.not_covering()


def _apply_match(
    deps: Deps,
    match_id: int,
    sides: dict[str, SideInput],
    has_slot: bool,
    now: datetime,
    raw_ref: str | None,
) -> bool:
    readings = [side.reading for side in sides.values() if side.reading is not None]
    with deps.session_factory() as session, session.begin():
        match = session.get(Match, match_id, with_for_update=True)
        if match is None:
            return False
        state = load_state(session, match, readings[0].source if readings else None)
        decision = decide(state, sides[filgoal.SOURCE], sides[yallakora.SOURCE], now, wait=deps.settings.confirm_wait)
        changed = apply_decision(session, match, decision, readings=readings, now=now, has_page_slot=has_slot)
        closed = list(decision.close_problems)
        if readings:
            closed.append(f"stale:{match_id}")
        texts = sync_problems(session, opened=decision.open_problems, closed=closed, now=now, raw_ref=raw_ref)
    _send(deps, texts)
    return changed


def _finish_run(
    deps: Deps,
    run_id: int,
    *,
    reads: Sequence[SourceRead],
    states: dict[str, str],
    cycle: CycleLog,
    raw_ref: str | None,
    matches: int,
) -> None:
    now = deps.clock()
    usable = [read for read in reads if read.outcome == "ok"]
    status = "failed" if not usable else ("succeeded" if len(usable) == len(reads) and not cycle.errors else "partial")
    with deps.session_factory() as session, session.begin():
        run = session.get(ImportRun, run_id)
        if run is not None:
            run.finished_at = now
            run.status = status
            run.items_found = matches
            run.items_upserted = cycle.changed
            run.http_errors = cycle.http_failures
            run.raw_path = raw_ref
            run.error = "; ".join(read.reason for read in reads if read.reason)[:500] or None
            run.log = {
                "pages": sum(len(read.pages_to_save) for read in reads),
                "pages_read": sum(read.pages_read for read in reads),
                "worker": "live",
                "sources": states,
                "skipped": cycle.skipped[:MAX_LOGGED],
                "ignored_event_types": sorted(cycle.ignored_event_types)[:MAX_LOGGED],
                "match_errors": cycle.errors,
            }
        deps.record_live_cycle(session, status=status, items_found=matches, finished_at=now)


def _open_run(deps: Deps, now: datetime) -> int:
    with deps.session_factory() as session, session.begin():
        run = ImportRun(source=POLLER, started_at=now, status="running")
        session.add(run)
        session.flush()
        return run.id


def run_cycle(deps: Deps) -> dict[str, Any]:
    """One poll. Returns a summary for the task log."""
    now = deps.clock()
    with deps.session_factory() as session, session.begin():
        if paused(session, now):
            pause_feed_rows(session, now)
            return {"skipped": "paused"}
        window = _window(session, now)
    if not window:
        return {"skipped": "no_matches"}

    deadline = deps.monotonic() + CYCLE_DEADLINE_S
    run_id = _open_run(deps, now)
    cycle = CycleLog()
    window_ids = {match.id for match in window}

    reads = [_read_list(deps, source, now, cycle) for source in (filgoal.SOURCE, yallakora.SOURCE)]
    links: dict[str, dict[int, str]] = {}
    filgoal_slots: set[int] = set()
    for read in reads:
        links[read.source] = _link_all(deps, read, window_ids, now) if read.outcome == "ok" else {}
    for read in reads:
        if read.outcome != "ok":
            continue
        slots = _slots(deps, read, window, links[read.source])
        if read.source == filgoal.SOURCE:
            filgoal_slots = {slot.match_id for slot in slots}
        _read_pages(deps, read, slots, links[read.source], deadline, cycle)

    raw_ref = _save_raw(deps, run_id, reads, now)
    states = _update_sources(deps, reads, raw_ref, now)

    by_source = {read.source: read for read in reads}
    for match in window:
        sides = {
            source: _side(by_source[source], states[source], links[source].get(match.id))
            for source in (filgoal.SOURCE, yallakora.SOURCE)
        }
        try:
            if _apply_match(deps, match.id, sides, match.id in filgoal_slots, now, raw_ref):
                cycle.changed += 1
        except SQLAlchemyError:
            cycle.errors += 1
            log.exception("live_match_not_applied", extra={"match_id": match.id})

    _finish_run(deps, run_id, reads=reads, states=states, cycle=cycle, raw_ref=raw_ref, matches=len(window))
    return {"run_id": run_id, "matches": len(window), "changed": cycle.changed, "sources": states}


def has_work_in(session_factory: Callable[[], Session], now: datetime) -> bool:
    """The scheduler's check. Paused rows go to the clock here, with no request and no alert."""
    with session_factory() as session, session.begin():
        if paused(session, now):
            pause_feed_rows(session, now)
            return False
        return session.scalars(live_window_query(now).limit(1)).first() is not None


def delete_old_runs(session: Session, now: datetime, *, days: int = 30) -> int:
    """``live_poller`` runs only; importer runs keep their own retention."""
    rows = session.scalars(
        select(ImportRun).where(ImportRun.source == POLLER, ImportRun.started_at < now - timedelta(days=days))
    ).all()
    for row in rows:
        session.delete(row)
    return len(rows)
