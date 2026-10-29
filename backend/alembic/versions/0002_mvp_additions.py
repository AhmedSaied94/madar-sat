"""0002: the D1 MVP additions (data-model "Revision 0002").

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-29

Every statement is additive (expand/contract). ``matches.is_live`` stays until the
status backfill is proven. CHECK constraints are named ``ck_<table>_<rule>``; other
constraints keep PostgreSQL's default names.
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

_MATCH_STATUSES = (
    "scheduled",
    "live",
    "halftime",
    "extra_time",
    "penalties",
    "finished",
    "postponed",
    "cancelled",
    "abandoned",
)
_MATCH_LOCKABLE = (
    "kickoff_at",
    "competition_id",
    "competition_name",
    "competition_stage",
    "home_team_id",
    "home_team_name",
    "home_logo_asset_id",
    "away_team_id",
    "away_team_name",
    "away_logo_asset_id",
    "stadium",
    "commentator_id",
    "status",
    "home_score",
    "away_score",
    "home_pen",
    "away_pen",
)
_CHANNEL_LOCKABLE = (
    "name",
    "display_name",
    "logo_asset_id",
    "category",
    "country",
    "satellite_id",
    "frequency_mhz",
    "polarization",
    "symbol_rate",
    "frequency_note",
    "access",
    "provider",
    "package",
    "beam",
    "show_in_match",
    "sort_order",
)
_DATASET_NAMES = (
    "matches",
    "live",
    "channels",
    "satellites",
    "competitions",
    "teams",
    "commentators",
    "rights_holders",
)


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # --- matches: status and protection -------------------------------------
    op.execute("ALTER TABLE matches ADD COLUMN status text NOT NULL DEFAULT 'scheduled'")
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_status "
        f"CHECK (status IN ({', '.join(chr(39) + s + chr(39) for s in _MATCH_STATUSES)}))"
    )
    op.execute("ALTER TABLE matches ADD COLUMN period text")
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_period "
        "CHECK (period IN ('1H', '2H', 'ET1', 'ET2') OR period IS NULL)"
    )
    op.execute("ALTER TABLE matches ADD COLUMN minute text")
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_minute "
        "CHECK (minute IS NULL OR minute ~ '^\\d{1,3}(\\+\\d{1,2})?$')"
    )
    op.execute("ALTER TABLE matches ADD COLUMN home_score smallint")
    op.execute("ALTER TABLE matches ADD COLUMN away_score smallint")
    op.execute("ALTER TABLE matches ADD COLUMN home_pen smallint")
    op.execute("ALTER TABLE matches ADD COLUMN away_pen smallint")
    op.execute("ALTER TABLE matches ADD CONSTRAINT ck_matches_home_score CHECK (home_score IS NULL OR home_score >= 0)")
    op.execute("ALTER TABLE matches ADD CONSTRAINT ck_matches_away_score CHECK (away_score IS NULL OR away_score >= 0)")
    op.execute("ALTER TABLE matches ADD CONSTRAINT ck_matches_home_pen CHECK (home_pen IS NULL OR home_pen >= 0)")
    op.execute("ALTER TABLE matches ADD CONSTRAINT ck_matches_away_pen CHECK (away_pen IS NULL OR away_pen >= 0)")
    op.execute("ALTER TABLE matches ADD COLUMN status_source text NOT NULL DEFAULT 'clock'")
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_status_source "
        "CHECK (status_source IN ('feed', 'manual', 'clock'))"
    )
    op.execute("ALTER TABLE matches ADD COLUMN status_label text")
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_status_label "
        "CHECK (status_label IS NULL OR length(status_label) <= 120)"
    )
    op.execute("ALTER TABLE matches ADD COLUMN status_updated_at timestamptz")
    op.execute("ALTER TABLE matches ADD COLUMN time_tbd boolean NOT NULL DEFAULT false")
    op.execute("ALTER TABLE matches ADD CONSTRAINT ck_matches_time_tbd CHECK (time_tbd = (kickoff_at IS NULL))")
    op.execute("ALTER TABLE matches ADD COLUMN locked_fields text[] NOT NULL DEFAULT '{}'")
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_locked_fields "
        f"CHECK (locked_fields <@ ARRAY[{', '.join(chr(39) + c + chr(39) for c in _MATCH_LOCKABLE)}]::text[])"
    )
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_clock_no_score CHECK ("
        "status_source <> 'clock' OR ("
        "status = 'scheduled' AND home_score IS NULL AND away_score IS NULL AND "
        "home_pen IS NULL AND away_pen IS NULL AND minute IS NULL AND period IS NULL))"
    )
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_scores_pair CHECK ("
        "(home_score IS NULL) = (away_score IS NULL) AND (home_pen IS NULL) = (away_pen IS NULL))"
    )
    op.execute(
        "CREATE INDEX matches_live_window_idx ON matches (kickoff_at) "
        "WHERE status NOT IN ('finished', 'cancelled', 'abandoned')"
    )

    # --- channels: locked fields --------------------------------------------
    op.execute("ALTER TABLE channels ADD COLUMN locked_fields text[] NOT NULL DEFAULT '{}'")
    op.execute(
        "ALTER TABLE channels ADD CONSTRAINT ck_channels_locked_fields "
        f"CHECK (locked_fields <@ ARRAY[{', '.join(chr(39) + c + chr(39) for c in _CHANNEL_LOCKABLE)}]::text[])"
    )
    op.execute("ALTER TABLE channels ADD COLUMN frequency_changed_at timestamptz")

    # --- search indexes ------------------------------------------------------
    op.execute("CREATE INDEX teams_name_norm_trgm_idx ON teams USING gin (name_norm gin_trgm_ops)")
    op.execute("CREATE INDEX competitions_name_norm_trgm_idx ON competitions USING gin (name_norm gin_trgm_ops)")
    op.execute("CREATE INDEX channels_name_norm_trgm_idx ON channels USING gin (name_norm gin_trgm_ops)")
    op.execute("CREATE INDEX commentators_name_norm_trgm_idx ON commentators USING gin (name_norm gin_trgm_ops)")

    # --- admin_users ---------------------------------------------------------
    op.execute(
        "CREATE TABLE admin_users ("
        "id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, "
        "email text NOT NULL, "
        "name text NOT NULL, "
        "role text NOT NULL, "
        "password_hash text NOT NULL, "
        "is_active boolean NOT NULL DEFAULT true, "
        "last_login_at timestamptz, "
        "created_at timestamptz NOT NULL DEFAULT now(), "
        "updated_at timestamptz NOT NULL DEFAULT now(), "
        "CONSTRAINT ck_admin_users_role CHECK (role IN ('editor', 'admin')), "
        "CONSTRAINT ck_admin_users_email_len CHECK (length(email) <= 254), "
        "CONSTRAINT ck_admin_users_name_len CHECK (length(name) <= 80))"
    )
    op.execute("CREATE UNIQUE INDEX admin_users_email_lower_key ON admin_users (lower(email))")
    op.execute(
        "CREATE TRIGGER admin_users_set_updated_at BEFORE UPDATE ON admin_users "
        "FOR EACH ROW EXECUTE FUNCTION set_updated_at()"
    )

    # --- admin_refresh_tokens ------------------------------------------------
    op.execute(
        "CREATE TABLE admin_refresh_tokens ("
        "id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, "
        "admin_user_id bigint NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE, "
        "token_hash char(64) NOT NULL UNIQUE, "
        "family_id uuid NOT NULL, "
        "expires_at timestamptz NOT NULL, "
        "revoked_at timestamptz, "
        "replaced_by_id bigint REFERENCES admin_refresh_tokens(id), "
        "created_at timestamptz NOT NULL DEFAULT now())"
    )
    op.execute("CREATE INDEX admin_refresh_tokens_admin_user_id_idx ON admin_refresh_tokens (admin_user_id)")

    # --- audit_log -----------------------------------------------------------
    op.execute(
        "CREATE TABLE audit_log ("
        "id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, "
        "admin_user_id bigint REFERENCES admin_users(id) ON DELETE SET NULL, "
        "entity text NOT NULL, "
        "entity_id bigint, "
        "action text NOT NULL, "
        "diff jsonb NOT NULL DEFAULT '{}', "
        "created_at timestamptz NOT NULL DEFAULT now(), "
        "CONSTRAINT ck_audit_log_action CHECK (action IN ('create', 'update', 'delete', 'merge', 'bulk')))"
    )
    op.execute("CREATE INDEX audit_log_entity_idx ON audit_log (entity, entity_id, created_at DESC)")
    op.execute("CREATE INDEX audit_log_admin_user_id_idx ON audit_log (admin_user_id, created_at DESC)")
    op.execute(
        "CREATE TRIGGER audit_log_forbid_delete BEFORE DELETE ON audit_log "
        "FOR EACH ROW EXECUTE FUNCTION forbid_delete()"
    )

    # --- devices -------------------------------------------------------------
    op.execute(
        "CREATE TABLE devices ("
        "id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, "
        "install_id uuid NOT NULL UNIQUE, "
        "token_hash char(64) NOT NULL UNIQUE, "
        "platform text NOT NULL, "
        "push_token text UNIQUE, "
        "app_version text, "
        "locale text, "
        "tz text, "
        "prefs jsonb NOT NULL DEFAULT '{}', "
        "created_at timestamptz NOT NULL DEFAULT now(), "
        "last_seen_at timestamptz NOT NULL DEFAULT now(), "
        "CONSTRAINT ck_devices_platform CHECK (platform IN ('android', 'ios', 'web')), "
        "CONSTRAINT ck_devices_push_token_len CHECK (push_token IS NULL OR length(push_token) <= 4096), "
        "CONSTRAINT ck_devices_app_version_len CHECK (app_version IS NULL OR length(app_version) <= 32), "
        "CONSTRAINT ck_devices_locale_len CHECK (locale IS NULL OR length(locale) <= 16), "
        "CONSTRAINT ck_devices_tz_len CHECK (tz IS NULL OR length(tz) <= 64))"
    )

    # --- device_follows ------------------------------------------------------
    op.execute(
        "CREATE TABLE device_follows ("
        "device_id bigint NOT NULL REFERENCES devices(id) ON DELETE CASCADE, "
        "team_id bigint REFERENCES teams(id) ON DELETE CASCADE, "
        "competition_id bigint REFERENCES competitions(id) ON DELETE CASCADE, "
        "match_id bigint REFERENCES matches(id), "
        "channel_id bigint REFERENCES channels(id) ON DELETE CASCADE, "
        "commentator_id bigint REFERENCES commentators(id) ON DELETE CASCADE, "
        "created_at timestamptz NOT NULL DEFAULT now(), "
        "CONSTRAINT ck_device_follows_one_target CHECK ("
        "num_nonnulls(team_id, competition_id, match_id, channel_id, commentator_id) = 1), "
        "CONSTRAINT device_follows_unique UNIQUE NULLS NOT DISTINCT "
        "(device_id, team_id, competition_id, match_id, channel_id, commentator_id))"
    )
    for col in ("team_id", "competition_id", "match_id", "channel_id", "commentator_id"):
        op.execute(f"CREATE INDEX device_follows_{col}_idx ON device_follows ({col}) WHERE {col} IS NOT NULL")

    # --- notification_outbox -------------------------------------------------
    op.execute(
        "CREATE TABLE notification_outbox ("
        "id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, "
        "type text NOT NULL, "
        "dedupe_key text NOT NULL UNIQUE, "
        "payload jsonb NOT NULL, "
        "audience jsonb NOT NULL, "
        "due_at timestamptz NOT NULL, "
        "status text NOT NULL DEFAULT 'pending', "
        "sent integer NOT NULL DEFAULT 0, "
        "failed integer NOT NULL DEFAULT 0, "
        "created_at timestamptz NOT NULL DEFAULT now(), "
        "sent_at timestamptz, "
        "CONSTRAINT ck_notification_outbox_type CHECK (type IN ("
        "'kickoff_reminder', 'match_started', 'goal', 'final_score', "
        "'channels_updated', 'frequency_changed', 'announcement')), "
        "CONSTRAINT ck_notification_outbox_dedupe_key_len CHECK (length(dedupe_key) <= 200), "
        "CONSTRAINT ck_notification_outbox_status "
        "CHECK (status IN ('pending', 'sending', 'sent', 'failed', 'cancelled')))"
    )
    op.execute(
        "CREATE INDEX notification_outbox_pending_due_idx ON notification_outbox (due_at) WHERE status = 'pending'"
    )

    # --- import_runs: new columns -------------------------------------------
    op.execute("ALTER TABLE import_runs ADD COLUMN items_found integer NOT NULL DEFAULT 0")
    op.execute("ALTER TABLE import_runs ADD COLUMN items_upserted integer NOT NULL DEFAULT 0")
    op.execute("ALTER TABLE import_runs ADD COLUMN http_errors integer NOT NULL DEFAULT 0")
    op.execute("ALTER TABLE import_runs ADD COLUMN status text NOT NULL DEFAULT 'running'")
    op.execute(
        "ALTER TABLE import_runs ADD CONSTRAINT ck_import_runs_status "
        "CHECK (status IN ('running', 'succeeded', 'partial', 'failed'))"
    )
    op.execute("ALTER TABLE import_runs ADD COLUMN raw_path text")

    # --- dataset_versions ----------------------------------------------------
    op.execute(
        "CREATE TABLE dataset_versions ("
        "name text PRIMARY KEY, "
        "version bigint NOT NULL DEFAULT 0, "
        "updated_at timestamptz NOT NULL DEFAULT now(), "
        "CONSTRAINT ck_dataset_versions_name "
        f"CHECK (name IN ({', '.join(chr(39) + n + chr(39) for n in _DATASET_NAMES)})))"
    )
    op.get_bind().execute(
        sa.text("INSERT INTO dataset_versions (name, version) VALUES (:name, 0)"),
        [{"name": name} for name in _DATASET_NAMES],
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS dataset_versions")

    op.execute("ALTER TABLE import_runs DROP COLUMN IF EXISTS raw_path")
    op.execute("ALTER TABLE import_runs DROP CONSTRAINT IF EXISTS ck_import_runs_status")
    op.execute("ALTER TABLE import_runs DROP COLUMN IF EXISTS status")
    op.execute("ALTER TABLE import_runs DROP COLUMN IF EXISTS http_errors")
    op.execute("ALTER TABLE import_runs DROP COLUMN IF EXISTS items_upserted")
    op.execute("ALTER TABLE import_runs DROP COLUMN IF EXISTS items_found")

    op.execute("DROP TABLE IF EXISTS notification_outbox")
    op.execute("DROP TABLE IF EXISTS device_follows")
    op.execute("DROP TABLE IF EXISTS devices")
    op.execute("DROP TABLE IF EXISTS audit_log")
    op.execute("DROP TABLE IF EXISTS admin_refresh_tokens")
    op.execute("DROP TABLE IF EXISTS admin_users")

    op.execute("DROP INDEX IF EXISTS commentators_name_norm_trgm_idx")
    op.execute("DROP INDEX IF EXISTS channels_name_norm_trgm_idx")
    op.execute("DROP INDEX IF EXISTS competitions_name_norm_trgm_idx")
    op.execute("DROP INDEX IF EXISTS teams_name_norm_trgm_idx")

    op.execute("ALTER TABLE channels DROP COLUMN IF EXISTS frequency_changed_at")
    op.execute("ALTER TABLE channels DROP CONSTRAINT IF EXISTS ck_channels_locked_fields")
    op.execute("ALTER TABLE channels DROP COLUMN IF EXISTS locked_fields")

    op.execute("DROP INDEX IF EXISTS matches_live_window_idx")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_scores_pair")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_clock_no_score")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_locked_fields")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS locked_fields")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_time_tbd")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS time_tbd")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS status_updated_at")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_status_label")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS status_label")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_status_source")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS status_source")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_away_pen")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_home_pen")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_away_score")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_home_score")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS away_pen")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS home_pen")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS away_score")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS home_score")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_minute")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS minute")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_period")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS period")
    op.execute("ALTER TABLE matches DROP CONSTRAINT IF EXISTS ck_matches_status")
    op.execute("ALTER TABLE matches DROP COLUMN IF EXISTS status")
