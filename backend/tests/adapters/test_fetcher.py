"""The fetcher: allowlist, hand-checked redirects, size cap, timeouts, retries (T055, R14)."""

from __future__ import annotations

import http.client
from collections.abc import Callable, Iterator

import httpx
import pytest

from app.adapters.fetcher import FetchError, HostNotAllowed, HttpFetcher, RedirectLimit, ResponseTooLarge
from app.workers.base import Retryable

ALLOWED = frozenset({"www.ysscores.com"})
USER_AGENT = "MadarSat/1.0 (+https://example.test; test)"


class AllowAll:
    """A limiter that always grants a token: the fetcher tests are not about the bucket."""

    def take(self, host: str, now: float | None = None) -> bool:
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


def test_a_rate_limited_host_waits_out_its_budget_without_a_request() -> None:
    """B2-R2-17: a fake clock, so the 60 s budget costs nothing and the poll count is asserted."""
    calls: list[httpx.Request] = []

    class Denied:
        def take(self, host: str, now: float | None = None) -> bool:
            return False

    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(request)
        return httpx.Response(200, text="ok")

    now = [1_700_000_000.0]
    sleeps: list[float] = []

    def clock() -> float:
        return now[0]

    def sleep(seconds: float) -> None:
        sleeps.append(seconds)
        now[0] += seconds

    fetcher = HttpFetcher(
        limiter=Denied(),
        user_agent=USER_AGENT,
        client=httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False),
        clock=clock,
        sleep=sleep,
        wait_budget=1.0,
        poll_seconds=0.25,
    )

    with pytest.raises(Retryable):
        fetcher.get("https://www.ysscores.com/x", allowed_hosts=ALLOWED)

    assert calls == []  # the request was never sent while the bucket was empty
    assert len(sleeps) == 4  # one poll per 250 ms of the 1 s budget
    assert sum(sleeps) == pytest.approx(1.0)


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


def test_a_four_day_fetch_waits_for_the_bucket_instead_of_failing() -> None:
    """B2-R1-8: the burst is two POSTs, then one every 4 s. A run waits ~8 s, not a retry from day 0."""
    import os
    from datetime import date

    import redis as redis_module

    from app.adapters.base import DateWindow
    from app.adapters.fetcher import WAIT_BUDGET
    from app.adapters.ratelimit import YSSCORES_BUCKET, RateLimiter
    from app.adapters.ysscores import YsscoresAdapter

    client = redis_module.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
    try:
        for key in client.scan_iter(match="ratelimit:*"):
            client.delete(key)
        limiter = RateLimiter(client, limits={"www.ysscores.com": YSSCORES_BUCKET})

        now = [1_700_000_000.0]

        def clock() -> float:
            return now[0]

        def sleep(seconds: float) -> None:
            now[0] += seconds

        calls: list[httpx.Request] = []

        def handler(request: httpx.Request) -> httpx.Response:
            calls.append(request)
            return httpx.Response(200, text="<div class='matches-wrapper'></div>")

        fetcher = HttpFetcher(
            limiter=limiter,
            user_agent=USER_AGENT,
            client=httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False),
            clock=clock,
            sleep=sleep,
        )
        window = DateWindow.next_days(date(2026, 10, 31))
        pages = YsscoresAdapter(fetcher).fetch(window)

        assert len(pages) == 4 and len(calls) == 4
        waited = now[0] - 1_700_000_000.0
        assert 0 < waited <= WAIT_BUDGET
        assert waited < 60  # the plan's one minute per run
    finally:
        for key in client.scan_iter(match="ratelimit:*"):
            client.delete(key)
        client.close()


GOAL_HOST = frozenset({"www.goal.com"})


def _dropped_body(error: Exception) -> httpx.Response:
    class Dropping(httpx.SyncByteStream):
        def __iter__(self) -> Iterator[bytes]:
            yield b"<html>part of a page"
            raise error

    return httpx.Response(200, stream=Dropping())


def test_goal_com_is_fetched_by_its_allowlist_and_nothing_else_opens_it() -> None:
    """Spec 031 T031: the host check takes the host as it does the others."""
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, text="ok")

    page = _fetcher(handler, calls).get("https://www.goal.com/ar/live-scores", allowed_hosts=GOAL_HOST)
    assert page.body == b"ok"
    with pytest.raises(HostNotAllowed):
        _fetcher(handler, calls).get("https://www.goal.com/ar/live-scores", allowed_hosts=ALLOWED)
    assert len(calls) == 1


@pytest.mark.parametrize(
    "error",
    [
        http.client.IncompleteRead(b"part", expected=100),
        http.client.RemoteDisconnected("gone"),
        httpx.RemoteProtocolError("peer closed connection without sending complete message body"),
        httpx.ReadError("connection reset"),
    ],
    ids=["incomplete-read", "remote-disconnected", "remote-protocol-error", "read-error"],
)
def test_a_dropped_connection_comes_out_as_retryable_not_raw(error: Exception) -> None:
    """Spec 031 T031. The first capture died on an uncaught ``IncompleteRead``, and nobody knew."""
    calls: list[httpx.Request] = []

    with pytest.raises(Retryable) as caught:
        _fetcher(lambda _: _dropped_body(error), calls).get(
            "https://www.goal.com/ar/live-scores?secret=1", allowed_hosts=GOAL_HOST
        )
    assert "dropped" in str(caught.value)
    assert "secret" not in str(caught.value)
    assert not str(caught.value).startswith("rate limit reached")  # the poller reads that as out of tokens


def test_a_connection_dropped_before_any_answer_comes_out_as_retryable() -> None:
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.RemoteProtocolError("server disconnected without sending a response")

    with pytest.raises(Retryable):
        _fetcher(handler, calls).get("https://www.goal.com/ar/live-scores", allowed_hosts=GOAL_HOST)


def test_a_timeout_stays_an_httpx_error_for_the_callers_that_read_it() -> None:
    calls: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("slow")

    with pytest.raises(httpx.ReadTimeout):
        _fetcher(handler, calls).get("https://www.goal.com/ar/live-scores", allowed_hosts=GOAL_HOST)
