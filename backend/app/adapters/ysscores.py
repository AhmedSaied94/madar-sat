"""The ysscores adapter: one POST per Cairo day, a pure parse, and normalization (T071, R16).

Ported from ``../old_app/public/IMPORT.html`` (`ysFetchDay`, `parseYSDay`). The site puts every
value in attributes on the match anchor, so reading attributes is as stable as the old page was.
Times are Cairo wall clock ("مواعيد الموقع بتوقيت القاهرة أصلاً"); the conversion is the only
place a time zone is applied.

The adapter writes no status and no score: fixtures only (constitution II, FR-021).
"""

from __future__ import annotations

from datetime import date
from typing import TYPE_CHECKING
from urllib.parse import urlsplit

# lxml ships no stubs and the project has no override for it (the dependency is Lane B1's, T001).
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

DAY_URL = "https://www.ysscores.com/ar/match_date_to"
ALLOWED_HOSTS = frozenset({"www.ysscores.com"})
# The site answers 403 to a plain client; these two headers are what its page sends (README).
HEADERS = {
    "X-Requested-With": "XMLHttpRequest",
    "Referer": "https://www.ysscores.com/ar/home",
}
_MONTHS = (
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
)


def date_param(day: date) -> str:
    """``"October 31,2026"``: English month, no space after the comma (IMPORT.html)."""
    return f"{_MONTHS[day.month - 1]} {day.day},{day.year}"


def _has_class(element: HtmlElement, cls: str) -> bool:
    return cls in (element.get("class") or "").split()


def _children_with_class(root: HtmlElement, tag: str, cls: str) -> list[HtmlElement]:
    return [el for el in root.iter(tag) if _has_class(el, cls)]


def _text(element: HtmlElement | None) -> str:
    return " ".join(element.text_content().split()) if element is not None else ""


def _attr(element: HtmlElement, name: str) -> str | None:
    value = (element.get(name) or "").strip()
    return value or None


def _id_from_href(href: str | None, kind: str) -> str | None:
    """``/ar/match/<id>/<slug>`` or ``/ar/team/<id>/<slug>``."""
    if not href:
        return None
    parts = [p for p in urlsplit(href).path.split("/") if p]
    for i, part in enumerate(parts):
        if part == kind and i + 1 < len(parts) and parts[i + 1].isdigit():
            return parts[i + 1]
    return None


class YsscoresAdapter:
    name = "ysscores"
    allowed_hosts = ALLOWED_HOSTS

    def __init__(self, fetcher: HttpFetcher | None) -> None:
        self.fetcher = fetcher
        # The pages fetched so far: the fetch task saves them when a later day fails (B2-R1-9).
        self.pages: list[RawPage] = []

    # --- fetch ---------------------------------------------------------------------------

    def fetch(self, window: DateWindow) -> list[RawPage]:
        if self.fetcher is None:
            raise RuntimeError("the ysscores adapter needs a fetcher to fetch")
        pages: list[RawPage] = []
        self.pages = pages
        for day in window:
            page = self.fetcher.post(
                DAY_URL,
                data={"get_date": date_param(day)},
                allowed_hosts=self.allowed_hosts,
                headers=HEADERS,
            )
            pages.append(
                RawPage(
                    url=f"{DAY_URL}#{day.isoformat()}",
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
            # An empty 200 is not a quiet day: the endpoint answered nothing (B2-R2-6).
            raise LayoutChanged("the response is empty")
        # Decode first: the endpoint answers an HTML fragment with no <meta charset>, and lxml
        # would otherwise guess Latin-1 and mangle every Arabic name.
        doc = lxml_html.fromstring(page.body.decode("utf-8", errors="replace"))
        wrappers = _children_with_class(doc, "div", "matches-wrapper")
        if not wrappers:
            # A day with no fixtures answers `.no-matches-wrapper`; anything else is a layout change.
            if _children_with_class(doc, "div", "no-matches-wrapper"):
                return []
            raise LayoutChanged("the response has no .matches-wrapper")
        day = day_of(page.url)
        items: list[ParsedFixture] = []
        for wrapper in wrappers:
            competition = _attr(wrapper, "champ_title")
            competition_logo = _attr(wrapper, "champ_img")
            for anchor in _children_with_class(wrapper, "a", "ajax-match-item"):
                home = _attr(anchor, "home_name")
                away = _attr(anchor, "away_name")
                if not home or not away:
                    continue
                time_element = next(iter(_children_with_class(anchor, "b", "match-date")), None)
                if time_element is None or _children_with_class(time_element, "span", "first-team-result"):
                    # A match in play (no `.match-date`) or finished (its `.match-date` holds the
                    # score spans): not a fixture. Importing it without a kickoff would wipe the one
                    # already stored, so it is skipped (R16: fixtures only). `.match-with-result`
                    # can't tell them apart: the page puts it on upcoming matches too.
                    continue
                wall_time = _wall_time(time_element)
                href = _attr(anchor, "href")
                # `match-postponed` / `data-status="14"` with «تأجلت» instead of a score: the old
                # app keeps the fixture but its time is no longer known (R16, B2-R1-10).
                postponed = _has_class(anchor, "match-postponed") or _attr(anchor, "data-status") == "14"
                items.append(
                    ParsedFixture(
                        external_id=_attr(anchor, "match_id") or _id_from_href(href, "match"),
                        url=href,
                        competition=competition,
                        competition_logo=competition_logo,
                        stage=_attr(anchor, "title"),
                        home=home,
                        away=away,
                        home_logo=_attr(anchor, "home_image"),
                        away_logo=_attr(anchor, "away_image"),
                        home_external_id=_id_from_href(_attr(anchor, "home_link"), "team"),
                        away_external_id=_id_from_href(_attr(anchor, "away_link"), "team"),
                        wall_time=wall_time,
                        match_date=day,
                        postponed=postponed,
                    )
                )
        return items

    # --- normalize -----------------------------------------------------------------------

    def normalize(self, item: ParsedFixture) -> NormalizedFixture:
        return normalize_fixture(item)


def _wall_time(element: HtmlElement) -> str:
    """``<b class="match-date">10:00<i class="mb-meridiem">م</i></b>`` -> ``"10:00 م"``."""
    meridiem = next(iter(_children_with_class(element, "i", "mb-meridiem")), None)
    marker = _text(meridiem)
    digits = _text(element)
    if marker:
        digits = " ".join(digits.replace(marker, " ").split())
        return f"{digits} {marker}".strip()
    return digits


def day_of(url: str) -> date:
    """The Cairo day a page answers, carried in the URL fragment by ``fetch``."""
    fragment = urlsplit(url).fragment
    try:
        return date.fromisoformat(fragment)
    except ValueError as exc:  # pragma: no cover - a caller bug, not a page problem
        raise ValueError(f"the page URL must carry its day as #YYYY-MM-DD, got {url!r}") from exc
