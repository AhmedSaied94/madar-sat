"""Raw pages and run records on VPS-2, and their 5-day retention (T063, R15)."""

from __future__ import annotations

import gzip
import json
from datetime import UTC, date, datetime, timedelta
from pathlib import Path

import pytest

from app.adapters.base import RawPage
from app.adapters.raw_store import RawStore

NOW = datetime(2026, 10, 31, 3, 0, tzinfo=UTC)


def _page(n: int, body: bytes | None = None) -> RawPage:
    return RawPage(
        url=f"https://www.ysscores.com/ar/match_date_to#day{n}",
        status=200,
        body=body if body is not None else f"<html>page {n}</html>".encode(),
        content_type="text/html",
        fetched_at=NOW,
    )


RUN_INFO = {
    "counts": {"items_found": 42, "items_upserted": 40, "http_errors": 0},
    "skipped": [{"ref": "5802974", "reason": "bad_time"}],
    "unresolved": [{"name": "فريق غامض", "competition": "دوري ما", "match_ref": "5802974"}],
}


@pytest.fixture
def store(tmp_path: Path) -> RawStore:
    return RawStore(root=tmp_path)


def test_pages_land_under_source_day_and_run(store: RawStore, tmp_path: Path) -> None:
    run_dir = store.save(
        source="ysscores",
        run_day=date(2026, 10, 31),
        run_id="2026-10-31T03:00:00Z-ysscores-7f3a",
        pages=[_page(1), _page(2)],
        run_info=RUN_INFO,
    )
    assert run_dir == tmp_path / "ysscores" / "2026-10-31" / "2026-10-31T03:00:00Z-ysscores-7f3a"
    assert gzip.decompress((run_dir / "1.html.gz").read_bytes()) == b"<html>page 1</html>"
    assert gzip.decompress((run_dir / "2.html.gz").read_bytes()) == b"<html>page 2</html>"


def test_run_json_records_counts_skips_and_unresolved_names(store: RawStore) -> None:
    run_dir = store.save(
        source="ysscores",
        run_day=date(2026, 10, 31),
        run_id="run-1",
        pages=[_page(1)],
        run_info=RUN_INFO,
    )
    written = json.loads((run_dir / "run.json").read_text(encoding="utf-8"))
    assert written == RUN_INFO
    assert written["counts"]["items_upserted"] == 40
    assert written["skipped"][0] == {"ref": "5802974", "reason": "bad_time"}
    assert written["unresolved"][0]["name"] == "فريق غامض"


def test_pruning_deletes_runs_older_than_five_days_and_keeps_newer_ones(store: RawStore, tmp_path: Path) -> None:
    old_day = (NOW - timedelta(days=6)).date()
    edge_day = (NOW - timedelta(days=5)).date()
    new_day = (NOW - timedelta(days=1)).date()
    for day, run in ((old_day, "old"), (edge_day, "edge"), (new_day, "new")):
        d = tmp_path / "ysscores" / day.isoformat() / run
        d.mkdir(parents=True)
        (d / "run.json").write_text("{}", encoding="utf-8")

    removed = store.prune_raw_pages(now=NOW)

    assert removed == 1
    assert not (tmp_path / "ysscores" / old_day.isoformat()).exists()
    assert (tmp_path / "ysscores" / edge_day.isoformat() / "edge").is_dir()
    assert (tmp_path / "ysscores" / new_day.isoformat() / "new").is_dir()


def test_pruning_covers_every_source_and_ignores_unexpected_names(store: RawStore, tmp_path: Path) -> None:
    old = (NOW - timedelta(days=9)).date().isoformat()
    (tmp_path / "legacy" / old / "run").mkdir(parents=True)
    (tmp_path / "ysscores" / "not-a-date" / "run").mkdir(parents=True)
    assert store.prune_raw_pages(now=NOW) == 1
    assert not (tmp_path / "legacy" / old).exists()
    assert (tmp_path / "ysscores" / "not-a-date" / "run").is_dir()


def test_saving_a_second_run_does_not_rewrite_the_first(store: RawStore, tmp_path: Path) -> None:
    first = store.save(
        source="ysscores", run_day=date(2026, 10, 31), run_id="run-1", pages=[_page(1)], run_info=RUN_INFO
    )
    second = store.save(
        source="ysscores", run_day=date(2026, 10, 31), run_id="run-2", pages=[_page(2)], run_info=RUN_INFO
    )
    assert first != second
    assert (first / "run.json").is_file()
    assert (second / "run.json").is_file()
    assert (tmp_path / "ysscores" / "2026-10-31" / "run-1" / "run.json").is_file()
