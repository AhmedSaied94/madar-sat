"""The beat entries and their queues (T076 D2, extended by D3's T066).

Every source entry now calls ``adapters.schedule_fetch`` on VPS-2, which applies the pause and the
breaker before it sends the fetch to the source's own queue (R17). ``test_schedule_fetch.py`` covers
that task and the planning; this file keeps the schedule's own contract.
"""

from __future__ import annotations

from app.adapters.schedule import BEAT_SCHEDULE, build_beat_schedule


def test_the_prune_entry_is_unchanged() -> None:
    prune = BEAT_SCHEDULE["prune-raw-pages"]
    assert prune["task"] == "adapters.prune_raw_pages"
    assert prune["args"] == ()
    assert prune["options"] == {"queue": "maintenance"}
    assert str(prune["schedule"]) == "<crontab: 15 3 * * * (m/h/dM/MY/d)>"


def test_the_source_entries_run_schedule_fetch_on_vps2() -> None:
    for name, args in (
        ("ysscores-fixtures", ("ysscores",)),
        ("satair-bridge", ("legacy",)),
        ("livesoccertv-48h", ("livesoccertv",)),
    ):
        entry = BEAT_SCHEDULE[name]
        assert entry["task"] == "adapters.schedule_fetch"
        assert entry["args"] == args
        # The pause and the breaker are in the database, which only VPS-2 can read (R17).
        assert entry["options"] == {"queue": "imports"}


def test_the_windows_are_utc() -> None:
    assert str(BEAT_SCHEDULE["ysscores-fixtures"]["schedule"]) == "<crontab: 0 */3 * * * (m/h/dM/MY/d)>"
    assert str(BEAT_SCHEDULE["satair-bridge"]["schedule"]) == "<crontab: 30 1-22/3 * * * (m/h/dM/MY/d)>"


def test_yallakora_runs_daily_and_every_six_hours_for_today_through_schedule_fetch() -> None:
    """D5 T057: a pause or an open breaker must stop both."""
    daily = BEAT_SCHEDULE["yallakora-daily"]
    today = BEAT_SCHEDULE["yallakora-today"]
    for entry in (daily, today):
        assert entry["task"] == "adapters.schedule_fetch"
        assert entry["args"] == ("yallakora",)
        assert entry["options"] == {"queue": "imports"}
    assert "kwargs" not in daily
    assert today["kwargs"] == {"window": "today"}
    assert str(daily["schedule"]) == "<crontab: 20 2 * * * (m/h/dM/MY/d)>"
    assert str(today["schedule"]) == "<crontab: 20 8,14,20 * * * (m/h/dM/MY/d)>"


def test_building_the_schedule_twice_gives_the_same_entries() -> None:
    assert build_beat_schedule().keys() == BEAT_SCHEDULE.keys()
