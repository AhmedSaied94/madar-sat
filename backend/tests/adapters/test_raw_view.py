"""``adapters.read_raw_page``: raw pages reach VPS-1 over Redis (D5 T052, R13)."""

from __future__ import annotations

import gzip
import json
import os
from datetime import UTC, date, datetime
from pathlib import Path
from typing import Any

import pytest
import redis

from app.adapters import tasks
from app.adapters.base import RawPage
from app.adapters.config import get_adapter_settings
from app.adapters.raw_store import RawStore
from app.adapters.tasks import MAX_RAW_VIEW_BYTES, RAW_VIEW_TTL, read_raw_page
from app.db.models import ImportRun

NOW = datetime(2026, 11, 4, 12, 0, tzinfo=UTC)
URLS = [
    "https://www.yallakora.com/matches-center?date=2026-11-04",
    "https://www.yallakora.com/matches-center?date=2026-11-05",
]


@pytest.fixture(autouse=True)
def _task_session(monkeypatch: pytest.MonkeyPatch, sync_session):
    from sqlalchemy.orm import Session

    import app.db.session as db_session

    monkeypatch.setattr(
        db_session,
        "SyncSession",
        lambda: Session(bind=sync_session.connection(), join_transaction_mode="create_savepoint"),
    )


@pytest.fixture(autouse=True)
def root(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> Path:
    monkeypatch.setenv("RAW_ROOT", str(tmp_path))
    get_adapter_settings.cache_clear()
    yield tmp_path
    get_adapter_settings.cache_clear()


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> redis.Redis:
    connection = redis.Redis.from_url(os.environ["REDIS_URL"], decode_responses=True)
    monkeypatch.setattr(tasks, "redis_client", lambda: connection)
    yield connection
    connection.close()


def saved_run(session: Any, root: Path, *bodies: bytes) -> ImportRun:
    pages = [RawPage(url=URLS[n % len(URLS)], status=200, body=body) for n, body in enumerate(bodies)]
    run_dir = RawStore(root).save(source="yallakora", run_day=date(2026, 11, 4), run_id="r-raw", pages=pages)
    (run_dir / "run.json").write_text(json.dumps({"page_urls": [page.url for page in pages]}), encoding="utf-8")
    run = ImportRun(source="yallakora", started_at=NOW, status="succeeded", raw_path=str(run_dir))
    session.add(run)
    session.flush()
    return run


def view(client: redis.Redis, run: ImportRun, page: int = 0) -> dict[str, Any]:
    raw = client.get(f"rawview:{run.id}:{page}")
    assert raw is not None
    return json.loads(raw)


def test_it_writes_the_page_as_text_with_a_five_minute_ttl(sync_session, root: Path, client: redis.Redis) -> None:
    run = saved_run(sync_session, root, "<html>الأولى</html>".encode(), b"<html>2</html>")

    read_raw_page.apply(args=(run.id, 0)).get()

    assert view(client, run) == {
        "pages": 2,
        "url": URLS[0],
        "content_type": "text/html",
        "text": "<html>الأولى</html>",
        "truncated": False,
    }
    assert 0 < client.ttl(f"rawview:{run.id}:0") <= RAW_VIEW_TTL == 300


def test_it_reads_the_page_it_was_asked_for(sync_session, root: Path, client: redis.Redis) -> None:
    run = saved_run(sync_session, root, b"<html>1</html>", b"<html>2</html>")

    read_raw_page.apply(args=(run.id, 1)).get()

    assert view(client, run, 1)["text"] == "<html>2</html>"
    assert view(client, run, 1)["url"] == URLS[1]


def test_a_large_page_is_capped_and_marked_truncated(sync_session, root: Path, client: redis.Redis) -> None:
    run = saved_run(sync_session, root, b"a" * (MAX_RAW_VIEW_BYTES + 10))

    read_raw_page.apply(args=(run.id, 0)).get()

    data = view(client, run)
    assert MAX_RAW_VIEW_BYTES == 512 * 1024
    assert len(data["text"].encode()) == MAX_RAW_VIEW_BYTES
    assert data["truncated"] is True


def test_a_cap_inside_a_character_does_not_garble_the_text(sync_session, root: Path, client: redis.Redis) -> None:
    run = saved_run(sync_session, root, b"a" + "ب".encode() * MAX_RAW_VIEW_BYTES)

    read_raw_page.apply(args=(run.id, 0)).get()

    assert "�" not in view(client, run)["text"]


def test_an_older_run_without_page_urls_has_no_url(sync_session, root: Path, client: redis.Redis) -> None:
    run = saved_run(sync_session, root, b"<html></html>")
    (Path(run.raw_path) / "run.json").unlink()

    read_raw_page.apply(args=(run.id, 0)).get()

    assert view(client, run)["url"] is None


@pytest.mark.parametrize("reason", ["pruned", "no_path", "no_such_page", "outside_the_root", "a_file_in_the_folder"])
def test_what_cannot_be_read_is_reported_as_gone(sync_session, root: Path, client: redis.Redis, reason: str) -> None:
    run = saved_run(sync_session, root, b"<html></html>")
    page = 0
    if reason == "pruned":
        for child in Path(run.raw_path).iterdir():
            child.unlink()
        Path(run.raw_path).rmdir()
    elif reason == "no_path":
        run.raw_path = None
    elif reason == "no_such_page":
        page = 5
    elif reason == "outside_the_root":
        # Never trust the stored path to stay inside the raw disk.
        outside = root.parent / f"{root.name}-outside"
        outside.mkdir()
        (outside / "1.html.gz").write_bytes(gzip.compress(b"secret"))
        run.raw_path = str(outside)
    else:
        run.raw_path = str(Path(run.raw_path) / "run.json")
    sync_session.flush()

    read_raw_page.apply(args=(run.id, page)).get()

    assert view(client, run, page) == {"gone": True}


def test_an_unknown_run_is_gone(sync_session, client: redis.Redis) -> None:
    read_raw_page.apply(args=(987654321, 0)).get()
    assert json.loads(client.get("rawview:987654321:0")) == {"gone": True}
    client.delete("rawview:987654321:0")


def test_the_task_runs_on_maintenance_where_the_raw_disk_is() -> None:
    assert tasks.IngestionRouter().route_for_task("adapters.read_raw_page") == {"queue": "maintenance"}
