"""The admin ASGI app (``app.admin:app``).

A separate application from ``app.public`` (FR-013). On D1 it only exposes the auth
stubs (501) and its health route; it is bound to WireGuard ``wg0`` by Compose, never
mounted on the public app.
"""

from __future__ import annotations

from fastapi import FastAPI

from app.api import errors, health, openapi
from app.api.admin import auth
from app.settings import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Madar Sat Admin API",
        version=settings.contract_version,
        description="Admin API — reachable only over WireGuard (constitution V).",
    )

    app.add_middleware(errors.RequestIdMiddleware)
    errors.register_exception_handlers(app)

    app.include_router(auth.router)

    app.add_api_route("/admin/api/healthz", health.health_endpoint, methods=["GET"], tags=["health"])
    openapi.install(app)

    return app


app = create_app()
