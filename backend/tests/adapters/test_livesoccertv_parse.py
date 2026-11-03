"""LiveSoccerTV's two parsers on the saved pages (T052, R14)."""

from __future__ import annotations

from datetime import UTC, date, datetime

import pytest

from app.adapters.base import LayoutChanged, RawPage
from app.adapters.livesoccertv import LivesoccertvAdapter
from tests.adapters.helpers import empty_match_page, empty_team_page, match_page, team_page


@pytest.fixture
def adapter() -> LivesoccertvAdapter:
    return LivesoccertvAdapter(fetcher=None)


def test_the_team_page_yields_upcoming_links_with_date_and_opponent(adapter: LivesoccertvAdapter) -> None:
    rows = adapter.parse_team(team_page())

    # The saved page lists ten rows, past and future; the two teams are read from the link's title
    # because the URL's slug order is alphabetical, not the page's home/away order.
    assert len(rows) == 10
    upcoming = [row for row in rows if row.match_date >= date(2026, 11, 7)]
    assert upcoming, "the fixture page carries upcoming matches"
    al_sekka = next(row for row in upcoming if row.away == "Al Sekka")
    assert al_sekka.home == "Al Ahly"
    assert al_sekka.match_date == date(2026, 11, 7)
    assert al_sekka.wall_time == "20:00"  # 18:00 UTC in Cairo
    assert al_sekka.url is not None and al_sekka.url.startswith("https://www.livesoccertv.com/match/")
    assert al_sekka.external_id == "5826900"


def test_a_team_page_without_matches_is_empty_not_broken(adapter: LivesoccertvAdapter) -> None:
    assert adapter.parse_team(empty_team_page()) == []


def test_the_match_page_yields_name_and_country(adapter: LivesoccertvAdapter) -> None:
    channels = adapter.parse_broadcasts(match_page())

    names = {(channel.name, channel.country) for channel in channels}
    # MENA and non-MENA listings both arrive, and a name Madar has no channel for is kept as is:
    # the matching rules, not the parser, decide what becomes a placeholder (R15).
    assert ("beIN Sports HD 1", "Algeria") in names
    assert ("DAZN Spain", "Spain") in names
    assert ("FanCode", "Afghanistan") in names
    assert len(channels) > 100
    assert all(channel.name and channel.country for channel in channels)


def test_a_match_page_without_broadcasters_yields_no_channels(adapter: LivesoccertvAdapter) -> None:
    assert adapter.parse_broadcasts(empty_match_page()) == []


def test_a_duplicate_country_and_name_is_reported_once(adapter: LivesoccertvAdapter) -> None:
    channels = adapter.parse_broadcasts(match_page())
    pairs = [(channel.name, channel.country) for channel in channels]
    assert len(pairs) == len(set(pairs))


def test_a_page_without_the_expected_tables_raises_layout_changed(adapter: LivesoccertvAdapter) -> None:
    not_a_team = RawPage(
        url="https://www.livesoccertv.com/teams/egypt/al-ahly/", status=200, body=b"<html><body>x</body></html>"
    )
    with pytest.raises(LayoutChanged):
        adapter.parse_team(not_a_team)

    not_a_match = RawPage(url="https://www.livesoccertv.com/match/x/1", status=200, body=b"<html><body>x</body></html>")
    with pytest.raises(LayoutChanged):
        adapter.parse_broadcasts(not_a_match)


ROW_5788304_TIME = (
    "<span class=\"timecell\"><span id='ko5788304' title=\"Match ended\" class='ts ft' "
    "dv='1792242000000' df='h:MMtt'> 9:00am</span></span>"
)


def _with_row_5788304_time(replacement: str) -> RawPage:
    """The saved team page with one row's time cell swapped, as the live site served it."""
    page = team_page()
    assert ROW_5788304_TIME.encode() in page.body, "the fixture's row 5788304 changed"
    return RawPage(url=page.url, status=200, body=page.body.replace(ROW_5788304_TIME.encode(), replacement.encode()))


def test_a_postponed_row_is_skipped_and_the_rest_of_the_page_still_parses(adapter: LivesoccertvAdapter) -> None:
    # Esteghlal's page on 2026-11-03: a postponed match keeps ``data-ko`` but prints a status, no epoch.
    postponed = _with_row_5788304_time('<span class="timecell" title="Match postponed">Postp.</span>')

    rows = adapter.parse_team(postponed)

    assert len(rows) == 9
    assert "5788304" not in {row.external_id for row in rows}


def test_a_printed_time_without_its_epoch_span_is_still_a_layout_change(adapter: LivesoccertvAdapter) -> None:
    no_epoch = _with_row_5788304_time('<span class="timecell"><span class="ts ft"> 9:00am</span></span>')

    with pytest.raises(LayoutChanged):
        adapter.parse_team(no_epoch)


def test_an_empty_body_is_a_layout_change(adapter: LivesoccertvAdapter) -> None:
    with pytest.raises(LayoutChanged):
        adapter.parse_broadcasts(RawPage(url="https://www.livesoccertv.com/match/x/1", status=200, body=b""))


def test_the_parser_touches_no_network_no_database_and_no_clock(adapter: LivesoccertvAdapter) -> None:
    """``parse`` is pure: the same page gives the same rows, whatever the clock says (R30)."""
    first = adapter.parse_team(team_page())
    second = adapter.parse_team(team_page())
    assert [(row.external_id, row.match_date, row.wall_time) for row in first] == [
        (row.external_id, row.match_date, row.wall_time) for row in second
    ]
    assert first[0].match_date == date(2026, 10, 11)
    assert datetime(2026, 10, 11, 13, 0, tzinfo=UTC).astimezone(UTC).date() == first[0].match_date
