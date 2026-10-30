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
- [ ] T015 [US1] Regenerate the admin client from the new `admin.json` (`cd admin && pnpm install && pnpm orval`) and commit `admin/src/api/generated/*` unedited; run `swagger_parser` too and confirm the app client has no diff (`public.json` is unchanged). Then open the contract PR from `d02-b1` with:
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
- [ ] A-F3 **Per-row version (Lane B1's contract).** `AdminMatchRow` carries no `etag`, so a bulk action reads each selected match with a `GET` first. Ask B1 to add `etag` to the row (non-breaking) and drop the round trips in `BulkBar.tsx`.
- [ ] A-F4 **Create responses in the client.** Orval emits no response schema for a 201-only operation, so `responseSchemas` maps the five `POST` creates to the entity's `PATCH` envelope (same `$ref` in `admin.json`). Switch back if B1's spec ever gives creates their own response schema or a `200`.
- [ ] A-F5 **T107 steps 2–4 (owner).** Prism `?mock=…` walk, `pnpm dev:wg` over WireGuard with the two-browser conflict, and screenshots at 1440 and 1024 against `Matches.png`, `MatchEditor.png` and `Dialogs.png`. Steps are in [owner-actions](../../docs/owner-actions.md#lane-a-admin-1).

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

- [ ] T109 [US3] Add `just_audio`, `url_launcher` and `cached_network_image` to `app/pubspec.yaml` (all in SD §5.1's list), run `flutter pub get`, and commit `app/pubspec.lock`.
- [ ] T110 [US3] Add the D2 copy to `app/lib/core/l10n/app_ar.arb` (S2–S5 labels, empty states including S3's «لم تُضف القنوات الناقلة بعد» with its «تحديث» action, `StaleHint`'s age text, the commentator clip states, copy and video actions) and the D2 codes to `app/lib/core/l10n/error_copy.dart`. No Arabic literal in widgets.
- [ ] T111 [P] [US3] Update `app/CLAUDE.md`: the SWR repository rule, the drift schema version and its migration test, the polling rule (only while visible and resumed), and the single audio player.

### Tests first (M): write them and see them fail

- [ ] T112 [P] [US3] Write `app/test/core/format/local_day_test.dart`: matches group by the device's local date of `kickoff_at`, never `match_date` (FR-041), for Cairo, Casablanca and Riyadh offsets injected as D1's time tests do (not read from the host); TBD matches go to the «موعد لم يُحدد» group; `TimeFormat.dayWindow` gives UTC bounds for the local day, including across a DST change.
- [ ] T113 [P] [US3] Write `app/test/core/db/migration_v2_test.dart`: a version-1 database with `matches` rows opens at version 2 with `match_windows` (`day` PK, `etag`, `fetched_at`) and `cached_documents` (`key` PK, `etag`, `body`, `fetched_at`) and its rows intact; local days outside today−1 … today+6 are pruned on start.
- [ ] T114 [P] [US3] Write `app/test/core/network/swr_repository_test.dart` with a fake Dio adapter ([R25](research.md#r25-stale-while-revalidate-with-drift)):
  - it emits the drift copy first, then sends `If-None-Match` with the stored ETag;
  - `200` replaces the day's rows (or the document) and the ETag in one transaction and emits again;
  - `304` touches only `fetched_at` and emits nothing new;
  - offline emits the cache and an error flag, never an empty list over a cached one;
  - freshness: stale after 5 minutes for matches and match detail, after 24 hours for satellites and channels;
  - **S4 isolation:** a `200` for S4's satellite-filtered day is stored under its `cached_documents` key and leaves that day's `matches` rows and `match_windows` ETag unchanged, so S2 never shows a filtered list.
- [ ] T115 [P] [US3] Write `app/test/features/match_detail/carriage_order_test.dart`: S3's groups put my satellites (the O10 default, Nilesat 7.0W and Badr by slug) first, then other satellites, then platforms; within a group, free before encrypted, then `sort_order`, then `id`; hidden links never appear (FR-043).
- [ ] T116 [P] [US3] Write `app/test/features/live/live_polling_test.dart` with `fake_async`: matches revalidate every 60 s and `/v1/live` is polled every 30 s only while a live or imminent match is on a visible route and the app is `resumed`; both stop when paused or when the route is covered; live states stay in memory and are never written to drift (FR-047).
- [ ] T117 [P] [US3] Write `app/test/features/match_detail/audio_player_test.dart`: one shared player, so starting a clip stops the other; `CommentatorRow` moves through idle, loading, playing and error; a failed load shows the error state.
- [ ] T118 [P] [US3] Write golden tests for the five new components, in RTL, both themes, at 1.0× and 1.3×, with the D1 dark ≠ light byte check: `app/test/goldens/commentator_row_test.dart` (four states), `filter_chip_row_test.dart` (with a live count), `search_field_test.dart` (empty, typing, clear), `segmented_test.dart` and `stale_hint_test.dart`. Each follows its README in `madar-design/design-system/components/`.
- [ ] T119 [P] [US3] Write `app/test/features/matches/matches_page_test.dart` (S2): the date strip with RTL paging and «اليوم»; the chips «الكل» and «مباشر ‹count›»; competition groups by admin priority, then earliest kickoff; the channel line; every `StatusBlock` variant, with no score or minute for an estimated live state and no cached state shown as live (SC-008); the TBD group; pull to refresh; the skeleton; the empty day and empty live states; `StaleHint` past 5 minutes.
- [ ] T120 [P] [US3] Write `app/test/features/match_detail/match_detail_page_test.dart` (S3): the hero; the three-part "where to watch" with its toolbar; `CarriageRow` collapsed with the readout, and expanded with the details, copy-frequency (to `Clipboard`) and reception-video (through `url_launcher`); the manual broadcaster cards; the stadium, Egyptian broadcaster and match-level commentator cards only with data; the no-channels state, «لم تُضف القنوات الناقلة بعد» with a «تحديث» button that revalidates the match (constitution I: a next action; the «تابع المباراة» follow action replaces it on D3); 171 links built lazily, with the back-to-top button after two screen heights.
- [ ] T121 [P] [US3] Write `app/test/features/my_satellites/my_satellites_page_test.dart` (S4: satellite chips, only matches carried on them, grouped by competition with finished last, both empty states) and `app/test/features/frequencies/frequencies_test.dart` (S5.1: search, my satellites pinned first; S5.2: the header, alignment aids, reception video, category switch with swipe, search by name or frequency digits such as `11843`, the readout always visible with the access badge, expansion, and the empty state).
- [ ] T122 [P] [US3] Write `app/tool/test_all_zones.sh`: run `flutter test` under `TZ=UTC`, then under `TZ=Africa/Cairo`, and exit non-zero if either fails or `git status --porcelain test/goldens` shows a change. T133 runs it. CI keeps its single run (`app.yml` is Lane B2's), as on D1.

### Implementation (M)

- [ ] T123 [US3] Bump `app/lib/core/db/app_database.dart` to `schemaVersion 2` with the `match_windows` and `cached_documents` tables, the v1 → v2 migration step and the start-up prune, then run `dart run build_runner build --delete-conflicting-outputs`. T113 passes.
- [ ] T124 [US3] Implement `app/lib/core/network/swr_repository.dart`, the stale-while-revalidate base on D1's `EtagInterceptor`, with a typed-rows path for matches by local day and a document path for `cached_documents`. T114 passes.
- [ ] T125 [P] [US3] Build the new components in `app/lib/design/components/`: `commentator_row.dart` (`CommentatorRow`), `filter_chip_row.dart` (`FilterChipRow`), `search_field.dart` (`SearchField`), `segmented.dart` (`Segmented`) and `stale_hint.dart` (`StaleHint`), each once under its INDEX name, `const` constructors, tokens only, Western digits, LTR islands for Latin names and frequencies, and one Arabic screen-reader label per composite row. T118 passes.
- [ ] T126 [US3] Implement `app/lib/features/my_satellites/data/my_satellites_provider.dart`: the O10 default resolved from `/v1/satellites` by the Nilesat 7.0W and Badr slugs until D3 stores the user's choice.
- [ ] T127 [US3] Build S2 in `app/lib/features/matches/` (the matches repository on T124, providers, and `matches_page.dart` with `PageView` day paging inside the RTL `Directionality`), replacing D1's direct `/v1/matches` call. T112 and T119 pass.
- [ ] T128 [US3] Implement `app/lib/features/live/live_poller.dart`: the 60 s and 30 s timers in a Riverpod provider, gated by route visibility and `AppLifecycleListener`, merging `/v1/live` states into the rows in memory. T116 passes.
- [ ] T129 [US3] Build S3 in `app/lib/features/match_detail/`: the repository on `cached_documents`, the `CustomScrollView` with one `SliverList.builder` per open group, the shared `just_audio` player provider, copy and video actions, the cards, and the no-channels state with «تحديث». T115, T117 and T120 pass.
- [ ] T130 [US3] Build S4 in `app/lib/features/my_satellites/` from T126 and the document path of T124: request `/v1/matches?from&to&satellite_ids=<selected ids>` for the local day and cache it under `matches:<day>:sat:<sorted ids>` in `cached_documents`. Never filter S2's cached rows locally (a row's channel line holds at most 2 carriages), and never write the filtered list through `matches` or `match_windows`. Its part of T121 and T114's S4 isolation case pass.
- [ ] T131 [US3] Build S5.1 and S5.2 in `app/lib/features/frequencies/` on `cached_documents` (`satellites`, `satellite:<id>:channels`). Its part of T121 passes.
- [ ] T132 [US3] Wire the routes in `app/lib/core/router/app_router.dart` (`/`, `/match/:id`, `/my-satellites`, `/satellites`, `/satellites/:id`) and the bottom navigation, replacing the D1 stubs; the match detail route stays pushed so it has a back arrow.

### Validation (M)

- [ ] T133 [US3] Validate in `app/`: `flutter analyze`, `./tool/check_token_copy.sh`, `./tool/check_literals.sh`, and `./tool/test_all_zones.sh` in the pinned golden image (all goldens pass, no changes between zones).
- [ ] T134 [US3] Write `docs/runbooks/store-releases.md` (FR-055): tagging `app-vX.Y.Z`, the `app-release.yml` artifact, enrolling in Play App Signing, the closed-track upload by hand, the testers list, backing up the upload keystore, and that the automated upload waits for the Play service account. Add it to `docs/runbooks/README.md`'s setup order and "After setup" table.
- [ ] T135 [US3] After the merge, the owner tags `app-v0.2.0`; confirm `app-release.yml` produces a signed `prod` AAB with `versionCode` from the run number, and that the owner uploads it to the closed track and a tester installs it (SC-009).
- [ ] T136 [US3] Walk the device steps of the [quickstart Lane M](quickstart.md#lane-m-app) on the closed-test build: S2 week paging, live filter and pull to refresh; S3 with 130 or more channels showing its answer in under 1 s and scrolling smoothly, a clip, copying a frequency, the reception video; S4 only Nilesat or Badr matches; S5.2 category switch and `11843` search; airplane mode showing cached copies with their age (SC-006 to SC-008). Take screenshots of each screen in both themes, compare them with the PNGs listed above, and attach them to the PR.
- [ ] T137 [US3] After the owner's `CORS_ORIGINS` change, open the PWA preview channel (`https://madar-sat--master-p2bbuj53.web.app`) and confirm S2 and S3 load data from VPS-1, and that DevTools → Network shows no request to `fonts.gstatic.com`, `fonts.googleapis.com` or a CanvasKit CDN.
- [ ] T138 [US3] Add the D2 Lane M items to `docs/owner-actions.md` (before merge: the `CORS_ORIGINS` change, the keystore backup; after merge: tag `app-v0.2.0`, Play App Signing, the closed-track upload, testers), each with its task ID and runbook link, and update the "Open now" table.

---

## Done check

An admin logs in over WireGuard and edits a match, and the change appears in the app; ysscores (or the bridge) imports tomorrow's fixtures; S2–S5 work on a real Android phone; closed-test build uploaded

How it is checked ([quickstart.md](quickstart.md#done-check-spec-sc-010)):

1. **Edit → app:** from a WireGuard peer, log in to the admin (`pnpm dev:wg`) and change tomorrow's match: kickoff, one channel and a manual status. On the phone, S2 and S3 show the change within 60 s, 3 times out of 3 (SC-001).
2. **Fixtures:** `import_runs` shows an unattended `ysscores` (or `legacy`) run since the morning, and tomorrow's Cairo day has its fixtures (SC-004).
3. **Phone:** the Lane M walk-through (T136) passes on the closed-test build (SC-006 to SC-008).
4. **Closed test:** the AAB is on the Play closed track, and at least one tester has installed it (SC-009).

Record the evidence on each lane's PR, and tick the owner items in `docs/owner-actions.md`.
