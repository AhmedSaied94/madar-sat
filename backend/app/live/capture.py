"""The small recorder that completes the parsers from real live pages (research R1, T019).

``capture-live`` saves both list pages every 60 s and the chosen match pages under
``/srv/raw/capture/<date>/``, through the deny list, ``HttpFetcher`` and the shared buckets. Reads only;
it writes nothing to the database.
"""

from __future__ import annotations

import logging
import time
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import httpx

from app.adapters.fetcher import FetchError
from app.domain.time import CAIRO
from app.live.robots import FILGOAL_HOST, YALLAKORA_HOST, is_allowed
from app.live.sources import filgoal, yallakora
from app.workers.base import Retryable

log = logging.getLogger(__name__)

INTERVAL_S = 60.0
LISTS = (
    ("filgoal_list", FILGOAL_HOST, filgoal.LIST_PATH),
    ("yallakora_list", YALLAKORA_HOST, yallakora.LIST_PATH),
)


@dataclass(frozen=True, slots=True)
class Target:
    name: str
    host: str
    path: str


def targets(filgoal_ids: Sequence[str], yallakora_paths: Sequence[str]) -> list[Target]:
    """Both lists, then the chosen match pages. A path the deny list covers fails before any request."""
    found = [Target(name, host, path) for name, host, path in LISTS]
    found += [Target(f"filgoal_{item}", FILGOAL_HOST, filgoal.match_path(item)) for item in filgoal_ids]
    for number, item in enumerate(yallakora_paths, start=1):
        found.append(Target(f"yallakora_{number}", YALLAKORA_HOST, urlsplit(item).path))
    for target in found:
        if not is_allowed(target.host, target.path):
            raise ValueError(f"{target.host}{target.path} is off limits (robots.txt)")
    return found


def output_path(root: Path, target: Target, now: datetime) -> Path:
    """``<root>/capture/<Cairo date>/<UTC time>_<name>.html``."""
    day = now.astimezone(CAIRO).date().isoformat()
    return root / "capture" / day / f"{now.astimezone(UTC):%H%M%S}_{target.name}.html"


def capture_once(items: Sequence[Target], fetch: Callable[[str, str], Any], root: Path, now: datetime) -> int:
    """One round; a failed page is logged and the rest go on. Returns the pages saved."""
    saved = 0
    for target in items:
        try:
            page = fetch(f"https://{target.host}{target.path}", target.host)
        except (Retryable, FetchError, httpx.HTTPError) as exc:
            log.warning("capture_failed", extra={"page": target.name, "why": str(exc)[:200]})
            continue
        path = output_path(root, target, now)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(page.body)
        saved += 1
    return saved


def run_capture(
    items: Sequence[Target],
    fetch: Callable[[str, str], Any],
    root: Path,
    minutes: int,
    *,
    clock: Callable[[], datetime] = lambda: datetime.now(UTC),
    sleep: Callable[[float], None] = time.sleep,
) -> int:
    saved = 0
    for _ in range(max(minutes, 1)):
        saved += capture_once(items, fetch, root, clock())
        sleep(INTERVAL_S)
    return saved
