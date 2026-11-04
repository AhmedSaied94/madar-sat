"""Raw pages on VPS-2: ``/srv/raw/<source>/<YYYY-MM-DD>/<run_id>/`` and its 5-day retention (T070, R15).

``ingest`` saves the pages it received, whichever host fetched them, and points
``import_runs.raw_path`` at this folder. ``run.json`` holds the counts, the skipped items and the
names that could not be resolved, which is where an editor looks after a ``partial`` run.
"""

from __future__ import annotations

import codecs
import gzip
import json
import re
import shutil
from collections.abc import Mapping, Sequence
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

from app.adapters.base import RawPage

RETENTION_DAYS = 5
RUN_INFO = "run.json"
# A fetched page's extension, per source: ysscores answers HTML, the bridge JSON (data-model).
SUFFIX = {"ysscores": "html", "legacy": "json"}
DEFAULT_SUFFIX = "html"
CONTENT_TYPES = {"html": "text/html", "json": "application/json"}
GONE: dict[str, Any] = {"gone": True}
_PAGE_FILE = re.compile(r"^(\d+)\.([a-z]+)\.gz$")


class RawStore:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root)

    def save(
        self,
        *,
        source: str,
        run_day: date,
        run_id: str,
        pages: Sequence[RawPage],
        run_info: Mapping[str, Any] | None = None,
    ) -> Path:
        """Write the pages gzipped and ``run.json``; return the run folder."""
        run_dir = self.root / source / run_day.isoformat() / _safe(run_id)
        run_dir.mkdir(parents=True, exist_ok=True)
        suffix = SUFFIX.get(source, DEFAULT_SUFFIX)
        for n, page in enumerate(pages, start=1):
            (run_dir / f"{n}.{suffix}.gz").write_bytes(gzip.compress(page.body, mtime=0))
        (run_dir / RUN_INFO).write_text(
            json.dumps(dict(run_info or {}), ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8"
        )
        return run_dir

    def prune_raw_pages(self, *, now: datetime | None = None, days: int = RETENTION_DAYS) -> int:
        """Delete run folders whose day is older than ``days``; return how many runs went."""
        current = now if now is not None else datetime.now(UTC)
        cutoff = current.date() - timedelta(days=days)
        removed = 0
        if not self.root.is_dir():
            return 0
        for source_dir in sorted(p for p in self.root.iterdir() if p.is_dir()):
            for day_dir in sorted(p for p in source_dir.iterdir() if p.is_dir()):
                try:
                    day = date.fromisoformat(day_dir.name)
                except ValueError:
                    continue  # not one of ours; leave it alone
                if day >= cutoff:
                    continue
                for run_dir in sorted(p for p in day_dir.iterdir() if p.is_dir()):
                    shutil.rmtree(run_dir, ignore_errors=False)
                    removed += 1
                try:
                    day_dir.rmdir()
                except OSError:
                    pass  # something else in there; keep the day folder
        return removed


def read_page(root: str | Path, raw_path: str | None, page: int, *, max_bytes: int) -> dict[str, Any]:
    """One saved page of a run as ``rawview:`` holds it, or ``{"gone": True}`` if it can't be read (D5 R13)."""
    base = Path(root).resolve()
    if not raw_path:
        return GONE
    run_dir = (base / raw_path).resolve()
    if not run_dir.is_relative_to(base) or not run_dir.is_dir():
        return GONE
    numbered = sorted((int(found.group(1)), found.group(2), path.name) for path, found in _saved_pages(run_dir))
    if not 0 <= page < len(numbered):
        return GONE
    _, suffix, filename = numbered[page]
    try:
        with gzip.open(run_dir / filename) as handle:
            body = handle.read(max_bytes + 1)  # never inflate more than the view can hold
    except (OSError, EOFError):
        return GONE
    # Incremental, so a cap inside a character drops that character instead of garbling it.
    text = codecs.getincrementaldecoder("utf-8")("replace").decode(body[:max_bytes], final=len(body) <= max_bytes)
    return {
        "pages": len(numbered),
        "url": _page_url(run_dir, page),
        "content_type": CONTENT_TYPES.get(suffix, "text/plain"),
        "text": text,
        "truncated": len(body) > max_bytes,
    }


def _saved_pages(run_dir: Path) -> list[tuple[Path, re.Match[str]]]:
    return [(path, found) for path in run_dir.iterdir() if (found := _PAGE_FILE.match(path.name))]


def _page_url(run_dir: Path, page: int) -> str | None:
    """``run.json`` names the pages; a run from before D5, or one whose file is gone, doesn't."""
    try:
        urls = json.loads((run_dir / RUN_INFO).read_text(encoding="utf-8")).get("page_urls") or []
    except (OSError, ValueError, AttributeError):
        return None
    return urls[page] if page < len(urls) else None


def _safe(name: str) -> str:
    """A run id is used as a folder name: keep it to one path component."""
    cleaned = name.replace("/", "-").replace("\\", "-").strip(". ")
    return cleaned or "run"
