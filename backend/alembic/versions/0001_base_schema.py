"""0001: the base schema, ``../old_app/migration/schema.sql`` unchanged.

Revision ID: 0001
Revises:
Create Date: 2026-10-29

Runs the byte-for-byte copy of the Sat Air schema through psycopg's
``exec_driver_sql`` (asyncpg can't prepare multi-statement scripts). The downgrade
raises: an applied revision is never edited (constitution "Migrations").
"""

from __future__ import annotations

from pathlib import Path

from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

_SQL_PATH = Path(__file__).resolve().parent.parent / "sql" / "0001_base_schema.sql"


def upgrade() -> None:
    sql = _SQL_PATH.read_text(encoding="utf-8")
    # psycopg3 interprets '%' as a parameter placeholder; the schema has a literal
    # '%' in forbid_delete's RAISE message, so double it for the driver. The .sql
    # file itself stays byte-for-byte unchanged.
    op.get_bind().exec_driver_sql(sql.replace("%", "%%"))


def downgrade() -> None:
    raise RuntimeError("revision 0001 is the base schema; it has no downgrade")
