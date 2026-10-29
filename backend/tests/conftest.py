"""Test setup: a fresh PostgreSQL 16 database, the app clients, and a frozen clock."""

from __future__ import annotations

import os
import uuid
from urllib.parse import urlsplit, urlunsplit

# Set the app's settings before any app module is imported. The test database is
# derived from TEST_DATABASE_URL (a PostgreSQL 16 server), never SQLite.
TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL", "postgresql://postgres:postgres@localhost:5434/postgres")


def _derive(url: str, dbname: str) -> str:
    parts = urlsplit(url)
    return urlunsplit((parts.scheme, parts.netloc, f"/{dbname}", parts.query, parts.fragment))


TEST_DB = f"madar_test_{uuid.uuid4().hex[:12]}"

os.environ["DATABASE_URL"] = _derive(TEST_DATABASE_URL, TEST_DB).replace("postgresql://", "postgresql+asyncpg://")
os.environ["DATABASE_URL_SYNC"] = _derive(TEST_DATABASE_URL, TEST_DB).replace("postgresql://", "postgresql+psycopg://")
os.environ.setdefault("REDIS_URL", os.environ.get("TEST_REDIS_URL", "redis://localhost:6380/0"))
os.environ.setdefault("MEDIA_BASE_URL", "https://media.example")
os.environ.setdefault("MEDIA_ROOT", "/tmp/madar-media-test")
os.environ.setdefault(
    "MEDIA_REHOST_ALLOWED_HOSTS",
    "pub-01ffc6064b9b435aa726a53a561a6f53.r2.dev,imgs.ysscores.com",
)
os.environ.setdefault("CORS_ORIGINS", "https://madar.web.app,https://madar.firebaseapp.com")

from datetime import UTC, datetime  # noqa: E402
from pathlib import Path  # noqa: E402

import pytest  # noqa: E402


@pytest.fixture(scope="session")
def _prepare_database():
    import psycopg

    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        conn.execute(f'CREATE DATABASE "{TEST_DB}"')

    from alembic.config import Config

    from alembic import command

    cfg = Config("alembic.ini")
    command.upgrade(cfg, "head")
    yield

    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        conn.execute(f'DROP DATABASE IF EXISTS "{TEST_DB}" WITH (FORCE)')


@pytest.fixture
def empty_database():
    """A brand-new empty database on the test server; yields its plain postgresql:// URL."""
    import psycopg

    name = f"madar_scratch_{uuid.uuid4().hex[:12]}"
    with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
        conn.execute(f'CREATE DATABASE "{name}"')
    try:
        yield _derive(TEST_DATABASE_URL, name)
    finally:
        with psycopg.connect(TEST_DATABASE_URL, autocommit=True) as conn:
            conn.execute(f'DROP DATABASE IF EXISTS "{name}" WITH (FORCE)')


SNAPSHOT_DIR = str(Path(__file__).resolve().parent / "fixtures" / "snapshot")


@pytest.fixture(scope="session")
def loaded_snapshot(_prepare_database):
    """Load the synthetic snapshot once so contract tests run against real data."""
    from app.db.session import SyncSession
    from app.etl.report import Report
    from app.etl.snapshot import load
    from app.etl.types import read_snapshot

    snapshot = read_snapshot(SNAPSHOT_DIR)
    report = Report("load-snapshot", SNAPSHOT_DIR)
    with SyncSession() as session:
        load(session, snapshot, report)
        session.commit()
    yield


@pytest.fixture
async def db_connection(_prepare_database):
    """One connection per test inside a transaction that is always rolled back."""
    from app.db.session import async_engine

    async with async_engine.connect() as conn:
        trans = await conn.begin()
        try:
            yield conn
        finally:
            await trans.rollback()


def _savepoint_session(conn):
    # A commit inside the test only releases a savepoint; the outer rollback undoes it.
    from sqlalchemy.ext.asyncio import AsyncSession

    return AsyncSession(bind=conn, join_transaction_mode="create_savepoint", expire_on_commit=False)


@pytest.fixture
async def session(db_connection):
    async with _savepoint_session(db_connection) as s:
        yield s


@pytest.fixture
def sync_session(_prepare_database):
    """A sync session in a per-test transaction that is always rolled back."""
    from sqlalchemy.orm import Session

    from app.db.session import sync_engine

    with sync_engine.connect() as conn:
        trans = conn.begin()
        try:
            with Session(bind=conn, join_transaction_mode="create_savepoint", expire_on_commit=False) as s:
                yield s
        finally:
            trans.rollback()


@pytest.fixture
def frozen_now() -> datetime:
    return datetime(2026, 10, 28, 18, 0, tzinfo=UTC)


async def _client(app, db_connection, frozen_now):
    """An ASGI client whose requests share the test's rolled-back transaction."""
    from httpx import ASGITransport, AsyncClient

    from app.api.deps import get_now
    from app.db.session import get_session

    async def _session():
        async with _savepoint_session(db_connection) as s:
            yield s

    overrides = {get_now: lambda: frozen_now, get_session: _session}
    app.dependency_overrides.update(overrides)
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            yield client
    finally:
        for dep in overrides:
            app.dependency_overrides.pop(dep, None)


@pytest.fixture
async def public_client(loaded_snapshot, db_connection, frozen_now):
    from app.public import app

    async for client in _client(app, db_connection, frozen_now):
        yield client


@pytest.fixture
async def admin_client(loaded_snapshot, db_connection, frozen_now):
    from app.admin import app

    async for client in _client(app, db_connection, frozen_now):
        yield client
