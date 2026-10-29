"""``/v1/channels/{id}`` route."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ETag, get_now
from app.api.envelope import Envelope, ok
from app.api.errors import EntityNotFound
from app.api.public._query import IdPath
from app.db.session import get_session
from app.schemas import public as s
from app.services import channels

router = APIRouter(prefix="/v1/channels", tags=["channels"])


@router.get(
    "/{channel_id}",
    response_model=Envelope[s.ChannelDetail],
    dependencies=[
        Depends(ETag("channel", ("channels", "satellites", "matches", "competitions", "teams"), bucket_s=60))
    ],
)
async def get_channel(
    channel_id: IdPath,
    session: AsyncSession = Depends(get_session),
    now: datetime = Depends(get_now),
) -> Envelope[s.ChannelDetail]:
    data = await channels.get_channel_detail(session, channel_id, now)
    if data is None:
        raise EntityNotFound("channel_not_found")
    return ok(data)
