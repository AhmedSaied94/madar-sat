"""The public ASGI app (``app.public:app``).

Serves ``/v1`` and ``/healthz``. It never imports or mounts admin routers
(constitution V, FR-013).
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import errors, health
from app.api.public import (
    channels,
    commentators,
    competitions,
    live,
    matches,
    rights_holders,
    satellites,
    teams,
)
from app.settings import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="Madar Sat Public API",
        version=settings.contract_version,
        description="Read-only /v1 endpoints for the Madar Sat app.",
    )

    app.add_middleware(errors.RequestIdMiddleware)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["GET"],
        allow_headers=["If-None-Match"],
        expose_headers=["ETag"],
    )

    errors.register_exception_handlers(app)

    app.include_router(matches.router)
    app.include_router(live.router)
    app.include_router(satellites.router)
    app.include_router(channels.router)
    app.include_router(competitions.router)
    app.include_router(teams.router)
    app.include_router(rights_holders.router)
    app.include_router(commentators.router)

    app.add_api_route("/healthz", health.health_endpoint, methods=["GET"], tags=["health"])

    return app


app = create_app()
