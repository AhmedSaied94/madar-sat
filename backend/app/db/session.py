"""Database engines and sessions.

The API uses an async asyncpg engine; the CLI, ETL and Alembic use a sync psycopg
engine (asyncpg cannot run the multi-statement schema script). Both read the same
connection settings, derived from ``DATABASE_URL`` / ``DATABASE_URL_SYNC``.
"""

from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy import create_engine
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.settings import get_settings

_settings = get_settings()

sync_engine = create_engine(_settings.database_url_sync, pool_pre_ping=True)
async_engine = create_async_engine(_settings.database_url, pool_pre_ping=True)

SyncSession = sessionmaker(bind=sync_engine, autoflush=False, expire_on_commit=False)
async_session_factory = async_sessionmaker(bind=async_engine, autoflush=False, expire_on_commit=False)


async def get_session() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency: yields one request-scoped async session."""
    async with async_session_factory() as session:
        yield session
