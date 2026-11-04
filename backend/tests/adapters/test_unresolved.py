"""``record_unresolved``: one row per name, per source and kind, that never reopens (D5 T051, FR-022)."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any

import pytest
from sqlalchemy import text

from app.adapters.unresolved import MAX_NAME, record_unresolved
from app.domain.arabic import ar_normalize

CONTEXT = {"match_id": 7, "home": "فريق", "away": "آخر", "competition": "كأس", "kickoff_at": None}


def rows(session: Any) -> list[Any]:
    return list(
        session.execute(
            text(
                "SELECT id, source, kind, name, name_norm, competition_norm, context, seen_count, state, "
                "first_seen_at, last_seen_at FROM unresolved_names ORDER BY id"
            )
        ).mappings()
    )


def record(session: Any, **overrides: Any) -> bool:
    fields: dict[str, Any] = {
        "source": "yallakora",
        "kind": "team",
        "name": "نادى فيكينج",
        "competition": "دوري أبطال أوروبا",
        "context": CONTEXT,
    }
    fields.update(overrides)
    return record_unresolved(session, **fields)


def test_a_new_name_writes_one_open_row(sync_session) -> None:
    assert record(sync_session) is True

    [row] = rows(sync_session)
    assert row["source"] == "yallakora"
    assert row["kind"] == "team"
    assert row["name"] == "نادى فيكينج"
    assert row["name_norm"] == ar_normalize("نادى فيكينج")
    assert row["competition_norm"] == ar_normalize("دوري أبطال أوروبا")
    assert row["context"] == CONTEXT
    assert row["seen_count"] == 1
    assert row["state"] == "open"


def test_a_repeat_raises_the_count_and_refreshes_the_context(sync_session) -> None:
    record(sync_session)
    sync_session.execute(
        text("UPDATE unresolved_names SET last_seen_at = :old"), {"old": datetime(2026, 1, 1, tzinfo=UTC)}
    )

    assert record(sync_session, name="نادي فيكينج", context={"match_id": 8}) is True

    [row] = rows(sync_session)
    assert row["seen_count"] == 2
    assert row["context"] == {"match_id": 8}
    assert row["last_seen_at"] > datetime(2026, 1, 1, tzinfo=UTC)
    assert row["name"] == "نادى فيكينج"  # the first spelling stays what the editor sees


@pytest.mark.parametrize(
    "overrides",
    [
        {"source": "ysscores"},
        {"kind": "channel"},
        {"name": "فريق ثالث"},
        {"competition": "الدوري المصري"},
        {"competition": None},
    ],
)
def test_each_part_of_the_key_makes_its_own_row(sync_session, overrides: dict[str, Any]) -> None:
    record(sync_session)
    record(sync_session, **overrides)
    assert len(rows(sync_session)) == 2


def test_no_competition_is_the_empty_scope(sync_session) -> None:
    record(sync_session, kind="channel", competition=None)
    assert rows(sync_session)[0]["competition_norm"] == ""


@pytest.mark.parametrize("state", ["ignored", "mapped", "created"])
def test_a_decided_row_does_not_reopen(sync_session, state: str) -> None:
    record(sync_session)
    sync_session.execute(text("UPDATE unresolved_names SET state = :state, target_id = 1"), {"state": state})

    assert record(sync_session, context={"match_id": 99}) is False

    [row] = rows(sync_session)
    assert row["state"] == state
    assert row["seen_count"] == 1
    assert row["context"] == CONTEXT


def test_the_name_is_capped(sync_session) -> None:
    record(sync_session, name="ا" * 500)
    assert len(rows(sync_session)[0]["name"]) == MAX_NAME == 200


def test_a_name_that_normalizes_to_nothing_is_not_queued(sync_session) -> None:
    assert record(sync_session, name="   ") is False
    assert rows(sync_session) == []


def test_the_context_may_hold_a_datetime(sync_session) -> None:
    kickoff = datetime(2026, 11, 4, 15, 0, tzinfo=UTC)
    record(sync_session, context={"kickoff_at": kickoff})
    assert rows(sync_session)[0]["context"] == {"kickoff_at": kickoff.isoformat()}
