"""The ``app.workers`` Celery app (research R13): broker, queues, base task and locks (T006)."""

from __future__ import annotations

import os
import subprocess
import sys
import types
import uuid
from pathlib import Path

import httpx
import pytest

BACKEND = Path(__file__).resolve().parents[2]
QUEUES = {"scrape", "scrape_home", "imports", "maintenance", "media", "live", "notifications"}


def test_broker_keys_share_the_celery_prefix():
    from app.workers import app

    assert app.conf.broker_transport_options == {"global_keyprefix": "celery:"}


def test_declares_exactly_the_queues_of_the_plan():
    from app.workers import app

    assert {q.name for q in app.conf.task_queues} == QUEUES
    assert app.conf.task_default_queue in QUEUES


def test_celery_settings_follow_constitution_vii():
    from app.workers import app

    conf = app.conf
    assert conf.task_ignore_result is True
    assert conf.task_acks_late is True
    assert conf.task_reject_on_worker_lost is True
    assert conf.worker_prefetch_multiplier == 1
    assert conf.task_serializer == "json"
    assert conf.result_serializer == "json"
    assert list(conf.accept_content) == ["json"]


def test_base_task_retries_with_backoff_and_jitter():
    from app.workers.base import BaseTask, Retryable

    assert BaseTask.autoretry_for == (Retryable, httpx.TransportError)
    assert BaseTask.retry_backoff is True
    assert BaseTask.retry_backoff_max == 600
    assert BaseTask.retry_jitter is True
    assert BaseTask.max_retries == 5


def test_task_decorator_binds_and_uses_the_base_class():
    from app.workers import app, task
    from app.workers.base import BaseTask

    @task(name="tests.workers.echo")
    def echo(self, value: str) -> str:
        return value

    registered = app.tasks["tests.workers.echo"]
    assert isinstance(registered, BaseTask)
    assert registered.run("x") == "x"  # bound: ``self`` is the task, the call passes only ``value``


def test_retryable_is_an_exception_b2_can_raise():
    from app.workers.base import Retryable

    assert issubclass(Retryable, Exception)


def _lock_name() -> str:
    return f"lock:test:{uuid.uuid4().hex}"


def test_second_redis_lock_on_the_same_name_yields_false():
    from app.workers.locks import redis_lock

    name = _lock_name()
    with redis_lock(name, ttl=30) as first:
        assert first is True
        with redis_lock(name, ttl=30) as second:
            assert second is False
    with redis_lock(name, ttl=30) as again:  # released on exit
        assert again is True


def test_redis_lock_deletes_only_its_own_token():
    import redis

    from app.workers.config import get_worker_settings
    from app.workers.locks import redis_lock

    name = _lock_name()
    client = redis.Redis.from_url(get_worker_settings().broker_url)
    try:
        with redis_lock(name, ttl=30) as held:
            assert held is True
            client.set(name, "someone-else")  # the lock expired and another worker took it
        assert client.get(name) == b"someone-else"
    finally:
        client.delete(name)
        client.close()


def test_redis_lock_expires_so_a_crash_cannot_hold_it_forever():
    import redis

    from app.workers.config import get_worker_settings
    from app.workers.locks import redis_lock

    name = _lock_name()
    client = redis.Redis.from_url(get_worker_settings().broker_url)
    try:
        with redis_lock(name, ttl=30):
            assert 0 < client.ttl(name) <= 30
    finally:
        client.close()


def _import_in_clean_interpreter(env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    probe = (
        "import sys, app.workers as w; "
        "print(w.app.conf.broker_url); "
        "print(sorted(m for m in sys.modules if m in ('app.settings', 'app.db', 'app.db.session')))"
    )
    base = {"PATH": os.environ.get("PATH", ""), "HOME": os.environ.get("HOME", "")}
    return subprocess.run(  # noqa: S603 - fixed argv, no shell
        [sys.executable, "-c", probe],
        cwd=BACKEND,
        env={**base, **env},
        capture_output=True,
        text=True,
        check=False,
    )


def test_a_box_with_only_redis_url_can_import_the_worker_app():
    out = _import_in_clean_interpreter({"REDIS_URL": "redis://homebox:pw@10.8.0.1:6379/0"})
    assert out.returncode == 0, out.stderr
    broker, loaded = out.stdout.strip().splitlines()
    assert broker == "redis://homebox:pw@10.8.0.1:6379/0"
    assert loaded == "[]"  # importing app.workers never loads app.settings or app.db


def test_celery_broker_url_wins_over_redis_url():
    out = _import_in_clean_interpreter(
        {"CELERY_BROKER_URL": "redis://broker:6379/1", "REDIS_URL": "redis://other:6379/0"}
    )
    assert out.returncode == 0, out.stderr
    assert out.stdout.splitlines()[0] == "redis://broker:6379/1"


def test_no_broker_setting_fails_loudly():
    out = _import_in_clean_interpreter({})
    assert out.returncode != 0
    assert "CELERY_BROKER_URL" in out.stderr


def test_missing_adapter_modules_leave_an_empty_schedule():
    from app.workers import load_beat_schedule

    assert load_beat_schedule("app.adapters.does_not_exist") == {}


def test_beat_schedule_is_read_from_the_adapter_schedule_module(monkeypatch):
    from app.workers import load_beat_schedule

    stub = types.ModuleType("app.adapters.fake_schedule")
    stub.BEAT_SCHEDULE = {"prune": {"task": "adapters.prune_raw_pages", "schedule": 60.0}}  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "app.adapters.fake_schedule", stub)
    assert load_beat_schedule("app.adapters.fake_schedule") == stub.BEAT_SCHEDULE  # type: ignore[attr-defined]


@pytest.mark.parametrize("module", ["app.adapters.tasks", "app.adapters.media_tasks"])
def test_only_existing_adapter_task_modules_are_included(module):
    from app.workers import app, existing_modules

    included = set(app.conf.include or ())
    assert included == set(existing_modules(("app.adapters.tasks", "app.adapters.media_tasks")))
    assert (module in included) == (module in existing_modules((module,)))


def test_a_bare_celery_call_routes_through_the_app_without_importing_the_tasks_module():
    """``celery call`` imports only ``app.workers``; the route is resolved lazily (B2-R1-19)."""
    probe = (
        "import sys, app.workers as w; "
        "print('app.adapters.tasks' in sys.modules); "
        "print(w.app.amqp.router.route({}, 'adapters.fetch', args=('legacy',), kwargs={})['queue'].name); "
        "print(w.app.amqp.router.route({}, 'adapters.fetch', args=('ysscores',), kwargs={})['queue'].name)"
    )
    out = subprocess.run(  # noqa: S603 - fixed argv, no shell
        [sys.executable, "-c", probe],
        cwd=BACKEND,
        env={"PATH": os.environ.get("PATH", ""), "HOME": os.environ.get("HOME", ""), "REDIS_URL": "redis://x:6379/0"},
        capture_output=True,
        text=True,
        check=False,
    )
    assert out.returncode == 0, out.stderr
    imported, legacy, ysscores = out.stdout.strip().splitlines()
    assert imported == "False"  # importing the app alone still doesn't load the tasks module
    assert legacy == "scrape"
    assert ysscores == "scrape_home"


def test_the_json_formatter_keeps_extra_fields(capsys):
    """The lock-skip and 'fetched' events are ``log.info`` with ``extra=``; both must reach stdout."""
    import json
    import logging

    from app.workers import logs

    root = logging.getLogger()
    before = (list(root.handlers), root.level)
    try:
        logs.setup_logging("INFO")
        logging.getLogger("madar.test").info("skipped", extra={"why": "lock_held", "source": "ysscores"})
    finally:
        root.handlers[:] = before[0]
        root.setLevel(before[1])

    payload = json.loads(capsys.readouterr().out.strip().splitlines()[-1])
    assert payload["message"] == "skipped"
    assert (payload["level"], payload["logger"]) == ("INFO", "madar.test")
    assert (payload["why"], payload["source"]) == ("lock_held", "ysscores")


def test_celery_switches_the_json_logger_on():
    """The signal is what makes the formatter apply in every worker, beat and the CLI."""
    import logging

    from celery import signals

    from app.workers import logs

    root = logging.getLogger()
    before = (list(root.handlers), root.level)
    try:
        signals.setup_logging.send(sender=None, loglevel="INFO")
        assert isinstance(root.handlers[-1].formatter, logs.JsonFormatter)
    finally:
        root.handlers[:] = before[0]
        root.setLevel(before[1])


def test_the_json_formatter_drops_and_caps_a_failing_tasks_payload(capsys):
    """Celery's failure log carries the task payload; one line must stay one readable line (B1-R2-7)."""
    import json
    import logging

    from app.workers import logs

    root = logging.getLogger()
    before = (list(root.handlers), root.level)
    argument = "x" * 100_000  # a whole scrape page, or a task argument that points at one
    try:
        logs.setup_logging("INFO")
        try:
            raise ValueError("boom")
        except ValueError:
            logging.getLogger("madar.test").error(
                "task failed",
                extra={"data": {"args": [argument], "kwargs": {"source": "ysscores"}}, "task_id": "abc"},
                exc_info=True,
            )
    finally:
        root.handlers[:] = before[0]
        root.setLevel(before[1])

    line = capsys.readouterr().out.strip()
    assert len(line) < logs.MAX_LINE_CHARS, f"one record wrote {len(line)} bytes"
    payload = json.loads(line)
    assert "data" not in payload and "args" not in payload and "kwargs" not in payload
    assert payload["task_id"] == "abc"
    assert "boom" in payload["exc"]


def test_httpx_and_httpcore_stay_at_warning(capsys):
    """`httpx` logs every request's full URL at INFO, and a URL can carry a key (B1-R2-7, D15)."""
    import logging

    from app.workers import logs

    root = logging.getLogger()
    before = (list(root.handlers), root.level)
    levels = {name: logging.getLogger(name).level for name in logs.QUIET_LOGGERS}
    try:
        logs.setup_logging("INFO")
        logging.getLogger("httpx").info("HTTP Request: GET https://firestore.example/x?key=SECRET123")
        logging.getLogger("httpcore").info("connect to firestore.example")
    finally:
        root.handlers[:] = before[0]
        root.setLevel(before[1])
        for name, level in levels.items():
            logging.getLogger(name).setLevel(level)

    out = capsys.readouterr().out
    assert "SECRET123" not in out
    assert out.strip() == ""
