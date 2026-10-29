"""``/v1/competitions`` and ``/v1/competitions/{id}`` routes."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.api.errors import EntityNotFound
from app.api.public._query import IdPath
from app.db.session import get_session
from app.schemas import public as s
from app.services import catalog

router = APIRouter(prefix="/v1/competitions", tags=["competitions"])

ETAG_DATASETS = ("competitions", "rights_holders")


@router.get(
    "",
    response_model=Envelope[list[s.Competition]],
    dependencies=[Depends(ETag("competitions", ETAG_DATASETS))],
)
async def list_competitions(session: AsyncSession = Depends(get_session)) -> Envelope[list[s.Competition]]:
    return ok(await catalog.list_competitions(session))


@router.get(
    "/{competition_id}",
    response_model=Envelope[s.CompetitionDetail],
    dependencies=[Depends(ETag("competition_detail", ETAG_DATASETS))],
)
async def get_competition(
    competition_id: IdPath, session: AsyncSession = Depends(get_session)
) -> Envelope[s.CompetitionDetail]:
    data = await catalog.get_competition(session, competition_id)
    if data is None:
        raise EntityNotFound("competition_not_found")
    return ok(data)
