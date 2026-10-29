"""Cairo wall-clock parsing, UTC conversion and window validation (research R5).

The snapshot stores kickoff as ``date`` + ``time`` where ``time`` is an Arabic
wall-clock string read as Africa/Cairo local time. Conversion uses the IANA zone so
both 2026 DST transitions are handled.
"""

from __future__ import annotations

import re
from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

CAIRO = ZoneInfo("Africa/Cairo")
UTC = UTC

TBD_ANCHOR = time(12, 0)  # a TBD match anchors to local noon
MAX_WINDOW = timedelta(days=8)

# "10:00 م", "02:30 ص", "2:30" (no marker). Marker ص = AM, م = PM.
_TIME_RE = re.compile(r"^(\d{1,2}):(\d{2})\s*([صم])?\s*$")


def parse_cairo_wall_clock(value: str | None) -> time | None:
    """Return the 24h wall clock, or ``None`` for an unknown kickoff (``"--:--"``)."""
    if not value:
        return None
    text = value.strip()
    if text == "--:--":
        return None
    m = _TIME_RE.match(text)
    if not m:
        return None
    hour = int(m.group(1))
    minute = int(m.group(2))
    marker = m.group(3)
    if marker == "ص":  # AM
        hour = hour % 12
    elif marker == "م":  # PM
        hour = hour % 12 + 12
    elif 1 <= hour <= 11:
        # No marker: the old app reads hours 1–11 as PM.
        hour += 12
    if hour >= 24:
        hour -= 24
    return time(hour, minute)


def cairo_to_utc(match_date: date, wall: time) -> datetime:
    """Combine a Cairo wall clock with a calendar date and convert to UTC."""
    local = datetime.combine(match_date, wall, tzinfo=CAIRO)
    return local.astimezone(UTC)


def tbd_anchor(match_date: date) -> datetime:
    """The UTC instant a ``time_tbd`` match is anchored to for window matching."""
    return cairo_to_utc(match_date, TBD_ANCHOR)


def validate_window(from_dt: datetime, to_dt: datetime) -> None:
    """Raise ``ValueError`` unless ``from < to`` and the span is ≤ 8 days."""
    if from_dt.tzinfo is None or to_dt.tzinfo is None:
        raise ValueError("window bounds must be timezone-aware")
    if from_dt >= to_dt:
        raise ValueError("from must be before to")
    if to_dt - from_dt > MAX_WINDOW:
        raise ValueError("window exceeds 8 days")
