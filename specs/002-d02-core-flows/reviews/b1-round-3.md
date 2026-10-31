# Implementation review: 002-d02-core-flows, lane B1, round 3

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); a layer subagent on Sonnet, every finding re-checked here
- Branch: `d02-features` (not `d02-b1`; the same combined checkout rounds 1 and 2 reviewed) · Base: `origin/master` (merge base `68f1752`) · Head: `635919d`, plus 158 uncommitted files across the four lanes
- Change (lane B1, this round): no new commit. The round-2 fixes, uncommitted: 19 files under `backend/` outside the adapters touched after round 2 (`api/admin/*`, `api/public/{teams,satellites}.py`, `etl/media.py`, `schemas/*`, `services/admin/lists.py`, `services/matches.py`, `workers/logs.py`, their tests), the re-exported `openapi/admin.json`, the regenerated Orval client, `contracts/admin-api.md` and `docs/runbooks/secrets.md`. Nothing in another lane's folder.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 0 · LOW 4 (1 PLAUSIBLE)

All seven ticked round-2 fixes do what their tasks say, and each has a test that fails on revert. The round-2 HIGH is gone: `public.json` is byte-identical to the export and oasdiff exits 0 against `contract-v1` on both documents. What is left is LOW: two test gaps, three doc leftovers, and the round-2 PLAUSIBLE and LOW items nobody tasked.

## Checks

Backend checks ran in a snapshot of this working tree (`git ls-files -co --exclude-standard`), against the dev PostgreSQL 16 (`:5434`) and Redis 7 (`:6380`).

| Check | Command | Result |
| --- | --- | --- |
| deps | `cd backend && uv sync --frozen` | exit 0 |
| ruff | `uv run ruff check .` | exit 0, clean |
| mypy | `uv run mypy --strict app` | exit 0, 118 files, no issues |
| pytest + coverage | `uv run pytest --cov --cov-report=term` | exit 0; coverage 96.28 % (gate 70 %) |
| OpenAPI current | `uv run python -m app.cli export-openapi` with `backend.yml`'s placeholder env, then `diff -rq openapi/` against the working tree | exit 0, no diff |
| non-breaking vs `contract-v1` | `git show contract-v1:backend/openapi/$f.json`, then `tufin/oasdiff:v1.35.0 breaking … --fail-on ERR` (as `backend.yml:141-151` runs it) | **public: exit 0, admin: exit 0** ("no breaking changes") |
| admin client current | `cd admin && pnpm orval`, then `diff -rq src/api/generated` against the working tree | exit 0, no diff |
| Dart client current | `cd app && dart run swagger_parser && dart run build_runner build -d`, then `diff -rq lib/core/network/generated` | exit 0, no diff |
| api-admin command | `uv run gunicorn --check-config app.admin:app -k uvicorn.workers.UvicornWorker -w 1 -b 0.0.0.0:8001 --forwarded-allow-ips=10.8.0.1` with the CI env | exit 0 |
| secrets | `zricethezav/gitleaks:v8.30.1 dir . --config .gitleaks.toml --redact --exit-code 1` from the snapshot root | exit 0, no leaks |
| real `celery worker` start with the JSON formatter | | **NOT RUN**: as in round 2 |
| T047 on VPS-1 | | **NOT RUN**: nothing is deployed |

Ways around the checks: no new `skip`, `xfail`, suppression or config change in this round's delta.

## Previous round

| Finding | Now |
| --- | --- |
| B1-R2-1 HIGH, `/v1` NUL guard publishes a `pattern` | fixed: `NoNul` `AfterValidator` (`backend/app/schemas/__init__.py:21`) on `api/public/teams.py:33` and `api/public/satellites.py:41`; oasdiff exit 0; `test_the_nul_guard_is_not_a_published_pattern` and the `%00` 422 cases fail on revert |
| B1-R2-2 commentator list stale 304 | fixed: `ETag("admin_commentators", ("commentators", "matches"))`; `test_the_commentator_list_etag_follows_a_match_assignment` |
| B1-R2-3 `rehost-media` doesn't bump presets | fixed: `etl/media.py:63` maps to `broadcast_presets`; `tests/db/test_rehost_media.py:313` |
| B1-R2-4 304 and `ETag` undeclared | fixed: every GET with an `ETag` dependency declares both; `test_every_route_that_answers_304_declares_it` walks the dependants |
| B1-R2-5 JWT key copied to VPS-2 | fixed: `docs/runbooks/secrets.md:18,84-88` are VPS-1 only |
| B1-R2-6 argon2 on the shared pool (PLAUSIBLE) | still open, not tasked: `api/admin/auth.py:211,214` |
| B1-R2-7 JSON formatter writes everything | fixed: `workers/logs.py` drops `data`, `args`, `kwargs`, caps fields and line, `httpx`/`httpcore` at WARNING (see B1-R3-1) |
| B1-R2-8 `BroadcastPreset.logo_asset_id` | fixed: `schemas/admin.py:671`, `services/admin/lists.py:270-274`, `contracts/admin-api.md:165`; `test_a_preset_lists_the_asset_id_the_editor_saves_in_a_slot` |
| B1-R2-9 … B1-R2-14 (LOW) | still open, not tasked (B1-R3-3 lists the doc leftovers) |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

None.

### LOW

#### B1-R3-1: the field and traceback caps of the JSON formatter are untested
- tests · B1-R2-7 task text · `backend/tests/unit/test_workers.py` (`test_the_json_formatter_drops_and_caps_a_failing_tasks_payload`) · CONFIRMED
- Problem: the 100 KB payload sits in `data`, which is dropped, so `MAX_FIELD_CHARS`, `MAX_EXC_CHARS` and the line fallback (`backend/app/workers/logs.py:75-84`) can be removed without a test failing.
- Failure scenario: `_cap` is dropped from `_field`; `extra={"page": <100 KB>}` writes a 100 KB line and the suite stays green.
- Fix direction: one case with a large value under a kept key, one with a long traceback.

#### B1-R3-2: the `setup_logging` tests leave `httpx` and `httpcore` at WARNING
- tests · test isolation · `backend/tests/unit/test_workers.py` · CONFIRMED
- Problem: only `test_httpx_and_httpcore_stay_at_warning` restores the two levels; the other tests that call `setup_logging` don't.
- Failure scenario: a later `caplog` test on `httpx` at INFO passes or fails by test order.
- Fix direction: restore the `QUIET_LOGGERS` levels in a shared fixture.

#### B1-R3-3: round 2's doc leftovers (B1-R2-12)
- ops · CLAUDE.md rule · `backend/CLAUDE.md:77` ("0001, 0002 and 0003", now `0004`), `specs/002-d02-core-flows/contracts/admin-api.md:49-57` (`AdminMatchRow` without `etag`), research R6 and `data-model.md` without `broadcast_presets` and `sources` · CONFIRMED

#### B1-R3-4: an exception text in the log line can still carry a URL
- security · FR-027 · `backend/app/workers/logs.py` (`exc` field) · PLAUSIBLE
- Problem: `httpx.HTTPStatusError`'s message embeds the request URL. The bridge key has moved to a header (B2-R2-5), so nothing secret rides there today, but nothing scrubs it either.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| FR-014 / SC-001, `/v1` stays compatible with `contract-v1` | `schemas/__init__.py:21` (`NoNul` without a published pattern) | oasdiff exit 0 on both; `test_public_schema.py` | met |
| constitution VI, every GET has an ETag that follows the data it shows | `api/admin/{commentators,lists,teams,channels}.py`, `etl/media.py:63`, revision `0004` | `tests/admin/test_list_etags.py`, `tests/db/test_rehost_media.py` | met |
| US4 scenario 6, a preset's logo can be saved with a slot | `BroadcastPreset.logo_asset_id` | `test_lists.py` | met |
| FR-027, logs carry no payloads or secrets | `workers/logs.py` | `test_workers.py` | met (caps partly untested, B1-R3-1) |

Round 2's table for the rest of US1 still holds; nothing in this delta changes it.

## Task audit

Ticked 7 (round-2 block), verified 7, not done 0, partly done 0.

## Owner must review

- `backend/openapi/admin.json`: the added `304` responses, `ETag` headers, `AdminMatchRow.etag` and `BroadcastPreset.logo_asset_id` (all additive).
- `backend/alembic/versions/0004_list_datasets.py`: the CHECK drop and re-add on `dataset_versions` and the two inserted rows.

## Outside this change

- Agent setup in `.specify/`, `.claude/` and `.opencode/`: none changed.

## Not reviewed

- A real `celery worker` start with the JSON formatter, and T047 on VPS-1 (above).
- The generated clients' content beyond "matches the generator".
