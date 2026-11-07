"""A13: source health, pause, resume, run and run history (T025)."""

from __future__ import annotations

from datetime import timedelta

from sqlalchemy import select

from app.db.models import AuditLog, DatasetVersion, ImportRun
from app.services.admin import writer


async def _health(client, name: str = "ysscores") -> dict:
    response = await client.get("/admin/api/sources")
    assert response.status_code == 200, response.text
    return next(source for source in response.json()["data"] if source["name"] == name)


def _run(session, now, *, status: str = "succeeded", minutes_ago: int = 60, items: int = 10) -> ImportRun:
    started = now - timedelta(minutes=minutes_ago)
    run = ImportRun(
        source="ysscores",
        started_at=started,
        finished_at=started + timedelta(minutes=2),
        items_found=items,
        items_upserted=items // 2,
        http_errors=0,
        status=status,
    )
    session.add(run)
    return run


async def test_the_health_fields_come_from_the_last_24_hours(editor_client, session, frozen_now):
    _run(session, frozen_now, status="succeeded", minutes_ago=120, items=41)
    _run(session, frozen_now, status="failed", minutes_ago=60, items=0)
    await session.flush()

    health = await _health(editor_client)

    assert health["breaker"] == "closed"
    assert health["consecutive_failures"] == 0
    assert health["paused"] is False
    assert health["running"] is False
    assert health["items_24h"] == [41, 0]
    assert health["error_rate_24h"] == 0.5
    assert health["last_run"]["status"] == "failed"


async def test_pause_audits_and_bumps_the_sources_dataset(editor_client, session, frozen_now):
    before = (await editor_client.get("/admin/api/sources")).headers["etag"]

    paused = await editor_client.post("/admin/api/sources/ysscores/pause")

    assert paused.status_code == 200, paused.text
    assert paused.json()["data"]["is_enabled"] is False
    assert paused.json()["data"]["paused"] is True
    after = (await editor_client.get("/admin/api/sources")).headers["etag"]
    assert after != before
    audit = await session.scalar(select(AuditLog).where(AuditLog.entity == "source").order_by(AuditLog.id.desc()))
    assert audit is not None and audit.diff["is_enabled"] == [True, False]


async def test_resume_resets_the_breaker_and_queues_one_manual_run(editor_client, session, frozen_now, monkeypatch):
    from app.db.models import Source

    source = await session.get(Source, "ysscores")
    assert source is not None
    source.is_enabled = False
    source.consecutive_failures = 3
    source.breaker_opened_at = frozen_now
    await session.flush()
    queued: list[str] = []
    monkeypatch.setattr("app.api.admin.sources.send_manual_run", queued.append)

    response = await editor_client.post("/admin/api/sources/ysscores/resume")

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert (data["is_enabled"], data["breaker"], data["consecutive_failures"]) == (True, "closed", 0)
    await session.refresh(source)
    assert (source.breaker_opened_at, source.paused_until, source.consecutive_failures) == (None, None, 0)
    assert queued == ["ysscores"]


async def test_a_finished_run_changes_the_etag(editor_client, session, frozen_now):
    before = (await editor_client.get("/admin/api/sources")).headers["etag"]
    await writer.bump_datasets(session, ("sources",))  # what B2's health.record_run does

    after = (await editor_client.get("/admin/api/sources")).headers["etag"]

    assert after != before


async def test_run_now_sends_the_task_by_name(editor_client, monkeypatch):
    sent: list[tuple] = []

    def record(name, args=None, kwargs=None, queue=None):
        sent.append((name, args, kwargs, queue))

    monkeypatch.setattr("app.workers.app.send_task", record)

    response = await editor_client.post("/admin/api/sources/ysscores/run")

    assert response.status_code == 202, response.text
    assert response.json()["data"] == {"queued": True}
    assert sent == [("adapters.schedule_fetch", ["ysscores"], {"manual": True}, "imports")]


async def test_a_held_lock_is_run_in_progress(editor_client, redis_client):
    await redis_client.set("lock:fetch:ysscores", "1", ex=60)
    try:
        response = await editor_client.post("/admin/api/sources/ysscores/run")
    finally:
        await redis_client.delete("lock:fetch:ysscores")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "run_in_progress"


async def test_manual_is_not_runnable(editor_client):
    response = await editor_client.post("/admin/api/sources/manual/run")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "source_not_runnable"


async def test_an_unknown_source_is_404(editor_client):
    response = await editor_client.get("/admin/api/sources/nope/runs")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "source_not_found"


async def test_the_runs_list_is_newest_first_with_a_cursor(editor_client, session, frozen_now):
    ids = []
    for minutes in (180, 120, 60):
        run = _run(session, frozen_now, minutes_ago=minutes)
        await session.flush()
        ids.append(run.id)

    first = await editor_client.get("/admin/api/sources/ysscores/runs", params={"limit": 2})
    assert first.status_code == 200, first.text
    page = [row["id"] for row in first.json()["data"]]
    cursor = first.json()["meta"]["next_cursor"]
    assert page == list(reversed(ids))[:2]
    assert cursor

    second = await editor_client.get("/admin/api/sources/ysscores/runs", params={"limit": 2, "cursor": cursor})
    assert [row["id"] for row in second.json()["data"]] == [ids[0]]


async def test_the_run_detail_carries_the_log(editor_client, session, frozen_now):
    run = _run(session, frozen_now, minutes_ago=30)
    run.log = {"unmatched_matches": [{"match_id": 1, "why": "match_not_found"}], "skipped_channels": 7}
    run.raw_path = "ysscores/2026-11-01/run.json"
    await session.flush()

    response = await editor_client.get(f"/admin/api/import-runs/{run.id}")

    assert response.status_code == 200, response.text
    data = response.json()["data"]
    assert data["log"] == run.log
    assert data["log_available"] is True
    assert data["raw_path"] == run.raw_path

    missing = await editor_client.get("/admin/api/import-runs/99999999")
    assert missing.status_code == 404
    assert missing.json()["error"]["code"] == "import_run_not_found"


_ = DatasetVersion


async def test_a_stopped_run_serialises_with_its_reason(editor_client, session, frozen_now):
    """A run that stopped on purpose keeps its reason in ``error`` (research R22, admin-api)."""
    run = _run(session, frozen_now, minutes_ago=30)
    run.status = "stopped"
    run.error = "budget_reached"
    await session.flush()

    listed = await editor_client.get("/admin/api/sources/ysscores/runs")
    assert listed.status_code == 200, listed.text
    [row] = [item for item in listed.json()["data"] if item["id"] == run.id]
    assert row["status"] == "stopped"
    assert row["error"] == "budget_reached"

    detail = await editor_client.get(f"/admin/api/import-runs/{run.id}")
    assert detail.json()["data"]["status"] == "stopped"
