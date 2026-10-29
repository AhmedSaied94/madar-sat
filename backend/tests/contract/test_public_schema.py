"""Schemathesis over the committed ``openapi/public.json`` against the live app (T016)."""

from __future__ import annotations

import json
from collections.abc import AsyncIterator, Iterator
from pathlib import Path

import pytest
import schemathesis
from hypothesis import HealthCheck, settings
from schemathesis.checks import not_a_server_error
from schemathesis.specs.openapi.checks import response_schema_conformance
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.db.session import get_session
from app.public import app
from app.settings import get_settings

OPENAPI_PATH = Path(__file__).resolve().parents[2] / "openapi" / "public.json"

schema = schemathesis.openapi.from_path(OPENAPI_PATH)
schema.app = app


@pytest.fixture(scope="module")
def nullpool_sessions(loaded_snapshot: None) -> Iterator[None]:
    # Schemathesis drives the ASGI app from its own event loop per request, so pooled
    # asyncpg connections can't be shared with the pytest loop: open one per request.
    engine = create_async_engine(get_settings().database_url, poolclass=NullPool)
    factory = async_sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    async def _session() -> AsyncIterator[AsyncSession]:
        async with factory() as session:
            yield session

    app.dependency_overrides[get_session] = _session
    yield
    app.dependency_overrides.pop(get_session, None)


@pytest.mark.usefixtures("nullpool_sessions")
@schema.parametrize()
@settings(max_examples=25, deadline=None, suppress_health_check=list(HealthCheck))
def test_public_api_conforms_to_contract(case: schemathesis.Case) -> None:
    case.call_and_validate(checks=[not_a_server_error, response_schema_conformance])


def test_committed_contract_matches_app() -> None:
    """``openapi/public.json`` is what ``export-openapi`` would write today."""
    live = app.openapi()
    live["info"]["version"] = get_settings().contract_version
    committed = json.loads(OPENAPI_PATH.read_text(encoding="utf-8"))
    assert json.loads(json.dumps(live, sort_keys=True)) == committed
