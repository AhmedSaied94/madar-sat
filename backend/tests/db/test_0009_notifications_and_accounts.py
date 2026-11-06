"""Revision 0009: the notification history, staff accounts and the broadcast lock (T003, data-model)."""

from __future__ import annotations

from pathlib import Path

import psycopg
import pytest
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from alembic import command

NEW_TABLES = {"channel_frequency_changes", "match_channel_changes"}
NEW_COLUMNS = {
    "notification_outbox.error": "text",
    "notification_outbox.audit_log_id": "bigint",
    "match_live_state.push_memory": "jsonb",
    "admin_users.must_change_password": "boolean",
    "admin_users.test_device_id": "bigint",
}
FREQUENCY_COLUMNS = {
    "old_frequency_mhz": "integer",
    "new_frequency_mhz": "integer",
    "old_polarization": "character",
    "new_polarization": "character",
    "old_symbol_rate": "integer",
    "new_symbol_rate": "integer",
}


def _alembic(url: str) -> Config:
    cfg = Config("alembic.ini")
    cfg.set_main_option("sqlalchemy.url", url.replace("postgresql://", "postgresql+psycopg://").replace("%", "%%"))
    return cfg


def _columns(conn: psycopg.Connection, table: str) -> dict[str, tuple[str, str | None]]:
    rows = conn.execute(
        "SELECT column_name, data_type, column_default FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = %s",
        (table,),
    ).fetchall()
    return {row[0]: (row[1], row[2]) for row in rows}


def _nullability(conn: psycopg.Connection, table: str) -> dict[str, str]:
    rows = conn.execute(
        "SELECT column_name, is_nullable FROM information_schema.columns "
        "WHERE table_schema = 'public' AND table_name = %s",
        (table,),
    ).fetchall()
    return {row[0]: row[1] for row in rows}


def _constraint(conn: psycopg.Connection, table: str, kind: str) -> dict[str, str]:
    rows = conn.execute(
        "SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = %s::regclass AND contype = %s",
        (table, kind),
    ).fetchall()
    return {row[0]: row[1] for row in rows}


def test_upgrade_adds_every_table_and_column(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database) as conn:
        tables = {
            row[0]
            for row in conn.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        }
        columns = {
            f"{table}.{name}": data_type
            for table in ("notification_outbox", "match_live_state", "admin_users")
            for name, (data_type, _) in _columns(conn, table).items()
        }
        frequency = {name: kind for name, (kind, _) in _columns(conn, "channel_frequency_changes").items()}
        frequency_null = _nullability(conn, "channel_frequency_changes")
        outbox_null = _nullability(conn, "notification_outbox")
        admin_null = _nullability(conn, "admin_users")
        state_null = _nullability(conn, "match_live_state")
        versions = {row[0] for row in conn.execute("SELECT name FROM dataset_versions")}

    assert NEW_TABLES <= tables
    assert {name: columns[name] for name in NEW_COLUMNS} == NEW_COLUMNS
    assert {name: frequency[name] for name in FREQUENCY_COLUMNS} == FREQUENCY_COLUMNS
    assert outbox_null["error"] == "YES"
    assert outbox_null["audit_log_id"] == "YES"
    assert admin_null["must_change_password"] == "NO"
    assert admin_null["test_device_id"] == "YES"
    assert state_null["push_memory"] == "NO"
    assert {"outbox", "admin_users"} <= versions
    assert frequency_null["outbox_id"] == "YES"


def test_new_columns_default_existing_rows(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "0008")
    with psycopg.connect(empty_database, autocommit=True) as conn:
        conn.execute(
            "INSERT INTO admin_users (email, name, role, password_hash) VALUES ('a@example.com', 'a', 'editor', 'x')"
        )
        conn.execute(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd) "
            "VALUES ('legacy', '2026-11-06', 'c', 'h', 'a', true)"
        )
        conn.execute(
            "INSERT INTO match_live_state (match_id) SELECT id FROM matches",
        )

    command.upgrade(cfg, "head")

    with psycopg.connect(empty_database) as conn:
        must_change = conn.execute("SELECT must_change_password FROM admin_users").fetchall()
        memory = conn.execute("SELECT push_memory FROM match_live_state").fetchall()
    assert must_change == [(False,)]
    assert memory == [({},)]


def test_match_channel_changes_refuses_a_second_row_per_direction(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database, autocommit=True) as conn:
        conn.execute("INSERT INTO channels (kind, name) VALUES ('platform', 'c1')")
        conn.execute(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd) "
            "VALUES ('legacy', '2026-11-06', 'c', 'h', 'a', true)"
        )
        conn.execute(
            "INSERT INTO match_channel_changes (match_id, channel_id, action, source) "
            "SELECT m.id, c.id, 'added', 'admin' FROM matches m, channels c"
        )
        with pytest.raises(psycopg.errors.UniqueViolation):
            conn.execute(
                "INSERT INTO match_channel_changes (match_id, channel_id, action, source) "
                "SELECT m.id, c.id, 'added', 'admin' FROM matches m, channels c"
            )
        with pytest.raises(psycopg.errors.CheckViolation):
            conn.execute(
                "INSERT INTO match_channel_changes (match_id, channel_id, action, source) "
                "SELECT m.id, c.id, 'bogus', 'admin' FROM matches m, channels c"
            )


def test_frequency_history_keeps_rows_when_its_parents_go(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database, autocommit=True) as conn:
        conn.execute("INSERT INTO channels (kind, name) VALUES ('platform', 'c1')")
        conn.execute(
            "INSERT INTO notification_outbox (type, dedupe_key, payload, audience, due_at, status) "
            "VALUES ('frequency_changed', 'frequency_changed:1:1', '{}', '{}', now(), 'sent')"
        )
        channel_id = conn.execute("SELECT id FROM channels").fetchone()[0]
        audit_id = conn.execute(
            "INSERT INTO audit_log (entity, entity_id, action, diff) VALUES ('channel', 1, 'update', '{}') RETURNING id"
        ).fetchone()[0]
        conn.execute(
            "INSERT INTO channel_frequency_changes (channel_id, old_frequency_mhz, new_frequency_mhz, "
            "old_polarization, new_polarization, old_symbol_rate, new_symbol_rate, source, outbox_id, "
            "audit_log_id, detected_at) SELECT %s, 11766, 11843, 'H', 'H', 27500, 27500, 'admin', o.id, %s, now() "
            "FROM notification_outbox o",
            (channel_id, audit_id),
        )
        with pytest.raises(psycopg.errors.UniqueViolation):
            conn.execute(
                "INSERT INTO channel_frequency_changes (channel_id, old_frequency_mhz, new_frequency_mhz, "
                "old_polarization, new_polarization, old_symbol_rate, new_symbol_rate, source, outbox_id, "
                "detected_at) SELECT %s, 11766, 11843, 'H', 'H', 27500, 27500, 'admin', o.id, now() "
                "FROM notification_outbox o",
                (channel_id,),
            )
        conn.execute("DELETE FROM notification_outbox")
        after = conn.execute("SELECT outbox_id, audit_log_id FROM channel_frequency_changes").fetchall()
        foreign = {
            row[0]: row[1]
            for row in conn.execute(
                "SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint "
                "WHERE conrelid = 'channel_frequency_changes'::regclass AND contype = 'f'"
            )
        }

    # ``audit_log`` forbids deletes, so its SET NULL is asserted from the definition.
    assert sum("ON DELETE SET NULL" in definition for definition in foreign.values()) == 2
    assert after == [(None, audit_id)]


def test_the_wider_checks_accept_the_new_values(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database) as conn:
        checks = {
            "matches": _constraint(conn, "matches", "c"),
            "import_runs": _constraint(conn, "import_runs", "c"),
            "dataset_versions": _constraint(conn, "dataset_versions", "c"),
        }

    assert "broadcasts" in checks["matches"]["ck_matches_locked_fields"]
    assert "stopped" in checks["import_runs"]["ck_import_runs_status"]
    assert "outbox" in checks["dataset_versions"]["ck_dataset_versions_name"]
    assert "admin_users" in checks["dataset_versions"]["ck_dataset_versions_name"]


def test_a_stopped_run_and_a_locked_broadcast_are_stored(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    with psycopg.connect(empty_database) as conn:
        conn.execute(
            "INSERT INTO import_runs (source, started_at, status, error) "
            "VALUES ('legacy', now(), 'stopped', 'budget_reached')"
        )
        conn.execute(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd, "
            "locked_fields) VALUES ('legacy', '2026-11-06', 'c', 'h', 'a', true, '{broadcasts}')"
        )
        conn.commit()
        run = conn.execute("SELECT status, error FROM import_runs").fetchone()
        locked = conn.execute("SELECT locked_fields FROM matches").fetchone()[0]

    assert run == ("stopped", "budget_reached")
    assert locked == ["broadcasts"]


def test_downgrade_rewrites_stopped_runs_and_strips_broadcasts(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "head")
    with psycopg.connect(empty_database, autocommit=True) as conn:
        conn.execute("INSERT INTO import_runs (source, started_at, status) VALUES ('legacy', now(), 'stopped')")
        conn.execute(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd, "
            "locked_fields) VALUES ('legacy', '2026-11-06', 'c', 'h', 'a', true, '{broadcasts,status}')"
        )

    command.downgrade(cfg, "0008")

    with psycopg.connect(empty_database) as conn:
        run = conn.execute("SELECT status FROM import_runs").fetchone()[0]
        locked = conn.execute("SELECT locked_fields FROM matches").fetchone()[0]
        checks = _constraint(conn, "import_runs", "c")
        match_checks = _constraint(conn, "matches", "c")
        tables = {
            row[0]
            for row in conn.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        }
        columns = {
            f"{table}.{name}"
            for table in ("notification_outbox", "match_live_state", "admin_users")
            for name in _columns(conn, table)
        }
        versions = {row[0] for row in conn.execute("SELECT name FROM dataset_versions")}

    assert run == "failed"
    assert locked == ["status"]
    assert "stopped" not in checks["ck_import_runs_status"]
    assert "broadcasts" not in match_checks["ck_matches_locked_fields"]
    assert not NEW_TABLES & tables
    assert not set(NEW_COLUMNS) & columns
    assert not {"outbox", "admin_users"} & versions


def test_upgrade_after_a_downgrade_restores_everything(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "0008")
    command.upgrade(cfg, "head")

    with psycopg.connect(empty_database) as conn:
        tables = {
            row[0]
            for row in conn.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
        }
        checks = _constraint(conn, "import_runs", "c")
    assert NEW_TABLES <= tables
    assert "stopped" in checks["ck_import_runs_status"]


SNAPSHOT_DIR = Path(__file__).resolve().parents[1] / "fixtures" / "snapshot"

COUNTED_TABLES = {
    "channels": "SELECT count(*) FROM channels",
    "matches": "SELECT count(*) FROM matches",
    "match_channels": "SELECT count(*) FROM match_channels",
    "satellites": "SELECT count(*) FROM satellites",
}


def _counts(conn: psycopg.Connection) -> dict[str, int]:
    return {name: conn.execute(sql).fetchone()[0] for name, sql in COUNTED_TABLES.items()}


def test_the_snapshot_fixture_survives_up_and_down(empty_database):
    """The committed snapshot loads on 0008, and 0009 neither refuses a row nor loses one."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import Session

    from app.etl.report import Report
    from app.etl.snapshot import load
    from app.etl.types import read_snapshot

    cfg = _alembic(empty_database)
    command.upgrade(cfg, "0008")
    engine = create_engine(empty_database.replace("postgresql://", "postgresql+psycopg://"))
    try:
        with Session(engine) as session:
            load(session, read_snapshot(str(SNAPSHOT_DIR)), Report("load-snapshot", str(SNAPSHOT_DIR)))
            session.commit()
    finally:
        engine.dispose()

    with psycopg.connect(empty_database) as conn:
        before = _counts(conn)

    command.upgrade(cfg, "head")
    command.downgrade(cfg, "0008")
    command.upgrade(cfg, "head")

    with psycopg.connect(empty_database) as conn:
        after = _counts(conn)
        version = conn.execute("SELECT version_num FROM alembic_version").fetchone()[0]

    assert after == before
    assert version == "0009"


def test_the_session_database_is_at_head(sync_session):
    assert sync_session.scalar(text("SELECT version_num FROM alembic_version")) == "0009"


def test_the_database_refuses_a_broadcast_outside_the_locked_list(sync_session):
    with pytest.raises(IntegrityError) as exc_info, sync_session.begin_nested():
        sync_session.execute(
            text(
                "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, "
                "time_tbd, locked_fields) VALUES ('legacy', '2026-11-06', 'c', 'h', 'a', true, '{bogus}')"
            )
        )
    assert exc_info.value.orig.diag.constraint_name == "ck_matches_locked_fields"
