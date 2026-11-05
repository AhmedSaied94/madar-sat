# Implementation review: 005-d05-live-and-discovery, lane B1, round 1

- Date: 2026-11-04 · Reviewer: Claude Code (claude-opus-5-5), layer reviews by Sonnet subagents, every CRITICAL and HIGH re-checked on Opus
- Branch: d05-b1 · Base: d42c7de (the lane's own parent; `origin/master` would also pull in B2's merge and the docs commits) · Head: bccbf7a, plus 0 uncommitted files
- Change: 1 commit, 127 files (37 generated client files in other lanes' folders, which T017 assigns to B1), +19037 −196
- Verdict: **BLOCK** · CRITICAL 1 · HIGH 7 · MEDIUM 12 · LOW 6

## Checks

| Check | Command | Result |
| --- | --- | --- |
| ruff | `uv run ruff check .` | exit 0 |
| mypy | `uv run mypy --strict app` | exit 0, 171 files |
| pytest + coverage | `uv run pytest --cov --cov-report=term-missing` on throwaway `postgres:16.15` and `redis:7.4.12` (the CI images and credentials) | **exit 1: 1 failed**, `tests/adapters/test_schedule_fetch.py:210`. Coverage 95.21 % |
| OpenAPI current | `uv run python -m app.cli export-openapi && git diff --exit-code openapi/` | exit 0 |
| oasdiff against `contract-v1` | not run locally; read from CI run 41787246504 | **fails: 1 ERR**, `response-property-any-of-added` on `MatchDetail.lineups` |
| Clients current | `pnpm orval`, `dart run swagger_parser`, `dart run build_runner build -d` on a clean export of a9b4bed | exit 0, no diff. CI's `clients` job never ran, because `openapi` failed |
| Alembic upgrade | `uv run alembic upgrade head` on an empty database | exit 0 |
| Alembic autogenerate | `uv run alembic check` | exit 255, 83 differences. See "Outside this change" |
| Alembic downgrade with a linked match | a `filgoal` row in `match_external_ids`, then `uv run alembic downgrade 0006` | **exit 1, FK violation** (B1-R1-16) |
| PR #36 CI | `gh pr view 36` | `test` and `openapi` **failed at merge**; the PR was merged anyway |
| Bypass scan | diff searched for skip, xfail, noqa, type: ignore | No skips. One justified `noqa: BLE001`, and a `type: ignore[import-untyped]` for lxml as elsewhere |

## Findings

### CRITICAL

#### B1-R1-1: a final status is published over an open disagreement, so a wrong final score becomes permanent

- pipelines · Constitution II (NON-NEGOTIABLE), data-model "Pending candidate" (`disagreement ─(sources agree)─▶ confirmed`) · `backend/app/live/crosscheck.py:127-129`, `backend/app/services/live.py:20`, locked in by `backend/tests/live/test_crosscheck.py:335` · CONFIRMED (ran `decide`)
- Problem: `pending` is false once `disagreement_since` is set, so a final status is written while the score is still in dispute.
- Failure scenario: confirmed 1-1, FilGoal shows `finished` 2-1, YallaKora still 1-1, and the 180 s wait has passed. `decide` returned `write_status=True, status='finished', confirm=None`, so 1-1 is stored as the final score. `finished` is in `SETTLED_STATUSES`, so the match leaves the window and is never polled again. If YallaKora catches up a minute later, nothing reads it. Fans see the wrong result, with `estimated: false`, for good.
- Fix direction: don't write a final status while a candidate or disagreement is open. Keep polling until the sources agree or the hard limit moves the row to the clock. Replace the test that asserts the current behaviour.

### HIGH

#### B1-R1-2: every penalty shootout ends in a disagreement and loses its penalties

- pipelines · spec Edge Cases "Extra time and penalties", FR-004 · `backend/app/live/sources/yallakora.py` (has no penalty parsing at all), `crosscheck.py:82-90` · CONFIRMED (ran `decide`)
- Problem: YallaKora's `Score` always has `home_pen=None`, and the cross-check compares penalties as part of the score.
- Failure scenario: FilGoal `Score(1,1,4,3)`, YallaKora `Score(1,1)`, both `finished`. They can never agree. After the wait `decide` writes `finished` with no confirmed penalties and opens `disagree:<id>`, on every cup match that reaches a shootout.
- Fix direction: compare penalty fields only when both sources carry them, with the single-source rule for those fields, or parse them from YallaKora if the capture shows they exist.

#### B1-R1-3: one failed FilGoal request can move a live match back to `scheduled`

- pipelines · spec Edge Cases "One failed poll", contract "A status moving backwards needs two polls in a row" · `backend/app/live/cycle.py:329-335`, `backend/app/live/apply.py:30`, `crosscheck.py:121-126` · CONFIRMED (ran `decide`)
- Problem: `previous_status` is the status source's own last reading. A FilGoal failure comes back as `not_covering`, which makes YallaKora primary, and YallaKora's stored reading can already match its current one.
- Failure scenario: a live match, FilGoal has one timeout, YallaKora has said `scheduled` for two polls because it lags. `decide` returned `write_status=True, status='scheduled'`. The row goes to `scheduled` with no minute, on one failed request.
- Fix direction: compare against the status last written to the match, by the same source, and don't let a source that just took over move the status backwards until it has shown that status in two polls as primary.

#### B1-R1-4: a malformed page that isn't `LayoutChanged` kills the whole cycle, with no alert

- pipelines · US1 scenario 7, FR-005, FR-007 · `backend/app/live/sources/filgoal.py:163`, `backend/app/live/cycle.py:174,217` · CONFIRMED (a string in `Events` of the real fixture raises `AttributeError`; the only handlers around parsing catch `LayoutChanged`)
- Failure scenario: FilGoal changes one field's shape. `run_cycle` raises every minute, the `import_runs` row stays `running`, no `format:filgoal` opens, and the healthy YallaKora data isn't used either. After 5 minutes the watchdog hides every live score.
- Fix direction: treat any exception from a parser as a validation failure of that source, stop one match's error from ending the cycle, and always close the run row. Add tests with shape-changed models.

#### B1-R1-5: a postponed match is later shown as finished

- pipelines · spec Edge Cases "postponed… polling stops", data-model "Status mapping", constitution II · `backend/app/live/watchdog.py:29`, `backend/app/live/apply.py:45-58`, `backend/app/domain/status.py:53`, `backend/app/services/live.py:20` · CONFIRMED (read)
- Problem: `postponed` isn't settled, so the watchdog selects a `feed` row in that state, and `to_clock` resets it to `scheduled`.
- Failure scenario: a match is postponed in the window. At kickoff + 210 min, or as soon as its readings stop, the watchdog moves it to the clock and sends a false `stale:` alert. Clients then see `live` (estimated) or `finished` (estimated) for a match that never kicked off.
- Fix direction: the watchdog and fallback must leave `postponed` as stored, and polling should stop for it as the spec says. Add a watchdog test.

#### B1-R1-6: the backend suite is red on the merged head

- tests · Quality gates, T035 · `backend/tests/adapters/test_schedule_fetch.py:210`, caused by `backend/app/workers/__init__.py` adding `app.live.schedule` · CONFIRMED
- Problem: `assert 19 == (12 + 3)`. B1 added four beat entries, and the test counts two schedule modules. CI showed it on PR #36, which was merged with `test` failing, and `build` needs `test`.
- Fix direction: the file is B2's. See B2-R1-3. Ask B2 to fix it, then finish T035.

#### B1-R1-7: the `openapi` job is red, so nothing can build or deploy from `master`

- ops · FR-015, T017, `backend.yml` (`build: needs: [test, openapi, clients]`) · CI run 41787246504, `docs/owner-actions.md:545` · CONFIRMED
- Problem: oasdiff fails on `MatchDetail.lineups`. R15 predicted this and shows it's safe for old builds, but T017 only says to "write that in the PR", and nothing yet says how the gate gets passed. T020 needs a deploy through `backend.yml`.
- Fix direction: an owner decision, not a guess: move `contract-v1`, add an oasdiff exception for this one rule, or another way. Record it in `docs/runbooks/ci-workflows.md`.

#### B1-R1-8: revision 0007 breaks the running admin API during a deploy and after any rollback

- db · Constitution VI, checklist 4.C (expand/contract), `docs/system-design.md` deploy order · `backend/alembic/versions/0007_live_and_aliases.py:247-250`; old code `backend/app/schemas/admin.py:696` at d42c7de (`kind: Literal["scraper", "api", "internal"]`) · CONFIRMED (read). Graded HIGH rather than CRITICAL because only admin reads are affected and no data is lost.
- Problem: 0007 adds source rows with kinds `fixtures`, `live_reader` and `live`. The previous release loads every source row into that `Literal`.
- Failure scenario: from the migration until the new API is up, and for as long as a rollback stays in place, `GET /admin/api/sources` and anything built on it answer 500.
- Fix direction: 0007 isn't applied anywhere yet (the spec branch isn't on `master`), so it can still change: keep the kinds the previous release accepts, for instance with a separate new column, or ship the wider `Literal` in a release before the rows.

### MEDIUM

- **B1-R1-9** · `backend/app/live/apply.py:254` · CONFIRMED. On recovery a row goes clock → feed and writes the pre-fallback confirmed score. With one source back, an old score shows as live for at least one poll. Write on recovery only when it equals the current reading.
- **B1-R1-10** · `backend/app/live/apply.py:53`, `watchdog.py` · PLAUSIBLE. `to_clock` returns False for a locked row, so no `stale:` problem opens, and a locked feed row with a dead worker stays `live` with no alert. Open the problem even when the row can't move.
- **B1-R1-11** · `backend/app/live/cycle.py:140-144`, `backend/app/adapters/fetcher.py:145-165` · CONFIRMED. `is_allowed` checks the first path only, and the fetcher's redirect loop checks the host only, so a same-host redirect to a denied path is fetched (FR-012).
- **B1-R1-12** · `backend/app/live/cycle.py:236-244`, `links.py:60-64` · CONFIRMED. Every list row inside the time bounds is resolved, and unknown names queued, before anything checks that we hold such a match. Leagues we don't carry fill A13, `seen_count` climbs every minute, and `unresolved_names` bumps every cycle. Look for candidate matches by kickoff first.
- **B1-R1-13** · `backend/app/live/sources/yallakora.py:127` · CONFIRMED in code, the live page shape is unknown. A missing status line reads as `scheduled`, and the saved page suggests live pages may drop it. Raise `LayoutChanged` when the label is empty but a score or counter is present.
- **B1-R1-14** · `backend/app/live/sources/filgoal.py:162` · CONFIRMED. A model with no `Events` key reads as `()`, so the stored timeline is wiped, where T023 wants a missing field to raise.
- **B1-R1-15** · `backend/app/services/catalog.py:41` · CONFIRMED. `upcoming` requires `kickoff_at IS NOT NULL`, so a TBD match never reaches S8 and its «لم يُحدد» (US2-6) can't show, though the team page includes such matches. Mirror the predicate in `services/teams.py`.
- **B1-R1-16** · `backend/alembic/versions/0007_live_and_aliases.py:293` · CONFIRMED (ran it). `downgrade` fails with an FK violation once the poller has linked any match, and T002's snapshot-fixture downgrade doesn't cover linked data.
- **B1-R1-17** · `backend/app/services/match_detail.py:280`, `filgoal.py:193` · PLAUSIBLE. Raw `ShirtNumber` goes into JSONB and then a strict model. Saved pages have integers, but a `""` or `"GK"` in a live page gives a 500 on match detail. Normalize on write.
- **B1-R1-18** · `backend/app/services/admin/unresolved_names.py` · PLAUSIBLE. Two concurrent unscoped maps both pass the check, and the loser's PK violation becomes `422 validation_failed` where the contract says `409 alias_conflict`.
- **B1-R1-19** · `backend/app/live/tasks.py:35` · PLAUSIBLE. A 2 s token wait against a 2-token, 4 s bucket looks like 2–3 requests per host per cycle, so a cap of 8 match pages isn't reachable. Check it in the capture and report it.
- **B1-R1-20** · tests · CONFIRMED. `tests/live/test_cycle.py:48-70,156-158` and `test_filgoal_parse.py:83-121` use hand-written live pages, against FR-052 until the capture replaces them. `test_cycle.py:506-528` would still pass if alerts went out before commit. No test has real lock contention.

### LOW

- **B1-R1-21** · `cycle.py:266`, `179,225`: raw pages keep FilGoal's `Comments`, and the change hash covers `TimeElapsed`, so live pages may never count as unchanged (PLAUSIBLE, check disk use in the capture).
- **B1-R1-22** · `cycle.py:357`: `sync_problems` runs after the `live` bump, so the bump isn't the last statement.
- **B1-R1-23** · `backend/app/api/public/competitions.py:22`: the ETag datasets omit `satellites` and `commentators`, unlike the sibling routes. Capped by the 60 s bucket.
- **B1-R1-24** · `backend/app/services/admin/sources.py:296,320`: synchronous `send_task` inside an async GET, the existing pattern.
- **B1-R1-25** · `backend/app/services/admin/ordering.py:55,92`: about 4 queries per item on rights-holder reorder.
- **B1-R1-26** · `unresolved_names.py:195`: `scope_required` with no competition leaves the editor no way forward, and `similarity() >= 0.3` can't use the trigram index.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US1-1 capture | `app/live/capture.py` | `test_capture.py` | Tool built; T020–T022 not run (needs a deploy and a match) |
| US1-2 quiet window | `tasks.py`, `live_window_query` | `test_cycle.py` | Done |
| US1-3 poll, bump, cache | `cycle.py`, `apply.py` | `test_cycle.py`, `test_apply.py` | Done on replay |
| US1-4 both agree | `crosscheck.py` | `test_crosscheck.py` | Done |
| US1-5 one source, wait | `crosscheck.py` | `test_crosscheck.py` | **Wrong at full time: B1-R1-1** |
| US1-6 one down, two polls | `crosscheck.py` | `test_crosscheck.py` | Score done; status wrong: B1-R1-3 |
| US1-7 format change | `cycle.py` | `test_cycle.py` | **Partial: B1-R1-4** |
| US1-8 both down | `apply.py`, `watchdog.py` | `test_apply.py`, `test_watchdog.py` | Done, except B1-R1-5 |
| US1-9 manual, locked | `apply.py` | `test_apply.py` | Done |
| US1-10 events | `apply.py` | `test_apply.py` | Done, except B1-R1-14 |
| US1-11 facts, robots | `robots.py`, parsers | `test_robots.py` | Partial: B1-R1-11 |
| FR-015–FR-017 contract, admin APIs | `0007`, `api/admin/*` | `tests/admin/*`, `tests/db/*` | Built; B1-R1-7, B1-R1-8, B1-R1-16 |
| FR-061 load re-run | none | none | T040 open (owner T048 first) |
| SC-001, SC-005 real match | none | none | Not run; replay doesn't pass them |
| SC-002, SC-003 | `crosscheck.py`, `cycle.py` | replay tests | Hand-written live pages until the capture |
| SC-004 | `tasks.py` | `test_cycle.py` | Done |

## Task audit

Ticked 32, verified 30, not done 0, partly done 2. T020–T022, T035, T037–T040 are unticked and honest.

| Task | Ticked | Finding |
| --- | --- | --- |
| T002 | yes | The downgrade isn't tested with linked data (B1-R1-16) |
| T023 | yes | A missing `Events` doesn't raise (B1-R1-14) |

## Owner must review

- `backend/alembic/versions/0007_live_and_aliases.py`: the source kinds (B1-R1-8) and the downgrade (B1-R1-16).
- `backend/openapi/public.json` and `admin.json`: the `lineups` widening, and how to settle the oasdiff gate (B1-R1-7).
- `backend/app/services/admin/unresolved_names.py` and `rights_holders.py`: role checks and `If-Match`.
- `backend/app/live/crosscheck.py`: the rules behind B1-R1-1 to B1-R1-3. No push code changed.

## Outside this change

- PR #35 and #36 were merged with `test` red, and #36 with `openapi` and the admin `check` red too. #37 fixed the admin check, and the backend jobs haven't run since, because #37 and #38 don't touch `backend/`.
- T001 is unticked: the spec branch isn't on `master`, so nothing has deployed, and lanes target the spec branch rather than `master`.
- `alembic check` reports 83 differences across the whole schema. Almost all are indexes and constraints the models don't declare, or type spellings like `CHAR`/`String`, the same before this change, and no CI job runs it. The 10 for D5's tables are the same kind, so this is no new finding.

## Not reviewed

- The capture, the load re-run and anything on the deployed hosts (T020–T022, T037–T040).
- oasdiff wasn't run locally; the result comes from CI.
- The poller against real live pages: none exist yet.
