# Implementation review: 003-d03-follow-push-sources, lane B1, round 1

- Date: 2026-11-01 · Reviewer: Claude Sonnet 5.5 (lead) with two Sonnet 5.5 layer reviewers (api/db/security, run twice; spec/tests). The lead re-opened every CRITICAL and HIGH finding and reproduced the probe-backed ones; MEDIUM and LOW findings are the reviewers' own, marked CONFIRMED when a reviewer reproduced or read them and PLAUSIBLE when only running would settle them.
- Branch: 003-d03-follow-push-sources (all four lane PRs merged; no lane branch was checked out, at the owner's request) · Base: origin/master (merge base 5323669) · Head: 8405dd2, plus 0 uncommitted files
- Change: B1's commits `23603f5` (devices, reminders, response cache and admin sources) and `bfa1774` (gitleaks allowlist), merged by PR #16; 94 files owned by B1 (+18,864 −139) per the scope script, of which 26 are `backend/tests/adapters/**` and `tests/fixtures/livesoccertv/**` that tasks.md assigns to B2. 3 files are in another lane's folders (see Outside this change).
- Verdict: **BLOCK** · CRITICAL 1 · HIGH 5 · MEDIUM 18 · LOW 17

## Checks

| Check | Command | Result |
| --- | --- | --- |
| ruff | `cd backend && uv run ruff check .` | exit 0, "All checks passed" |
| mypy | `uv run mypy --strict app` | exit 2 on this machine: a stray `/mnt/endeavour/home/saied-dev/__init__.py` makes mypy read the repo path as a package (environment, not code) |
| mypy, workaround | `MYPYPATH=$PWD uv run mypy --strict --explicit-package-bases app` | exit 0 |
| pytest, default settings | `uv run pytest -q` | exit 1: 857 errors, all `password authentication failed for user "postgres"` / Redis `Authentication required`. The test defaults (`postgres:postgres`, Redis without password) do not match `infra/compose/dev.yml` (`madar:changeme`, Redis `requirepass`); CI sets its own services. Environment, see Outside this change |
| pytest, dev-stack credentials | `TEST_DATABASE_URL=postgresql://madar:changeme@localhost:5434/postgres TEST_REDIS_URL=redis://:changeme@localhost:6380/0 uv run pytest --cov --cov-report=term-missing -q` | exit 1: 1,292 passed, 4 failed. The 4 are `tests/adapters/test_homebox_acl.py` (D2's; needs a Redis started with the home-box ACL, as CI does; the dev Redis has `requirepass` only). Coverage 93.62 % (gate 70 %): `app/devices` 76–100 %, `app/notifications/dispatcher.py` 97 %, **`sender.py` 49 %, `tasks.py` 32 %** |
| Contract in sync with code | `tests/contract/test_committed_contract_matches_app` (inside the pytest run) | passed |
| Migration 0005 up/down | `tests/db/test_migrations.py` (inside the pytest run) | passed |
| Reviewer probes | `scratchpad/probe/test_probe_b1.py` (lead re-ran) and `test_probe_b1_admin.py` (reviewer) | reproduced: cancelled reminder stays cancelled after a reschedule; an empty token raises `ValueError('Message.fid must be a non-empty string.')`; a message-level `INVALID_ARGUMENT` is classified as a dead token; a late message reads «بعد دقيقة» for a match 45 min old; `GET /sources` answers 304 while `running` has changed; `resume` queues a run for `manual`; a no-op reorder bumps `competitions` |
| `export-openapi && git diff --exit-code openapi/` | not run | NOT RUN: needs the full settings set; the in-pytest contract test above covers the same staleness |
| Generated clients regenerate with no diff | not run | NOT RUN: `pnpm orval` and `dart run swagger_parser` + `build_runner` rewrite tracked files, and this review is read-only on code |

Ways around the checks: none found. No new `skip`/`xfail`/`.only`; no ruff or mypy config change (only `ignore_missing_imports` for `firebase_admin`); `fail_under = 70` unchanged and the coverage `source` list gained `app/devices` and `app/notifications`. New `# type: ignore[no-untyped-call]` ×4 on identical `aioredis.from_url` helpers and `# noqa: BLE001` ×9 are narrow and commented (LOW, below).

## Previous round

Round 1: none.

## Findings

### CRITICAL

#### B1-R1-1: One empty push token blocks every reminder, indefinitely
- Layer: security/pipelines · Source: constitution V (validate at the boundary), VII (idempotent, observable push); FR-003, FR-007; spec edge "two dispatchers or a retried task" · `backend/app/schemas/public.py:457`, `backend/app/notifications/dispatcher.py:95`, `backend/app/notifications/sender.py:94-99`, `backend/app/notifications/dispatcher.py:113-115` · CONFIRMED (code read, probe reproduced)
- Problem: `DeviceUpdate.push_token` has `max_length=4096` and no minimum, so `""` is accepted and stored (`devices/service.py:79` only treats `None` as "clear"). The audience filter is `push_token IS NOT NULL`, so the empty string is in every audience. firebase-admin 7.7.0 raises `ValueError` while encoding that message, which `send_page` turns into `Retryable` for the whole page. `dispatch_due` then releases only the failing row (`_RELEASE`), so the retry never ends: after the retries are used up `mark_failed` runs against `status = 'sending'`, but the row is already `pending` again, so it matches nothing (`_MARK_FAILED`, `dispatcher.py:113`).
- Failure scenario: anyone registers a device (open endpoint, 30 per 10 min per IP), sends `PUT /v1/devices/me {"push_token": ""}` and follows a popular competition. For every match of that competition the page that contains this device fails whole. The row stays `pending` and is always the oldest due row; each minute `claim` takes it with up to 9 later rows, `break` leaves those 9 in `sending` for 10 minutes (`STUCK_AFTER`), they are reclaimed and queue behind it again. Reminders with a later `due_at` do not go out until someone edits the database by hand. The app never sends an empty token, so only a hostile or buggy client triggers it, and `FakePushSender` never validates tokens, so no test sees it.
- Fix direction: validate at the API (non-empty, no NUL), exclude empty tokens in the audience query, encode each message on its own in `FcmSender` so one bad device counts as `failed` instead of failing the page, and release every claimed-but-unprocessed row when a page fails. Task `B1-R1-1`.

### HIGH

#### B1-R1-2: Any FCM `INVALID_ARGUMENT` wipes the push tokens of the whole page
- Layer: pipelines/db · Source: FR-007, research R7, constitution II · `backend/app/notifications/sender.py:122-131`, `backend/app/notifications/dispatcher.py:111,234-235`, `backend/app/settings.py` (`PWA_ORIGIN`) · CONFIRMED mechanism (probe: `InvalidArgumentError("webpush.fcm_options.link must be an https URL")` returns True from `_is_unregistered`); trigger PLAUSIBLE until a real send
- Problem: `_is_unregistered` returns True for `code == "INVALID_ARGUMENT" or "INVALID_ARGUMENT" in str(exc)`. FCM uses that code for bad message fields as well as bad registration tokens. The dispatcher then runs `UPDATE devices SET push_token = NULL` for every token marked this way and still ends the row `sent`.
- Failure scenario: `PWA_ORIGIN` is an `AnyHttpUrl`, so `http://…` is accepted. Every web reminder then fails with `INVALID_ARGUMENT` on `fcm_options.link`, and every web device loses its token. The app does not re-send an unchanged token (`push_token_sync.dart`: "repeating the same token does nothing"), so those devices stay silent until FCM rotates the token. The runbook's "it registers again the next time the app opens" is not true for this app. The owner's first real send is also the first time FCM sees the `fid` field (see Not reviewed), so a rejection there would wipe real tokens.
- Fix direction: clear a token only on `UnregisteredError`, or on an `INVALID_ARGUMENT` whose detail names the registration token; count everything else as `failed` and alert. Require `https` for `PWA_ORIGIN`. Task `B1-R1-2`.

#### B1-R1-3: A cancelled reminder is never revived, so a rescheduled match gets none
- Layer: pipelines · Source: FR-006, spec scenario 7 · `backend/app/notifications/scheduler.py:40-43` (`ON CONFLICT … DO UPDATE … WHERE notification_outbox.status = 'pending'`) with `_CANCEL` (`:46-56`) · CONFIRMED (code read; probe reproduced: after postponed → scheduled with a new kickoff the row stays `cancelled`)
- Problem: `_CANCEL` turns the row `cancelled` when the match is postponed, cancelled, TBD, or moves beyond 24 h. When the match qualifies again, the upsert hits the `cancelled` row and the guard skips it.
- Failure scenario: a followed match is postponed, then rescheduled with status `scheduled` and a new kickoff. Followers get no reminder. The same happens when a kickoff moves past 24 h and back, or a TBD match gets a time. No test covers it (`test_scheduler.py` asserts only the cancel).
- Fix direction: let the upsert reset a `cancelled` row that never sent back to `pending` with the new `due_at`; keep `sent` and `failed` final. Task `B1-R1-3`.

#### B1-R1-4: Exhausted retries never mark the row `failed`
- Layer: pipelines · Source: FR-007, data-model lifecycle ("retries exhausted → failed"), `docs/runbooks/push-notifications.md` ("after 5 retries the row is failed") · `backend/app/notifications/dispatcher.py:113,115`, `backend/app/notifications/tasks.py` (`dispatch_due`, the `mark_failed` call) · CONFIRMED (code read)
- Problem: `dispatch_due` releases the row to `pending` on every `Retryable` (`_RELEASE`); the task then calls `mark_failed` once retries run out, whose SQL requires `status = 'sending'`. It updates zero rows.
- Failure scenario: an FCM credential failure (wrong or unreadable `fcm.json`) leaves every due row `pending` for ever; beat re-claims them each minute and they fire hours later, with copy that says the match starts in 15 minutes. `dispatch_failed` is logged but no row ever shows as failed in A15.
- Fix direction: mark failed from the state the row is actually in, or count attempts on the row; then a row that cannot be sent stops being retried. Task `B1-R1-4`.

#### B1-R1-5: A late reminder tells followers a started match begins "in 1 minute"
- Layer: pipelines/api · Source: constitution II (NON-NEGOTIABLE, never present a guess or stale copy as fact); spec edge "a match whose kickoff has passed gets no reminder" · `backend/app/notifications/messages.py:99` (`max(int(round(…)), 1)`), `backend/app/notifications/dispatcher.py:29,184` (`DEAD_STATUSES`, `_cancelled`), `backend/tests/notifications/test_messages.py:88` · CONFIRMED (probe: kickoff 45 min ago → «⁨A⁩ × ⁨B⁩ بعد دقيقة»)
- Problem: at dispatch the row is skipped only for `postponed`, `cancelled` or `abandoned`. Nothing checks that kickoff is still ahead or that the match is not live or finished, and the minutes are clamped up to 1.
- Failure scenario: the worker or FCM is down for more than 15 minutes, or B1-R1-1/B1-R1-4 hold a row; when it goes out, followers get «بعد دقيقة» for a match already in play or finished. Under normal operation a row is at most about 11 minutes late, which is why this is HIGH and not CRITICAL.
- Fix direction: at dispatch (and in `_CANCEL`) cancel a row whose kickoff has passed or whose match is live or finished; never clamp a negative lead up to 1. Task `B1-R1-5`.

#### B1-R1-6: The real FCM path has no tests (a test-first area)
- Layer: tests · Source: FR-053 and T020 ("dispatcher batching and UNREGISTERED cleanup"), constitution Test-first · `backend/app/notifications/sender.py:90-131` (49 % covered), `backend/app/notifications/tasks.py` (32 %), `backend/tests/support.py:36,46` · CONFIRMED (coverage report; no test calls `send_page` or `_is_unregistered`)
- Problem: the only code that decides UNREGISTERED vs failed vs retry is unproven. `FakePushSender` raises `Retryable` for `UNAVAILABLE`, but the real `send_each` returns per-message errors, so the fake models a failure mode the real sender does not have. The three tasks in `tasks.py`, `mark_failed` and `prune_outbox` have no tests; B1-R1-1, -2 and -4 live exactly here.
- Fix direction: test `send_page` with a stubbed `messaging.send_each` returning a `BatchResponse` of `UnregisteredError`, `UnavailableError`, `InvalidArgumentError` and success; test the task layer including retry exhaustion; make the fake behave like the real one. Task `B1-R1-6`.

### MEDIUM

- **`GET /admin/api/sources` hides `running` behind a 304** (FR-011 "A13 and A2 never show a stale state"): `api/admin/sources.py:57` uses `ETag("admin_sources", ("sources",))` with no time bucket, while `services/admin/sources.py:113,120-135` reads the `lock:fetch|ingest:<name>` keys at request time. «تشغيل الآن» bumps, the task then takes the lock, and A13's next refetch with `If-None-Match` gets a 304 with `running` unchanged; `items_24h`, `error_rate_24h` and `paused` (via `paused_until`) also change with time. CONFIRMED by probe. Fix: a short time bucket like the dashboard, or bump when the lock is taken.
- **`resume` queues a manual run for sources that `run` refuses** (`api/admin/sources.py` `resume_source` calls `send_manual_run` unconditionally; `service.resume` never calls `check_runnable`). `POST /sources/manual/run` gives 409 `source_not_runnable`, `POST /sources/manual/resume` gives 200 and queues `['manual']`; B2's `adapters.schedule_fetch` then raises `ValueError("unknown source 'manual'")` (`adapters/tasks.py:657-658`). Same for `legacy` without the bridge, and a held lock is ignored. CONFIRMED by probe.
- **A no-op reorder still bumps datasets** (`services/admin/ordering.py:89`, unconditional `writer.bump_datasets`): a same-order `PUT /competitions/order` returned 200, `competitions` went 1 → 2, and no audit rows were written. `backend/CLAUDE.md`: "a write that changes nothing writes nothing"; every drop-in-place invalidates every public `matches` and `competitions` cache and ETag. CONFIRMED by probe.
- **Transient per-message FCM errors are never retried** (FR-007 "retries other failures with bounded backoff"): `sender.py:105-112` counts any non-UNREGISTERED per-message error as `failed` and `dispatcher.py:247` still ends the row `sent`. During an FCM 503 burst the whole audience loses its reminder, with an INFO log line only. CONFIRMED.
- **500 instead of 422 on odd input:** `FollowSet` (`schemas/public.py`) has no `ge`/`le` on ids and no per-list cap before the 500-total check, so `{"teams":[10**30]}` reaches asyncpg and returns 500; `app_version: "a\u0000b"` raises in Postgres (500). D1 has `ID_MAX` for this. CONFIRMED by reviewer probe.
- **A cache hit resets the key's TTL** (`api/cache.py`, `ResponseCacheMiddleware.dispatch`): the cached handler answers 200 with an ETag, so `store()` runs again. A hot key never expires, so the TTL no longer bounds staleness. CONFIRMED by probe (TTL 5 → 300 after one hit).
- **The cache key space is attacker-controlled** (`api/etag.py` hashes every query parameter): `?cb=<random>` makes a new `rc:` key per request at 600 req/min/IP, and Redis runs `--maxmemory-policy volatile-lru` (`infra/compose/vps1.yml:204`) shared with the Celery broker, `lock:` and `rl:` keys, so locks and limits can be the LRU victims. PLAUSIBLE.
- **The per-IP limit is bypassed by minting devices** (`api/ratelimit.py`): a verified token is counted only in `rl:d:*`, never in the IP bucket; the register window allows 30 devices per 10 min per IP. PLAUSIBLE.
- **Audit rows for pause, resume and run never name the source** (`services/admin/sources.py:174,186,211`: `add_audit(…, "source", None, "update", diff)`; the diff is `{'is_enabled': [True, False]}`); FR-011 "audited" and A2's `recent_changes` cannot say which source. `test_sources.py:60-61` asserts only the diff. CONFIRMED. Fix: put `{"name": [None, name]}` in the diff.
- **Dashboard splits one competition into duplicate groups** (`services/admin/dashboard.py:48` orders by priority, kickoff, id and groups on adjacency at `:55`): equal or NULL priorities with kickoffs A 10′, B 20′, A 30′ gave group ids `[3, 4, 3]`, which A2 would show twice and clash React keys. The query also has no status filter, so cancelled, postponed and finished matches count as "missing channels". CONFIRMED by probe.
- **Weak test: device satellites win over the default order** (FR-008, Clarification Q3): `test_messages.py:54-61` uses two non-default links on the same satellite; deleting the `if my_satellite_ids:` block (`messages.py:76`) leaves it green.
- **No end-to-end test of SC-002**: only scheduler ×2 and one `dispatch_due`; no test runs scheduler → dispatcher five times and asserts one send. No hole seen in the code.
- **Placeholder exclusion in the satellite routes is unproven** (T024): `tests/api/test_placeholders_hidden.py:13` has `with_satellite=False` and no caller passes `True`; the two `placeholder_source.is_(None)` additions in `services/satellites.py` can be removed without a failing test.
- **No integration test that two detail URLs do not share a cached body** (FR-009): only the unit test on `compute_etag(path=…)`; if `api/deps.py` stopped passing `path=request.url.path`, one match's body would be served for another.
- **`service.register` is check-then-insert on `install_id`** (`devices/service.py`): a concurrent first registration raises the unique violation (500). Use `INSERT … ON CONFLICT (install_id) DO UPDATE`. The `dv:` Redis set/delete also runs before commit, so the limiter can cache a rotated hash as valid for up to 10 min (limiter bucket only, not auth).
- **Edits outside B1's lane (FR-051), disclosed in the task notes:** `admin/src/features/matches/queries.ts` (Lane A; `SourceItem` → `SourceHealth` after regeneration; keeping `SourceItem` as an alias schema would have avoided it), `backend/app/adapters/{base,satair_bridge,tasks}.py` and `backend/tests/adapters/test_tasks.py` (B2; formatting only), `.gitleaks.toml` (root; narrow: one regex, four paths, `AND`).
- **Rollback to D2 exposes placeholders:** D2's `visible_link` has no placeholder filter and `downgrade()` drops `placeholder_source` but keeps the rows, so the "expand-only, D2 keeps running" claim fails once LiveSoccerTV has created placeholders. Add to the rollback runbook.
- **Runbook errors:** `push-notifications.md` says a device whose token was cleared "registers again the next time the app opens" (not true, B1-R1-2); it uses `scp -J ubuntu@10.8.0.1 … ubuntu@10.1.0.118` where the project rule is the `madar-vps2` alias.

### LOW

- `devices/follows.py` `load()` is dead code with a shared-list bug (`dict.fromkeys(_KINDS, [])`); also dead: `schemas/public.py:_check_tz`, `scheduler.seconds_until_due`, `REMINDER_LEAD`, `MAX_DUE_NOW`, `ScheduleReport.rows`.
- `/v1/devices*` 401, 422 and 429 responses carry no `Cache-Control: no-store` (FR-002 says every response); the envelope test checks 2xx only.
- `cache.TTL_S` keys `commentators`/`commentator_detail` do not match the route id `commentator`, so commentator detail is never cached (FR-009); TTLs also differ from SD §6.3.2 (harmless, versions are in the key).
- OpenAPI declares `429` only on the four device operations, though the limiter runs on all 14 `/v1` GETs ("one new error code on every path"); `too_many_follows` is listed in neither spec; `device_not_found` (the follows race) is not declared; `DELETE /v1/devices/me` is 204 with no envelope (as `contracts/public-devices.md` says, but D2's deletes answer 200 `{success: true, data: null}`).
- `lead_min` is accepted on any notification type (T006: only `kickoff_reminder`).
- A new Redis client is created per call (rate limit, cache lookup, cache store, `dv`), up to 4 connects per request; `# type: ignore[no-untyped-call]` is copy-pasted into 4 identical helpers.
- `follows` tests never cover the `channels` and `commentators` kinds, nor the soft-deleted-channel rule.
- `test_two_sessions_claim_disjoint_rows` would hang rather than fail if `SKIP LOCKED` were removed.
- T014 is still `[ ]` although PR #16 merged it (bookkeeping).
- Quickstart step 4 says "the logged message names the channel" but nothing logs title/body/tag; step 6 says `cache: hit`, the code logs `cache_hit`. Coverage is 93.54 % in the commit message and 93.49 % in tasks.md.
- Ordering lock order (`services/admin/ordering.py:43-47`): rows lock in client order, so two editors reordering overlapping rows in opposite orders can deadlock and get a 500 (PLAUSIBLE). Sort ids first.
- Ordering renumbers unlisted rows (`ordering.py:68-83`): every unlisted row with a non-null priority is rewritten and audited and its version changes, so another editor's open copy gets 409; `contracts/admin-api.md` says "rows not listed keep theirs".
- Ordering audit entity is `entity.rstrip("s")` (`ordering.py:86`), so rows say `competition`/`satellite` while every other writer uses the plural; an entity-history query misses them and the test pins the singular.
- `run` and `resume` call `send_task` after `commit()` and do not handle a broker error: state and audit are saved and the client gets a 500.
- `health()` (`services/admin/sources.py:96-104`) loads full `ImportRun` rows including the 64 KB `log` JSONB for every run in 24 h per source, polled every 30 s by A13 and 60 s by A2; `defer(ImportRun.log)` would avoid it (PLAUSIBLE).
- The role-walk test still asserts `>= 36` routes after D3 added 8 (the walk is generic, so the new routes are covered).

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| AS1 register, rotate, hash only | `devices/service.py:register`, `tokens.py` | `devices/test_register.py` | Built; concurrent first registration races (MEDIUM) |
| AS2 device auth, 401, own device only | `devices/auth.py` | `devices/test_auth.py` | Built |
| AS3 update, token moves between devices | `devices/service.py:update` | `devices/test_update.py` | Built; **empty `push_token` accepted (B1-R1-1)** |
| AS4 atomic follow replace | `devices/follows.py` (row lock) | `devices/test_follows.py` incl. concurrent PUTs | Built; `channels`/`commentators` kinds untested |
| AS5 one row per match, one send | `notifications/scheduler.py`, `dispatcher.py` | `test_scheduler.py` (×2 → one row), `test_dispatcher.py` | Built; end-to-end SC-002 untested |
| AS6 claim, DISTINCT audience, ≤ 500, UNREGISTERED cleanup | `dispatcher.py`, `sender.py` | `test_dispatcher.py` (fake sender only) | **Partial: real FCM mapping untested and wrong (R1-2, R1-6)** |
| AS6 title, body, tag, route | `notifications/messages.py` | `test_messages.py` | Built and matches PB §11 (deliberate Arabic number agreement, R8); satellite precedence weakly tested; late copy wrong (R1-5) |
| AS7 kickoff moves / TBD / postponed / cancelled | `scheduler.py:_UPSERT/_CANCEL` | `test_scheduler.py` | **Partial: no revival (R1-3)** |
| AS8 cache hit, invalidate on write | `api/cache.py`, ETag hook | `test_cache.py` | Built; TTL refreshed on hit (MEDIUM) |
| AS9 429 per IP and per device | `api/ratelimit.py` | `test_ratelimit.py` | Built |
| FR-006 scheduler cadence | `notifications/schedule.py` (5 min), `workers/__init__.py` | `test_workers.py` | Built |
| FR-007 retry and failure | `dispatcher.py`, `tasks.py` | none for tasks | **Partial: retries never end in `failed` (R1-4)** |
| FR-009 response cache by dataset versions | `api/cache.py`, `api/etag.py` | `test_cache.py`, `test_etag.py` | Built |
| FR-010 rate limits | `api/ratelimit.py` | `test_ratelimit.py` | Built |
| FR-011 admin sources, dashboard, ordering, placeholder filters | `services/admin/{sources,dashboard,ordering}.py` | `tests/admin/*` | Built and audited with `If-Match`/409/428; stale 304 on `running`, audit lacks source name, no-op reorder bumps (MEDIUM) |
| FR-012 settings, no secret defaults | `settings.py` | config only | Built |
| FR-053 test-first areas | see rows | auth, atomic follows, scheduling, DISTINCT audience, copy, cache, limits, reorder 409 | **Partial: FCM sender and tasks untested** |
| FR-054 coverage ≥ 70 % MVP bar | `pyproject.toml` | pytest run: 93.62 % | Built |

## Task audit

Ticked 46 (T001–T013, T015–T044, T046, T048, T049), verified 43, not done 0, partly done 3.

| Task | Mismatch |
| --- | --- |
| T020 `[x]` | "dispatcher batching and UNREGISTERED cleanup" is tested only against a fake sender; the real `FcmSender` mapping has no test (B1-R1-6). |
| T022 `[x]` | The scheduler test asserts the cancel but not the revival of a rescheduled match (B1-R1-3). |
| T036 `[x]` | The dispatcher ends rows `failed` by a statement that cannot match (B1-R1-4). |
| T014 `[ ]` | Merged as PR #16; bookkeeping only. |
| T045, T047 `[ ]` | Honestly open: need the local stack with a real FCM registration and the deployed worker plus the owner's key. |

## Owner must review

- `backend/openapi/public.json` (+644) and `backend/openapi/admin.json` (+2,452): the contract diff. Against the D3 merge base it is additive only (3 new public paths; 8 new admin operations; `SourceItem` → `SourceHealth`, a subclass, so the wire is a superset).
- `backend/alembic/versions/0005_devices_outbox_sources.py`: expand-only, reversible (the rollback caveat above).
- `backend/app/notifications/dispatcher.py:91-107` (`AUDIENCE`): the push audience query. It is a single `SELECT DISTINCT` with bound parameters; read it with B1-R1-1 in mind (empty tokens are in it).
- `backend/app/notifications/sender.py` and `backend/app/devices/auth.py`: FCM error handling and device-token auth.
- `backend/app/api/ratelimit.py` and the three limits in `settings.py` (120 per device, 600 per IP, 30 per 10 min to register).

## Outside this change

- Test defaults in `backend/tests/conftest.py` (`postgres:postgres`, Redis without password) do not match the documented dev stack (`infra/compose/dev.yml`: `madar:changeme`, Redis `requirepass`), so `uv run pytest` as `backend/CLAUDE.md` documents it fails locally until `TEST_DATABASE_URL` and `TEST_REDIS_URL` are set. CI is unaffected. No task; the owner may want one line in `backend/CLAUDE.md`.
- `tests/adapters/test_homebox_acl.py` (D2) needs a Redis started with the home-box ACL; it cannot pass against the dev Redis.
- `/mnt/endeavour/home/saied-dev/__init__.py` (outside the repo) breaks `mypy` package detection when run from this checkout path.
- Against the `contract-v1` tag, the 422 body of 10 public GET operations and 2 admin auth operations changed from `HTTPValidationError{detail}` to the envelope. That landed in D2; D3's own diff does not touch it.
- Cross-lane dependency: Lane A needs B1 to add `etag` to the competition and satellite list rows (see `A-R1-1`); that is a B1 contract change, to be raised by the owner.

## Not reviewed

- Whether FCM v1 accepts a registration token in the `fid` field of firebase-admin 7.7.0. The owner's dry run (`FCM_DRY_RUN`) should settle it before a live send; PB §11 against the live FCM payload needs the same dry run.
- Real FCM, the arm64 Docker build of `firebase-admin` (T001), Redis `maxmemory` behaviour on the host, uvicorn `--forwarded-allow-ips`, and whether `tests/contract/test_public_schema.py` stays green under the 30-per-10-min register limit.
- The generated clients byte-for-byte against the generators (NOT RUN, see Checks).
