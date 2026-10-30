"""The worker app's own settings (research R13, FR-028).

The scrape worker on the home box has Redis and nothing else: no database URL, no media
root. ``app.settings.Settings`` requires those, so this small class reads only the broker
URL. Importing ``app.workers`` must never import ``app.settings`` or ``app.db``.
"""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class WorkerSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None, extra="ignore", case_sensitive=False)

    # ``vps2.yml`` names CELERY_BROKER_URL; the home box sets only REDIS_URL.
    celery_broker_url: str | None = Field(default=None, alias="CELERY_BROKER_URL")
    redis_url: str | None = Field(default=None, alias="REDIS_URL")

    @property
    def broker_url(self) -> str:
        url = self.celery_broker_url or self.redis_url
        if not url:
            raise RuntimeError("the worker app needs CELERY_BROKER_URL (or REDIS_URL) to find its broker")
        return url


@lru_cache
def get_worker_settings() -> WorkerSettings:
    return WorkerSettings()
