"""The one HTTP client the adapters may use (T069, R14, FR-020).

Guarantees, all tested in ``tests/adapters/test_fetcher.py``:

- only hosts on the adapter's allowlist are requested, and redirects are followed by hand so the
  target host is checked before it is contacted (SSRF, constitution V);
- at most three redirects;
- a 5 s connect timeout, a 20 s read timeout and a 5 MB streaming cap;
- 429, 403 and 5xx raise ``Retryable`` so Celery backs off with jitter; other 4xx fail the run;
- one request per host per the Redis token bucket: the fetcher waits for the next token, up to
  ``wait_budget`` seconds, instead of failing the whole run (B2-R1-8);
- ``http_errors`` counts every response of 400 or more, for the run row (B2-R1-9).
"""

from __future__ import annotations

import time
from collections.abc import Callable
from types import TracebackType
from urllib.parse import urljoin, urlsplit, urlunsplit

import httpx

from app.adapters.base import RawPage
from app.adapters.ratelimit import TokenBucket
from app.workers.base import Retryable

USER_AGENT_HEADER = "user-agent"
CONNECT_TIMEOUT = 5.0
READ_TIMEOUT = 20.0
MAX_BYTES = 5 * 1024 * 1024
MAX_REDIRECTS = 3
RETRYABLE_STATUSES = frozenset({403, 429})
# A four-day ysscores run needs two burst tokens and one more every 4 s, so it waits about 8 s.
WAIT_BUDGET = 60.0
POLL_SECONDS = 0.25


class FetchError(Exception):
    """The request failed and a retry would not help.

    ``status`` is the HTTP status when the failure came from one, so an adapter can tell a
    missing document (404) from a real error.
    """

    def __init__(self, message: str, status: int | None = None) -> None:
        super().__init__(message)
        self.status = status


class HostNotAllowed(FetchError):
    """The URL, or a redirect's target, is outside the adapter's allowlist."""


class RedirectLimit(FetchError):
    """More than three redirects."""


class ResponseTooLarge(FetchError):
    """The body is over the 5 MB cap."""


def host_of(url: str) -> str:
    return urlsplit(url).hostname or ""


def _without_query(url: str) -> str:
    """The URL with its query and fragment dropped, for messages that end up in a log (B2-R2-5)."""
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, parts.path, "", ""))


class HttpFetcher:
    def __init__(
        self,
        limiter: TokenBucket,
        user_agent: str,
        client: httpx.Client | None = None,
        max_bytes: int = MAX_BYTES,
        max_redirects: int = MAX_REDIRECTS,
        clock: Callable[[], float] = time.time,
        sleep: Callable[[float], None] = time.sleep,
        wait_budget: float = WAIT_BUDGET,
        poll_seconds: float = POLL_SECONDS,
    ) -> None:
        self.client = client or httpx.Client(
            follow_redirects=False,
            timeout=httpx.Timeout(CONNECT_TIMEOUT, read=READ_TIMEOUT),
        )
        self.limiter = limiter
        self.user_agent = user_agent
        self.max_bytes = max_bytes
        self.max_redirects = max_redirects
        self.clock = clock
        self.sleep = sleep
        self.wait_budget = wait_budget
        self.poll_seconds = poll_seconds
        # Every 4xx/5xx the source answered, so a failed run records how often (B2-R1-9).
        self.http_errors = 0

    def __enter__(self) -> HttpFetcher:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc: BaseException | None,
        tb: TracebackType | None,
    ) -> None:
        self.close()

    def close(self) -> None:
        self.client.close()

    def get(
        self,
        url: str,
        allowed_hosts: frozenset[str],
        params: dict[str, str] | None = None,
        headers: dict[str, str] | None = None,
    ) -> RawPage:
        return self._request("GET", url, allowed_hosts=allowed_hosts, params=params, headers=headers)

    def post(
        self,
        url: str,
        data: dict[str, str],
        allowed_hosts: frozenset[str],
        headers: dict[str, str] | None = None,
    ) -> RawPage:
        return self._request("POST", url, allowed_hosts=allowed_hosts, data=data, headers=headers)

    def _request(
        self,
        method: str,
        url: str,
        allowed_hosts: frozenset[str],
        params: dict[str, str] | None = None,
        data: dict[str, str] | None = None,
        headers: dict[str, str] | None = None,
    ) -> RawPage:
        current = url
        redirects = 0
        while True:
            self._check_host(current, allowed_hosts)
            self._wait_for_token(host_of(current))

            with self.client.stream(
                method,
                current,
                params=params,
                data=data,
                headers={USER_AGENT_HEADER: self.user_agent, **(headers or {})},
            ) as response:
                if response.is_redirect:
                    redirects += 1
                    if redirects > self.max_redirects:
                        raise RedirectLimit(f"more than {self.max_redirects} redirects from {url}")
                    location = response.headers.get("location")
                    if not location:
                        raise FetchError(f"{current} answered {response.status_code} without a location")
                    target = urljoin(current, location)
                    self._check_host(target, allowed_hosts)
                    current = target
                    if response.status_code in {301, 302, 303}:
                        method, data = "GET", None
                    params = None
                    continue

                if response.status_code >= 400:
                    self.http_errors += 1
                body = self._read_capped(response)
                page = RawPage(
                    url=str(response.url),
                    status=response.status_code,
                    body=body,
                    content_type=response.headers.get("content-type"),
                )

            if page.status in RETRYABLE_STATUSES or page.status >= 500:
                raise Retryable(f"{current} answered {page.status}")
            if page.status >= 400:
                raise FetchError(f"{current} answered {page.status}", status=page.status)
            return page

    def _wait_for_token(self, host: str) -> None:
        """Wait for the host's next token, up to the budget, instead of aborting the fetch (B2-R1-8).

        The bucket holds two tokens and refills one every four seconds, so a four-day run that used
        its burst waits about eight seconds. Past the budget the run is retried, as before.
        """
        deadline = self.clock() + self.wait_budget
        while not self.limiter.take(host, now=self.clock()):
            if self.clock() >= deadline:
                raise Retryable(f"rate limit reached for {host}")
            self.sleep(self.poll_seconds)

    def _read_capped(self, response: httpx.Response) -> bytes:
        chunks: list[bytes] = []
        total = 0
        for chunk in response.iter_bytes():
            total += len(chunk)
            if total > self.max_bytes:
                # No query string: the bridge's key travelled there until B2-R2-5.
                raise ResponseTooLarge(f"{_without_query(str(response.url))} is over the {self.max_bytes} byte cap")
            chunks.append(chunk)
        return b"".join(chunks)

    @staticmethod
    def _check_host(url: str, allowed_hosts: frozenset[str]) -> None:
        host = host_of(url)
        if not host:
            raise HostNotAllowed(f"no host in {url!r}")
        if host not in allowed_hosts:
            raise HostNotAllowed(f"{host} is not on the allowlist")
