# Implementation review: 031-d05-live-sources, lane B1, round 1

- Date: 2026-11-05 · Reviewer: Claude Code, Opus 5.5, with eight Sonnet review agents whose findings were re-checked here
- Branch: d05-b1 · Base: 7c1d1b7 (merge base 7c1d1b7) · Head: 7c1d1b7, plus 55 uncommitted files
- Change: 0 commits, 55 files (0 in another lane's folders), +5854 −1194
- Verdict: BLOCK · CRITICAL 1 · HIGH 4 · MEDIUM 10 · LOW 9

The base is the commit that holds spec 031's plan and tasks, so this round covers only the spec's own work. Round 1 of spec 005 already covered the rest of D5.

## Checks

Run from `backend/`, with `TEST_DATABASE_URL` and `TEST_REDIS_URL` pointed at the dev stack.

| Check | Command | Result |
| --- | --- | --- |
| Lint | `uv run ruff check .` | Exit 0 |
| Format (not in CI) | `uv run ruff format --check .` | Exit 0 |
| Types | `uv run mypy --strict app` | Exit 0 |
| Tests and coverage | `uv run pytest -p no:cacheprovider --tb=line --cov --cov-branch --cov-report=term` | Exit 1: 2222 passed, 4 failed in 289 s. Total 94%, `app/live` 96%, against a bar of 70. All 4 are in `tests/adapters/test_homebox_acl.py` (see [Outside this change](#outside-this-change)) |
| Contract | `uv run python -m app.cli export-openapi && git diff --exit-code openapi/` | Exit 0 |
| Models and migrations | Fresh upgrade, then `compare_metadata`, at `0008` and at `0007` | 84 differences at each head, and the two sets are identical. None mentions a new name |
| The same tests at the base | `uv run pytest tests/adapters/test_homebox_acl.py` in clean `madar_sat/backend` at 7c1d1b7 | Exit 1: the same 4 fail, with `AuthenticationError` |
| Problem branches | `pytest tests/live/test_apply.py test_cycle.py test_watchdog.py test_tasks.py --cov=app.live.problems --cov-branch` | Exit 0: `problems.py` branch `61->63` is never taken |
| Shoot-out, through the real code | A scratch test running `decide`, `apply_decision` and `run_watchdog` on PostgreSQL | The match finishes 1–1 at kickoff + 151 ([B1-R1-1](#b1-r1-1-a-match-in-extra-time-or-a-shoot-out-is-finished-at-kickoff--150)) |
| Replaced goal, through the real code | A scratch script running `_write_events` against a stub session | Old goal stays, new one never lands ([B1-R1-2](#b1-r1-2-a-goal-event-whose-id-changes-at-the-same-score-can-never-be-replaced)) |
| Mutants | Three one-line changes to `crosscheck.py` in a scratch copy, then `test_crosscheck.py` and `test_replay.py` | All three pass, as the review agent found ([B1-R1-14](#b1-r1-14-rule-boundaries-that-no-test-pins)) |
| Single transaction | `psql -1` with SQL on stdin, on PostgreSQL 16, showing `pg_current_xact_id()` twice | The same ID twice. The removal block is one transaction, so a reviewer's doubt about it is dropped |
| Runbook literals (from the repo root) | `infra/scripts/check-doc-commands.sh`, which `infra.yml` runs when `docs/runbooks/` changes | Exit 0 |
| Secrets | `gitleaks` | NOT RUN: not installed here. CI runs it |
| The rest of `infra.yml` | Its other steps | NOT RUN: nothing under `infra/` or `.github/` changed in this lane |
| Generated clients | Regenerate Dart and TS | NOT RUN: the OpenAPI files didn't change |
| Image build | `docker build` | NOT RUN: no Dockerfile or dependency changed |

**Ways around the checks.** No `skip` or `xfail`, and no change to `pyproject.toml`, `uv.lock`, `.github/` or `alembic.ini`. New suppressions: three `# noqa: BLE001` in `capture.py` and one `# noqa: SLF001` in `test_replay.py`, which ruff's selected rules don't include, so they do nothing, and one `# type: ignore[arg-type]` at `capture.py:229`, with its reason. Tests were removed: see [B1-R1-5](#b1-r1-5-three-tests-were-deleted-and-the-re-open-path-lost-its-proof). The rewrites of `test_crosscheck.py` and `test_capture.py` follow T010 and T021.

## Findings

### CRITICAL

#### B1-R1-1: A match in extra time or a shoot-out is finished at kickoff + 150

- Layer: pipelines · Source: constitution II (NON-NEGOTIABLE) and VII ("so extra time and penalties aren't cut off"), FR-009, plan Complexity Tracking row 3 · Location: `backend/app/live/watchdog.py:40-67`, with `contracts/live-rules.md:106-113` · CONFIRMED by a run
- Problem: no parser maps an extra-time or penalty wording, because the first capture saw none. So those rows come in as `unknown_status`, and `decide` keeps the stored stage, as designed: `live`, `2H`. `_finish_stuck` then reads the row as an ordinary stuck second half. It never looks at unknown rows, so a quiet score and a peak of 90 or more finish it. The code follows the contract's stuck rule, so the contract has the gap too.
- Failure scenario: a 1–1 cup match reaches a shoot-out at about kickoff + 150, and no goal has come for 15 minutes. The scratch test ran this on PostgreSQL through the real `decide`, `apply_decision` and `run_watchdog`: at kickoff + 151 the row went from `live 2H` to `finished`, 1–1, with `home_pen` empty. Polling then stops and only a person can undo it, so the shoot-out is never recorded. The owner gets one `stuck:` alert, but fans see a false final result.
- Why the recorded exceptions don't cover it: row 1 covers a finish under FR-009, and FR-009 excludes extra time and penalties. Row 3 accepts an old stage during unknown statuses because "+ 210 bounds it", and the plan expects "the first cup night" to hit this path. Here + 150 cuts it off instead.
- Fix direction: treat a fresh reading from a usable source with no period, and a status of `NULL` or `live`, as still playing in `_finish_stuck`, so the row waits for + 210. `live` is needed because YallaKora's match page says `مباشر`, and `_with_list_stage` (`cycle.py:254`) leaves it with no period when its list row's status is unknown. An ordinary second-half row isn't affected. Change `live-rules.md`, FR-009, SD §6.7 and the runbook's stuck table with it (FR-025).

### HIGH

#### B1-R1-2: A goal event whose ID changes at the same score can never be replaced

- Layer: pipelines · Source: FR-011, FR-017 ("MUST NOT show the same goal twice"), constitution II · Location: `backend/app/live/apply.py:203-207`, `:221-238`; `backend/app/live/sources/goal.py:164-169` · CONFIRMED by a run
- Problem: `goals` counts every stored goal row, including rows the source no longer lists. So the insert guard refuses the new event, and `_event_gone` refuses to delete the old one: each waits for the other. Goal.com's event ID hashes the minute, extra time and scorer, so filling in a scorer or correcting a minute changes it. The same happens on FilGoal when a goal is ruled out and another comes within the 5-minute hold.
- Failure scenario, from the scratch run: at 1–0 the source replaces goal A with B. Thirty minutes later the timeline still shows A, and B has never landed. At 2–0 the source lists B and C, and the timeline shows A and B: the first goal twice and the second not at all. Polling ends at full time, so this stays. `/v1` serves it wherever FilGoal has no events.
- Fix direction: a missing goal whose hold has passed goes when the goals the source still lists for that side already cover the accepted score, and its replacement lands in the same poll. A and B never show together. A goal missing while nothing replaces it still stays with the score. Add "same score, event ID changes" and the 2–0 case as tests.

#### B1-R1-3: The capture never stops reading a source that blocks it

- Layer: pipelines · Source: US4 scenario 2 ("A block isn't evaded, and it stops the work on that source until the owner decides"), constitution VII, T026 · Location: `backend/app/live/capture.py:88-103`, `:114-127`, `:146-164` · CONFIRMED by reading
- Problem: `_save_page` treats a 403 or 429 like any other error and goes on, and `_watch_round` counts only list failures. Nothing stops the source, in code or in a test.
- Failure scenario: VPS-2 gets 403 on match pages while the list still answers. Every round, for four hours, the capture asks for up to 12 more pages and gets 12 more refusals, with no alert. If the list is refused too, the owner hears after 5 rounds, and the requests still go on until someone stops the whole capture. Pressing on against a block is how a block hardens.
- Fix direction: after a 403 or 429 on any page, make no more requests to that source in this round and tell the owner at once. If the next round is refused too, stop that source for the rest of the capture. A 5xx, a dropped connection and an empty bucket stay logged failures. `tasks.py` already tells an empty bucket apart by the fetcher's message.

#### B1-R1-4: The capture's errors never reach its log, and the log goes when it ends

- Layer: pipelines, ops · Source: FR-020 ("treat any read error as a logged result"), US4 scenario 3, FR-023 · Location: `backend/app/cli.py:109-138`, `backend/app/workers/logs.py:98-100`, `docs/runbooks/live-poller.md:194`, `:198`, `:208`, `:212`, `specs/031-d05-live-sources/quickstart.md:44` · CONFIRMED by a run
- Problem: `setup_logging` only runs on Celery's signal, and `python -m app.cli` never fires it, so `capture-live` runs on Python's default handler. It prints the bare message, with no `page` or `why`, and drops everything under WARNING. The tests pass because `caplog` sees the extras. Separately, `--rm` deletes the container when the capture ends, taking its log with it, and the runbook's `docker ps -a` then shows nothing.
- Failure scenario: a scratch script printed `capture_failed` and nothing else for a failure with `page=filgoal_list` and `why=Retryable: answered 403`. T028 must report "errors and blocks from VPS-2" per source. A capture costs a match night, and this one can't say what failed.
- Fix direction: call `setup_logging()` in `cmd_capture_live`, with a test on the real entry point that a failure's `page` and `why` reach the output. Remove `--rm` from both documents, and say to run `docker rm madar-capture` after writing the report and before a new capture.

#### B1-R1-5: Three tests were deleted, and the re-open path lost its proof

- Layer: tests · Source: review checklist ("deleted or skipped tests"), FR-006, the contract's Alerts table · Location: `backend/tests/live/test_apply.py` (removed `test_a_problem_alerts_once_while_open_and_once_on_recovery`, `test_the_alert_text_names_the_saved_page`, `test_closing_a_problem_that_never_opened_says_nothing`), `:609`; `backend/app/live/problems.py:61` · CONFIRMED by coverage
- Problem: no rule change explains these. `problems.py` only gained text, and its behaviour is the same. Nothing replaces them. Line 609 keeps one assertion from the third test, on the end of an unrelated `load_state` test, which also keeps the import in use.
- Failure scenario: coverage shows branch `61->63` is never taken, so no test re-opens a problem. Remove that path and the suite still passes, and then a source that breaks, recovers and breaks again never alerts the second time. Nothing asserts that an alert names the saved page either: `raw_ref` is only checked as a stored column.
- Fix direction: restore the three tests in place, with one open, close and re-open case for `unknown_status:` and for `stuck:`. Remove the assertion at line 609.

### MEDIUM

#### B1-R1-6: The capture and the poller compete for the same buckets, and a round takes minutes

- Layer: pipelines · Source: FR-015, FR-021, SC-001 · Location: `backend/app/live/capture.py:35`, `backend/app/cli.py:125`, `:170`, `backend/app/live/tasks.py:35`, `docs/runbooks/live-poller.md:200` · PLAUSIBLE: the arithmetic is certain, and the effect needs a live night
- Problem: each host's bucket gives 15 requests a minute. On a busy night the poller wants up to 9 on FilGoal and the capture up to 13, which is 22. The capture waits 60 s for a token and the poller 2 s, so the poller loses, with `out_of_tokens` skips and no alert. Each source's pages also run one after another, so a full round takes about 2.5 to 3 minutes, not the "about once a minute" the runbook gives. That can't resolve the 6 to 40 s delays T028 must report.
- Fix direction: pause the poller during a capture, or lower the default `--page-cap`, or give the capture a smaller wait, and say which in the runbook. T028 should measure what's left.

#### B1-R1-7: Page data becomes a URL path with no check

- Layer: security · Source: FR-013, spec 005 research R4 (the deny list is "checked before any request") · Location: `backend/app/live/sources/filgoal.py:62-63`, `:110`; `yallakora.py:111`; `goal.py:48`, `:154`; `backend/app/live/cycle.py:209-213`, `:284`; `capture.py:90`, `:125` · CONFIRMED by a run
- Problem: `is_allowed` checks the raw path, and httpx then normalizes it. An ID of `1/../../login` passes as `/matches/1/../../login/coverage/`, and the request goes to `/login/coverage/`, which the deny list refuses when asked directly. A YallaKora href of `:8080/x` reaches another port on the same host. The host can't change: `@evil.example/x` is refused by `_check_host`. So a hostile page can only steer us around its own site, which keeps this at MEDIUM.
- Fix direction: accept IDs matching `^[A-Za-z0-9_-]{1,64}$`, require paths that start with `/` and hold no `..`, `\`, `:` or `@`, and run `is_allowed` on the normalized path.

#### B1-R1-8: Scores and shirt numbers have no range or type check

- Layer: pipelines · Source: FR-013 ("every response is validated, and a failure stops only this source") · Location: `backend/app/live/sources/goal.py:72-88`, `:215`; `filgoal.py:157-168`, `:214`; `backend/alembic/versions/0002_mvp_additions.py:106-109`; `backend/app/live/cycle.py:611-613`; `backend/app/schemas/public.py:232` · CONFIRMED by reading, except the shirt number, which is PLAUSIBLE
- Problem: `isinstance(x, int)` accepts `True`, `-3` and `99999`. A negative score breaks `ck_matches_home_score`, and a huge one overflows `smallint`, so `_apply_match` rolls back and that match loses every source's update for as long as the page says so. A value that fits, such as 50, goes to fans at once, because a rise needs no second source. A non-numeric shirt number would make `LineupPlayer.number` fail on the match page.
- Fix direction: raise `LayoutChanged` for a score outside 0–99 or one that isn't a plain integer, and drop a shirt number that isn't one.

#### B1-R1-9: One malformed row on Goal.com's worldwide list stops the source

- Layer: pipelines · Source: FR-001's intent, FR-013 · Location: `backend/app/live/sources/goal.py:66-69`, `:112-113`, `:156-160`; `backend/app/live/cycle.py:131-138` · PLAUSIBLE: the mechanism is certain, and how often it happens isn't known
- Problem: the list holds about 89 matches from every competition. A fixture with `teamA: null` raises `AttributeError`, which `_validated` turns into `LayoutChanged`, so one row nobody polls makes Goal.com `invalid` for every match until that row leaves the page. `goal_list.html` is hand-built, so the parser hasn't seen a real list yet.
- Fix direction: on the list, skip and count a row with a bad structure, and fail the source only when the page's shape is wrong or most rows fail. Keep match pages strict. Look at this again with T027's real list.

#### B1-R1-10: Rolling back after Goal.com has stored rows breaks the older release

- Layer: db, ops · Source: `docs/runbooks/deploy-and-rollback.md:138` ("an older release runs on the newer schema") · Location: `git show 7c1d1b7:backend/app/live/apply.py:28-37`, `git show 7c1d1b7:backend/app/services/match_detail.py:271-278` · CONFIRMED by reading
- Problem: the schema is safe, and the data isn't. The older `_last_primary` calls `next()` with no default over a `SOURCES` without `goal`. So a match whose newest reading is Goal.com's alone raises `StopIteration` on every poll, before any new reading is stored. The older `_live_details` has no source filter, so a match with both sources' events shows its goals twice.
- Fix direction: add a step to the rollback runbook: set `LIVE_GOAL_ENABLED=false`, run the removal block, then roll back.

#### B1-R1-11: Goal.com's `psql` blocks run where there is no PostgreSQL

- Layer: ops · Source: root `CLAUDE.md` ("Every command in a runbook must match the code"), US3 scenario 5 · Location: `docs/runbooks/live-poller.md:126-127`, `:144`, `:155`, `:161`; `infra/compose/vps1.yml:208` · CONFIRMED by reading
- Problem: the section opens "On VPS-2", and `postgres` exists only in `vps1.yml`, so both blocks fail with "no such service". It fails safe, and the general note at line 121 hints at the answer, which keeps this below HIGH. But it's the approved way to remove the data if the approval ends.
- Fix direction: say "on VPS-1, in its `dc` shell" before each block.

#### B1-R1-12: Switching Goal.com off doesn't stop a capture already running

- Layer: ops · Source: FR-014, runbook accuracy · Location: `docs/runbooks/live-poller.md:150`, `backend/app/cli.py:127` · CONFIRMED by reading
- Problem: the runbook says no request goes "from the poller, the daily `robots.txt` check or the capture". The capture reads the setting once at its start, and `dc up -d worker-live worker-maintenance` doesn't touch its container.
- Fix direction: add `docker stop madar-capture` to the steps, or say a running capture isn't covered.

#### B1-R1-13: `owner-actions.md` has a dead link and a misplaced review

- Layer: ops · Source: root `CLAUDE.md`, Owner actions · Location: `docs/owner-actions.md:20`, `:543`, `:649-654` · CONFIRMED by reading
- Problem: line 543 links `#a-held-final-score`, a heading this change removed, and its sentence describes a rule that's gone. Row 031 puts the `0008` review under "After merge", though T017 and line 649 say before. The lane's items aren't split into before and after merge, and T026, T028, T029 and T035 have no runbook or quickstart link.
- Fix direction: correct all three in the lane's section and row.

#### B1-R1-14: Rule boundaries that no test pins

- Layer: tests · Source: live-rules tables, T010, T014, T021, FR-009, FR-014, FR-017 · CONFIRMED: `[run]` rows were re-run here, and the rest come from the review agent's mutants plus re-reading the tests
- Problem: the state machine's tests are strong on timers, and these still pass with a real bug in place:

| Where | Change that still passes | What it would break |
| --- | --- | --- |
| `crosscheck.py:328` | `known = list(readings)` `[run]` | An unknown row starts a backward-status hold, and later hits the assertion at `:186`. The only test, `test_crosscheck.py:907`, is one poll and doesn't check `status_drop_since`. This is the first cup night's path |
| `crosscheck.py:26`, `:238` | `MINUTE_SLACK = 20` `[run]` | FR-017's "more than 5 below". Tests use only 1 and 58 below |
| `crosscheck.py:241` | No same-period check `[run]` | Stored `45+3` in 1H holds back a 2H `47` |
| `crosscheck.py:34-44` | Penalties ranked with ET2, ET2 ranked 4 | Stage order past the second half, which no capture has seen |
| `crosscheck.py:150` | `_differ` compares only two sources | T010's three sources, for disagreement |
| `crosscheck.py:65`, `:81`, `:88` | `_covers`, `_same` or `_highest` ignoring a penalty side | T010's penalties |
| `watchdog.py:22`, `:44` | Any threshold from 71 to 104, or `<=` | FR-009's "below 90". Tests use peaks 70 and 104 |
| `watchdog.py:91` | No `_status_locked` at + 210 | T014's "`manual` and `locked_fields` win". `test_watchdog.py:93` has no period, and `:329` is at + 150 |
| `apply.py:236` | `>` for `>=` | A second goal written while the score is still 1–0 |
| `apply.py:281` | `<=` for `<` | A corrected lineup from the same source refused |
| `capture.py:124` | No ID sanitizing | `test_capture.py:186` uses a Goal.com ID that never gets a page, so it proves nothing |
| `capture.py:153`, `:159` | `>` for `>=` | FR-021's 5 rounds. Tests use 7 and 6 |
| `config.py:19-30` | `goal_enabled` default `False`, other defaults changed | FR-014's "on by default" |

- Fix direction: add these cases. Start with the unknown row over two polls, which [B1-R1-1](#b1-r1-1-a-match-in-extra-time-or-a-shoot-out-is-finished-at-kickoff--150)'s fix will touch anyway, and one test asserting every default in `data-model.md`.

#### B1-R1-15: Nothing enforces that B2's bucket merges first

- Layer: pipelines · Source: FR-015, tasks.md dependency graph ("B2 T030–T032 ─▶ B1's Goal.com fetches") · Location: this tree's `backend/app/adapters/ratelimit.py:99-101` · CONFIRMED by reading
- Problem: this tree has no `www.goal.com` bucket, `RateLimiter.take` returns `True` for an unknown host, and `LIVE_GOAL_ENABLED` is on by default. If B1 merges first, Goal.com is limited only by the page cap. B2's own section passed review, so this is a dependency to note, not B2's defect.
- Fix direction: add a B1 test that every host in `ROBOTS_COPIES` has a bucket in `DEFAULT_LIMITS`, which fails until B2 is in. State the merge order in `owner-actions.md`.

### LOW

#### B1-R1-16: A disagreement alert can fire on one reading

- Layer: pipelines · Source: FR-006 · Location: `backend/app/live/crosscheck.py:333-336` · CONFIRMED by reading
- Problem: `since` carries through a poll with one reading, and `alert` doesn't need a difference seen now, so a source going quiet at minute 9 can open `disagree:` at minute 10.
- Failure scenario: a false alert, followed by a recovery message when the source returns.
- Fix direction: `alert = differ and since is not None and now - since >= disagree_after`.

#### B1-R1-17: A frozen minute stays current past + 150

- Layer: pipelines · Source: research R5, FR-017 · Location: `backend/app/live/apply.py:87-89` · CONFIRMED by reading
- Problem: when `to_clock` refuses, the row keeps its minute, and Complexity Tracking row 4 accepts an old score but not an old minute.
- Failure scenario: every source goes down at + 155 on `90+4`, and `/v1/live` shows `90+4` as live until the stuck step.
- Fix direction: clear `minute` on the refusal.

#### B1-R1-18: `unknown_status:<source>` opens for rows nobody polls

- Layer: pipelines · Source: FR-001 · Location: `backend/app/live/cycle.py:248` · CONFIRMED by reading
- Problem: it's filled from every list row before linking.
- Failure scenario: one abandoned match anywhere on Goal.com's worldwide list raises an alert, and its 5-day "add the wording" step, about a match we don't carry.
- Fix direction: count only rows linked into the window, or lower its urgency in the runbook.

#### B1-R1-19: Goal.com can stop sending scores with no alert

- Layer: pipelines · Source: FR-013 · Location: `backend/app/live/sources/goal.py:126-131`, against `filgoal.py:97` and `yallakora.py:93` · CONFIRMED by reading
- Problem: the other two readers call `require_score` for played rows and this one doesn't, on purpose (`test_a_live_row_with_a_null_score_stays_usable`).
- Failure scenario: Goal.com drops scores from live rows and stays valid, and a `RESULT` row with no score still counts as a full-time vote.
- Fix direction: require a score on played rows, or alert when live rows carry none.

#### B1-R1-20: A heartbeat error can lose the watchdog's alerts

- Layer: pipelines · Source: FR-021 · Location: `backend/app/live/tasks.py:139-144`, `backend/app/live/capture.py:213-218` · PLAUSIBLE: only a corrupt Redis key gets here
- Problem: `check_heartbeat` runs before the watchdog's alerts are sent, and catches only Redis and OS errors. A bad encoding or a naive timestamp raises out of it.
- Failure scenario: the alerts already marked as sent in the committed transaction are lost.
- Fix direction: send the alerts first, or catch the error in the task.

#### B1-R1-21: The one-source choice ignores freshness and sides

- Layer: api, pipelines · Source: FR-017 · Location: `backend/app/services/match_detail.py:277`, `backend/app/live/apply.py:289-302` · PLAUSIBLE: this follows R9's words
- Problem: events come from FilGoal if it has any row at all, and lineups from the first source with either side.
- Failure scenario: FilGoal loses its page slot mid-match and its timeline stops growing while Goal.com's is complete. FilGoal with only a home lineup means the away side is never stored.
- Fix direction: decide with T028's data whether this matters.

#### B1-R1-22: Small document drift

- Layer: ops · Source: root `CLAUDE.md`, Runbooks · Location: as listed · CONFIRMED by reading
- Problem:
  - `docs/runbooks/live-poller.md:41` says "up to 10 minutes", and the plan's row and `:43` make it about 15.
  - `quickstart.md:79` says "restart", and the runbook says `dc up -d`.
  - `docs/runbooks/README.md:37` doesn't mention switching Goal.com off.
  - `specs/005-d05-live-and-discovery/contracts/live-pipeline.md:81` still lists `LIVE_CONFIRM_WAIT_S`.
  - `backend/app/schemas/public.py:222` still says goal events are "absent while their score is unconfirmed". Changing it changes the OpenAPI, so it needs a re-export and regenerated clients.
  - `contracts/live-rules.md:52` was widened during implementation (`live` with no period now covers extra time and penalties, and the list row's stage fills in), and `spec.md` doesn't mention it. It's the safe direction.
- Failure scenario: a reader trusts an older sentence.
- Fix direction: correct each with the next change that touches it.

#### B1-R1-23: Small edges in the capture and the robots check

- Layer: pipelines · Source: FR-020 · Location: `backend/app/cli.py:169-170`, `backend/app/live/capture.py:120`, `backend/app/live/robots/goal.txt`, `backend/app/live/robots_check.py:34` · CONFIRMED by reading, except the Sitemap effect, which is PLAUSIBLE
- Problem: `--page-cap -1` slices from the end of the list. `goal.txt` is 36 `Sitemap:` lines around one rule, and the comparison only strips blanks.
- Failure scenario: a mistyped cap reads the wrong rows, and Goal.com adding a locale opens `robots:www.goal.com` with no rule changed.
- Fix direction: reject a negative cap in the parser, and leave `Sitemap:` lines out of the comparison.

#### B1-R1-24: Fixtures keep real players' names

- Layer: tests · Source: FR-022 ("no personal data") · Location: `backend/tests/live/fixtures/goal_match_stats.html`, the FilGoal match fixtures · PLAUSIBLE: a question for the owner
- Problem: they hold public footballers' names and shirt numbers, which the app shows anyway and which the parser tests need.
- Failure scenario: none in practice, unless the owner reads FR-022 more strictly.
- Fix direction: the owner decides, then T027 follows it.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US1.1, FR-001, SC-003: YallaKora live statuses, an unknown one affects its row only | `yallakora.py:33-41`; `cycle.py:254`, `:429-438`; `crosscheck.py` | `test_the_list_reads_every_status_the_capture_saw`, `test_mubashir_on_a_live_match_page_is_live_with_no_half`, `test_a_page_with_no_period_takes_the_stage_from_its_list_row`, `test_an_unknown_status_with_a_score_counts_and_keeps_the_match_fresh` | Met, see B1-R1-14 |
| US1.2, FR-002, SC-004: FilGoal's minute, both clock forms, never negative | `filgoal.py:133-155` | `test_the_minute_handles_both_forms_of_the_clock`, `test_no_minute_is_ever_negative`, the replay's clock tests (97.9% of 1,367) | Met |
| FR-003: types 4, 20, 9, and an own goal's side | `filgoal.py:54`, `:193-198` | `test_leipzigs_own_goal_counts_for_the_away_side`, and the red card and missed penalty tests | Met |
| US1.3, FR-004, SC-001: a rise goes out in the first poll | `crosscheck.py:131-147` | `test_a_rise_from_any_source_goes_out_at_once`, replay (longest 40 s) | Met |
| US1.4, US1.5, FR-005: a drop waits 5 minutes, and the goal leaves the timeline | `crosscheck.py:136-147`; `apply.py:210-240` | `test_two_sources_agreeing_on_a_lower_score_*`, `test_only_mouloudias_false_score_ever_goes_down`, `test_a_goal_past_what_the_score_needs_goes_at_the_hold` | Met |
| US1.6, FR-006, SC-002: disagreement alerts | `crosscheck.py:331-337`, `:352-357` | `test_a_disagreement_alerts_at_ten_minutes`, `test_a_disagreement_closes_when_they_agree`, `test_a_finished_match_that_differs_alerts_as_it_finishes`, replay | Met, see B1-R1-16 |
| FR-007: status moves | `crosscheck.py:200-228`, `:317` | `test_a_later_status_goes_out_at_once_from_any_source`, `test_a_backward_status_holds_for_five_minutes`, `test_a_final_status_never_returns` | Met |
| US2.1, FR-008: the full-time rules | `crosscheck.py:258-289`, `:349-358` | `test_two_sources_showing_full_time_finish_at_once` through `test_a_new_score_and_full_time_in_one_poll_*`, and the cycle's hold tests | Met for the rules as written. No parser yet produces the extra-time status they protect against |
| US2.2: finished stays finished | `crosscheck.py:317`; the poll window | `test_a_final_status_never_returns` | Met |
| US2.3, FR-009, FR-010, SC-005: stuck matches and the clock guard | `watchdog.py:40-67`, `:90-96`; `apply.py:73-95` | `test_bristol_city_v_wolves_finishes_on_its_score_at_the_stuck_limit`, the limit tests, the clock tests from all 3 callers, replay (14 of 16) | **Not met** for extra time and penalties: [B1-R1-1](#b1-r1-1-a-match-in-extra-time-or-a-shoot-out-is-finished-at-kickoff--150). Met otherwise |
| US2.4: red card, own goal, missed penalty stored | `filgoal.py`; the check in `0007` | the FilGoal parse tests | Met |
| FR-011: missing events, no duplicates | `apply.py:203-240` | `test_a_missing_event_stays_under_the_hold_and_goes_at_it`, `test_events_are_idempotent` | **Partly met**: [B1-R1-2](#b1-r1-2-a-goal-event-whose-id-changes-at-the-same-score-can-never-be-replaced) |
| FR-012: one pure function, and the clock only when all enabled sources are down | `crosscheck.py:307-371`; `cycle.py:429-438` | table tests, `test_every_enabled_source_must_be_down_before_the_clock` | Met |
| US3.1–US3.3, FR-013–FR-016: Goal.com's reader, off switch, names, order | `goal.py`; `cycle.py:159-197`, `:556-615`; `robots.py`; `robots_check.py` | `test_goal_parse.py`, `test_three_sources_are_read_in_one_cycle_goal_com_last`, `test_switched_off_goal_com_gets_no_request_and_writes_nothing`, `test_goal_com_names_reach_the_queue_under_goal_and_no_team_is_made` | Met, apart from B1-R1-8, B1-R1-9 and B1-R1-15 (bucket in B2) |
| FR-017: the minute rules, one events source, one lineup source, no goal shown twice across sources | `crosscheck.py:231-244`; `apply.py:116-150`, `:263-302`; `match_detail.py:268-282` | `test_a_minute_more_than_five_below_the_peak_*`, `test_the_wrap_never_shows_even_after_the_stored_minute_was_cleared`, `test_a_real_minute_in_another_period_stands_*`, `test_events_come_from_filgoal_when_it_has_any_*`, `test_a_lineup_comes_from_the_first_source_that_has_one_*` | Met across sources. Within one source see B1-R1-2 |
| US3.4, FR-018: stats stored, `/v1` unchanged | `0008_live_sources.py`; `apply.py:305-314` | `test_0008_live_sources.py`, `test_stats_are_stored_only_on_change_*`, OpenAPI diff exit 0 | Met |
| US3.5, FR-014: off switch and the runbook's removal | `live-poller.md`; `owner-actions.md` T002 | no automated test (docs) | **Partly met**: B1-R1-11, B1-R1-12 |
| FR-019: D6's bar | `spec.md`; `crosscheck.py:122`; `apply.py:107-108` | `test_the_first_score_is_accepted_with_its_source_and_time` | Met |
| US4.1, FR-020: the capture tool | `capture.py`; `cli.py:109-138`; `tasks.py:125-144` | `test_capture.py` | **Partly met**: [B1-R1-4](#b1-r1-4-the-captures-errors-never-reach-its-log-and-the-log-goes-when-it-ends). The run itself is T026 |
| US4.2, FR-021: told during the capture, and a block stops the source | `capture.py:146-164`, `:221-237` | `test_capture.py` | **Not met** for a block: [B1-R1-3](#b1-r1-3-the-capture-never-stops-reading-a-source-that-blocks-it). Met for a source failing or going quiet, and a dead capture |
| US4.3, US4.4, FR-022–FR-025, SC-007, SC-008 | none yet | none yet | Not yet: T026–T029, correctly unticked |
| SC-006: Goal.com off | `cycle.py:598` | `test_switched_off_goal_com_gets_no_request_and_writes_nothing` | Met |
| FR-026–FR-028: docs, moved notes, lane boundaries | `owner-actions.md`, runbooks | 0 files in another lane's folders | Met, apart from B1-R1-13 |

## Task audit

Ticked 23, verified 14, not done 0, partly done 9. Unticked and correctly open: T026, T027, T028, T029, T035.

| Task | State | Why |
| --- | --- | --- |
| T010 | Partly done | "1, 2 and 3 sources in every order" isn't met for disagreement or penalties (B1-R1-14) |
| T011 | Partly done | SC-003 is only implied, through the parser tests and the status maps |
| T013 | Partly done | No upgrade and downgrade "on the snapshot": `test_0008_live_sources.py` uses an empty database and hand-made rows |
| T014 | Partly done | "`manual` and `locked_fields` win" isn't tested at + 210 (B1-R1-14) |
| T018 | Partly done | Events with `missing_since` can't be replaced (B1-R1-2) |
| T021 | Partly done | The 5-round boundaries aren't pinned (B1-R1-14), and logging is only proven through `caplog` (B1-R1-4) |
| T022 | Partly done | B1-R1-3, B1-R1-4 |
| T023 | Partly done | Wrong host and a wrong claim in the runbook (B1-R1-11, B1-R1-12) |
| T025 | Partly done | B1-R1-13 |

T024's figures were re-run here and hold. T019 does what its task says: the gap in B1-R1-1 is in the contract it follows.

## Owner must review

- `backend/alembic/versions/0008_live_sources.py` (T017): expand-only, all columns nullable, `match_stats` with `ON DELETE CASCADE`, `sources` gets `('goal', 'internal')`, and what its downgrade deletes. The agent review of it found nothing wrong, and it's still yours to read before merge.

There's no API contract change, auth or permissions code, push audience query or UI screen in this change.

## Outside this change

- `tests/adapters/test_homebox_acl.py`: 4 tests fail on the local Redis with `AuthenticationError`, the same at 7c1d1b7 in clean `madar_sat`. It's B2's file, so CI must settle it.
- Autogenerate reports 84 differences at both `0007` and `0008`, and they're the same set. They predate this change, and no test checks for them.
- **Worth measuring in T028:** the page caps are mostly out of reach. A bucket of 2 tokens, with a 2 s wait (`tasks.py:35`), gives FilGoal the list and about 2 pages a cycle, not 9, and `pick_slots` gives those to the same matches each time. That affects SC-004 and the stuck rule's peak minute.
- `cycle.py:237`: a successful list read clears the strikes a page's 429 just added, so page-level backoff never grows.
- `robots_check.py:31` doesn't catch `OutOfTokens`, so an empty bucket ends the daily check and leaves the remaining hosts unread.
- `docs/runbooks/live-poller.md:108-118` labels `dc exec postgres` and `dc exec redis` as VPS-2. Fix it with B1-R1-11.
- `POST /admin/api/sources/{goal,filgoal}/pause` returns 200, and the poller ignores it (`services/admin/sources.py:230`). FilGoal already behaved this way, and `GET /sources` hides `goal`.
- `links.py`'s `link_reading` trusts a stored link for good.
- `_write_event`'s update path, `stale:` closing when readings resume, and `PageHashes.changed` on bytes have no test.
- B2-R1-1 (a dropped connection trips the host's backoff) needs a line in `cycle.py` here if it's fixed. See `reviews/b2-round-1.md`.

## Not reviewed

- Anything on VPS-2 or against the live sites, and T026–T029, T035 and DC1, which need a deploy and match nights.
- `gitleaks`, image builds and client regeneration, as in Checks. A reviewer read the diff for secrets and found none.
- B1 and B2 merged together: only `docs/` was trial-merged, with 0 conflicts. Each lane's tests ran on its own tree.
- Mutants on `apply.py`, `watchdog.py` and `capture.py`'s database-free parts rest on the review agent's work and on reading the tests. Only the three `crosscheck.py` mutants marked `[run]` were re-run here.
