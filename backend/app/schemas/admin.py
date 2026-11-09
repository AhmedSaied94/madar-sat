"""Pydantic schemas for the admin API: the D1 auth shapes and the D2 contract.

The auth shapes match ``specs/001-d01-foundation/contracts/admin-auth-v1.md`` and never change.
The rest match ``specs/002-d02-core-flows/contracts/admin-api.md`` exactly. Request bodies reject
unknown fields (``extra="forbid"``); in the entity bodies an omitted field means "unchanged".
"""

from __future__ import annotations

from datetime import date, datetime
from enum import StrEnum
from typing import Annotated, Any, Literal

from pydantic import (
    AfterValidator,
    AwareDatetime,
    BaseModel,
    ConfigDict,
    EmailStr,
    Field,
    StringConstraints,
    model_validator,
)
from pydantic_core import PydanticCustomError

from app.domain.content import find_card_sharing_label
from app.schemas import admin_examples as ex
from app.schemas.public import (
    Access,
    Beam,
    Category,
    CompetitionRef,
    Frequency,
    Kind,
    NotificationType,
    Period,
    Score,
    Sport,
    Status,
    TeamRef,
)


class AdminRole(StrEnum):
    editor = "editor"
    admin = "admin"


class AdminUser(BaseModel):
    id: int
    email: EmailStr
    name: str
    role: AdminRole
    # Set by a temporary password; the client redirects to the change-password screen (R19).
    must_change_password: bool = False


class Session(BaseModel):
    model_config = ConfigDict(
        # Always in the response, so required in its schema despite the defaults.
        json_schema_serialization_defaults_required=True,
        json_schema_extra={
            "examples": [
                {
                    "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIzIn0.signature",
                    "token_type": "Bearer",
                    "expires_in": 900,
                    "admin": {"id": 3, "email": "editor@example.com", "name": "محرر", "role": "editor"},
                }
            ]
        },
    )

    access_token: str
    token_type: Literal["Bearer"] = "Bearer"  # noqa: S105 - the OAuth token type, not a secret
    expires_in: int = 900
    admin: AdminUser


class LoginRequest(BaseModel):
    email: EmailStr = Field(max_length=254)
    password: str = Field(min_length=1, max_length=256)


class ChangePasswordRequest(BaseModel):
    """A flagged account's own change; the length rules answer ``422 password_too_short`` (admin-api)."""

    model_config = ConfigDict(extra="forbid")

    current_password: str = Field(min_length=1, max_length=256)
    new_password: str = Field(min_length=1, max_length=256)


# --- D2: validation building blocks (data-model "Validation rules") ------------------------------


def _no_card_sharing_label(value: str) -> str:
    """Refuse a card-sharing label in any free text that reaches /v1 (constitution, Content and legal; O3)."""
    if find_card_sharing_label(value) is not None:
        raise PydanticCustomError("card_sharing_label", "this text may not name a card-sharing service")
    return value


# Every admin text input is refused a NUL before it reaches the database (B1-R1-2, FR-013).
def _no_nul(value: Any) -> None:
    if isinstance(value, str):
        if "\x00" in value:
            raise PydanticCustomError("nul_byte", "this text may not contain a NUL character")
    elif isinstance(value, dict):
        for item in value.values():
            _no_nul(item)
    elif isinstance(value, (list, tuple, set)):
        for item in value:
            _no_nul(item)


# Trimmed, non-empty text with a length cap and no card-sharing label.
Name120 = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=120),
    AfterValidator(_no_card_sharing_label),
]
Text120 = Name120
Text80 = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=80),
    AfterValidator(_no_card_sharing_label),
]
Minute = Annotated[str, StringConstraints(max_length=8, pattern=r"^\d{1,3}(\+\d{1,2})?$")]
Slug = Annotated[str, StringConstraints(max_length=120, pattern=r"^[a-z0-9]+(-[a-z0-9]+)*$")]
Etag = Annotated[str, StringConstraints(min_length=3, max_length=80)]
HttpsUrl = Annotated[str, StringConstraints(max_length=2048, pattern=r"^https://\S+$")]
Password = Annotated[str, Field(min_length=12, max_length=256)]
Orbit = Annotated[float, Field(ge=-180, le=180)]
# ``priority`` and ``sort_order`` are PostgreSQL ``integer`` (32-bit): a larger value is a 422, never a database error.
Int32 = Annotated[int, Field(ge=0, le=2**31 - 1)]
# Every id column is a bigint: a larger id is a 422, never a database error.
Id = Annotated[int, Field(ge=1, le=2**63 - 1)]

MAX_LINKS_PER_MATCH = 300
MAX_BULK_ITEMS = 200
MAX_QUERY_LENGTH = 64


class _Body(BaseModel):
    """Base of every request body: unknown fields are a validation error, and no text carries a NUL."""

    model_config = ConfigDict(extra="forbid")

    @model_validator(mode="before")
    @classmethod
    def _refuse_nul(cls, data: Any) -> Any:
        _no_nul(data)
        return data


# --- D2: shared response parts --------------------------------------------------------------------


class IdName(BaseModel):
    id: int
    name: str


class AdminSatelliteRef(BaseModel):
    id: int
    name_ar: str
    name_en: str
    orbital_position: float | None


class ChangedBy(BaseModel):
    """Who last changed an entity: an admin (by name) or an importer (by source name)."""

    kind: Literal["admin", "source"]
    name: str


class LastChange(ChangedBy):
    at: datetime


class ExternalId(BaseModel):
    source: str
    external_id: str


class MatchExternalIdItem(ExternalId):
    url: str | None


# --- D2: matches (A3, A4) -------------------------------------------------------------------------


class AdminMatchRow(BaseModel):
    """One A3 row."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.MATCH_ROW]})

    id: int
    match_date: date
    kickoff_at: datetime | None
    time_tbd: bool
    status: Status
    estimated: bool
    score: Score | None
    competition: CompetitionRef
    home: TeamRef
    away: TeamRef
    channel_count: int
    broadcaster_count: int
    missing_channels: bool
    commentator: IdName | None
    sources: list[str]
    locked: bool
    etag: Etag  # the version the bulk actions send as each item's If-Match (A-R1-3)


class AdminMatchTeam(BaseModel):
    team_id: int | None
    name: str
    logo_asset_id: int | None
    logo: str | None


class AdminMatchStatus(BaseModel):
    status: Status
    status_source: Literal["clock", "feed", "manual"]
    estimated: bool
    period: Period | None
    minute: str | None
    score: Score | None
    status_label: str | None
    status_updated_at: datetime | None


class AdminBroadcast(BaseModel):
    slot: int
    label: str
    logo_asset_id: int | None
    logo: str | None
    commentator_id: int | None


class AdminMatchChannel(BaseModel):
    channel_id: int
    name: str
    display_name: str | None
    kind: Kind
    satellite: AdminSatelliteRef | None
    frequency: Frequency | None
    access: Access | None
    category: Category | None
    logo: str | None
    source: str
    imported_by: str | None
    is_hidden: bool
    hidden_by_name: bool  # «مخفية دائماً»
    commentator_id: int | None
    commentator2_id: int | None


class AdminMatch(BaseModel):
    """The A4 editor's match."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.MATCH]})

    id: int
    sport: Sport
    match_date: date
    kickoff_at: datetime | None
    time_tbd: bool
    competition_id: int | None
    competition_name: str
    competition_stage: str | None
    home: AdminMatchTeam
    away: AdminMatchTeam
    stadium: str | None
    commentator_id: int | None
    status: AdminMatchStatus
    broadcasts: list[AdminBroadcast]
    channels: list[AdminMatchChannel]
    locked_fields: list[str]
    external_ids: list[MatchExternalIdItem]
    source: str  # who created the row
    last_change: LastChange | None


class TeamInput(_Body):
    """A team by id, or as text only. Exactly one of the two."""

    team_id: Id | None = None
    name: Name120 | None = None

    @model_validator(mode="after")
    def _exactly_one(self) -> TeamInput:
        if (self.team_id is None) == (self.name is None):
            raise PydanticCustomError("team_or_name", "send exactly one of team_id or name")
        return self


class MatchFields(_Body):
    """``MatchPatch.fields``: every key optional; a key sent replaces that value (``null`` clears it)."""

    kickoff_at: AwareDatetime | None = None
    time_tbd: bool | None = None
    match_date: date | None = None
    competition_id: Id | None = None
    competition_name: Name120 | None = None
    competition_stage: Text80 | None = None
    home: TeamInput | None = None
    away: TeamInput | None = None
    stadium: Text120 | None = None
    commentator_id: Id | None = None

    @model_validator(mode="after")
    def _kickoff_or_tbd(self) -> MatchFields:
        if self.time_tbd is True and self.kickoff_at is not None:
            raise PydanticCustomError("kickoff_and_tbd", "kickoff_at must be empty when time_tbd is true")
        return self


class BroadcastSlotInput(_Body):
    slot: Literal[1, 2]
    label: Text80
    logo_asset_id: Id | None = None
    commentator_id: Id | None = None


class ChannelLinkInput(_Body):
    channel_id: Id
    is_hidden: bool = False
    commentator_id: Id | None = None
    commentator2_id: Id | None = None

    @model_validator(mode="after")
    def _second_commentator_needs_first(self) -> ChannelLinkInput:
        if self.commentator2_id is not None and (
            self.commentator_id is None or self.commentator2_id == self.commentator_id
        ):
            raise PydanticCustomError("commentators", "commentator2_id needs a different commentator_id")
        return self


class ScoreInput(_Body):
    home: int = Field(ge=0, le=99)
    away: int = Field(ge=0, le=99)
    home_pen: int | None = Field(default=None, ge=0, le=99)
    away_pen: int | None = Field(default=None, ge=0, le=99)

    @model_validator(mode="after")
    def _penalties_come_in_pairs(self) -> ScoreInput:
        if (self.home_pen is None) != (self.away_pen is None):
            raise PydanticCustomError("penalties_pair", "send both home_pen and away_pen, or neither")
        return self


class StatusSet(_Body):
    """A manual status. Which of the other keys each status allows is checked in ``domain.manual_status``."""

    status: Status
    period: Period | None = None
    minute: str | None = None
    score: ScoreInput | None = None
    status_label: Text80 | None = None  # reaches /v1, so it is screened like every other free text


class StatusPatch(_Body):
    """``{set: …}`` or ``{clear: true}``."""

    set: StatusSet | None = None
    clear: bool | None = None

    @model_validator(mode="after")
    def _one_action(self) -> StatusPatch:
        if (self.set is None) == (self.clear is not True):
            raise PydanticCustomError("set_or_clear", "send exactly one of set or clear: true")
        return self


class MatchPatch(_Body):
    """Every section optional. A section sent replaces that section; all are saved under one ``If-Match``."""

    fields: MatchFields | None = None
    broadcasts: Annotated[list[BroadcastSlotInput], Field(max_length=2)] | None = None
    channels: Annotated[list[ChannelLinkInput], Field(max_length=MAX_LINKS_PER_MATCH)] | None = None
    status: StatusPatch | None = None


class MatchCreateFields(_Body):
    """``MatchFields`` with the keys a new match needs."""

    kickoff_at: AwareDatetime | None = None
    time_tbd: bool = False
    match_date: date
    competition_id: Id | None = None
    competition_name: Name120 | None = None
    competition_stage: Text80 | None = None
    home: TeamInput
    away: TeamInput
    stadium: Text120 | None = None
    commentator_id: Id | None = None

    @model_validator(mode="after")
    def _complete(self) -> MatchCreateFields:
        if self.time_tbd and self.kickoff_at is not None:
            raise PydanticCustomError("kickoff_and_tbd", "kickoff_at must be empty when time_tbd is true")
        if not self.time_tbd and self.kickoff_at is None:
            raise PydanticCustomError("kickoff_required", "send kickoff_at, or time_tbd: true")
        if self.competition_id is None and self.competition_name is None:
            raise PydanticCustomError("competition_required", "send competition_id or competition_name")
        return self


class MatchCreate(MatchCreateFields):
    broadcasts: Annotated[list[BroadcastSlotInput], Field(max_length=2)] = Field(default_factory=list)
    channels: Annotated[list[ChannelLinkInput], Field(max_length=MAX_LINKS_PER_MATCH)] = Field(default_factory=list)


class BulkItem(_Body):
    id: Id
    # Optional in the schema on purpose: an item without it must reach the service and get
    # `428 precondition_required` (like a missing `If-Match`), not a generic 422.
    etag: Etag | None = Field(
        default=None, description="The match's current ETag. Required: without it the answer is `428`."
    )


class BulkChangeCompetition(_Body):
    action: Literal["change_competition"]
    items: Annotated[list[BulkItem], Field(min_length=1, max_length=MAX_BULK_ITEMS)]
    competition_id: Id
    competition_stage: Text80 | None = None


class BulkRemoveChannels(_Body):
    action: Literal["remove_channels"]
    items: Annotated[list[BulkItem], Field(min_length=1, max_length=MAX_BULK_ITEMS)]
    channel_ids: list[Id] | None = None  # null = every visible link


BulkRequest = Annotated[BulkChangeCompetition | BulkRemoveChannels, Field(discriminator="action")]


class BulkUpdated(BaseModel):
    id: int
    etag: str


class BulkResult(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.BULK_RESULT]})

    updated: list[BulkUpdated]


# --- D2: teams, competitions, satellites, channels, commentators -----------------------------------


class TeamItem(BaseModel):
    """Enough to tell same-name teams apart in a picker."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.TEAM_ITEM]})

    id: int
    name: str
    country: str | None
    logo: str | None
    primary_competition: IdName | None
    competitions: list[IdName]


class AdminTeam(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.TEAM]})

    id: int
    sport: Sport
    name: str
    country: str | None
    logo_asset_id: int | None
    logo: str | None
    stadium: str | None
    primary_competition_id: int | None
    competition_ids: list[int]
    external_ids: list[ExternalId]  # read-only on D2


class TeamCreate(_Body):
    sport: Sport = Sport.football
    name: Name120
    country: Name120 | None = None
    logo_asset_id: Id | None = None
    stadium: Text120 | None = None
    primary_competition_id: Id | None = None
    competition_ids: Annotated[list[Id], Field(max_length=100)] = Field(default_factory=list)


class TeamPatch(_Body):
    name: Name120 | None = Field(default=None)
    country: Name120 | None = None
    logo_asset_id: Id | None = None
    stadium: Text120 | None = None
    primary_competition_id: Id | None = None
    competition_ids: Annotated[list[Id], Field(max_length=100)] | None = None


class AdminCompetition(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.COMPETITION]})

    id: int
    sport: Sport
    name: str
    logo_asset_id: int | None
    logo: str | None
    priority: int | None
    etag: Etag  # the version `PUT /competitions/order` checks as an item's If-Match (A-R1-1)


class CompetitionCreate(_Body):
    sport: Sport = Sport.football
    name: Name120
    logo_asset_id: Id | None = None
    priority: Int32 | None = None


class CompetitionPatch(_Body):
    name: Name120 | None = Field(default=None)
    logo_asset_id: Id | None = None
    priority: Int32 | None = None


class AdminSatellite(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.SATELLITE]})

    id: int
    slug: str
    kind: Literal["satellite", "terrestrial"]
    name_en: str
    name_ar: str
    orbital_position: float | None
    logo_asset_id: int | None
    logo: str | None
    best_frequency: Frequency | None
    worst_frequency: Frequency | None
    reception_url: str | None
    priority: int | None
    etag: Etag  # the version `PUT /satellites/order` checks as an item's If-Match (A-R1-1)


class SatelliteCreate(_Body):
    slug: Slug
    kind: Literal["satellite", "terrestrial"] = "satellite"
    name_en: Name120
    name_ar: Name120
    orbital_position: Orbit | None = None
    logo_asset_id: Id | None = None
    best_frequency: Frequency | None = None
    worst_frequency: Frequency | None = None
    reception_url: HttpsUrl | None = None
    priority: Int32 | None = None

    @model_validator(mode="after")
    def _orbit_matches_kind(self) -> SatelliteCreate:
        if (self.kind == "satellite") != (self.orbital_position is not None):
            raise PydanticCustomError(
                "orbital_position", "satellites need an orbital_position; terrestrial rows have none"
            )
        return self


class SatellitePatch(_Body):
    slug: Slug | None = None
    name_en: Name120 | None = None
    name_ar: Name120 | None = None
    orbital_position: Orbit | None = None
    logo_asset_id: Id | None = None
    best_frequency: Frequency | None = None
    worst_frequency: Frequency | None = None
    reception_url: HttpsUrl | None = None
    priority: Int32 | None = None


class ChannelItem(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.CHANNEL_ITEM]})

    id: int
    kind: Kind
    name: str
    display_name: str | None
    logo_asset_id: int | None
    logo: str | None
    category: Category | None
    country: str | None
    satellite_id: int | None
    frequency: Frequency | None
    frequency_note: str | None
    access: Access | None
    provider: str | None
    package: str | None
    beam: Beam | None
    show_in_match: bool
    sort_order: int | None
    hidden_by_name: bool
    # D3: the importer that created this placeholder; NULL for a normal channel (research R18).
    placeholder_source: str | None


class AdminChannel(ChannelItem):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.CHANNEL]})

    locked_fields: list[str]


class ChannelCreate(_Body):
    """A channel's ``kind`` decides which of the other fields it may have (``ck_channels_kind_fields``)."""

    kind: Kind
    name: Name120
    display_name: Name120 | None = None
    logo_asset_id: Id | None = None
    category: Category | None = None
    country: Name120 | None = None
    satellite_id: Id | None = None
    frequency: Frequency | None = None
    frequency_note: Text120 | None = None
    access: Access | None = None
    provider: Text120 | None = None
    package: Text120 | None = None
    beam: Beam | None = None
    show_in_match: bool = False
    sort_order: Int32 | None = None


class ChannelPatch(_Body):
    # A platform placeholder an importer made becomes a satellite channel here (A-R1-5); the new kind
    # has to satisfy the same field rules as a created one, in the same request.
    kind: Kind | None = Field(default=None)
    name: Name120 | None = Field(default=None)
    display_name: Name120 | None = None
    logo_asset_id: Id | None = None
    category: Category | None = None
    country: Name120 | None = None
    satellite_id: Id | None = None
    frequency: Frequency | None = None
    frequency_note: Text120 | None = None
    access: Access | None = None
    provider: Text120 | None = None
    package: Text120 | None = None
    beam: Beam | None = None
    show_in_match: bool | None = Field(default=None)
    sort_order: Int32 | None = None


class CommentatorUsage(BaseModel):
    matches: int
    match_channels: int


class AdminCommentator(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.COMMENTATOR]})

    id: int
    name: str
    photo_asset_id: int | None
    photo: str | None
    audio_asset_id: int | None
    audio: str | None
    usage: CommentatorUsage


class CommentatorCreate(_Body):
    name: Name120
    photo_asset_id: Id | None = None
    audio_asset_id: Id | None = None


class CommentatorPatch(_Body):
    name: Name120 | None = Field(default=None)
    photo_asset_id: Id | None = None
    audio_asset_id: Id | None = None


# --- D2: lists for A4 and uploads ------------------------------------------------------------------


class BroadcastPreset(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.BROADCAST_PRESET]})

    id: int
    name: str
    logo_asset_id: Id | None  # the id A4 saves in a slot's logo_asset_id (B1-R2-8)
    logo: str | None


class HiddenChannelName(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.HIDDEN_CHANNEL_NAME]})

    name: str


class HiddenChannelNameCreate(_Body):
    name: Name120


class SourceItem(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.SOURCE]})

    name: str
    kind: Literal["scraper", "api", "internal", "fixtures", "live_reader", "live"]
    is_enabled: bool


# --- D3: sources, runs, dashboard and ordering (contracts/admin-api.md) ----------------------------


class ImportRunRow(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.IMPORT_RUN_ROW]})

    id: Id
    status: Literal["running", "succeeded", "partial", "failed", "stopped"]
    started_at: datetime
    finished_at: datetime | None
    items_found: Int32
    items_upserted: Int32
    http_errors: Int32
    error: str | None


class ImportRunDetail(ImportRunRow):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.IMPORT_RUN_DETAIL]})

    raw_path: str | None
    log: dict[str, Any] | None
    log_available: bool
    pages: Int32
    worker: str | None


class RawPage(BaseModel):
    """A saved page as inert text, never a link (005 research R13). ``pending``: poll again, up to 10 s."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.RAW_PAGE]})

    state: Literal["pending", "ready", "gone"]
    page: Int32
    pages: Int32
    url: str | None
    content_type: str | None
    text: str | None
    truncated: bool


class LiveSourceCard(BaseModel):
    name: str
    state: Literal["ok", "failing", "down", "invalid"]


class LiveCard(BaseModel):
    matches_live: Int32
    error_share: Annotated[float, Field(ge=0, le=1)]
    sources: list[LiveSourceCard]


class SourceHealth(SourceItem):
    """D2's ``SourceItem`` with the health fields added (A13)."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.SOURCE_HEALTH]})

    breaker: Literal["closed", "open"]
    breaker_opened_at: datetime | None
    consecutive_failures: Int32
    paused: bool
    last_success_at: datetime | None
    last_run: ImportRunRow | None
    items_24h: list[Int32]
    error_rate_24h: Annotated[float, Field(ge=0, le=1)] | None
    running: bool
    live: LiveCard | None


class SourceRunQueued(BaseModel):
    queued: bool


class DashboardCompetition(BaseModel):
    id: Id | None
    name: str
    priority: int | None


class DashboardMatch(BaseModel):
    id: Id
    kickoff_at: datetime | None
    home: str
    away: str


class DashboardGroup(BaseModel):
    competition: DashboardCompetition
    matches: list[DashboardMatch]


class RecentChange(BaseModel):
    at: datetime
    by: ChangedBy
    entity: str
    entity_id: Id | None
    action: str


class Dashboard(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.DASHBOARD]})

    missing_channels: list[DashboardGroup]
    missing_channels_count: int
    placeholders_to_complete: int
    sources: list[SourceHealth]
    recent_changes: list[RecentChange]


class OrderItem(_Body):
    id: Id
    # Optional in the schema on purpose: a missing value must reach the service and get
    # `428 precondition_required` like a missing `If-Match`.
    if_match: Etag | None = Field(default=None, description="The row's current ETag. Required.")


class OrderRequest(_Body):
    """The full new order of the rows being moved, top first; each carries its version."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [{"items": [{"id": 12, "if_match": '"3f9a…"'}, {"id": 4, "if_match": '"7c2b…"'}]}]
        },
    )

    items: Annotated[list[OrderItem], Field(min_length=1, max_length=MAX_BULK_ITEMS)]

    @model_validator(mode="after")
    def _ids_are_unique(self) -> OrderRequest:
        ids = [item.id for item in self.items]
        if len(ids) != len(set(ids)):
            raise ValueError("repeated ids")
        return self


class MediaAsset(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.MEDIA_ASSET]})

    id: int
    kind: Literal["image", "audio"]
    url: str
    width: int | None
    height: int | None
    duration_ms: int | None
    bytes: int


# --- D6: notifications, staff accounts, audit and channel history (contracts/admin-api.md) --------
#
# The outbox log, the composer, A16's accounts, A17's audit and A8's history. Every ``GET`` carries
# an ``ETag``; the writes go through the writer and write ``audit_log`` (FR-024 to FR-026).


NotificationStatus = Literal["pending", "sending", "sent", "failed", "cancelled"]
NotificationAudienceKind = Literal[
    "match_followers", "match_core", "match_only", "channel", "team", "competition", "all", "device"
]
ReachKind = Literal["all", "team", "competition", "match", "channel"]
AnnouncementAudienceKind = Literal["all", "team", "competition", "match", "channel"]


class NotificationTarget(BaseModel):
    """Where a row went, built from current data; ``label`` is null for ``all`` (admin-api)."""

    kind: NotificationAudienceKind
    label: str | None
    id: int | None


class NotificationRow(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.NOTIFICATION_ROW]})

    id: Id
    type: NotificationType
    status: NotificationStatus
    error: str | None
    target: NotificationTarget
    is_test: bool
    is_correction: bool
    recipients: Int32
    sent: Int32
    failed: Int32
    due_at: datetime
    sent_at: datetime | None
    created_at: datetime
    etag: Etag  # the row's own version: what `POST notifications/{id}/cancel` checks as If-Match (B1-R1-2)


class NotificationReach(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.NOTIFICATION_REACH]})

    devices: Int32


class AnnouncementTarget(_Body):
    type: Literal["none", "match", "channel"]
    id: Id | None = None


class AnnouncementAudience(_Body):
    kind: AnnouncementAudienceKind
    id: Id | None = None


class AnnouncementCreate(_Body):
    """A15's composer; the route is built here, never sent as text (admin-api)."""

    model_config = ConfigDict(
        extra="forbid", json_schema_extra={"examples": [ex.ANNOUNCEMENT_BODY]}, str_strip_whitespace=True
    )

    # The label screen runs in the service, so it answers ``422 text_not_allowed`` (admin-api).
    title: Annotated[str, Field(min_length=1, max_length=65)]
    body: Annotated[str, Field(min_length=1, max_length=180)]
    target: AnnouncementTarget
    audience: AnnouncementAudience
    send_at: AwareDatetime | None = None


class TestSendCreate(_Body):
    """A test send goes to the admin's saved device, prefs ignored (admin-api)."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    title: Annotated[str, Field(min_length=1, max_length=65)]
    body: Annotated[str, Field(min_length=1, max_length=180)]
    target: AnnouncementTarget


class TestDeviceRow(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.TEST_DEVICE]})

    device_id: Id
    platform: str
    app_version: str | None
    has_push_token: bool


class TestDevicePatch(_Body):
    device_id: Id


class AdminUserRow(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.ADMIN_USER_ROW]})

    id: Id
    email: EmailStr
    name: str
    role: AdminRole
    is_active: bool
    # The TTL of ``auth:locked:<h>``, or null (research R19).
    locked_for_s: Int32 | None
    last_login_at: datetime | None
    must_change_password: bool
    etag: Etag  # the account's own version: what PATCH and reset-password check as If-Match (B1-R1-2)


class UserCreate(_Body):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    email: EmailStr = Field(max_length=254)
    name: Annotated[str, Field(min_length=1, max_length=80), AfterValidator(_no_card_sharing_label)]
    role: AdminRole


class UserPatch(_Body):
    name: Annotated[str, Field(min_length=1, max_length=80), AfterValidator(_no_card_sharing_label)] | None = None
    role: AdminRole | None = None
    is_active: bool | None = None


class UserWithPassword(BaseModel):
    """The temporary password is returned once, with ``Cache-Control: no-store``, and never stored in clear."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.USER_WITH_PASSWORD]})

    user: AdminUserRow
    temporary_password: str


class AuditActor(BaseModel):
    kind: Literal["admin", "importer", "system"]
    id: int | None
    name: str | None


class AuditRow(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [ex.AUDIT_ROW]})

    id: Id
    created_at: datetime
    actor: AuditActor
    entity: str
    entity_id: Id | None
    action: str
    summary_fields: list[str]
    has_notification: bool


class AuditNotification(BaseModel):
    id: Id
    type: NotificationType
    status: NotificationStatus
    sent: Int32
    failed: Int32


class AuditDetail(AuditRow):
    """``diff`` exactly as stored, old shapes included, and the outbox row that links to this entry."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.AUDIT_DETAIL]})

    diff: dict[str, Any]
    notification: AuditNotification | None


class FrequencyHistoryRow(BaseModel):
    """What followers of a carriage were told; ``actor`` from the row's own audit id (research R6, R20)."""

    model_config = ConfigDict(json_schema_extra={"examples": [ex.FREQUENCY_HISTORY_ROW]})

    id: Id
    old: str
    new: str
    source: str
    actor: str | None
    detected_at: datetime
