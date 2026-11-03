"""Application settings.

Every secret is required with no default: a missing value fails fast at import so
a misconfigured deployment never serves with empty credentials (constitution V).
"""

from __future__ import annotations

import ipaddress
from functools import lru_cache
from pathlib import Path
from typing import Annotated

from pydantic import AnyHttpUrl, Field, SecretStr, ValidationInfo, field_validator
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

    # D3 notifications (research R8-R9). Read by the notifications worker only: the public and
    # admin apps start without them, so the credential file is not a required setting.
    fcm_credentials_file: Path | None = Field(default=None, alias="FCM_CREDENTIALS_FILE")
    fcm_dry_run: bool = Field(default=False, alias="FCM_DRY_RUN")
    # The web push link's origin. https only: an ``http://`` origin makes FCM refuse every web
    # message with INVALID_ARGUMENT on ``fcm_options.link`` (B1-R1-2).
    pwa_origin: AnyHttpUrl | None = Field(default=None, alias="PWA_ORIGIN")

    # D3 response cache (research R10).
    response_cache_enabled: bool = Field(default=True, alias="RESPONSE_CACHE_ENABLED")
    response_cache_max_bytes: int = Field(default=524288, alias="RESPONSE_CACHE_MAX_BYTES")

    # D3 rate limits on /v1 (research R11); values, not contract.
    rate_limit_device_per_min: int = Field(default=120, alias="RATE_LIMIT_DEVICE_PER_MIN")
    rate_limit_ip_per_min: int = Field(default=600, alias="RATE_LIMIT_IP_PER_MIN")
    rate_limit_register_per_10min: int = Field(default=30, alias="RATE_LIMIT_REGISTER_PER_10MIN")

    # D4 client IP and the load-test allowlist (research R1, R3). Both are comma lists that live only
    # in the host .env: TRUSTED_PROXIES is who may set X-Forwarded-For (Caddy; keep the admin on the
    # default), RATE_LIMIT_EXEMPT_IPS holds the load generator's address for one window and then
    # goes back to empty. A value that isn't an IP fails startup (constitution V).
    trusted_proxies: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: ["10.8.0.1"], alias="TRUSTED_PROXIES"
    )
    rate_limit_exempt_ips: Annotated[list[str], NoDecode] = Field(default_factory=list, alias="RATE_LIMIT_EXEMPT_IPS")

    @field_validator(
        "media_rehost_allowed_hosts",
        "cors_origins",
        "trusted_proxies",
        "rate_limit_exempt_ips",
        mode="before",
    )
    @classmethod
    def _split_comma_list(cls, v: object) -> object:
        if isinstance(v, str):
            return [item.strip() for item in v.split(",") if item.strip()]
        return v

    @field_validator("trusted_proxies", "rate_limit_exempt_ips")
    @classmethod
    def _each_entry_is_an_ip(cls, value: list[str], info: ValidationInfo) -> list[str]:
        alias = {
            "trusted_proxies": "TRUSTED_PROXIES",
            "rate_limit_exempt_ips": "RATE_LIMIT_EXEMPT_IPS",
        }.get(str(info.field_name), str(info.field_name))
        addresses: list[str] = []
        for entry in value:
            try:
                addresses.append(str(ipaddress.ip_address(entry)))
            except ValueError as error:
                raise ValueError(f"{alias} must be a comma list of IP addresses; {entry!r} is not one") from error
        return addresses

    @field_validator("pwa_origin")
    @classmethod
    def _pwa_origin_is_https(cls, value: AnyHttpUrl | None) -> AnyHttpUrl | None:
        if value is not None and value.scheme != "https":
            raise ValueError("PWA_ORIGIN must be an https origin")
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
