"""Schemathesis over the committed ``openapi/admin.json`` against the live admin app (T030, FR-013).

Writes here are real commits, so the run gets a database of its own (migrated, snapshot loaded) and is
dropped afterwards: the rolled-back transaction the other tests share can't be used, because Schemathesis
drives the app from its own event loop for every request.
"""

from __future__ import annotations

import json
import os
import uuid
from collections.abc import AsyncIterator, Iterator
from datetime import UTC, datetime
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import psycopg
import pytest
import schemathesis
from alembic.config import Config
from hypothesis import HealthCheck, settings
from schemathesis.checks import not_a_server_error
from schemathesis.specs.openapi.checks import response_schema_conformance
from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import NullPool

from alembic import command
from app.admin import app
from app.auth.passwords import hash_password
from app.auth.tokens import issue_access_token
from app.db.models import AdminUser
from app.db.session import get_session
from app.etl.report import Report
from app.etl.snapshot import load
from app.etl.types import read_snapshot
from app.settings import get_settings

OPENAPI_PATH = Path(__file__).resolve().parents[2] / "openapi" / "admin.json"
SNAPSHOT_DIR = str(Path(__file__).resolve().parents[1] / "fixtures" / "snapshot")
TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL", "postgresql://postgres:postgres@localhost:5434/postgres")

schema = schemathesis.openapi.from_path(OPENAPI_PATH)
schema.app = app


def _url(scheme: str, name: str) -> str:
    parts = urlsplit(TEST_DATABASE_URL)
    return urlunsplit((scheme, parts.netloc, f"/{name}", parts.query, parts.fragment))


@pytest.fixture(scope="module")
def contract_database(_prepare_database: None) -> Iterator[dict[str, str]]:
    """A migrated database with the snapshot loaded and one editor, for the writes Schemathesis makes."""
    name = f"madar_contract_{uuid.uuid4().hex[:12]}"
    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        conn.execute(f'CREATE DATABASE "{name}"')
    sync_url = _url("postgresql+psycopg", name)
    try:
        cfg = Config("alembic.ini")
        cfg.set_main_option("sqlalchemy.url", sync_url)
        command.upgrade(cfg, "head")

        engine = create_engine(sync_url)
        with Session(engine) as session:
            snapshot = read_snapshot(SNAPSHOT_DIR)
            load(session, snapshot, Report("load-snapshot", SNAPSHOT_DIR))
            editor = AdminUser(
                email="contract@example.com", name="محرر", role="editor", password_hash=hash_password("x" * 16)
            )
            session.add(editor)
            session.commit()
            token = issue_access_token(editor.id, editor.role, datetime.now(UTC))
        engine.dispose()
        yield {"async_url": _url("postgresql+asyncpg", name), "token": token}
    finally:
        with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
            conn.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')


@pytest.fixture(scope="module")
def contract_app(contract_database: dict[str, str]) -> Iterator[dict[str, str]]:
    engine = create_async_engine(contract_database["async_url"], poolclass=NullPool)
    factory = async_sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    async def _session() -> AsyncIterator[AsyncSession]:
        async with factory() as session:
            yield session

    app.dependency_overrides[get_session] = _session
    yield {"Authorization": f"Bearer {contract_database['token']}"}
    app.dependency_overrides.pop(get_session, None)


@pytest.mark.usefixtures("redis_client")
@schema.parametrize()
@settings(max_examples=20, deadline=None, suppress_health_check=list(HealthCheck))
def test_admin_api_conforms_to_contract(case: schemathesis.Case, contract_app: dict[str, str]) -> None:
    case.call_and_validate(headers=contract_app, checks=[not_a_server_error, response_schema_conformance])


def test_committed_contract_matches_app() -> None:
    """``openapi/admin.json`` is what ``export-openapi`` would write today."""
    live = app.openapi()
    live["info"]["version"] = get_settings().contract_version
    committed = json.loads(OPENAPI_PATH.read_text(encoding="utf-8"))
    assert json.loads(json.dumps(live, sort_keys=True)) == committed


D6_ERROR_CODES = {
    "password_change_required",
    "notification_not_cancellable",
    "send_at_in_past",
    "text_not_allowed",
    "test_device_not_set",
    "test_device_no_token",
    "device_not_found",
    "email_taken",
    "cannot_change_self",
    "last_admin",
    "password_too_short",
    "password_unchanged",
}


def test_every_d6_error_code_is_documented():
    """Each code A15/A16 has to handle appears in the committed admin document (admin-api)."""
    import json
    from pathlib import Path

    document = json.loads(Path("openapi/admin.json").read_text(encoding="utf-8"))
    documented: set[str] = set()

    def walk(node):
        if isinstance(node, dict):
            code = node.get("code")
            if isinstance(code, str):
                documented.add(code)
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(document)
    description = document.get("info", {}).get("description", "")
    assert D6_ERROR_CODES <= (documented | {code for code in D6_ERROR_CODES if code in description})
