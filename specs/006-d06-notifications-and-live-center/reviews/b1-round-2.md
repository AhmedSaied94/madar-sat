# Implementation review: 006-d06-notifications-and-live-center, lane B1, round 2

- Date: 2026-11-09 · Reviewer: Claude Code (Opus 5.5, `claude-opus-5-5`), with one Sonnet reviewer on the round-1 fix commit; every finding below re-checked on Opus
- Branch: `d06-b1` · Base: `origin/master` (merge base `b7fd7d9`) · Head: `0d945f2`, plus 0 uncommitted files
- Change: 19 commits, 309 files (177 in another lane's folders), +38 076 −560. Of those, B1's own commits are `3a5b40b`, `9eee57e`, `a76f339` (round 1) and `0d945f2` (the round-1 fixes, this round's delta). The 177 other-lane files are: the regenerated admin client (`admin/src/api/generated/*`, 4 files) and Dart client (`app/lib/core/network/generated/models/*`, 6 files) from B1's own commits, both assigned by T019; everything else came in with the merges of PRs #47 (B2), #48 (A) and #49 (M) into the spec branch, which `d06-b1` was fast-forwarded onto. Those are the other lanes' to review and are not reviewed here.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 3 (new) · LOW 3 (new); round-1 MEDIUM/LOW notes still open are listed under "Previous round"

## Checks

| Check | Command | Result |
| --- | --- | --- |
| ruff | `cd backend && uv run ruff check .` | exit 0, "All checks passed!" |
| mypy | `uv run mypy --strict app` | exit 0, no issues in 186 source files |
| pytest + coverage | `TEST_DATABASE_URL=postgresql://madar:changeme@localhost:5434/madar TEST_REDIS_URL=redis://:changeme@localhost:6380/0 uv run pytest -q --cov` (PostgreSQL 16 + Redis 7 from `infra/compose/dev.yml`; the URLs from `docs/runbooks/local-dev.md`) | exit 1, coverage 95.27 %: 16 failures, none in this round's delta. 4 are `tests/adapters/test_homebox_acl.py` (B2's file; the local Redis has no home-box ACL users, as in round 1). 12 are `test_ratelimit.py`, `test_login.py`, `test_change_password.py` (counts of `200` where `429` was due, an extra `auth:lock:` key): other review agents ran pytest on the same Redis DB at the same time, and `redis_client` clears only shared prefixes |
| pytest rerun, isolated Redis | same, with `TEST_REDIS_URL=redis://:changeme@localhost:6380/11`: `uv run pytest -q tests/api/test_ratelimit.py tests/auth/` | exit 0, all pass |
| OpenAPI current | `python -m app.cli export-openapi` on a scratch copy of `backend/` with `backend.yml`'s placeholder env, then `diff -r` against the committed `openapi/` | exit 0, no diff |
| Admin client current | `pnpm orval` on a scratch copy of `admin/` against the committed `admin.json`, then `diff -r src/api/generated` | exit 0, no diff |
| Dart client current | NOT RUN this round: `public.json` is unchanged since round 1 (`git diff a76f339 0d945f2 -- backend/openapi` touches only `admin.json`), and round 1 regenerated it with no diff. Flutter tooling runs only on the test box | — |
| oasdiff (`/v1` non-breaking) | NOT RUN (Docker image, CI only); `public.json` unchanged since round 1 | — |
| CI on `0d945f2` | NOT RUN: the commit is not pushed (`origin/d06-b1` is `a76f339`) | — |
| Ways around the checks | `git show 0d945f2` searched for `noqa`, `type: ignore`, `skip`, `xfail` | one `# type: ignore[method-assign]` in `tests/notifications/test_producers.py` (B1-R2-6); no skips, no config changes |

## Previous round

| Finding | Now |
| --- | --- |
| B1-R1-1 `match_started` never on a normal kickoff (HIGH) | **Fixed.** `producers.py:142-168` records `live_seen: false` when the match is first evaluated before play; `apply_decision` always creates the `match_live_state` row first (`live/apply.py:350-352`), so the flag persists. `test_a_normal_kickoff_announces_match_started_once` drives scheduled → live through `cycle._apply_match` with nothing seeded |
| B1-R1-2 `If-Match` unreachable for A16/A15 (HIGH) | **Fixed on B1's side.** `AdminUserRow.etag` / `NotificationRow.etag` (`schemas/admin.py:897, 966`) carry `etag_of(row_state(row))`, the value `lock_and_check` compares; tests take it from the list and are refused with the list header. Lane A's pages still send the list `ETag` (`UsersPage.tsx:59`, `NotificationsPage.tsx:102`), tracked as A-R1-1 |
| B1-R1-3 new account unflagged (HIGH) | **Fixed.** `users.py:110` `must_change_password=True`; `test_a_new_account_must_change_its_temporary_password_first` proves the 403 and that `auth/me` works |
| B1-R1-4 off switch does nothing (HIGH) | **Fixed.** `push-notifications.md:128-145` appends or replaces, uses `on-call.md`'s preamble, `--force-recreate`s `worker-notify`, and fails unless the worker reports the list. Two weaker spots in the companion blocks: B1-R2-2, B1-R2-5 |
| B1-R1-5 T024/T028 cases untested (HIGH) | **Fixed.** Correction guard both ways, locked score, abandoned/postponed/cancelled, watchdog finish and a later poll, editor finish over the limit, retried and overlapping poll, `kick_dispatch` after commit, alert after commit on both the all-refused and `MAX_ATTEMPTS` paths. Gaps left: B1-R2-4 |
| B1-R1-6 audience tests can't fail (HIGH) | **Fixed.** `test_push_types.py` dispatches one row at a time and asserts exact device sets per kind, a goal's audience, the master switch on a goal and a reminder, and a `match_started` opt-in |
| B1-R1-7 `last_admin` race | Still open (note) |
| B1-R1-8 reach undercounts a match audience | Still open (note) |
| B1-R1-9 synchronous `send_task` in async handlers | Still open (note) |
| B1-R1-10 announcement/test send bump no dataset | Still open (note) |
| B1-R1-11 no index for A17's order and filters | Still open (note) |
| B1-R1-12 `GET audit/{id}` has no `ETag` | Still open (note) |
| B1-R1-13 error codes only in `info.description` | Still open (note) |
| B1-R1-14 engine without `hide_parameters` | Still open (PLAUSIBLE note) |
| B1-R1-15 `repair-matches sport --apply` bumps no dataset | Still open (note) |
| B1-R1-16 `push` problem flaps; alert before commit | Partly fixed: the failed-path alert now goes after commit (`dispatcher.py:723-737`); the close on a 0-device row (`_alert`, `dispatcher.py:667-676`) is unchanged |
| B1-R1-17 watchdog-finished row gets `final_score` from a racing poll | **Fixed** by `status_before` (`cycle.py:520`, `producers.py:214`); see B1-R2-1 for its cost |
| B1-R1-18 editor `final_score`/correction with no age bound | Still open (note) |
| B1-R1-19 non-`Retryable` errors leave a row `sending` | Still open (note) |
| B1-R1-20 per-device queries while building messages | Still open (note) |
| B1-R1-21 `last_error` loses the HTTP status; `test_sender.py` bullet | Still open (note) |
| B1-R1-22 T025/T026 test gaps | Still open (note) |
| B1-R1-23 A4 bulk remove skips `report_link_change_async` | Still open (note) |
| B1-R1-24 audience-review section describes the old query | Still open: `push-notifications.md:174-182` still describes one `AUDIENCE` with the `kickoff_reminder` condition, and `:22` still says "claims up to 10 due rows". The owner's T037 gate reads this section |
| B1-R1-25 runbook commands that don't match the code | Still open (`imports-and-sources.md:300,304` `/srv/madar/compose.yml`; `load-testing.md:193`) |
| B1-R1-26 live-window index test unstable | Still open (PLAUSIBLE note) |
| B1-R1-27 `backend/CLAUDE.md` unchanged | Still open: `git diff b7fd7d9 HEAD -- backend/CLAUDE.md` is empty |
| B1-R1-28 … B1-R1-35 (LOW) | Still open, unchanged code |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

#### B1-R2-1: A producer failure on the finishing poll now loses `final_score` for good
- Layer pipelines · Source FR-007, FR-008, `producers.py` module docstring ("The next poll tries again") · `backend/app/notifications/producers.py:214`, `backend/app/live/cycle.py:545-550` · CONFIRMED by reading
- Problem: `final_score` is written only when `status_before != "finished"`, i.e. only by the poll that finished the row. That poll runs `record_poll` in a savepoint; if anything before `_final_score` raises (the goal bar, a goal insert), the savepoint rolls back, the match still commits as `finished`, and the match then leaves the poll window (`live_window_query` excludes settled statuses, and `decide` changes nothing on a final status). No later code path writes the row.
- Failure scenario: a bug in the goal-bar evaluation on the 90′ poll that also flips the match to `finished` logs `push_producers_failed`; followers never get «انتهت المباراة», and nothing alerts (B1-R1-33).
- Fix direction: run `_final_score` in its own savepoint ahead of the goal work, or keep the `status_before` rule but let `_apply_match` retry the producers once; fix the docstring either way.

#### B1-R2-2: The "turn every type back on" check passes when the worker didn't come back
- Layer ops · Source FR-021, T040 · `docs/runbooks/push-notifications.md:149-154` · CONFIRMED by reading
- Problem: `got=$(dc exec -T worker-notify printenv PUSH_TYPES_OFF)` is empty both when the value is cleared and when `dc exec` fails (the container is restarting, or `dc` is undefined in a new shell), and `[ -z "$got" ]` then prints "every type on".
- Failure scenario: after the first-night incident the owner turns pushes back on; `worker-notify` crash-loops on the recreate; the block prints "every type on" and no push goes out until someone notices.
- Fix direction: check `dc exec`'s exit status (or print a sentinel such as `${PUSH_TYPES_OFF-UNSET}`) and fail on anything but an empty, set value.

#### B1-R2-3: The audience review the owner signs off (T037) still describes the old query
- Layer ops · Source T037, T040, `CLAUDE.md` runbook rule · `docs/runbooks/push-notifications.md:174-182` · CONFIRMED
- Problem: this is B1-R1-24 still open, raised here only because the round-1 fixes edited this file and the push PR's merge gate depends on this section. It names one `AUDIENCE` and the `kickoff_reminder` condition, not the three queries (`AUDIENCE`, `AUDIENCE_ALL`, `AUDIENCE_DEVICE`) with the per-type and master-switch conditions.
- Failure scenario: the owner reviews the query against the runbook's description, finds them different, and either signs off something the runbook doesn't describe or blocks the merge.
- Fix direction: describe each of the three queries, per `kind`, with the master switch and type defaults, as the code has them.

### LOW

- **B1-R2-4** (tests, CONFIRMED) `test_a_match_first_seen_at_thirty_minutes_is_a_silent_baseline` (`tests/notifications/test_producers.py:310`) can't fail on the rule it names: at kickoff − 30 min the 15-minute window already stops it (the rule is covered by the older `test_a_match_already_in_play_on_its_first_evaluation_only_sets_the_flag`). No test covers `match_started` for a `clock` or `manual` in-play row whose `live_seen` is `false` (`producers.py:142-149`).
- **B1-R2-5** (ops, CONFIRMED) `deploy-and-rollback.md:146-148` says to run the off switch "with `OFF=<all six>`", but the block itself assigns `OFF=goal,match_started` (`push-notifications.md:135`), so an operator who sets `OFF` first and pastes the block stops two types, and the final check still passes. Say "edit the `OFF=` line" or use `OFF=${OFF:-goal,match_started}`.
- **B1-R2-6** (tests/process, CONFIRMED) `0d945f2` adds a `# type: ignore[method-assign]` in `test_producers.py` (tests are outside `mypy --strict app`, so harmless; pass `deps` in instead), and it carries the B2, A and M round-1 fix blocks into their sections of `tasks.md` (`@@ -270`, `-312`, `-368` hunks): review output, not B1 edits, but it means this branch touches other lanes' sections.

## Requirements

Only the rows that changed since round 1; the rest stand as in `b1-round-1.md`.

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US1-4 one message per event | `AUDIENCE` `SELECT DISTINCT` | `test_push_types.py::_dispatch_one` (no token twice), exact sets | OK |
| US1-5 type off / defaults | `AUDIENCE` | `test_match_started_reaches_a_follower_who_turned_it_on` | OK |
| US1-6 `match_started` from the feed | `producers.py:142-168` | `test_a_normal_kickoff_announces_match_started_once` (through `_apply_match`) | OK |
| US1-7 `final_score` once, exclusions | `producers.py:214-230`, `status_before` | watchdog, later-poll, abandoned/postponed/cancelled, editor-over-limit tests | OK (B1-R2-1 edge) |
| US1-14 correction | `producers.py` | poller guard both ways, editor path | OK |
| US1-15 master switch | `AUDIENCE` | goal and reminder with `enabled: false` | OK |
| FR-021 off switch | `policy.py`, runbook | `test_policy.py`; runbook block read | OK (B1-R2-2, -5 on the companion blocks) |
| FR-023/024 If-Match | per-row `etag` | `test_each_listed_account_carries_the_version_its_writes_check`, `test_cancel_takes_the_version_from_the_log_row` | OK on the API; lane A's A-R1-1 pending |
| FR-025 accounts | `users.py:110` | `test_a_new_account_must_change_its_temporary_password_first` | OK (B1-R1-7 note) |
| FR-029 / SC-014 failure alert | `dispatcher.py:723-737` | both after-commit tests | OK (B1-R1-16 flap note) |
| SC-003 no double send | `ON CONFLICT DO NOTHING` | `test_a_retried_or_overlapping_poll_writes_a_goal_once` | OK |

## Task audit

Ticked 45 (39 from round 1 plus the 6 round-1 fix tasks), verified 45, not done 0, partly done 0 among the fix tasks. T041 and T042 are unticked and correctly owner or live steps. The round-1 partial marks on T006, T025, T026, T027 (`test_sender.py`), T039/T040 runbook commands and T037 stand as MEDIUM notes (B1-R1-21, -22, -24, -25); they are not re-raised.

## Owner must review

- `backend/openapi/admin.json`: the new `etag` on `AdminUserRow` and `NotificationRow`, and that it hashes the whole stored row (an account's `etag` moves when it signs in).
- `backend/app/notifications/dispatcher.py`: `AUDIENCE`, `AUDIENCE_ALL`, `AUDIENCE_DEVICE`, from the code, not from `push-notifications.md` (B1-R2-3).
- `backend/app/notifications/producers.py` `record_poll`: the `live_seen` states and the `status_before` rule for `final_score`.
- `backend/app/services/admin/users.py` `create()`: new accounts flagged for a password change.
- `docs/runbooks/push-notifications.md` "The off switch": walk it on a scratch `.env` without the key, as B1-R1-4 asked for the PR.
- Unchanged from round 1: `0009_notifications_and_accounts.py`, `auth/roles.py`, `api/admin/auth.py`.

## Outside this change

- Lane A's A16 and A15 pages still send the list `ETag` (`admin/src/features/users/UsersPage.tsx:59`, `admin/src/features/notifications/NotificationsPage.tsx:102`); tracked as A-R1-1 in lane A's section.
- The 167 other-lane files merged in from PRs #47, #48 and #49.
- `backend/tests/conftest.py`'s default `TEST_DATABASE_URL` still doesn't match `dev.yml` (noted in round 1; `local-dev.md` documents the workaround used here).
- `backend/tests/conftest.py:184-212`: the database is per session, but Redis isn't. Parallel lane runs share DB 0 and the `auth:`/`rl:` prefixes, so rate-limit and login tests fail when two lanes run together (seen this round). A per-session Redis DB number or key prefix would make "parallel runs are safe" (`backend/CLAUDE.md`) true for Redis too.

## Not reviewed

- The Dart client regeneration, oasdiff and CI on `0d945f2` (see Checks).
- The code of B1's round-1 change outside the `0d945f2` delta was not re-reviewed line by line; its round-1 findings were re-checked against the current files.
- T041 and T042 (owner steps).
