"""The YallaKora adapter: one list page per Cairo day, a pure parse (D5 T055, FR-020).

Each match on ``/matches-center`` is a ``[liveScoreMatchId]`` card inside a ``.matchCard``: the channel,
the stage, both team names and a kickoff on the site's 24-hour Cairo clock. The adapter imports
fixtures and the Egyptian broadcaster only. The card's status and score belong to the live poller
(``app/live/``), so neither is read here, except that a postponed card has no kickoff any more.

Only list URLs are requested: ``/matches-center?date=YYYY-MM-DD`` matches no rule in the site's
``robots.txt`` (research R4), and the host is the shared ``www.yallakora.com`` bucket (R3).
"""

from __future__ import annotations

import re
from datetime import date
from typing import TYPE_CHECKING
from urllib.parse import parse_qs, urljoin, urlsplit, urlunsplit

from lxml import html as lxml_html  # type: ignore[import-untyped]
from lxml.html import HtmlElement  # type: ignore[import-untyped]

from app.adapters.base import (
    DateWindow,
    LayoutChanged,
    NormalizedFixture,
    ParsedFixture,
    RawPage,
    normalize_fixture,
)

if TYPE_CHECKING:  # the fetch path's HTTP client; importing it here would drag in app.workers
    from app.adapters.fetcher import HttpFetcher

BASE_URL = "https://www.yallakora.com"
LIST_URL = f"{BASE_URL}/matches-center"
ALLOWED_HOSTS = frozenset({"www.yallakora.com"})
# The page's own text on a day with no fixtures; anything else with no cards is a layout change.
NO_MATCHES_TEXT = "لا يوجد مباريات"
POSTPONED_TEXT = "تأجيل"

_CLOCK = re.compile(r"^(\d{1,2}):(\d{2})$")


def _has_class(element: HtmlElement, cls: str) -> bool:
    return cls in (element.get("class") or "").split()


def _with_class(root: HtmlElement, cls: str) -> list[HtmlElement]:
    return [el for el in root.iterdescendants() if isinstance(el.tag, str) and _has_class(el, cls)]


def _text(element: HtmlElement | None) -> str:
    return " ".join(element.text_content().split()) if element is not None else ""


def _first_text(root: HtmlElement, cls: str) -> str:
    return _text(next(iter(_with_class(root, cls)), None))


def _team_name(card: HtmlElement, cls: str) -> str:
    side = next(iter(_with_class(card, cls)), None)
    return _text(next(side.iter("p"), None)) if side is not None else ""


def _marked_wall_time(clock: str) -> str | None:
    """``"09:30"`` -> ``"09:30 ص"``, or ``None`` when the card holds no clock.

    The site's clock is 24-hour, and the shared parser reads an unmarked 1–11 as PM (the old app's
    rule), so the marker has to be explicit or a morning kickoff moves twelve hours.
    """
    match = _CLOCK.match(clock)
    if match is None:
        return None
    hour, minute = int(match.group(1)), int(match.group(2))
    if hour > 23 or minute > 59:
        return None
    return f"{hour % 12 or 12:02d}:{minute:02d} {'ص' if hour < 12 else 'م'}"


def _absolute_url(href: str | None) -> str | None:
    """The match link without its fragment, which only scrolls the page."""
    if not href:
        return None
    parts = urlsplit(urljoin(BASE_URL, href))
    return urlunsplit((parts.scheme, parts.netloc, parts.path, parts.query, ""))


def day_of(url: str) -> date:
    """The Cairo day a page answers, from its ``date`` parameter (set by ``fetch``)."""
    values = parse_qs(urlsplit(url).query).get("date", [])
    try:
        return date.fromisoformat(values[0])
    except (IndexError, ValueError) as exc:  # pragma: no cover - a caller bug, not a page problem
        raise ValueError(f"the page URL must carry ?date=YYYY-MM-DD, got {url!r}") from exc


class YallakoraAdapter:
    name = "yallakora"
    allowed_hosts = ALLOWED_HOSTS

    def __init__(self, fetcher: HttpFetcher | None) -> None:
        self.fetcher = fetcher
        # The pages fetched so far: the fetch task saves them when a later day fails.
        self.pages: list[RawPage] = []

    # --- fetch ---------------------------------------------------------------------------

    def fetch(self, window: DateWindow) -> list[RawPage]:
        if self.fetcher is None:
            raise RuntimeError("the yallakora adapter needs a fetcher to fetch")
        pages: list[RawPage] = []
        self.pages = pages
        for day in window:
            url = f"{LIST_URL}?date={day.isoformat()}"
            page = self.fetcher.get(url, allowed_hosts=self.allowed_hosts)
            pages.append(
                RawPage(
                    url=url,
                    status=page.status,
                    body=page.body,
                    content_type=page.content_type,
                    fetched_at=page.fetched_at,
                )
            )
        return pages

    # --- parse (pure) --------------------------------------------------------------------

    def parse(self, page: RawPage) -> list[ParsedFixture]:
        if not page.body.strip():
            raise LayoutChanged("the response is empty")
        doc = lxml_html.fromstring(page.body.decode("utf-8", errors="replace"))
        lists = [el for el in _with_class(doc, "matchCard") if _has_class(el, "matchesList")]
        if not lists:
            if NO_MATCHES_TEXT in doc.text_content():
                return []
            raise LayoutChanged("the page has no .matchCard.matchesList")
        day = day_of(page.url)
        items: list[ParsedFixture] = []
        for match_list in lists:
            competition = _text(next(match_list.iter("h2"), None)) or None
            cards = [
                el for el in match_list.iterdescendants() if isinstance(el.tag, str) and el.get("livescorematchid")
            ]
            if not cards:
                raise LayoutChanged("a .matchCard has no [liveScoreMatchId] cards")
            for card in cards:
                item = _fixture(card, competition, day)
                if item is not None:
                    items.append(item)
        return items

    # --- normalize -----------------------------------------------------------------------

    def normalize(self, item: ParsedFixture) -> NormalizedFixture:
        return normalize_fixture(item)


def _fixture(card: HtmlElement, competition: str | None, day: date) -> ParsedFixture | None:
    home = _team_name(card, "teamA")
    away = _team_name(card, "teamB")
    if not home or not away:
        raise LayoutChanged(f"card {card.get('livescorematchid')} has no team names")
    postponed = POSTPONED_TEXT in _first_text(card, "matchStatus")
    wall_time = _marked_wall_time(_first_text(card, "time"))
    if wall_time is None and not postponed:
        # A card with no clock, such as one showing a minute: importing it would wipe the stored
        # kickoff, and it says nothing a fixture needs (the same rule as ysscores' live anchors).
        return None
    anchor = next(card.iter("a"), None)
    return ParsedFixture(
        external_id=card.get("livescorematchid"),
        url=_absolute_url(anchor.get("href") if anchor is not None else None),
        competition=competition,
        stage=_first_text(card, "date") or None,
        home=home,
        away=away,
        wall_time=wall_time or "",
        match_date=day,
        postponed=postponed,
        local_broadcaster_eg=_first_text(card, "channel") or None,
    )
