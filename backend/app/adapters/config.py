"""Lane B2's own settings, read from the worker's environment only.

It is deliberately separate from ``app.settings``: the home box runs the fetch path with no
database, media or CORS values, so importing this module must never require them (FR-028, T051).
Every value fails fast only in the task that needs it, so a host can start without the bridge's
Sat Air configuration and the fetch path still works.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

# R16: the countries LiveSoccerTV listings are read from, before normalization. A name from another
# country is skipped unless Madar already has that channel; these are the ones worth a placeholder.
MENA_COUNTRIES = (
    "Egypt",
    "Saudi Arabia",
    "United Arab Emirates",
    "Qatar",
    "Kuwait",
    "Bahrain",
    "Oman",
    "Jordan",
    "Lebanon",
    "Syria",
    "Iraq",
    "Palestine",
    "Yemen",
    "Libya",
    "Tunisia",
    "Algeria",
    "Morocco",
    "Mauritania",
    "Sudan",
    "Somalia",
    "Djibouti",
    "Comoros",
    "Middle East",
    "MENA",
    "North Africa",
    "Arab World",
)


def normalize_country(value: str | None) -> str:
    """``"United Arab Emirates"`` -> ``"united-arab-emirates"`` (``LVS.html``'s ``normalizeCountry``)."""
    if not value:
        return ""
    lowered = value.strip().lower().replace("_", " ")
    kept = "".join(char if char.isascii() and char.isalpha() or char.isspace() else "-" for char in lowered)
    return "-".join(part for part in kept.split() if part)


# The aliases ``LVS.html``'s ``countriesMatch`` accepts for the same country (R15).
COUNTRY_ALIASES: dict[str, tuple[str, ...]] = {
    "england": ("united-kingdom", "uk", "britain"),
    "united-kingdom": ("england",),
    "south-korea": ("korea",),
    "korea": ("south-korea",),
    "uae": ("united-arab-emirates", "emirates"),
    "united-arab-emirates": ("uae",),
    "usa": ("united-states", "us"),
    "united-states": ("usa",),
}


def countries_match(first: str | None, second: str | None) -> bool:
    """Whether two listings' countries are the same place under the documented aliases."""
    left, right = normalize_country(first), normalize_country(second)
    if not left or not right:
        return False
    return left == right or right in COUNTRY_ALIASES.get(left, ())


class AdapterSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None, extra="ignore", case_sensitive=False)

    # The Firestore bridge. The old project's configuration lives only in VPS-2's .env (D15, FR-052).
    satair_firebase_project_id: str | None = Field(default=None, alias="SATAIR_FIREBASE_PROJECT_ID")
    satair_firebase_api_key: SecretStr | None = Field(default=None, alias="SATAIR_FIREBASE_API_KEY")

    scrape_user_agent: str | None = Field(default=None, alias="SCRAPE_USER_AGENT")
    ysscores_fetch_queue: Literal["scrape_home", "scrape"] = Field(default="scrape_home", alias="YSSCORES_FETCH_QUEUE")
    raw_root: Path = Field(default=Path("/srv/raw"), alias="RAW_ROOT")

    # LiveSoccerTV (R14–R16). The country list is a setting, not a release: changing it needs a
    # restarted worker and beat (the runbook says so).
    livesoccertv_countries: str = Field(default=",".join(MENA_COUNTRIES), alias="LIVESOCCERTV_COUNTRIES")
    livesoccertv_fetch_queue: Literal["scrape_home", "scrape"] = Field(
        default="scrape_home", alias="LIVESOCCERTV_FETCH_QUEUE"
    )

    # Source health (R17) and the two alert channels.
    source_breaker_threshold: int = Field(default=3, alias="SOURCE_BREAKER_THRESHOLD", ge=1)
    telegram_bot_token: SecretStr | None = Field(default=None, alias="TELEGRAM_BOT_TOKEN")
    telegram_chat_id: str | None = Field(default=None, alias="TELEGRAM_CHAT_ID")

    # Uptime Kuma push monitors, one per Celery queue (contracts/pipelines-and-ops.md §Heartbeats).
    kuma_push_url_maintenance: str | None = Field(default=None, alias="KUMA_PUSH_URL_MAINTENANCE")
    kuma_push_url_imports: str | None = Field(default=None, alias="KUMA_PUSH_URL_IMPORTS")
    kuma_push_url_notifications: str | None = Field(default=None, alias="KUMA_PUSH_URL_NOTIFICATIONS")

    def countries(self) -> tuple[str, ...]:
        """The configured countries, normalized and de-duplicated, order kept (R16)."""
        raw = self.livesoccertv_countries
        if not raw.strip():
            raw = ",".join(MENA_COUNTRIES)
        wanted: list[str] = []
        for part in raw.split(","):
            normal = normalize_country(part)
            if normal and normal not in wanted:
                wanted.append(normal)
        return tuple(wanted)

    def require_user_agent(self) -> str:
        if not self.scrape_user_agent:
            raise RuntimeError("SCRAPE_USER_AGENT is not set; the fetcher refuses to send an anonymous agent")
        return self.scrape_user_agent

    def require_bridge(self) -> tuple[str, str]:
        """The bridge's project id and API key; the only place they are read (FR-027)."""
        if not self.satair_firebase_project_id or not self.satair_firebase_api_key:
            raise RuntimeError(
                "SATAIR_FIREBASE_PROJECT_ID and SATAIR_FIREBASE_API_KEY are not set; the bridge needs both"
            )
        return self.satair_firebase_project_id, self.satair_firebase_api_key.get_secret_value()

    def telegram_target(self) -> tuple[str, str] | None:
        """``(bot_token, chat_id)``, or ``None`` when alerts are log-only (R17)."""
        if not self.telegram_bot_token or not self.telegram_chat_id:
            return None
        return self.telegram_bot_token.get_secret_value(), self.telegram_chat_id

    def kuma_push_url(self, queue: str) -> str | None:
        """The heartbeat URL for a Celery queue; ``None`` leaves the queue unmonitored."""
        return {
            "maintenance": self.kuma_push_url_maintenance,
            "imports": self.kuma_push_url_imports,
            "notifications": self.kuma_push_url_notifications,
        }.get(queue)


@lru_cache
def get_adapter_settings() -> AdapterSettings:
    return AdapterSettings()
