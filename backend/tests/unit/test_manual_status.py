"""The manual-status validation table of data-model.md, one case per cell (T020, FR-011)."""

from __future__ import annotations

from dataclasses import dataclass

import pytest

from app.domain.manual_status import validate


@dataclass(frozen=True)
class Score:
    home: int
    away: int
    home_pen: int | None = None
    away_pen: int | None = None


SCORE = Score(1, 0)
PENS = Score(1, 1, 4, 3)


def _fields(errors: list[dict]) -> set[str]:
    return {error["loc"][-1] for error in errors}


def _check(status, *, period=None, minute=None, score=None, status_label=None) -> list[dict]:
    return validate(status, period, minute, score, status_label)


@pytest.mark.parametrize("status", ["scheduled", "postponed", "cancelled"])
class TestStatusesWithNothingElse:
    def test_the_bare_status_passes(self, status):
        assert _check(status) == []

    def test_a_score_is_not_allowed(self, status):
        errors = _check(status, score=SCORE)

        assert _fields(errors) == {"score"}
        assert errors[0]["type"] == "not_allowed"

    def test_penalties_a_period_and_a_minute_are_not_allowed(self, status):
        errors = _check(status, period="1H", minute="12", score=PENS)

        assert _fields(errors) == {"score", "period", "minute"}


class TestLive:
    def test_a_score_alone_passes(self):
        assert _check("live", score=SCORE) == []

    def test_period_and_minute_are_optional(self):
        assert _check("live", score=SCORE, period="2H", minute="67") == []
        assert _check("live", score=SCORE, period="1H") == []

    def test_a_score_is_required(self):
        errors = _check("live")

        assert _fields(errors) == {"score"}
        assert errors[0]["type"] == "required"

    def test_penalties_are_not_allowed(self):
        assert _fields(_check("live", score=PENS)) == {"score"}

    @pytest.mark.parametrize("period", ["ET1", "ET2"])
    def test_an_extra_time_period_is_not_allowed(self, period):
        assert _fields(_check("live", score=SCORE, period=period)) == {"period"}


class TestHalftime:
    def test_a_score_alone_passes(self):
        assert _check("halftime", score=SCORE) == []

    def test_a_score_is_required(self):
        assert _fields(_check("halftime")) == {"score"}

    def test_period_minute_and_penalties_are_not_allowed(self):
        errors = _check("halftime", score=PENS, period="1H", minute="45")

        assert _fields(errors) == {"score", "period", "minute"}


class TestExtraTime:
    @pytest.mark.parametrize("period", ["ET1", "ET2", None])
    def test_extra_time_periods_pass(self, period):
        assert _check("extra_time", score=SCORE, period=period, minute="105") == []

    def test_a_score_is_required(self):
        assert _fields(_check("extra_time", period="ET1")) == {"score"}

    @pytest.mark.parametrize("period", ["1H", "2H"])
    def test_a_regular_time_period_is_not_allowed(self, period):
        assert _fields(_check("extra_time", score=SCORE, period=period)) == {"period"}

    def test_penalties_are_not_allowed(self):
        assert _fields(_check("extra_time", score=PENS)) == {"score"}


@pytest.mark.parametrize("status", ["penalties", "finished"])
class TestPenaltiesAndFinished:
    def test_a_score_passes(self, status):
        assert _check(status, score=SCORE) == []

    def test_a_score_with_penalties_passes(self, status):
        assert _check(status, score=PENS) == []

    def test_a_score_is_required(self, status):
        assert _fields(_check(status)) == {"score"}

    def test_period_and_minute_are_not_allowed(self, status):
        assert _fields(_check(status, score=SCORE, period="2H", minute="90")) == {"period", "minute"}


class TestAbandoned:
    def test_no_score_passes(self):
        assert _check("abandoned") == []

    def test_a_score_and_a_minute_pass(self):
        assert _check("abandoned", score=SCORE, minute="34") == []

    def test_penalties_and_a_period_are_not_allowed(self):
        assert _fields(_check("abandoned", score=PENS, period="1H")) == {"score", "period"}


class TestMinute:
    @pytest.mark.parametrize("minute", ["0", "45", "90", "45+2", "120", "90+10", "999"])
    def test_these_pass(self, minute):
        assert _check("live", score=SCORE, minute=minute) == []

    @pytest.mark.parametrize("minute", ["45+", "1234", "abc", "", "+2", "45+123", "4 5", "-1"])
    def test_these_fail(self, minute):
        errors = _check("live", score=SCORE, minute=minute)

        assert _fields(errors) == {"minute"}
        assert errors[0]["type"] == "invalid_format"


class TestStatusLabel:
    def test_80_characters_pass_for_any_status(self):
        assert _check("postponed", status_label="ص" * 80) == []
        assert _check("live", score=SCORE, status_label="x" * 80) == []

    def test_81_characters_fail(self):
        errors = _check("postponed", status_label="x" * 81)

        assert _fields(errors) == {"status_label"}
        assert errors[0]["type"] == "too_long"


class TestUnknownValues:
    def test_an_unknown_status_fails(self):
        errors = _check("paused")

        assert _fields(errors) == {"status"}

    def test_an_unknown_period_fails(self):
        assert _fields(_check("live", score=SCORE, period="3H")) == {"period"}


def test_the_errors_list_every_bad_field_with_its_path():
    errors = _check("postponed", period="1H", minute="45+", score=PENS, status_label="x" * 81)

    assert _fields(errors) == {"score", "period", "minute", "status_label"}
    assert all(set(error) == {"loc", "type"} for error in errors)
    assert len(errors) == 4  # one error per field
