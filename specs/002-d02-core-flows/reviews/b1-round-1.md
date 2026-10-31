# Implementation review: 002-d02-core-flows, lane B1, round 1

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); layer subagents on Sonnet, every finding re-checked here
- Branch: `d02-features` (the four D2 lane PRs, #8–#11, merged into it; not yet on `master`) · Base: `master` (merge base `68f1752`) · Head: `6f81c90`, clean tree
- Change (lane B1): 3 commits (`ab06ea6`, `da17913`, `1d3c0f5`, merged as PR #8), 107 files under `backend/` (+37342 −271) plus the regenerated clients and 4 shared docs. No file in another lane's folder except the generated Orval and Retrofit clients, which T015 assigns to B1.
- Verdict: **BLOCK** · CRITICAL 1 · HIGH 3 · MEDIUM 6 (1 PLAUSIBLE) · LOW 14 (4 PLAUSIBLE)

The admin API is close to done, and the writer unit of work (`app/services/admin/writer.py`) is solid. One rule is broken badly enough to block: the login limit can be bypassed by sending attempts in parallel. Three more gaps stop the API meeting its own contract. A NUL byte in any admin text field returns a 500, and that already fails the CI contract gate. Six list GETs never answer 304. A new match locks no fields, so the next import can overwrite it.

## Checks

Every check ran in a `git archive` copy of HEAD `6f81c90`, so the generators and goldens could write freely without touching the working tree. The backend ran against the dev PostgreSQL 16.15 (`:5434`) and Redis 7 (`:6380`).

| Check | Command | Result |
| --- | --- | --- |
| deps | `cd backend && uv sync --frozen` | exit 0 |
| ruff | `uv run ruff check .` | exit 0, clean |
| mypy | `uv run mypy --strict app` | exit 0, no issues |
| pytest + coverage | `uv run pytest --cov --cov-report=term-missing` | **exit 1**: 1023 passed, **2 failed**. `test_admin_contract.py[POST /admin/api/hidden-channel-names]` and `test_public_schema.py[GET /v1/teams]` both send a `\u0000` in a text input, which asyncpg rejects with `CharacterNotInRepertoireError`, giving a 500. Coverage is 95.80 % on domain/services/adapters (gate 70 %) |
| contract rerun | `uv run pytest tests/contract/test_admin_contract.py tests/contract/test_public_schema.py` (the Hypothesis example DB now holds the failing case) | **exit 1**: `POST /admin/api/hidden-channel-names` fails again; `/v1/teams` passes. CI on PRs #8 and #9 passed only because Hypothesis didn't draw a NUL there |
| OpenAPI current | `uv run python -m app.cli export-openapi && git status --porcelain -- openapi/` (with the `backend.yml` placeholder env) | exit 0, no diff |
| non-breaking vs `contract-v1` | `oasdiff breaking contract-v1:{public,admin}.json HEAD:{public,admin}.json --fail-on ERR` (`tufin/oasdiff:v1.35.0`) | exit 0 for both specs |
| `public.json` unchanged by D2 | `git diff --stat 68f1752 6f81c90 -- backend/openapi/public.json` | no diff |
| migrations | on a fresh DB, `alembic upgrade head`, then `compare_metadata(Base.metadata)` | upgrade ok. 74 diffs, identical to the same run on master `68f1752` (D1's partial models: indexes, domains). None touch `audit_log.source`, `ck_audit_log_actor` or `match_channels.imported_by` |
| 0003 reversible | `tests/db/test_migrations.py`, in the pytest run | passed |
| clients current | `cd admin && pnpm orval`; `cd app && dart run swagger_parser && dart run build_runner build -d`; then `git status --porcelain -- admin/src/api/generated app/lib/core/network/generated` | exit 0 for all three, no diff |
| T047 on VPS-1 | | **NOT RUN**: the D2 work is on `d02-features`, not deployed |

I scanned the diff for ways around the checks. There are no new `skip`, `xfail` or `noqa`, and no lint, mypy or coverage config changes. Two new `# type: ignore`s are narrow: `app/auth/roles.py:75` (avoidable, LOW below) and `:80`.

## Findings

### CRITICAL

#### B1-R1-1: the login limit can be bypassed by sending attempts in parallel
- Layer `security` · Source FR-003, SC-003, constitution V (NON-NEGOTIABLE), system-design §8 · `backend/app/api/admin/auth.py:189-205`; `backend/app/auth/limits.py:56-100` · CONFIRMED
- Problem: `login` reads `limiter.locked_for(email, ip)` (`:189`), then awaits the admin lookup (`:196`) and the password check (`:199` / `:202`), and only after that calls `record_failure` (`:205`). Each `await` yields to other requests, so N concurrent requests all pass `locked_for` before the first failure is recorded. The lock key is only set once the count reaches `MAX_FAILURES` inside `record_failure`, and nothing re-checks the count before verifying the password. With several uvicorn workers the window grows.
- Failure scenario: an attacker who is a WireGuard peer, or who holds a stolen peer config, opens 50 parallel `POST /admin/api/auth/login` requests for one email. All 50 passwords are checked, not 5, and each wave after the 15-minute lock lapses gets another 50. `tests/auth/test_login.py` sends its attempts one by one, so it passes.
- Fix direction: reserve the attempt before checking the password. Do an atomic `INCR` (or the existing `zadd` and `zcard` pipeline) before the password check, and refuse when the count is already at `MAX_FAILURES`. A Lua script that adds and counts in one step also works. Clear the reservation on success. Add a test that fires 10 concurrent logins with a wrong password (`asyncio.gather`) and asserts at most 5 password verifications (patch `passwords.verify_password` to count) and at least 5 `429`s.

### HIGH

#### B1-R1-2: a NUL byte in any admin text input returns a 500, and it fails the CI contract test
- Layer `api` · Source FR-013, constitution VI (envelope, stable `error.code`), the CI gate `backend.yml` · `backend/app/schemas/admin.py:93-103` (`Name120`, `Text80`) and every other `str` field · CONFIRMED (pytest above)
- Problem: the shared string types limit length and screen card-sharing labels, but they let `\u0000` through. PostgreSQL text can't hold it, so asyncpg raises `CharacterNotInRepertoireError`, which surfaces as an unhandled 500 with no envelope.
- Failure scenario: Schemathesis or Hypothesis draws a NUL for `POST /admin/api/hidden-channel-names`, and the contract test fails. The failing example is now stored in the local example DB, so CI goes red as soon as the draw repeats. Any editor who pastes text containing a NUL (from a PDF, say) gets «خطأ غير متوقع» instead of a validation message.
- Fix direction: one shared guard on every admin text input. Add an `AfterValidator` or `pattern` to `Name120`, `Text80` and the other `str` aliases, or a single `BeforeValidator` on a base `AdminText` type that rejects `\x00` with `422 validation_failed`. Add a parametrised test that posts a NUL to each admin text field and expects 422. The same bug on `/v1/teams?q=` predates D2 (see "Outside this change").

#### B1-R1-3: six admin list GETs send no `ETag` and never answer 304
- Layer `api` · Source constitution VI ("every GET returns an `ETag` … answers `If-None-Match` with a 304"), T045 ("weak list ETags with `304`", ticked), contracts/admin-api.md · `backend/app/api/admin/teams.py:23`, `channels.py:24`, `commentators.py:23`, `lists.py:22` (`/broadcast-presets`), `lists.py:35` (`/hidden-channel-names`), `lists.py:80` (`/sources`) · CONFIRMED
- Problem: only `matches.py:39`, `competitions.py:25` and `satellites.py:25` declare `Depends(ETag(...))`. The other six list routes return 200 with the full body every time.
- Failure scenario: A4's pickers and A3's filters refetch these lists on every focus and mount, and each returns its whole page. T045 is ticked as done, but its "weak list ETags with `304`" was never built for these routes.
- Fix direction: add `Depends(ETag("admin_<name>", (<datasets>,)))` to each one, with the datasets they read: `teams`; `channels`; `commentators`; `broadcast_presets` (or the dataset that `writer.py` bumps for presets); `hidden_channel_names`; and `sources`, if `source_states` writes bump something. If no dataset covers a list, give it one. Add a test per route: a GET with the returned `ETag` as `If-None-Match` answers 304, and an edit through the API changes the ETag.

#### B1-R1-4: a match created in the admin locks no fields, so the next import can take it over
- Layer `api` · Source constitution VI (an admin write "adds the edited field names to `locked_fields`"), FR-010, SC-002 · `backend/app/services/admin/matches.py:255-293` (`create` sets `locked_fields=[]`); `backend/app/services/admin/writer.py:226-243` (`save_create` never locks); consumer `backend/app/adapters/upsert.py:225-262` (B2's duplicate probe) · CONFIRMED
- Problem: every update locks the fields it writes, but a create locks none. B2's upsert looks for an existing match with the same teams within ±45 minutes and adopts it. With `locked_fields` empty it then overwrites the kickoff, the competition, the stage and the status source with whatever the feed says.
- Failure scenario: an editor adds Ahly vs Zamalek at 20:00 Cairo, ahead of the feed. ysscores lists the same match at 19:30 (the feed is wrong), and the next `ysscores-fixtures` run moves the kickoff to 19:30. The app shows the wrong time, and the editor's entry is lost with no trace beyond the import's audit row.
- Fix direction: in `create`, set `locked_fields` to the names of the fields the editor supplied (kickoff, teams, competition, stage, venue, and so on), through the same helper the update path uses, so the audit diff and the lock agree. Add a test: create a match through the API, run `Upserter` on a fixture item that the duplicate probe matches with a different kickoff, and assert the kickoff did not change. The test fails before the fix.

### MEDIUM

#### B1-R1-5: hiding a channel name bumps only `matches`, so `/v1/satellites` serves stale counts
- Layer `api` · Source FR-014, constitution VI · `backend/app/services/admin/writer.py:54` (`HIDDEN_NAME_CHANGED = ("matches",)`); `backend/app/services/satellites.py:38-39` (filters by hidden names); `backend/app/api/public/satellites.py:22` (ETag from `("satellites", "channels")`) · CONFIRMED
- Problem: a hidden name changes what `/v1/satellites` and the satellite-channel lists return, but those ETags are built from datasets the change never bumps.
- Failure scenario: an editor hides «beIN SPORTS 1 HD» everywhere, but S5.1 and S5.2 revalidate with their old ETag and get 304 until an unrelated satellite or channel edit happens.
- Fix direction: also bump `channels` (or whichever dataset the satellite routes read) on a hidden-name change. research.md R6's bump table lists only `matches`, so the owner must amend R6 first; that is an ask task.

#### B1-R1-6: deleting a competition silently deletes its rights-holder rows
- Layer `db` · Source contracts/admin-api.md:30 (`409 in_use` "deleting an entity something still references"), data-model.md · `backend/app/services/admin/competitions.py:93-110` (the in-use map); `backend/alembic/versions/0001_base_schema.sql:306` (`rights_holder_competitions … ON DELETE CASCADE`) · CONFIRMED
- Problem: the in-use check counts matches and the other references but not `rights_holder_competitions`. The cascade then deletes those rows without a trace in `audit_log`.
- Fix direction: add `rights_holder_competitions` to the in-use map, so the delete answers `409 in_use` with its count. Add a test.

#### B1-R1-7: argon2 runs on the event loop
- Layer `api` · Source the 4.B check "no blocking I/O in async code" · `backend/app/api/admin/auth.py:199,202` · CONFIRMED
- Problem: `burn_verify` and `verify_password` are synchronous and cost tens of milliseconds by design. Each login blocks every other request on that worker, including the editors' saves.
- Fix direction: run them with `await anyio.to_thread.run_sync(...)` (or `run_in_threadpool`). Do this together with B1-R1-1, so the attempt is reserved before the thread starts.

#### B1-R1-8: the secrets runbook sends `ADMIN_JWT_SECRET` to VPS-2 and `worker-media`
- Layer `ops` · Source FR-004 ("a key that exists only in the host environment" of the service that signs), constitution V (least privilege) · `docs/runbooks/secrets.md:18` · CONFIRMED
- Problem: the table says the key goes in "Both VPS-1-facing `.env` files (VPS-1 and VPS-2)" and is used by "`api-admin`, `worker-media`". Only `api-admin` signs or reads admin JWTs (`app/admin.py:29`). VPS-2 never needs the key.
- Fix direction: make the row say VPS-1's `.env`, used by `api-admin` only. If the shared `env_file` puts it in every VPS-1 container, note that and stop listing `worker-media` as a user.

#### B1-R1-9: no test covers the refresh lock or the startup secret check
- Layer `tests` · Source FR-004, FR-053 · `backend/app/auth/tokens.py:131` (`with_for_update()` on refresh); `backend/app/admin.py:29` (refuses to start without a usable secret); `backend/tests/auth/test_refresh.py` · CONFIRMED
- Problem: rotation correctness depends on the `FOR UPDATE`, but no test sends two concurrent refreshes with the same token. No test starts `app.admin:app` without `ADMIN_JWT_SECRET`, or with a short one.
- Fix direction: add both tests. For the first, two concurrent refreshes with one token: exactly one succeeds and the family is revoked per the reuse rule. For the second, the lifespan raises on a missing or short key. Each fails if its guard is removed.

#### B1-R1-10: ffmpeg's input format is not pinned
- Layer `security` · Source FR-012 (uploads are re-encoded and checked), system-design §8 · `backend/app/media/encode.py:76` (`[ffmpeg, "-nostdin", "-y", "-i", str(src), …]`) · PLAUSIBLE
- Problem: with no `-f` before `-i`, ffmpeg probes the format, and an upload sniffed as audio can still be read by another demuxer (for example HLS playlists with network or file references). I didn't build a hostile file. The re-encode runs in the API container on VPS-1, with read access to the media disk.
- Fix direction: pass `-f <expected demuxer>` for the sniffed type and `-protocol_whitelist file,pipe`. The owner may decide this is enough of a risk to test with a crafted file.

### LOW

- B1-R1-11 `backend/app/services/admin/matches.py:235-248`: when an editor clears a manual status, `locked_fields` is reassigned after `save_update` has already computed the diff and bumped the versions. The audit diff misses the lock change, though the row is right. CONFIRMED.
- B1-R1-12 `backend/app/services/admin/lists.py:257`: commentator usage is queried once per row (N+1, at most 100 per page). CONFIRMED.
- B1-R1-13 `backend/app/services/admin/lists.py:50-58`: `decode_cursor` checks only the length, not the value types, so a forged cursor could reach the query as the wrong type. Likely a 500 rather than a leak. PLAUSIBLE.
- B1-R1-14 `backend/app/schemas/admin.py:104`: `Minute`'s `\d` also matches Arabic-Indic digits in Python's `re` (Unicode by default). Use `[0-9]`. PLAUSIBLE (I didn't send one).
- B1-R1-15 `backend/app/schemas/admin.py:407`: bulk `channel_ids: list[Id] | None` has no `max_length`. CONFIRMED.
- B1-R1-16 `backend/openapi/admin.json`: the bulk route doesn't declare the 404 and 428 it can return, so the generated clients cannot type them. CONFIRMED.
- B1-R1-17 `backend/app/services/admin/lists.py:288-299` (`add_hidden_name`) and the upload dedupe in `app/media/store.py`: both check, then insert. Two concurrent identical requests give one 201 and one 500 (unique violation) instead of 409 or 200. CONFIRMED by reading.
- B1-R1-18 `backend/app/workers/locks.py:27-28`: `conn.set(...)` runs before the `try`, so if it raises, the connection the helper opened is never closed. CONFIRMED.
- B1-R1-19 `backend/app/services/admin/match_view.py:78`: `changed_at` is stored and emitted as `+00:00`, while the rest of the API emits `Z`. Both are ISO-8601 UTC, but the format differs between fields of one response. CONFIRMED.
- B1-R1-20 `backend/app/media/store.py:32`: `mkstemp` creates files with mode 0600, owned by uid 10001. Caddy (`infra/compose/vps1.yml:47`, read-only mount) can read them only because it runs as root today. PLAUSIBLE.
- B1-R1-21 `backend/app/auth/tokens.py:131`: two tabs refreshing at once look like token reuse and revoke the whole family, signing the editor out. The design accepts this, but `staff-accounts.md` doesn't mention it. PLAUSIBLE.
- B1-R1-22: lockouts, token-reuse revocations and role refusals are not logged as security events (system-design §8, `docs/system-design.md:574`, lists an audit log under AuthN/AuthZ). CONFIRMED.
- B1-R1-23 tests: the `# type: ignore[arg-type]` at `app/auth/roles.py:75` can be removed by constructing `role` as the `Role` enum. The route walk in `tests/contract/test_admin_routes_have_roles.py` skips routes that aren't `APIRoute`. No test asserts there is no default admin after `alembic upgrade head` (FR-002). CONFIRMED.
- B1-R1-24 process: T015 is done (the generated clients are in `da17913` and current) but unticked. B1's ticks arrived in B2's commit `b0fcde2`, not B1's own (FR-051 says each lane ticks only its own section). Code and tests landed in one commit (`ab06ea6`), so test-first (FR-053) can't be shown from history. CONFIRMED.

## Requirements

| Requirement | Status | Where | Test |
| --- | --- | --- | --- |
| FR-001 auth endpoints | Built | `app/api/admin/auth.py` | `tests/contract/test_admin_auth_contract.py`, `tests/auth/test_login.py` |
| FR-002 argon2id, ≥ 12 chars, no default, CLI | Built | `app/auth/passwords.py`, `app/cli` | `tests/auth/test_passwords.py`, `tests/auth/test_cli_admins.py`; no "no default account" test (B1-R1-23) |
| FR-003 5 per 15 min per email + IP | **Partial**: sequential only | `app/auth/limits.py` | `tests/auth/test_login.py`; concurrent bypass B1-R1-1 |
| FR-004 JWT 15 min, refresh 14 d, rotation | Built | `app/auth/tokens.py` | `tests/auth/test_refresh.py`; lock and startup untested (B1-R1-9) |
| FR-005 one role dependency | Built | `app/auth/roles.py` | `tests/contract/test_admin_routes_have_roles.py` |
| FR-006 CRUD for the six entities | Built | `app/api/admin/*.py`, `app/services/admin/*.py` | `tests/admin/test_entities.py` |
| FR-007 A3 and A4 list data | Built | `app/services/admin/lists.py`, `match_view.py` | `tests/admin/test_lists.py` |
| FR-008 match operations, `409 in_use` | Built; competition delete gap | `app/services/admin/matches.py`, `bulk.py`, `competitions.py` | `tests/admin/test_match_patch.py`, `test_bulk.py`; B1-R1-6 |
| FR-009 single-GET ETag, `If-Match` | Built | `app/services/admin/writer.py` | `tests/admin/test_writer.py` |
| constitution VI list ETag / 304 (T045) | **Partial**: 3 of 9 lists | `app/api/admin/*.py` | B1-R1-3 |
| FR-010 audit + bump + lock in one transaction | **Partial**: create locks nothing | `writer.py:226-243` | `tests/admin/test_writer.py`; B1-R1-4, B1-R1-11 |
| FR-011 manual status | Built | `app/domain/…`, `services/admin/matches.py` | `tests/unit/test_manual_status.py`, `tests/admin/test_match_status.py` |
| FR-012 uploads | Built | `app/media/` | `tests/admin/test_uploads.py`; B1-R1-10 |
| FR-013 contract tests on PostgreSQL 16 | **Failing** | `tests/contract/` | B1-R1-2 |
| FR-014 edit visible on revalidation | **Partial**: hidden names | `writer.py:54` | `tests/admin/test_edit_reaches_v1.py`; B1-R1-5 |
| SC-002 audit, bump, lock 100 % | **Partial** | | B1-R1-4 |
| SC-003 the sixth attempt refused | **Not met** under concurrency | | B1-R1-1 |
| FR-051 own folders only | Met (generated clients per T015); ticks via B2's commit | | B1-R1-24 |
| FR-052 no secret committed | Met: the diff has placeholders only | | |
| FR-053 tests first | Not shown | | B1-R1-24 |
| FR-054 coverage | Met: 95.80 % | | pytest run |
| FR-055 `staff-accounts.md` | Built; `secrets.md:18` is wrong | `docs/runbooks/` | B1-R1-8 |

## Task audit

- T001–T014, T016–T046 and T048–T050 are ticked. The work exists, with these exceptions: T045's list ETags (B1-R1-3), and the match create path, which locks nothing (B1-R1-4).
- T015 is unticked but done (B1-R1-24).
- T047 is open and correctly so: it needs the deploy and the owner's `ADMIN_JWT_SECRET`, and on VPS-1 B2-R1-1 and B2-R1-3 block it today.

## Owner must review

- B1-R1-5: **decided 2026-10-31**. A hidden-name change bumps `matches` and `channels`, and research.md R6 is amended to say so.
- B1-R1-10: whether to pin ffmpeg's demuxer now, or test with a crafted file first.

## Outside this change

- `/v1/teams?q=` with a NUL returns a 500 (`test_public_schema.py[GET /v1/teams]`). That route is D1's. B1-R1-2's guard should cover the public query parameters too, but that is a D1 fix.
- The 74 autogenerate diffs (indexes and domains) are identical on master. They come from D1's partial models.
- Every service in `infra/compose/vps1.yml` loads the same `env_file`, so each container sees every VPS-1 secret. That is D1's pattern; B1-R1-8 only fixes the runbook.

## Not reviewed

- The generated Orval and Retrofit files: I checked them against the generators, and read no code in them.
- `backend/tests/adapters/` and the raw-page fixtures: B2's (see `b2-round-1.md`).
