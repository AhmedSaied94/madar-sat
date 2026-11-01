"""``ScrapeResult`` version 2 beside version 1 (T056, contracts/pipelines-and-ops.md)."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

from app.adapters.base import ParsedFixture, RawPage
from app.adapters.messages import (
    CURRENT_SCHEMA,
    MAX_BROADCAST_PAGES,
    MAX_PAGES,
    BroadcastChannel,
    BroadcastItem,
    MessageTooLarge,
    ScrapeResult,
    UnmatchedMatch,
    UnsupportedSchema,
)
from tests.adapters.helpers import match_page

NOW = datetime(2026, 11, 7, 16, 0, tzinfo=UTC)


def _broadcasts(**overrides) -> ScrapeResult:
    values = {
        "source": "livesoccertv",
        "run_id": "r-1",
        "started_at": NOW,
        "finished_at": NOW,
        "fetched_on": "home-box",
        "pages": [match_page()],
        "kind": "broadcasts",
        "targets": 1,
    }
    return ScrapeResult.build(**{**values, **overrides})


def test_a_broadcasts_message_round_trips() -> None:
    item = BroadcastItem(
        match_id=48213,
        match_url="https://www.livesoccertv.com/matches/x/1",
        channels=[BroadcastChannel(name="beIN Sports HD 1", country="Algeria")],
    )
    result = _broadcasts(items=[item], unmatched=[UnmatchedMatch(match_id=48300, why="match_not_found")])

    wire = result.as_task_arg()
    assert wire["schema"] == 2 and wire["kind"] == "broadcasts"
    assert wire["targets"] == 1
    assert wire["items"][0]["match_id"] == 48213
    assert wire["unmatched"] == [{"match_id": 48300, "why": "match_not_found"}]

    again = ScrapeResult.model_validate(wire)
    assert isinstance(again.items[0], BroadcastItem)
    assert again.items[0].channels[0].country == "Algeria"
    assert again.raw_pages()[0].body == match_page().body


def test_a_version_1_fixture_message_still_validates() -> None:
    fixture = ParsedFixture(
        external_id="9000001",
        competition="الدوري المصري الممتاز",
        home="الأهلي",
        away="الزمالك",
        wall_time="10:00 م",
        match_date=datetime(2026, 10, 31, tzinfo=UTC).date(),
    )
    wire = {
        "schema": 1,
        "source": "ysscores",
        "run_id": "r-old",
        "started_at": NOW.isoformat(),
        "finished_at": NOW.isoformat(),
        "fetched_on": "home-box",
        "pages": [],
        "items": [fixture.model_dump(mode="json")],
        "http_errors": 0,
        "error": None,
    }

    result = ScrapeResult.model_validate(wire)

    assert result.schema == 1
    assert result.kind == "fixtures"  # the default, so a v1 message needs no new field
    assert isinstance(result.items[0], ParsedFixture)
    assert result.items[0].home == "الأهلي"


def test_an_unknown_version_is_rejected_loudly() -> None:
    with pytest.raises(UnsupportedSchema):
        ScrapeResult.model_validate(
            {
                "schema": 3,
                "source": "livesoccertv",
                "run_id": "r",
                "started_at": NOW.isoformat(),
                "finished_at": NOW.isoformat(),
                "fetched_on": "home-box",
            }
        )


def test_the_current_schema_is_two_and_one_is_still_accepted() -> None:
    assert CURRENT_SCHEMA == 2
    assert ScrapeResult.accepted_schemas() == frozenset({1, 2})


def test_items_must_match_the_kind() -> None:
    fixture = ParsedFixture(home="أ", away="ب", wall_time="10:00", match_date=NOW.date())
    with pytest.raises(ValidationError):
        _broadcasts(items=[fixture])

    with pytest.raises(ValidationError):
        ScrapeResult.build(
            source="ysscores",
            run_id="r",
            started_at=NOW,
            finished_at=NOW,
            fetched_on="home-box",
            pages=[],
            items=[BroadcastItem(match_id=1, match_url="https://x/1", channels=[])],
        )


def test_a_window_still_carries_at_most_four_pages() -> None:
    page = RawPage(url="https://www.ysscores.com/x#2026-11-07", status=200, body=b"<html></html>")
    with pytest.raises(MessageTooLarge):
        ScrapeResult.build(
            source="ysscores",
            run_id="r",
            started_at=NOW,
            finished_at=NOW,
            fetched_on="home-box",
            pages=[page] * (MAX_PAGES + 1),
        )


def test_a_broadcast_run_carries_up_to_its_own_cap() -> None:
    page = RawPage(url="https://www.livesoccertv.com/match/x/1", status=200, body=b"<html></html>")
    result = ScrapeResult.build(
        source="livesoccertv",
        run_id="r",
        started_at=NOW,
        finished_at=NOW,
        fetched_on="home-box",
        pages=[page] * MAX_BROADCAST_PAGES,
        kind="broadcasts",
        targets=12,
    )
    assert len(result.raw_pages()) == MAX_BROADCAST_PAGES
    with pytest.raises(MessageTooLarge):
        ScrapeResult.build(
            source="livesoccertv",
            run_id="r",
            started_at=NOW,
            finished_at=NOW,
            fetched_on="home-box",
            pages=[page] * (MAX_BROADCAST_PAGES + 1),
            kind="broadcasts",
            targets=13,
        )


def test_targets_and_unmatched_belong_to_broadcasts_only() -> None:
    with pytest.raises(ValidationError):
        ScrapeResult(
            schema=2,
            source="ysscores",
            run_id="r",
            started_at=NOW,
            finished_at=NOW,
            fetched_on="home-box",
            targets=3,
        )
