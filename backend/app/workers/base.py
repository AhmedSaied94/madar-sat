"""The base task class every Celery task uses (research R13, constitution VII)."""

from __future__ import annotations

import httpx
from celery import Task


class Retryable(Exception):
    """Raise from a task for a transient failure (429, 403, 5xx): Celery backs off and retries."""


class BaseTask(Task):  # type: ignore[misc]
    """``autoretry_for`` transient errors, with exponential backoff and jitter, at most 5 retries.

    Tasks are declared with ``app.workers.task``, which also binds them (``self`` first).
    """

    autoretry_for = (Retryable, httpx.TransportError)
    retry_backoff = True
    retry_backoff_max = 600
    retry_jitter = True
    max_retries = 5
