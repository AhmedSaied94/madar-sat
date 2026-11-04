"""0007: the live tables, name aliases and the unresolved-names queue (D5, Lane B1).

Revision ID: 0007
Revises: 0006
Create Date: 2026-11-04

Expand-only: new tables, nullable columns and wider checks, so the D4 API keeps running against it
(constitution, Migrations).

- ``match_events``, ``match_lineups``: structured facts the poller serves;
- ``match_live_state``, ``match_source_readings``, ``live_source_state``, ``live_problems``: the
  cross-check's memory, which survives restarts and a clock fallback (research R5);
- ``team_aliases``, ``competition_aliases``, ``channel_aliases``, ``unresolved_names``: names the
  importers can't match wait for an editor instead of creating duplicates (R8, R9);
- ``matches.local_broadcaster_eg``, ``rights_holder_carriages.package``;
- the ``filgoal``, ``yallakora`` and ``live_poller`` sources, with the kinds they need.
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None

KINDS_BEFORE = ("scraper", "api", "internal")
KINDS_AFTER = (*KINDS_BEFORE, "fixtures", "live_reader", "live")

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
)
DATASETS_AFTER = (*DATASETS_BEFORE, "unresolved_names")

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
)
LOCKABLE_AFTER = (*LOCKABLE_BEFORE, "local_broadcaster_eg")


def _in(names: tuple[str, ...]) -> str:
    return ", ".join(f"'{name}'" for name in names)


def _set_kinds(names: tuple[str, ...]) -> None:
    op.execute("ALTER TABLE sources DROP CONSTRAINT ck_sources_kind")
    op.execute(f"ALTER TABLE sources ADD CONSTRAINT ck_sources_kind CHECK (kind IN ({_in(names)}))")


def _set_datasets(names: tuple[str, ...]) -> None:
    op.execute("ALTER TABLE dataset_versions DROP CONSTRAINT ck_dataset_versions_name")
    op.execute(f"ALTER TABLE dataset_versions ADD CONSTRAINT ck_dataset_versions_name CHECK (name IN ({_in(names)}))")


def _set_lockable(names: tuple[str, ...]) -> None:
    op.execute("ALTER TABLE matches DROP CONSTRAINT ck_matches_locked_fields")
    op.execute(
        "ALTER TABLE matches ADD CONSTRAINT ck_matches_locked_fields "
        f"CHECK (locked_fields <@ ARRAY[{_in(names)}]::text[])"
    )


def _live_tables() -> None:
    op.execute(
        """
        CREATE TABLE match_events (
          id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
          match_id    bigint NOT NULL REFERENCES matches (id),
          side        text NOT NULL CONSTRAINT ck_match_events_side CHECK (side IN ('home', 'away')),
          type        text NOT NULL CONSTRAINT ck_match_events_type
                      CHECK (type IN ('goal', 'own_goal', 'penalty', 'missed_penalty', 'red_card')),
          minute      text NOT NULL CONSTRAINT ck_match_events_minute CHECK (minute ~ '^\\d{1,3}(\\+\\d{1,2})?$'),
          player_name text,
          source      text NOT NULL REFERENCES sources (name),
          external_id text NOT NULL,
          created_at  timestamptz NOT NULL DEFAULT now(),
          CONSTRAINT match_events_match_id_source_external_id_key UNIQUE (match_id, source, external_id)
        )
        """
    )
    op.execute("CREATE INDEX match_events_match_id_minute_idx ON match_events (match_id, minute)")
    op.execute(
        """
        CREATE TABLE match_lineups (
          match_id   bigint NOT NULL REFERENCES matches (id),
          side       text NOT NULL CONSTRAINT ck_match_lineups_side CHECK (side IN ('home', 'away')),
          formation  text,
          players    jsonb NOT NULL DEFAULT '[]' CONSTRAINT ck_match_lineups_players
                     CHECK (jsonb_typeof(players) = 'array' AND jsonb_array_length(players) <= 40),
          source     text NOT NULL REFERENCES sources (name),
          updated_at timestamptz NOT NULL DEFAULT now(),
          PRIMARY KEY (match_id, side)
        )
        """
    )
    op.execute(
        """
        CREATE TABLE match_live_state (
          match_id           bigint PRIMARY KEY REFERENCES matches (id),
          confirmed_home     smallint CONSTRAINT ck_match_live_state_home CHECK (confirmed_home >= 0),
          confirmed_away     smallint CONSTRAINT ck_match_live_state_away CHECK (confirmed_away >= 0),
          confirmed_home_pen smallint CONSTRAINT ck_match_live_state_home_pen CHECK (confirmed_home_pen >= 0),
          confirmed_away_pen smallint CONSTRAINT ck_match_live_state_away_pen CHECK (confirmed_away_pen >= 0),
          candidate          jsonb,
          disagreement_since timestamptz,
          has_page_slot      boolean NOT NULL DEFAULT false,
          last_reading_at    timestamptz,
          updated_at         timestamptz NOT NULL DEFAULT now()
        )
        """
    )
    op.execute("CREATE INDEX match_live_state_last_reading_at_idx ON match_live_state (last_reading_at)")
    op.execute(
        """
        CREATE TABLE match_source_readings (
          match_id   bigint NOT NULL REFERENCES matches (id),
          source     text NOT NULL REFERENCES sources (name),
          status     text,
          period     text,
          minute     text,
          home_score smallint,
          away_score smallint,
          home_pen   smallint,
          away_pen   smallint,
          read_at    timestamptz NOT NULL,
          changed_at timestamptz NOT NULL,
          PRIMARY KEY (match_id, source)
        )
        """
    )
    op.execute(
        """
        CREATE TABLE live_source_state (
          source               text PRIMARY KEY REFERENCES sources (name),
          state                text NOT NULL DEFAULT 'ok' CONSTRAINT ck_live_source_state_state
                               CHECK (state IN ('ok', 'failing', 'down', 'invalid')),
          consecutive_failures integer NOT NULL DEFAULT 0 CONSTRAINT ck_live_source_state_failures
                               CHECK (consecutive_failures >= 0),
          last_ok_at           timestamptz
        )
        """
    )
    op.execute(
        """
        CREATE TABLE live_problems (
          key                  text PRIMARY KEY,
          opened_at            timestamptz NOT NULL,
          closed_at            timestamptz,
          raw_ref              text,
          alerted_at           timestamptz,
          recovered_alerted_at timestamptz
        )
        """
    )


def _alias_tables() -> None:
    op.execute(
        """
        CREATE TABLE team_aliases (
          source           text NOT NULL REFERENCES sources (name),
          alias_norm       text NOT NULL,
          competition_norm text NOT NULL DEFAULT '',
          team_id          bigint NOT NULL REFERENCES teams (id) ON DELETE CASCADE,
          created_by       bigint REFERENCES admin_users (id) ON DELETE SET NULL,
          created_at       timestamptz NOT NULL DEFAULT now(),
          PRIMARY KEY (source, alias_norm, competition_norm)
        )
        """
    )
    op.execute("CREATE INDEX team_aliases_team_id_idx ON team_aliases (team_id)")
    for table, column, target in (
        ("competition_aliases", "competition_id", "competitions"),
        ("channel_aliases", "channel_id", "channels"),
    ):
        op.execute(
            f"""
            CREATE TABLE {table} (
              source     text NOT NULL REFERENCES sources (name),
              alias_norm text NOT NULL,
              {column}   bigint NOT NULL REFERENCES {target} (id) ON DELETE CASCADE,
              created_by bigint REFERENCES admin_users (id) ON DELETE SET NULL,
              created_at timestamptz NOT NULL DEFAULT now(),
              PRIMARY KEY (source, alias_norm)
            )
            """
        )
        op.execute(f"CREATE INDEX {table}_{column}_idx ON {table} ({column})")
    op.execute(
        """
        CREATE TABLE unresolved_names (
          id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
          source           text NOT NULL REFERENCES sources (name),
          kind             text NOT NULL CONSTRAINT ck_unresolved_names_kind
                           CHECK (kind IN ('team', 'competition', 'channel')),
          name             text NOT NULL CONSTRAINT ck_unresolved_names_name CHECK (length(name) <= 200),
          name_norm        text NOT NULL,
          competition_norm text NOT NULL DEFAULT '',
          context          jsonb NOT NULL DEFAULT '{}',
          seen_count       integer NOT NULL DEFAULT 1 CONSTRAINT ck_unresolved_names_seen_count CHECK (seen_count >= 0),
          first_seen_at    timestamptz NOT NULL DEFAULT now(),
          last_seen_at     timestamptz NOT NULL DEFAULT now(),
          state            text NOT NULL DEFAULT 'open' CONSTRAINT ck_unresolved_names_state
                           CHECK (state IN ('open', 'mapped', 'created', 'ignored')),
          target_id        bigint,
          resolved_by      bigint REFERENCES admin_users (id) ON DELETE SET NULL,
          resolved_at      timestamptz,
          CONSTRAINT ck_unresolved_names_target CHECK (state NOT IN ('mapped', 'created') OR target_id IS NOT NULL),
          CONSTRAINT unresolved_names_source_kind_name_norm_competition_norm_key
            UNIQUE (source, kind, name_norm, competition_norm)
        )
        """
    )
    op.execute("CREATE INDEX unresolved_names_open_idx ON unresolved_names (last_seen_at) WHERE state = 'open'")


def upgrade() -> None:
    _set_kinds(KINDS_AFTER)
    op.execute("UPDATE sources SET kind = 'fixtures', updated_at = now() WHERE name = 'yallakora'")
    op.execute(
        "INSERT INTO sources (name, kind) VALUES "
        "('filgoal', 'live_reader'), ('yallakora', 'fixtures'), ('live_poller', 'live') "
        "ON CONFLICT (name) DO NOTHING"
    )

    _set_datasets(DATASETS_AFTER)
    op.execute("INSERT INTO dataset_versions (name, version) VALUES ('unresolved_names', 0) ON CONFLICT DO NOTHING")

    op.add_column("matches", sa.Column("local_broadcaster_eg", sa.Text()))
    _set_lockable(LOCKABLE_AFTER)
    op.add_column("rights_holder_carriages", sa.Column("package", sa.Text()))

    _live_tables()
    _alias_tables()


def downgrade() -> None:
    for table in (
        "unresolved_names",
        "channel_aliases",
        "competition_aliases",
        "team_aliases",
        "live_problems",
        "live_source_state",
        "match_source_readings",
        "match_live_state",
        "match_lineups",
        "match_events",
    ):
        op.execute(f"DROP TABLE {table}")

    op.drop_column("rights_holder_carriages", "package")
    op.execute(
        "UPDATE matches SET locked_fields = array_remove(locked_fields, 'local_broadcaster_eg') "
        "WHERE 'local_broadcaster_eg' = ANY (locked_fields)"
    )
    _set_lockable(LOCKABLE_BEFORE)
    op.drop_column("matches", "local_broadcaster_eg")

    op.execute("DELETE FROM dataset_versions WHERE name = 'unresolved_names'")
    _set_datasets(DATASETS_BEFORE)

    # The poller's own run records go with its source; importer runs are untouched.
    op.execute("DELETE FROM import_runs WHERE source IN ('filgoal', 'live_poller')")
    op.execute("DELETE FROM sources WHERE name IN ('filgoal', 'live_poller')")
    op.execute("UPDATE sources SET kind = 'scraper', updated_at = now() WHERE name = 'yallakora'")
    _set_kinds(KINDS_BEFORE)
