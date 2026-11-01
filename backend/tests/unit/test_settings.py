"""Settings that must fail fast (constitution V, FR-012): the push link's origin is https only.

An ``http://`` ``PWA_ORIGIN`` makes every web reminder fail at FCM with ``INVALID_ARGUMENT`` on
``fcm_options.link``, which used to be read as a dead token and cleared it (B1-R1-2).
"""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.settings import Settings


def test_an_https_pwa_origin_is_accepted(monkeypatch):
    monkeypatch.setenv("PWA_ORIGIN", "https://madar.web.app")

    assert str(Settings().pwa_origin) == "https://madar.web.app/"


def test_a_plain_http_pwa_origin_is_refused(monkeypatch):
    monkeypatch.setenv("PWA_ORIGIN", "http://madar.web.app")

    with pytest.raises(ValidationError):
        Settings()


def test_no_pwa_origin_is_still_allowed(monkeypatch):
    monkeypatch.delenv("PWA_ORIGIN", raising=False)

    assert Settings().pwa_origin is None
