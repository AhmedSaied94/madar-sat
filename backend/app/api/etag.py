"""Weak ETag computation (research R4, constitution VI).

The ETag is ``W/"<first 16 hex of sha256>"`` over the route id, the normalized query,
the dataset versions the endpoint reads, ``MEDIA_BASE_URL`` and the contract version,
plus an optional time bucket for endpoints whose payload carries clock-derived status.
"""

from __future__ import annotations

import hashlib
import time as _time
from collections.abc import Mapping
from typing import Any

from app.settings import get_settings


def _canonical_value(value: Any) -> str:
    if isinstance(value, (list, tuple)):
        parts = [str(v) for v in value]
    else:
        parts = str(value).split(",")
    # Sort a pure comma-separated integer list so ``satellite_ids=3,1,2`` and
    # ``1,2,3`` hash the same (the ranking/filtering depends on the set, not order).
    if len(parts) > 1 and all(p.strip().isdigit() for p in parts):
        parts = sorted(parts, key=lambda p: int(p.strip()))
    return ",".join(p.strip() for p in parts)


def canonical_query(query: Mapping[str, Any]) -> list[tuple[str, str]]:
    return [(k, _canonical_value(query[k])) for k in sorted(query)]


def compute_etag(
    route_id: str,
    query: Mapping[str, Any],
    datasets: Mapping[str, int],
    bucket_s: int | None = None,
    now: float | None = None,
) -> str:
    """Compute the weak ETag for one endpoint invocation."""
    settings = get_settings()
    parts: list[str] = [route_id]
    parts.extend(f"{k}={v}" for k, v in canonical_query(query))
    parts.extend(f"{k}={datasets[k]}" for k in sorted(datasets))
    parts.append(settings.media_base_url)
    parts.append(settings.contract_version)
    if bucket_s is not None:
        ts = int((now if now is not None else _time.time()) // bucket_s)
        parts.append(f"t={ts}")

    digest = hashlib.sha256("\x00".join(parts).encode("utf-8")).hexdigest()
    return f'W/"{digest[:16]}"'


def _opaque(tag: str) -> str:
    return tag.strip().removeprefix("W/")


def if_none_match(header: str | None, etag: str) -> bool:
    """Whether an ``If-None-Match`` header matches ``etag`` (weak comparison, lists, ``*``)."""
    if not header:
        return False
    if header.strip() == "*":
        return True
    return _opaque(etag) in {_opaque(tag) for tag in header.split(",")}
