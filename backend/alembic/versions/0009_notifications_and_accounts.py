"""0009: the notification history, staff accounts and the lockable broadcast slots (D6, Lane B1).

Revision ID: 0009
Revises: 0008
Create Date: 2026-11-06

Expand-only: new tables, nullable columns, two wider CHECKs and two new dataset names, so the
release before this revision keeps running against it (constitution, Migrations).

- ``channel_frequency_changes``: what followers of a carriage were told, written when a hold ends,
  so a typo fixed inside the hold leaves no public trace (research R6);
- ``match_channel_changes``: the links fans could see being added or removed, one row per direction
  per channel per match (R5);
- ``notification_outbox.error``: the short reason a row failed or was cancelled (R9);
- ``notification_outbox.audit_log_id``: the save behind a push, for A17 (R20);
- ``match_live_state.push_memory``: the goal bar's memory (R2);
- ``admin_users.must_change_password``, ``admin_users.test_device_id``: temporary passwords and the
  test device (R19);
- ``matches.ck_matches_locked_fields`` gains ``broadcasts``, and ``import_runs.status`` gains
  ``stopped`` (R22, R23).
"""

from __future__ import annotations

from alembic import op

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None

DATASETS_BEFORE = (
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
    "unresolved_names",
)
DATASETS_AFTER = (*DATASETS_BEFORE, "outbox", "admin_users")

LOCKABLE_BEFORE = (
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
    "local_broadcaster_eg",
)
LOCKABLE_AFTER = (*LOCKABLE_BEFORE, "broadcasts")

RUN_STATUSES_BEFORE = ("running", "succeeded", "partial", "failed")
RUN_STATUSES_AFTER = (*RUN_STATUSES_BEFORE, "stopped")


def _in(names: tuple[str, ...]) -> str:
    return ", ".join(f"'{name}'" for name in names)


def _set_datasets(names: tuple[str, ...]) -> None:
    op.execute("ALTER TABLE dataset_versions DROP CONSTRAINT ck_dataset_versions_name")
    op.execute(f"ALTER TABLE dataset_versions ADD CONSTRAINT ck_dataset_versions_name CHECK (name IN ({_in(names)}))")


def _set_lockable(names: tuple[str, ...]) -> None:
    op.execute("ALTER TABLE matches DROP CONSTRAINT ck_matches_locked_fields")
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_locked_fields "
        f"CHECK (locked_fields <@ ARRAY[{_in(names)}]::text[])"
    )


def _set_run_statuses(names: tuple[str, ...]) -> None:
    op.execute("ALTER TABLE import_runs DROP CONSTRAINT ck_import_runs_status")
    op.execute(f"ALTER TABLE import_runs ADD CONSTRAINT ck_import_runs_status CHECK (status IN ({_in(names)}))")


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE channel_frequency_changes (
          id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
          channel_id        bigint NOT NULL REFERENCES channels (id) ON DELETE CASCADE,
          old_frequency_mhz frequency_mhz NOT NULL,
          new_frequency_mhz frequency_mhz NOT NULL,
          old_polarization  polarization NOT NULL,
          new_polarization  polarization NOT NULL,
          old_symbol_rate   symbol_rate NOT NULL,
          new_symbol_rate   symbol_rate NOT NULL,
          source            text NOT NULL,
          outbox_id         bigint UNIQUE REFERENCES notification_outbox (id) ON DELETE SET NULL,
          audit_log_id      bigint REFERENCES audit_log (id) ON DELETE SET NULL,
          detected_at       timestamptz NOT NULL
        )
        """
    )
    op.execute(
        "CREATE INDEX channel_frequency_changes_channel_idx ON channel_frequency_changes (channel_id, detected_at DESC)"
    )
    op.execute(
        """
        CREATE TABLE match_channel_changes (
          id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
          match_id     bigint NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
          channel_id   bigint NOT NULL REFERENCES channels (id) ON DELETE CASCADE,
          action       text NOT NULL CONSTRAINT ck_match_channel_changes_action CHECK (action IN ('added', 'removed')),
          source       text NOT NULL,
          created_at   timestamptz NOT NULL DEFAULT now(),
          announced_at timestamptz,
          CONSTRAINT match_channel_changes_unique UNIQUE (match_id, channel_id, action)
        )
        """
    )
    op.execute(
        "CREATE INDEX match_channel_changes_pending_idx ON match_channel_changes (match_id) WHERE announced_at IS NULL"
    )
    op.execute("ALTER TABLE notification_outbox ADD COLUMN error text")
    op.execute(
        "ALTER TABLE notification_outbox ADD COLUMN audit_log_id bigint REFERENCES audit_log (id) ON DELETE SET NULL"
    )
    op.execute("ALTER TABLE match_live_state ADD COLUMN push_memory jsonb NOT NULL DEFAULT '{}'")
    op.execute("ALTER TABLE admin_users ADD COLUMN must_change_password boolean NOT NULL DEFAULT false")
    op.execute("ALTER TABLE admin_users ADD COLUMN test_device_id bigint REFERENCES devices (id) ON DELETE SET NULL")
    _set_lockable(LOCKABLE_AFTER)
    _set_run_statuses(RUN_STATUSES_AFTER)
    _set_datasets(DATASETS_AFTER)
    op.execute("INSERT INTO dataset_versions (name, version) VALUES ('outbox', 0) ON CONFLICT DO NOTHING")
    op.execute("INSERT INTO dataset_versions (name, version) VALUES ('admin_users', 0) ON CONFLICT DO NOTHING")


def downgrade() -> None:
    # The old release's schemas can't read these two values, so they go before the CHECKs narrow.
    op.execute("UPDATE import_runs SET status = 'failed' WHERE status = 'stopped'")
    op.execute(
        "UPDATE matches SET locked_fields = array_remove(locked_fields, 'broadcasts') "
        "WHERE 'broadcasts' = ANY (locked_fields)"
    )
    _set_lockable(LOCKABLE_BEFORE)
    _set_run_statuses(RUN_STATUSES_BEFORE)
    op.execute("DELETE FROM dataset_versions WHERE name IN ('outbox', 'admin_users')")
    _set_datasets(DATASETS_BEFORE)
    op.execute("ALTER TABLE admin_users DROP COLUMN test_device_id")
    op.execute("ALTER TABLE admin_users DROP COLUMN must_change_password")
    op.execute("ALTER TABLE match_live_state DROP COLUMN push_memory")
    op.execute("ALTER TABLE notification_outbox DROP COLUMN audit_log_id")
    op.execute("ALTER TABLE notification_outbox DROP COLUMN error")
    op.execute("DROP TABLE match_channel_changes")
    op.execute("DROP TABLE channel_frequency_changes")
