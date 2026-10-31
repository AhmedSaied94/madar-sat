"""``app.admin:app`` refuses to start without a usable ``ADMIN_JWT_SECRET`` (FR-004, B1-R1-9).

The check is in the lifespan, not at import, so ``export-openapi`` and the workers can import the
module without the secret. These three cases are what keeps it that way: remove the check and the
missing-key and short-key cases start passing, which fails this test.
"""

from __future__ import annotations

import pytest
from fastapi import FastAPI

from app.admin import lifespan


@pytest.mark.parametrize(
    ("secret", "starts"),
    [
        (None, False),
        ("x" * 31, False),
        ("x" * 32, True),
    ],
)
async def test_the_lifespan_refuses_a_missing_or_short_secret(monkeypatch, secret, starts):
    from app.settings import get_settings

    if secret is None:
        monkeypatch.delenv("ADMIN_JWT_SECRET", raising=False)
    else:
        monkeypatch.setenv("ADMIN_JWT_SECRET", secret)
    get_settings.cache_clear()  # the settings object is cached, and this test changes its input

    try:
        if starts:
            async with lifespan(FastAPI()):
                pass
        else:
            with pytest.raises(RuntimeError, match="ADMIN_JWT_SECRET"):
                async with lifespan(FastAPI()):
                    pass
    finally:
        get_settings.cache_clear()
