"""``/v1/matches`` and ``/v1/matches/{id}`` routes."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ETag, get_now
from app.api.envelope import Envelope, ok
from app.api.errors import EntityNotFound
from app.api.public._query import IdPath, IdQuery, parse_id_list, query_error
from app.db.session import get_session
from app.domain.time import validate_window
from app.schemas import public as s
from app.services import match_detail, matches

router = APIRouter(prefix="/v1/matches", tags=["matches"])

MATCH_DATASETS = ("matches", "channels", "satellites", "competitions", "teams", "commentators")


@router.get(
    "",
    response_model=Envelope[list[s.MatchSummary]],
    dependencies=[Depends(ETag("matches", MATCH_DATASETS, bucket_s=60))],
)
async def list_matches(
    from_dt: datetime = Query(..., alias="from"),
    to_dt: datetime = Query(..., alias="to"),
    sport: s.Sport | None = Query(None),
    competition_id: IdQuery = None,
    team_id: IdQuery = None,
    satellite_ids: str | None = Query(None),
    my_satellite_ids: str | None = Query(None),
    status: s.Status | None = Query(None),
    session: AsyncSession = Depends(get_session),
    now: datetime = Depends(get_now),
) -> Envelope[list[s.MatchSummary]]:
    try:
        validate_window(from_dt, to_dt)
    except ValueError as e:
        raise query_error("to", "window", str(e)) from None
    data = await matches.list_matches(
        session,
        now=now,
        from_dt=from_dt,
        to_dt=to_dt,
        sport=sport.value if sport else None,
        competition_id=competition_id,
        team_id=team_id,
        satellite_ids=parse_id_list(satellite_ids, "satellite_ids"),
        my_satellite_ids=parse_id_list(my_satellite_ids, "my_satellite_ids"),
        status=status.value if status else None,
    )
    return ok(data, {"count": len(data)})


@router.get(
    "/{match_id}",
    response_model=Envelope[s.MatchDetail],
    dependencies=[Depends(ETag("match_detail", MATCH_DATASETS, bucket_s=15))],
)
async def get_match(
    match_id: IdPath,
    session: AsyncSession = Depends(get_session),
    now: datetime = Depends(get_now),
) -> Envelope[s.MatchDetail]:
    data = await match_detail.get_match_detail(session, match_id, now)
    if data is None:
        raise EntityNotFound("match_not_found")
    return ok(data)
