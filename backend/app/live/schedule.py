"""Beat entries for the live poller (005 contracts/live-pipeline.md, Tasks). All times are UTC."""

from __future__ import annotations

from datetime import timedelta
from typing import Any

from celery.schedules import crontab

BEAT_SCHEDULE: dict[str, dict[str, Any]] = {
    "live-scheduler": {
        "task": "live.scheduler",
        "schedule": timedelta(seconds=60),
        "options": {"queue": "live", "expires": 55},
    },
    "live-watchdog": {
        "task": "live.watchdog",
        "schedule": timedelta(minutes=2),
        "options": {"queue": "maintenance", "expires": 110},
    },
    "live-prune-runs": {
        "task": "live.prune_runs",
        "schedule": crontab(minute=40, hour=3),
        "options": {"queue": "maintenance"},
    },
    "live-check-robots": {
        "task": "live.check_robots",
        "schedule": crontab(minute=50, hour=3),
        "options": {"queue": "live"},
    },
}
