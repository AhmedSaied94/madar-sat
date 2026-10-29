"""``/v1/live`` window, statuses and index use (T042)."""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from sqlalchemy import text
from sqlalchemy.dialects import postgresql

from app.db.models import Match
from app.services.live import live_window_query


def _match(label: str, kickoff, **fields) -> Match:
    return Match(
        source="legacy",
        match_date=date(2026, 10, 28),
        kickoff_at=kickoff,
        competition_name="كأس الاختبار",
        home_team_name=f"{label} home",
        away_team_name=f"{label} away",
        locked_fields=[],
        **fields,
    )


@pytest.mark.asyncio
async def test_window_is_closed_at_both_ends_and_skips_settled_feed_rows(session, public_client, frozen_now):
    rows = {
        "lower-edge": _match("lower-edge", frozen_now - timedelta(minutes=150)),
        "upper-edge": _match("upper-edge", frozen_now + timedelta(minutes=10)),
        "too-early": _match("too-early", frozen_now - timedelta(minutes=150, seconds=1)),
        "too-late": _match("too-late", frozen_now + timedelta(minutes=10, seconds=1)),
        "feed-live": _match(
            "feed-live",
            frozen_now - timedelta(minutes=30),
            status="live",
            status_source="feed",
            period="1H",
            minute="30",
            home_score=1,
            away_score=0,
        ),
        "feed-finished": _match(
            "feed-finished",
            frozen_now - timedelta(minutes=100),
            status="finished",
            status_source="feed",
            home_score=2,
            away_score=2,
        ),
    }
    session.add_all(rows.values())
    await session.commit()

    resp = await public_client.get("/v1/live")
    assert resp.status_code == 200
    by_id = {item["match_id"]: item for item in resp.json()["data"]}

    assert rows["lower-edge"].id in by_id
    assert rows["upper-edge"].id in by_id
    assert rows["too-early"].id not in by_id
    assert rows["too-late"].id not in by_id
    assert rows["feed-finished"].id not in by_id

    live = by_id[rows["feed-live"].id]
    assert (live["status"], live["estimated"], live["minute"]) == ("live", False, "30")
    assert live["score"]["home"] == 1

    upcoming = by_id[rows["upper-edge"].id]
    assert (upcoming["status"], upcoming["estimated"], upcoming["score"]) == ("scheduled", False, None)


@pytest.mark.asyncio
async def test_query_uses_the_live_window_index(session, frozen_now):
    stmt = live_window_query(frozen_now).compile(dialect=postgresql.dialect(), compile_kwargs={"literal_binds": True})
    await session.execute(text("SET LOCAL enable_seqscan = off"))
    plan = "\n".join((await session.execute(text(f"EXPLAIN {stmt}"))).scalars())  # noqa: S608 - compiled locally
    assert "matches_live_window_idx" in plan, plan
