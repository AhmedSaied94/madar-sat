---

description: "D5 · Live and discovery: tasks per lane"
---

# Tasks: D5 · Live and discovery

**Input**: Design documents from `specs/005-d05-live-and-discovery/`: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md).

**Tests**: Mandatory (constitution, Quality Gates). In every lane, test tasks come first and must be seen failing before the code they cover.

**Organization**: one `## Lane` section per lane, each an independently testable user story, plus `## Before lanes start` and a final `## Done check`.

- A lane implements and ticks **only its own section** and changes only its own folders (FR-051). Generated files are never edited by hand.
- Review fix tasks are appended at the end of a lane's section by `/speckit-review-implementation`.
- **Carry-over** (delivery-plan §5.3): the failed D4 load test's fix (FR-060–FR-063), in B1 and B2. SR-2, D4's T071 and T072, and the public announcement stay with the owner in `docs/owner-actions.md`.

| Section | Spec story | Story label | Branch | Folders |
| --- | --- | --- | --- | --- |
| Lane B1 | User Story 1 (P1) | `[US1]` | `d05-b1` | `backend/` except `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/`; `docs/load-tests/`; `specs/005-d05-live-and-discovery/capture-report.md` |
| Lane B2 | User Story 3 (P3) | `[US3]` | `d05-b2` | `infra/`, `.github/`, `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/` |
| Lane A | User Story 4 (P4) | `[US4]` | `d05-a` | `admin/` |
| Lane M | User Story 2 (P2) | `[US2]` | `d05-m` | `app/` |

Every lane may also edit `docs/runbooks/` for its own parts and its own section of `docs/owner-actions.md` (FR-054).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task).
- **[USn]**: the spec story the task belongs to.
- Paths are repo-relative.

## Dependencies & execution order

### Between lanes

```text
T001 (docs on master)
 ├─▶ B1 T002–T017 (0007 + contract PR, by 13:00) ─▶ A T063 on, M T078 on, B2 T046 on
 ├─▶ B2 T045 (shared signatures merged to master) ─▶ B1 rebases ─▶ T031, T033; and B2's own resolver work
 ├─▶ B1 T018–T019 + B2 T043–T044 merged and deployed ─▶ B1 T020 (capture on VPS-2)
 ├─▶ B2 T047 (resize steps) ─▶ owner T048 (resize) ─▶ B1 T040 (load re-run) ─fail▶ B2 T062 (Caddy cache) ─▶ T040 again
 ├─▶ B1 T023 and T029 (parsers on saved pages): start now, no capture needed
 └─▶ B1 T020 (first suitable live match) ─▶ T021–T022 (parsers completed) ─▶ T038–T039
B2 T054 (queue writer) ─▶ real rows in A's queue; A runs on the mock until then
Real match on the deployed hosts ─▶ Done check
```

### Inside each lane

Tests first, seen failing, then code. The tasks are in order unless marked [P].

### Parallel examples

- **B1:** T003, T004, T005 and T006 are separate test files. T023–T027 can be written together, with no capture needed.
- **B2:** T049 and T050 (parser and resolver tests).
- **A:** the queue (T065–T068) and A9 (T072–T074) touch different folders.
- **M:** S6, S7 and S8 (T083–T085) are separate feature folders once T082 is done.

## Implementation strategy

1. **Contract by 13:00** unblocks A and M.
2. **Parsers now, completed by the capture.** Parsers start on saved finished and scheduled pages, and any status they haven't seen fails validation. The cross-check rules, links and apply steps are tested with `SourceReading` values, then re-run on captured pages. The capture runs on the first suitable match, meaning a live match both list pages carry, with `capture-live` and the buckets already deployed.
3. **MVP of the day:** Lane B1 alone gives real scores on existing screens. S6–S8 and the queue can land in any order after the contract.
4. **If the capture fails:** B1 stops and tells the owner (spec Edge Cases). A, M and B2's importer continue.
5. **Quarter-day rule (§5.3):** if the day runs late, cut A9's drag order first, then S8's rights shortcut. The cross-check, watchdog, queue and done-check items don't move.

---

## Before lanes start

- [ ] T001 Planning session, with the owner's merge: commit `docs/delivery-plan.md`, `docs/owner-actions.md`, `docs/product-business.md`, `docs/system-design.md`, `.specify/memory/constitution.md` (1.3.0, with its Sync Impact Report in the PR body) and `specs/005-d05-live-and-discovery/` to `master` through a PR, so lane branches cut from `origin/master` have them.

---

## Lane B1

**Goal:** the score and minute a fan sees come from a real feed, never from a guess; the contract ships by 13:00; the load test passes.

**Independent test:** replay the capture through the poller and check each row of SD §6.7's table, then watch a real match on `/v1/live` ([quickstart B1](quickstart.md#b1-capture)).

### Contract: tests first (B1)

- [ ] T002 [US1] In `backend/tests/db/test_0007_live_and_aliases.py`, test upgrade and downgrade on an empty database and on the snapshot fixture: every table and column in [data-model.md](data-model.md) exists; `match_events` is unique on `(match_id, source, external_id)` and rejects a `type` outside `goal, own_goal, penalty, missed_penalty, red_card`; `team_aliases` is keyed `(source, alias_norm, competition_norm)`; `unresolved_names` is unique on `(source, kind, name_norm, competition_norm)`; `state` allows only `open, mapped, created, ignored`, and `target_id` is required when `mapped` or `created`; `sources` holds `filgoal`, `yallakora`, `live_poller`; `dataset_versions` allows `unresolved_names`.
- [ ] T003 [P] [US1] In `backend/tests/api/test_match_detail_live.py`, test `MatchDetail.events` and `.lineups` per [public-api](contracts/public-api.md#matchdetail): filled from stored rows; `[]` and `null` when none; `[]` and `null` when `estimated: true`; `local_broadcaster_eg` returned when stored.
- [ ] T004 [P] [US1] In `backend/tests/api/test_discovery_details.py`, test: `ChannelDetail.upcoming_matches` limited to now − 150 min … now + 7 days and 20 rows; `CompetitionDetail` has `upcoming` and `recent` (≤ 30 each) and `rights_holders[].satellites` and `.competition_count`; the competition ETag changes when a match changes. In `backend/tests/api/test_live_window.py`, test that `/v1/live` keeps a `feed` match with no final state at kickoff + 170 min and drops it after + 210 min, and that a `clock` match still leaves at + 150 min.
- [ ] T005 [P] [US1] In `backend/tests/admin/test_unresolved_names.py`, test per [admin-api](contracts/admin-api.md#unresolved-names-a13): the filters and cursor; `meta.open_count`; suggestions (≤ 3, exact first, threshold `similarity() ≥ 0.3`, `[]` for a Latin name with no same-script candidate); `map` writes the alias and sets `mapped`, or `created` with `created: true`; `scope_to_competition` required when more than one team shares the name; `409 alias_conflict`; `409 edit_conflict` on a non-`open` row; `428` without `If-Match`; `ignore`; audit row and `unresolved_names` bump; the list's `ETag` changing on a bump and answering `304`; editor role required.
- [ ] T006 [P] [US1] In `backend/tests/admin/test_rights_holders.py`, test list, detail, create, `PATCH` replacing `competitions` and `carriages` atomically, reorder, and `DELETE` (admin role only); `422` unless each carriage with frequencies has exactly one `is_primary`; `Name120` screening; `If-Match`, audit, and `rights_holders` and `competitions` bumps; `ETag` and `304` on both GET routes.
- [ ] T007 [P] [US1] In `backend/tests/admin/test_sources_live.py`, test: `GET /sources` has `live_poller` with the `live` block and no `filgoal`; `POST /sources/live_poller/run` answers `409 source_not_runnable`; `GET /import-runs/{id}/raw` returns `pending`, then `ready` from a seeded `rawview:` key, and `gone` when `raw_path` is null; each state has its own `ETag`, and a `pending` tag never matches a `ready` one; the path never comes from the request.
- [ ] T008 [P] [US1] In `backend/tests/admin/test_match_versions.py`, test that changing `minute`, `period` or `status_updated_at` leaves the match ETag unchanged, while changing a score or `status` changes it ([R14](research.md#r14-editor-conflicts-during-a-live-match)).

### Contract: implementation (B1)

- [ ] T009 [US1] Write `backend/alembic/versions/0007_live_and_aliases.py` (revises `0006`), expand-only, per [data-model.md](data-model.md): the new tables, `matches.local_broadcaster_eg`, `rights_holder_carriages.package`, the updated `ck_matches_locked_fields` and `ck_dataset_versions_name`, the `sources` rows, and the index on `match_live_state.last_reading_at`. T002 passes.
- [ ] T010 [US1] Add the models to `backend/app/db/models.py`, and `local_broadcaster_eg` to `MATCH_LOCKABLE` in `backend/app/domain/lockable.py`.
- [ ] T011 [US1] Add `MatchEvent`, `MatchLineups`, `RightsHolderRef` and a typed `FrequencyChange` to `backend/app/schemas/public.py`; fill events, lineups and the broadcaster in `backend/app/services/match_detail.py`, with goal-type events absent while a candidate is pending (data-model `match_events`). T003 passes.
- [ ] T012 [US1] Update `backend/app/services/channels.py` (the 7-day limit) and `backend/app/services/catalog.py` plus `backend/app/api/public/competitions.py` (`upcoming`, `recent`, the rights fields, ETag datasets with `bucket_s=60`), and `live_window_query` in `backend/app/services/live.py` to keep `feed` matches with no final state up to kickoff + 210 min. T004 passes.
- [ ] T013 [US1] Add `backend/app/services/admin/unresolved_names.py` and `backend/app/api/admin/unresolved_names.py` through `writer.py`, with the suggestion query on `pg_trgm`; register the router in `backend/app/admin.py`. T005 passes.
- [ ] T014 [US1] Add `backend/app/services/admin/rights_holders.py` and `backend/app/api/admin/rights_holders.py`, using `ordering.py`; register the router. T006 passes.
- [ ] T015 [US1] In `backend/app/services/admin/sources.py` and `backend/app/api/admin/sources.py`, add the `live` block, hide `kind='live_reader'` sources, refuse `run` on `live_poller`, and add the raw route. It sends `adapters.read_raw_page` by task name to `maintenance`, so B1 needn't import B2's code. Add `pages` and `worker` to `ImportRunDetail`. T007 passes.
- [ ] T016 [US1] In `backend/app/services/admin/versions.py`, stop hashing `matches.minute`, `period` and `status_updated_at`. T008 passes.
- [ ] T017 [US1] Run `uv run python -m app.cli export-openapi`, regenerate both clients unedited, run the `oasdiff` check, and open the contract PR by 13:00. If it flags `lineups` widening from `null`, write that in the PR for the owner to accept ([R15](research.md#r15-old-app-builds-are-safe)). **Owner reviews the migration and contract before merge.** Tell A, M and B2 when merged.

### Capture (B1)

The next section's tests and parsers don't wait for T020. T021 corrects them once the capture exists.

- [ ] T018 [US1] In `backend/tests/live/test_robots.py`, test one allowed and one denied path per rule in [R4](research.md#r4-the-robotstxt-rules-that-affect-us), including `/uefa/...` and `/asian-champions-league/...` allowed and `/champions-league/...` denied on YallaKora. Then write `backend/app/live/robots.py` with the deny list and `is_allowed(host, path)`, and commit both `robots.txt` copies under `backend/app/live/robots/`.
- [ ] T019 [US1] Write `backend/app/live/capture.py` and a `capture-live` command in `backend/app/cli.py` ([R1](research.md#r1-parsers-start-now-and-a-small-recorder-completes-them)): `--filgoal`, `--yallakora`, `--minutes`; saves both list pages every 60 s and the chosen match pages under `/srv/raw/capture/<date>/` with a timestamp, through `HttpFetcher`, `robots.is_allowed` and the shared buckets; never runs if `SCRAPE_USER_AGENT` is unset. A unit test covers the deny check and the output layout.
- [ ] T020 [US1] After T018, T019, T043 and T044 are merged and deployed through `backend.yml`, pick the day's first suitable live match: one both list pages carry, as early as possible so a later kickoff is left for T038. Run the capture on VPS-2 ([quickstart](quickstart.md#b1-capture)). Then commit a trimmed set covering pre-match, first half, goal, half-time, second half and full time under `backend/tests/live/fixtures/`, with no personal data. If none is available today, say so in the PR. Parser work continues on the saved pages, and the done check moves to the next match day.
- [ ] T021 [US1] Write `specs/005-d05-live-and-discovery/capture-report.md`: fields found per page; every status string and its §6.2.3 state; each source's measured update delay; `LIVE_CONFIRM_WAIT_S`; both page caps; `LIVE_DOWN_AFTER_FAILURES`; gzip page sizes; whether YallaKora has usable stats on allowed pages; and any change SD §6.7 needs. If a source is unusable, **stop and tell the owner**. Otherwise add the captured pages to T023's tests, see the differences fail, then correct the parsers and complete their status maps in T029's files.
- [ ] T022 [US1] Feed the team names in the capture through the resolver and list those not matched, and hand the list to the owner to clear in A13 or add through B2's queue before the done-check match. If the capture justifies stats, add expand-only `backend/alembic/versions/0008_match_stats.py` per [R16](research.md#r16-match-stats-wait-for-the-capture) in its own PR; otherwise record that in the report and don't add it (FR-018).

### Poller: tests first (B1)

- [ ] T023 [P] [US1] In `backend/tests/live/test_filgoal_parse.py` and `test_yallakora_parse.py`, starting now: save real finished and scheduled pages from both sites under `backend/tests/live/fixtures/`, with no personal data, and test on them, with no capture needed: list and match readings, the status map, Western-digit minutes, an unknown status and a missing field raising `LayoutChanged`, a blocked page or empty body failing, and no commentary text in any reading.
- [ ] T024 [P] [US1] In `backend/tests/live/test_crosscheck.py`, write a table test of `decide` for every row of SD §6.7's table in both source orders: both agree; one updated, then the other; wait ends; one down with two polls; one invalid; one not covering the match; both down; recovery; a score going down; penalty scores; a backward status needing two polls; status and minute taken from FilGoal, or YallaKora when FilGoal is unusable.
- [ ] T025 [P] [US1] In `backend/tests/live/test_links.py`, test: an existing external ID wins; both teams and kickoff within 45 min link and write the external ID; one unresolved team, reversed order, more than one match or a kickoff gap don't link; a scoped alias beats an unscoped one; unresolved names reach `record_unresolved`. In `test_pick.py`, test: existing slots first, then `competitions.priority`, then the earlier kickoff, up to the cap, a match keeps its slot, and a blocked path gets none.
- [ ] T026 [P] [US1] In `backend/tests/live/test_apply.py` on PostgreSQL, test: `clock → feed`; a fallback clears score, minute and period and meets `ck_matches_clock_no_score`, with `match_live_state` keeping the score; recovery restores it through the rules; `manual` is untouched; `locked_fields` are skipped per field; goal events held while pending and removed events deleted; events idempotent; `live` bumped last and `matches` not bumped; the postponed, cancelled and abandoned states.
- [ ] T027 [P] [US1] In `backend/tests/live/test_cycle.py`, with a fake fetcher replaying saved pages, test: one alert per problem across restarts and retries, then one on recovery; a quiet window sends 0 requests (SC-004); pause acts as both down with no alert; a changed format gives 0 wrong scores (SC-003); overlapping cycles exit; a 429, 403 or 5xx sets `live:backoff:<host>` with exponential backoff and jitter capped at 10 min, and the cycle skips that host and counts a failure; a list page with no matches while one is in the window opens `format:<source>` once (zero-items alarm); repeated failures never set `breaker_opened_at`, and the source recovers when valid again; a `feed` match stays selected up to kickoff + 210 min; a match with no opened page takes status and score from list pages under the same cross-check; an alert is sent only after commit; an `import_runs` row per cycle; a raw page saved only on change or failure. In `test_watchdog.py`: a `feed` row with no reading for `LIVE_STALE_AFTER_S`, or past `LIVE_HARD_LIMIT_MIN` with no final state, moves to the clock and opens `stale:<match_id>`; `manual` rows are left alone.

### Poller: implementation (B1)

- [ ] T028 [US1] Write `backend/app/live/config.py` with the settings in [live-pipeline](contracts/live-pipeline.md#settings), and `backend/app/live/types.py` with `SourceReading`, `Score`, `Event`, `Lineups`, `SideInput`, `Decision` (importing `app.workers` must still load neither `app.settings` nor `app.db`).
- [ ] T029 [US1] Write `backend/app/live/sources/filgoal.py` and `sources/yallakora.py`: pure `parse_list` and `parse_match`, with status maps from the saved pages, where any status not yet seen fails validation. This doesn't wait for the capture, and T021 completes the maps. T023 passes.
- [ ] T030 [US1] Write `backend/app/live/crosscheck.py` as one pure `decide` function. T024 passes.
- [ ] T031 [US1] Write `backend/app/live/links.py` and `pick.py`, using B2's `resolve_team` and `record_unresolved`, after rebasing on T045's merge to `master`. T025 passes.
- [ ] T032 [US1] Write `backend/app/live/apply.py`, the event and lineup diffs, and `backend/app/live/problems.py`. T026 passes.
- [ ] T033 [US1] Write `backend/app/live/tasks.py` (`live.scheduler`, `live.poll`, one cycle per [the contract](contracts/live-pipeline.md#one-cycle)) and `backend/app/live/schedule.py`, and add `app.live.schedule` to `SCHEDULE_MODULES` in `backend/app/workers/__init__.py`. Use `bind=True`, `autoretry_for`, `retry_backoff`, `retry_jitter`, a bounded `max_retries` and the `SET NX EX` locks. Add the backoff and the zero-items alarm, and call B2's `health.record_live_cycle` for `live_poller`; never call `record_run`, which can open the breaker. No outbox row is written (FR-014). T027's cycle tests pass.
- [ ] T034 [US1] Add `live.watchdog`, `live.prune_runs` (runs older than 30 days, for `live_poller` only) and `live.check_robots` to the same files. T027's watchdog tests pass.
- [ ] T035 [US1] Run `uv run ruff check . && uv run mypy --strict app && uv run pytest`, and raise the coverage config to include `app/live` at the MVP bar.

### Ops and validation (B1)

- [ ] T036 [US1] Write `docs/runbooks/live-poller.md`: what runs and where, the settings, how to pause, reading `live_problems`, what to do for each alert, updating a parser from a saved page, and the disk check. Add it to `docs/runbooks/README.md`'s table and each alert to `docs/runbooks/on-call.md`.
- [ ] T037 [US1] On the deployed hosts, walk the live checks: `/v1/live` during a match, a stopped `worker-live` tripping the watchdog within 7 min, and an unset Telegram token logging rather than failing.
- [ ] T038 [US1] Watch one real match, later than T020's, from kickoff to full time against the broadcast on the deployed parsers (SC-001). If no later kickoff fits today, say so in `docs/owner-actions.md` and move this and DC1 to the next match day; no other lane is held. Record each goal's first source appearance, confirmation and arrival in the app, and check ≤ 45 s from confirmation (SC-005). Add the results to `capture-report.md`.
- [ ] T039 [US1] If the capture changed SD §6.7's rules, update `docs/system-design.md` in the same PR.
- [ ] T040 [US1] After owner T048, re-run the load test by `docs/runbooks/load-testing.md` from VPS-2 at `LIVE_RPS=170`, `MATCHES_RPS=50`, `DURATION=10m`. Add the result under "Re-runs" in `docs/load-tests/2026-11-03-mvp.md`, confirm the allowlist reads `effective: []` afterwards and record whether it passed (FR-061, SC-010). If it failed or the limit wasn't confirmed, tell B2 to start T062, then run it again.
- [ ] T041 [US1] Add Lane B1's items to `docs/owner-actions.md` (D5 section and "Open now"): the migration and contract review, the load-test window, the done-check match and, if T017 flagged it, accepting the `lineups` finding.

---

## Lane B2

**Goal:** names the importers can't match wait in a queue instead of creating duplicates; YallaKora imports; the live worker runs.

**Independent test:** run the adapter on saved pages, then on the live host: its `import_runs` row has counts, broadcasters appear, and an invented team reaches `unresolved_names` and creates no team ([quickstart B2](quickstart.md#b2-yallakora-and-the-queue)).

### Shared parts and infrastructure (B2, first)

- [ ] T042 [US3] In `backend/tests/adapters/test_heartbeat.py`, add a test that `live` is a heartbeat queue with a `heartbeat-live` beat entry. Then add `live` to `HEARTBEAT_QUEUES` in `backend/app/adapters/tasks.py`, `kuma_push_url_live` to `backend/app/adapters/config.py`, the beat entry to `backend/app/adapters/schedule.py`, and `KUMA_PUSH_URL_LIVE` to `infra/compose/example.env`.
- [ ] T043 [US3] Start `worker-live` on VPS-2: give it `RAW_ROOT: ${RAW_ROOT:-/srv/raw}` and the `/srv/raw:/srv/raw` volume in `infra/compose/vps2.yml`, as `worker-imports` has, add it to the service list in `infra/scripts/deploy.sh` and any `infra.yml` expectation, and update `docs/runbooks/workers.md` (it says `worker-live` isn't started) and `docs/runbooks/uptime-kuma.md` (the `live` push monitor). Deploy so the capture can run.
- [ ] T044 [P] [US3] In `backend/tests/adapters/test_ratelimit.py`, test that `www.filgoal.com` and `www.yallakora.com` have `Bucket(capacity=2, refill_seconds=4.0)`, and that the poller and importer share the key. Then add them to `DEFAULT_LIMITS` in `backend/app/adapters/ratelimit.py`.
- [ ] T045 [US3] By the morning, merge the signatures in [live-pipeline](contracts/live-pipeline.md#shared-code-b2-owns) to `master` in a small PR, as stubs that need no new table, and tell B1 to rebase: `record_unresolved(session, *, source, kind, name, competition, context)` in `backend/app/adapters/unresolved.py` (logs only for now), `resolve_channel` in `backend/app/adapters/resolve.py` (always unresolved for now), and, complete with a test in `backend/tests/adapters/test_health.py`, `record_live_cycle(session, *, status, items_found, finished_at)` in `backend/app/adapters/health.py`, which never sets `breaker_opened_at`. T054 and T053 fill them in.
- [ ] T046 [US3] Rebase `d05-b2` on B1's merged contract PR before writing to the new tables from `backend/app/adapters/`.

### Load-test carry-over (B2)

- [ ] T047 [US3] Add resize steps to `docs/runbooks/provision-host.md`: checking the Ampere A1 limits page, resizing an instance to 2–3 OCPU within the free limit, what restarts, and how to check afterwards. Review `gunicorn -w` for `api-public` in `infra/compose/vps1.yml` against the new core count, and update `docs/runbooks/load-testing.md`'s step 3 and SD §2 and §7.1 once the owner confirms the limit.
- [ ] T048 [US3] **Owner:** check the OCI limits page. If 4 OCPU is confirmed free, resize VPS-1 to 2–3 OCPU by T047's steps and tell B1 (T040). If not, tell B2 to start T062. Record it in `docs/owner-actions.md`.

### Importer and resolver: tests first (B2)

- [ ] T049 [P] [US3] Save real YallaKora list pages under `backend/tests/fixtures/yallakora/` from VPS-2, with no personal data. In `backend/tests/adapters/test_yallakora.py`, test: the parser is pure; Cairo wall-clock times become UTC; `liveScoreMatchId` becomes `external_id`; the `channel` value becomes the Egyptian broadcaster; competition and stage text are cleaned; a page with no match list raises `LayoutChanged`; a no-matches day returns `[]`; it writes no status or score.
- [ ] T050 [P] [US3] In `backend/tests/adapters/test_resolve.py`, test the order: external ID, then scoped alias, then unscoped alias (`reason="alias"`), then today's name rules; `resolve_channel`; and `resolve_competition` with its alias table. Existing tests still pass.
- [ ] T051 [P] [US3] In `backend/tests/adapters/test_unresolved.py`, test `record_unresolved`: one row per `(source, kind, name_norm, competition_norm)`; a repeat raises `seen_count` and refreshes `context` and `last_seen_at`; an `ignored`, `mapped` or `created` row doesn't reopen; `name` capped at 200. In `test_upsert.py`, test a run with an unknown team creates no team, queues the name and keeps the text name, and that `local_broadcaster_eg` is written from a fixture but skipped when it is in `locked_fields`.
- [ ] T052 [P] [US3] In `backend/tests/adapters/test_raw_view.py`, test `adapters.read_raw_page`: reads only the run's `raw_path`, writes `rawview:<run>:<page>` with text capped at 512 KB and a 5-min TTL, marks `truncated`, and handles a pruned path.

### Importer and resolver: implementation (B2)

- [ ] T053 [US3] Add the alias step and `resolve_channel` to `backend/app/adapters/resolve.py`. T050 passes.
- [ ] T054 [US3] Implement `backend/app/adapters/unresolved.py`, and call it from `backend/app/adapters/upsert.py` wherever `outcome.unresolved` is filled, for ysscores, the bridge and YallaKora. In `backend/app/adapters/livesoccertv_links.py`, also record a `channel` row while keeping its placeholder ([R11](research.md#r11-livesoccertvs-placeholders-stay)), and use `channel_aliases` first. T051 passes.
- [ ] T055 [US3] Write `backend/app/adapters/yallakora.py` implementing `SourceAdapter`, `allowed_hosts = {"www.yallakora.com"}`, with `robots`-safe list URLs only. Register it in `adapter_for` and `IngestionRouter` in `backend/app/adapters/tasks.py`, on the `scrape` queue. T049 passes.
- [ ] T056 [US3] Write `local_broadcaster_eg` in `backend/app/adapters/upsert.py`, skipped when locked (`MATCH_LOCKABLE`). T051's broadcaster test passes.
- [ ] T057 [US3] Add `yallakora-daily` and `yallakora-today` (every 6 h, today only) to `backend/app/adapters/schedule.py`, with a test that both go through `adapters.schedule_fetch`.
- [ ] T058 [US3] Add `adapters.read_raw_page` on `maintenance` to `backend/app/adapters/tasks.py`. T052 passes.

### Ops and validation (B2)

- [ ] T059 [US3] Update `docs/runbooks/imports-and-sources.md` (the schedule, `yallakora`, the queue) and `docs/runbooks/source-alerts.md`; add a `yallakora` row to the on-call page.
- [ ] T060 [US3] Deploy and run `yallakora` on the live host ([quickstart](quickstart.md#b2-yallakora-and-the-queue)). Put the evidence in the PR: the `import_runs` row, broadcasters on matches, queue rows, 0 new teams, competitions or channels (SC-006), and `seen_count` rising with no duplicate on a second run.
- [ ] T061 [US3] Add Lane B2's items to `docs/owner-actions.md`: `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` on VPS-2 if missing, `KUMA_PUSH_URL_LIVE` and its monitor, the OCI resize, and the disk check.
- [ ] T062 [US3] **Only if B1's T040 asks (FR-062):** build a custom arm64 Caddy image with `cache-handler` under `infra/`, cache `/v1/live` for at most 15 s keeping `ETag` and `304`, cover it in `infra.yml`, update `docs/runbooks/load-testing.md` and `deploy-and-rollback.md`, and tell B1 to re-run. Otherwise, close this task as not needed and say why.

---

## Lane A

**Goal:** an editor clears unmatched names and maintains broadcast rights.

**Independent test:** over WireGuard, map, create and ignore queued names; read a failed run's raw page; create a rights holder and see it in `/v1/competitions/{id}` ([quickstart A](quickstart.md#lane-a)).

### Setup (A)

- [ ] T063 [US4] After B1's T017, run `pnpm orval`, commit the output, and add every new endpoint to `responseSchemas` in `admin/src/api/http.ts` (a request without one fails). Add the copy to `admin/src/i18n/ar.ts`, and the `alias_conflict` and `source_not_runnable` codes to `errorCopy`.
- [ ] T064 [US4] Read the boards and their HTML in `madar-design/admin-react/SCREENS.md`: A13 Sources + unresolved names, A13 Run detail, A9 Rights holders. Add the routes in `admin/src/app/App.tsx`: `/rights-holders` replaces its placeholder (`navigation.ts` already links it).

### Unresolved queue: tests first, then code (A)

- [ ] T065 [P] [US4] In `admin/src/features/unresolved/UnresolvedQueue.test.tsx`, test: rows show name (a Latin name as an LTR island), kind, source, match context, suggestion and confidence with Western digits; the source filter; the count; loading, empty and error states; map with a suggestion pre-filled and nothing written before save; the picker for several `exact` candidates, which sends `scope_to_competition: true`; `alias_conflict` and a stale `If-Match` showing their copy; ignore; keyboard focus.
- [ ] T066 [US4] Build `admin/src/features/unresolved/UnresolvedQueue.tsx` and `queries.ts`, rebuilt from the board with the existing `DataTable`, `Field` and `StatusChip`, placed under A13 in `admin/src/features/sources/SourcesPage.tsx`. T065 passes.
- [ ] T067 [P] [US4] In `admin/src/features/unresolved/CreateFromName.test.tsx`, test: create new opens the existing team, competition or channel form pre-filled, then calls `map` with `created: true`; a failed `map` leaves the row open and says so.
- [ ] T068 [US4] Build `CreateFromName.tsx`, reusing `TeamEditor`, `CompetitionEditor` and the channel drawer. T067 passes.

### Sources and run detail (A)

- [ ] T069 [P] [US4] In `admin/src/features/sources/SourcesPage.test.tsx`, test the Live poller card: matches live, each source's state, error share, "run now" absent, pause and resume. In `SourceRunPage.test.tsx`, test: the fetch-to-upsert rows from the log, with «لم يبدأ» for a stage it doesn't record; the raw page polling `pending` for up to 10 s, then `ready`, `gone` and a timeout; `truncated` shown; a fixture with `<script>` and `onerror` rendering as text and running nothing; `url` as an LTR island, not a link.
- [ ] T070 [US4] Add the card to `SourcesPage.tsx`.
- [ ] T071 [US4] Complete `admin/src/features/sources/SourceRunPage.tsx` to match the board. Raw text goes in a `<pre>` as a React child, never `dangerouslySetInnerHTML`. T069 passes.

### A9 Rights holders: tests first, then code (A)

- [ ] T072 [P] [US4] In `admin/src/features/rights/RightsHoldersPage.test.tsx`, test: list and drag order with keyboard support; create and edit with competitions, carriages, satellites, a frequency list, access and package; the Zod schema refusing zero or two primaries in a carriage; the frequency shown LTR; a stale `If-Match`; delete for an admin only; all list states.
- [ ] T073 [US4] Build `admin/src/features/rights/RightsHoldersPage.tsx` and `queries.ts`, with the existing drag-order pattern from `CompetitionsPage.tsx`.
- [ ] T074 [US4] Build `admin/src/features/rights/RightsHolderEditor.tsx` with React Hook Form and the generated Zod schemas. T072 passes.

### Validation (A)

- [ ] T075 [US4] Run `pnpm typecheck && pnpm lint && pnpm test && pnpm build && ./scripts/check-literals.sh && ./scripts/check-token-copy.sh && pnpm e2e`. Extend `admin/e2e/smoke.spec.ts` only if a new shell route breaks it.
- [ ] T076 [US4] Compare with the boards at 1440 and 1024 in both themes and attach the screenshots to the PR. Walk [quickstart A](quickstart.md#lane-a) over WireGuard after deploy, including SC-007's timing.
- [ ] T077 [US4] Add Lane A's items to `docs/owner-actions.md`, and the queue's use to `docs/runbooks/imports-and-sources.md`, where its section already exists.

---

## Lane M

**Goal:** a fan opens a channel, a team or a competition and sees what's on.

**Independent test:** on a real Android phone, open each screen from S2 or S3 with real data in both themes; follows survive a restart; each offline and empty state shows ([quickstart M](quickstart.md#lane-m)).

### Setup (M)

- [ ] T078 [US2] After B1's T017, run `dart run swagger_parser` and `dart run build_runner build -d`, and commit the output. Read the boards and HTML for S6 Channel sheet, S7 Team and S8 Competition in `madar-design/app-flutter/SCREENS.md`.
- [ ] T079 [US2] Add the strings to `app/lib/core/l10n/app_ar.arb`, using the boards' copy (`«تابع القناة»`, `«القادمة»`, `«النتائج»`, `«لا توجد مباريات قادمة»`, `«حقوق البث»`, `«سجل التردد»`) and the PB §14 glossary.

### Tests first (M): write them and see them fail

- [ ] T080 [P] [US2] In `app/test/features/channel/`, `team/` and `competition/`, write repository tests against the existing `CachedDocuments` table with keys `channel:<id>`, `team:<id>` and `competition:<id>`: the drift copy is emitted first; `If-None-Match` is sent; a `200` updates; a `304` changes nothing; a failed request with no cache reaches the stream as an error.
- [ ] T081 [P] [US2] Write widget tests and goldens (RTL × {light, dark} × {1.0, 1.3}) for each screen's states: first-load skeleton, cached, stale age, offline, no connection, empty, error. Also test: S6's readout visible with no tap, dark and LTR; other carriages with My satellites and free first; frequency history hidden when empty and limited to 3 when not; S7's tabs and empty copy; S8's date groups by local date, `«لم يُحدد»` for an unknown kickoff, an estimated match with no score, and rights rows with no chevron or tap; merged Arabic semantics labels; router tests for the three paths and the entry points.

### Implementation (M)

- [ ] T082 [US2] Add `data` and `domain` for `app/lib/features/channel/`, `team/` and `competition/`: Riverpod repositories using the generated client. T080 passes. Run `build_runner`.
- [ ] T083 [P] [US2] Build `app/lib/features/channel/presentation/channel_sheet.dart` and focused sub-widgets per [app-screens](contracts/app-screens.md#s6), with the existing `FrequencyReadout`, `Logo` and `MatchRow`, and `ListView.builder` for dynamic lists. Replace `/channel/:id` in `app/lib/core/router/` with a `pageBuilder` that shows a modal bottom sheet and stays deep-linkable.
- [ ] T084 [P] [US2] Build `app/lib/features/team/presentation/team_page.dart` per [app-screens](contracts/app-screens.md#s7), and replace `/team/:id`.
- [ ] T085 [P] [US2] Build `app/lib/features/competition/presentation/competition_page.dart` per [app-screens](contracts/app-screens.md#s8), with no hide/show and no `عرض الكل`, and replace `/competition/:id`.
- [ ] T086 [US2] Wire the entry points: S3's carriage rows and S5's channel rows to S6; S3's hero crest and name, and S9, to S7; S2's section header, S3's competition line and S9 to S8. A `MatchRow` tap stays S3. Merge `/v1/live` values into these screens' rows as on S2.
- [ ] T087 [US2] Wire follow on S6, S7 and S8 to `follows_repository`, as a plain toggle. T081 passes.

### Validation (M)

- [ ] T088 [US2] From `app/`, run `flutter analyze`, `./tool/check_literals.sh`, `./tool/check_token_copy.sh` and `RTEST_HOST=flutter-tests rtest` (never `flutter test` on the laptop; if the box is unreachable, tell the owner). Regenerate goldens only as `app/CLAUDE.md` says. Confirm `app/lib/**/*.g.dart` are current.
- [ ] T089 [US2] Update `docs/runbooks/remote-config.md`'s `features` example to `live_center: false` until D6, and add the owner step to set the value. Confirm no code reads the flag.
- [ ] T090 [US2] Compare each screen with its PNG in both themes, and hand the owner [quickstart M](quickstart.md#lane-m)'s steps on a real Android phone (SC-008), with the build used.
- [ ] T091 [US2] Add Lane M's items to `docs/owner-actions.md`: the device walk, the Remote Config value, and the next `app-v*` and `web-v*` tags.

---

## Done check

Copied word for word from delivery-plan Appendix A, row 005:

> A real live match updates status and score from FilGoal, cross-checked with YallaKora (O7); YallaKora imports; unresolved names visible in the admin; S6, S7, S8 on a device

Replay alone doesn't pass it.

**Preconditions (owner):**

- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` on VPS-2;
- the capture's unmatched names cleared before the done-check match (T022);
- the load test passing before the public link is announced (FR-063; not required for this done check).

**Checks:**

- [ ] DC1 A real live match updates status and score from FilGoal, cross-checked with YallaKora: B1 T038, on a match after the capture's. With no later kickoff today, this moves to the next match day.
- [ ] DC2 YallaKora imports: B2 T060.
- [ ] DC3 Unresolved names visible in the admin: Lane A T076, with real rows from T060.
- [ ] DC4 S6, S7, S8 on a device: Lane M T090, walked by the owner.
- [ ] DC5 The load test re-run passes (SC-010, the carry-over): B1 T040.
- [ ] DC6 Each lane's owner items are in `docs/owner-actions.md`, and every changed operated part has its runbook (FR-054).
