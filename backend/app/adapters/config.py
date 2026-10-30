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


class AdapterSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None, extra="ignore", case_sensitive=False)

    # The Firestore bridge. The old project's configuration lives only in VPS-2's .env (D15, FR-052).
    satair_firebase_project_id: str | None = Field(default=None, alias="SATAIR_FIREBASE_PROJECT_ID")
    satair_firebase_api_key: SecretStr | None = Field(default=None, alias="SATAIR_FIREBASE_API_KEY")

    scrape_user_agent: str | None = Field(default=None, alias="SCRAPE_USER_AGENT")
    ysscores_fetch_queue: Literal["scrape_home", "scrape"] = Field(default="scrape_home", alias="YSSCORES_FETCH_QUEUE")
    raw_root: Path = Field(default=Path("/srv/raw"), alias="RAW_ROOT")

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


@lru_cache
def get_adapter_settings() -> AdapterSettings:
    return AdapterSettings()
