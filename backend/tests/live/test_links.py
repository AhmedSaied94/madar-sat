"""Linking a reading to a match (T025), through B2's resolver."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import select

from app.db.models import MatchExternalId, Team, TeamAlias
from app.domain.arabic import ar_normalize
from app.live.links import link_reading
from tests.live.helpers import make_match, make_reading

NOW = datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
KICKOFF = NOW - timedelta(minutes=30)
WINDOW = (NOW - timedelta(minutes=210), NOW + timedelta(minutes=10))
HOME = "فريق الاختبار الأول"
AWAY = "فريق الاختبار الثاني"


class Recorder:
    def __init__(self):
        self.calls = []

    def __call__(self, session, **values):
        self.calls.append(values)


@pytest.fixture
def teams(sync_session):
    home, away = Team(name=HOME), Team(name=AWAY)
    sync_session.add_all([home, away])
    sync_session.flush()
    return home, away


def link(session, reading, recorder=None):
    return link_reading(session, reading, record_unresolved=recorder or Recorder(), window=WINDOW)


def reading(**values):
    return make_reading(external_id="f9", home=HOME, away=AWAY, kickoff_at=KICKOFF, **values)


def test_an_existing_external_id_wins(sync_session):
    match = make_match(sync_session, KICKOFF)
    sync_session.add(MatchExternalId(source="filgoal", external_id="f9", match_id=match.id))
    sync_session.flush()

    assert link(sync_session, make_reading(external_id="f9", home="أي", away="اسم")) == match.id


def test_both_teams_and_a_close_kickoff_link_and_write_the_id(sync_session, teams):
    match = make_match(
        sync_session, KICKOFF + timedelta(minutes=44), home_team_id=teams[0].id, away_team_id=teams[1].id
    )

    assert link(sync_session, reading(page_path="/matches/f9/coverage/")) == match.id

    row = sync_session.scalar(select(MatchExternalId).where(MatchExternalId.external_id == "f9"))
    assert (row.source, row.match_id, row.url) == ("filgoal", match.id, "/matches/f9/coverage/")


def test_one_unresolved_team_does_not_link_and_reaches_the_queue(sync_session, teams):
    make_match(sync_session, KICKOFF, home_team_id=teams[0].id, away_team_id=teams[1].id)
    recorder = Recorder()

    found = link(
        sync_session,
        make_reading(external_id="f9", home=HOME, away="فريق لا نعرفه", kickoff_at=KICKOFF, competition="دوري"),
        recorder,
    )

    assert found is None
    assert [(call["kind"], call["name"], call["competition"], call["source"]) for call in recorder.calls] == [
        ("team", "فريق لا نعرفه", "دوري", "filgoal")
    ]


def test_a_scoped_alias_beats_an_unscoped_one(sync_session, teams):
    home, away = teams
    other = Team(name="فريق آخر من دوري آخر")
    sync_session.add(other)
    sync_session.flush()
    name, league = "اسم مشترك بين فريقين", "دوري الاختبار"
    sync_session.add_all(
        [
            TeamAlias(source="filgoal", alias_norm=ar_normalize(name), competition_norm="", team_id=other.id),
            TeamAlias(
                source="filgoal", alias_norm=ar_normalize(name), competition_norm=ar_normalize(league), team_id=home.id
            ),
        ]
    )
    expected = make_match(sync_session, KICKOFF, home_team_id=home.id, away_team_id=away.id)
    elsewhere = make_match(sync_session, KICKOFF, home_team_id=other.id, away_team_id=away.id)

    scoped = make_reading(external_id="f9", home=name, away=AWAY, kickoff_at=KICKOFF, competition=league)
    unscoped = make_reading(external_id="f10", home=name, away=AWAY, kickoff_at=KICKOFF, competition="دوري مختلف")

    assert link(sync_session, scoped) == expected.id
    assert link(sync_session, unscoped) == elsewhere.id


def test_a_reversed_order_does_not_link(sync_session, teams):
    make_match(sync_session, KICKOFF, home_team_id=teams[1].id, away_team_id=teams[0].id)

    assert link(sync_session, reading()) is None
    assert sync_session.scalar(select(MatchExternalId).where(MatchExternalId.external_id == "f9")) is None


def test_more_than_one_match_does_not_link(sync_session, teams):
    for minutes in (0, 20):
        make_match(
            sync_session, KICKOFF + timedelta(minutes=minutes), home_team_id=teams[0].id, away_team_id=teams[1].id
        )

    assert link(sync_session, reading()) is None


def test_a_kickoff_gap_does_not_link(sync_session, teams):
    make_match(sync_session, KICKOFF + timedelta(minutes=46), home_team_id=teams[0].id, away_team_id=teams[1].id)

    assert link(sync_session, reading()) is None


def test_a_row_outside_the_window_is_not_looked_up(sync_session, teams):
    recorder = Recorder()

    far = make_reading(external_id="f9", home="مجهول", away="مجهول آخر", kickoff_at=NOW + timedelta(hours=5))

    assert link(sync_session, far, recorder) is None
    assert recorder.calls == []


def _no_time(**values):
    return make_reading(external_id="f9", home=HOME, away=AWAY, kickoff_at=None, **values)


def test_a_row_without_a_time_links_to_the_one_match_with_those_teams_in_the_window(sync_session, teams):
    """FilGoal's row loses its clock once a match starts, and the match still needs its score (R7)."""
    match = make_match(sync_session, NOW - timedelta(minutes=200), home_team_id=teams[0].id, away_team_id=teams[1].id)

    assert link(sync_session, _no_time()) == match.id
    stored = sync_session.scalar(select(MatchExternalId).where(MatchExternalId.external_id == "f9"))
    assert stored.match_id == match.id


def test_a_row_without_a_time_does_not_link_to_a_match_outside_the_window(sync_session, teams):
    make_match(sync_session, NOW - timedelta(minutes=211), home_team_id=teams[0].id, away_team_id=teams[1].id)

    assert link(sync_session, _no_time()) is None


def test_a_row_without_a_time_does_not_link_when_two_matches_fit(sync_session, teams):
    for minutes in (20, 120):
        make_match(sync_session, NOW - timedelta(minutes=minutes), home_team_id=teams[0].id, away_team_id=teams[1].id)

    assert link(sync_session, _no_time()) is None


def test_a_row_without_a_time_does_not_link_on_a_reversed_order(sync_session, teams):
    make_match(sync_session, KICKOFF, home_team_id=teams[1].id, away_team_id=teams[0].id)

    assert link(sync_session, _no_time()) is None


def test_a_playing_row_without_a_time_queues_a_name_it_cannot_resolve(sync_session):
    recorder = Recorder()
    row = make_reading(external_id="f9", home="مجهول", away="مجهول آخر", kickoff_at=None, status=None, period=None)

    assert link(sync_session, row, recorder) is None
    assert {call["name"] for call in recorder.calls} == {"مجهول", "مجهول آخر"}


def test_a_finished_row_without_a_time_links_but_queues_nothing(sync_session, teams):
    """The list keeps yesterday's results, and they would fill the queue with names nobody needs."""
    recorder = Recorder()
    finished = {"status": "finished", "period": None, "minute": None}
    stale = make_reading(external_id="f8", home="مجهول", away="مجهول آخر", kickoff_at=None, **finished)
    match = make_match(sync_session, KICKOFF, home_team_id=teams[0].id, away_team_id=teams[1].id)

    assert link(sync_session, stale, recorder) is None
    assert recorder.calls == []
    assert link(sync_session, _no_time(**finished), recorder) == match.id
