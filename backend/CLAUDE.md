# backend/CLAUDE.md — Lane B1

Madar Sat backend: two ASGI apps — public `app.public:app` (`/v1`) and admin
`app.admin:app` (`/admin/api`, WireGuard only, never mounted on the public app).

## Architecture rules

- **Ingestion** uses scraper adapters in `app/adapters/` (Lane B2: ysscores, LiveSoccerTV,
  sporteventz, YallaKora, API-Football) that implement the `SourceAdapter` protocol
  (system-design §6.6): `fetch` → `parse` (pure, tested against saved raw pages) → `normalize`.
  They upsert by `(source, external_id)`, skip any field listed in `locked_fields` (admin edits
  win), and send unmatched names to `unresolved_names`.
- **Cache invalidation** uses `dataset_versions`. Each write bumps a version; Redis cache keys
  and ETags are built from the versions, so nothing is deleted by key scan. Admin mutations also
  write `audit_log` and require `If-Match`.
- **Push** uses an outbox. Producers only insert `notification_outbox` rows with a unique
  `dedupe_key`. One dispatcher claims rows with `FOR UPDATE SKIP LOCKED`, resolves devices with
  `SELECT DISTINCT` over `device_follows`, and sends through FCM.
- **Match status** is an explicit state machine (§6.2.3). A clock-guessed "live" carries
  `estimated: true` and must never show a score or minute.
- **Time:** `kickoff_at` is UTC. Source times are Cairo wall-clock and are converted with
  `AT TIME ZONE 'Africa/Cairo'`.

## Running locally

```bash
docker compose -f ../infra/compose/dev.yml up -d postgres redis   # PostgreSQL 16 + Redis 7
uv run alembic upgrade head
uv run python -m app.cli load-snapshot --snapshot-dir ~/madar-snapshot --report-dir /tmp
uv run python -m app.cli rehost-media --snapshot-dir ~/madar-snapshot --report-dir /tmp
uv run ruff check . && uv run mypy --strict app && uv run pytest   # what backend.yml runs
uv run python -m app.cli export-openapi && git diff --exit-code openapi/
uv run uvicorn app.public:app --port 8000
```

## Module layout

- `app/public.py`, `app/admin.py` — the two app factories.
- `app/settings.py` — pydantic-settings; every secret is required (fails fast).
- `app/db/` — SQLAlchemy 2 models (`models.py`) and engines (`session.py`: async asyncpg for the API, sync psycopg for the CLI/Alembic).
- `app/domain/` — pure logic: `status.py` (clock rule), `time.py` (Cairo→UTC), `frequency.py`, `regions.py`, `ranking.py`.
- `app/api/` — envelope, errors, ETag, routers.
- `app/schemas/` — Pydantic response models (the contract).
- `app/services/` — one read query per endpoint.
- `app/etl/` — snapshot loader, media rehoster, load report.
- `app/adapters/` — Lane B2 (empty on D1).

## Ownership

- B1 owns **migrations** and the **contract** (`backend/openapi/*.json`).
- Revision `0001` is `alembic/sql/0001_base_schema.sql`, a byte-for-byte copy of
  `../old_app/migration/schema.sql` — **never edited**.
- `backend/openapi/public.json` and `admin.json` are exported from code, committed,
  and tagged `contract-v1`; after the tag, changes must be non-breaking (FR-014).
- Generated clients (Orval / swagger_parser) are regenerated, never hand-edited.

## CLI

- `python -m app.cli export-openapi`: needs every required setting in the environment
  (settings fail fast at import), but connects to nothing, so placeholder values work in CI.
- `python -m app.cli load-snapshot --snapshot-dir <dir> --report-dir <dir>`
- `python -m app.cli rehost-media --snapshot-dir <dir> --report-dir <dir>`

## Tests

Database tests use real PostgreSQL 16 (`TEST_DATABASE_URL`, default
`localhost:5434`), never SQLite; Redis comes from `TEST_REDIS_URL` (default
`localhost:6380`). Each session creates and drops its own database, so parallel runs are safe.

- `loaded_snapshot` loads `tests/fixtures/snapshot` once per session (committed).
- `session` / `sync_session` / `db_connection` run each test in a transaction that is
  rolled back. `public_client` / `admin_client` serve requests through that same
  connection, so rows a test adds are visible to the API and gone afterwards.
- `empty_database` gives a throwaway database for migration tests.
- `tests/contract/test_public_schema.py` runs schemathesis over the committed
  `openapi/public.json` and fails if the file is stale; re-export after any API change.

Coverage ≥ 70 % on `app/domain`, `app/services`, `app/adapters` (MVP bar).
