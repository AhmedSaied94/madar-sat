"""``/v1/rights-holders`` and ``/v1/rights-holders/{id}`` routes."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ETag
from app.api.envelope import Envelope, ok
from app.api.errors import EntityNotFound
from app.api.public._query import IdPath, IdQuery
from app.db.session import get_session
from app.schemas import public as s
from app.services import catalog

router = APIRouter(prefix="/v1/rights-holders", tags=["rights-holders"])

ETAG_DATASETS = ("rights_holders", "satellites", "competitions")


@router.get(
    "",
    response_model=Envelope[list[s.RightsHolder]],
    dependencies=[Depends(ETag("rights_holders", ETAG_DATASETS))],
)
async def list_rights_holders(
    satellite_id: IdQuery = None,
    competition_id: IdQuery = None,
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[s.RightsHolder]]:
    return ok(await catalog.list_rights_holders(session, satellite_id, competition_id))


@router.get(
    "/{rights_holder_id}",
    response_model=Envelope[s.RightsHolderDetail],
    dependencies=[Depends(ETag("rights_holder_detail", ETAG_DATASETS))],
)
async def get_rights_holder(
    rights_holder_id: IdPath, session: AsyncSession = Depends(get_session)
) -> Envelope[s.RightsHolderDetail]:
    data = await catalog.get_rights_holder(session, rights_holder_id)
    if data is None:
        raise EntityNotFound("rights_holder_not_found")
    return ok(data)
