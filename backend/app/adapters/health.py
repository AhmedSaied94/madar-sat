"""Source health: the circuit breaker, the zero-items alarm and the ``sources`` bump (R17).

Called once per run, inside the ingest transaction that writes ``import_runs``, so the run row and
the breaker can never disagree. Lane B1 owns revision ``0005`` that adds the four columns; this
module names them in SQL rather than adding them to ``app.db.models`` (Lane B1 owns that file), so
it starts working the moment the migration lands.

Alerts go through :func:`app.adapters.alerts.send_alert`: logged and swallowed, never raised.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime
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


def column_available(session: Any, table: str, column: str) -> bool:
    """Whether 0005's column exists, asked once per session.

    Lane B2's code names 0005's columns but cannot add them (Lane B1 owns the migration and
    ``app.db.models``). Until the migration lands, the health writes and the run log stay off and
    the run still records what it did; after it, they turn on with no code change (T068).
    """
    key = f"column:{table}.{column}"
    known = session.info.get(key)
    if known is not None:
        return bool(known)
    found = (
        session.execute(
            text(
                "SELECT 1 FROM information_schema.columns "
                "WHERE table_schema = 'public' AND table_name = :table AND column_name = :column"
            ),
            {"table": table, "column": column},
        ).first()
        is not None
    )
    session.info[key] = found
    return found


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

    if not column_available(session, "sources", "consecutive_failures"):
        if bump:
            bump_datasets(session, ["sources"])
        return outcome

    zero_items = status != "failed" and items_found == 0 and (pages > 0 or targets > 0)
    failure = status == "failed" or zero_items

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


def source_is_paused(session: Any, source: str, *, now: datetime | None = None) -> bool:
    """``is_enabled = false``, an open breaker, or ``paused_until`` in the future (R17)."""
    has_breaker = column_available(session, "sources", "breaker_opened_at")
    selected = "is_enabled, paused_until, breaker_opened_at" if has_breaker else "is_enabled, paused_until"
    row = session.execute(
        text(f"SELECT {selected} FROM sources WHERE name = :name"),  # noqa: S608 - a fixed column list
        {"name": source},
    ).first()
    if row is None:
        return False
    enabled, paused_until = row[0], row[1]
    breaker_opened_at = row[2] if has_breaker else None
    if not enabled or breaker_opened_at is not None:
        return True
    return bool(paused_until is not None and paused_until > (now or datetime.now(UTC)))
