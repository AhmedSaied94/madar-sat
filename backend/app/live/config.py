"""The live poller's settings, read from the worker's environment (005 contracts/live-pipeline.md).

Separate from ``app.settings``, like ``app.adapters.config``: importing ``app.workers`` must load
neither ``app.settings`` nor ``app.db``. The capture report sets the page caps and the timers.
"""

from __future__ import annotations

from datetime import timedelta
from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class LiveSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None, extra="ignore", case_sensitive=False)

    page_cap_filgoal: int = Field(default=8, ge=0, alias="LIVE_PAGE_CAP_FILGOAL")
    page_cap_yallakora: int = Field(default=2, ge=0, alias="LIVE_PAGE_CAP_YALLAKORA")
    page_cap_goal: int = Field(default=4, ge=0, alias="LIVE_PAGE_CAP_GOAL")
    goal_enabled: bool = Field(default=True, alias="LIVE_GOAL_ENABLED")
    drop_hold_s: int = Field(default=300, ge=0, alias="LIVE_DROP_HOLD_S")
    disagree_after_s: int = Field(default=600, ge=0, alias="LIVE_DISAGREE_AFTER_S")
    fulltime_hold_s: int = Field(default=600, ge=0, alias="LIVE_FULLTIME_HOLD_S")
    stuck_after_min: int = Field(default=150, ge=1, alias="LIVE_STUCK_AFTER_MIN")
    stuck_quiet_min: int = Field(default=15, ge=0, alias="LIVE_STUCK_QUIET_MIN")
    down_after_failures: int = Field(default=3, ge=1, alias="LIVE_DOWN_AFTER_FAILURES")
    stale_after_s: int = Field(default=300, ge=1, alias="LIVE_STALE_AFTER_S")
    hard_limit_min: int = Field(default=210, ge=1, alias="LIVE_HARD_LIMIT_MIN")

    @property
    def drop_hold(self) -> timedelta:
        return timedelta(seconds=self.drop_hold_s)

    @property
    def disagree_after(self) -> timedelta:
        return timedelta(seconds=self.disagree_after_s)

    @property
    def fulltime_hold(self) -> timedelta:
        return timedelta(seconds=self.fulltime_hold_s)

    @property
    def stuck_after(self) -> timedelta:
        return timedelta(minutes=self.stuck_after_min)

    @property
    def stuck_quiet(self) -> timedelta:
        return timedelta(minutes=self.stuck_quiet_min)

    @property
    def stale_after(self) -> timedelta:
        return timedelta(seconds=self.stale_after_s)

    @property
    def hard_limit(self) -> timedelta:
        return timedelta(minutes=self.hard_limit_min)


@lru_cache
def get_live_settings() -> LiveSettings:
    return LiveSettings()
