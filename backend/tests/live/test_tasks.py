"""The Celery wrappers: locks, what each one calls, and alerts after the transaction (T033, T034)."""

from __future__ import annotations

from contextlib import nullcontext

import pytest

from app.adapters.base import RawPage
from app.adapters.health import record_live_cycle
from app.adapters.unresolved import record_unresolved
from app.live import cycle, tasks, watchdog
from app.live.cycle import OutOfTokens
from app.workers.base import Retryable
from tests.live.test_cycle import FakeRedis


class FakeSession:
    def __enter__(self):
        return self

    def __exit__(self, *_):
        return None

    def begin(self):
        return nullcontext()


@pytest.fixture
def client(monkeypatch):
    fake = FakeRedis()
    monkeypatch.setattr(tasks, "_redis", lambda: fake)
    return fake


@pytest.fixture
def alerts(monkeypatch):
    sent = []
    monkeypatch.setattr(tasks, "send_alert", sent.append)
    return sent


@pytest.fixture
def session(monkeypatch):
    monkeypatch.setattr("app.db.session.SyncSession", FakeSession)


@pytest.mark.parametrize(
    ("task", "lock"),
    [
        (tasks.live_scheduler, "lock:live:scheduler"),
        (tasks.live_poll, "lock:live:poll"),
        (tasks.live_watchdog, "lock:live:watchdog"),
        (tasks.live_prune_runs, "lock:live:prune"),
        (tasks.live_check_robots, "lock:live:robots"),
    ],
)
def test_a_held_lock_exits(client, task, lock):
    client.set(lock, "another worker")

    assert task.run() == {"skipped": "lock_held"}


def test_the_scheduler_queues_one_poll_when_there_is_work(client, session, monkeypatch):
    queued = []
    monkeypatch.setattr(cycle, "has_work_in", lambda factory, now: True)
    monkeypatch.setattr(tasks.live_poll, "apply_async", lambda **options: queued.append(options))

    assert tasks.live_scheduler.run() == {"queued": True}
    assert queued == [{"queue": "live"}]


def test_the_scheduler_queues_nothing_on_a_quiet_day(client, session, monkeypatch):
    monkeypatch.setattr(cycle, "has_work_in", lambda factory, now: False)
    monkeypatch.setattr(tasks.live_poll, "apply_async", lambda **options: pytest.fail("no work"))

    assert tasks.live_scheduler.run() == {"queued": False}


def test_a_poll_runs_one_cycle_with_the_real_dependencies(client, monkeypatch):
    seen = []
    monkeypatch.setattr(tasks, "_fetcher", lambda redis_client: nullcontext(object()))
    monkeypatch.setattr(cycle, "run_cycle", lambda deps: seen.append(deps) or {"matches": 1})

    assert tasks.live_poll.run() == {"matches": 1}
    assert seen[0].settings.confirm_wait_s == 180
    assert tasks.live_poll.max_retries == 0


def test_a_poll_calls_b2s_own_queue_and_health_functions(client):
    deps = tasks._deps(client, object())

    assert deps.record_unresolved is record_unresolved
    assert deps.record_live_cycle is record_live_cycle


def test_the_watchdog_alerts_after_its_transaction(client, session, alerts, monkeypatch):
    monkeypatch.setattr(watchdog, "run_watchdog", lambda s, now, settings: ["نص التنبيه"])

    assert tasks.live_watchdog.run() == {"alerts": 1}
    assert alerts == ["نص التنبيه"]


def test_pruning_reports_what_it_deleted(client, session, monkeypatch):
    monkeypatch.setattr(cycle, "delete_old_runs", lambda s, now: 4)

    assert tasks.live_prune_runs.run() == {"deleted": 4}


def test_the_robots_check_alerts_after_its_transaction(client, session, alerts, monkeypatch):
    monkeypatch.setattr(tasks, "_fetcher", lambda redis_client: nullcontext(object()))
    monkeypatch.setattr("app.live.robots_check.check_robots", lambda s, fetch, now: ["تغير"])

    assert tasks.live_check_robots.run() == {"alerts": 1}
    assert alerts == ["تغير"]


class Fetcher:
    def __init__(self, result):
        self.result = result
        self.calls = []

    def get(self, url, allowed_hosts):
        self.calls.append((url, allowed_hosts))
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


def test_the_fetch_allows_only_the_host_it_was_asked_for():
    page = RawPage(url="https://www.filgoal.com/matches/", status=200, body=b"", content_type=None)
    fetcher = Fetcher(page)

    assert tasks._fetch_with(fetcher)("https://www.filgoal.com/matches/", "www.filgoal.com") is page
    assert fetcher.calls[0][1] == frozenset({"www.filgoal.com"})


def test_an_empty_bucket_is_not_the_hosts_fault():
    fetch = tasks._fetch_with(Fetcher(Retryable("rate limit reached for www.filgoal.com")))

    with pytest.raises(OutOfTokens):
        fetch("https://www.filgoal.com/matches/", "www.filgoal.com")


def test_a_block_stays_a_block():
    fetch = tasks._fetch_with(Fetcher(Retryable("https://www.filgoal.com/matches/ answered 429")))

    with pytest.raises(Retryable):
        fetch("https://www.filgoal.com/matches/", "www.filgoal.com")
