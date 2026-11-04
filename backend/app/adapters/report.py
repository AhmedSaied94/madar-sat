"""Read-only evidence that imports ran unattended (D4 T033, research R6).

Run it on VPS-2, inside the import workers' image, so it reads the same database and the same
schedule the beat uses:

```bash
dc exec worker-imports python -m app.adapters.report runs --hours 48
dc exec worker-imports python -m app.adapters.report coverage --days 4
```

It opens no network connection, writes nothing, and adds no endpoint (FR-041). The exit code is
`1` when a slot is missing or was run by hand: that is evidence for the PR, not an alarm.

**Slots.** A slot is one firing of a full-listing beat entry in ``schedule.py``. The
``livesoccertv-t60`` entry is not a slot: it re-reads the same source minutes before kickoff, so
counting it would claim two independent imports for one listing. A run covers a slot when it has
the slot's source and started within ``SLOT_TOLERANCE`` of it.

**Manual runs.** ``import_runs`` has no trigger column (D3 chose not to add one), so a manual run is
read from ``audit_log``: the two source actions that queue one — «تشغيل الآن» (diff key ``run``) and
resume (``is_enabled`` false→true). The source is not in the audit row, so the run's own ``source``
and a tight time window (``MANUAL_GRACE``) are what attribute it, which is exact because one person
queues at a time.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from app.adapters.schedule import BEAT_SCHEDULE

CAIRO = ZoneInfo("Africa/Cairo")
SLOT_TOLERANCE = timedelta(minutes=5)
MANUAL_GRACE = timedelta(minutes=5)
MAX_UNMATCHED = 8


@dataclass(frozen=True)
class Slot:
    """One firing of a full-listing beat entry."""

    schedule: str
    source: str
    at: datetime


@dataclass(frozen=True)
class RunFacts:
    """The columns the report needs from one ``import_runs`` row."""

    id: int
    source: str
    started_at: datetime
    status: str
    items_found: int
    items_upserted: int


@dataclass(frozen=True)
class Trigger:
    """One audited source action that queued a manual run."""

    at: datetime
    kind: str  # "run" (تشغيل الآن) or "resume"


@dataclass(frozen=True)
class SlotResult:
    slot: Slot
    run: RunFacts | None
    manual: bool
    reason: str

    @property
    def flagged(self) -> bool:
        return self.run is None or self.manual


@dataclass(frozen=True)
class CoverageMatch:
    """One match of a prioritized competition, and whether a fan can watch it."""

    cairo_day: date
    competition: str
    has_visible_channel: bool


@dataclass(frozen=True)
class CoverageRow:
    cairo_day: date
    competition: str
    matches: int
    with_channels: int
    unmatched: tuple[str, ...]


def _slot_entries() -> list[tuple[str, str, Any]]:
    """The (name, source, crontab) of every full-listing entry."""
    entries = []
    for name, entry in BEAT_SCHEDULE.items():
        if entry["task"] != "adapters.schedule_fetch":
            continue
        if entry.get("kwargs", {}).get("window") or entry.get("kwargs", {}).get("manual"):
            continue
        entries.append((name, entry["args"][0], entry["schedule"]))
    return sorted(entries)


def _slot_times(crontab: Any, start: datetime, end: datetime) -> list[datetime]:
    """Every firing of a minute/hour crontab between two instants, ends included."""
    if len(crontab.day_of_week) != 7 or len(crontab.day_of_month) != 31 or len(crontab.month_of_year) != 12:
        raise ValueError("the report expands minute/hour schedules only")
    minutes, hours = set(crontab.minute), set(crontab.hour)
    current = start.astimezone(UTC).replace(second=0, microsecond=0)
    stop = end.astimezone(UTC)
    found = []
    while current <= stop:
        if current.minute in minutes and current.hour in hours:
            found.append(current)
        current += timedelta(minutes=1)
    return found


def expected_slots(start: datetime, end: datetime) -> list[Slot]:
    """The scheduled slots of ``schedule.py`` in ``[start, end]``, oldest first."""
    slots = [
        Slot(name, source, at) for name, source, crontab in _slot_entries() for at in _slot_times(crontab, start, end)
    ]
    return sorted(slots, key=lambda slot: (slot.at, slot.schedule))


def manual_triggers(rows: Iterable[tuple[datetime, Mapping[str, Any]]]) -> list[Trigger]:
    """The audited source actions that queue a run, from raw ``audit_log`` diff rows."""
    triggers = []
    for created_at, diff in rows:
        if "run" in diff:
            triggers.append(Trigger(created_at, "run"))
        elif _is_resume(diff.get("is_enabled")):
            triggers.append(Trigger(created_at, "resume"))
    return sorted(triggers, key=lambda trigger: trigger.at)


def _is_resume(is_enabled: Any) -> bool:
    return isinstance(is_enabled, (list, tuple)) and list(is_enabled) == [False, True]


def match_slots(
    slots: Sequence[Slot],
    runs: Iterable[RunFacts],
    triggers: Iterable[Trigger],
    tolerance: timedelta = SLOT_TOLERANCE,
) -> list[SlotResult]:
    """Put each run under the slot it answered, and flag a slot that none did."""
    by_source: dict[str, list[RunFacts]] = {}
    for run in sorted(runs, key=lambda item: item.started_at):
        by_source.setdefault(run.source, []).append(run)
    trigger_list = list(triggers)

    results = []
    for slot in slots:
        candidates = [run for run in by_source.get(slot.source, ()) if slot.at <= run.started_at <= slot.at + tolerance]
        if not candidates:
            results.append(SlotResult(slot, None, False, "missing"))
            continue
        run = candidates[0]
        trigger = next(
            (item for item in trigger_list if item.at <= run.started_at <= item.at + MANUAL_GRACE),
            None,
        )
        reason = "scheduled" if trigger is None else f"manual ({'run now' if trigger.kind == 'run' else 'resume'})"
        results.append(SlotResult(slot, run, trigger is not None, reason))
    return results


def coverage_rows(
    days: Sequence[date],
    competitions: Sequence[str],
    matches: Iterable[CoverageMatch],
    unmatched: Mapping[date, Sequence[str]],
) -> list[CoverageRow]:
    """One row per Cairo day and prioritized competition, gaps included."""
    counted: dict[tuple[date, str], list[int]] = {}
    for match in matches:
        totals = counted.setdefault((match.cairo_day, match.competition), [0, 0])
        totals[0] += 1
        totals[1] += 1 if match.has_visible_channel else 0

    rows = []
    for day in days:
        for competition in competitions:
            total, visible = counted.get((day, competition), (0, 0))
            names = tuple(unmatched.get(day, ()))
            rows.append(CoverageRow(day, competition, total, visible, names[:MAX_UNMATCHED]))
    return rows


def cairo_days(days: int, now: datetime) -> list[date]:
    """Today's Cairo date and the next ``days - 1``."""
    today = now.astimezone(CAIRO).date()
    return [today + timedelta(days=offset) for offset in range(days)]


def render_runs(results: Sequence[SlotResult]) -> list[str]:
    """The runs table, in the formats of data-model.md."""
    rows = [["source", "slot (UTC)", "run", "status", "found", "upserted", "manual", "reason"]]
    for result in results:
        run = result.run
        rows.append(
            [
                result.slot.source,
                result.slot.at.strftime("%Y-%m-%d %H:%M"),
                "-" if run is None else str(run.id),
                "-" if run is None else run.status,
                "-" if run is None else str(run.items_found),
                "-" if run is None else str(run.items_upserted),
                "yes" if result.manual else "no",
                result.reason,
            ]
        )
    return _table(rows)


def render_coverage(rows: Sequence[CoverageRow]) -> list[str]:
    """The coverage table, in the formats of data-model.md.

    The skipped names belong to the day, not to one competition, so they are shown on the day's
    first row only.
    """
    table = [["cairo day", "competition", "matches", "with channels", "unmatched names"]]
    shown_days: set[date] = set()
    for row in rows:
        names = row.unmatched if row.cairo_day not in shown_days else ()
        shown_days.add(row.cairo_day)
        table.append(
            [
                row.cairo_day.isoformat(),
                row.competition,
                str(row.matches),
                str(row.with_channels),
                ", ".join(names) or "-",
            ]
        )
    return _table(table)


def _table(rows: list[list[str]]) -> list[str]:
    """Left-aligned columns, two spaces apart, no borders: readable in a journal and a PR."""
    widths = [max(len(row[index]) for row in rows) for index in range(len(rows[0]))]
    return ["  ".join(cell.ljust(widths[index]) for index, cell in enumerate(row)).rstrip() for row in rows]


# --- the two read-only queries -------------------------------------------------


def _fetch_runs(start: datetime, end: datetime) -> list[RunFacts]:
    from sqlalchemy import select

    from app.db.models import ImportRun
    from app.db.session import SyncSession

    with SyncSession() as session:
        found = session.scalars(
            select(ImportRun)
            .where(ImportRun.started_at >= start, ImportRun.started_at <= end)
            .order_by(ImportRun.started_at)
        ).all()
    return [
        RunFacts(run.id, run.source, run.started_at, run.status, run.items_found, run.items_upserted) for run in found
    ]


def _fetch_triggers(start: datetime, end: datetime) -> list[Trigger]:
    from sqlalchemy import select

    from app.db.models import AuditLog
    from app.db.session import SyncSession

    with SyncSession() as session:
        found = session.execute(
            select(AuditLog.created_at, AuditLog.diff)
            .where(
                AuditLog.entity == "source",
                AuditLog.action == "update",
                AuditLog.created_at >= start,
                AuditLog.created_at <= end,
            )
            .order_by(AuditLog.created_at)
        ).all()
    return manual_triggers((created_at, diff or {}) for created_at, diff in found)


def _fetch_coverage(days: Sequence[date]) -> tuple[list[str], list[CoverageMatch], dict[date, tuple[str, ...]]]:
    """The prioritized competitions, their matches per Cairo day, and the skipped names."""
    from sqlalchemy import exists, func, select

    from app.db.models import Channel, Competition, HiddenChannelName, ImportRun, Match, MatchChannel
    from app.db.session import SyncSession

    hidden = select(HiddenChannelName.name)
    # The same visibility rule as `app.services.common.visible_link` (research R6).
    visible = exists(
        select(MatchChannel.match_id)
        .join(Channel, Channel.id == MatchChannel.channel_id)
        .where(
            MatchChannel.match_id == Match.id,
            MatchChannel.is_hidden.is_(False),
            Channel.deleted_at.is_(None),
            Channel.placeholder_source.is_(None),
            Channel.name_norm.not_in(hidden),
            func.ar_normalize(func.coalesce(Channel.display_name, "")).not_in(hidden),
        )
    )
    start = datetime.combine(days[0], time.min, tzinfo=CAIRO).astimezone(UTC)
    end = datetime.combine(days[-1] + timedelta(days=1), time.min, tzinfo=CAIRO).astimezone(UTC)

    with SyncSession() as session:
        competitions = list(
            session.scalars(
                select(Competition.name)
                .where(Competition.priority.is_not(None))
                .order_by(Competition.priority, Competition.name)
            )
        )
        found = session.execute(
            select(Match.match_date, Competition.name, visible)
            .join(Competition, Competition.id == Match.competition_id)
            .where(Match.match_date.in_(days), Competition.priority.is_not(None))
            .order_by(Match.match_date, Competition.priority, Match.kickoff_at)
        ).all()
        runs = session.execute(
            select(ImportRun.started_at, ImportRun.log)
            .where(ImportRun.started_at >= start, ImportRun.started_at < end)
            .order_by(ImportRun.started_at)
        ).all()

    matches = [CoverageMatch(day, name, bool(shown)) for day, name, shown in found]
    unmatched: dict[date, list[str]] = {}
    for started_at, log in runs:
        if not isinstance(log, Mapping):
            continue
        refs = unmatched.setdefault(started_at.astimezone(CAIRO).date(), [])
        for item in (log.get("skipped") or {}).get("items", ()):
            ref = str(item.get("ref", ""))
            if ref and ref not in refs:
                refs.append(ref)
    return competitions, matches, {day: tuple(refs) for day, refs in unmatched.items()}


def _print(lines: Sequence[str]) -> None:
    print("\n".join(lines))


def cmd_runs(args: argparse.Namespace) -> int:
    now = datetime.now(UTC)
    start = now - timedelta(hours=args.hours)
    results = match_slots(expected_slots(start, now), _fetch_runs(start, now), _fetch_triggers(start, now))
    _print(render_runs(results))
    flagged = [result for result in results if result.flagged]
    print(f"\n{len(results)} slots, {len(flagged)} flagged (missing or manual)")
    return 1 if flagged else 0


def cmd_coverage(args: argparse.Namespace) -> int:
    days = cairo_days(args.days, datetime.now(UTC))
    competitions, matches, unmatched = _fetch_coverage(days)
    _print(render_coverage(coverage_rows(days, competitions, matches, unmatched)))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python -m app.adapters.report", description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    runs = commands.add_parser("runs", help="one row per scheduled slot")
    runs.add_argument("--hours", type=int, default=48)
    runs.set_defaults(func=cmd_runs)
    coverage = commands.add_parser("coverage", help="one row per Cairo day and prioritized competition")
    coverage.add_argument("--days", type=int, default=4)
    coverage.set_defaults(func=cmd_coverage)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    sys.exit(main())
