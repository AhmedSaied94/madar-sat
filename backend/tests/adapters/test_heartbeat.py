"""``ops.heartbeat``: one GET per queue, nothing without a URL (T059, R20)."""

from __future__ import annotations

import httpx
import pytest

from app.adapters import tasks
from app.adapters.config import get_adapter_settings
from app.adapters.tasks import heartbeat, scrape_home_backlog


@pytest.fixture(autouse=True)
def _fresh_settings():
    get_adapter_settings.cache_clear()
    yield
    get_adapter_settings.cache_clear()


class FakeClient:
    def __init__(self, status: int = 200, error: Exception | None = None) -> None:
        self.status = status
        self.error = error
        self.calls: list[tuple[str, dict]] = []

    def __enter__(self) -> FakeClient:
        return self

    def __exit__(self, *args: object) -> None:
        return None

    def get(self, url: str, params: dict | None = None) -> httpx.Response:
        self.calls.append((url, params or {}))
        if self.error is not None:
            raise self.error
        return httpx.Response(self.status)


def test_it_getS_its_kuma_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KUMA_PUSH_URL_IMPORTS", "http://uptime-kuma:3001/api/push/token?status=up&msg=ok")
    get_adapter_settings.cache_clear()
    client = FakeClient()
    monkeypatch.setattr(tasks.httpx, "Client", lambda **kwargs: client)

    result = heartbeat.apply(args=("imports",)).get()

    assert result == {"queue": "imports", "sent": True}
    assert len(client.calls) == 1
    url, params = client.calls[0]
    assert url.startswith("http://uptime-kuma:3001/api/push/")
    assert params == {"status": "up", "msg": "ok"}


def test_a_kuma_style_url_is_pushed_as_one_status_up(monkeypatch: pytest.MonkeyPatch) -> None:
    """Kuma shows ``…?status=up&msg=OK&ping=``; the push must carry that one ``status``, no ``ping``.

    The backup scripts had to cut the query themselves (B2-R2-1). ``httpx`` replaces the query when
    ``params`` is given, so this runs the real client over a mock transport and pins that.
    """
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json={"ok": True})

    monkeypatch.setenv("KUMA_PUSH_URL_IMPORTS", "http://uptime-kuma:3001/api/push/token?status=up&msg=OK&ping=")
    get_adapter_settings.cache_clear()
    real_client = httpx.Client
    monkeypatch.setattr(
        tasks.httpx, "Client", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs)
    )

    assert heartbeat.apply(args=("imports",)).get() == {"queue": "imports", "sent": True}
    assert len(seen) == 1
    assert seen[0].url.path == "/api/push/token"
    assert seen[0].url.params.multi_items() == [("status", "up"), ("msg", "ok")]


def test_without_a_url_it_is_a_no_op(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("KUMA_PUSH_URL_MAINTENANCE", raising=False)
    get_adapter_settings.cache_clear()
    called: list[str] = []
    monkeypatch.setattr(tasks.httpx, "Client", lambda **kwargs: called.append("client"))

    assert heartbeat.apply(args=("maintenance",)).get() == {"queue": "maintenance", "sent": False}
    assert called == []


def test_an_error_is_logged_not_raised(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KUMA_PUSH_URL_NOTIFICATIONS", "http://uptime-kuma:3001/api/push/token")
    get_adapter_settings.cache_clear()
    client = FakeClient(error=httpx.ConnectError("down"))
    monkeypatch.setattr(tasks.httpx, "Client", lambda **kwargs: client)

    assert heartbeat.apply(args=("notifications",)).get() == {"queue": "notifications", "sent": False}


def test_a_rejected_push_is_not_sent(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KUMA_PUSH_URL_IMPORTS", "http://uptime-kuma:3001/api/push/token")
    get_adapter_settings.cache_clear()
    monkeypatch.setattr(tasks.httpx, "Client", lambda **kwargs: FakeClient(status=503))

    assert heartbeat.apply(args=("imports",)).get() == {"queue": "imports", "sent": False}


def test_an_unknown_queue_has_no_url() -> None:
    assert get_adapter_settings().kuma_push_url("scrape") is None


class FakeRedis:
    def __init__(self, depth: int) -> None:
        self.depth = depth
        self.keys: list[str] = []

    def llen(self, key: str) -> int:
        self.keys.append(key)
        return self.depth


def _backlog(monkeypatch: pytest.MonkeyPatch, depth: int, *, url: str | None = "http://uptime-kuma:3001/api/push/t"):
    if url is None:
        monkeypatch.delenv("KUMA_PUSH_URL_SCRAPE_HOME", raising=False)
    else:
        monkeypatch.setenv("KUMA_PUSH_URL_SCRAPE_HOME", url)
    monkeypatch.delenv("SCRAPE_HOME_BACKLOG_MAX", raising=False)
    get_adapter_settings.cache_clear()
    redis = FakeRedis(depth)
    client = FakeClient()
    monkeypatch.setattr(tasks, "_broker_redis", lambda: redis)
    monkeypatch.setattr(tasks.httpx, "Client", lambda **kwargs: client)
    return redis, client, scrape_home_backlog.apply().get()


def test_a_short_home_box_queue_pushes_up(monkeypatch: pytest.MonkeyPatch) -> None:
    redis, client, result = _backlog(monkeypatch, depth=2)

    assert redis.keys == ["celery:scrape_home"]  # the prefixed list that schedule_fetch pushes to
    assert result == {"queue": "scrape_home", "depth": 2, "sent": True}
    assert client.calls == [("http://uptime-kuma:3001/api/push/t", {"status": "up", "msg": "2 waiting"})]


def test_the_limit_itself_is_still_up(monkeypatch: pytest.MonkeyPatch) -> None:
    _, client, _ = _backlog(monkeypatch, depth=6)
    assert client.calls[0][1]["status"] == "up"


def test_a_backed_up_home_box_queue_pushes_down_with_the_count(monkeypatch: pytest.MonkeyPatch) -> None:
    """2026-11-03: the hung worker left 26 fetches waiting and nothing alerted."""
    _, client, result = _backlog(monkeypatch, depth=26)

    assert result == {"queue": "scrape_home", "depth": 26, "sent": True}
    assert client.calls[0][1] == {"status": "down", "msg": "26 fetches waiting"}


def test_without_a_url_the_backlog_is_logged_not_pushed(monkeypatch: pytest.MonkeyPatch) -> None:
    _, client, result = _backlog(monkeypatch, depth=26, url=None)

    assert result == {"queue": "scrape_home", "depth": 26, "sent": False}
    assert client.calls == []


def test_the_backlog_check_is_routed_to_vps2() -> None:
    assert tasks.IngestionRouter().route_for_task("ops.scrape_home_backlog") == {"queue": "imports"}
