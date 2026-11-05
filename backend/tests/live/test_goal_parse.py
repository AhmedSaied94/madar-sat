"""Goal.com's reader (031 T005, research R8).

``goal_list.html`` holds real FIXTURE, RESULT and POSTPONED rows from a list page saved on 2026-11-05, which
had no live rows at that moment. Its LIVE rows are built from the 2026-11-04 capture's match pages, which
carry the same fields. T027 replaces them with rows from a saved live list. ``firstHalfStoppage000`` is
built by hand for first-half stoppage time, because the capture's list only saw it at half-time.
"""

from __future__ import annotations

import json
import re
from datetime import UTC, date, datetime
from pathlib import Path

import pytest

from app.live.sources import goal
from app.live.types import LayoutChanged, Score

FIXTURES = Path(__file__).parent / "fixtures"
TODAY = date(2026, 11, 4)
_BLOB = re.compile(r'(<script id="__NEXT_DATA__"[^>]*>)(.*?)(</script>)', re.S)


def _page(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


def _content(name: str) -> dict:
    return json.loads(_BLOB.search(_page(name).decode()).group(2))["props"]["pageProps"]["content"]


def _with_content(name: str, content: dict) -> bytes:
    blob = json.dumps({"props": {"pageProps": {"content": content}}}, ensure_ascii=False)
    return _BLOB.sub(lambda found: found.group(1) + blob + found.group(3), _page(name).decode()).encode()


def _rows(body: bytes | None = None) -> dict:
    rows = goal.parse_list(body if body is not None else _page("goal_list.html"), today=TODAY)
    return {row.external_id: row for row in rows}


def _with_row(**changes) -> bytes:
    content = _content("goal_list.html")
    content["liveScores"][0]["matches"][0].update(changes)
    return _with_content("goal_list.html", content)


PORTO = "7NZPl1sW42sl7zvVkOtqe"


def test_a_live_row_gives_id_teams_kickoff_status_period_minute_and_score():
    row = _rows()[PORTO]

    assert row.source == "goal"
    assert (row.home, row.away) == ("بورتو", "نابولي")
    assert row.competition == "دوري أبطال أوروبا"
    assert row.kickoff_at == datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
    assert (row.status, row.period, row.minute) == ("live", "1H", "2")
    assert row.score == Score(0, 0)
    assert row.events is None
    assert row.stats is None
    assert row.unknown_status is None


def test_links_come_from_hrefs_ending_in_the_match_id():
    rows = _rows()

    assert rows[PORTO].page_path.endswith(f"/{PORTO}")
    assert rows[PORTO].page_path.startswith("/ar-eg/")
    assert "%" in rows[PORTO].page_path
    assert rows["irXUOKvc9dSverr6s4SgV"].page_path.endswith("/irXUOKvc9dSverr6s4SgV")


def test_a_row_with_no_link_has_no_page_path():
    content = _content("goal_list.html")
    body = _BLOB.search(_page("goal_list.html").decode()).group(0)
    blob = json.dumps({"props": {"pageProps": {"content": content}}}, ensure_ascii=False)
    assert body

    rows = _rows(
        f'<html><body><script id="__NEXT_DATA__" type="application/json">{blob}</script></body></html>'.encode()
    )

    assert rows[PORTO].page_path is None


@pytest.mark.parametrize(
    ("external_id", "state"),
    [
        (PORTO, ("live", "1H")),
        ("eg3PLncUQ58nMidLNHHoU", ("halftime", None)),
        ("_t-wM8gFstRD6wYdm7G9m", ("live", "2H")),
        ("-bTdAe3K7sZQeZLxHM3Co", ("finished", None)),
        ("irXUOKvc9dSverr6s4SgV", ("scheduled", None)),
        ("zPcxW0csa-OCJD1KnKluK", ("postponed", None)),
    ],
)
def test_the_statuses_map(external_id, state):
    row = _rows()[external_id]

    assert (row.status, row.period) == state
    assert row.unknown_status is None
    assert row.status_label  # what a client reads is Arabic, never Goal.com's constant
    assert row.status_label.isascii() is False


def test_stoppage_time_shows_as_plus_n():
    rows = _rows()

    assert rows["firstHalfStoppage000"].minute == "45+2"
    assert rows["_t-wM8gFstRD6wYdm7G9m"].minute == "90+2"


def test_half_time_shows_no_minute():
    assert _rows()["eg3PLncUQ58nMidLNHHoU"].minute is None


def test_a_row_that_hasnt_been_played_has_no_score():
    rows = _rows()

    assert rows["irXUOKvc9dSverr6s4SgV"].score is None
    assert rows["zPcxW0csa-OCJD1KnKluK"].score is None  # it shows 0–0, which is no result
    assert rows["-bTdAe3K7sZQeZLxHM3Co"].score == Score(1, 3)


@pytest.mark.parametrize(
    "changes",
    [{"status": "SUSPENDED", "period": None}, {"status": "LIVE", "period": {"type": "EXTRA_FIRST_HALF", "minute": 95}}],
)
def test_an_unknown_status_keeps_its_score_and_nothing_else(changes):
    rows = _rows(_with_row(score={"teamA": 2, "teamB": 1}, **changes))

    row = rows[PORTO]
    assert row.unknown_status
    assert (row.status, row.period, row.minute) == (None, None, None)
    assert row.score == Score(2, 1)
    assert all(other.unknown_status is None for key, other in rows.items() if key != PORTO)
    assert len(rows) == 7


def test_an_unknown_status_with_no_score_has_no_score():
    row = _rows(_with_row(status="SUSPENDED", period=None, score=None))[PORTO]

    assert row.unknown_status == "SUSPENDED"
    assert row.score is None


def test_a_live_row_with_a_null_score_stays_usable():
    row = _rows(_with_row(score=None))[PORTO]

    assert (row.status, row.score) == ("live", None)


def test_penalties_are_read_when_they_are_there():
    row = _rows(_with_row(penalty={"teamA": 4, "teamB": 3}, score={"teamA": 1, "teamB": 1}))[PORTO]

    assert row.score == Score(1, 1, 4, 3)


@pytest.mark.parametrize(
    "body",
    [
        b"",
        b"   ",
        b"<html><body>Just a moment...</body></html>",
        b'<html><script id="__NEXT_DATA__">{not json</script></html>',
        b'<html><script id="__NEXT_DATA__">{"props": {"pageProps": {"content": {}}}}</script></html>',
        b'<html><script id="__NEXT_DATA__">{"props": {}}</script></html>',
    ],
)
def test_a_page_without_its_data_fails_validation(body):
    with pytest.raises(LayoutChanged):
        goal.parse_list(body, today=TODAY)
    with pytest.raises(LayoutChanged):
        goal.parse_match(body)


@pytest.mark.parametrize("field", ["id", "status", "teamA", "teamB", "score", "startDate"])
def test_a_row_missing_a_field_fails_validation(field):
    content = _content("goal_list.html")
    del content["liveScores"][0]["matches"][0][field]

    with pytest.raises(LayoutChanged):
        goal.parse_list(_with_content("goal_list.html", content), today=TODAY)


def test_a_score_that_isnt_a_number_fails_validation():
    with pytest.raises(LayoutChanged):
        goal.parse_list(_with_row(score={"teamA": "x", "teamB": 1}), today=TODAY)


def test_a_list_with_no_rows_is_valid_and_empty():
    assert goal.parse_list(_with_content("goal_list.html", {"liveScores": []}), today=TODAY) == []


def test_the_match_page_reads_the_row_fields():
    reading = goal.parse_match(_page("goal_match_no_stats.html"))

    assert reading.external_id == "Xik4gP2-SvZ29NJ7BqQez"
    assert (reading.status, reading.period, reading.minute) == ("live", "2H", "78")
    assert reading.score == Score(3, 1)
    assert (reading.home, reading.away) == ("التعاون", "الفيصلي")
    assert reading.kickoff_at is not None


def test_goal_events_map_and_keep_goal_coms_side():
    reading = goal.parse_match(_page("goal_match_no_stats.html"))

    by_type = {}
    for event in reading.events:
        by_type.setdefault(event.type, []).append(event)
    assert sorted(by_type) == ["goal", "own_goal", "penalty"]
    assert len(by_type["goal"]) == 2
    # GOAL_OWN on TEAM_B took the score from 2–0 to 2–1, so it's already the side it counts for (R7).
    assert (by_type["own_goal"][0].side, by_type["own_goal"][0].minute) == ("away", "58")
    assert by_type["own_goal"][0].player is None
    assert (by_type["penalty"][0].side, by_type["penalty"][0].minute, by_type["penalty"][0].player) == (
        "home",
        "48",
        "عبد الرزاق حمد الله",
    )


def test_event_ids_are_stable_and_distinct():
    first = goal.parse_match(_page("goal_match_no_stats.html"))
    second = goal.parse_match(_page("goal_match_no_stats.html"))

    assert [event.external_id for event in first.events] == [event.external_id for event in second.events]
    assert len({event.external_id for event in first.events}) == len(first.events)
    assert all(re.fullmatch(r"[0-9a-f]{16}(-\d+)?", event.external_id) for event in first.events)


def test_an_event_id_doesnt_depend_on_the_running_score():
    """A later correction changes the running score of every later goal. They're still the same goals."""
    content = _content("goal_match_no_stats.html")
    before = goal.parse_match(_with_content("goal_match_no_stats.html", content))
    for event in content["match"]["events"]:
        if event.get("score"):
            event["score"] = {"teamA": 9, "teamB": 9}

    after = goal.parse_match(_with_content("goal_match_no_stats.html", content))

    assert [event.external_id for event in after.events] == [event.external_id for event in before.events]


def test_two_identical_events_stay_two_events():
    content = _content("goal_match_no_stats.html")
    own = next(event for event in content["match"]["events"] if event["type"] == "GOAL_OWN")
    content["match"]["events"].append(dict(own))

    reading = goal.parse_match(_with_content("goal_match_no_stats.html", content))

    ids = [event.external_id for event in reading.events if event.type == "own_goal"]
    assert len(ids) == 2
    assert len(set(ids)) == 2


def test_stoppage_time_on_an_event_shows_as_plus_n():
    content = _content("goal_match_no_stats.html")
    goal_event = next(event for event in content["match"]["events"] if event["type"] == "GOAL")
    goal_event["period"] = {"minute": 45, "extra": 3}

    reading = goal.parse_match(_with_content("goal_match_no_stats.html", content))

    assert "45+3" in {event.minute for event in reading.events}


def test_period_markers_and_yellow_cards_are_skipped_without_a_log():
    reading = goal.parse_match(_page("goal_match_stats.html"))

    assert reading.events == ()
    assert reading.ignored_event_types == ()


def test_an_event_type_nobody_has_seen_is_logged_not_guessed():
    content = _content("goal_match_no_stats.html")
    content["match"]["events"].append({"__typename": "MatchCardEvent", "type": "CARD_RED", "side": "TEAM_A"})

    reading = goal.parse_match(_with_content("goal_match_no_stats.html", content))

    assert reading.ignored_event_types == ("CARD_RED",)
    assert len(reading.events) == 4


def test_a_goal_for_neither_team_fails_validation():
    content = _content("goal_match_no_stats.html")
    content["match"]["events"][0]["side"] = "TEAM_C"

    with pytest.raises(LayoutChanged):
        goal.parse_match(_with_content("goal_match_no_stats.html", content))


def test_lineups_have_formation_names_and_numbers_and_no_ratings():
    reading = goal.parse_match(_page("goal_match_stats.html"))

    home = reading.lineups.home
    assert home.formation == "3-4-1-2"
    starters = [player for player in home.players if player["is_starter"]]
    substitutes = [player for player in home.players if not player["is_starter"]]
    assert len(starters) == 11
    assert substitutes
    assert home.players[0]["is_starter"] is True
    assert set(starters[0]) == {"name", "number", "position", "is_starter"}
    assert starters[0]["name"]
    assert isinstance(starters[0]["number"], int)
    assert reading.lineups.away.players


def test_a_page_with_no_lineups_has_none():
    assert goal.parse_match(_page("goal_match_no_stats.html")).lineups is None


def test_stats_come_from_the_summary_as_home_and_away():
    reading = goal.parse_match(_page("goal_match_stats.html"))

    assert reading.stats[0] == {"type": "POSSESSION", "home": 34, "away": 66}
    assert {row["type"] for row in reading.stats} == {
        "POSSESSION",
        "SHOT_ON_TARGET",
        "CORNER_TOTAL",
        "FOUL_COMMITED",
        "OFFSIDE_TOTAL",
    }
    assert all(set(row) == {"type", "home", "away"} for row in reading.stats)


def test_a_page_with_no_stats_has_none():
    assert goal.parse_match(_page("goal_match_no_stats.html")).stats is None


def test_an_unknown_status_on_the_match_page_keeps_its_score_and_nothing_else():
    content = _content("goal_match_no_stats.html")
    content["match"]["period"] = {"type": "PENALTY_SHOOTOUT", "minute": 120, "extra": 0}

    reading = goal.parse_match(_with_content("goal_match_no_stats.html", content))

    assert reading.unknown_status == "LIVE/PENALTY_SHOOTOUT"
    assert (reading.status, reading.period, reading.minute) == (None, None, None)
    assert reading.score == Score(3, 1)


def test_nothing_written_or_decorative_reaches_a_reading():
    marker = "تعليق مكتوب لا يجوز نشره"
    image = "https://cdn.sportfeeds.io/sdl/images/person/head/medium/x.png"
    content = _content("goal_match_stats.html")
    content["tabsInfo"] = {"commentary": [{"text": marker}]}
    content["articles"] = [{"title": marker, "body": marker}]
    content["match"]["venue"] = {"name": marker}
    content["match"]["commentary"] = marker
    content["match"]["teamA"]["image"] = {"url": image}
    for row in content["match"]["lineups"]["teamA"]["lineup"]:
        row["person"]["image"] = {"url": image}
        row["score"] = 9.9

    reading = goal.parse_match(_with_content("goal_match_stats.html", content))

    text = repr(reading)
    assert marker not in text
    assert image not in text
    assert "9.9" not in text


def test_a_list_reading_holds_no_venue_or_image():
    marker = "سان سيرو"
    content = _content("goal_list.html")
    content["liveScores"][0]["matches"][0]["venue"] = {"name": marker}
    content["liveScores"][0]["matches"][0]["teamA"]["image"] = {"url": "https://x/y.png"}

    text = repr(goal.parse_list(_with_content("goal_list.html", content), today=TODAY))

    assert marker not in text
    assert "y.png" not in text
