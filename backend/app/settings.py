"""Application settings.

Every secret is required with no default: a missing value fails fast at import so
a misconfigured deployment never serves with empty credentials (constitution V).
"""

from __future__ import annotations

from functools import lru_cache
from typing import Annotated

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None, extra="ignore", case_sensitive=False)

    # Database: asyncpg for the API, psycopg (sync) for the CLI and Alembic.
    database_url: str = Field(alias="DATABASE_URL")
    database_url_sync: str = Field(alias="DATABASE_URL_SYNC")

    # Services.
    redis_url: str = Field(alias="REDIS_URL")

    # Media.
    media_base_url: str = Field(alias="MEDIA_BASE_URL")
    media_root: str = Field(alias="MEDIA_ROOT")
    media_rehost_allowed_hosts: Annotated[list[str], NoDecode] = Field(alias="MEDIA_REHOST_ALLOWED_HOSTS")

    # HTTP.
    cors_origins: Annotated[list[str], NoDecode] = Field(alias="CORS_ORIGINS")
    contract_version: str = Field(default="1.0.0", alias="CONTRACT_VERSION")

    # Admin access-token signing key (research R2). Only api-admin needs it, so it is optional
    # here and checked when that app starts (app.admin lifespan); the public app and the
    # workers never read it. No default: a deployment without it must not sign anything.
    admin_jwt_secret: SecretStr | None = Field(default=None, alias="ADMIN_JWT_SECRET")

    # Rollback drill only (never used for real traffic).
    healthz_force_fail: bool = Field(default=False, alias="HEALTHZ_FORCE_FAIL")

    @field_validator("media_rehost_allowed_hosts", "cors_origins", mode="before")
    @classmethod
    def _split_comma_list(cls, v: object) -> object:
        if isinstance(v, str):
            return [item.strip() for item in v.split(",") if item.strip()]
        return v


@lru_cache
def get_settings() -> Settings:
    return Settings()
