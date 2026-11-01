"""The reminder scheduler: one outbox row per followed match (research R6).

Producers only insert ``notification_outbox`` rows with a unique ``dedupe_key``; a second run moves a
pending row (a moved kickoff) and never touches a sent one. A match that became ``time_tbd``,
``postponed``, ``cancelled`` or moved past 24 h has its pending reminders cancelled.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta

from sqlalchemy import text
from sqlalchemy.orm import Session

REMINDER_MINUTES = 15
WINDOW_HOURS = 24
MAX_DUE_NOW = 10

# A followed match in the next 24 h, at least one follower, and a reminder that is still open:
# the upsert moves ``due_at`` for a moved kickoff, never re-sends a row that already went out, and
# revives a row that was cancelled (a postponed match that is scheduled again, a TBD match that
# gets a time, a kickoff that moved past 24 h and back) — B1-R1-3.
_UPSERT = """
INSERT INTO notification_outbox (type, dedupe_key, payload, audience, due_at, status)
SELECT 'kickoff_reminder',
       'kickoff_reminder:' || m.id,
       jsonb_build_object('match_id', m.id, 'kickoff_at', m.kickoff_at),
       jsonb_build_object('kind', 'match_followers', 'match_id', m.id),
       greatest(m.kickoff_at - make_interval(mins => :lead), :now),
       'pending'
  FROM matches m
 WHERE m.kickoff_at > :now
   AND m.kickoff_at <= :now + make_interval(hours => :window)
   AND m.time_tbd = false
   AND m.status = 'scheduled'
   AND EXISTS (
         SELECT 1 FROM device_follows f
          WHERE f.match_id = m.id
             OR f.team_id IN (m.home_team_id, m.away_team_id)
             OR f.competition_id = m.competition_id)
ON CONFLICT (dedupe_key) DO UPDATE
   SET due_at = EXCLUDED.due_at,
       payload = EXCLUDED.payload,
       status = 'pending',
       claimed_at = NULL
 WHERE notification_outbox.status IN ('pending', 'cancelled')
"""

# ``sent`` and ``failed`` are final; ``sending`` is in flight. A kickoff that has passed cancels the
# row here too, so an outage cannot leave a reminder queued for a match already in play (B1-R1-5).
_CANCEL = """
UPDATE notification_outbox o
   SET status = 'cancelled'
  FROM matches m
 WHERE o.dedupe_key = 'kickoff_reminder:' || m.id
   AND o.status IN ('pending', 'sending')
   AND (m.time_tbd = true
        OR m.status IN ('postponed', 'cancelled', 'abandoned', 'live', 'finished')
        OR m.kickoff_at IS NULL
        OR m.kickoff_at <= :now
        OR m.kickoff_at > :now + make_interval(hours => :window))
"""

_DUE_NOW = """
SELECT count(*) FROM notification_outbox
 WHERE status = 'pending' AND due_at <= :now
"""


@dataclass
class ScheduleReport:
    scheduled: int = 0
    cancelled: int = 0
    due_now: int = 0
    rows: list[int] = field(default_factory=list)


def schedule_reminders(session: Session, now: datetime) -> ScheduleReport:
    """Upsert this run's reminder rows, cancel the ones whose match no longer qualifies."""
    params = {"now": now, "lead": REMINDER_MINUTES, "window": WINDOW_HOURS}
    upserted = _rowcount(session.execute(text(_UPSERT), params))
    cancelled = _rowcount(session.execute(text(_CANCEL), params))
    due_now = int(session.execute(text(_DUE_NOW), {"now": now}).scalar_one())
    return ScheduleReport(scheduled=upserted, cancelled=cancelled, due_now=due_now)


def _rowcount(result: object) -> int:
    return int(getattr(result, "rowcount", 0) or 0)


def seconds_until_due(row_due_at: datetime, now: datetime) -> float:
    """How long until a row is due; used by tests and logs."""
    return max((row_due_at - now).total_seconds(), 0.0)


REMINDER_LEAD = timedelta(minutes=REMINDER_MINUTES)
