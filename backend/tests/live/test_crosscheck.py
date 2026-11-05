"""The live rules as one table test (031 contracts/live-rules.md, T010).

Every test goes through ``decided``, which runs the poll with the sources in every order and asserts that
the order they're passed in changes nothing. A rule that holds for any source is parametrized over the three.
"""

from __future__ import annotations

from dataclasses import replace
from datetime import UTC, datetime, timedelta
from itertools import permutations

import pytest

from app.live.crosscheck import BOTH_DOWN, decide, next_peak
from app.live.types import Decision, LiveState, Peak, Score, SideInput, SourceReading

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
DROP_HOLD = timedelta(minutes=5)
DISAGREE_AFTER = timedelta(minutes=10)
FULLTIME_HOLD = timedelta(minutes=10)
DISAGREE = "disagree:7"
SOURCES = ("filgoal", "goal", "yallakora")
ABSENT = SideInput.not_covering()
DOWN = SideInput.unavailable()


def side(
    source: str,
    score: Score | None = None,
    *,
    status: str | None = "live",
    period: str | None = "1H",
    minute: str | None = "23",
    unknown: str | None = None,
) -> SideInput:
    return SideInput.valid(
        SourceReading(
            source=source,
            external_id="1",
            home="أ",
            away="ب",
            competition=None,
            kickoff_at=None,
            status=None if unknown else status,
            period=None if unknown else period,
            minute=None if unknown else minute,
            score=score,
            status_label=None if unknown else f"{source}-label",
            unknown_status=unknown,
        )
    )


def state(confirmed: Score | None = Score(0, 0), **changes) -> LiveState:
    values = {"status": "live", "period": "1H", "minute": "22", "status_label": "الشوط الأول"}
    return replace(LiveState(match_id=7, confirmed=confirmed, **values), **changes)


def decided(before: LiveState, sides: dict[str, SideInput], now: datetime = NOW) -> Decision:
    decisions = [
        decide(
            before,
            dict(order),
            now,
            drop_hold=DROP_HOLD,
            disagree_after=DISAGREE_AFTER,
            fulltime_hold=FULLTIME_HOLD,
        )
        for order in permutations(sides.items())
    ]
    assert all(decision == decisions[0] for decision in decisions)
    return decisions[0]


def others(source: str) -> list[str]:
    return [name for name in SOURCES if name != source]


# ---------------------------------------------------------------------------------------- the score


def test_the_first_score_is_accepted_with_its_source_and_time():
    decision = decided(state(None), {"yallakora": side("yallakora", Score(0, 0))})

    assert decision.confirm == Score(0, 0)
    assert decision.score_first_source == "yallakora"
    assert decision.score_changed_at == NOW


def test_the_first_score_is_the_one_covering_the_most_goals():
    decision = decided(state(None), {"filgoal": side("filgoal", Score(1, 0)), "goal": side("goal", Score(2, 0))})

    assert decision.confirm == Score(2, 0)
    assert decision.score_first_source == "goal"


@pytest.mark.parametrize(
    ("winner", "sides"),
    [
        ("filgoal", {"filgoal": Score(1, 0), "goal": Score(0, 1), "yallakora": Score(0, 1)}),
        ("goal", {"goal": Score(1, 0), "yallakora": Score(0, 1)}),
    ],
)
def test_the_first_score_on_a_tie_follows_the_order(winner, sides):
    decision = decided(state(None), {name: side(name, score) for name, score in sides.items()})

    assert decision.score_first_source == winner
    assert decision.confirm == sides[winner]


@pytest.mark.parametrize("source", SOURCES)
def test_a_rise_from_any_source_goes_out_at_once(source):
    before = state(Score(1, 0), drop_since=NOW - timedelta(minutes=1))
    sides = {source: side(source, Score(2, 0))}
    sides |= {name: side(name, Score(1, 0)) for name in others(source)}

    decision = decided(before, sides)

    assert decision.confirm == Score(2, 0)
    assert decision.score_first_source == source
    assert decision.score_changed_at == NOW
    assert decision.drop_since is None


@pytest.mark.parametrize("sources", [("filgoal", "goal"), ("goal", "yallakora"), ("filgoal", "yallakora")])
def test_the_highest_of_two_rises_wins(sources):
    first, second = sources
    decision = decided(state(Score(0, 0)), {first: side(first, Score(1, 0)), second: side(second, Score(2, 1))})

    assert decision.confirm == Score(2, 1)
    assert decision.score_first_source == second


def test_two_rises_that_tie_follow_the_order():
    sides = {"yallakora": side("yallakora", Score(0, 1)), "goal": side("goal", Score(1, 0))}

    decision = decided(state(Score(0, 0)), sides)

    assert decision.confirm == Score(1, 0)
    assert decision.score_first_source == "goal"


@pytest.mark.parametrize("lagging", SOURCES)
def test_a_lagging_source_neither_blocks_nor_lowers_a_rise(lagging):
    sides = {name: side(name, Score(1, 1)) for name in others(lagging)}
    sides[lagging] = side(lagging, Score(0, 0))

    decision = decided(state(Score(0, 0)), sides)

    assert decision.confirm == Score(1, 1)
    assert decision.drop_since is None


def test_the_same_score_again_changes_nothing_and_keeps_who_said_it_first():
    first_seen = NOW - timedelta(minutes=4)
    before = state(Score(1, 0), score_first_source="goal", score_changed_at=first_seen)

    decision = decided(before, {"filgoal": side("filgoal", Score(1, 0))})

    assert decision.confirm is None
    assert decision.score_first_source == "goal"
    assert decision.score_changed_at == first_seen


@pytest.mark.parametrize("keeping", SOURCES)
def test_a_lower_reading_keeps_the_score_while_any_reading_covers_it(keeping):
    sides = {name: side(name, Score(1, 1)) for name in others(keeping)}
    sides[keeping] = side(keeping, Score(2, 1))

    decision = decided(state(Score(2, 1)), sides)

    assert decision.confirm is None
    assert decision.drop_since is None


@pytest.mark.parametrize("source", SOURCES)
def test_a_drop_held_under_five_minutes_changes_nothing(source):
    started = NOW - DROP_HOLD + timedelta(seconds=1)
    fresh = decided(state(Score(2, 1)), {source: side(source, Score(1, 1))})
    held = decided(state(Score(2, 1), drop_since=started), {source: side(source, Score(1, 1))})

    assert (fresh.confirm, fresh.drop_since) == (None, NOW)
    assert (held.confirm, held.drop_since) == (None, started)


@pytest.mark.parametrize("source", SOURCES)
def test_a_drop_goes_out_at_five_minutes(source):
    before = state(Score(2, 1), drop_since=NOW - DROP_HOLD, score_first_source="goal")

    decision = decided(before, {source: side(source, Score(1, 1))})

    assert decision.confirm == Score(1, 1)
    assert decision.drop_since is None
    assert decision.score_first_source == source
    assert decision.score_changed_at == NOW


def test_a_drop_at_five_minutes_takes_the_highest_reading():
    before = state(Score(3, 1), drop_since=NOW - DROP_HOLD)

    decision = decided(before, {"yallakora": side("yallakora", Score(1, 1)), "filgoal": side("filgoal", Score(2, 1))})

    assert decision.confirm == Score(2, 1)


def test_two_sources_agreeing_on_a_lower_score_dont_lower_it_before_five_minutes():
    decision = decided(
        state(Score(2, 1)),
        {"filgoal": side("filgoal", Score(1, 1)), "yallakora": side("yallakora", Score(1, 1))},
    )

    assert (decision.confirm, decision.drop_since) == (None, NOW)


def test_a_reappearing_score_clears_the_drop():
    before = state(Score(2, 1), drop_since=NOW - timedelta(minutes=4))

    decision = decided(before, {"filgoal": side("filgoal", Score(2, 1))})

    assert (decision.confirm, decision.drop_since) == (None, None)


def test_a_score_that_rises_on_one_side_and_falls_on_the_other_is_a_drop():
    before = state(Score(1, 1))

    fresh = decided(before, {"filgoal": side("filgoal", Score(0, 2))})
    held = decided(replace(before, drop_since=NOW - DROP_HOLD), {"filgoal": side("filgoal", Score(0, 2))})

    assert (fresh.confirm, fresh.drop_since) == (None, NOW)
    assert held.confirm == Score(0, 2)


def test_a_poll_with_no_score_changes_nothing_and_keeps_the_drop_open():
    started = NOW - DROP_HOLD
    before = state(Score(2, 1), drop_since=started)

    decision = decided(before, {"filgoal": side("filgoal", None)})

    assert (decision.confirm, decision.drop_since) == (None, started)


# ------------------------------------------------------------------------------------------ penalties


def test_penalties_rise_like_goals():
    before = state(Score(1, 1, 2, 2), status="penalties", period=None)

    decision = decided(before, {"filgoal": side("filgoal", Score(1, 1, 3, 2), status="penalties", period=None)})

    assert decision.confirm == Score(1, 1, 3, 2)


def test_lower_penalties_are_a_drop():
    before = state(Score(1, 1, 3, 2), status="penalties", period=None)
    reading = {"filgoal": side("filgoal", Score(1, 1, 2, 2), status="penalties", period=None)}

    assert (decided(before, reading).confirm, decided(before, reading).drop_since) == (None, NOW)
    assert decided(replace(before, drop_since=NOW - DROP_HOLD), reading).confirm == Score(1, 1, 2, 2)


@pytest.mark.parametrize("source", SOURCES)
def test_a_source_without_penalties_doesnt_erase_them(source):
    before = state(Score(1, 1, 3, 2), status="penalties", period=None)

    decision = decided(before, {source: side(source, Score(1, 1), status="penalties", period=None)})

    assert (decision.confirm, decision.drop_since) == (None, None)


def test_a_higher_score_without_penalties_keeps_the_accepted_ones():
    before = state(Score(1, 1, 3, 2), status="penalties", period=None)

    decision = decided(before, {"yallakora": side("yallakora", Score(2, 1), status="penalties", period=None)})

    assert decision.confirm == Score(2, 1, 3, 2)


def test_penalties_arriving_from_one_source_are_accepted_at_once():
    before = state(Score(1, 1), status="penalties", period=None)
    sides = {
        "filgoal": side("filgoal", Score(1, 1, 1, 0), status="penalties", period=None),
        "yallakora": side("yallakora", Score(1, 1), status="penalties", period=None),
    }

    decision = decided(before, sides)

    assert decision.confirm == Score(1, 1, 1, 0)
    assert decision.disagreement_since is None


# --------------------------------------------------------------------------------------- disagreement


def test_sources_that_differ_start_the_clock_with_no_alert():
    decision = decided(
        state(Score(1, 0)), {"filgoal": side("filgoal", Score(1, 0)), "yallakora": side("yallakora", Score(0, 0))}
    )

    assert decision.disagreement_since == NOW
    assert DISAGREE not in decision.open_problems


def test_a_disagreement_alerts_at_ten_minutes():
    started = NOW - DISAGREE_AFTER
    sides = {"filgoal": side("filgoal", Score(1, 0)), "yallakora": side("yallakora", Score(0, 0))}

    early = decided(state(Score(1, 0), disagreement_since=NOW - timedelta(minutes=9)), sides)
    assert DISAGREE not in early.open_problems

    decision = decided(state(Score(1, 0), disagreement_since=started), sides)
    assert DISAGREE in decision.open_problems
    assert decision.disagreement_since == started


def test_a_disagreement_closes_when_they_agree():
    started = NOW - timedelta(minutes=20)
    sides = {"filgoal": side("filgoal", Score(1, 0)), "yallakora": side("yallakora", Score(1, 0))}

    decision = decided(state(Score(1, 0), disagreement_since=started), sides)

    assert decision.disagreement_since is None
    assert DISAGREE in decision.close_problems
    assert DISAGREE not in decision.open_problems


def test_a_source_going_quiet_doesnt_end_a_disagreement():
    started = NOW - timedelta(minutes=3)
    sides = {"filgoal": side("filgoal", Score(1, 0)), "yallakora": ABSENT}

    decision = decided(state(Score(1, 0), disagreement_since=started), sides)

    assert decision.disagreement_since == started
    assert DISAGREE not in decision.close_problems


def test_a_source_not_covering_a_match_gives_no_disagreement():
    sides = {"filgoal": side("filgoal", Score(1, 0)), "yallakora": ABSENT, "goal": ABSENT}

    decision = decided(state(Score(1, 0)), sides)

    assert decision.disagreement_since is None
    assert decision.open_problems == ()


def test_a_finished_match_that_differs_alerts_as_it_finishes():
    before = state(Score(2, 1), status="live", period="2H", finish_wait_since=NOW - DROP_HOLD)
    sides = {
        "filgoal": side("filgoal", Score(2, 1), status="finished", period=None, minute=None),
        "yallakora": side("yallakora", Score(1, 1), status="finished", period=None, minute=None),
    }

    decision = decided(before, sides)

    assert decision.status == "finished"
    assert DISAGREE in decision.open_problems


# ------------------------------------------------------------------------------------- later statuses


@pytest.mark.parametrize("source", SOURCES)
def test_a_later_status_goes_out_at_once_from_any_source(source):
    sides = {source: side(source, Score(0, 0), status="live", period="2H", minute="47")}
    sides |= {name: side(name, Score(0, 0), status="halftime", period=None, minute=None) for name in others(source)}

    decision = decided(state(status="halftime", period=None, minute=None), sides)

    assert decision.write_status is True
    assert (decision.status, decision.period, decision.minute) == ("live", "2H", "47")
    assert decision.status_label == f"{source}-label"


def test_filgoal_behind_doesnt_hold_a_later_status_back():
    sides = {
        "filgoal": side("filgoal", Score(0, 0), status="live", period="1H", minute="46"),
        "yallakora": side("yallakora", Score(0, 0), status="halftime", period=None, minute=None),
    }

    decision = decided(state(status="live", period="1H", minute="45"), sides)

    assert decision.status == "halftime"
    assert decision.status_label == "yallakora-label"


@pytest.mark.parametrize(
    ("sides", "label"),
    [
        (("filgoal", "goal", "yallakora"), "filgoal-label"),
        (("goal", "yallakora"), "goal-label"),
    ],
)
def test_a_tie_on_stage_follows_the_order(sides, label):
    readings = {name: side(name, Score(0, 0), period="2H") for name in sides}

    decision = decided(state(status="halftime", period=None), readings)

    assert decision.status_label == label


def test_the_stored_stage_takes_its_label_from_the_first_source_showing_it():
    sides = {
        "goal": side("goal", Score(0, 0), status="live", period="1H"),
        "yallakora": side("yallakora", Score(0, 0), status="live", period="1H"),
    }

    decision = decided(state(status_drop_since=NOW - timedelta(minutes=2)), sides)

    assert decision.status_label == "goal-label"
    assert decision.status_drop_since is None


def test_live_with_no_period_moves_a_scheduled_row_to_live():
    decision = decided(
        state(None, status="scheduled", period=None, minute=None, status_label=None),
        {"yallakora": side("yallakora", Score(0, 0), status="live", period=None, minute=None)},
    )

    assert (decision.status, decision.period) == ("live", None)


@pytest.mark.parametrize(
    ("status", "period"),
    [("live", "1H"), ("halftime", None), ("live", "2H"), ("extra_time", "ET1"), ("penalties", None)],
)
def test_live_with_no_period_never_counts_as_a_move_back(status, period):
    before = state(status=status, period=period, status_drop_since=NOW - timedelta(minutes=9))

    decision = decided(before, {"yallakora": side("yallakora", Score(0, 0), status="live", period=None, minute=None)})

    assert (decision.status, decision.period) == (status, period)
    assert decision.status_drop_since is None


def test_a_period_arriving_on_a_row_with_none_is_written():
    decision = decided(state(status="live", period=None), {"filgoal": side("filgoal", Score(0, 0), period="1H")})

    assert (decision.status, decision.period) == ("live", "1H")


# ---------------------------------------------------------------------------------- backward statuses


@pytest.mark.parametrize("source", SOURCES)
def test_a_backward_status_holds_for_five_minutes(source):
    reading = {source: side(source, Score(0, 0), status="live", period="1H", minute="44")}
    before = state(status="live", period="2H", minute="50", status_label="stored")

    fresh = decided(before, reading)
    held = decided(replace(before, status_drop_since=NOW - timedelta(minutes=4)), reading)
    gone = decided(replace(before, status_drop_since=NOW - DROP_HOLD), reading)

    assert (fresh.status, fresh.period, fresh.status_drop_since, fresh.status_label) == ("live", "2H", NOW, "stored")
    assert (held.status, held.period) == ("live", "2H")
    assert (gone.status, gone.period, gone.status_drop_since) == ("live", "1H", None)


def test_a_backward_status_waits_for_every_source():
    before = state(status="live", period="2H", status_drop_since=NOW - timedelta(minutes=9))
    sides = {
        "filgoal": side("filgoal", Score(0, 0), status="live", period="1H"),
        "yallakora": side("yallakora", Score(0, 0), status="live", period="2H"),
    }

    decision = decided(before, sides)

    assert (decision.status, decision.period, decision.status_drop_since) == ("live", "2H", None)


def test_a_backward_move_at_five_minutes_writes_the_latest_stage_shown():
    before = state(status="live", period="2H", status_drop_since=NOW - DROP_HOLD)
    sides = {
        "filgoal": side("filgoal", Score(0, 0), status="scheduled", period=None, minute=None),
        "yallakora": side("yallakora", Score(0, 0), status="live", period="1H", minute=None),
    }

    decision = decided(before, sides)

    assert (decision.status, decision.period) == ("live", "1H")


@pytest.mark.parametrize("source", SOURCES)
def test_a_failed_request_cant_move_a_match_back(source):
    before = state(status="live", period="2H", status_drop_since=NOW - timedelta(minutes=2))
    sides = {source: ABSENT}
    sides |= {name: ABSENT for name in others(source)}

    decision = decided(before, sides)

    assert decision.write_status is False
    assert decision.fallback is False
    assert decision.status_drop_since == before.status_drop_since


@pytest.mark.parametrize("status", ["finished", "cancelled", "abandoned"])
def test_a_final_status_never_returns(status):
    before = state(Score(2, 1), status=status, period=None, minute=None)

    decision = decided(before, {"filgoal": side("filgoal", Score(3, 1), status="live", period="2H", minute="60")})

    assert decision.write_status is False
    assert decision.confirm is None


def test_cancelled_comes_only_from_the_first_usable_source():
    sides = {
        "filgoal": side("filgoal", Score(1, 0), status="live", period="2H"),
        "yallakora": side("yallakora", Score(1, 0), status="cancelled", period=None, minute=None),
    }

    decision = decided(state(Score(1, 0), status="live", period="2H"), sides)

    assert decision.status == "live"


@pytest.mark.parametrize("status", ["cancelled", "abandoned"])
def test_a_cancelled_status_from_the_first_usable_source_is_written(status):
    sides = {
        "filgoal": side("filgoal", Score(1, 0), status=status, period=None, minute=None),
        "yallakora": side("yallakora", Score(1, 0), status="live", period="2H"),
    }

    decision = decided(state(Score(1, 0), status="live", period="2H"), sides)

    assert (decision.status, decision.period, decision.minute) == (status, None, None)


def test_postponed_from_the_first_usable_source_is_written_on_a_row_that_hasnt_started():
    sides = {
        "filgoal": side("filgoal", None, status="postponed", period=None, minute=None),
        "yallakora": side("yallakora", None, status="scheduled", period=None, minute=None),
    }

    decision = decided(state(None, status="scheduled", period=None, minute=None), sides)

    assert decision.status == "postponed"


def test_postponed_from_another_source_is_ignored():
    sides = {
        "filgoal": side("filgoal", None, status="scheduled", period=None, minute=None),
        "yallakora": side("yallakora", None, status="postponed", period=None, minute=None),
    }

    decision = decided(state(None, status="scheduled", period=None, minute=None), sides)

    assert decision.status == "scheduled"


# -------------------------------------------------------------------------------------------- the minute


def test_the_minute_comes_from_the_source_that_supplied_the_status():
    sides = {
        "filgoal": side("filgoal", Score(0, 0), status="live", period="1H", minute="44"),
        "goal": side("goal", Score(0, 0), status="live", period="2H", minute="47"),
    }

    assert decided(state(status="live", period="1H", minute="44"), sides).minute == "47"


def test_the_minute_comes_from_the_next_source_at_the_same_stage():
    sides = {
        "filgoal": side("filgoal", Score(0, 0), minute=None),
        "goal": side("goal", Score(0, 0), minute="30"),
        "yallakora": side("yallakora", Score(0, 0), minute=None),
    }

    decision = decided(state(minute="29"), sides)

    assert decision.status_label == "filgoal-label"
    assert decision.minute == "30"


def test_a_late_answer_within_five_of_the_peak_keeps_the_stored_minute():
    before = state(status="live", period="2H", minute="60", peaks={"filgoal": Peak(60, "2H")})

    decision = decided(before, {"filgoal": side("filgoal", Score(0, 0), period="2H", minute="59")})

    assert decision.minute == "60"


def test_a_minute_more_than_five_below_the_peak_in_the_same_period_counts_as_no_minute():
    """FilGoal's wrap, from 104 to 46."""
    before = state(status="live", period="2H", minute=None, peaks={"filgoal": Peak(104, "2H")})

    decision = decided(before, {"filgoal": side("filgoal", Score(1, 2), period="2H", minute="46")})

    assert decision.minute is None


def test_the_wrap_never_shows_even_after_the_stored_minute_was_cleared():
    peaks = {"filgoal": Peak(104, "2H")}
    before = state(status="live", period="2H", minute="90+14", peaks=peaks)
    first = decided(before, {"filgoal": side("filgoal", Score(1, 2), period="2H", minute=None)})
    assert first.minute is None

    next_poll = replace(before, minute=first.minute)
    second = decided(next_poll, {"filgoal": side("filgoal", Score(1, 2), period="2H", minute="46")})

    assert second.minute is None


def test_a_real_minute_in_another_period_stands_after_a_long_first_half():
    before = state(status="halftime", period=None, minute=None, peaks={"filgoal": Peak(53, "1H")})

    decision = decided(before, {"filgoal": side("filgoal", Score(0, 0), period="2H", minute="47")})

    assert (decision.period, decision.minute) == ("2H", "47")


def test_another_sources_peak_has_no_say_on_this_ones_minute():
    before = state(status="live", period="2H", minute=None, peaks={"filgoal": Peak(104, "2H")})
    sides = {
        "filgoal": side("filgoal", Score(0, 0), period="2H", minute=None),
        "goal": side("goal", Score(0, 0), period="2H", minute="60"),
    }

    assert decided(before, sides).minute == "60"


@pytest.mark.parametrize(
    "sides",
    [
        pytest.param(
            {"filgoal": side("filgoal", Score(0, 0), period="2H", minute=None)}, id="a list row with no minute"
        ),
        pytest.param({"filgoal": side("filgoal", Score(0, 0), unknown="شوط إضافي")}, id="only unknown rows"),
        pytest.param(
            {"filgoal": side("filgoal", Score(0, 0), status="finished", period=None, minute=None)},
            id="the full-time hold",
        ),
    ],
)
def test_a_poll_with_readings_and_no_minute_for_the_stage_clears_it(sides):
    assert decided(state(minute="88", status="live", period="2H"), sides).minute is None


def test_a_poll_with_no_readings_at_all_changes_nothing():
    decision = decided(state(minute="88"), {"filgoal": ABSENT, "yallakora": ABSENT})

    assert decision.write_status is False


def test_halftime_shows_no_minute():
    sides = {"filgoal": side("filgoal", Score(0, 0), status="halftime", period=None, minute=None)}

    assert decided(state(minute="45+3"), sides).minute is None


@pytest.mark.parametrize(
    ("peak", "reading", "expected"),
    [
        (None, {"status": "live", "period": "1H", "minute": "23"}, Peak(23, "1H")),
        (Peak(23, "1H"), {"status": "live", "period": "1H", "minute": "24"}, Peak(24, "1H")),
        (Peak(90, "2H"), {"status": "live", "period": "2H", "minute": "90+3"}, Peak(93, "2H")),
        (Peak(104, "2H"), {"status": "live", "period": "2H", "minute": "46"}, Peak(104, "2H")),
        (Peak(53, "1H"), {"status": "live", "period": "2H", "minute": "47"}, Peak(53, "1H")),
        (Peak(53, "1H"), {"status": "live", "period": "2H", "minute": "54"}, Peak(54, "2H")),
        (Peak(53, "1H"), {"status": "halftime", "period": None, "minute": "60"}, Peak(53, "1H")),
        (Peak(90, "2H"), {"status": "extra_time", "period": "ET1", "minute": "95"}, Peak(95, "ET1")),
        (Peak(53, "1H"), {"status": "live", "period": "1H", "minute": None}, Peak(53, "1H")),
        (None, {"status": "halftime", "period": None, "minute": None}, None),
    ],
)
def test_next_peak(peak, reading, expected):
    assert next_peak(peak, side("filgoal", Score(0, 0), **reading).reading) == expected


def test_an_unknown_row_leaves_the_peak_alone():
    assert next_peak(Peak(53, "1H"), side("filgoal", Score(0, 0), unknown="شوط إضافي").reading) == Peak(53, "1H")


# -------------------------------------------------------------------------------------------- full time

FT = {"status": "finished", "period": None, "minute": None}
SECOND_HALF = {"status": "live", "period": "2H", "minute": "90"}
EXTRA = {"status": "extra_time", "period": "ET1", "minute": "95"}
PENALTIES = {"status": "penalties", "period": None, "minute": None}


def second_half(score: Score = Score(1, 0), **changes) -> LiveState:
    return state(score, status="live", period="2H", minute="90", **changes)


@pytest.mark.parametrize("pair", [("filgoal", "goal"), ("filgoal", "yallakora"), ("goal", "yallakora")])
def test_two_sources_showing_full_time_finish_at_once(pair):
    decision = decided(second_half(), {name: side(name, Score(1, 0), **FT) for name in pair})

    assert (decision.status, decision.period, decision.minute) == ("finished", None, None)
    assert decision.status_label == f"{pair[0]}-label"
    assert decision.fulltime_since is None


@pytest.mark.parametrize("stuck", [EXTRA, PENALTIES], ids=["extra time", "penalties"])
def test_two_full_times_finish_even_if_a_third_shows_extra_time(stuck):
    sides = {
        "filgoal": side("filgoal", Score(1, 0), **FT),
        "goal": side("goal", Score(1, 0), **FT),
        "yallakora": side("yallakora", Score(1, 0), **stuck),
    }

    assert decided(second_half(), sides).status == "finished"


@pytest.mark.parametrize("source", SOURCES)
def test_one_source_alone_starts_a_ten_minute_hold(source):
    decision = decided(second_half(), {source: side(source, Score(1, 0), **FT)})

    assert (decision.status, decision.period) == ("live", "2H")
    assert (decision.fulltime_source, decision.fulltime_since) == (source, NOW)


@pytest.mark.parametrize("source", SOURCES)
def test_one_source_alone_finishes_at_ten_minutes(source):
    held = NOW - FULLTIME_HOLD + timedelta(seconds=1)
    reading = {source: side(source, Score(1, 0), **FT)}

    waiting = decided(second_half(fulltime_source=source, fulltime_since=held), reading)
    assert waiting.status == "live"
    assert (waiting.fulltime_source, waiting.fulltime_since) == (source, held)

    done = decided(second_half(fulltime_source=source, fulltime_since=NOW - FULLTIME_HOLD), reading)
    assert done.status == "finished"


def test_the_only_source_covering_a_match_still_waits_the_ten_minutes():
    sides = {"filgoal": side("filgoal", Score(1, 0), **FT), "goal": ABSENT, "yallakora": ABSENT}

    assert decided(second_half(), sides).status == "live"


@pytest.mark.parametrize(
    "reading",
    [
        pytest.param(side("filgoal", Score(1, 0), **SECOND_HALF), id="second half"),
        pytest.param(side("filgoal", Score(1, 0), unknown="وقت إضافي"), id="unknown"),
    ],
)
def test_the_source_reading_anything_else_restarts_the_ten_minutes(reading):
    before = second_half(fulltime_source="filgoal", fulltime_since=NOW - timedelta(minutes=9), finish_wait_since=NOW)

    decision = decided(before, {"filgoal": reading})

    assert decision.status == "live"
    assert (decision.fulltime_source, decision.fulltime_since, decision.finish_wait_since) == (None, None, None)


def test_a_poll_with_no_reading_from_it_doesnt_restart_the_ten_minutes():
    held = NOW - timedelta(minutes=9)
    before = second_half(fulltime_source="filgoal", fulltime_since=held)

    decision = decided(before, {"filgoal": ABSENT, "yallakora": side("yallakora", Score(1, 0), **SECOND_HALF)})

    assert (decision.fulltime_source, decision.fulltime_since) == ("filgoal", held)


def test_a_hold_past_its_time_needs_a_reading_to_finish():
    held = NOW - timedelta(minutes=30)

    decision = decided(second_half(fulltime_source="filgoal", fulltime_since=held), {"filgoal": ABSENT})

    assert decision.write_status is False
    assert decision.fulltime_since == held


def test_another_source_taking_over_a_lone_full_time_starts_again():
    before = second_half(fulltime_source="filgoal", fulltime_since=NOW - timedelta(minutes=9))

    decision = decided(before, {"filgoal": ABSENT, "yallakora": side("yallakora", Score(1, 0), **FT)})

    assert decision.status == "live"
    assert (decision.fulltime_source, decision.fulltime_since) == ("yallakora", NOW)


@pytest.mark.parametrize("later", [EXTRA, PENALTIES], ids=["extra time", "penalties"])
def test_extra_time_stops_a_lone_full_time_and_clears_the_hold(later):
    before = second_half(fulltime_source="filgoal", fulltime_since=NOW - FULLTIME_HOLD, finish_wait_since=NOW)
    sides = {"filgoal": side("filgoal", Score(1, 0), **FT), "yallakora": side("yallakora", Score(1, 0), **later)}

    decision = decided(before, sides)

    assert decision.status == later["status"]
    assert (decision.fulltime_source, decision.fulltime_since, decision.finish_wait_since) == (None, None, None)


def test_a_status_no_parser_knows_stops_another_sources_lone_full_time():
    # FilGoal on full time at 1-1 while Goal.com has moved on to a stage no map holds (B1-R2-1): it may be extra time.
    before = second_half(fulltime_source="filgoal", fulltime_since=NOW - FULLTIME_HOLD, finish_wait_since=NOW)
    sides = {
        "filgoal": side("filgoal", Score(1, 1), **FT),
        "goal": side("goal", Score(1, 1), unknown="LIVE/EXTRA_TIME_FIRST_HALF"),
    }

    decision = decided(before, sides)

    assert decision.status == "live"
    assert (decision.fulltime_source, decision.fulltime_since, decision.finish_wait_since) == (None, None, None)


def test_a_status_no_parser_knows_keeps_a_lone_full_time_from_starting():
    sides = {
        "filgoal": side("filgoal", Score(1, 1), **FT),
        "goal": side("goal", Score(1, 1), unknown="LIVE/EXTRA_TIME_FIRST_HALF"),
    }

    decision = decided(second_half(), sides)

    assert decision.status == "live"
    assert (decision.fulltime_source, decision.fulltime_since) == (None, None)


def test_a_status_no_parser_knows_restarts_the_wait_when_the_held_source_has_no_reading():
    before = second_half(fulltime_source="filgoal", fulltime_since=NOW - timedelta(minutes=9))
    sides = {"filgoal": ABSENT, "goal": side("goal", Score(1, 1), unknown="LIVE/EXTRA_TIME_FIRST_HALF")}

    decision = decided(before, sides)

    assert (decision.fulltime_source, decision.fulltime_since) == (None, None)


def test_two_full_times_finish_even_if_a_third_shows_a_status_no_parser_knows():
    sides = {
        "filgoal": side("filgoal", Score(1, 1), **FT),
        "yallakora": side("yallakora", Score(1, 1), **FT),
        "goal": side("goal", Score(1, 1), unknown="LIVE/EXTRA_TIME_FIRST_HALF"),
    }

    assert decided(second_half(), sides).status == "finished"


def test_a_lone_full_time_blocks_a_backward_move():
    before = second_half(status_drop_since=NOW - DROP_HOLD)
    sides = {
        "filgoal": side("filgoal", Score(1, 0), **FT),
        "yallakora": side("yallakora", Score(1, 0), status="live", period="1H", minute=None),
    }

    decision = decided(before, sides)

    assert (decision.status, decision.period, decision.status_drop_since) == ("live", "2H", None)


def test_full_time_waits_while_a_drop_is_open():
    sides = {name: side(name, Score(1, 0), **FT) for name in ("filgoal", "yallakora")}

    decision = decided(second_half(Score(2, 0)), sides)

    assert decision.status == "live"
    assert decision.finish_wait_since == NOW
    assert decision.drop_since == NOW


def test_full_time_waits_while_scores_differ():
    sides = {
        "filgoal": side("filgoal", Score(1, 0), **FT),
        "yallakora": side("yallakora", Score(0, 0), **FT),
    }

    decision = decided(second_half(), sides)

    assert decision.status == "live"
    assert decision.finish_wait_since == NOW


def test_a_full_time_wait_ends_when_they_agree():
    sides = {name: side(name, Score(1, 0), **FT) for name in ("filgoal", "yallakora")}

    decision = decided(second_half(finish_wait_since=NOW - timedelta(minutes=1)), sides)

    assert decision.status == "finished"
    assert decision.finish_wait_since is None
    assert DISAGREE not in decision.open_problems


def test_a_full_time_wait_finishes_on_the_accepted_score_with_an_alert_at_five_minutes():
    sides = {
        "filgoal": side("filgoal", Score(1, 0), **FT),
        "yallakora": side("yallakora", Score(0, 0), **FT),
    }

    decision = decided(second_half(finish_wait_since=NOW - DROP_HOLD), sides)

    assert decision.status == "finished"
    assert decision.confirm is None  # 1–0 stays
    assert DISAGREE in decision.open_problems


def test_a_finish_while_a_drop_reaches_its_limit_takes_the_lower_score():
    sides = {name: side(name, Score(1, 0), **FT) for name in ("filgoal", "yallakora")}

    decision = decided(second_half(Score(2, 0), drop_since=NOW - DROP_HOLD, finish_wait_since=NOW - DROP_HOLD), sides)

    assert decision.status == "finished"
    assert decision.confirm == Score(1, 0)


def test_a_new_score_and_full_time_in_one_poll_finish_on_the_new_score():
    sides = {name: side(name, Score(2, 0), **FT) for name in ("filgoal", "yallakora")}

    decision = decided(second_half(Score(1, 0)), sides)

    assert decision.status == "finished"
    assert decision.confirm == Score(2, 0)


# ---------------------------------------------------------------------------------------- unknown status


@pytest.mark.parametrize("source", SOURCES)
def test_a_higher_score_on_an_unknown_row_is_accepted(source):
    decision = decided(state(Score(1, 0)), {source: side(source, Score(2, 0), unknown="شوط إضافي")})

    assert decision.confirm == Score(2, 0)
    assert decision.score_first_source == source


def test_an_equal_score_on_an_unknown_row_stops_a_drop():
    before = state(Score(1, 0), drop_since=NOW - timedelta(minutes=4))

    decision = decided(before, {"filgoal": side("filgoal", Score(1, 0), unknown="شوط إضافي")})

    assert (decision.confirm, decision.drop_since) == (None, None)


def test_a_lower_score_on_an_unknown_row_is_ignored():
    before = state(Score(2, 0))

    decision = decided(before, {"filgoal": side("filgoal", Score(1, 0), unknown="شوط إضافي")})

    assert (decision.confirm, decision.drop_since) == (None, None)


def test_a_lower_score_on_an_unknown_row_leaves_an_open_drop_as_it_was():
    started = NOW - timedelta(minutes=9)
    sides = {"filgoal": side("filgoal", Score(1, 0), unknown="شوط إضافي")}

    decision = decided(state(Score(2, 0), drop_since=started), sides)

    assert (decision.confirm, decision.drop_since) == (None, started)


def test_a_lower_score_on_an_unknown_row_is_no_disagreement():
    sides = {
        "filgoal": side("filgoal", Score(1, 0), unknown="شوط إضافي"),
        "yallakora": side("yallakora", Score(2, 0)),
    }

    assert decided(state(Score(2, 0)), sides).disagreement_since is None


def test_an_unknown_rows_status_and_minute_change_nothing():
    before = state(Score(1, 0), status="live", period="2H", minute="88", status_label="الشوط الثاني")

    decision = decided(before, {"filgoal": side("filgoal", Score(1, 0), unknown="شوط إضافي")})

    assert (decision.status, decision.period, decision.status_label) == ("live", "2H", "الشوط الثاني")
    assert decision.minute is None


def test_a_nil_score_on_an_unknown_row_isnt_a_first_score():
    decision = decided(state(None), {"filgoal": side("filgoal", Score(0, 0), unknown="شوط إضافي")})

    assert decision.confirm is None


def test_any_other_score_on_an_unknown_row_is_a_first_score():
    decision = decided(state(None), {"filgoal": side("filgoal", Score(1, 0), unknown="شوط إضافي")})

    assert decision.confirm == Score(1, 0)


# ------------------------------------------------------------------------------------- sources going away


@pytest.mark.parametrize("working", SOURCES)
def test_with_some_sources_down_the_others_carry_on_under_the_same_rules(working):
    sides = {name: DOWN for name in others(working)}
    sides[working] = side(working, Score(1, 0))

    decision = decided(state(Score(0, 0)), sides)

    assert decision.fallback is False
    assert decision.confirm == Score(1, 0)


@pytest.mark.parametrize(
    "sides",
    [{"filgoal": DOWN, "yallakora": DOWN}, {"filgoal": DOWN, "goal": DOWN, "yallakora": DOWN}, {"filgoal": DOWN}],
    ids=["two", "three", "one"],
)
def test_all_enabled_sources_down_goes_to_the_clock(sides):
    decision = decided(state(Score(1, 0)), sides)

    assert decision.fallback is True
    assert BOTH_DOWN in decision.open_problems
    assert decision.write_status is False


def test_a_source_that_doesnt_cover_a_match_stops_the_fallback():
    decision = decided(state(Score(1, 0)), {"filgoal": DOWN, "yallakora": ABSENT})

    assert decision.fallback is False
    assert decision.write_status is False


def test_a_disabled_source_has_no_effect():
    reading = side("filgoal", Score(1, 0))

    with_goal_absent = decided(state(Score(0, 0)), {"filgoal": reading, "goal": ABSENT, "yallakora": ABSENT})
    without_goal = decided(state(Score(0, 0)), {"filgoal": reading, "yallakora": ABSENT})

    assert with_goal_absent == without_goal


def test_a_poll_with_a_reading_closes_both_down():
    assert BOTH_DOWN in decided(state(), {"filgoal": side("filgoal", Score(0, 0))}).close_problems


def test_a_poll_nobody_could_read_keeps_the_memory():
    before = state(
        Score(2, 1),
        drop_since=NOW - timedelta(minutes=1),
        status_drop_since=NOW - timedelta(minutes=2),
        score_first_source="goal",
        score_changed_at=NOW - timedelta(minutes=3),
        fulltime_source="yallakora",
        fulltime_since=NOW - timedelta(minutes=4),
        finish_wait_since=NOW - timedelta(minutes=5),
        disagreement_since=NOW - timedelta(minutes=6),
    )

    decision = decided(before, {"filgoal": ABSENT, "yallakora": ABSENT})

    assert decision.drop_since == before.drop_since
    assert decision.status_drop_since == before.status_drop_since
    assert decision.score_first_source == "goal"
    assert decision.score_changed_at == before.score_changed_at
    assert decision.fulltime_source == "yallakora"
    assert decision.fulltime_since == before.fulltime_since
    assert decision.finish_wait_since == before.finish_wait_since
    assert decision.disagreement_since == before.disagreement_since
