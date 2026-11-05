"""What keeps a feed row honest when ``worker-live`` itself dies (research R6), and the pause."""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.adapters.health import bump_datasets
from app.db.models import LiveProblem, Match, MatchLiveState
from app.domain.status import STATUS_POSTPONED
from app.live.apply import LIVE_DATASET, to_clock
from app.live.config import LiveSettings
from app.live.problems import close_problem, open_problem
from app.services.live import SETTLED_STATUSES, poll_window_query

# A match's own problems can't recover once it has left the window, so they close some time after.
PROBLEM_GRACE = timedelta(hours=1)
MATCH_PROBLEM_PREFIXES = ("disagree:", "stale:")


def run_watchdog(session: Session, now: datetime, settings: LiveSettings) -> list[str]:
    """Moves stale ``feed`` rows to the clock and opens ``stale:<id>``; the alerts to send after commit."""
    rows = session.scalars(
        select(Match)
        .outerjoin(MatchLiveState, MatchLiveState.match_id == Match.id)
        .where(
            Match.status_source == "feed",
            Match.status.not_in((*SETTLED_STATUSES, STATUS_POSTPONED)),
            or_(
                Match.kickoff_at < now - settings.hard_limit,
                MatchLiveState.last_reading_at.is_(None),
                MatchLiveState.last_reading_at < now - settings.stale_after,
            ),
        )
        .with_for_update(of=Match, skip_locked=True)
    ).all()
    alerts: list[str] = []
    moved = False
    for match in rows:
        if to_clock(match, now):
            moved = True
            alert = open_problem(session, f"stale:{match.id}", now)
            if alert:
                alerts.append(alert)
    if moved:
        bump_datasets(session, [LIVE_DATASET])
    alerts += _close_past_matches(session, now, settings)
    return alerts


def _close_past_matches(session: Session, now: datetime, settings: LiveSettings) -> list[str]:
    keys = session.scalars(
        select(LiveProblem.key).where(
            LiveProblem.closed_at.is_(None),
            or_(*(LiveProblem.key.startswith(prefix) for prefix in MATCH_PROBLEM_PREFIXES)),
        )
    ).all()
    alerts: list[str] = []
    for key in keys:
        match = session.get(Match, int(key.partition(":")[2]))
        kickoff = match.kickoff_at if match is not None else None
        if kickoff is None or kickoff < now - settings.hard_limit - PROBLEM_GRACE:
            alert = close_problem(session, key, now)
            if alert:
                alerts.append(alert)
    return alerts


def pause_feed_rows(session: Session, now: datetime) -> bool:
    """A paused poller counts as both sources down with no alert, so it can't leave stale scores (R6)."""
    rows = session.scalars(
        poll_window_query(now).where(Match.status_source == "feed").with_for_update(of=Match, skip_locked=True)
    ).all()
    moved = [to_clock(match, now) for match in rows]
    if any(moved):
        bump_datasets(session, [LIVE_DATASET])
    return any(moved)
