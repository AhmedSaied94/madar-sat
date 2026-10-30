"""0003: audit source and link origin (D2 data-model "Revision 0003").

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-30

Two additive columns, so the conflict dialog can name the importer that changed a match and
the editor's removal rule can tell a link an importer brought from one an editor added:

- ``audit_log.source``: the importer behind a change (NULL for admin and CLI actions), with
  ``ck_audit_log_actor`` so a row is an admin's, a source's, or a system action (both NULL).
- ``match_channels.imported_by``: the source that first brought the link (NULL = an editor
  added it), backfilled from ``source`` wherever ``source <> 'manual'``. No index: it is read
  only together with the primary key.

``/v1`` doesn't change. The downgrade drops both columns and the CHECK.
"""

from __future__ import annotations

from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TABLE audit_log ADD COLUMN source text REFERENCES sources (name)")
    op.execute(
        "ALTER TABLE audit_log ADD CONSTRAINT ck_audit_log_actor CHECK (admin_user_id IS NULL OR source IS NULL)"
    )

    op.execute("ALTER TABLE match_channels ADD COLUMN imported_by text REFERENCES sources (name)")
    op.execute("UPDATE match_channels SET imported_by = source WHERE source <> 'manual'")


def downgrade() -> None:
    op.execute("ALTER TABLE match_channels DROP COLUMN IF EXISTS imported_by")

    op.execute("ALTER TABLE audit_log DROP CONSTRAINT IF EXISTS ck_audit_log_actor")
    op.execute("ALTER TABLE audit_log DROP COLUMN IF EXISTS source")
