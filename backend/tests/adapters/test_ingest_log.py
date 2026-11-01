"""The compact run log in ``import_runs.log`` (T060, R12, R18)."""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path

import pytest

from app.adapters.health import column_available
from app.adapters.messages import BroadcastItem, ScrapeResult
from app.adapters.tasks import MAX_LOG_BYTES, MAX_LOG_ITEMS, _compact_log, _fit, ingest
from tests.adapters.helpers import last_run, match_page, new_match

NOW = datetime(2026, 11, 7, 16, 0, tzinfo=UTC)


def _result(**overrides) -> ScrapeResult:
    values = {
        "source": "livesoccertv",
        "run_id": "2026-11-07T16:00:00Z-livesoccertv-abcd",
        "started_at": NOW,
        "finished_at": NOW,
        "fetched_on": "home-box",
        "pages": [match_page()],
        "kind": "broadcasts",
        "targets": 1,
    }
    return ScrapeResult.build(**{**values, **overrides})


class _Links:
    def __init__(self, skipped: list[dict[str, str]] | None = None) -> None:
        self.added = [1, 2]
        self.removed = [3]
        self.placeholders_created = ["Al Kass One"]
        self.skipped = skipped or []


def test_the_log_keeps_counts_and_a_bounded_list() -> None:
    skipped = [{"name": f"Channel {index}", "country": "egypt", "why": "country_not_listed"} for index in range(200)]
    payload = _compact_log(_result(), None, _Links(skipped), None, {"planned": 3, "mapped": 2})

    assert payload["kind"] == "broadcasts"
    assert payload["counts"]["links_added"] == 2
    assert payload["counts"]["targets"] == 1
    assert payload["placeholders_created"] == ["Al Kass One"]
    assert payload["skipped"]["count"] == 200
    assert len(payload["skipped"]["items"]) == MAX_LOG_ITEMS
    assert payload["plan"] == {"planned": 3, "mapped": 2}


def test_a_log_over_sixty_four_kilobytes_is_shrunk_not_dropped() -> None:
    huge = [{"name": "x" * 400, "why": "country_not_listed"} for _ in range(5000)]
    payload = _fit({"skipped": {"count": len(huge), "items": huge}, "counts": {"items_found": 1}})

    encoded = json.dumps(payload, ensure_ascii=False, default=str).encode("utf-8")
    assert len(encoded) <= MAX_LOG_BYTES
    assert payload["counts"] == {"items_found": 1}
    assert payload["skipped"]["count"] == 5000
    assert payload["skipped"]["truncated"] is True


@pytest.fixture
def prepared(sync_session, monkeypatch: pytest.MonkeyPatch, tmp_path: Path):
    """Point ingest at the test transaction and a scratch raw root (as ``test_tasks`` does)."""
    from sqlalchemy.orm import Session

    import app.db.session as db_session
    from app.adapters.config import get_adapter_settings

    monkeypatch.setenv("RAW_ROOT", str(tmp_path))
    get_adapter_settings.cache_clear()

    def factory() -> Session:
        return Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint")

    monkeypatch.setattr(db_session, "SyncSession", factory)
    return tmp_path


def test_a_failed_fetch_still_counts_toward_the_breaker(
    sync_session, prepared, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A failed run is what opens the breaker, so health must see it (R17)."""
    calls: list[dict] = []
    from app.adapters import health

    def record(session, **kwargs):  # noqa: ANN001 - the seam
        calls.append(kwargs)
        return health.HealthOutcome()

    monkeypatch.setattr("app.adapters.health.record_run", record)
    failed = ScrapeResult.failed(
        source="livesoccertv",
        run_id="r-failed",
        started_at=NOW,
        finished_at=NOW,
        fetched_on="home-box",
        http_errors=2,
        error="layout_changed",
    )

    assert ingest.apply(args=(failed.as_task_arg(),)).get()["status"] == "failed"
    assert calls and calls[0]["status"] == "failed"
    assert calls[0]["source"] == "livesoccertv"


def test_a_broadcast_run_writes_its_log_beside_run_json(sync_session, prepared) -> None:
    if not column_available(sync_session, "import_runs", "log"):
        pytest.skip("0005's import_runs.log is not applied yet (B1 T008; rebase at T068)")
    match = new_match(sync_session, kickoff_at=NOW)
    result = _result(items=[BroadcastItem(match_id=match.id, match_url="https://x/1", channels=[])])

    summary = ingest.apply(args=(result.as_task_arg(),)).get()
    sync_session.expire_all()
    run = last_run(sync_session)

    assert summary["kind"] == "broadcasts"
    logged = json.loads(
        sync_session.execute(
            __import__("sqlalchemy").text("SELECT log FROM import_runs WHERE id = :id"), {"id": run.id}
        ).scalar_one()
    )
    assert logged["kind"] == "broadcasts"
    assert logged["counts"]["targets"] == 1
    assert logged["health"]["breaker_opened"] is False
    assert "plan" in logged

    run_json = json.loads((Path(run.raw_path) / "run.json").read_text(encoding="utf-8"))
    assert run_json["counts"]["items_found"] == 1
    assert run_json["unmatched"] == []
