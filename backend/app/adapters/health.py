"""Source health: the circuit breaker, the zero-items alarm and the ``sources`` bump (R17).

Called once per run, inside the ingest transaction that writes ``import_runs``, so the run row and
the breaker can never disagree. Revision ``0005`` (Lane B1) adds the four columns; this module names
them in SQL rather than adding them to ``app.db.models``, which Lane B1 owns.

Alerts go through :func:`app.adapters.alerts.send_alert`: logged and swallowed, never raised.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from typing import Any

from sqlalchemy import func, text, update

from app.adapters.alerts import send_alert
from app.domain.time import CAIRO

# The four columns ``0005`` adds to ``sources`` (data-model §Source health).
HEALTH_COLUMNS_SQL = """
SELECT consecutive_failures, breaker_opened_at, last_success_at, last_zero_alert_on
FROM sources WHERE name = :name
"""
# The breaker's dead-man switch: when it opened, and for how many failures.
OPEN_BREAKER_SQL = """
UPDATE sources
   SET consecutive_failures = consecutive_failures + 1,
       breaker_opened_at = CASE
           WHEN consecutive_failures + 1 >= :threshold AND breaker_opened_at IS NULL THEN :now
           ELSE breaker_opened_at END,
       updated_at = now()
 WHERE name = :name
RETURNING consecutive_failures, breaker_opened_at
"""
# A zero-items run counts as a failure, but alerts at most once per source per Cairo day.
ZERO_ALERT_SQL = """
UPDATE sources SET last_zero_alert_on = :today, updated_at = now()
 WHERE name = :name
   AND (last_zero_alert_on IS NULL OR last_zero_alert_on <> :today)
RETURNING last_zero_alert_on
"""
SUCCESS_SQL = """
UPDATE sources
   SET consecutive_failures = 0,
       last_success_at = :finished_at,
       updated_at = now()
 WHERE name = :name
RETURNING last_success_at
"""
LIVE_POLLER = "live_poller"
LIVE_FAILURE_SQL = """
UPDATE sources SET consecutive_failures = consecutive_failures + 1, updated_at = now()
 WHERE name = 'live_poller'
"""
# sporteventz lists about 40 events in two weeks, so a valid empty response is normal there and
# only alarms after a week with no records at all (D6 R21, FR-039).
ZERO_ITEMS_GRACE_DAYS: dict[str, int] = {"sporteventz": 7}
GRACE_BASELINE_SQL = """
SELECT max(finished_at) FILTER (WHERE items_found > 0), min(started_at)
  FROM import_runs WHERE source = :source
"""


@dataclass(frozen=True, slots=True)
class HealthOutcome:
    """What the run did to the source row, for the compact run log (A13)."""

    consecutive_failures: int = 0
    breaker_opened: bool = False
    zero_alert_sent: bool = False

    def as_log(self) -> dict[str, Any]:
        return {
            "consecutive_failures": self.consecutive_failures,
            "breaker_opened": self.breaker_opened,
            "zero_items_alert": self.zero_alert_sent,
        }


def bump_datasets(session: Any, names: list[str]) -> None:
    """The sync twin of Lane B1's ``app.services.admin.writer.bump_datasets``.

    Same rows, same statement shape: ``version = version + 1`` for each name. Called as the last
    write of the ingest transaction, so an ``ETag`` built from the version changes after the run
    (R12, R17).
    """
    from app.db.models import DatasetVersion

    wanted = sorted(set(names))
    if not wanted:
        return
    session.flush()
    session.execute(
        update(DatasetVersion)
        .where(DatasetVersion.name.in_(wanted))
        .values(version=DatasetVersion.version + 1, updated_at=func.now())
    )


def cairo_today(now: datetime) -> date:
    return now.astimezone(CAIRO).date()


def record_run(
    session: Any,
    *,
    source: str,
    status: str,
    items_found: int,
    finished_at: datetime,
    pages: int = 0,
    targets: int = 0,
    alert: Any = None,
    now: datetime | None = None,
    bump: bool = True,
) -> HealthOutcome:
    """Update the source row for one finished run, then bump ``sources`` in the same transaction.

    - ``failed``: ``consecutive_failures + 1``; at the threshold the breaker opens and one alert
      goes out ("⛔ المصدر ‹name› متوقف بعد ‹N› محاولات فاشلة");
    - zero items with pages or targets: the same count, plus one alert per Cairo day;
    - ``succeeded``/``partial`` with items: the count resets and ``last_success_at`` moves.
    """
    from app.adapters.config import get_adapter_settings

    settings = get_adapter_settings()
    when = now or datetime.now(UTC)
    notify = send_alert if alert is None else alert
    outcome = HealthOutcome()

    zero_items = status != "failed" and items_found == 0 and (pages > 0 or targets > 0)
    if zero_items and source in ZERO_ITEMS_GRACE_DAYS:
        zero_items = not _within_zero_grace(session, source, when, ZERO_ITEMS_GRACE_DAYS[source])
    failure = status == "failed" or zero_items

    if status == "stopped":
        # A run that stopped on purpose (no key, an exhausted budget) is neither a failure nor a
        # quiet source: it touches neither the breaker nor the zero-items alarm (FR-035).
        if bump:
            bump_datasets(session, ["sources"])
        return outcome

    if failure:
        before = session.execute(text(HEALTH_COLUMNS_SQL), {"name": source}).first()
        opened_before = bool(before is not None and before[1] is not None)
        failures_before = int(before[0]) if before is not None else 0
        row = session.execute(
            text(OPEN_BREAKER_SQL),
            {"name": source, "threshold": settings.source_breaker_threshold, "now": when},
        ).first()
        failures = int(row[0]) if row is not None else failures_before + 1
        breaker_opened = (not opened_before) and row is not None and row[1] is not None
        if breaker_opened:
            notify(f"⛔ المصدر ‹{source}› متوقف بعد ‹{failures}› محاولات فاشلة")
        zero_sent = False
        if zero_items:
            zero_row = session.execute(text(ZERO_ALERT_SQL), {"name": source, "today": cairo_today(when)}).first()
            zero_sent = zero_row is not None
            if zero_sent:
                notify(f"⚠️ المصدر ‹{source}› لم يجد أي عناصر")
        outcome = HealthOutcome(consecutive_failures=failures, breaker_opened=breaker_opened, zero_alert_sent=zero_sent)
    elif items_found > 0:
        session.execute(text(SUCCESS_SQL), {"name": source, "finished_at": finished_at})

    if bump:
        bump_datasets(session, ["sources"])
    return outcome


def _within_zero_grace(session: Any, source: str, now: datetime, days: int) -> bool:
    """Whether the source is still inside its quiet window: 7 days from its last run with records.

    A source that has never brought a record counts from its first run, so a brand-new adapter is
    not accused on its first quiet day, and a source that stays empty for a week is.
    """
    last_records, first_run = session.execute(text(GRACE_BASELINE_SQL), {"source": source}).one()
    baseline = last_records or first_run
    return baseline is None or now - baseline < timedelta(days=days)


def record_live_cycle(session: Any, *, status: str, items_found: int, finished_at: datetime) -> None:
    """Record one live poller cycle on the ``live_poller`` row, with no breaker (D5 contract).

    The poller has its own failure handling per source (``live_source_state``, the watchdog), and an
    open breaker would stop a live match's polling, so this never sets ``breaker_opened_at``.
    The caller bumps ``sources``, last in its transaction, so A13's run list shows the cycle.
    An idle cycle (not failed, no items) leaves the row as it is.
    """
    if status == "failed":
        session.execute(text(LIVE_FAILURE_SQL))
    elif items_found > 0:
        session.execute(text(SUCCESS_SQL), {"name": LIVE_POLLER, "finished_at": finished_at})


def source_is_paused(session: Any, source: str, *, now: datetime | None = None) -> bool:
    """``is_enabled = false``, an open breaker, or ``paused_until`` in the future (R17)."""
    row = session.execute(
        text("SELECT is_enabled, paused_until, breaker_opened_at FROM sources WHERE name = :name"),
        {"name": source},
    ).first()
    if row is None:
        return False
    enabled, paused_until, breaker_opened_at = row
    if not enabled or breaker_opened_at is not None:
        return True
    return bool(paused_until is not None and paused_until > (now or datetime.now(UTC)))
