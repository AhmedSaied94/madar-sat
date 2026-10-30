"""The role dependency every admin route carries (research R4).

``require_role("editor" | "admin")`` returns a FastAPI dependency that decodes the bearer token,
loads the admin by ``sub`` on every request (so a deactivation or a role change takes effect at
once, not when the 15-minute token runs out), and compares role rank (``admin`` covers ``editor``).
The role in the token is never trusted.

Use the two module-level instances, ``require_editor`` and ``require_admin``. FastAPI caches a
dependency per request by identity, so a router that lists one in ``dependencies=[…]`` and a
handler that also declares it run it once. A test walks ``app.admin:app`` and fails if a route
other than ``auth/*`` and ``healthz`` lacks one (T019).
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import datetime
from typing import Literal

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_now
from app.api.errors import forbidden, unauthenticated
from app.auth.tokens import InvalidToken, TokenExpired, decode_access_token
from app.db.models import AdminUser
from app.db.session import get_session

Role = Literal["editor", "admin"]
_RANK: dict[str, int] = {"editor": 1, "admin": 2}


@dataclass(frozen=True)
class AuthedAdmin:
    id: int
    email: str
    name: str
    role: Role

    def covers(self, role: Role) -> bool:
        return _RANK[self.role] >= _RANK[role]


def bearer_token(request: Request) -> str:
    """The token of an ``Authorization: Bearer <token>`` header, or ``401 unauthenticated``."""
    scheme, _, token = request.headers.get("authorization", "").partition(" ")
    token = token.strip()
    if scheme.lower() != "bearer" or not token:
        raise unauthenticated()
    return token


async def authenticate(request: Request, session: AsyncSession, now: datetime) -> AdminUser:
    """The active admin behind the request's access token (401 otherwise); no role check."""
    try:
        claims = decode_access_token(bearer_token(request), now)
    except TokenExpired:
        raise unauthenticated("token_expired") from None
    except InvalidToken:
        raise unauthenticated() from None
    admin = await session.get(AdminUser, claims.admin_id)
    if admin is None or not admin.is_active:
        raise unauthenticated()
    return admin


def require_role(role: Role) -> Callable[..., Awaitable[AuthedAdmin]]:
    async def dependency(
        request: Request,
        session: AsyncSession = Depends(get_session),
        now: datetime = Depends(get_now),
    ) -> AuthedAdmin:
        admin = await authenticate(request, session, now)
        authed = AuthedAdmin(id=admin.id, email=admin.email, name=admin.name, role=admin.role)  # type: ignore[arg-type]
        if not authed.covers(role):
            raise forbidden(role)
        return authed

    dependency.required_role = role  # type: ignore[attr-defined]  # read by the route-walking test
    return dependency


require_editor = require_role("editor")
require_admin = require_role("admin")
