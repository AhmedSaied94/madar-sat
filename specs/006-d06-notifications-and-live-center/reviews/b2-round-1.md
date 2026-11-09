# Implementation review: 006-d06-notifications-and-live-center, lane B2, round 1

- Date: 2026-11-09 · Reviewer: Claude Code (Opus 5.5, `claude-opus-5-5`), with a Sonnet layer reviewer; every finding re-checked on Opus
- Branch: `d06-b2` · Base: `2cfe280` (B1's merge #46, which this branch was rebased on; the lane's own commits are `59bc9de`, `756c227`, `af517ba`) · Head: `af517ba`, plus 0 uncommitted files
- Change: 3 commits, 43 files (0 in another lane's folders: `backend/tests/adapters/` and `backend/tests/fixtures/` are B2's per the tasks.md lane table), +7 720 −82
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 1 · MEDIUM 6 · LOW 4

The lane is already merged into the spec branch (PR #47, 2026-11-07).

## Checks

| Check | Command | Result |
| --- | --- | --- |
| ruff | `uv run ruff check .` (clean copy of `d06-b2`) | exit 0, clean |
| mypy | `uv run mypy --strict app` | exit 0, clean |
| pytest + coverage | `TEST_DATABASE_URL=…5434 TEST_REDIS_URL=…6380 uv run pytest --cov --cov-report=term-missing` | exit 1: everything passes except the 4 `test_homebox_acl.py` tests (the local Redis has no home-box ACL users; not changed by this lane). Coverage 95.11 %; `sporteventz.py` 87 %, `upsert.py` 95 %, `health.py` 99 % |
| OpenAPI current | `uv run python -m app.cli export-openapi` then `diff -r` | exit 0, no diff |
| Adapter parse tests on saved pages | `tests/adapters/test_sporteventz.py` inside the run | pass |
| CI on PR #47 | `gh run view 42367293885` | **backend `test` failed** on B1's live-window index tests (B1-R1-26) and the PR merged red; the PR body says "whole suite green" |
| infra check | CI `infra` job on #47 | pass |

## Findings

### CRITICAL

None.

### HIGH

#### B2-R1-1: A changed sporteventz record shape stays silent for 7 days, and skipped records are never counted
- Layer pipelines · Source FR-037 ("a changed page shape still is one at once"), FR-030 ("skip and count"), contracts/importers.md, constitution VII · `backend/app/adapters/sporteventz.py:187-236`, `backend/app/adapters/health.py:133-135`, `backend/app/adapters/tasks.py:196-200` · CONFIRMED
- Problem: only a missing `Records` key, access key or non-JSON answer raises `LayoutChanged`. A record whose `Sport`, `Begin`, `Team1` or `Team2` no longer reads is skipped into `self.skipped`, which nothing reads: the fetch task builds its result from `items` only and `ingest` uses a fresh adapter. With every record skipped the run is `succeeded` with 0 items, and the 7-day zero-items grace suppresses the alarm.
- Failure scenario: the site renames `Team1`/`Team2` (or changes the `Begin` format). Every record is skipped, every run "succeeds" with 0 items, and nobody is alerted for a week; A13 and `run.json` never show that 191 records were rejected.
- Fix direction: carry the skip counts and reasons into the run's log, and treat "records present, none usable, not all skipped as other sports" as `LayoutChanged`. Test that case, plus a `failed` run inside the grace still counting toward the breaker.

### MEDIUM

- **B2-R1-2** (spec/ops, CONFIRMED) sporteventz imports the site's whole ~2-week list, not "today to +3" (FR-030): `fetch` ignores `window` (`sporteventz.py:133`), and the fixtures hold 191 records from Nov 6 to Nov 16. The runbook, owner-actions and the PR body all state "today to +3". Filter by the window, or record the departure in R21 and fix the three docs.
- **B2-R1-3** (tests, CONFIRMED) `test_upsert.py:1072-1082` "never merge across sports" can't fail: for `sporteventz`, `_find_match` returns before any probe. The `Match.sport == item.sport` filters in `_duplicate_probe` (`upsert.py:507, 522`, the ysscores / legacy / manual path) are untested. Also untested: slot update and delete when broadcasters change (`upsert.py:365-368`), the sporteventz rate bucket (`ratelimit.py:49`), and its route and queue (`tasks.py:92, 704`).
- **B2-R1-4** (ops, CONFIRMED) Runbooks and `example.env` describe API-Football behaviour that isn't built: `secrets.md:121-132` (rotation steps), `imports-and-sources.md` (the intro and the `schedule_fetch '["api_football"]'` command), and `example.env`'s "Empty means the source stops on purpose". `schedule_fetch("api_football")` raises `ValueError` (no entry in `tasks.py:698-704`), and A13's «تشغيل الآن» can queue it, because `sources` seeds it enabled. Nothing is registered half-built (checked).
- **B2-R1-5** (ops, CONFIRMED) The new sporteventz "run now" block in `imports-and-sources.md` defines `dc` against `compose/vps2.yml`, then runs `dc exec postgres psql` under "VPS-1"; `vps2.yml` has no `postgres`. It also omits `manual: true`, unlike the YallaKora block.
- **B2-R1-6** (pipelines, PLAUSIBLE) `_write_fields` now writes `sport` on every update (`upsert.py:568`). The Sat Air bridge builds fixtures with the default `football` (`satair_bridge.py:119-138`), so a bridge run over an old sporteventz row repaired by `repair-matches sport` would set it back to football. Sources that don't state a sport shouldn't write it.
- **B2-R1-7** (spec, CONFIRMED) US4 scenarios 4–8, FR-034–FR-036 and SC-009 are not delivered: T059–T064 are correctly gated on the owner's API-Football checks, and T066 on a live run. Recorded so the day's done check accounts for it (Appendix A row 006 doesn't depend on it). tasks.md's "the whole lane is green" overstates the state.

### LOW

- **B2-R1-8** The card-sharing screen runs per joined slot (`upsert.py:339-350`): one flagged name drops slot 2's other names, and an empty broadcast list never clears stale importer entries.
- **B2-R1-9** Other-sport writes bump the football `matches` / `live` datasets (`upsert.py:171-176`): cache hit rate only.
- **B2-R1-10** `backend/CLAUDE.md` doesn't carry the new importer rules (`NO_RESOLVE`/`STRICT` sets, `stopped`, `report_link_change` from importers, `sport` compared in merges).
- **B2-R1-11** `docs/owner-actions.md` B2: the terms decision is labelled T052 (it's T067's), "dropping it is a one-line change to `SPORTS`" is wrong (an empty `SPORTS` fails every run and trips the breaker), and the "Open now" row still says "before B2's merge".

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US4-1 twice, no duplicates | `sporteventz.py`, `upsert.py` | `test_sporteventz_ingest.py:156` | OK |
| US4-2 editor's entries stay | `upsert.py:333` | `test_sporteventz_ingest.py:168` | OK |
| US4-3 football only for clients and poller | B1's reads; `livesoccertv.plan_targets` | `test_livesoccertv_plan.py:81` | OK (B2's part) |
| US4-4..8 API-Football | — | — | Not built, gated on T059 (B2-R1-7) |
| US4-9 names stay as text, queue doesn't grow | `upsert.py:200-206, 238` | `test_sporteventz_ingest.py:238` | OK |
| FR-030 sporteventz | `sporteventz.py` | `test_sporteventz.py` | Partly: window (B2-R1-2), counting (B2-R1-1) |
| FR-031 broadcaster slots | `sporteventz._broadcast_slots`, `upsert.py` | `test_sporteventz.py:171-203` | OK (B2-R1-8) |
| FR-032 no rows, no queue | `upsert.py` no-resolve | ingest tests | OK |
| FR-033 sport written and compared | `upsert.py` | `test_upsert.py` (B2-R1-3) | Code OK, guard untested |
| FR-037 both importers | adapter, health, tasks | tests | Partly (B2-R1-1) |
| FR-038 importers report link changes | `upsert.py:252, 662-677`, `livesoccertv_links.py:196-201` | `test_upsert.py`, `test_livesoccertv_links.py` | OK |
| FR-039 LiveSoccerTV skips other sports | `livesoccertv.py:513` | `test_livesoccertv_plan.py` | OK |

## Task audit

Ticked 17, verified 15, not done 0, partly done 2. Unticked T059–T064 and T066 are correctly gated (owner checks, live host).

| Task | Mismatch |
| --- | --- |
| T044 | The cross-sport merge test can't fail (B2-R1-3) |
| T053, T055 | Skips are counted only on a discarded adapter, never in the run (B2-R1-1) |
| T057 | The window registered is "today to +3", but the adapter ignores it (B2-R1-2) |
| T065 | Runbooks describe unbuilt API-Football behaviour and a broken run-now block (B2-R1-4, -5) |

## Owner must review

None of the listed kinds (no migration, contract, auth, audience query or UI). The owner decisions are sporteventz's terms (T067) and the API-Football checks (T059).

## Outside this change

- `HttpFetcher._check_host` ignores the scheme, so a same-host `http://` redirect is allowed (pre-existing).
- The four fixture HTML pages carry an anonymous Joomla guest `csrf.token`; harmless, but worth stripping.

## Not reviewed

- The 4 home-box ACL tests could not run against the local Redis.
- T066's live run and the API-Football tasks were not attempted (owner-gated).
