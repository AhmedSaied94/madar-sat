"""YallaKora: a pure parse pinned to saved pages, and the fetch's URLs (D5 T049, T055, FR-020)."""

from __future__ import annotations

from datetime import UTC, date, datetime
from pathlib import Path

import pytest

from app.adapters.base import DateWindow, LayoutChanged, ParsedFixture, RawPage, SourceAdapter
from app.adapters.yallakora import LIST_URL, YallakoraAdapter

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "yallakora"


def page(day: str, body: bytes | None = None) -> RawPage:
    data = (FIXTURES / f"{day}.html").read_bytes() if body is None else body
    return RawPage(url=f"{LIST_URL}?date={day}", status=200, body=data)


def scheduled_body() -> str:
    return (FIXTURES / "2026-11-04.html").read_text(encoding="utf-8")


def adapter() -> YallakoraAdapter:
    return YallakoraAdapter(fetcher=None)


def by_id(items: list[ParsedFixture]) -> dict[str | None, ParsedFixture]:
    return {item.external_id: item for item in items}


def test_the_adapter_implements_the_protocol_on_the_one_host() -> None:
    assert isinstance(adapter(), SourceAdapter)
    assert adapter().name == "yallakora"
    assert adapter().allowed_hosts == frozenset({"www.yallakora.com"})


def test_a_scheduled_page_gives_every_match_with_its_fields() -> None:
    items = adapter().parse(page("2026-11-04"))

    assert len(items) == 16
    first = by_id(items)["114019"]  # liveScoreMatchId is the external id
    assert first.competition == "كأس مصر"
    assert first.stage == "دور الـ 32"
    assert first.home == "غزل المحلة"
    assert first.away == "الاتحاد السكندري"
    assert first.local_broadcaster_eg == "ON Sport MAX"
    assert first.match_date == date(2026, 11, 4)
    assert first.url is not None
    assert first.url.startswith("https://www.yallakora.com/egypt-cup/3066/match/114019/")
    assert "#" not in first.url
    assert first.postponed is False


def test_a_match_with_no_channel_has_no_broadcaster() -> None:
    assert by_id(adapter().parse(page("2026-11-04")))["112558"].local_broadcaster_eg is None


def test_cairo_wall_clock_becomes_utc() -> None:
    parser = adapter()
    item = by_id(parser.parse(page("2026-11-04")))["114019"]  # 17:00 in Cairo, UTC+2 in November

    normal = parser.normalize(item)

    assert normal.kickoff_at == datetime(2026, 11, 4, 15, 0, tzinfo=UTC)
    assert normal.time_tbd is False
    assert normal.local_broadcaster_eg == "ON Sport MAX"


@pytest.mark.parametrize(
    ("wall", "expected"),
    [
        # The shared parser reads an unmarked 1–11 as PM, which is the old app's rule. The site's
        # clock is 24-hour, so a morning kickoff must not move twelve hours.
        ("09:30", datetime(2026, 11, 4, 7, 30, tzinfo=UTC)),
        ("12:00", datetime(2026, 11, 4, 10, 0, tzinfo=UTC)),
        ("00:30", datetime(2026, 11, 3, 22, 30, tzinfo=UTC)),
        ("23:15", datetime(2026, 11, 4, 21, 15, tzinfo=UTC)),
    ],
)
def test_the_site_clock_is_read_as_24_hours(wall: str, expected: datetime) -> None:
    body = scheduled_body().replace('<span class="time">17:00</span>', f'<span class="time">{wall}</span>')
    parser = adapter()

    item = by_id(parser.parse(page("2026-11-04", body.encode())))["114019"]

    assert parser.normalize(item).kickoff_at == expected


def test_a_finished_page_keeps_the_kickoff_and_writes_no_status_or_score() -> None:
    parser = adapter()

    items = parser.parse(page("2026-11-03"))

    assert items
    assert parser.normalize(by_id(items)["113207"]).kickoff_at == datetime(2026, 11, 3, 15, 0, tzinfo=UTC)
    fields = set(ParsedFixture.model_fields)
    assert not fields & {"status", "period", "minute", "score", "home_score", "away_score"}


def test_a_match_showing_no_clock_is_skipped_so_its_kickoff_survives() -> None:
    """A live card may hold a minute in place of the time: importing it would clear the kickoff."""
    body = scheduled_body().replace('<span class="time">17:00</span>', '<span class="time">45\'</span>')

    items = by_id(adapter().parse(page("2026-11-04", body.encode())))

    assert "114019" not in items
    assert "113205" not in items  # the same 17:00 on another card
    assert "113208" in items  # 20:00 is untouched


def test_a_postponed_match_keeps_the_fixture_with_no_kickoff() -> None:
    parser = adapter()
    head, tail = scheduled_body().split('liveScoreMatchId="114019"', 1)
    body = head + 'liveScoreMatchId="114019"' + tail.replace("<span>لم تبدأ</span>", "<span>تأجيل</span>", 1)

    item = by_id(parser.parse(page("2026-11-04", body.encode())))["114019"]

    assert item.postponed is True
    normal = parser.normalize(item)
    assert normal.kickoff_at is None
    assert normal.time_tbd is True


def test_competition_and_stage_text_are_cleaned() -> None:
    parser = adapter()
    head, tail = scheduled_body().split('liveScoreMatchId="114019"', 1)
    body = head + 'liveScoreMatchId="114019"' + tail.replace("دور الـ 32", "دور الـ 32   دور الـ 32", 1)

    normal = parser.normalize(by_id(parser.parse(page("2026-11-04", body.encode())))["114019"])

    assert normal.stage == "دور الـ 32"
    assert normal.competition == "كأس مصر"


def test_a_no_matches_day_returns_nothing() -> None:
    assert adapter().parse(page("2027-07-21")) == []


@pytest.mark.parametrize(
    "body",
    [
        b"",
        b"   ",
        b"<!doctype html><html><head><title>Just a moment...</title></head><body></body></html>",
    ],
)
def test_a_page_with_no_match_list_is_a_layout_change(body: bytes) -> None:
    with pytest.raises(LayoutChanged):
        adapter().parse(page("2026-11-04", body))


def test_a_match_card_that_lost_its_team_names_is_a_layout_change() -> None:
    body = scheduled_body().replace('class="teams teamA"', 'class="side"').replace('class="teams teamB"', 'class="s"')

    with pytest.raises(LayoutChanged):
        adapter().parse(page("2026-11-04", body.encode()))


def test_a_match_list_that_lost_its_ids_is_a_layout_change() -> None:
    body = scheduled_body().replace("liveScoreMatchId=", "data-id=")

    with pytest.raises(LayoutChanged):
        adapter().parse(page("2026-11-04", body.encode()))


class RecordingFetcher:
    def __init__(self) -> None:
        self.urls: list[str] = []
        self.hosts: list[frozenset[str]] = []

    def get(
        self,
        url: str,
        allowed_hosts: frozenset[str],
        params: dict[str, str] | None = None,
        headers: dict[str, str] | None = None,
    ) -> RawPage:
        self.urls.append(url)
        self.hosts.append(allowed_hosts)
        return RawPage(url=url, status=200, body=b"<html></html>")


def test_fetch_asks_for_one_list_page_per_day_on_allowed_urls_only() -> None:
    fetcher = RecordingFetcher()
    subject = YallakoraAdapter(fetcher=fetcher)  # type: ignore[arg-type]

    pages = subject.fetch(DateWindow.next_days(today=date(2026, 11, 4), span=2))

    assert fetcher.urls == [
        "https://www.yallakora.com/matches-center?date=2026-11-04",
        "https://www.yallakora.com/matches-center?date=2026-11-05",
    ]
    assert fetcher.hosts == [frozenset({"www.yallakora.com"})] * 2
    assert [p.url for p in pages] == fetcher.urls
    assert subject.pages == list(pages)
    # robots.txt forbids `/*?*?*`, so a list URL has one `?` and nothing else to match a rule.
    assert all(url.count("?") == 1 for url in fetcher.urls)


def test_fetch_needs_a_fetcher() -> None:
    with pytest.raises(RuntimeError):
        adapter().fetch(DateWindow.next_days(today=date(2026, 11, 4), span=1))


def test_the_parser_is_pure() -> None:
    """Twice the same page, no fetcher, no database, no clock: the same fixtures."""
    assert adapter().parse(page("2026-11-04")) == adapter().parse(page("2026-11-04"))
