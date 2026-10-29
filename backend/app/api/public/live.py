"""``/v1/live`` route."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ETag, get_now
from app.api.envelope import Envelope, ok
from app.db.session import get_session
from app.schemas import public as s
from app.services import live

router = APIRouter(prefix="/v1/live", tags=["live"])


@router.get(
    "",
    response_model=Envelope[list[s.LiveState]],
    dependencies=[Depends(ETag("live", ("matches", "live"), bucket_s=15))],
)
async def get_live(
    session: AsyncSession = Depends(get_session),
    now: datetime = Depends(get_now),
) -> Envelope[list[s.LiveState]]:
    return ok(await live.list_live(session, now))
