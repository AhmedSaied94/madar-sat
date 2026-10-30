"""The versioned scrape→ingest message (T062, contracts/ingestion.md)."""

from __future__ import annotations

import base64
import gzip
import os
from datetime import UTC, date, datetime

import pytest
from pydantic import ValidationError

from app.adapters.base import ParsedFixture, RawPage
from app.adapters.messages import (
    CURRENT_SCHEMA,
    MAX_BYTES,
    MessageTooLarge,
    ScrapeResult,
    UnsupportedSchema,
)

NOW = datetime(2026, 10, 31, 3, 0, tzinfo=UTC)


def _fixture() -> ParsedFixture:
    return ParsedFixture(
        external_id="5802974",
        url="https://www.ysscores.com/ar/match/5802974/x",
        competition="الدوري الفرنسي",
        competition_logo="https://imgs.ysscores.com/championship/48/c.png",
        stage="الجولة 9",
        home="ليل",
        away="لانس",
        home_logo="https://imgs.ysscores.com/teams/64/a.png",
        away_logo=None,
        home_external_id="8639",
        away_external_id="8588",
        wall_time="10:05 م",
        match_date=date(2026, 10, 30),
    )


def _page(body: bytes = b"<html>ok</html>") -> RawPage:
    return RawPage(
        url="https://www.ysscores.com/ar/match_date_to#2026-10-30",
        status=200,
        body=body,
        content_type="text/html",
        fetched_at=NOW,
    )


def _result(pages: list[RawPage] | None = None) -> ScrapeResult:
    return ScrapeResult.build(
        source="ysscores",
        run_id="2026-10-31T03:00:00Z-ysscores-7f3a",
        started_at=NOW,
        finished_at=NOW,
        fetched_on="home-box",
        pages=pages if pages is not None else [_page()],
        items=[_fixture()],
    )


def test_a_schema_1_message_round_trips_on_both_ends() -> None:
    assert CURRENT_SCHEMA == 1
    built = _result()
    assert built.schema == 1
    payload = built.model_dump_json()
    again = ScrapeResult.model_validate_json(payload)
    assert again == built
    assert again.source == "ysscores"
    assert again.fetched_on == "home-box"
    assert again.items == [_fixture()]


def test_the_pages_travel_gzipped_and_come_back_as_bytes() -> None:
    built = _result()
    encoded = built.pages[0].gz_b64
    assert gzip.decompress(base64.b64decode(encoded)) == b"<html>ok</html>"
    restored = built.raw_pages()
    assert restored[0].body == b"<html>ok</html>"
    assert restored[0].url == "https://www.ysscores.com/ar/match_date_to#2026-10-30"
    assert restored[0].status == 200
    assert restored[0].fetched_at == NOW


def test_the_previous_schema_is_accepted_once_a_second_one_exists() -> None:
    assert ScrapeResult.accepted_schemas() == frozenset({1})
    # Simulating the next contract step: the current and the one before it are accepted.
    assert ScrapeResult.accepted_schemas(current=2) == frozenset({1, 2})


@pytest.mark.parametrize("schema", [0, 2, 99])
def test_any_other_schema_is_rejected_loudly(schema: int) -> None:
    payload = _result().model_dump()
    payload["schema"] = schema
    with pytest.raises((UnsupportedSchema, ValidationError)):
        ScrapeResult.model_validate(payload)


def test_a_message_over_two_megabytes_is_refused_at_build_time() -> None:
    assert MAX_BYTES == 2 * 1024 * 1024
    pages = [_page(os.urandom(3 * 1024 * 1024))]  # incompressible, so the cap bites
    with pytest.raises(MessageTooLarge):
        _result(pages)


def test_a_failed_fetch_still_builds_a_result() -> None:
    failed = ScrapeResult.failed(
        source="ysscores",
        run_id="2026-10-31T03:00:00Z-ysscores-7f3a",
        started_at=NOW,
        finished_at=NOW,
        fetched_on="home-box",
        http_errors=3,
        error="layout_changed",
    )
    assert failed.pages == []
    assert failed.items == []
    assert failed.http_errors == 3
    assert failed.error == "layout_changed"
    assert len(failed.error) <= 120
