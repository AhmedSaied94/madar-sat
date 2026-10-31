"""Fetching one media URL safely (README rule 16, constitution V: SSRF)."""

from __future__ import annotations

from urllib.parse import urlsplit

import httpx

from app.media.errors import RehostError

MAX_BYTES = 5 * 1024 * 1024  # download cap
TIMEOUT_S = 10.0


def host_of(url: str) -> str:
    return urlsplit(url).netloc


def fetch_media(client: httpx.Client, url: str, allowed_hosts: list[str]) -> bytes:
    """Fetch one media URL, enforcing the allowlist, redirect policy and size cap.

    The body is streamed and abandoned as soon as it passes ``MAX_BYTES`` (or when the
    declared ``Content-Length`` already does), so an oversized file is never fully read.
    """
    if host_of(url) not in allowed_hosts:
        raise RehostError("host_not_allowed")
    body = bytearray()
    try:
        with client.stream("GET", url, follow_redirects=False, timeout=TIMEOUT_S) as response:
            if response.is_redirect:
                raise RehostError("redirect_off_host")
            if response.status_code != 200:
                raise RehostError(f"http_{response.status_code}")
            declared = response.headers.get("Content-Length", "")
            if declared.isdigit() and int(declared) > MAX_BYTES:
                raise RehostError("too_large")
            for chunk in response.iter_bytes():
                body.extend(chunk)
                if len(body) > MAX_BYTES:
                    raise RehostError("too_large")
    except httpx.TimeoutException as e:
        raise RehostError("timeout") from e
    except httpx.HTTPError as e:
        raise RehostError("http_error") from e
    if not body:
        raise RehostError("decode_error")
    return bytes(body)
