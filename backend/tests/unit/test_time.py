from __future__ import annotations

from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

import pytest

from app.domain.time import (
    cairo_to_utc,
    parse_cairo_wall_clock,
    tbd_anchor,
    validate_window,
)
from app.services.matches import tbd_dates


class TestParse:
    def test_pm_marker(self):
        assert parse_cairo_wall_clock("10:00 م") == time(22, 0)

    def test_am_marker(self):
        assert parse_cairo_wall_clock("10:00 ص") == time(10, 0)

    def test_unmarked_hour_is_pm(self):
        assert parse_cairo_wall_clock("02:30") == time(14, 30)

    def test_unmarked_noon(self):
        assert parse_cairo_wall_clock("12:00") == time(12, 0)

    def test_noon_with_pm(self):
        assert parse_cairo_wall_clock("12:00 م") == time(12, 0)

    def test_midnight_with_am(self):
        assert parse_cairo_wall_clock("12:00 ص") == time(0, 0)

    def test_unknown_kickoff(self):
        assert parse_cairo_wall_clock("--:--") is None

    def test_empty_is_none(self):
        assert parse_cairo_wall_clock("") is None


class TestConversion:
    def test_winter_is_utc_plus_2(self):
        # Before the 2026 DST start (last Friday of April).
        assert cairo_to_utc(date(2026, 1, 15), time(22, 0)) == datetime(2026, 1, 15, 20, 0, tzinfo=UTC)

    def test_summer_is_utc_plus_3(self):
        # During DST (Apr 24 – Oct 29 2026).
        assert cairo_to_utc(date(2026, 6, 15), time(22, 0)) == datetime(2026, 6, 15, 19, 0, tzinfo=UTC)

    def test_autumn_returns_to_utc_plus_2(self):
        # After the DST end.
        assert cairo_to_utc(date(2026, 11, 15), time(22, 0)) == datetime(2026, 11, 15, 20, 0, tzinfo=UTC)


class TestWindow:
    def test_valid_window(self):
        f = datetime(2026, 10, 1, tzinfo=UTC)
        validate_window(f, f + timedelta(days=8))

    def test_from_not_before_to(self):
        f = datetime(2026, 10, 1, tzinfo=UTC)
        with pytest.raises(ValueError):
            validate_window(f, f)
        with pytest.raises(ValueError):
            validate_window(f + timedelta(hours=1), f)

    def test_window_over_eight_days(self):
        f = datetime(2026, 10, 1, tzinfo=UTC)
        with pytest.raises(ValueError):
            validate_window(f, f + timedelta(days=8, seconds=1))


class TestTbdAnchor:
    def test_anchor_is_cairo_noon(self):
        assert tbd_anchor(date(2026, 6, 15)) == datetime(2026, 6, 15, 9, 0, tzinfo=UTC)  # Cairo summer, UTC+3
        assert tbd_anchor(date(2026, 12, 15)) == datetime(2026, 12, 15, 10, 0, tzinfo=UTC)  # winter, UTC+2

    @pytest.mark.parametrize("zone", ["Asia/Riyadh", "Europe/Paris", "Africa/Casablanca"])
    @pytest.mark.parametrize(
        "day",
        # Around both 2026 Cairo changes and Paris's own.
        [date(2026, 3, 29), date(2026, 4, 24), date(2026, 10, 25), date(2026, 10, 29), date(2026, 10, 30)],
    )
    def test_tbd_match_lands_in_exactly_its_own_local_day(self, zone, day):
        tz = ZoneInfo(zone)

        def local_day(d: date) -> tuple[datetime, datetime]:
            """The [from, to) window a client in ``zone`` sends for its local date ``d``."""
            start = datetime.combine(d, time(0), tz).astimezone(UTC)
            return start, datetime.combine(d + timedelta(days=1), time(0), tz).astimezone(UTC)

        anchor = tbd_anchor(day)
        for other, expected in ((day - timedelta(days=1), False), (day, True), (day + timedelta(days=1), False)):
            lo, hi = local_day(other)
            assert (lo <= anchor < hi) is expected, (zone, day, other)
        assert tbd_dates(*local_day(day)) == {day}
