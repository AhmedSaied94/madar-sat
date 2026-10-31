"""Migrations: 0001 is schema.sql unchanged; 0002 adds the MVP schema and downgrades (T012)."""

from __future__ import annotations

import hashlib
from pathlib import Path

import psycopg
import pytest
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from alembic import command

BACKEND = Path(__file__).resolve().parents[2]
SQL_PATH = BACKEND / "alembic" / "sql" / "0001_base_schema.sql"
OLD_APP_SCHEMA = BACKEND.parent.parent / "old_app" / "migration" / "schema.sql"
# SHA-256 of ../old_app/migration/schema.sql, recorded when 0001 was copied (FR-001).
SCHEMA_SHA256 = "c0c9ff2617eee890f0507de73de8299daf68079b70b026543657e84380e2bcae"

DATASET_NAMES = {
    "matches",
    "live",
    "channels",
    "satellites",
    "competitions",
    "teams",
    "commentators",
    "rights_holders",
    "broadcast_presets",
    "sources",
}

# Every object revision 0002 adds (data-model "Revision 0002").
TABLES_0002 = {
    "admin_users",
    "admin_refresh_tokens",
    "audit_log",
    "devices",
    "device_follows",
    "notification_outbox",
    "dataset_versions",
}
COLUMNS_0002 = {
    *(
        f"matches.{c}"
        for c in (
            "status",
            "period",
            "minute",
            "home_score",
            "away_score",
            "home_pen",
            "away_pen",
            "status_source",
            "status_label",
            "status_updated_at",
            "time_tbd",
            "locked_fields",
        )
    ),
    "channels.locked_fields",
    "channels.frequency_changed_at",
    *(f"import_runs.{c}" for c in ("items_found", "items_upserted", "http_errors", "status", "raw_path")),
}
CONSTRAINTS_0002 = {
    *(
        f"ck_matches_{rule}"
        for rule in (
            "status",
            "period",
            "minute",
            "home_score",
            "away_score",
            "home_pen",
            "away_pen",
            "status_source",
            "status_label",
            "time_tbd",
            "locked_fields",
            "clock_no_score",
            "scores_pair",
        )
    ),
    "ck_channels_locked_fields",
    "ck_admin_users_role",
    "ck_admin_users_email_len",
    "ck_admin_users_name_len",
    "ck_audit_log_action",
    "ck_devices_platform",
    "ck_devices_push_token_len",
    "ck_devices_app_version_len",
    "ck_devices_locale_len",
    "ck_devices_tz_len",
    "ck_device_follows_one_target",
    "device_follows_unique",
    "ck_notification_outbox_type",
    "ck_notification_outbox_status",
    "ck_notification_outbox_dedupe_key_len",
    "ck_import_runs_status",
    "ck_dataset_versions_name",
}
INDEXES_0002 = {
    "matches_live_window_idx",
    "teams_name_norm_trgm_idx",
    "competitions_name_norm_trgm_idx",
    "channels_name_norm_trgm_idx",
    "commentators_name_norm_trgm_idx",
    "admin_users_email_lower_key",
    "admin_refresh_tokens_admin_user_id_idx",
    "audit_log_entity_idx",
    "audit_log_admin_user_id_idx",
    "notification_outbox_pending_due_idx",
    *(f"device_follows_{c}_idx" for c in ("team_id", "competition_id", "match_id", "channel_id", "commentator_id")),
}
TRIGGERS_0002 = {"admin_users_set_updated_at", "audit_log_forbid_delete"}

_CATALOG = {
    "tables": "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
    "columns": "SELECT table_name || '.' || column_name FROM information_schema.columns WHERE table_schema = 'public'",
    "constraints": "SELECT conname FROM pg_constraint WHERE connamespace = 'public'::regnamespace",
    "indexes": "SELECT indexname FROM pg_indexes WHERE schemaname = 'public'",
    "triggers": "SELECT tgname FROM pg_trigger WHERE NOT tgisinternal",
    "extensions": "SELECT extname FROM pg_extension",
}


def _schema(url: str) -> dict[str, set[str]]:
    with psycopg.connect(url) as conn:
        return {kind: {row[0] for row in conn.execute(sql)} for kind, sql in _CATALOG.items()}


def _alembic(url: str) -> Config:
    cfg = Config("alembic.ini")
    cfg.set_main_option("sqlalchemy.url", url.replace("postgresql://", "postgresql+psycopg://").replace("%", "%%"))
    return cfg


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_0001_sql_is_the_recorded_schema():
    assert _sha256(SQL_PATH) == SCHEMA_SHA256


def test_old_app_schema_still_matches_the_recorded_hash():
    if not OLD_APP_SCHEMA.exists():
        pytest.skip("sibling ../old_app is not checked out (CI)")
    assert _sha256(OLD_APP_SCHEMA) == SCHEMA_SHA256


def test_upgrade_on_an_empty_database_creates_every_0002_object_and_seeds_versions(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    schema = _schema(empty_database)
    assert TABLES_0002 <= schema["tables"]
    assert COLUMNS_0002 <= schema["columns"]
    assert CONSTRAINTS_0002 <= schema["constraints"]
    assert INDEXES_0002 <= schema["indexes"]
    assert TRIGGERS_0002 <= schema["triggers"]
    assert "pg_trgm" in schema["extensions"]
    with psycopg.connect(empty_database) as conn:
        versions = dict(conn.execute("SELECT name, version FROM dataset_versions").fetchall())
    assert versions == dict.fromkeys(DATASET_NAMES, 0)


def test_0002_downgrades_cleanly_and_upgrades_again(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "0001")

    schema = _schema(empty_database)
    assert not TABLES_0002 & schema["tables"]
    assert not COLUMNS_0002 & schema["columns"]
    assert not CONSTRAINTS_0002 & schema["constraints"]
    assert not INDEXES_0002 & schema["indexes"]
    assert not TRIGGERS_0002 & schema["triggers"]
    # 0001 is intact: its own tables and triggers are still there.
    assert {"matches", "channels", "import_runs"} <= schema["tables"]
    assert "matches_forbid_delete" in schema["triggers"]

    command.upgrade(cfg, "head")
    assert TABLES_0002 <= _schema(empty_database)["tables"]


def test_session_database_is_at_head(sync_session):
    assert sync_session.scalar(text("SELECT version_num FROM alembic_version")) == "0004"


@pytest.mark.parametrize(
    ("constraint", "sql"),
    [
        (
            "ck_matches_clock_no_score",
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, "
            "time_tbd, status_source, home_score, away_score) "
            "VALUES ('legacy', '2026-10-28', 'c', 'h', 'a', true, 'clock', 1, 0)",
        ),
        (
            "ck_matches_time_tbd",
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, "
            "time_tbd, kickoff_at) "
            "VALUES ('legacy', '2026-10-28', 'c', 'h', 'a', true, '2026-10-28T18:00:00Z')",
        ),
        (
            "ck_matches_locked_fields",
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, "
            "time_tbd, locked_fields) "
            "VALUES ('legacy', '2026-10-28', 'c', 'h', 'a', true, '{kickoff_at,no_such_column}')",
        ),
        (
            "ck_channels_locked_fields",
            "INSERT INTO channels (kind, name, locked_fields) VALUES ('platform', 'x', '{name,no_such_column}')",
        ),
        (
            "ck_device_follows_one_target",
            "WITH d AS (INSERT INTO devices (install_id, token_hash, platform) "
            "VALUES (gen_random_uuid(), repeat('a', 64), 'android') RETURNING id) "
            "INSERT INTO device_follows (device_id, team_id, competition_id) SELECT id, 1, 1 FROM d",
        ),
        (
            "ck_device_follows_one_target",
            "WITH d AS (INSERT INTO devices (install_id, token_hash, platform) "
            "VALUES (gen_random_uuid(), repeat('b', 64), 'web') RETURNING id) "
            "INSERT INTO device_follows (device_id) SELECT id FROM d",
        ),
        (
            "ck_notification_outbox_status",
            "INSERT INTO notification_outbox (type, dedupe_key, payload, audience, due_at, status) "
            "VALUES ('goal', 'k', '{}', '{}', now(), 'bogus')",
        ),
        ("ck_dataset_versions_name", "INSERT INTO dataset_versions (name) VALUES ('bogus')"),
    ],
)
def test_check_constraints_reject_bad_rows(sync_session, constraint, sql):
    with pytest.raises(IntegrityError) as exc_info, sync_session.begin_nested():
        sync_session.execute(text(sql))
    assert exc_info.value.orig.diag.constraint_name == constraint


def test_a_well_formed_feed_row_is_accepted(sync_session):
    sync_session.execute(
        text(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, "
            "kickoff_at, status, status_source, period, minute, home_score, away_score, locked_fields) "
            "VALUES ('legacy', '2026-10-28', 'c', 'h', 'a', '2026-10-28T18:00:00Z', "
            "'live', 'feed', '2H', '90+3', 1, 0, '{kickoff_at}')"
        )
    )


# --- Revision 0003: audit source and link origin (D2, data-model "Revision 0003") ---------------


def _seed_links(url: str) -> None:
    """Three links at revision 0002: a snapshot one, an importer's and an editor's (0001 seeds the sources)."""
    with psycopg.connect(url, autocommit=True) as conn:
        conn.execute(
            "INSERT INTO channels (kind, name) VALUES ('platform', 'c1'), ('platform', 'c2'), ('platform', 'c3')"
        )
        conn.execute(
            "INSERT INTO matches (source, match_date, competition_name, home_team_name, away_team_name, time_tbd) "
            "VALUES ('legacy', '2026-10-28', 'c', 'h', 'a', true)"
        )
        conn.execute(
            "INSERT INTO match_channels (match_id, channel_id, source) "
            "SELECT m.id, c.id, CASE c.name WHEN 'c1' THEN 'legacy' WHEN 'c2' THEN 'ysscores' ELSE 'manual' END "
            "FROM matches m, channels c"
        )


def test_0003_adds_the_two_columns_and_the_actor_check(empty_database):
    command.upgrade(_alembic(empty_database), "head")

    schema = _schema(empty_database)
    assert {"audit_log.source", "match_channels.imported_by"} <= schema["columns"]
    assert "ck_audit_log_actor" in schema["constraints"]
    with psycopg.connect(empty_database) as conn:
        references = conn.execute(
            "SELECT conrelid::regclass::text, confrelid::regclass::text FROM pg_constraint WHERE contype = 'f' "
            "AND conrelid IN ('audit_log'::regclass, 'match_channels'::regclass) AND confrelid = 'sources'::regclass"
        ).fetchall()
    assert {tuple(row) for row in references} >= {("audit_log", "sources"), ("match_channels", "sources")}


def test_0003_backfills_imported_by_from_source_except_manual(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "0002")
    _seed_links(empty_database)

    command.upgrade(cfg, "0003")

    with psycopg.connect(empty_database) as conn:
        rows = dict(
            conn.execute(
                "SELECT c.name, mc.imported_by FROM match_channels mc JOIN channels c ON c.id = mc.channel_id"
            ).fetchall()
        )
    assert rows == {"c1": "legacy", "c2": "ysscores", "c3": None}


def test_0003_downgrade_drops_both_columns_and_keeps_every_other_row(empty_database):
    cfg = _alembic(empty_database)
    command.upgrade(cfg, "0002")
    _seed_links(empty_database)
    command.upgrade(cfg, "head")
    with psycopg.connect(empty_database) as conn:
        before = conn.execute(
            "SELECT match_id, channel_id, source, is_hidden FROM match_channels ORDER BY 2"
        ).fetchall()

    command.downgrade(cfg, "0002")

    schema = _schema(empty_database)
    assert not {"audit_log.source", "match_channels.imported_by"} & schema["columns"]
    assert "ck_audit_log_actor" not in schema["constraints"]
    with psycopg.connect(empty_database) as conn:
        after = conn.execute("SELECT match_id, channel_id, source, is_hidden FROM match_channels ORDER BY 2").fetchall()
    assert after == before

    command.upgrade(cfg, "head")
    assert "audit_log.source" in _schema(empty_database)["columns"]


def test_audit_row_cannot_have_both_an_admin_and_a_source(sync_session):
    admin_id = sync_session.scalar(
        text(
            "INSERT INTO admin_users (email, name, role, password_hash) "
            "VALUES ('a@example.com', 'a', 'editor', 'x') RETURNING id"
        )
    )
    with pytest.raises(IntegrityError) as exc_info, sync_session.begin_nested():
        sync_session.execute(
            text(
                "INSERT INTO audit_log (admin_user_id, source, entity, action) "
                "VALUES (:admin, 'legacy', 'matches', 'update')"
            ),
            {"admin": admin_id},
        )
    assert exc_info.value.orig.diag.constraint_name == "ck_audit_log_actor"


def test_audit_row_may_name_a_source_alone_or_be_a_system_action(sync_session):
    sync_session.execute(text("INSERT INTO audit_log (source, entity, action) VALUES ('legacy', 'matches', 'update')"))
    sync_session.execute(text("INSERT INTO audit_log (entity, action) VALUES ('admin_users', 'create')"))
