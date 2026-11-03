"""The public ASGI app (``app.public:app``).

Serves ``/v1`` and ``/healthz``. It never imports or mounts admin routers
(constitution V, FR-013).
"""

from __future__ import annotations

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import cache, errors, health, openapi
from app.api.public import (
    channels,
    commentators,
    competitions,
    devices,
    live,
    matches,
    rights_holders,
    satellites,
    teams,
)
from app.api.ratelimit import rate_limit, warn_if_exempt_allowlist
from app.settings import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    warn_if_exempt_allowlist()
    app = FastAPI(
        title="Madar Sat Public API",
        version=settings.contract_version,
        description="Read-only /v1 endpoints for the Madar Sat app.",
    )

    app.add_middleware(errors.RequestIdMiddleware)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["If-None-Match", "Authorization", "Content-Type"],
        expose_headers=["ETag"],
    )
    app.add_middleware(cache.ResponseCacheMiddleware)

    errors.register_exception_handlers(app)

    limit = [Depends(rate_limit)]
    app.include_router(matches.router, dependencies=limit)
    app.include_router(live.router, dependencies=limit)
    app.include_router(satellites.router, dependencies=limit)
    app.include_router(channels.router, dependencies=limit)
    app.include_router(competitions.router, dependencies=limit)
    app.include_router(teams.router, dependencies=limit)
    app.include_router(rights_holders.router, dependencies=limit)
    app.include_router(commentators.router, dependencies=limit)
    app.include_router(devices.router, dependencies=limit)

    app.add_api_route("/healthz", health.health_endpoint, methods=["GET"], tags=["health"])
    openapi.install(app)

    return app


app = create_app()
