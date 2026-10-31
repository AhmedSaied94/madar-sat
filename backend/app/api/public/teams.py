"""``/v1/teams`` search and ``/v1/teams/{id}`` routes."""

from __future__ import annotations

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import ETag, get_now
from app.api.envelope import Envelope, ok
from app.api.errors import EntityNotFound
from app.api.public._query import IdPath, query_error
from app.db.session import get_session
from app.schemas import NoNul
from app.schemas import public as s
from app.services import teams

router = APIRouter(prefix="/v1/teams", tags=["teams"])

# Contract ETag table: search and detail read the same datasets; only the detail is bucketed.
TEAM_DATASETS = ("teams", "competitions", "matches", "channels", "satellites", "commentators")


@router.get(
    "",
    response_model=Envelope[list[s.TeamSearchItem]],
    dependencies=[Depends(ETag("teams", TEAM_DATASETS))],
)
async def search_teams(
    # No `pattern=`: the NUL guard must not enter the published schema (B1-R2-1).
    q: Annotated[str, Query(min_length=1, max_length=64), NoNul],
    limit: int = Query(20, ge=1, le=50),
    cursor: str | None = Query(None),
    session: AsyncSession = Depends(get_session),
) -> Envelope[list[s.TeamSearchItem]]:
    try:
        items, next_cursor = await teams.search_teams(session, q, limit=limit, cursor=cursor)
    except teams.InvalidCursor:
        raise query_error("cursor", "invalid_cursor", "invalid cursor") from None
    return ok(items, {"next_cursor": next_cursor})


@router.get(
    "/{team_id}",
    response_model=Envelope[s.TeamDetail],
    dependencies=[Depends(ETag("team_detail", TEAM_DATASETS, bucket_s=60))],
)
async def get_team(
    team_id: IdPath,
    session: AsyncSession = Depends(get_session),
    now: datetime = Depends(get_now),
) -> Envelope[s.TeamDetail]:
    data = await teams.get_team(session, team_id, now)
    if data is None:
        raise EntityNotFound("team_not_found")
    return ok(data)
