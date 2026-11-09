"""One poll (005 contracts/live-pipeline.md, One cycle). Celery-free, so a fake fetcher can drive it.

Each match gets its own transaction ending in the ``live`` bump, and alerts go out only after that
transaction commits. Source problems are ``format:``, ``down:`` and ``unknown_status:``. No outbox row is
written (FR-014 of spec 005).
"""

from __future__ import annotations

import logging
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field, replace
from datetime import date, datetime, timedelta
from typing import Any, TypeVar

import httpx
from sqlalchemy import select
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
from app.live.robots import FILGOAL_HOST, GOAL_HOST, YALLAKORA_HOST, is_allowed
from app.live.sources import filgoal, goal, yallakora
from app.live.sources.common import safe_path
from app.live.types import LayoutChanged, SideInput, SourceReading
from app.live.watchdog import pause_feed_rows
from app.notifications.producers import record_poll
from app.services.live import FEED_WINDOW_BEFORE, WINDOW_AFTER, poll_window_query
from app.workers.base import Retryable

log = logging.getLogger(__name__)

T = TypeVar("T")

POLLER = "live_poller"
CYCLE_DEADLINE_S = 50.0
MAX_LOGGED = 50
USABLE_STATES = frozenset({"ok", "failing"})
# A list row's stage fills in a match page that doesn't say which half it's in.
STAGED_ON_THE_LIST = frozenset({"live", "halftime"})


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
    # Queues ``notifications.dispatch_due`` after a poll that wrote a row (research R3). ``None`` in
    # tests and in a process with no broker: the beat's own dispatch picks the row up a minute later.
    kick_dispatch: Callable[[], None] | None = None


@dataclass
class SourceRead:
    """One source's cycle: what it said, and what became of it."""

    source: str
    outcome: str = "ok"  # ok, failed, invalid or skipped
    readings: dict[str, SourceReading] = field(default_factory=dict)
    pages_to_save: list[RawPage] = field(default_factory=list)
    reason: str | None = None
    pages_read: int = 0
    unknown_statuses: set[str] = field(default_factory=set)


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
    reads: list[SourceRead] = field(default_factory=list)
    states: dict[str, str] = field(default_factory=dict)
    raw_ref: str | None = None
    filgoal_slots: set[int] = field(default_factory=set)


def _send(deps: Deps, texts: Sequence[str]) -> None:
    for text in texts:
        if not deps.alert(text):
            log.warning("live_alert_not_sent", extra={"text": text})


def _window(session: Session, now: datetime) -> list[WindowMatch]:
    rows = session.execute(
        poll_window_query(now)
        .with_only_columns(Match.id, Match.kickoff_at, Competition.priority, MatchLiveState.has_page_slot)
        .select_from(Match)
        .outerjoin(Competition, Competition.id == Match.competition_id)
        .outerjoin(MatchLiveState, MatchLiveState.match_id == Match.id)
    ).all()
    return [WindowMatch(row[0], row[1], row[2], bool(row[3])) for row in rows if row[1] is not None]


def paused(session: Session, now: datetime) -> bool:
    return source_is_paused(session, POLLER, now=now)


def _validated(source: str, parse: Callable[[], T]) -> T:
    """A page whose shape changed can raise anything: each of those is that page failing validation."""
    try:
        return parse()
    except LayoutChanged:
        raise
    except Exception as exc:  # noqa: BLE001 - the page is untrusted, and the other source must still be used
        raise LayoutChanged(f"{source}: an unexpected page shape ({type(exc).__name__})") from exc


def _parse_filgoal_page(body: bytes, external_id: str) -> SourceReading:
    reading = filgoal.parse_match(body)
    if reading.external_id != external_id:
        raise LayoutChanged("filgoal: the page is about another match")
    return reading


def _parse_yallakora_page(body: bytes, external_id: str) -> SourceReading:
    return yallakora.parse_match(body, external_id=external_id)


def _parse_goal_page(body: bytes, external_id: str) -> SourceReading:
    reading = goal.parse_match(body)
    if reading.external_id != external_id:
        raise LayoutChanged("goal: the page is about another match")
    return reading


@dataclass(frozen=True, slots=True)
class LiveSource:
    name: str
    host: str
    list_path: str
    parse_list: Callable[..., list[SourceReading]]
    parse_page: Callable[[bytes, str], SourceReading]
    page_cap: Callable[[LiveSettings], int]
    enabled: Callable[[LiveSettings], bool] = lambda _settings: True
    dated_list_path: Callable[[date], str] | None = None


FILGOAL = LiveSource(
    filgoal.SOURCE,
    FILGOAL_HOST,
    filgoal.LIST_PATH,
    filgoal.parse_list,
    _parse_filgoal_page,
    lambda settings: settings.page_cap_filgoal,
)
YALLAKORA = LiveSource(
    yallakora.SOURCE,
    YALLAKORA_HOST,
    yallakora.LIST_PATH,
    yallakora.parse_list,
    _parse_yallakora_page,
    lambda settings: settings.page_cap_yallakora,
    dated_list_path=yallakora.dated_list_path,
)
GOAL = LiveSource(
    goal.SOURCE,
    GOAL_HOST,
    goal.LIST_PATH,
    goal.parse_list,
    _parse_goal_page,
    lambda settings: settings.page_cap_goal,
    lambda settings: settings.goal_enabled,
)
# Each group reads its lists and then its pages. Goal.com answers slowly, so it only uses time left over (R8).
READ_GROUPS: tuple[tuple[LiveSource, ...], ...] = ((FILGOAL, YALLAKORA), (GOAL,))
BY_NAME = {source.name: source for group in READ_GROUPS for source in group}


def _parse_list(source: str, body: bytes, day: date) -> list[SourceReading]:
    return _validated(source, lambda: BY_NAME[source].parse_list(body, today=day))


def _parse_page(source: str, body: bytes, external_id: str) -> SourceReading:
    return _validated(source, lambda: BY_NAME[source].parse_page(body, external_id))


def _guarded_get(deps: Deps, source: str, path: str) -> RawPage:
    host = BY_NAME[source].host
    if not is_allowed(host, path):
        raise FetchError(f"{host}{path} is off limits")
    return deps.fetch(f"https://{host}{path}", host)


def _read_list(deps: Deps, source: str, now: datetime, cycle: CycleLog) -> SourceRead:
    read = SourceRead(source)
    host = BY_NAME[source].host
    if deps.backoff.active(host):
        read.outcome, read.reason = "failed", "backoff"
        return read
    try:
        page = _guarded_get(deps, source, BY_NAME[source].list_path)
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
        rows = _parse_list(source, page.body, now.astimezone(CAIRO).date())
        if not rows:
            raise LayoutChanged(f"{source}: a list with no matches while one is in the window")
    except LayoutChanged as exc:
        read.outcome, read.reason = "invalid", str(exc)[:200]
        read.pages_to_save.append(page)
        return read
    read.readings = {row.external_id: row for row in rows}
    read.unknown_statuses.update(row.unknown_status for row in rows if row.unknown_status)
    if deps.hashes.changed(page.url, page.body):
        read.pages_to_save.append(page)
    return read


def _earlier_days(window: Sequence[WindowMatch], now: datetime) -> list[date]:
    """The Cairo days before today that a match in the window kicked off on."""
    today = now.astimezone(CAIRO).date()
    return sorted({day for match in window if (day := match.kickoff_at.astimezone(CAIRO).date()) < today})


def _read_earlier_lists(
    deps: Deps,
    read: SourceRead,
    window: Sequence[WindowMatch],
    now: datetime,
    deadline: float,
    cycle: CycleLog,
) -> None:
    """A match still on at Cairo's midnight leaves the plain list, so its own day's list is read until it closes.

    Today's row wins an ID both lists have. As with a match page, a failed request costs only this read, and a
    page that fails validation stops the whole source. An empty list stops nothing: it may be a quiet day.
    """
    source = BY_NAME[read.source]
    if source.dated_list_path is None:
        return
    for day in _earlier_days(window, now):
        name = f"{read.source}:list:{day.isoformat()}"
        if deps.monotonic() >= deadline:
            cycle.skipped.append(name)
            return
        try:
            page = _guarded_get(deps, read.source, source.dated_list_path(day))
        except OutOfTokens:
            cycle.skipped.append(name)
            return
        except Retryable as exc:
            deps.backoff.trip(source.host)
            cycle.http_failures += 1
            log.info("live_list_blocked", extra={"source": read.source, "why": str(exc)[:200]})
            return
        except (FetchError, httpx.HTTPError) as exc:
            cycle.http_failures += 1
            log.info("live_list_failed", extra={"source": read.source, "why": str(exc)[:200]})
            continue
        read.pages_read += 1
        try:
            rows = _parse_list(read.source, page.body, day)
        except LayoutChanged as exc:
            read.outcome, read.reason = "invalid", str(exc)[:200]
            read.pages_to_save.append(page)
            read.readings = {}
            return
        read.readings = {**{row.external_id: row for row in rows}, **read.readings}
        read.unknown_statuses.update(row.unknown_status for row in rows if row.unknown_status)
        if deps.hashes.changed(page.url, page.body):
            read.pages_to_save.append(page)


def _with_list_stage(page: SourceReading, row: SourceReading | None) -> SourceReading:
    """A match page may say only ``live``, and its list row knows the half: YallaKora's does (R2)."""
    if page.status != "live" or page.period is not None or row is None or row.status not in STAGED_ON_THE_LIST:
        return page
    return replace(
        page,
        status=row.status,
        period=row.period,
        status_label=row.status_label,
        minute=page.minute if row.status == "live" else None,
    )


def _read_pages(
    deps: Deps,
    read: SourceRead,
    slots: Sequence[SlotCandidate],
    linked: dict[int, str],
    deadline: float,
    cycle: CycleLog,
) -> None:
    """Replaces list readings with match pages. A page that fails validation stops the whole source."""
    host = BY_NAME[read.source].host
    for number, slot in enumerate(slots):
        if deps.monotonic() >= deadline:
            cycle.skipped += [f"{read.source}:{item.match_id}" for item in slots[number:]]
            return
        external_id = linked[slot.match_id]
        path = safe_path(slot.path)
        if path is None:
            cycle.http_failures += 1
            log.info("live_page_bad_path", extra={"source": read.source, "match_id": slot.match_id})
            continue
        try:
            page = _guarded_get(deps, read.source, path)
        except OutOfTokens:
            cycle.skipped += [f"{read.source}:{item.match_id}" for item in slots[number:]]
            return
        except Retryable as exc:
            deps.backoff.trip(host)
            cycle.http_failures += 1
            log.info("live_page_blocked", extra={"source": read.source, "why": str(exc)[:200]})
            return
        except (FetchError, httpx.HTTPError, httpx.InvalidURL) as exc:
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
        if reading.unknown_status:
            read.unknown_statuses.add(reading.unknown_status)
        read.readings[external_id] = _with_list_stage(reading, read.readings.get(external_id))
        if deps.hashes.changed(page.url, page.body):
            read.pages_to_save.append(page)


def _link_all(deps: Deps, read: SourceRead, window_ids: set[int], now: datetime, cycle: CycleLog) -> dict[int, str]:
    """``match id → external id`` for this source's rows inside the window. One row's error skips that row."""
    bounds = (now - FEED_WINDOW_BEFORE, now + WINDOW_AFTER)
    linked: dict[int, str] = {}
    recorded: list[bool] = []

    def record(session: Session, **values: Any) -> None:
        recorded.append(bool(deps.record_unresolved(session, **values)))

    with deps.session_factory() as session, session.begin():
        for external_id, reading in read.readings.items():
            try:
                with session.begin_nested():
                    match_id = link_reading(session, reading, record_unresolved=record, window=bounds)
            except Exception:  # noqa: BLE001 - the other rows still count
                cycle.errors += 1
                log.exception("live_row_not_linked", extra={"source": read.source, "external_id": external_id})
                continue
            if match_id in window_ids and match_id is not None:
                linked[match_id] = external_id
        if any(recorded):
            bump_datasets(session, ["unresolved_names"])
    return linked


def _slots(deps: Deps, read: SourceRead, window: Sequence[WindowMatch], linked: dict[int, str]) -> list[SlotCandidate]:
    source = BY_NAME[read.source]
    is_filgoal = read.source == filgoal.SOURCE
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
    return pick_slots(candidates, host=source.host, cap=source.page_cap(deps.settings))


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


def _unknown_status_problems(session: Session, read: SourceRead, raw_ref: str | None, now: datetime) -> list[str]:
    """It doesn't stop the source: the row's score still counts, and the owner reads the saved page (FR-001)."""
    key = f"unknown_status:{read.source}"
    if not read.unknown_statuses:
        return sync_problems(session, closed=(key,), now=now)
    log.warning("live_unknown_status", extra={"source": read.source, "labels": sorted(read.unknown_statuses)})
    return sync_problems(session, opened=(key,), now=now, raw_ref=raw_ref)


def _update_sources(deps: Deps, reads: Sequence[SourceRead], raw_ref: str | None, now: datetime) -> dict[str, str]:
    """``live_source_state`` and the source problems, in one transaction."""
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
                texts += _unknown_status_problems(session, read, raw_ref, now)
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
    if read.outcome != "ok" or external_id is None or external_id not in read.readings:
        return SideInput.not_covering()
    reading = read.readings[external_id]
    if reading.unknown_status is not None and reading.score is None:
        return SideInput.not_covering()  # nothing to use, and it mustn't keep the match from going stale
    return SideInput.valid(reading)


def _apply_match(
    deps: Deps,
    match_id: int,
    sides: dict[str, SideInput],
    has_slot: bool,
    now: datetime,
    raw_ref: str | None,
) -> bool:
    readings = [side.reading for side in sides.values() if side.reading is not None]
    settings = deps.settings
    with deps.session_factory() as session, session.begin():
        match = session.get(Match, match_id, with_for_update=True)
        if match is None:
            return False
        # The producers write ``final_score`` only when this poll is the one that finished the row.
        status_before = match.status
        state = load_state(session, match)
        decision = decide(
            state,
            sides,
            now,
            drop_hold=settings.drop_hold,
            disagree_after=settings.disagree_after,
            fulltime_hold=settings.fulltime_hold,
        )
        changed = apply_decision(
            session,
            match,
            decision,
            readings=readings,
            now=now,
            has_page_slot=has_slot,
            drop_hold=settings.drop_hold,
            stuck_after=settings.stuck_after,
        )
        closed = list(decision.close_problems)
        if readings:
            closed.append(f"stale:{match_id}")
        # The push producers run in their own savepoint: a bug in copy or memory rolls back only the
        # push work, and the score still commits (FR-008, research R3).
        produced = 0
        try:
            with session.begin_nested():
                produced = record_poll(session, match, readings, now, status_before=status_before)
        except Exception:  # noqa: BLE001 - never let a push bug stop the live score
            log.exception("push_producers_failed", extra={"match_id": match_id})
        texts = sync_problems(session, opened=decision.open_problems, closed=closed, now=now, raw_ref=raw_ref)
    _send(deps, texts)
    if produced and deps.kick_dispatch is not None:
        deps.kick_dispatch()
    return changed


def _finish_run(deps: Deps, run_id: int, cycle: CycleLog, *, matches: int, broken: str | None = None) -> None:
    now = deps.clock()
    reads, states, raw_ref = cycle.reads, cycle.states, cycle.raw_ref
    usable = [read for read in reads if read.outcome == "ok"]
    status = "partial" if usable else "failed"
    if broken is not None:
        status = "failed"
    elif usable and len(usable) == len(reads) and not cycle.errors:
        status = "succeeded"
    reasons = [read.reason for read in reads if read.reason]
    with deps.session_factory() as session, session.begin():
        run = session.get(ImportRun, run_id)
        if run is not None:
            run.finished_at = now
            run.status = status
            run.items_found = matches
            run.items_upserted = cycle.changed
            run.http_errors = cycle.http_failures
            run.raw_path = raw_ref
            run.error = "; ".join([*reasons, *([broken] if broken else [])])[:500] or None
            run.log = {
                "pages": sum(len(read.pages_to_save) for read in reads),
                "pages_read": sum(read.pages_read for read in reads),
                "worker": "live",
                "sources": states,
                "skipped": cycle.skipped[:MAX_LOGGED],
                "ignored_event_types": sorted(cycle.ignored_event_types)[:MAX_LOGGED],
                "unknown_statuses": {
                    read.source: sorted(read.unknown_statuses)[:MAX_LOGGED] for read in reads if read.unknown_statuses
                },
                "match_errors": cycle.errors,
            }
        deps.record_live_cycle(session, status=status, items_found=matches, finished_at=now)
        # A13's run list has this version in its ETag, as every importer's run does. Last, as in tasks.py.
        bump_datasets(session, ["sources"])


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
            pause_feed_rows(session, now, stuck_after=deps.settings.stuck_after)
            return {"skipped": "paused"}
        window = _window(session, now)
    if not window:
        return {"skipped": "no_matches"}

    run_id = _open_run(deps, now)
    cycle = CycleLog()
    try:
        _poll(deps, run_id, window, now, cycle)
        _finish_run(deps, run_id, cycle, matches=len(window))
    except Exception as exc:
        log.exception("live_cycle_failed", extra={"run_id": run_id})
        _close_broken_run(deps, run_id, cycle, len(window), exc)
        raise
    return {"run_id": run_id, "matches": len(window), "changed": cycle.changed, "sources": cycle.states}


def _close_broken_run(deps: Deps, run_id: int, cycle: CycleLog, matches: int, exc: Exception) -> None:
    """A run row left ``running`` would say the poller is still at it. The next cycle is the retry."""
    try:
        _finish_run(deps, run_id, cycle, matches=matches, broken=f"the cycle stopped: {type(exc).__name__}")
    except Exception:  # noqa: BLE001 - the caller re-raises the first error, which is the one that matters
        log.exception("live_run_not_closed", extra={"run_id": run_id})


def _read_group(
    deps: Deps,
    sources: Sequence[LiveSource],
    window: Sequence[WindowMatch],
    now: datetime,
    deadline: float,
    cycle: CycleLog,
    *,
    after_others: bool,
) -> dict[str, dict[int, str]]:
    """Lists, then links, then pages, adding to ``cycle.reads``. Returns ``source → match id → external id``."""
    reads = [
        _past_deadline(source.name, cycle)
        if after_others and deps.monotonic() >= deadline
        else _read_list(deps, source.name, now, cycle)
        for source in sources
    ]
    cycle.reads += reads
    for read in reads:
        if read.outcome == "ok":
            _read_earlier_lists(deps, read, window, now, deadline, cycle)
    window_ids = {match.id for match in window}
    links = {
        read.source: _link_all(deps, read, window_ids, now, cycle) if read.outcome == "ok" else {} for read in reads
    }
    for read in reads:
        if read.outcome != "ok":
            continue
        slots = _slots(deps, read, window, links[read.source])
        if read.source == filgoal.SOURCE:
            cycle.filgoal_slots = {slot.match_id for slot in slots}
        _read_pages(deps, read, slots, links[read.source], deadline, cycle)
    return links


def _past_deadline(source: str, cycle: CycleLog) -> SourceRead:
    """Not the source's fault: no failure counts, and the other sources have had their reads."""
    cycle.skipped.append(f"{source}:list")
    return SourceRead(source, outcome="skipped", reason="past_deadline")


def _poll(deps: Deps, run_id: int, window: Sequence[WindowMatch], now: datetime, cycle: CycleLog) -> None:
    deadline = deps.monotonic() + CYCLE_DEADLINE_S
    links: dict[str, dict[int, str]] = {}
    for number, group in enumerate(READ_GROUPS):
        enabled = [source for source in group if source.enabled(deps.settings)]
        links |= _read_group(deps, enabled, window, now, deadline, cycle, after_others=number > 0)

    reads = cycle.reads
    raw_ref = cycle.raw_ref = _save_raw(deps, run_id, reads, now)
    states = cycle.states = _update_sources(deps, reads, raw_ref, now)

    by_source = {read.source: read for read in reads}
    for match in window:
        sides = {source: _side(read, states[source], links[source].get(match.id)) for source, read in by_source.items()}
        try:
            if _apply_match(deps, match.id, sides, match.id in cycle.filgoal_slots, now, raw_ref):
                cycle.changed += 1
        except Exception:  # noqa: BLE001 - one match's error can't cost the others their poll
            cycle.errors += 1
            log.exception("live_match_not_applied", extra={"match_id": match.id})


def has_work_in(session_factory: Callable[[], Session], now: datetime, *, stuck_after: timedelta) -> bool:
    """The scheduler's check. Paused rows go to the clock here, with no request and no alert."""
    with session_factory() as session, session.begin():
        if paused(session, now):
            pause_feed_rows(session, now, stuck_after=stuck_after)
            return False
        return session.scalars(poll_window_query(now).limit(1)).first() is not None


def delete_old_runs(session: Session, now: datetime, *, days: int = 30) -> int:
    """``live_poller`` runs only; importer runs keep their own retention."""
    rows = session.scalars(
        select(ImportRun).where(ImportRun.source == POLLER, ImportRun.started_at < now - timedelta(days=days))
    ).all()
    for row in rows:
        session.delete(row)
    return len(rows)
