"""``/v1/satellites`` and ``/v1/satellites/{id}/channels`` routes."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.api.errors import EntityNotFound
from app.api.public._query import IdPath
from app.db.session import get_session
from app.schemas import public as s
from app.services import satellites

router = APIRouter(prefix="/v1/satellites", tags=["satellites"])


@router.get(
    "",
    response_model=Envelope[list[s.Satellite]],
    dependencies=[Depends(ETag("satellites", ("satellites", "channels")))],
)
async def list_satellites(
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[s.Satellite]]:
    return ok(await satellites.list_satellites(session))


@router.get(
    "/{satellite_id}/channels",
    response_model=Envelope[list[s.ChannelCarriage]],
    dependencies=[Depends(ETag("satellite_channels", ("channels", "satellites")))],
)
async def list_satellite_channels(
    satellite_id: IdPath,
    category: s.Category | None = Query(None),
    q: str | None = Query(None, max_length=64),
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[s.ChannelCarriage]]:
    data = await satellites.list_satellite_channels(
        session, satellite_id, category=category.value if category else None, q=q
    )
    if data is None:
        raise EntityNotFound("satellite_not_found")
    return ok(data)
