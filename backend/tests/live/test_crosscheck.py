"""Every row of SD §6.7's table, in both source orders where they differ (T024)."""

from __future__ import annotations

from dataclasses import replace
from datetime import UTC, datetime, timedelta

import pytest

from app.live.crosscheck import BOTH_DOWN, decide
from app.live.types import Candidate, LiveState, Score, SideInput, SourceReading

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
WAIT = timedelta(seconds=180)
DISAGREE = "disagree:7"


def reading(source: str, score: Score | None = None, *, status="live", period="1H", minute="23") -> SideInput:
    return SideInput.valid(
        SourceReading(
            source=source,
            external_id="1",
            home="أ",
            away="ب",
            competition=None,
            kickoff_at=None,
            status=status,
            period=period,
            minute=minute,
            score=score,
            status_label=f"{source}-label",
        )
    )


def state(confirmed: Score | None = Score(0, 0), **changes) -> LiveState:
    return replace(LiveState(match_id=7, status="live", period="1H", confirmed=confirmed), **changes)


def sides(first: SideInput, second: SideInput, order: str) -> tuple[SideInput, SideInput]:
    """``first`` plays FilGoal or YallaKora, so a rule is tested from both sides."""
    return (first, second) if order == "filgoal" else (second, first)


@pytest.fixture(params=["filgoal", "yallakora"])
def order(request) -> str:
    return request.param


def side(order: str, score: Score | None = None, **kwargs) -> SideInput:
    return reading(order, score, **kwargs)


def other(order: str, score: Score | None = None, **kwargs) -> SideInput:
    return reading("yallakora" if order == "filgoal" else "filgoal", score, **kwargs)


def run(current: LiveState, order: str, first: SideInput, second: SideInput, now=NOW):
    filgoal, yallakora = sides(first, second, order)
    return decide(current, filgoal, yallakora, now, wait=WAIT)


def test_both_agree_on_a_new_score_confirms_it(order):
    decision = run(state(), order, side(order, Score(1, 0)), other(order, Score(1, 0)))

    assert decision.confirm == Score(1, 0)
    assert decision.candidate is None
    assert decision.hold_goal_events is False
    assert DISAGREE in decision.close_problems


def test_one_updated_waits_and_holds_the_goal(order):
    decision = run(state(), order, side(order, Score(1, 0)), other(order, Score(0, 0)))

    assert decision.confirm is None
    assert decision.candidate == Candidate(Score(1, 0), order, NOW, 1)
    assert decision.hold_goal_events is True
    assert decision.open_problems == ()


def test_then_the_other_updates_and_it_confirms(order):
    pending = state(candidate=Candidate(Score(1, 0), order, NOW - timedelta(seconds=60), 1))

    decision = run(pending, order, side(order, Score(1, 0)), other(order, Score(1, 0)))

    assert decision.confirm == Score(1, 0)
    assert decision.candidate is None


def test_a_source_going_back_to_the_confirmed_score_drops_the_candidate(order):
    pending = state(candidate=Candidate(Score(1, 0), order, NOW - timedelta(seconds=60), 1))

    decision = run(pending, order, side(order, Score(0, 0)), other(order, Score(0, 0)))

    assert decision.confirm is None
    assert decision.candidate is None
    assert decision.hold_goal_events is False


def test_the_wait_ending_opens_a_disagreement_and_keeps_the_confirmed_score(order):
    pending = state(candidate=Candidate(Score(1, 0), order, NOW - WAIT, 3))

    decision = run(pending, order, side(order, Score(1, 0)), other(order, Score(0, 0)))

    assert decision.confirm is None
    assert decision.open_problems == (DISAGREE,)
    assert decision.disagreement_since == NOW
    assert decision.candidate.first_seen_at == NOW - WAIT
    assert decision.hold_goal_events is True


def test_agreement_after_a_disagreement_closes_it(order):
    pending = state(
        candidate=Candidate(Score(1, 0), order, NOW - WAIT, 3),
        disagreement_since=NOW - timedelta(seconds=30),
    )

    decision = run(pending, order, side(order, Score(1, 0)), other(order, Score(1, 0)))

    assert decision.confirm == Score(1, 0)
    assert decision.disagreement_since is None
    assert DISAGREE in decision.close_problems


def test_a_different_new_score_restarts_the_wait_but_a_disagreement_stays_open(order):
    since = NOW - timedelta(seconds=30)
    pending = state(candidate=Candidate(Score(1, 0), order, NOW - WAIT, 3), disagreement_since=since)

    decision = run(pending, order, side(order, Score(2, 0)), other(order, Score(0, 0)))

    assert decision.candidate == Candidate(Score(2, 0), order, NOW, 1)
    assert decision.disagreement_since == since


@pytest.mark.parametrize("gone", [SideInput.unavailable(), SideInput.not_covering()], ids=["down", "not_covering"])
def test_one_source_needs_the_new_score_in_two_polls_in_a_row(order, gone):
    first = run(state(), order, side(order, Score(1, 0)), gone)
    assert first.confirm is None
    assert first.candidate.polls == 1
    assert first.hold_goal_events is True

    second = run(state(candidate=first.candidate), order, side(order, Score(1, 0)), gone)
    assert second.confirm == Score(1, 0)
    assert second.candidate is None
    assert second.hold_goal_events is False


def test_one_source_changing_its_mind_starts_again(order):
    pending = state(candidate=Candidate(Score(1, 0), order, NOW, 1))

    decision = run(pending, order, side(order, Score(0, 1)), SideInput.unavailable())

    assert decision.confirm is None
    assert decision.candidate == Candidate(Score(0, 1), order, NOW, 1)


def test_both_down_falls_back_to_the_clock():
    decision = decide(state(), SideInput.unavailable(), SideInput.unavailable(), NOW, wait=WAIT)

    assert decision.fallback is True
    assert decision.write_status is False
    assert decision.confirm is None
    assert decision.open_problems == (BOTH_DOWN,)


def test_recovery_goes_through_the_normal_rules(order):
    after_fallback = state(status="scheduled", period=None)

    same = run(after_fallback, order, side(order, Score(0, 0)), SideInput.unavailable())
    assert same.fallback is False
    assert same.write_status is True
    assert same.confirm is None  # still the confirmed score; apply writes it back
    assert BOTH_DOWN in same.close_problems

    new = run(after_fallback, order, side(order, Score(1, 0)), SideInput.unavailable())
    assert new.confirm is None
    assert new.candidate.polls == 1


def test_nobody_has_the_match_changes_nothing():
    pending = state(candidate=Candidate(Score(1, 0), "filgoal", NOW, 1))

    for pair in [
        (SideInput.not_covering(), SideInput.not_covering()),
        (SideInput.unavailable(), SideInput.not_covering()),
        (SideInput.not_covering(), SideInput.unavailable()),
    ]:
        decision = decide(pending, *pair, NOW, wait=WAIT)
        assert decision.fallback is False
        assert decision.write_status is False
        assert decision.candidate == pending.candidate
        assert decision.hold_goal_events is True


def test_a_score_going_down_follows_the_same_rules(order):
    current = state(Score(2, 0))

    waiting = run(current, order, side(order, Score(1, 0)), other(order, Score(2, 0)))
    assert waiting.confirm is None
    assert waiting.candidate.score == Score(1, 0)

    agreed = run(current, order, side(order, Score(1, 0)), other(order, Score(1, 0)))
    assert agreed.confirm == Score(1, 0)


def test_penalties_are_part_of_the_score(order):
    current = state(Score(1, 1), status="penalties", period=None)
    with_pens = Score(1, 1, 3, 2)

    differs = run(
        current,
        order,
        side(order, with_pens, status="penalties", period=None),
        other(order, Score(1, 1), status="penalties", period=None),
    )
    assert differs.confirm is None
    assert differs.candidate.score == with_pens

    same = run(
        current,
        order,
        side(order, with_pens, status="penalties", period=None),
        other(order, with_pens, status="penalties", period=None),
    )
    assert same.confirm == with_pens


def test_a_first_nil_score_is_the_baseline_not_news(order):
    current = state(None, status="scheduled", period=None)

    alone = run(current, order, side(order, Score(0, 0)), other(order, None, status="scheduled", period=None))
    assert alone.confirm == Score(0, 0)
    assert alone.candidate is None

    single = run(current, order, side(order, Score(0, 0)), SideInput.unavailable())
    assert single.confirm == Score(0, 0)


def test_a_first_goal_from_one_source_still_waits(order):
    current = state(None, status="scheduled", period=None)

    decision = run(current, order, side(order, Score(1, 0)), other(order, None, status="scheduled", period=None))

    assert decision.confirm is None
    assert decision.candidate.score == Score(1, 0)


def test_both_without_a_score_changes_no_score(order):
    current = state(None, status="scheduled", period=None)

    decision = run(
        current,
        order,
        side(order, None, status="scheduled", period=None),
        other(order, None, status="scheduled", period=None),
    )

    assert decision.confirm is None
    assert decision.candidate is None


def test_status_and_minute_come_from_filgoal_when_usable():
    decision = decide(
        state(),
        reading("filgoal", Score(0, 0), status="halftime", period=None, minute=None),
        reading("yallakora", Score(0, 0), status="live", period="1H", minute="44"),
        NOW,
        wait=WAIT,
    )

    assert decision.write_status is True
    assert (decision.status, decision.period, decision.minute) == ("halftime", None, None)
    assert decision.status_reading.source == "filgoal"
    assert decision.status_label == "filgoal-label"


@pytest.mark.parametrize("filgoal", [SideInput.unavailable(), SideInput.not_covering()], ids=["down", "not_covering"])
def test_status_and_minute_come_from_yallakora_when_filgoal_is_unusable(filgoal):
    decision = decide(state(), filgoal, reading("yallakora", Score(0, 0), minute="44"), NOW, wait=WAIT)

    assert decision.write_status is True
    assert decision.minute == "44"
    assert decision.status_reading.source == "yallakora"


def test_a_status_alone_needs_no_second_source():
    decision = decide(
        state(),
        reading("filgoal", Score(0, 0), status="live", period="2H", minute="46"),
        reading("yallakora", Score(0, 0), status="halftime", period=None),
        NOW,
        wait=WAIT,
    )

    assert (decision.status, decision.period) == ("live", "2H")


def test_a_backward_status_needs_two_polls_in_a_row():
    current = state(status="finished", period=None)
    back = reading("filgoal", Score(0, 0), status="live", period="2H")

    first = decide(current, back, SideInput.not_covering(), NOW, wait=WAIT)
    assert first.write_status is False

    second = decide(replace(current, previous_status=("live", "2H")), back, SideInput.not_covering(), NOW, wait=WAIT)
    assert second.write_status is True
    assert second.status == "live"


def test_a_different_earlier_poll_does_not_count_for_a_backward_status():
    current = state(status="halftime", period=None, previous_status=("live", "2H"))

    decision = decide(
        current, reading("filgoal", Score(0, 0), status="live", period="1H"), SideInput.not_covering(), NOW, wait=WAIT
    )

    assert decision.write_status is False


def test_a_final_status_waits_for_a_pending_score():
    current = state(candidate=Candidate(Score(1, 0), "filgoal", NOW, 1))

    decision = decide(
        current,
        reading("filgoal", Score(1, 0), status="finished", period=None, minute=None),
        reading("yallakora", Score(0, 0), status="finished", period=None, minute=None),
        NOW,
        wait=WAIT,
    )

    assert decision.write_status is False
    assert decision.candidate is not None


def test_a_final_status_is_written_once_the_score_is_a_disagreement():
    current = state(candidate=Candidate(Score(1, 0), "filgoal", NOW - WAIT, 4))

    decision = decide(
        current,
        reading("filgoal", Score(1, 0), status="finished", period=None, minute=None),
        reading("yallakora", Score(0, 0), status="finished", period=None, minute=None),
        NOW,
        wait=WAIT,
    )

    assert decision.write_status is True
    assert decision.status == "finished"
    assert decision.confirm is None
    assert decision.open_problems == (DISAGREE,)


@pytest.mark.parametrize("status", ["postponed", "cancelled", "abandoned"])
def test_a_match_that_will_not_be_played_is_a_status_like_any_other(status):
    current = state(None, status="scheduled", period=None)

    decision = decide(
        current,
        reading("filgoal", None, status=status, period=None, minute=None),
        SideInput.not_covering(),
        NOW,
        wait=WAIT,
    )

    assert decision.write_status is True
    assert decision.status == status
