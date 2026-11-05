"""Derived match status for clock-sourced rows (constitution II, research R3).

On D1 every snapshot row is ``status_source = 'clock'``. The live/estimated state is
derived at read time and never stored, so a clock row always carries ``status =
'scheduled'`` in the database and no score, minute or period.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Protocol

LIVE_WINDOW = timedelta(minutes=120)

STATUS_SCHEDULED = "scheduled"
STATUS_LIVE = "live"
STATUS_FINISHED = "finished"
STATUS_POSTPONED = "postponed"


@dataclass(frozen=True)
class DerivedStatus:
    status: str
    estimated: bool


class _ClockRow(Protocol):
    status_source: str
    status: str
    time_tbd: bool
    kickoff_at: datetime | None


def derive_status(row: _ClockRow, now: datetime) -> DerivedStatus:
    """Derive the API status for one match row at ``now`` (timezone-aware).

    ``feed`` and ``manual`` rows are returned as stored and are never ``estimated``;
    only ``clock`` rows are derived. A ``manual`` status wins until an admin clears it
    (data-model "Match status").
    """
    if row.status_source != "clock":
        return DerivedStatus(status=row.status, estimated=False)

    if row.time_tbd or row.kickoff_at is None:
        return DerivedStatus(status=STATUS_SCHEDULED, estimated=False)

    if now < row.kickoff_at:
        return DerivedStatus(status=STATUS_SCHEDULED, estimated=False)

    if now < row.kickoff_at + LIVE_WINDOW:
        return DerivedStatus(status=STATUS_LIVE, estimated=True)

    return DerivedStatus(status=STATUS_FINISHED, estimated=True)
