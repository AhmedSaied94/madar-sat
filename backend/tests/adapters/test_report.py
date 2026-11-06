"""The import report's pure parts (D4 T031, research R6).

`python -m app.adapters.report` is the read-only proof that imports ran unattended: one row per
scheduled slot, and the coverage per Cairo day for the prioritized competitions. The database
access lives in two thin query functions; everything that decides is here, so it is testable
without a server.
"""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest

from app.adapters import report
from app.adapters.report import (
    CoverageMatch,
    RunFacts,
    Slot,
    coverage_rows,
    expected_slots,
    manual_triggers,
    match_slots,
    render_coverage,
    render_runs,
)

T0 = datetime(2026, 11, 1, 0, 0, tzinfo=UTC)


def _sources(slots: list[Slot]) -> set[str]:
    return {slot.source for slot in slots}


def _at(slots: list[Slot], source: str) -> list[datetime]:
    return [slot.at for slot in slots if slot.source == source]


def test_the_slots_cover_the_window_at_the_schedule_rates() -> None:
    slots = expected_slots(T0, T0 + timedelta(hours=47, minutes=59))

    # The full-listing entries of schedule.py: every 3 h, every 3 h from 01:00, every 2 h, daily,
    # and sporteventz every 6 h. `yallakora-today` re-reads one day of the same listing, so it is no
    # slot, like the T−60 entry.
    assert _sources(slots) == {"ysscores", "legacy", "livesoccertv", "yallakora", "sporteventz"}
    assert len(_at(slots, "yallakora")) == 2

    sporteventz = _at(slots, "sporteventz")
    assert len(sporteventz) == 8
    assert sporteventz[0] == T0 + timedelta(minutes=10)

    ysscores = _at(slots, "ysscores")
    assert len(ysscores) == 16
    assert ysscores[0] == T0
    assert ysscores[1] == T0 + timedelta(hours=3)

    legacy = _at(slots, "legacy")
    assert len(legacy) == 16
    assert legacy[0] == T0 + timedelta(hours=1, minutes=30)

    livesoccertv = _at(slots, "livesoccertv")
    assert len(livesoccertv) == 24
    assert livesoccertv[0] == T0 + timedelta(minutes=45)


def test_the_window_ends_are_inclusive_at_the_slot_minute() -> None:
    window = expected_slots(T0 + timedelta(hours=2, minutes=59), T0 + timedelta(hours=3))
    assert [slot.at for slot in window if slot.source == "ysscores"] == [T0 + timedelta(hours=3)]


def test_a_stopped_run_fills_its_slot() -> None:
    """FR-035: the daily report calls a run that stopped on purpose answered, not missing."""
    slot = Slot("sporteventz-6h", "sporteventz", T0)
    run = RunFacts(7, "sporteventz", T0, "stopped", 0, 0)

    [result] = match_slots([slot], [run], [])

    assert result.run == run
    assert result.flagged is False
    assert result.reason == "scheduled"
    assert "stopped" in render_runs([result])[1]


def test_the_t60_refresh_is_not_a_coverage_slot() -> None:
    """It re-reads the same source minutes before kickoff; counting it would double one import."""
    names = {(slot.schedule, slot.source) for slot in expected_slots(T0, T0 + timedelta(hours=48))}
    assert not any("t60" in schedule for schedule, _ in names)


def test_a_run_covers_the_slot_it_started_in() -> None:
    slots = [Slot("ysscores-fixtures", "ysscores", T0 + timedelta(hours=3))]
    runs = [RunFacts(7, "ysscores", T0 + timedelta(hours=3, seconds=1), "succeeded", 42, 40)]

    [result] = match_slots(slots, runs, [])

    assert result.run is not None and result.run.id == 7
    assert result.manual is False
    assert result.flagged is False


def test_lateness_within_the_tolerance_still_covers_the_slot() -> None:
    slots = [Slot("ysscores-fixtures", "ysscores", T0 + timedelta(hours=3))]
    runs = [RunFacts(7, "ysscores", T0 + timedelta(hours=3, minutes=4), "succeeded", 1, 1)]

    [result] = match_slots(slots, runs, [])
    assert result.run is not None and result.flagged is False


def test_a_slot_without_a_run_is_missing_and_flags() -> None:
    slots = [Slot("ysscores-fixtures", "ysscores", T0 + timedelta(hours=3))]
    runs = [RunFacts(7, "ysscores", T0 + timedelta(hours=6), "succeeded", 1, 1)]

    [result] = match_slots(slots, runs, [])
    assert result.run is None
    assert result.reason == "missing"
    assert result.flagged is True


def test_a_run_of_another_source_never_covers_a_slot() -> None:
    slots = [Slot("ysscores-fixtures", "ysscores", T0)]
    runs = [RunFacts(1, "legacy", T0, "succeeded", 1, 1)]

    [result] = match_slots(slots, runs, [])
    assert result.run is None


def test_manual_triggers_come_from_the_source_actions() -> None:
    rows = [
        (T0, {"run": [None, T0.isoformat()]}),  # «تشغيل الآن»
        (T0 + timedelta(hours=1), {"is_enabled": [False, True]}),  # resume
        (T0 + timedelta(hours=2), {"is_enabled": [True, False]}),  # pause, no run
        (T0 + timedelta(hours=3), {"name": ["a", "b"]}),  # an ordinary source edit
    ]

    triggers = manual_triggers(rows)

    assert [t.kind for t in triggers] == ["run", "resume"]
    assert [t.at for t in triggers] == [T0, T0 + timedelta(hours=1)]


def test_a_slot_run_by_hand_is_flagged_even_when_it_succeeded() -> None:
    slot = Slot("ysscores-fixtures", "ysscores", T0 + timedelta(hours=3))
    run = RunFacts(9, "ysscores", T0 + timedelta(hours=3, seconds=5), "succeeded", 12, 12)
    trigger = manual_triggers([(T0 + timedelta(hours=3), {"run": [None, "x"]})])

    [result] = match_slots([slot], [run], trigger)

    assert result.run is not None and result.run.id == 9
    assert result.manual is True
    assert result.reason == "manual (run now)"
    assert result.flagged is True


def test_a_trigger_long_before_the_run_does_not_make_it_manual() -> None:
    slot = Slot("ysscores-fixtures", "ysscores", T0 + timedelta(hours=3))
    run = RunFacts(9, "ysscores", T0 + timedelta(hours=3), "succeeded", 12, 12)
    trigger = manual_triggers([(T0, {"run": [None, "x"]})])

    [result] = match_slots([slot], [run], trigger)
    assert result.manual is False


def test_the_table_marks_each_flagged_slot() -> None:
    slots = [
        Slot("ysscores-fixtures", "ysscores", T0),
        Slot("satair-bridge", "legacy", T0 + timedelta(minutes=30)),
    ]
    runs = [RunFacts(3, "ysscores", T0, "partial", 180, 12)]
    triggers = manual_triggers([(T0 + timedelta(minutes=30), {"is_enabled": [False, True]})])
    runs.append(RunFacts(4, "legacy", T0 + timedelta(minutes=30), "succeeded", 161, 2))

    table = "\n".join(render_runs(match_slots(slots, runs, triggers)))

    header = table.splitlines()[0]
    for column in ("source", "slot (UTC)", "run", "status", "found", "upserted", "manual", "reason"):
        assert column in header
    assert "ysscores" in table and "2026-11-01 00:00" in table
    assert "no" in table  # the empty manual cell of the scheduled run
    assert "manual (resume)" in table


def test_coverage_counts_a_match_only_with_a_visible_channel() -> None:
    day = date(2026, 11, 1)
    matches = [
        CoverageMatch(day, "الدوري المصري", True),
        CoverageMatch(day, "الدوري المصري", False),
        CoverageMatch(day, "دوري أبطال أوروبا", True),
    ]

    rows = coverage_rows([day], ["الدوري المصري", "دوري أبطال أوروبا"], matches, {})

    by_competition = {row.competition: row for row in rows}
    assert by_competition["الدوري المصري"].matches == 2
    assert by_competition["الدوري المصري"].with_channels == 1
    assert by_competition["دوري أبطال أوروبا"].matches == 1
    assert by_competition["دوري أبطال أوروبا"].with_channels == 1


def test_a_prioritized_competition_with_no_match_shows_as_a_gap() -> None:
    day = date(2026, 11, 1)
    rows = coverage_rows([day], ["الدوري المصري"], [], {})
    [row] = rows
    assert (row.matches, row.with_channels) == (0, 0)


def test_coverage_carries_the_unmatched_names_of_the_day() -> None:
    day = date(2026, 11, 1)
    rows = coverage_rows([day], ["الدوري المصري"], [], {day: ("Real Madrid",)})
    assert rows[0].unmatched == ("Real Madrid",)


def test_the_coverage_table_has_one_row_per_day_and_competition() -> None:
    days = [date(2026, 11, 1), date(2026, 11, 2)]
    matches = [CoverageMatch(days[0], "الدوري المصري", True)]

    table = "\n".join(render_coverage(coverage_rows(days, ["الدوري المصري"], matches, {})))

    assert "cairo day" in table.splitlines()[0]
    assert len([line for line in table.splitlines() if "2026-11-01" in line]) == 1
    assert len([line for line in table.splitlines() if "2026-11-02" in line]) == 1


def test_the_unmatched_names_are_shown_once_per_day() -> None:
    day = date(2026, 11, 1)
    rows = coverage_rows([day], ["أ", "ب"], [], {day: ("Real Madrid",)})

    lines = render_coverage(rows)

    assert "Real Madrid" in lines[1]
    assert "Real Madrid" not in lines[2]


def test_runs_exits_non_zero_when_a_slot_is_flagged(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(report, "_fetch_runs", lambda start, end: [])
    monkeypatch.setattr(report, "_fetch_triggers", lambda start, end: [])

    assert report.main(["runs", "--hours", "3"]) == 1


def test_runs_exits_zero_when_every_slot_ran(monkeypatch: pytest.MonkeyPatch) -> None:
    def runs(start: datetime, end: datetime) -> list[RunFacts]:
        return [
            RunFacts(index, slot.source, slot.at, "succeeded", 1, 1)
            for index, slot in enumerate(report.expected_slots(start, end))
        ]

    monkeypatch.setattr(report, "_fetch_runs", runs)
    monkeypatch.setattr(report, "_fetch_triggers", lambda start, end: [])

    assert report.main(["runs", "--hours", "3"]) == 0


def test_coverage_prints_one_day_without_a_database(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setattr(
        report,
        "_fetch_coverage",
        lambda days: (["دوري"], [CoverageMatch(days[0], "دوري", True)], {}),
    )

    assert report.main(["coverage", "--days", "1"]) == 0
    assert "cairo day" in capsys.readouterr().out
