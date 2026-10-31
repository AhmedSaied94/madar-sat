# Implementation review: 002-d02-core-flows, lane B1, round 2

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); layer subagents on Sonnet, every finding re-checked here
- Branch: `d02-features` · Base: `master` (merge base `68f1752`) · Head: `6f81c90` when reviewed, plus 106 uncommitted files (the round-1 fixes of B1, B2 and A). `3ac2bf5` has since committed Lane A's and Lane M's fixes; B1's files are still uncommitted and unchanged from what was reviewed.
- Change (lane B1, this round): no new commit. 32 tracked files under `backend/` outside the adapters (+607 −45) and 5 new ones (revision `0004`, `app/workers/logs.py`, three test files), the re-exported `openapi/{public,admin}.json` and the regenerated Orval client (T015 assigns both to B1). Nothing in another lane's folder.
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 1 · MEDIUM 7 (1 PLAUSIBLE) · LOW 6

Round 1's CRITICAL is fixed: the login limit is one atomic Lua step, proven against Redis under concurrency, and the other two HIGHs from round 1 are fixed too. One new HIGH remains, and it is a side effect of this round. The NUL guard on `/v1/teams?q=` adds a `pattern` to `public.json`, which the CI contract gate counts as a breaking change, so the `openapi` job fails. The other findings are smaller cache gaps in the new list ETags and two docs.

## Checks

Backend checks ran in a snapshot of this working tree (`git ls-files -co --exclude-standard`, so the uncommitted fixes are in it), against the dev PostgreSQL 16 (`:5434`) and Redis 7 (`:6380`).

| Check | Command | Result |
| --- | --- | --- |
| deps | `cd backend && uv sync --frozen` | exit 0 |
| ruff | `uv run ruff check .` | exit 0, clean |
| mypy | `uv run mypy --strict app` | exit 0, no issues |
| pytest + coverage | `uv run pytest --cov --cov-report=term-missing` | exit 0: 1068 passed, 1 skipped (`tests/db/test_migrations.py:150`, the `../old_app` schema hash; the sibling folder isn't in the copy, and the skip predates D2). Coverage 96.22 % (gate 70 %) |
| round 1's failing contract cases | round 1's Hypothesis example DB copied in, then `uv run pytest tests/contract/test_admin_contract.py tests/contract/test_public_schema.py` | exit 0: the stored NUL examples now get `422` |
| OpenAPI current | `uv run python -m app.cli export-openapi && git status --porcelain -- openapi/` (the `backend.yml` placeholder env) | exit 0, no diff |
| non-breaking vs `contract-v1` | `oasdiff breaking contract-v1:{public,admin}.json HEAD:{public,admin}.json --fail-on ERR` (`tufin/oasdiff:v1.35.0`, as `backend.yml:139-148` runs it) | **public: exit 1**, `request-parameter-pattern-added` on `GET /v1/teams` `q` (B1-R2-1). admin: exit 0 |
| migrations | fresh DB, `alembic upgrade head` (now to `0004`), then `compare_metadata(Base.metadata)` | upgrade ok; the same 74 diffs as round 1 and master (D1's partial models), nothing new from `0004` |
| admin client current | `cd admin && pnpm orval && git status --porcelain -- src/api/generated` | exit 0, no diff |
| Dart client current | `cd app && dart run swagger_parser && dart run build_runner build -d` with this checkout's `public.json` | exit 0, no diff (the `pattern` changes nothing in the Dart client) |
| api-admin command | `uv run gunicorn --check-config app.admin:app -k uvicorn.workers.UvicornWorker -w 1 -b 0.0.0.0:8001 --forwarded-allow-ips=10.8.0.1` | exit 0 |
| login reserve under concurrency | 12 concurrent `LoginLimiter.reserve` calls on one key against the dev Redis, then 7 sequential | 5 allowed of 12; sequentially 4, 3, 2, 1, 0 remaining, then two refusals |
| anonymous 304 | a probe test (deleted afterwards): an anonymous list GET with a matching `If-None-Match` | `401`, not `304` |
| secrets | `zricethezav/gitleaks:v8.30.1 git /repo --config /repo/.gitleaks.toml --redact --exit-code 1` over the snapshot | exit 0, no leaks |
| real `celery worker` start with the JSON formatter | | **NOT RUN**: `celery` is not on the lean-ctx shell allowlist. `app.log.setup()` in a fresh process was used instead |
| T047 on VPS-1 | | **NOT RUN**: nothing is deployed |

Ways around the checks: no new `skip`, `xfail` or config change. Four new suppressions (B1-R2-11).

## Previous round

| Finding | Now |
| --- | --- |
| B1-R1-1 CRITICAL login limit | **Fixed.** `limits.py:34-52` is one Lua `EVAL` (`ZREMRANGEBYSCORE`, `ZADD`, `ZCARD`, `EXPIRE`, then the lock at 5). `auth.py:197-205` reserves before the lookup, so unknown and real emails count the same, and a success clears both keys (`:217`). `test_login.py::test_parallel_wrong_logins_verify_at_most_five_passwords` fails on revert |
| B1-R1-2 HIGH NUL bytes | **Fixed** for every admin body (`schemas/admin.py:92-106,134-142`, a recursive `_Body` validator), the admin queries and the hidden-name path; `tests/admin/test_nul_inputs.py` fails without it. The public query guard causes B1-R2-1. A forged cursor still 500s (B1-R2-10) |
| B1-R1-3 HIGH list ETags | **Partly fixed.** Six routes now answer `304` (`tests/admin/test_list_etags.py`), with two new dataset rows in `0004`. Open: B1-R2-2, B1-R2-3, B1-R2-4 |
| B1-R1-4 HIGH create locks nothing | **Fixed.** `matches.py:142-157,301-305`; the API-create-then-`UpsertPipeline` test fails on revert. It weakened an older test (B1-R2-9) |
| B1-R1-5 hidden name bumps `channels` | **Fixed** (`writer.py:54-55`; the real `/v1/satellites` ETags are compared) |
| B1-R1-6 competition in-use | **Fixed** (`competitions.py:104-110`) |
| B1-R1-7 argon2 on the loop | **Fixed** (`auth.py:211,214`), on the default thread pool (B1-R2-6) |
| B1-R1-8 `ADMIN_JWT_SECRET` runbook | **Partly fixed.** The table row is right; the rotation steps still copy it to VPS-2 (B1-R2-5) |
| B1-R1-9 refresh lock and startup tests | **Fixed** (two real connections give `[200, 401]`; `tests/auth/test_admin_startup.py`) |
| B1-R1-10 ffmpeg demuxer | Still open: owner decision |
| B1-R1-11 to B1-R1-21 (LOW) | Still open, unchanged (`matches.py` lock reassignment, `lists.py:257` N+1, `decode_cursor`, `Minute`'s `\d`, bulk `channel_ids` cap, bulk 404/428 undocumented, hidden-name check-then-insert, `locks.py:27-28`, `+00:00`, `mkstemp` mode, two-tab refresh) |
| B1-R1-22 security-event logging | Still open |
| B1-R1-23 suppressions and test gaps | Still open, and four new suppressions (B1-R2-11) |
| B1-R1-24 T015 unticked, commit hygiene | Still open: T015 is `[ ]` (`tasks.md:166`); the round-2 work is uncommitted |

## Findings

### HIGH

#### B1-R2-1: the NUL guard on `/v1/teams?q=` fails the non-breaking gate against `contract-v1`
- Layer `api` · Source the CI job `openapi` (`.github/workflows/backend.yml:139-148`), constitution VI (`/v1` stays compatible), T015 ("public.json unchanged by D2") · `backend/app/api/public/teams.py:31` (`pattern=NO_NUL_PATTERN`), the same on `backend/app/api/public/satellites.py:39`; `backend/openapi/public.json` (two `pattern` additions) · CONFIRMED (oasdiff above)
- Problem: oasdiff reports `error [request-parameter-pattern-added] GET /v1/teams: added the pattern '^[^\x00]*$' to the query request parameter q`. A new pattern on a request parameter is treated as rejecting values that were accepted before.
- Failure scenario: the PR's `openapi` job exits 1 and the contract gate stays red. Round 1 recorded this gate as exit 0 for both specs, so this round made it fail.
- Fix direction: keep the guard at run time and out of the published schema. One option is an `AfterValidator` on `q` (it adds no `pattern` to the JSON schema). Another is one exception handler that maps asyncpg's `CharacterNotInRepertoireError` to the `422 validation_failed` envelope. Re-export `public.json`, check that it equals `contract-v1` for these routes, and re-run oasdiff. Keep `test_public_schema.py`'s NUL example green. If the owner wants the pattern in the schema, that is a contract decision (an oasdiff exception), not a lane call.

### MEDIUM

#### B1-R2-2: the commentator list answers a stale `304` after a match is given a commentator
- Layer `api` · Source constitution VI (an ETag from the datasets the response reads), B1-R1-3 · `backend/app/api/admin/commentators.py:34` (`ETag("admin_commentators", ("commentators",))`); the body's `usage` is read from `matches.commentator_id` and `match_channels` (`backend/app/services/admin/lists.py:257`, `services/admin/commentators.py:29-38`) · CONFIRMED (reproduced in the snapshot)
- Problem: a match PATCH that sets `commentator_id` bumps only `matches`, which the list's ETag doesn't include.
- Failure scenario: an editor assigns a commentator to a match. The commentator list still answers `304`, so every client that cached it keeps `usage.matches = 0` until some other commentator edit bumps the dataset.
- Fix direction: add `matches` to the list's datasets. Test: assign a commentator through the API, and expect the list ETag to change.

#### B1-R2-3: `rehost-media` writes preset logos without bumping `broadcast_presets`
- Layer `db` · Source B1-R1-3 (every write path bumps its dataset) · `backend/app/etl/media.py:63` (`"broadcast": (BroadcastPreset, None)  # admin-only picker, no public dataset`), `:190-192` (a `None` dataset is never bumped) · CONFIRMED by reading
- Problem: `GET /broadcast-presets` now has its own dataset (`0004`), but the only writer of `broadcast_presets.logo_asset_id` bumps nothing, and the comment is now false.
- Failure scenario: `load-snapshot` bumps every dataset, and then `rehost-media` sets the logos. An editor who opened A4 between the two runs keeps getting `304` with `logo: null` until something else bumps the dataset. Nothing does before A11 on D7.
- Fix direction: map `"broadcast"` to `"broadcast_presets"`, and test that `rehost-media` bumps it.

#### B1-R2-4: the six new `304`s and their `ETag` headers are not in the OpenAPI contract
- Layer `api` · Source constitution VI, FR-014 (the OpenAPI document is the contract), B1-R1-16 · `backend/openapi/admin.json`, GET on `/admin/api/{teams,channels,commentators,broadcast-presets,hidden-channel-names,sources}` · CONFIRMED (I listed each GET's responses: `200, 401, 403(, 422)`; `matches` and `satellites` declare `304`)
- Problem: the routes answer `304` and send `ETag`, but neither is declared.
- Failure scenario: Orval types the six responses as `200` only, so Lane A's pickers can't tell a `304` from a body without a cast, and the schema-based contract test can't check the `304` either.
- Fix direction: add `304: _docs.NOT_MODIFIED` and the `ETag` header doc to the six routes, as `matches` has them. Re-export, regenerate the clients, and run oasdiff (an added response is not breaking).

#### B1-R2-5: the `ADMIN_JWT_SECRET` rotation steps still copy the key to VPS-2
- Layer `ops` · Source FR-004, constitution V (least privilege), B1-R1-8 · `docs/runbooks/secrets.md:84-85` · CONFIRMED
- Problem: the corrected row (`:18`) says VPS-1 and `api-admin` only. The procedure below it says "put it … in VPS-2's `.env` (the media worker runs the same app)", then `dc up -d --force-recreate api-admin worker-media` and "re-run the VPS-2 deploy".
- Failure scenario: the owner follows the procedure and puts the admin signing key on a host that never verifies an admin token.
- Fix direction: VPS-1 only, and recreate `api-admin` only. No test (docs).

#### B1-R2-6: argon2 now runs on the shared 40-thread pool, with no bound of its own
- Layer `security` · Source constitution V (resource exhaustion) · `backend/app/api/admin/auth.py:211,214` · PLAUSIBLE (load not run)
- Problem: `anyio.to_thread.run_sync` uses the default limiter of 40 threads. Each hash is the RFC 9106 low-memory profile (64 MiB, p = 4). The login limit is per email and IP, so many distinct emails each get five attempts.
- Failure scenario: a WireGuard peer sends logins for many emails. Up to 40 hashes run at once, about 2.5 GiB, in the single-worker `api-admin` container (`infra/compose/vps1.yml`, `-w 1`). Before this round the hashes ran one at a time.
- Fix direction: a dedicated `anyio.CapacityLimiter` of 2 to 4 passed as `limiter=`, and a test that the fifth parallel hash waits.

#### B1-R2-7: the JSON log formatter writes whatever a library attaches, including a whole Celery task payload and httpx's full request URLs
- Layer `ops` · Source FR-027 and D15 (the old project's configuration lives only in VPS-2's host environment), constitution V; asked by Lane B2 (`b2-round-2.md` B2-R2-5 and B2-R2-19) · `backend/app/workers/logs.py:32-33` (every non-reserved record attribute is dumped), `:46` (the root logger at INFO) · CONFIRMED (B2's probes; I read the code)
- Problem: the formatter copies every `extra` attribute without a size cap. Celery's task-failure log attaches `data` with the task's `args` and `kwargs`. The root logger at INFO also lets `httpx` print `HTTP Request: GET <full URL>` for every request.
- Failure scenario: a failed `adapters.ingest` logs its whole `ScrapeResult` (up to 2 MB of pages and items) on one line; a 100 KB argument gave a 102,212-byte line. Every bridge request logs its URL, and that URL carries the old project's Firebase key (B2-R2-5).
- Fix direction: drop or truncate `data`, `args` and `kwargs`, and cap each field's length. Set the `httpx` and `httpcore` loggers to WARNING. Add tests for both.

#### B1-R2-8: `BroadcastPreset` has no `logo_asset_id`, so the editor can't keep a preset's logo
- Layer `api` · Source US4 scenario 6, FR-008; asked by Lane A (`a-round-2.md` A-R2-2) · `backend/app/services/admin/lists.py:267-270` (`BroadcastPreset(id, name, logo)`); `specs/002-d02-core-flows/contracts/admin-api.md:165` (`[{id, name, logo}]`) · CONFIRMED
- Problem: a slot saves `logo_asset_id`, but the preset list gives only the logo URL, so A4 has no asset id to save. Lane A works around this by sending the preset's own `id` (A-R2-2).
- Failure scenario: an editor picks «beIN SPORTS» for slot 1. A4 sends the preset id 3 as `logo_asset_id`, and the public app shows media asset 3, which is some other logo or nothing.
- Fix direction: add `logo_asset_id: int | None` to `BroadcastPreset` (an added field, which oasdiff accepts), update `contracts/admin-api.md`, re-export and regenerate. Test that the list carries the preset's asset id.

### LOW

- B1-R2-9 `backend/tests/admin/test_writer.py:147-156` (`test_locked_fields_gain_only_the_changed_lockable_fields`): now that a create locks `stadium` (B1-R1-4), the assertion is true whether or not an edit locks an unchanged field, so that property is no longer tested. Create without a stadium, set it through an importer write, then PATCH it unchanged and assert it stays unlocked. CONFIRMED.
- B1-R2-10 `backend/app/services/admin/lists.py:50-58` (`decode_cursor`, B1-R1-13): a base64 cursor `["a\u0000", 1]` on `GET /admin/api/teams` gave a `DBAPIError` and a 500 in a probe. Validate each value's type and refuse NUL with `invalid_cursor`. CONFIRMED.
- B1-R2-11 new suppressions: `backend/app/auth/limits.py:122` (`# type: ignore[no-untyped-call]`), `backend/app/workers/logs.py:49` (`# type: ignore[untyped-decorator]`), `backend/app/workers/__init__.py:19` (`# noqa: F401`, avoidable with `from app.workers import logs as logs`) and one `# noqa: S603` in `tests/unit/test_workers.py`. The first two cover untyped third-party signatures, the same pattern as `get_redis` and the other Celery decorators. CONFIRMED.
- B1-R2-12 docs not updated: `backend/CLAUDE.md:77` still says revisions 0001 to 0003; `contracts/admin-api.md:49-57` (`AdminMatchRow`) has no `etag`; research.md R6 and data-model.md don't list `broadcast_presets` and `sources` as datasets. CONFIRMED.
- B1-R2-13 `backend/tests/admin/test_lists.py:~58`: the row `etag` is compared with a single GET only for a match with no links or slots, so a grouping bug in `versions.match_versions` (`app/services/admin/versions.py:101-114`) would pass. Add two matches with links and slots, and a bulk action that uses each row's `etag`. CONFIRMED.
- B1-R2-14 `backend/app/api/admin/auth.py:12` imports `anyio`, which `pyproject.toml` doesn't declare (it arrives through Starlette). Declare it, or use `starlette.concurrency.run_in_threadpool` with a limiter. CONFIRMED.

## Requirements

Only the rows that changed since round 1. Every other row of `b1-round-1.md` stands.

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| FR-003, SC-003 five attempts per 15 min | `app/auth/limits.py:34-52,113-139`, `api/admin/auth.py:197-217` | `tests/auth/test_login.py` (parallel and sequential) | **Met** |
| FR-004 refresh rotation and startup key | `auth/tokens.py:131`, `admin.py:29` | `test_refresh.py`, `test_admin_startup.py` | **Met** |
| FR-010, SC-002 a create locks its fields | `services/admin/matches.py:142-157,301-305` | `test_match_patch.py::TestCreate` | **Met** |
| FR-013 contract tests on PostgreSQL 16 | `schemas/admin.py:92-106`, public query guards | `tests/contract/`, `test_nul_inputs.py` | **Met**; the public guard breaks the `contract-v1` gate (B1-R2-1) |
| FR-014 an edit is visible on revalidation | `writer.py:54-55`, the six list ETags | `test_lists.py`, `test_list_etags.py` | **Partial**: commentator usage (B1-R2-2), preset logos (B1-R2-3) |
| constitution VI list ETag and 304 (T045) | `api/admin/*.py`, `0004_list_datasets.py` | `test_list_etags.py` | **Partial**: 304s undocumented (B1-R2-4) |
| US4 scenario 6 broadcaster slots (B1's contract part) | `services/admin/lists.py:267-270` | none | **Partial**: no preset asset id (B1-R2-8) |
| FR-027, D15 the bridge key stays in VPS-2's environment (B1's log part) | `app/workers/logs.py` | none | **Partial** (B1-R2-7) |
| FR-055 runbooks | `docs/runbooks/secrets.md`, `database-migrations.md` | | **Partial** (B1-R2-5) |

## Task audit

Round-1 fix tasks: 9 ticked, 6 verified, 2 partly done (B1-R1-3, B1-R1-8), and 1 done with a side effect that fails a check (B1-R1-2). T015 is still unticked though done, and T047 is open, correctly.

| Task | Mismatch |
| --- | --- |
| B1-R1-2 | done for admin; its public part makes the `contract-v1` gate fail (B1-R2-1) |
| B1-R1-3 | the commentator list misses `matches` (B1-R2-2); `rehost-media` doesn't bump presets (B1-R2-3); the 304s aren't in the contract (B1-R2-4) |
| B1-R1-8 | the rotation steps still name VPS-2 and `worker-media` (B1-R2-5) |
| T015 | done (clients current) but `[ ]` |

## Owner must review

- `backend/openapi/public.json`: whether a `pattern` on a `/v1` query parameter is acceptable at all, or the guard stays out of the schema (B1-R2-1).
- `backend/openapi/admin.json`: the new `AdminMatchRow.etag` and the six list routes.
- `backend/alembic/versions/0004_list_datasets.py`: the widened CHECK and the two data rows, and the downgrade.
- `backend/app/auth/limits.py:34-52` and `backend/app/api/admin/auth.py:197-217`: the Lua reserve and the refund on success.
- B1-R1-10 (from round 1): whether to pin ffmpeg's demuxer now.

## Outside this change

- The 74 autogenerate diffs are D1's partial models, identical on master.
- Every VPS-1 service still loads the one shared `env_file` (D1's pattern).
- `backend/app/adapters/tasks.py:84` still sets `task_routes` at import next to B1's lazy `route()`. Both give the same answer, and it is B2's file (`b2-round-2.md`, LOW).

## Not reviewed

- The generated Orval and Retrofit files: compared with the generators, not read.
- `backend/app/adapters/`, `backend/tests/adapters/` and the fixtures: B2's (`b2-round-2.md`).
- A real Celery worker with the new log formatter (`celery` not allowlisted), and the 40-hash load for B1-R2-6.
