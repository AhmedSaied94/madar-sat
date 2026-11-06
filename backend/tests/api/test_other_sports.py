"""FR-022 and SC-010: one sport, football, everywhere the app reads (T004, research R12)."""

from __future__ import annotations

from datetime import date, datetime, timedelta

from app.db.models import Match
from app.services.live import poll_window_query


def _match(label: str, kickoff: datetime, *, sport: str = "football", **fields) -> Match:
    return Match(
        source="legacy",
        sport=sport,
        match_date=date(2026, 11, 6),
        kickoff_at=kickoff,
        competition_name="دوري",
        home_team_name=f"{label} أ",
        away_team_name=f"{label} ب",
        locked_fields=[],
        **fields,
    )


async def _window(client, frozen_now) -> dict[str, dict]:
    response = await client.get(
        "/v1/matches",
        params={"from": frozen_now.isoformat(), "to": (frozen_now + timedelta(hours=3)).isoformat()},
    )
    assert response.status_code == 200, response.text
    return {row["home"]["name"]: row for row in response.json()["data"]}


async def test_matches_without_a_sport_returns_football_only(public_client, session, frozen_now):
    session.add_all(
        [
            _match("كرة", frozen_now + timedelta(hours=1)),
            _match("سلة", frozen_now + timedelta(hours=1), sport="basketball"),
        ]
    )
    await session.flush()

    rows = await _window(public_client, frozen_now)
    assert "كرة أ" in rows
    assert "سلة أ" not in rows


async def test_matches_with_a_sport_returns_that_sport(public_client, session, frozen_now):
    session.add_all(
        [
            _match("كرة", frozen_now + timedelta(hours=1)),
            _match("سلة", frozen_now + timedelta(hours=1), sport="basketball"),
        ]
    )
    await session.flush()

    response = await public_client.get(
        "/v1/matches",
        params={
            "from": frozen_now.isoformat(),
            "to": (frozen_now + timedelta(hours=3)).isoformat(),
            "sport": "basketball",
        },
    )
    assert response.status_code == 200, response.text
    names = {row["home"]["name"] for row in response.json()["data"]}
    assert names == {"سلة أ"}


async def test_live_returns_football_only(public_client, session, frozen_now):
    live = {"status": "live", "status_source": "feed", "period": "1H", "minute": "20", "home_score": 1, "away_score": 0}
    football = _match("كرة", frozen_now - timedelta(minutes=20), **live)
    basketball = _match("سلة", frozen_now - timedelta(minutes=20), sport="basketball", **live)
    session.add_all([football, basketball])
    await session.flush()

    body = (await public_client.get("/v1/live")).json()["data"]
    labels = {row["match_id"] for row in body}
    assert football.id in labels
    assert basketball.id not in labels


async def test_the_poller_and_the_watchdog_never_see_another_sport(session, frozen_now):
    session.add_all(
        [
            _match("كرة", frozen_now - timedelta(minutes=20), status="live", status_source="feed"),
            _match(
                "سلة",
                frozen_now - timedelta(minutes=20),
                sport="basketball",
                status="live",
                status_source="feed",
            ),
        ]
    )
    await session.flush()

    picked = list((await session.execute(poll_window_query(frozen_now))).scalars())
    assert [row.home_team_name for row in picked] == ["كرة أ"]
