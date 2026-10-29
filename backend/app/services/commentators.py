"""``/v1/commentators/{id}`` detail."""

from __future__ import annotations

from datetime import datetime, timedelta

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Commentator, Match, MatchChannel, MediaAsset
from app.schemas import public as s
from app.services.common import media_url
from app.services.matches import summaries_for_ids


async def get_commentator(session: AsyncSession, commentator_id: int, now: datetime) -> s.CommentatorDetail | None:
    c = (await session.execute(select(Commentator).where(Commentator.id == commentator_id))).scalar_one_or_none()
    if c is None:
        return None

    photo_path = (await session.execute(select(MediaAsset.path).where(MediaAsset.id == c.photo_asset_id))).scalar()
    audio_path = (await session.execute(select(MediaAsset.path).where(MediaAsset.id == c.audio_asset_id))).scalar()

    lo = now - timedelta(minutes=150)
    match_ids = (
        (
            await session.execute(
                select(Match.id)
                .where(
                    or_(
                        Match.commentator_id == commentator_id,
                        Match.id.in_(
                            select(MatchChannel.match_id).where(
                                or_(
                                    MatchChannel.commentator_id == commentator_id,
                                    MatchChannel.commentator2_id == commentator_id,
                                )
                            )
                        ),
                    ),
                    Match.kickoff_at.is_not(None),
                    Match.kickoff_at >= lo,
                )
                .order_by(Match.kickoff_at.asc(), Match.id.asc())
                .limit(20)
            )
        )
        .scalars()
        .all()
    )

    upcoming = await summaries_for_ids(session, now, list(match_ids))

    return s.CommentatorDetail(
        id=c.id,
        name=c.name,
        image=media_url(photo_path),
        audio=media_url(audio_path),
        upcoming=upcoming,
    )
