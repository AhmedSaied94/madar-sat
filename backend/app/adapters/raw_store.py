"""Raw pages on VPS-2: ``/srv/raw/<source>/<YYYY-MM-DD>/<run_id>/`` and its 5-day retention (T070, R15).

``ingest`` saves the pages it received, whichever host fetched them, and points
``import_runs.raw_path`` at this folder. ``run.json`` holds the counts, the skipped items and the
names that could not be resolved, which is where an editor looks after a ``partial`` run.
"""

from __future__ import annotations

import gzip
import json
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


def _safe(name: str) -> str:
    """A run id is used as a folder name: keep it to one path component."""
    cleaned = name.replace("/", "-").replace("\\", "-").strip(". ")
    return cleaned or "run"
