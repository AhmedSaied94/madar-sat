"""Rows and readings the live tests share."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import DatasetVersion, Match
from app.domain.time import CAIRO
from app.live.types import Event, Lineups, Score, SourceReading


def make_match(session: Session, kickoff_at: datetime, **values) -> Match:
    defaults = {
        "source": "ysscores",
        "match_date": kickoff_at.astimezone(CAIRO).date(),
        "competition_name": "دوري",
        "home_team_name": "الأهلي",
        "away_team_name": "الزمالك",
        "kickoff_at": kickoff_at,
        "locked_fields": [],
    }
    match = Match(**{**defaults, **values})
    session.add(match)
    session.flush()
    return match


def make_reading(
    source: str = "filgoal",
    score: Score | None = None,
    *,
    external_id: str = "1",
    status: str | None = "live",
    period: str | None = "1H",
    minute: str | None = "23",
    events: tuple[Event, ...] | None = None,
    lineups: Lineups | None = None,
    home: str = "الأهلي",
    away: str = "الزمالك",
    kickoff_at: datetime | None = None,
    competition: str | None = None,
    page_path: str | None = None,
    label: str | None = "الشوط الاول",
) -> SourceReading:
    return SourceReading(
        source=source,
        external_id=external_id,
        home=home,
        away=away,
        competition=competition,
        kickoff_at=kickoff_at,
        status=status,
        period=period,
        minute=minute,
        score=score,
        events=events,
        lineups=lineups,
        status_label=label,
        page_path=page_path,
    )


def version(session: Session, name: str) -> int:
    session.flush()
    return session.scalar(select(DatasetVersion.version).where(DatasetVersion.name == name)) or 0
