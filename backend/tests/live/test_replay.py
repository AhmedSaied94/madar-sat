"""The 2026-11-04 capture replayed through ``decide``, a poll at a time (031 T011, research R13).

Three committed files feed it: ``specs/031-d05-live-sources/replay-timelines-2026-11-04.json`` for the scores
and statuses, and two trimmed from the same ``events.jsonl`` under ``fixtures/``.

**The assumption about list rows (R13).** The capture stopped reading a match's page when the match left
FilGoal's live list, and it saved no list page. So finishing is modelled from what it did keep, per poll:

- inside FilGoal's live set, FilGoal's last row stands;
- outside it, a last row at the second half or later reads full time, and anything else is no reading;
- YallaKora's last row stands.

That's an inference, and it carries the 3 FilGoal-only matches that finish and some of the others. The next
capture saves list pages, which settles it (T028, FR-025).

**The replay has two sources**, because Goal.com has only 15 minutes of data. That also makes it the replay
SC-006 asks for: with Goal.com's setting off, these are the results.
"""

from __future__ import annotations

import json
from collections import defaultdict
from dataclasses import dataclass, field, replace
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import pytest

from app.live.crosscheck import decide, next_peak
from app.live.sources import filgoal, yallakora
from app.live.sources.common import minute_value
from app.live.types import Decision, LiveState, Peak, Score, SideInput, SourceReading

SPEC = Path(__file__).parents[3] / "specs" / "031-d05-live-sources"
FIXTURES = Path(__file__).parent / "fixtures"
TIMELINES = json.loads((SPEC / "replay-timelines-2026-11-04.json").read_text(encoding="utf-8"))
LIVE_SET = json.loads((FIXTURES / "replay-filgoal-live-set-2026-11-04.json").read_text(encoding="utf-8"))["records"]
CLOCK = json.loads((FIXTURES / "replay-filgoal-clock-2026-11-04.json").read_text(encoding="utf-8"))["records"]

DROP_HOLD = timedelta(minutes=5)
DISAGREE_AFTER = timedelta(minutes=10)
FULLTIME_HOLD = timedelta(minutes=10)
FIRST_SOURCE_LIMIT = timedelta(seconds=60)
MINUTE_SLACK = 5

PORTO_NAPOLI = "378944"
MOULOUDIA = "376088"
BRISTOL_WOLVES = "378892"
LEFT_OPEN = {MOULOUDIA, BRISTOL_WOLVES}
BOTH_SOURCES = {match["filgoal_id"] for match in TIMELINES["matches"] if match["yallakora_id"]}


def _time(text: str) -> datetime:
    return datetime.fromisoformat(text)


POLLS = [_time(poll) for poll in TIMELINES["polls"]]
LIVE_SETS = [(_time(row["t"]), set(row["ids"])) for row in LIVE_SET]


def _live_set_at(now: datetime) -> set[str]:
    current: set[str] = set()
    for at, ids in LIVE_SETS:
        if at > now:
            break
        current = ids
    return current


def _score(row: list[Any]) -> Score | None:
    """Rows from before kickoff carry no score."""
    home, away = row[1]
    return None if home is None or away is None else Score(home, away)


def _rank(state: tuple[str, str | None]) -> int:
    return {("live", "2H"): 3, ("finished", None): 4}.get(state, 0)


def _reading(source: str, row: list[Any], status: tuple[str, str | None], label: str) -> SideInput:
    return SideInput.valid(
        SourceReading(
            source=source,
            external_id="1",
            home="أ",
            away="ب",
            competition=None,
            kickoff_at=None,
            status=status[0],
            period=status[1],
            minute=None,
            score=_score(row),
            status_label=label,
        )
    )


def _last_row(rows: list[list[Any]], now: datetime) -> list[Any] | None:
    found = None
    for row in rows:
        if _time(row[0]) > now:
            break
        found = row
    return found


def _filgoal_side(match: dict[str, Any], now: datetime) -> SideInput:
    row = _last_row(match["filgoal"], now)
    if row is None:
        return SideInput.not_covering()
    status = filgoal.STATUS_MAP[row[2]]
    if match["filgoal_id"] in _live_set_at(now):
        return _reading("filgoal", row, status, row[2])
    if _rank(status) >= _rank(("live", "2H")):
        return _reading("filgoal", row, ("finished", None), "انتهت")
    return SideInput.not_covering()


def _yallakora_side(match: dict[str, Any], now: datetime) -> SideInput:
    row = _last_row(match["yallakora"], now)
    if row is None:
        return SideInput.not_covering()
    return _reading("yallakora", row, yallakora.STATUS_MAP[row[2]], row[2])


def _shows_full_time(side: SideInput) -> bool:
    return side.reading is not None and side.reading.status == "finished"


@dataclass
class Replayed:
    match: dict[str, Any]
    state: LiveState
    finished_by: str | None = None
    finished_at: datetime | None = None
    first_full_time: datetime | None = None
    drops: list[tuple[Score, Score]] = field(default_factory=list)
    alerts: int = 0
    rises_at: list[tuple[Score, datetime]] = field(default_factory=list)
    stages_undone: int = 0


_STAGE_ORDER = {
    ("scheduled", None): 0,
    ("live", "1H"): 1,
    ("halftime", None): 2,
    ("live", "2H"): 3,
    ("finished", None): 4,
}


def _next_state(before: LiveState, decision: Decision) -> LiveState:
    return replace(
        before,
        status=decision.status if decision.write_status else before.status,
        period=decision.period if decision.write_status else before.period,
        minute=decision.minute if decision.write_status else before.minute,
        status_label=decision.status_label if decision.write_status else before.status_label,
        confirmed=decision.confirm or before.confirmed,
        drop_since=decision.drop_since,
        status_drop_since=decision.status_drop_since,
        score_first_source=decision.score_first_source,
        score_changed_at=decision.score_changed_at,
        fulltime_source=decision.fulltime_source,
        fulltime_since=decision.fulltime_since,
        finish_wait_since=decision.finish_wait_since,
        disagreement_since=decision.disagreement_since,
    )


def _covers(score: Score, other: Score) -> bool:
    return score.home >= other.home and score.away >= other.away


def _replay(match: dict[str, Any]) -> Replayed:
    result = Replayed(match, LiveState(match_id=1, status="scheduled", period=None))
    disagree = f"disagree:{result.state.match_id}"
    alerted = False
    for now in POLLS:
        sides = {"filgoal": _filgoal_side(match, now), "yallakora": _yallakora_side(match, now)}
        if result.first_full_time is None and any(_shows_full_time(side) for side in sides.values()):
            result.first_full_time = now
        before = result.state
        decision = decide(
            before, sides, now, drop_hold=DROP_HOLD, disagree_after=DISAGREE_AFTER, fulltime_hold=FULLTIME_HOLD
        )
        result.state = _next_state(before, decision)
        if decision.confirm is not None:
            if before.confirmed is not None and not _covers(decision.confirm, before.confirmed):
                result.drops.append((before.confirmed, decision.confirm))  # the drop rule waits, by design
            else:
                result.rises_at.append((decision.confirm, now))
        if disagree in decision.open_problems and not alerted:
            alerted = True
            result.alerts += 1
        if disagree in decision.close_problems:
            alerted = False
        was = _STAGE_ORDER.get((before.status, before.period), 0)
        if _STAGE_ORDER.get((result.state.status, result.state.period), 0) < was:
            result.stages_undone += 1
        if result.state.status == "finished" and before.status != "finished":
            result.finished_at = now
            result.finished_by = "second source" if sum(map(_shows_full_time, sides.values())) >= 2 else "hold"
            break
    return result


@pytest.fixture(scope="module")
def replayed() -> dict[str, Replayed]:
    return {match["filgoal_id"]: _replay(match) for match in TIMELINES["matches"]}


def _last_score(match: dict[str, Any]) -> Score:
    rows = sorted(match["filgoal"] + match["yallakora"], key=lambda row: row[0])
    return next(score for row in reversed(rows) if (score := _score(row)) is not None)


def test_the_replay_covers_all_sixteen_matches(replayed):
    assert len(replayed) == 16
    assert len(BOTH_SOURCES) == 11


def test_every_new_score_reaches_fans_within_sixty_seconds_of_the_first_source(replayed):
    """SC-001."""
    late = []
    for result in replayed.values():
        rows = sorted(result.match["filgoal"] + result.match["yallakora"], key=lambda row: row[0])
        for score, at in result.rises_at:
            first = next((_time(row[0]) for row in rows if _score(row) == score), None)
            if first is not None and at - first > FIRST_SOURCE_LIMIT:
                late.append((result.match["filgoal_id"], score, at - first))
    assert late == []


def test_only_mouloudias_false_score_ever_goes_down(replayed):
    """SC-001: no score is shown backward. The one correction is the drop rule ending a false goal (R2)."""
    drops = {key: result.drops for key, result in replayed.items() if result.drops}

    assert drops == {MOULOUDIA: [(Score(2, 0), Score(1, 0))]}


def test_mouloudia_ends_on_one_nil(replayed):
    assert replayed[MOULOUDIA].state.confirmed == Score(1, 0)


@pytest.mark.parametrize("key", [match["filgoal_id"] for match in TIMELINES["matches"]])
def test_every_final_score_is_the_last_score_the_sources_showed(replayed, key):
    """SC-001 and SC-005: all 16, including the 11 on both sources."""
    result = replayed[key]

    assert result.state.confirmed == _last_score(result.match)


def test_at_most_one_disagreement_alert_on_porto_napoli(replayed):
    """SC-002."""
    alerts = {key: result.alerts for key, result in replayed.items() if result.alerts}

    assert sum(alerts.values()) <= 1
    assert set(alerts) <= {PORTO_NAPOLI}


def test_no_status_move_had_to_be_undone(replayed):
    assert {key: result.stages_undone for key, result in replayed.items() if result.stages_undone} == {}


def test_fourteen_of_sixteen_finish_ten_by_a_second_source_and_four_by_the_hold(replayed):
    """SC-005, on the assumption this module's docstring states."""
    finished = {key: result for key, result in replayed.items() if result.state.status == "finished"}
    by_second_source = [key for key, result in finished.items() if result.finished_by == "second source"]
    by_hold = [key for key, result in finished.items() if result.finished_by == "hold"]

    assert set(replayed) - set(finished) == LEFT_OPEN
    assert len(finished) == 14
    assert len(by_second_source) == 10
    assert len(by_hold) == 4


def test_the_finish_delays_are_what_research_measured(replayed):
    """R13: at most 5 minutes with a second source, and 14.9 on the hold."""
    for result in replayed.values():
        if result.state.status != "finished":
            continue
        delay = result.finished_at - result.first_full_time
        limit = timedelta(minutes=5) if result.finished_by == "second source" else timedelta(minutes=15)
        assert delay <= limit, result.match["filgoal_id"]


def test_the_two_left_open_keep_their_scores(replayed):
    """FR-009 finishes Bristol City v Wolves at + 150 (``test_watchdog.py``). The capture can't tell for Mouloudia."""
    assert replayed[BRISTOL_WOLVES].state.status == "live"
    assert replayed[BRISTOL_WOLVES].state.confirmed == Score(1, 2)


# ------------------------------------------------------------------------------------- SC-004: the minute


def _clock_reading(record: dict[str, Any], status: tuple[str, str | None]) -> SourceReading:
    current = {
        "IsCounterEnabled": record["counter"],
        "TimeElapsed": {"Minutes": record["minutes"]},
        "MatchStatusMaxTime": record["max"],
    }
    return SourceReading(
        source="filgoal",
        external_id=record["match"],
        home="أ",
        away="ب",
        competition=None,
        kickoff_at=None,
        status=status[0],
        period=status[1],
        minute=filgoal._minute(current, status[1]),  # noqa: SLF001 - the code under test, on real clock values
        score=Score(0, 0),
        status_label=record["status"],
    )


@dataclass
class ClockReplay:
    readings: int = 0
    shown: int = 0
    parser_minutes: int = 0
    shown_by_period: dict[tuple[str, str], list[int]] = field(default_factory=lambda: defaultdict(list))
    negative: int = 0


def _replay_clock() -> ClockReplay:
    """Each match's records in order, through the FilGoal minute code and the minute rules."""
    result = ClockReplay()
    states: dict[str, LiveState] = {}
    peaks: dict[str, Peak | None] = {}
    for record in CLOCK:
        key = record["match"]
        status = filgoal.STATUS_MAP[record["status"]]
        reading = _clock_reading(record, status)
        before = states.get(key) or LiveState(match_id=int(key), status="scheduled", period=None, confirmed=Score(0, 0))
        before = replace(before, peaks={"filgoal": peak} if (peak := peaks.get(key)) else {})
        decision = decide(
            before,
            {"filgoal": SideInput.valid(reading)},
            _time(record["t"]),
            drop_hold=DROP_HOLD,
            disagree_after=DISAGREE_AFTER,
            fulltime_hold=FULLTIME_HOLD,
        )
        states[key] = _next_state(before, decision)
        peaks[key] = next_peak(peaks.get(key), reading)
        if reading.status != "live":
            continue
        result.readings += 1
        result.parser_minutes += reading.minute is not None
        if reading.minute is not None and reading.minute.startswith("-"):
            result.negative += 1
        value = minute_value(decision.minute)
        if value is None:
            continue
        result.shown += 1
        result.shown_by_period[(key, reading.period or "")].append(value)
    return result


@pytest.fixture(scope="module")
def clock() -> ClockReplay:
    return _replay_clock()


def test_the_capture_holds_the_live_readings_research_counted(clock):
    assert clock.readings == 1367


def test_at_least_95_percent_of_live_readings_show_a_minute(clock):
    """SC-004. R4 measured 98.2 %, 1,343, for the same rule."""
    assert clock.shown / clock.readings >= 0.95


def test_no_minute_is_negative(clock):
    assert clock.negative == 0
    assert all(value >= 0 for values in clock.shown_by_period.values() for value in values)


def test_no_wrapped_minute_is_shown(clock):
    """Bristol City v Wolves wraps from 104 to 46 (R4). No shown minute falls more than 5 below its period's highest."""
    wrapped = []
    for key, values in clock.shown_by_period.items():
        highest = 0
        for value in values:
            highest = max(highest, value)
            if value < highest - MINUTE_SLACK:
                wrapped.append((key, value, highest))
    assert wrapped == []


def test_bristol_reached_its_real_peak_and_kept_it(clock):
    values = clock.shown_by_period[(BRISTOL_WOLVES, "2H")]

    assert max(values) >= 90
    assert min(values[values.index(max(values)) :]) >= max(values) - MINUTE_SLACK
