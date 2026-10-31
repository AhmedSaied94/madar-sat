"""The home box's Redis ACL: queue and consume, nothing else (T066, R21)."""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

import pytest
import redis

ACL_TEMPLATE = Path(__file__).resolve().parents[3] / "infra" / "redis" / "users.acl.tmpl"
PASSWORD = "test-homebox-password"  # noqa: S105 - throwaway, applied to the throwaway test Redis


def _homebox_rule() -> str:
    text = ACL_TEMPLATE.read_text(encoding="utf-8")
    rules = [line.strip() for line in text.splitlines() if re.match(r"^user\s+homebox\s", line.strip())]
    assert len(rules) == 1, "the template must define exactly one homebox user"
    return rules[0]


@pytest.fixture
def admin_client() -> redis.Redis:
    """Cleared only of the Celery keys: the test Redis is shared with the other lanes' tests."""
    client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
    _clear(client)
    yield client
    client.execute_command("ACL", "DELUSER", "homebox")
    _clear(client)
    client.close()


def _clear(client: redis.Redis) -> None:
    for key in client.scan_iter(match="celery:*"):
        client.delete(key)


@pytest.fixture
def homebox(admin_client: redis.Redis) -> redis.Redis:
    rule = _homebox_rule().replace("${REDIS_HOMEBOX_PASSWORD}", PASSWORD)
    assert rule.startswith("user homebox ")
    # Apply the file's own rule, so the test fails if the file stops matching the contract.
    admin_client.execute_command("ACL", "SETUSER", *rule[len("user ") :].split())
    url = os.environ["REDIS_URL"]
    client = redis.Redis.from_url(url, username="homebox", password=PASSWORD, decode_responses=True)
    yield client
    client.close()


def test_the_template_holds_placeholders_only() -> None:
    text = ACL_TEMPLATE.read_text(encoding="utf-8")
    assert "${REDIS_PASSWORD}" in _rule_for(text, "default")
    assert "${REDIS_HOMEBOX_PASSWORD}" in _rule_for(text, "homebox")
    # No literal secret anywhere: every `>` password argument is a placeholder.
    assert all(v.startswith("${") and v.endswith("}") for v in re.findall(r">([^\s]+)", text))


def _rule_for(text: str, user: str) -> str:
    (line,) = [ln.strip() for ln in text.splitlines() if re.match(rf"^user\s+{user}\s", ln.strip())]
    return line


def _raises_permission(fn: Any) -> None:
    with pytest.raises(redis.ResponseError) as exc:
        fn()
    assert "NOPERM" in str(exc.value) or "permission" in str(exc.value).lower()


def test_a_real_celery_connection_queues_and_consumes_a_task(homebox: redis.Redis) -> None:
    """B2-R1-18: the ACL must allow what kombu sends, not only the commands a test types by hand."""
    from urllib.parse import urlsplit, urlunsplit

    import kombu

    parts = urlsplit(os.environ["REDIS_URL"])
    url = urlunsplit((parts.scheme, f"homebox:{PASSWORD}@{parts.hostname}:{parts.port}", parts.path, "", ""))
    conn = kombu.Connection(url, transport_options={"global_keyprefix": "celery:"})
    try:
        conn.Producer(serializer="json").publish(
            {"task": "adapters.fetch"},
            exchange="",
            routing_key="scrape_home",
            declare=[kombu.Queue("scrape_home", routing_key="scrape_home")],
        )
        queue = conn.SimpleQueue("scrape_home")
        try:
            message = queue.get(block=False, timeout=5)
            assert message is not None and message.payload == {"task": "adapters.fetch"}
            message.ack()
        finally:
            queue.close()
    finally:
        conn.release()


def test_the_home_box_uses_rate_limit_buckets_and_fetch_locks(homebox: redis.Redis) -> None:
    homebox.hset("ratelimit:www.ysscores.com", mapping={"tokens": 1.5, "ts": 1_000})
    assert homebox.hget("ratelimit:www.ysscores.com", "tokens") == "1.5"
    assert homebox.set("lock:fetch:ysscores", "token", nx=True, ex=60) is True
    assert homebox.delete("lock:fetch:ysscores") == 1


def test_the_home_box_cannot_publish_outside_its_channel_prefix(homebox: redis.Redis) -> None:
    """The channel pattern is `&celery:*`, not `&*` (B2-R1-18)."""
    _raises_permission(lambda: homebox.execute_command("PUBLISH", "auth:leak", "x"))


def test_the_home_box_cannot_read_an_auth_key(homebox: redis.Redis, admin_client: redis.Redis) -> None:
    admin_client.set("auth:lock:abc:1.2.3.4", "1")
    _raises_permission(lambda: homebox.get("auth:lock:abc:1.2.3.4"))
    _raises_permission(lambda: homebox.set("auth:lock:abc:1.2.3.4", "forged"))


def test_the_home_box_cannot_use_admin_or_dangerous_commands(homebox: redis.Redis) -> None:
    _raises_permission(lambda: homebox.execute_command("CONFIG", "GET", "maxmemory"))
    _raises_permission(lambda: homebox.execute_command("FLUSHALL"))
    _raises_permission(lambda: homebox.execute_command("KEYS", "*"))
    _raises_permission(lambda: homebox.execute_command("ACL", "LIST"))


def test_the_default_user_still_authenticates(admin_client: redis.Redis) -> None:
    # The template's `default` rule keeps the admin path working (vps1.yml's healthcheck).
    assert admin_client.ping() is True


def _homebox_url() -> str:
    from urllib.parse import urlsplit, urlunsplit

    parts = urlsplit(os.environ["REDIS_URL"])
    return urlunsplit((parts.scheme, f"homebox:{PASSWORD}@{parts.hostname}:{parts.port}", parts.path, "", ""))


def test_a_real_worker_starts_and_answers_inspect_ping(homebox: redis.Redis, tmp_path: Path) -> None:
    """B2-R2-3: a worker PSUBSCRIBEs `celery:/0.celery.pidbox`, which `&celery:*` does not match.

    Starting the worker is the only way to prove the ACL allows what Celery actually does; the
    producer/`SimpleQueue` test above passes even when the worker cannot start.
    """
    import subprocess
    import sys
    import time

    from celery import Celery

    backend = ACL_TEMPLATE.parents[2] / "backend"
    url = _homebox_url()
    log = tmp_path / "worker.log"
    env = {**os.environ, "REDIS_URL": url, "CELERY_BROKER_URL": url, "PYTHONUNBUFFERED": "1"}
    with log.open("w", encoding="utf-8") as handle:
        process = subprocess.Popen(  # noqa: S603 - fixed argv, no shell
            [
                sys.executable,
                "-m",
                "celery",
                "-A",
                "app.workers:app",
                "worker",
                "-Q",
                "scrape_home",
                "--without-gossip",
                "--without-mingle",
                "--without-heartbeat",
                "--pool=solo",
                "--concurrency=1",
                "--loglevel=WARNING",
                f"--pidfile={tmp_path / 'worker.pid'}",
                "--hostname=homebox-test@%h",
            ],
            cwd=backend,
            env=env,
            stdout=handle,
            stderr=subprocess.STDOUT,
            text=True,
        )
        try:
            client = Celery("madar-acl-test", broker=os.environ["REDIS_URL"])
            # The same prefix the worker uses, so the reply queue is the one it writes (app.workers).
            client.conf.broker_transport_options = {"global_keyprefix": "celery:"}
            reply = None
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    break
                reply = client.control.inspect(timeout=2).ping()
                if reply:
                    break
                time.sleep(1)
            assert process.poll() is None, "the worker exited; the ACL refused a command it sends:\n" + log.read_text(
                encoding="utf-8"
            )
            assert reply, "the worker never answered inspect ping"
            assert {value["ok"] for value in reply.values()} == {"pong"}
        finally:
            process.terminate()
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:  # pragma: no cover - a stuck worker is killed
                process.kill()
                process.wait(timeout=10)
