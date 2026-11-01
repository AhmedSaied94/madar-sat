"""Token generation and hashing for anonymous devices (research R1).

A token is 256 server-generated bits, base64url without padding (43 characters). The server
stores only ``sha256(token)`` hex, so a database leak does not hand out working tokens and a
lookup is an indexed equality on a value an attacker cannot choose.
"""

from __future__ import annotations

import base64
import hashlib
import secrets

TOKEN_BYTES = 32
TOKEN_CHARS = 43  # base64url of 32 bytes without padding
SCHEME = "Device"


def new_token() -> str:
    """A fresh 43-character base64url token."""
    return base64.urlsafe_b64encode(secrets.token_bytes(TOKEN_BYTES)).rstrip(b"=").decode("ascii")


def token_hash(token: str) -> str:
    """The stored form of a token: lowercase ``sha256`` hex."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def parse_header(header: str | None) -> str | None:
    """The token of an ``Authorization: Device <token>`` header, or ``None`` when it doesn't parse."""
    if not header:
        return None
    scheme, _, token = header.partition(" ")
    token = token.strip()
    if scheme.lower() != SCHEME.lower() or not token:
        return None
    return token
