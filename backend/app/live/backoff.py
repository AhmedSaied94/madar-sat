"""The poller's small Redis state: per-host backoff and the raw-page hashes (research R6, R12).

Losing either is harmless: a flush means one extra request or one extra saved page.
"""

from __future__ import annotations

import hashlib
import random
import re
from collections.abc import Callable
from typing import Any

MAX_BACKOFF_S = 600
BASE_BACKOFF_S = 60
STRIKES_TTL_S = 3600
HASH_TTL_S = 86400
_WS = re.compile(rb"\s+")


def next_delay(strikes: int, jitter: Callable[[], float] = random.random) -> int:
    """Exponential from a minute, capped at 10 min, with up to half taken off so hosts don't sync."""
    ceiling: int = min(MAX_BACKOFF_S, BASE_BACKOFF_S * 2 ** max(strikes - 1, 0))
    return max(1, round(float(ceiling) * (1 - jitter() / 2)))


class Backoff:
    """``live:backoff:<host>`` is set for as long as the host must be left alone."""

    def __init__(self, client: Any, jitter: Callable[[], float] = random.random) -> None:
        self._client = client
        self._jitter = jitter

    def active(self, host: str) -> bool:
        return bool(self._client.exists(f"live:backoff:{host}"))

    def trip(self, host: str) -> int:
        strikes_key = f"live:backoff:{host}:strikes"
        strikes = int(self._client.incr(strikes_key))
        self._client.expire(strikes_key, STRIKES_TTL_S)
        delay = next_delay(strikes, self._jitter)
        self._client.set(f"live:backoff:{host}", strikes, ex=delay)
        return delay

    def clear(self, host: str) -> None:
        self._client.delete(f"live:backoff:{host}", f"live:backoff:{host}:strikes")


class PageHashes:
    """Whether a page's content changed since the last save."""

    def __init__(self, client: Any) -> None:
        self._client = client

    def changed(self, url: str, body: bytes) -> bool:
        key = f"live:rawhash:{hashlib.sha256(url.encode()).hexdigest()[:32]}"
        digest = hashlib.sha256(_WS.sub(b" ", body)).hexdigest()
        previous = self._client.get(key)
        if previous is not None and (previous.decode() if isinstance(previous, bytes) else previous) == digest:
            return False
        self._client.set(key, digest, ex=HASH_TTL_S)
        return True
