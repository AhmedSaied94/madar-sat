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

from pydantic import BaseModel, ConfigDict

WINDOW_DAYS = 4  # today to +3 (FR-021, R16)
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
    links: tuple[FixtureLink, ...] = ()
    ys_match_id: str | None = None
    legacy_id: str | None = None


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
    links: tuple[FixtureLink, ...] = ()
    ys_match_id: str | None = None
    legacy_id: str | None = None


@runtime_checkable
class SourceAdapter(Protocol):
    """SD §6.6. ``name`` is the ``sources.name`` the adapter writes as."""

    name: str
    allowed_hosts: frozenset[str]

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
