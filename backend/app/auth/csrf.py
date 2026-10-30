"""The ``madar_csrf`` value that refresh and logout must echo in ``X-CSRF-Token`` (research R2)."""

from __future__ import annotations

import hmac
import secrets

CSRF_COOKIE = "madar_csrf"
CSRF_HEADER = "X-CSRF-Token"


def new_csrf_value() -> str:
    return secrets.token_urlsafe(32)


def csrf_matches(cookie: str | None, header: str | None) -> bool:
    """Both present, non-empty and equal, compared in constant time."""
    if not cookie or not header:
        return False
    return hmac.compare_digest(cookie.encode(), header.encode())
