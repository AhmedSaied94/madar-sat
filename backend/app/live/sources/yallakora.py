"""YallaKora, the cross-check: its list page and match page (SD §6.7, research R1, R3).

Lineups stay out of reach (``*/Match/Matchsquad2`` is in ``robots.txt``), so this source gives status
and score. Status strings come from saved pages; any other fails validation until the capture adds it.
"""

from __future__ import annotations

from datetime import date
from typing import Any
from urllib.parse import urlsplit

from app.live.sources.common import (
    cairo_kickoff,
    clean,
    first,
    pair,
    parse_document,
    require_name,
    require_score,
    score_part,
    text_of,
    western,
)
from app.live.types import LayoutChanged, SourceReading

SOURCE = "yallakora"
HOST = "www.yallakora.com"
LIST_PATH = "/matches-center"

STATUS_MAP: dict[str, tuple[str, str | None]] = {
    "لم تبدأ": ("scheduled", None),
    "انتهت": ("finished", None),
    "تأجيل": ("postponed", None),
}
_MONTHS = {
    "يناير": 1,
    "فبراير": 2,
    "مارس": 3,
    "أبريل": 4,
    "ابريل": 4,
    "مايو": 5,
    "يونيو": 6,
    "يوليو": 7,
    "أغسطس": 8,
    "اغسطس": 8,
    "سبتمبر": 9,
    "أكتوبر": 10,
    "اكتوبر": 10,
    "نوفمبر": 11,
    "ديسمبر": 12,
}


def _status(name: str) -> tuple[str, str | None]:
    state = STATUS_MAP.get(clean(name))
    if state is None:
        raise LayoutChanged(f"yallakora: unknown status {clean(name)[:40]!r}")
    return state


def _team(row: Any, side: str) -> str:
    return require_name(text_of(first(row.xpath(f".//*[contains(@class, '{side}')][1]//p"))), side)


def parse_list(body: bytes, *, today: date) -> list[SourceReading]:
    """Every match row. ``today`` is the Cairo date the page shows: a row holds only a clock time."""
    doc = parse_document(body, SOURCE)
    if not doc.xpath("//*[contains(concat(' ', normalize-space(@class), ' '), ' matchesCenter ')]"):
        raise LayoutChanged("yallakora: no match center on the page")
    found: dict[str, SourceReading] = {}
    for row in doc.xpath("//*[@livescorematchid]"):
        external_id = row.get("livescorematchid") or ""
        if external_id and external_id not in found:
            found[external_id] = _list_row(row, external_id, today)
    return list(found.values())


def _list_row(row: Any, external_id: str, today: date) -> SourceReading:
    label = text_of(first(row.xpath(".//*[contains(@class, 'matchStatus')]")))
    status, period = _status(require_name(label, "status"))
    parts = row.xpath(".//*[contains(@class, 'MResult')]//span[contains(@class, 'score')]")
    if len(parts) != 2:
        raise LayoutChanged("yallakora: a row without its two scores")
    score = pair(score_part(parts[0].text_content()), score_part(parts[1].text_content()))
    require_score(status, score)
    card = first(row.xpath("ancestor::*[contains(@class, 'matchCard')][1]"))
    competition = text_of(first(card.xpath(".//*[contains(@class, 'tourTitle')]//h2"))) if card is not None else ""
    link = first(row.xpath(".//a/@href"))
    return SourceReading(
        source=SOURCE,
        external_id=external_id,
        home=_team(row, "teamA"),
        away=_team(row, "teamB"),
        competition=competition or None,
        kickoff_at=cairo_kickoff(
            today, text_of(first(row.xpath(".//*[contains(@class, 'MResult')]//*[@class='time']")))
        ),
        status=status,
        period=period,
        minute=None,
        score=score,
        status_label=label,
        page_path=urlsplit(link).path if link else None,
    )


def _page_day(text: str) -> date | None:
    """``03 نوفمبر 2026``."""
    parts = western(clean(text)).split(" ")
    if len(parts) != 3 or parts[1] not in _MONTHS or not parts[0].isdigit() or not parts[2].isdigit():
        return None
    return date(int(parts[2]), _MONTHS[parts[1]], int(parts[0]))


def parse_match(body: bytes, *, external_id: str) -> SourceReading:
    """A match page's header. A match that hasn't started has no status line, only its date and time."""
    doc = parse_document(body, SOURCE)
    info = first(doc.xpath("//*[contains(concat(' ', normalize-space(@class), ' '), ' matchScoreInfo ')]"))
    if info is None:
        raise LayoutChanged("yallakora: no match header on the page")
    header = info.getparent()
    label = text_of(first(header.xpath(".//p[contains(concat(' ', normalize-space(@class), ' '), ' status ')]")))
    day = _page_day(text_of(first(header.xpath(".//*[contains(@class, 'matchDateInfo')]//*[@class='date']"))))
    if not label and day is None:
        raise LayoutChanged("yallakora: a match page with neither a status nor a date")
    status, period = _status(label) if label else ("scheduled", None)
    home = first(info.xpath(".//*[contains(@class, 'result')]//*[@class='a']"))
    away = first(info.xpath(".//*[contains(@class, 'result')]//*[@class='b']"))
    score = pair(
        score_part(home.text_content()) if home is not None else None,
        score_part(away.text_content()) if away is not None else None,
    )
    require_score(status, score)
    clock = text_of(first(header.xpath(".//*[contains(@class, 'matchDateInfo')]//*[@class='time']")))
    return SourceReading(
        source=SOURCE,
        external_id=external_id,
        home=require_name(text_of(first(info.xpath(".//*[contains(@class, 'teamA')][1]//p"))), "home team"),
        away=require_name(text_of(first(info.xpath(".//*[contains(@class, 'teamB')][1]//p"))), "away team"),
        competition=text_of(first(header.xpath(".//*[contains(@class, 'tourNameBtn')][1]/a[1]"))) or None,
        kickoff_at=cairo_kickoff(day, clock) if day is not None else None,
        status=status,
        period=period,
        minute=None,
        score=score,
        status_label=label or None,
    )
