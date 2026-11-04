"""FilGoal's parsers on saved finished and scheduled pages (T023). The capture adds live pages (T021)."""

from __future__ import annotations

import json
import re
from datetime import UTC, date, datetime
from pathlib import Path

import pytest

from app.live.sources import filgoal
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


def test_an_unknown_status_fails_validation_on_the_page():
    model = _model("filgoal_match_finished.html")
    model["CurrentMatchStatus"]["MatchStatusName"] = "ركلات الترجيح"

    with pytest.raises(LayoutChanged):
        filgoal.parse_match(_with_model(model))


def test_an_unknown_status_fails_validation_on_the_list():
    page = _page("filgoal_list.html").decode().replace("لم تبدأ", "شوط إضافي").encode()

    with pytest.raises(LayoutChanged):
        filgoal.parse_list(page, today=TODAY)


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
