"""The fetcher: allowlist, hand-checked redirects, size cap, timeouts, retries (T055, R14)."""

from __future__ import annotations

from collections.abc import Callable

import httpx
import pytest

from app.adapters.fetcher import FetchError, HostNotAllowed, HttpFetcher, RedirectLimit, ResponseTooLarge
from app.workers.base import Retryable

ALLOWED = frozenset({"www.ysscores.com"})
USER_AGENT = "MadarSat/1.0 (+https://example.test; test)"


class AllowAll:
    """A limiter that always grants a token: the fetcher tests are not about the bucket."""

    def take(self, host: str) -> bool:
        return True


def _fetcher(handler: Callable[[httpx.Request], httpx.Response], calls: list[httpx.Request]) -> HttpFetcher:
    def record(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return handler(request)

    return HttpFetcher(
        limiter=AllowAll(),
        user_agent=USER_AGENT,
        client=httpx.Client(transport=httpx.MockTransport(record), follow_redirects=False),
    )


def test_a_host_outside_the_allowlist_is_refused_before_any_request() -> None:
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="nope")

    with pytest.raises(HostNotAllowed):
        _fetcher(handler, calls).get("https://evil.example/", allowed_hosts=ALLOWED)
    assert calls == []


def test_redirects_are_followed_by_hand_up_to_three_times() -> None:
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        n = len(calls)
        if n <= 3:
            return httpx.Response(302, headers={"location": f"/hop{n + 1}"})
        return httpx.Response(200, text="landed")

    page = _fetcher(handler, calls).get("https://www.ysscores.com/start", allowed_hosts=ALLOWED)
    assert page.body == b"landed"
    assert str(page.url) == "https://www.ysscores.com/hop4"
    assert len(calls) == 4


def test_a_fourth_redirect_fails() -> None:
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(302, headers={"location": "/again"})

    with pytest.raises(RedirectLimit):
        _fetcher(handler, calls).get("https://www.ysscores.com/start", allowed_hosts=ALLOWED)
    assert len(calls) == 4  # the first request and three followed redirects


def test_a_redirect_to_another_host_fails_without_following_it() -> None:
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(302, headers={"location": "https://evil.example/steal"})

    with pytest.raises(HostNotAllowed):
        _fetcher(handler, calls).get("https://www.ysscores.com/start", allowed_hosts=ALLOWED)
    assert len(calls) == 1


def test_a_body_over_the_cap_is_cut_off_and_fails() -> None:
    calls: list[httpx.Request] = []
    chunk = b"x" * 4096

    def handler(request: httpx.Request) -> httpx.Response:
        def body():
            for _ in range(2000):  # 8 MB, over the 5 MB cap
                yield chunk

        return httpx.Response(200, content=body())

    fetcher = _fetcher(handler, calls)
    with pytest.raises(ResponseTooLarge):
        fetcher.get("https://www.ysscores.com/big", allowed_hosts=ALLOWED)
    assert fetcher.max_bytes == 5 * 1024 * 1024


def test_the_timeouts_are_five_seconds_to_connect_and_twenty_to_read() -> None:
    fetcher = HttpFetcher(limiter=AllowAll(), user_agent=USER_AGENT)  # its own client, no request made
    try:
        timeout = fetcher.client.timeout
        assert timeout.connect == 5.0
        assert timeout.read == 20.0
    finally:
        fetcher.close()


@pytest.mark.parametrize("status", [429, 403, 500, 502, 503])
def test_429_403_and_5xx_are_retryable(status: int) -> None:
    fetcher = _fetcher(lambda request: httpx.Response(status, text="busy"), [])
    with pytest.raises(Retryable):
        fetcher.get("https://www.ysscores.com/x", allowed_hosts=ALLOWED)


@pytest.mark.parametrize("status", [400, 404, 422])
def test_other_4xx_fail_without_a_retry(status: int) -> None:
    calls: list[httpx.Request] = []
    fetcher = _fetcher(lambda request: httpx.Response(status, text="bad"), calls)
    with pytest.raises(FetchError):
        fetcher.get("https://www.ysscores.com/x", allowed_hosts=ALLOWED)
    assert len(calls) == 1


def test_the_user_agent_is_the_configured_one() -> None:
    seen: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request.headers["user-agent"])
        return httpx.Response(200, text="ok")

    _fetcher(handler, []).get("https://www.ysscores.com/x", allowed_hosts=ALLOWED)
    assert seen == [USER_AGENT]


def test_the_fetched_page_carries_the_url_status_and_body() -> None:
    fetcher = _fetcher(lambda request: httpx.Response(200, html="<html>ok</html>"), [])
    page = fetcher.get("https://www.ysscores.com/x", allowed_hosts=ALLOWED)
    assert page.status == 200
    assert page.body == b"<html>ok</html>"
    assert page.content_type is None or page.content_type.startswith("text/html")
    assert page.fetched_at.tzinfo is not None


def test_a_rate_limited_host_raises_retryable_without_a_request() -> None:
    calls: list[httpx.Request] = []

    class Denied:
        def take(self, host: str) -> bool:
            return False

    fetcher = HttpFetcher(
        limiter=Denied(),
        user_agent=USER_AGENT,
        client=httpx.Client(transport=httpx.MockTransport(lambda r: httpx.Response(200)), follow_redirects=False),
    )
    with pytest.raises(Retryable):
        fetcher.get("https://www.ysscores.com/x", allowed_hosts=ALLOWED)
    assert calls == []


def test_a_post_body_goes_out_as_a_form() -> None:
    seen: list[bytes] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request.content)
        return httpx.Response(200, text="ok")

    _fetcher(handler, []).post(
        "https://www.ysscores.com/ar/match_date_to",
        data={"get_date": "October 31,2026"},
        allowed_hosts=ALLOWED,
    )
    assert seen == [b"get_date=October+31%2C2026"]
