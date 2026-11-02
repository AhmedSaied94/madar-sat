"""0006: the outbox attempt counter (B1-R1-4, D3 round 1).

Revision ID: 0006
Revises: 0005
Create Date: 2026-11-01

Expand-only: one column with a default, so the API and the D2 rows keep working. A row whose
whole-call failures reach the retry limit becomes ``failed``; before this the count lived only in
the Celery task, and the every-minute beat re-claimed the released row as a new task, so the count
never ran out and the row stayed ``pending`` for ever.
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "notification_outbox",
        sa.Column("attempts", sa.Integer(), nullable=False, server_default=sa.text("0")),
    )
    op.execute("ALTER TABLE notification_outbox ADD CONSTRAINT ck_notification_outbox_attempts CHECK (attempts >= 0)")


def downgrade() -> None:
    op.execute("ALTER TABLE notification_outbox DROP CONSTRAINT ck_notification_outbox_attempts")
    op.drop_column("notification_outbox", "attempts")
