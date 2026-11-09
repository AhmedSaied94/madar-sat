# Implementation review: 006-d06-notifications-and-live-center, lane B1, round 1

- Date: 2026-11-09 · Reviewer: Claude Code (Opus 5.5, `claude-opus-5-5`), with Sonnet layer reviewers; every finding below re-checked on Opus
- Branch: `d06-b1` · Base: `origin/master` (merge base `b7fd7d9`) · Head: `a76f339`, plus 0 uncommitted files
- Change: 3 commits, 116 files (10 in another lane's folders: the regenerated admin and Dart clients, T019), +19 367 −227
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 6 · MEDIUM 21 · LOW 8

The lane is already merged into the spec branch (PR #46, 2026-11-07). The fix tasks below go to the lane's next run on the spec branch, before the spec branch reaches `master`.

## Checks

| Check | Command | Result |
| --- | --- | --- |
| ruff | `uv run ruff check .` (clean copy of `d06-b1`) | exit 0, clean |
| mypy | `uv run mypy --strict app` | exit 0, clean |
| pytest + coverage | `TEST_DATABASE_URL=…5434 TEST_REDIS_URL=…6380 uv run pytest --cov --cov-report=term-missing` (PostgreSQL 16, Redis 7 from `infra/compose/dev.yml`) | exit 1: everything passes except 4 `tests/adapters/test_homebox_acl.py` tests (`AuthenticationError`: the local Redis has no home-box ACL users; the file is B2's, unchanged here). Coverage 95.38 % |
| OpenAPI current | `uv run python -m app.cli export-openapi` then `diff -r` against the committed `openapi/` | exit 0, no diff |
| Generated clients current | lane A's `pnpm orval` and lane M's `dart run swagger_parser && dart run build_runner build -d` on the spec heads, then diff | exit 0, no diff (see the A and M round files) |
| oasdiff (`/v1` non-breaking) | not run locally (Docker image). CI `openapi` job on PR #46 | CI pass; `public.json` diff is additive only (`LiveState.event_count`, `NotificationPrefs.enabled`), read by hand |
| Alembic up/down on a fresh DB | `tests/db/test_0009_notifications_and_accounts.py` inside the pytest run | pass |
| Autogenerate diff | NOT RUN: the repo has no autogenerate check, and models omit indexes and CHECKs by convention | — |
| CI on PR #46 | `gh pr checks 46` | backend `test`, `openapi`, `clients` pass; **admin `check` failed** (`tsc`: `stopped` missing in `SourceRunPage.tsx` / `SourcesPage.tsx` after the client regenerated) and the PR merged red. Lane A fixed it in #48 |
| CI on PR #47 (B2, carries B1's live queries) | `gh run view 42367293885` | **backend `test` failed**: `test_live_semantics.py::test_query_uses_the_live_window_index` and `::test_the_poll_window_uses_the_live_window_index_too` (an incremental sort, not `matches_live_window_idx`, after `Match.sport == 'football'` joined the query). They passed locally here: the plan choice is not stable. See B1-R1-26 |

## Findings

### CRITICAL

None.

### HIGH

#### B1-R1-1: `match_started` is never produced on a normal kickoff
- Layer pipelines · Source US1 scenario 6, FR-003, T024, T033 · `backend/app/notifications/producers.py:125-152` · CONFIRMED
- Problem: "first evaluation" is detected as `was_empty` (no `home`/`away` in `push_memory`). Before kickoff a match has no stored score, so `_accepted()` is None (`producers.py:86-90`), `evaluate` stores no baseline (`goal_bar.py:98-99`), and memory stays `{}`. On the first live poll `was_empty` is true, nothing is written, and `live_seen` is set. The test seeds a baseline (`tests/notifications/test_producers.py:44`) that production never creates.
- Failure scenario: a fan turns «بداية المباراة» on, follows tonight's match; polls run from kickoff − 10 min with no score, then the feed says `live` 0–0 at 1′. No row is written, then or ever.
- Fix direction: record that the match was evaluated while not in play (e.g. `live_seen: false`) so only a match first seen already in play is a silent baseline; test the scheduled → live sequence through `_apply_match`.

#### B1-R1-2: A16's edit, deactivate, reactivate and reset, and A15's cancel, can never pass `If-Match`
- Layer api (contract) · Source FR-023, FR-024, FR-043, US3 scenarios 4, 8, 10, constitution VI · `backend/app/schemas/admin.py:881-895, 953-965`; `backend/app/services/admin/users.py:147, 192`; `backend/app/services/admin/notifications.py:335-346` · CONFIRMED
- Problem: the writes compare `If-Match` with the row's own content hash (`lock_and_check` → `versions.etag_of(row_state(row))`), but `AdminUserRow` and `NotificationRow` carry no version, and there is no `GET users/{id}` or `GET notifications/{id}`. The list `ETag`s are dataset + bucket tags, a different value. A client can learn a row's version only from the response to a write it can't make. B1's own tests compute the version from the ORM row (`tests/admin/test_users.py:32-34`), which hides it.
- Failure scenario: on the real API, every A16 role change, deactivation, reset and every A15 cancel answers `409 edit_conflict` (lane A sends the list `ETag`; see A-R1-1). Only account creation works.
- Fix direction: add a per-row `etag` to `AdminUserRow` and `NotificationRow` (as `ChannelRow` does), re-export, regenerate both clients, and add a test that takes the version from the list response. Tell lane A.

#### B1-R1-3: A new account is created unflagged, so its temporary password never has to be changed
- Layer api/security · Source FR-025, US3 scenario 7, R19 · `backend/app/services/admin/users.py:93-106` (`must_change_password=False`, docstring "unflagged"); `backend/tests/admin/test_users.py:90` pins it · CONFIRMED
- Problem: only `reset_password` sets the flag. `docs/runbooks/staff-accounts.md` (this lane's) says the new account "starts with `must_change_password = true`".
- Failure scenario: an admin creates an editor in A16 and hands over the generated password; the editor signs in, is never sent to `/change-password`, and the password the admin saw stays valid for good.
- Fix direction: set the flag on create, flip the test, and add one that a fresh account gets `403 password_change_required` on a role route.

#### B1-R1-4: The documented off switch does nothing on the first match night
- Layer ops · Source FR-021 ("`push-notifications.md` MUST say how to use it within a minute"), T040 · `docs/runbooks/push-notifications.md:123-130` · CONFIRMED
- Problem: `sed -i 's/^PUSH_TYPES_OFF=.*/…/' .env || echo … | tee -a .env`: `sed -i` exits 0 when no line matches, so the append never runs, and `deploy-and-rollback.md:145` / owner-actions say the key is not set first. The block also `cd /srv/madar` and calls `dc`, which no line in this file defines (every other runbook defines `dc()` from `/srv/madar/infra` with `IMAGE_TAG`, e.g. `on-call.md:26-31`).
- Failure scenario: a false goal reaches every follower; the owner pastes the block; `dc: command not found` (or, with `dc` defined, `printenv` prints an empty line) and goal pushes keep going.
- Fix direction: an append-or-replace that works when the key is absent, the same `cd /srv/madar/infra` + `IMAGE_TAG` + `dc()` preamble as `on-call.md`, a recreate that re-reads `.env`, and a check that fails when the printed value is empty.

#### B1-R1-5: T024 and T028 are ticked, but most of their named producer and alert cases have no test
- Layer tests · Source T024, T028, FR-028, SC-003, constitution test-first ("outbox dedupe") · `backend/tests/notifications/test_producers.py` (10 tests), `backend/tests/live/test_cycle.py:703-755`, `backend/tests/notifications/test_push_alerts.py` · CONFIRMED
- Problem, with no test anywhere: the poller's correction guard `_sent_this_generation` (`producers.py:97-116`) in either direction (only the editor path is tested); a locked score (only `status_source='manual'` is); `final_score` none for `abandoned`, `postponed`, `cancelled`, a watchdog finish or a later poll of that row, and an editor finish over a finish at the limit; retry / overlapping poll / restart writing a goal twice; "fans' values the same with producers on as off"; `kick_dispatch` after commit; the scheduled → live `match_started` (B1-R1-1 got through because of this). T028: no run with every send refused, no "sent after commit" assertion, and no alert assertion on the `MAX_ATTEMPTS` → `failed` path (which sends before commit, B1-R1-16).
- Failure scenario: flipping `_sent_this_generation` to always true sends «تصحيح النتيجة» for scores nobody was told; every test stays green.
- Fix direction: add each case through `record_poll` / `_apply_match` on PostgreSQL, each written to fail when its rule flips.

#### B1-R1-6: The audience tests cannot fail for the audience mistakes that would spam
- Layer tests · Source FR-017, SC-004, US1 scenarios 4, 5, 15, T027, constitution test-first ("audience") · `backend/tests/notifications/test_push_types.py:166-193` · CONFIRMED
- Problem: five rows are dispatched in one run and the test asserts each kind's owners are a subset of the union of every token sent; the only exclusion checked is a device that follows nothing. The master switch (`prefs ->> 'enabled'`) is tested only on `all` and `device` (`:199`, `:247`), never on the follow query `AUDIENCE`; a `match_started` opt-in is never tested.
- Failure scenario: add `OR f.competition_id = :competition_id` to `match_core`; every competition follower then gets every goal and final score, and the suite stays green. Delete the master-switch line from `AUDIENCE`; still green.
- Fix direction: one row per dispatch (or read per page), exact device sets per kind including the exclusions (competition follower not on `match_core`, channel follower not on match kinds, team follower not on `match_only`), master off on a follow kind including a reminder, and a positive `match_started` opt-in.

### MEDIUM

- **B1-R1-7** (security/db, CONFIRMED by reading) `last_admin` race: `services/admin/users.py:164-169` locks only the target row and counts active admins with a plain `SELECT count(*)`. Two admins deactivating or demoting each other at once both see 2 and both commit, leaving none (recovery by CLI). Serialize the check (lock every active admin row or an advisory lock) and add a two-session test.
- **B1-R1-8** (api, CONFIRMED) Reach undercounts a match audience: `services/admin/notifications.py:111-113` sets only `match_id` for `match`, `match_core`, `match_followers`, while the dispatcher adds both teams (and the competition for `match_followers`). `tests/admin/test_notifications.py:208` pins the low number.
- **B1-R1-9** (api, CONFIRMED) The dispatch kick is a synchronous `send_task` (`notifications/kick.py:41-44`) called after `commit()` in async handlers (`api/admin/matches.py:164-166`, `channels.py:158-160`, `notifications.py:25-30`). A broker outage blocks the loop and turns committed saves into 500s; a retried announcement gets a fresh dedupe key and goes out twice. Guard it and run it off the loop.
- **B1-R1-10** (api, CONFIRMED) `create_announcement` and `test_send` (`services/admin/notifications.py:301-390`) bump no dataset, so A15's log can answer 304 for up to 15 s after the admin's own send.
- **B1-R1-11** (db, CONFIRMED) No index serves A17's default order `created_at DESC, id DESC` or the `source` / period filters (`services/admin/audit.py:73-99`); `0009` adds none.
- **B1-R1-12** (api, CONFIRMED) `GET audit/{id}` (`api/admin/audit.py:72-85`) returns no `ETag` (constitution VI).
- **B1-R1-13** (api/tests, CONFIRMED) Eight of the new error codes appear only in `info.description`, not as response examples, and `tests/contract/test_admin_contract.py:149` unions the description into "documented", so it can't fail.
- **B1-R1-14** (security, PLAUSIBLE) `db/session.py:21` builds the engine without `hide_parameters=True`; a DB error while writing `password_hash` (create, reset, change-password) logs the statement's parameters through `_unhandled`'s `logger.exception`. SC-011.
- **B1-R1-15** (api, CONFIRMED) `repair-matches sport --apply` (`services/match_repair.py:295-330`) bumps no dataset, unlike `merge` and `fill-teams`.
- **B1-R1-16** (pipelines, CONFIRMED) The `push` problem closes on any finished row, including one with 0 devices (`dispatcher.py:667-676`), so it flaps "recovered" during an FCM outage; on the failed path the alert is sent before `commit()` (`:725-734`). SC-014.
- **B1-R1-17** (pipelines, PLAUSIBLE) A match the watchdog finishes between the cycle's window read and `_apply_match` still gets `final_score` (`producers.py:204` checks only `finished` + `feed`). Produce it only when this poll moved the status.
- **B1-R1-18** (pipelines, CONFIRMED) Editor-produced `final_score` and corrections have no age bound (`producers.py:235-291`); after the 30-day prune frees the key, or on a watchdog-finished match, fixing an old score sends «انتهت المباراة» now.
- **B1-R1-19** (pipelines, CONFIRMED structure) Only `Retryable` is caught in `dispatch_row` (`dispatcher.py:718-735`); an assert in `_view` (unknown kickoff) or `build_channels_updated`'s `ValueError` leaves a row `sending`, reclaimed every 10 minutes, never `failed`, never alerted.
- **B1-R1-20** (pipelines, CONFIRMED) Per-device queries while building messages (`dispatcher.py:607-617` → `_goal_events`, `_channel_view`): a 10 000-follower goal costs about 10 000 extra round trips. SC-002 risk.
- **B1-R1-21** (pipelines/tests, CONFIRMED) `sender.py:149-157` keeps `last_error` only for non-transient errors, so a row failing on repeated 503s says "FCM retryable", not `FCM 503`; `test_push_alerts.py:176` pins that. T027's `test_sender.py` bullet was not done.
- **B1-R1-22** (tests, CONFIRMED) T025/T026 gaps: no test that a second save inside the hold adds no row, that the history row copies `audit_log_id` (every fixture has None), that the hold's end bumps `CHANNEL_CHANGED`, that a retry writes one history row (`:224` inserts by hand), that a typo fixed inside the hold sends the fixed value, or that the `is_hidden` path counts; `:273` is a tautology.
- **B1-R1-23** (pipelines, CONFIRMED) A4's bulk remove (`services/admin/bulk.py:87` → `match_links.remove_all_visible`) deletes or hides links without `report_link_change_async` (FR-010).
- **B1-R1-24** (ops, CONFIRMED) The owner's pre-merge audience review (`push-notifications.md:150-158`, the T037 gate) describes the old single `AUDIENCE` with `#>> '{types,kickoff_reminder,on}'`, not the three current queries; the dispatch paragraph still says "claims up to 10 rows".
- **B1-R1-25** (ops, CONFIRMED) Runbook commands that don't match the code: `imports-and-sources.md` relabelling uses `/srv/madar/compose.yml` (doesn't exist) and says it prints only untouched rows (it prints all); `load-testing.md:193` cites a seeding script under `backend/loadtest/` that doesn't exist (T041 can't run as written); `database-migrations.md:98` says nothing is lost while the downgrade drops `channel_frequency_changes`.
- **B1-R1-26** (db/tests, PLAUSIBLE) The live-window index test failed on PR #47's CI and passed locally: with `Match.sport == 'football'` the planner can pick another plan for `/v1/live` and the poller. Make the index match the query (or the test robust) on purpose.
- **B1-R1-27** (ops, CONFIRMED) `backend/CLAUDE.md` unchanged: no `goal_bar`, `policy`, `producers`, `channel_changes`, `kick`, `PUSH_TYPES_OFF`, `repair-matches sport`, revision `0009` (it still calls `0008` unmerged), `require_signed_in`, the writer's `then`, or the new routers.

### LOW

- **B1-R1-28** A crafted cursor gives 500 (`services/admin/notifications.py:186-191`, `audit.py:60-65`).
- **B1-R1-29** The re-queue runs inside the dispatch lock (`notifications/tasks.py:77-80`); the follow-up can find `lock_held` and wait for the beat.
- **B1-R1-30** A second reversal after a correction is not corrected (the generation guard ignores sent corrections).
- **B1-R1-31** A channel removed and re-added within one hold is announced as added (`channel_changes.py:195-211`).
- **B1-R1-32** An outbox row whose audience has no `kind` falls back to `all` (`dispatcher.py:258, 286`); fail closed instead. Every producer sets a kind today.
- **B1-R1-33** A producer exception is only logged (`live/cycle.py:547-549`, `push_producers_failed`): no problem, counter or runbook line, so a persistent bug silences goal pushes unseen.
- **B1-R1-34** `repair-matches sport` with an unknown sport raises a traceback instead of `RepairRefused`.
- **B1-R1-35** The match-detail `ETag` (`api/public/matches.py:64`) ignores the `live` dataset that event writes bump (`live/apply.py:373`), so lane M's `event_count` re-read can get a 304 inside the 15 s bucket and wait for the 60 s timer (SC-006 still met at the timer).

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US1-1 goal on two sources | `goal_bar.py`, `producers.py` | `test_goal_bar.py`, replay | OK |
| US1-2 one source 3 min; contradiction holds | `goal_bar.py` | `test_goal_bar.py`, replay (Mouloudia +240 s) | OK |
| US1-3 scorer/minute only when known | `messages.py` | `test_messages.py` | OK |
| US1-4 one message per event | `AUDIENCE` `SELECT DISTINCT` | `test_push_types.py` (weak, B1-R1-6) | Partly proven |
| US1-5 type off / defaults | `AUDIENCE` | weak tests (B1-R1-6) | Code OK, proof weak |
| US1-6 `match_started` from the feed | `producers.py` | test seeds a baseline | **Broken (B1-R1-1)** |
| US1-7 `final_score` once, exclusions | `producers.py` | partial (B1-R1-5) | Code OK on normal path (B1-R1-17, -18) |
| US1-8 `channels_updated` held, one push | `channel_changes.py`, dispatcher netting | `test_channel_changes.py` | OK, gaps B1-R1-22, -23 |
| US1-9/10 frequency hold, set-back | `producers.frequency_hold`, dispatcher | `test_frequency_changes.py` | OK, gaps B1-R1-22 |
| US1-11 late rows cancelled | `policy.py` | `test_policy.py` | OK |
| US1-12 no backfill at switch-on | `goal_bar` baseline | `test_producers.py` | OK |
| US1-13 copy per type | `messages.py` | `test_messages.py` (code point exact) | OK |
| US1-14 correction | `producers.py` | editor path only (B1-R1-5) | Code OK, poller path unproven |
| US1-15 master switch | `AUDIENCE`, `AUDIENCE_ALL` | `all`/`device` only (B1-R1-6) | Code OK, proof weak |
| FR-021 off switch | `policy.parse_types_off`, dispatcher | `test_policy.py` | Code OK, **runbook broken (B1-R1-4)** |
| FR-022 / SC-010 football by default | `api/public/matches.py`, `services/live.py` | `test_other_sports.py` | OK |
| FR-023/024 admin API, roles, If-Match | `api/admin/*` | `test_notifications.py`, `test_users.py`, route walk | Roles OK; **If-Match unreachable (B1-R1-2)** |
| FR-025 accounts | `services/admin/users.py` | `test_users.py`, `test_change_password.py` | **Create unflagged (B1-R1-3)**, race (B1-R1-7) |
| FR-026 audit read-only, links | `services/admin/audit.py` | `test_audit.py` | OK (B1-R1-11, -12) |
| FR-027 migration + contract | `0009`, `openapi/` | `test_0009…`, export diff | OK |
| FR-029 / SC-014 failure alert | `dispatcher.py`, `problems.py` | `test_push_alerts.py` | Partly (B1-R1-16) |
| FR-033 repair | `match_repair.py`, `cli.py` | `test_match_repair.py` | OK (B1-R1-15) |
| SC-001 replay 58 / 0 / no false 2–0 | `goal_bar.py` | `test_goal_bar_replay.py` | OK |
| SC-002 / SC-008 timing | dispatcher ordering, page budget | ordering tests; load test not run (T041) | Unproven (B1-R1-20) |
| SC-003 no double send | `ON CONFLICT DO NOTHING` | thin (B1-R1-5) | Code OK, proof thin |
| SC-011 no password in logs | `users.py` allowlist | `caplog` tests on success paths | OK (B1-R1-14 PLAUSIBLE) |

## Task audit

Ticked 39, verified 30, not done 0, partly done 9. T041 and T042 are unticked and correctly owner or live steps.

| Task | Mismatch |
| --- | --- |
| T006 | Editor 403 hits 3 of 5 write routes; `cancel` isn't in `ADMIN_ONLY_PREFIXES`; 65/180 never accepted |
| T016 | Create doesn't flag the account (B1-R1-3) |
| T024 | Most named cases untested (B1-R1-5) |
| T025, T026 | Gaps in B1-R1-22 |
| T027 | Audience test can't fail (B1-R1-6); `test_sender.py` bullet not done (B1-R1-21) |
| T028 | Alert after commit and the failed path unproven (B1-R1-5, -16) |
| T033 | `match_started` never fires (B1-R1-1) |
| T039, T040 | Runbook commands wrong (B1-R1-4, -24, -25) |
| T037 | The contract PR and the push PR shipped as one PR (#46) into the spec branch; the "contract first, push last" deploy order in the quickstart, `deploy-and-rollback.md` and owner-actions can no longer happen as written: the spec branch → `master` merge is now the moment every type turns on |

## Owner must review

- `backend/alembic/versions/0009_notifications_and_accounts.py`: expand-only, the CHECK drop and re-add, and what the downgrade rewrites.
- `backend/openapi/admin.json`, `public.json`: the new admin paths, and that `/v1` changes are additive; plus the per-row `etag` B1-R1-2 adds.
- `backend/app/notifications/dispatcher.py`: `AUDIENCE`, `AUDIENCE_ALL`, `AUDIENCE_DEVICE` (each type's audience, the master switch, the defaults). Read them from the code, not from `push-notifications.md` (B1-R1-24).
- `backend/app/auth/roles.py`, `backend/app/api/admin/auth.py` (`require_signed_in`, `change-password`) and `backend/app/services/admin/users.py` (temporary password, flags, `last_admin`).
- The merge of the spec branch to `master` is the moment every automatic type reaches every follower (T037); keep the off switch to hand once B1-R1-4 is fixed.

## Outside this change

- `backend/tests/conftest.py`'s default `TEST_DATABASE_URL` (`postgres:postgres`) doesn't match `infra/compose/dev.yml`'s `example.env` credentials (`madar`/`changeme`); `backend/CLAUDE.md` should say to set `TEST_DATABASE_URL` and `TEST_REDIS_URL`.
- `sources.py:44` already called `send_task` synchronously in async handlers (B1-R1-9's pattern predates this change).
- CI's coverage floor is 70 % while the constitution's gate is 80 %; this lane is at 95 %.
- FR-071 / T002 (planning session): SD §6.7/§6.8, PB §11 and the delivery plan have no D6 corrections on `master` or the spec branch; `delivery-plan.md` still gives D6 `0004` and a later day `0009`.

## Not reviewed

- `oasdiff` was not run locally (CI ran it on #46).
- The 4 home-box ACL tests could not run against the local Redis.
- T041 (50 000-device load test) and T042 (live points) are owner steps and were not attempted.
