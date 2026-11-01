"""Beat entries for the notifications tasks (contracts/pipelines-and-ops.md §Beat entries after D3).

Importing this module must never load ``app.settings`` or ``app.db``: ``app.workers`` merges it into
the beat schedule on the home box too, which has neither.
"""

from __future__ import annotations

from typing import Any

from celery.schedules import crontab


def build_beat_schedule() -> dict[str, dict[str, Any]]:
    return {
        "notify-schedule": {
            "task": "notifications.schedule_reminders",
            "schedule": crontab(minute="*/5"),
            "args": (),
            "options": {"queue": "notifications"},
        },
        "notify-dispatch": {
            "task": "notifications.dispatch_due",
            "schedule": crontab(minute="*"),
            "args": (),
            "options": {"queue": "notifications"},
        },
        "notify-prune": {
            "task": "notifications.prune_outbox",
            "schedule": crontab(minute=30, hour=4),
            "args": (),
            "options": {"queue": "maintenance"},
        },
    }


BEAT_SCHEDULE = build_beat_schedule()
