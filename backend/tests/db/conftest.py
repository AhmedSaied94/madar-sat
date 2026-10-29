"""DB tests need the test database prepared (migrations applied)."""

import pytest


@pytest.fixture(scope="session", autouse=True)
def _db(_prepare_database):
    yield
