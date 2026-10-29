"""Pydantic response models for the public API — these *are* the contract.

Shapes match ``specs/001-d01-foundation/contracts/public-api-v1.md`` exactly. Optional
fields are present and ``null``, never omitted.
"""

from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class Status(StrEnum):
    scheduled = "scheduled"
    live = "live"
    halftime = "halftime"
    extra_time = "extra_time"
    penalties = "penalties"
    finished = "finished"
    postponed = "postponed"
    cancelled = "cancelled"
    abandoned = "abandoned"


class Period(StrEnum):
    first_half = "1H"
    second_half = "2H"
    extra_first = "ET1"
    extra_second = "ET2"


class Polarization(StrEnum):
    h = "H"
    v = "V"
    l = "L"  # noqa: E741
    r = "R"


class Access(StrEnum):
    free = "free"
    encrypted = "encrypted"


class Beam(StrEnum):
    wide = "wide"
    narrow = "narrow"


class Category(StrEnum):
    sports = "sports"
    entertainment = "entertainment"


class Sport(StrEnum):
    football = "football"
    basketball = "basketball"
    handball = "handball"
    volleyball = "volleyball"
    tennis = "tennis"


class Kind(StrEnum):
    satellite = "satellite"
    terrestrial = "terrestrial"
    platform = "platform"


# --- Shared shapes ------------------------------------------------------------


class Frequency(BaseModel):
    mhz: int
    pol: Polarization
    sr: int


class SatelliteRef(BaseModel):
    id: int
    slug: str
    name_ar: str
    name_en: str
    orbital_position: float | None


class TeamRef(BaseModel):
    id: int | None
    name: str
    logo: str | None


class CompetitionRef(BaseModel):
    id: int | None
    name: str
    logo: str | None
    stage: str | None
    priority: int | None


class Score(BaseModel):
    home: int
    away: int
    home_pen: int | None
    away_pen: int | None


class CommentatorRef(BaseModel):
    id: int
    name: str
    image: str | None
    audio: str | None


class NamedRef(BaseModel):
    """A minimal named entity reference: ``{id, name, logo}``."""

    id: int
    name: str
    logo: str | None


class PrimaryCompetitionRef(BaseModel):
    """``{id, name}`` — a team's primary competition in search results."""

    id: int
    name: str


class HeadlineEntry(BaseModel):
    channel_id: int
    name: str
    access: Access | None
    satellite: SatelliteRef | None
    frequency: Frequency | None


class Broadcast(BaseModel):
    channel_count: int
    has_free: bool
    headline: list[HeadlineEntry] = Field(max_length=2)


# --- Matches ------------------------------------------------------------------


class MatchSummary(BaseModel):
    id: int
    sport: Sport
    kickoff_at: datetime | None
    time_tbd: bool
    match_date: date
    status: Status
    estimated: bool
    period: Period | None
    minute: str | None
    score: Score | None
    status_label: str | None
    competition: CompetitionRef
    home: TeamRef
    away: TeamRef
    broadcast: Broadcast
    commentator: CommentatorRef | None
    updated_at: datetime


# Defaults only spare the builders from passing None; the response schema still marks
# these fields required, since they are always present (null when empty).
_ALWAYS_PRESENT = ConfigDict(json_schema_serialization_defaults_required=True)


class BroadcastEntry(BaseModel):
    model_config = _ALWAYS_PRESENT

    kind: Literal["custom", "channel"]
    channel_id: int | None = None
    label: str
    logo: str | None
    access: Access | None = None
    satellite: SatelliteRef | None = None
    frequency: Frequency | None = None
    commentators: list[CommentatorRef] = Field(default_factory=list)


class CarriageEntry(BaseModel):
    model_config = _ALWAYS_PRESENT

    id: int
    kind: Kind
    name: str
    display_name: str | None
    logo: str | None
    category: Category | None
    satellite: SatelliteRef | None
    frequency: Frequency | None
    frequency_note: str | None
    access: Access | None
    provider: str | None
    package: str | None
    beam: Beam | None
    country: str | None
    frequency_changed_at: datetime | None
    commentators: list[CommentatorRef] = Field(default_factory=list)


class PlatformEntry(BaseModel):
    channel_id: int
    name: str
    country: str | None
    logo: str | None


class PlatformGroup(BaseModel):
    region: str
    items: list[PlatformEntry]


class MatchDetail(MatchSummary):
    stadium: str | None
    local_broadcaster_eg: str | None
    broadcasts: list[BroadcastEntry]
    carriages: list[CarriageEntry]
    platforms: list[PlatformGroup]
    events: list[Any]
    lineups: None
    feed_id: int | None


class LiveState(BaseModel):
    match_id: int
    status: Status
    estimated: bool
    period: Period | None
    minute: str | None
    score: Score | None
    status_label: str | None
    status_updated_at: datetime | None


# --- Satellites and channels --------------------------------------------------


class Satellite(BaseModel):
    id: int
    slug: str
    name_ar: str
    name_en: str
    orbital_position: float | None
    kind: Kind
    logo: str | None
    channel_count: int
    best_frequency: Frequency | None
    worst_frequency: Frequency | None
    reception_url: str | None


class ChannelCarriage(BaseModel):
    id: int
    kind: Kind
    name: str
    display_name: str | None
    logo: str | None
    category: Category | None
    satellite: SatelliteRef | None
    frequency: Frequency | None
    frequency_note: str | None
    access: Access | None
    provider: str | None
    package: str | None
    beam: Beam | None
    country: str | None
    frequency_changed_at: datetime | None


class ChannelDetail(ChannelCarriage):
    other_carriages: list[ChannelCarriage]
    upcoming_matches: list[MatchSummary]
    recent_frequency_changes: list[Any]


# --- Catalog ------------------------------------------------------------------


class Competition(BaseModel):
    id: int
    sport: Sport
    name: str
    logo: str | None
    priority: int | None


class CompetitionDetail(Competition):
    rights_holders: list[NamedRef]


class TeamSearchItem(BaseModel):
    id: int
    sport: Sport
    name: str
    country: str | None
    logo: str | None
    primary_competition: PrimaryCompetitionRef | None


class TeamDetail(TeamSearchItem):
    stadium: str | None
    competitions: list[NamedRef]
    upcoming: list[MatchSummary]
    recent: list[MatchSummary]


class RightsHolder(BaseModel):
    id: int
    name: str
    logo: str | None
    sort_order: int | None


class RightsHolderFrequency(Frequency):
    is_primary: bool


class RightsHolderCarriage(BaseModel):
    id: int
    access: Access
    beam: Beam | None
    satellites: list[SatelliteRef]
    frequencies: list[RightsHolderFrequency]


class RightsHolderDetail(RightsHolder):
    competitions: list[NamedRef]
    carriages: list[RightsHolderCarriage]


class CommentatorDetail(CommentatorRef):
    upcoming: list[MatchSummary]


class HealthStatus(BaseModel):
    db: Literal["ok"]
    redis: Literal["ok"]
