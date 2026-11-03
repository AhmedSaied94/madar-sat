"""``adapters.schedule_fetch``: pause, breaker, planning and queues (T058, T066, T069, R14, R17)."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Any

import pytest

from app.adapters.config import get_adapter_settings
from app.adapters.livesoccertv import MemoryRecentFetches, plan_targets
from app.adapters.schedule import BEAT_SCHEDULE
from app.adapters.tasks import schedule_fetch
from app.db.models import Source
from tests.adapters.helpers import new_lst_team, new_match, new_team

NOW = datetime(2026, 11, 7, 12, 0, tzinfo=UTC)


@pytest.fixture(autouse=True)
def _fresh_settings():
    get_adapter_settings.cache_clear()
    yield
    get_adapter_settings.cache_clear()


@pytest.fixture(autouse=True)
def _task_session(monkeypatch: pytest.MonkeyPatch, sync_session):
    """The task opens its own session; point it at the test's transaction (as ``test_tasks`` does)."""
    from sqlalchemy.orm import Session

    import app.db.session as db_session

    def factory() -> Session:
        return Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint")

    monkeypatch.setattr(db_session, "SyncSession", factory)
    return factory


@pytest.fixture
def sent(monkeypatch: pytest.MonkeyPatch) -> list[dict[str, Any]]:
    """Capture what would have been published instead of running the fetch eagerly."""
    from app.adapters import tasks

    calls: list[dict[str, Any]] = []
    monkeypatch.setattr(tasks.fetch, "apply_async", lambda **kwargs: calls.append(kwargs))
    return calls


def _pause(session: Any, name: str = "livesoccertv") -> None:
    source = session.get(Source, name)
    assert source is not None
    source.is_enabled = False
    session.flush()


def test_the_registered_task_name_is_exactly_schedule_fetch() -> None:
    """A13's «تشغيل الآن» sends the name through ``send_task``, so it must not drift (T069)."""
    from app.workers import app

    assert "adapters.schedule_fetch" in app.tasks
    assert schedule_fetch.name == "adapters.schedule_fetch"


def test_a_paused_source_is_skipped(sync_session, sent) -> None:
    _pause(sync_session)
    result = schedule_fetch.apply(args=("livesoccertv",)).get()
    assert result["skipped"] is True
    assert result["why"] == "paused"
    assert sent == []


def test_a_manual_run_ignores_the_pause(sync_session, sent, monkeypatch: pytest.MonkeyPatch) -> None:
    _pause(sync_session)
    monkeypatch.setattr(
        "app.adapters.tasks.plan_targets",
        lambda session, *, now, window="default": plan_targets(
            session, now=now, window=window, recent=MemoryRecentFetches()
        ),
    )
    monkeypatch.setattr("app.adapters.tasks.store_plan_log", lambda payload: None)
    home = new_team(sync_session, "الأهلي")
    away = new_team(sync_session, "الزمالك")
    new_lst_team(sync_session, ar_name="الأهلي", slug="al-ahly", team_id=home.id)
    new_lst_team(sync_session, ar_name="الزمالك", slug="al-zamalek", team_id=away.id)
    new_match(
        sync_session,
        kickoff_at=datetime.now(UTC) + timedelta(hours=2),
        home_team_id=home.id,
        away_team_id=away.id,
    )

    result = schedule_fetch.apply(args=("livesoccertv",), kwargs={"manual": True}).get()

    assert result.get("skipped") is not True
    assert len(sent) == 1


def test_a_source_with_no_targets_sends_no_fetch(sync_session, sent) -> None:
    result = schedule_fetch.apply(args=("livesoccertv",)).get()
    assert result["skipped"] is True
    assert result["why"] == "no_targets"
    assert sent == []


def test_livesoccertv_plans_then_sends_its_targets_to_its_queue(
    sync_session, sent, monkeypatch: pytest.MonkeyPatch
) -> None:
    home = new_team(sync_session, "الأهلي")
    away = new_team(sync_session, "الزمالك")
    new_lst_team(sync_session, ar_name="الأهلي", slug="al-ahly", team_id=home.id)
    new_lst_team(sync_session, ar_name="الزمالك", slug="al-zamalek", team_id=away.id)
    kickoff = datetime.now(UTC) + timedelta(hours=2)
    match = new_match(sync_session, kickoff_at=kickoff, home_team_id=home.id, away_team_id=away.id)
    monkeypatch.setenv("LIVESOCCERTV_FETCH_QUEUE", "scrape")
    # The planned marks live in Redis; this run must not depend on a previous test's keys.
    monkeypatch.setattr(
        "app.adapters.tasks.plan_targets",
        lambda session, *, now, window="default": plan_targets(
            session, now=now, window=window, recent=MemoryRecentFetches()
        ),
    )
    monkeypatch.setattr("app.adapters.tasks.store_plan_log", lambda payload: None)

    result = schedule_fetch.apply(args=("livesoccertv",)).get()

    assert result["planned"] == 1
    assert len(sent) == 1
    assert sent[0]["queue"] == "scrape"
    assert sent[0]["args"] == ["livesoccertv"]
    target = sent[0]["kwargs"]["targets"][0]
    assert target["match_id"] == match.id
    assert datetime.fromisoformat(target["kickoff_at"]) == kickoff


def test_ysscores_goes_to_the_home_box_by_default(sync_session, sent) -> None:
    schedule_fetch.apply(args=("ysscores",)).get()
    assert sent == [{"args": ["ysscores"], "queue": "scrape_home"}]


def test_ysscores_moves_to_vps2_when_the_setting_says_so(sync_session, sent, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("YSSCORES_FETCH_QUEUE", "scrape")
    schedule_fetch.apply(args=("ysscores",)).get()
    assert sent == [{"args": ["ysscores"], "queue": "scrape"}]


def test_the_bridge_goes_to_vps2(sync_session, sent) -> None:
    schedule_fetch.apply(args=("legacy",)).get()
    assert sent == [{"args": ["legacy"], "queue": "scrape"}]


def test_the_beat_schedule_has_every_entry_and_calls_no_fetch_directly() -> None:
    assert set(BEAT_SCHEDULE) == {
        "ysscores-fixtures",
        "satair-bridge",
        "livesoccertv-48h",
        "livesoccertv-t60",
        "prune-raw-pages",
        "heartbeat-maintenance",
        "heartbeat-imports",
        "heartbeat-notifications",
        "scrape-home-backlog",
    }

    source_entries = {name: entry for name, entry in BEAT_SCHEDULE.items() if "fetch" in entry["task"]}
    assert source_entries
    assert {entry["task"] for entry in source_entries.values()} == {"adapters.schedule_fetch"}
    assert all(entry["task"] != "adapters.fetch" for entry in BEAT_SCHEDULE.values())
    # Every scheduling pass runs on VPS-2, where the pause and the breaker are visible (R17).
    assert {entry["options"]["queue"] for entry in source_entries.values()} == {"imports"}


def test_the_t60_entry_asks_for_the_narrow_window() -> None:
    entry = BEAT_SCHEDULE["livesoccertv-t60"]
    assert entry["args"] == ("livesoccertv",)
    assert entry["kwargs"] == {"window": "t60"}
    assert str(entry["schedule"]) == "<crontab: */10 * * * * (m/h/dM/MY/d)>"
    assert str(BEAT_SCHEDULE["livesoccertv-48h"]["schedule"]) == "<crontab: 45 */2 * * * (m/h/dM/MY/d)>"


def test_the_worker_app_merges_both_schedule_modules_without_clashing() -> None:
    """``app.workers`` loads the adapters' and the notifications' entries in one schedule (T070)."""
    from app.notifications.schedule import BEAT_SCHEDULE as NOTIFY_SCHEDULE
    from app.workers import app

    loaded = app.conf.beat_schedule
    assert set(BEAT_SCHEDULE) <= set(loaded)
    assert set(NOTIFY_SCHEDULE) <= set(loaded)
    assert not set(BEAT_SCHEDULE) & set(NOTIFY_SCHEDULE)
    assert len(loaded) == len(BEAT_SCHEDULE) + len(NOTIFY_SCHEDULE)
    assert loaded["livesoccertv-t60"]["task"] == "adapters.schedule_fetch"
    assert loaded["notify-dispatch"]["task"] == "notifications.dispatch_due"


def test_the_registered_task_names_are_the_ones_a13_and_the_beat_call() -> None:
    """``inspect registered`` in ``dev.yml`` must list both, by exactly these names (T069, T070)."""
    import app.notifications.tasks  # noqa: F401 - the worker's `include` imports it at start-up
    from app.workers import app

    for name in ("adapters.schedule_fetch", "adapters.fetch", "adapters.ingest", "ops.heartbeat"):
        assert name in app.tasks, name
    for name in ("notifications.dispatch_due", "notifications.schedule_reminders"):
        assert name in app.tasks, name


def test_the_heartbeats_cover_their_own_queues() -> None:
    for queue in ("maintenance", "imports", "notifications"):
        entry = BEAT_SCHEDULE[f"heartbeat-{queue}"]
        assert entry["task"] == "ops.heartbeat"
        assert entry["args"] == (queue,)
        assert entry["options"]["queue"] == queue


def test_the_home_box_backlog_is_checked_on_vps2() -> None:
    """The home box cannot reach Kuma, so its queue is read from VPS-2's ``imports`` worker."""
    entry = BEAT_SCHEDULE["scrape-home-backlog"]
    assert entry["task"] == "ops.scrape_home_backlog"
    assert entry["options"]["queue"] == "imports"
    assert str(entry["schedule"]) == "<crontab: */5 * * * * (m/h/dM/MY/d)>"
