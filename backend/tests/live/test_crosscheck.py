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


def _final_other(order: str, score: Score | None) -> SideInput:
    return other(order, score, status="finished", period=None, minute=None)


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

    second = decide(
        replace(current, previous_status=("live", "2H"), previous_primary="filgoal"),
        back,
        SideInput.not_covering(),
        NOW,
        wait=WAIT,
    )
    assert second.write_status is True
    assert second.status == "live"


def test_a_different_earlier_poll_does_not_count_for_a_backward_status():
    current = state(status="halftime", period=None, previous_status=("live", "2H"), previous_primary="filgoal")

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


def _final(source: str, score: Score | None, status: str = "finished") -> SideInput:
    return reading(source, score, status=status, period=None, minute=None)


@pytest.mark.parametrize("final", ["finished", "cancelled", "abandoned"])
def test_a_final_status_is_never_written_when_the_wait_ends_without_agreement(final):
    current = state(Score(1, 1), candidate=Candidate(Score(2, 1), "filgoal", NOW - WAIT, 4))

    decision = decide(
        current, _final("filgoal", Score(2, 1), final), _final("yallakora", Score(1, 1), final), NOW, wait=WAIT
    )

    assert decision.write_status is False
    assert decision.confirm is None
    assert decision.open_problems == (DISAGREE,)
    assert decision.candidate.score == Score(2, 1)
    assert decision.disagreement_since == NOW


def test_a_final_status_stays_held_for_as_long_as_the_disagreement_is_open():
    since = NOW - timedelta(minutes=20)
    current = state(Score(1, 1), candidate=Candidate(Score(2, 1), "filgoal", NOW - WAIT, 25), disagreement_since=since)

    decision = decide(current, _final("filgoal", Score(2, 1)), _final("yallakora", Score(1, 1)), NOW, wait=WAIT)

    assert decision.write_status is False
    assert decision.disagreement_since == since
    assert decision.hold_goal_events is True


def test_the_final_status_goes_out_with_the_score_once_the_sources_agree():
    current = state(
        Score(1, 1),
        candidate=Candidate(Score(2, 1), "filgoal", NOW - WAIT, 25),
        disagreement_since=NOW - timedelta(minutes=20),
    )

    decision = decide(current, _final("filgoal", Score(2, 1)), _final("yallakora", Score(2, 1)), NOW, wait=WAIT)

    assert (decision.write_status, decision.status, decision.confirm) == (True, "finished", Score(2, 1))
    assert decision.disagreement_since is None
    assert DISAGREE in decision.close_problems


def test_status_and_minute_keep_moving_during_a_disagreement():
    current = state(
        Score(1, 1),
        candidate=Candidate(Score(2, 1), "filgoal", NOW - WAIT, 25),
        disagreement_since=NOW - timedelta(minutes=20),
    )

    decision = decide(
        current,
        reading("filgoal", Score(2, 1), status="live", period="2H", minute="90+1"),
        reading("yallakora", Score(1, 1), status="live", period="2H"),
        NOW,
        wait=WAIT,
    )

    assert (decision.write_status, decision.minute, decision.confirm) == (True, "90+1", None)


@pytest.mark.parametrize("gone", [SideInput.unavailable(), SideInput.not_covering()], ids=["down", "not_covering"])
def test_a_disagreement_ends_only_on_agreement_not_when_the_other_source_goes_quiet(gone):
    """One failed request of the lagging source must not turn the disputed score into the final one."""
    current = state(
        Score(1, 1),
        candidate=Candidate(Score(2, 1), "filgoal", NOW - WAIT, 25),
        disagreement_since=NOW - timedelta(minutes=20),
    )

    decision = decide(current, _final("filgoal", Score(2, 1)), gone, NOW, wait=WAIT)

    assert decision.confirm is None
    assert decision.write_status is False
    assert decision.candidate.score == Score(2, 1)
    assert decision.disagreement_since == current.disagreement_since
    assert DISAGREE not in decision.close_problems


@pytest.mark.parametrize("disagreement_since", [None, NOW - timedelta(minutes=20)], ids=["pending", "disagreement"])
def test_the_lagging_source_alone_cannot_publish_the_old_score_as_final(disagreement_since):
    """FilGoal's one timeout makes YallaKora primary, and its 1–1 equals the confirmed score."""
    current = state(
        Score(1, 1), candidate=Candidate(Score(2, 1), "filgoal", NOW - WAIT, 2), disagreement_since=disagreement_since
    )

    decision = decide(current, SideInput.not_covering(), _final("yallakora", Score(1, 1)), NOW, wait=WAIT)

    assert decision.write_status is False
    assert decision.candidate == current.candidate
    assert decision.disagreement_since == disagreement_since
    assert DISAGREE not in decision.close_problems
    assert decision.hold_goal_events is True


def test_the_source_that_held_the_new_score_can_take_it_back_alone():
    current = state(
        Score(1, 1),
        candidate=Candidate(Score(2, 1), "filgoal", NOW - WAIT, 25),
        disagreement_since=NOW - timedelta(minutes=20),
    )

    decision = decide(current, _final("filgoal", Score(1, 1)), SideInput.not_covering(), NOW, wait=WAIT)

    assert (decision.write_status, decision.status) == (True, "finished")
    assert decision.candidate is None
    assert DISAGREE in decision.close_problems


def test_penalties_one_source_carries_need_two_polls_and_never_become_a_disagreement(order):
    current = state(Score(1, 1), status="penalties", period=None)
    with_pens = Score(1, 1, 4, 3)

    first = run(current, order, _final(order, with_pens), _final_other(order, Score(1, 1)))
    assert first.confirm is None
    assert first.candidate == Candidate(with_pens, order, NOW, 1)
    assert first.open_problems == ()
    assert first.write_status is False  # the final state waits for its penalties

    later = NOW + WAIT + timedelta(seconds=1)
    second = run(
        replace(current, candidate=first.candidate),
        order,
        _final(order, with_pens),
        _final_other(order, Score(1, 1)),
        now=later,
    )
    assert second.confirm == with_pens
    assert second.candidate is None
    assert second.open_problems == ()
    assert (second.write_status, second.status) == (True, "finished")
    assert DISAGREE in second.close_problems


def test_goals_both_show_go_out_at_once_while_the_penalties_wait(order):
    current = state(Score(1, 0), status="live", period="2H")
    with_pens = Score(1, 1, 4, 3)

    decision = run(current, order, side(order, with_pens), other(order, Score(1, 1)))

    assert decision.confirm == Score(1, 1)
    assert decision.candidate == Candidate(with_pens, order, NOW, 1)
    assert decision.hold_goal_events is True


def test_a_source_without_penalties_never_erases_confirmed_ones(order):
    current = state(Score(1, 1, 4, 3), status="penalties", period=None)

    both = run(current, order, side(order, Score(1, 1)), other(order, Score(1, 1)))
    assert both.confirm is None
    assert both.candidate is None

    alone = run(current, order, side(order, Score(1, 1)), SideInput.not_covering())
    assert alone.confirm is None
    assert alone.candidate is None

    carried = run(current, order, side(order, Score(1, 1, 4, 3)), other(order, Score(1, 1)))
    assert carried.confirm is None
    assert carried.candidate is None
    assert carried.hold_goal_events is False


def test_a_candidate_is_measured_against_goals_when_the_confirmed_score_has_penalties(order):
    current = state(Score(1, 1, 4, 3), status="penalties", period=None)

    decision = run(current, order, side(order, Score(1, 1)), other(order, Score(2, 1)))

    assert decision.confirm is None
    assert decision.candidate.score == Score(2, 1)
    assert decision.candidate.source == ("yallakora" if order == "filgoal" else "filgoal")


def test_penalties_both_sources_carry_are_still_compared(order):
    current = state(Score(1, 1), status="penalties", period=None)

    decision = run(
        current,
        order,
        side(order, Score(1, 1, 4, 3)),
        other(order, Score(1, 1, 5, 3)),
        now=NOW,
    )
    assert decision.confirm is None
    assert decision.candidate.polls == 1

    waited = run(
        replace(current, candidate=decision.candidate),
        order,
        side(order, Score(1, 1, 4, 3)),
        other(order, Score(1, 1, 5, 3)),
        now=NOW + WAIT,
    )
    assert waited.open_problems == (DISAGREE,)


def test_one_source_alone_needs_two_polls_for_penalties_too(order):
    current = state(Score(1, 1), status="penalties", period=None)
    with_pens = Score(1, 1, 4, 3)

    first = run(current, order, side(order, with_pens), SideInput.not_covering())
    assert first.confirm is None
    assert first.candidate == Candidate(with_pens, order, NOW, 1)

    second = run(replace(current, candidate=first.candidate), order, side(order, with_pens), SideInput.not_covering())
    assert second.confirm == with_pens


def test_a_source_that_just_took_over_cannot_move_the_status_backwards():
    """FilGoal was primary and said live; its one failed request must not publish YallaKora's lag."""
    current = state(previous_status=("live", "1H"), previous_primary="filgoal")

    decision = decide(
        current,
        SideInput.not_covering(),
        reading("yallakora", Score(0, 0), status="scheduled", period=None),
        NOW,
        wait=WAIT,
    )

    assert decision.write_status is False


def test_a_backward_status_counts_only_the_polls_where_that_source_was_primary():
    back = reading("yallakora", Score(0, 0), status="scheduled", period=None)

    # YallaKora said it before too, but FilGoal was the primary then: this is its first poll as primary.
    took_over = decide(
        state(previous_status=("scheduled", None), previous_primary="filgoal"),
        SideInput.not_covering(),
        back,
        NOW,
        wait=WAIT,
    )
    assert took_over.write_status is False

    # The second poll in a row as primary.
    second = decide(
        state(previous_status=("scheduled", None), previous_primary="yallakora"),
        SideInput.not_covering(),
        back,
        NOW,
        wait=WAIT,
    )
    assert (second.write_status, second.status) == (True, "scheduled")


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


def test_a_poll_without_the_page_keeps_the_pending_penalties_and_the_final_waits(order):
    """A failed page fetch leaves list rows with no penalties: they must not end the wait for them."""
    with_pens = Score(1, 1, 4, 3)
    current = state(
        Score(1, 1), status="penalties", period=None, candidate=Candidate(with_pens, order, NOW, 1)
    )

    both_lists = run(current, order, _final(order, Score(1, 1)), _final_other(order, Score(1, 1)))
    assert both_lists.candidate == current.candidate
    assert both_lists.confirm is None
    assert both_lists.write_status is False

    one_list = run(current, order, _final(order, Score(1, 1)), SideInput.not_covering())
    assert one_list.candidate == current.candidate
    assert one_list.write_status is False

    page_back = run(current, order, _final(order, with_pens), _final_other(order, Score(1, 1)))
    assert page_back.confirm == with_pens
    assert page_back.write_status is True
