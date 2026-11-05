"""0008: what the live rules remember, each source's peak minute, match stats and Goal.com (spec 031, Lane B1).

Revision ID: 0008
Revises: 0007
Create Date: 2026-11-05

Expand-only: nullable columns, one new table and one new source, so the release before this revision
keeps running against it (constitution, Migrations).

- ``match_live_state``: the score, status and full-time memory of the rewritten rules. ``candidate`` is
  no longer written, and stays for rollback;
- ``match_source_readings.peak_minute``, ``peak_period``: the highest minute each source has shown;
- ``match_events.missing_since``: an event's deletion waits for five minutes of absence;
- ``match_stats``: Goal.com's summary, never served to clients;
- the ``goal`` source. Its kind stays inside what the release before this revision accepts
  (``SourceItem.kind``), and the code tells live sources apart by name.
"""

from __future__ import annotations

from alembic import op

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None

STATE_COLUMNS = (
    ("score_first_source", "text"),
    ("score_changed_at", "timestamptz"),
    ("drop_since", "timestamptz"),
    ("status_drop_since", "timestamptz"),
    ("fulltime_source", "text"),
    ("fulltime_since", "timestamptz"),
    ("finish_wait_since", "timestamptz"),
)


def upgrade() -> None:
    for name, kind in STATE_COLUMNS:
        op.execute(f"ALTER TABLE match_live_state ADD COLUMN {name} {kind}")
    op.execute("ALTER TABLE match_source_readings ADD COLUMN peak_minute smallint")
    op.execute("ALTER TABLE match_source_readings ADD COLUMN peak_period text")
    op.execute("ALTER TABLE match_events ADD COLUMN missing_since timestamptz")
    op.execute(
        """
        CREATE TABLE match_stats (
          match_id   bigint NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
          source     text NOT NULL REFERENCES sources (name),
          stats      jsonb NOT NULL CONSTRAINT ck_match_stats_stats CHECK (jsonb_typeof(stats) = 'array'),
          updated_at timestamptz NOT NULL DEFAULT now(),
          PRIMARY KEY (match_id, source)
        )
        """
    )
    op.execute("INSERT INTO sources (name, kind) VALUES ('goal', 'internal') ON CONFLICT (name) DO NOTHING")


def downgrade() -> None:
    op.execute("DROP TABLE match_stats")
    # Everywhere the poller or an editor's name mapping can leave a ``goal`` row. Nothing makes a match, a
    # match channel or an audit row from this source, so any such row stops the downgrade instead of going.
    op.execute("DELETE FROM match_events WHERE source = 'goal'")
    op.execute("DELETE FROM match_lineups WHERE source = 'goal'")
    op.execute("DELETE FROM match_source_readings WHERE source = 'goal'")
    op.execute("DELETE FROM live_source_state WHERE source = 'goal'")
    op.execute("DELETE FROM match_external_ids WHERE source = 'goal'")
    op.execute("DELETE FROM unresolved_names WHERE source = 'goal'")
    op.execute("DELETE FROM team_aliases WHERE source = 'goal'")
    op.execute("DELETE FROM competition_aliases WHERE source = 'goal'")
    op.execute("DELETE FROM channel_aliases WHERE source = 'goal'")
    op.execute("DELETE FROM sources WHERE name = 'goal'")
    op.execute("ALTER TABLE match_events DROP COLUMN missing_since")
    op.execute("ALTER TABLE match_source_readings DROP COLUMN peak_period")
    op.execute("ALTER TABLE match_source_readings DROP COLUMN peak_minute")
    for name, _ in reversed(STATE_COLUMNS):
        op.execute(f"ALTER TABLE match_live_state DROP COLUMN {name}")
