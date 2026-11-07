"""The outbox dispatcher (research R7, R8, R9).

One row at a time, best first: a live type (``goal``, ``match_started``, ``final_score``) ahead of an
older announcement, so a big send never holds a goal. Each turn sends at most 20 pages of one row, then
returns it to ``pending`` with its cursor, so a 50,000-device announcement takes several turns and the
50-second run limit ends cleanly with a re-queue.

Before the first page the row is checked in this order: channel changes are netted, a frequency hold
writes its history, ``PUSH_TYPES_OFF`` cancels, then :func:`app.notifications.policy.decide` judges age
and the match's state. A cancelled or failed row keeps a short reason in ``error`` for A15.
"""

from __future__ import annotations

import logging
import time
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.db.models import Channel, Match, MatchEvent, NotificationOutbox, Satellite
from app.notifications.messages import (
    ChannelView,
    FrequencyReadout,
    GoalEvent,
    MatchView,
    PushMessage,
    VisibleLink,
    build_announcement,
    build_channels_updated,
    build_correction,
    build_final_score,
    build_frequency_changed,
    build_goal,
    build_match_started,
    build_message,
)
from app.notifications.policy import Cancel, decide, parse_types_off
from app.notifications.sender import PushRetryable, PushSender
from app.services.match_detail import EVENT_SOURCES
from app.workers.base import Retryable

log = logging.getLogger("madar.notifications")

PAGE_SIZE = 500
CLAIM_LIMIT = 10
STUCK_AFTER = timedelta(minutes=10)
# A row is tried this many times before it is marked failed: the same bound as the worker's
# ``max_retries``, but counted on the row so the every-minute beat cannot retry it for ever (B1-R1-4).
MAX_ATTEMPTS = 5
# A reminder whose match is in one of these states must never go out (B1-R1-5).
DEAD_STATUSES = ("postponed", "cancelled", "abandoned", "live", "finished")
# One turn's budget (R8): 10,000 devices, then the row is released for the next turn.
PAGES_PER_TURN = 20
RUN_SECONDS = 50
PRIORITY_TYPES = ("goal", "match_started", "final_score")
# The `push` problem (research R11): a send of at least this many devices, failing above this share.
ALERT_MIN_DEVICES = 10
ALERT_FAIL_SHARE = 0.20


@dataclass
class DispatchReport:
    claimed: list[int] = field(default_factory=list)
    sent: int = 0
    failed: int = 0
    cancelled: int = 0
    deferred: int = 0
    requeued: bool = False
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

# One row at a time, live types first (R8). The owner reviews the audience queries below.
_CLAIM_ONE = """
SELECT id FROM notification_outbox
 WHERE status = 'pending' AND due_at <= :now
 ORDER BY CASE WHEN type IN ('goal', 'match_started', 'final_score') THEN 0 ELSE 1 END, due_at, id
 LIMIT 1
 FOR UPDATE SKIP LOCKED
"""

_CLAIM = """
SELECT id FROM notification_outbox
 WHERE status = 'pending' AND due_at <= :now
 ORDER BY CASE WHEN type IN ('goal', 'match_started', 'final_score') THEN 0 ELSE 1 END, due_at, id
 FOR UPDATE SKIP LOCKED
 LIMIT :limit
"""

_MARK_SENDING = "UPDATE notification_outbox SET status = 'sending', claimed_at = :now WHERE id = ANY(:ids)"

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

# The follow audience (R7): one DISTINCT device per page, bound parameters only. A parameter a kind
# doesn't use stays NULL and its comparison is false. The device's master switch and the type's own
# switch are honoured in SQL, so a page never carries a device that turned the type off.
AUDIENCE = """
SELECT DISTINCT d.id, d.push_token, d.satellite_ids, d.prefs
  FROM devices d
  JOIN device_follows f ON f.device_id = d.id
 WHERE d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
   AND d.id > :cursor
   AND (f.match_id = CAST(:match_id AS bigint)
        OR f.competition_id = CAST(:competition_id AS bigint)
        OR f.team_id IN (CAST(:home_team_id AS bigint), CAST(:away_team_id AS bigint))
        OR f.channel_id = CAST(:channel_id AS bigint))
   AND COALESCE((d.prefs ->> 'enabled')::boolean, true)
   AND COALESCE((d.prefs -> 'types' -> CAST(:type AS text) ->> 'on')::boolean, :default_on)
 ORDER BY d.id
 LIMIT :limit
"""

# No follows, so nothing to de-duplicate.
AUDIENCE_ALL = """
SELECT d.id, d.push_token, d.satellite_ids, d.prefs
  FROM devices d
 WHERE d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
   AND d.id > :cursor
   AND COALESCE((d.prefs ->> 'enabled')::boolean, true)
   AND COALESCE((d.prefs -> 'types' -> CAST(:type AS text) ->> 'on')::boolean, :default_on)
 ORDER BY d.id
 LIMIT :limit
"""

# A test send: one device, whatever its prefs (FR-016).
AUDIENCE_DEVICE = """
SELECT d.id, d.push_token, d.satellite_ids, d.prefs
  FROM devices d
 WHERE d.id = CAST(:device_id AS bigint)
   AND d.id > :cursor
   AND d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
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
UPDATE notification_outbox SET status = 'failed', claimed_at = NULL, error = COALESCE(:error, error)
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

# The audience kind chooses the query and which parameters are set (push-pipeline "Audiences").
_FOLLOW_KINDS = ("match_followers", "match_core", "match_only", "channel", "team", "competition")


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


def claim_next(session: Session, now: datetime) -> int | None:
    """The best due row, locked and marked ``sending``; ``None`` when nothing is due."""
    row = session.execute(text(_CLAIM_ONE), {"now": now}).first()
    if row is None:
        session.commit()
        return None
    outbox_id = int(row[0])
    session.execute(text(_MARK_SENDING), {"ids": [outbox_id], "now": now})
    session.commit()
    return outbox_id


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


# --- The audience ------------------------------------------------------------------------------------


def _audience_target(audience: Mapping[str, Any], match: Match | None) -> dict[str, Any]:
    kind = str(audience.get("kind") or "all")
    params: dict[str, Any] = {
        "match_id": None,
        "competition_id": None,
        "home_team_id": None,
        "away_team_id": None,
        "channel_id": None,
        "device_id": None,
    }
    if kind in ("match_followers", "match_core", "match_only"):
        params["match_id"] = audience.get("match_id")
        if kind in ("match_followers", "match_core") and match is not None:
            params["home_team_id"] = match.home_team_id
            params["away_team_id"] = match.away_team_id
            if kind == "match_followers":
                params["competition_id"] = match.competition_id
    elif kind == "channel":
        params["channel_id"] = audience.get("channel_id")
    elif kind == "team":
        params["home_team_id"] = audience.get("team_id")
    elif kind == "competition":
        params["competition_id"] = audience.get("competition_id")
    elif kind == "device":
        params["device_id"] = audience.get("device_id")
    return params


def _audience_sql(audience: Mapping[str, Any]) -> str:
    kind = str(audience.get("kind") or "all")
    if kind == "all":
        return AUDIENCE_ALL
    if kind == "device":
        return AUDIENCE_DEVICE
    return AUDIENCE


def audience_page(
    session: Session,
    row: NotificationOutbox,
    match: Match | None,
    cursor: int,
    limit: int = PAGE_SIZE,
) -> list[AudienceDevice]:
    """One page of a row's audience: the query its ``audience.kind`` names, prefs honoured in SQL."""
    audience = row.audience or {}
    params = _audience_target(audience, match)
    params.update(
        {
            "cursor": cursor,
            "limit": limit,
            "type": _switch_type(row),
            "default_on": _default_on(row),
        }
    )
    rows = session.execute(text(_audience_sql(audience)), params).mappings()
    return [
        AudienceDevice(
            id=item["id"],
            push_token=item["push_token"],
            satellite_ids=tuple(item["satellite_ids"] or ()),
            prefs=item["prefs"] or {},
        )
        for item in rows
    ]


def _switch_type(row: NotificationOutbox) -> str:
    """A correction reads the ``goal`` switch (data-model ``notification_outbox.payload``)."""
    payload = row.payload or {}
    return "goal" if row.type == "goal" and payload.get("kind") == "correction" else row.type


def _default_on(row: NotificationOutbox) -> bool:
    from app.notifications.policy import default_on

    return default_on(_switch_type(row))


# --- Cancelling -------------------------------------------------------------------------------------


def _cancel(session: Session, row: NotificationOutbox, reason: str, now: datetime) -> str:
    row.status = "cancelled"
    row.error = reason
    row.sent_at = None
    session.commit()
    log.info("push_cancelled", extra={"row": row.id, "reason": reason, "at": now.isoformat()})
    return "cancelled"


def _cancelled(match: Match | None, now: datetime) -> bool:
    """A reminder that must not go out: no kickoff, a dead status, or a kickoff that has passed."""
    return (
        match is None
        or match.kickoff_at is None
        or match.time_tbd
        or match.kickoff_at <= now
        or match.status in DEAD_STATUSES
    )


# --- The row's own preparations, before the first page ------------------------------------------------


def _prepare_channels(session: Session, row: NotificationOutbox, match: Match, now: datetime) -> str | None:
    """Net the unannounced changes once and store the ids, so a retry sends the same message (R5)."""
    from app.notifications.channel_changes import net_pending

    payload = dict(row.payload or {})
    if "added" not in payload and "removed" not in payload:
        added, removed = net_pending(session, match.id, now)
        payload.update({"added": [link.channel_id for link in added], "removed": [link.channel_id for link in removed]})
        row.payload = payload
        session.commit()
    if not payload.get("added") and not payload.get("removed"):
        return _cancel(session, row, "no_net_change", now)
    return None


def _current_tuning(channel: Channel) -> FrequencyReadout | None:
    if channel.frequency_mhz is None or channel.polarization is None or channel.symbol_rate is None:
        return None
    return FrequencyReadout(channel.frequency_mhz, channel.polarization, channel.symbol_rate)


def _readout(value: Mapping[str, Any]) -> FrequencyReadout:
    return FrequencyReadout(int(value["mhz"]), str(value["pol"]), int(value["sr"]))


def _prepare_frequency(session: Session, row: NotificationOutbox, now: datetime) -> str | None:
    """When a hold ends: write the history, move ``frequency_changed_at``, bump, then send (R6).

    The history is written even when the type is switched off: stopping pushes never loses what
    followers were told. Equal or incomplete values cancel with ``no_net_change``.
    """
    from sqlalchemy.dialects.postgresql import insert

    from app.db.models import ChannelFrequencyChange
    from app.etl.snapshot import bump_dataset_versions
    from app.services.admin.writer import CHANNEL_CHANGED

    payload = dict(row.payload or {})
    channel = session.get(Channel, int(payload.get("channel_id") or 0))
    if channel is None:
        return _cancel(session, row, "no_net_change", now)
    current = _current_tuning(channel)
    old = payload.get("old") or {}
    if current is None or "new" not in payload and _readout(old) == current:
        return _cancel(session, row, "no_net_change", now)
    if "new" in payload:
        new = _readout(payload["new"])
    else:
        new = current
        payload["new"] = {"mhz": new.mhz, "pol": new.polarization, "sr": new.symbol_rate}
        row.payload = payload
        session.execute(
            insert(ChannelFrequencyChange)
            .values(
                channel_id=channel.id,
                old_frequency_mhz=_readout(old).mhz,
                new_frequency_mhz=new.mhz,
                old_polarization=_readout(old).polarization,
                new_polarization=new.polarization,
                old_symbol_rate=_readout(old).symbol_rate,
                new_symbol_rate=new.symbol_rate,
                source="admin",
                outbox_id=row.id,
                audit_log_id=row.audit_log_id,
                detected_at=now,
            )
            .on_conflict_do_nothing(index_elements=["outbox_id"])
        )
        channel.frequency_changed_at = now
        bump_dataset_versions(session, CHANNEL_CHANGED)
        session.commit()
    return None


# --- Building one device's message -------------------------------------------------------------------


def _goal_events(session: Session, match_id: int) -> list[GoalEvent]:
    """The served timeline's events, for the scorer rule (one source only, so a goal can't double)."""
    rows = list(
        session.scalars(select(MatchEvent).where(MatchEvent.match_id == match_id, MatchEvent.source.in_(EVENT_SOURCES)))
    )
    by_source: dict[str, list[MatchEvent]] = {}
    for event in rows:
        by_source.setdefault(event.source, []).append(event)
    served = next((by_source[source] for source in EVENT_SOURCES if source in by_source), [])
    return [GoalEvent(type=e.type, side=e.side, minute=e.minute, player=e.player_name) for e in served]


def _channel_view(session: Session, channel_id: int) -> VisibleLink | None:
    row = session.execute(
        select(Channel, Satellite)
        .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
        .where(Channel.id == channel_id, Channel.deleted_at.is_(None), Channel.placeholder_source.is_(None))
    ).first()
    if row is None:
        return None
    channel, satellite = row
    return VisibleLink(
        channel_id=channel.id,
        name=channel.display_name or channel.name,
        access=channel.access,
        sort_order=channel.sort_order,
        show_in_match=channel.show_in_match,
        satellite_id=channel.satellite_id,
        satellite_slug=satellite.slug if satellite is not None else None,
        satellite_name=satellite.name_ar if satellite is not None else None,
    )


def _view(match: Match) -> MatchView:
    kickoff = match.kickoff_at
    assert kickoff is not None
    return MatchView(id=match.id, kickoff_at=kickoff, home_name=match.home_team_name, away_name=match.away_team_name)


def _message(
    session: Session,
    row: NotificationOutbox,
    match: Match | None,
    links: Sequence[VisibleLink],
    device: AudienceDevice,
    pwa_origin: str | None,
    now: datetime,
) -> PushMessage:
    payload = row.payload or {}
    if row.type == "kickoff_reminder":
        assert match is not None  # a reminder is cancelled without one
        return build_message(_view(match), list(links), device.satellite_ids, pwa_origin, now)
    if row.type == "announcement":
        return build_announcement(
            row.id,
            str(payload.get("title") or ""),
            str(payload.get("body") or ""),
            str(payload.get("route") or "/"),
            pwa_origin,
        )
    if row.type == "frequency_changed":
        channel = session.get(Channel, int(payload.get("channel_id") or 0))
        assert channel is not None
        satellite = session.get(Satellite, channel.satellite_id) if channel.satellite_id else None
        view = ChannelView(
            id=channel.id,
            name=channel.display_name or channel.name,
            satellite_name=satellite.name_ar if satellite is not None else None,
        )
        return build_frequency_changed(view, _readout(payload["old"]), _readout(payload["new"]), pwa_origin)
    assert match is not None
    if row.type == "match_started":
        return build_match_started(_view(match), pwa_origin)
    if row.type == "goal":
        if payload.get("kind") == "correction":
            return build_correction(_view(match), int(payload["home"]), int(payload["away"]), pwa_origin)
        return build_goal(
            _view(match),
            int(payload["home"]),
            int(payload["away"]),
            str(payload.get("side") or ""),
            _goal_events(session, match.id),
            pwa_origin,
        )
    if row.type == "final_score":
        return build_final_score(
            _view(match),
            int(match.home_score or 0),
            int(match.away_score or 0),
            match.home_pen,
            match.away_pen,
            pwa_origin,
        )
    if row.type == "channels_updated":
        added = [link for link in (_channel_view(session, i) for i in payload.get("added") or []) if link]
        removed = [link for link in (_channel_view(session, i) for i in payload.get("removed") or []) if link]
        return build_channels_updated(_view(match), added, removed, device.satellite_ids, pwa_origin)
    raise ValueError(f"no message builder for {row.type!r}")


# --- One row -----------------------------------------------------------------------------------------


def dispatch_row(
    session: Session,
    outbox_id: int,
    sender: PushSender,
    now: datetime,
    pwa_origin: str | None,
    *,
    page_budget: int = PAGES_PER_TURN,
) -> str:
    """Send one claimed row, page by page. Returns ``sent``, ``cancelled``, ``deferred`` or ``gone``.

    Raises :class:`PushRetryable` from a page's whole-call failure, or from a page that delivered to
    nobody while a device was still ``retryable`` after the sender's own re-sends, after committing
    the pages already recorded, so the retry resumes at ``cursor_device_id``.
    """
    row = session.get(NotificationOutbox, outbox_id)
    if row is None:
        return "gone"
    payload = row.payload or {}
    audience = row.audience or {}
    first_turn = (row.cursor_device_id or 0) == 0
    match_id = int(payload.get("match_id", 0))
    match = session.get(Match, match_id) if match_id else None

    if row.type == "kickoff_reminder":
        if _cancelled(match, now):
            return _cancel(session, row, "late", now)
    if row.type == "channels_updated" and first_turn:
        if match is None:
            return _cancel(session, row, "match_finished", now)
        stopped = _prepare_channels(session, row, match, now)
        if stopped is not None:
            return stopped
    if row.type == "frequency_changed" and first_turn:
        stopped = _prepare_frequency(session, row, now)
        if stopped is not None:
            return stopped

    from app.settings import get_settings

    if row.type in parse_types_off(get_settings().push_types_off):
        return _cancel(session, row, "type_off", now)

    decision = decide(
        row.type,
        row.due_at,
        now,
        match.status if match is not None else None,
        row.payload or {},
        (int(match.home_score), int(match.away_score))
        if match is not None and match.home_score is not None and match.away_score is not None
        else None,
        scheduled=_scheduled(row),
        is_test=audience.get("kind") == "device",
    )
    if isinstance(decision, Cancel):
        return _cancel(session, row, decision.reason, now)

    links = visible_links(session, match.id) if match is not None else []
    cursor = row.cursor_device_id or 0
    pages = 0
    while pages < page_budget:
        devices = audience_page(session, row, match, cursor)
        if not devices:
            break
        messages: list[PushMessage] = [
            PushMessage(
                token=device.push_token,
                title=(message := _message(session, row, match, links, device, pwa_origin, now)).title,
                body=message.body,
                data=message.data,
                tag=message.tag,
                link=message.link,
            )
            for device in devices
        ]
        try:
            outcome = sender.send_page(messages)
        except Retryable:
            raise
        if outcome.unregistered:
            session.execute(text(_CLEAR_TOKENS), {"tokens": list(outcome.unregistered)})
        if outcome.retryable and not outcome.sent:
            # FCM took nobody on this page, so sending the page again repeats nothing: it is not
            # recorded, and the cursor/``attempts`` path retries it (B1-R2-1).
            raise PushRetryable(outcome.last_error or "FCM retryable")
        # Some devices on the page already have the message and the cursor cannot say which, so the
        # page is not sent again whole: a device the sender's own re-sends could not reach is a
        # failed one (it was retried with backoff first), and the page is recorded.
        failed = outcome.failed + len(outcome.retryable)
        if failed:
            log.error("push_page_failed", extra={"row": outbox_id, "failed": failed})
        session.execute(
            text(_RECORD_PAGE),
            {"id": outbox_id, "sent": outcome.sent, "failed": failed, "cursor": devices[-1].id},
        )
        session.commit()
        cursor = devices[-1].id
        pages += 1
        if len(devices) < PAGE_SIZE:
            break

    row = session.get(NotificationOutbox, outbox_id, populate_existing=True)
    if row is None:
        return "gone"
    if pages >= page_budget:
        # The row's turn is spent: it goes back to pending with its cursor, and the run re-queues.
        row.status = "pending"
        row.claimed_at = None
        session.commit()
        return "deferred"
    row.status = "sent"
    row.sent_at = now
    session.commit()
    return "sent"


def _scheduled(row: NotificationOutbox) -> bool:
    """An announcement with a ``send_at`` is scheduled; anything due now is not (FR-019)."""
    return row.type == "announcement" and row.due_at > row.created_at + timedelta(seconds=1)


# --- The run ------------------------------------------------------------------------------------------


def _alert(session: Session, row: NotificationOutbox, now: datetime) -> list[str]:
    """The ``push`` problem, opened or closed by this row (research R11). Returns the texts to send."""
    from app.live.problems import sync_problems

    audience = row.audience or {}
    if audience.get("kind") == "device" or row.status == "cancelled":
        return []
    total = row.sent + row.failed
    failing = row.status == "failed" or (total >= ALERT_MIN_DEVICES and row.failed / total > ALERT_FAIL_SHARE)
    return sync_problems(session, opened=["push"] if failing else (), closed=[] if failing else ["push"], now=now)


def _send_alerts(texts: Sequence[str]) -> None:
    if not texts:
        return
    from app.adapters.alerts import send_alert

    for message in texts:
        if not send_alert(message):
            log.warning("push_alert_not_sent", extra={"text": message})


def dispatch_due(
    session: Session,
    sender: PushSender,
    now: datetime,
    pwa_origin: str | None = None,
    limit: int = CLAIM_LIMIT,
    *,
    monotonic: Callable[[], float] | None = None,
) -> DispatchReport:
    """Reclaim, then send one row at a time until nothing is due or 50 s have passed (R8).

    A whole-call failure stops the run at its row: it goes back to ``pending`` with its cursor while
    it has attempts left, and at :data:`MAX_ATTEMPTS` it becomes ``failed`` with its reason and is
    never claimed again. ``limit`` bounds how many rows one call takes before it re-queues itself.
    """
    clock = monotonic or time.monotonic
    report = DispatchReport()
    reclaim_stuck(session, now)
    session.commit()
    started = clock()

    while len(report.claimed) < limit:
        if clock() - started >= RUN_SECONDS:
            report.requeued = True
            break
        outbox_id = claim_next(session, now)
        if outbox_id is None:
            break
        report.claimed.append(outbox_id)
        try:
            outcome = dispatch_row(session, outbox_id, sender, now, pwa_origin)
        except Retryable as exc:
            reason = getattr(exc, "reason", None)
            attempts = int(session.execute(text(_BUMP_ATTEMPTS), {"id": outbox_id}).scalar_one())
            if attempts >= MAX_ATTEMPTS:
                session.execute(text(_MARK_FAILED), {"ids": [outbox_id], "error": reason})
                row = session.get(NotificationOutbox, outbox_id, populate_existing=True)
                if row is not None:
                    _send_alerts(_alert(session, row, now))
                report.failed_row_id = outbox_id
                report.failed += 1
                log.error("dispatch_failed", extra={"row": outbox_id, "attempts": attempts})
            else:
                session.execute(text(_RELEASE), {"ids": [outbox_id]})
                report.retry_row_id = outbox_id
            session.commit()
            break

        if outcome == "cancelled":
            report.cancelled += 1
        elif outcome == "sent":
            report.sent += 1
            row = session.get(NotificationOutbox, outbox_id, populate_existing=True)
            if row is not None:
                texts = _alert(session, row, now)
                session.commit()
                _send_alerts(texts)
        elif outcome == "deferred":
            report.deferred += 1
            report.requeued = True
            break

    if report.requeued is False and len(report.claimed) >= limit:
        # One call takes a bounded number of rows; anything still due waits for the next run.
        report.requeued = True
    return report


def mark_failed(session: Session, outbox_id: int, reason: str | None = None) -> None:
    """The row whose retries are exhausted, whatever state the retry left it in."""
    session.execute(text(_MARK_FAILED), {"ids": [outbox_id], "error": reason})
    session.commit()


def prune_outbox(session: Session, now: datetime, keep: timedelta = timedelta(days=30)) -> int:
    """Rows kept 30 days for A15, then deleted; announced channel changes go with them (R5)."""
    from app.notifications.channel_changes import prune_announced

    cutoff = now - keep
    removed = _rowcount(session.execute(text(_PRUNE), {"cutoff": cutoff}))
    prune_announced(session, cutoff)
    return removed
