---

description: "D3 · Follow, push and sources: tasks per lane"
---

# Tasks: D3 · Follow, push and sources

**Input**: Design documents from `specs/003-d03-follow-push-sources/`: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md).

**Tests**: Mandatory (constitution, Quality Gates). In every lane, the test tasks come first and must be seen failing before the code they cover (FR-053, [research R30](research.md#r30-what-is-written-first)). The coverage bar is the MVP bar in FR-054.

**Organization**: one `## Lane` section per lane, each an independently testable user story, plus a final `## Done check`.

- A lane implements and ticks **only its own section** and changes only its own folders (FR-051). The one exception: the PR that changes an OpenAPI spec regenerates both clients and commits the generator output unedited (D14), because `backend.yml`'s `clients` job fails on a stale client.
- Review fix tasks are appended at the end of a lane's section by `/speckit-review-implementation`.
- **Carry-over from 002** (delivery-plan §5.3): Lane A's A-F1 and A-F2 come first in Lane A (T090, T091). The owner's open D2 checks (B1 T047, B2 T086–T087, A T107 steps 2–4, M T135–T137) stay in `specs/002-d02-core-flows/tasks.md` and `docs/owner-actions.md`; they don't block D3 code.

| Section | Spec story | Story label | Branch | Folders |
| --- | --- | --- | --- | --- |
| Lane B1 | User Story 1 (P1) | `[US1]` | `d03-b1` | `backend/` except `backend/app/adapters/`, `backend/tests/adapters/` and `backend/tests/fixtures/livesoccertv/`; plus the generator output in `admin/src/api/generated/` and `app/lib/core/network/generated/` in a PR that changes an OpenAPI spec |
| Lane B2 | User Story 3 (P3) | `[US3]` | `d03-b2` | `infra/`, `.github/`, `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/livesoccertv/` |
| Lane A | User Story 4 (P4) | `[US4]` | `d03-a` | `admin/` |
| Lane M | User Story 2 (P2) | `[US2]` | `d03-m` | `app/` |

Every lane may also edit `docs/runbooks/` for its own parts and its own section of `docs/owner-actions.md` (FR-055).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task).
- **[USn]**: the spec story the task belongs to.
- Paths are repo-relative.

## Dependencies & execution order

### Between lanes

- **Contracts at 13:00:** T014 (B1: both OpenAPI specs, the regenerated Dart and admin clients, revision `0005` and the `app.workers` change, merged to `master`) blocks:
  - Lane M's T133 (device registration and follow sync against the generated client);
  - Lane A's T100–T103 (ordering, A13 and A2 against the generated client);
  - Lane B2's T068–T072 (they write `0005`'s source-health and placeholder columns and import `app.notifications.schedule` through `app.workers`).
  
  Before then, M builds onboarding, S9, S15, S16 and S0 on local state; A closes A-F1 and A-F2 and builds A5, A7, A8 and A10 on D2's endpoints; B2 writes its tests, saved pages, `parse`, the backup image and the Kuma service.
- **The dispatcher on the hosts** (B1's T047) needs B2's T077 (`worker-notify` mounts `/srv/secrets/fcm.json`, the new env in `vps2.yml`) and the owner's FCM key.
- **A13's «تشغيل الآن»** (B1's T040) sends `adapters.schedule_fetch`, which B2 builds in T064. Until B2 merges, the B1 contract test checks only that the task is sent by name.
- **Done check:** all four lanes, the owner's iPhone, and the next morning's backup.

### Inside each lane

```text
Setup → Tests (must fail) → implementation in the listed order → Validation
```

`[P]` tasks inside a block can run together.

### Parallel examples

```text
B1 tests:   T015–T029 together after T005 and T014
B1 code:    T030, T031, T032 together; T036, T037 together
B2 tests:   T052–T060 together after T051
B2 infra:   T073, T074, T075, T076 together
A:          T092, T093, T094 (components) together; T095–T099 (screens) as parallel features
M:          T113–T125 together after T112; T126 (components) as parallel files
```

## Implementation strategy

1. **Morning:** B1 writes the device and admin schemas and stub routes with examples, revision `0005` and the `app.workers` change, and merges them with both regenerated clients by 13:00 (T014). B2 saves LiveSoccerTV pages and writes its parse, matching and health tests, the backup image and Kuma. A closes A-F1 and A-F2 and builds its components and A5, A7, A8, A10. M builds onboarding, S9, S15, S16, S0, drift v3, the new components and the Firebase setup.
2. **13:00:** T014 merges. Everyone rebases.
3. **Afternoon:** B1 builds devices, the scheduler, the dispatcher, the cache, the limits and the admin services, then deploys. B2 builds `schedule_fetch`, LiveSoccerTV, health, alerts and heartbeats, then deploys and installs the timers. A builds A6, A13 and A2. M wires registration, follow sync, push and Remote Config.
4. **Evening:** the owner installs the FCM key and other secrets; the first LiveSoccerTV run is checked; the iPhone push test runs on a real device.
5. **Next morning:** the first nightly backup is checked. Then the Done check.

Each lane merges at least twice (delivery-plan §5.2): once at the contract or scaffold point, once at the end.

---

## Lane B1

**Story (User Story 1, P1):** As a fan who follows a team, I get exactly one reminder before its match, naming the channel.

**Independent test:** register a device, set its push token and satellites, follow a team and its competition; create a match 20 min ahead; run the scheduler twice (one row) and the dispatcher at the due time (one message, naming a channel on the device's satellites, tag `match_<id>`); an `UNREGISTERED` token is cleared; a repeated public read is a cache hit, and an admin edit makes the next read miss ([quickstart.md](quickstart.md#lane-b1-devices-notifications-cache-admin-additions)).

**The owner must review:** the contract diff (T014), revision `0005` (T008), the audience query (T034), and the rate-limit values (T037).

### Setup (B1)

- [x] T001 [US1] Add `firebase-admin` to `backend/pyproject.toml` and refresh `backend/uv.lock` (SD §6.8, [R9](research.md#r9-fcm-credentials-and-the-sender)). Check it installs on `linux/arm64` and `linux/amd64` in the Docker build. Keep `[tool.coverage]` `fail_under = 70` over `app/domain`, `app/services`, `app/adapters`, and add `app/devices` and `app/notifications` to it (FR-054).
- [x] T002 [P] [US1] Extend `backend/app/settings.py` (no secret gets a default):
  - `FCM_CREDENTIALS_FILE: Path | None`, `FCM_DRY_RUN: bool = False`, `PWA_ORIGIN: AnyHttpUrl | None` (read by the notifications worker only; `app.public` and `app.admin` start without them);
  - `RESPONSE_CACHE_ENABLED: bool = True`, `RESPONSE_CACHE_MAX_BYTES: int = 524288`;
  - `RATE_LIMIT_DEVICE_PER_MIN: int = 120`, `RATE_LIMIT_IP_PER_MIN: int = 600`, `RATE_LIMIT_REGISTER_PER_10MIN: int = 30` ([R11](research.md#r11-rate-limits-on-v1)).
- [x] T003 [P] [US1] Update `backend/CLAUDE.md`: the `app/devices/` and `app/notifications/` modules; that only `app/notifications/` talks to FCM and producers only insert outbox rows; the response cache keys on the ETag and is never invalidated by deleting keys; `0005` joins the revisions never edited after merge; B2 writes source health and placeholders only through `app/adapters/health.py` and `livesoccertv_links.py`.
- [x] T004 [P] [US1] Add the D3 error codes to `backend/app/api/errors.py`, each with its status and `meta` keys ([contracts/public-devices.md](contracts/public-devices.md#endpoints), [contracts/admin-api.md](contracts/admin-api.md)): `rate_limited` (429, `retry_after_s`), `unknown_follow_target` (422, `unknown`), `too_many_follows` (422, `max`), `unknown_satellite` (422, `unknown`), `run_in_progress` (409), `source_not_runnable` (409), `source_not_found` (404), `import_run_not_found` (404).
- [x] T005 [US1] Extend `backend/tests/conftest.py`: a `device_client` fixture (registers a device, carries its `Authorization: Device` header); a `FakePushSender` recording messages and answering per token (`ok`, `UNREGISTERED`, `UNAVAILABLE`); a frozen-clock helper for the scheduler; a factory for a match with kickoff `now + Δ`, two teams, a competition and links on chosen satellites.

### Contract and migration (B1, before 13:00)

- [x] T006 [US1] Write the device shapes in `backend/app/schemas/public.py` (Pydantic v2, `extra="forbid"`) exactly as [contracts/public-devices.md](contracts/public-devices.md):
  - `DeviceRegister`: `install_id: UUID`, `platform: Literal["android", "ios", "web"]`;
  - `DeviceRegistered`: `device_id: int`, `device_token: str`;
  - `DeviceUpdate`: every field optional; `push_token` "≤ 4096 characters", `app_version` "≤ 32", `locale` "≤ 16", `tz` "≤ 64 characters (IANA name)" checked with `zoneinfo`, `satellite_ids` "≤ 32", `prefs: NotificationPrefs`;
  - `NotificationPrefs`: `types` keyed by the seven SD §6.8 types, each `{on: bool, lead_min: Literal[5, 15, 30, 60] | None}` (lead time only on `kickoff_reminder`); unknown types refused; defaults filled on read ([R4](research.md#r4-notification-preferences));
  - `Device` (response, no token or hash, `has_push_token: bool`); `FollowSet` (five `list[int]` fields, "≤ 500 ids in total", duplicates collapsed).
  
  Add named examples for Prism and the Dart client.
- [x] T007 [US1] Write the admin additions in `backend/app/schemas/admin.py` exactly as [contracts/admin-api.md](contracts/admin-api.md): `SourceHealth` (extends D2's `SourceItem`, fields added only), `ImportRunRow`, `ImportRunDetail`, `Dashboard`, `OrderRequest` (`items: list[{id: int, if_match: str}]`, ≥ 1, ids unique), the `placeholder` and `show_in_match` filters on the channel list and `placeholder_source` on channel rows, the `missing_logo` filter on the team list. Named examples for each.
- [x] T008 [US1] Add revision `0005` cases to `backend/tests/db/test_migrations.py` (see them fail), then write `backend/alembic/versions/0005_devices_outbox_sources.py` and the matching columns in `backend/app/db/models.py`, exactly as [data-model](data-model.md#revision-0005_devices_outbox_sources-lane-b1):
  - `devices.satellite_ids bigint[] NOT NULL DEFAULT '{}'` with `ck_devices_satellite_ids` "`cardinality(satellite_ids) <= 32`";
  - `notification_outbox.claimed_at timestamptz`, `notification_outbox.cursor_device_id bigint NOT NULL DEFAULT 0`, index `notification_outbox_sending_idx ON (claimed_at) WHERE status = 'sending'`;
  - `sources.consecutive_failures integer NOT NULL DEFAULT 0` (`>= 0`), `sources.breaker_opened_at timestamptz`, `sources.last_success_at timestamptz`, `sources.last_zero_alert_on date`;
  - `import_runs.log jsonb`;
  - `channels.placeholder_source text REFERENCES sources(name)` and `channels_placeholder_idx ON (placeholder_source) WHERE placeholder_source IS NOT NULL`.
  
  Tests: every column and check exists; a 33-element `satellite_ids` is refused; `downgrade 0004` drops them all and leaves every other row unchanged; `upgrade head` again works.
- [x] T009 [US1] Write `backend/tests/unit/test_workers.py` cases (see them fail), then change `backend/app/workers/__init__.py` so `SCHEDULE_MODULES = ("app.adapters.schedule", "app.notifications.schedule")` and `TASK_MODULES` adds `app.notifications.tasks`: the beat schedule is the merge of every existing module's `BEAT_SCHEDULE` (a duplicate entry name raises), and a missing module is skipped as today. Importing `app.workers` still loads neither `app.settings` nor `app.db` (the home box test stays green).
- [x] T010 [US1] Add `backend/app/api/public/devices.py` with the four routes as stubs answering the named examples, mounted on `app.public:app` only, and `backend/app/api/admin/{sources,dashboard,ordering}.py` stubs, mounted on `app.admin:app`, each with its role dependency (`editor`). Every route declares its error responses.
- [x] T011 [US1] Extend `backend/tests/contract/test_admin_routes_have_roles.py` so it enumerates the new admin routes, and `backend/tests/contract/test_openapi_envelope.py` so the device routes are checked for the envelope and `Cache-Control: no-store`.
- [x] T012 [US1] Export both specs (`uv run python -m app.cli export-openapi`) and check them non-breaking against `contract-v1` with `backend.yml`'s breaking-change check run locally.
- [x] T013 [US1] Regenerate both clients and commit the output unedited (`cd admin && pnpm install && pnpm orval`; `cd app && flutter pub get && dart run swagger_parser && dart run build_runner build -d`).
- [ ] T014 [US1] **13:00 merge:** open the PR with T001–T013 (suite green, the new tests passing against stubs or skipped with `xfail(strict=True)` only where the behaviour is later work in this lane), get the owner's review of the contract diff and `0005`, merge to `master`, and tell lanes A, M and B2.

### Tests first (B1): write them and see them fail

- [x] T015 [P] [US1] `backend/tests/devices/test_register.py` ([R1](research.md#r1-device-registration-and-the-token)): `201` with a 43-character base64url token; only `sha256(token)` stored, the token never logged; the same `install_id` again → same `device_id`, new token, old token `401`, follows kept; bad platform or `install_id` → `422`.
- [x] T016 [P] [US1] `backend/tests/devices/test_auth.py` ([R2](research.md#r2-device-authentication)): missing header, wrong scheme, malformed, unknown token → `401 unauthenticated` with identical bodies; a valid token reaches only its own device; `last_seen_at` changes at most once an hour.
- [x] T017 [P] [US1] `backend/tests/devices/test_update.py`: each `DeviceUpdate` field stored and validated ("≤ 4096", "≤ 32", "≤ 16", IANA `tz`, unknown satellite → `422 unknown_satellite`, 33 satellites → `422`); omitted fields unchanged, `null` clears; a push token held by device B moves to A and B's becomes NULL; `prefs` defaults filled on read; `DELETE /v1/devices/me` → `204`, the token `401` afterwards, follows gone.
- [x] T018 [P] [US1] `backend/tests/devices/test_follows.py` ([R5](research.md#r5-replacing-the-follow-set)): a set is stored exactly and returned; a second PUT replaces it (removed items gone); unknown ids → `422 unknown_follow_target` listing them by kind, nothing changed; 501 ids → `422 too_many_follows`; duplicates collapsed; two concurrent PUTs from one device end with one of the two sets, never a mix.
- [x] T019 [P] [US1] `backend/tests/notifications/test_scheduler.py` ([R6](research.md#r6-the-reminder-scheduler)): a followed match 20 min ahead → one row `kickoff_reminder:<id>` due at kickoff − 15 min; running twice → still one; an unfollowed match → none; kickoff moved while pending → `due_at` moves; moved after `sent` → row unchanged, no new row; `time_tbd`, `postponed`, `cancelled` or kickoff past 24 h → `cancelled`; created 7 min before kickoff → due now; kickoff passed → none.
- [x] T020 [P] [US1] `backend/tests/notifications/test_dispatcher.py` ([R7](research.md#r7-the-dispatcher)): two sessions claiming at once get disjoint rows (`SKIP LOCKED`); a device following the home team, the away team, the competition and the match gets exactly one message; 1,200 devices → three `send_each` calls of ≤ 500; `UNREGISTERED` → `push_token` NULL; a whole-call `UNAVAILABLE` on page 2 → retry resumes at `cursor_device_id` and page 1's devices get nothing more; a type switched off in `prefs` → not sent; a row stuck in `sending` for 11 min returns to `pending`; a match cancelled while queued → `cancelled`, nothing sent; `sent`, `failed` and `sent_at` recorded.
- [x] T021 [P] [US1] `backend/tests/notifications/test_messages.py` ([R8](research.md#r8-the-kickoff-reminder-message)): the channel on the device's satellites wins, free first; none of them carries the match → the default (Nilesat + Badr by slug, free first); no visible link → the no-channel body; hidden links, hidden names, deleted channels and placeholders are never named; title minutes from send time (`بعد 15 دقيقة`, `بعد 7 دقائق`, `بعد دقيقتين`, at least 1); every name wrapped in U+2068 … U+2069; Western digits only; `tag` and `collapse_key` `match_<id>`, `data.route` `/match/<id>`, web `fcm_options.link` from `PWA_ORIGIN`.
- [x] T022 [P] [US1] `backend/tests/api/test_cache.py` ([R10](research.md#r10-the-response-cache)): a second identical read is served from `rc:<etag>` (no DB query, asserted with a query counter); bumping a dataset the route depends on → the next read misses and returns the new data with a new `ETag`; bumping an unrelated dataset → still a hit; a body over `RESPONSE_CACHE_MAX_BYTES` isn't stored; Redis down → the read succeeds from the DB; `/v1/devices*` never cached; `304` behaviour unchanged.
- [x] T023 [P] [US1] `backend/tests/api/test_ratelimit.py` ([R11](research.md#r11-rate-limits-on-v1)): over the per-IP limit → `429 rate_limited`, `Retry-After`, `meta.retry_after_s`; a **verified** device token is counted per device, not per IP (two devices behind one IP each get their own 120/min); an unknown, malformed or revoked token is counted per IP, so 1,000 requests from one IP with a fresh random token each still hit `429`; verification hits the database at most once per token per 10 min (cache of valid hashes) and a deleted or rotated device's hash stops counting as valid at once; `POST /v1/devices` has its own window; `X-Forwarded-For` trusted only from Caddy's address; `/healthz` exempt; Redis down → allowed; the admin app has no such middleware.
- [x] T024 [P] [US1] `backend/tests/api/test_placeholders_hidden.py` ([R13](research.md#r13-placeholders-in-the-public-api)): a channel with `placeholder_source` set and linked to a match appears in none of `/v1/matches` (channel line), `/v1/matches/{id}`, `/v1/satellites/{id}/channels`, `/v1/channels/{id}` (`404`); after an admin PATCH with `show_in_match: true` it appears, and `placeholder_source` is NULL with one audit entry.
- [x] T025 [P] [US1] `backend/tests/admin/test_sources.py` ([R12](research.md#r12-admin-additions)): `GET /sources` health fields (breaker, paused, `items_24h`, `error_rate_24h`, `running` from the lock keys); pause → `is_enabled` false, audited, `sources` bumped (the list's `ETag` changes); resume → the four health fields reset ([data-model](data-model.md#source-health)), `sources` bumped, and one `adapters.schedule_fetch` queued with `manual=True`; a finished run (B2's `health.record_run`, faked here by bumping) changes the `GET /sources` `ETag`, so A13 never gets a stale `304`; run → `202` and `adapters.schedule_fetch` sent by name with `manual=True` on `imports` (Celery mocked); run while the lock is held → `409 run_in_progress`; `manual` → `409 source_not_runnable`; runs list newest first with cursor; run detail with `log`.
- [x] T026 [P] [US1] `backend/tests/admin/test_dashboard.py`: today's matches without a visible channel grouped by competition priority then kickoff; `placeholders_to_complete` counts non-deleted placeholders; `sources` equals `GET /sources`; `recent_changes` is the last 10 audit entries; a window over 2 days → `422`; the `ETag` is built from `matches`, `channels` and `sources` with a 60 s bucket (`bucket_s=60`, for `recent_changes`), so it changes after a run, an edit or a minute.
- [x] T027 [P] [US1] `backend/tests/admin/test_ordering.py`: `PUT /competitions/order` sets `priority` 1…n in order, audits each changed row, bumps `competitions` and `matches`; unlisted rows keep their order after the listed ones; one stale `if_match` → `409 edit_conflict` with `stale_ids` and nothing changed; repeated or unknown ids → `422`. The same for satellites (bumps `satellites`).
- [x] T028 [P] [US1] `backend/tests/admin/test_channel_placeholders.py`: `GET /channels?placeholder=true` lists only placeholders, with `placeholder_source`; `GET /channels?show_in_match=true|false` filters on that flag; `GET /teams?missing_logo=true` lists only teams without a logo.
- [x] T029 [P] [US1] `backend/tests/contract/test_public_contract.py` and `test_admin_contract.py`: schemathesis runs over the new routes against the exported specs, on PostgreSQL 16.

### Implementation (B1)

- [x] T030 [P] [US1] `backend/app/devices/tokens.py` and `backend/app/devices/auth.py`: token generation (`secrets.token_bytes(32)`, base64url), `sha256` hex, the `DeviceAuth` dependency and the hourly `last_seen_at` touch. T015, T016 pass.
- [x] T031 [P] [US1] `backend/app/devices/service.py`: register (upsert by `install_id`, rotate), update (field rules, push-token move, satellite check), delete. T017 passes.
- [x] T032 [P] [US1] `backend/app/devices/follows.py`: replace under `SELECT … FOR UPDATE` on the device row, one existence query per kind, `DELETE` + `INSERT`, cap 500. T018 passes.
- [x] T033 [US1] Replace the stubs in `backend/app/api/public/devices.py` with the services; every response `Cache-Control: no-store`.
- [x] T034 [US1] `backend/app/notifications/scheduler.py` and `backend/app/notifications/dispatcher.py` with `backend/app/notifications/tasks.py` (`notifications.schedule_reminders`, `notifications.dispatch_due`, `notifications.prune_outbox` on the D2 base task, `bind=True`, bounded retries, a `lock:notifications:schedule` `SET NX EX` lock) and `backend/app/notifications/schedule.py` (`BEAT_SCHEDULE` per [contracts/pipelines-and-ops.md](contracts/pipelines-and-ops.md#beat-entries-after-d3-utc)). The audience is the one `SELECT DISTINCT` of [R7](research.md#r7-the-dispatcher), with bound parameters only; put it in its own function with a docstring so the owner can review it. T019, T020 pass.
- [x] T035 [US1] `backend/app/notifications/messages.py` (channel choice with `app.domain.ranking`, Arabic copy, number agreement, FSI/PDI isolation, FCM fields) and `backend/app/notifications/sender.py` (`PushSender` protocol, `FcmSender` over `firebase_admin.messaging.send_each` initialized once from `FCM_CREDENTIALS_FILE`, `dry_run` from `FCM_DRY_RUN`, mapping `UNREGISTERED` / invalid-token errors per message and whole-call failures to `Retryable`). T021 passes.
- [x] T036 [P] [US1] `backend/app/api/cache.py`: `cached_response(etag, ttl, build)` storing the serialized envelope at `rc:<etag>`, size cap, fail-open on Redis errors, logged hits and misses; wire it into every public GET route with the SD §6.3.2 TTLs. T022 passes.
- [x] T037 [P] [US1] `backend/app/api/ratelimit.py`: the two-bucket sliding window middleware on `app.public:app`. Key: the device-token hash **only when that hash is a live device** (checked against a Redis set of valid hashes, `dv:<hash>`, filled from one indexed `devices.token_hash` lookup on a miss with a 10 min TTL, a 60 s negative entry for unknown hashes, and deleted by `backend/app/devices/service.py` on rotate and delete); otherwise the trusted client IP (reuse D2's client-IP helper). The register window, `/healthz` exempt, fail-open ([R11](research.md#r11-rate-limits-on-v1)). T023 passes.
- [x] T038 [US1] Exclude placeholders (`placeholder_source IS NULL`) in every public channel query in `backend/app/services/` (match detail, match list channel line, satellite channels, channel detail), and clear `placeholder_source` in `backend/app/services/admin/channels.py` when a save sets `show_in_match: true`. T024 passes.
- [x] T039 [P] [US1] `backend/app/services/admin/channels.py` and `teams.py` list filters (`placeholder`, `show_in_match`, `missing_logo`). T028 passes.
- [x] T040 [US1] `backend/app/services/admin/sources.py` and `backend/app/api/admin/sources.py`: health read (24 h window from `import_runs`, running from lock keys), pause, resume (resets the four fields, then queues one `adapters.schedule_fetch` with `manual=True`), run (`send_task("adapters.schedule_fetch", …)`), runs list with cursor, run detail from `import_runs.log`; pause, resume and run audited through D2's writer, and pause and resume bump the `sources` dataset so the existing `ETag("admin_sources", ("sources",))` changes. The runs list and run detail take their `ETag` from `sources` too. T025 passes.
- [x] T041 [P] [US1] `backend/app/services/admin/dashboard.py` and `backend/app/api/admin/dashboard.py`, with `ETag("admin_dashboard", ("matches", "channels", "sources"), bucket_s=60)`. T026 passes.
- [x] T042 [P] [US1] `backend/app/services/admin/ordering.py` and `backend/app/api/admin/ordering.py`, through D2's writer unit of work with each item's version. T027 passes.
- [x] T043 [US1] Map the new error codes in the OpenAPI response declarations; re-export both specs; confirm the generated clients are unchanged from T013 or regenerate and commit them.
- [x] T044 [US1] Run the full backend suite (`uv run ruff check . && uv run mypy --strict app && uv run pytest --cov`) and fix any failure in the code, never by weakening a test. T029 passes.

### Validation (B1)

- [ ] T045 [US1] Run [quickstart Lane B1](quickstart.md#lane-b1-devices-notifications-cache-admin-additions) steps 1–8 on `infra/compose/dev.yml` with the snapshot loaded and `FCM_DRY_RUN=true`; record the output in the PR.
- [x] T046 [US1] Confirm the MVP bar: coverage ≥ 70 % with `app/devices` and `app/notifications` included, and contract tests on every new route (FR-054). Record the figure in the PR.
- [ ] T047 [US1] Deploy and check on the hosts (needs B2's T077 and the owner's FCM key on VPS-2): merge; `backend.yml` deploys and runs `0005`; `worker-notify` logs `fcm: initialized`; the owner runs one real reminder to their own Android phone through `notifications.dispatch_due` (quickstart step 4 without dry run).
- [x] T048 [US1] Write `docs/runbooks/push-notifications.md` (FR-055): the FCM service account (create, install at `/srv/secrets/fcm.json` mode 600, rotate), `FCM_DRY_RUN`, reading the outbox (`sent`, `failed`, stuck `sending`), re-sending a failed row safely, and the owner's audience-query review. Write `docs/runbooks/response-cache-and-limits.md`: what is cached and for how long, turning the cache off (`RESPONSE_CACHE_ENABLED=false`), changing the limits and spotting a CGNAT false positive. Add the new variables to `docs/runbooks/secrets.md`, `0005` to `docs/runbooks/database-migrations.md`, and both runbooks to `docs/runbooks/README.md`'s setup order and "After setup" table. Every command must match the code.
- [x] T049 [US1] Add the D3 Lane B1 items to `docs/owner-actions.md` (before merge: review the contract diff, `0005`, the audience query and the limits; after merge: install the FCM key, run the first real reminder), each with its task ID and runbook link, and update the "Open now" table.

### Notes from the implementer (B1)

- **T014, T045 and T047 are open.** T014 is the contract PR and needs your review and merge. T045 needs the local stack with the snapshot loaded and a real FCM registration token for the dry run; the same behaviour is covered by `tests/devices/`, `tests/notifications/`, `tests/api/` and `tests/admin/` against PostgreSQL 16 and Redis 7. T047 needs B2's T077 and your FCM key.
- **T044 and T046:** `uv run ruff check .`, `uv run mypy --strict app` and `uv run pytest --cov` are green: **1212 passed, 93.49 % total** over `app/domain`, `app/services`, `app/adapters`, `app/devices` and `app/notifications`. `tests/adapters/test_homebox_acl.py` is excluded from that figure: it fails identically on `master` here because the dev Redis sets `requirepass` and the D2 ACL template's `homebox` rule is applied on top of the default user's password (a local environment, not a change in this lane).
- **T013 changed one line outside the generated client.** `admin/src/features/matches/queries.ts` (Lane A) imported `SourceItem` from the generated schemas; `GET /sources` now answers `SourceHealth`, so Orval no longer exports `SourceItem` and the admin typecheck failed. The import and the one field type now say `SourceHealth` — the shape A13 uses anyway. Lane A should confirm it at T100.
- Both clients were regenerated after the final `export-openapi`: `cd admin && pnpm orval`, and `cd app && dart run swagger_parser && dart run build_runner build -d`.

---

## Lane B2

**Story (User Story 3, P3):** As the owner, I trust the data pipeline to run and to tell me when it breaks.

**Independent test:** LiveSoccerTV `parse` tests pass on saved pages; a run adds `livesoccertv` links (and hidden placeholders) to upcoming matches, a second adds none, and an editor-removed link stays hidden; three failed runs open the breaker and alert on Telegram; a zero-items run alerts once; the next morning restic lists last night's snapshot in B2 and the OCI bucket holds the media; a stopped worker alerts in Kuma ([quickstart.md](quickstart.md#lane-b2-livesoccertv-health-backups-monitoring)).

**The owner must review:** the matching rules (T062), the backup retention and restore path (T073, T085), and the Kuma monitors (T086).

### Setup (B2)

- [x] T050 [US3] Save LiveSoccerTV pages as test fixtures in `backend/tests/fixtures/livesoccertv/`: at least 3 team pages (one Egyptian club, one European club, one national team) and their match pages, including one match with MENA and non-MENA broadcasters, one with a channel Madar lacks, one with no broadcasters yet, and one team page with no upcoming match. Fetch them directly from `www.livesoccertv.com` (not through `LVS.html`'s proxy), strip cookies and tracking scripts, and commit only HTML.
- [x] T051 [US3] Extend `backend/app/adapters/config.py` (`AdapterSettings`): `LIVESOCCERTV_COUNTRIES` (comma-separated, normalized with `normalizeCountry`, default the MENA list of [R16](research.md#r16-the-country-list)), `LIVESOCCERTV_FETCH_QUEUE` (default `scrape_home`), `SOURCE_BREAKER_THRESHOLD: int = 3`, `TELEGRAM_BOT_TOKEN: SecretStr | None`, `TELEGRAM_CHAT_ID: str | None`, `KUMA_PUSH_URL_MAINTENANCE`, `KUMA_PUSH_URL_IMPORTS`, `KUMA_PUSH_URL_NOTIFICATIONS` (all optional; no secret has a default).

### Tests first (B2): write them and see them fail

- [x] T052 [P] [US3] `backend/tests/adapters/test_livesoccertv_parse.py`: `parse` is pure (no network, no DB); the team page yields upcoming match links with date and opponent; the match page yields `[{name, country}]`; the no-broadcasters page yields an empty list; a page without the expected tables raises `LayoutChanged`.
- [x] T053 [P] [US3] `backend/tests/adapters/test_livesoccertv_plan.py` ([R14](research.md#r14-livesoccertv-plan-fetch-ingest)): targets are Madar matches in the next 48 h whose teams map through `livesoccertv_teams` (team id, else exact `ar_name_norm`); unmapped matches are skipped and counted; `window="t60"` plans only kickoffs in 55–70 min not fetched in the last 30 min; no targets → no fetch sent.
- [x] T054 [P] [US3] `backend/tests/adapters/test_livesoccertv_match.py`: the team page's link is picked by Cairo date and opponent; no match → `unmatched: match_not_found`.
- [x] T055 [P] [US3] `backend/tests/adapters/test_livesoccertv_links.py` ([R15](research.md#r15-matching-livesoccertv-channels), [R18](research.md#r18-placeholder-channels)):
  - an existing channel (by `name_norm` or display name, not deleted) is linked whatever country lists it, and by country when the Madar channel has one;
  - a name from a configured country that matches nothing → one placeholder (`kind = 'platform'`, `satellite_id` NULL, `show_in_match = false`, `placeholder_source = 'livesoccertv'`, `country` normalized), linked, audited with `source = livesoccertv`, `channels` bumped;
  - a second run, or another match with that name → the same placeholder reused;
  - a soft-deleted placeholder with that name → nothing created, the name skipped;
  - a name from an unlisted country with no match → skipped, counted;
  - never touches `manual` links or other sources' links; removes only `livesoccertv` links the page no longer lists; an editor-hidden link stays hidden and isn't re-added.
- [x] T056 [P] [US3] `backend/tests/adapters/test_messages_v2.py`: `ScrapeResult` v2 with `kind = "broadcasts"` round-trips; v1 messages still validate; an unknown version is rejected loudly.
- [x] T057 [P] [US3] `backend/tests/adapters/test_health.py` ([R17](research.md#r17-source-health-breaker-and-zero-items-alarm)): a failed run increments `consecutive_failures`; a success with items resets it and sets `last_success_at`; reaching `SOURCE_BREAKER_THRESHOLD` sets `breaker_opened_at` and sends one alert; zero items with pages or targets counts as a failure and alerts once per Cairo day (`last_zero_alert_on`); the alert text names the source; every `record_run` bumps the `sources` dataset in the same transaction, so A13's `ETag` changes after each run.
- [x] T058 [P] [US3] `backend/tests/adapters/test_schedule_fetch.py`: a paused source (`is_enabled` false, breaker open, or `paused_until` in the future) is skipped unless `manual=True`; ysscores and legacy go to their configured queues; livesoccertv plans first; the beat schedule has every entry of [contracts/pipelines-and-ops.md](contracts/pipelines-and-ops.md#beat-entries-after-d3-utc) and none calls `adapters.fetch` directly.
- [x] T059 [P] [US3] `backend/tests/adapters/test_alerts.py` and `test_heartbeat.py`: `send_alert` posts to `api.telegram.org` only, with a 5 s timeout, logs and swallows errors, and only logs without the settings; `ops.heartbeat(queue)` GETs its Kuma URL and is a no-op without it.
- [x] T060 [P] [US3] `backend/tests/adapters/test_ingest_log.py`: ingest writes the compact run log to `import_runs.log` (≤ 64 KB, lists truncated with a count), alongside `run.json`.

### Adapters (B2)

- [x] T061 [US3] `backend/app/adapters/livesoccertv.py`: the `SourceAdapter` with `allowed_hosts = {"www.livesoccertv.com"}`, 1 request / 4 s per host through D2's rate limiter, fetch per target (team page → match page), pure `parse`, `LayoutChanged` on missing tables. T052, T054 pass.
- [x] T062 [US3] `backend/app/adapters/livesoccertv_links.py`: the port of `saveChannelsToMatch` (`../old_app/public/LVS.html` lines 861–930) with `normalizeCountry` / `countriesMatch`, placeholders, and D2's link rules, writing only through D1/D2 models (no change to B1's services). T055 passes.
- [x] T063 [US3] `backend/app/adapters/messages.py`: `ScrapeResult` v2 (`kind`, `targets`, broadcast items, `unmatched`), still reading v1. T056 passes.
- [x] T064 [US3] `backend/app/adapters/tasks.py`: `adapters.schedule_fetch(source, manual=False, window="default")` (pause check, LiveSoccerTV planning, send to the fetch queue); `adapters.fetch` takes `targets`; `adapters.ingest` handles `broadcasts` through `livesoccertv_links`, writes `import_runs.log`, and calls `health.record_run` in its transaction; `ops.heartbeat(queue)`. Extend `IngestionRouter` for the LiveSoccerTV fetch queue. T053, T058, T060 pass.
- [x] T065 [P] [US3] `backend/app/adapters/health.py` (`record_run`, breaker, zero-items, and the `sources` dataset bump through B1's `bump_datasets`) and `backend/app/adapters/alerts.py` (`send_alert` through the D2 fetcher with `api.telegram.org` allowlisted). Extend `_source_is_paused` with `breaker_opened_at`. T057, T059 pass.
- [x] T066 [US3] `backend/app/adapters/schedule.py`: every entry through `adapters.schedule_fetch`, plus `livesoccertv-48h`, `livesoccertv-t60` and the three `heartbeat-*` entries, as [contracts/pipelines-and-ops.md](contracts/pipelines-and-ops.md#beat-entries-after-d3-utc). T058 passes.
- [x] T067 [US3] Run `uv run pytest tests/adapters --cov=app/adapters` and the whole backend suite; coverage on `app/adapters` ≥ 70 %.

### After the 13:00 merge (B2)

- [x] T068 [US3] Rebase on `master` (T014): `0005`'s columns exist; the health and placeholder tests run against them.
- [x] T069 [US3] Confirm `api-admin`'s `send_task("adapters.schedule_fetch", …)` reaches `worker-imports` on VPS-2 (the name and queue match `tasks.py`); add a test that the registered task name is exactly `adapters.schedule_fetch`.
- [x] T070 [US3] Confirm `app.workers` loads both schedule modules with no duplicate entry names (`celery -A app.workers inspect registered` in `dev.yml`).
- [x] T071 [US3] Add a `livesoccertv_teams` check to the snapshot data: count mapped teams and log the top unmapped teams of the next 48 h in the first run's log, so the owner sees the coverage.
- [x] T072 [US3] Write `docs/runbooks/imports-and-sources.md` additions: LiveSoccerTV (what it reads, its queue, the country list and how to change it, placeholders and how editors complete or delete them), the breaker and zero-items alarm, pause / resume / run now in A13, and moving its fetch between the home box and VPS-2.

### Hosts and pipelines (B2)

- [x] T073 [P] [US3] `infra/backup/Dockerfile` (arm64: `restic`, `rclone`, `postgresql-client-16`, `curl`), `infra/backup/backup-db.sh` (`pg_dump -Fc` over the VCN to `/srv/backup`, `restic backup`, `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`, Kuma push up or down with the error) and `infra/backup/backup-media.sh` (`rclone sync /srv/media` to the OCI bucket; with `--weekly`, `restic backup /srv/media` and `forget --keep-weekly 4`). `set -euo pipefail`, no secret echoed, shellcheck clean ([R19](research.md#r19-backups)).
- [x] T074 [P] [US3] `infra/systemd/backup-db.{service,timer}` (03:00 Africa/Cairo, `Persistent=true`), `backup-media.{service,timer}` (03:30) and `backup-media-weekly.{service,timer}` (Sunday 04:00), each running `docker compose run --rm`.
- [x] T075 [P] [US3] `infra/compose/vps2.yml`: `uptime-kuma` (`louislam/uptime-kuma:1`, `/srv/kuma`, port 3001 on the VCN address only), `backup-db` (one-shot, profile `backup`, `/srv/backup`), and the D3 variables for the workers ([contracts/pipelines-and-ops.md](contracts/pipelines-and-ops.md#host-environment-added-on-d3)). `infra/compose/vps1.yml`: `backup-media` (one-shot, profile `backup`, `/srv/media` read-only).
- [x] T076 [P] [US3] `infra/Caddyfile`: on the `wg0` site, `handle_path /kuma/*` → `<VPS2_VCN_IP>:3001` with the security headers; nothing public. `infra/firewall/vps2.rules`: 3001/tcp from VPS-1's VCN address only. Validate with `caddy validate` and `infra/scripts/check-firewall.sh`.
- [x] T077 [US3] `infra/compose/vps2.yml`: `worker-notify` mounts `/srv/secrets/fcm.json` read-only and gets `FCM_CREDENTIALS_FILE`, `FCM_DRY_RUN`, `PWA_ORIGIN`; no other service mounts it. Add every D3 variable to `infra/compose/example.env` with an empty value.
- [x] T078 [US3] `infra/scripts/deploy.sh`: install and enable the systemd timers on each host (idempotent), create `/srv/backup`, `/srv/kuma`, `/srv/secrets` (mode 700); `infra/scripts/bootstrap-vps.sh` creates the same directories on a new host.
- [x] T079 [US3] `.github/workflows/backend.yml` (or `infra.yml`): build and push the `madar-backup` image for `linux/arm64` to GHCR on changes to `infra/backup/`, and validate the Compose files, the Caddyfile and the shell scripts on PRs.
- [x] T080 [US3] Run `docker compose -f infra/compose/vps1.yml config -q`, the same for `vps2.yml`, `shellcheck infra/scripts/*.sh infra/backup/*.sh` and `systemd-analyze verify infra/systemd/*`.

### Validation (B2)

- [ ] T081 [US3] Deploy: merge; the backend and backup images deploy; `ssh madar-vps2 docker compose ps` shows `uptime-kuma` and `worker-notify` healthy and one `beat`; the timers are listed by `systemctl list-timers` on both hosts.
- [ ] T082 [US3] Run [quickstart Lane B2](quickstart.md#lane-b2-livesoccertv-health-backups-monitoring) steps 2–5: a LiveSoccerTV run adds links and placeholders, a second adds none, an editor-removed link stays hidden, the breaker opens and alerts, the zero-items alert fires once.
- [ ] T083 [US3] Next morning, step 6: restic lists last night's snapshot in B2; `rclone lsd` shows the media copy; Kuma shows both backup heartbeats green (SC-004). Record the snapshot id in the PR.
- [ ] T084 [US3] Stop `worker-notify` for 10 min and confirm Kuma alerts on Telegram; start it again.
- [x] T085 [US3] Write `docs/runbooks/backups.md` (what is backed up, where, when, retention, the B2 10 GB watch, running a backup by hand, listing snapshots, where the monthly restore drill lives from D8) and `docs/runbooks/source-alerts.md` (the Telegram bot and chat, what each alert means, what to do). Every command must match the scripts.
- [x] T086 [US3] Write `docs/runbooks/uptime-kuma.md`: reaching it at `https://10.8.0.1/kuma/`, the first admin account, the exact monitors to create (four HTTP checks, six push monitors with their env variable names), the Telegram notification, and what each alert means. Add every D3 runbook to `docs/runbooks/README.md`'s setup order and "After setup" table, and the new variables to `docs/runbooks/secrets.md`.
- [x] T087 [US3] Add the D3 Lane B2 items to `docs/owner-actions.md` (before merge: create the Telegram bot and chat, the B2 bucket and key, the restic password, the OCI bucket and key; after merge: create the Kuma monitors, check the first LiveSoccerTV run and the first backup), each with its task ID and runbook link, and update the "Open now" table.

---

## Lane A

**Story (User Story 4, P4):** As an editor, I can maintain every MVP entity and see at a glance what today is missing.

**Independent test:** against the admin API over WireGuard: edit a team's logo and alias (A5); reorder competitions by mouse and keyboard (A6); reorder satellites and set Nilesat's best and worst frequency and video (A7); filter, edit in the drawer, add on another satellite and complete a placeholder (A8); upload and play a commentator clip (A10); pause, resume and run a source (A13); see the dashboard (A2) ([quickstart.md](quickstart.md#lane-a-admin)).

### Setup (A)

- [x] T088 [US4] Add `@dnd-kit/core` and `@dnd-kit/sortable` to `admin/package.json` (exact versions) and refresh the lockfile ([R22](research.md#r22-ordering-with-drag-and-keyboard)).
- [x] T089 [P] [US4] Add Arabic copy for the new `error.code`s (`run_in_progress`, `source_not_runnable`, `source_not_found`, `import_run_not_found`) and the new screens to `admin/src/i18n/`; never show `error.message`.

### Carry-over from 002 (A, first)

- [x] T090 [US4] **A-F1 (002 T106):** wire `zodResolver(patchMatchBody)` into `admin/src/features/matches/MatchEditor.tsx` so the one React Hook Form form resolves through the Orval schema instead of validating the assembled patch by hand. A4's behaviour and `MatchEditor.test.tsx` stay green. Tick 002's A-F1 when done.
- [x] T091 [US4] **A-F2:** move A3's table in `admin/src/features/matches/MatchesPage.tsx` onto the shared `DataTable` (grouping, bulk bar, skeleton, J/K/X/E keys) and delete the local markup. `MatchesPage.test.tsx` stays green. Tick 002's A-F2 when done.

### Tests and components first (A)

- [x] T092 [P] [US4] Write `admin/src/components/SortableList/SortableList.test.tsx` (see it fail), then build `SortableList` with `@dnd-kit`: drag handle, keyboard lift/move/drop with Arabic announcements, visible focus, disabled while saving, RTL; tokens only.
- [x] T093 [P] [US4] Write `admin/src/components/AudioPlayer/AudioPlayer.test.tsx` (see it fail), then build `AudioPlayer` on native `<audio>`: idle, playing, paused, error, loading; only one plays at a time across the page; visible focus ([R23](research.md#r23-a8s-editor-drawer-a10s-audio-and-a5s-logo-preview)).
- [x] T094 [P] [US4] Write `admin/src/components/KpiCard/KpiCard.test.tsx` (see it fail), then build `KpiCard` from its INDEX README (label with glyph, tabular figure, context, optional link), every README state.

### Screens (A)

Each screen is checked against its board in `madar-design/admin-react/SCREENS.md`; each gets a flow test against the generated MSW handlers written first and seen failing.

- [x] T095 [P] [US4] A5 Teams in `admin/src/features/teams/` (`TeamsPage.tsx`, `TeamEditor.tsx`, tests): `DataTable` with search and the competition and missing-logo filters; editor with name, aliases, logo upload previewed on dark and light tiles in the `Logo` frame, main and other competitions, stadium, external ids read-only; unsaved guard; `409` conflict dialog. No merge tool.
- [x] T096 [P] [US4] A7 Satellites in `admin/src/features/satellites/`: `SortableList` order (wired to the order endpoint in T101); editor with Arabic and English names, orbital position, best and worst frequency (MHz, H/V/L/R, symbol rate), reception video (`https` only, refused otherwise), logo.
- [x] T097 [P] [US4] A8 Channels in `admin/src/features/channels/`: `DataTable` with the satellite, category, access, missing logo, platform-only, shown-on-match-pages and placeholder filters; the editor drawer (focus trapped and returned, unsaved guard) with every field of PB A8; «إضافة على قمر آخر» prefilling `POST /channels` and showing `409 already_exists`; a placeholder shows a «يحتاج استكمال» marker, and completing it (satellite and frequency or platform, show on match pages) saves through PATCH.
- [x] T098 [P] [US4] A10 Commentators in `admin/src/features/commentators/`: table with photo, name and `AudioPlayer`; rename, replace photo or clip through D2's media upload; delete shows the usage count first and the `409 in_use` refusal.
- [x] T099 [P] [US4] A6 Competitions in `admin/src/features/competitions/`: `SortableList` with drag and keyboard; editor with name, aliases and logo.

### After the 13:00 merge (A)

- [x] T100 [US4] Rebase on `master` (T014) and build on the regenerated client; replace any local placeholder types with the generated ones.
- [x] T101 [US4] Wire A6 and A7 ordering to `PUT /competitions/order` and `PUT /satellites/order` with each row's version; a `409` opens the D2 conflict dialog and reloads; tests for both paths.
- [x] T102 [US4] A13 Sources in `admin/src/features/sources/` (`SourcesPage.tsx`, `SourceRunPage.tsx`, tests): a card per source with status, last success, an items sparkline, error rate and breaker `StatusChip`; «تشغيل الآن» (disabled while running, `409 run_in_progress` toast), «إيقاف» / «استئناف»; run history with cursor and the run detail (counts, errors, log, placeholders created, unmatched matches). React Query refetch every 30 s while visible ([R24](research.md#r24-a13-and-a2-refresh)).
- [x] T103 [US4] A2 Dashboard in `admin/src/features/dashboard/`: `KpiCard`s for matches without channels, placeholders to complete and source health; the missing-channels list by competition linking to A4; source tiles linking to A13; recent changes. Refetch every 60 s while visible.
- [x] T104 [US4] Add A2, A5–A8, A10 and A13 to `SidebarNav` and the router, with A2 as the landing page after login.
- [x] T105 [US4] Run `pnpm typecheck && pnpm lint && pnpm test && pnpm build && ./scripts/check-literals.sh && ./scripts/check-token-copy.sh`.

### Validation (A)

- [ ] T106 [US4] Walk [quickstart Lane A](quickstart.md#lane-a-admin) steps 1–8 with `pnpm dev:wg` against VPS-1 (needs B1's T047 deploy), including the two-browser reorder conflict and the keyboard-only reorder.
- [ ] T107 [US4] Take screenshots at 1440 and 1024 against `Main.png`, `Teams.png`, `Competitions.png`, `Satellites.png`, `Channels.png`, `Commentators.png`, `Sources.png` and `SourceRun.png`, in the theme each board uses, and attach them to the PR.
- [x] T108 [US4] Add the D3 Lane A items to `docs/owner-actions.md` (after merge: the editor walk-through over WireGuard), each with its task ID, and update the "Open now" table.

#### Notes from the implementation (Lane A, 2026-11-01)

Not review findings: three contract gaps found while building, each needing Lane B1 and none worked around by inventing behaviour.

- **`aliases` on teams and competitions.** The spec's US4 scenarios have A5 and A6 edit aliases, but D2's `AdminTeam`/`TeamCreate`/`TeamPatch` and the competition schemas carry no alias field, and the D3 contract says "no change". The editors ship without it (owner's decision on the day); the alias table is D5's.
- **No per-row version on the competition and satellite lists.** `PUT /competitions/order` and `PUT /satellites/order` require `if_match` per item, but `AdminCompetition` and `AdminSatellite` carry no `etag` (unlike `AdminMatchRow`, A-F3). T101 reads each moved row's version from its detail immediately before the reorder, so a change between the list render and the save is not detected; adding `etag` to both rows closes it.
- **`ChannelPatch` has no `kind`.** `contracts/admin-api.md` says a placeholder "moved to `kind: satellite`" saves through `PATCH /channels/{id}`, but the patch model omits `kind`. A platform placeholder can therefore gain a satellite and frequency but cannot become a satellite channel; the importers' placeholders are `platform` (R18), so completing one needs `kind` in the patch.

A4: `GET /commentators` has only `q` and a cursor, so A10 ships the search alone and not the board's «بلا صورة» / «بلا صوت» filters; adding them is a contract change with a list filter each.

Two test fixtures were updated for the contract change rather than weakened: the `GET /sources` handlers now answer `SourceHealth` (health fields), and the channel fixtures carry `placeholder_source`. A3's group-header query moved from `rowheader` to `columnheader` because the shared `DataTable` marks its group row with `scope="colgroup"`, and its lock glyph is now named by the table.

---

## Lane M

**Story (User Story 2, P2):** As a new user, I set up my teams and dish once and start getting reminders.

**Independent test:** on a fresh Android install, S1.1–S1.4 (theme, two teams, Nilesat and Hotbird, allow) → S9 shows both teams; quitting at S1.2 resumes there; a test match for a followed team gives a reminder that opens S3; on an iPhone (iOS ≥ 16.4) the install guide shows in Safari, and after installing, a test push arrives; airplane mode shows the offline banner; a raised `min_supported_build` shows the forced update ([quickstart.md](quickstart.md#lane-m-app)).

### Setup (M)

- [x] T109 [US2] Add `firebase_core`, `firebase_messaging`, `firebase_remote_config`, `firebase_crashlytics`, `flutter_secure_storage` and `share_plus` to `app/pubspec.yaml` (versions compatible with the pinned Flutter) and run `flutter pub get` ([R25](research.md#r25-firebase-in-the-flutter-app)).
- [x] T110 [P] [US2] Add the Firebase options (public identifiers: `apiKey`, `appId`, `messagingSenderId`, `projectId`, `authDomain`, `storageBucket`, per platform) and the public VAPID key to `app/env/{dev,staging,prod}.json`, read through `app/lib/core/config/app_config.dart`; `Firebase.initializeApp(options: …)` in each `main_*.dart`. No `google-services.json`; no private key anywhere.
- [x] T111 [P] [US2] Add the D3 ARB strings to `app/lib/l10n/` (onboarding, S9, S15, S16, S0, the follow and bell actions, and the new `error.code`s `rate_limited`, `unknown_follow_target`, `too_many_follows`, `unknown_satellite`), following PB §14's voice.
- [x] T112 [US2] Add drift schema v3 to `app/lib/core/db/app_database.dart` (`app_settings`, `follows`, `sync_state` exactly as [data-model](data-model.md#drift-app-schema-v3-lane-m)) with the v2 → v3 migration, regenerate, and add a migration test in `app/test/core/db/`.

### Tests first (M): write them and see them fail

- [x] T113 [P] [US2] `app/test/features/onboarding/onboarding_controller_test.dart`: steps advance and go back; skip marks done; the step survives a restart (drift); done → never shown again; a step reopened from S15 doesn't reset `onboarding_done`.
- [ ] T114 [P] [US2] **Blocked on T014 (B1's `d03-b1`): the app has no generated `/v1/devices` operation yet. The local half is built and tested in `test/features/devices/push_token_sync_test.dart` (secure storage, the token → `sync_state.device` flag, and the `Authorization: Device` rule).** `app/test/features/devices/device_repository_test.dart` ([R27](research.md#r27-onboarding-state-device-registration-and-follow-sync)): the device header goes on every `/v1` request once a token exists and never to the media host; first launch registers once and stores the token and install id in secure storage (fake); a `401` re-registers with the same install id; push token, settings and satellite changes send `PUT /devices/me`; a failure sets `sync_state.device.dirty` and retries on resume.
- [ ] T115 [P] [US2] **Blocked on T014 for the send half; the device's own set is built and tested in `test/features/follows/follows_repository_test.dart` (writes drift at once, flags `sync_state.follows`, the last full set wins).** `app/test/features/follows/follows_repository_test.dart`: toggles update drift at once and send the full set; a failed send keeps the local set and retries on launch, resume and reconnect; the last full set wins; a `422 unknown_follow_target` drops those ids locally.
- [x] T116 [P] [US2] `app/test/core/config/remote_config_test.dart` ([R28](research.md#r28-remote-config)): bundled defaults when the fetch fails; `api_base_url` / `media_base_url` accepted only as `https` without userinfo; `min_supported_build` above the build → forced update; `live_poll_interval_s` reaches the live poller.
- [x] T117 [P] [US2] `app/test/core/config/media_image_test.dart`: the image helper loads only from the active media host and shows the placeholder for any other URL.
- [x] T118 [P] [US2] `app/test/core/platform/push_service_test.dart`: a token is sent once per change; a message's `data.route` opens the route through go_router; on web, the permission prompt is requested only from a user action; on iOS Safari not standalone, `canRequestPermission` is false.
- [x] T119 [P] [US2] `app/test/features/system/system_screens_test.dart` ([R29](research.md#r29-s0-and-the-offline-banner)): no connection with nothing cached → the no-connection screen with «إعادة المحاولة»; server error with nothing cached → load failed; offline with a cache → the banner with the age; back on a root tab → the exit snackbar, a second back exits.
- [x] T120 [P] [US2] `app/test/features/favorites/favorites_screen_test.dart`: «مبارياتي القادمة» shows the next 3 matches of followed teams and matches; the Teams section lists followed teams with remove; no Competitions, Channels or Commentators section is shown (their follow actions arrive with S8 on D5 and later); remove unfollows; the empty state with «أضف فرقاً».
- [x] T121 [P] [US2] `app/test/features/settings/settings_screen_test.dart`: time zone (automatic or GMT−12 … GMT+14), 12/24 h, theme, font scale 1.0 / 1.15 / 1.3, my satellites apply app-wide; «حذف بيانات جهازي» asks first, calls `DELETE /devices/me`, clears drift and secure storage and returns to S1.1.
- [x] T122 [P] [US2] `app/test/features/match_detail/follow_action_test.dart`: S3's no-channels state shows «تابع المباراة» and follows the match; the «حدد أقمارك» chip shows while the default satellites apply and opens S15's satellites.
- [x] T123 [P] [US2] `app/test/features/onboarding/teams_step_test.dart`: «الاهلي» and «الأهلي» give the same results (D1's Arabic normalization in the query); groups by competition with popular first; the tray collects chosen teams.
- [x] T124 [P] [US2] Goldens in `app/test/goldens/` for every new component ([contracts/app-screens.md](contracts/app-screens.md#components-built-once-under-their-index-names)) in RTL, both themes, 1.0× and 1.3×.
- [x] T125 [P] [US2] `app/test/architecture/` additions: feature code never imports `firebase_messaging`, `firebase_crashlytics` or `flutter_secure_storage` directly (only `core/platform/` and `core/config/`).

### Implementation (M)

- [x] T126 [P] [US2] Build the new components in `app/lib/design/components/` under their INDEX names: `list_row.dart` (`ListRow`), `button.dart` (follow and bell variants), `dialog.dart` (`MadarDialog`), `banner.dart` (`OfflineBanner`, `MadarSnackbar`), `form_controls.dart` (toggle, radio, checkbox), `progress_dots.dart`; tokens only, every README state. T124 passes.
- [x] T127 [US2] Platform adapters in `app/lib/core/platform/` with web no-ops chosen by conditional import: `push_service.dart` (permission, token, foreground and opened messages → go_router), `crash_reporter.dart` (Crashlytics on Android, no-op on web), `install_guide.dart` (standalone detection). T118, T125 pass.
- [x] T128 [US2] `app/web/firebase-messaging-sw.js` ([R26](research.md#r26-web-push-and-the-iphone-pwa)): pinned exact Firebase compat SDK version, the public web config, `onBackgroundMessage` with the `tag`, `notificationclick` opening `fcm_options.link`. Add it to `tool/check_web_assets.sh` so the web build ships it at the origin root.
- [x] T129 [US2] `app/lib/core/config/remote_config.dart` and the media image helper; route every `NetworkImage` / `CachedNetworkImageProvider` call through the helper (the eight sites from D2's security follow-up). T116, T117 pass.
- [x] T130 [US2] Onboarding in `app/lib/features/onboarding/` (S1.1–S1.5, controller, routes `/onboarding/:step` with the first-launch redirect) against `Onb-*.png`. T113, T123 pass.
- [x] T131 [US2] S9 in `app/lib/features/favorites/` (upcoming matches and the Teams section only; the Competitions, Channels and Commentators sections stay hidden until their follow actions exist), S15 core in `app/lib/features/settings/`, S16 in `app/lib/features/more/` (share through `share_plus`, the install row on the iOS PWA only), against their boards. T120, T121 pass.
- [x] T132 [US2] S0 in `app/lib/features/system/` (forced update before the shell, no connection, load failed, offline banner from a `ConnectivityState` provider fed by Dio, the exit snackbar with `PopScope`), against the `Sys-*` and `Matches-Banners` boards. T119 passes.

### After the 13:00 merge (M)

- [ ] T133 [US2] **Blocked: T014's contract has not merged, so there is no generated client for `/v1/devices`, `/v1/devices/me` or `/v1/follows`. Rebase once B1 merges, then build the network halves here.** Rebase on `master` (T014) and build `app/lib/features/devices/` and `app/lib/features/follows/` on the regenerated Dart client: registration on first launch, the `Authorization: Device` interceptor in `app/lib/core/network/` (on **every** `/v1` request once a token exists, so rate limits count per device and phones behind one carrier IP don't share a bucket; never on media or other hosts), `PUT /devices/me` (push token, app version, tz, locale, satellite ids, prefs), the follow sync with retry. T114, T115 pass.
- [x] T134 [US2] Wire my satellites (S1.3, S15) into the D2 ordering of S2, S3, S4 and S5 (replacing the fixed default once chosen), and S3's follow toggle, «تابع المباراة» and «حدد أقمارك». T122 passes.
- [x] T135 [US2] Run `flutter analyze`, `./tool/check_literals.sh`, `./tool/check_token_copy.sh` and `RTEST_HOST=flutter-tests rtest` (all tests and goldens on the test box; if the box is unreachable, report it and don't run locally).

### Validation (M)

- [ ] T136 [US2] **Owner.** On a real Android phone, walk [quickstart Lane M](quickstart.md#lane-m-app) steps 1–6, with B1 creating the test match for step 3; take screenshots of each screen in both themes against its PNG and attach them to the PR.
- [ ] T137 [US2] **Owner.** On a real iPhone with iOS ≥ 16.4, step 7: the install guide in Safari, then install, allow and receive the reminder in the installed PWA; record the iOS version and a screenshot (delivery-plan §10 risk).
- [x] T138 [US2] Write `docs/runbooks/remote-config.md` (the keys, their bundled defaults, changing a host safely, raising `min_supported_build`) and add push setup to `docs/runbooks/store-releases.md` (the Android notification channel, the web VAPID key, the service worker, testing an iPhone PWA). Add both to `docs/runbooks/README.md`.
- [x] T139 [US2] Add the D3 Lane M items to `docs/owner-actions.md` (before merge: create the web push VAPID key and Remote Config parameters; after merge: the phone and iPhone walk-throughs, a closed-test build), each with its task ID and runbook link, and update the "Open now" table.

---

## Done check

A kickoff reminder arrives on Android and on an installed iPhone PWA; LiveSoccerTV adds channels to upcoming matches; all MVP admin entities editable; one nightly backup completed; onboarding → follow → favorites works

How it is checked ([quickstart.md](quickstart.md#done-check-spec-sc-009)):

1. **Reminders:** a test match for a followed team gives one reminder, naming a channel on the device's satellites, on a real Android phone and on an installed iPhone PWA, 3 times out of 3 (SC-001; M's T136–T137, B1's T047).
2. **LiveSoccerTV:** an unattended run has added `livesoccertv` links to upcoming matches, and a second run added none (SC-003; B2's T082).
3. **Admin entities:** matches (D2), teams, competitions, satellites, channels and commentators each saved from the admin, visible in the app within 60 s (SC-006; A's T106).
4. **Backup:** last night's restic snapshot is listed in B2 (SC-004; B2's T083).
5. **Onboarding → follow → favorites:** a fresh install reaches favorites with its teams in under 2 minutes (SC-007; M's T136).
