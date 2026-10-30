"""The three beat entries and their queues (T076, contracts/ingestion.md §Queues)."""

from __future__ import annotations

import pytest

from app.adapters.config import get_adapter_settings
from app.adapters.schedule import beat_schedule, build_beat_schedule


@pytest.fixture(autouse=True)
def _fresh_settings():
    """The adapter settings are cached for the worker's life; each test needs its own environment."""
    get_adapter_settings.cache_clear()
    yield
    get_adapter_settings.cache_clear()


def test_the_three_entries_and_their_utc_schedules() -> None:
    schedule = beat_schedule
    assert set(schedule) == {"ysscores-fixtures", "satair-bridge", "prune-raw-pages"}

    ysscores = schedule["ysscores-fixtures"]
    assert ysscores["task"] == "adapters.fetch"
    assert ysscores["args"] == ("ysscores",)
    assert str(ysscores["schedule"]) == "<crontab: 0 */3 * * * (m/h/dM/MY/d)>"

    bridge = schedule["satair-bridge"]
    assert bridge["task"] == "adapters.fetch"
    assert bridge["args"] == ("legacy",)
    assert str(bridge["schedule"]) == "<crontab: 30 1-22/3 * * * (m/h/dM/MY/d)>"

    prune = schedule["prune-raw-pages"]
    assert prune["task"] == "adapters.prune_raw_pages"
    assert prune["args"] == ()
    assert str(prune["schedule"]) == "<crontab: 15 3 * * * (m/h/dM/MY/d)>"


def test_the_queues_follow_the_hosts() -> None:
    schedule = build_beat_schedule()
    assert schedule["ysscores-fixtures"]["options"] == {"queue": "scrape_home"}
    assert schedule["satair-bridge"]["options"] == {"queue": "scrape"}
    assert schedule["prune-raw-pages"]["options"] == {"queue": "maintenance"}


def test_ysscores_moves_to_vps2_when_the_setting_says_so(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("YSSCORES_FETCH_QUEUE", "scrape")
    assert build_beat_schedule()["ysscores-fixtures"]["options"] == {"queue": "scrape"}
