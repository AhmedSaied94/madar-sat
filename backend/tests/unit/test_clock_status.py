from __future__ import annotations

import dataclasses
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest

from app.domain.status import derive_status

NOW = datetime(2026, 10, 28, 18, 0, tzinfo=UTC)


def row(status_source="clock", status="scheduled", time_tbd=False, kickoff_at=None):
    return SimpleNamespace(status_source=status_source, status=status, time_tbd=time_tbd, kickoff_at=kickoff_at)


def test_time_tbd_is_scheduled_not_estimated():
    d = derive_status(row(time_tbd=True, kickoff_at=None), NOW)
    assert d.status == "scheduled"
    assert d.estimated is False


def test_before_kickoff_is_scheduled_not_estimated():
    d = derive_status(row(kickoff_at=NOW + timedelta(minutes=10)), NOW)
    assert d.status == "scheduled"
    assert d.estimated is False


def test_kickoff_boundary_is_live_estimated():
    d = derive_status(row(kickoff_at=NOW), NOW)
    assert d.status == "live"
    assert d.estimated is True


def test_during_window_is_live_estimated():
    d = derive_status(row(kickoff_at=NOW - timedelta(minutes=119)), NOW)
    assert d.status == "live"
    assert d.estimated is True


def test_120_minute_boundary_is_finished_estimated():
    d = derive_status(row(kickoff_at=NOW - timedelta(minutes=120)), NOW)
    assert d.status == "finished"
    assert d.estimated is True


def test_after_window_is_finished_estimated():
    d = derive_status(row(kickoff_at=NOW - timedelta(hours=3)), NOW)
    assert d.status == "finished"
    assert d.estimated is True


def test_feed_rows_returned_as_stored_not_estimated():
    d = derive_status(row(status_source="feed", status="live"), NOW)
    assert d.status == "live"
    assert d.estimated is False


def test_manual_rows_returned_as_stored_not_estimated():
    d = derive_status(row(status_source="manual", status="finished"), NOW)
    assert d.status == "finished"
    assert d.estimated is False


def test_just_before_kickoff_is_still_scheduled():
    d = derive_status(row(kickoff_at=NOW + timedelta(microseconds=1)), NOW)
    assert (d.status, d.estimated) == ("scheduled", False)


def test_just_before_120_minutes_is_still_live():
    d = derive_status(row(kickoff_at=NOW - timedelta(minutes=120) + timedelta(microseconds=1)), NOW)
    assert (d.status, d.estimated) == ("live", True)


@pytest.mark.parametrize("minutes_since_kickoff", [None, -10, 0, 60, 120, 300])
def test_clock_results_never_carry_score_minute_or_period(minutes_since_kickoff):
    kickoff = None if minutes_since_kickoff is None else NOW - timedelta(minutes=minutes_since_kickoff)
    clock_row = row(time_tbd=kickoff is None, kickoff_at=kickoff)
    # Even a stray value on the row object must not leak into the derived result.
    clock_row.home_score, clock_row.minute, clock_row.period = 3, "55", "2H"
    d = derive_status(clock_row, NOW)
    assert {f.name for f in dataclasses.fields(d)} == {"status", "estimated"}
