"""Per-test transactions are rolled back, and the app sees the test's rows (T005)."""

from __future__ import annotations

import pytest
from sqlalchemy import func, select

from app.db.models import Commentator

NAME = "معلق اختبار العزل"


@pytest.mark.asyncio
async def test_rows_written_in_a_test_are_visible_to_the_app(session, public_client):
    commentator = Commentator(name=NAME)
    session.add(commentator)
    await session.commit()  # releases a savepoint only

    resp = await public_client.get(f"/v1/commentators/{commentator.id}")
    assert resp.status_code == 200
    assert resp.json()["data"]["name"] == NAME


@pytest.mark.asyncio
async def test_rows_from_the_previous_test_are_gone(session):
    count = await session.scalar(select(func.count()).select_from(Commentator).where(Commentator.name == NAME))
    assert count == 0


def test_sync_session_rolls_back_too(sync_session):
    sync_session.add(Commentator(name=NAME + " sync"))
    sync_session.commit()
    assert sync_session.scalar(select(func.count()).where(Commentator.name == NAME + " sync")) == 1


def test_sync_rows_from_the_previous_test_are_gone(sync_session):
    assert sync_session.scalar(select(func.count()).where(Commentator.name == NAME + " sync")) == 0
