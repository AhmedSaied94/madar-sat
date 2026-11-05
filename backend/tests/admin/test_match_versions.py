"""The poller's minute writes don't invalidate an open editor's copy (T008, research R14)."""

from __future__ import annotations

from datetime import UTC, date, datetime

import pytest

from app.db.models import Match
from app.services.admin import versions


def _match(**fields) -> Match:
    defaults = {
        "id": 7,
        "source": "legacy",
        "match_date": date(2026, 10, 28),
        "competition_name": "كأس",
        "home_team_name": "أ",
        "away_team_name": "ب",
        "status": "live",
        "status_source": "feed",
        "period": "1H",
        "minute": "10",
        "home_score": 0,
        "away_score": 0,
        "locked_fields": [],
    }
    return Match(**{**defaults, **fields})


def _etag(match: Match) -> str:
    return versions.etag_of(versions.match_state(match, [], []))


@pytest.mark.parametrize(
    "field, value",
    [("minute", "11"), ("period", "2H"), ("status_updated_at", datetime(2026, 10, 29, tzinfo=UTC))],
)
def test_clock_fields_leave_the_etag_unchanged(field, value):
    assert _etag(_match()) == _etag(_match(**{field: value}))


@pytest.mark.parametrize("field, value", [("home_score", 1), ("away_score", 1), ("status", "halftime")])
def test_score_and_status_change_the_etag(field, value):
    assert _etag(_match()) != _etag(_match(**{field: value}))


def test_the_audit_diff_still_sees_the_minute():
    assert "minute" in versions.row_state(_match())
