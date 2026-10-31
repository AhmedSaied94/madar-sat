---

description: "D2 · Core flows: tasks per lane"
---

# Tasks: D2 · Core flows

**Input**: Design documents from `specs/002-d02-core-flows/`: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md).

**Tests**: Mandatory (constitution, Quality Gates). In every lane, the test tasks come first and must be seen failing before the code they cover (FR-053, [research R28](research.md#r28-what-is-written-first)). The coverage bar is the MVP bar in FR-054.

**Organization**: one `## Lane` section per lane, each an independently testable user story, plus a final `## Done check`.

- A lane implements and ticks **only its own section** and changes only its own folders (FR-051). The one exception: the PR that changes an OpenAPI spec regenerates both clients and commits the generator output unedited (D14), because `backend.yml`'s `clients` job fails on a stale client.
- Review fix tasks are appended at the end of a lane's section by `/speckit-review-implementation`.

| Section | Spec story | Story label | Branch | Folders |
| --- | --- | --- | --- | --- |
| Lane B1 | User Story 1 (P1) | `[US1]` | `d02-b1` | `backend/` except `backend/app/adapters/` and `backend/tests/adapters/`; plus the generator output in `admin/src/api/generated/` (and `app/lib/core/network/generated/`) in a PR that changes an OpenAPI spec |
| Lane B2 | User Story 2 (P2) | `[US2]` | `d02-b2` | `infra/`, `.github/`, `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/{ysscores,satair_bridge}/` |
| Lane A | User Story 4 (P4) | `[US4]` | `d02-a` | `admin/` |
| Lane M | User Story 3 (P3) | `[US3]` | `d02-m` | `app/` |

Every lane may also edit `docs/runbooks/` for its own parts and its own section of `docs/owner-actions.md` (FR-055).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task).
- **[USn]**: the spec story the task belongs to.
- Paths are repo-relative.

## Dependencies & execution order

### Between lanes

- **Admin contract at 13:00:**
  - T015 (B1: the admin OpenAPI, the regenerated admin client and B2's blockers, merged to `master`) blocks Lane A's T093.
  - Before then, A builds its components, `cairoTime` and the A3 and A4 layouts, with their tests.
- **B2 needs B1's morning blockers**, which reach `master` in T015's PR:
  - T001 (the `celery[redis]` and `lxml` dependencies), T006 (the `app.workers` app), T008 (`app/media/`) and T010 (revision `0003`, for `match_channels.imported_by` and `audit_log.source`).
  - B2 writes its tests, saved pages, adapter base, fetcher and infra files before them. T073–T076 wait for them.
- **B1's deploy needs B2's host changes:** T047 (B1 on VPS-1) needs T078 (`vps1.yml`: api-admin's proxy flags, `/srv/media` read-write, `ADMIN_JWT_SECRET`) and T085 (`backend.yml`). Until then, B1 verifies locally with `infra/compose/dev.yml`.
- **A over WireGuard:** T107 step 3 needs T047 (the admin API deployed, and the first admin created).
- **M:** needs nothing new from B1. The PWA preview check (T137) needs the owner's `CORS_ORIGINS` change on VPS-1.
- **Done check:** all four lanes.

### Inside each lane

```text
Setup → Tests (must fail) → implementation in the listed order → Validation
```

`[P]` tasks inside a block can run together.

### Parallel examples

```text
B1 tests:   T016–T021 (auth, roles, status, versions) together; T022–T030 (writes, lists, uploads, contract) after T005
B1 domain:  T031, T032, T033 together; T037, T038 together
B2 tests:   T055–T067 together after T051 and T052
B2 infra:   T078, T079, T080, T081, T082, T084 together
A:          T094–T097 (lib and component tests) together; T100, T101, T102 together
M:          T112–T122 together after T109; T125 (components) as five parallel files
```

## Implementation strategy

1. **Morning:** each lane sets up and writes its failing tests; B1 writes its own after the 13:00 merge, so that PR stays green. B1 builds B2's blockers (dependencies, `app.workers`, `app/media/`, `0003`) and the admin contract. B2 saves the pages, builds the adapter base and writes the host files. A builds components. M builds the SWR repository and the new components.
2. **13:00:** B1 merges the admin contract, the regenerated admin client and B2's blockers (T015). A and B2 rebase on it.
3. **Afternoon:** B1 builds auth, the writer and the routes. B2 builds resolution, upsert, the bridge, tasks and the VPS-2 deploy. A builds A3 and A4 against Prism. M builds S2–S5 and live polling.
4. **Evening:** B1 deploys and the owner creates the first admin. B2 checks the first unattended run. A checks A3 and A4 over WireGuard. The owner tags `app-v0.2.0` and uploads the AAB. Then the Done check.

Each lane merges at least twice (delivery-plan §5.2): once at the contract or scaffold point, once at the end.

---

## Lane B1

**Story (User Story 1, P1):** As an editor, I edit any MVP entity safely through the admin API, and the edit is live in `/v1` within 60 s.

**Independent test:** on a database loaded with the snapshot:

1. create the first admin with the CLI and log in;
2. update one match's kickoff and channels with `If-Match`;
3. check the audit entry and its diff, the bumped `matches` version, the edited fields in `locked_fields`, a `409` when the old `If-Match` is sent again, and the change with a new `ETag` from `/v1/matches`;
4. set the match to manual live, 1–0, and see `/v1/live` serve it with `estimated: false`; clear it, and the clock estimate returns ([quickstart.md](quickstart.md#lane-b1-admin-api)).

**The owner must review:** the admin contract diff (T015), revision `0003` (T010), `backend/app/auth/` (T031–T034), and the role dependency with its test (T019, T034).

### Setup (B1)

- [X] T001 [US1] Add the D2 dependencies to `backend/pyproject.toml` and refresh `backend/uv.lock`:
  - **Runtime:** `argon2-cffi`, `PyJWT`, `python-multipart`, `celery[redis]`, and `lxml` (Lane B2's parser, added here because B1 owns the file; [research R13](research.md#r13-the-celery-app-and-queues)).
  - **Coverage:** `[tool.coverage]` keeps `fail_under = 70` over `app/domain`, `app/services` and `app/adapters` (FR-054).
  - Merge this in the morning: B2 needs it (Dependencies).
- [X] T002 [P] [US1] Extend `backend/app/settings.py`:
  - `ADMIN_JWT_SECRET`: `SecretStr | None`, no default. `app/admin.py` checks it at startup and refuses to start when it is missing or shorter than 32 bytes ([R2](research.md#r2-access-jwt-refresh-rotation-and-csrf)). `app.public:app` and the workers never need it.
  - `CELERY_BROKER_URL` is **not** added here. `Settings` requires the database, media and CORS values, which the home box doesn't have (FR-028), so the worker app reads its broker from its own small settings class (T006).
  - No secret gets a default value.
- [X] T003 [P] [US1] Update `backend/CLAUDE.md`:
  - the `app/auth/`, `app/services/admin/`, `app/media/` and `app/workers/` modules, and that `app/adapters/` and `tests/adapters/` are Lane B2's;
  - `0001`–`0003` are never edited after merge;
  - the new CLI commands, and that passwords are never accepted as arguments;
  - the writer unit of work is the only path for admin mutations;
  - a PR that changes `backend/openapi/*.json` also regenerates both clients (`cd admin && pnpm install && pnpm orval`; `cd app && flutter pub get && dart run swagger_parser && dart run build_runner build -d`) and commits their output unedited, because `backend.yml`'s `clients` job fails on a stale client (D14, [ci-workflows.md](../../docs/runbooks/ci-workflows.md)).
- [X] T004 [P] [US1] Add the D2 error codes of [contracts/admin-api.md](contracts/admin-api.md#errors-added-on-d2) to `backend/app/api/errors.py`, each with its status and `meta` keys: `forbidden` (`required_role`), the seven `*_not_found` codes including `hidden_name_not_found`, `edit_conflict` (`current_etag`, `changed_by {kind, name}`, `changed_at`, and `stale_ids` for bulk), `in_use` (`usage`), `already_exists` (`field`), `file_too_large` (`max_bytes`), `unsupported_media_type`, `media_invalid` and `precondition_required`. No error body ever contains a traceback.
- [X] T005 [US1] Extend `backend/tests/conftest.py`:
  - a Redis fixture on `TEST_REDIS_URL` (already set in CI), flushed before each test, used by api-admin's login limits;
  - helpers that create an `editor` and an `admin` with a known password, and `editor_client` / `admin_client` fixtures carrying a valid bearer token;
  - an `etag_of(client, path)` helper that GETs an entity and returns its `ETag`;
  - the snapshot fixture from D1 loaded once per session for the admin tests.

### B2's morning blockers (B1)

- [X] T006 [US1] Write `backend/tests/unit/test_workers.py` (see it fail), then create the `app.workers` Celery app in `backend/app/workers/__init__.py`, `backend/app/workers/config.py`, `backend/app/workers/base.py` and `backend/app/workers/locks.py` ([R13](research.md#r13-the-celery-app-and-queues)):
  - **Broker:** `backend/app/workers/config.py` is a pydantic-settings class that reads only `CELERY_BROKER_URL`, falling back to `REDIS_URL` (`vps2.yml` names the first; the home box sets only the second). Importing `app.workers` never calls `app.settings.get_settings()` and never imports `app.db`. The app uses `broker_transport_options = {"global_keyprefix": "celery:"}`.
  - **Settings:** `task_ignore_result=True`, `task_acks_late=True`, `task_reject_on_worker_lost=True`, `worker_prefetch_multiplier=1`, JSON serializers only.
  - **Queues:** `scrape`, `scrape_home`, `imports`, `maintenance`, `media`, plus the idle `live` and `notifications`.
  - **Base task:** `bind=True`, `autoretry_for=(Retryable, httpx.TransportError)`, `retry_backoff=True`, `retry_backoff_max=600`, `retry_jitter=True`, `max_retries=5`. `Retryable` lives in `app/workers/base.py` so B2 can raise it.
  - **Locks:** a `redis_lock(name, ttl)` context manager with `SET NX EX` that yields `False` when the lock is held, and deletes only its own token on exit.
  - It autodiscovers `app.adapters.tasks` and `app.adapters.media_tasks`, and takes `beat_schedule` from `app.adapters.schedule`, when those modules exist (an `ImportError` there leaves an empty schedule, so B1 can merge first).
  - **Tests:** the key prefix, the queue names, the base task's retry options, that a second `redis_lock` on the same name yields `False`, and that a subprocess with only `REDIS_URL` in its environment can `import app.workers` and read the broker URL.
- [X] T007 [US1] Run the D1 media tests in `backend/tests/db/test_rehost_media.py` and confirm they are green before the move (they are the safety net for T008).
- [X] T008 [US1] Move the D1 media code into `backend/app/media/`, shared by the uploads (T044) and B2's logo worker:
  - `backend/app/media/fetch.py`: `fetch_media` (allowlist, no redirect to another host, 5 MB cap);
  - `backend/app/media/encode.py`: `_encode_image` and `_encode_audio` as public `encode_image` (WebP ≤ 512 px, no EXIF, `Image.MAX_IMAGE_PIXELS = 40_000_000`) and `encode_audio` (`ffprobe`, then `ffmpeg -t 30` to AAC in MP4), and `download_and_encode`;
  - `backend/app/media/store.py`: content-addressed storage under `MEDIA_ROOT` returning the existing `media_assets` row for a known `sha256`.

  `backend/app/etl/media.py` keeps only what `rehost-media` needs and imports the rest. `test_rehost_media.py` stays green with no change to its assertions.
- [X] T009 [US1] Add revision `0003` cases to `backend/tests/db/test_migrations.py` and see them fail ([data-model](data-model.md#revision-0003-audit-source-and-link-origin)):
  - `audit_log.source` references `sources (name)`; `ck_audit_log_actor` rejects a row with both `admin_user_id` and `source`;
  - `match_channels.imported_by` references `sources (name)` and is backfilled with `source` wherever `source <> 'manual'` (snapshot links become `legacy`);
  - `downgrade 0002` drops both columns and the CHECK and leaves every other row unchanged; `upgrade head` again works.
- [X] T010 [US1] Write `backend/alembic/versions/0003_audit_source_link_origin.py` (psycopg, like `0002`) and the matching columns in `backend/app/db/models.py`, exactly as the [data-model revision](data-model.md#revision-0003-audit-source-and-link-origin): `audit_log.source text REFERENCES sources (name)`, `ck_audit_log_actor` (`admin_user_id IS NULL OR source IS NULL`), `match_channels.imported_by text REFERENCES sources (name)` with the backfill `UPDATE match_channels SET imported_by = source WHERE source <> 'manual'`, no index, and a downgrade that drops both and the CHECK. T009 passes.

These five tasks (T006, T007, T008, T009, T010), with T001, go to `master` in the 13:00 contract PR (T015), so B2 can build on them in the afternoon. They leave the suite green.

### Admin contract (B1, before 13:00)

- [X] T011 [US1] Write the admin shapes in `backend/app/schemas/admin.py` (Pydantic v2, `extra="forbid"`) exactly as [contracts/admin-api.md](contracts/admin-api.md):
  - `AdminMatchRow`, `AdminMatch`, `MatchPatch` (sections `fields`, `broadcasts`, `channels`, `status` with `set` or `clear`), `MatchCreate`, `BulkRequest` (`change_competition`, `remove_channels`) and `BulkResult`;
  - `TeamItem`, `AdminTeam`, `AdminCompetition`, `AdminSatellite`, `ChannelItem`, `AdminChannel`, `AdminCommentator`, and their create and patch bodies;
  - `BroadcastPreset`, `HiddenChannelName`, `SourceItem`, `MediaAsset`.

  Validation quoted from [data-model.md](data-model.md#validation-rules-from-the-spec):
  - "names ≤ 120 characters"; "`competition_stage` ≤ 80, `stadium` ≤ 120"; "broadcaster `label` ≤ 80, `status_label` ≤ 80"; "`q` ≤ 64";
  - "up to 300 links per match, and up to 200 items per bulk request";
  - `minute`: "optional, ≤ 8 characters, `^\d{1,3}(\+\d{1,2})?$`"; `period`: `1H`, `2H`, `ET1`, `ET2`;
  - `home` and `away` take exactly one of `team_id` or `name`; `competition_name` is required when `competition_id` is null;
  - "**Kickoff:** an ISO-8601 UTC instant, or `time_tbd: true` with a `match_date`";
  - channel `frequency` is all three values or null, with D1's `^(\d{4,5})\s+([HVLR])\s+(\d{4,5})$` rule; `reception_url` is `https` only; `orbital_position` is within ±180 and present for satellites;
  - "**Passwords:** ≥ 12 characters and ≤ 256";
  - **Content:** every free-text field that reaches `/v1` (entity names, `display_name`, `provider`, `package`, `competition_stage`, `stadium`, a team or competition name sent as text, broadcaster `label`, `status_label`) is refused with `422 validation_error` when it holds a card-sharing label (constitution, Content and legal; O3). Move D1's `CARD_SHARING_LABELS`, `find_card_sharing_label` and `strip_card_sharing_labels` from `backend/app/etl/checks.py` to `backend/app/domain/content.py`, keep `app/etl/checks.py` importing them, and use `find_card_sharing_label` in the validators (its whole-word match lets "Apollon" and "Guinea-Bissau" through).

  The per-status score, penalty, period and minute rules are checked in T037, not in the schema, so the error lists every bad field.
- [X] T012 [US1] Create stub routers in `backend/app/api/admin/`: `matches.py`, `teams.py`, `competitions.py`, `satellites.py`, `channels.py`, `commentators.py`, `lists.py` (broadcast presets, hidden channel names, sources) and `media.py`:
  - every route, method, query parameter, header (`If-Match`, `ETag`) and status in [contracts/admin-api.md](contracts/admin-api.md), with `response_model` set to the T011 shapes;
  - each router is created with `dependencies=[Depends(require_role(...))]` from `backend/app/auth/roles.py` (a stub that T034 makes real), with `admin` on `POST /matches/bulk` when the action is `remove_channels`, checked in the handler;
  - stub handlers answer `501` with an envelope until their implementation task lands;
  - mount them on `app.admin:app` only (`backend/app/admin.py`). Never on the public app.
- [X] T013 [US1] Add the named Prism examples to the routes' OpenAPI responses: `match_ok`, `edit_conflict` (409, `changed_by` an admin), `edit_conflict_source` (409, `changed_by: {kind: "source", name: "ysscores"}`), `precondition_required` (428), `forbidden_remove_channels` (403), `validation_error_status` (422: a score on `postponed`), `media_ok`, `file_too_large`, `unsupported_media_type`, `media_invalid`. Use Arabic sample names, and no real person's data.
- [X] T014 [US1] Run `uv run python -m app.cli export-openapi` and commit `backend/openapi/admin.json`. Confirm:
  - `backend/openapi/public.json` has no diff;
  - the D1 oasdiff loop ([001 quickstart](../001-d01-foundation/quickstart.md)) reports no breaking change against `contract-v1` for both specs;
  - `pnpm prism` in `admin/` serves every example above.
- [X] T015 [US1] Regenerate the admin client from the new `admin.json` (`cd admin && pnpm install && pnpm orval`) and commit `admin/src/api/generated/*` unedited; run `swagger_parser` too and confirm the app client has no diff (`public.json` is unchanged). Then open the contract PR from `d02-b1` with:
  - the `admin.json` diff, the stub routers and the regenerated admin client;
  - B2's morning blockers: T001, T006, T007, T008, T009 and T010.

  The tests of the next block (T016–T030) are committed only after this PR merges, so its CI (`test`, `openapi`, `clients`) is green. After the owner's review, merge it to `master` **by 13:00** and tell Lanes A and B2. No new tag is cut ([contracts/admin-api.md](contracts/admin-api.md)).

### Tests first (B1): write them and see them fail

- [X] T016 [P] [US1] Write `backend/tests/auth/test_passwords.py` and `backend/tests/auth/test_cli_admins.py` ([R1](research.md#r1-passwords-the-cli-and-accounts)):
  - argon2id with t = 3, m = 64 MiB, p = 4; `check_needs_rehash` triggers a silent rehash on login;
  - `create-admin --email --name --role` reads the password twice with `getpass`, or once with `--password-stdin`; it refuses a password under 12 or over 256 characters, a mismatch and a duplicate email, each with a non-zero exit;
  - no `--password` option exists, and the password never appears in stdout, stderr or the `audit_log` diff;
  - `set-admin-password --email` and `deactivate-admin --email`; deactivation revokes every refresh token of that admin.
- [X] T017 [P] [US1] Write `backend/tests/auth/test_login.py` against the D1 [admin-auth-v1.md](../001-d01-foundation/contracts/admin-auth-v1.md) shapes ([R3](research.md#r3-login-limiting-and-the-client-ip)):
  - a good login returns the access token in the body (`expires_in: 900`) and sets the refresh and `madar_csrf` cookies with D1's names, paths and attributes;
  - wrong passwords count down `attempts_remaining` (`5 − count`);
  - the sixth attempt within 15 minutes gets `429 account_locked` with `retry_after_s` equal to the lock's TTL and a matching `Retry-After`, for a registered and an unregistered email alike, with byte-identical bodies (SC-003);
  - an unknown email still runs `verify` against a dummy hash;
  - a success deletes `auth:fail:*` and `auth:lock:*` for that key; the keys hold `sha256(lower(email))[:32]`, never the email;
  - a deactivated admin gets `invalid_credentials`;
  - `X-Forwarded-For` is honored only when the request comes from `10.8.0.1`.
- [X] T018 [P] [US1] Write `backend/tests/auth/test_refresh.py` ([R2](research.md#r2-access-jwt-refresh-rotation-and-csrf)):
  - refresh rotates the token (old row `revoked_at` and `replaced_by_id` set, new row in the same family) and rotates `madar_csrf`;
  - reusing a rotated or revoked token revokes the whole family and answers `401 refresh_invalid`;
  - refresh and logout without `X-CSRF-Token`, or with one that differs from the cookie, get `403 csrf_failed`;
  - logout revokes the token and clears both cookies;
  - a deactivated admin can't refresh;
  - an access JWT older than 15 minutes gets `401 token_expired`; a bad signature gets `401 unauthenticated`.
- [X] T019 [P] [US1] Write `backend/tests/contract/test_admin_routes_have_roles.py` ([R4](research.md#r4-roles-on-every-route)): walk `app.admin:app.routes` and fail if any route other than `auth/*` and `healthz` lacks the `require_role` dependency. Also assert: an `editor` gets `403 forbidden` with `meta.required_role = "admin"` on `remove_channels`, and no route of `app.admin:app` is reachable on `app.public:app`.
- [X] T020 [P] [US1] Write `backend/tests/unit/test_manual_status.py` for `app.domain.manual_status.validate`, with one case per cell of the [data-model validation table](data-model.md#match-status-manual-override-adds-to-001s-match-status):
  - `scheduled`, `postponed`, `cancelled`: score, penalties, period and minute not allowed;
  - `live`: score required, no penalties, period `1H` or `2H`, minute optional; `halftime`: score required, nothing else;
  - `extra_time`: score required, period `ET1` or `ET2`, minute optional;
  - `penalties` and `finished`: score required, penalties optional, no period or minute;
  - `abandoned`: score optional, minute optional, no penalties or period;
  - `minute` `"45+2"` passes; `"45+"`, `"1234"` and `"abc"` fail; `status_label` over 80 characters fails;
  - the errors list every bad field.
- [X] T021 [P] [US1] Write `backend/tests/unit/test_versions.py` for `app.services.admin.versions` ([R5](research.md#r5-entity-versions-and-if-match)):
  - the ETag is `"` + the first 32 hex characters of SHA-256 over canonical JSON (sorted keys and rows) + `"`;
  - for a match, it changes with any column except `created_at` and `updated_at`, with any `match_channels` row's `channel_id`, `source`, `imported_by`, `is_hidden`, `commentator_id` or `commentator2_id`, and with any `match_custom_broadcasts` row;
  - row order doesn't change it; renaming the home team doesn't change the match's version;
  - a team's version includes its `team_competitions` ids.
- [X] T022 [P] [US1] Write `backend/tests/admin/test_writer.py`, the shared write rules ([R6](research.md#r6-one-unit-of-work-per-admin-write), SC-002):
  - `PATCH` and `DELETE` without `If-Match` → `428 precondition_required`, and nothing is written;
  - a stale `If-Match` → `409 edit_conflict` with `meta.current_etag`, `changed_by {kind: "admin", name}` and `changed_at` from the latest `audit_log` row; after an importer's audit row, `changed_by {kind: "source", name: "ysscores"}`; for a snapshot-only row, `changed_by: null`;
  - the `audit_log` diff holds only the fields whose value changed, links under `channels: {added, removed, changed}` and slots under `broadcasts`;
  - `locked_fields` gains only changed lockable fields (a field sent with its current value isn't locked);
  - one test per row of the R6 dataset-bump table, checking `dataset_versions` before and after;
  - the response carries the new `ETag`, equal to a fresh GET's.
- [X] T023 [P] [US1] Write `backend/tests/admin/test_match_patch.py` ([R7](research.md#r7-the-match-editors-payload), the [link lifecycle](data-model.md#matchchannel-link-lifecycle)):
  - kickoff as a UTC instant, and `time_tbd: true` with `match_date`; teams by `team_id` or as text; competition by id or by `competition_name`; stage and stadium at their caps and one over;
  - `broadcasts` is the full list: a missing slot is cleared;
  - links: a new link → `source = 'manual'`, `imported_by = NULL`; a changed `is_hidden` or commentator → `source = 'manual'`; a left-out editor link → deleted; a left-out imported link → kept with `source = 'manual'`, `is_hidden = true`;
  - commentator 2 without commentator 1, or equal to it → `422` (`ck_match_channels_commentators`);
  - 301 links → `422 validation_error`;
  - a card-sharing label (`VIP`, «ليست مكسورة», …) in `stadium`, `competition_stage`, a text team name, a broadcaster `label` or a `status_label` → `422 validation_error` naming the field, and nothing is written;
  - `POST /matches` creates with `source = manual`, takes no `If-Match`, returns `201` with an `ETag`, and writes an audit row.
- [X] T024 [P] [US1] Write `backend/tests/admin/test_match_status.py` (FR-011):
  - setting `live` 1–0 stores `status_source = 'manual'`, `status_updated_at`, locks only the changed status and score fields, and bumps `live` and `matches`;
  - `/v1/live`, `/v1/matches` and `/v1/matches/{id}` then serve it with `estimated: false`;
  - clearing sets `status_source = 'clock'`, `status = 'scheduled'`, NULLs score, penalties, minute and period (`ck_matches_clock_no_score`), removes `status`, `home_score`, `away_score`, `home_pen` and `away_pen` from `locked_fields`, and `/v1` derives the clock state again;
  - a score on `postponed` → `422 validation_error` with the field.
- [X] T025 [P] [US1] Write `backend/tests/admin/test_bulk.py` ([R8](research.md#r8-bulk-actions)):
  - `change_competition` (editor) changes every item and writes one `audit_log` row per match with `action = 'bulk'`;
  - `remove_channels` (admin) with `channel_ids: null` removes every visible link by the R7 rule; an editor gets `403 forbidden`;
  - one stale item → `409 edit_conflict` with `meta.stale_ids`, and no item changes;
  - 201 items → `422`; an item without `etag` → `428`.
- [X] T026 [P] [US1] Write `backend/tests/admin/test_entities.py` for teams, competitions, satellites, channels and commentators:
  - list, read with `ETag`, create (no `If-Match`), update and delete (with `If-Match`), each audited and bumping its R6 datasets;
  - deleting a referenced team, competition or commentator → `409 in_use` with `meta.usage` counts; a satellite with channels → `409 in_use`; a channel → soft delete (`deleted_at`), gone from `/v1`;
  - `409 already_exists` with `meta.field` for a satellite slug, a competition per sport and name, and a channel carriage;
  - a channel's `kind` decides its fields (`ck_channels_kind_fields`); an editor's channel change locks its changed fields;
  - every free-text field (`name`, `display_name`, `provider`, `package`) rejects the card-sharing labels (`Mega Share`, `Apollo`, `VIP`, «ليست مكسورة», `BISS`) with `422`, while "Apollon" and "Guinea-Bissau" pass; after the whole test module, D1's `scan_card_sharing_labels` finds no label in any stored text column;
  - `reception_url` with `http://` → `422`;
  - each unknown id → its `<entity>_not_found` code.
- [X] T027 [P] [US1] Write `backend/tests/admin/test_lists.py` ([R9](research.md#r9-admin-lists-and-pickers)):
  - `GET /matches?from&to`: `to − from` over 8 days → `422`; each filter (`competition_id`, `source` matching the creator or any external id, `missing_channels` meaning no visible link and no manual broadcaster, `status`); the derived status with `estimated`; order by competition priority (nulls last), then kickoff; a weak list `ETag` and `304`;
  - `GET /teams?q`: the top 20 by `pg_trgm` similarity on `ar_normalize(q)` with a prefix match first, `next_cursor: null`, each item with country, logo, primary and other competitions; `q` over 64 → `422`;
  - teams, channels and commentators without `q` page by keyset cursor, `limit` ≤ 100, stable while rows are inserted; channels filter by `satellite_id`, `category`, `kind`, `access` and `missing_logo`, and include platforms without a satellite;
  - `GET /broadcast-presets` and `GET /sources` are read-only lists;
  - `POST /hidden-channel-names` stores `ar_normalize(name)`, answers `201`, then `200` for the same name; `DELETE /hidden-channel-names/{name}` (URL-encoded Arabic) → `200`, then `404 hidden_name_not_found`; both write an audit row with `entity = 'hidden_channel_names'` and bump `matches`; a channel matching a hidden name shows `hidden_by_name: true` in `AdminMatch`.
- [X] T028 [P] [US1] Write `backend/tests/admin/test_uploads.py` ([R10](research.md#r10-uploads)), using small generated files:
  - each magic signature is accepted: PNG `89 50 4E 47`, JPEG `FF D8 FF`, WebP `RIFF….WEBP`; MP3 `ID3` and a frame sync, M4A `….ftyp`, OGG `OggS`, WAV `RIFF….WAVE`;
  - an image over 2 MB or audio over 1 MB → `413 file_too_large` with `meta.max_bytes`, refused from `Content-Length` before parsing;
  - a text file named `.png` with `Content-Type: image/png` → `415 unsupported_media_type`;
  - a decompression bomb and an undecodable file → `422 media_invalid`;
  - the same bytes twice → `200` with the same asset id;
  - an image comes back as WebP ≤ 512 px with no EXIF; a 45 s audio file comes back trimmed to 30 s;
  - the response has `id`, `kind`, absolute `url`, `width`, `height`, `duration_ms` and `bytes`.
- [X] T029 [P] [US1] Write `backend/tests/admin/test_edit_reaches_v1.py` ([R11](research.md#r11-manual-status-on-the-read-path-and-the-60-s-path), FR-014): take the `/v1/matches` and `/v1/live` ETags, save a kickoff and a channel change through the admin API, then send the old ETags with `If-None-Match` and expect `200` with the change. Repeat for a manual status.
- [X] T030 [P] [US1] Write `backend/tests/contract/test_admin_contract.py`: schemathesis `from_asgi` over `backend/openapi/admin.json` with an editor's bearer token, `not_a_server_error` and `response_schema_conformance` (FR-013). Every admin endpoint is exercised at least once, and every response is in the envelope.

### Implementation (B1)

- [X] T031 [P] [US1] Implement `backend/app/auth/passwords.py`: argon2-cffi `PasswordHasher` with the RFC 9106 low-memory profile, `verify` with rehash, and a module-level dummy hash for unknown emails.
- [X] T032 [P] [US1] Implement `backend/app/auth/tokens.py`: the PyJWT HS256 access token (`sub`, `role`, `iat`, `exp` = 15 min) signed with `ADMIN_JWT_SECRET`; refresh tokens from `secrets.token_urlsafe(32)` stored as SHA-256 with `family_id`, 14-day expiry, rotation under `SELECT … FOR UPDATE`, and family revocation on reuse.
- [X] T033 [P] [US1] Implement `backend/app/auth/csrf.py` (the `madar_csrf` cookie, rotated on refresh, compared with `hmac.compare_digest`) and `backend/app/auth/limits.py` (the `auth:fail:<h>:<ip>` sorted set trimmed to 15 minutes, `auth:lock:<h>:<ip>` with `EX 900`, cleared on success; [Redis keys](data-model.md#redis-keys)).
- [X] T034 [US1] Implement `backend/app/auth/roles.py` `require_role("editor" | "admin")`: decode the JWT, load the admin by `sub` on every request, reject inactive admins, compare role rank (`admin` covers `editor`), and raise `401 unauthenticated`, `401 token_expired` or `403 forbidden`. T019 passes.
- [X] T035 [US1] Make `backend/app/api/admin/auth.py` real (login, refresh, logout, current admin) without changing any request, response, cookie, header or error code of D1's `admin-auth-v1.md` (FR-001). T017 and T018 pass, and `test_admin_auth_contract.py` stays green.
- [X] T036 [US1] Add `create-admin`, `set-admin-password` and `deactivate-admin` to `backend/app/cli.py` ([R1](research.md#r1-passwords-the-cli-and-accounts)), writing CLI audit rows with both actor columns NULL and no password or hash in the diff. T016 passes.
- [X] T037 [P] [US1] Implement `backend/app/domain/manual_status.py` `validate(status, period, minute, score, status_label)` with the data-model table. T020 passes.
- [X] T038 [P] [US1] Implement `backend/app/services/admin/versions.py`: the canonical-JSON hash per entity, computed on GET and again under the row lock. T021 passes.
- [X] T039 [US1] Implement `backend/app/services/admin/writer.py`, the one unit of work for every admin mutation ([R6](research.md#r6-one-unit-of-work-per-admin-write)):
  1. lock the row (`SELECT … FOR UPDATE`; bulk locks in id order);
  2. check `If-Match` (`428` / `409` with `changed_by` from the latest audit row);
  3. apply the validated change;
  4. compute the field diff of changed fields only;
  5. add changed lockable fields to `locked_fields`;
  6. write the `audit_log` row;
  7. bump the datasets of the R6 table as the last statement;
  8. return the new version.

  Creates and the hidden-name add and remove skip steps 1–2 only (plan, Complexity Tracking). Every query is bound; no SQL is built by string formatting.
- [X] T040 [US1] Implement the match services in `backend/app/services/admin/matches.py` (read, create, fields, broadcasts), `backend/app/services/admin/links.py` (the link list diff and the lifecycle of the data model) and `backend/app/services/admin/status.py` (set and clear, using T037). `PATCH /matches/{id}` applies its sections together under one `If-Match`. T022–T024 pass.
- [X] T041 [US1] Implement `backend/app/services/admin/bulk.py`: both actions in one transaction, all or nothing, `meta.stale_ids`, the `admin` check for `remove_channels`, one `bulk` audit row per match. T025 passes.
- [X] T042 [US1] Implement entity CRUD in `backend/app/services/admin/teams.py`, `competitions.py`, `satellites.py`, `channels.py` and `commentators.py`, all through the writer: `in_use` usage counts, soft delete for channels, `already_exists` from the unique constraints, the kind-field rule, and the card-sharing label check of T011. T026 passes.
- [X] T043 [US1] Implement `backend/app/services/admin/lists.py`: the A3 match list (one query with `selectinload` for teams, competition, links and external ids, no N+1), team and commentator search (`pg_trgm` on `ar_normalize(q)`), keyset cursors, presets, sources and hidden names. T027 passes.
- [X] T044 [US1] Implement `backend/app/services/admin/uploads.py` on `app.media`: the `Content-Length` check (cap + 64 KB), the hard-capped body read, magic bytes, encoding in a thread pool, and content-addressed storage. T028 passes.
- [X] T045 [US1] Replace the stub handlers in `backend/app/api/admin/*.py` with the services: `ETag` on single GETs and write responses, `If-Match` read from the header (or the bulk item), weak list ETags with `304`, and every response in the envelope. Run `export-openapi`: `admin.json` changes only if a description changed, and the oasdiff loop stays non-breaking. If it changed, regenerate the admin client in the same PR, as in T015. T029 and T030 pass.
- [X] T046 [US1] Run the full backend suite (`uv run ruff check . && uv run mypy --strict app && uv run pytest --cov`) and fix any failure in the code, never by weakening a test.

### Validation (B1)

- [ ] T047 [US1] Deploy and check on VPS-1 over WireGuard (needs B2's T078 and T085, and the owner's `ADMIN_JWT_SECRET` in VPS-1's `.env`):
  1. merge to `master`; `backend.yml` deploys and runs `0003`;
  2. the owner runs `docker compose -f infra/compose/vps1.yml run --rm api-admin python -m app.cli create-admin --email … --name … --role admin` and types the password at the prompt;
  3. run the [quickstart Lane B1](quickstart.md#lane-b1-admin-api) `curl` checks from a peer: login (`expires_in` 900), a match `ETag`, and a `PATCH` without `If-Match` → `precondition_required`;
  4. confirm `https://api.<ip1>.sslip.io/admin/api/…` answers `404` from the internet.
- [X] T048 [US1] Confirm the MVP bar: `uv run pytest --cov` passes with `fail_under = 70` on `app/domain`, `app/services` and `app/adapters`, and contract tests cover every `/v1` and `/admin/api` route (FR-054). Record the coverage figure in the PR.
- [X] T049 [US1] Write `docs/runbooks/staff-accounts.md` (FR-055): create an admin, reset a password, deactivate an editor (which revokes their sessions), what to do after a suspected token leak (rotate `ADMIN_JWT_SECRET`, restart api-admin, every session ends), and that accounts move to A16 on D6. Add `ADMIN_JWT_SECRET` to `docs/runbooks/secrets.md` (generate with `openssl rand -base64 48`, never committed), and `0003` to `docs/runbooks/database-migrations.md` if it lists revisions. Add the runbook to `docs/runbooks/README.md`'s setup order and "After setup" table. Every command must match the code.
- [X] T050 [US1] Add the D2 Lane B1 items to `docs/owner-actions.md` (before merge: review T015 and T010, set `ADMIN_JWT_SECRET`; after merge: create the first admin, one editor account per editor), each with its task ID and runbook link, and update the "Open now" table.

### Review fixes (round 1)

Source: [reviews/b1-round-1.md](reviews/b1-round-1.md). Fix in this order, then re-run `/speckit-review-implementation lane=b1` as round 2. Two items from other lanes also wait on this lane: Lane A's A-F3 (add `etag` to `AdminMatchRow`, which A-R1-3 depends on), and Lane B2's asks B2-R1-15 and B2-R1-19 (in `app/workers/`).

- [X] B1-R1-1 [US1] Reserve the login attempt before checking the password, in `backend/app/api/admin/auth.py` (lines 189–205) and `backend/app/auth/limits.py`. Today `locked_for` is read, then the lookup and the argon2 check are awaited, then `record_failure` runs, so N parallel requests all get a password check. Afterwards an atomic Redis step (a Lua script, or `INCR` with a limit check) counts the attempt and refuses at `MAX_FAILURES` before any verification, and a success clears it. Add a test that fires 10 concurrent wrong logins with `asyncio.gather` and asserts at most 5 calls to `passwords.verify_password` and at least 5 `429 account_locked`. It must fail before the fix. (CRITICAL, per FR-003, SC-003, constitution V)
- [X] B1-R1-2 [US1] Reject NUL bytes in every admin text input, in `backend/app/schemas/admin.py` (`Name120`, `Text80` and every other `str` field). Today `\u0000` reaches asyncpg, which raises `CharacterNotInRepertoireError` and returns a 500 with no envelope, and that already fails `test_admin_contract.py[POST /admin/api/hidden-channel-names]`. Afterwards one shared validator answers `422 validation_failed`. Add a parametrised test that posts a NUL to each admin text field and expects 422, and keep the contract test green. (HIGH, per FR-013, constitution VI)
- [X] B1-R1-3 [US1] Add `Depends(ETag(...))` to the six admin list GETs: `backend/app/api/admin/teams.py:23`, `channels.py:24`, `commentators.py:23`, `lists.py:22` (`/broadcast-presets`), `lists.py:35` (`/hidden-channel-names`) and `lists.py:80` (`/sources`). Today they send no `ETag` and never answer 304, though T045 is ticked. Each should depend on the datasets it reads; give a list its own dataset if none covers it. Add a test per route: the returned `ETag` as `If-None-Match` gives `304`, and an edit through the API changes it. (HIGH, per constitution VI, T045)
- [X] B1-R1-4 [US1] Lock the fields an editor supplies when a match is created, in `backend/app/services/admin/matches.py` (lines 255–293) and `backend/app/services/admin/writer.py` (`save_create`, lines 226–243). Today `create` writes `locked_fields=[]`, so B2's duplicate probe (`backend/app/adapters/upsert.py:225-262`) can adopt the row and overwrite its kickoff, competition and stage. Afterwards the supplied field names are locked through the same helper as updates, and the audit diff shows them. Add a test: create a match through the API, run `Upserter` on a fixture item the probe matches with another kickoff, and assert the kickoff is unchanged. (HIGH, per FR-010, SC-002, constitution VI)
- [X] B1-R1-5 [US1] Bump `channels` as well as `matches` when a hidden name is added or removed, in `backend/app/services/admin/writer.py:54` (`HIDDEN_NAME_CHANGED`). The owner decided this on 2026-10-31, and research.md R6 now says it. Today only `matches` is bumped, while `backend/app/services/satellites.py:38-39` filters by hidden names and `backend/app/api/public/satellites.py:22,33` build their ETags from `("satellites", "channels")`, so S5 keeps getting 304 with stale data. Add a test that adding and removing a hidden name both change the `/v1/satellites` and `/v1/satellites/{id}/channels` ETags. (MEDIUM, per FR-014)
- [X] B1-R1-6 [US1] Count `rights_holder_competitions` in the competition in-use check, in `backend/app/services/admin/competitions.py` (lines 93–110). Today a delete cascades them away (`0001_base_schema.sql:306`) with no `409 in_use` and no audit. Add a test that the delete answers `409 in_use` with the count. (MEDIUM, per contracts/admin-api.md)
- [X] B1-R1-7 [US1] Run argon2 off the event loop, in `backend/app/api/admin/auth.py:199,202`. Today `burn_verify` and `verify_password` block every request on the worker for each login. Use `anyio.to_thread.run_sync`, after B1-R1-1's reservation. Add a test that a login doesn't block a concurrent `GET /admin/api/auth/me` (for example, patch the hash to sleep and assert the other request finishes first). (MEDIUM, per the async rule in 4.B)
- [X] B1-R1-8 [US1] Correct the `ADMIN_JWT_SECRET` row in `docs/runbooks/secrets.md:18`. Today it says the key goes in both VPS `.env` files and is used by `api-admin` and `worker-media`. Afterwards it says VPS-1 only, used by `api-admin` only (`backend/app/admin.py:29`), and notes that the shared `env_file` exposes it to the other VPS-1 containers. No test (docs). (MEDIUM, per FR-004, constitution V)
- [X] B1-R1-9 [US1] Test the refresh row lock and the startup secret check, in `backend/tests/auth/test_refresh.py` and a new lifespan test. Today removing `.with_for_update()` (`backend/app/auth/tokens.py:131`) or the check in `backend/app/admin.py:29` keeps the suite green. Afterwards: two concurrent refreshes on two real connections with one token, where exactly one succeeds and the reuse rule applies; and the lifespan refuses an unset, a 31-byte and accepts a 32-byte key. Each test fails when its guard is removed. (MEDIUM, per FR-004, FR-053)

Done in round 2 on `d02-features`: all nine. Cross-lane asks delivered with them: Lane A's A-F3
(`AdminMatchRow.etag`, computed in bulk by `versions.match_versions`), Lane B2's B2-R1-15 (a JSON log
formatter in `app/workers/logs.py`) and B2-R1-19 (task routing resolved lazily in `app/workers`).
T045's six missing list ETags needed two dataset names, so revision `0004` adds `broadcast_presets`
and `sources`.

### Review fixes (round 2)

Source: [reviews/b1-round-2.md](reviews/b1-round-2.md). Fix in this order, then re-run `/speckit-review-implementation lane=b1` as round 3. Two of these were asked by other lanes: B1-R2-7 by Lane B2 (B2-R2-5), and B1-R2-8 by Lane A (A-R2-2 waits on it).

- [X] B1-R2-1 [US1] Keep the NUL guard on `/v1` query parameters out of the published schema, in `backend/app/api/public/teams.py:31` and `backend/app/api/public/satellites.py:39`. Today `pattern=NO_NUL_PATTERN` adds `"pattern": "^[^\\x00]*$"` to `backend/openapi/public.json`, and `oasdiff breaking contract-v1:public.json HEAD:public.json --fail-on ERR` (`.github/workflows/backend.yml:139-148`) exits 1 with `request-parameter-pattern-added` on `GET /v1/teams` `q`. Afterwards a NUL in `q` still gets `422 validation_failed` (an `AfterValidator`, or one handler that maps asyncpg's `CharacterNotInRepertoireError` to the envelope), `public.json` has no `pattern` on these parameters, and oasdiff exits 0. Keep `tests/contract/test_public_schema.py` green, and add a test that `public.json`'s `q` has no `pattern`. If the owner wants the pattern in the schema, ask for an oasdiff exception instead of guessing. (HIGH, per the CI contract gate, constitution VI)
- [X] B1-R2-2 [US1] Add `matches` to the commentator list's datasets, in `backend/app/api/admin/commentators.py:34`. Today the ETag is built from `("commentators",)` while the body's `usage` counts `matches.commentator_id` and `match_channels` (`backend/app/services/admin/lists.py:257`), so assigning a commentator to a match leaves the list answering `304` with `usage.matches = 0`. Add a test: take the list's ETag, assign the commentator to a match through the API, and expect a `200` with the new usage. (MEDIUM, per constitution VI, B1-R1-3)
- [X] B1-R2-3 [US1] Bump `broadcast_presets` when `rehost-media` sets a preset's logo, in `backend/app/etl/media.py:63` (`"broadcast": (BroadcastPreset, None)`) and `:190-192`. Today a `None` dataset is never bumped, so `GET /admin/api/broadcast-presets` keeps answering `304` with `logo: null` after the logos are set. Map it to `"broadcast_presets"`, correct the comment, and test that `rehost-media` bumps the dataset. (MEDIUM, per B1-R1-3)
- [X] B1-R2-4 [US1] Declare the `304` and the `ETag` header on the six admin list GETs, in `backend/app/api/admin/{teams,channels,commentators,lists}.py` (`/teams`, `/channels`, `/commentators`, `/broadcast-presets`, `/hidden-channel-names`, `/sources`). Today `backend/openapi/admin.json` lists only `200, 401, 403(, 422)` for them, while `matches` and `satellites` declare `304` through `_docs.NOT_MODIFIED`. Re-export the spec, regenerate the Orval and Retrofit clients, and add a contract test that every GET with an `ETag` dependency declares `304`. (MEDIUM, per constitution VI, FR-014)
- [X] B1-R2-5 [US1] Make the `ADMIN_JWT_SECRET` rotation steps VPS-1 only, in `docs/runbooks/secrets.md:84-85`. Today they put the key in VPS-2's `.env` and recreate `worker-media`, which contradicts the corrected row at `:18`. Afterwards the steps write it to VPS-1's `.env` and recreate `api-admin` only. No test (docs). (MEDIUM, per FR-004, constitution V)
- [X] B1-R2-7 [US1] Cap what the JSON log formatter writes, in `backend/app/workers/logs.py:32-33,46`. Today it copies every `extra` attribute, so Celery's failure log puts a whole task payload (`data` with `args` and `kwargs`, up to 2 MB of `ScrapeResult`) on one line. With the root at INFO, `httpx` also logs every request's full URL, including the bridge's `?key=` (Lane B2 moves the key to a header in B2-R2-5). Afterwards `data`, `args` and `kwargs` are dropped or truncated, every field has a length cap, and the `httpx` and `httpcore` loggers sit at WARNING. Add tests: a failing task with a 100 KB argument logs a line under the cap, and an `httpx` request logs no URL at INFO. (MEDIUM, per FR-027, D15, constitution V)
- [X] B1-R2-8 [US1] Add `logo_asset_id` to `BroadcastPreset`, in `backend/app/schemas/admin.py` (the `BroadcastPreset` model), `backend/app/services/admin/lists.py:267-270` and `specs/002-d02-core-flows/contracts/admin-api.md:165`. Today the list gives `{id, name, logo}` only, so A4 has no asset id to save with a preset, and Lane A sends the preset's own `id` as `logo_asset_id` (A-R2-2). Re-export (an added field, which oasdiff accepts) and regenerate the clients. Add a test that a preset with a logo lists its `logo_asset_id`. (MEDIUM, per US4 scenario 6, FR-008)

Done in round 3 on `d02-features`: all seven. The `/v1` NUL guard is an `AfterValidator`, so
`public.json` is byte-identical to `contract-v1` again and oasdiff exits 0 on both documents; the six
list GETs (and `matches`, `competitions`, `satellites`) now declare `304` and the `ETag` header, with a
test that walks every route with a `Depends(ETag(...))`. `BroadcastPreset.logo_asset_id` re-exports as
a required nullable field and the Orval client is regenerated. The JSON formatter drops `data`, `args`
and `kwargs`, caps every field at 256 characters and the line at 8 KB, and puts `httpx`/`httpcore` at
WARNING. One extra fix outside the list: `tbd_dates` clamped its two-day margin, which schemathesis
reached as an `OverflowError` (a 500 on `GET /v1/matches` with `from` on year 1).

---

## Lane B2

**Story (User Story 2, P2):** As the owner, tomorrow's fixtures arrive without anyone opening a browser.

**Independent test:**

- the ysscores `parse` tests pass against the saved pages;
- beat starts a run with no one acting: tomorrow's fixtures appear with UTC kickoffs and resolved teams, an `import_runs` row records the counts and the raw page path, and a second run creates no rows;
- a match's kickoff locked in the admin survives the next run;
- with ysscores paused, the bridge adds the fixtures ysscores doesn't have, with their channels, and duplicates none ([quickstart.md](quickstart.md#lane-b2-ingestion-and-hosts)).

**The owner must review:** the firewall change (T082), the Redis ACL (T081), `deploy.sh --host vps2` (T083), the home-box update script and units (T084), and the `backend.yml` changes (T085).

### Setup (B2)

- [X] T051 [US2] Create `backend/app/adapters/__init__.py` and `backend/app/adapters/config.py` (pydantic-settings, B2's own settings, failing fast only in the tasks that need them):
  - `SATAIR_FIREBASE_PROJECT_ID` and `SATAIR_FIREBASE_API_KEY` (`SecretStr`), no defaults, read only by the bridge;
  - `SCRAPE_USER_AGENT`, required by the fetcher;
  - `YSSCORES_FETCH_QUEUE`: `scrape_home` (default) or `scrape`;
  - `RAW_ROOT`, default `/srv/raw`.

  The old Sat Air configuration never appears in the repo, in a test or in a log line (D15, FR-052).
- [X] T052 [P] [US2] Save the test pages:
  - `backend/tests/fixtures/ysscores/`: three `match_date_to` responses saved on D2, a normal day, a day with `"--:--"` and a postponement, and an empty day, plus a `README.md` with the date each was saved and the known kickoff that one test pins;
  - `backend/tests/fixtures/satair_bridge/`: synthetic Firestore REST documents in the real typed-value shape (`stringValue`, `arrayValue`, `mapValue`, …) with `matches[]`, `channelIds` (one orphan id), `hiddenChannels` and `channelCommentators`. No real export data and no project id or key.
- [X] T053 [P] [US2] Update `infra/README.md` and `infra/CLAUDE.md`: the home box as a third host (x86-64, WireGuard peer, `worker-scrape -Q scrape_home` only, no database credentials), the new `.env` names per host from [contracts/ingestion.md](contracts/ingestion.md#hosts-and-their-settings) (names only), the GitHub variable `VPS2_VCN_IP`, and the GHCR packages `madar-backend` and `madar-backend-amd64`.
- [X] T054 [P] [US2] Add every new variable to `infra/compose/example.env` with an obviously fake value: `ADMIN_JWT_SECRET`, `REDIS_HOMEBOX_PASSWORD`, `HOME_BOX_WG_IP`, `SATAIR_FIREBASE_PROJECT_ID`, `SATAIR_FIREBASE_API_KEY`, `SCRAPE_USER_AGENT`, `YSSCORES_FETCH_QUEUE`, `RAW_ROOT`, `GHCR_READ_TOKEN`.

### Tests first (B2): write them and see them fail

- [X] T055 [P] [US2] Write `backend/tests/adapters/test_fetcher.py` with `httpx.MockTransport` ([R14](research.md#r14-the-sourceadapter-base)):
  - a host outside `allowed_hosts` is refused with no request made;
  - a redirect is followed by hand at most 3 times and only to an allowed host; a redirect elsewhere fails;
  - a body over 5 MB is cut off and fails; the 5 s connect and 20 s read timeouts are set;
  - 429, 403 and 5xx raise `Retryable`; other 4xx fail without a retry;
  - the `User-Agent` is `SCRAPE_USER_AGENT`.
- [X] T056 [P] [US2] Write `backend/tests/adapters/test_ratelimit.py` against the test Redis: the `ratelimit:<host>` token bucket gives ysscores 1 request per 4 s with a burst of 2 and Firestore 5 per second, is atomic under two concurrent callers, and expires after 1 h idle.
- [X] T057 [P] [US2] Write `backend/tests/adapters/test_ysscores_parse.py` on the saved pages ([R16](research.md#r16-the-ysscores-adapter)):
  - each `.matches-wrapper` gives `champ_title` and `champ_img`; each `a.ajax-match-item` gives the teams, logos, team ids when present, `.match-date`, and the match id from `/ar/match/<id>/<slug>`;
  - the pinned fixture's kickoff text matches the README;
  - a response without `matches-wrapper` raises the layout-change error; the empty day gives no items;
  - `parse` makes no network, database or clock call.
- [X] T058 [P] [US2] Write `backend/tests/adapters/test_ysscores_normalize.py`:
  - the form body is `get_date=<Month D,YYYY>` (`"October 31,2026"`: English month, no space after the comma), one POST per Cairo day, today to +3;
  - Cairo wall clock → UTC with `app.domain.time`, on each side of the 2026 Africa/Cairo DST changes;
  - `"--:--"` → `time_tbd` with `kickoff_at` None;
  - placeholders (`""`, `"⚽"`, «غير مدرج») → None; doubled stage text cleaned;
  - logo URLs kept only when their host is on `MEDIA_REHOST_ALLOWED_HOSTS`;
  - no status or score is ever produced.
- [X] T059 [P] [US2] Write `backend/tests/adapters/test_resolve.py` ([R17](research.md#r17-entity-resolution-v0)):
  - competition: an external id hit, then an exact `(sport, name_norm)`, else NULL with the name kept;
  - team: an external id hit; exactly one same `name_norm` and sport; among several, the highest `competitionSimilarity` ≥ 0.5 with no tie; anything else unresolved with no id, listed for `run.json`;
  - teams are never created;
  - the Python port of `competitionSimilarity`, `tokenize`, `stripArabicAffixes` and `STOP_WORDS` matches cases taken from `../old_app/src/utils/arabicMatch.js` (write the expected values in the test with a comment naming the JS function; don't copy the file).
- [X] T060 [P] [US2] Write `backend/tests/adapters/test_upsert.py` on PostgreSQL 16 ([R18](research.md#r18-the-upsert-pipeline)):
  - a first run creates rows by `(source, external_id)` with UTC kickoffs; a second run on the same input creates 0 rows and reports `items_upserted = 0` (SC-004);
  - a kickoff in `locked_fields` survives, including when the lock commits after the run started (re-read under `SELECT … FOR UPDATE`);
  - the duplicate probe: the same resolved teams within ±45 minutes gains the external id instead of a new row; 46 minutes apart makes a new row; with a NULL team id, the same normalized names on the same `match_date`;
  - links: inserted with `source = imported_by = <adapter>`; a link the source no longer lists is deleted only when its `source` is this adapter; `manual` links, including hidden ones, are never touched or re-added;
  - a bad item fails in its savepoint and the run is `partial`;
  - a changed match gets an `audit_log` row with `source` set and `admin_user_id` NULL;
  - `matches` (and `live` when a kickoff changed) is bumped once per run, and not at all when nothing changed;
  - a resolved team with a NULL logo and an allowlisted logo URL queues `adapters.rehost_logo` after the commit; the pipeline never stores a URL.
- [X] T061 [P] [US2] Write `backend/tests/adapters/test_satair_bridge.py` on the saved documents ([R19](research.md#r19-the-firestore-bridge)):
  - the typed values convert to plain JSON;
  - the request is a GET to `firestore.googleapis.com/v1/projects/<id>/databases/(default)/documents/matchDays/<YYYY-MM-DD>` only;
  - rows key on `matches.legacy_id`, and `ysMatchId` is recorded as the ysscores external id;
  - an orphan channel id is skipped and logged; `hiddenChannels` sets `is_hidden`; `channelCommentators` gives commentators 1 and 2 by `name_norm`, creating a commentator for a new name;
  - a match that already has a ysscores external id keeps its fields, and only its `legacy` links change;
  - no card-sharing label is read; manual broadcaster slots aren't imported.
- [X] T062 [P] [US2] Write `backend/tests/adapters/test_messages.py`: `ScrapeResult` with `schema: 1` validates on both ends; the previous schema version is accepted once a second one exists; any other version is rejected loudly; a message over 2 MB of pages is refused at build time; a failed fetch builds a result with `http_errors`, no pages and a short `error`.
- [X] T063 [P] [US2] Write `backend/tests/adapters/test_raw_store.py` with a temp `RAW_ROOT`: pages land in `<source>/<YYYY-MM-DD>/<run_id>/<n>.html.gz` with `run.json` (`counts`, `skipped[{ref, reason}]`, `unresolved[{name, competition, match_ref}]`); `prune_raw_pages` deletes run folders older than 5 days and keeps newer ones.
- [X] T064 [P] [US2] Write `backend/tests/adapters/test_tasks.py` with Celery's eager mode and the test Redis:
  - `adapters.fetch` holding `lock:fetch:<source>` makes a second fetch exit and log `skipped`; the same for `lock:ingest:<source>`;
  - ysscores fetches route to `scrape_home`, or to `scrape` when `YSSCORES_FETCH_QUEUE=scrape`; the bridge always to `scrape`; ingest to `imports`; prune to `maintenance`; `rehost_logo` to `media`;
  - fetches expire 2 h after queueing;
  - `ingest` writes `import_runs` (`running`, then `succeeded`, `partial` or `failed`) with `items_found`, `items_upserted`, `http_errors`, `raw_path`, and `matches_imported` equal to `items_upserted` (SC-005);
  - every task uses the `app.workers` base class;
  - **the home box's path (FR-028):** a subprocess with only `REDIS_URL` and `SCRAPE_USER_AGENT` in its environment imports `app.workers` and runs `adapters.fetch` on a saved page (eager, through `httpx.MockTransport`), and neither `app.db` nor `app.settings.get_settings()` is loaded.
- [X] T065 [P] [US2] Write `backend/tests/adapters/test_rehost_logo.py` with `httpx.MockTransport` ([R20](research.md#r20-importer-found-logos-a-media-worker-on-vps-1)):
  - an allowlisted logo fills an empty `logo_asset_id` through `UPDATE … WHERE id = :id AND logo_asset_id IS NULL`, writes an `audit_log` row with `source` set and `{logo_asset_id: [null, id]}`, and bumps `teams` (or `competitions`) and `matches`;
  - an existing logo, including one set while the task ran, is never replaced;
  - a host outside the allowlist, a redirect elsewhere, an oversize file or a decode failure is logged and dropped with the logo still NULL; network errors and 5xx raise `Retryable`;
  - the same bytes reuse the `media_assets` row; `lock:media:<sha256(url)>` drops a duplicate in flight.
- [X] T066 [P] [US2] Write `backend/tests/adapters/test_homebox_acl.py`: read `infra/redis/users.acl.tmpl`, apply its `homebox` rules to the test Redis with `ACL SETUSER` and a test password, connect as `homebox`, and assert it can queue and consume a task under `celery:*` and use `ratelimit:*` and `lock:fetch:*`, but fails to read an `auth:*` key and to run `CONFIG`, `FLUSHALL` and `KEYS`. Delete the user afterwards.
- [X] T067 [P] [US2] Extend `.github/workflows/infra.yml`: `docker compose … config -q` for `infra/compose/home-box.yml`; shellcheck on `infra/scripts/home-box-update.sh`; `systemd-analyze verify` on the home-box units; and a check that `infra/redis/users.acl.tmpl` contains no password value, only the placeholders.

### Adapters (B2)

- [X] T068 [US2] Implement `backend/app/adapters/base.py`: the SD §6.6 `SourceAdapter` protocol (`name`, `allowed_hosts`, `fetch`, `parse`, `normalize`), `DateWindow` (Cairo days, today to +3), `RawPage`, and the `ParsedFixture` and `NormalizedFixture` fields of [contracts/ingestion.md](contracts/ingestion.md#sourceadapter-sd-66).
- [X] T069 [US2] Implement `backend/app/adapters/fetcher.py` (`HttpFetcher` with `follow_redirects=False` and the hand-checked redirects, timeouts, 5 MB streaming cap, `Retryable` on 429/403/5xx) and `backend/app/adapters/ratelimit.py` (one atomic Lua token bucket per host). T055 and T056 pass.
- [X] T070 [P] [US2] Implement `backend/app/adapters/messages.py` (`ScrapeResult`, schema 1, gzipped base64 pages, ≤ 2 MB) and `backend/app/adapters/raw_store.py` (the raw layout, `run.json`, and `prune`). T062 and T063 pass.
- [X] T071 [US2] Implement `backend/app/adapters/ysscores.py`: the per-day POST, the pure lxml `parse`, and `normalize` with `app.domain.time` and `app.domain.arabic.ar_normalize`. T057 and T058 pass.
- [X] T072 [US2] Implement `backend/app/adapters/resolve.py` with the `competitionSimilarity` port. T059 passes.
- [X] T073 [US2] Implement `backend/app/adapters/upsert.py` (needs B1's T010): find by key, then the duplicate probe; lock and re-read `locked_fields`; write unlocked changed fields; record external ids; the importer link rules; the audit row with `source`; queue logos after the commit; bump once per run. Use B1's models and bound queries only. T060 passes.
- [X] T074 [US2] Implement `backend/app/adapters/satair_bridge.py` on the upsert path, as source `legacy`. T061 passes.
- [X] T075 [US2] Implement `backend/app/adapters/tasks.py` (`adapters.fetch`, `adapters.ingest`, `adapters.prune_raw_pages`) and `backend/app/adapters/media_tasks.py` (`adapters.rehost_logo`, calling B1's `app.media` without changing it) on the `app.workers` base class (needs B1's T006 and T008). The fetch path (`base.py`, `fetcher.py`, `ratelimit.py`, `messages.py`, and the `fetch` and `parse` parts of `ysscores.py` and `satair_bridge.py`) imports neither `app.db` nor `app.settings`; `ingest`, `prune_raw_pages` and `rehost_logo` import the database and upsert code inside the task body, so the home box never loads them. T064 and T065 pass.
- [X] T076 [US2] Implement `backend/app/adapters/schedule.py` with the beat entries `ysscores-fixtures` `crontab(minute=0, hour="*/3")`, `satair-bridge` `crontab(minute=30, hour="1-22/3")` and `prune-raw-pages` `crontab(minute=15, hour=3)`, all UTC. Add a test in `backend/tests/adapters/test_schedule.py` (written first) that asserts the three entries and their queues.
- [X] T077 [US2] Run the backend suite (`uv run ruff check . && uv run mypy --strict app && uv run pytest tests/adapters --cov`) and fix any failure in the code.

### Hosts and pipelines (B2)

- [X] T078 [P] [US2] Update `infra/compose/vps1.yml`:
  - `api-admin`: `--proxy-headers --forwarded-allow-ips=10.8.0.1` (gunicorn's uvicorn worker, via `FORWARDED_ALLOW_IPS=10.8.0.1` and `--forwarded-allow-ips`), `/srv/media` mounted read-write, and `ADMIN_JWT_SECRET` from `.env`;
  - `worker-media`: the backend image, `celery -A app.workers worker -Q media -n worker@%h -c 1 --without-gossip --without-mingle`, a 256 MB memory limit, `/srv/media` read-write, the local PostgreSQL and Redis, and the `celery inspect ping` healthcheck of `vps2.yml`;
  - `redis`: started with `--aclfile /etc/redis/users.acl` instead of `--requirepass` (the rendered file defines `default` with `REDIS_PASSWORD` and `homebox`), and also published on `10.8.0.1:6379`; its healthcheck still authenticates as `default`.
- [X] T079 [P] [US2] Update `infra/compose/vps2.yml`: `RAW_ROOT=/srv/raw` mounted read-write into `worker-imports` and `worker-maintenance`; `worker-scrape` on `-Q scrape`; from `.env`, the base values `Settings` requires for `ingest` (`DATABASE_URL`, `DATABASE_URL_SYNC` and `REDIS_URL` pointing at VPS-1's VCN IP, plus `MEDIA_BASE_URL`, `MEDIA_ROOT`, `MEDIA_REHOST_ALLOWED_HOSTS` and `CORS_ORIGINS`, the last unused by workers) and the `SATAIR_*`, `SCRAPE_USER_AGENT` and `YSSCORES_FETCH_QUEUE` values. `worker-live`, `worker-notify` and `flower` stay defined and are not started on D2. Keep exactly one `beat`.
- [X] T080 [P] [US2] Create `infra/compose/home-box.yml`: one `worker-scrape` service from `ghcr.io/${GHCR_OWNER}/madar-backend-amd64:stable` (`platform: linux/amd64`), `-Q scrape_home`, `REDIS_URL=redis://homebox:<password>@10.8.0.1:6379/0` and `SCRAPE_USER_AGENT` from the box's `.env`, no database URL, `cap_drop: [ALL]`, `no-new-privileges`, and the same healthcheck.
- [X] T081 [P] [US2] Create `infra/redis/users.acl.tmpl` with the `default` user and the [homebox ACL](contracts/ingestion.md#the-home-boxs-redis-acl) on one line each, using `${REDIS_PASSWORD}` and `${REDIS_HOMEBOX_PASSWORD}` placeholders. Narrow the categories to the commands Celery and the token-bucket script actually send, keeping T066 green. Render it on VPS-1 in `infra/scripts/deploy.sh` to `/srv/madar/redis/users.acl` (mode 600, owner `deploy`), reading the passwords from `/srv/madar/.env`, never echoing them.
- [X] T082 [P] [US2] Limit Redis on `wg0` to the home box in `infra/firewall/vps1.rules`. Redis on `10.8.0.1:6379` is a Docker-published port, so Docker redirects its traffic before it reaches INPUT (the file's own comment above the DOCKER-USER rules):
  - add `-A DOCKER-USER ! -s ${HOME_BOX_WG_IP}/32 -p tcp -m conntrack --ctorigdst 10.8.0.1 --ctorigdstport 6379 --ctdir ORIGINAL -j DROP` next to the VCN rules. Add `HOME_BOX_WG_IP` (the address `wg-add-peer.sh home-box` gave the box) to `infra/scripts/bootstrap-vps.sh`'s required keys and `envsubst` list for `vps1`, to `infra/compose/example.env`, and to the render command in `docs/runbooks/firewall-changes.md`;
  - remove the INPUT rule `-A INPUT -i wg0 -p tcp -m tcp --dport 6379 -j ACCEPT`, which today accepts every `wg0` peer;
  - extend `infra/scripts/check-firewall.sh` to check both, and test from a second peer (the owner's laptop) that `10.8.0.1:6379` doesn't connect.
- [X] T083 [US2] Extend `infra/scripts/deploy.sh` ([R22](research.md#r22-deploying-vps-2)):
  - on VPS-1, also start `worker-media` on the new tag, wait for its healthcheck as well as both `/healthz` URLs, and roll both back together;
  - `deploy.sh --host vps2 <image-tag>`: pull with the token from stdin, `compose -f compose/vps2.yml up -d worker-imports worker-scrape worker-maintenance beat`, wait up to 90 s for every one to be healthy, and restore the previous tag on failure.
- [X] T084 [P] [US2] Create `infra/scripts/home-box-update.sh`, `infra/scripts/home-box-update.service` and `infra/scripts/home-box-update.timer` (every 10 minutes): log in to GHCR with `GHCR_READ_TOKEN` from the box's `.env`, pull `:stable`, log out, `compose -f home-box.yml up -d`. CI never connects to the box.
- [X] T085 [US2] Extend `.github/workflows/backend.yml`:
  - **build:** also build `linux/amd64` natively on the x86 runner and push it as `ghcr.io/<owner>/madar-backend-amd64:<sha>`;
  - **deploy:** unchanged steps, plus `worker-media` through `deploy.sh`;
  - **deploy-vps2:** after `deploy`, group `deploy-vps2`, over WireGuard with `ssh -J deploy@10.8.0.1 deploy@${{ vars.VPS2_VCN_IP }}`, rsync `infra/`, then `deploy.sh --host vps2 <sha>`;
  - **stable tag:** after both deploys succeed, move `madar-backend-amd64:stable` to the sha;
  - **retention:** keep 3 versions of each package, never deleting the one `stable` points to.

### Validation (B2)

- [ ] T086 [US2] Bring the hosts up (the owner sets VPS-2's `.env`, `REDIS_HOMEBOX_PASSWORD` and `HOME_BOX_WG_IP` on VPS-1, `VPS2_VCN_IP`, VPS-2's host key in `DEPLOY_KNOWN_HOSTS`, and the home box's peer, `.env` and timer), merge, and check:
  - `backend.yml`'s `deploy` and `deploy-vps2` are green and the amd64 image is tagged `stable`;
  - VPS-1 shows `api-public`, `api-admin` and `worker-media` healthy; VPS-2 shows the three workers healthy and exactly one `beat`; the home box shows `worker-scrape` healthy on `scrape_home`.
- [ ] T087 [US2] Check the first unattended run ([quickstart.md](quickstart.md#lane-b2-ingestion-and-hosts)): after the next `ysscores-fixtures` slot, `import_runs` shows a `succeeded` (or `partial`, with reasons in `run.json`) run, `raw_path` exists on VPS-2, tomorrow's Cairo day has ysscores matches with UTC kickoffs, a second run reports `items_upserted = 0`, and a kickoff locked in the admin is unchanged (SC-004). Stop the home box's worker, start a `legacy` run on demand, and see tomorrow's fixtures with their links and no duplicates. Confirm a new team's logo was filled by `worker-media` on `media.<ip1>.sslip.io`.
- [X] T088 [US2] Write the runbooks (FR-055): `docs/runbooks/imports-and-sources.md` (the schedule, starting a run on demand with the exact `celery -A app.workers call` command, reading `import_runs` and `run.json`, pausing a source, switching `YSSCORES_FETCH_QUEUE`), `docs/runbooks/home-box.md` (joining WireGuard, its `.env`, the timer, checking it, and taking it offline), and `docs/runbooks/workers.md` (VPS-2's services, `worker-media` on VPS-1, health, the VPS-2 deploy and rollback, and the raw-page retention). Update `deploy-and-rollback.md` (VPS-2 and `worker-media`), `firewall-changes.md` (6379 on `wg0`), `private-network.md` (the home-box peer) and `secrets.md` (`REDIS_HOMEBOX_PASSWORD`, `SATAIR_*`, `GHCR_READ_TOKEN`). Keep `docs/runbooks/README.md`'s setup order and "After setup" table pointing to them. Every command must match the code.
- [X] T089 [US2] Add the D2 Lane B2 items to `docs/owner-actions.md` (before merge: review T081–T085; set VPS-2's `.env` and `REDIS_HOMEBOX_PASSWORD`; add `VPS2_VCN_IP` and VPS-2's host key; set up the home box; after merge: check the first unattended run and the bridge), each with its task ID and runbook link, and update the "Open now" table.

### Still open in this lane

Everything blocked on Lane B1's morning merge is now implemented against it, after rebasing on
`d02-b1` (T015's PR): `app.workers` (T006), `app/media/` (T008) and revision `0003` (T010) are in
the tree, so T060, T061, T064, T065 and T073–T075 are written and green, and T077 passes:

- `pytest tests/adapters`: 128 tests (fetcher, rate limit, ysscores parse/normalize, resolution,
  the message, the raw store, the home-box ACL, the schedule, upsert, the bridge, the tasks,
  `rehost_logo`), coverage 93 % on `app/adapters`;
- `ruff check .` and `mypy --strict app` are clean, and the whole backend suite is green.

T086 and T087 are the owner's checks on the live hosts, and stay open until the hosts exist.

### Review fixes (round 1)

Source: [reviews/b2-round-1.md](reviews/b2-round-1.md). Fix in this order, before the first merge to `master`: as built, the first deploy takes Redis down (B2-R1-1). Then re-run `/speckit-review-implementation lane=b2` as round 2. The PLAUSIBLE findings (B2-R1-23 to B2-R1-28) have no task; check them at T086 and T047.

- [X] B2-R1-1 [US2] Make the rendered Redis ACL readable by the container's `redis` user (uid 999) and nobody else, in `infra/scripts/deploy.sh:131` and `infra/scripts/bootstrap-vps.sh`. Today `install -m 600` leaves it owned by `deploy`, and `redis:7.4.12` aborts with "Error loading ACLs … Permission denied", so the first `sync` or `deploy` crash-loops Redis and `/healthz` returns 503. For example, have bootstrap create a gid-999 group that `deploy` joins, then render with `install -m 640 -g <group>`. Add a CI step to `.github/workflows/infra.yml` that renders the template with fake passwords at the same mode and owner, boots `redis:7.4.12` with the compose command, and `PING`s it as `default` and `homebox`. It must fail on today's script. (CRITICAL, per constitution IX, T081)
- [X] B2-R1-2 [US2] Reconcile channel links only for adapters that supply them, in `backend/app/adapters/upsert.py` (`:174`, `:371-377`) and `backend/app/adapters/base.py`. Today ysscores sends `links=()`, so every `source='ysscores'` link the D1 snapshot loaded (`backend/app/etl/matches.py:243`) is deleted on the first run. Use `links: … | None`, where `None` means "not provided", or an adapter capability flag. Add a test in `backend/tests/adapters/test_upsert.py`: a snapshot match with `source='ysscores'` links keeps them all after a ysscores run. (CRITICAL, per FR-022, constitution I and VII)
- [X] B2-R1-3 [US2] Drop `--proxy-headers` from the api-admin command in `infra/compose/vps1.yml:85`. Today gunicorn 26.2.0 exits 2 with "unrecognized arguments", so api-admin can't start, and a rollback keeps the same command. `UvicornWorker` with `--forwarded-allow-ips=10.8.0.1` already trusts XFF from Caddy. Add a CI step that runs the compose file's api-admin command with `gunicorn --check-config`, so a bad flag fails the PR. (HIGH, per FR-003, constitution IX)
- [X] B2-R1-4 [US2] Give the jump to VPS-1 its own identity and pinned host key, in `.github/actions/vps1-sync/action.yml` and `.github/workflows/backend.yml:338`. Today `-J deploy@10.8.0.1` gets none of the command-line `-i`, `UserKnownHostsFile` or `StrictHostKeyChecking` options, so `deploy-vps2` fails, and `stable` and `retention` never run. Write an ssh config with `Host vps1` (identity, known_hosts, `IdentitiesOnly`, `BatchMode`) and `Host vps2` with `ProxyJump vps1`, and use it with `-F`. Add a CI dry-run that prints the effective jump options (`ssh -G vps2`) and asserts the jump uses the key. (HIGH, per FR-029, T085)
- [X] B2-R1-5 [US2] Create `/srv/raw` for uid 10001 on VPS-2, in `infra/scripts/bootstrap-vps.sh` (`ensure_dirs`, lines 158–162), and say so in `docs/runbooks/workers.md`. Today Docker creates it as `root:root 0755`, so `RawStore.save` raises `PermissionError` and every ingest fails. Add a check to the bootstrap test or the CI script lint that `ensure_dirs vps2` lists `/srv/raw`. (HIGH, per FR-025, FR-029, T079)
- [X] B2-R1-6 [US2] Gate `check-firewall.sh`'s VPS-1 expectations by host role, in `infra/scripts/check-firewall.sh:70-88`. Today `bootstrap-vps.sh vps2` (`:249`, `:264`) re-applies the firewall and restarts Docker on every run, then exits 1. Give VPS-2 its own expectations. Add a CI step that runs the check's expectation logic against both rendered rulesets: VPS-1 passes, VPS-2 passes, and a VPS-1 set without the 6379 rule fails. (HIGH, per T082, constitution IX)
- [X] B2-R1-7 [US2] Load the ACL when the rendered file changes, in `infra/scripts/deploy.sh` (`render_redis_acl`, lines 118–135), and fix the rotation runbooks. Today nothing restarts Redis or runs `ACL LOAD`, so a rotated password stays valid. `docs/runbooks/secrets.md:68,119,125` and `docs/runbooks/home-box.md:59` describe a recreate that doesn't happen, and "Rotate the Redis password" would cause `WRONGPASS` everywhere. Afterwards the script compares the files, runs `redis-cli ACL LOAD` (or restarts Redis) and checks the result, and both procedures render, then load, then recreate the clients. Add a shellcheck-clean test, or a CI step that renders twice with different passwords and asserts the second password works and the first doesn't. (HIGH, per constitution V, T088)
- [X] B2-R1-8 [US2] Let a ysscores fetch wait for its tokens, in `backend/app/adapters/fetcher.py:122-123` (with `ratelimit.py:28` and `ysscores.py:101-111`). Today the third of four POSTs finds the bucket empty and raises `Retryable`, and the retry starts again at day 0, so no 4-day run can ever finish. Afterwards the fetcher sleeps until the next token, up to `refill_seconds`, with a bounded total deadline, or the fetch resumes per day. Add a test with the real `RateLimiter` (dev Redis) and a fake clock: a four-day fetch completes within the plan's one minute. It must fail before the fix. (HIGH, per FR-020, SC-004, R16)
- [X] B2-R1-9 [US2] Record every failed fetch in `import_runs`, in `backend/app/adapters/tasks.py` (`:30`, `:128-158`), `backend/app/adapters/ysscores.py:55,134` and `fetcher.py`. Today ysscores' own `LayoutChanged`, exhausted `Retryable`, `FetchError`, `HostNotAllowed`, `ResponseTooLarge` and `RedirectLimit` escape with no `ScrapeResult`, and `http_errors` is always 0. Afterwards there is one shared `LayoutChanged` in `adapters/base.py`, the fetcher counts HTTP errors, and both the final retry and non-retryable errors send `ScrapeResult.failed(...)` with the count, a reason and the pages fetched so far. Fix `imports-and-sources.md:70,87` to match. Add `fetch`-level tests for 403 × 6, for 404, and for a page with no `.matches-wrapper`, each ending in a `failed` run with its errors. (HIGH, per FR-025, SC-005)
- [X] B2-R1-10 [US2] Import postponed ysscores items with `time_tbd = true` and no kickoff, in `backend/app/adapters/ysscores.py:145-151` and `base.py` (`normalize`). The owner decided this on 2026-10-31, and research.md R16 "Postponed items" now says it. Today `match-postponed` / `data-status="14"` is ignored, so these items import as scheduled at their old time, and the D1 clock rule later shows them as «مباشر». Afterwards:
  - `parse` carries a `postponed` flag;
  - `normalize` drops the time;
  - a locked kickoff is kept, with `time_tbd` derived from it (B2-R1-11);
  - no status is written;
  - each postponed item is listed in `run.json`.

  Reverse `backend/tests/adapters/test_ysscores_parse.py:79-83` (`test_postponed_items_keep_their_time`) on `tests/fixtures/ysscores/2026-10-31.html` (10 postponed of 129). Add an upsert test: a match already stored as scheduled becomes TBD on the next run. (HIGH, per constitution II, R16)
- [X] B2-R1-11 [US2] Write `time_tbd` only together with `kickoff_at`, in `backend/app/adapters/upsert.py:319-345`. Today a locked kickoff plus a TBD feed item violates `ck_matches_time_tbd`, so the item's other fields never update and every run is `partial`. Derive `time_tbd` from the resulting kickoff. Add a test with a locked kickoff and a `--:--` item. (MEDIUM, per FR-022)
- [X] B2-R1-12 [US2] Give `ingest` a failure path, in `backend/app/adapters/tasks.py:190-236`. Today the `running` row is committed with no `try`, `normalize` runs outside the per-item savepoints (a `"12:99 م"` time raises), and nothing sets `finished_at`. Afterwards any exception marks the run `failed` with an `error` and `finished_at`, then re-raises. Normalising happens per item inside the savepoint, and every terminal state sets `finished_at`. Add tests for a bad time and for a raw-store `PermissionError`. (MEDIUM, per FR-025, constitution VII)
- [X] B2-R1-13 [US2] Bound the decompressed size of home-box pages, in `backend/app/adapters/messages.py:146`. Today `gzip.decompress` has no limit, so a 1.5 MB message can inflate to gigabytes and OOM `worker-imports`. Use `zlib.decompressobj` with `max_length` at the fetcher's 5 MB cap and reject anything larger. Add a gzip-bomb test. (MEDIUM, per constitution V)
- [X] B2-R1-14 [US2] Record orphan channel refs, in `backend/app/adapters/upsert.py:412-414`. Today the comment says "skipped and logged", but nothing is logged or recorded. Add each one to `outcome.skipped` with reason `channel_not_published`, so it reaches `run.json`, and assert it in `backend/tests/adapters/test_satair_bridge.py`. (MEDIUM, per FR-027, T061)
- [X] B2-R1-15 [US2] Set the worker log level in `infra/compose/vps2.yml:41,51,64`, `infra/compose/vps1.yml:108` and `infra/compose/home-box.yml` (`--loglevel=INFO`), and ask Lane B1 for a JSON log formatter in `backend/app/workers/` that keeps `extra=` fields (a `setup_logging` handler). Today every `log.info` (`skipped`, `fetched`, `ingested`, `source_paused`) is dropped, and warnings lose their fields. Add a test that a task's `log.info` with `extra=` reaches stdout as JSON with those keys (B1's part). (MEDIUM, per constitution IX, US2 scenario 6)
- [X] B2-R1-16 [US2] Make the adapter tests prove what T060, T061 and T064 claim, in `backend/tests/adapters/`:
  - a two-connection test in which removing `.with_for_update()` at `upsert.py:301` fails;
  - the manual-hidden-link re-add path (`upsert.py:386-388`) with the channel in the source's desired set;
  - the `except Exception` savepoint (`upsert.py:107-113`);
  - real assertions in place of `test_rehost_logo.py:111` (`… or asset.path`) and `test_satair_bridge.py:104-109`;
  - prefix-scoped deletes instead of `flushdb()` in `test_tasks.py`, `test_ratelimit.py`, `test_rehost_logo.py` and `test_homebox_acl.py`.

  Each new test must fail when its guard is removed. (MEDIUM, per constitution test-first, T060)
- [X] B2-R1-17 [US2] Make T067's placeholder check able to fail, in `.github/workflows/infra.yml:51-52`. Today its regex only catches a password at the end of a line, so a literal mid-line password on the `default` line passes. Flag any `>` token on a `user` line that isn't exactly `>${REDIS_PASSWORD}` or `>${REDIS_HOMEBOX_PASSWORD}`, and add two bad templates as fixtures that the step must reject. (MEDIUM, per T067, FR-052)
- [X] B2-R1-18 [US2] Narrow the `homebox` ACL to what the worker sends, in `infra/redis/users.acl.tmpl:11`. Today it is the contract's starting point byte for byte (`+@scripting`, `+@pubsub &*`, `+@keyspace`), though T081 is ticked. Derive the list from a real worker run (`ACL LOG` or `MONITOR`). Replace the raw-command test in `backend/tests/adapters/test_homebox_acl.py:65-77` with a real kombu connection (with `global_keyprefix`) as `homebox`, sending and receiving one task, and a denied command. (MEDIUM, per T081, constitution V)
- [X] B2-R1-19 [US2] Fix the on-demand fetch command in `docs/runbooks/imports-and-sources.md:39-45`, and ask Lane B1 to register `IngestionRouter` in `create_app()` in `backend/app/workers/`. Today `celery call` never imports `app.adapters.tasks`, so `adapters.fetch` routes to `maintenance` and runs on VPS-2 instead of the home box. Until B1's change lands, pass `--queue` explicitly. Add a test that resolves the route in a fresh subprocess importing only `app.workers`. (MEDIUM, per contracts/ingestion.md, T064)
- [X] B2-R1-20 [US2] Correct the runbook commands that don't run as written. Run each corrected command once against the dev stack or a host:
  - `ssh deploy@…` from the owner's machine becomes `ssh ubuntu@…` then `sudo -iu deploy`, in `docs/runbooks/workers.md:29-37,60-63,101-102`, `imports-and-sources.md:39-51,79` and `home-box.md:97`;
  - `psql "$DATABASE_URL_SYNC"` becomes `dc exec postgres psql -U madar -d madar`, in `imports-and-sources.md:60,96,97`;
  - `--env-file` is added in `home-box.md:65-66`;
  - `home-box.md:76` uses the `madar-redis-1` container and reads the password inside it;
  - `imports-and-sources.md:116` names its services;
  - write down how VPS-2's host key reaches `DEPLOY_KNOWN_HOSTS`.

  No test (docs). (MEDIUM, per T088, the root CLAUDE.md runbook rule)
- [X] B2-R1-21 [US2] Correct the D2 facts in `docs/owner-actions.md` (lines 13, 195–198, 208–215, 233):
  - move the home-box start after the first deploy;
  - make the "Open now" counts match the lists;
  - give Lane A's T108 items their IDs, the editors' WireGuard peer and the quickstart link;
  - fix the `../../specs/…` link to `../specs/…`;
  - say that a missing `ADMIN_JWT_SECRET` fails every compose command at parse time;
  - add `--pass` to the `redis-cli --user homebox ping` proof.

  No test (docs). (MEDIUM, per T089, the root CLAUDE.md owner-actions rule)
- [X] B2-R1-22 [US2] Update the host docs:
  - `docs/runbooks/provision-host.md` §4 lists `REDIS_HOMEBOX_PASSWORD`, `HOME_BOX_WG_IP` and VPS-2's keys;
  - `docs/runbooks/exposure-check.md` checks `10.8.0.1:6379` from a wg0 peer;
  - `docs/runbooks/README.md` moves `staff-accounts.md` out of "Planned runbooks".

  No test (docs). (MEDIUM, per FR-055)

Done in round 2 on `d02-features`: all 22. The one deliberate deviation: B2-R1-8 waits in the
fetcher (`WAIT_BUDGET` 60 s, 250 ms polls) rather than resuming per day, and B2-R1-18 keeps
`+@pubsub` scoped to `&celery:*` after a real kombu run showed the transport needs sets and
pub/sub (so `+@set` stays granted through `+@write`).

### Review fixes (round 2)

Source: [reviews/b2-round-2.md](reviews/b2-round-2.md). Fix in this order, then re-run `/speckit-review-implementation lane=b2` as round 3. B2-R2-5 also asks Lane B1 (B1-R2-7). B2-R2-13 waits on Lane M's `d02-m` landing.

- [X] B2-R2-1 [US2] Make the Redis ACL directory traversable by uid 999, in `infra/scripts/deploy.sh:131` (`install -d -m 700 "$state_dir/redis"`, re-applied on every run) and `infra/scripts/bootstrap-vps.sh:173` (`install -d -m 750 -o deploy -g deploy /srv/madar/redis`). Today `redis:7.4.12` with the 640 `deploy:999` file in a 700 or 750 `deploy` directory aborts with `opening file '/etc/redis/users.acl': Permission denied`, so the first D2 deploy takes `/healthz` to 503 with no rollback. Afterwards the directory is group 999 with mode 750 (or 755), and one render script is called by both `deploy.sh` and `infra/scripts/check-redis-acl.sh` (which today builds its own 755 directory at `:26`), so CI checks the real modes, owner and group. Add a negative fixture: a 700 directory must fail the check. It must fail on today's `deploy.sh`. (CRITICAL, per constitution IX and V, T081, B2-R1-1)
- [X] B2-R2-2 [US2] Call `ssh-config.sh` by its real path, in `.github/actions/vps1-sync/action.yml:55`. Today `"$GITHUB_ACTION_PATH/../../infra/scripts/ssh-config.sh"` resolves to `.github/infra/scripts/`, which doesn't exist, so the "ssh" step exits 127 and `deploy`, `deploy-vps2` and `infra.yml`'s `sync` all fail. Use `"$GITHUB_WORKSPACE/infra/scripts/ssh-config.sh"`, and add a CI step that runs the path the action uses. (HIGH, per FR-029, T085, B2-R1-4)
- [X] B2-R2-3 [US2] Let the `homebox` user subscribe to the worker's control channel, in `infra/redis/users.acl.tmpl:13`. Today a real `celery worker -Q scrape_home` as `homebox` exits with `NoPermissionError('No permissions to access a channel')`, because `PSUBSCRIBE celery:/0.celery.pidbox` is matched literally and `&celery:*` doesn't allow it. Add `&celery:/0.celery.pidbox`, and correct the comment that says it "may not touch a `set`". Make `backend/tests/adapters/test_homebox_acl.py` start a real worker as `homebox` and get an `inspect ping` reply; today's test runs only a producer and a `SimpleQueue`. (HIGH, per T081, research R21, FR-028, SC-004, B2-R1-18)
- [X] B2-R2-4 [US2] Make `infra.yml`'s shellcheck and actionlint steps pass, in `infra/scripts/check-redis-acl.sh:30` and `.github/workflows/infra.yml:52,87`. Today `koalaman/shellcheck:v0.11.0 --external-sources infra/scripts/*.sh` and `rhysd/actionlint:1.7.12` both exit 1 with SC2016 on each `envsubst '${…}'` line, so the infra `check` job is red and `sync` never runs. Add `# shellcheck disable=SC2016` with the same reason `deploy.sh` gives, and re-run both pinned images. (HIGH, per the constitution quality gates)
- [X] B2-R2-5 [US2] Send the bridge's Firebase key in a header, in `backend/app/adapters/satair_bridge.py:78` (`params={"key": api_key}`), `backend/app/adapters/fetcher.py` (`get()` takes `headers`) and `fetcher.py:197`. Today `httpx` logs every request's full URL at INFO, so each bridge run writes `?key=…` to the logs, and an oversize Firestore body puts it in `fetch_failed`'s `why` through `ResponseTooLarge`'s message. Afterwards the key goes in `X-Goog-Api-Key`, and `ResponseTooLarge` names the URL without its query. Ask Lane B1 to quiet `httpx` as well (B1-R2-7). Add a test that captures the logs of a bridge fetch, an oversize one included, and asserts the key never appears. (HIGH, per FR-027, D15, constitution V, B2-R1-29)
- [X] B2-R2-6 [US2] Send a `failed` result for every way a fetch can end, in `backend/app/adapters/tasks.py:132-162` and `backend/app/adapters/ysscores.py` (`parse`). Today `httpx.TransportError` on the last retry, an empty 200 (`lxml` raises `ParserError`), `MessageTooLarge` from `ScrapeResult.build` and any other exception leave no `import_runs` row. Afterwards the final attempt of a transport error and a last `except Exception` both send a `failed` result with an error code and re-raise. A page with no document raises `LayoutChanged`, and a `failed` result drops its pages when they would exceed the cap. Add `fetch` tests for a transport error on every attempt, an empty 200 and an oversize failure. (HIGH, per FR-025, SC-005, B2-R1-9)
- [X] B2-R2-7 [US2] Correct how VPS-2's host key gets into `DEPLOY_KNOWN_HOSTS`, in `docs/runbooks/provision-host.md:361`. Today it runs `ssh-keyscan -J …`, but `ssh-keyscan` has no `-J`, and the `sed` renames the host to `vps2` while `ssh-config.sh` sets no `HostKeyAlias`, so `deploy-vps2` would fail host-key verification. Scan from VPS-1 (`ssh ubuntu@10.8.0.1 ssh-keyscan -t ed25519 "$VPS2_VCN_IP"`) and keep the IP, or add `HostKeyAlias vps2` in `infra/scripts/ssh-config.sh`. Add the VPS-2 line to the CI `ssh -G` fixture. (MEDIUM, per T088, B2-R1-20f)
- [X] B2-R2-8 [US2] Make the Redis password rotation render the ACL, in `docs/runbooks/secrets.md:122-128` and `:74`. Today step 2 only runs `dc restart redis`, so Redis restarts on the old ACL while every client sends the new password, and the home-box step 4 runs `docker compose -f infra/compose/home-box.yml up -d` with no `--env-file`. Afterwards step 2 runs `deploy.sh --infra-only`, step 4 passes `--env-file /srv/madar/.env`, and the VPS-2 recreate command is written out. No test (docs). (MEDIUM, per constitution V, B2-R1-7, B2-R1-20c)
- [X] B2-R2-9 [US2] Fix the home-box ACL listing command, in `docs/runbooks/home-box.md:82-83`. Today it uses `docker exec -T` (not a flag) and a `sed` that prints the rest of the ACL line, not the password. Use `docker exec madar-redis-1 sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ACL LIST'`, the form of the container's own health check. No test (docs). (MEDIUM, per B2-R1-20d)
- [X] B2-R2-10 [US2] Stop `bootstrap-vps.sh` aborting when gid 999 has no group, in `infra/scripts/bootstrap-vps.sh:166` (`existing=$(getent group "$acl_gid" | cut -d: -f1)` under `pipefail`). Today a missing group exits 2 with no message, so the `groupadd` branch never runs. Afterwards the lookup tolerates a missing group (or the script uses a dedicated group). `provision-host.md` and `docs/owner-actions.md` also say that an already-provisioned VPS-1 must re-run `bootstrap-vps.sh vps1` before the first D2 deploy (`deploy.sh:129` refuses without it). Add a CI case for an unused gid. (MEDIUM, per constitution IX)
- [X] B2-R2-11 [US2] Make the Redis ACL reload safe, in `infra/scripts/deploy.sh:138-164`. Today the file is replaced and Redis restarted. A bad file leaves Redis down with the old ACL gone, and the check pings as `default` only. Afterwards the old file is kept and restored on failure (or `ACL LOAD` is used), `homebox` is checked too, and `infra.yml` renders the ACL twice with different passwords and proves the second works and the first doesn't. (MEDIUM, per constitution IX and V, B2-R1-7)
- [X] B2-R2-12 [US2] Guard VPS-2's `up -d` and roll it back, in `infra/scripts/deploy.sh:248,261`. Today VPS-1 uses `start_apis … || started=0` with a rollback, but VPS-2's `up -d` under `set -e` just exits. Afterwards a failed start on VPS-2 rolls back to the previous tag. Add a dry-run or scripted test of the failure path. (MEDIUM, per constitution IX, B2-R1-24)
- [X] B2-R2-13 [US2] Run Lane M's two checks in CI once `d02-m` lands, in `.github/workflows/app.yml` and `.github/workflows/pwa.yml`. Today no workflow runs `app/tool/check_web_assets.sh` (`sqlite3.wasm`, `drift_worker.js`) or `app/tool/check_providers.sh`, and `pwa.yml`'s web build runs only on `master`. Add a web build plus `check_web_assets.sh` on PRs that touch `app/**`. Add `check_providers.sh` to `app.yml`, unless Lane M moves that check into `flutter test` (`m-round-2.md` M-R2-7); agree with Lane M first. (MEDIUM, per M-R1-2, M-R1-16, SC-009)
- [X] B2-R2-14 [US2] Run the api-admin command check when the compose file changes, in `.github/workflows/backend.yml:10-18`. Today the step at `:86-106` parses `infra/compose/vps1.yml`, but a PR that edits only that file doesn't trigger `backend.yml`. Add `infra/compose/**` to the path filters, or run the step in `infra.yml` too. (MEDIUM, per B2-R1-3)
- [X] B2-R2-15 [US2] Bring the deploy docs in line with the code:
  - `docs/runbooks/deploy-and-rollback.md:16-17`: the `ubuntu@` jump, the Redis restart on an ACL change, and the VPS-2 divergence note (B2-R1-36).
  - `docs/owner-actions.md` T082 proof: the box's `.env` has no `REDIS_HOMEBOX_PASSWORD`.
  - `docs/runbooks/README.md` step 11: the home-box peer and the firewall rule before the first deploys, as owner-actions says.
  - `provision-host.md:390` and `firewall-changes.md:87`: `check-firewall.sh --role`.

  No test (docs). (MEDIUM, per T088, FR-055, B2-R1-21, B2-R1-25)
- [X] B2-R2-16 [US2] Bound the whole message, not just each page, in `backend/app/adapters/messages.py:145-149,158-168`. Today `raw_pages()` inflates every page, and the page count is unbounded: 250 pages of 5 MB zeros make a 1.7 MB message (under the 2 MB cap) that inflates to 1,250 MB in `worker-imports`. Cap the page count (a window is at most four pages) and a total inflated budget, and check the message length before parsing. Add a many-page test that the swap to `gzip.decompress` also fails. (MEDIUM, per B2-R1-13)
- [X] B2-R2-17 [US2] Make the rate-limit fetcher test fast and real, in `backend/tests/adapters/test_fetcher.py:147-161,218`. Today `test_a_rate_limited_host_raises_retryable_without_a_request` busy-waits the real 60 s `WAIT_BUDGET`, its `assert calls == []` is vacuous (`calls` isn't wired to the transport), and `:218` adds a `# type: ignore[arg-type]`. Inject a fake clock and sleep with a small budget, wire `calls` to the transport, assert the poll count, and build the window with `DateWindow.next_days(...)`. (MEDIUM, per B2-R1-16)
- [X] B2-R2-18 [US2] Make two new guards provable, in `backend/tests/adapters/test_upsert.py:268` (the guard at `backend/app/adapters/upsert.py:408-409`) and a task-level test for `backend/app/adapters/tasks.py:322`. Today deleting `if channel_id in existing: continue` keeps all tests green, because the duplicate lands in `skipped` and nobody checks it, and `run.json["postponed"]` is asserted nowhere. Assert `outcome.skipped == []` with the link row unchanged, and that `run.json["postponed"]` lists the postponed refs. Each test must fail when its guard is removed. (MEDIUM, per B2-R1-16, research R16)

Done in round 3 on `d02-features`: all eighteen. Deviations and decisions worth knowing:

- the ACL is rendered by one script, `infra/scripts/render-redis-acl.sh`, called by `deploy.sh` and by
  `check-redis-acl.sh`; it writes the directory 750 and the file 640, both group 999, and keeps the
  previous file. A refused ACL is restored instead of using `ACL LOAD` (the old password is the only
  one Redis still accepts, so the deploy cannot authenticate to run it), and the post-change check
  pings `default` **and** `homebox`;
- `check-redis-acl.sh` also rotates the password once, which is the render-twice proof B2-R2-11 asked
  for; the 700-directory fixture must fail;
- the home-box worker test starts a real `celery worker` as `homebox` and waits for `inspect ping`
  (60 s budget). It fails when `&celery:/0.celery.pidbox` is removed — verified by removing it;
- the message caps are `MAX_PAGES = 4` and `MAX_TOTAL_BYTES = 16 MB`; a page-level bomb test uses
  `tracemalloc` to show the peak stays at the 5 MB page cap, which is what kills the
  `gzip.decompress` mutant;
- B2-R2-13 delivers the web build plus `check_web_assets.sh` in `app.yml`. `check_providers.sh` stays
  out of CI on purpose: Lane M is moving that check into `flutter test` (`m-round-2.md` M-R2-7), which
  the same job already runs;
- the VPS-2 rollback dry run lives in `infra.yml` and extracts `deploy_vps2` with `awk`, so it drives
  the real function under `set -e` with stubbed `docker`/compose.

### Review fixes (round 3)

Source: [reviews/b2-round-3.md](reviews/b2-round-3.md). Fix in this order, then re-run `/speckit-review-implementation lane=b2` as round 4.

- [X] B2-R3-1 [US2] Send a `failed` result when `adapters.fetch` fails during setup, in `backend/app/adapters/tasks.py:124,130-131`. Today `date.fromisoformat(start)`, `http_fetcher()` (which calls `require_user_agent()` and `redis_client()`) and `adapter_for()` run before the `try`, so a missing `SCRAPE_USER_AGENT` on the home box makes every run raise with no `import_runs` row. Build the fetcher and adapter inside the guarded block (close the fetcher only when it was built), or send `_send_failure(..., "fetch_error")` for a setup error. Add a test with no user agent configured that expects a `failed` run row. (MEDIUM, per FR-025, SC-005, B2-R2-6)
- [X] B2-R3-2 [US2] Restore the previous Redis ACL when the first `up` fails, in `infra/scripts/deploy.sh:190-192` (`deploy_vps1`) and `:320-322` (`--infra-only`). Today `render_redis_acl` installs the new file and `up -d --wait … redis` runs before `reload_redis_acl`, whose restore from `users.acl.prev` is the only one. If that `up` recreates Redis and Redis refuses the file, `set -e` exits and Redis stays down on it. Run the same restore for a failed `up` (one function both paths use), and cover it in `infra/scripts/check-redis-acl.sh` or an `infra.yml` step that drives the function with a stubbed compose. (MEDIUM, per constitution IX, B2-R2-11)
- [X] B2-R3-3 [US2] Write out the VPS-2 command in the Redis rotation, in `docs/runbooks/secrets.md:143`. Today it runs `dc up -d --force-recreate worker-imports worker-scrape worker-maintenance beat`, and `dc` is VPS-1's helper (`deploy-and-rollback.md:49`, `-f compose/vps1.yml`, no `--profile workers`). Use the full command, as `docs/runbooks/imports-and-sources.md:125` does: `IMAGE_TAG=$(cat /srv/madar/current_tag) docker compose --env-file /srv/madar/.env --profile workers -f /srv/madar/infra/compose/vps2.yml up -d --force-recreate …`, checked against `deploy.sh`'s `vps2_compose`. No test (docs). (MEDIUM, per the root `CLAUDE.md` runbook rule, B2-R2-8)
- [X] B2-R3-4 [US2] Stop an infra-only compose change from deploying a release, in `.github/workflows/backend.yml:15`. Today `infra/compose/**` is in the `push` filter as well as `pull_request`, so a merge that touches only `infra/compose/*.yml` builds an image and deploys both VPSes, while `docs/runbooks/deploy-and-rollback.md:3` says such a push applies the infra files without a new image. Keep `infra/compose/**` on `pull_request` only (the api-admin command check is what B2-R2-14 needed), or move that check into `infra.yml`. If the owner wants the deploy, correct `deploy-and-rollback.md:3,218-222` instead. Re-run actionlint. (MEDIUM, per the runbook rule, B2-R2-14)

Done in round 4 on `d02-features`: all four.

- the whole of `adapters.fetch`'s setup (the `start` date, `http_fetcher()`, `adapter_for()`) is inside
  the guard now; `_pages_of`/`_http_errors_of` keep the failure paths readable when the adapter or the
  fetcher was never built. Two tests: a missing `SCRAPE_USER_AGENT` and a bad `start` each write a
  `failed` `import_runs` row;
- `apply_stateful_infra` wraps the `up -d --wait` that recreates Redis, and both `deploy_vps1` and
  `--infra-only` call it. `restore_previous_acl` is shared with `reload_redis_acl`, so the file is put
  back whether the container refuses it at `up` or at the restart. An `infra.yml` step extracts both
  functions, drives them with a stubbed compose, and fails without the restore; it also checks that a
  healthy `up` leaves the new ACL untouched;
- with the stubbed compose now matching on `$1`, the VPS-2 rollback step also fails when `|| started=0`
  is removed. The earlier `case "$*" in *" up -d "*)` never matched (no leading space), so that step
  had been exercising the healthy path;
- `secrets.md`'s rotation step 3 is the full VPS-2 command (`--profile workers`, `vps2.yml`,
  `IMAGE_TAG`), matching `deploy.sh`'s `vps2_compose`;
- `infra/compose/**` stays on `backend.yml`'s `pull_request` filter only, so an infra-only compose push
  syncs infra without a release; `ci-workflows.md` and `infra/README.md` say so.

---

## Lane A

**Story (User Story 4, P4):** As an editor, I fix the day's matches and their channels in one screen.

**Independent test:**

- against Prism serving the updated `admin.json`: `?mock=edit_conflict`, `?mock=precondition_required` and `?mock=forbidden_remove_channels` show their states, and `pnpm test` is green;
- over WireGuard, against the deployed admin API: log in, open tomorrow in A3, filter to missing channels, open a match in A4, add two channels with commentators, hide one channel from this match only, set a manual score, and save: «تم الحفظ» appears, and the change then appears in the app;
- saving the same match from a second browser, then from the first, shows the conflict dialog ([quickstart.md](quickstart.md#lane-a-admin)).

**Compare against:** admin boards "Matches" (`madar-design/admin-react/screens/02-content/Matches.png`), "Match editor" (`madar-design/admin-react/screens/02-content/MatchEditor.png`) and "Dialogs" (`madar-design/admin-react/screens/04-login-and-states/Dialogs.png`), with `madar-design/design-system/components/ConfirmDialog/README.md` and `Button/README.md`.

### Setup (A)

- [x] T090 [US4] Add `date-fns` and `date-fns-tz` to `admin/package.json` and `admin/pnpm-lock.yaml`. Add the `dev:wg` script (`vite --mode wg`) and, in `admin/vite.config.ts`, a `wg` mode whose `server.proxy['/admin/api']` targets `https://10.8.0.1` with `secure: true`, trusting Caddy's root through `NODE_EXTRA_CA_CERTS` ([R23](research.md#r23-reaching-the-admin-api-over-wireguard-on-d2)). No CORS is enabled anywhere.
- [x] T091 [P] [US4] Move `admin/src/app/App.tsx` from `BrowserRouter` to `createBrowserRouter` + `RouterProvider`, with the A3 (`/matches`) and A4 (`/matches/new`, `/matches/:id`) routes behind the session guard. `App.test.tsx` and `Shell.test.tsx` stay green.
- [x] T092 [P] [US4] Update `admin/CLAUDE.md`: `pnpm dev:wg` with `NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt`; that admin times are always Cairo time through `src/lib/cairoTime.ts`; that every endpoint's Zod schema is registered in `src/api/http.ts`.
- [x] T093 [US4] After B1's T015 is on `master` (it carries the regenerated admin client), rebase `d02-a` on it and confirm `pnpm orval && git diff --exit-code src/api/generated/` is clean. Never edit or regenerate a different client by hand on this branch. Register every new endpoint's response schema in `admin/src/api/http.ts`'s `responseSchemas` map (keyed `"<METHOD> <path>"`), and add the generated MSW handlers to `admin/src/test/server.ts`.

### Tests first (A): write them and see them fail

- [x] T094 [P] [US4] Write `admin/src/lib/cairoTime.test.ts` ([R24](research.md#r24-session-forms-and-time-in-the-admin)):
  - a Cairo wall time converts to the right UTC instant on each side of Egypt's 2026 DST changes (the stored UTC differs by the right offset);
  - formatting a UTC instant gives Cairo time with Western digits (`ar-EG-u-nu-latn`), whatever `process.env.TZ` is (run under `TZ=UTC` and `TZ=Asia/Riyadh`);
  - Cairo day bounds for A3's tabs are UTC `from`/`to` covering exactly that Cairo day.
- [x] T095 [P] [US4] Write `admin/src/api/http.test.ts`:
  - mutating requests send `X-CSRF-Token` from the `madar_csrf` cookie;
  - two parallel requests that get `401 token_expired` share one refresh, then both retry once;
  - a failed refresh clears the in-memory token and routes to A1;
  - a response that fails its Zod schema is rejected with a typed error, never passed through.
- [x] T096 [P] [US4] Write `admin/src/components/Button/Button.test.tsx`: each variant and size in `Button/README.md`, disabled, loading, and visible keyboard focus.
- [x] T097 [P] [US4] Write `admin/src/components/ConfirmDialog/ConfirmDialog.test.tsx` and `admin/src/components/ConfirmDialog/ConflictDialog.test.tsx`:
  - `ConfirmDialog phrase`: the confirm button stays disabled until the exact phrase is typed; Escape and cancel close it; focus is trapped and returns to the trigger;
  - `ConflictDialog diff`: the title «عدّل ‹user› هذا العنصر — اعرض التغييرات» for `changed_by.kind = "admin"`, the source's name for `kind = "source"`, the field diff lines, and «إعادة التحميل».
- [x] T098 [P] [US4] Write `admin/src/features/matches/MatchesPage.test.tsx` (A3, MSW from Orval):
  - day tabs in Cairo time; the four filters (competition, source, missing channels, status) sent as query parameters;
  - rows grouped by competition with time, teams and logos, status, channel count, commentator, sources and the locked marker;
  - the table skeleton and the empty state;
  - bulk change of competition for an editor; bulk removal of channels only for an `admin`, after typed confirmation, and absent for an editor;
  - «إضافة مباراة»; no delete action anywhere.
- [x] T099 [P] [US4] Write `admin/src/features/matches/MatchEditor.test.tsx` (A4, MSW from Orval):
  - the team picker shows country, logo and competitions to tell same-name teams apart, and accepts free text;
  - a kickoff entered in Cairo time, labelled «بتوقيت القاهرة», is sent as the right UTC instant on each side of the DST change; "time to be confirmed" sends `time_tbd`;
  - the status override allows a score only where the data-model table allows it, and penalties only for `penalties` and `finished`;
  - the two broadcaster slots; the channel picker filters; per channel, the source badge, «إخفاء من هذا الماتش فقط», «إخفاء دائماً» (after a confirmation) and commentators 1 and 2 (2 disabled until 1 is set); a channel hidden everywhere shows «مخفية دائماً» with «إظهار»;
  - a save sends only changed sections with `If-Match`, then shows «تم الحفظ»; a failure shows «فشل الحفظ»;
  - `409` opens `ConflictDialog` with the current match's diff, and «إعادة التحميل» resets the form; `428` and `422` show their Arabic copy;
  - leaving with unsaved changes is blocked (`useBlocker` and `beforeunload`).

### Implementation (A)

- [x] T100 [P] [US4] Build `admin/src/components/Button/Button.tsx` with `cva` from `Button/README.md`, tokens only. T096 passes.
- [x] T101 [P] [US4] Build `admin/src/components/ConfirmDialog/ConfirmDialog.tsx` and `admin/src/components/ConfirmDialog/ConflictDialog.tsx` from the README and `Dialogs.png`, tokens only, RTL. T097 passes.
- [x] T102 [P] [US4] Implement `admin/src/lib/cairoTime.ts` with `fromZonedTime` and `formatInTimeZone` for `Africa/Cairo`, and the day-bounds helper. T094 passes.
- [x] T103 [US4] Update `admin/src/api/http.ts` (the CSRF header, the single-flight refresh, the retry) and `admin/src/features/auth/session.ts` (refresh once on load, again at `expires_in − 60 s`). T095 passes, and the D1 login tests stay green.
- [x] T104 [US4] Add the D2 copy to `admin/src/i18n/ar.ts`: A3 and A4 labels, toasts, dialogs, empty states, and the `error.code` → Arabic map for every D2 code (`forbidden`, the `*_not_found` codes, `edit_conflict`, `in_use`, `already_exists`, `file_too_large`, `unsupported_media_type`, `validation_error`, `media_invalid`, `precondition_required`). No Arabic literal in components.
- [x] T105 [US4] (built from `StatusChip`, `EmptyState` and `Toast`; the table markup is local rather than `DataTable` — see A-F2) Build A3 in `admin/src/features/matches/MatchesPage.tsx`, `admin/src/features/matches/BulkBar.tsx` and `admin/src/features/matches/queries.ts` (React Query hooks over the Orval client), from `DataTable`, `StatusChip`, `EmptyState`, `Toast` and the new components, and add it to the sidebar. T098 passes.
- [ ] T106 [US4] (open: the editor is one form whose patch is validated by Orval's `patchMatchBody`; the React Hook Form resolver is not wired — A-F1) Build A4 in `admin/src/features/matches/MatchEditor.tsx` with one React Hook Form form and Orval's Zod resolver, split into `admin/src/features/matches/editor/{FieldsSection,TimeField,StatusSection,BroadcastSlots,ChannelsSection}.tsx`, `admin/src/features/matches/TeamPicker.tsx` and `admin/src/features/matches/ChannelPicker.tsx`, plus the unsaved guard, the conflict flow and the toasts. T099 passes.

### Validation (A)

- [ ] T107 [US4] (automated step 1 passes; steps 2–4 are the owner's browser walk — A-F5) Validate the lane in `admin/`:
  1. run `pnpm typecheck && pnpm lint && pnpm test && pnpm build && ./scripts/check-literals.sh && ./scripts/check-token-copy.sh`, and confirm `pnpm orval && git diff --exit-code src/api/generated/`;
  2. run `pnpm prism` + `pnpm dev` and check `?mock=edit_conflict`, `?mock=edit_conflict_source`, `?mock=precondition_required` and `?mock=forbidden_remove_channels`;
  3. after B1's T047, run `NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt pnpm dev:wg` and walk the [quickstart Lane A](quickstart.md#lane-a-admin) steps, including the two-browser conflict;
  4. take screenshots of A3, A4 and both dialogs at 1440 px and 1024 px, compare them with `Matches.png`, `MatchEditor.png` and `Dialogs.png`, and attach them next to the PNGs in the PR.
- [x] T108 [US4] Add the D2 Lane A items to `docs/owner-actions.md` (after merge: a WireGuard peer and Caddy's root CA on each editor's machine, and the first editor walk-through), each with its task ID and runbook link, and update the "Open now" table.

---

### Lane A follow-ups (open)

Carried out of the first implementation pass; none of these are hidden in a commit message.

- [ ] A-F1 **T106, React Hook Form.** Wire `zodResolver(patchMatchBody)` into `MatchEditor` so the one form resolves through the Orval schema instead of validating the assembled patch by hand. Keep A4's behaviour and `MatchEditor.test.tsx` green.
- [ ] A-F2 **T105, `DataTable`.** Move A3's table onto the shared `DataTable` (grouping, bulk bar, skeleton, J/K/X/E keys) and delete the local markup in `MatchesPage.tsx`. Keep `MatchesPage.test.tsx` green.
- [x] A-F3 **Per-row version (Lane B1's contract).** `AdminMatchRow` carries no `etag`, so a bulk action reads each selected match with a `GET` first. Ask B1 to add `etag` to the row (non-breaking) and drop the round trips in `BulkBar.tsx`.
- [ ] A-F4 **Create responses in the client.** Orval emits no response schema for a 201-only operation, so `responseSchemas` maps the five `POST` creates to the entity's `PATCH` envelope (same `$ref` in `admin.json`). Switch back if B1's spec ever gives creates their own response schema or a `200`.
- [ ] A-F5 **T107 steps 2–4 (owner).** Prism `?mock=…` walk, `pnpm dev:wg` over WireGuard with the two-browser conflict, and screenshots at 1440 and 1024 against `Matches.png`, `MatchEditor.png` and `Dialogs.png`. Steps are in [owner-actions](../../docs/owner-actions.md#lane-a-admin-1).

### Review fixes (round 1)

Source: [reviews/a-round-1.md](reviews/a-round-1.md). A-F1 to A-F5 above stay as they are and aren't repeated here: A-R1-11 is A-F1, A-R1-10's `DataTable` part is A-F2, and A-R1-3's bulk part waits on A-F3 (Lane B1). Fix A-R1-1 and A-R1-3 together: fixing the bearer alone turns a failed save into a silent overwrite. Then re-run `/speckit-review-implementation lane=a` as round 2.

- [x] A-R1-1 [US4] Read entity versions through the authenticated mutator, in `admin/src/api/http.ts:224-231` (`getEntityEtag`), used at `admin/src/features/matches/MatchEditor.tsx:250-252` and `BulkBar.tsx:30-34`. Today it calls the bare axios instance without `Authorization`, so against the real API every save of an existing match ends in `428` and every bulk action fails. Afterwards the version comes with the refresh, the retry and the schema. Make the MSW handlers answer `401` without a bearer, and add tests for an A4 save and a bulk action that fail before the fix. (HIGH, per FR-009, FR-031, US4 scenarios 3 and 8)
- [x] A-R1-2 [US4] Take the new version and the server state from each successful save, in `admin/src/features/matches/MatchEditor.tsx:231,240,278-303`. Today `etag` and `lockedFields` keep their load-time values, so a second save in the same session gets `409` against the editor's own change. Have the mutator return the `ETag` header with the body. Add a two-saves test that sends the second `If-Match` as the first save's new ETag. (HIGH, per FR-009, US4 scenario 8)
- [x] A-R1-3 [US4] Send the version the editor actually saw, in `admin/src/features/matches/MatchEditor.tsx:244-254` and `BulkBar.tsx:29-39`. Today A4 takes its data and its ETag from two separate GETs, bulk fetches fresh versions at click time (so a stale selection overwrites silently), and `fail()` ignores `meta.stale_ids`. Afterwards A4 takes the ETag from the response that filled the form, and bulk sends the versions from the list once `AdminMatchRow.etag` exists (A-F3). Until then bulk must not silently fetch fresh versions. A `409` names the `stale_ids` rows. Add tests: a version change between list and click gives `409` with the rows named; A4's `If-Match` equals the loaded data's version. (HIGH, per FR-009, constitution VI, edge cases "two editors" and "bulk with one stale item")
- [x] A-R1-4 [US4] Make «إضافة مباراة» save, in `admin/src/features/matches/MatchEditor.tsx:232,244-247,279,289-297` and `editor/FieldsSection.tsx:57`. Today `initial` is null on `/matches/new`, so `save()` returns silently, the unsaved guard never fires, and the body spreads the `MatchPatch` shape into a flat `MatchCreate` behind an `as` cast. Afterwards the create route seeds an initial state, builds a typed `MatchCreate` with no cast, keeps the date editable under TBD, and navigates to `/matches/:id` on `201`. Add a create test that asserts the request body and the navigation. (HIGH, per FR-031, FR-032)
- [x] A-R1-5 [US4] Show the other version in the `409` dialog, in `admin/src/features/matches/MatchEditor.tsx:201-224,307-316,385-392` and `admin/src/components/ConfirmDialog/ConflictDialog.tsx`. Today it lists the editor's own edits and stamps `new Date()` as the time of the other save. Afterwards a `409` fetches the current match, diffs it against the loaded version, and shows `meta.changed_at`. «تجاهل تعديلاتي» really discards, and «أعد تطبيق تعديلاتي» is built or its drop is recorded with the owner. Add tests for the diff content, the time shown and each action. (HIGH, per US4 scenario 8, constitution II, R24)
- [x] A-R1-6 [US4] Rebuild the team picker as a combobox keyed by team id, in `admin/src/features/matches/TeamPicker.tsx`. Today a `<datalist>` with `value={team.name}` plus `find` by name always picks the first of two same-name teams, and no logo is shown. Afterwards each option shows the logo, country and competition, and choosing it sets the id. Add a test that picks the second «الأهلي» and asserts its id in the body. (HIGH, per US4 scenario 4, FR-032)
- [x] A-R1-7 [US4] Add the satellite filter to the channel picker, in `admin/src/features/matches/ChannelPicker.tsx:14-45`. Today only `q`, `category` and `limit` are sent. Add a satellite select fed by `useListSatellites`, with «منصات بلا قمر», and a test that asserts the `satellite_id` query parameter. (HIGH, per US4 scenario 7)
- [x] A-R1-8 [US4] Keep broadcaster logos and add the presets, in `admin/src/features/matches/MatchEditor.tsx:98-102,184-196`, `editor/BroadcastSlots.tsx` and `editor/FieldsSection.tsx:115-123`. Today `fromMatch` and `buildPatch` drop `logo_asset_id`, so the server clears a slot's logo on any edit, `GET /broadcast-presets` is never called, and the stage has no presets. Add a test that a commentator-only slot edit sends the same `logo_asset_id`, and tests for both preset lists. (HIGH, per US4 scenarios 4 and 6, FR-008)
- [x] A-R1-9 [US4] Stop publishing a blank score as 0–0, in `admin/src/features/matches/MatchEditor.tsx:145-160` and `editor/StatusSection.tsx`. Today `Number('' || 0)` saves 0–0 as fact, a penalty-only edit is neither dirty nor sent, and `status.set` omits `minute` and `period`. Afterwards a manual `live` or `finished` needs an explicit score, penalties count as a change, and minute and period are carried or editable. Add payload tests for all three. (HIGH, per constitution II, FR-011, US4 scenario 5)
- [x] A-R1-10 [US4] Reuse `SourceChip` and `Field`, in `admin/src/features/matches/MatchesPage.tsx:39-49` (the local `SourceBadge`) and `editor/FieldsSection.tsx` (raw inputs, the local `LockBadge`). Today both re-implement shared components. The `DataTable` part is A-F2. Keep `MatchesPage.test.tsx` and `MatchEditor.test.tsx` green, and add a test that a locked field renders `Field`'s locked state. (HIGH, per constitution IV, FR-035)
- [x] A-R1-12 [US4] Print the UTC time in the "saved as" hint, in `admin/src/features/matches/editor/FieldsSection.tsx:27,80` (`admin/src/i18n/ar.ts:225`). Today `formatCairoTime(utc)` prints the Cairo wall time labelled UTC. Add a test: 20:00 Cairo on 31 October reads «يُحفظ 18:00 UTC». (MEDIUM, per constitution II, US4 scenario 4)
- [x] A-R1-13 [US4] Map the real source names, in `admin/src/features/matches/MatchesPage.tsx:31-36`. Today `legacy` shows `LST`, and `kickoff` and `satair_bridge` aren't sources. Go through `SourceChip` (A-R1-10) with `ysscores`, `livesoccertv`, `sporteventz`, `yallakora`, `api_football`, `manual` and `legacy`, and correct the assertion in `MatchesPage.test.tsx`. (MEDIUM, per constitution II, PB A3)
- [x] A-R1-14 [US4] Handle failures of the channel-section mutations, in `admin/src/features/matches/editor/ChannelsSection.tsx:48-61`. Today `void hideEverywhere()` and `void showAgain()` reject unhandled, with no «فشل الحفظ» and the dialog left open. Add a test with a `403` that expects the toast. (MEDIUM, per FR-033)
- [x] A-R1-15 [US4] Add A4's loading and error states, in `admin/src/features/matches/MatchEditor.tsx:335-337,345`. Today a `404`, `403` or offline load shows an empty editor with Save enabled, the loading text says «جارٍ الحفظ», and `/matches/abc` becomes `NaN`. Afterwards there is a skeleton, an error `EmptyState` via `copyForErrorCode`, and an id check. Add tests for `404` and a bad id. (MEDIUM, per FR-033)
- [x] A-R1-16 [US4] Make «احفظ وغادر» go where the editor was going, and only after the save succeeds, in `admin/src/features/matches/MatchEditor.tsx:394-408`. Today it always navigates to `/matches`, even when the save failed, and the cancel button reads «إلغاء» where `Dialogs.png` has «ابقَ». Use `blocker.proceed()`. Add tests for a sidebar link after a successful save and after a failed one. (MEDIUM, per US4 scenario 8)
- [x] A-R1-17 [US4] Match `?mock=` examples by operation template, in `admin/src/api/http.ts:237-243`. Today the literal URL (`/matches/48213`) never matches the `{match_id}` key, so T107 step 2's conflict states can't be shown. Add a test for `PATCH /admin/api/matches/{id}` with `?mock=edit_conflict`. (MEDIUM, per T107)
- [x] A-R1-18 [US4] Isolate Latin names inside Arabic strings, in `admin/src/features/matches/MatchEditor.tsx:345,387`, `admin/src/i18n/ar.ts:250` (`hideTitle`) and the other interpolations, `MatchesPage.tsx:402` and `ChannelsSection.tsx:98,116,136`. Render each name as `<bdi dir="ltr">`, or build the label from isolated parts. Add a test with «Sky Sport Italy». (MEDIUM, per constitution III)
- [x] A-R1-19 [US4] End the session only on a definitive refresh refusal, in `admin/src/api/http.ts:200-211` and `admin/src/features/auth/session.ts:77-79`. Today a network blip during refresh signs the editor out and unmounts A4 without the unsaved prompt. Retry network errors, end only on `401`/`403`, and report `refresh_invalid` as itself. Add tests for both. (MEDIUM, per FR-030, US4 scenario 1)
- [x] A-R1-20 [US4] Give `Button` the README's sizes and pressed state, in `admin/src/components/Button/Button.tsx:22-26`. Today `sm` and `xs` also render 48 px. Use 48, 40 and 32 px heights with a 48 px hit area for all three, and add the pressed state. Add tests on the rendered heights and the pressed class. (MEDIUM, per FR-035, constitution IV)
- [x] A-R1-21 [US4] Build conditional classes with `clsx` or `cva`, in `admin/src/features/matches/MatchesPage.tsx:177,195-197,260-262` and `admin/src/components/ConfirmDialog/ConfirmDialog.tsx:55-57`. The existing tests stay green. (MEDIUM, per admin/CLAUDE.md)
- [x] A-R1-22 [US4] Add the tests that T094, T097, T098 and T099 claim, in `admin/src/features/matches/*.test.tsx` and `admin/src/lib/cairoTime.test.ts`:
  - submitting a bulk removal;
  - «مخفية دائماً» with «إظهار»;
  - the `409` dialog's current version;
  - A4's «فشل الحفظ» and `beforeunload`;
  - DST on both sides in the editor;
  - the `TZ=UTC` and `TZ=Asia/Riyadh` runs, in `.github/workflows/admin.yml` (Lane B2 owns the workflow, so ask B2), or correct the claim in the test's comment.

  (MEDIUM, per constitution test-first)
- [x] A-R1-23 [US4] Write the D2 editor access in a runbook (`docs/runbooks/`, for example `admin-access.md`): `NODE_EXTRA_CA_CERTS=… pnpm dev:wg`, Caddy's CA and the WireGuard peer. Add it to `docs/runbooks/README.md`, and correct `admin/CLAUDE.md:41` (Playwright arrives on D4, not D11). No test (docs). (MEDIUM, per the root CLAUDE.md runbook rule)
- [x] A-R1-24 [US4] Show «لم يُحدد» for an unknown kickoff on A3, in `admin/src/features/matches/MatchesPage.tsx:348-350`, instead of «—». Add a test. (MEDIUM, per constitution II and the root CLAUDE.md client rules)

**Round 1 closed on 2026-10-31 in this branch** (`d02-features`), with `pnpm typecheck`, `pnpm lint`, `pnpm test` (165 tests), `pnpm build`, `./scripts/check-literals.sh` and `./scripts/check-token-copy.sh` green, and `pnpm orval && git diff --exit-code src/api/generated/` clean. Notes on three of them:

- **A-R1-1 and A-R1-3** were fixed together as asked: `getEntityEtag` is gone. A4 takes its `If-Match` from the response that filled the form (`etagOf` keeps a response's `ETag` on its envelope), and `save()` calls Orval's `patchMatch` with that header explicit, so a second save reuses the first save's new version instead of the load-time one. A bulk item sends `row.etag`, which B1's contract now carries (A-F3, ticked above); the per-row `GET`s are gone, and a `409`'s `meta.stale_ids` is shown in the bar and in the toast.
- **A-R1-20** is done: every size is a 48 px target, because the Fill/README's 40 and 32 px are fills clipped inside the 48 px element with a transparent band of border, not smaller elements (A-R2-3). No `space-10` token is needed, so the owner action below is withdrawn.
- **A-R1-5's «أعد تطبيق تعديلاتي»** is deliberately not built: the API's conflict contract sends the current `ETag`, and replaying a patch blind against a newer version is exactly what the dialog exists to prevent. «تجاهل تعديلاتي» now really drops the editor's edits, «إعادة التحميل» adopts the server's version and time, and the drop is recorded with the owner in [owner-actions](../../docs/owner-actions.md#lane-a-admin).
- **A-R1-23** added [docs/runbooks/admin-access.md](../../docs/runbooks/admin-access.md), in the runbook index and the "After setup" table.

Then re-run `/speckit-review-implementation lane=a` as round 2.

### Review fixes (round 2)

Source: [reviews/a-round-2.md](reviews/a-round-2.md). Fix in this order, then re-run `/speckit-review-implementation lane=a` as round 3. A-R2-2 waits on Lane B1's B1-R2-8 (`logo_asset_id` on `BroadcastPreset`).

- [x] A-R2-1 [US4] Carry the match version as an ordinary value that survives React Query, in `admin/src/api/http.ts:57-71,330-332` (`withEtag` stores it as a symbol-keyed property) and `admin/src/features/matches/MatchEditor.tsx:351-359,426,470`. Today `replaceEqualDeep` (`@tanstack/query-core` 5.105.0) rebuilds a changed object from `Object.keys`, so after a changed refetch `etagOf` is `null`. A save after «إعادة التحميل», or after reopening a match whose query was refetched, then sends no `If-Match` and gets `428`. Return the ETag next to the data from the query function, turn structural sharing off for this query, or keep a store keyed by match id. Add tests that refetch changed data and then save, once after «إعادة التحميل» and once after a remount, asserting the new `If-Match`. (HIGH, per FR-009, US4 scenario 8, R24)
- [x] A-R2-2 [US4] Stop sending a preset's own `id` as `logo_asset_id`, in `admin/src/features/matches/editor/BroadcastSlots.tsx:38-41`. Today `choosePreset` sets `logoAssetId: preset.id`, a `broadcast_presets` key, which the server reads as a `media_assets` id, so it refuses it or publishes an unrelated image as the broadcaster's logo. Once B1-R2-8 adds `logo_asset_id` to `BroadcastPreset`, use it; until then a preset sets the label and leaves the logo empty. Fix the test fixture (`MatchEditor.test.tsx:206-213,494-509`) so a preset's asset id differs from its id, and assert the body's `logo_asset_id`. (HIGH, per US4 scenario 6, FR-008, constitution II)
- [x] A-R2-3 [US4] Give Button `sm` and `xs` a 48 px target again, in `admin/src/components/Button/Button.tsx:26-27`. Today `h-8 border-y-8 … bg-clip-padding` and `h-6 border-y-8 …` make a 32 px and a 24 px element with a 16 px and an 8 px fill, because preflight's `border-box` puts the borders inside the height. A4's Save, the bulk bar, the dialogs and the channel buttons look broken, and none is 48 px. Use `h-12 border-y-4` (a 40 px fill) and `h-12 border-y-8` (a 32 px fill) with `border-transparent bg-clip-padding`, or a hit-area pseudo-element. Make `Button.test.tsx:27-43` assert `h-12` for every size, and correct the A-R1-20 note above and the `space-10` owner action. (HIGH, per constitution IV, the Button README, A-R1-20)
- [x] A-R2-4 [US4] Make `?mock=` match operations with path parameters, in `admin/vite.config.ts:22-35` and `admin/src/api/http.ts:262-284`. Today `__MOCK_EXAMPLE_STATUSES__` is keyed by the spec path (`PATCH /admin/api/matches/{match_id}`) and `operationTemplate` returns `PATCH /admin/api/matches/{}`, so `/matches/48213?mock=edit_conflict` sends no `Prefer` header. Key both the same way (normalise `{name}` to `{}` in `vite.config.ts`), and test the status lookup itself with the map stubbed, not only `operationTemplate`. (HIGH, per T107, A-R1-17)
- [x] A-R2-5 [US4] Offer the stage presets, in `admin/src/features/matches/editor/FieldsSection.tsx:116-121` and `admin/src/i18n/ar.ts`. Today the stage is a bare `Field`. US4 scenario 4 asks for «الجولة الأولى، ذهاب/إياب دور 16، ربع النهائي، نصف النهائي، النهائي» or free text, and A-R1-8 is ticked "tests for both preset lists". Add a datalist or combobox that keeps free text, and a test that picks a preset and checks `competition_stage` in the body. (HIGH, per US4 scenario 4, A-R1-8)
- [x] A-R2-6 [US4] Keep the editor's edits when the conflict dialog is dismissed with Escape, in `admin/src/components/ConfirmDialog/ConflictDialog.tsx:54` (`<Modal onClose={onDiscard}>`) and `admin/src/features/matches/MatchEditor.tsx:605-609`. Today Escape resets the form to the baseline. Make Escape a dismiss that keeps the state, and keep the discard on «تجاهل تعديلاتي» only. Test that Escape leaves the edits in place. (MEDIUM, per the ConfirmDialog README, US4 scenario 8)
- [x] A-R2-7 [US4] Diff every editor field in the conflict dialog, in `admin/src/features/matches/MatchEditor.tsx:275-307` (`diffStates`) and `:416-423`. Today only kickoff, competition id, stage, stadium, status mode and the channel count are compared. A score-only conflict shows an empty «اعرض التغييرات», the competition shows as `"12"` and the status as `live`, and a missing `changed_at` is replaced with the client's clock. Compare teams, scores, penalties, minute, period, broadcasts and commentators with display names, hide the toggle when nothing differs, and say the time is unknown instead of using now. Test a score-only conflict and a missing `changed_at`. (MEDIUM, per US4 scenario 8, constitution II)
- [x] A-R2-8 [US4] Keep the team picker's active option on screen, in `admin/src/features/matches/TeamPicker.tsx:52-67,103`. Today the list renders `teams.slice(0, 5)` while ↓ moves up to `teams.length - 1`, so Enter can pick a team the editor never saw, and the active option has no style. Render every result in a scrolling list (or bound `active` to what is shown), add an active style, and reset `active` on a new query. Test ↓ past the fifth row. (MEDIUM, per A-R1-6)
- [x] A-R2-9 [US4] Name the stale rows and refresh the list after a stale bulk `409`, in `admin/src/features/matches/BulkBar.tsx:38-49` and `admin/src/features/matches/queries.ts:22-30`. Today the message lists numeric ids, and only `onSuccess` invalidates, so a retry gets the same 409. Name the rows («home × away» in `<bdi>`) and invalidate the list on a stale 409. Test both. (MEDIUM, per the spec edge case on stale bulk items, FR-031)
- [x] A-R2-10 [US4] Clear the React Query cache on sign-out and on a final session expiry, in `admin/src/features/auth/session.ts:44-47,66-69`. Today only the session and token are dropped, so a second editor on the same tab sees the first editor's cached data and versions. Call `queryClient.clear()` (the provider sits inside `QueryClientProvider`), and test that a query's data is gone after sign-out. (MEDIUM, per FR-030, A-R1-34)
- [x] A-R2-12 [US4] Clear a slot's logo when its label is overtyped with another broadcaster, in `admin/src/features/matches/editor/BroadcastSlots.tsx:42-44`. Today any label that isn't a preset keeps the previous `logoAssetId`, so «Foo TV» typed over «Sky Sport Italy» publishes with Sky's logo, and `MatchEditor.test.tsx:511-522` expects that. Keep the logo only while the label is unchanged or is the preset's, show the slot's logo, and update the test. (MEDIUM, per constitution II, US4 scenario 6)
- [x] A-R2-13 [US4] Correct `docs/runbooks/admin-access.md`. Today the CA step (`:24`, `scp ubuntu@10.8.0.1:/tmp/caddy-root.crt`) copies a file nothing creates; use `private-network.md:177`'s command. The `?mock=` table uses `/matches?mock=…`, but the PATCH happens on `/matches/<id>`. "You land on A3" is wrong, because login returns to `/` with no `from`. Settle `admin/vite.config.ts:49`'s `changeOrigin: false` in the T107 walk (Caddy's only site is `https://10.8.0.1`), and record the result. No test (docs). (MEDIUM, per the root `CLAUDE.md` runbook rule, A-R1-23, A-R1-27)

Done in round 3 on `d02-features`: all twelve. Two notes. A-R2-2 uses `BroadcastPreset.logo_asset_id`
once Lane B1's B1-R2-8 lands it: a preset sends its media asset, never its own id, and the fixture now
gives the preset an id (71/72) that differs from its asset (31/82), so the mix-up cannot come back
unnoticed. A-R2-13 settles `changeOrigin: true` (Caddy matches its own site address) and records it in
the runbook and in the T107 owner action; the browser walk itself is still the owner's. Checks:
`pnpm typecheck`, `pnpm lint` (0 errors, the same 25 warnings), `pnpm test` (175 tests, +10),
`pnpm build`, `./scripts/check-literals.sh`, `./scripts/check-token-copy.sh`.

### Review fixes (round 3)

Source: [reviews/a-round-3.md](reviews/a-round-3.md). Fix it, then re-run `/speckit-review-implementation lane=a` as round 4.

- [x] A-R3-1 [US4] Handle a failed refetch when opening the conflict dialog, in `admin/src/features/matches/MatchEditor.tsx:494-499` (`openConflict`). Today it awaits `match.refetch()` and reads `refreshed.data`, but React Query's `refetch` resolves on failure and keeps the previous data, so after a `409` and a failed GET the dialog is built from the stale cache. It shows «لم يتغيّر…», «إعادة التحميل» adopts the old version, and the next save gets another `409`. When `refreshed.isError`, don't build `theirs` from the cache: show the error copy for the refetch failure (or a dialog state without the reload action) and keep the editor's edits. Add a test where the `PATCH` answers `409` and the following `GET` fails, expecting no reload offer and the edits kept. (MEDIUM, per FR-009, US4 scenario 8)

Done in round 4 on `d02-features`. `openConflict` checks `refreshed.isError` before it reads `data`: the
dialog stays closed, the banner carries the refetch's own error copy, and nothing is adopted. The
first-load guard now reads `match.isError && match.data === undefined`, so a failed background refetch
keeps the form and its unsaved edits on screen instead of replacing the editor with the error state —
which is what "the edits are kept" needs (and what A-R2-15's first point asked for). Test:
`MatchEditor.test.tsx` "offers no reload, and keeps the edits, when the refetch after a 409 fails".
Checks: `pnpm typecheck`, `pnpm lint` (0 errors, the same 25 warnings), `pnpm test` (176 tests, +1),
`pnpm build`, `./scripts/check-literals.sh`, `./scripts/check-token-copy.sh`.

## Lane M

**Story (User Story 3, P3):** As a fan, I find where today's match is on and which frequency to tune, on a real phone.

**Independent test:** install the closed-test build on a real Android phone:

- on S2, page through the week, filter to live and open a match;
- S3 lists the carriages on Nilesat and Badr first, with readouts and access badges, then the other satellites, then platforms; a commentator clip plays;
- S4 shows only matches carried on the selected satellites;
- on S5.1 open Nilesat; on S5.2 switch to entertainment and search by frequency digits;
- in airplane mode, the same screens show the cached data with its age;
- the PWA preview channel repeats S2 and S3 in a browser ([quickstart.md](quickstart.md#lane-m-app)).

**Compare against:** app boards "S2 Matches" (`madar-design/app-flutter/screens/02-matches/Matches.png`, `Matches-Light.png`, `Matches-Loading.png`), "S3" (`madar-design/app-flutter/screens/03-match-detail/Match-Prematch.png`, `Match-Live.png`, `Match-Channels.png`, `Match-NoChannels.png`), "S4 My satellites" (`madar-design/app-flutter/screens/04-satellites-frequencies/MySatellites.png`), "S5.1" (`Frequencies.png`) and "S5.2" (`Satellite.png`).

### Setup (M)

- [X] T109 [US3] Add `just_audio`, `url_launcher` and `cached_network_image` to `app/pubspec.yaml` (all in SD §5.1's list), run `flutter pub get`, and commit `app/pubspec.lock`.
- [X] T110 [US3] Add the D2 copy to `app/lib/core/l10n/app_ar.arb` (S2–S5 labels, empty states including S3's «لم تُضف القنوات الناقلة بعد» with its «تحديث» action, `StaleHint`'s age text, the commentator clip states, copy and video actions) and the D2 codes to `app/lib/core/l10n/error_copy.dart`. No Arabic literal in widgets.
- [X] T111 [P] [US3] Update `app/CLAUDE.md`: the SWR repository rule, the drift schema version and its migration test, the polling rule (only while visible and resumed), and the single audio player.

### Tests first (M): write them and see them fail

- [X] T112 [P] [US3] Write `app/test/core/format/local_day_test.dart`: matches group by the device's local date of `kickoff_at`, never `match_date` (FR-041), for Cairo, Casablanca and Riyadh offsets injected as D1's time tests do (not read from the host); TBD matches go to the «موعد لم يُحدد» group; `TimeFormat.dayWindow` gives UTC bounds for the local day, including across a DST change.
- [X] T113 [P] [US3] Write `app/test/core/db/migration_v2_test.dart`: a version-1 database with `matches` rows opens at version 2 with `match_windows` (`day` PK, `etag`, `fetched_at`) and `cached_documents` (`key` PK, `etag`, `body`, `fetched_at`) and its rows intact; local days outside today−1 … today+6 are pruned on start.
- [X] T114 [P] [US3] Write `app/test/core/network/swr_repository_test.dart` with a fake Dio adapter ([R25](research.md#r25-stale-while-revalidate-with-drift)):
  - it emits the drift copy first, then sends `If-None-Match` with the stored ETag;
  - `200` replaces the day's rows (or the document) and the ETag in one transaction and emits again;
  - `304` touches only `fetched_at` and emits nothing new;
  - offline emits the cache and an error flag, never an empty list over a cached one;
  - freshness: stale after 5 minutes for matches and match detail, after 24 hours for satellites and channels;
  - **S4 isolation:** a `200` for S4's satellite-filtered day is stored under its `cached_documents` key and leaves that day's `matches` rows and `match_windows` ETag unchanged, so S2 never shows a filtered list.
- [X] T115 [P] [US3] Write `app/test/features/match_detail/carriage_order_test.dart`: S3's groups put my satellites (the O10 default, Nilesat 7.0W and Badr by slug) first, then other satellites, then platforms; within a group, free before encrypted, then `sort_order`, then `id`; hidden links never appear (FR-043).
- [X] T116 [P] [US3] Write `app/test/features/live/live_polling_test.dart` with `fake_async`: matches revalidate every 60 s and `/v1/live` is polled every 30 s only while a live or imminent match is on a visible route and the app is `resumed`; both stop when paused or when the route is covered; live states stay in memory and are never written to drift (FR-047).
- [X] T117 [P] [US3] Write `app/test/features/match_detail/audio_player_test.dart`: one shared player, so starting a clip stops the other; `CommentatorRow` moves through idle, loading, playing and error; a failed load shows the error state.
- [X] T118 [P] [US3] Write golden tests for the five new components, in RTL, both themes, at 1.0× and 1.3×, with the D1 dark ≠ light byte check: `app/test/goldens/commentator_row_test.dart` (four states), `filter_chip_row_test.dart` (with a live count), `search_field_test.dart` (empty, typing, clear), `segmented_test.dart` and `stale_hint_test.dart`. Each follows its README in `madar-design/design-system/components/`.
- [X] T119 [P] [US3] Write `app/test/features/matches/matches_page_test.dart` (S2): the date strip with RTL paging and «اليوم»; the chips «الكل» and «مباشر ‹count›»; competition groups by admin priority, then earliest kickoff; the channel line; every `StatusBlock` variant, with no score or minute for an estimated live state and no cached state shown as live (SC-008); the TBD group; pull to refresh; the skeleton; the empty day and empty live states; `StaleHint` past 5 minutes.
- [X] T120 [P] [US3] Write `app/test/features/match_detail/match_detail_page_test.dart` (S3): the hero; the three-part "where to watch" with its toolbar; `CarriageRow` collapsed with the readout, and expanded with the details, copy-frequency (to `Clipboard`) and reception-video (through `url_launcher`); the manual broadcaster cards; the stadium, Egyptian broadcaster and match-level commentator cards only with data; the no-channels state, «لم تُضف القنوات الناقلة بعد» with a «تحديث» button that revalidates the match (constitution I: a next action; the «تابع المباراة» follow action replaces it on D3); 171 links built lazily, with the back-to-top button after two screen heights.
- [X] T121 [P] [US3] Write `app/test/features/my_satellites/my_satellites_page_test.dart` (S4: satellite chips, only matches carried on them, grouped by competition with finished last, both empty states) and `app/test/features/frequencies/frequencies_test.dart` (S5.1: search, my satellites pinned first; S5.2: the header, alignment aids, reception video, category switch with swipe, search by name or frequency digits such as `11843`, the readout always visible with the access badge, expansion, and the empty state).
- [X] T122 [P] [US3] Write `app/tool/test_all_zones.sh`: run `flutter test` under `TZ=UTC`, then under `TZ=Africa/Cairo`, and exit non-zero if either fails or `git status --porcelain test/goldens` shows a change. T133 runs it. CI keeps its single run (`app.yml` is Lane B2's), as on D1.

### Implementation (M)

- [X] T123 [US3] Bump `app/lib/core/db/app_database.dart` to `schemaVersion 2` with the `match_windows` and `cached_documents` tables, the v1 → v2 migration step and the start-up prune, then run `dart run build_runner build --delete-conflicting-outputs`. T113 passes.
- [X] T124 [US3] Implement `app/lib/core/network/swr_repository.dart`, the stale-while-revalidate base on D1's `EtagInterceptor`, with a typed-rows path for matches by local day and a document path for `cached_documents`. T114 passes.
- [X] T125 [P] [US3] Build the new components in `app/lib/design/components/`: `commentator_row.dart` (`CommentatorRow`), `filter_chip_row.dart` (`FilterChipRow`), `search_field.dart` (`SearchField`), `segmented.dart` (`Segmented`) and `stale_hint.dart` (`StaleHint`), each once under its INDEX name, `const` constructors, tokens only, Western digits, LTR islands for Latin names and frequencies, and one Arabic screen-reader label per composite row. T118 passes.
- [X] T126 [US3] Implement `app/lib/features/my_satellites/data/my_satellites_provider.dart`: the O10 default resolved from `/v1/satellites` by the Nilesat 7.0W and Badr slugs until D3 stores the user's choice.
- [X] T127 [US3] Build S2 in `app/lib/features/matches/` (the matches repository on T124, providers, and `matches_page.dart` with `PageView` day paging inside the RTL `Directionality`), replacing D1's direct `/v1/matches` call. T112 and T119 pass.
- [X] T128 [US3] Implement `app/lib/features/live/live_poller.dart`: the 60 s and 30 s timers in a Riverpod provider, gated by route visibility and `AppLifecycleListener`, merging `/v1/live` states into the rows in memory. T116 passes.
- [X] T129 [US3] Build S3 in `app/lib/features/match_detail/`: the repository on `cached_documents`, the `CustomScrollView` with one `SliverList.builder` per open group, the shared `just_audio` player provider, copy and video actions, the cards, and the no-channels state with «تحديث». T115, T117 and T120 pass.
- [X] T130 [US3] Build S4 in `app/lib/features/my_satellites/` from T126 and the document path of T124: request `/v1/matches?from&to&satellite_ids=<selected ids>` for the local day and cache it under `matches:<day>:sat:<sorted ids>` in `cached_documents`. Never filter S2's cached rows locally (a row's channel line holds at most 2 carriages), and never write the filtered list through `matches` or `match_windows`. Its part of T121 and T114's S4 isolation case pass.
- [X] T131 [US3] Build S5.1 and S5.2 in `app/lib/features/frequencies/` on `cached_documents` (`satellites`, `satellite:<id>:channels`). Its part of T121 passes.
- [X] T132 [US3] Wire the routes in `app/lib/core/router/app_router.dart` (`/`, `/match/:id`, `/my-satellites`, `/satellites`, `/satellites/:id`) and the bottom navigation, replacing the D1 stubs; the match detail route stays pushed so it has a back arrow.

### Validation (M)

- [X] T133 [US3] Validate in `app/`: `flutter analyze`, `./tool/check_token_copy.sh`, `./tool/check_literals.sh`, and `./tool/test_all_zones.sh` in the pinned golden image (all goldens pass, no changes between zones).
- [X] T134 [US3] Write `docs/runbooks/store-releases.md` (FR-055): tagging `app-vX.Y.Z`, the `app-release.yml` artifact, enrolling in Play App Signing, the closed-track upload by hand, the testers list, backing up the upload keystore, and that the automated upload waits for the Play service account. Add it to `docs/runbooks/README.md`'s setup order and "After setup" table.
- [ ] T135 [US3] After the merge, the owner tags `app-v0.2.0`; confirm `app-release.yml` produces a signed `prod` AAB with `versionCode` from the run number, and that the owner uploads it to the closed track and a tester installs it (SC-009).
- [ ] T136 [US3] Walk the device steps of the [quickstart Lane M](quickstart.md#lane-m-app) on the closed-test build: S2 week paging, live filter and pull to refresh; S3 with 130 or more channels showing its answer in under 1 s and scrolling smoothly, a clip, copying a frequency, the reception video; S4 only Nilesat or Badr matches; S5.2 category switch and `11843` search; airplane mode showing cached copies with their age (SC-006 to SC-008). Take screenshots of each screen in both themes, compare them with the PNGs listed above, and attach them to the PR.
- [ ] T137 [US3] After the owner's `CORS_ORIGINS` change, open the PWA preview channel (`https://madar-sat--master-p2bbuj53.web.app`) and confirm S2 and S3 load data from VPS-1, and that DevTools → Network shows no request to `fonts.gstatic.com`, `fonts.googleapis.com` or a CanvasKit CDN.
- [X] T138 [US3] Add the D2 Lane M items to `docs/owner-actions.md` (before merge: the `CORS_ORIGINS` change, the keystore backup; after merge: tag `app-v0.2.0`, Play App Signing, the closed-track upload, testers), each with its task ID and runbook link, and update the "Open now" table.

### Still open in Lane M

T133 is the one open task that is not the owner's. Its three steps were run by hand because the shell allowlist blocks `./tool/test_all_zones.sh` (`lean-ctx allow test_all_zones.sh` lets it run): `flutter analyze` reports no issues; `tool/check_literals.sh` and `tool/check_token_copy.sh` pass; `flutter test` is 436 tests, all green under `TZ=UTC` and under `TZ=Africa/Cairo`, with `git status test/goldens` unchanged between the runs. T135–T137 are the owner's release and device checks ([owner-actions.md](../../docs/owner-actions.md#lane-m-app)). Nothing here was run on a phone, in a browser, or against VPS-1.

Where the build departs from this file's text, on purpose:

- **S3** has no pre-kickoff countdown boxes, bell or share button, and not the «حدد أقمارك» chip (D3 adds the follow action and the user's own satellites; `orderCarriages` already takes an `isMine` predicate). Its no-channels body reads «ستظهر القنوات والترددات هنا فور إضافتها.» instead of the product doc's «تابع المباراة…», which points at a follow action that does not exist before D3. Groups are full-bleed header bars with dividers, not rounded cards: the pinned Flutter has no sliver clip.
- **T115:** the generated model has no `sort_order`; the server already returns each group sorted by it and then by id, so the list's own order stands for both.
- **S4** shows today only, with no date strip, live chip or «تعديل» chip (FR-044 lists none); the satellite selection lasts for the session until D3 stores it.
- **S2's** date strip shows 7 cells, not 8, to fit 360 dp; the eighth day pages in when today+6 is selected.
- **`SwrRepository`:** a `304` also re-emits the cached data with the confirmed time, so `StaleHint` does not call a copy the server just confirmed stale. R25 says a `304` "touches only `fetched_at`", which it still does; FR-046's "a `304` changes nothing" is read as "changes no data".
- **`StaleHint`** has one rule on every screen, `SwrSnapshot.staleAge`: the copy is older than its freshness target (FR-046).
- **`MatchRow`:** the `+N` extra-channel count is now an LTR island (it drew `13+` in RTL), so the four `match_row` goldens changed. `CountBadge` has the same RTL behaviour and was left alone; only the gallery and its golden show a signed `+171`.

From the security review (no CRITICAL or HIGH findings). Fixed in this lane: a clip address must be `https` before it reaches the player; `httpsUri` also refuses userinfo, a port outside 1–65535 and an address over 2048 characters; `UrlLauncherOpener` re-checks `https` itself and answers `false` when the platform throws; route ids must match `[1-9]\d{0,9}` (`int.tryParse` took `-5`, `+5` and `0x10`); and `watchDay` lost its unused `my_satellite_ids` parameter, which would have shared one cached ETag between different selections. Not fixed, on purpose, for D3:

- **Image hosts.** Logos and commentator photos from the API go straight to `NetworkImage` / `CachedNetworkImageProvider` at eight sites. Android blocks cleartext and the web blocks mixed content, so the open risk is a third-party host seeing the user's IP. The fix is one shared helper that also pins the media host, and that host comes from Remote Config on D3 (`AppConfig.mediaBaseUrl` is only the bundled default), so it belongs there.
- **Cache growth.** `cached_documents` bodies have no size cap, and pruning runs only when the database opens, so a PWA session that stays open for days never prunes. Keys are bounded by what one person opens, and rows by the 14-day retention. A cap, pruning after writes, and checking that a response's `id` is the one asked for are the follow-up.

From the Flutter review (no CRITICAL findings). Fixed in this lane, each with a test that failed first except the two rebuild-scope changes and the two mounted guards, which change no behaviour a test can see:

- **`CarriageRow`** announced itself as a button but gave the merged node no tap action, and `excludeSemantics` hid the expanded copy-frequency and reception-video actions, so a screen-reader user could neither expand a row nor reach its actions. The node now carries `onTap` and the actions sit outside it; the goldens are byte-identical.
- **`watchDay`** read the cached day outside its `try`, so rows the models could no longer read failed every open and the day stayed broken until it aged out. An unreadable day now counts as uncached: no ETag is sent and the answer replaces it.
- **Live states** had no expiry, so a score could outlive its match, indefinitely when `/v1/live` stopped answering. They now expire `PollIntervals.liveStateTtl` (60 s, two poll intervals) after the last answer; the row falls back to its own status or the quiet estimated «مباشر».
- **S2** kept the day it opened on as «اليوم» after midnight; on resume a new date now opens the new today.
- **S3** retries the satellite catalogue on its next poll when its first load failed, so reception links no longer stay off for a session that started offline.
- **S4 and S5.1** check `mounted` before invalidating after a pull to refresh, as S2 already did; **`CommentatorRow`** and **S3** watch only their own clip state and live state, so a progress tick or another match's update no longer rebuilds them.

Not fixed, on purpose:

- **Touch targets.** `Segmented` is 36 dp and the dense `SearchField` 40 dp, below the 48 dp minimum. Both follow the design package's component specs, so it is a design decision: change the design, or keep the look and grow the hit area.
- **`MatchGroupSection`** builds one competition's rows in a `Column` inside the lazy list, so a day with a 30–60 match group builds them all on the first frame. Not measured; S4 shows the flat alternative.
- **Overlapping revalidations** of one day (a poll and a pull to refresh) can land out of order; the next poll corrects it.
- **Test seam.** `groupDay`, `MadarTime.kickoff` and S3's hero read the host zone while the database takes an injected `offsetAt`. Production uses the host zone for both; a test must set `TZ`, which is what `test_all_zones.sh` is for.

### Review fixes (round 1)

Source: [reviews/m-round-1.md](reviews/m-round-1.md). Fix in this order, regenerate the goldens only in the pinned image, then re-run `/speckit-review-implementation lane=m` as round 2. If lean-ctx blocks the T133 scripts, ask the owner to run `lean-ctx allow check_token_copy.sh`, `lean-ctx allow check_literals.sh` and `lean-ctx allow test_all_zones.sh`.

- [x] M-R1-1 [US3] Take live states only from `/v1/live`, in `app/lib/features/live/live_merge.dart:18-41`, `app/lib/features/matches/domain/matches_day.dart:13,110` and `app/lib/features/match_detail/domain/match_detail_live.dart:34-42`. Today a cached row whose stored status is in play, with no current live state, becomes `Status.live, estimated: true`. Offline, hours after the match ended, S2, S3 and S4 still show «مباشر», and it counts in «مباشر ‹n›» and the live filter. Afterwards such a row gets a non-live treatment (its kickoff time and the StaleHint age), isn't counted as live, and doesn't pass the live filter. Rewrite `app/test/features/matches/matches_page_test.dart:625-644`, which today asserts «مباشر» under a title that says the opposite, to fail before the fix, and add the same case for S3 and S4. (CRITICAL, per constitution II, FR-046, SC-008, R25) — **Done.** A cached in-play row is now shown by its kickoff time, with no «مباشر», no count and no live-filter hit (`withLiveState`, `detailWithLiveState`); S2, S3 and S4 poll `/v1/live` from the **cached** rows, before the merge. Tests rewritten in `matches_page_test`, `match_detail_page_test`, `my_satellites_page_test`, `live_merge_test`, `match_detail_live_test`.
- [x] M-R1-2 [US3] Open drift on the web, in `app/lib/core/db/app_database.dart:115`. Today `driftDatabase(name: 'madar')` passes no `web:` options, so `drift_flutter` throws `ArgumentError` and every PWA screen shows «تعذّر تحميل البيانات». Pass `DriftWebOptions` with the `sqlite3.wasm` and drift worker URIs, ship both in `app/web/` (no CDN), and record their source and version in `app/CLAUDE.md`. Add a check that fails before the fix: a `flutter test --platform chrome` test that opens the database, or a `pwa.yml`/`app.yml` step that asserts both assets exist in `build/web` (B2 owns the workflows, so ask B2 for the step). (HIGH, per FR-049, SC-009, constitution VIII) — **Done.** `AppDatabase.open()` passes `DriftWebOptions`; `web/sqlite3.wasm` and `web/drift_worker.js` ship from drift 2.35.3 (recorded in `app/CLAUDE.md`); `test/core/db/web_assets_test.dart` and `tool/check_web_assets.sh`. The `app.yml` step is Lane B2's (owner-actions).
- [x] M-R1-3 [US3] Issue the cached requests through the generated client, in `app/lib/core/network/swr_repository.dart:108-218` and the six literal `/v1` paths (`swr_repository.dart:114`, `match_detail_providers.dart:20`, `satellite_channels_provider.dart:23`, `my_satellites_provider.dart:29`, `satellite_matches_repository.dart:57-62`, `frequencies_page.dart:177`). Today they are raw `_dio.get` calls with hand-typed paths and query names and a hand-parsed envelope. The owner decided on 2026-10-31 to use the generated client, with no recorded exception; research.md R25 "Requests" now says so. Set `original_http_response: true` in `app/swagger_parser.yaml` (swagger_parser 1.45.0 supports it), and regenerate with `dart run swagger_parser && dart run build_runner build -d`. Call the generated `MadarApi` methods and read the status and `ETag` from `HttpResponse<T>`. Keep `If-None-Match` in the existing ETag interceptor, and parse errors with the generated `ErrorEnvelope`. Remove the six literal paths and the hand-written `_unwrap`. Update the live poll and D1's callers for the new return type. Add a test that fails when a generated operation's path changes. (HIGH, per constitution VI) — **Done.** `original_http_response: true`, regenerated client; `SwrRepository` calls the generated operations and reads status/ETag from `HttpResponse`; the six literal paths and `_unwrap` are gone. `test/core/network/generated_client_test.dart` fails on a hand-written `/v1` path or raw Dio call.
- [x] M-R1-4 [US3] Show the expanded carriage row's satellite correctly, in `app/lib/design/components/carriage_row.dart:210-216,242-255`. Today it prints «7.0- · نايل سات» (a signed number, reordered by bidi, with no E/W), never shows `nameEn` or `package`, and labels the category «التفاصيل». Build the row from isolated parts: the Arabic name, `nameEn` as an LTR island, and `OrbitalPosition.label` as an LTR island. Add the «الوصول» row (access · provider · package) and the «الفئة» label. Assert all of them in `app/test/features/match_detail/match_detail_page_test.dart` and the S5.2 test, which fail before the fix, and regenerate `carriage_row_*` goldens in the pinned image. (HIGH, per US3 scenario 5, FR-048, constitution III) — **Done.** The expanded row builds the satellite from isolated parts (nameAr, nameEn, `OrbitalPosition.label`), adds «الوصول» (access · provider · package) and «الفئة», and the four `carriage_row` goldens were regenerated with the pinned 3.47.7.
- [x] M-R1-5 [US3] Title S3's mine part honestly while no satellites are chosen, in `app/lib/features/match_detail/presentation/where_to_watch_slivers.dart:82-100`. Today the defaults are titled «على أقمارك», and there is no «حدد أقمارك». Afterwards the title reads «على نايل سات وبدر», built from the default set's names, until the user chooses. The «حدد أقمارك» chip is deferred to D3 with its picker. The owner decided this on 2026-10-31, and it is recorded in `plan.md` Complexity Tracking and research.md R26. Add the ARB string, and tests for the default title and for a chosen set (which keeps «على أقمارك»). (HIGH, per constitution I, US3 scenario 4) — **Done.** S3 titles the default set «على نايل سات وبدر» from the catalogue (`mySatelliteNamesProvider`), falling back to the bundled copy before it loads; «على أقمارك» returns once `chosenSatelliteIdsProvider` is set (D3). Tests for both states.
- [x] M-R1-6 [US3] Draw the live chip's dot only while a match is live, in `app/lib/features/matches/presentation/matches_page.dart:145-150` (`isLive: liveCount > 0`). Today it is red at zero. Add a page test: no `LiveDot` at 0, one at 1 or more. (HIGH, per US3 scenario 1, constitution IV) — **Done.** `isLive: (view?.liveCount ?? 0) > 0`; page tests assert no `LiveDot` at zero and one at one or more.
- [x] M-R1-7 [US3] Grow the hit areas of `Segmented` and the dense `SearchField` to `MadarLayout.touchMin`, in `app/lib/design/components/segmented.dart:79` and `search_field.dart:85`, keeping the visible 36 and 40 dp. Today both are below 48 dp (the constitution's MUST; the FormControls README itself says 48 px). Use the `CommentatorRow` 40-in-48 pattern, and add tests that the tap target is at least 48 × 48 dp. Goldens shouldn't change; if they do, regenerate in the pinned image. (HIGH, per constitution IV) — **Done.** `Segmented` draws 36 inside a 48 dp target and the dense `SearchField` draws 40 inside 48 (a tap focuses the field); tests assert both targets.
- [x] M-R1-8 [US3] Add the pre-kickoff countdown to the S3 hero, in `app/lib/features/match_detail/presentation/match_hero.dart:54-81,109-114`. Today nothing is shown outside `StatusBlock`'s 60-minute window. Add a one-line text countdown («تبدأ بعد …») from the existing time helpers, with a test three hours before kickoff. (MEDIUM, per US3 scenario 4) — **Done.** The hero shows «تبدأ بعد …» (minutes/hours/days) when the kickoff is more than an hour away, and reads it in its semantics label; tested three hours out.
- [x] M-R1-9 [US3] Change `commentatorPlaying` to «جاري التشغيل...», in `app/lib/core/l10n/app_ar.arb:114`, and the label in `app/test/goldens/commentator_row_test.dart:54`. Regenerate l10n. (MEDIUM, per US3 scenario 6) — **Done.** `commentatorPlaying` is «جاري التشغيل...»; the ARB, the golden test and `audio_player_test` updated.
- [x] M-R1-10 [US3] Show an S2 group's stage only when every match in it shares that stage, in `app/lib/features/matches/domain/matches_day.dart:52`, as S4 does (`my_satellites/domain/competition_groups.dart:44-48`). Today the first match's stage labels the group. Add a mixed-stage test. (MEDIUM, per constitution II) — **Done.** `groupDay` computes the group's stage like S4 (only when every match shares it); mixed-stage test added.
- [x] M-R1-11 [US3] Keep the `FrequencyReadout` in the expanded row, with tap-to-copy and its copied state, in `app/lib/design/components/carriage_row.dart:104,168-182`. Today it is hidden and replaced by plain text, and copying shows a default `SnackBar`. Reverse `match_detail_page_test.dart:533`. (MEDIUM, per FR-042, the FrequencyReadout and CarriageRow READMEs) — **Done.** The `FrequencyReadout` stays on the open row, taps copy and outlines itself in `success` for two seconds; `match_detail_page_test` and `carriage_row_test` assert it.
- [x] M-R1-12 [US3] Hide «تابع» until follows exist, in `app/lib/design/components/carriage_row.dart:157`. Today it is drawn active and does nothing. Add a test that it is absent when `onFollow` is null. (MEDIUM, per constitution I and II) — **Done.** «تابع» is drawn only when `onFollow` is given; a test covers both.
- [x] M-R1-13 [US3] Remove `data/`, drift and Dio imports from `domain/`, in `app/lib/features/match_detail/domain/carriage_order.dart:5` and `app/lib/features/matches/domain/matches_day.dart:1,5`. Move the default slugs, kept-days window and freshness constants into `domain/` or a neutral core file, and pass them in. Add an import-rule test (a script or `dart analyze` custom lint) that fails on a `domain/` → `data/` import. (MEDIUM, per constitution VIII) — **Done.** `MySatellites` moved to `features/my_satellites/domain/`, the kept-days window to `core/format/retention.dart` and `Freshness`/`DocumentKeys`/`SwrSnapshot` to `core/network/swr_snapshot.dart` (with `ApiFailure` pure and its Dio mapping in `dio_failure.dart`). `test/architecture/domain_imports_test.dart` fails on a `domain/` → data/drift/Dio/Riverpod import.
- [x] M-R1-14 [US3] Move refresh and poll policy out of widgets, in `app/lib/features/matches/presentation/day_page.dart:119-129`, `my_satellites_page.dart:217-226`, `frequencies_page.dart:170-187` (it re-declares its key, path and parser) and `app/lib/features/live/live_poller.dart:97-159`. Expose `refresh()` on the providers, and make the poll policy a notifier that takes visibility and lifecycle as inputs, as T128 says. Record in `tasks.md` whatever stays widget-based on purpose. Add provider-level tests for refresh and the poll policy. (MEDIUM, per constitution VIII, T128) — **Done.** Refresh and poll policy live in the providers: `revalidate()` (one conditional request) and `refresh()` (the whole cycle, waited on) on every data notifier, and `livePollingProvider` runs the timers, fed visibility, lifecycle and whether live matters by `LivePollingScope`. Widget-side on purpose: the `PageController` and scroll position, the `TickerMode`/`AppLifecycleListener` signal itself, and the search `TextEditingController`. `matches_providers_test` and the poll-policy test in `live_polling_test` are provider-level.
- [x] M-R1-15 [US3] Stop the SWR layer masking every error, in `app/lib/core/network/swr_repository.dart:131,175,225`. Today any throw, including a `TypeError` from contract drift, becomes `const ApiFailure()` with no log, and a storage failure after a good `200` discards the body. Catch `DioException` and `ApiFailure` explicitly, log the rest through `dart:developer`, and emit the fetched data when the write fails. Add tests for a bad body and a failing write. (MEDIUM, per the error-handling rule in 4.E) — **Done.** `DioException`/`ApiFailure` are mapped; any other throw is logged through `dart:developer` and the fetched data still stands, including when the drift write fails (`swr_repository_test`, "a storage failure after a good 200").
- [x] M-R1-16 [US3] Write every provider in `app/lib/`, D1's included, with `@riverpod` and `riverpod_generator`, and run `dart run build_runner build -d`. The owner decided on 2026-10-31 to keep the constitution's "Riverpod (+ generator)"; research.md R26 "Providers" now says so. Today about 25 providers are hand-written while the generator sits unused (`app/pubspec.yaml:18,38`). Do it together with M-R1-14, which rewrites the same providers, so the app never mixes the two styles. Keep `flutter test` green, with overrides moved to the generated providers. Add a check that fails on a hand-written `Provider(`, `StateNotifierProvider(`, `NotifierProvider(` or `FutureProvider(` in `lib/`: a small `app/tool/` script that `app.yml` runs. Lane B2 owns the workflow, so ask B2 for the CI step. (MEDIUM, per constitution VIII) — **Done.** Every provider in `lib/` (D1's included) is `@riverpod`; `tool/check_providers.sh` fails on a hand-written one. The `app.yml` step is Lane B2's (owner-actions).
- [x] M-R1-17 [US3] Pump S2 and S3 in the light theme and at 1.3×, in `app/test/features/matches/matches_page_test.dart` and `app/test/features/match_detail/match_detail_page_test.dart`. Today both run dark only at 1.0×. Assert no overflow and the main texts. (MEDIUM, per AGENTS.md, FR-048) — **Done.** S2 and S3 are pumped in the light theme at 1.3× as well as dark, asserting no overflow; both harnesses take `brightness` and `textScale`.

### Review fixes (round 2)

Source: [reviews/m-round-2.md](reviews/m-round-2.md). Fix in this order, regenerate the goldens only in the pinned image, then re-run `/speckit-review-implementation lane=m` as round 3. Run the tests with `rtest` on the test box. M-R2-7 settles which CI step Lane B2 still adds (B2-R2-13).

- [x] M-R2-1 [US3] Render the expanded carriage row's tuning line as an LTR island, in `app/lib/design/components/carriage_row.dart:285` (`Text('${MadarDigits.plain(frequency.mhz)} MHz')`). Today a number and a Latin unit in a plain `Text` inside the RTL row read «MHz 11843», and the regenerated `carriage_row_*` goldens accepted it (the old ones drew «11843 MHz», like the `Match-Channels` board). Use `LtrIsland` as `:276-278` does. Assert that the text's `Directionality` is LTR in `carriage_row_test.dart`, `match_detail_page_test.dart:591` and `frequencies_test.dart:653,660` (their `find.text('11977 MHz')` passes in either order), and regenerate the goldens. (HIGH, per the root `CLAUDE.md` LTR-island rule, FR-048) — **Done.** The line is an `LtrIsland`, and `carriage_row_test`, `match_detail_page_test` and `frequencies_test` read `Directionality.of` on the text itself, so `find.text` passing in either order is no longer enough. The four `carriage_row` goldens were regenerated on the Ubuntu 24.04 test box with the pinned 3.47.7 and now draw «11843 MHz».
- [x] M-R2-2 [US3] Check `ref.mounted` after the drain in every `refresh()`, in `app/lib/features/matches/data/matches_providers.dart:33-41`, `features/my_satellites/data/satellite_matches_provider.dart:57-67`, `my_satellites_provider.dart:24-31`, `features/match_detail/data/match_detail_providers.dart:31-40` and `features/frequencies/data/satellite_channels_provider.dart:21-30`. Today each auto-dispose notifier awaits a whole network cycle, then calls `ref.invalidateSelf()`, which throws `UnmountedRefException` (Riverpod 3.4.3) when the user left the screen meanwhile, so `RefreshIndicator`'s future fails uncaught. Add `if (!ref.mounted) return;` before `invalidateSelf()`, as `LivePolling._fetchLive` does. Add a provider test that disposes the container during the drain and expects no error. (HIGH, per the async rule, M-R1-14) — **Done.** All five `refresh()` methods return early when the provider is gone. `matches_providers_test` starts a refresh, disposes the container mid-cycle and expects the future to complete; without the guard it fails with `UnmountedRefException`.
- [x] M-R2-3 [US3] Give each `LivePollingScope` its own polling state, in `app/lib/features/live/live_poller.dart:84-131,198-219`. Today S2, S3 and S4 drive one auto-dispose `LivePolling`, and `sync` overwrites all four fields (`_onRevalidate` too). With S3 pushed over S2, S2's `TickerMode` turns off when the transition ends, after S3 started its timers, so S2's `visible: false` cancels S3's `/v1/live` poll and revalidation and installs S2's callback. A live match on S3 then falls back to its kickoff time when the live state's 60 s TTL ends. Make the controller per scope (a family keyed by the scope, or one the scope owns), or have a hidden scope release its claim instead of stopping the timers. Add a widget test with S3 pushed over S2 and the transition settled, asserting S3's live and revalidate timers still fire. (HIGH, per FR-047, US3 scenario 12, R26) — **Done.** The one policy keeps a **claim per scope** (`sync(scope, …)`, `release(scope)` in the scope's `dispose`), and only the claims of visible, resumed screens drive the timers, so covering S2 stops S2's claim alone and one `/v1/live` per tick still serves every screen. `live_polling_test` pushes S3 over S2, settles the transition, and asserts S3's live poll and revalidation still fire while S2's callback stays silent.
- [x] M-R2-4 [US3] Read error codes with the generated `ErrorEnvelope`, in `app/lib/core/network/dio_failure.dart:19,26-33` (`errorCodeOf` walks `body['error']['code']` by hand). The owner's M-R1-3 decision (research.md R25) says errors are read with the generated model, and nothing in `lib/` uses it today. Parse with `ErrorEnvelope.fromJson` behind a type check, keep `null` for a non-envelope body, and test an error body read through the generated model. (MEDIUM, per R25, constitution VI) — **Done.** `errorCodeOf` parses the body with `ErrorEnvelope.fromJson` behind a type check and answers null for anything the model cannot read; `test/core/network/dio_failure_test.dart` covers an envelope, a proxy page, a partial body and a transport failure.
- [x] M-R2-5 [US3] Send SWR requests through the app's Dio and its interceptors, in `app/lib/core/network/swr_repository.dart:274-294` (`_requestDio` builds a new `Dio` with copied options and only `_ConditionalEtag`). Today anything added to `dioProvider` later (the D3 `Authorization: Device` token, logging) never reaches the cached reads, and it is a second ETag interceptor next to `EtagInterceptor`. Carry the conditional `If-None-Match` through `RequestOptions.extra` on the app's Dio, read by one interceptor. Test that an interceptor added to `dioProvider` sees an SWR request. (MEDIUM, per R25, the root `CLAUDE.md` auth contract) — **Done.** `_requestDio` copies the app Dio's interceptors at request time, minus `EtagInterceptor` (the ETag comes from drift), and adds the one `_ConditionalEtag`; the generated client offers no per-request `extra`, so a copied view is how a later D3 token or log reaches the cached reads. A `304` an interceptor resolved into a response now also reads as unchanged. Tests: an interceptor added to the Dio sees a cached read; `EtagInterceptor`'s memory never decides what one sends.
- [x] M-R2-6 [US3] Make the domain-imports test catch relative imports, in `app/test/architecture/domain_imports_test.dart:11-14`. Today it matches only `/data/` and a few `package:` prefixes, so `matches_day.dart`'s old `../../../core/db/app_database.dart` and `../../../core/network/swr_repository.dart` imports would pass. Also forbid `core/db/`, `core/network/swr_repository`, `core/network/dio_`, `/presentation/`, `package:flutter/` and `dart:ui`, and match `export` and double-quoted forms. Prove each with a fixture string. (MEDIUM, per M-R1-13, constitution VIII) — **Done.** The patterns now run over every `import` and `export` clause, either quote style, relative or `package:`, and forbid `core/db/`, `core/network/swr_repository`, `core/network/dio_`, `/presentation/`, `/data/`, `package:flutter/`, `dart:ui` and the plugin packages; a fixture test proves each kind, including round 1's two relative imports.
- [x] M-R2-7 [US3] Replace `app/tool/check_providers.sh:11` with a `flutter test` file under `app/test/architecture/`. Today its pattern misses `StateNotifierProvider<A, B>(`, `ChangeNotifierProvider(`, a name without the `Provider` suffix and a two-line declaration, and nothing runs it. Scan `lib/**` outside `*.g.dart` for those constructors, and prove each miss with a fixture string. Tell Lane B2 that only the web-assets step is still needed in CI (B2-R2-13). (MEDIUM, per M-R1-16, constitution VIII) — **Done.** `test/architecture/providers_test.dart` looks for the constructor call, not the declaration, so all four misses are caught and each has a fixture; `tool/check_providers.sh` is deleted and the check runs in `flutter test`, so Lane B2 needs the web-assets step only (its round-2 change already adds that one, and says the provider check stays out of CI).
- [x] M-R2-8 [US3] Show the satellite's orbital position once, in `app/lib/design/components/carriage_row.dart:270-280`. Today `nameEn` already carries it ("Nilesat 7.0W"), so the row reads «نايل سات  Nilesat 7.0W  7.0W», and at 1.3× the second one wraps. `OrbitalPosition.label` also drops the degree sign that the satellite header's `OrbitalPosition.degrees` shows. Drop the separate position, as the board does (or show it with `degrees()` only when `nameEn` lacks it), and update `carriage_row_test.dart:72-84`, `match_detail_page_test.dart:587-597` and the goldens. (MEDIUM, per the `Match-Channels` board, M-R1-4) — **Done.** `_extraPosition` adds `degrees()` («13.0°E») only when `nameEn` does not already carry the position, so Nilesat's row names it once; a test pads a satellite named "Hotbird" with a `13.0°E` island.
- [x] M-R2-9 [US3] Keep the `Segmented` track at 48 dp, in `app/lib/design/components/segmented.dart:30-31,80-84`. Today the 4 dp track padding wraps 48 dp segments, so the visible `surface2` track grew from 44 to 56 dp (`segmented_*` goldens). M-R1-7 asked to keep the visible size. Drop the track padding and inset the 36 dp pill inside each 48 dp segment, then regenerate the goldens, or record the new size as accepted with the owner. (MEDIUM, per M-R1-7, the FormControls board) — **Done.** The track keeps only the board's horizontal inset, so its height is the 48 dp segment and the 36 dp pill is centred inside it; the `segmented_*` goldens were regenerated on the pinned 3.47.7 and show 6 dp of track above and below the pill.
- [x] M-R2-10 [US3] Test the access row's provider and package and the countdown's null cases, in `app/test/fixtures/sample_models.dart:117-118` (`provider: null, package: null`), `test/goldens/carriage_row_test.dart`, `test/features/frequencies/frequencies_test.dart:644-662` and `test/features/match_detail/match_detail_page_test.dart`. Today no golden or S5.2 assertion has a provider or a package, so `carriage_row.dart:298-312` can be reverted unnoticed. The countdown's four null cases (`match_hero.dart:133-143`) are untested: inside the hour, after kickoff, TBD and not scheduled. Add a carriage with both to the expanded-row test, the golden and S5.2, and one test per countdown case. (MEDIUM, per M-R1-4, M-R1-8) — **Done.** `sampleCarriage`, `sampleCarriageEntry` and `channelEntry` take a `provider` and a `package`; the expanded-row test, the golden and S5.2 assert both (the Latin package as an LTR island). `test/features/match_detail/match_hero_test.dart` covers the countdown: three hours out, inside the hour, after kickoff, `time_tbd`, no kickoff, and a match no longer scheduled.

### Review fixes (round 3)

Source: [reviews/m-round-3.md](reviews/m-round-3.md). Fix in this order, run the tests with `rtest` on the test box, then re-run `/speckit-review-implementation lane=m` as round 4.

- [x] M-R3-1 [US3] Catch the modifier forms in the providers guard, in `app/test/architecture/providers_test.dart:15-21`. Today the pattern needs `<` or `(` right after the class name, so `FutureProvider.autoDispose((ref) …)`, `Provider.family<…>(…)` and `NotifierProvider.autoDispose<A, B>(…)` (the usual hand-written forms on `flutter_riverpod` 3) pass. Allow `.autoDispose` and `.family` (in either order) before `<`/`(`, add one offender fixture per form, and narrow the `path.contains('generated')` skip to `lib/core/network/generated/`. (MEDIUM, per constitution VIII, M-R2-7) — **Done.** The pattern takes `(.autoDispose|.family)*` in either order before `<`/`(`; six fixtures cover `FutureProvider.autoDispose(`, `StreamProvider.autoDispose(`, `Provider.family<…>(`, `NotifierProvider.autoDispose<…>(` and both mixed orders. The `generated` skip is now the `lib/core/network/generated/` prefix (a `*.g.dart` file stays skipped: the generator's own `$NotifierProvider` wrappers would otherwise trip the pattern).
- [x] M-R3-2 [US3] Regenerate the provider code, in the six `*.g.dart` files (`frequencies/data/satellite_channels_provider`, `live/live_poller`, `match_detail/data/match_detail_providers`, `matches/data/matches_providers`, `my_satellites/data/my_satellites_provider`, `my_satellites/data/satellite_matches_provider`, under `app/lib/features/`) that `dart run build_runner build -d` changes on this tree (their hashes and copied doc comments are from before the round-2 edits). Commit the generator's output unchanged. Then ask Lane B2 to make `app.yml` fail on a stale `app/lib/**/*.g.dart` (run `build_runner`, then `git diff --exit-code`), because `backend.yml:209`'s check covers only `lib/core/network/generated`. (MEDIUM, per the constitution's generated-files rule) — **Done.** `dart run build_runner build -d` rewrote exactly those six files (provider hashes and the doc comments copied from the round-2 sources; no other output changed). The B2 step is recorded in `docs/owner-actions.md` and `docs/runbooks/ci-workflows.md`, and `app/CLAUDE.md` no longer claims CI already checks them.

---

## Done check

An admin logs in over WireGuard and edits a match, and the change appears in the app; ysscores (or the bridge) imports tomorrow's fixtures; S2–S5 work on a real Android phone; closed-test build uploaded

How it is checked ([quickstart.md](quickstart.md#done-check-spec-sc-010)):

1. **Edit → app:** from a WireGuard peer, log in to the admin (`pnpm dev:wg`) and change tomorrow's match: kickoff, one channel and a manual status. On the phone, S2 and S3 show the change within 60 s, 3 times out of 3 (SC-001).
2. **Fixtures:** `import_runs` shows an unattended `ysscores` (or `legacy`) run since the morning, and tomorrow's Cairo day has its fixtures (SC-004).
3. **Phone:** the Lane M walk-through (T136) passes on the closed-test build (SC-006 to SC-008).
4. **Closed test:** the AAB is on the Play closed track, and at least one tester has installed it (SC-009).

Record the evidence on each lane's PR, and tick the owner items in `docs/owner-actions.md`.
