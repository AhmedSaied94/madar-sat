"""The ingestion tasks: queues, locks, expiry, run rows and the home-box path (T064, R15, R21)."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import textwrap
from datetime import UTC, date, datetime
from pathlib import Path

import pytest
import redis

from app.adapters.base import RawPage
from app.adapters.messages import ScrapeResult
from app.adapters.tasks import (
    FETCH_EXPIRES,
    IngestionRouter,
    adapter_for,
    ingest,
    prune_raw_pages,
)
from app.workers.base import BaseTask
from app.workers.config import get_worker_settings
from tests.adapters.test_upsert import fixture

BACKEND = Path(__file__).resolve().parents[2]
SAVED_PAGE = Path(__file__).resolve().parents[1] / "fixtures" / "ysscores" / "2026-10-30.html"
NOW = datetime(2026, 10, 31, 3, 0, tzinfo=UTC)


@pytest.fixture
def redis_client() -> redis.Redis:
    client = redis.Redis.from_url(get_worker_settings().broker_url, decode_responses=True)
    client.flushdb()
    yield client
    client.flushdb()
    client.close()


@pytest.fixture(autouse=True)
def _eager():
    from app.workers import app

    before = app.conf.task_always_eager
    app.conf.task_always_eager = True
    yield
    app.conf.task_always_eager = before


def test_every_task_uses_the_worker_base_class() -> None:
    import app.adapters.media_tasks  # noqa: F401 - the worker's `include` imports it at start-up
    from app.workers import app

    for name in ("adapters.fetch", "adapters.ingest", "adapters.prune_raw_pages", "adapters.rehost_logo"):
        assert isinstance(app.tasks[name], BaseTask), name


def test_a_fetch_expires_two_hours_after_it_is_queued() -> None:
    from app.workers import app

    assert app.tasks["adapters.fetch"].expires == FETCH_EXPIRES == 2 * 60 * 60


class TestRouting:
    router = IngestionRouter()

    def test_ysscores_goes_to_the_home_box_by_default(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from app.adapters.config import get_adapter_settings

        get_adapter_settings.cache_clear()
        monkeypatch.delenv("YSSCORES_FETCH_QUEUE", raising=False)
        assert self.router.route_for_task("adapters.fetch", args=("ysscores",)) == {"queue": "scrape_home"}

    def test_ysscores_moves_to_vps2_when_the_setting_says_so(self, monkeypatch: pytest.MonkeyPatch) -> None:
        from app.adapters.config import get_adapter_settings

        monkeypatch.setenv("YSSCORES_FETCH_QUEUE", "scrape")
        get_adapter_settings.cache_clear()
        try:
            assert self.router.route_for_task("adapters.fetch", args=("ysscores",)) == {"queue": "scrape"}
        finally:
            get_adapter_settings.cache_clear()

    def test_the_bridge_ingest_prune_and_logo_queues(self) -> None:
        assert self.router.route_for_task("adapters.fetch", args=("legacy",)) == {"queue": "scrape"}
        assert self.router.route_for_task("adapters.ingest") == {"queue": "imports"}
        assert self.router.route_for_task("adapters.prune_raw_pages") == {"queue": "maintenance"}
        assert self.router.route_for_task("adapters.rehost_logo") == {"queue": "media"}
        assert self.router.route_for_task("something.else") is None

    def test_the_app_routes_a_bare_celery_call_to_the_right_queue(self) -> None:
        from app.workers import app

        assert app.amqp.router.route({}, "adapters.fetch", args=("legacy",))["queue"].name == "scrape"
        assert app.amqp.router.route({}, "adapters.ingest")["queue"].name == "imports"


def test_a_held_fetch_lock_makes_the_run_exit(redis_client: redis.Redis, monkeypatch: pytest.MonkeyPatch) -> None:
    from app.adapters import tasks as module

    redis_client.set("lock:fetch:ysscores", "someone-else", ex=60)
    called: list[str] = []
    monkeypatch.setattr(module, "http_fetcher", lambda: called.append("fetched") or None)  # type: ignore[func-returns-value]

    from app.adapters.tasks import fetch

    result = fetch.apply(args=("ysscores",)).get()
    assert result == {"source": "ysscores", "skipped": True}
    assert called == []


def test_a_held_ingest_lock_makes_the_run_exit(redis_client: redis.Redis) -> None:
    result = ScrapeResult.build(
        source="ysscores",
        run_id="r-1",
        started_at=NOW,
        finished_at=NOW,
        fetched_on="home-box",
        pages=[],
        items=[],
    )
    redis_client.set("lock:ingest:ysscores", "someone-else", ex=60)
    assert ingest.apply(args=(result.as_task_arg(),)).get() == {"source": "ysscores", "skipped": True}


def _saved_result(day: str = "2026-10-30") -> ScrapeResult:
    adapter = adapter_for("ysscores")
    page = RawPage(
        url=f"https://www.ysscores.com/ar/match_date_to#{day}",
        status=200,
        body=(Path(__file__).resolve().parents[1] / "fixtures" / "ysscores" / f"{day}.html").read_bytes(),
    )
    items = adapter.parse(page)
    return ScrapeResult.build(
        source="ysscores",
        run_id=f"{day}T03:00:00Z-ysscores-abcd",
        started_at=NOW,
        finished_at=NOW,
        fetched_on="home-box",
        pages=[page],
        items=items,
    )


class TestIngest:
    def _prepare(self, monkeypatch: pytest.MonkeyPatch, sync_session, tmp_path: Path) -> None:
        import app.db.session as db_session
        from app.adapters.config import get_adapter_settings

        monkeypatch.setenv("RAW_ROOT", str(tmp_path))
        get_adapter_settings.cache_clear()
        from sqlalchemy.orm import Session

        def factory() -> Session:
            return Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint")

        monkeypatch.setattr(db_session, "SyncSession", factory)
        self.tmp_path = tmp_path

    def test_it_writes_the_run_row_the_pages_and_the_matches(
        self, sync_session, loaded_snapshot, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        self._prepare(monkeypatch, sync_session, tmp_path)
        result = _saved_result()
        summary = ingest.apply(args=(result.as_task_arg(),)).get()

        assert summary["status"] == "succeeded"
        assert summary["items_upserted"] == len(result.items) > 0

        from app.db.models import ImportRun

        run = sync_session.query(ImportRun).order_by(ImportRun.id.desc()).first()
        assert run is not None
        assert run.source == "ysscores"
        assert run.status == "succeeded"
        assert run.items_found == len(result.items)
        assert run.items_upserted == run.matches_imported == summary["items_upserted"]
        assert run.http_errors == 0
        assert run.raw_path is not None and Path(run.raw_path).is_dir()
        assert (Path(run.raw_path) / "1.html.gz").is_file()
        run_json = json.loads((Path(run.raw_path) / "run.json").read_text(encoding="utf-8"))
        assert run_json["counts"]["items_upserted"] == run.items_upserted
        assert "skipped" in run_json and "unresolved" in run_json

    def test_a_second_run_upserts_nothing(
        self, sync_session, loaded_snapshot, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        self._prepare(monkeypatch, sync_session, tmp_path)
        result = _saved_result()
        ingest.apply(args=(result.as_task_arg(),)).get()
        second = ingest.apply(args=(result.as_task_arg(),)).get()
        assert second["items_upserted"] == 0  # SC-004

    def test_a_failed_fetch_records_a_failed_run(
        self, sync_session, loaded_snapshot, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        self._prepare(monkeypatch, sync_session, tmp_path)
        failed = ScrapeResult.failed(
            source="ysscores",
            run_id="r-failed",
            started_at=NOW,
            finished_at=NOW,
            fetched_on="home-box",
            http_errors=3,
            error="layout_changed",
        )
        summary = ingest.apply(args=(failed.as_task_arg(),)).get()
        assert summary["status"] == "failed"

        from app.db.models import ImportRun

        run = sync_session.query(ImportRun).order_by(ImportRun.id.desc()).first()
        assert run is not None and run.status == "failed"
        assert run.error == "layout_changed"
        assert run.http_errors == 3

    def test_a_partial_run_is_partial(
        self, sync_session, loaded_snapshot, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        self._prepare(monkeypatch, sync_session, tmp_path)
        from app.adapters.base import ParsedFixture

        good = fixture()
        context = {
            "match_date": good.match_date,
            "wall_time": "10:00 م",
            "competition": good.competition,
            "stage": good.stage,
            "home": good.home,
            "away": good.away,
            "external_id": "ys-9001",
        }
        parsed = [
            ParsedFixture(**context),  # type: ignore[arg-type]
            ParsedFixture(**{**context, "external_id": "ys-9002", "home": None}),  # type: ignore[arg-type]
        ]
        result = ScrapeResult.build(
            source="ysscores",
            run_id="r-partial",
            started_at=NOW,
            finished_at=NOW,
            fetched_on="home-box",
            pages=[RawPage(url="https://www.ysscores.com/x#2026-11-05", status=200, body=b"<html></html>")],
            items=parsed,
        )
        summary = ingest.apply(args=(result.as_task_arg(),)).get()
        assert summary["status"] == "partial"
        assert summary["items_upserted"] == 1

    def test_it_queues_logos_on_the_media_queue_after_the_commit(
        self, sync_session, loaded_snapshot, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        self._prepare(monkeypatch, sync_session, tmp_path)
        sent: list[tuple[tuple, dict]] = []
        from app.adapters import media_tasks

        monkeypatch.setattr(
            media_tasks.rehost_logo, "apply_async", lambda args, queue: sent.append((tuple(args), {"queue": queue}))
        )
        from app.adapters.base import ParsedFixture

        parsed = ParsedFixture(
            external_id="ys-9100",
            competition="الدوري المصري الممتاز",
            home="مان سيتي",
            away="الزمالك",
            away_logo="https://imgs.ysscores.com/teams/64/city.png",
            wall_time="09:00 م",
            match_date=date(2026, 11, 6),
        )
        result = ScrapeResult.build(
            source="ysscores",
            run_id="r-logo",
            started_at=NOW,
            finished_at=NOW,
            fetched_on="home-box",
            pages=[RawPage(url="https://www.ysscores.com/x#2026-11-06", status=200, body=b"<html></html>")],
            items=[parsed],
        )
        ingest.apply(args=(result.as_task_arg(),)).get()
        assert len(sent) == 1
        entity, entity_id, url, source = sent[0][0]
        assert (entity, source) == ("teams", "ysscores")
        assert url.endswith("city.png")
        assert sent[0][1] == {"queue": "media"}


def test_prune_deletes_old_run_folders(
    sync_session, loaded_snapshot, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    from app.adapters.config import get_adapter_settings

    old = tmp_path / "ysscores" / "2026-10-01" / "run"
    old.mkdir(parents=True)
    (old / "run.json").write_text("{}", encoding="utf-8")
    monkeypatch.setenv("RAW_ROOT", str(tmp_path))
    get_adapter_settings.cache_clear()
    assert prune_raw_pages.apply().get() == {"removed": 1}
    assert not old.exists()


def test_the_home_box_path_loads_neither_the_database_nor_the_app_settings(tmp_path: Path) -> None:
    """A subprocess with only REDIS_URL and SCRAPE_USER_AGENT fetches and parses one saved page (FR-028)."""
    script = textwrap.dedent(
        """
        import json, sys
        from pathlib import Path
        import httpx

        from app.workers import app
        app.conf.task_always_eager = True
        app.conf.task_eager_propagates = True

        import app.adapters.tasks as tasks
        from app.adapters.base import RawPage
        from app.adapters.fetcher import HttpFetcher
        from app.adapters.ratelimit import RateLimiter

        page = Path(sys.argv[1]).read_bytes()

        class Allowed:
            def take(self, host):
                return True

        def transport_page(source: str) -> HttpFetcher:
            def handler(request):
                return httpx.Response(200, content=page, headers={"content-type": "text/html"})
            return HttpFetcher(
                limiter=Allowed(),
                user_agent="test",
                client=httpx.Client(transport=httpx.MockTransport(handler), follow_redirects=False),
            )

        sent = []
        tasks.http_fetcher = lambda: transport_page("ysscores")
        tasks.send_ingest = sent.append
        result = tasks.fetch.apply(args=("ysscores", "2026-10-30")).get()
        assert result["source"] == "ysscores" and result["items"] > 0, result
        assert sent and sent[0].source == "ysscores"
        assert "app.db" not in sys.modules, "the fetch path imported app.db"
        assert "app.settings" not in sys.modules, "the fetch path imported app.settings"
        print("OK", json.dumps(result))
        """
    )
    env = {
        "PATH": os.environ.get("PATH", ""),
        "REDIS_URL": os.environ.get("REDIS_URL", "redis://localhost:6380/0"),
        "SCRAPE_USER_AGENT": "MadarSat/test",
        "PYTHONPATH": str(BACKEND),
        "HOME": os.environ.get("HOME", "/tmp"),
    }
    proc = subprocess.run(
        [sys.executable, "-c", script, str(SAVED_PAGE)],
        cwd=BACKEND,
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert proc.returncode == 0, proc.stderr[-3000:]
    assert proc.stdout.strip().startswith("OK")


def test_the_adapter_registry_covers_both_sources() -> None:
    assert adapter_for("ysscores").name == "ysscores"
    assert adapter_for("legacy").name == "legacy"
    with pytest.raises(ValueError):
        adapter_for("elsewhere")


def test_a_day_without_fixtures_still_reports(redis_client: redis.Redis) -> None:
    from app.adapters.tasks import fetch

    sent: list[ScrapeResult] = []
    import app.adapters.tasks as module

    class Empty:
        def post(self, url: str, data: dict[str, str], allowed_hosts, headers=None):
            return RawPage(
                url=url,
                status=200,
                body='<div class="no-matches-wrapper">لا توجد مباريات</div>'.encode(),
            )

        def get(self, url: str, allowed_hosts, params=None):  # pragma: no cover - not used here
            raise AssertionError

        def close(self) -> None:
            pass

    module.http_fetcher = lambda: Empty()  # type: ignore[assignment]
    module.send_ingest = sent.append  # type: ignore[assignment]
    try:
        result = fetch.apply(args=("ysscores", "2026-11-11")).get()
    finally:
        import importlib

        importlib.reload(module)
    assert result["items"] == 0
    assert sent and sent[0].pages and sent[0].error is None
