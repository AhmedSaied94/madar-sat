"""ysscores `fetch`/`normalize`: the form body, Cairo→UTC, placeholders, logos (T058, R16)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

import pytest

from app.adapters.base import DateWindow, NormalizedFixture, ParsedFixture
from app.adapters.ysscores import YsscoresAdapter


class RecordingFetcher:
    """Stands in for HttpFetcher: records each POST and returns a page per call."""

    def __init__(self) -> None:
        self.calls: list[tuple[str, dict[str, str]]] = []

    def post(
        self,
        url: str,
        data: dict[str, str],
        allowed_hosts: frozenset[str],
        headers: dict[str, str] | None = None,
    ):
        from app.adapters.base import RawPage

        self.calls.append((url, data))
        assert allowed_hosts == frozenset({"www.ysscores.com"})
        return RawPage(url=url, status=200, body=b'<div class="matches-wrapper"></div>')


def _item(**overrides: Any) -> ParsedFixture:
    fields: dict[str, Any] = {
        "external_id": "1",
        "url": "https://www.ysscores.com/ar/match/1/x",
        "competition": "الدوري المصري",
        "competition_logo": "",
        "stage": "الجولة 1",
        "home": "الأهلي",
        "away": "الزمالك",
        "home_logo": "",
        "away_logo": "",
        "home_external_id": None,
        "away_external_id": None,
        "wall_time": "10:00 م",
        "match_date": date(2026, 10, 30),
    }
    fields.update(overrides)
    return ParsedFixture(**fields)


def test_the_form_body_is_the_english_month_with_no_space_after_the_comma() -> None:
    fetcher = RecordingFetcher()
    adapter = YsscoresAdapter(fetcher=fetcher)  # type: ignore[arg-type]
    adapter.fetch(DateWindow(days=(date(2026, 10, 31),)))
    assert fetcher.calls == [
        (
            "https://www.ysscores.com/ar/match_date_to",
            {"get_date": "October 31,2026"},
        )
    ]


def test_one_post_per_cairo_day_today_to_plus_three() -> None:
    fetcher = RecordingFetcher()
    adapter = YsscoresAdapter(fetcher=fetcher)  # type: ignore[arg-type]
    window = DateWindow.next_days(today=date(2026, 10, 30))
    adapter.fetch(window)
    assert [data["get_date"] for _, data in fetcher.calls] == [
        "October 30,2026",
        "October 31,2026",
        "November 1,2026",
        "November 2,2026",
    ]


class TestCairoToUtc:
    adapter = YsscoresAdapter(fetcher=None)  # type: ignore[arg-type]

    @pytest.mark.parametrize(
        ("match_date", "expected"),
        [
            (date(2026, 4, 23), "2026-04-23T20:00:00+00:00"),  # last day of +2
            (date(2026, 4, 24), "2026-04-24T19:00:00+00:00"),  # DST starts
            (date(2026, 10, 29), "2026-10-29T19:00:00+00:00"),  # last day of +3
            (date(2026, 10, 30), "2026-10-30T20:00:00+00:00"),  # DST ends
        ],
    )
    def test_across_both_2026_dst_changes(self, match_date: date, expected: str) -> None:
        normalized = self.adapter.normalize(_item(match_date=match_date, wall_time="10:00 م"))
        assert normalized.kickoff_at == datetime.fromisoformat(expected)
        assert normalized.time_tbd is False


def test_the_unknown_time_sets_time_tbd_and_no_kickoff() -> None:
    normalized = YsscoresAdapter(fetcher=None).normalize(_item(wall_time="--:--"))  # type: ignore[arg-type]
    assert normalized.time_tbd is True
    assert normalized.kickoff_at is None


@pytest.mark.parametrize("placeholder", ["", "   ", "⚽", "غير مدرج", "«غير مدرج»", "-"])
def test_placeholders_become_none(placeholder: str) -> None:
    normalized = YsscoresAdapter(fetcher=None).normalize(  # type: ignore[arg-type]
        _item(home=placeholder, away=placeholder, stage=placeholder, competition=placeholder)
    )
    assert normalized.home is None
    assert normalized.away is None
    assert normalized.stage is None
    assert normalized.competition is None


def test_doubled_stage_text_is_cleaned() -> None:
    adapter = YsscoresAdapter(fetcher=None)  # type: ignore[arg-type]
    assert adapter.normalize(_item(stage="الجولة 12 الجولة 12")).stage == "الجولة 12"
    assert adapter.normalize(_item(stage="الجولة 12  /  الجولة 12")).stage == "الجولة 12"
    assert adapter.normalize(_item(stage="نصف النهائي  نصف النهائي")).stage == "نصف النهائي"


def test_logo_urls_are_kept_only_from_an_allowlisted_host() -> None:
    adapter = YsscoresAdapter(fetcher=None)  # type: ignore[arg-type]
    normalized = adapter.normalize(
        _item(
            home_logo="https://imgs.ysscores.com/teams/64/a.png",
            away_logo="https://evil.example/b.png",
            competition_logo="https://imgs.ysscores.com/championship/48/c.png",
        )
    )
    assert normalized.home_logo == "https://imgs.ysscores.com/teams/64/a.png"
    assert normalized.away_logo is None
    assert normalized.competition_logo == "https://imgs.ysscores.com/championship/48/c.png"


def test_names_keep_their_text_but_lose_the_extra_whitespace() -> None:
    normalized = YsscoresAdapter(fetcher=None).normalize(  # type: ignore[arg-type]
        _item(home="  الأهلي   المصري ", away="الزمالك")
    )
    assert normalized.home == "الأهلي المصري"
    assert normalized.away == "الزمالك"


def test_a_fixture_never_carries_a_status_or_a_score() -> None:
    normalized = YsscoresAdapter(fetcher=None).normalize(_item())  # type: ignore[arg-type]
    assert isinstance(normalized, NormalizedFixture)
    assert not hasattr(normalized, "status")
    assert not hasattr(normalized, "home_score")
    assert set(NormalizedFixture.__dataclass_fields__).isdisjoint({"status", "home_score", "away_score"})
