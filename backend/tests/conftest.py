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
# Only the admin app reads this (research R2); at least 32 bytes.
os.environ.setdefault("ADMIN_JWT_SECRET", "test-only-admin-jwt-secret-0123456789abcdef")

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


async def _client(app, db_connection, frozen_now, *, headers=None, client_addr=("127.0.0.1", 50000)):
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
        transport = ASGITransport(app=app, client=client_addr)
        async with AsyncClient(transport=transport, base_url="http://test", headers=headers) as client:
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
async def anon_admin_client(loaded_snapshot, db_connection, frozen_now):
    """The admin app with no credentials (the auth routes, 401 and 403 tests)."""
    from app.admin import app

    async for client in _client(app, db_connection, frozen_now):
        yield client


# --- Admin accounts, tokens and Redis (D2) ----------------------------------------------------------

ADMIN_PASSWORD = "correct horse battery"  # ≥ 12 characters; the hash is computed once per session
TEST_REDIS_URL = os.environ.get("TEST_REDIS_URL", "redis://localhost:6380/0")
REDIS_TEST_PREFIXES = ("auth:", "lock:test:")


@pytest.fixture(scope="session")
def admin_password() -> str:
    return ADMIN_PASSWORD


@pytest.fixture(scope="session")
def admin_password_hash(admin_password) -> str:
    from app.auth.passwords import hash_password

    return hash_password(admin_password)


@pytest.fixture
async def redis_client():
    """Redis on ``TEST_REDIS_URL`` with this app's keys cleared before each test.

    Only the ``auth:`` and ``lock:test:`` prefixes are deleted: other lanes' tests share the server,
    so FLUSHDB would break them.
    """
    import redis.asyncio as aioredis

    client = aioredis.from_url(TEST_REDIS_URL)
    for prefix in REDIS_TEST_PREFIXES:
        async for key in client.scan_iter(match=f"{prefix}*"):
            await client.delete(key)
    try:
        yield client
    finally:
        await client.aclose()


@pytest.fixture
def make_admin(session, admin_password_hash):
    """Create an admin account in the test transaction; returns the ``AdminUser`` row."""
    from app.db.models import AdminUser

    async def _make(email="editor@example.com", name="محرر", role="editor", *, is_active=True, password_hash=None):
        admin = AdminUser(
            email=email, name=name, role=role, password_hash=password_hash or admin_password_hash, is_active=is_active
        )
        session.add(admin)
        await session.flush()
        return admin

    return _make


def bearer(admin, now) -> dict[str, str]:
    """An ``Authorization`` header carrying a valid access token for ``admin`` at ``now``."""
    from app.auth.tokens import issue_access_token

    return {"Authorization": f"Bearer {issue_access_token(admin.id, admin.role, now)}"}


@pytest.fixture
async def editor_client(loaded_snapshot, db_connection, frozen_now, make_admin, redis_client):
    """The admin app, signed in as an ``editor``. ``client.admin`` is the account."""
    from app.admin import app

    editor = await make_admin("editor@example.com", "محرر", "editor")
    async for client in _client(app, db_connection, frozen_now, headers=bearer(editor, frozen_now)):
        client.admin = editor
        yield client


@pytest.fixture
async def admin_client(loaded_snapshot, db_connection, frozen_now, make_admin, redis_client):
    """The admin app, signed in as an ``admin``. ``client.admin`` is the account."""
    from app.admin import app

    boss = await make_admin("boss@example.com", "مدير", "admin")
    async for client in _client(app, db_connection, frozen_now, headers=bearer(boss, frozen_now)):
        client.admin = boss
        yield client


@pytest.fixture
def client_at(loaded_snapshot, db_connection, frozen_now):
    """``async with client_at(("10.8.0.1", 5000), headers) as client``: the admin app from a given peer address."""
    from contextlib import asynccontextmanager

    @asynccontextmanager
    async def _open(addr, headers=None):
        from app.admin import app

        async for client in _client(app, db_connection, frozen_now, headers=headers, client_addr=addr):
            yield client

    return _open


@pytest.fixture
def etag_of():
    """``await etag_of(client, "/admin/api/matches/1")``: the entity's current ``ETag``."""

    async def _etag(client, path: str) -> str:
        response = await client.get(path)
        assert response.status_code == 200, response.text
        return response.headers["etag"]

    return _etag
