"""Finding the match page from the team page: Cairo date and opponent (T054, R14)."""

from __future__ import annotations

from datetime import UTC, date, datetime

from app.adapters.livesoccertv import LivesoccertvAdapter, LivesoccertvTarget, pick_match
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
