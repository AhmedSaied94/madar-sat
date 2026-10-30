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
    client = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
    client.flushdb()
    yield client
    client.execute_command("ACL", "DELUSER", "homebox")
    client.flushdb()
    client.close()


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


def test_the_home_box_can_queue_and_consume_a_task(homebox: redis.Redis, admin_client: redis.Redis) -> None:
    admin_client.rpush("celery:queue:scrape_home", '{"task": "adapters.fetch"}')
    assert homebox.lpop("celery:queue:scrape_home") == '{"task": "adapters.fetch"}'
    homebox.rpush("celery:unacked:1", "x")
    assert homebox.llen("celery:unacked:1") == 1


def test_the_home_box_uses_rate_limit_buckets_and_fetch_locks(homebox: redis.Redis) -> None:
    homebox.hset("ratelimit:www.ysscores.com", mapping={"tokens": 1.5, "ts": 1_000})
    assert homebox.hget("ratelimit:www.ysscores.com", "tokens") == "1.5"
    assert homebox.set("lock:fetch:ysscores", "token", nx=True, ex=60) is True
    assert homebox.delete("lock:fetch:ysscores") == 1


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
