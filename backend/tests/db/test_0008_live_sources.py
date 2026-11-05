"""Revision 0008: what the rules remember, the peak minute, stats and Goal.com's source row (031 T013)."""

from __future__ import annotations

import psycopg
import pytest
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from alembic import command
from app.schemas.admin import SourceItem

STATE_COLUMNS = {
    "score_first_source": "text",
    "score_changed_at": "timestamp with time zone",
    "drop_since": "timestamp with time zone",
    "status_drop_since": "timestamp with time zone",
    "fulltime_source": "text",
    "fulltime_since": "timestamp with time zone",
    "finish_wait_since": "timestamp with time zone",
}


def _alembic(url: str) -> Config:
    cfg = Config("alembic.ini")
    cfg.set_main_option("sqlalchemy.url", url.replace("postgresql://", "postgresql+psycopg://").replace("%", "%%"))
    return cfg


def _columns(conn: psycopg.Connection, table: str) -> dict[str, tuple[str, str]]:
    rows = conn.execute(
        "SELECT column_name, data_type, is_nullable FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = %s",
        (table,),
    ).fetchall()
    return {row[0]: (row[1], row[2]) for row in rows}


def test_upgrade_adds_nullable_columns_and_the_stats_table(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database) as conn:
        state = _columns(conn, "match_live_state")
        readings = _columns(conn, "match_source_readings")
        events = _columns(conn, "match_events")
        stats = _columns(conn, "match_stats")
        primary = conn.execute(
            "SELECT pg_get_constraintdef(oid) FROM pg_constraint "
            "WHERE conrelid = 'match_stats'::regclass AND contype = 'p'"
        ).fetchone()[0]
        foreign = [
            row[0]
            for row in conn.execute(
                "SELECT pg_get_constraintdef(oid) FROM pg_constraint "
                "WHERE conrelid = 'match_stats'::regclass AND contype = 'f'"
            )
        ]

    assert {name: state[name] for name in STATE_COLUMNS} == {
        name: (kind, "YES") for name, kind in STATE_COLUMNS.items()
    }
    assert readings["peak_minute"] == ("smallint", "YES")
    assert readings["peak_period"] == ("text", "YES")
    assert events["missing_since"] == ("timestamp with time zone", "YES")
    assert set(stats) == {"match_id", "source", "stats", "updated_at"}
    assert stats["stats"][0] == "jsonb"
    assert primary == "PRIMARY KEY (match_id, source)"
    assert any("REFERENCES matches(id) ON DELETE CASCADE" in row for row in foreign)


def test_candidate_stays_for_rollback(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database) as conn:
        assert "candidate" in _columns(conn, "match_live_state")


def test_the_goal_source_is_inside_what_the_previous_release_accepts(empty_database):
    """``SourceItem.kind``: the API before 0008 must keep answering on the migrated schema (B1-R1-8)."""
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database) as conn:
        kinds = dict(conn.execute("SELECT name, kind FROM sources").fetchall())

    assert kinds["goal"] == "internal"
    for name, kind in kinds.items():
        SourceItem(name=name, kind=kind, is_enabled=True)


def test_downgrade_removes_it_all_and_upgrade_returns_it(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "head")

    command.downgrade(cfg, "0007")
    with psycopg.connect(empty_database) as conn:
        assert not set(STATE_COLUMNS) & set(_columns(conn, "match_live_state"))
        assert "peak_minute" not in _columns(conn, "match_source_readings")
        assert "missing_since" not in _columns(conn, "match_events")
        assert _columns(conn, "match_stats") == {}
        assert conn.execute("SELECT count(*) FROM sources WHERE name = 'goal'").fetchone() == (0,)

    command.upgrade(cfg, "head")
    with psycopg.connect(empty_database) as conn:
        assert set(STATE_COLUMNS) <= set(_columns(conn, "match_live_state"))


def _fill_goal_rows(conn: psycopg.Connection) -> int:
    match = conn.execute(
        "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd) "
        "VALUES ('manual', '2026-11-04', 'كأس', 'أ', 'ب', true) RETURNING id"
    ).fetchone()[0]
    conn.execute("INSERT INTO match_external_ids (source, external_id, match_id) VALUES ('goal', 'x', %s)", (match,))
    conn.execute(
        "INSERT INTO match_events (match_id, side, type, minute, source, external_id) "
        "VALUES (%s, 'home', 'goal', '23', 'goal', 'g')",
        (match,),
    )
    conn.execute(
        "INSERT INTO match_lineups (match_id, side, players, source) VALUES (%s, 'home', '[]', 'goal')", (match,)
    )
    conn.execute(
        "INSERT INTO match_source_readings (match_id, source, read_at, changed_at) VALUES (%s, 'goal', now(), now())",
        (match,),
    )
    conn.execute("INSERT INTO match_stats (match_id, source, stats) VALUES (%s, 'goal', '[]')", (match,))
    conn.execute("INSERT INTO live_source_state (source) VALUES ('goal')")
    conn.execute(
        "INSERT INTO unresolved_names (source, kind, name, name_norm, first_seen_at, last_seen_at) "
        "VALUES ('goal', 'team', 'أ', 'ا', now(), now())"
    )
    return match


def test_downgrade_keeps_other_rows_and_clears_only_goal_coms(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "head")
    with psycopg.connect(empty_database, autocommit=True) as conn:
        match = _fill_goal_rows(conn)
        conn.execute(
            "INSERT INTO match_events (match_id, side, type, minute, source, external_id) "
            "VALUES (%s, 'home', 'goal', '23', 'filgoal', 'f')",
            (match,),
        )

    command.downgrade(cfg, "0007")

    with psycopg.connect(empty_database) as conn:
        assert conn.execute("SELECT source FROM match_events").fetchall() == [("filgoal",)]
        assert conn.execute("SELECT count(*) FROM matches").fetchone() == (1,)
        assert conn.execute("SELECT count(*) FROM sources WHERE name = 'goal'").fetchone() == (0,)


def test_upgrade_and_downgrade_keep_existing_rows(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "0007")
    with psycopg.connect(empty_database, autocommit=True) as conn:
        match = conn.execute(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd) "
            "VALUES ('manual', '2026-11-04', 'كأس', 'أ', 'ب', true) RETURNING id"
        ).fetchone()[0]
        conn.execute(
            "INSERT INTO match_live_state (match_id, confirmed_home, confirmed_away) VALUES (%s, 1, 0)", (match,)
        )

    command.upgrade(cfg, "head")
    with psycopg.connect(empty_database) as conn:
        assert conn.execute(
            "SELECT confirmed_home, confirmed_away, drop_since, score_changed_at FROM match_live_state"
        ).fetchall() == [(1, 0, None, None)]

    command.downgrade(cfg, "0007")
    with psycopg.connect(empty_database) as conn:
        assert conn.execute("SELECT confirmed_home FROM match_live_state").fetchall() == [(1,)]


def test_a_match_has_one_stats_row_per_source(sync_session):
    match = sync_session.execute(
        text(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd) "
            "VALUES ('manual', '2026-11-04', 'كأس', 'أ', 'ب', true) RETURNING id"
        )
    ).scalar_one()
    insert = text("INSERT INTO match_stats (match_id, source, stats) VALUES (:m, 'goal', '[]')")
    sync_session.execute(insert, {"m": match})

    with pytest.raises(IntegrityError), sync_session.begin_nested():
        sync_session.execute(insert, {"m": match})
