"""The one HTTP client the adapters may use (T069, R14, FR-020).

Guarantees, all tested in ``tests/adapters/test_fetcher.py``:

- only hosts on the adapter's allowlist are requested, and redirects are followed by hand so the
  target host is checked before it is contacted (SSRF, constitution V);
- at most three redirects;
- a 5 s connect timeout, a 20 s read timeout and a 5 MB streaming cap;
- 429, 403 and 5xx raise ``Retryable`` so Celery backs off with jitter; other 4xx fail the run;
- one request per host per the Redis token bucket, or ``Retryable`` when the bucket is empty.
"""

from __future__ import annotations

from types import TracebackType
from urllib.parse import urljoin, urlsplit

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


class FetchError(Exception):
    """The request failed and a retry would not help."""


class HostNotAllowed(FetchError):
    """The URL, or a redirect's target, is outside the adapter's allowlist."""


class RedirectLimit(FetchError):
    """More than three redirects."""


class ResponseTooLarge(FetchError):
    """The body is over the 5 MB cap."""


def host_of(url: str) -> str:
    return urlsplit(url).hostname or ""


class HttpFetcher:
    def __init__(
        self,
        limiter: TokenBucket,
        user_agent: str,
        client: httpx.Client | None = None,
        max_bytes: int = MAX_BYTES,
        max_redirects: int = MAX_REDIRECTS,
    ) -> None:
        self.client = client or httpx.Client(
            follow_redirects=False,
            timeout=httpx.Timeout(CONNECT_TIMEOUT, read=READ_TIMEOUT),
        )
        self.limiter = limiter
        self.user_agent = user_agent
        self.max_bytes = max_bytes
        self.max_redirects = max_redirects

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
    ) -> RawPage:
        return self._request("GET", url, allowed_hosts=allowed_hosts, params=params)

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
            if not self.limiter.take(host_of(current)):
                raise Retryable(f"rate limit reached for {host_of(current)}")

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
                raise FetchError(f"{current} answered {page.status}")
            return page

    def _read_capped(self, response: httpx.Response) -> bytes:
        chunks: list[bytes] = []
        total = 0
        for chunk in response.iter_bytes():
            total += len(chunk)
            if total > self.max_bytes:
                raise ResponseTooLarge(f"{response.url} is over the {self.max_bytes} byte cap")
            chunks.append(chunk)
        return b"".join(chunks)

    @staticmethod
    def _check_host(url: str, allowed_hosts: frozenset[str]) -> None:
        host = host_of(url)
        if not host:
            raise HostNotAllowed(f"no host in {url!r}")
        if host not in allowed_hosts:
            raise HostNotAllowed(f"{host} is not on the allowlist")
