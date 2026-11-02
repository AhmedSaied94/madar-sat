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


def test_the_current_message_round_trips_on_both_ends() -> None:
    assert CURRENT_SCHEMA == 2
    built = _result()
    assert built.schema == 2
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
    # D3 made V2 current: the current schema and the one before it are accepted (contracts §ScrapeResult).
    assert ScrapeResult.accepted_schemas() == frozenset({1, 2})
    assert ScrapeResult.accepted_schemas(current=3) == frozenset({2, 3})
    assert ScrapeResult.accepted_schemas(current=1) == frozenset({1})


@pytest.mark.parametrize("schema", [0, 3, 99])
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


def test_a_gzip_bomb_is_refused_before_it_is_decompressed() -> None:
    """B2-R1-13: 1.5 MB of gzip can inflate to gigabytes; the inflate is capped at the page size."""
    from app.adapters.base import RawPage
    from app.adapters.messages import MAX_PAGE_BYTES, MessageTooLarge, ScrapeResult

    bomb = b"a" * (MAX_PAGE_BYTES + 1024)  # compresses to a few kilobytes
    result = ScrapeResult.build(
        source="ysscores",
        run_id="r-bomb",
        started_at=datetime(2026, 10, 31, 3, 0, tzinfo=UTC),
        finished_at=datetime(2026, 10, 31, 3, 1, tzinfo=UTC),
        fetched_on="home-box",
        pages=[
            RawPage(
                url="https://www.ysscores.com/ar/match_date_to#2026-10-30",
                status=200,
                body=bomb,
            )
        ],
    )
    assert len(result.pages[0].gz_b64) < 2 * 1024 * 1024  # the message itself fits

    with pytest.raises(MessageTooLarge):
        result.raw_pages()


def test_many_small_pages_are_refused_before_the_run_inflates_them() -> None:
    """250 pages of 5 MB zeros fit under 2 MB compressed and inflate to gigabytes (B2-R2-16)."""
    from app.adapters.messages import MAX_PAGES

    pages = [_page(b"\0" * (5 * 1024 * 1024)) for _ in range(250)]
    with pytest.raises(MessageTooLarge):
        _result(pages)
    assert MAX_PAGES == 4


def test_a_run_over_the_total_inflate_budget_is_refused() -> None:
    """Each page is under its own cap; four of them are over the run's budget (B2-R2-16)."""
    from app.adapters.messages import MAX_PAGE_BYTES, MAX_TOTAL_BYTES

    pages = [_page(b"\0" * MAX_PAGE_BYTES) for _ in range(4)]
    result = _result(pages)  # the compressed message fits the 2 MB cap
    assert len(result.pages) == 4
    assert 4 * MAX_PAGE_BYTES > MAX_TOTAL_BYTES

    with pytest.raises(MessageTooLarge):
        result.raw_pages()


def test_the_inflate_stops_at_the_page_cap_instead_of_allocating_the_bomb() -> None:
    """Kills the `decompressobj(max_length)` → `gzip.decompress` swap: the peak stays at the cap."""
    import tracemalloc

    from app.adapters.messages import MAX_PAGE_BYTES

    bomb = b"\0" * (64 * 1024 * 1024)  # compresses to well under the 2 MB message cap
    result = _result([_page(bomb)])
    assert len(result.pages[0].gz_b64) < 2 * 1024 * 1024

    tracemalloc.start()
    try:
        with pytest.raises(MessageTooLarge):
            result.raw_pages()
        peak = tracemalloc.get_traced_memory()[1]
    finally:
        tracemalloc.stop()

    assert peak < 32 * 1024 * 1024, f"inflating allocated {peak} bytes; the cap is {MAX_PAGE_BYTES}"


def test_an_oversize_wire_payload_is_refused_before_pydantic_parses_it() -> None:
    """`ingest` validates a dict: a 3 MB value is refused for its size, not as a field error (B2-R2-16)."""
    payload = _result().as_task_arg()
    payload["items"] = "x" * (3 * 1024 * 1024)  # not a list: a ValidationError once it is parsed

    with pytest.raises(MessageTooLarge):  # not a ValidationError: the size is checked first
        ScrapeResult.model_validate(payload)
