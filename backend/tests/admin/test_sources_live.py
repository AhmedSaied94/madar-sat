"""A13's Live poller card and the raw page route (T007, contracts/admin-api.md, research R13)."""

from __future__ import annotations

import json
from datetime import timedelta

import pytest

from app.db.models import ImportRun, LiveSourceState, Match


@pytest.fixture
def queued(monkeypatch):
    calls: list[tuple[int, int]] = []
    monkeypatch.setattr("app.services.admin.sources.send_read_raw_page", lambda run, page: calls.append((run, page)))
    return calls


async def _sources(client) -> dict[str, dict]:
    response = await client.get("/admin/api/sources")
    assert response.status_code == 200, response.text
    return {row["name"]: row for row in response.json()["data"]}


async def _clear(redis_client, run_id: int) -> None:
    async for key in redis_client.scan_iter(match=f"rawview:{run_id}:*"):
        await redis_client.delete(key)


async def _run(session, now, raw_path: str | None = "live_poller/2026-11-04/run.json", log=None) -> ImportRun:
    run = ImportRun(source="live_poller", started_at=now, status="succeeded", raw_path=raw_path, log=log)
    session.add(run)
    await session.flush()
    return run


@pytest.mark.parametrize("name", ["live_poller", "filgoal", "goal"])
async def test_the_live_sources_are_refused_a_manual_run_by_name(admin_client, name):
    response = await admin_client.post(f"/admin/api/sources/{name}/run")

    assert response.status_code == 409, response.text
    assert response.json()["error"]["code"] == "source_not_runnable"


async def test_only_the_live_poller_carries_the_live_block(editor_client, session):
    sources = await _sources(editor_client)

    assert sources["live_poller"]["live"] is not None
    assert sources["yallakora"]["live"] is None
    assert sources["yallakora"]["kind"] == "scraper"


async def test_the_live_card_is_listed_and_the_reader_is_hidden(editor_client, session, frozen_now):
    session.add_all(
        [
            LiveSourceState(source="filgoal", state="ok", consecutive_failures=0),
            LiveSourceState(source="yallakora", state="down", consecutive_failures=3),
            Match(
                source="legacy",
                match_date=frozen_now.date(),
                kickoff_at=frozen_now - timedelta(minutes=20),
                competition_name="كأس",
                home_team_name="أ",
                away_team_name="ب",
                status="live",
                status_source="feed",
                period="1H",
                minute="20",
                home_score=0,
                away_score=0,
                locked_fields=[],
            ),
            ImportRun(source="live_poller", started_at=frozen_now, status="succeeded"),
            ImportRun(source="live_poller", started_at=frozen_now, status="failed"),
        ]
    )
    await session.flush()

    sources = await _sources(editor_client)

    assert "filgoal" not in sources
    assert "goal" not in sources
    live = sources["live_poller"]["live"]
    assert live["matches_live"] == 1
    assert live["error_share"] == 0.5
    assert live["sources"] == [{"name": "filgoal", "state": "ok"}, {"name": "yallakora", "state": "down"}]
    assert sources["ysscores"]["live"] is None
    assert sources["yallakora"]["kind"] == "scraper"


@pytest.mark.parametrize("name", ["live_poller", "filgoal", "goal"])
async def test_a_live_source_cannot_be_run(editor_client, name):
    response = await editor_client.post(f"/admin/api/sources/{name}/run")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "source_not_runnable"


async def test_pausing_and_resuming_the_live_poller_queues_no_import(editor_client, monkeypatch):
    queued: list[str] = []
    monkeypatch.setattr("app.api.admin.sources.send_manual_run", queued.append)

    paused = await editor_client.post("/admin/api/sources/live_poller/pause")
    resumed = await editor_client.post("/admin/api/sources/live_poller/resume")

    assert paused.json()["data"]["paused"] is True
    assert resumed.json()["data"]["paused"] is False
    assert queued == []


async def test_raw_page_goes_from_pending_to_ready(editor_client, session, frozen_now, redis_client, queued):
    run = await _run(session, frozen_now)
    await _clear(redis_client, run.id)
    url = f"/admin/api/import-runs/{run.id}/raw"

    pending = await editor_client.get(url, params={"page": 0})

    assert pending.status_code == 200, pending.text
    assert pending.json()["data"]["state"] == "pending"
    assert pending.json()["data"]["text"] is None
    assert queued == [(run.id, 0)]

    await redis_client.set(
        f"rawview:{run.id}:0",
        json.dumps(
            {
                "pages": 3,
                "url": "https://www.filgoal.com/matches/",
                "content_type": "text/html",
                "text": "<html>…</html>",
                "truncated": False,
            }
        ),
    )
    stale = await editor_client.get(url, params={"page": 0}, headers={"If-None-Match": pending.headers["etag"]})

    assert stale.status_code == 200
    assert stale.headers["etag"] != pending.headers["etag"]
    assert stale.json()["data"] == {
        "state": "ready",
        "page": 0,
        "pages": 3,
        "url": "https://www.filgoal.com/matches/",
        "content_type": "text/html",
        "text": "<html>…</html>",
        "truncated": False,
    }

    again = await editor_client.get(url, params={"page": 0}, headers={"If-None-Match": stale.headers["etag"]})
    assert again.status_code == 304
    await _clear(redis_client, run.id)


async def test_a_repeated_poll_queues_the_read_once(editor_client, session, frozen_now, redis_client, queued):
    run = await _run(session, frozen_now)
    await _clear(redis_client, run.id)
    url = f"/admin/api/import-runs/{run.id}/raw"

    await editor_client.get(url)
    await editor_client.get(url)

    assert queued == [(run.id, 0)]
    await _clear(redis_client, run.id)


async def test_no_raw_path_is_gone_and_queues_nothing(editor_client, session, frozen_now, queued):
    run = await _run(session, frozen_now, raw_path=None)

    response = await editor_client.get(f"/admin/api/import-runs/{run.id}/raw")

    assert response.json()["data"]["state"] == "gone"
    assert queued == []


async def test_a_pruned_page_reported_by_the_worker_is_gone(editor_client, session, frozen_now, redis_client, queued):
    run = await _run(session, frozen_now)
    await _clear(redis_client, run.id)
    await redis_client.set(f"rawview:{run.id}:0", json.dumps({"gone": True}))

    response = await editor_client.get(f"/admin/api/import-runs/{run.id}/raw")

    assert response.json()["data"]["state"] == "gone"
    await _clear(redis_client, run.id)


async def test_the_path_never_comes_from_the_request(editor_client, session, frozen_now, redis_client, queued):
    run = await _run(session, frozen_now)
    await _clear(redis_client, run.id)

    response = await editor_client.get(
        f"/admin/api/import-runs/{run.id}/raw", params={"page": 0, "path": "/etc/passwd", "raw_path": "/etc/passwd"}
    )

    assert response.status_code == 200
    assert queued == [(run.id, 0)]  # only the run's id and page reach the worker
    await _clear(redis_client, run.id)


async def test_a_negative_page_or_an_unknown_run_is_refused(editor_client, session, frozen_now):
    run = await _run(session, frozen_now)

    assert (await editor_client.get(f"/admin/api/import-runs/{run.id}/raw", params={"page": -1})).status_code == 422
    assert (await editor_client.get("/admin/api/import-runs/999999999/raw")).status_code == 404


async def test_run_detail_has_pages_and_worker(editor_client, session, frozen_now):
    with_log = await _run(session, frozen_now, log={"pages": 3, "worker": "worker-live@vps2"})
    without = await _run(session, frozen_now, raw_path=None)

    first = (await editor_client.get(f"/admin/api/import-runs/{with_log.id}")).json()["data"]
    second = (await editor_client.get(f"/admin/api/import-runs/{without.id}")).json()["data"]

    assert (first["pages"], first["worker"]) == (3, "worker-live@vps2")
    assert (second["pages"], second["worker"]) == (0, None)
