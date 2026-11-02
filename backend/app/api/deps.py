"""FastAPI dependencies: current time and the ETag dependency (research R4)."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import Depends, Request, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import cache
from app.api.errors import NotModified, validator_headers
from app.api.etag import compute_etag, if_none_match
from app.db.models import DatasetVersion
from app.db.session import get_session


def get_now() -> datetime:
    """Current UTC time; overridable in tests for a frozen clock."""
    return datetime.now(UTC)


class ETag:
    """A per-route dependency that computes and checks the weak ETag.

    Reads ``dataset_versions`` once (one small query), answers a matching
    ``If-None-Match`` with a 304 before the main query runs, and otherwise sets
    ``ETag``, ``Cache-Control: no-cache`` and ``Vary: Accept-Encoding``.
    """

    def __init__(self, route_id: str, datasets: tuple[str, ...], bucket_s: int | None = None) -> None:
        self.route_id = route_id
        self.datasets = datasets
        self.bucket_s = bucket_s

    async def __call__(
        self,
        request: Request,
        response: Response,
        session: AsyncSession = Depends(get_session),
    ) -> None:
        versions: dict[str, int] = {}
        if self.datasets:
            rows = await session.execute(
                select(DatasetVersion.name, DatasetVersion.version).where(DatasetVersion.name.in_(self.datasets))
            )
            versions = {name: version for name, version in rows}
        etag = compute_etag(self.route_id, request.query_params, versions, self.bucket_s, path=request.url.path)
        if if_none_match(request.headers.get("if-none-match"), etag):
            raise NotModified(etag)
        ttl = cache.ttl_for(self.route_id)
        if ttl is not None:
            request.state.cache_ttl = ttl
            stored = await cache.lookup(etag)
            if stored is not None:
                raise cache.CachedResponse(etag, stored)
        response.headers.update(validator_headers(etag))
