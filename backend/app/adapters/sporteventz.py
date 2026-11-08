"""The sporteventz adapter: other-sport fixtures and their broadcasters (D6 T055, R21, FR-037–FR-039).

Each of four sport pages (basketball, handball, volleyball, tennis) embeds a data link the site
itself opens: ``/index.php?option=com_magictable&…&table=1&accesskey=<n>``. The access key dies on
the next page load, so the page is read fresh, the link is used at once, and an empty answer means
the key expired and the page is read once more (``../old_app/public/SPORTS.html`` lines 519–556).

Robots reading, 2026-11-06: ``https://www.sporteventz.com/robots.txt`` disallows
``/administrator/``, ``/bin/``, ``/blackhole/``, ``/cache/``, ``/cli/``, ``/components/``,
``/includes/``, ``/installation/``, ``/language/``, ``/layouts/``, ``/libraries/``, ``/logs/``,
``/modules/``, ``/plugins/`` and ``/tmp/`` for ``*`` (and everything for SemrushBot). Neither path
this adapter reads — ``/en/other-sport/<slug>.html`` and ``/index.php`` — matches a rule. There is
no shared robots check in the importers; ``yallakora.py`` records its reading the same way, and
``tests/adapters/test_sporteventz.py`` checks both paths against the committed copy with
``urllib.robotparser``. Re-check it whenever the source is reviewed (runbook).

Times: the site answers in the offset the request asks for, and the old tool sent ``+0300`` while
calling it Cairo, which is an hour wrong in winter. This adapter sends one fixed offset and converts
with that same offset, so the UTC kickoff is right whatever the season. It does not use
``domain/time.py``: that parser reads an unmarked 1–11 as PM.

Names: other sports have no Madar catalog, so team and competition names stay text, resolved through
neither an alias nor a queue (FR-032). Broadcasters are written as two custom slots, ranked here.
"""

from __future__ import annotations

import json
import re
from datetime import UTC, date, datetime, time, timedelta, timezone
from typing import TYPE_CHECKING
from urllib.parse import quote, urljoin, urlsplit, urlunsplit

from app.adapters.base import (
    DateWindow,
    LayoutChanged,
    NormalizedFixture,
    ParsedFixture,
    RawPage,
    clean_text,
)

if TYPE_CHECKING:  # the fetch path's HTTP client; importing it here would drag in app.workers
    from app.adapters.fetcher import HttpFetcher

BASE_URL = "https://www.sporteventz.com"
PAGE_URL = BASE_URL + "/en/other-sport/{slug}.html"
ALLOWED_HOSTS = frozenset({"www.sporteventz.com"})
# The contract's four sports, in the order the run reads them (R21).
SPORTS = ("basketball", "handball", "volleyball", "tennis")
# ``Sport`` on the wire → the ``sport`` domain's values. Anything else is skipped and counted.
SPORT_MAP = {
    "basketball": "basketball",
    "handball": "handball",
    "volleyball": "volleyball",
    "tennis": "tennis",
}
# One fixed offset, sent to the site and used to convert back, so no season changes it. The `+`
# must be percent-encoded in the query, or the site reads it as a space.
CLIENT_TZ_OFFSET = "+0300"
CLIENT_TZ_PARAM = quote(CLIENT_TZ_OFFSET, safe="")
CLIENT_TZ = timezone(timedelta(hours=3))
MAX_BROADCAST_LABEL = 80
SLOT_SEPARATOR = " · "
# The old tool's end-of-match marker, kept because a football row can appear on these pages.
FOOTBALL_SPORTS = frozenset({"football", "soccer", "footballsoccer"})

_MAGIC_LINK = re.compile(r"index\.php\?option=com_magictable[^\"'`\s<>\\]+", re.IGNORECASE)
_ACCESS_KEY = re.compile(r"[?&]accesskey=\d+", re.IGNORECASE)
_TABLE_ONE = re.compile(r"[?&]table=1(&|$)", re.IGNORECASE)
_BEGIN = re.compile(r"(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})(?:\s+(\d{1,2}):(\d{2}))?")
# The old tool's Arabic channels, then an Arab country code; the rest keeps the site's order (R21).
_ARABIC_CHANNELS = re.compile(
    r"bein|ssc\b|ad sports|abu ?dhabi|dubai|al ?kass|ar?riyadi|arryadia|nile ?sat|nilesat|shahid|"
    r"thmanyah|on ?time|on ?sport|dmc|cbc|mbc|starzplay|قناة|رياض",
    re.IGNORECASE,
)
_ARAB_COUNTRIES = frozenset(
    {
        "EG",
        "SA",
        "AE",
        "QA",
        "MA",
        "DZ",
        "TN",
        "LY",
        "JO",
        "KW",
        "IQ",
        "SY",
        "LB",
        "OM",
        "BH",
        "YE",
        "SD",
        "PS",
        "MR",
        "SO",
        "DJ",
        "KM",
    }
)
_MONTHS = (
    "january",
    "february",
    "march",
    "april",
    "may",
    "june",
    "july",
    "august",
    "september",
    "october",
    "november",
    "december",
)


class SporteventzAdapter:
    name = "sporteventz"
    allowed_hosts = ALLOWED_HOSTS

    def __init__(self, fetcher: HttpFetcher | None) -> None:
        self.fetcher = fetcher
        # The pages fetched so far: the fetch task saves them when a later sport fails.
        self.pages: list[RawPage] = []
        # What ``parse`` refused, with the reason, so the run log can count it (R21).
        self.skipped: list[dict[str, str]] = []

    # --- fetch ---------------------------------------------------------------------------

    def fetch(self, window: DateWindow) -> list[RawPage]:
        """One page and its data per sport; the window is the site's own (it lists two weeks)."""
        if self.fetcher is None:
            raise RuntimeError("the sporteventz adapter needs a fetcher to fetch")
        pages: list[RawPage] = []
        self.pages = pages
        self.skipped = []
        for sport in SPORTS:
            page_url = PAGE_URL.format(slug=sport)
            page = self.fetcher.get(page_url, allowed_hosts=self.allowed_hosts)
            pages.append(page)
            data = self._data_for(page, page_url)
            pages.append(data)
        return pages

    def _data_for(self, page: RawPage, page_url: str) -> RawPage:
        """Read the page's data link, then the data; an empty body means the key expired."""
        if self.fetcher is None:  # pragma: no cover - fetch guards it
            raise RuntimeError("the sporteventz adapter needs a fetcher to fetch")
        data: RawPage | None = None
        for attempt in (0, 1):
            link = _data_link(page.text, page_url)
            if link is None:
                raise LayoutChanged("the sport page holds no com_magictable link with accesskey and table=1")
            data = self.fetcher.post(_tune(link), data={}, allowed_hosts=self.allowed_hosts)
            if data.body.strip():
                return data
            if attempt == 0:
                # The key dies on the next page load, so a fresh page is what mints a usable one.
                page = self.fetcher.get(_bust(page_url), allowed_hosts=self.allowed_hosts)
                if self.pages:
                    self.pages[-1] = page
        raise LayoutChanged("the access key expired before the data answered")

    # --- parse (pure) --------------------------------------------------------------------

    def parse(self, page: RawPage) -> list[ParsedFixture]:
        """The data response's records; an access page is not a data page and holds no fixtures."""
        if not _is_data_url(page.url):
            return []
        if not page.body.strip():
            raise LayoutChanged("the data answer is empty: the access key expired")
        body = page.body.decode("utf-8", errors="replace").lstrip("\ufeff")
        try:
            payload = json.loads(body)
        except ValueError as exc:
            raise LayoutChanged(f"the data answer is not JSON: {body[:80]!r}") from exc
        if not isinstance(payload, dict):
            raise LayoutChanged("the data answer is not a JSON object")
        result = payload.get("Result")
        if isinstance(result, str) and result.strip().upper() != "OK":
            raise LayoutChanged(f"the site answered {result!r}")
        if "Records" not in payload:
            raise LayoutChanged("the data answer has no Records key")
        records = payload["Records"]
        records = records if isinstance(records, list) else ([records] if records else [])
        items: list[ParsedFixture] = []
        for record in records:
            if not isinstance(record, dict):
                continue
            item = self._fixture(record)
            if item is not None:
                items.append(item)
        return items

    def _fixture(self, record: dict[str, object]) -> ParsedFixture | None:
        sport_text = _text(record.get("Sport"))
        sport = SPORT_MAP.get(_squash(sport_text))
        if sport is None:
            reason = "football" if _squash(sport_text) in FOOTBALL_SPORTS else "other_sport"
            self._skip(_ref(record), reason)
            return None
        parsed_begin = _parse_begin(_text(record.get("Begin")))
        if parsed_begin is None:
            self._skip(_ref(record), "unreadable_begin")
            return None
        local_day, wall, has_time = parsed_begin
        home = clean_text(_text(record.get("Team1")))
        away = clean_text(_text(record.get("Team2")))
        if not home or not away:
            self._skip(_ref(record), "missing_teams")
            return None
        if home.casefold() == away.casefold():
            # The source has broken records where a team plays itself (SPORTS.html line 313).
            self._skip(_ref(record), "same_team_twice")
            return None
        tournament = clean_text(_text(record.get("Tournament")))
        category = clean_text(_text(record.get("Category")))
        external_id = _text(record.get("@id")) or None
        return ParsedFixture(
            external_id=external_id,
            competition=tournament or category or sport_text,
            stage=category if category and (not tournament or tournament != category) else None,
            home=home,
            away=away,
            wall_time=wall if has_time else "",
            match_date=local_day,
            sport=sport,
            broadcasts=_broadcast_slots(record.get("Channels")),
        )

    def _skip(self, ref: str, reason: str) -> None:
        self.skipped.append({"ref": ref, "reason": reason})

    # --- normalize -----------------------------------------------------------------------

    def normalize(self, item: ParsedFixture) -> NormalizedFixture:
        """The printed local time with the offset the request sent, in UTC (never Cairo's season)."""
        kickoff = None
        if item.wall_time:
            hour, minute = (int(part) for part in item.wall_time.split(":", 1))
            kickoff = datetime.combine(item.match_date, time(hour, minute), tzinfo=CLIENT_TZ).astimezone(UTC)
        return NormalizedFixture(
            match_date=item.match_date,
            kickoff_at=kickoff,
            time_tbd=kickoff is None,
            home=clean_text(item.home),
            away=clean_text(item.away),
            competition=clean_text(item.competition),
            stage=clean_text(item.stage),
            external_id=item.external_id,
            url=item.url,
            sport=item.sport,
            broadcasts=item.broadcasts,
        )


def _is_data_url(url: str) -> bool:
    return "com_magictable" in url


def _data_link(html: str, page_url: str) -> str | None:
    """The one com_magictable link that returns data: it carries an access key and ``table=1``."""
    for raw in _MAGIC_LINK.findall(html):
        if _ACCESS_KEY.search(raw) and _TABLE_ONE.search(raw):
            return _absolute(raw, page_url)
    return None


def _absolute(url: str, base: str) -> str:
    """The data link is on the site's root, not beside the sport page (SPORTS.html line 372)."""
    if re.match(r"^https?://", url, re.IGNORECASE):
        return url
    parts = urlsplit(url)
    if parts.path.startswith("/"):
        return urljoin(f"{urlsplit(base).scheme}://{urlsplit(base).netloc}", url)
    scheme, netloc = urlsplit(base).scheme, urlsplit(base).netloc
    return urlunsplit((scheme, netloc, "/" + parts.path.lstrip("./"), parts.query, parts.fragment))


def _tune(url: str) -> str:
    """Force the sent offset and English, so the answer is in the clock this adapter converts."""
    tuned = re.sub(r"([?&])client_tz_offset=[^&]*", r"\1client_tz_offset=" + CLIENT_TZ_PARAM, url)
    if "client_tz_offset=" not in tuned:
        tuned += "&client_tz_offset=" + CLIENT_TZ_PARAM
    tuned = re.sub(r"([?&])language_code=[^&]*", r"\1language_code=en", tuned)
    if "language_code=" not in tuned:
        tuned += "&language_code=en"
    return tuned


def _bust(url: str) -> str:
    """A fresh page: the site caches, and a cached page's key is already dead (SPORTS.html line 511)."""
    separator = "&" if "?" in url else "?"
    return f"{url}{separator}cb={int(datetime.now(UTC).timestamp())}"


def _parse_begin(value: str) -> tuple[date, str, bool] | None:
    """``"Friday, 06 November 2026 05:00"`` → (local day, "05:00", True); no clock → False."""
    match = _BEGIN.search(value)
    if match is None:
        return None
    day, month, year = int(match.group(1)), match.group(2).lower()[:3], int(match.group(3))
    try:
        month_number = next(index for index, name in enumerate(_MONTHS, start=1) if name[:3] == month)
    except StopIteration:
        return None
    hour = int(match.group(4)) if match.group(4) else 0
    minute = int(match.group(5)) if match.group(5) else 0
    if not 1 <= day <= 31 or hour > 23 or minute > 59:
        return None
    try:
        local_day = date(year, month_number, day)
    except ValueError:
        return None
    return local_day, f"{hour:02d}:{minute:02d}", match.group(4) is not None


def _broadcast_slots(channels: object) -> tuple[str, ...]:
    """Slot 1, then the next four joined; slot 2 is cut at a whole name within 80 characters."""
    names = _channel_names(channels)
    if not names:
        return ()
    ranked = sorted(names, key=lambda item: item[1])
    first = ranked[0][0]
    rest: list[str] = []
    for name, _rank in ranked[1:5]:
        candidate = SLOT_SEPARATOR.join([*rest, name])
        if len(candidate) > MAX_BROADCAST_LABEL:
            break
        rest.append(name)
    if not rest:
        return (first[:MAX_BROADCAST_LABEL],)
    return (first[:MAX_BROADCAST_LABEL], SLOT_SEPARATOR.join(rest))


def _channel_names(channels: object) -> list[tuple[str, int]]:
    """``(name, rank)`` de-duplicated by name, keeping the site's order within a rank (R21)."""
    if not isinstance(channels, dict):
        return []
    listed = channels.get("Channel")
    rows = listed if isinstance(listed, list) else ([listed] if listed else [])
    found: list[tuple[str, int]] = []
    seen: set[str] = set()
    for row in rows:
        if isinstance(row, dict):
            name = _text(row.get("Name"))
            country = _text(row.get("Country"))
        else:
            name, country = _text(row), ""
        if not name or name.casefold() in seen:
            continue
        seen.add(name.casefold())
        found.append((name, _channel_rank(name, country)))
    return found


def _channel_rank(name: str, country: str) -> int:
    if _ARABIC_CHANNELS.search(name):
        return 0
    if country.strip().upper() in _ARAB_COUNTRIES:
        return 1
    return 2


def _text(value: object) -> str:
    """The payload is XML turned into JSON, so a field may be a string, a number or ``{"#text"}``."""
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, dict):
        inner = value.get("#text")
        if isinstance(inner, str):
            return inner.strip()
        if isinstance(inner, (int, float)):
            return str(inner)
    return ""


def _squash(value: str) -> str:
    return re.sub(r"[^a-z]", "", value.casefold())


def _ref(record: dict[str, object]) -> str:
    return _text(record.get("@id")) or "?"
