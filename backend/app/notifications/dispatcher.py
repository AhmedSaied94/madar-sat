"""The outbox dispatcher (research R7).

Claim rows with ``FOR UPDATE SKIP LOCKED``, resolve the audience with one ``SELECT DISTINCT``, build
each device's message, send one page of ≤ 500 through the sender, and record the page's result with
the cursor that lets a retry resume where it stopped. ``notification_outbox`` is the only producer
of push: nothing here is called from a request.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.models import Match, NotificationOutbox
from app.notifications.messages import MatchView, PushMessage, VisibleLink, build_message
from app.notifications.sender import PushSender
from app.workers.base import Retryable

log = logging.getLogger("madar.notifications")

PAGE_SIZE = 500
CLAIM_LIMIT = 10
STUCK_AFTER = timedelta(minutes=10)
# A row is tried this many times before it is marked failed: the same bound as the worker's
# ``max_retries``, but counted on the row so the every-minute beat cannot retry it for ever
# (B1-R1-4).
MAX_ATTEMPTS = 5
# A reminder whose match is in one of these states must never go out (B1-R1-5).
DEAD_STATUSES = ("postponed", "cancelled", "abandoned", "live", "finished")


@dataclass
class DispatchReport:
    claimed: list[int] = field(default_factory=list)
    sent: int = 0
    failed: int = 0
    cancelled: int = 0
    retry_row_id: int | None = None
    failed_row_id: int | None = None


@dataclass(frozen=True)
class AudienceDevice:
    id: int
    push_token: str
    satellite_ids: tuple[int, ...]
    prefs: dict[str, Any]


_RECLAIM = """
UPDATE notification_outbox
   SET status = 'pending', claimed_at = NULL
 WHERE status = 'sending' AND claimed_at IS NOT NULL AND claimed_at < :cutoff
"""

_CLAIM = """
SELECT id FROM notification_outbox
 WHERE status = 'pending' AND due_at <= :now
 ORDER BY due_at, id
 FOR UPDATE SKIP LOCKED
 LIMIT :limit
"""

_MARK_SENDING = """
UPDATE notification_outbox SET status = 'sending', claimed_at = :now WHERE id = ANY(:ids)
"""

_VISIBLE_LINKS = """
SELECT c.id,
       COALESCE(c.display_name, c.name) AS name,
       c.access,
       c.sort_order,
       c.show_in_match,
       c.satellite_id,
       s.slug AS satellite_slug,
       s.name_ar AS satellite_name
  FROM match_channels mc
  JOIN channels c ON c.id = mc.channel_id
  LEFT JOIN satellites s ON s.id = c.satellite_id
 WHERE mc.match_id = :match_id
   AND mc.is_hidden = false
   AND c.deleted_at IS NULL
   AND c.placeholder_source IS NULL
   AND c.name_norm NOT IN (SELECT name FROM hidden_channel_names)
   AND ar_normalize(COALESCE(c.display_name, '')) NOT IN (SELECT name FROM hidden_channel_names)
 ORDER BY c.sort_order NULLS LAST, c.id
"""

# The owner reviews this query (brief, research R7): one DISTINCT audience per page, bound
# parameters only, and the device's type switch honoured in SQL so a page never carries a device
# that turned the reminder off. An empty token is not a device FCM can reach, and it would fail
# the whole page (B1-R1-1), so it is filtered here as well as refused by the API.
AUDIENCE = """
SELECT DISTINCT d.id, d.push_token, d.satellite_ids, d.prefs
  FROM devices d
  JOIN device_follows f ON f.device_id = d.id
 WHERE d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
   AND d.id > :cursor
   AND (f.match_id = :match_id
        OR f.competition_id = :competition_id
        OR f.team_id IN (:home_team_id, :away_team_id))
   AND COALESCE((d.prefs #>> '{types,kickoff_reminder,on}')::boolean, true)
 ORDER BY d.id
 LIMIT :limit
"""

_RECORD_PAGE = """
UPDATE notification_outbox
   SET sent = sent + :sent, failed = failed + :failed, cursor_device_id = :cursor
 WHERE id = :id
"""

_CLEAR_TOKENS = "UPDATE devices SET push_token = NULL WHERE push_token = ANY(:tokens)"

# A row's attempts are counted on the row, not on the worker: the beat claims a released row
# again every minute, so the task's own retry counter alone never runs out (B1-R1-4).
_MARK_FAILED = """
UPDATE notification_outbox SET status = 'failed', claimed_at = NULL
 WHERE id = ANY(:ids) AND status IN ('pending', 'sending')
"""

_BUMP_ATTEMPTS = "UPDATE notification_outbox SET attempts = attempts + 1 WHERE id = :id RETURNING attempts"

_RELEASE = """
UPDATE notification_outbox SET status = 'pending', claimed_at = NULL
 WHERE id = ANY(:ids) AND status = 'sending'
"""

_PRUNE = """
DELETE FROM notification_outbox
 WHERE status IN ('sent', 'failed', 'cancelled')
   AND COALESCE(sent_at, created_at) < :cutoff
"""


def _rowcount(result: object) -> int:
    return int(getattr(result, "rowcount", 0) or 0)


def reclaim_stuck(session: Session, now: datetime) -> int:
    """Rows a dead worker left in ``sending`` go back to ``pending``, keeping their cursor."""
    return _rowcount(session.execute(text(_RECLAIM), {"cutoff": now - STUCK_AFTER}))


def claim(session: Session, now: datetime, limit: int = CLAIM_LIMIT) -> list[int]:
    """Lock up to ``limit`` due rows and mark them ``sending`` in a short transaction."""
    ids = list(session.execute(text(_CLAIM), {"now": now, "limit": limit}).scalars().all())
    if ids:
        session.execute(text(_MARK_SENDING), {"ids": ids, "now": now})
    session.commit()
    return ids


def visible_links(session: Session, match_id: int) -> list[VisibleLink]:
    rows = session.execute(text(_VISIBLE_LINKS), {"match_id": match_id}).mappings().all()
    return [
        VisibleLink(
            channel_id=row["id"],
            name=row["name"],
            access=row["access"],
            sort_order=row["sort_order"],
            show_in_match=row["show_in_match"],
            satellite_id=row["satellite_id"],
            satellite_slug=row["satellite_slug"],
            satellite_name=row["satellite_name"],
        )
        for row in rows
    ]


def audience_page(session: Session, match: Match, cursor: int, limit: int = PAGE_SIZE) -> list[AudienceDevice]:
    """One page of the match's audience: devices following the home team, the away team, the
    competition or the match itself, that have a push token and the reminder switched on."""
    rows = session.execute(
        text(AUDIENCE),
        {
            "cursor": cursor,
            "match_id": match.id,
            "competition_id": match.competition_id,
            "home_team_id": match.home_team_id,
            "away_team_id": match.away_team_id,
            "limit": limit,
        },
    ).mappings()
    return [
        AudienceDevice(
            id=row["id"],
            push_token=row["push_token"],
            satellite_ids=tuple(row["satellite_ids"] or ()),
            prefs=row["prefs"] or {},
        )
        for row in rows
    ]


def _cancelled(match: Match | None, now: datetime) -> bool:
    """A row that must not go out: no kickoff, a dead status, or a kickoff that has passed.

    The last one is what stops an outage from telling followers that a match already in play starts
    in a minute (B1-R1-5).
    """
    return (
        match is None
        or match.kickoff_at is None
        or match.time_tbd
        or match.kickoff_at <= now
        or match.status in DEAD_STATUSES
    )


def dispatch_row(session: Session, outbox_id: int, sender: PushSender, now: datetime, pwa_origin: str | None) -> str:
    """Send one claimed row to its whole audience, page by page. Returns ``sent`` or ``cancelled``.

    Raises :class:`Retryable` from a page's whole-call failure, or from a page that delivered to
    nobody while a device was still ``retryable`` after the sender's own re-sends, after committing
    the pages already recorded, so the retry resumes at ``cursor_device_id``.
    """
    row = session.get(NotificationOutbox, outbox_id)
    if row is None:
        return "gone"
    match_id = int((row.payload or {}).get("match_id", 0))
    match = session.get(Match, match_id) if match_id else None
    if _cancelled(match, now):
        row.status = "cancelled"
        session.commit()
        return "cancelled"

    assert match is not None  # narrowed by _cancelled
    kickoff = match.kickoff_at
    assert kickoff is not None
    view = MatchView(
        id=match.id,
        kickoff_at=kickoff,
        home_name=match.home_team_name,
        away_name=match.away_team_name,
    )
    links = visible_links(session, match.id)
    cursor = row.cursor_device_id or 0

    while True:
        devices = audience_page(session, match, cursor)
        if not devices:
            break
        messages: list[PushMessage] = []
        for device in devices:
            message = build_message(view, links, device.satellite_ids, pwa_origin, now)
            messages.append(
                PushMessage(
                    token=device.push_token,
                    title=message.title,
                    body=message.body,
                    data=message.data,
                    tag=message.tag,
                    link=message.link,
                )
            )
        outcome = sender.send_page(messages)
        if outcome.unregistered:
            session.execute(text(_CLEAR_TOKENS), {"tokens": list(outcome.unregistered)})
        if outcome.retryable and not outcome.sent:
            # FCM took nobody on this page, so sending the page again repeats nothing: it is not
            # recorded, and the cursor/``attempts`` path retries it (B1-R2-1).
            raise Retryable(f"FCM could not take {len(outcome.retryable)} messages; the page is retried")
        # Some devices on the page already have the message and the cursor cannot say which, so the
        # page is not sent again whole: a device the sender's own re-sends could not reach is a
        # failed one (it was retried with backoff first), and the page is recorded.
        failed = outcome.failed + len(outcome.retryable)
        if failed:
            # A device that did not get the reminder is worth an alert: it is usually a bad message
            # field or an outage, not a dead token (B1-R1-2).
            log.error("push_page_failed", extra={"row": outbox_id, "failed": failed})
        session.execute(
            text(_RECORD_PAGE),
            {"id": outbox_id, "sent": outcome.sent, "failed": failed, "cursor": devices[-1].id},
        )
        session.commit()
        cursor = devices[-1].id
        if len(devices) < PAGE_SIZE:
            break

    row = session.get(NotificationOutbox, outbox_id, populate_existing=True)
    if row is not None:
        row.status = "sent"
        row.sent_at = now
        session.commit()
    return "sent"


def dispatch_due(
    session: Session,
    sender: PushSender,
    now: datetime,
    pwa_origin: str | None = None,
    limit: int = CLAIM_LIMIT,
) -> DispatchReport:
    """Reclaim, claim and dispatch. A whole-call failure stops the run at its row.

    The failing row goes back to ``pending`` with its cursor while it has attempts left; at
    :data:`MAX_ATTEMPTS` it becomes ``failed`` and is never claimed again. Every row claimed after
    it goes back to ``pending`` too, so a failed page never strands them in ``sending`` for
    :data:`STUCK_AFTER` (B1-R1-1, B1-R1-4).
    """
    report = DispatchReport()
    reclaim_stuck(session, now)
    session.commit()

    report.claimed = claim(session, now, limit)
    for index, outbox_id in enumerate(report.claimed):
        try:
            outcome = dispatch_row(session, outbox_id, sender, now, pwa_origin)
        except Retryable:
            # The pages already recorded stay recorded; the row goes back to pending with its cursor,
            # so the retry resumes where it stopped and never sends page one twice.
            attempts = int(session.execute(text(_BUMP_ATTEMPTS), {"id": outbox_id}).scalar_one())
            if attempts >= MAX_ATTEMPTS:
                session.execute(text(_MARK_FAILED), {"ids": [outbox_id]})
                report.failed_row_id = outbox_id
                log.error("dispatch_failed", extra={"row": outbox_id, "attempts": attempts})
            else:
                session.execute(text(_RELEASE), {"ids": [outbox_id]})
                report.retry_row_id = outbox_id
            stranded = report.claimed[index + 1 :]
            if stranded:
                session.execute(text(_RELEASE), {"ids": stranded})
            session.commit()
            break
        if outcome == "cancelled":
            report.cancelled += 1
        elif outcome == "sent":
            report.sent += 1
    return report


def mark_failed(session: Session, outbox_id: int) -> None:
    """The row whose retries are exhausted, whatever state the retry left it in."""
    session.execute(text(_MARK_FAILED), {"ids": [outbox_id]})
    session.commit()


def prune_outbox(session: Session, now: datetime, keep: timedelta = timedelta(days=30)) -> int:
    """Rows kept 30 days for A15, then deleted (contracts/pipelines-and-ops.md)."""
    return _rowcount(session.execute(text(_PRUNE), {"cutoff": now - keep}))
