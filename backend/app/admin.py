"""The admin ASGI app (``app.admin:app``).

A separate application from ``app.public`` (FR-013): bound to WireGuard ``wg0`` by Compose and
never mounted on the public app. Every route except ``auth/*`` and ``healthz`` carries the role
dependency of ``app.auth.roles`` (research R4); a test walks the routes to keep it that way.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api import errors, health, openapi
from app.api.admin import (
    audit,
    auth,
    channels,
    commentators,
    competitions,
    dashboard,
    lists,
    matches,
    media,
    notifications,
    ordering,
    rights_holders,
    satellites,
    sources,
    teams,
    unresolved_names,
    users,
)
from app.auth.tokens import signing_key
from app.settings import get_settings

DESCRIPTION = (
    "Admin API, reachable only over WireGuard (constitution V). Every route except `auth/*` and `healthz` "
    "needs `Authorization: Bearer <access_token>` and the role in its row of the contract. "
    "Writes need `If-Match` with the entity's `ETag`.\n\n"
    "Error codes added on D6: `password_change_required` (a flagged account may only read `auth/me` and "
    "change its password), `notification_not_cancellable` (only a pending announcement cancels), "
    "`send_at_in_past`, `text_not_allowed` (a card-sharing label), `test_device_not_set`, "
    "`test_device_no_token`, `device_not_found`, `email_taken`, `cannot_change_self`, `last_admin`, "
    "`password_too_short`, `password_unchanged`."
)


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Refuse to start without a usable ``ADMIN_JWT_SECRET``. Checked here, not at import, so
    ``export-openapi`` (CI) can import this module without the secret."""
    signing_key()
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Madar Sat Admin API",
        version=settings.contract_version,
        description=DESCRIPTION,
        lifespan=lifespan,
    )

    app.add_middleware(errors.RequestIdMiddleware)
    errors.register_exception_handlers(app)

    app.include_router(auth.router)
    for router in (
        matches.router,
        teams.router,
        competitions.router,
        satellites.router,
        channels.router,
        commentators.router,
        lists.router,
        media.router,
        sources.router,
        dashboard.router,
        ordering.router,
        unresolved_names.router,
        rights_holders.router,
        notifications.router,
        users.router,
        audit.router,
    ):
        app.include_router(router)

    app.add_api_route("/admin/api/healthz", health.health_endpoint, methods=["GET"], tags=["health"])
    openapi.install(app)

    return app


app = create_app()
