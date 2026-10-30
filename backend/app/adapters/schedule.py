"""Beat entries for the ingestion tasks (T076, R16, R19, FR-026).

All times are UTC. ``app.workers`` takes ``beat_schedule`` as its schedule; exactly one ``beat``
runs, on VPS-2. The bridge runs 90 minutes after ysscores, so it adds what ysscores does not have
instead of racing it for the same fixture.

The ysscores queue is read when the module is imported, from ``YSSCORES_FETCH_QUEUE``: the container
has its environment before the process starts, so a changed value needs a restarted worker and
``beat`` (the runbook says so).
"""

from __future__ import annotations

from typing import Any

# Celery ships no stubs (the dependency is Lane B1's, T001).
from celery.schedules import crontab  # type: ignore[import-untyped]

from app.adapters.config import get_adapter_settings


def ysscores_queue() -> str:
    """``scrape_home`` (the home box, the default) or ``scrape`` on VPS-2 (R21)."""
    return get_adapter_settings().ysscores_fetch_queue


def build_beat_schedule(ysscores: str | None = None) -> dict[str, dict[str, Any]]:
    """The three entries; ``ysscores`` overrides the queue, which keeps the tests simple."""
    return {
        "ysscores-fixtures": {
            "task": "adapters.fetch",
            "schedule": crontab(minute=0, hour="*/3"),
            "args": ("ysscores",),
            "options": {"queue": ysscores or ysscores_queue()},
        },
        "satair-bridge": {
            "task": "adapters.fetch",
            "schedule": crontab(minute=30, hour="1-22/3"),
            "args": ("legacy",),
            "options": {"queue": "scrape"},
        },
        "prune-raw-pages": {
            "task": "adapters.prune_raw_pages",
            "schedule": crontab(minute=15, hour=3),
            "args": (),
            "options": {"queue": "maintenance"},
        },
    }


beat_schedule = build_beat_schedule()
