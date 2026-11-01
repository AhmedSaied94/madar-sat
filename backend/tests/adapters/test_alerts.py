"""Telegram alerts: one host, a short timeout, never raised (T059, R17)."""

from __future__ import annotations

import logging

import httpx
import pytest

from app.adapters import alerts
from app.adapters.config import get_adapter_settings


@pytest.fixture(autouse=True)
def _fresh_settings():
    get_adapter_settings.cache_clear()
    yield
    get_adapter_settings.cache_clear()


def _client(handler, timeout_holder: dict[str, object] | None = None) -> httpx.Client:
    return httpx.Client(transport=httpx.MockTransport(handler))


def test_it_posts_to_the_telegram_api_only(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123:abc")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "-100200")
    get_adapter_settings.cache_clear()
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json={"ok": True})

    assert alerts.send_alert("⛔ المصدر ‹ysscores› متوقف", client=_client(handler)) is True

    assert len(seen) == 1
    assert seen[0].method == "POST"
    assert seen[0].url.host == "api.telegram.org"
    assert "/bot123:abc/sendMessage" in str(seen[0].url)
    body = seen[0].read().decode()
    assert "-100200" in body and "ysscores" in body


def test_it_uses_a_five_second_timeout(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123:abc")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "42")
    get_adapter_settings.cache_clear()
    holder: dict[str, object] = {}

    real_client = httpx.Client

    def factory(**kwargs):  # noqa: ANN001 - the seam
        holder.update(kwargs)
        return real_client(transport=httpx.MockTransport(lambda request: httpx.Response(200)))

    monkeypatch.setattr(alerts.httpx, "Client", factory)
    alerts.send_alert("x")

    timeout = holder["timeout"]
    assert isinstance(timeout, httpx.Timeout) and timeout.connect == 5.0


def test_a_transport_error_is_logged_and_swallowed(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123:abc")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "42")
    get_adapter_settings.cache_clear()

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route", request=request)

    with caplog.at_level(logging.ERROR):
        assert alerts.send_alert("x", client=_client(handler)) is False
    assert any(record.message == "alert_failed" for record in caplog.records)


def test_a_rejection_is_logged_without_the_token(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    monkeypatch.setenv("TELEGRAM_BOT_TOKEN", "123:abc")
    monkeypatch.setenv("TELEGRAM_CHAT_ID", "42")
    get_adapter_settings.cache_clear()

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(401, text="unauthorized")

    with caplog.at_level(logging.ERROR):
        assert alerts.send_alert("x", client=_client(handler)) is False
    records = [record for record in caplog.records if record.message == "alert_rejected"]
    assert records and records[0].status == 401  # type: ignore[attr-defined]
    assert "123:abc" not in caplog.text


def test_without_settings_it_only_logs(monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture) -> None:
    monkeypatch.delenv("TELEGRAM_BOT_TOKEN", raising=False)
    monkeypatch.delenv("TELEGRAM_CHAT_ID", raising=False)
    get_adapter_settings.cache_clear()

    def handler(request: httpx.Request) -> httpx.Response:  # pragma: no cover - never called
        raise AssertionError("no request may leave without a token")

    with caplog.at_level(logging.WARNING):
        assert alerts.send_alert("⛔ يعمل", client=_client(handler)) is False
    assert any(record.message == "alert_not_sent" for record in caplog.records)
