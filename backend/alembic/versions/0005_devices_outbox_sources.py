"""0005: devices, the outbox cursor, source health, run logs and placeholders (D3, Lane B1).

Revision ID: 0005
Revises: 0004
Create Date: 2026-11-01

Expand-only: every change is a nullable column or one with a default, so the D2 API keeps
running against it (constitution, Migrations). ``devices``, ``device_follows`` and
``notification_outbox`` already exist from ``0002``; D3 is their first writer.

- ``devices.satellite_ids``: the device's dish, used to word reminders (research R3);
- ``notification_outbox.claimed_at`` / ``cursor_device_id``: reclaim stuck rows and resume a
  partly sent one without sending twice (R7);
- ``sources`` health columns: the circuit breaker and the zero-items alarm (R17);
- ``import_runs.log``: the compact run log, read by ``api-admin`` on VPS-1 (R12);
- ``channels.placeholder_source``: an importer-created placeholder, hidden from ``/v1`` (R18).
"""

from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "devices",
        sa.Column("satellite_ids", sa.ARRAY(sa.BigInteger()), nullable=False, server_default=sa.text("'{}'")),
    )
    op.execute("ALTER TABLE devices ADD CONSTRAINT ck_devices_satellite_ids CHECK (cardinality(satellite_ids) <= 32)")

    op.add_column("notification_outbox", sa.Column("claimed_at", sa.DateTime(timezone=True)))
    op.add_column(
        "notification_outbox",
        sa.Column("cursor_device_id", sa.BigInteger(), nullable=False, server_default=sa.text("0")),
    )
    op.execute(
        "CREATE INDEX notification_outbox_sending_idx ON notification_outbox (claimed_at) WHERE status = 'sending'"
    )

    op.add_column(
        "sources", sa.Column("consecutive_failures", sa.Integer(), nullable=False, server_default=sa.text("0"))
    )
    op.execute("ALTER TABLE sources ADD CONSTRAINT ck_sources_consecutive_failures CHECK (consecutive_failures >= 0)")
    op.add_column("sources", sa.Column("breaker_opened_at", sa.DateTime(timezone=True)))
    op.add_column("sources", sa.Column("last_success_at", sa.DateTime(timezone=True)))
    op.add_column("sources", sa.Column("last_zero_alert_on", sa.Date()))

    op.add_column("import_runs", sa.Column("log", postgresql.JSONB()))

    op.add_column("channels", sa.Column("placeholder_source", sa.Text()))
    op.create_foreign_key("channels_placeholder_source_fkey", "channels", "sources", ["placeholder_source"], ["name"])
    op.execute(
        "CREATE INDEX channels_placeholder_idx ON channels (placeholder_source) WHERE placeholder_source IS NOT NULL"
    )


def downgrade() -> None:
    op.execute("DROP INDEX channels_placeholder_idx")
    op.drop_constraint("channels_placeholder_source_fkey", "channels", type_="foreignkey")
    op.drop_column("channels", "placeholder_source")

    op.drop_column("import_runs", "log")

    op.drop_column("sources", "last_zero_alert_on")
    op.drop_column("sources", "last_success_at")
    op.drop_column("sources", "breaker_opened_at")
    op.execute("ALTER TABLE sources DROP CONSTRAINT ck_sources_consecutive_failures")
    op.drop_column("sources", "consecutive_failures")

    op.execute("DROP INDEX notification_outbox_sending_idx")
    op.drop_column("notification_outbox", "cursor_device_id")
    op.drop_column("notification_outbox", "claimed_at")

    op.execute("ALTER TABLE devices DROP CONSTRAINT ck_devices_satellite_ids")
    op.drop_column("devices", "satellite_ids")
