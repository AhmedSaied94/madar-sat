from __future__ import annotations

from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool

from alembic import context
from app.db.models import Base
from app.settings import get_settings

config = context.config

if config.config_file_name is not None:
    # Keep the app's loggers when migrations run in-process (tests, CLI).
    fileConfig(config.config_file_name, disable_existing_loggers=False)

# The sync psycopg URL (DATABASE_URL_SYNC): asyncpg can't run multi-statement scripts.
# A caller that already set a URL (a test migrating a throwaway database) keeps it.
if not config.get_main_option("sqlalchemy.url"):
    # configparser treats "%" as interpolation, so a percent-encoded password needs "%%".
    config.set_main_option("sqlalchemy.url", get_settings().database_url_sync.replace("%", "%%"))

# The models' metadata carries the naming convention: ck_<table>_<rule>, PostgreSQL's
# default names otherwise.
target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url, target_metadata=target_metadata, literal_binds=True, dialect_opts={"paramstyle": "named"}
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
