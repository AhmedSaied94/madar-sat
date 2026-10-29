"""``/v1/commentators/{id}`` route."""

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
from app.services import commentators

router = APIRouter(prefix="/v1/commentators", tags=["commentators"])


@router.get(
    "/{commentator_id}",
    response_model=Envelope[s.CommentatorDetail],
    dependencies=[
        Depends(
            ETag(
                "commentator",
                ("commentators", "matches", "channels", "satellites", "competitions", "teams"),
                bucket_s=60,
            )
        )
    ],
)
async def get_commentator(
    commentator_id: IdPath,
    session: AsyncSession = Depends(get_session),
    now: datetime = Depends(get_now),
) -> Envelope[s.CommentatorDetail]:
    data = await commentators.get_commentator(session, commentator_id, now)
    if data is None:
        raise EntityNotFound("commentator_not_found")
    return ok(data)
