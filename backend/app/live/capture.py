"""The recorder that completes the parsers from real live pages (research R1, spec 031 R12).

``capture-live`` reads all three list pages about once a minute, and the pages of the matches those lists
show being played, up to a cap per source. It saves them gzipped under ``/srv/raw/capture/<date>/``, through
the deny list, ``HttpFetcher`` and the shared buckets. Reads only; it writes nothing to the database.

Nobody watches it for four hours, so it says what happens: one Telegram message when it starts and ends, one
when a source fails or goes quiet for five rounds, and one when that ends. A source that refuses a request ends
its round and says so at once, and refusing the next round too stops it for good. A dead process can't say so
itself, so each round writes the time to Redis and ``live.watchdog`` looks at that key.
"""

from __future__ import annotations

import gzip
import logging
import re
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import redis

from app.domain.time import CAIRO
from app.live.robots import FILGOAL_HOST, GOAL_HOST, YALLAKORA_HOST, is_allowed
from app.live.sources import filgoal, goal, yallakora
from app.live.sources.common import safe_path
from app.live.types import SourceReading

log = logging.getLogger(__name__)

INTERVAL_S = 60.0
DEFAULT_PAGE_CAP = 12
ALERT_AFTER_ROUNDS = 5
HEARTBEAT_KEY = "live:capture:heartbeat"
HEARTBEAT_MAX_AGE = timedelta(minutes=5)
PLAYING = frozenset({"live", "halftime", "extra_time", "penalties"})

_UNSAFE_IN_A_NAME = re.compile(r"[^A-Za-z0-9_-]")
_REFUSED = re.compile(r"answered (?:403|429)$")

Fetch = Callable[[str, str], Any]
Alert = Callable[[str], bool]
Clock = Callable[[], datetime]


@dataclass(frozen=True, slots=True)
class ListSource:
    name: str
    host: str
    path: str
    parse: Callable[..., list[SourceReading]]


LISTS = (
    ListSource(filgoal.SOURCE, FILGOAL_HOST, filgoal.LIST_PATH, filgoal.parse_list),
    ListSource(yallakora.SOURCE, YALLAKORA_HOST, yallakora.LIST_PATH, yallakora.parse_list),
    ListSource(goal.SOURCE, GOAL_HOST, goal.LIST_PATH, goal.parse_list),
)


def enabled_lists(*, goal_enabled: bool) -> tuple[ListSource, ...]:
    """Switched off means no request at all, from the capture too (FR-014)."""
    return tuple(source for source in LISTS if source.name != goal.SOURCE or goal_enabled)


@dataclass(frozen=True, slots=True)
class Target:
    name: str
    host: str
    path: str


@dataclass(frozen=True, slots=True)
class SourceRound:
    read: bool  # its list answered
    live_rows: int = 0
    pages_saved: int = 0
    refused: bool = False  # it answered 403 or 429, so the rest of its round was skipped


@dataclass(frozen=True, slots=True)
class _SavedPage:
    body: bytes | None = None  # None after a logged failure of any kind
    refused: bool = False


def output_path(root: Path, target: Target, now: datetime) -> Path:
    """``<root>/capture/<Cairo date>/<UTC time>_<name>.html.gz``."""
    day = now.astimezone(CAIRO).date().isoformat()
    return root / "capture" / day / f"{now.astimezone(UTC):%H%M%S}_{target.name}.html.gz"


def _save_page(target: Target, fetch: Fetch, root: Path, clock: Clock) -> _SavedPage:
    """The page's body, saved. After a logged failure of any kind, the capture itself goes on."""
    if not is_allowed(target.host, target.path):
        log.warning("capture_denied", extra={"page": target.name, "path": target.path})
        return _SavedPage()
    try:
        page = fetch(f"https://{target.host}{target.path}", target.host)
        path = output_path(root, target, clock())
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(gzip.compress(page.body))
    except Exception as exc:  # noqa: BLE001 - a dropped connection on one page can't end a night's capture (R12)
        log.warning("capture_failed", extra={"page": target.name, "why": f"{type(exc).__name__}: {exc}"[:200]})
        # The fetcher has one exception for a refusal, a 5xx and an empty bucket, and only its message differs.
        return _SavedPage(refused=_REFUSED.search(str(exc)) is not None)
    return _SavedPage(page.body)


def _rows(source: ListSource, body: bytes, now: datetime) -> list[SourceReading]:
    """The page is saved already, and a changed shape is what the capture is there to record."""
    try:
        return source.parse(body, today=now.astimezone(CAIRO).date())
    except Exception as exc:  # noqa: BLE001 - the page is untrusted, and any error means the same here
        log.warning("capture_list_not_parsed", extra={"source": source.name, "why": repr(exc)[:200]})
        return []


def capture_source(source: ListSource, fetch: Fetch, root: Path, clock: Clock, page_cap: int) -> SourceRound:
    """One source's list and pages, until it refuses one. A row with an unknown status gets a page: it may be extra
    time.
    """
    listed = _save_page(Target(f"{source.name}_list", source.host, source.path), fetch, root, clock)
    if listed.body is None:
        return SourceRound(read=False, refused=listed.refused)
    rows = _rows(source, listed.body, clock())
    live_rows = sum(row.status in PLAYING for row in rows)
    chosen = [row for row in rows if safe_path(row.page_path) and (row.status in PLAYING or row.unknown_status)]
    saved = 1
    for row in chosen[:page_cap]:
        path = safe_path(row.page_path)
        assert path is not None  # filtered above
        name = f"{source.name}_{_UNSAFE_IN_A_NAME.sub('_', row.external_id)}"
        match_page = _save_page(Target(name, source.host, path), fetch, root, clock)
        if match_page.refused:
            return SourceRound(True, live_rows, saved, refused=True)
        if match_page.body is not None:
            saved += 1
    return SourceRound(True, live_rows, saved)


def _send(alert: Alert, text: str) -> None:
    try:
        if not alert(text):
            log.warning("capture_alert_not_sent", extra={"text": text})
    except Exception as exc:  # noqa: BLE001 - nothing about telling the owner can stop the capture
        log.warning("capture_alert_not_sent", extra={"text": text, "why": repr(exc)[:200]})


@dataclass
class _Watch:
    failed: int = 0
    quiet: int = 0
    failing_told: bool = False
    quiet_told: bool = False
    refused_last_round: bool = False
    stopped: bool = False  # refused twice in a row: nothing more goes to it until a restart


def _watch_refusal(name: str, watch: _Watch, result: SourceRound, alert: Alert) -> None:
    """A block isn't evaded (US4 scenario 2): one more try next round, then the source is left alone."""
    if not result.refused:
        if watch.refused_last_round:
            _send(alert, f"التسجيل: عاد {name} يقبل الطلبات.")
        watch.refused_last_round = False
        return
    if watch.refused_last_round:
        watch.stopped = True
        log.warning("capture_source_stopped", extra={"source": name})
        _send(alert, f"التسجيل: رفض {name} الطلبات جولتين متتاليتين، فتوقفت قراءته حتى إعادة التشغيل.")
    else:
        _send(alert, f"التسجيل: رفض {name} طلبًا (403 أو 429)، فانتهت جولته. يُجرَّب مرة في الجولة التالية.")
    watch.refused_last_round = True


def _watch_round(watches: Mapping[str, _Watch], rounds: Mapping[str, SourceRound], alert: Alert) -> None:
    """A failed read isn't quiet, and neither is a night when nobody shows a live row (FR-021)."""
    for name, result in rounds.items():
        watch = watches[name]
        _watch_refusal(name, watch, result, alert)
        others_live = any(other.live_rows for key, other in rounds.items() if key != name)
        watch.failed = 0 if result.read else watch.failed + 1
        watch.quiet = watch.quiet + 1 if result.read and not result.live_rows and others_live else 0
        if watch.failed >= ALERT_AFTER_ROUNDS and not watch.failing_told:
            watch.failing_told = True
            _send(alert, f"التسجيل: فشل {name} في {ALERT_AFTER_ROUNDS} جولات متتالية.")
        elif result.read and watch.failing_told:
            watch.failing_told = False
            _send(alert, f"التسجيل: عاد {name} للعمل.")
        if watch.quiet >= ALERT_AFTER_ROUNDS and not watch.quiet_told:
            watch.quiet_told = True
            _send(alert, f"التسجيل: {name} بلا مباريات جارية منذ {ALERT_AFTER_ROUNDS} جولات، وغيره يعرضها.")
        elif result.live_rows and watch.quiet_told:
            watch.quiet_told = False
            _send(alert, f"التسجيل: عاد {name} يعرض مباريات جارية.")


def _beat(client: redis.Redis, now: datetime) -> None:
    try:
        client.set(HEARTBEAT_KEY, now.isoformat())
    except (redis.RedisError, OSError) as exc:
        log.warning("capture_heartbeat_failed", extra={"why": repr(exc)[:200]})


def _clear_beat(client: redis.Redis) -> None:
    try:
        client.delete(HEARTBEAT_KEY)
    except (redis.RedisError, OSError) as exc:
        log.warning("capture_heartbeat_failed", extra={"why": repr(exc)[:200]})


def run_capture(
    sources: Sequence[ListSource],
    fetch: Fetch,
    root: Path,
    minutes: int,
    *,
    alert: Alert,
    client: redis.Redis,
    page_cap: int = DEFAULT_PAGE_CAP,
    clock: Clock = lambda: datetime.now(UTC),
    sleep: Callable[[float], None] = time.sleep,
) -> int:
    """Rounds about a minute apart until the time asked for has passed. Returns the pages saved."""
    end = clock() + timedelta(minutes=max(minutes, 1))
    _send(alert, f"بدأ التسجيل، وينتهي نحو {end.astimezone(CAIRO):%H:%M} بتوقيت القاهرة.")
    watches = {source.name: _Watch() for source in sources}
    saved = 0
    while (started := clock()) < end:
        rounds: dict[str, SourceRound] = {}
        for source in sources:
            if watches[source.name].stopped:
                continue
            # Before each source, as one slow source's pages can take minutes under its rate limit.
            _beat(client, clock())
            rounds[source.name] = capture_source(source, fetch, root, clock, page_cap)
        _beat(client, clock())
        _watch_round(watches, rounds, alert)
        saved += sum(result.pages_saved for result in rounds.values())
        sleep(max(0.0, INTERVAL_S - (clock() - started).total_seconds()))
    _clear_beat(client)
    _send(alert, f"انتهى التسجيل: {saved} صفحة تحت /srv/raw/capture/.")
    return saved


def _beat_is_old(value: bytes | str, now: datetime) -> bool:
    text = value.decode() if isinstance(value, bytes) else value
    try:
        return now - datetime.fromisoformat(text) > HEARTBEAT_MAX_AGE
    except ValueError:
        return True


def check_heartbeat(client: redis.Redis, now: datetime, alert: Alert) -> bool:
    """For ``live.watchdog``. ``True`` when it told the owner a capture stopped before its end.

    The key goes once the alert has gone, so one stop is one alert. A capture still running after all
    writes it back on its next round.
    """
    try:
        value = client.get(HEARTBEAT_KEY)
        if value is None or not _beat_is_old(value, now):  # type: ignore[arg-type]  # sync client, not awaitable
            return False
        if not alert("توقف التسجيل قبل نهايته: لا جولة منذ أكثر من 5 دقائق."):
            return False
        client.delete(HEARTBEAT_KEY)
    except (redis.RedisError, OSError) as exc:
        log.warning("capture_heartbeat_not_checked", extra={"why": repr(exc)[:200]})
        return False
    return True
