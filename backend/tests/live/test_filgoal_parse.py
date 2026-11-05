"""FilGoal's parsers on saved pages, and on trimmed models from the 2026-11-04 capture (031 T004)."""

from __future__ import annotations

import json
import re
from datetime import UTC, date, datetime
from pathlib import Path

import pytest

from app.live.sources import filgoal
from app.live.sources.common import minute_value
from app.live.types import LayoutChanged, Score

FIXTURES = Path(__file__).parent / "fixtures"
TODAY = date(2026, 11, 4)


def _page(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


def _model(name: str) -> dict:
    text = _page(name).decode()
    return json.JSONDecoder().raw_decode(text[re.search(r"viewModelData\s*=\s*", text).end() :])[0]


def _with_model(model: dict) -> bytes:
    encoded = json.dumps(model, ensure_ascii=False)
    return f"<html><body><script>var viewModelData = {encoded};</script></body></html>".encode()


def test_the_list_reads_finished_and_scheduled_rows():
    rows = filgoal.parse_list(_page("filgoal_list.html"), today=TODAY)

    finished = next(row for row in rows if row.external_id == "378934")
    assert finished.status == "finished"
    assert finished.score == Score(0, 2)
    assert finished.home == "أتلتيكو مدريد"
    assert finished.away == "بايرن ميونيخ"
    assert finished.competition == "دوري أبطال أوروبا"
    assert finished.external_id == "378934"
    assert finished.page_path == "/matches/378934/coverage/"
    assert finished.events is None
    assert finished.status_label == "انتهت"

    scheduled = next(row for row in rows if row.status == "scheduled")
    assert scheduled.score is None
    assert scheduled.kickoff_at == datetime(2026, 11, 4, 15, 0, tzinfo=UTC)  # 17:00 in Cairo


def test_a_finished_page_has_its_score_events_and_lineups():
    reading = filgoal.parse_match(_page("filgoal_match_finished.html"))

    assert reading.external_id == "378939"
    assert reading.status == "finished"
    assert reading.score == Score(3, 2)
    assert reading.kickoff_at == datetime(2026, 11, 3, 20, 0, tzinfo=UTC)  # 22:00 in Cairo
    types = {event.type for event in reading.events}
    assert types == {"goal", "penalty", "red_card"}
    assert all(
        event.side in {"home", "away"} and re.fullmatch(r"\d{1,3}(\+\d{1,2})?", event.minute)
        for event in reading.events
    )
    red = next(event for event in reading.events if event.type == "red_card")
    assert red.minute == "90+1"
    assert all(event.external_id.isdigit() for event in reading.events)
    assert reading.lineups.home.formation
    starters = [player for player in reading.lineups.home.players if player["is_starter"]]
    assert len(starters) == 11
    assert set(starters[0]) == {"name", "number", "position", "is_starter"}
    assert reading.lineups.home.players[0]["is_starter"] is True


def test_a_scheduled_page_has_no_score_events_or_lineups():
    reading = filgoal.parse_match(_page("filgoal_match_scheduled.html"))

    assert (reading.status, reading.score, reading.minute) == ("scheduled", None, None)
    assert reading.events == ()
    assert reading.lineups is None


@pytest.mark.parametrize(
    ("name", "state"),
    [
        ("لم تبدأ", ("scheduled", None)),
        ("بعد قليل", ("scheduled", None)),
        ("الشوط الاول", ("live", "1H")),
        ("استراحة", ("halftime", None)),
        ("الشوط الثاني", ("live", "2H")),
        ("انتهت", ("finished", None)),
        ("تأجيل", ("postponed", None)),
    ],
)
def test_the_status_map(name, state):
    model = _model("filgoal_match_finished.html")
    model["CurrentMatchStatus"]["MatchStatusName"] = name
    model["CurrentMatchStatus"]["IsCounterEnabled"] = False

    reading = filgoal.parse_match(_with_model(model))

    assert (reading.status, reading.period) == state


@pytest.mark.parametrize(
    ("status", "elapsed", "minute"),
    [("الشوط الاول", 23, "23"), ("الشوط الاول", 47, "45+2"), ("الشوط الثاني", 10, "55"), ("الشوط الثاني", 48, "90+3")],
)
def test_the_minute_counts_from_the_period_and_is_western(status, elapsed, minute):
    model = _model("filgoal_match_finished.html")
    model["CurrentMatchStatus"].update(
        MatchStatusName=status,
        IsCounterEnabled=True,
        MatchStatusMaxTime=45,
        TimeElapsed={"Minutes": elapsed, "Seconds": 1},
    )

    reading = filgoal.parse_match(_with_model(model))

    assert reading.minute == minute
    assert reading.minute.isascii()


def _live_model(status: str, elapsed: int | None, *, limit: int | None = 45, counter: bool = True) -> bytes:
    model = _model("filgoal_match_finished.html")
    model["CurrentMatchStatus"].update(
        MatchStatusName=status,
        IsCounterEnabled=counter,
        MatchStatusMaxTime=limit,
        TimeElapsed={"Minutes": elapsed, "Seconds": 1},
    )
    return _with_model(model)


FIRST_HALF = "الشوط الاول"
SECOND_HALF = "الشوط الثاني"


@pytest.mark.parametrize(
    ("status", "elapsed", "minute"),
    [
        # The start time is shifted by whole hours, so the mod finds the real minute (R4).
        (FIRST_HALF, -98, "22"),
        (FIRST_HALF, -104, "16"),
        (SECOND_HALF, -109, "56"),
        (SECOND_HALF, -106, "59"),
        # The wrap in R4: 61 minutes into the period reads as 1. T010 and T014 stop it moving the minute back.
        (SECOND_HALF, -59, "46"),
        # A positive value still works.
        (FIRST_HALF, 22, "22"),
        (SECOND_HALF, 24, "69"),
        # Past the period's length it's stoppage time.
        (FIRST_HALF, 47, "45+2"),
        (SECOND_HALF, 48, "90+3"),
        (FIRST_HALF, -73, "45+2"),
        (SECOND_HALF, -73, "90+2"),
        # The limit is on elapsed time in the period, not on the result: 60 is the last with a minute.
        (SECOND_HALF, 60, "90+15"),
        (SECOND_HALF, 61, None),
        (FIRST_HALF, 60, "45+15"),
        (FIRST_HALF, 61, None),
    ],
)
def test_the_minute_handles_both_forms_of_the_clock(status, elapsed, minute):
    assert filgoal.parse_match(_live_model(status, elapsed)).minute == minute


@pytest.mark.parametrize("elapsed", [-1, -59, -60, -61, -119, -120, -600, -1439, 0, 45])
def test_no_minute_is_ever_negative(elapsed):
    minute = filgoal.parse_match(_live_model(SECOND_HALF, elapsed)).minute

    assert minute is not None
    assert not minute.startswith("-")
    assert minute_value(minute) >= 45


def test_a_clock_with_no_length_still_gives_the_minute():
    assert filgoal.parse_match(_live_model(FIRST_HALF, 30, limit=None)).minute == "30"
    assert filgoal.parse_match(_live_model(FIRST_HALF, -98, limit=None)).minute == "22"


@pytest.mark.parametrize("elapsed", [None, "x"])
def test_an_unreadable_clock_gives_no_minute(elapsed):
    assert filgoal.parse_match(_live_model(FIRST_HALF, elapsed)).minute is None


def test_a_stopped_counter_gives_no_minute():
    assert filgoal.parse_match(_live_model(FIRST_HALF, 22, counter=False)).minute is None


@pytest.mark.parametrize(
    ("minute", "value"),
    [("93", 93), ("90+3", 93), ("45+2", 47), ("1", 1), ("0", 0), ("", None), (None, None), ("x", None)],
)
def test_minute_value(minute, value):
    assert minute_value(minute) == value


def _captured(name: str) -> dict:
    return json.loads((FIXTURES / f"filgoal_model_{name}.json").read_text(encoding="utf-8"))


def _event(model: dict, type_id: int) -> dict:
    return next(event for event in model["Events"] if event["MatchEventTypeId"] == type_id)


def test_leipzigs_own_goal_counts_for_the_away_side():
    """Lukeba plays for the home team, and his goal made it 0–1 (R7)."""
    model = _captured("own_goal")
    assert _event(model, 20)["TeamId"] == model["HomeTeamId"]

    reading = filgoal.parse_match(_with_model(model))

    own = next(event for event in reading.events if event.type == "own_goal")
    assert own.side == "away"
    assert own.minute == "37"
    assert own.player == _event(model, 20)["PlayerAName"]
    assert reading.score == Score(0, 1)
    assert reading.minute == "41"  # TimeElapsed is -79 here


def test_an_own_goal_by_the_away_team_counts_for_the_home_side():
    model = _captured("own_goal")
    _event(model, 20)["TeamId"] = model["AwayTeamId"]

    reading = filgoal.parse_match(_with_model(model))

    assert next(event for event in reading.events if event.type == "own_goal").side == "home"


def test_a_red_card_stays_on_the_players_team():
    model = _captured("red_card")
    assert _event(model, 4)["TeamId"] == model["AwayTeamId"]

    reading = filgoal.parse_match(_with_model(model))

    red = next(event for event in reading.events if event.type == "red_card")
    assert (red.side, red.minute, red.external_id) == ("away", "88", str(_event(model, 4)["Id"]))
    assert reading.minute == "90+2"


def test_a_missed_penalty_stays_on_the_players_team():
    model = _captured("missed_penalty")
    assert _event(model, 9)["TeamId"] == model["HomeTeamId"]

    reading = filgoal.parse_match(_with_model(model))

    missed = next(event for event in reading.events if event.type == "missed_penalty")
    assert (missed.side, missed.minute) == ("home", "69")
    assert reading.minute == "69"


def test_an_unknown_status_on_the_page_keeps_its_score_and_nothing_else():
    model = _model("filgoal_match_finished.html")
    model["CurrentMatchStatus"].update(MatchStatusName="ركلات الترجيح", IsCounterEnabled=True, MatchStatusMaxTime=45)
    model["CurrentMatchStatus"]["TimeElapsed"] = {"Minutes": 10, "Seconds": 0}

    reading = filgoal.parse_match(_with_model(model))

    assert reading.unknown_status == "ركلات الترجيح"
    assert (reading.status, reading.period, reading.minute) == (None, None, None)
    assert reading.score == Score(3, 2)
    assert reading.events  # the events are still facts about this match


def test_an_unknown_status_on_the_list_affects_that_row_only():
    page = _page("filgoal_list.html").decode().replace("لم تبدأ", "شوط إضافي", 1).encode()

    rows = filgoal.parse_list(page, today=TODAY)

    unknown = [row for row in rows if row.unknown_status]
    assert len(unknown) == 1
    assert unknown[0].unknown_status == "شوط إضافي"
    assert (unknown[0].status, unknown[0].period, unknown[0].minute, unknown[0].score) == (None, None, None, None)
    assert all(row.status is not None for row in rows if not row.unknown_status)
    assert len(rows) >= 2


def test_an_unknown_status_on_the_list_keeps_a_score_it_has():
    page = _page("filgoal_list.html").decode().replace("انتهت", "شوط إضافي", 1).encode()

    row = next(row for row in filgoal.parse_list(page, today=TODAY) if row.unknown_status)

    assert row.score == Score(0, 2)
    assert row.status is None


@pytest.mark.parametrize("field", ["HomeScore", "AwayScore", "HomeTeamName", "CurrentMatchStatus", "Date", "Id"])
def test_a_missing_field_fails_validation(field):
    model = _model("filgoal_match_finished.html")
    del model[field]

    with pytest.raises(LayoutChanged):
        filgoal.parse_match(_with_model(model))


def test_a_finished_match_without_a_score_fails_validation():
    model = _model("filgoal_match_finished.html")
    model["HomeScore"] = model["AwayScore"] = None

    with pytest.raises(LayoutChanged):
        filgoal.parse_match(_with_model(model))


@pytest.mark.parametrize(
    "body",
    [b"", b"   ", b"<html><body>Just a moment...</body></html>", b"<html><title>Attention Required</title></html>"],
)
def test_a_blocked_page_or_an_empty_body_fails(body):
    with pytest.raises(LayoutChanged):
        filgoal.parse_list(body, today=TODAY)
    with pytest.raises(LayoutChanged):
        filgoal.parse_match(body)


def test_a_list_with_no_rows_is_valid_and_empty():
    body = b'<html><body><div id="match-slider-holder"></div></body></html>'

    assert filgoal.parse_list(body, today=TODAY) == []


def test_no_commentary_text_reaches_a_reading():
    model = _model("filgoal_match_finished.html")
    marker = "تعليق مكتوب لا يجوز نشره"
    model["Comments"] = [{"Id": 1, "Text": marker, "Body": marker}]
    for event in model["Events"]:
        event["Comment"] = marker

    reading = filgoal.parse_match(_with_model(model))

    assert marker not in repr(reading)


def test_an_event_type_nobody_has_seen_is_listed_not_guessed():
    model = _model("filgoal_match_finished.html")
    model["Events"][0].update(MatchEventTypeId=99, MatchEventTypeName="نوع جديد")
    before = {
        event.external_id for event in filgoal.parse_match(_with_model(_model("filgoal_match_finished.html"))).events
    }

    reading = filgoal.parse_match(_with_model(model))

    assert reading.ignored_event_types == ("نوع جديد",)
    assert {event.external_id for event in reading.events} <= before
