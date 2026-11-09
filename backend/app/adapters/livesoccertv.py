"""LiveSoccerTV: plan from Madar's matches, fetch a team page and a match page, parse purely.

The home box has no database, so a run is split in three (R14):

1. **plan** — ``plan_targets`` (VPS-2, part of ``adapters.schedule_fetch``) reads the Madar matches
   of the next 48 h whose two teams map through ``livesoccertv_teams`` and builds the targets;
2. **fetch** — ``LivesoccertvAdapter.fetch(targets=…)`` (the fetch queue) opens the home team's
   page ``/teams/<country>/<slug>/``, finds the match link by Cairo date and opponent, then reads
   the broadcaster table of the match page;
3. **ingest** — ``app.adapters.livesoccertv_links`` writes the links (VPS-2).

``parse_team`` and ``parse_broadcasts`` are pure: no network, no database, no clock. The pages are
saved as fixtures in ``tests/fixtures/livesoccertv/``; the Cloudflare worker proxy ``LVS.html`` used
is not ours and is not used (R14).
"""

from __future__ import annotations

import logging
import re
import unicodedata
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, time, timedelta
from typing import TYPE_CHECKING, Any
from urllib.parse import urlsplit

# lxml ships no stubs and the project has no override for it (the dependency is Lane B1's, T001).
from lxml import html as lxml_html  # type: ignore[import-untyped]
from lxml.html import HtmlElement  # type: ignore[import-untyped]

from app.adapters.base import DateWindow, LayoutChanged, NormalizedFixture, ParsedFixture, RawPage, normalize_fixture
from app.adapters.messages import BroadcastChannel, BroadcastItem, UnmatchedMatch
from app.domain.arabic import ar_normalize
from app.domain.time import CAIRO

if TYPE_CHECKING:  # the fetch path's HTTP client; importing it here would drag in app.workers
    from app.adapters.fetcher import HttpFetcher

log = logging.getLogger(__name__)

BASE = "https://www.livesoccertv.com"
ALLOWED_HOSTS = frozenset({"www.livesoccertv.com"})
NAME = "livesoccertv"

PLAN_HOURS = 48
# The T−60 pass: kickoffs 55–70 minutes away, so a channel that arrives late still lands (SD §6.6).
T60_FROM_MIN = 55
T60_TO_MIN = 70
# Matches planned (or fetched) in the last 30 minutes are not planned again (R14).
RECENT_TTL = 30 * 60
# A run carries at most 24 pages (12 matches × a team page and a match page), which keeps the
# ScrapeResult under its 2 MB cap. The rest are planned by the next beat slot (R14).
MAX_TARGETS_PER_RUN = 12
# A channel name is read when it is between these lengths and is not a URL (``LVS.html``).
MIN_CHANNEL_LENGTH = 2
MAX_CHANNEL_LENGTH = 80
MAX_COUNTRY_LENGTH = 60
TEAM_PAGE_MARKER = "Fixtures, Results"
MATCH_PAGE_MARKER = "dynamic-international-tv"
# A time cell that prints a clock (``6:00am``); a status (``Postp.``, ``TBA``) has no kickoff to read.
CLOCK_TEXT = re.compile(r"\d{1,2}:\d{2}")


# Club-name noise that the two sides spell differently: the mapping table's slug drops it
# (``bayern-munchen``, ``pyramids-fc``) while the team page prints it (``FC Bayern München``,
# ``Pyramids FC``), and the other way round for ``fenerbahce-sk`` / ``Fenerbahçe SK``.
NOISE_TOKENS = frozenset({"fc", "cf", "afc", "sc", "ac", "ssc", "sk", "club", "cd", "ca", "fk", "bk"})


def _fold(name: str | None) -> str:
    """Lower-case, fold Latin accents to ASCII (NFKD), then apply ``ar_normalize``.

    ``ar_normalize`` already lower-cases and turns punctuation (``'``, ``.``) into spaces, but it
    does not touch Latin diacritics, which is why ``"Atlético"`` used to keep its ``é`` (B2-R1-8).
    """
    if not name:
        return ""
    decomposed = unicodedata.normalize("NFKD", name)
    return ar_normalize("".join(char for char in decomposed if not unicodedata.combining(char)))


def team_slug(name: str | None) -> str:
    """``"Atlético Madrid"`` -> ``"atletico-madrid"``: the form LiveSoccerTV puts in its URLs."""
    return "-".join(_fold(name).split())


def team_key(name: str | None) -> str:
    """A separator-free, noise-free form, so a slug and a printed name compare equal.

    ``"cote-divoire"`` and ``"Côte d'Ivoire"`` both give ``"cotedivoire"``; ``"bayern-munchen"``
    and ``"FC Bayern München"`` both give ``"bayernmunchen"`` (B2-R1-8). ``ar_normalize`` already
    turns the hyphen into a space, so only the tokens have to be rejoined.
    """
    return "".join(token for token in _fold(name).split() if token not in NOISE_TOKENS)


def match_url_slugs(url: str | None) -> frozenset[str] | None:
    """The two team slugs of a ``/match/<a>-vs-<b>/<id>`` link, or ``None``.

    LiveSoccerTV's own URL carries the same slugs the mapping table stores, which is the most
    reliable comparison: it is what the site itself links to (B2-R1-8).
    """
    if not url:
        return None
    parts = [part for part in urlsplit(url).path.split("/") if part]
    if "match" not in parts:
        return None
    segment = parts.index("match") + 1
    if segment >= len(parts):
        return None
    for separator in ("-vs-", "-v-"):
        if separator in parts[segment]:
            home, away = parts[segment].split(separator, 1)
            if home and away:
                return frozenset({home, away})
    return None


@dataclass(frozen=True, slots=True)
class LivesoccertvTarget:
    """One Madar match to read from LiveSoccerTV (R14 step 1)."""

    match_id: int
    kickoff_at: datetime
    home_slug: str
    away_slug: str
    country: str
    # The mapping's ``en_name``: what the team page prints, when the club's team-page slug is not the
    # one in its match links (``shanghai-tellace`` vs ``/match/…-vs-shanghai-port/``).
    home_name: str = ""
    away_name: str = ""

    def as_task_arg(self) -> dict[str, Any]:
        return {
            "match_id": self.match_id,
            "kickoff_at": self.kickoff_at.isoformat(),
            "home_slug": self.home_slug,
            "away_slug": self.away_slug,
            "country": self.country,
            "home_name": self.home_name,
            "away_name": self.away_name,
        }

    @classmethod
    def from_task_arg(cls, data: dict[str, Any]) -> LivesoccertvTarget:
        return cls(
            match_id=int(data["match_id"]),
            kickoff_at=datetime.fromisoformat(str(data["kickoff_at"])),
            home_slug=str(data["home_slug"]),
            away_slug=str(data["away_slug"]),
            country=str(data["country"]),
            home_name=str(data.get("home_name") or ""),  # a fetch queued before the names existed
            away_name=str(data.get("away_name") or ""),
        )


@dataclass(slots=True)
class Plan:
    """What one planning pass found, for the run log and A13 (R14, T071)."""

    targets: list[LivesoccertvTarget] = field(default_factory=list)
    unmapped: list[str] = field(default_factory=list)
    recent: list[int] = field(default_factory=list)
    mapped: int = 0

    def log_payload(self) -> dict[str, Any]:
        return {
            "planned": len(self.targets),
            "mapped": self.mapped,
            "unmapped": len(self.unmapped),
            "unmapped_sample": self.unmapped[:10],
            "recent": len(self.recent),
        }


PLAN_LOG_KEY = "lstv:plan:last"


def store_plan_log(payload: dict[str, Any], client: Any = None) -> None:
    """Keep the last plan beside Redis, so the next ingest's run log can show its coverage (T071)."""
    import json

    conn = client or _redis()
    conn.set(PLAN_LOG_KEY, json.dumps(payload, ensure_ascii=False), ex=2 * 60 * 60)


def last_plan_log(client: Any = None) -> dict[str, Any] | None:
    import json

    conn = client or _redis()
    raw = conn.get(PLAN_LOG_KEY)
    if not raw:
        return None
    try:
        loaded = json.loads(raw)
    except ValueError:  # a half-written key cannot fail a run
        return None
    return loaded if isinstance(loaded, dict) else None


class RecentFetches:
    """Whether a match was planned or fetched recently, so T−60 and 48 h do not repeat it."""

    def seen(self, match_id: int) -> bool:  # pragma: no cover - the protocol's default
        raise NotImplementedError

    def mark(self, match_id: int) -> None:  # pragma: no cover - the protocol's default
        raise NotImplementedError


class RedisRecentFetches(RecentFetches):
    """``lstv:fetched:<match_id>`` with a 30-minute TTL, on VPS-2's Redis (R14)."""

    def __init__(self, client: Any) -> None:
        self._client = client

    @staticmethod
    def key(match_id: int) -> str:
        return f"lstv:fetched:{match_id}"

    def seen(self, match_id: int) -> bool:
        return bool(self._client.exists(self.key(match_id)))

    def mark(self, match_id: int) -> None:
        self._client.set(self.key(match_id), "1", ex=RECENT_TTL)


class MemoryRecentFetches(RecentFetches):
    """The tests' store: the same rules without a Redis round trip."""

    def __init__(self, seen: Iterable[int] = ()) -> None:
        self.marked: set[int] = set(seen)

    def seen(self, match_id: int) -> bool:
        return match_id in self.marked

    def mark(self, match_id: int) -> None:
        self.marked.add(match_id)


def _text(element: HtmlElement | None) -> str:
    return " ".join(element.text_content().split()) if element is not None else ""


def _epoch_of(row: HtmlElement) -> datetime | None:
    """The row's kickoff from its ``dv`` epoch span; LiveSoccerTV renders times in the reader's zone."""
    for span in row.xpath(".//span[@dv]"):
        raw = (span.get("dv") or "").strip()
        if raw.isdigit():
            return datetime.fromtimestamp(int(raw) / 1000, UTC)
    if not (row.get("data-ko") or "").strip():
        return None
    # A postponed or unscheduled match prints a status in its time cell and has no epoch span: skip
    # the row, not the page (one ``Postp.`` row once failed a whole run).
    timecell = _first(row.xpath(".//span[contains(@class, 'timecell')]"))
    if timecell is not None and not CLOCK_TEXT.search(_text(timecell)):
        return None
    # ``data-ko`` is the site's default zone (America/New_York), never Madar's clock: refuse it.
    raise LayoutChanged("the kickoff carries no epoch span; the page's clock is not UTC")


def _absolute(href: str) -> str:
    return href if href.startswith("http") else f"{BASE}{href}"


def _home_away(title: str) -> tuple[str | None, str | None]:
    """``"Zamalek vs Al Ahly"`` -> ``("Zamalek", "Al Ahly")``: the page's own order (home first)."""
    for separator in (" vs ", " v "):
        if separator in title:
            home, away = title.split(separator, 1)
            return home.strip() or None, away.strip() or None
    return None, None


def cairo_day(moment: datetime) -> date:
    return moment.astimezone(CAIRO).date()


class LivesoccertvAdapter:
    """``SourceAdapter`` for LiveSoccerTV: a team page's rows, then a match page's broadcasters."""

    name = NAME
    allowed_hosts = ALLOWED_HOSTS

    def __init__(self, fetcher: HttpFetcher | None) -> None:
        self.fetcher = fetcher
        # The pages fetched so far, so the fetch task can save them when a later target fails.
        self.pages: list[RawPage] = []
        # What the run hands to ``ingest``: one item per planned match, plus the ones no page
        # answered for (contracts/pipelines-and-ops.md §ScrapeResult v2).
        self.items: list[BroadcastItem] = []
        self.unmatched: list[UnmatchedMatch] = []

    # --- plan (VPS-2) --------------------------------------------------------------------

    def team_url(self, country: str, slug: str) -> str:
        return f"{BASE}/teams/{country}/{slug}/"

    # --- fetch (the fetch queue) ---------------------------------------------------------

    def fetch(self, window: DateWindow, targets: Sequence[LivesoccertvTarget] | None = None) -> list[RawPage]:
        """Read each target's team page and match page; a missing match is ``unmatched`` (R14)."""
        if self.fetcher is None:
            raise RuntimeError("the livesoccertv adapter needs a fetcher to fetch")
        if not targets:
            raise RuntimeError("the livesoccertv adapter fetches planned targets, not a date window")
        if len(targets) > MAX_TARGETS_PER_RUN:
            raise RuntimeError(f"a run carries at most {MAX_TARGETS_PER_RUN} targets")

        from app.adapters.fetcher import FetchError

        pages: list[RawPage] = []
        self.pages = pages
        self.items = []
        self.unmatched = []
        for target in targets:
            try:
                team_page = self.fetcher.get(self.team_url(target.country, target.home_slug), self.allowed_hosts)
            except FetchError as exc:
                if exc.status != 404:
                    raise
                self.unmatched.append(UnmatchedMatch(match_id=target.match_id, why="team_page_not_found"))
                continue
            pages.append(team_page)

            row = pick_match(self.parse_team(team_page), target)
            if row is None or row.url is None:
                self.unmatched.append(UnmatchedMatch(match_id=target.match_id, why="match_not_found"))
                continue

            try:
                match_page = self.fetcher.get(row.url, self.allowed_hosts)
            except FetchError as exc:
                if exc.status != 404:
                    raise
                self.unmatched.append(UnmatchedMatch(match_id=target.match_id, why="match_page_not_found"))
                continue
            pages.append(match_page)
            channels = self.parse_broadcasts(match_page)
            self.items.append(BroadcastItem(match_id=target.match_id, match_url=match_page.url, channels=channels))
            log.info(
                "livesoccertv_match",
                extra={"match_id": target.match_id, "channels": len(channels), "url": match_page.url},
            )
        return pages

    # --- parse (pure) --------------------------------------------------------------------

    def parse(self, page: RawPage) -> list[ParsedFixture]:
        """The protocol's entry point: a team page's rows; a match page carries no fixtures."""
        if _is_match_page(page.url):
            return []
        return self.parse_team(page)

    def parse_team(self, page: RawPage) -> list[ParsedFixture]:
        """The team page's match rows: kickoff (UTC), the page's home/away names and the link."""
        doc = _document(page)
        if TEAM_PAGE_MARKER not in doc.text_content():
            raise LayoutChanged("the page is not a team page: the fixtures header is missing")
        items: list[ParsedFixture] = []
        for table in doc.xpath("//table[contains(@class, 'schedules')]"):
            for row in table.xpath(".//tr[contains(@class, 'matchrow')]"):
                link = _first(row.xpath(".//a[contains(@href, '/match/')]"))
                if link is None:
                    continue
                kickoff = _epoch_of(row)
                if kickoff is None:
                    continue
                home, away = _home_away((link.get("title") or "").strip())
                if not home or not away:
                    continue
                local = kickoff.astimezone(CAIRO)
                items.append(
                    ParsedFixture(
                        external_id=(row.get("id") or "").strip() or None,
                        url=_absolute((link.get("href") or "").strip()),
                        home=home,
                        away=away,
                        wall_time=local.strftime("%H:%M"),
                        match_date=local.date(),
                    )
                )
        return items

    def parse_broadcasts(self, page: RawPage) -> list[BroadcastChannel]:
        """``[{name, country}]`` from ``table.ichannels``; ``[]`` when the page lists none yet."""
        doc = _document(page)
        if not doc.xpath(f"//*[@id='{MATCH_PAGE_MARKER}']"):
            raise LayoutChanged("the page is not a match page: the coverage block is missing")
        channels: list[BroadcastChannel] = []
        seen: set[tuple[str, str]] = set()
        for table in doc.xpath("//table[contains(@class, 'ichannels')]"):
            for row in table.xpath("./tr"):
                cells = row.xpath("./td")
                if len(cells) < 2:
                    continue
                country = _text(_first(cells[0].xpath(".//span[contains(@class, 'flag')]")))
                if not country:
                    country = _text(cells[0])
                country = country[:MAX_COUNTRY_LENGTH].strip()
                if not country:
                    continue
                for anchor in cells[1].xpath(".//a"):
                    name = _text(anchor)
                    if not _valid_channel_name(name):
                        continue
                    key = (ar_normalize(name), ar_normalize(country))
                    if key in seen:
                        continue
                    seen.add(key)
                    channels.append(BroadcastChannel(name=name, country=country))
        return channels

    # --- normalize -----------------------------------------------------------------------

    def normalize(self, item: ParsedFixture) -> NormalizedFixture:
        return normalize_fixture(item)


def _is_match_page(url: str) -> bool:
    return "/match/" in urlsplit(url).path


def _document(page: RawPage) -> HtmlElement:
    if not page.body.strip():
        raise LayoutChanged(f"{page.url} answered an empty body")
    return lxml_html.fromstring(page.body.decode("utf-8", errors="replace"))


def _first(elements: Sequence[HtmlElement]) -> HtmlElement | None:
    return elements[0] if elements else None


def _valid_channel_name(name: str) -> bool:
    return (
        MIN_CHANNEL_LENGTH <= len(name) <= MAX_CHANNEL_LENGTH
        and "/" not in name
        and not name.lower().startswith("http")
    )


def pick_match(rows: Sequence[ParsedFixture], target: LivesoccertvTarget) -> ParsedFixture | None:
    """The row of the target's match: same Cairo day, and the same two teams in either order (T054).

    The mapping table holds LiveSoccerTV's URL slug while the team page prints the display name
    (``atletico-madrid`` vs ``Atlético Madrid``), so the match link's own slug pair is compared
    first, and the folded, noise-free names second (B2-R1-8). A side's name is its slug or the
    mapping's ``en_name``: a club's team-page slug can differ from its match-link slug.
    """
    wanted_slugs = frozenset(
        slug for slug in (target.home_slug.strip("/").lower(), target.away_slug.strip("/").lower()) if slug
    )
    home_keys = {key for key in (team_key(target.home_slug), team_key(target.home_name)) if key}
    away_keys = {key for key in (team_key(target.away_slug), team_key(target.away_name)) if key}
    day = cairo_day(target.kickoff_at)
    for row in rows:
        if row.match_date != day:
            continue
        if wanted_slugs and match_url_slugs(row.url) == wanted_slugs:
            return row
        first, second = team_key(row.home), team_key(row.away)
        if (
            home_keys
            and away_keys
            and ((first in home_keys and second in away_keys) or (first in away_keys and second in home_keys))
        ):
            return row
    return None


# --- planning (VPS-2, the database side) -------------------------------------------------


def plan_targets(
    session: Any,
    *,
    now: datetime,
    window: str = "default",
    recent: RecentFetches | None = None,
    limit: int = MAX_TARGETS_PER_RUN,
) -> Plan:
    """The targets of one pass: Madar matches in the window whose teams map through the dictionary.

    ``window="t60"`` plans only kickoffs 55–70 minutes away; ``"default"`` the next 48 hours. A
    match planned in the last 30 minutes is skipped, so T−60 and 48 h never repeat one fetch (R14).
    """
    from sqlalchemy import select

    from app.db.models import LivesoccertvTeam, Match, Team

    planned = Plan()
    store = recent if recent is not None else RedisRecentFetches(_redis())

    if window == "t60":
        start = now + timedelta(minutes=T60_FROM_MIN)
        end = now + timedelta(minutes=T60_TO_MIN)
    else:
        start = now
        end = now + timedelta(hours=PLAN_HOURS)

    matches = list(
        session.execute(
            select(
                Match.id,
                Match.kickoff_at,
                Match.home_team_id,
                Match.away_team_id,
                Match.home_team_name,
                Match.away_team_name,
            )
            .where(
                Match.sport == "football",
                Match.kickoff_at.is_not(None),
                Match.kickoff_at >= start,
                Match.kickoff_at <= end,
                Match.time_tbd.is_(False),
                Match.status == "scheduled",
            )
            .order_by(Match.kickoff_at, Match.id)
        )
    )
    if not matches:
        return planned

    team_ids = {m.home_team_id for m in matches if m.home_team_id} | {m.away_team_id for m in matches if m.away_team_id}
    names = {ar_normalize(m.home_team_name) for m in matches} | {ar_normalize(m.away_team_name) for m in matches}
    names.discard("")

    by_team: dict[int, LivesoccertvTeam] = {}
    by_name: dict[str, LivesoccertvTeam] = {}
    for row in session.execute(
        select(LivesoccertvTeam).where(
            (LivesoccertvTeam.team_id.in_(team_ids)) | (LivesoccertvTeam.ar_name_norm.in_(names))
        )
    ).scalars():
        if row.team_id is not None and row.team_id not in by_team:
            by_team[row.team_id] = row
        if row.ar_name_norm not in by_name:
            by_name[row.ar_name_norm] = row

    norms = {}
    if team_ids:
        norms = dict(session.execute(select(Team.id, Team.name_norm).where(Team.id.in_(team_ids))).all())

    for match in matches:
        home = _mapping_for(match.home_team_id, match.home_team_name, by_team, by_name, norms)
        away = _mapping_for(match.away_team_id, match.away_team_name, by_team, by_name, norms)
        if home is None or away is None or not home.country or not away.country:
            planned.unmapped.append(f"{match.home_team_name} × {match.away_team_name}")
            continue
        planned.mapped += 1
        if store.seen(match.id):
            planned.recent.append(match.id)
            continue
        if len(planned.targets) >= limit:
            break
        kickoff = match.kickoff_at
        assert kickoff is not None  # filtered above
        planned.targets.append(
            LivesoccertvTarget(
                match_id=match.id,
                kickoff_at=kickoff,
                home_slug=home.slug,
                away_slug=away.slug,
                country=home.country,
                home_name=home.en_name,
                away_name=away.en_name,
            )
        )
        store.mark(match.id)
    return planned


def _mapping_for(
    team_id: int | None,
    team_name: str | None,
    by_team: dict[int, Any],
    by_name: dict[str, Any],
    norms: dict[int, str],
) -> Any | None:
    """A team id first, else the exact normalized Arabic name (R14, T053)."""
    if team_id is not None and team_id in by_team:
        return by_team[team_id]
    normal = norms.get(team_id) if team_id is not None else None
    normal = normal or ar_normalize(team_name)
    return by_name.get(normal)


def targets_from_args(raw: Sequence[dict[str, Any]] | None) -> list[LivesoccertvTarget]:
    return [LivesoccertvTarget.from_task_arg(item) for item in raw or ()]


def _redis() -> Any:
    """The worker's Redis, for the 30-minute "already planned" marks (imported lazily)."""
    import redis

    from app.workers.config import get_worker_settings

    return redis.Redis.from_url(get_worker_settings().broker_url)


def wall_clock(moment: datetime) -> time:
    """The Cairo wall clock of a kickoff, for logs and runbooks."""
    return moment.astimezone(CAIRO).timetz().replace(tzinfo=None)


__all__ = [
    "ALLOWED_HOSTS",
    "MAX_TARGETS_PER_RUN",
    "NAME",
    "MemoryRecentFetches",
    "LivesoccertvAdapter",
    "LivesoccertvTarget",
    "Plan",
    "RecentFetches",
    "RedisRecentFetches",
    "cairo_day",
    "last_plan_log",
    "match_url_slugs",
    "store_plan_log",
    "pick_match",
    "plan_targets",
    "team_key",
    "team_slug",
    "targets_from_args",
    "wall_clock",
]
