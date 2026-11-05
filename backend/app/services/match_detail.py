"""``/v1/matches/{id}`` read query (research R6)."""

from __future__ import annotations

from collections.abc import Callable
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.db.models import (
    Channel,
    Commentator,
    Competition,
    Feed,
    Match,
    MatchChannel,
    MatchCustomBroadcast,
    MatchEvent,
    MatchLineup,
    Satellite,
    Team,
)
from app.domain.ranking import is_preferred_carriage, preferred_carriage_key
from app.domain.regions import REGION_ORDER, region_for
from app.schemas import public as s
from app.services.common import hidden_names, media_url, visible_link
from app.services.matches import build_match_summary, fetch_media_paths, frequency, satellite_ref

CommentatorLookup = Callable[[int | None], s.CommentatorRef | None]
# One source per timeline, so a goal can't show twice: names and minutes differ between them (R9).
EVENT_SOURCES = ("filgoal", "goal")


def _path(paths: dict[int, str], asset_id: int | None) -> str | None:
    if asset_id is None:
        return None
    return paths.get(asset_id)


async def get_match_detail(session: AsyncSession, match_id: int, now: datetime) -> s.MatchDetail | None:
    home_team = aliased(Team)
    away_team = aliased(Team)
    row = (
        await session.execute(
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
            .where(Match.id == match_id)
        )
    ).first()
    if row is None:
        return None

    match = row[0]

    link_rows = await session.execute(
        select(
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
            Channel.display_name,
            Channel.logo_asset_id,
            Channel.category,
            Channel.provider,
            Channel.package,
            Channel.beam,
            Channel.country,
            Channel.frequency_changed_at,
            Channel.frequency_note,
            Satellite.slug,
            Satellite.name_ar,
            Satellite.name_en,
            Satellite.orbital_position,
            Satellite.priority,
            MatchChannel.commentator_id,
            MatchChannel.commentator2_id,
        )
        .join(Channel, Channel.id == MatchChannel.channel_id)
        .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
        .where(MatchChannel.match_id == match_id)
        .where(visible_link(MatchChannel, Channel, hidden_names()))
    )
    channels: list[dict[str, Any]] = []
    commentator_ids: set[int | None] = set()
    asset_ids: set[int | None] = {
        match.home_logo_asset_id,
        match.away_logo_asset_id,
        row[2],  # competition logo
        row[3],  # home team logo
        row[4],  # away team logo
        row[6],  # match commentator photo
        row[7],  # match commentator audio
    }
    for r in link_rows:
        channels.append(
            {
                "id": r[0],
                "name": r[1],
                "access": r[2],
                "sort_order": r[3],
                "show_in_match": r[4],
                "kind": r[5],
                "satellite_id": r[6],
                "frequency_mhz": r[7],
                "polarization": r[8],
                "symbol_rate": r[9],
                "display_name": r[10],
                "logo_asset_id": r[11],
                "category": r[12],
                "provider": r[13],
                "package": r[14],
                "beam": r[15],
                "country": r[16],
                "frequency_changed_at": r[17],
                "frequency_note": r[18],
                "slug": r[19],
                "name_ar": r[20],
                "name_en": r[21],
                "orbital_position": float(r[22]) if r[22] is not None else None,
                "satellite_priority": r[23],
                "commentator_id": r[24],
                "commentator2_id": r[25],
            }
        )
        asset_ids.add(r[11])
        commentator_ids.update({r[24], r[25]})

    custom_rows = (
        await session.execute(
            select(
                MatchCustomBroadcast.slot,
                MatchCustomBroadcast.label,
                MatchCustomBroadcast.logo_asset_id,
                MatchCustomBroadcast.commentator_id,
            )
            .where(MatchCustomBroadcast.match_id == match_id)
            .order_by(MatchCustomBroadcast.slot)
        )
    ).all()
    for cr in custom_rows:
        asset_ids.add(cr[2])
        commentator_ids.add(cr[3])

    commentator_rows = (
        await session.execute(
            select(Commentator.id, Commentator.name, Commentator.photo_asset_id, Commentator.audio_asset_id).where(
                Commentator.id.in_(sorted({i for i in commentator_ids if i is not None}))
            )
        )
    ).all()
    commentators: dict[int, Any] = {cm[0]: cm for cm in commentator_rows}
    for cm in commentator_rows:
        asset_ids.update({cm[2], cm[3]})

    paths = await fetch_media_paths(session, asset_ids)

    def comment_ref(cid: int | None) -> s.CommentatorRef | None:
        if cid is None or cid not in commentators:
            return None
        cdata = commentators[cid]
        return s.CommentatorRef(
            id=cdata[0], name=cdata[1], image=media_url(paths.get(cdata[2])), audio=media_url(paths.get(cdata[3]))
        )

    for c in channels:
        c["logo_path"] = paths.get(c["logo_asset_id"])

    custom_broadcasts: list[s.BroadcastEntry] = []
    for cr in custom_rows:
        custom_broadcasts.append(
            s.BroadcastEntry(
                kind="custom",
                label=cr[1],
                logo=media_url(_path(paths, cr[2])),
                # The loader stores each slot's own commentator (slot 1 = the match commentator).
                commentators=[ref for ref in (comment_ref(cr[3]),) if ref is not None],
            )
        )

    preferred = [c for c in channels if is_preferred_carriage(c["kind"], c["slug"], c["show_in_match"])]
    preferred.sort(key=lambda c: preferred_carriage_key(c["access"], c["sort_order"], c["id"]))
    broadcasts = custom_broadcasts + [_channel_broadcast(c, comment_ref) for c in preferred]

    carriages = [c for c in channels if c["kind"] in ("satellite", "terrestrial")]
    carriages.sort(
        key=lambda c: (
            c["satellite_priority"] is None,
            c["satellite_priority"] if c["satellite_priority"] is not None else 0,
            c["access"] != "free",
            c["sort_order"] is None,
            c["sort_order"] or 0,
            c["id"],
        )
    )
    carriage_entries = [_carriage(c, comment_ref) for c in carriages]

    platform_items = [c for c in channels if c["kind"] == "platform"]
    groups: dict[str, list[s.PlatformEntry]] = {}
    for c in platform_items:
        groups.setdefault(region_for(c["country"]), []).append(
            s.PlatformEntry(channel_id=c["id"], name=c["name"], country=c["country"], logo=media_url(c["logo_path"]))
        )
    for g in groups.values():
        g.sort(key=lambda p: (p.country or "", p.name))
    platform_groups = [
        s.PlatformGroup(region=region, items=groups[region]) for region in REGION_ORDER if region in groups
    ]

    feed_row = (await session.execute(select(Feed.id).where(Feed.match_id == match_id).limit(1))).first()
    feed_id = feed_row[0] if feed_row is not None else None

    summary = build_match_summary(
        match,
        now,
        row[1],
        _path(paths, row[2]),
        _path(paths, match.home_logo_asset_id) or _path(paths, row[3]),
        _path(paths, match.away_logo_asset_id) or _path(paths, row[4]),
        row[5],
        _path(paths, row[6]),
        _path(paths, row[7]),
        channels,
        (),
        (),
    )

    # An estimated state comes from the clock, so nothing from the feed may sit beside it.
    events, lineups = ([], None) if summary.estimated else await _live_details(session, match_id)

    return s.MatchDetail(
        **summary.model_dump(),
        stadium=match.stadium,
        local_broadcaster_eg=match.local_broadcaster_eg,
        broadcasts=broadcasts,
        carriages=carriage_entries,
        platforms=platform_groups,
        events=events,
        lineups=lineups,
        feed_id=feed_id,
    )


def _minute_key(minute: str) -> tuple[int, int]:
    """``45+2`` sorts after ``45`` and before ``46``; text order would put ``9`` after ``45``."""
    regular, _, stoppage = minute.partition("+")
    return int(regular), int(stoppage or 0)


async def _live_details(session: AsyncSession, match_id: int) -> tuple[list[s.MatchEvent], s.MatchLineups | None]:
    event_rows = await session.scalars(
        select(MatchEvent).where(MatchEvent.match_id == match_id, MatchEvent.source.in_(EVENT_SOURCES))
    )
    by_source: dict[str, list[MatchEvent]] = {}
    for event in event_rows:
        by_source.setdefault(event.source, []).append(event)
    served = next((by_source[source] for source in EVENT_SOURCES if source in by_source), [])
    events = [
        s.MatchEvent(type=e.type, side=e.side, minute=e.minute, player=e.player_name)
        for e in sorted(served, key=lambda e: (_minute_key(e.minute), e.id))
    ]
    sides = {
        row.side: s.LineupSide(formation=row.formation, players=row.players)
        for row in await session.scalars(select(MatchLineup).where(MatchLineup.match_id == match_id))
    }
    lineups = s.MatchLineups(home=sides.get("home"), away=sides.get("away")) if sides else None
    return events, lineups


def _commentators(c: dict[str, Any], comment_ref: CommentatorLookup) -> list[s.CommentatorRef]:
    return [x for x in (comment_ref(c["commentator_id"]), comment_ref(c["commentator2_id"])) if x is not None]


def _channel_broadcast(c: dict[str, Any], comment_ref: CommentatorLookup) -> s.BroadcastEntry:
    return s.BroadcastEntry(
        kind="channel",
        channel_id=c["id"],
        label=c["name"],
        logo=media_url(c["logo_path"]),
        access=c["access"],
        satellite=satellite_ref(c),
        frequency=frequency(c),
        commentators=_commentators(c, comment_ref),
    )


def _carriage(c: dict[str, Any], comment_ref: CommentatorLookup) -> s.CarriageEntry:
    return s.CarriageEntry(
        id=c["id"],
        kind=c["kind"],
        name=c["name"],
        display_name=c["display_name"],
        logo=media_url(c["logo_path"]),
        category=c["category"],
        satellite=satellite_ref(c),
        frequency=frequency(c),
        frequency_note=c["frequency_note"],
        access=c["access"],
        provider=c["provider"],
        package=c["package"],
        beam=c["beam"],
        country=c["country"],
        frequency_changed_at=c["frequency_changed_at"],
        commentators=_commentators(c, comment_ref),
    )
