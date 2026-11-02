"""Finding the match page from the team page: Cairo date and opponent (T054, R14)."""

from __future__ import annotations

from datetime import UTC, date, datetime

from app.adapters.base import ParsedFixture
from app.adapters.livesoccertv import (
    LivesoccertvAdapter,
    LivesoccertvTarget,
    pick_match,
    team_key,
    team_slug,
)
from tests.adapters.helpers import empty_team_page, team_page


def _target(**overrides) -> LivesoccertvTarget:
    values = {
        "match_id": 48213,
        "kickoff_at": datetime(2026, 11, 7, 18, 0, tzinfo=UTC),  # 20:00 Cairo, 7 November
        "home_slug": "al-ahly",
        "away_slug": "al-sekka",
        "country": "egypt",
    }
    return LivesoccertvTarget(**{**values, **overrides})


def test_the_link_is_picked_by_cairo_date_and_opponent() -> None:
    rows = LivesoccertvAdapter(None).parse_team(team_page())
    row = pick_match(rows, _target())
    assert row is not None
    assert row.url is not None and "/al-ahly-vs-al-sekka/" in row.url


def test_a_match_on_another_cairo_day_is_not_picked() -> None:
    rows = LivesoccertvAdapter(None).parse_team(team_page())
    assert pick_match(rows, _target(kickoff_at=datetime(2026, 11, 8, 18, 0, tzinfo=UTC))) is None


def test_a_different_opponent_is_not_picked() -> None:
    rows = LivesoccertvAdapter(None).parse_team(team_page())
    assert (
        pick_match(rows, _target(away_slug="pyramids-fc", kickoff_at=datetime(2026, 11, 7, 18, 0, tzinfo=UTC))) is None
    )


def test_the_pair_matches_in_either_order() -> None:
    """Madar knows which side is home; the page's URL slug order is alphabetical."""
    rows = LivesoccertvAdapter(None).parse_team(team_page())
    swapped = _target(home_slug="al-sekka", away_slug="al-ahly")
    row = pick_match(rows, swapped)
    assert row is not None and row.home == "Al Ahly"


def test_no_match_records_unmatched_match_not_found() -> None:
    """A team page that has no link for the target leaves the match unmatched, never guessed."""

    class _Fetcher:
        http_errors = 0

        def __init__(self) -> None:
            self.requested: list[str] = []

        def get(self, url: str, allowed_hosts):  # noqa: ANN001 - the tests' stub
            self.requested.append(url)
            return empty_team_page()

    fetcher = _Fetcher()
    adapter = LivesoccertvAdapter(fetcher)  # type: ignore[arg-type]
    from app.adapters.base import DateWindow

    pages = adapter.fetch(DateWindow.next_days(today=date(2026, 11, 7)), targets=[_target()])

    assert fetcher.requested == ["https://www.livesoccertv.com/teams/egypt/al-ahly/"]
    assert len(pages) == 1
    assert adapter.items == []
    assert [item.why for item in adapter.unmatched] == ["match_not_found"]


def test_a_found_match_fetches_its_match_page_and_builds_one_item() -> None:
    pages = {
        "https://www.livesoccertv.com/teams/egypt/al-ahly/": team_page(),
    }
    match_url = "https://www.livesoccertv.com/match/al-ahly-vs-al-sekka/27z7272vt"

    class _Fetcher:
        http_errors = 0

        def __init__(self) -> None:
            self.requested: list[str] = []

        def get(self, url: str, allowed_hosts):  # noqa: ANN001 - the tests' stub
            self.requested.append(url)
            if url in pages:
                return pages[url]
            assert url.startswith(match_url)
            from tests.adapters.helpers import fixture_page

            return fixture_page(
                "match-al-ahly-vs-al-sekka-none.html",
                "https://www.livesoccertv.com/matches/al-ahly-vs-al-sekka/27z7272vt",
            )

    adapter = LivesoccertvAdapter(_Fetcher())  # type: ignore[arg-type]
    from app.adapters.base import DateWindow

    adapter.fetch(DateWindow.next_days(today=date(2026, 11, 7)), targets=[_target()])

    assert len(adapter.items) == 1
    assert adapter.items[0].match_id == 48213
    assert adapter.items[0].channels == []
    assert len(adapter.pages) == 2
    assert adapter.unmatched == []


# --- B2-R1-8: the mapping table's ASCII URL slug against the page's printed name -------------


def _row(
    home: str,
    away: str,
    url: str | None,
    match_date: date = date(2026, 11, 7),
) -> ParsedFixture:
    return ParsedFixture(
        url=url,
        home=home,
        away=away,
        wall_time="20:00",
        match_date=match_date,
    )


def test_a_slug_folds_latin_accents_and_drops_the_dead_replacements() -> None:
    """The URL form of the names LiveSoccerTV prints, without its diacritics (B2-R1-8)."""
    assert team_slug("Atlético Madrid") == "atletico-madrid"
    assert team_slug("Fenerbahçe SK") == "fenerbahce-sk"
    assert team_slug("FC Bayern München") == "fc-bayern-munchen"
    # ``ar_normalize`` already turns the apostrophe and the period into spaces.
    assert team_slug("Tala'ea El Gaish") == "tala-ea-el-gaish"
    assert team_slug(None) == ""


def test_a_key_ignores_separators_accents_apostrophes_and_club_noise() -> None:
    assert team_key("atletico-madrid") == team_key("Atlético Madrid") == "atleticomadrid"
    assert team_key("cote-divoire") == team_key("Côte d'Ivoire") == "cotedivoire"
    assert team_key("bayern-munchen") == team_key("FC Bayern München") == "bayernmunchen"
    assert team_key("fenerbahce-sk") == team_key("Fenerbahçe SK") == "fenerbahce"
    assert team_key("tala-ea-el-gaish") == team_key("Tala'ea El Gaish") == "talaeaelgaish"


def test_an_accented_opponent_is_picked_by_the_match_url_slugs() -> None:
    """``atletico-madrid`` in the dictionary, ``Atlético Madrid`` on the page."""
    rows = [
        _row(
            "Atlético Madrid",
            "Valencia",
            "https://www.livesoccertv.com/match/atletico-madrid-vs-valencia/1bpms",
        )
    ]
    row = pick_match(rows, _target(home_slug="atletico-madrid", away_slug="valencia", country="spain"))
    assert row is not None and row.home == "Atlético Madrid"


def test_an_apostrophe_name_is_picked() -> None:
    """``cote-divoire`` in the dictionary, ``Côte d'Ivoire`` on the page."""
    rows = [
        _row(
            "Côte d'Ivoire",
            "Egypt",
            "https://www.livesoccertv.com/match/cote-divoire-vs-egypt/dd",
        )
    ]
    row = pick_match(rows, _target(home_slug="cote-divoire", away_slug="egypt", country="egypt"))
    assert row is not None and row.away == "Egypt"


def test_a_prefixed_and_suffixed_name_is_picked() -> None:
    """``bayern-munchen`` / ``fenerbahce-sk`` in the dictionary, ``FC …`` / ``… SK`` on the page."""
    rows = [
        _row(
            "Fenerbahçe SK",
            "FC Bayern München",
            "https://www.livesoccertv.com/match/bayern-munchen-vs-fenerbahce-sk/1abcd",
        )
    ]
    row = pick_match(
        rows,
        _target(home_slug="bayern-munchen", away_slug="fenerbahce-sk", country="germany"),
    )
    assert row is not None and row.away == "FC Bayern München"


def test_the_display_names_are_the_fallback_when_the_link_carries_no_slug_pair() -> None:
    rows = [_row("Tala'ea El Gaish", "Pyramids FC", None)]
    row = pick_match(
        rows,
        _target(home_slug="tala-ea-el-gaish", away_slug="pyramids-fc", country="egypt"),
    )
    assert row is not None and row.home == "Tala'ea El Gaish"


def test_a_folded_name_does_not_pick_another_club_of_the_same_day() -> None:
    """The folding must not make two different pairs equal (no guessing)."""
    rows = [
        _row(
            "Atlético Madrid",
            "Sevilla",
            "https://www.livesoccertv.com/match/atletico-madrid-vs-sevilla/1bbbb",
        )
    ]
    assert pick_match(rows, _target(home_slug="atletico-madrid", away_slug="valencia", country="spain")) is None
