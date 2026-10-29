"""SQLAlchemy 2 mapped classes for every table the API and loader read.

The naming convention reproduces ``schema.sql``'s names: CHECKs are ``ck_<table>_<rule>``
and everything else keeps PostgreSQL's default names. ``name_norm`` columns are
``GENERATED ALWAYS AS (...) STORED`` and therefore read-only.
"""

from __future__ import annotations

from datetime import date, datetime
from typing import Any

from sqlalchemy import (
    BigInteger,
    Boolean,
    Computed,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    MetaData,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "%(table_name)s_%(column_0_name)s_key",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "%(table_name)s_%(column_0_name)s_fkey",
    "pk": "%(table_name)s_pkey",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


# --- Reference data -----------------------------------------------------------


class Source(Base):
    __tablename__ = "sources"

    name: Mapped[str] = mapped_column(Text, primary_key=True)
    kind: Mapped[str] = mapped_column(Text)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    paused_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MediaAsset(Base):
    __tablename__ = "media_assets"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    sha256: Mapped[str] = mapped_column(String(64), unique=True)
    kind: Mapped[str] = mapped_column(Text)  # logo | photo | audio
    path: Mapped[str] = mapped_column(Text, unique=True)
    mime: Mapped[str] = mapped_column(Text)  # image/webp | audio/mp4
    bytes: Mapped[int] = mapped_column(Integer)
    width: Mapped[int | None] = mapped_column(SmallInteger)
    height: Mapped[int | None] = mapped_column(SmallInteger)
    duration_ms: Mapped[int | None] = mapped_column(Integer)
    original_url: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Satellite(Base):
    __tablename__ = "satellites"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    legacy_id: Mapped[str | None] = mapped_column(Text, unique=True)
    slug: Mapped[str] = mapped_column(Text, unique=True)
    kind: Mapped[str] = mapped_column(Text, default="satellite")
    name_en: Mapped[str] = mapped_column(Text)
    name_ar: Mapped[str] = mapped_column(Text)
    orbital_position: Mapped[Any | None] = mapped_column(Numeric(4, 1))
    logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    best_frequency_mhz: Mapped[int | None] = mapped_column(Integer)
    best_polarization: Mapped[str | None] = mapped_column(String(1))
    best_symbol_rate: Mapped[int | None] = mapped_column(Integer)
    worst_frequency_mhz: Mapped[int | None] = mapped_column(Integer)
    worst_polarization: Mapped[str | None] = mapped_column(String(1))
    worst_symbol_rate: Mapped[int | None] = mapped_column(Integer)
    reception_url: Mapped[str | None] = mapped_column(Text)
    priority: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Competition(Base):
    __tablename__ = "competitions"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    legacy_id: Mapped[str | None] = mapped_column(Text, unique=True)
    sport: Mapped[str] = mapped_column(String(32), default="football")
    name: Mapped[str] = mapped_column(Text)
    name_norm: Mapped[str] = mapped_column(Text, Computed("ar_normalize(name)", persisted=True))
    logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    priority: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class CompetitionExternalId(Base):
    __tablename__ = "competition_external_ids"

    source: Mapped[str] = mapped_column(ForeignKey("sources.name"), primary_key=True)
    external_id: Mapped[str] = mapped_column(Text, primary_key=True)
    competition_id: Mapped[int] = mapped_column(ForeignKey("competitions.id", ondelete="CASCADE"))


class Channel(Base):
    __tablename__ = "channels"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    legacy_id: Mapped[str | None] = mapped_column(Text, unique=True)
    kind: Mapped[str] = mapped_column(Text)
    name: Mapped[str] = mapped_column(Text)
    name_norm: Mapped[str] = mapped_column(Text, Computed("ar_normalize(name)", persisted=True))
    display_name: Mapped[str | None] = mapped_column(Text)
    logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    category: Mapped[str | None] = mapped_column(Text)
    country: Mapped[str | None] = mapped_column(Text)
    satellite_id: Mapped[int | None] = mapped_column(ForeignKey("satellites.id"))
    frequency_mhz: Mapped[int | None] = mapped_column(Integer)
    polarization: Mapped[str | None] = mapped_column(String(1))
    symbol_rate: Mapped[int | None] = mapped_column(Integer)
    frequency_note: Mapped[str | None] = mapped_column(Text)
    access: Mapped[str | None] = mapped_column(Text)
    provider: Mapped[str | None] = mapped_column(Text)
    package: Mapped[str | None] = mapped_column(Text)
    beam: Mapped[str | None] = mapped_column(Text)
    show_in_match: Mapped[bool] = mapped_column(Boolean, default=False)
    sort_order: Mapped[int | None] = mapped_column(Integer)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    locked_fields: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    frequency_changed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class HiddenChannelName(Base):
    __tablename__ = "hidden_channel_names"

    name: Mapped[str] = mapped_column(Text, primary_key=True)


class Team(Base):
    __tablename__ = "teams"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    legacy_id: Mapped[str | None] = mapped_column(Text, unique=True)
    sport: Mapped[str] = mapped_column(String(32), default="football")
    name: Mapped[str] = mapped_column(Text)
    name_norm: Mapped[str] = mapped_column(Text, Computed("ar_normalize(name)", persisted=True))
    country: Mapped[str | None] = mapped_column(Text)
    logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    stadium: Mapped[str | None] = mapped_column(Text)
    primary_competition_id: Mapped[int | None] = mapped_column(ForeignKey("competitions.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class TeamExternalId(Base):
    __tablename__ = "team_external_ids"

    source: Mapped[str] = mapped_column(ForeignKey("sources.name"), primary_key=True)
    external_id: Mapped[str] = mapped_column(Text, primary_key=True)
    team_id: Mapped[int] = mapped_column(ForeignKey("teams.id", ondelete="CASCADE"))


class TeamCompetition(Base):
    __tablename__ = "team_competitions"

    team_id: Mapped[int] = mapped_column(ForeignKey("teams.id", ondelete="CASCADE"), primary_key=True)
    competition_id: Mapped[int] = mapped_column(ForeignKey("competitions.id", ondelete="CASCADE"), primary_key=True)


class LivesoccertvTeam(Base):
    __tablename__ = "livesoccertv_teams"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    ar_name: Mapped[str] = mapped_column(Text)
    ar_name_norm: Mapped[str] = mapped_column(Text, Computed("ar_normalize(ar_name)", persisted=True))
    en_name: Mapped[str] = mapped_column(Text)
    country: Mapped[str | None] = mapped_column(Text)
    slug: Mapped[str] = mapped_column(Text)
    team_id: Mapped[int | None] = mapped_column(ForeignKey("teams.id", ondelete="SET NULL"))
    saved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    __table_args__ = (
        UniqueConstraint("ar_name", "country", "slug", name="livesoccertv_teams_ar_name_country_slug_key"),
    )


class Commentator(Base):
    __tablename__ = "commentators"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(Text)
    name_norm: Mapped[str] = mapped_column(Text, Computed("ar_normalize(name)", persisted=True))
    photo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    audio_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class BroadcastPreset(Base):
    __tablename__ = "broadcast_presets"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(Text, unique=True)
    logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))


# --- Rights holders -----------------------------------------------------------


class RightsHolder(Base):
    __tablename__ = "rights_holders"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    legacy_id: Mapped[str | None] = mapped_column(Text, unique=True)
    name: Mapped[str] = mapped_column(Text)
    logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    sort_order: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RightsHolderCompetition(Base):
    __tablename__ = "rights_holder_competitions"

    rights_holder_id: Mapped[int] = mapped_column(ForeignKey("rights_holders.id", ondelete="CASCADE"), primary_key=True)
    competition_id: Mapped[int] = mapped_column(ForeignKey("competitions.id", ondelete="CASCADE"), primary_key=True)


class RightsHolderCarriage(Base):
    __tablename__ = "rights_holder_carriages"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    rights_holder_id: Mapped[int] = mapped_column(ForeignKey("rights_holders.id", ondelete="CASCADE"))
    position: Mapped[int] = mapped_column(SmallInteger)
    access: Mapped[str] = mapped_column(Text)
    beam: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (UniqueConstraint("rights_holder_id", "position"),)


class RightsHolderCarriageSatellite(Base):
    __tablename__ = "rights_holder_carriage_satellites"

    carriage_id: Mapped[int] = mapped_column(
        ForeignKey("rights_holder_carriages.id", ondelete="CASCADE"), primary_key=True
    )
    satellite_id: Mapped[int] = mapped_column(ForeignKey("satellites.id"), primary_key=True)


class RightsHolderFrequency(Base):
    __tablename__ = "rights_holder_frequencies"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    carriage_id: Mapped[int] = mapped_column(ForeignKey("rights_holder_carriages.id", ondelete="CASCADE"))
    frequency_mhz: Mapped[int] = mapped_column(Integer)
    polarization: Mapped[str] = mapped_column(String(1))
    symbol_rate: Mapped[int] = mapped_column(Integer)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)

    __table_args__ = (UniqueConstraint("carriage_id", "frequency_mhz", "polarization", "symbol_rate"),)


# --- Matches ------------------------------------------------------------------


class Match(Base):
    __tablename__ = "matches"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    legacy_id: Mapped[str | None] = mapped_column(Text, unique=True)
    sport: Mapped[str] = mapped_column(String(32), default="football")
    source: Mapped[str] = mapped_column(ForeignKey("sources.name"))
    match_date: Mapped[date] = mapped_column(Date)
    kickoff_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    competition_id: Mapped[int | None] = mapped_column(ForeignKey("competitions.id", ondelete="SET NULL"))
    competition_name: Mapped[str] = mapped_column(Text)
    competition_stage: Mapped[str | None] = mapped_column(Text)
    home_team_id: Mapped[int | None] = mapped_column(ForeignKey("teams.id", ondelete="SET NULL"))
    home_team_name: Mapped[str] = mapped_column(Text)
    home_logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    away_team_id: Mapped[int | None] = mapped_column(ForeignKey("teams.id", ondelete="SET NULL"))
    away_team_name: Mapped[str] = mapped_column(Text)
    away_logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    stadium: Mapped[str | None] = mapped_column(Text)
    commentator_id: Mapped[int | None] = mapped_column(ForeignKey("commentators.id", ondelete="SET NULL"))
    is_live: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[str] = mapped_column(Text, default="scheduled")
    period: Mapped[str | None] = mapped_column(Text)
    minute: Mapped[str | None] = mapped_column(Text)
    home_score: Mapped[int | None] = mapped_column(SmallInteger)
    away_score: Mapped[int | None] = mapped_column(SmallInteger)
    home_pen: Mapped[int | None] = mapped_column(SmallInteger)
    away_pen: Mapped[int | None] = mapped_column(SmallInteger)
    status_source: Mapped[str] = mapped_column(Text, default="clock")
    status_label: Mapped[str | None] = mapped_column(Text)
    status_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    time_tbd: Mapped[bool] = mapped_column(Boolean, default=False)
    locked_fields: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MatchExternalId(Base):
    __tablename__ = "match_external_ids"

    source: Mapped[str] = mapped_column(ForeignKey("sources.name"), primary_key=True)
    external_id: Mapped[str] = mapped_column(Text, primary_key=True)
    match_id: Mapped[int] = mapped_column(ForeignKey("matches.id"))
    url: Mapped[str | None] = mapped_column(Text)


class MatchChannel(Base):
    __tablename__ = "match_channels"

    match_id: Mapped[int] = mapped_column(ForeignKey("matches.id"), primary_key=True)
    channel_id: Mapped[int] = mapped_column(ForeignKey("channels.id"), primary_key=True)
    source: Mapped[str] = mapped_column(ForeignKey("sources.name"))
    is_hidden: Mapped[bool] = mapped_column(Boolean, default=False)
    commentator_id: Mapped[int | None] = mapped_column(ForeignKey("commentators.id", ondelete="SET NULL"))
    commentator2_id: Mapped[int | None] = mapped_column(ForeignKey("commentators.id", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MatchCustomBroadcast(Base):
    __tablename__ = "match_custom_broadcasts"

    match_id: Mapped[int] = mapped_column(ForeignKey("matches.id"), primary_key=True)
    slot: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    label: Mapped[str] = mapped_column(Text)
    logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    commentator_id: Mapped[int | None] = mapped_column(ForeignKey("commentators.id", ondelete="SET NULL"))


class Feed(Base):
    __tablename__ = "feeds"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    legacy_id: Mapped[str | None] = mapped_column(Text, unique=True)
    match_id: Mapped[int | None] = mapped_column(ForeignKey("matches.id"))
    feed_date: Mapped[date] = mapped_column(Date)
    home_team_name: Mapped[str] = mapped_column(Text)
    away_team_name: Mapped[str] = mapped_column(Text)
    home_logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    away_logo_asset_id: Mapped[int | None] = mapped_column(ForeignKey("media_assets.id"))
    lines: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ImportRun(Base):
    __tablename__ = "import_runs"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    source: Mapped[str] = mapped_column(ForeignKey("sources.name"))
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    matches_imported: Mapped[int] = mapped_column(Integer, default=0)
    error: Mapped[str | None] = mapped_column(Text)
    items_found: Mapped[int] = mapped_column(Integer, default=0)
    items_upserted: Mapped[int] = mapped_column(Integer, default=0)
    http_errors: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(Text, default="running")
    raw_path: Mapped[str | None] = mapped_column(Text)


# --- 0002 additions (created now, used on D2/D3) ------------------------------


class AdminUser(Base):
    __tablename__ = "admin_users"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(Text)
    name: Mapped[str] = mapped_column(Text)
    role: Mapped[str] = mapped_column(Text)
    password_hash: Mapped[str] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AdminRefreshToken(Base):
    __tablename__ = "admin_refresh_tokens"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    admin_user_id: Mapped[int] = mapped_column(ForeignKey("admin_users.id", ondelete="CASCADE"))
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    family_id: Mapped[Any] = mapped_column(PG_UUID)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    replaced_by_id: Mapped[int | None] = mapped_column(ForeignKey("admin_refresh_tokens.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AuditLog(Base):
    __tablename__ = "audit_log"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    admin_user_id: Mapped[int | None] = mapped_column(ForeignKey("admin_users.id", ondelete="SET NULL"))
    entity: Mapped[str] = mapped_column(Text)
    entity_id: Mapped[int | None] = mapped_column(BigInteger)
    action: Mapped[str] = mapped_column(Text)
    diff: Mapped[Any] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    install_id: Mapped[Any] = mapped_column(PG_UUID, unique=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    platform: Mapped[str] = mapped_column(Text)
    push_token: Mapped[str | None] = mapped_column(Text, unique=True)
    app_version: Mapped[str | None] = mapped_column(Text)
    locale: Mapped[str | None] = mapped_column(Text)
    tz: Mapped[str | None] = mapped_column(Text)
    prefs: Mapped[Any] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DeviceFollow(Base):
    __tablename__ = "device_follows"

    device_id: Mapped[int] = mapped_column(ForeignKey("devices.id", ondelete="CASCADE"), primary_key=True)
    team_id: Mapped[int | None] = mapped_column(ForeignKey("teams.id", ondelete="CASCADE"), primary_key=True)
    competition_id: Mapped[int | None] = mapped_column(
        ForeignKey("competitions.id", ondelete="CASCADE"), primary_key=True
    )
    match_id: Mapped[int | None] = mapped_column(ForeignKey("matches.id"), primary_key=True)
    channel_id: Mapped[int | None] = mapped_column(ForeignKey("channels.id", ondelete="CASCADE"), primary_key=True)
    commentator_id: Mapped[int | None] = mapped_column(
        ForeignKey("commentators.id", ondelete="CASCADE"), primary_key=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class NotificationOutbox(Base):
    __tablename__ = "notification_outbox"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    type: Mapped[str] = mapped_column(Text)
    dedupe_key: Mapped[str] = mapped_column(Text, unique=True)
    payload: Mapped[Any] = mapped_column(JSONB)
    audience: Mapped[Any] = mapped_column(JSONB)
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(Text, default="pending")
    sent: Mapped[int] = mapped_column(Integer, default=0)
    failed: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class DatasetVersion(Base):
    __tablename__ = "dataset_versions"

    name: Mapped[str] = mapped_column(Text, primary_key=True)
    version: Mapped[int] = mapped_column(BigInteger, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


DATASET_NAMES = (
    "matches",
    "live",
    "channels",
    "satellites",
    "competitions",
    "teams",
    "commentators",
    "rights_holders",
)
