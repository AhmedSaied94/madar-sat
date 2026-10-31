"""``/v1/matches`` read query and shared summary assembly (FR-008)."""

from __future__ import annotations

from collections.abc import Iterable
from datetime import date, datetime, timedelta
from typing import Any

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.db.models import Channel, Commentator, Competition, Match, MatchChannel, MediaAsset, Satellite, Team
from app.domain.ranking import HeadlineCandidate, headline
from app.domain.status import DerivedStatus, derive_status
from app.domain.time import tbd_anchor
from app.schemas import public as s
from app.services.common import hidden_names, media_url, visible_link


async def fetch_media_paths(session: AsyncSession, asset_ids: Iterable[int | None]) -> dict[int, str]:
    ids = sorted({i for i in asset_ids if i is not None})
    if not ids:
        return {}
    rows = await session.execute(select(MediaAsset.id, MediaAsset.path).where(MediaAsset.id.in_(ids)))
    return {i: p for i, p in rows.all()}


def tbd_dates(from_dt: datetime, to_dt: datetime) -> set[date]:
    """The dates whose TBD anchor falls inside the window.

    A window may legally start on the calendar's first day or end on its last, so the two-day
    margins are clamped instead of raising ``OverflowError`` (schemathesis finds it).
    """
    result: set[date] = set()
    try:
        start = (from_dt - timedelta(days=2)).date()
    except OverflowError:
        start = date.min
    try:
        end = (to_dt + timedelta(days=2)).date()
    except OverflowError:
        end = date.max
    d = start
    while d <= end:
        if from_dt <= tbd_anchor(d) < to_dt:
            result.add(d)
        if d == date.max:
            break
        d += timedelta(days=1)
    return result


async def fetch_visible_channels(session: AsyncSession, match_ids: list[int]) -> dict[int, list[dict[str, Any]]]:
    if not match_ids:
        return {}
    rows = await session.execute(
        select(
            MatchChannel.match_id,
            Channel.id,
            Channel.name,
            Channel.access,
            Channel.sort_order,
            Channel.show_in_match,
            Channel.kind,
            Channel.satellite_id,
            Channel.frequency_mhz,
            Channel.polarization,
            Channel.symbol_rate,
            Satellite.slug,
            Satellite.name_ar,
            Satellite.name_en,
            Satellite.orbital_position,
        )
        .join(Channel, Channel.id == MatchChannel.channel_id)
        .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
        .where(MatchChannel.match_id.in_(match_ids))
        .where(visible_link(MatchChannel, Channel, hidden_names()))
        .order_by(Channel.sort_order.nulls_last(), Channel.id)
    )
    result: dict[int, list[dict[str, Any]]] = {}
    for r in rows:
        item = {
            "id": r[1],
            "name": r[2],
            "access": r[3],
            "sort_order": r[4],
            "show_in_match": r[5],
            "kind": r[6],
            "satellite_id": r[7],
            "frequency_mhz": r[8],
            "polarization": r[9],
            "symbol_rate": r[10],
            "slug": r[11],
            "name_ar": r[12],
            "name_en": r[13],
            "orbital_position": float(r[14]) if r[14] is not None else None,
        }
        result.setdefault(r[0], []).append(item)
    return result


def satellite_ref(ch: dict[str, Any]) -> s.SatelliteRef | None:
    if ch["satellite_id"] is None:
        return None
    return s.SatelliteRef(
        id=ch["satellite_id"],
        slug=ch["slug"],
        name_ar=ch["name_ar"],
        name_en=ch["name_en"],
        orbital_position=ch["orbital_position"],
    )


def frequency(ch: dict[str, Any]) -> s.Frequency | None:
    if ch["frequency_mhz"] is None:
        return None
    return s.Frequency(mhz=ch["frequency_mhz"], pol=ch["polarization"], sr=ch["symbol_rate"])


def build_broadcast(
    channels: list[dict[str, Any]],
    my_satellite_ids: tuple[int, ...],
    filter_satellite_ids: tuple[int, ...],
) -> s.Broadcast:
    candidates = [
        HeadlineCandidate(
            channel_id=c["id"],
            name=c["name"],
            access=c["access"],
            satellite_id=c["satellite_id"],
            satellite_slug=c["slug"],
            sort_order=c["sort_order"],
            show_in_match=c["show_in_match"],
        )
        for c in channels
    ]
    picked = headline(candidates, my_satellite_ids, filter_satellite_ids)
    by_id = {c["id"]: c for c in channels}
    entries = [
        s.HeadlineEntry(
            channel_id=hc.channel_id,
            name=hc.name,
            access=hc.access,
            satellite=satellite_ref(by_id[hc.channel_id]),
            frequency=frequency(by_id[hc.channel_id]),
        )
        for hc in picked
    ]
    return s.Broadcast(
        channel_count=len(channels),
        has_free=any(c["access"] == "free" for c in channels),
        headline=entries,
    )


def match_score(match: Match) -> s.Score | None:
    if match.home_score is None and match.away_score is None:
        return None
    return s.Score(
        home=match.home_score or 0,
        away=match.away_score or 0,
        home_pen=match.home_pen,
        away_pen=match.away_pen,
    )


def build_match_summary(
    match: Match,
    now: datetime,
    competition_priority: int | None,
    competition_logo_path: str | None,
    home_logo_path: str | None,
    away_logo_path: str | None,
    commentator_name: str | None,
    commentator_photo: str | None,
    commentator_audio: str | None,
    channels: list[dict[str, Any]],
    my_satellite_ids: tuple[int, ...],
    filter_satellite_ids: tuple[int, ...],
) -> s.MatchSummary:
    derived: DerivedStatus = derive_status(match, now)
    competition = s.CompetitionRef(
        id=match.competition_id,
        name=match.competition_name,
        logo=media_url(competition_logo_path),
        stage=match.competition_stage,
        priority=competition_priority,
    )
    home = s.TeamRef(id=match.home_team_id, name=match.home_team_name, logo=media_url(home_logo_path))
    away = s.TeamRef(id=match.away_team_id, name=match.away_team_name, logo=media_url(away_logo_path))
    commentator = None
    if match.commentator_id is not None:
        commentator = s.CommentatorRef(
            id=match.commentator_id,
            name=commentator_name or "",
            image=media_url(commentator_photo),
            audio=media_url(commentator_audio),
        )
    return s.MatchSummary(
        id=match.id,
        sport=match.sport,
        kickoff_at=match.kickoff_at,
        time_tbd=match.time_tbd,
        match_date=match.match_date,
        status=derived.status,
        estimated=derived.estimated,
        period=match.period if not derived.estimated else None,
        minute=match.minute if not derived.estimated else None,
        score=match_score(match) if not derived.estimated else None,
        status_label=match.status_label,
        competition=competition,
        home=home,
        away=away,
        broadcast=build_broadcast(channels, my_satellite_ids, filter_satellite_ids),
        commentator=commentator,
        updated_at=match.updated_at,
    )


# A row carries the match plus its joined scalars for summary assembly.
def _match_rows(session: AsyncSession, conditions: list[Any]) -> Any:
    home_team = aliased(Team)
    away_team = aliased(Team)
    return session.execute(
        select(
            Match,
            Competition.priority,
            Competition.logo_asset_id,
            home_team.logo_asset_id,
            away_team.logo_asset_id,
            Commentator.name,
            Commentator.photo_asset_id,
            Commentator.audio_asset_id,
        )
        .outerjoin(Competition, Competition.id == Match.competition_id)
        .outerjoin(home_team, home_team.id == Match.home_team_id)
        .outerjoin(away_team, away_team.id == Match.away_team_id)
        .outerjoin(Commentator, Commentator.id == Match.commentator_id)
        .where(*conditions)
        .order_by(Match.kickoff_at.asc(), Match.id.asc())
    )


async def assemble_summaries(
    session: AsyncSession,
    now: datetime,
    raw_rows: Any,
    my_satellite_ids: tuple[int, ...] = (),
    filter_satellite_ids: tuple[int, ...] = (),
    channels: dict[int, list[dict[str, Any]]] | None = None,
) -> list[s.MatchSummary]:
    """Build summaries from the joined rows returned by ``_match_rows``.

    ``channels`` is the caller's ``fetch_visible_channels`` result when it already has one.
    """
    rows = list(raw_rows)
    if not rows:
        return []
    matches = [r[0] for r in rows]
    meta = {
        m.id: {
            "competition_priority": r[1],
            "competition_logo_asset_id": r[2],
            "home_team_logo_asset_id": r[3],
            "away_team_logo_asset_id": r[4],
            "commentator_name": r[5],
            "commentator_photo": r[6],
            "commentator_audio": r[7],
        }
        for m, r in zip(matches, rows, strict=False)
    }
    asset_ids: set[int] = set()
    for m, r in zip(matches, rows, strict=False):
        asset_ids.update({m.home_logo_asset_id, m.away_logo_asset_id, r[2], r[3], r[4], r[6], r[7]})
    paths = await fetch_media_paths(session, asset_ids)
    if channels is None:
        channels = await fetch_visible_channels(session, [m.id for m in matches])

    result: list[s.MatchSummary] = []
    for m in matches:
        md = meta[m.id]
        result.append(
            build_match_summary(
                m,
                now,
                md["competition_priority"],
                paths.get(md["competition_logo_asset_id"]),
                paths.get(m.home_logo_asset_id) or paths.get(md["home_team_logo_asset_id"]),
                paths.get(m.away_logo_asset_id) or paths.get(md["away_team_logo_asset_id"]),
                md["commentator_name"],
                paths.get(md["commentator_photo"]),
                paths.get(md["commentator_audio"]),
                channels.get(m.id, []),
                my_satellite_ids,
                filter_satellite_ids,
            )
        )
    return result


async def list_matches(
    session: AsyncSession,
    *,
    now: datetime,
    from_dt: datetime,
    to_dt: datetime,
    sport: str | None = None,
    competition_id: int | None = None,
    team_id: int | None = None,
    satellite_ids: tuple[int, ...] = (),
    status: str | None = None,
    my_satellite_ids: tuple[int, ...] = (),
) -> list[s.MatchSummary]:
    conditions = [
        or_(
            and_(Match.kickoff_at.is_not(None), Match.kickoff_at >= from_dt, Match.kickoff_at < to_dt),
            and_(Match.time_tbd.is_(True), Match.match_date.in_(tbd_dates(from_dt, to_dt))),
        )
    ]
    if sport:
        conditions.append(Match.sport == sport)
    if competition_id is not None:
        conditions.append(Match.competition_id == competition_id)
    if team_id is not None:
        conditions.append(or_(Match.home_team_id == team_id, Match.away_team_id == team_id))

    rows = list((await _match_rows(session, conditions)).all())

    # satellite_ids is a filter: keep matches with a visible carriage on those satellites.
    channels: dict[int, list[dict[str, Any]]] | None = None
    if satellite_ids:
        channels = await fetch_visible_channels(session, [r[0].id for r in rows])
        rows = [
            r
            for r in rows
            if any(
                c["satellite_id"] in satellite_ids and c["kind"] in ("satellite", "terrestrial")
                for c in channels.get(r[0].id, [])
            )
        ]

    if status is not None:
        rows = [r for r in rows if derive_status(r[0], now).status == status]

    return await assemble_summaries(session, now, rows, my_satellite_ids, satellite_ids, channels)


async def summaries_for_ids(session: AsyncSession, now: datetime, match_ids: list[int]) -> list[s.MatchSummary]:
    """Build summaries for an explicit list of match ids, kickoff-ascending."""
    if not match_ids:
        return []
    rows = list((await _match_rows(session, [Match.id.in_(match_ids)])).all())
    return await assemble_summaries(session, now, rows)
