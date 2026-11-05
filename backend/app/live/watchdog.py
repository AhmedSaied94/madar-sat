"""What keeps a feed row honest when ``worker-live`` itself dies (research R6), the stuck limits and the pause."""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import and_, exists, or_, select
from sqlalchemy.orm import Session

from app.adapters.health import bump_datasets
from app.db.models import LiveProblem, LiveSourceState, Match, MatchLiveState, MatchSourceReading
from app.domain.status import STATUS_POSTPONED
from app.live.apply import LIVE_DATASET, reached_second_half, to_clock
from app.live.config import LiveSettings
from app.live.problems import close_problem, open_problem
from app.services.live import SETTLED_STATUSES, poll_window_query

# A match's own problems can't recover once it has left the window, so they close some time after.
PROBLEM_GRACE = timedelta(hours=1)
MATCH_PROBLEM_PREFIXES = ("disagree:", "stale:", "stuck:")
# The length of a match, not something to tune: a source below it may still be playing (FR-009).
FULL_MATCH_MINUTES = 90
USABLE_STATES = ("ok", "failing")
FINISHED_LABEL = "انتهت"


def _finish(session: Session, match: Match, now: datetime) -> str | None:
    """Finished on its last score, unless a person has answered for the status (FR-009)."""
    match.status = "finished"
    match.period = match.minute = None
    match.status_label = FINISHED_LABEL
    match.status_updated_at = now
    return open_problem(session, f"stuck:{match.id}", now)


def _status_locked(match: Match) -> bool:
    return "status" in (match.locked_fields or ())


def _finish_stuck(session: Session, now: datetime, settings: LiveSettings) -> tuple[list[str], bool]:
    """Second-half rows past the stuck limit whose score is quiet, with no usable source saying it's still on.

    A source says so with a peak below 90, or with a reading that has no stage: an unmapped status, or a page
    that says only ``live``. That can be extra time or a shoot-out, which waits for the hard limit (FR-009).
    """
    still_playing = exists().where(
        MatchSourceReading.match_id == Match.id,
        MatchSourceReading.read_at >= now - settings.stale_after,
        LiveSourceState.source == MatchSourceReading.source,
        LiveSourceState.state.in_(USABLE_STATES),
        or_(
            MatchSourceReading.peak_minute < FULL_MATCH_MINUTES,
            and_(
                MatchSourceReading.period.is_(None),
                or_(MatchSourceReading.status.is_(None), MatchSourceReading.status == "live"),
            ),
        ),
    )
    rows = session.scalars(
        select(Match)
        .outerjoin(MatchLiveState, MatchLiveState.match_id == Match.id)
        .where(
            Match.status_source == "feed",
            Match.status == "live",
            Match.period == "2H",
            Match.kickoff_at < now - settings.stuck_after,
            or_(
                MatchLiveState.score_changed_at.is_(None),
                MatchLiveState.score_changed_at < now - settings.stuck_quiet,
            ),
            ~still_playing,
        )
        .with_for_update(of=Match, skip_locked=True)
    ).all()
    finishing = [match for match in rows if not _status_locked(match)]
    alerts = [_finish(session, match, now) for match in finishing]
    return [alert for alert in alerts if alert], bool(finishing)


def run_watchdog(session: Session, now: datetime, settings: LiveSettings) -> list[str]:
    """Finishes stuck rows, moves stale ones to the clock and opens their problems; the alerts for after commit."""
    alerts, moved = _finish_stuck(session, now, settings)
    session.flush()
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
    for match in rows:
        alert: str | None = None
        past_limit = match.kickoff_at is not None and match.kickoff_at < now - settings.hard_limit
        if past_limit and reached_second_half(match) and not _status_locked(match):
            alert = _finish(session, match, now)
            moved = True
        elif to_clock(match, now, stuck_after=settings.stuck_after):
            alert = open_problem(session, f"stale:{match.id}", now)
            moved = True
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


def pause_feed_rows(session: Session, now: datetime, *, stuck_after: timedelta) -> bool:
    """A paused poller counts as every source down with no alert, so it can't leave stale scores (R6)."""
    rows = session.scalars(
        poll_window_query(now).where(Match.status_source == "feed").with_for_update(of=Match, skip_locked=True)
    ).all()
    moved = [to_clock(match, now, stuck_after=stuck_after) for match in rows]
    if any(moved):
        bump_datasets(session, [LIVE_DATASET])
    return any(moved)
