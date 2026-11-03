"""``client_ip()``: the trusted-proxy setting decides whose ``X-Forwarded-For`` is believed (D4 T001).

The public app sits behind Caddy on VPS-1, which reaches ``api-public`` through the Docker bridge
gateway, so the peer is ``172.30.0.1``, not Caddy's usual ``10.8.0.1`` (research R1). The list comes
from ``TRUSTED_PROXIES``; the admin app keeps the default.
"""

from __future__ import annotations

import pytest
from fastapi import Request
from pydantic import ValidationError

from app.auth.limits import client_ip
from app.settings import Settings, get_settings


def _request(peer: str, forwarded: str | None = None) -> Request:
    headers = [(b"x-forwarded-for", forwarded.encode())] if forwarded is not None else []
    return Request(
        {
            "type": "http",
            "client": (peer, 5000),
            "headers": headers,
            "method": "GET",
            "path": "/v1/live",
        }
    )


def _trust(monkeypatch: pytest.MonkeyPatch, *proxies: str) -> None:
    monkeypatch.setattr(get_settings(), "trusted_proxies", list(proxies))


@pytest.mark.parametrize("peer", ["127.0.0.1", "172.30.0.1"])
def test_a_trusted_peer_passes_the_client_it_saw(monkeypatch, peer):
    _trust(monkeypatch, "127.0.0.1", "172.30.0.1")

    assert client_ip(_request(peer, "203.0.113.7")) == "203.0.113.7"


def test_the_forged_left_hop_is_ignored(monkeypatch):
    _trust(monkeypatch, "127.0.0.1", "172.30.0.1")

    # The client sent 6.6.6.6; Caddy appended the address it saw, so the right-most hop wins.
    assert client_ip(_request("172.30.0.1", "6.6.6.6, 203.0.113.7")) == "203.0.113.7"


def test_a_peer_outside_the_list_ignores_the_header(monkeypatch):
    _trust(monkeypatch, "127.0.0.1", "172.30.0.1")

    assert client_ip(_request("203.0.113.9", "198.51.100.1")) == "203.0.113.9"


def test_an_empty_list_trusts_nobody(monkeypatch):
    _trust(monkeypatch)

    assert client_ip(_request("10.8.0.1", "203.0.113.7")) == "10.8.0.1"


def test_an_invalid_hop_falls_back_to_the_peer(monkeypatch):
    _trust(monkeypatch, "127.0.0.1")

    assert client_ip(_request("127.0.0.1", "not-an-ip")) == "127.0.0.1"


def test_the_default_is_caddys_wireguard_address():
    assert Settings().trusted_proxies == ["10.8.0.1"]


def test_a_bad_proxy_fails_startup():
    with pytest.raises(ValidationError, match="TRUSTED_PROXIES"):
        Settings(TRUSTED_PROXIES="10.8.0.1,not-an-ip")


def test_a_comma_list_is_split_and_validated():
    settings = Settings(TRUSTED_PROXIES="127.0.0.1, 172.30.0.1")

    assert settings.trusted_proxies == ["127.0.0.1", "172.30.0.1"]
