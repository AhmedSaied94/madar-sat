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
  and ETags are built from the versions, so nothing is deleted by key scan. The public response
  cache (`app/api/cache.py`) stores each serialized `200` under `rc:<etag>` for its route's TTL;
  a bump changes the tag, so the next read misses. `/v1/devices*` is `no-store` and never cached.
- **Admin writes** all go through `app/services/admin/writer.py`, the one unit of work: lock the
  row (`FOR UPDATE`), check `If-Match` against the version recomputed under the lock (`428` without
  it, `409 edit_conflict` when stale), apply, diff, add the changed lockable fields to
  `locked_fields`, write `audit_log`, bump the datasets **as the last statement**, commit. A write
  that changes nothing writes nothing. Never mutate an entity from a handler any other way.
- **Entity versions** (`ETag`/`If-Match`) are content hashes (`services/admin/versions.py`): the first
  32 hex of SHA-256 over the entity's own stored state, in quotes. An importer's change makes an open
  editor's copy stale too. Importers that touch a match, team or channel must keep that in mind.
- **Auth** (`app/auth/`): argon2id passwords, 15-minute HS256 access tokens (`ADMIN_JWT_SECRET`), rotating
  hashed refresh tokens in `admin_refresh_tokens` (reuse revokes the family), the `madar_csrf` double
  submit, login limiting in Redis. The client IP comes from `TRUSTED_PROXIES` (`client_ip()` in
  `app/auth/limits.py`): Caddy only, right-most untrusted hop wins, and the public app trusts its
  Compose bridge gateway. `RATE_LIMIT_EXEMPT_IPS` (empty by default, load-test window only) skips the
  `/v1` limiter for exact IPs and warns at startup. `require_editor` / `require_admin` load the admin from the database on
  every request; the role in the token is never trusted. Every admin route except `auth/*` and `healthz`
  carries one (a test walks the routes).
- **Push** uses an outbox. Producers only insert `notification_outbox` rows with a unique
  `dedupe_key`; they never send. One dispatcher claims rows with `FOR UPDATE SKIP LOCKED`, resolves
  devices with one `SELECT DISTINCT` over `device_follows` (`AUDIENCE` in
  `app/notifications/dispatcher.py`, reviewed by the owner), and sends through FCM in pages of 500.
  **Only `app/notifications/` imports `firebase_admin`** (`sender.py`); nothing else talks to FCM.
  A token is cleared only when FCM says the registration token is dead (`UnregisteredError`, or
  `INVALID_ARGUMENT` naming the token). A transient per-message error (503, 500, 429, timeout) is sent
  again for that device alone after `RETRY_DELAYS` in `sender.py`; a device still unreachable is
  `retryable` in `SendOutcome`. A page that delivered to nobody while some device is `retryable` raises
  `Retryable` unrecorded (the cursor/`attempts` path retries it, never `sent`); on a page that did deliver
  to some, the unreachable remainder is counted `failed`, so no device is sent the message twice. Any other
  per-message error is `failed` and logged, and one unusable message never fails the page.
  `notification_outbox.attempts` bounds whole-call retries
  (5 → `failed`), and a row whose kickoff has passed or whose match is `live`/`finished` is
  `cancelled` at dispatch and by the scheduler, never sent late.
- **Devices and follows** (`app/devices/`): `POST /v1/devices` upserts on `install_id` and rotates
  the token; the row keeps only `sha256(token)` and the token is returned once. `PUT
  /v1/devices/me/follows` replaces the whole set atomically under a device row lock (≤ 500).
  `PUT /v1/devices/me` moves a push token to the device that sends it. The rate limiter stores
  `dv:<hash>` and deletes it on rotate and delete (`app/api/ratelimit.py`).
- **Source health** is written only by Lane B2's `app/adapters/health.py`; placeholders only by
  `app/adapters/livesoccertv_links.py`. This lane reads them in `app/services/admin/sources.py`
  and hides placeholders (`placeholder_source IS NOT NULL`) from every public channel query.
- **Match status** is an explicit state machine (§6.2.3). A clock-guessed "live" carries
  `estimated: true` and must never show a score or minute. A manual status (`status_source = 'manual'`)
  is served as stored until an admin clears it; the allowed fields per status are in
  `app/domain/manual_status.py`.
- **Content rule:** no free text that reaches `/v1` may hold a card-sharing label. Request schemas screen it
  (`Name120`, `Text80`, `Text120` in `app/schemas/admin.py`); `find_card_sharing_label` is in `app/domain/content.py`.
- **Time:** `kickoff_at` is UTC. Source times are Cairo wall-clock and are converted with
  `AT TIME ZONE 'Africa/Cairo'`. An admin match's `match_date` follows the Cairo date of its kickoff.

## Running locally

```bash
docker compose -f ../infra/compose/dev.yml up -d postgres redis   # PostgreSQL 16 + Redis 7
uv run alembic upgrade head
uv run python -m app.cli load-snapshot --snapshot-dir ~/madar-snapshot --report-dir /tmp
uv run python -m app.cli rehost-media --snapshot-dir ~/madar-snapshot --report-dir /tmp
uv run ruff check . && uv run mypy --strict app && uv run pytest   # what backend.yml runs
uv run python -m app.cli export-openapi && git diff --exit-code openapi/
uv run uvicorn app.public:app --port 8000
ADMIN_JWT_SECRET=$(openssl rand -hex 32) uv run uvicorn app.admin:app --port 8001   # needs the secret
```

## Module layout

- `app/public.py`, `app/admin.py` — the two app factories. `app.admin` refuses to start without a usable
  `ADMIN_JWT_SECRET` (checked in its lifespan, so `export-openapi` still works without it).
- `app/settings.py` — pydantic-settings; every secret is required (fails fast).
- `app/db/` — SQLAlchemy 2 models (`models.py`) and engines (`session.py`: async asyncpg for the API, sync psycopg for the CLI/Alembic).
- `app/domain/` — pure logic: `status.py` (clock rule), `manual_status.py` (what each manual status allows),
  `lockable.py` (the lockable columns), `content.py` (card-sharing labels), `time.py` (Cairo→UTC), `frequency.py`,
  `regions.py`, `ranking.py`.
- `app/api/` — envelope, errors, ETag, routers. `app/api/admin/` holds one router per admin resource.
- `app/auth/` — passwords, tokens, CSRF, login limits, roles, and the account commands behind the CLI.
- `app/schemas/` — Pydantic models (the contract). `admin.py` also holds the request bodies.
- `app/services/` — one read query per endpoint. `app/services/admin/` is the admin write side: `writer.py`,
  `versions.py`, `refs.py` (id checks), one module per entity, `matches.py` + `match_links.py` + `match_view.py` +
  `match_list.py`, `bulk.py`, `lists.py`, `uploads.py`.
- `app/media/` — fetch, encode and store media; shared by the snapshot rehoster (`app/etl/media.py`) and the upload route.
- `app/devices/` — token generation and hashing, the `DeviceAuth` dependency, the update service and the
  atomic follow-set replacement.
- `app/notifications/` — `scheduler.py` (one outbox row per followed match), `dispatcher.py` (claim, the
  audience query, pages, cursor), `messages.py` (copy and FCM fields, pure), `sender.py` (`PushSender`
  protocol and `FcmSender`), `tasks.py` and `schedule.py` (`BEAT_SCHEDULE`).
- `app/workers/` — the Celery app (queues, retry base task, Redis locks). It merges the `BEAT_SCHEDULE` of
  every module in `SCHEDULE_MODULES` (`app.adapters.schedule`, `app.notifications.schedule`, `app.live.schedule`) and raises on
  a duplicate entry name. Importing `app.workers` still loads neither `app.settings` nor `app.db`.
- `app/live/` — the live poller (005 contracts/live-pipeline.md, 031 contracts/live-rules.md). Pure: `sources/` (parsers), `crosscheck.py`
  (`decide`), `pick.py`, `robots.py`. Database: `links.py`, `apply.py`, `problems.py`, `watchdog.py`. `cycle.py` is
  one Celery-free poll, and `tasks.py` and `schedule.py` wrap it. `capture.py` backs `capture-live`.
- `app/etl/` — snapshot loader, media rehoster, load report.
- `app/adapters/` and `tests/adapters/` — Lane B2's. B1 does not edit them.

## Ownership

- B1 owns **migrations** and the **contract** (`backend/openapi/*.json`).
- Revisions `0001` to `0006` are applied and **never edited**; a change is a new revision. `0007` is D5's
  expand-only revision (the live tables, aliases, the unresolved-names queue), and `0008` is spec 031's (the rules'
  memory, the peak minute, `match_stats`, the `goal` source), unmerged until its PR. `0005` is D3's expand-only revision (device satellites, the outbox cursor, source health,
  `import_runs.log`, `channels.placeholder_source`).
  `0001` is `alembic/sql/0001_base_schema.sql`, a byte-for-byte copy of `../old_app/migration/schema.sql`.
- `backend/openapi/public.json` and `admin.json` are exported from code, committed,
  and tagged `contract-v1`; after the tag, changes must be non-breaking (FR-014).
- Generated clients (Orval / swagger_parser) are regenerated, never hand-edited. The PR that changes an
  OpenAPI document also runs both generators and commits their output (`backend.yml`'s `clients` job fails otherwise).

## CLI

- `python -m app.cli export-openapi`: needs every required setting in the environment
  (settings fail fast at import), but connects to nothing, so placeholder values work in CI.
- `python -m app.cli load-snapshot --snapshot-dir <dir> --report-dir <dir>`
- `python -m app.cli rehost-media --snapshot-dir <dir> --report-dir <dir>`
- `python -m app.cli capture-live [--minutes <n>] [--page-cap <n>]`: saves live pages ([live-poller.md](../docs/runbooks/live-poller.md))
- `python -m app.cli repair-matches merge <pairs.json | -> [--apply]`, `repair-matches fill-teams [--apply]`: a dry run without `--apply`. The merge is a one-time, owner-approved exception to "matches are never deleted" ([imports-and-sources.md](../docs/runbooks/imports-and-sources.md#merging-duplicate-matches))
- `python -m app.cli create-admin --email <e> --name <n> --role editor|admin`, `set-admin-password --email <e>`,
  `deactivate-admin --email <e>`: staff accounts until A16 (D6). There is **no `--password` option**: the password
  is read twice from the terminal, or once from stdin with `--password-stdin`, so it never reaches shell
  history or `ps`. Each command writes an `audit_log` row with no password or hash in it; see
  `docs/runbooks/staff-accounts.md`.

## Tests

Database tests use real PostgreSQL 16 (`TEST_DATABASE_URL`, default
`localhost:5434`), never SQLite; Redis comes from `TEST_REDIS_URL` (default
`localhost:6380`). Each session creates and drops its own database, so parallel runs are safe.

- `loaded_snapshot` loads `tests/fixtures/snapshot` once per session (committed).
- `session` / `sync_session` / `db_connection` run each test in a transaction that is
  rolled back. `public_client` / `anon_admin_client` / `editor_client` / `admin_client` serve requests through that
  same connection, so rows a test adds are visible to the API and gone afterwards. `editor_client` and
  `admin_client` are signed in (`client.admin` is the account); `make_admin` creates more accounts.
- `redis_client` clears only the `auth:` and `lock:test:` keys before a test: other lanes share the server.
- `empty_database` gives a throwaway database for migration tests.
- `tests/admin/` covers the admin write side (`helpers.py` has `new_match`, `patch_match`, `create`, dataset and audit
  helpers); `tests/auth/` covers login, refresh and the CLI; `tests/unit/` the pure parts.
- `tests/contract/test_public_schema.py` and `test_admin_contract.py` run schemathesis over the committed
  `openapi/*.json` and fail if the file is stale; re-export after any API change. The admin one writes for real, so it
  runs against a scratch database of its own.
- Audio tests need `ffmpeg` and `ffprobe` and skip without them (CI and the image have them).

Coverage ≥ 70 % on `app/domain`, `app/services`, `app/adapters`, `app/devices` and `app/notifications`
(MVP bar).
