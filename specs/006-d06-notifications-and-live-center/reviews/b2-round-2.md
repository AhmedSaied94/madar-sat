# Implementation review: 006-d06-notifications-and-live-center, lane B2, round 2

- Date: 2026-11-09 · Reviewer: Claude Code (Opus 5.5, `claude-opus-5-5`); layers reviewed directly, no subagents
- Branch: `d06-b2` · Base: `origin/master` (merge base `b7fd7d9`) · Head: `cfff52c`, plus 0 uncommitted files
- Change: 19 commits, 309 files (271 in another lane's folders), +37 718 −562. The branch is the spec branch at `2652223` (lanes B1, B2, A and M merged as #46–#49) plus B2's round-1 fix commit `cfff52c` (10 files, +492 −5). The 271 other-lane files arrive through those merges and are each lane's own work, reviewed in its own round; this round reviews `cfff52c` and re-checks every round-1 finding against B2's own commits (`59bc9de`, `756c227`, `af517ba`, `cfff52c`).
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 1 · MEDIUM 7 · LOW 5

`cfff52c` is not pushed (`origin/d06-b2` is still `af517ba`), so no CI has run on it; the checks below are local.

## Checks

| Check | Command | Result |
| --- | --- | --- |
| ruff | `cd backend && uv run ruff check .` | exit 0, all checks passed |
| mypy | `uv run mypy --strict app` | exit 0, no issues in 186 files |
| pytest + coverage | `TEST_DATABASE_URL=postgresql://madar:changeme@localhost:5434/madar TEST_REDIS_URL=redis://:changeme@localhost:6380/0 uv run pytest --cov --cov-report=term-missing` | exit 1: 7 failures, none in B2's code. 4 `test_homebox_acl.py` (the local Redis has no home-box ACL users, as in round 1); `test_dashboard.py::test_placeholders_and_sources_are_counted` and 2 `test_login.py` tests failed on keys shared with other lanes' suites running at the same time on Redis db 0 (the dashboard diff is sporteventz `running: True`, another suite's fetch lock). Re-run on a private Redis db (`…/7`): `tests/auth/test_login.py tests/admin/test_dashboard.py` exit 0, all pass. Coverage 95 % total; `sporteventz.py` 91 %, `adapters/tasks.py` 93 %, `messages.py` 97 %, `health.py` 99 % |
| OpenAPI current | both apps exported with `app.cli._write_openapi` to a scratch folder (CI's placeholder env), then `diff -q` against `openapi/public.json` and `openapi/admin.json` | exit 0, no diff (the change touches no schema) |
| Adapter parse tests on saved pages | `uv run pytest tests/adapters/test_sporteventz.py tests/adapters/test_sporteventz_ingest.py tests/adapters/test_health.py` (same env) | exit 0, 44 passed |
| `Sport` renamed / reshaped on the saved basketball answer | scratch script calling `SporteventzAdapter.parse` on `tests/fixtures/sporteventz/2026-11-06/basketball.json` with `Sport` renamed to `SportName`, then with `Sport` as `{"name": "Basketball"}` | exit 0: **no `LayoutChanged`**, 0 items, skips `{"other_sport": 79}` both times (B2-R2-1) |
| Ways around the checks | `git show cfff52c` searched for `skip`, `xfail`, `noqa`, `type: ignore`, config changes | none new; no config, threshold or test removed |

## Previous round

| Finding | Now |
| --- | --- |
| B2-R1-1 (HIGH) changed record shape silent for 7 days, skips never counted | **Partly fixed.** Skips are counted by reason into `import_runs.log`, `counts` and `run.json` (`tasks.py:296-304, 557-559, 590-592`), and a renamed `Team1`/`Team2`, a new `Begin` format or non-object records now raise `LayoutChanged` (`sporteventz.py:201-207`, tests `test_sporteventz.py:242-257`, `test_sporteventz_ingest.py`, `test_health.py`). Still open for `Sport`, the fourth field the finding named: see B2-R2-1 |
| B2-R1-2 (MEDIUM) window ignored, docs say "today to +3" | Still open (`sporteventz.py:133`; `imports-and-sources.md:17`, `owner-actions.md:670`, `contracts/importers.md:48`) |
| B2-R1-3 (MEDIUM) cross-sport merge test can't fail; slot update, rate bucket, route untested | Still open (`test_upsert.py` unchanged since round 1) |
| B2-R1-4 (MEDIUM) runbooks describe unbuilt API-Football behaviour | Still open (`secrets.md:121-132`, `imports-and-sources.md:294`) |
| B2-R1-5 (MEDIUM) sporteventz run-now block: `dc` on VPS-1 undefined, no `manual: true` | Still open (`imports-and-sources.md:260-271`, unchanged; the new `parse_skipped` query at :272 reuses the same undefined `dc`) |
| B2-R1-6 (MEDIUM, PLAUSIBLE) `sport` written on every update | Still open (`upsert.py:568`) |
| B2-R1-7 (MEDIUM) US4 4–8, FR-034–036, SC-009 not delivered | Still open, correctly gated on T059; tasks.md:282 still says "The whole lane is green" |
| B2-R1-8 (LOW) card-sharing screen per slot | Still open |
| B2-R1-9 (LOW) other-sport writes bump football datasets | Still open |
| B2-R1-10 (LOW) `backend/CLAUDE.md` lacks the new importer rules | Still open; `parse_skipped` and `EXPECTED_SKIPS` are now missing too |
| B2-R1-11 (LOW) owner-actions B2: T052 label, "one-line change", stale "Open now" | Still open (`owner-actions.md:21, 682`); the "Open now" row also still reads "B2 is rebased on B1's `#46` and green" and "before B2's merge", though #47 merged on 2026-11-08 |

## Findings

### CRITICAL

None.

### HIGH

#### B2-R2-1: A renamed or reshaped `Sport` field is still a silent, "succeeded" empty run
- pipelines · FR-037 ("a changed page shape still is one at once"), B2-R1-1's task (which names `Sport` among the fields), constitution VII · `backend/app/adapters/sporteventz.py:211-216` and `:67-69` (`EXPECTED_SKIPS`) · CONFIRMED
- Problem: `_fixture` reads `Sport` with `_text(record.get("Sport"))`. When the key is renamed, or its value changes shape (it is an object `{"@id", "#text", "rank"}` today), the text is `""`, which is not football, so the record is skipped as `other_sport`. `other_sport` is in `EXPECTED_SKIPS`, so `parse` raises nothing. Each sport page lists only its own sport (the four saved answers hold 79/23/61/28 records, all of the page's sport), so "every record is another sport" is itself a changed page, but it is treated as a quiet one.
- Failure scenario: run on the saved basketball answer with `Sport` renamed to `SportName` (or reshaped to `{"name": "Basketball"}`): `parse` returns `[]` with skips `{"other_sport": 79}` and no `LayoutChanged`. Every run "succeeds" with 0 items, the 7-day zero-items grace keeps it silent, and the runbooks (`source-alerts.md:71-77`, `imports-and-sources.md:249-253`) tell the on-call that a changed page fails at once. The only trace is `other_sport` counts in the log, which the runbook calls normal.
- Fix direction: give an empty or unreadable `Sport` its own unexpected reason (for example `missing_sport`), so it is not an expected skip; consider also failing a sport page whose records are all of other sports. Add `Sport` to the parametrized rename test in `test_sporteventz.py` (and a reshaped `Sport` value), and list the new reason in both runbooks.

### MEDIUM

- **B2-R2-2** (pipelines/ops, CONFIRMED) `ScrapeResult` gained `parse_skipped` (`messages.py:123-126`) with `extra="forbid"` and no schema bump, and the wire contract (`specs/002-d02-core-flows/contracts/ingestion.md` §ScrapeResult) doesn't list it. A sporteventz message with any skip, read by an `ingest` one release behind (a rollback with messages queued, or the seconds of a deploy), fails `ScrapeResult.model_validate` (`tasks.py:372`) and the run leaves no `import_runs` row. Bump the schema (R21 keeps the previous one readable) or let ingest ignore unknown optional fields, and record the field in the contract.
- **B2-R1-2 … B2-R1-7** remain open as listed under "Previous round" (notes, no tasks).

### LOW

- **B2-R2-3** (spec, CONFIRMED) `cfff52c` also adds the other three lanes' round-1 review blocks to their `tasks.md` sections (B1 :224-235, A :332-345, M :401-408). The text is the same as each lane's own append and the spec branch merged it cleanly (`4fa417c`), so nothing is lost, but a lane commit should touch only its own section.
- **B2-R1-8 … B2-R1-11** remain open as listed under "Previous round".

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US4-1 twice, no duplicates | `sporteventz.py`, `upsert.py` | `test_sporteventz_ingest.py:156` | OK |
| US4-2 editor's entries stay | `upsert.py:333` | `test_sporteventz_ingest.py:168` | OK |
| US4-3 football only for clients and poller | B1's reads; `livesoccertv.plan_targets` | `test_livesoccertv_plan.py:81` | OK (B2's part) |
| US4-4..8 API-Football | — | — | Not built, gated on T059 (B2-R1-7) |
| US4-9 names stay as text, queue doesn't grow | `upsert.py:200-206, 238` | `test_sporteventz_ingest.py:238` | OK |
| FR-030 sporteventz, skip and count | `sporteventz.py`, `tasks.py:296-304` | `test_sporteventz.py:243-290`, `test_sporteventz_ingest.py` (skip counts) | Counting OK; window still not applied (B2-R1-2) |
| FR-031 broadcaster slots | `sporteventz._broadcast_slots`, `upsert.py` | `test_sporteventz.py:171-203` | OK (B2-R1-8) |
| FR-032 no rows, no queue | `upsert.py` no-resolve | ingest tests | OK |
| FR-033 sport written and compared | `upsert.py` | `test_upsert.py` (B2-R1-3) | Code OK, guard untested |
| FR-037 changed page alarms at once | `sporteventz.py:201-207`, `health.py` | `test_sporteventz.py:242-257`, `test_health.py` (failed run inside the grace) | Partly: `Sport` still silent (B2-R2-1) |
| FR-038 importers report link changes | `upsert.py:252, 662-677`, `livesoccertv_links.py:196-201` | `test_upsert.py`, `test_livesoccertv_links.py` | OK |
| FR-039 LiveSoccerTV skips other sports; sporteventz quiet grace | `livesoccertv.py:513`, `health.py` | `test_livesoccertv_plan.py`, `test_health.py` (valid empty run inside the grace) | OK |

## Task audit

Ticked 18 (T044–T058, T065, T067, B2-R1-1), verified 16, not done 0, partly done 2. Unticked T059–T064 and T066 are correctly gated (owner checks, live host).

| Task | Mismatch |
| --- | --- |
| B2-R1-1 | `Sport`, one of the four fields the task names, still fails silently (B2-R2-1) |
| T044 | The cross-sport merge test still can't fail (B2-R1-3) |

## Owner must review

None of the listed kinds: the change has no migration, API contract, auth code, push audience query or UI screen. The `ScrapeResult` wire change (B2-R2-2) is internal to the workers. The owner decisions are unchanged: sporteventz's terms (T067) and the API-Football checks (T059).

## Outside this change

- `backend/tests/conftest.py:11` defaults `TEST_DATABASE_URL` to `postgres:postgres@localhost:5434`, but the dev stack `backend/CLAUDE.md` documents (`infra/compose/dev.yml`, `example.env`) creates `madar:changeme`, so the documented `uv run pytest` fails every database test until `TEST_DATABASE_URL`/`TEST_REDIS_URL` are set by hand. Not B2's change.
- `backend/pyproject.toml:104` sets `fail_under = 70`, below the constitution's 80 % gate (pre-existing; actual coverage is above 80 %).
- From round 1, still true: `HttpFetcher._check_host` ignores the scheme; the fixture HTML pages carry a Joomla guest `csrf.token`.

## Not reviewed

- The other lanes' files that arrive through the spec-branch merges (#46, #48, #49): each lane's own review covers them.
- T066's live run and the API-Football tasks (owner-gated); nothing was run against a host.
- The home-box ACL tests (no ACL users in the local Redis); CI has not run on `cfff52c` because it isn't pushed.
- `tests/conftest.py` isolates the database per session but not Redis: concurrent suites share db 0, which is what made the dashboard and login tests fail here (outside this change; worth a per-session Redis db).
