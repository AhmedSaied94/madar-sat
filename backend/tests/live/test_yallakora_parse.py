"""YallaKora's parsers on saved finished and scheduled pages (T023). The capture adds live pages (T021)."""

from __future__ import annotations

from datetime import UTC, date, datetime
from pathlib import Path

import pytest

from app.live.sources import yallakora
from app.live.types import LayoutChanged, Score

FIXTURES = Path(__file__).parent / "fixtures"
TODAY = date(2026, 11, 4)


def _page(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


def test_the_list_reads_finished_and_scheduled_rows():
    rows = yallakora.parse_list(_page("yallakora_list.html"), today=TODAY)
    statuses = {row.status for row in rows}
    assert statuses == {"finished", "scheduled"}

    scheduled = next(row for row in rows if row.status == "scheduled")
    assert scheduled.external_id == "114019"
    assert (scheduled.home, scheduled.away) == ("غزل المحلة", "الاتحاد السكندري")
    assert scheduled.score is None
    assert scheduled.competition == "كأس مصر"
    assert scheduled.kickoff_at == datetime(2026, 11, 4, 15, 0, tzinfo=UTC)
    assert scheduled.page_path.startswith("/egypt-cup/3066/match/114019/")
    assert "#" not in scheduled.page_path

    finished = next(row for row in rows if row.external_id == "113207")
    assert finished.score == Score(1, 0)
    assert finished.status_label == "انتهت"
    assert finished.events is None


def test_a_finished_page_has_status_and_score():
    reading = yallakora.parse_match(_page("yallakora_match_finished.html"), external_id="113207")

    assert reading.status == "finished"
    assert reading.score == Score(1, 0)
    assert (reading.home, reading.away) == ("القناة", "مودرن سبورت")
    assert reading.kickoff_at == datetime(2026, 11, 3, 15, 0, tzinfo=UTC)
    assert reading.lineups is None


def test_a_scheduled_page_has_no_status_line_and_no_score():
    reading = yallakora.parse_match(_page("yallakora_match_scheduled.html"), external_id="114019")

    assert (reading.status, reading.score) == ("scheduled", None)
    assert reading.kickoff_at == datetime(2026, 11, 4, 15, 0, tzinfo=UTC)


def test_arabic_indic_digits_become_western():
    page = _page("yallakora_list.html").decode().replace('<span class="score">1</span>', '<span class="score">١</span>')

    finished = next(row for row in yallakora.parse_list(page.encode(), today=TODAY) if row.external_id == "113207")

    assert finished.score == Score(1, 0)


def test_an_unknown_status_fails_validation():
    page = _page("yallakora_list.html").decode().replace("لم تبدأ", "الشوط الأول").encode()

    with pytest.raises(LayoutChanged):
        yallakora.parse_list(page, today=TODAY)


def test_a_missing_field_fails_validation():
    page = _page("yallakora_list.html").decode().replace('class="matchStatus"', 'class="other"').encode()

    with pytest.raises(LayoutChanged):
        yallakora.parse_list(page, today=TODAY)


def test_a_finished_row_without_a_score_fails_validation():
    page = _page("yallakora_list.html").decode().replace('<span class="score">1</span>', '<span class="score">-</span>')

    with pytest.raises(LayoutChanged):
        yallakora.parse_list(page.encode(), today=TODAY)


@pytest.mark.parametrize("body", [b"", b"  ", b"<html><body>Just a moment...</body></html>"])
def test_a_blocked_page_or_an_empty_body_fails(body):
    with pytest.raises(LayoutChanged):
        yallakora.parse_list(body, today=TODAY)
    with pytest.raises(LayoutChanged):
        yallakora.parse_match(body, external_id="1")


def test_a_list_with_no_rows_is_valid_and_empty():
    assert (
        yallakora.parse_list(b'<html><body><section class="matchesCenter"></section></body></html>', today=TODAY) == []
    )
