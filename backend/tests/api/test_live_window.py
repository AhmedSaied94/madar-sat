"""``/v1/live`` keeps a long ``feed`` match up to kickoff + 210 min (T004, research R6)."""

from __future__ import annotations

from datetime import date, timedelta

from app.db.models import Match


def _match(label: str, kickoff, **fields) -> Match:
    return Match(
        source="legacy",
        match_date=date(2026, 10, 28),
        kickoff_at=kickoff,
        competition_name="كأس",
        home_team_name=f"{label} أ",
        away_team_name=f"{label} ب",
        locked_fields=[],
        **fields,
    )


FEED = {
    "status": "extra_time",
    "status_source": "feed",
    "period": "ET1",
    "minute": "105",
    "home_score": 1,
    "away_score": 1,
}


async def test_the_window_depends_on_the_status_source(public_client, session, frozen_now):
    rows = {
        "feed-170": _match("feed-170", frozen_now - timedelta(minutes=170), **FEED),
        "feed-210": _match("feed-210", frozen_now - timedelta(minutes=210), **FEED),
        "feed-211": _match("feed-211", frozen_now - timedelta(minutes=211), **FEED),
        "clock-150": _match("clock-150", frozen_now - timedelta(minutes=150)),
        "clock-151": _match("clock-151", frozen_now - timedelta(minutes=151)),
        "manual-170": _match("manual-170", frozen_now - timedelta(minutes=170), status="live", status_source="manual"),
        "feed-done": _match(
            "feed-done",
            frozen_now - timedelta(minutes=170),
            status="finished",
            status_source="feed",
            home_score=1,
            away_score=1,
        ),
    }
    session.add_all(rows.values())
    await session.flush()

    data = (await public_client.get("/v1/live")).json()["data"]

    found = {row["match_id"] for row in data}
    ids = {label: row.id for label, row in rows.items()}
    assert {ids["feed-170"], ids["feed-210"], ids["clock-150"]} <= found
    assert not {ids["feed-211"], ids["clock-151"], ids["manual-170"], ids["feed-done"]} & found
    served = next(row for row in data if row["match_id"] == ids["feed-170"])
    assert (served["estimated"], served["minute"], served["score"]["home"]) == (False, "105", 1)
