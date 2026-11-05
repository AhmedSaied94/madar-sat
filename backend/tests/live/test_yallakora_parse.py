"""YallaKora's parsers on saved pages: finished, scheduled and, from the 2026-11-04 capture, live (031 T003)."""

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


@pytest.mark.parametrize(
    ("label", "state"),
    [
        ("الشوط الأول", ("live", "1H")),
        ("استراحة", ("halftime", None)),
        ("الشوط الثاني", ("live", "2H")),
        ("انتهت", ("finished", None)),
        ("لم تبدأ", ("scheduled", None)),
    ],
)
def test_the_list_reads_every_status_the_capture_saw(label, state):
    rows = {row.status_label: row for row in yallakora.parse_list(_page("yallakora_list_live.html"), today=TODAY)}

    row = rows[label]
    assert (row.status, row.period) == state
    assert row.unknown_status is None
    assert row.minute is None
    assert row.page_path.startswith("/")


def test_a_live_row_has_its_score_and_kickoff():
    rows = {row.external_id: row for row in yallakora.parse_list(_page("yallakora_list_live.html"), today=TODAY)}

    assert rows["114215"].score == Score(0, 0)
    assert (rows["114215"].home, rows["114215"].away) == ("سلافيا براج", "أرسنال")
    assert rows["114215"].kickoff_at == datetime(2026, 11, 4, 20, 0, tzinfo=UTC)
    assert rows["113860"].score == Score(1, 1)
    assert (rows["113860"].status, rows["113860"].period) == ("live", "2H")


def test_mubashir_on_a_live_match_page_is_live_with_no_half():
    reading = yallakora.parse_match(_page("yallakora_match_live.html"), external_id="112558")

    assert (reading.status, reading.period, reading.minute) == ("live", None, None)
    assert reading.status_label == "مباشر"
    assert reading.score == Score(1, 1)
    assert reading.unknown_status is None
    assert reading.home and reading.away


def _with_unknown_row(label: str) -> bytes:
    return (
        _page("yallakora_list_live.html")
        .decode()
        .replace("<span>الشوط الثاني</span>", f"<span>{label}</span>")
        .encode()
    )


def test_an_unknown_status_on_a_list_row_keeps_its_score_and_nothing_else():
    rows = {row.external_id: row for row in yallakora.parse_list(_with_unknown_row("شوط إضافي"), today=TODAY)}

    row = rows["113860"]
    assert row.unknown_status == "شوط إضافي"
    assert (row.status, row.period, row.minute) == (None, None, None)
    assert row.score == Score(1, 1)
    assert (row.home, row.away) == ("ايك اثينا", "ريال مدريد")


def test_an_unknown_status_on_a_list_row_leaves_the_other_rows_alone():
    rows = {row.external_id: row for row in yallakora.parse_list(_with_unknown_row("شوط إضافي"), today=TODAY)}

    others = [row for external_id, row in rows.items() if external_id != "113860"]
    assert len(others) == 4
    assert all(row.unknown_status is None and row.status is not None for row in others)


def test_an_unknown_status_with_no_score_gives_a_row_with_no_score():
    page = _page("yallakora_list_live.html").decode().replace("لم تبدأ", "شوط إضافي").encode()

    row = next(row for row in yallakora.parse_list(page, today=TODAY) if row.unknown_status)

    assert row.score is None
    assert row.status is None


def test_an_unknown_status_on_a_match_page_keeps_its_score_and_nothing_else():
    page = _page("yallakora_match_live.html").decode().replace(">مباشر<", ">ركلات الترجيح<").encode()

    reading = yallakora.parse_match(page, external_id="112558")

    assert reading.unknown_status == "ركلات الترجيح"
    assert (reading.status, reading.period, reading.minute) == (None, None, None)
    assert reading.score == Score(1, 1)


def test_a_page_with_no_match_center_still_stops_the_source():
    with pytest.raises(LayoutChanged):
        yallakora.parse_list(b"<html><body><section class='other'></section></body></html>", today=TODAY)


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
