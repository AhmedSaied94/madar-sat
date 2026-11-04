"""Beat entries for the ingestion tasks (T066, R14, R16, R17, FR-026).

All times are UTC. ``app.workers`` reads ``BEAT_SCHEDULE`` (``workers.load_beat_schedule``); exactly
one ``beat`` runs, on VPS-2. Every source entry now calls ``adapters.schedule_fetch`` rather than
``adapters.fetch``: the pause and the breaker live in the database, and only VPS-2 can read them
(R17). ``schedule_fetch`` then sends the fetch to the source's own queue, so moving ysscores or
LiveSoccerTV between the home box and VPS-2 stays a setting, not a schedule change (R21).

The bridge runs 90 minutes after ysscores, so it adds what ysscores does not have instead of racing
it for the same fixture. The ``heartbeat-*`` entries keep one Kuma push monitor per Celery
queue alive, so a worker that dies goes quiet and Kuma alerts (R20). ``scrape-home-backlog`` does
the same for the home box from VPS-2, by the depth of its queue.
"""

from __future__ import annotations

from typing import Any

from celery.schedules import crontab

SCHEDULE_QUEUE = "imports"


def build_beat_schedule() -> dict[str, dict[str, Any]]:
    """Every entry: sources through ``schedule_fetch``, prune, and one heartbeat per queue."""
    return {
        "ysscores-fixtures": {
            "task": "adapters.schedule_fetch",
            "schedule": crontab(minute=0, hour="*/3"),
            "args": ("ysscores",),
            "options": {"queue": SCHEDULE_QUEUE},
        },
        "satair-bridge": {
            "task": "adapters.schedule_fetch",
            "schedule": crontab(minute=30, hour="1-22/3"),
            "args": ("legacy",),
            "options": {"queue": SCHEDULE_QUEUE},
        },
        "livesoccertv-48h": {
            "task": "adapters.schedule_fetch",
            "schedule": crontab(minute=45, hour="*/2"),
            "args": ("livesoccertv",),
            "options": {"queue": SCHEDULE_QUEUE},
        },
        "livesoccertv-t60": {
            "task": "adapters.schedule_fetch",
            "schedule": crontab(minute="*/10"),
            "args": ("livesoccertv",),
            "kwargs": {"window": "t60"},
            "options": {"queue": SCHEDULE_QUEUE},
        },
        # The Egyptian broadcaster (D5 FR-020): today to +3 once a day, then today every 6 h.
        "yallakora-daily": {
            "task": "adapters.schedule_fetch",
            "schedule": crontab(minute=20, hour=2),
            "args": ("yallakora",),
            "options": {"queue": SCHEDULE_QUEUE},
        },
        "yallakora-today": {
            "task": "adapters.schedule_fetch",
            "schedule": crontab(minute=20, hour="8,14,20"),
            "args": ("yallakora",),
            "kwargs": {"window": "today"},
            "options": {"queue": SCHEDULE_QUEUE},
        },
        "prune-raw-pages": {
            "task": "adapters.prune_raw_pages",
            "schedule": crontab(minute=15, hour=3),
            "args": (),
            "options": {"queue": "maintenance"},
        },
        "heartbeat-maintenance": {
            "task": "ops.heartbeat",
            "schedule": crontab(minute="*/5"),
            "args": ("maintenance",),
            "options": {"queue": "maintenance"},
        },
        "heartbeat-imports": {
            "task": "ops.heartbeat",
            "schedule": crontab(minute="*/5"),
            "args": ("imports",),
            "options": {"queue": "imports"},
        },
        "heartbeat-notifications": {
            "task": "ops.heartbeat",
            "schedule": crontab(minute="*/5"),
            "args": ("notifications",),
            "options": {"queue": "notifications"},
        },
        "heartbeat-live": {
            "task": "ops.heartbeat",
            "schedule": crontab(minute="*/5"),
            "args": ("live",),
            "options": {"queue": "live"},
        },
        # The home box cannot reach Kuma; VPS-2 reports how many fetches wait for it.
        "scrape-home-backlog": {
            "task": "ops.scrape_home_backlog",
            "schedule": crontab(minute="*/5"),
            "args": (),
            "options": {"queue": "imports"},
        },
    }


BEAT_SCHEDULE = build_beat_schedule()
