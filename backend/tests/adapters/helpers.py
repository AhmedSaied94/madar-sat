"""Row factories for Lane B2's sync-session tests (matches, teams, channels, the LST dictionary)."""

from __future__ import annotations

from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

from sqlalchemy import select

from app.db.models import Channel, DatasetVersion, ImportRun, LivesoccertvTeam, Match, Team

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures" / "livesoccertv"


def fixture_page(name: str, url: str) -> Any:
    """One saved LiveSoccerTV page, as the fetch task would hand it to ``parse``."""
    from app.adapters.base import RawPage

    return RawPage(url=url, status=200, body=(FIXTURES / name).read_bytes())


def team_page() -> Any:
    return fixture_page("team-al-ahly-egypt.html", "https://www.livesoccertv.com/teams/egypt/al-ahly/")


def match_page() -> Any:
    return fixture_page(
        "match-real-madrid-vs-valencia.html", "https://www.livesoccertv.com/matches/real-madrid-vs-valencia/1bpms"
    )


def empty_match_page() -> Any:
    return fixture_page(
        "match-al-ahly-vs-al-sekka-none.html", "https://www.livesoccertv.com/matches/al-ahly-vs-al-sekka/27z7272vt"
    )


def empty_team_page() -> Any:
    return fixture_page("team-egypt-a-empty.html", "https://www.livesoccertv.com/teams/egypt/egypt-a/")


def new_team(session: Any, name: str, country: str | None = None) -> Team:
    team = Team(name=name, country=country, sport="football")
    session.add(team)
    session.flush()
    return team


def new_match(
    session: Any,
    *,
    kickoff_at: datetime | None,
    home: str = "الأهلي",
    away: str = "الزمالك",
    home_team_id: int | None = None,
    away_team_id: int | None = None,
    status: str = "scheduled",
    time_tbd: bool = False,
    sport: str = "football",
) -> Match:
    # ck_matches_time_tbd: no kickoff means the time is TBD, and the other way round.
    kickoff_at = None if time_tbd else kickoff_at
    match = Match(
        sport=sport,
        source="ysscores",
        match_date=(kickoff_at.date() if kickoff_at else date(2026, 11, 7)),
        kickoff_at=kickoff_at,
        competition_name="الدوري المصري الممتاز",
        home_team_id=home_team_id,
        home_team_name=home,
        away_team_id=away_team_id,
        away_team_name=away,
        status=status,
        # ck_matches_clock_no_score: a clock-sourced row can only be `scheduled`.
        status_source="clock" if status == "scheduled" else "manual",
        time_tbd=time_tbd,
    )
    session.add(match)
    session.flush()
    return match


def new_lst_team(
    session: Any,
    *,
    ar_name: str,
    slug: str,
    country: str | None = "egypt",
    team_id: int | None = None,
) -> LivesoccertvTeam:
    row = LivesoccertvTeam(
        ar_name=ar_name, en_name=slug.replace("-", " ").title(), country=country, slug=slug, team_id=team_id
    )
    session.add(row)
    session.flush()
    return row


def new_channel(
    session: Any,
    name: str,
    *,
    kind: str = "platform",
    country: str | None = None,
    display_name: str | None = None,
    deleted: bool = False,
) -> Channel:
    channel = Channel(kind=kind, name=name, country=country, display_name=display_name)
    if deleted:
        channel.deleted_at = datetime(2026, 10, 1, tzinfo=UTC)
    session.add(channel)
    session.flush()
    return channel


def dataset_versions(session: Any) -> dict[str, int]:
    return dict(session.execute(select(DatasetVersion.name, DatasetVersion.version)).all())


def last_run(session: Any, source: str = "livesoccertv") -> ImportRun:
    run = (
        session.execute(select(ImportRun).where(ImportRun.source == source).order_by(ImportRun.id.desc()))
        .scalars()
        .first()
    )
    assert run is not None
    return run
