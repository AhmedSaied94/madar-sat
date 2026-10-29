"""``/v1/teams`` search and ``/v1/teams/{id}`` detail."""

from __future__ import annotations

import base64
from datetime import datetime

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Competition, Match, MediaAsset, Team, TeamCompetition
from app.domain.arabic import ar_normalize
from app.domain.time import CAIRO
from app.schemas import public as s
from app.services.common import media_url
from app.services.matches import summaries_for_ids


def _encode_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(str(offset).encode()).decode().rstrip("=")


MAX_OFFSET = 2_147_483_647


class InvalidCursor(ValueError):
    """The cursor wasn't produced by ``_encode_cursor``."""


def _decode_cursor(cursor: str) -> int:
    try:
        raw = base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)).decode("ascii")
    except ValueError:  # binascii.Error and UnicodeDecodeError
        raise InvalidCursor(cursor) from None
    # isdigit() alone accepts Arabic-Indic digits; only what _encode_cursor writes is valid.
    if not (raw.isascii() and raw.isdigit()) or int(raw) > MAX_OFFSET:
        raise InvalidCursor(cursor)
    return int(raw)


async def search_teams(
    session: AsyncSession, q: str, limit: int = 20, cursor: str | None = None
) -> tuple[list[s.TeamSearchItem], str | None]:
    q_norm = ar_normalize(q)
    offset = _decode_cursor(cursor) if cursor else 0

    exact = (Team.name_norm == q_norm).desc()
    prefix = Team.name_norm.like(f"{q_norm}%").desc()
    sim = func.similarity(Team.name_norm, q_norm).desc()

    rows = (
        await session.execute(
            select(Team, Competition.name, MediaAsset.path)
            .outerjoin(Competition, Competition.id == Team.primary_competition_id)
            .outerjoin(MediaAsset, MediaAsset.id == Team.logo_asset_id)
            .where(or_(Team.name_norm.like(f"%{q_norm}%"), func.similarity(Team.name_norm, q_norm) > 0.25))
            .order_by(exact, prefix, sim, Team.id)
            .limit(limit + 1)
            .offset(offset)
        )
    ).all()

    items = [
        s.TeamSearchItem(
            id=t.id,
            sport=t.sport,
            name=t.name,
            country=t.country,
            logo=media_url(p),
            primary_competition=s.PrimaryCompetitionRef(id=t.primary_competition_id, name=comp_name)
            if t.primary_competition_id is not None
            else None,
        )
        for t, comp_name, p in rows[:limit]
    ]
    next_cursor = _encode_cursor(offset + limit) if len(rows) > limit else None
    return items, next_cursor


async def get_team(session: AsyncSession, team_id: int, now: datetime) -> s.TeamDetail | None:
    row = (
        await session.execute(
            select(Team, Competition.name, MediaAsset.path)
            .outerjoin(Competition, Competition.id == Team.primary_competition_id)
            .outerjoin(MediaAsset, MediaAsset.id == Team.logo_asset_id)
            .where(Team.id == team_id)
        )
    ).first()
    if row is None:
        return None
    team, comp_name, logo_path = row

    comp_rows = await session.execute(
        select(Competition.id, Competition.name, MediaAsset.path)
        .join(TeamCompetition, TeamCompetition.competition_id == Competition.id)
        .outerjoin(MediaAsset, MediaAsset.id == Competition.logo_asset_id)
        .where(TeamCompetition.team_id == team_id)
        .order_by(Competition.name)
    )
    competitions = [s.NamedRef(id=r[0], name=r[1], logo=media_url(r[2])) for r in comp_rows]

    team_filter = or_(Match.home_team_id == team_id, Match.away_team_id == team_id)

    upcoming_ids = (
        (
            await session.execute(
                select(Match.id)
                .where(
                    team_filter,
                    or_(
                        Match.kickoff_at >= now,
                        # match_date is a Cairo calendar date: a TBD match is upcoming until that day ends.
                        and_(Match.time_tbd.is_(True), Match.match_date >= now.astimezone(CAIRO).date()),
                    ),
                )
                .order_by(Match.kickoff_at.asc(), Match.id.asc())
                .limit(10)
            )
        )
        .scalars()
        .all()
    )
    recent_ids = (
        (
            await session.execute(
                select(Match.id)
                .where(team_filter, Match.kickoff_at.is_not(None), Match.kickoff_at < now)
                .order_by(Match.kickoff_at.desc(), Match.id.desc())
                .limit(10)
            )
        )
        .scalars()
        .all()
    )

    upcoming = await summaries_for_ids(session, now, list(upcoming_ids))
    recent = await summaries_for_ids(session, now, list(recent_ids))
    recent.reverse()

    return s.TeamDetail(
        id=team.id,
        sport=team.sport,
        name=team.name,
        country=team.country,
        logo=media_url(logo_path),
        primary_competition=s.PrimaryCompetitionRef(id=team.primary_competition_id, name=comp_name)
        if team.primary_competition_id is not None
        else None,
        stadium=team.stadium,
        competitions=competitions,
        upcoming=upcoming,
        recent=recent,
    )
