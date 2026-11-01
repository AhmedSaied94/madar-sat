"""ysscores `parse`, pure and pinned to saved pages (T057, R16, FR-021)."""

from __future__ import annotations

import re
from datetime import date
from pathlib import Path

import pytest

from app.adapters.ysscores import LayoutChanged, YsscoresAdapter

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "ysscores"
NORMAL = FIXTURES / "2026-10-30.html"
POSTPONED = FIXTURES / "2026-10-31.html"
EMPTY = FIXTURES / "2026-11-11.html"

TBD_PAGE = """<!doctype html><html><body>
<div class="matches-wrapper" id="1" champ_title="كأس مصر"
     champ_img="https://imgs.ysscores.com/championship/1/cup.png">
  <a href="https://www.ysscores.com/ar/match/7000001/Al-Ahly-vs-Zamalek" title="دور الـ 16"
     home_name="الأهلي" away_name="الزمالك"
     home_image="https://imgs.ysscores.com/teams/1/a.png" away_image="https://imgs.ysscores.com/teams/2/b.png"
     match_id="7000001" data-status="0" class="ajax-match-item inline-match-item mb-row">
    <b class="match-date">--:--</b>
  </a>
</div>
</body></html>"""

# A finished match as the live page drew it on 2026-10-31: its `.match-date` holds the score
# instead of a time. Next to it, a fixture still to come; both carry `.match-with-result`.
FINISHED_PAGE = """<!doctype html><html><body>
<div class="matches-wrapper" id="1" champ_title="الدوري المصري"
     champ_img="https://imgs.ysscores.com/championship/1/league.png">
  <a href="https://www.ysscores.com/ar/match/7000002/Abo-Qir-vs-Ghazl-El-Mahalla" title="الجولة 12"
     home_name="أبو قير" away_name="غزل المحلة" match_id="7000002" data-status="4"
     class="ajax-match-item inline-match-item mb-row match-with-result">
    <div class="result-wrap">
      <span class="result-status-text">انتهت المباراة</span>
      <b class="match-date">
        <span class="first-team-result loser">0</span>
        <i>-</i>
        <span class="second-team-result winner">1</span>
      </b>
    </div>
  </a>
  <a href="https://www.ysscores.com/ar/match/7000003/Ceramica-vs-ZED" title="الجولة 12"
     home_name="سيراميكا" away_name="نادي زد" match_id="7000003" data-status="0"
     class="ajax-match-item inline-match-item mb-row match-with-result">
    <b class="match-date">08:00<i class="mb-meridiem">م</i></b>
  </a>
</div>
</body></html>"""


@pytest.fixture
def adapter() -> YsscoresAdapter:
    # No fetcher: parse must not need the network (T057).
    return YsscoresAdapter(fetcher=None)  # type: ignore[arg-type]


def _page(path: Path):
    """The page as ``fetch`` hands it over: its Cairo day in the URL fragment."""
    from app.adapters.base import RawPage

    day = path.stem  # 2026-10-30.html -> 2026-10-30
    return RawPage(url=f"https://www.ysscores.com/ar/match_date_to#{day}", status=200, body=path.read_bytes())


def test_each_wrapper_gives_its_competition_title_and_logo(adapter: YsscoresAdapter) -> None:
    items = adapter.parse(_page(NORMAL))
    assert len(items) == 38  # 53 anchors: 11 in play, 4 finished
    assert {item.competition for item in items} >= {"الدوري الفرنسي", "الدوري المصري"}
    lille = next(i for i in items if i.external_id == "5802974")
    assert lille.competition == "الدوري الفرنسي"
    assert lille.competition_logo == "https://imgs.ysscores.com/championship/48/9551719862665.png"


def test_each_item_gives_its_teams_logos_time_stage_and_ids(adapter: YsscoresAdapter) -> None:
    items = {item.external_id: item for item in adapter.parse(_page(NORMAL))}
    lille = items["5802974"]
    assert (lille.home, lille.away) == ("ليل", "لانس")
    assert lille.home_external_id == "8639"
    assert lille.away_external_id == "8588"
    assert lille.home_logo == "https://imgs.ysscores.com/teams/64/381690287334.png"
    assert lille.away_logo == "https://imgs.ysscores.com/teams/64/1281690287063.png"
    assert lille.wall_time == "10:05 م"  # the meridiem <i> is separated from the digits
    assert lille.match_date == date(2026, 10, 30)
    assert lille.stage == "الجولة 9"
    assert lille.url == "https://www.ysscores.com/ar/match/5802974/LOSC-Lille-vs-RC-Lens"


def test_the_pinned_kickoff_matches_the_readme(adapter: YsscoresAdapter) -> None:
    from app.adapters.base import NormalizedFixture

    item = next(i for i in adapter.parse(_page(NORMAL)) if i.external_id == "5802974")
    normalized = adapter.normalize(item)
    assert isinstance(normalized, NormalizedFixture)
    # 10:05 pm Cairo on 2026-10-30, after Egypt's DST ended: UTC+2 (README).
    assert normalized.kickoff_at is not None
    assert normalized.kickoff_at.isoformat() == "2026-10-30T20:05:00+00:00"
    assert normalized.time_tbd is False


def test_postponed_items_are_kept_without_a_kickoff(adapter: YsscoresAdapter) -> None:
    """B2-R1-10: the fixture stays, but its old time is not presented as fact."""
    items = adapter.parse(_page(POSTPONED))
    assert len(items) == 129
    postponed = [item for item in items if item.postponed]
    assert len(postponed) == 10  # `match-postponed` / `data-status="14"` with «تأجلت»

    normalized = [adapter.normalize(item) for item in postponed]
    assert all(item.kickoff_at is None and item.time_tbd is True for item in normalized)
    assert all(item.postponed for item in normalized)
    # Every other fixture keeps its time.
    assert all(item.postponed is False for item in items if item not in postponed)


def test_an_empty_day_gives_no_items_and_is_not_a_layout_change(adapter: YsscoresAdapter) -> None:
    assert adapter.parse(_page(EMPTY)) == []


def test_a_page_without_a_wrapper_is_a_layout_change(adapter: YsscoresAdapter) -> None:
    from app.adapters.base import RawPage

    page = RawPage(
        url="https://www.ysscores.com/ar/match_date_to#2026-10-30",
        status=200,
        body=b"<html><body>blocked</body></html>",
    )
    with pytest.raises(LayoutChanged):
        adapter.parse(page)


def test_matches_in_play_are_not_fixtures_and_are_skipped(adapter: YsscoresAdapter) -> None:
    items = adapter.parse(_page(NORMAL))
    # Of the page's 53 anchors, 11 are in play (no .match-date) and 4 finished (a .match-date holding
    # the score). Importing one with no kickoff would wipe the kickoff already stored for it, so parse
    # drops them; what is left is a time, never a score.
    assert len(items) == 38
    assert all(re.fullmatch(r"\d{1,2}:\d{2} [صم]", item.wall_time or "") for item in items)


def test_finished_matches_showing_their_score_are_skipped(adapter: YsscoresAdapter) -> None:
    """A finished match keeps its `.match-date`, filled with the score. Read as a time it has none,
    and the upsert would wipe the kickoff already stored for it (58 matches on 2026-10-31)."""
    from app.adapters.base import RawPage

    page = RawPage(url="https://www.ysscores.com/ar/match_date_to#2026-10-31", status=200, body=FINISHED_PAGE.encode())
    (item,) = adapter.parse(page)
    assert item.external_id == "7000003"
    assert item.wall_time == "08:00 م"


def test_the_unknown_time_marker_parses(adapter: YsscoresAdapter) -> None:
    from app.adapters.base import RawPage

    page = RawPage(url="https://www.ysscores.com/ar/match_date_to#2026-10-31", status=200, body=TBD_PAGE.encode())
    (item,) = adapter.parse(page)
    assert item.wall_time == "--:--"
    normalized = adapter.normalize(item)
    assert normalized.time_tbd is True
    assert normalized.kickoff_at is None


def test_parse_makes_no_network_database_or_clock_call(adapter: YsscoresAdapter, monkeypatch) -> None:
    import socket
    import time as clock

    def boom(*args, **kwargs):
        raise AssertionError("parse must be pure")

    monkeypatch.setattr(socket, "create_connection", boom)
    monkeypatch.setattr(clock, "time", boom)
    first = adapter.parse(_page(NORMAL))
    second = adapter.parse(_page(NORMAL))
    assert first == second
