"""The ``SourceAdapter`` base of SD §6.6 and the shapes shared by every adapter (T068, R14).

The contract is in ``specs/002-d02-core-flows/contracts/ingestion.md``. ``parse`` is pure: no
network, no database, no clock. Only ``fetch`` talks to a host, and only through ``HttpFetcher``.
"""

from __future__ import annotations

import re
from collections.abc import Iterator, Sequence
from dataclasses import dataclass, field
from datetime import UTC, date, datetime, timedelta
from typing import Protocol, runtime_checkable
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict

from app.domain.time import cairo_to_utc, parse_cairo_wall_clock

WINDOW_DAYS = 4  # today to +3 (FR-021, R16)


class LayoutChanged(Exception):
    """The document is not the shape the adapter reads: the source changed.

    One class for every adapter, so the fetch task records the failure the same way whichever
    source broke (B2-R1-9).
    """


_DOUBLED_SLASH = re.compile(r"^(.+?)\s+/\s+\1$")
_DOUBLED_SPACE = re.compile(r"^(.+?)\s+\1$")


@dataclass(frozen=True, slots=True, order=True)
class DateWindow:
    """The Cairo calendar days a run covers: today to +3 by default (contracts §SourceAdapter)."""

    days: tuple[date, ...]

    @classmethod
    def next_days(cls, today: date, span: int = WINDOW_DAYS) -> DateWindow:
        return cls(days=tuple(today + timedelta(days=n) for n in range(span)))

    def __iter__(self) -> Iterator[date]:
        return iter(self.days)

    def __len__(self) -> int:
        return len(self.days)


@dataclass(frozen=True, slots=True)
class RawPage:
    """One fetched response, as the fetch task sends it and the raw store saves it."""

    url: str
    status: int
    body: bytes
    content_type: str | None = None
    fetched_at: datetime = field(default_factory=lambda: datetime.now(UTC))

    @property
    def text(self) -> str:
        return self.body.decode("utf-8", errors="replace")


class FixtureLink(BaseModel):
    """A channel link the bridge brings: the source's channel reference, not our id (R19)."""

    model_config = ConfigDict(frozen=True)

    channel_ref: str
    hidden: bool = False
    commentator: str | None = None
    commentator2: str | None = None


class ParsedFixture(BaseModel):
    """The page's own values, as strings (contracts/ingestion.md §ParsedFixture)."""

    model_config = ConfigDict(frozen=True)

    external_id: str | None = None
    url: str | None = None
    competition: str | None = None
    competition_logo: str | None = None
    stage: str | None = None
    home: str | None = None
    away: str | None = None
    home_logo: str | None = None
    away_logo: str | None = None
    home_external_id: str | None = None
    away_external_id: str | None = None
    wall_time: str = ""
    match_date: date
    # The domain's five sports; a source that says nothing is a football page (D6 T047).
    sport: str = "football"
    # None means "this source says nothing about links", which is not the same as an empty list
    # (B2-R1-2): the upsert must not delete links it did not bring.
    links: tuple[FixtureLink, ...] | None = None
    ys_match_id: str | None = None
    legacy_id: str | None = None
    # The source marks the fixture postponed: no kickoff is known any more (R16, B2-R1-10).
    postponed: bool = False
    # YallaKora's channel text, which is what an Egyptian viewer watches it on (D5 FR-020).
    local_broadcaster_eg: str | None = None
    # The source's own broadcaster slots, in its own words (sporteventz, D6 FR-037). None means
    # "this source says nothing about broadcasters", so a stored slot is never cleared by it.
    broadcasts: tuple[str, ...] | None = None


@dataclass(frozen=True, slots=True)
class NormalizedFixture:
    """The page's values after cleanup: UTC kickoff, NULL for placeholders, allowlisted logos."""

    match_date: date
    kickoff_at: datetime | None
    time_tbd: bool
    home: str | None
    away: str | None
    competition: str | None
    stage: str | None = None
    competition_logo: str | None = None
    home_logo: str | None = None
    away_logo: str | None = None
    external_id: str | None = None
    url: str | None = None
    home_external_id: str | None = None
    away_external_id: str | None = None
    sport: str = "football"
    links: tuple[FixtureLink, ...] | None = None  # None: no link information from this source
    ys_match_id: str | None = None
    legacy_id: str | None = None
    postponed: bool = False
    local_broadcaster_eg: str | None = None
    broadcasts: tuple[str, ...] | None = None  # None: no broadcaster information from this source


@runtime_checkable
class SourceAdapter(Protocol):
    """SD §6.6. ``name`` is the ``sources.name`` the adapter writes as."""

    name: str
    allowed_hosts: frozenset[str]
    # The pages fetched so far, so the fetch task can save them when a later day fails (B2-R1-9).
    pages: list[RawPage]

    def fetch(self, window: DateWindow) -> Sequence[RawPage]: ...

    def parse(self, page: RawPage) -> list[ParsedFixture]: ...

    def normalize(self, item: ParsedFixture) -> NormalizedFixture: ...


# Placeholders the sources use for "not published" (migration README rules, R16).
PLACEHOLDERS = frozenset({"", "-", "--", "---", "⚽", "غير مدرج", "«غير مدرج»", "غير محدد", "n/a", "null"})


def clean_text(value: str | None) -> str | None:
    """Collapse whitespace, clean doubled stage text, and map a placeholder to ``None``."""
    if value is None:
        return None
    text = " ".join(value.replace("\u200f", " ").split())
    text = text.strip("«»\"' ")
    if text.strip(" -") == "" or text in PLACEHOLDERS:
        return None
    # "الجولة 12 الجولة 12" / "الجولة 12 / الجولة 12" / "نصف النهائي نصف النهائي" -> one copy.
    doubled = _DOUBLED_SLASH.match(text) or _DOUBLED_SPACE.match(text)
    if doubled:
        text = doubled.group(1).strip()
    return text or None


def allowlisted_logo(url: str | None) -> str | None:
    """Keep a logo only from a host the media worker may rehost from (FR-024).

    Imported lazily: ``normalize`` runs in ``ingest`` on VPS-2, and the fetch/parse path on the
    home box must never load ``app.settings`` (FR-028). The pipeline never stores a URL anyway.
    """
    if not url:
        return None
    from app.settings import get_settings

    host = urlsplit(url).hostname or ""
    return url if host in frozenset(get_settings().media_rehost_allowed_hosts) else None


def normalize_fixture(item: ParsedFixture) -> NormalizedFixture:
    """The rules from the migration README that every source shares (R16, R19).

    Cairo wall clock to UTC, ``"--:--"`` to ``time_tbd`` with no kickoff, placeholders to NULL,
    doubled stage text cleaned, and a logo kept only from an allowlisted host.
    """
    wall = None if item.postponed else parse_cairo_wall_clock(item.wall_time)
    return NormalizedFixture(
        match_date=item.match_date,
        kickoff_at=None if wall is None else cairo_to_utc(item.match_date, wall),
        time_tbd=wall is None,
        postponed=item.postponed,
        home=clean_text(item.home),
        away=clean_text(item.away),
        competition=clean_text(item.competition),
        stage=clean_text(item.stage),
        competition_logo=allowlisted_logo(item.competition_logo),
        home_logo=allowlisted_logo(item.home_logo),
        away_logo=allowlisted_logo(item.away_logo),
        external_id=item.external_id,
        url=item.url,
        home_external_id=item.home_external_id,
        away_external_id=item.away_external_id,
        sport=item.sport,
        links=item.links,
        ys_match_id=item.ys_match_id,
        legacy_id=item.legacy_id,
        local_broadcaster_eg=clean_text(item.local_broadcaster_eg),
        broadcasts=item.broadcasts,
    )
