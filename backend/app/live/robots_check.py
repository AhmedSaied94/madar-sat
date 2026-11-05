"""Compares each site's ``robots.txt`` with the committed copy (research R4)."""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime
from typing import Any

import httpx
from sqlalchemy.orm import Session

from app.adapters.fetcher import FetchError
from app.live.problems import close_problem, open_problem
from app.live.robots import GOAL_HOST, ROBOTS_COPIES, committed_copy, normalized
from app.workers.base import Retryable

log = logging.getLogger(__name__)


def check_robots(
    session: Session, fetch: Callable[[str, str], Any], now: datetime, *, goal_enabled: bool = True
) -> list[str]:
    """The alerts to send after commit. A failed fetch says nothing about the rules: no change."""
    alerts: list[str | None] = []
    for host in ROBOTS_COPIES:
        if host == GOAL_HOST and not goal_enabled:
            continue  # switched off means no request at all (FR-014)
        try:
            page = fetch(f"https://{host}/robots.txt", host)
        except (Retryable, FetchError, httpx.HTTPError) as exc:
            log.info("robots_not_checked", extra={"host": host, "why": str(exc)[:200]})
            continue
        same = normalized(page.body.decode("utf-8", "replace")) == normalized(committed_copy(host))
        key = f"robots:{host}"
        alerts.append(close_problem(session, key, now) if same else open_problem(session, key, now))
    return [text for text in alerts if text is not None]
