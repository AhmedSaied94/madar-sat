"""``/healthz`` — live DB + Redis check (constitution VI, contracts).

A 200 carries an ETag hashed from the check result; a 503 carries no ETag.
"""

from __future__ import annotations

import hashlib

from fastapi import Depends, Request, Response
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.envelope import Envelope, ok
from app.api.errors import ApiError, NotModified, validator_headers
from app.api.etag import if_none_match
from app.db.session import get_session
from app.schemas.public import HealthStatus
from app.settings import get_settings


def _health_etag(data: dict[str, str]) -> str:
    digest = hashlib.sha256(repr(sorted(data.items())).encode("utf-8")).hexdigest()
    return f'W/"{digest[:16]}"'


async def _check_db(session: AsyncSession) -> bool:
    try:
        await session.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


async def _check_redis() -> bool:
    import redis.asyncio as aioredis

    try:
        client = aioredis.from_url(get_settings().redis_url, socket_connect_timeout=2)
        try:
            await client.ping()
            return True
        finally:
            await client.aclose()
    except Exception:
        return False


async def health_endpoint(
    request: Request, response: Response, session: AsyncSession = Depends(get_session)
) -> Envelope[HealthStatus]:
    settings = get_settings()
    if settings.healthz_force_fail:
        raise ApiError(503, "unhealthy", "forced failure")
    db_ok = await _check_db(session)
    redis_ok = await _check_redis()
    if not (db_ok and redis_ok):
        raise ApiError(503, "unhealthy", "dependency down")

    data = HealthStatus(db="ok", redis="ok")
    etag = _health_etag(data.model_dump())
    if if_none_match(request.headers.get("if-none-match"), etag):
        raise NotModified(etag)
    response.headers.update(validator_headers(etag))
    return ok(data)
