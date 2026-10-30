---

description: "D1 · Foundation: tasks per lane"
---

# Tasks: D1 · Foundation

**Input**: Design documents from `specs/001-d01-foundation/`: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md).

**Tests**: Mandatory (constitution, Quality Gates). In every lane, the test tasks come first and must be seen failing before the code they cover (FR-053). The coverage bar is the MVP bar in FR-054.

**Organization**: one `## Lane` section per lane, each an independently testable user story, plus a final `## Done check`.

- A lane implements and ticks **only its own section** and changes only its own folders (FR-051).
- Review fix tasks are appended at the end of a lane's section by `/speckit-review-implementation`.

| Section | Spec story | Story label | Branch | Folders |
| --- | --- | --- | --- | --- |
| Lane B1 | User Story 1 (P1) | `[US1]` | `d01-b1` | `backend/` except `backend/app/adapters/` |
| Lane B2 | User Story 2 (P2) | `[US2]` | `d01-b2` | `infra/`, `.github/`, `backend/app/adapters/` |
| Lane A | User Story 4 (P4) | `[US4]` | `d01-a` | `admin/` |
| Lane M | User Story 3 (P3) | `[US3]` | `d01-m` | `app/` |

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task).
- **[USn]**: the spec story the task belongs to.
- Paths are repo-relative.

## Dependencies & execution order

### Between lanes

- **Contract tag at 13:00:**
  - T024 (B1, tag `contract-v1`) blocks Lane A's T082 and Lane M's T121 (client generation).
  - Before the tag, A and M work on scaffolds, tokens, components and tests.
- **Deploy pipeline:**
  - T048 (B1, load on VPS-1) needs B2's T058 (VPS-1 Compose and Caddy) and T060 (`backend.yml` deploy).
  - Until then, B1 verifies locally with `infra/compose/dev.yml` (T053). B1 can start that file's Postgres service by hand if T053 isn't merged yet.
- **Generated-client check:** `backend.yml`'s `clients` job (T060) runs only when `admin/orval.config.ts` (T082) and `app/swagger_parser.yaml` (T121) exist. It is skipped before then.
- **Done check:** all four lanes.

### Inside each lane

```text
Setup → Tests (must fail) → implementation in the listed order → Validation
```

`[P]` tasks inside a block can run together.

### Parallel examples

```text
B1 tests:   T006, T007, T008, T009, T010, T011 (unit) together; T012–T018 (db/contract) after T005
B1 domain:  T029, T030, T031, T032, T033 together
B2:         T051, T052, T053, T054 together after T050
A:          T075, T076, T077, T078, T079 (component tests) together
M:          T107–T117 (goldens) together after T106; T123 (Logo) first, then T124–T133 (components) together
```

## Implementation strategy

1. **Morning:** each lane sets up and writes its failing tests. B1 drafts the contract; B2 provisions hosts.
2. **13:00:** B1 tags `contract-v1` (T024). A and M generate their clients from the tag.
3. **Afternoon:** B1 builds data and queries. B2 builds the pipelines and deploys B1. A builds the shell and A1. M builds the drift schema and the matches route.
4. **Evening:** load the snapshot on VPS-1, run the rollback drill, test on a phone, then run the Done check.

Each lane merges at least twice (delivery-plan §5.2): once at the contract or scaffold point, once at the end.

---

## Lane B1

**Story (User Story 1, P1):** As a client developer, I can call `/v1` and get real Sat Air data in the documented envelope and shapes.

**Independent test:** on an empty PostgreSQL 16, `alembic upgrade head`, then `load-snapshot` twice (reconciled, same counts), then `pytest` green. Then `https://api.<ip1>.sslip.io/v1/matches` returns snapshot data with an `ETag`, and a repeat with `If-None-Match` gets `304` ([quickstart.md](quickstart.md#lane-b1-data-and-contract)).

**The owner must review:** the contract diff (T024), the migrations (T025–T027) and `backend/openapi/*.json`.

### Setup (B1)

- [x] T001 [US1] Create `backend/pyproject.toml` (Python 3.13, managed by `uv`) and `backend/uv.lock`.
  - **Runtime deps:** fastapi, uvicorn[standard], gunicorn, sqlalchemy[asyncio] ≥ 2, asyncpg, psycopg[binary] ≥ 3, alembic, pydantic ≥ 2, pydantic-settings, redis, httpx, pillow.
  - **Dev deps:** pytest, pytest-asyncio, pytest-cov, schemathesis, ruff, mypy.
  - **Config:** ruff (pyflakes, isort, bugbear, bandit `S` rules) and `mypy --strict` in `pyproject.toml`.
  - **Coverage:** `[tool.coverage]` measures `app/domain`, `app/services` and `app/adapters`, with `fail_under = 70` (FR-054).
- [x] T002 [P] [US1] Create `backend/Dockerfile`:
  - multi-stage on `python:3.13-slim`, buildable for `linux/arm64`;
  - final stage: Debian `ffmpeg`, the virtualenv from `uv sync --frozen --no-dev`, a non-root user, and no compilers;
  - default command: `gunicorn app.public:app -k uvicorn.workers.UvicornWorker -w 2 -b 0.0.0.0:8000`. Compose overrides it for `api-admin` with `app.admin:app -w 1 -b 0.0.0.0:8001`.
- [x] T003 [P] [US1] Create `backend/app/settings.py` with pydantic-settings, failing fast on missing required values:
  - **Database:** `DATABASE_URL` (asyncpg), `DATABASE_URL_SYNC` (psycopg).
  - **Services:** `REDIS_URL`.
  - **Media:** `MEDIA_BASE_URL`, `MEDIA_ROOT`, and `MEDIA_REHOST_ALLOWED_HOSTS` (comma list, no default).
  - **HTTP:** `CORS_ORIGINS` (comma list), `CONTRACT_VERSION = "1.0.0"`.
  - **Drill only:** `HEALTHZ_FORCE_FAIL` (bool, default false; used only by the rollback drill).

  No secret has a default value.
- [x] T004 [P] [US1] Write `backend/CLAUDE.md` (delivery-plan §8.2). It covers:
  - running with `infra/compose/dev.yml`, `uv run alembic upgrade head` and `uv run pytest`;
  - the module layout of plan.md;
  - that B1 owns migrations and the contract;
  - that `0001` is never edited;
  - the CLI commands;
  - that generated clients are regenerated, never edited.
- [x] T005 [US1] Create `backend/tests/conftest.py`:
  - PostgreSQL 16 from `TEST_DATABASE_URL`; never SQLite (constitution, Test-first);
  - create a fresh database per test session and run `alembic upgrade head`;
  - per-test transactions rolled back;
  - an `httpx.AsyncClient` over `ASGITransport` for `app.public:app` and `app.admin:app`;
  - a frozen `now` fixture.

### Tests first (B1): write them and see them fail

- [x] T006 [P] [US1] Write `backend/tests/unit/test_clock_status.py` for `app.domain.status.derive_status` (data-model "Match status"):

  | Case | Expected |
  | --- | --- |
  | `time_tbd` | `scheduled`, `estimated: false` |
  | `now < kickoff_at` | `scheduled`, `estimated: false` |
  | `kickoff_at ≤ now < kickoff_at + 120 min` | `live`, `estimated: true` |
  | `now ≥ kickoff_at + 120 min` | `finished`, `estimated: true` |
  | `feed` or `manual` rows | returned as stored, `estimated: false` |

  - Test both boundaries exactly.
  - Clock results never carry `score`, `minute` or `period`.
- [x] T007 [P] [US1] Write `backend/tests/unit/test_time.py` for `app.domain.time`:
  - **Cairo wall clock:** `"10:00 م"` → 22:00 and `ص` → AM; an hour 1–11 with no marker → PM; `"--:--"` → `None`.
  - **Conversion:** to UTC across both 2026 Africa/Cairo DST changes.
  - **Window:** `from < to` and `to − from ≤ 8 days`.
  - **TBD anchor:** a TBD match is in `[from, to)` when `match_date 12:00 Africa/Cairo` is, tested for Riyadh, Paris and Casablanca windows ([R5](research.md#r5-matches-whose-kickoff-time-is-unknown)).
- [x] T008 [P] [US1] Write `backend/tests/unit/test_frequency.py` for `app.domain.frequency`:
  - parse with `^(\d{4,5})\s+([HVLR])\s+(\d{4,5})$` after replacing Cyrillic `Н` with `H`;
  - `"12054 H"`, `"UHF 32"` and `"كازاخستان"` → `frequency_note` (the last is dropped on platform rows);
  - MHz outside 2000–13000 or symbol rate outside 500–60000 → rejected;
  - a satellite `bestFreq`/`worstFreq` with no polarization (`"12166 29700"`) → NULL tuning plus a warning;
  - a repeated frequency in one rights carriage → deduplicated.
- [x] T009 [P] [US1] Write `backend/tests/unit/test_regions.py` for `app.domain.regions` ([R7](research.md#r7-platform-regions)):
  - «البرايزل», «إندونسيا», «هونع كونغ», "United States", "Australia" → their regions;
  - region words («الشرق الأوسط», «أوروبا», «أمريكا الجنوبية») map to their region;
  - «عالمي», empty and unknown values → «أخرى»;
  - `REGION_ORDER` = الشرق الأوسط، أوروبا، آسيا، الأمريكتان، أفريقيا، أوقيانوسيا، أخرى.
- [x] T010 [P] [US1] Write `backend/tests/unit/test_ranking.py` for `app.domain.ranking.headline` ([R2](research.md#r2-personal-channel-line-on-match-rows)):
  - at most 2 entries;
  - on `my_satellite_ids` (or the `satellite_ids` filter) first;
  - otherwise the default satellites `nilesat-7-0w`, `badr-26-0e` or `show_in_match`;
  - then free before encrypted, then `sort_order`, then `id`;
  - hidden or deleted links never appear;
  - platform entries have `satellite` and `frequency` null.
- [x] T011 [P] [US1] Write `backend/tests/unit/test_etag.py` for `app.api.etag` ([R4](research.md#r4-etags-304-and-time)):
  - format `W/"<16 hex>"`;
  - changes with any listed dataset version, the normalized query (parameter order doesn't matter), `MEDIA_BASE_URL`, `CONTRACT_VERSION` and the time bucket (60 s / 15 s);
  - stable within a bucket.
- [x] T012 [P] [US1] Write `backend/tests/db/test_migrations.py`:
  - `backend/alembic/sql/0001_base_schema.sql` has a recorded SHA-256 equal to `../old_app/migration/schema.sql`'s (compare to the sibling file only when it exists);
  - `upgrade head` works on an empty database;
  - every `0002` object in [data-model.md](data-model.md) exists;
  - these CHECKs reject bad rows: `ck_matches_clock_no_score` (a clock row with a score), `ck_matches_time_tbd`, `ck_matches_locked_fields` (an unknown column name), `ck_channels_locked_fields`, `ck_device_follows_one_target` (two targets set), `ck_notification_outbox_status`, `ck_dataset_versions_name`;
  - `dataset_versions` is seeded with the 8 names;
  - `0002` downgrades cleanly.
- [x] T013 [P] [US1] Create the synthetic fixture snapshot in `backend/tests/fixtures/snapshot/hosting/*.json` and `backend/tests/fixtures/snapshot/firestore/*.json`. It uses the real file shapes and contains no real data ([R11](research.md#r11-test-data-without-committing-the-snapshot)). Include at least one row for each case:
  - Cyrillic `Н`; `"12054 H"`; `UHF 32`; `"كازاخستان"`;
  - `""`, `"⚽"` and «غير مدرج»; `"--:--"`; `ص`, `م` and an unmarked hour;
  - one `ysMatchId` on two days; orphan channel ids in `channelIds`, `channelOrder` and `rightsOrder`;
  - an ambiguous team name, a missing team name, and a commentator only on matches;
  - `" Eutel 16.0E"` and `"Eutel 16.0E"`; `DVB T2`;
  - card-sharing labels in `encryption` (`Mega Share`, `Apollo`, `VIP`, «ليست مكسورة», `BISS`);
  - a `carriage_key` duplicate and a `platform_key` duplicate;
  - a hidden channel, both per match and by name;
  - `is_live: true`.
- [x] T014 [P] [US1] Write `backend/tests/db/test_load_snapshot.py`, which loads T013 and asserts:
  - the report reconciles ([contracts/load-report.md](contracts/load-report.md));
  - every README rule 1–17 has an assertion;
  - **idempotency:** a second run reports identical counts and row counts don't change (FR-004);
  - no stored text column contains any card-sharing label (FR-005);
  - `is_live` rows load with `status_source = 'clock'` and `status = 'scheduled'`;
  - every dataset version is bumped;
  - the details JSONL lists each merge and skip.
- [x] T015 [P] [US1] Write `backend/tests/db/test_rehost_media.py` with an `httpx.MockTransport`:
  - an allowlisted host is fetched;
  - any other host → `host_not_allowed`, and no request is made;
  - a redirect to another host is refused;
  - more than 5 MB → `too_large`;
  - an image becomes WebP ≤ 512 px with no EXIF;
  - audio becomes AAC in MP4 ≤ 30 s via ffmpeg;
  - the same bytes under two URLs → one `media_assets` row;
  - a re-run skips an `original_url` already present;
  - a failure leaves the `*_asset_id` NULL.
- [x] T016 [P] [US1] Write `backend/tests/contract/test_public_contract.py`:
  - **Schema:** schemathesis `from_asgi` over `backend/openapi/public.json` with the `not_a_server_error` and `response_schema_conformance` checks.
  - **Envelope:** every FR-008 route returns it.
  - **ETag:** present, plus `Cache-Control: no-cache`; `If-None-Match` → `304` with an empty body ≤ 1 KB; a dataset version bump → `200`.
  - **Health:** `/healthz` returns `200` with an `ETag` and answers a matching `If-None-Match` with `304`; with `HEALTHZ_FORCE_FAIL` set it returns `503 unhealthy` with no `ETag` (constitution VI).
  - **CORS:** only `CORS_ORIGINS` are allowed, and `ETag` is exposed.
  - **Validation (`validation_error`):** a window > 8 days, more than 32 ids in a list, `q` longer than 64 characters.
  - **Not found:** each `<entity>_not_found` code; an unknown route → `not_found`; 405 → `method_not_allowed`.
  - **Errors:** no response body ever contains a traceback.
- [x] T017 [P] [US1] Write `backend/tests/contract/test_matches_semantics.py`:
  - **List:**
    - the window and TBD anchor; order by `kickoff_at`, then `id`, with TBD last;
    - `satellite_ids` filters, and `my_satellite_ids` only reorders `broadcast.headline`;
    - `status=live` filters on the derived status;
    - hidden links never appear in any section;
    - home and away logos fall back to the team logo.
  - **Detail:**
    - `broadcasts` = custom slots, then preferred carriages, free first;
    - `carriages` covers satellite and terrestrial links;
    - `platforms` is grouped in `REGION_ORDER`;
    - `local_broadcaster_eg` is null, `events` is `[]`, `lineups` is null.
  - **Estimated rows:** null `score`, `minute` and `period`.
  - **Size:** one full fixture day of `/v1/matches` gzips to ≤ 60 KB (SC-003).
- [x] T018 [P] [US1] Write `backend/tests/contract/test_admin_auth_contract.py`:
  - **Routes:** `app.admin:app` exposes only `/admin/api/auth/login`, `/admin/api/auth/refresh`, `/admin/api/auth/logout`, `/admin/api/auth/me` and `/admin/api/healthz`.
  - **D1 behaviour:** each auth route returns `501` with `error.code = "not_implemented"`.
  - **OpenAPI:** declares the request and response shapes of [contracts/admin-auth-v1.md](contracts/admin-auth-v1.md), with the named examples `login_ok`, `invalid_credentials` (`meta.attempts_remaining: 3`), `account_locked` (`meta.retry_after_s: 872`) and `validation_error`.
  - **Separation:** `app.public` has no `/admin` route and doesn't import `app.api.admin`.

### Contract (B1, before 13:00)

- [x] T019 [US1] Implement `backend/app/api/envelope.py` and `backend/app/api/errors.py`:
  - a generic `Envelope[T]` model;
  - exception handlers for `HTTPException`, `RequestValidationError`, 404, 405 and unhandled errors, producing the codes in the [contract error table](contracts/public-api-v1.md#errors);
  - `meta.errors = [{loc, type}]` for `validation_error`;
  - `meta.generated_at` on every success;
  - the error is logged with a request id; the body has no traceback.
- [x] T020 [P] [US1] Implement the Pydantic response models in `backend/app/schemas/public.py`, exactly as [contracts/public-api-v1.md](contracts/public-api-v1.md):
  - **Shared parts:** `Frequency`, `SatelliteRef`, `TeamRef`, `CompetitionRef`, `Score`, `CommentatorRef`.
  - **Matches:** `MatchSummary` (with `match_date` and `broadcast.headline` ≤ 2), `MatchDetail` (`local_broadcaster_eg` nullable; `events: []`; `lineups: null`), `LiveState`.
  - **Channels and satellites:** `Satellite`, `ChannelCarriage`, `ChannelDetail`.
  - **Catalog:** `Competition`, `CompetitionDetail`, `TeamSearchItem`, `TeamDetail`, `RightsHolder`, `RightsHolderDetail`, `CommentatorDetail`.
  - **Enums:**
    - status: `scheduled`, `live`, `halftime`, `extra_time`, `penalties`, `finished`, `postponed`, `cancelled`, `abandoned`;
    - period: `1H`, `2H`, `ET1`, `ET2`;
    - pol: `H`, `V`, `L`, `R`;
    - access: `free`, `encrypted`;
    - beam: `wide`, `narrow`;
    - category: `sports`, `entertainment`;
    - sport: `football`, `basketball`, `handball`, `volleyball`, `tennis`;
    - kind: `satellite`, `terrestrial`, `platform`.

  Optional fields are present and `null`, never omitted.
- [x] T021 [P] [US1] Implement `backend/app/schemas/admin.py`:
  - `AdminUser` (role `editor` | `admin`);
  - `Session` (`access_token`, `token_type: "Bearer"`, `expires_in: 900`, `admin`);
  - `LoginRequest`: email in email format, "≤ 254 characters"; password, "1–256" characters;
  - the named OpenAPI examples from [contracts/admin-auth-v1.md](contracts/admin-auth-v1.md).
- [x] T022 [US1] Create the routers in `backend/app/api/` with full signatures and query validation, returning stubs. Each route validates its inputs per [contracts/public-api-v1.md](contracts/public-api-v1.md): the window ≤ 8 days, id lists ≤ 32, `q` ≤ 64, `limit` 1–50 and the enums.
  - **Public routers:** `backend/app/api/public/{matches,live,satellites,channels,competitions,teams,rights_holders,commentators,health}.py`.
  - **`backend/app/public.py`:** builds the FastAPI app with the envelope handlers and CORS from `CORS_ORIGINS` (method `GET`, request header `If-None-Match`, exposed header `ETag`).
  - **Admin:** `backend/app/api/admin/auth.py` (login, refresh, logout, me) and `backend/app/admin.py`. Every auth route returns `501 not_implemented`, and the OpenAPI documents the cookies `madar_refresh`/`madar_csrf` and the `X-CSRF-Token` header.

  `app/public.py` never imports `app.api.admin`.
- [x] T023 [US1] Add the `export-openapi` command to `backend/app/cli.py` (stdlib argparse). It writes `backend/openapi/public.json` and `backend/openapi/admin.json` deterministically (sorted keys, 2-space indent, `info.version = CONTRACT_VERSION`). Commit both files.
- [x] T024 [US1] Freeze the contract in `backend/openapi/` by 13:00:
  1. open a PR with `backend/openapi/*.json`;
  2. the owner reviews `git diff` against `specs/001-d01-foundation/contracts/`;
  3. merge, then `git tag -a contract-v1 -m "D1 contract freeze" && git push origin contract-v1`;
  4. tell Lanes A and M.

  After this, changes to `backend/openapi/*.json` must be non-breaking as FR-014 defines it. `backend.yml`'s `openapi` job (T060) enforces that with `oasdiff breaking`.

### Data and queries (B1, afternoon)

- [x] T025 [US1] Create the Alembic base in `backend/alembic/`:
  - `backend/alembic.ini` and `backend/alembic/env.py`: sync psycopg URL from `DATABASE_URL_SYNC`, with a SQLAlchemy naming convention giving `ck_<table>_<rule>` and PostgreSQL's default names otherwise;
  - `backend/alembic/sql/0001_base_schema.sql`: a byte-for-byte copy of `../old_app/migration/schema.sql`, the only file copied from `old_app` (FR-001);
  - `backend/alembic/versions/0001_base_schema.py`: runs the file with `op.get_bind().exec_driver_sql(sql)`; its downgrade raises.
- [x] T026 [US1] Write `backend/alembic/versions/0002_mvp_additions.py`, part 1, per [data-model.md](data-model.md):
  - **`matches`:**
    - `status text NOT NULL DEFAULT 'scheduled'` with `ck_matches_status` (`scheduled`, `live`, `halftime`, `extra_time`, `penalties`, `finished`, `postponed`, `cancelled`, `abandoned`);
    - `period` with `ck_matches_period` (`1H`, `2H`, `ET1`, `ET2` or NULL);
    - `minute` with `ck_matches_minute` (`^\d{1,3}(\+\d{1,2})?$`);
    - `home_score`, `away_score`, `home_pen`, `away_pen` as `smallint` "≥ 0";
    - `status_source text NOT NULL DEFAULT 'clock'` with `ck_matches_status_source` (`feed`, `manual`, `clock`);
    - `status_label` "≤ 120 characters"; `status_updated_at`;
    - `time_tbd boolean NOT NULL DEFAULT false` with `ck_matches_time_tbd` "`time_tbd = (kickoff_at IS NULL)`";
    - `locked_fields text[] NOT NULL DEFAULT '{}'` with `ck_matches_locked_fields` (subset of the lockable match columns listed in data-model);
    - `ck_matches_clock_no_score` and `ck_matches_scores_pair`;
    - `matches_live_window_idx`.
  - **`channels`:** `locked_fields` with `ck_channels_locked_fields` (the listed channel columns), and `frequency_changed_at timestamptz`.
  - **Search:** `CREATE EXTENSION IF NOT EXISTS pg_trgm`, plus GIN `(name_norm gin_trgm_ops)` on `teams`, `competitions`, `channels` and `commentators`.

  Keep `matches.is_live`.
- [x] T027 [US1] Write `backend/alembic/versions/0002_mvp_additions.py`, part 2 (same file, after T026), per [data-model.md](data-model.md):
  - **`admin_users`:** email unique on `lower(email)`, "≤ 254 characters"; name "≤ 80 characters"; `ck_admin_users_role` (`editor`, `admin`); argon2id `password_hash`; `is_active`; `last_login_at`; `set_updated_at` trigger.
  - **`admin_refresh_tokens`:** `token_hash char(64) NOT NULL UNIQUE`, `family_id uuid`, `expires_at`, `revoked_at`, `replaced_by_id`.
  - **`audit_log`:** `ck_audit_log_action` (`create`, `update`, `delete`, `merge`, `bulk`); `diff jsonb`; the two indexes; a `forbid_delete` trigger.
  - **`devices`:**
    - `install_id uuid UNIQUE`, `token_hash char(64) UNIQUE`;
    - `ck_devices_platform` (`android`, `ios`, `web`);
    - `push_token` UNIQUE, "≤ 4096 characters"; `app_version` "≤ 32"; `locale` "≤ 16"; `tz` "≤ 64";
    - `prefs jsonb`.
  - **`device_follows`:** `ck_device_follows_one_target` "`num_nonnulls(team_id, competition_id, match_id, channel_id, commentator_id) = 1`"; `UNIQUE NULLS NOT DISTINCT` over the six columns; one partial index per target.
  - **`notification_outbox`:**
    - `ck_notification_outbox_type` (the 7 types);
    - `dedupe_key` UNIQUE, "≤ 200 characters";
    - `ck_notification_outbox_status` (`pending`, `sending`, `sent`, `failed`, `cancelled`);
    - `notification_outbox_pending_due_idx`.
  - **`import_runs`:** `items_found`, `items_upserted`, `http_errors`, `status` with `ck_import_runs_status` (`running`, `succeeded`, `partial`, `failed`), and `raw_path`.
  - **`dataset_versions`:** `ck_dataset_versions_name` (`matches`, `live`, `channels`, `satellites`, `competitions`, `teams`, `commentators`, `rights_holders`), seeded with version 0.
  - **Downgrade:** drops everything `0002` added, in reverse order.
- [x] T028 [P] [US1] Create the SQLAlchemy 2 mapped classes for every table the API and loader read in `backend/app/db/models.py`, using the same naming convention, and the engines in `backend/app/db/session.py` (async asyncpg for the API, sync psycopg for the CLI).
- [x] T029 [P] [US1] Implement `derive_status(row, now) -> DerivedStatus` in `backend/app/domain/status.py` until T006 passes.
- [x] T030 [P] [US1] Implement Cairo wall-clock parsing, UTC conversion, window validation and the TBD anchor in `backend/app/domain/time.py` until T007 passes.
- [x] T031 [P] [US1] Implement frequency parsing and domain checks in `backend/app/domain/frequency.py` until T008 passes.
- [x] T032 [P] [US1] Implement the curated country → region map and `REGION_ORDER` in `backend/app/domain/regions.py` until T009 passes:
  - keys are `ar_normalize`d;
  - it covers all 201 platform country values in the snapshot;
  - unmapped values → «أخرى».
- [x] T033 [P] [US1] Implement headline ranking and the preferred-carriage rule in `backend/app/domain/ranking.py` until T010 passes. Default satellite slugs: `nilesat-7-0w`, `badr-26-0e`.
- [x] T034 [US1] Implement the report and the load orchestrator in `backend/app/etl/`:
  - `backend/app/etl/report.py`: the load-report JSON and details JSONL of [contracts/load-report.md](contracts/load-report.md);
  - `backend/app/etl/snapshot.py`: one psycopg transaction calling the steps in T035–T037, then bumping every dataset version last;
  - `load-snapshot --snapshot-dir --report-dir` in `backend/app/cli.py`: exits non-zero unless `reconciled` is true.
- [x] T035 [P] [US1] Implement the reference data in `backend/app/etl/reference.py` (README rules 12–15, 4):
  - **Satellites:** trim names; `" Eutel 16.0E"` → `"Eutel 16.0E Africa"`; `DVB T2` → `terrestrial`; `orbital_position` from the name; `slug`; best and worst tuning.
  - **Competitions** and **teams:** with `ysId` → `team_external_ids`, `ysId` 10089 → first team plus a warning; `team_competitions`.
  - **Commentators:** upsert by `name_norm`, including those found only on matches.
  - **Others:** broadcast presets; `hidden_channel_names` normalized; `livesoccertv_teams` with a unique `team_id` match.
- [x] T036 [P] [US1] Implement channels and rights holders in `backend/app/etl/channels.py` (README rules 5, 9, 10):
  - `kind`: no `satelliteEn` → `platform`; `DVB T2` → `terrestrial`; otherwise `satellite`;
  - `access` rules per kind, with platform → `free` or NULL;
  - `beam` from `bundle`;
  - `encryption` is never read, and `provider`/`package` stay NULL;
  - merge `channels_carriage_key`/`channels_platform_key` duplicates, keeping the lowest `channelOrder`, moving their links and logging the merge;
  - `sort_order` from `channelOrder`;
  - rights holders: carriages, satellites and frequencies with one primary, dropping `satellite[]`.
- [x] T037 [US1] Implement matches in `backend/app/etl/matches.py` (README rules 3, 4, 6–8, 11), after T035 and T036:
  - **Kickoff:** Cairo → UTC; `"--:--"` → `kickoff_at` NULL and `time_tbd` true.
  - **Teams:** ties broken by competition, otherwise `*_team_id` NULL with the name kept.
  - **Match fields:** placeholders → NULL; `source = 'legacy'`; `status_source = 'clock'`, `status = 'scheduled'`; `is_live` ignored.
  - **External ids:** `match_external_ids` for `ysMatchId`, `lstUrl` (path plus `url`) and `seId`.
  - **Merges:** a `ysMatchId` listed twice merges into the listing whose `match_date` is the Cairo date of `kickoff_at`, moving channel links with their hidden flags and commentators.
  - **`match_channels`:**
    - `source` is `ysscores` for `importedChannelIds`, else `legacy`;
    - `is_hidden` comes from `hiddenChannels`;
    - commentators 1 and 2 come per channel;
    - orphans are skipped and logged.
  - **Other links:** `match_custom_broadcasts` slots 1–2; `feeds` with `match_id`.
- [x] T038 [US1] Implement media rehosting in `backend/app/etl/media.py` and `rehost-media --report-dir` in `backend/app/cli.py`, per [R10](research.md#r10-snapshot-loader-and-media-rehosting), until T015 passes:
  - httpx with `follow_redirects=False`, 10 s timeout, 5 MB cap, 4 concurrent downloads;
  - only hosts in `MEDIA_REHOST_ALLOWED_HOSTS`;
  - Pillow → WebP ≤ 512 px with metadata stripped; `ffmpeg -t 30` → AAC in MP4;
  - stored at `MEDIA_ROOT/<kind>/<sha[:2]>/<sha>.<ext>`, one row per SHA-256 with `original_url`;
  - sets every `*_asset_id` from README rule 16;
  - adds the `media` block to the report.
- [x] T039 [US1] Implement `backend/app/api/etag.py` until T011 passes:
  - `compute_etag(route_id, query, datasets, bucket_s)`;
  - a FastAPI dependency that reads `dataset_versions` once, answers `304` on a matching `If-None-Match`, and sets `ETag`, `Cache-Control: no-cache` and `Vary: Accept-Encoding`;
  - the per-endpoint inputs from the [ETag table](contracts/public-api-v1.md#etag-inputs-per-endpoint-research-r4).
- [x] T040 [US1] Implement the `/v1/matches` query in `backend/app/services/matches.py`:
  - the window and TBD anchor; the filters `sport`, `competition_id`, `team_id`, `satellite_ids`;
  - derived `status` and the `status` filter;
  - `broadcast.channel_count`, `has_free` and `headline` (≤ 2) from T033, excluding hidden and deleted links;
  - media URLs from `MEDIA_BASE_URL + "/" + path`;
  - the logo fallback;
  - no N+1 queries: one query per section, batched by match ids.
- [x] T041 [US1] Implement match detail in `backend/app/services/match_detail.py`:
  - `broadcasts` (custom slots, then preferred carriages, free first);
  - `carriages` (satellite + terrestrial, by satellite priority, free first, then `sort_order`) with per-channel commentators 1 and 2;
  - `platforms` grouped by region with T032;
  - `feed_id`;
  - `local_broadcaster_eg: null`, `events: []`, `lineups: null`;
  - `404 match_not_found`.
- [x] T042 [US1] Implement `/v1/live` in `backend/app/services/live.py`: matches with `kickoff_at ∈ [now − 150 min, now + 10 min]` using `matches_live_window_idx`, returning `LiveState` with the derived status.
- [x] T043 [P] [US1] Implement satellites in `backend/app/services/satellites.py`:
  - `/v1/satellites`: ordered by `priority` (nulls last), then `orbital_position`; `channel_count` counts visible carriages.
  - `/v1/satellites/{id}/channels`: `category`, and `q` matching `ar_normalize(q)` in `name_norm` or a frequency digit prefix; ordered by `sort_order` (nulls last), then `name`; `404 satellite_not_found`.
- [x] T044 [P] [US1] Implement `/v1/channels/{id}` in `backend/app/services/channels.py`: `other_carriages` (same `name_norm`, not deleted), `upcoming_matches` (≤ 20, `kickoff_at ≥ now − 150 min`), `recent_frequency_changes: []`, and `404 channel_not_found`.
- [x] T045 [P] [US1] Implement competitions and rights holders in `backend/app/services/catalog.py`:
  - `/v1/competitions[/{id}]`, with `rights_holders` on the detail;
  - `/v1/rights-holders[/{id}]`, with the `satellite_id` and `competition_id` filters through the link tables, and carriages with `frequencies[].is_primary` on the detail;
  - the `404` codes.
- [x] T046 [P] [US1] Implement teams and commentators in `backend/app/services/`:
  - `backend/app/services/teams.py`:
    - `/v1/teams?q`: `limit` 1–50, default 20; order exact `name_norm`, then prefix, then trigram similarity, then `id`; an opaque `next_cursor`;
    - `/v1/teams/{id}`: `competitions`, `upcoming` ≤ 10, `recent` ≤ 10.
  - `backend/app/services/commentators.py`: `/v1/commentators/{id}` with `upcoming` ≤ 20.
  - Both return their `404` codes.
- [ ] T047 [US1] Connect T040–T046 to the routers from T022 through the T039 ETag dependency, then finish `/healthz` in `backend/app/api/public/health.py` and `backend/app/admin.py`:
  - `SELECT 1` plus a Redis `PING`, checked live on every request;
  - `503 unhealthy` on failure, or when `HEALTHZ_FORCE_FAIL` is set;
  - a `200` carries `ETag: W/"<16 hex>"` hashed from `data` and honors `If-None-Match`; a `503` carries no `ETag` ([contract](contracts/public-api-v1.md), constitution VI).

  Then re-run `export-openapi`, run the `oasdiff breaking` check from [quickstart.md](quickstart.md#lane-b1-data-and-contract) against `contract-v1` (it must exit `0`: FR-014 defines non-breaking), and get T016–T018 green.

### Validation (B1)

- [x] T048 [US1] Load the data on VPS-1 with `infra/compose/vps1.yml` (needs B2's T058 and T060):
  1. Copy the refreshed snapshot to `/srv/snapshot/<date>/` over WireGuard (`scp`). Never commit it.
  2. Run `docker compose -f infra/compose/vps1.yml run --rm api-public python -m app.cli load-snapshot --snapshot-dir /srv/snapshot/<date> --report-dir /srv/reports`, then `rehost-media`.
  3. Confirm `reconciled: true` and `checks.card_sharing_labels_found: 0` (SC-002).
  4. Run the [quickstart Lane B1](quickstart.md#lane-b1-data-and-contract) `curl` checks against `https://api.<ip1>.sslip.io`, including the `304` (≤ 1 KB) and no media URL on the old hosts (SC-004).
- [ ] T049 [US1] Confirm the MVP bar: `uv run pytest --cov` passes with `fail_under = 70` on `app/domain`, `app/services` and `app/adapters`, and contract tests cover every FR-008 route (FR-054). Record the coverage figure in the PR.

---

## Lane B2

**Story (User Story 2, P2):** As the owner, I can push to `master` and have each folder built, checked and deployed without touching a server.

**Independent test:**

- a trivial `backend/` merge to `master` is live on VPS-1 within 15 minutes;
- the rollback drill restores the previous image on its own;
- a PR with a fake secret fails;
- the external port scan shows only 80/tcp, 443/tcp and 51820/udp ([quickstart.md](quickstart.md#lane-b2-servers-and-ci)).

**The owner must review:** the firewall rules (T055), the Caddyfile admin site (T057), and the deploy and rollback script (T059).

### Setup (B2)

- [x] T050 [US2] Create `infra/README.md`. It lists:
  - each host's role (SD §7.1);
  - the hostnames and ports (SD §7.2);
  - the required GitHub secrets (`WG_CI_CONFIG`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`, `FIREBASE_SERVICE_ACCOUNT`) and variables (`VPS1_IP`, `VPS2_IP`, `ARM_RUNNER` optional);
  - the host `.env` variables (names only; files live at `/srv/madar/.env`, mode 600);
  - the rule that no key or secret is ever committed.

### Tests first (B2): write them and see them fail

- [x] T051 [P] [US2] Create `.github/workflows/infra.yml`, triggered on `infra/**` and `.github/workflows/**`:
  - `docker compose -f infra/compose/{vps1,vps2,dev}.yml --env-file infra/compose/example.env config -q`;
  - `docker run caddy:2 caddy validate --config infra/Caddyfile` (with example env);
  - shellcheck on `infra/scripts/*.sh`;
  - actionlint on `.github/workflows/*.yml`.
- [x] T052 [P] [US2] Create `.github/workflows/gitleaks.yml`, which runs on every PR and push: the gitleaks CLI container (`zricethezav/gitleaks`) with `git --redact`, failing on findings ([R14](research.md#r14-ci-layout)). Add a `.gitleaks.toml` that extends the defaults and allowlists only `backend/tests/fixtures/` false positives, if any.
- [x] T053 [P] [US2] Create `infra/compose/dev.yml` for local development:
  - `postgres:16` and `redis:7` on `127.0.0.1` with dev-only passwords from `infra/compose/example.env`;
  - a local Caddy with `tls internal` at `https://localhost:8443`, proxying to the host API at `host.docker.internal:8000` for the app's `dev` flavor ([R16](research.md#r16-flavors-hosts-and-https)).
- [x] T054 [P] [US2] Create `infra/compose/example.env`: every variable name used by `vps1.yml`, `vps2.yml` and `dev.yml`, with obviously fake placeholder values and a header saying real values live only on the hosts.

### Hosts and network (B2)

- [x] T055 [US2] Write the firewall rules in `infra/firewall/`, applied with `iptables-restore` and persisted by `netfilter-persistent`, with the ACCEPT rules placed before OCI's default REJECT (SD §7.2, R12):
  - **`infra/firewall/vps1.rules`:**
    - public 80/tcp, 443/tcp and 51820/udp;
    - 22/tcp only on `wg0`;
    - 5432 and 6379 only from VPS-2's VCN IP, plus 6379 on `wg0` for the home box later.
  - **`infra/firewall/vps2.rules`:** 22/tcp only from VPS-1's VCN IP, everything else closed.

  Also write `infra/scripts/check-firewall.sh`, which prints the active and persisted rules and fails if they differ.
- [x] T056 [US2] Set up WireGuard and host bootstrap in `infra/wireguard/` and `infra/scripts/`:
  - **`infra/wireguard/wg0.conf.tmpl`:** hub `Address = 10.8.0.1/24`, `ListenPort = 51820`, key placeholders, one `[Peer]` block per peer with an `AllowedIPs` `/32`.
  - **`infra/wireguard/peer.conf.tmpl`.**
  - **`infra/scripts/wg-add-peer.sh`:** generates keys on the host, never in the repo, and appends the peer.
  - **`infra/scripts/bootstrap-vps.sh <vps1|vps2>`**, idempotent:
    - installs Docker and WireGuard;
    - creates the `deploy` user (docker group, SSH key only);
    - creates `/srv/madar`, `/srv/media`, `/srv/snapshot`, `/srv/reports` and `/srv/app-mirror`;
    - applies T055's rules;
    - installs `/etc/systemd/system/docker.service.d/10-after-wg0.conf` (`Wants=` and `After=wg-quick@wg0.service`), so `api-admin`'s `10.8.0.1` binding exists when Docker starts ([R12](research.md#r12-hosts-networking-and-docker));
    - **refuses to close port 22 to the public until the operator confirms the OCI serial console was tested** (FR-023).
- [x] T057 [US2] Write `infra/Caddyfile` (FR-021):
  - **Global:** ACME email from env.
  - **`api.{$VPS1_IP}.sslip.io`:** `encode zstd gzip`, `reverse_proxy 127.0.0.1:8000`.
  - **`media.{$VPS1_IP}.sslip.io`:** `file_server` on `/srv/media`, `Cache-Control: public, max-age=31536000, immutable`, `X-Content-Type-Options: nosniff`.
  - **`app.{$VPS1_IP}.sslip.io`:** `file_server` on `/srv/app-mirror`, with CORS for `GET` from the two PWA origins.
  - **Every public site:** HSTS, `nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`.
  - **`https://10.8.0.1`:**
    - `bind 10.8.0.1` and `tls internal`;
    - `/admin/api/*` → `reverse_proxy 10.8.0.1:8001`;
    - everything else → `file_server` on `/srv/admin`, with a placeholder `index.html` until D4;
    - `X-Frame-Options: DENY` and `Content-Security-Policy: default-src 'self'`.
- [x] T058 [US2] Write the Compose files in `infra/compose/`. Every image runs on `linux/arm64`, and logging uses the `local` driver with rotation (FR-020, R12).
  - **`infra/compose/vps1.yml`:**
    - `caddy` (`network_mode: host`; mounts the directory `/srv/madar/infra:ro` and runs `caddy run --config <mount>/Caddyfile`, never a single-file mount, because `rsync` replaces the file by rename; plus `/srv/media:ro`, `/srv/app-mirror:ro`, `/srv/admin:ro` and a Caddy data volume);
    - `api-public` (`ghcr.io/<owner>/madar-backend:${IMAGE_TAG}`, `127.0.0.1:8000`);
    - `api-admin` (same image, command `app.admin:app`, published only on `10.8.0.1:8001`, the `wg0` address: constitution V);
    - `migrate` (profile `tools`, `alembic upgrade head`);
    - `postgres:16` (`${VCN_IP}:5432`, volume, password from env, `shared_buffers=1536MB`);
    - `redis:7` (`${VCN_IP}:6379`, `requirepass`, `maxmemory 512mb`);
    - every service gets `env_file: /srv/madar/.env` and a healthcheck.
  - **`infra/compose/vps2.yml`:** `worker-imports`, `worker-scrape`, `worker-live`, `worker-notify`, `worker-maintenance`, `beat` (exactly one) and `flower`, all under profile `workers` so nothing starts until the worker code exists (SD §6.1).

  Bring VPS-1 up with `caddy`, `postgres` and `redis` running, and confirm that `api.`, `media.` and `app.<ip1>.sslip.io` get Let's Encrypt certificates.

### Pipelines (B2)

- [x] T059 [US2] Write `infra/scripts/deploy.sh <image-tag> | --infra-only`, run as `deploy` on VPS-1 from the synced `/srv/madar/infra/` ([R13](research.md#r13-image-build-deploy-and-rollback)):
  1. apply the synced infra: `docker compose up -d caddy postgres redis` (Compose recreates only services whose definition changed), then `docker compose exec caddy caddy reload --config <mount>/Caddyfile`. With `--infra-only`, stop here; no token is read;
  2. record the running tag in `/srv/madar/previous_tag`;
  3. read a GHCR token from stdin, `docker login ghcr.io --password-stdin`, `docker compose pull`, and `docker logout ghcr.io` in an `EXIT` trap, so no registry credential stays on the host;
  4. `docker compose run --rm migrate`, aborting with non-zero **before** touching any running API container if it fails;
  5. `IMAGE_TAG=<tag> docker compose up -d api-public api-admin`;
  6. poll `http://127.0.0.1:8000/healthz` for 60 s;
  7. on failure, `IMAGE_TAG=<previous> docker compose up -d api-public api-admin`, re-check health and exit non-zero.
- [x] T060 [US2] Write `.github/workflows/backend.yml`, triggered on `backend/**`, plus `workflow_dispatch` with an input `break_healthcheck`:
  - **`test`:** `sudo apt-get install -y ffmpeg` (T015 transcodes audio), then ruff, `mypy --strict` and `pytest --cov` with `postgres:16` and `redis:7` services (`TEST_DATABASE_URL`).
  - **`openapi`:** `uv run python -m app.cli export-openapi && git diff --exit-code backend/openapi/`. Once the `contract-v1` tag exists, it also runs the [quickstart](quickstart.md#lane-b1-data-and-contract) `oasdiff breaking` check (a pinned `tufin/oasdiff` image, `--fail-on ERR`) for both specs against the tag (FR-014, SC-001).
  - **`clients`:** runs only if `admin/orval.config.ts` and `app/swagger_parser.yaml` exist. Node 22 + pnpm `orval`, Flutter (pinned) `swagger_parser` + `build_runner`, then `git diff --exit-code admin/src/api/generated app/lib/core/network/generated`.
  - **`build`** (on `master`): buildx + QEMU `linux/arm64` (or `vars.ARM_RUNNER`) with the GHA cache, pushed to `ghcr.io/<owner>/madar-backend:${{ github.sha }}`.
  - **`deploy`** (on `master`, `concurrency: deploy-vps1`, `permissions: packages: read`):
    1. `wg-quick up` from `WG_CI_CONFIG`;
    2. write `DEPLOY_KNOWN_HOSTS` to a known-hosts file, and connect only with `-o StrictHostKeyChecking=yes -o UserKnownHostsFile=<file>` (SSH and `rsync -e`);
    3. `rsync -a --delete infra/ deploy@10.8.0.1:/srv/madar/infra/`;
    4. pipe `${{ secrets.GITHUB_TOKEN }}` to SSH `deploy@10.8.0.1 /srv/madar/infra/scripts/deploy.sh <sha>` on stdin, never as an argument.

    With `break_healthcheck=true` it deploys with `HEALTHZ_FORCE_FAIL=1` for the drill.
  - **`retention`:** `actions/delete-package-versions` keeping the newest 3 `madar-backend` versions.

  Also add a `sync` job to `.github/workflows/infra.yml`: on pushes to `master` only, after its checks pass, in the same `deploy-vps1` concurrency group. It runs steps 1–3 above, then SSH `deploy.sh --infra-only`, so a Caddyfile or Compose change reaches VPS-1 without a backend change.
- [x] T061 [P] [US2] Write `.github/workflows/app.yml`, triggered on `app/**` and `backend/openapi/public.json`:
  - `flutter analyze`;
  - `flutter test` (goldens) inside `ghcr.io/cirruslabs/flutter:<app/.flutter-version>`;
  - `app/tool/check_token_copy.sh` and `app/tool/check_literals.sh`;
  - `flutter build apk --debug --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json`;
  - upload `app-prod-debug.apk` as an artifact (FR-025).
- [x] T062 [P] [US2] Create `infra/firebase/firebase.json` and `infra/firebase/.firebaserc` (Hosting: `public` = `../../app/build/web`; `no-cache` on `index.html`, `flutter_bootstrap.js` and the service workers; `immutable` on hashed files, SD §5.2). Then write `.github/workflows/pwa.yml`, triggered on `app/**` pushes to `master` and `workflow_dispatch`:
  - `flutter build web --release -t lib/main_prod.dart --dart-define-from-file=env/prod.json`;
  - deploy to Firebase Hosting preview channel `master` (`expires: 30d`) with `FirebaseExtended/action-hosting-deploy` and `FIREBASE_SERVICE_ACCOUNT`;
  - print the channel URL.
- [x] T063 [P] [US2] Write `.github/workflows/admin.yml`, triggered on `admin/**` and `backend/openapi/admin.json`: pnpm install (frozen lockfile), `pnpm typecheck`, `pnpm lint`, `pnpm test`, `pnpm build`, `admin/scripts/check-literals.sh`, `admin/scripts/check-token-copy.sh`. No deploy on D1.

### Validation (B2)

- [ ] T064 [US2] Bootstrap both hosts with `infra/scripts/bootstrap-vps.sh`:
  1. test the OCI serial console on both hosts first;
  2. run `infra/scripts/bootstrap-vps.sh vps1` and `vps2`;
  3. add WireGuard peers for the owner and CI;
  4. reboot both hosts and confirm `check-firewall.sh` passes and WireGuard comes back.
- [ ] T065 [US2] Scan VPS-1 from outside WireGuard, as in `specs/001-d01-foundation/quickstart.md` (SC-009):
  - `nmap -Pn -p 22,80,443,5432,6379,8000,8001 <ip1>` shows only 80 and 443 open;
  - UDP 51820 answers;
  - each public host has a valid certificate and the SD §8 headers;
  - `https://10.8.0.1` doesn't answer from the public internet, and does answer over WireGuard.
- [ ] T066 [US2] Run the deploy and rollback drill through `.github/workflows/backend.yml` (SC-005):
  1. merge a trivial `backend/` change and confirm it is live within 15 minutes with no server step;
  2. run `backend.yml` with `break_healthcheck=true` and confirm the job fails and the previous tag is running again;
  3. confirm only 3 package versions remain in GHCR.
- [ ] T067 [US2] Prove secret scanning and CI coverage in `.github/workflows/` (SC-006):
  - open a throwaway PR adding a fake AWS-style key to a test file, confirm `gitleaks.yml` fails, then close the PR;
  - confirm each of `backend.yml`, `admin.yml`, `app.yml`, `infra.yml` and `pwa.yml` has a green run on `master`. Coordinate with Lanes A and M for their first merges.

---

## Lane A

**Story (User Story 4, P4):** As an editor, I see the admin shell and log-in screen in the Madar look, wired to a generated client.

**Independent test:** `pnpm dev` against Prism serving the `contract-v1` admin spec:

- `?mock=invalid_credentials` shows «إيميل أو باسوورد غلط» and «تبقّت 3 محاولات…»;
- `?mock=account_locked` shows the lockout panel with «14:32»;
- `?mock=login_ok` shows the A0 shell, with the sidebar on the right;
- `pnpm test` is green ([quickstart.md](quickstart.md#lane-a-admin)).

**Compare against:** admin board "Login · error + lockout" (`madar-design/admin-react/screens/04-login-and-states/Login.png`) and "Admin components · all states" (`madar-design/admin-react/screens/00-design-system/Comp-Admin.png`).

### Setup (A)

- [X] T068 [US4] Scaffold `admin/` with Vite, React 18 and TypeScript, using pnpm with `admin/pnpm-lock.yaml`:
  - **`admin/tsconfig.json`:** `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`.
  - **Dependencies:** react-router-dom v6, @tanstack/react-query v5, react-hook-form, zod, @hookform/resolvers, axios (the Orval client), clsx, class-variance-authority.
  - **Dev dependencies:** tailwindcss v3, postcss, autoprefixer, vitest, @testing-library/react, @testing-library/user-event, jsdom, msw, orval, @stoplight/prism-cli, eslint + typescript-eslint + eslint-plugin-react-hooks + eslint-plugin-jsx-a11y + eslint-plugin-tailwindcss.
  - **Scripts:** `dev`, `build`, `typecheck`, `lint`, `test`, `orval`, `prism`.
- [X] T069 [P] [US4] Write `admin/CLAUDE.md` (delivery-plan §8.2). It covers:
  - running Vite with the Prism mock;
  - `pnpm orval` regeneration from `backend/openapi/admin.json` (never hand-edited);
  - token and font copies;
  - looking up `madar-design/admin-react/SCREENS.md`;
  - the RTL, digits and error-code rules;
  - the test commands.
- [X] T070 [P] [US4] Copy the design tokens and fonts verbatim into `admin/src/`, and add a copy check ([R15](research.md#r15-tokens-fonts-and-the-generated-client)):
  - `madar-design/design-system/tokens.css` → `admin/src/styles/tokens.css`;
  - `madar-design/design-system/code/react/tokens.ts` → `admin/src/styles/tokens.ts`;
  - `madar-design/design-system/fonts/*.ttf` → `admin/src/assets/fonts/`;
  - `admin/scripts/check-token-copy.sh` runs `cmp` on each copy against its source and fails on any difference.
- [X] T071 [US4] Set up the theme and the RTL root in `admin/tailwind.config.ts`, `admin/src/styles/global.css` and `admin/index.html`:
  - **`admin/tailwind.config.ts`:** colors map to `var(--<token>)` for every `ColorToken`; spacing, radii and shadows come from `tokens.ts`; there is no default palette.
  - **`admin/src/styles/global.css`:** `@font-face` for Changa, IBM Plex Sans Arabic and IBM Plex Mono from the bundled files (`font-display: swap`, no external fetch); tabular numerals on numeric text.
  - **`admin/index.html`:** `<html lang="ar" dir="rtl" data-theme="dark">`, with a CSP `meta` of `default-src 'self'`.
- [X] T072 [P] [US4] Set up linting and the literal check in `admin/eslint.config.js` and `admin/scripts/check-literals.sh`:
  - `admin/eslint.config.js`: `tailwindcss/no-arbitrary-value: error`, react-hooks rules, jsx-a11y, `@typescript-eslint/no-explicit-any: error`;
  - `admin/scripts/check-literals.sh`, which uses `rg` to fail on hex colors, `\d+px` and `font-family` in `admin/src/` outside `admin/src/styles/` and generated folders (SC-008).
- [X] T073 [P] [US4] Write the Arabic copy and the error-code map in `admin/src/i18n/ar.ts`:
  - A0 sidebar labels, in PB §10 A0 order: لوحة المتابعة، المباريات، الفرق، البطولات، القنوات، الأقمار، حقوق البث، المعلقون، الفيدات، القوائم، المصادر، البلاغات [V2]، الإشعارات، المستخدمون، سجل التغييرات;
  - the A1 copy from the Login board;
  - `errorCopy` mapping `invalid_credentials`, `account_locked`, `validation_error`, `not_implemented`, `csrf_failed`, `refresh_invalid`, `unauthenticated`, `token_expired`, `internal_error` and a network error to Arabic text.

  `error.message` is never rendered.
- [X] T074 [US4] Create the test setup in `admin/src/test/setup.ts`: Testing Library, jsdom, an MSW server, and a helper that renders inside `dir="rtl"` with the query client and router.

### Tests first (A): write them and see them fail

- [X] T075 [P] [US4] Write `admin/src/components/SidebarNav/SidebarNav.test.tsx`: every state in `madar-design/design-system/components/SidebarNav/README.md` (active item, grouped sections, attention counts, V2-marked items, signed-in user with role, keyboard focus), plus that it renders in the right-hand position in RTL.
- [X] T076 [P] [US4] Write `admin/src/components/DataTable/DataTable.test.tsx`: every state in `madar-design/design-system/components/DataTable/README.md`:
  - sortable header; competition group rows; row actions on hover/focus;
  - bulk selection with the bulk bar; warning rows; locked-field marker;
  - skeleton and empty states;
  - keyboard navigation.
- [X] T077 [P] [US4] Write `admin/src/components/Field/Field.test.tsx`: every state in `madar-design/design-system/components/FormField/README.md` (label, hint, error, locked, disabled, focus), with label/`aria-describedby` wiring.
- [X] T078 [P] [US4] Write `admin/src/components/StatusChip/StatusChip.test.tsx`: every `kind` in `madar-design/design-system/components/StatusChip/README.md` (send states, `SourceChip`, `RoleChip`, health). Meaning must never depend on color alone: each has a text or icon label.
- [X] T079 [P] [US4] Write `admin/src/components/Toast/Toast.test.tsx`: «تم الحفظ» and «فشل الحفظ» toasts per the toast part of `madar-design/design-system/components/Banner/README.md`, with an `aria-live` region, auto-dismiss timing and reduced motion respected.
- [X] T080 [P] [US4] Write `admin/src/features/shell/Shell.test.tsx`: the A0 sidebar on the right with the T073 labels in order, V2 items marked, and the top bar with global search and the signed-in user and role.
- [X] T081 [P] [US4] Write `admin/src/features/auth/LoginPage.test.tsx` against the Orval MSW handlers:
  - **States:** default, submitting, `invalid_credentials` (shows «إيميل أو باسوورد غلط» and «تبقّت 3 محاولات قبل الإيقاف المؤقت»), `account_locked` (shows «تم إيقاف الدخول مؤقتاً» and a countdown starting at «14:32» from `retry_after_s: 872`), and `validation_error`.
  - **Storage:** after login, `localStorage` and `sessionStorage` hold no token (FR-034).
  - **Error text:** `error.message` text never appears.

### Client and mock (A, after the 13:00 tag)

- [X] T082 [US4] Write `admin/orval.config.ts` and generate the client (from `contract-v1` plus `d01-a`'s non-breaking envelope fix to the spec; Orval has no separate mock path, so the MSW handlers are `admin/src/api/generated/admin.msw.ts`):
  - input `../backend/openapi/admin.json` at tag `contract-v1`;
  - output react-query hooks to `admin/src/api/generated/`, with Zod schemas from the same spec, and MSW handlers to `admin/src/api/mocks/`;
  - an axios mutator `admin/src/api/http.ts` with base URL `/admin/api`, `withCredentials`, and every response parsed with Zod;
  - run `pnpm orval` and commit the output, which is never hand-edited.
- [X] T083 [US4] Configure the Prism mock in `admin/package.json`, `admin/vite.config.ts` and `admin/src/api/http.ts`:
  - a `prism` script: `prism mock ../backend/openapi/admin.json --port 4010`;
  - a Vite dev proxy `/admin/api` → `http://localhost:4010`;
  - in `admin/src/api/http.ts`, only when `import.meta.env.DEV`, a `?mock=<name>` page parameter adds `Prefer: example=<name>` ([contracts/admin-auth-v1.md](contracts/admin-auth-v1.md#prism-usage-lane-a)).

### Implementation (A)

- [X] T084 [P] [US4] Implement `admin/src/components/SidebarNav/SidebarNav.tsx` with cva variants and token classes only, until T075 passes.
- [X] T085 [P] [US4] Implement `admin/src/components/DataTable/DataTable.tsx` (`columns`, `rows`, `groupBy`, `selectable`; keyboard-first) until T076 passes.
- [X] T086 [P] [US4] Implement `admin/src/components/Field/Field.tsx` (`label`, `hint`, `error`, `locked`) until T077 passes.
- [X] T087 [P] [US4] Implement `admin/src/components/StatusChip/StatusChip.tsx` (`Stat`, `SourceChip`, `RoleChip`, `HealthChip`) until T078 passes.
- [X] T088 [P] [US4] Implement `admin/src/components/Toast/Toast.tsx` and `useToast` until T079 passes.
- [X] T089 [US4] Implement the app root and the A0 shell in `admin/src/app/App.tsx` and `admin/src/features/shell/Shell.tsx`:
  - `admin/src/app/App.tsx`: QueryClient, routes `/login` and `/`, and an auth guard that sends unauthenticated users to `/login`;
  - `admin/src/features/shell/Shell.tsx`: `SidebarNav` on the right, the top bar with search and the user and role, and a content outlet with an `EmptyState` placeholder;
  - run until T080 passes.
- [X] T090 [US4] Implement `admin/src/features/auth/LoginPage.tsx`, `admin/src/features/auth/session.ts` and `admin/src/features/auth/useCountdown.ts`, until T081 passes:
  - React Hook Form + a Zod schema built from the generated types;
  - submit with the generated login mutation;
  - the session (access token and `AdminUser`) is held in a React context in memory only;
  - errors map through `errorCopy` by `error.code`;
  - the lockout countdown shows `mm:ss` in Western digits from `meta.retry_after_s`;
  - the note «متاح فقط عبر شبكة WireGuard».

### Validation (A)

- [ ] T091 [US4] Validate the lane in `admin/`:
  1. run `pnpm typecheck && pnpm lint && pnpm test && pnpm build && ./scripts/check-literals.sh && ./scripts/check-token-copy.sh`;
  2. run `pnpm prism` + `pnpm dev`, take screenshots of `/login?mock=invalid_credentials`, `/login?mock=account_locked` and the shell at 1440 px and 1024 px, and compare them with the Login and Comp-Admin PNGs;
  3. attach the screenshots next to the PNGs in the PR (constitution "Done means").

---

## Lane M

**Story (User Story 3, P3):** As a user, I open the app and see today's real matches, in a shell built only from Madar tokens and components.

**Independent test:**

- the goldens pass in the pinned image;
- the `prod`-flavor debug APK from CI, installed on a phone, lists today's local-day matches from VPS-1 (or `EmptyState`);
- `/gallery` opens in the debug build;
- a release build has no `/gallery` ([quickstart.md](quickstart.md#lane-m-app)).

**Compare against:** app boards "Brand, color & type", "Components · Matches", "Components · Channels", "Components · Core, feedback, platform" and "S2 Matches" (`madar-design/app-flutter/screens/00-design-system/*.png`, `madar-design/app-flutter/screens/02-matches/Matches.png`).

**Deviation (plan.md Complexity Tracking):** the D1 matches route reads `/v1/matches` without the stale-while-revalidate repository; that comes on D2.

### Setup (M)

- [x] T092 [US3] Create the Flutter project in `app/` and its flavors:
  - `flutter create --org com.madarsat --project-name madar_sat --platforms android,web app` (O1 package id `com.madarsat.app`);
  - pin the Flutter version in `app/.flutter-version`;
  - Android `productFlavors` `dev` (`applicationIdSuffix ".dev"`), `staging` (`".staging"`) and `prod` (no suffix) in `app/android/app/build.gradle.kts`;
  - remove the counter sample.
- [x] T093 [US3] Add the dependencies in `app/pubspec.yaml` and the lint config in `app/analysis_options.yaml`:
  - **Dependencies:** flutter_riverpod, riverpod_annotation, go_router, dio, retrofit, freezed_annotation, json_annotation, drift, drift_flutter, intl.
  - **Dev dependencies:** build_runner, riverpod_generator, retrofit_generator, freezed, json_serializable, drift_dev, swagger_parser, flutter_lints.
  - **Lints:** `strict-casts`, `strict-inference`, `strict-raw-types`; `prefer_const_constructors` and `use_build_context_synchronously` as errors.
- [x] T094 [P] [US3] Write `app/CLAUDE.md` (delivery-plan §8.2). It covers:
  - the flavors and their run commands;
  - codegen (`dart run swagger_parser`, `dart run build_runner build -d`);
  - token and font copies;
  - looking up `madar-design/app-flutter/SCREENS.md`;
  - the platform-adapter pattern;
  - golden updates only in the pinned container (`flutter test --update-goldens` inside `ghcr.io/cirruslabs/flutter:<pin>`).
- [x] T095 [P] [US3] Create the flavor config and entry points in `app/env/` and `app/lib/`:
  - `app/env/dev.json` (`API_BASE_URL=https://localhost:8443`), `app/env/staging.json` (the LAN Caddy over HTTPS) and `app/env/prod.json` (`https://api.<ip1>.sslip.io`, `https://media.<ip1>.sslip.io`), with public values only;
  - `app/lib/core/config/app_config.dart`, reading them with `String.fromEnvironment`;
  - `app/lib/main_dev.dart`, `main_staging.dart` and `main_prod.dart`.
- [x] T096 [P] [US3] Configure Android networking in `app/android/app/src/main/` ([R16](research.md#r16-flavors-hosts-and-https)):
  - `app/android/app/src/main/res/xml/network_security_config.xml`: system CAs only and `cleartextTrafficPermitted="false"`;
  - a `<debug-overrides>` block that trusts user CAs, so debug builds accept the local Caddy root CA;
  - reference the file from `AndroidManifest.xml`.
- [x] T097 [P] [US3] Copy the design tokens and fonts verbatim into `app/`, and add a copy check:
  - `madar-design/design-system/code/flutter/madar_tokens.dart` → `app/lib/core/theme/madar_tokens.dart`;
  - `madar-design/design-system/fonts/*.ttf` → `app/assets/fonts/`, declared in `pubspec.yaml` under the families `Changa`, `IBM Plex Sans Arabic` and `IBM Plex Mono` with their weights;
  - `app/tool/check_token_copy.sh` runs `cmp` on each copy against its source.
- [x] T098 [P] [US3] Write `app/tool/check_literals.sh` ([R20](research.md#r20-detecting-hard-coded-visual-values)). It uses `rg` over `app/lib/` outside `core/theme/` and `generated/`, failing on:
  - `Color(0x` and `Colors.`;
  - `fontFamily:`;
  - numeric literals in `EdgeInsets.`, `SizedBox(`, `BorderRadius.` and `fontSize:`.
- [x] T099 [US3] Build the theme in `app/lib/core/theme/madar_theme.dart`:
  - `ThemeData` for light and dark from `MadarColors`, `MadarText`, `MadarRadii` and `MadarFonts`;
  - `context.madarColors` access;
  - the app forced RTL and the locale fixed to `ar`, with digits handled by `MadarFormat`.
- [x] T100 [US3] Set up localization: `app/l10n.yaml` and `app/lib/core/l10n/app_ar.arb`, with every string for the components, the matches route and the error-code map (`not_found`, `validation_error`, `internal_error`, network error, the empty day «لا توجد مباريات في هذا اليوم», «لم يُحدد», «مباشر», «انتهت» and the others). No literal user-facing string lives in widgets.

### Tests first (M): write them and see them fail

- [x] T101 [P] [US3] Write `app/test/core/format/digits_test.dart`: Western digits (0–9) for counts, times, scores and frequencies under the `ar` locale, with tabular figures applied ([R19](research.md#r19-western-digits-and-time-formatting)).
- [x] T102 [P] [US3] Write `app/test/core/format/time_test.dart`:
  - local kickoff in 12 h with `ص`/`م` (`9:00 م`) and in 24 h (`21:00`) from a UTC `kickoff_at`;
  - local-day bounds sent as UTC `from`/`to` across a DST change;
  - a `time_tbd` match renders «لم يُحدد».
- [x] T103 [P] [US3] Write `app/test/core/format/bidi_test.dart`:
  - `11843 H 27500` and Latin channel or satellite names render inside an LTR `Directionality` island in an RTL tree;
  - a score is built from isolated parts, never a raw `1 - 0` string.
- [x] T104 [P] [US3] Write `app/test/core/db/matches_table_test.dart`: an in-memory drift database writes and reads back a `MatchSummary` fixture unchanged, including the nested `competition`, `home`, `away`, `broadcast.headline` and the null `score`.
- [x] T105 [P] [US3] Write `app/test/core/router/router_test.dart`:
  - every PB §8.4 route resolves to its stub screen RTL, including `/`, `/live`, `/day/2026-10-28`, `/match/1`, `/my-satellites`, `/satellites`, `/satellites/1`, `/channel/1`, `/team/1`, `/competition/1`, `/favorites`, `/rights`, `/rights/1`, `/feeds`, `/search?q=x`, `/settings` and `/install`;
  - the back arrow points right;
  - `/gallery` exists only when `kDebugMode` is true (FR-045).
- [x] T106 [US3] Create the golden harness in `app/test/`:
  - `app/test/flutter_test_config.dart` loads the bundled TTFs with `FontLoader`;
  - `app/test/goldens/golden_harness.dart` provides `goldenVariants(name, builder)`, which renders each case in RTL × {light, dark} × text scale {1.0, 1.3} on a 360-dp-wide surface ([R18](research.md#r18-golden-tests)).
- [x] T107 [P] [US3] Write `app/test/goldens/match_row_test.dart`: `MatchRow` in every state from `madar-design/design-system/components/MatchRow/README.md`, including long Arabic names over two lines, a followed star, a channel line with `+N` and «مجانية», and no channel line. Add a `find.bySemanticsLabel` test: the row is one merged node whose Arabic label reads home, away, status, score and minute when shown, and the headline channel, in the PB §13.8 form «الأهلي ضد الزمالك، مباشر، الدقيقة 67، النتيجة 1 مقابل 0، على أون سبورت 1». An estimated-live row's label has no score or minute.
- [x] T108 [P] [US3] Write `app/test/goldens/status_block_test.dart`: `StatusBlock` in every PB S2 variant:
  - scheduled; imminent `بعد 25 د`; live score + minute; halftime; extra time; penalties `(4-3)`; finished;
  - postponed, cancelled, abandoned;
  - **estimated live: «مباشر» with no score and the quieter treatment**;
  - time unknown «لم يُحدد».
- [x] T109 [P] [US3] Write `app/test/goldens/frequency_readout_test.dart`: `FrequencyReadout` at its sizes and in its states (`ok`, `dim`, `note`, good, bad) from its README. It stays a dark well with cyan IBM Plex Mono digits, LTR, in **both** themes.
- [x] T110 [P] [US3] Write `app/test/goldens/carriage_row_test.dart`: `CarriageRow` collapsed (logo, name, access badge, satellite, readout visible) and expanded, with free and encrypted variants and the long-name truncation from its README. Add a `find.bySemanticsLabel` test: the collapsed row is one merged node whose Arabic label gives the channel, free or encrypted, the satellite and the frequency (PB §13.8).
- [x] T111 [P] [US3] Write `app/test/goldens/access_badge_test.dart`: `AccessBadge` free and encrypted (neutral with a lock, never the error color), plus `SatelliteBadge` and `ChangedBadge`, per `madar-design/design-system/components/Badges/README.md`.
- [x] T112 [P] [US3] Write `app/test/goldens/date_strip_test.dart`: `DateStrip` with today marked, a selected day and RTL order, per its README.
- [x] T113 [P] [US3] Write `app/test/goldens/bottom_nav_test.dart`: `MadarBottomNav` with each of the 5 destinations current, a badge, RTL order (المباريات first on the right), and touch targets ≥ 48 dp.
- [x] T114 [P] [US3] Write `app/test/goldens/top_bar_test.dart`: `MadarTopBar.root()` (the wordmark «مدار» at the start (right) and search at the end) and the detail variant (back arrow pointing right, title, up to 2 actions).
- [x] T115 [P] [US3] Write `app/test/goldens/empty_state_test.dart`: `EmptyState` with the orbit-ring illustration, title, help line and at most one action, covering the empty-day and load-failed copy.
- [x] T116 [P] [US3] Write `app/test/goldens/skeleton_test.dart`: `Skeleton` for the S2 first load (3 groups × 3 rows), static when reduced motion is on.
- [x] T117 [P] [US3] Write `app/test/goldens/logo_test.dart` per `madar-design/design-system/components/Logo/README.md`: `BrandMark` at 28, 40 and 64 (ink tile, bare ring, single-ink) and with the «مدار» wordmark; `TeamCrest` with a logo and with the first-letter shield fallback; `LogoTile` with a logo and with each entity fallback in the README, always on the neutral tile. Logos come from a test asset image, never the network.
- [x] T118 [P] [US3] Write `app/test/features/matches/matches_page_test.dart` with a fake generated API client:
  - rows render teams and local kickoff in Western digits;
  - an empty response shows `EmptyState` «لا توجد مباريات في هذا اليوم»;
  - an `error.code` failure shows the mapped Arabic error;
  - the request window is the device's local day sent as UTC bounds (FR-048).

### Implementation (M)

- [x] T119 [P] [US3] Implement `MadarFormat` in `app/lib/core/format/` (`digits.dart`, `time.dart`, `bidi.dart`) until T101–T103 pass.
- [x] T120 [US3] Implement the router in `app/lib/core/router/app_router.dart` until T105 passes:
  - go_router with every PB §8.4 route as a stub screen;
  - a `/gallery` route added only when `kDebugMode` is true.
- [x] T121 [US3] Generate the API client in `app/lib/core/network/generated/` after B1's T024 tag:
  - `app/swagger_parser.yaml`: input `../backend/openapi/public.json` at tag `contract-v1`, output `app/lib/core/network/generated/`, retrofit + freezed;
  - run `dart run swagger_parser && dart run build_runner build -d` and commit the output, which is never hand-edited.
- [x] T122 [US3] Implement the network and database core in `app/lib/core/`:
  - `app/lib/core/network/dio_provider.dart`: one Dio with the base URL from `AppConfig`, timeouts, and an `EtagInterceptor` (`app/lib/core/network/etag_interceptor.dart`) that stores ETags per URL in memory and sends `If-None-Match`;
  - `app/lib/core/db/app_database.dart`: the drift `Matches` table with `MatchSummary` fields and nested parts as JSON columns, `drift_flutter` for native and web;
  - run until T104 passes.
- [x] T123 [P] [US3] Implement `app/lib/design/components/logo.dart` (`BrandMark`, `TeamCrest`, `LogoTile`) until T117 passes. Finish it before T124, T127 and T131, which use it.
- [x] T124 [P] [US3] Implement `app/lib/design/components/match_row.dart` (`MatchRow(match:, onTap:, onLongPress:)`) until T107 passes. Wrap it in `MergeSemantics` with the Arabic label built from `MadarFormat` and ARB strings, never string literals in the widget.
- [x] T125 [P] [US3] Implement `app/lib/design/components/status_block.dart` (`StatusBlock(status:, kickoff:, score:, minute:)`) until T108 passes.
- [x] T126 [P] [US3] Implement `app/lib/design/components/frequency_readout.dart` (`FrequencyReadout(mhz:, polarization:, symbolRate:, size:)`) until T109 passes.
- [x] T127 [P] [US3] Implement `app/lib/design/components/carriage_row.dart` until T110 passes, with the same `MergeSemantics` label approach as `MatchRow`.
- [x] T128 [P] [US3] Implement `app/lib/design/components/badges.dart` (`AccessBadge`, `SatelliteBadge`, `ChangedBadge`) until T111 passes.
- [x] T129 [P] [US3] Implement `app/lib/design/components/date_strip.dart` until T112 passes.
- [x] T130 [P] [US3] Implement `app/lib/design/components/bottom_nav.dart` (`MadarBottomNav(current:)`) until T113 passes.
- [x] T131 [P] [US3] Implement `app/lib/design/components/top_bar.dart` (`MadarTopBar.root()`, `MadarTopBar.detail(...)`) until T114 passes.
- [x] T132 [P] [US3] Implement `app/lib/design/components/empty_state.dart` until T115 passes.
- [x] T133 [P] [US3] Implement `app/lib/design/components/skeleton.dart` until T116 passes.
- [x] T134 [US3] Implement the gallery in `app/lib/features/gallery/presentation/gallery_page.dart`: every FR-043 component in every state, with theme and text-scale toggles. Register it only when `kDebugMode` is true (FR-045).
- [x] T135 [US3] Implement the matches route in `app/lib/features/matches/`, until T118 passes:
  - `app/lib/features/matches/data/matches_api.dart`: wraps the generated client and computes today's local-day `from`/`to` in UTC;
  - `app/lib/features/matches/presentation/matches_page.dart`: a Riverpod provider and unstyled rows with `ListView.builder`, `EmptyState`, and error copy by `error.code`;
  - add a code comment pointing to the plan.md deviation (SWR repository on D2).

### Validation (M)

- [ ] T136 [US3] Validate the lane in `app/`:
  1. run `flutter analyze`, `./tool/check_token_copy.sh` and `./tool/check_literals.sh`;
  2. run `flutter test` inside `ghcr.io/cirruslabs/flutter:<pin>` (all goldens pass);
  3. install the CI `app-prod-debug.apk` on an Android phone and confirm the matches route lists today's matches from VPS-1 (or `EmptyState`) and that `/gallery` opens;
  4. take screenshots of the gallery in both themes and compare them with the four design-system PNGs and `Matches.png`;
  5. build and serve the web app, and confirm in Chrome DevTools → Network that `/gallery` and the matches route make no request to `fonts.gstatic.com` or `fonts.googleapis.com` ([quickstart.md](quickstart.md#lane-m-app), FR-042). Fix a hit by bundling the missing glyphs, never by allowing the fetch;
  6. attach the screenshots and the Network result to the PR.

### Review fixes (round 1)

Source: [reviews/m-round-1.md](reviews/m-round-1.md). Fix in this order, then re-run `/speckit-review-implementation lane m` as round 2.

- [x] M-R1-1 [US3] Make the dark goldens really dark (FR-044, SC-007). In `app/test/goldens/golden_harness.dart`, apply the theme before each capture (for example `pumpAndSettle`, or pass `themeAnimationDuration: Duration.zero` to `MaterialApp`), and turn off `debugShowCheckedModeBanner`. Regenerate the goldens only in the pinned container (after M-R1-7). Add a check that fails if a light and a dark PNG of the same component and scale are byte-identical.
- [x] M-R1-2 [US3] Make the goldens and `app/test/core/format/time_test.dart` independent of the host time zone. Render fixed kickoff times by building the widgets from a known local `DateTime` (or injecting the offset), and write the spring-forward test with explicit UTC instants. Prove it by running `TZ=UTC flutter test` and `TZ=Africa/Cairo flutter test`; both exit 0 with no golden changes between them.
- [x] M-R1-3 [US3] Make the drift `Matches` table round-trip a `MatchSummary` unchanged (FR-047, US3-7). In `app/lib/core/db/app_database.dart`, read `kickoffAt`, `matchDate` and `updatedAt` back as UTC (a converter or `.toUtc()` in `readAll`), and store unknown `sport` and `status` values so they read back as the same value instead of `''`. Change `app/test/core/db/matches_table_test.dart` to `expect(read, fixture)` on the whole object, including a `kickoffAt` of `null` and an unknown status.
- [x] M-R1-4 [US3] Show the error state without the 38-second retry delay (FR-048). In `app/lib/features/matches/presentation/matches_providers.dart`, give `matchesProvider` a `retry:` that does not retry (or at most one quick retry) so the `error.code` copy appears right away. Add a widget test that overrides the API to throw a `MatchesFailure` and expects the `EmptyState` (error kind) after one `pump()`, not a `Skeleton`.
- [x] M-R1-5 [US3] Remove missing glyphs from the golden images. Load the icon font in `app/test/flutter_test_config.dart` so icons draw, replace `'$minute′'` in `app/lib/design/components/status_block.dart` (lines 93 and 122) with a localized minute string from `app_ar.arb` or confirm U+2032 exists in the bundled fonts, and regenerate the goldens (in the pinned container). Open one regenerated PNG and confirm no empty squares remain.
- [x] M-R1-6 [US3] Add `<uses-permission android:name="android.permission.INTERNET"/>` to `app/android/app/src/main/AndroidManifest.xml`. Release signing with the debug key (`app/android/app/build.gradle.kts:56-58`) stays a TODO only if `docs/owner-actions.md` names it as an owner action for the day the first release is cut; add that line there.
- [x] M-R1-7 [US3] Make `app/.flutter-version` name a Flutter version that has a `ghcr.io/cirruslabs/flutter` image (verify with `docker manifest inspect ghcr.io/cirruslabs/flutter:<version>`) that still builds the app and passes `flutter analyze`. Then update `docs/owner-actions.md` (golden container tag) and `docs/runbooks/ci-workflows.md` if they name the old value. If no such image exists for the Flutter version the project needs, say so in `docs/owner-actions.md` and ask the owner which image to use; do not guess.

### Review fixes (round 2)

Source: [reviews/m-round-2.md](reviews/m-round-2.md). The owner's open decision on the golden image (M-R1-7, `docs/owner-actions.md` "Golden container tag") has no task here; when it is made, regenerate the goldens in the chosen image. Then re-run `/speckit-review-implementation lane=m` as round 3.

- [x] M-R2-1 [US3] Make the drift `Matches.matchDate` round-trip a real parsed `MatchSummary` (FR-047, US3-7, constitution II). In `app/lib/core/db/app_database.dart` (lines 26, 74, 106) `match_date` is a calendar date (`format: date`), and the generated model parses `'2026-10-28'` to local midnight; the code stores and reads `.toUtc()`, so under `TZ=Africa/Cairo` the day reads back as 27 October and `==` is false in every zone. Store the date as `yyyy-MM-dd` text (or a drift converter) and read it back as `DateTime(y, m, d)`; regenerate with `dart run build_runner build -d`. `schemaVersion` stays 1 while nothing in `lib/` calls `replaceDay`; add a migration step if that changes first. In `app/test/core/db/matches_table_test.dart` build the fixtures with `MatchSummary.fromJson` (`'match_date': '2026-10-28'`) instead of `DateTime.utc(2026, 10, 28)` (`app/test/fixtures/sample_models.dart:34`), `expect(read, fixture)`, and run `TZ=UTC flutter test` and `TZ=Africa/Cairo flutter test`. The test fails before the fix, even in UTC. (MEDIUM, per FR-047)
- [x] M-R2-2 [US3] Remove the layout literals the SC-008 script cannot see, then make the script see them (FR-042, SC-008, constitution IV). Literals: `app/lib/core/format/bidi.dart:67` (`horizontal: 6`), `app/lib/design/components/status_block.dart:309-310` (`MadarSpace.s1 + 2`), `:333` (`strokeWidth = 1`), `:337-338` (`dash = 4.0`, `gap = 3.0`) and `app/lib/features/matches/presentation/matches_page.dart:54` (`Divider(height: 1, …)`). Use `MadarSpace`, `MadarRadii` and other tokens; if the design needs a step the tokens lack (for example 6 dp), ask the owner to add it through `madar-design/design-system/tokens.json` and `generate_tokens.py`, never in the copied `madar_tokens.dart`. Widen `app/tool/check_literals.sh` to match `EdgeInsets\w*`, `Divider(`, `strokeWidth` and `Madar\w+\.\w+ \+ \d`. Prove it: the widened script exits non-zero on the tree before the fix and zero after. If lean-ctx blocks the script, ask the owner to run `lean-ctx allow check_literals.sh`. (MEDIUM, per SC-008)

---

## Done check

VPS-1 serves `/v1` with snapshot data over HTTPS; contract tagged `v1`; admin login screen renders against the mock; the app shows the component gallery (goldens pass) and loads `/v1/matches`; CI green in all four folders
