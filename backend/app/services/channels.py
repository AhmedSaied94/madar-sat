"""``/v1/channels/{id}`` read query."""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Channel, Match, MatchChannel, MediaAsset, Satellite
from app.schemas import public as s
from app.services.matches import summaries_for_ids
from app.services.satellites import _carriage


async def get_channel_detail(session: AsyncSession, channel_id: int, now: datetime) -> s.ChannelDetail | None:
    row = (
        await session.execute(
            select(Channel, Satellite, MediaAsset.path)
            .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
            .outerjoin(MediaAsset, MediaAsset.id == Channel.logo_asset_id)
            .where(Channel.id == channel_id, Channel.deleted_at.is_(None), Channel.placeholder_source.is_(None))
        )
    ).first()
    if row is None:
        return None
    ch, sat, logo_path = row

    # Other carriages: same name_norm, not deleted, excluding this row.
    other_rows = await session.execute(
        select(Channel, Satellite, MediaAsset.path)
        .outerjoin(Satellite, Satellite.id == Channel.satellite_id)
        .outerjoin(MediaAsset, MediaAsset.id == Channel.logo_asset_id)
        .where(
            Channel.name_norm == ch.name_norm,
            Channel.id != channel_id,
            Channel.deleted_at.is_(None),
            Channel.placeholder_source.is_(None),
        )
        .order_by(Channel.sort_order.asc().nulls_last(), Channel.id)
    )
    other_carriages = [_carriage(o_ch, o_sat, o_logo) for o_ch, o_sat, o_logo in other_rows]

    # Upcoming matches (≤ 20): kickoff at or after now − 150 min, channel visible.
    match_id_rows = await session.execute(
        select(MatchChannel.match_id)
        .join(Match, Match.id == MatchChannel.match_id)
        .where(
            MatchChannel.channel_id == channel_id,
            MatchChannel.is_hidden.is_(False),
            Match.kickoff_at.is_not(None),
            Match.kickoff_at >= now - timedelta(minutes=150),
        )
        .order_by(Match.kickoff_at.asc())
        .limit(20)
    )
    upcoming = await summaries_for_ids(session, now, [r[0] for r in match_id_rows])

    return s.ChannelDetail(
        **_carriage(ch, sat, logo_path).model_dump(),
        other_carriages=other_carriages,
        upcoming_matches=upcoming,
        recent_frequency_changes=[],
    )
