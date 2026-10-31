"""0004: dataset names for the two admin lists that had none (B1-R1-3).

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-31



``GET /admin/api/broadcast-presets`` and ``GET /admin/api/sources`` answer with an ``ETag`` built
from ``dataset_versions`` (constitution VI), and neither list had a dataset of its own. D2 writes
neither, so both start at 0; A11 and A13 bump them when they become editable.
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None

ADDED = ("broadcast_presets", "sources")
BEFORE = ("matches", "live", "channels", "satellites", "competitions", "teams", "commentators", "rights_holders")
AFTER = BEFORE + ADDED


def _check(names: tuple[str, ...]) -> str:
    allowed = ", ".join(f"'{name}'" for name in names)
    return f"ADD CONSTRAINT ck_dataset_versions_name CHECK (name IN ({allowed}))"


def upgrade() -> None:
    op.execute("ALTER TABLE dataset_versions DROP CONSTRAINT ck_dataset_versions_name")
    op.execute(f"ALTER TABLE dataset_versions {_check(AFTER)}")
    op.get_bind().execute(
        sa.text("INSERT INTO dataset_versions (name, version) VALUES (:name, 0) ON CONFLICT DO NOTHING"),
        [{"name": name} for name in ADDED],
    )


def downgrade() -> None:
    op.execute("DELETE FROM dataset_versions WHERE name IN ('broadcast_presets', 'sources')")
    op.execute("ALTER TABLE dataset_versions DROP CONSTRAINT ck_dataset_versions_name")
    op.execute(f"ALTER TABLE dataset_versions {_check(BEFORE)}")
