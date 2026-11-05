---

description: "D5 follow-up · Live sources: tasks per lane"
---

# Tasks: D5 follow-up · Live sources

**Input**: Design documents from `specs/031-d05-live-sources/`: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/live-rules.md](contracts/live-rules.md), [quickstart.md](quickstart.md).

**Tests**: Mandatory (constitution, Quality Gates). In every lane, test tasks come first and must be seen failing before the code they cover.

**Organization**: one `## Lane` section per lane, plus `## Before lanes start` and a final `## Done check`.

- A lane implements and ticks **only its own section** and changes only its own folders (FR-028). Generated files are never edited by hand.
- Review fix tasks are appended at the end of a lane's section by `/speckit-review-implementation`.
- **Moved here from spec 005:** T020 (capture), T021 (report), T022 (names and stats), T038 (watched match), T039 (SD update). Spec 005's T037 and T040 stay there.

| Section | Spec story | Story label | Branch | Folders |
| --- | --- | --- | --- | --- |
| Lane B1 | User Stories 1–4 | `[US1]`–`[US4]` | `d05-b1` | `backend/` except `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/`; `specs/031-d05-live-sources/capture-report.md` |
| Lane B2 | User Story 4, and Goal.com's rate limit | `[US3]`, `[US4]` | `d05-b2` | `infra/`, `.github/`, `backend/app/adapters/`, `backend/tests/adapters/` |

Every lane may also edit `docs/runbooks/` for its own parts and its own section of `docs/owner-actions.md`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task).
- **[USn]**: the spec story the task belongs to.
- Paths are repo-relative.

## Dependencies & execution order

```text
T001 (docs and spec reach the lane branches)
 ├─▶ B1 T003–T012 (parsers and rules): pure, start now
 ├─▶ B1 T013–T020 (0008, apply, watchdog, cycle) ─▶ T021–T022 (capture tool)
 ├─▶ B2 T030–T032 (bucket, settings) ─▶ B1's Goal.com fetches, on any host
 └─▶ B1 T021–T022 + B2 T030–T033, merged and deployed
       ─▶ T026 (capture on VPS-2, next match night)
       ─▶ T027 (fixtures, parsers corrected) ─▶ T028 (report; rules change here if needed)
       ─▶ T029 (a later match, watched) ─▶ Done check
T002 (owner's approval record): done 2026-11-05
```

### Inside each lane

Tests first, seen failing, then code. The tasks are in order unless marked [P].

### Parallel examples

- **B1:** T003, T004 and T005 are separate test files, as are T010 and T011.
- **B2:** T030 and T032 touch different folders.

## Implementation strategy

1. **Parsers and rules first.** They're pure, and the replay proves them today. That alone removes the worst findings.
2. **Storage and cycle next**, so the new rules run for real, with Goal.com behind its setting.
3. **Capture from VPS-2 on the next match night.** It settles live list parsing and datacenter access.
4. **If the capture blocks or disproves something:** the report says so, the rule and docs change together (FR-025), and a blocked source stops until the owner decides. Nobody works around a block.
5. **If the day runs late:** cut Goal.com's match pages first (T009's `parse_match`, and stats and the second events source in T018). Its list page still gives score, status and minute. The parser fixes and new rules don't move.

---

## Before lanes start

- [ ] T001 The docs, the "moved" notes in spec 005's tasks and this spec are committed in PR #39, at the owner's request. Before starting, bring that branch (or `master`, once #39 is merged) into `d05-b1` and `d05-b2`, so they have round 1's fixes and these docs.
- [X] T002 Owner: record FootballCo's approval in `docs/owner-actions.md`. Done 2026-11-05 from the owner's report: scraping for goals, match stats and everything else this spec plans, with no conditions or exceptions.

---

## Lane B1

**Goal:** the poller works on real live pages; a goal reaches fans quickly and truthfully; a finished match keeps its score; Goal.com runs as a third source with an off switch; a capture and a watched match prove it.

**Independent test:** `uv run pytest tests/live`, including the replay ([quickstart](quickstart.md#b1-replay-and-tests)). Then the capture and the watched match.

### Parsers: tests first (B1)

- [ ] T003 [P] [US1] In `backend/tests/live/test_yallakora_parse.py`, add trimmed real pages from `~/madar-capture/2026-11-04/live/yallakora/` under `backend/tests/live/fixtures/`, with no commentary: test `مباشر` on a live match page gives `live` with no period. Add list-row tests built from the capture's rows for `الشوط الأول` (live, 1H), `استراحة` (halftime) and `الشوط الثاني` (live, 2H). Test an unknown status drops only that row and reports it, and that a page with no match center still raises `LayoutChanged`.
- [ ] T004 [P] [US1] In `backend/tests/live/test_filgoal_parse.py`, with trimmed models from `~/madar-capture/2026-11-04/live/filgoal/`: `TimeElapsed.Minutes` of −98 in the first half gives `22`; −109 in the second half gives `56`; a positive value still works; `MatchStatusMaxTime` overflow gives `45+n`; a result past `MatchStatusMaxTime` + 15 gives no minute; no result is negative. Types 4, 20 and 9 give `red_card`, `own_goal` and `missed_penalty`. Leipzig's own goal (home team, score 0–1) has `side = away`. A red card's side stays the player's team. An unknown row status drops only that row.
- [ ] T005 [P] [US3] In new `backend/tests/live/test_goal_parse.py`, with trimmed pages from `~/madar-capture/2026-11-04/live-goal/` and one saved list page: list rows give ID, teams, kickoff, status, period, minute and score, with page links from `href`s; `LIVE` with `FIRST_HALF`, `HALF_TIME`, `SECOND_HALF`, plus `RESULT` and `FIXTURE`, map correctly; extra minutes show as `45+n`; an unknown status drops only its row; a missing `__NEXT_DATA__` raises `LayoutChanged`. On a match page: `GOAL`, `GOAL_OWN`, `GOAL_PENALTY` map to ours, keep Goal.com's side and get a stable hashed `external_id`; `PERIOD_*` and `CARD_YELLOW` are skipped; other types are logged. Lineups have formation, names and shirt numbers, with no ratings. `stats.summary` gives `[{type, home, away}]`. No reading holds commentary, an article, a venue or an image.

### Parsers: implementation (B1)

- [ ] T006 [US3] In `backend/app/live/types.py`, add `UnknownStatus`, a `stats` field on `SourceReading`, and source order `("filgoal", "goal", "yallakora")`. In `backend/app/live/config.py`, add the settings in [data-model](data-model.md#settings) and remove `LIVE_CONFIRM_WAIT_S`. Importing `app.workers` must still load neither `app.settings` nor `app.db`.
- [ ] T007 [US1] In `backend/app/live/sources/yallakora.py`, add the statuses, and record a row with an unknown status instead of raising from `parse_list`. T003 passes.
- [ ] T008 [US1] In `backend/app/live/sources/filgoal.py`, fix `_minute` by [R4](research.md#r4-filgoals-minute), map types 4, 20 and 9, flip an own goal's side by [R7](research.md#r7-own-goals-and-event-sides), and treat an unknown row status as in T007. T004 passes.
- [ ] T009 [US3] Write `backend/app/live/sources/goal.py` by [R8](research.md#r8-goalcoms-reader) with pure `parse_list` and `parse_match`, add `GOAL_HOST` and an empty deny list to `backend/app/live/robots.py`, and commit its `robots.txt` as `backend/app/live/robots/goal.txt`, extending `backend/tests/live/test_robots.py`. T005 passes.

### Rules: tests first (B1)

- [ ] T010 [P] [US1] Rewrite `backend/tests/live/test_crosscheck.py` as a table test of [the contract](contracts/live-rules.md) with 1, 2 and 3 sources in every order: first score; a rise from any source goes out at once; the highest of two rises wins; a lagging source neither blocks nor lowers it; a lower reading keeps the score while any reading covers it; a drop held under 5 minutes changes nothing, and at 5 minutes goes out; two sources agreeing on a lower score don't lower it before 5 minutes; a reappearing score clears `drop_since`; 1–1 to 0–2 counts as a drop; penalty scores; disagreement at 10 minutes, on a finished match, and its closing; any source's full time finishes; full time waits while a drop is open or scores differ, then finishes on the accepted score with an alert; a source without penalties doesn't erase them; a failed request can't move a match back; a backward status holds for 5 minutes; a finished status never returns; status and minute order; a minute not moving backward; a source not covering; some sources down; all enabled sources down; a disabled source having no effect.
- [ ] T011 [P] [US1] Write `backend/tests/live/test_replay.py`, feeding [replay-timelines-2026-11-04.json](replay-timelines-2026-11-04.json) through `decide`, a poll at a time, for each expectation in [quickstart](quickstart.md#b1-replay-and-tests): every new score ≤ 60 s after the first source (SC-001); 0 scores shown backward; 11 of 11 final scores right; at most 1 disagreement alert (SC-002); Mouloudia Alger ends on 1–0; each match the capture saw reach full time ends finished (SC-005). SC-003 and SC-004 are asserted over the saved fixtures.

### Rules: implementation (B1)

- [ ] T012 [US1] Rewrite `backend/app/live/crosscheck.py`: `decide(state, sides, now, *, drop_hold, disagree_after)` per the contract, still one pure function with no database access, adding `drop_since`, `status_drop_since`, `score_first_source` and `score_changed_at` to `LiveState` and `Decision`. T010 and T011 pass.

### Storage and cycle: tests first (B1)

- [ ] T013 [P] [US3] Extend or add `backend/tests/db/test_0008_live_sources.py`: upgrade and downgrade on an empty database and the snapshot; the new `match_live_state` columns are nullable; `match_events.missing_since` is nullable; `match_stats` has PK `(match_id, source)`, `stats` jsonb and `ON DELETE CASCADE`; `sources` holds `('goal', 'internal')`, inside the kinds the previous release accepts, and `GET /sources` hides it by name.
- [ ] T014 [P] [US2] Extend `backend/tests/live/test_apply.py` and `test_watchdog.py`: an event missing under 5 minutes stays, and at 5 minutes is deleted; it returning clears `missing_since`; lineups come from the first source in order that has them and don't alternate; stats are stored only on change and bump no client dataset; a `live` 2H match with no score change for 15 minutes at kickoff + 150 finishes with its score and opens `stuck:<id>` once; a goal inside those 15 minutes keeps it open; extra time and penalties aren't touched until + 210; a stale row before + 150 still goes to the clock; a row past the limit that reached the second half never goes back to `scheduled` and keeps its score; `manual` and `locked_fields` win.
- [ ] T015 [P] [US3] Extend `backend/tests/api/test_match_detail_live.py`: events come from FilGoal if it has any, otherwise Goal.com, and never both; goal events no longer vanish during a `drop_since`; `/v1` schema unchanged, by the committed OpenAPI files.
- [ ] T016 [P] [US3] Extend `backend/tests/live/test_cycle.py`, with a fake fetcher: three sources in one cycle; `LIVE_GOAL_ENABLED=false` sends Goal.com 0 requests and writes nothing from it (SC-006); Goal.com's requests come after the other two, stop at the deadline and never cost them a read; Goal.com failing, blocked or invalid leaves the others working; an unknown status opens `unknown_status:<source>` once and doesn't stop the source; `both_down` only when all enabled sources are down; Goal.com names reach `record_unresolved` under `goal`, with no team created.

### Storage and cycle: implementation (B1)

- [ ] T017 [US3] Write `backend/alembic/versions/0008_live_sources.py` (revises `0007`), expand-only, per [data-model.md](data-model.md), and add the columns and `MatchStats` to `backend/app/db/models.py`. Add `goal` to the live-source names in `backend/app/services/admin/sources.py`. T013 passes. **Owner reviews the migration before merge.**
- [ ] T018 [US2] In `backend/app/live/apply.py`, write the new state, events with `missing_since`, one lineup source and stats. In `backend/app/services/match_detail.py`, serve one events source and drop the `candidate` filter. T014's apply tests and T015 pass.
- [ ] T019 [US2] In `backend/app/live/watchdog.py`, add the stuck-match step per [the contract](contracts/live-rules.md#stuck-matches-watchdog), guard the hard-limit case, and add `stuck:` to `MATCH_PROBLEM_PREFIXES`. In `backend/app/live/problems.py`, add the Arabic text for `unknown_status` and `stuck`, and reword `both_down` and `disagree` for any number of sources. T014's watchdog tests pass.
- [ ] T020 [US3] In `backend/app/live/cycle.py`, replace `HOSTS`, `LIST_PATHS` and the two-source calls with one table of enabled sources, in the order in [R8](research.md#r8-goalcoms-reader). Pass `sides` to `decide`, handle `UnknownStatus` rows, and add `LIVE_PAGE_CAP_GOAL`. Use `backend/app/live/tasks.py` for any settings it passes. T016 passes, and the existing cycle tests pass or are updated only where the rules changed.

### Capture tool (B1)

- [ ] T021 [P] [US4] Extend `backend/tests/live/test_capture.py`: `capture-live` reads all three list pages; picks live match pages from each list up to a cap, with no IDs given; saves list and match pages gzipped; a read error of any kind, including `http.client.IncompleteRead` from the fetcher, is logged and the next page goes on; a source failing 5 rounds in a row sends one alert and one on recovery; it writes nothing to the database.
- [ ] T022 [US4] Extend `backend/app/live/capture.py` and the `capture-live` command in `backend/app/cli.py` to match, using `app.adapters.alerts.send_alert`. T021 passes.

### Ops and validation (B1)

- [ ] T023 [US4] Update `docs/runbooks/live-poller.md`: the three sources, the new rules, each new setting (and the removal of `LIVE_CONFIRM_WAIT_S`), the new alerts, `capture-live` on VPS-2 as B2 sets it up, switching Goal.com off, and removing its data. Add the new alerts to `docs/runbooks/on-call.md`. Make [quickstart](quickstart.md#b1-and-b2-capture-from-vps-2)'s command match the code.
- [ ] T024 [US4] Run `uv run ruff check . && uv run mypy --strict app && uv run pytest`, `uv run python -m app.cli export-openapi && git diff --exit-code openapi/`, and confirm `app/live` meets the coverage bar spec 005's T035 sets.
- [ ] T025 [US4] Add any new Lane B1 items to `docs/owner-actions.md`, beyond the migration review, the capture night and the watched match already there.
- [ ] T026 [US4] After T022 and B2's T030–T033 are merged and deployed, run the capture on VPS-2 for a night's whole match, starting before kickoff ([quickstart](quickstart.md#b1-and-b2-capture-from-vps-2)). This replaces spec 005's T020. If a source blocks VPS-2, stop using it and tell the owner. **If no suitable match is available, say so in `docs/owner-actions.md` and move it to the next match night.**
- [ ] T027 [US4] Commit a trimmed set from the capture under `backend/tests/live/fixtures/`, covering every status and mapped event type, and live list rows from all three sources, with no personal data and no commentary. Add them to T003–T005's tests, see the differences fail, then correct the parsers (FR-022).
- [ ] T028 [US4] Write `specs/031-d05-live-sources/capture-report.md` (FR-023): fields per page; every status and its state; each source's delays, reversals, errors and blocks from VPS-2; the three-way comparison the first capture couldn't give; gzip page sizes; the values for page caps and timers; unresolved team names per source, handed to the owner (spec 005's T022). Stats storage is already decided, so no further revision follows from it. If a rule is wrong, change it with `crosscheck.py`, `spec.md` and SD §6.7 together (FR-025).
- [ ] T029 [US4] Watch one real match, later than T026's, against the broadcast on the deployed hosts with all three sources ([quickstart](quickstart.md#b1-a-real-match)). This replaces spec 005's T038. For each goal, record its time on the broadcast, first source, acceptance and arrival in the app, and check ≤ 45 s from acceptance (SC-008). Add the results to `capture-report.md`, and update SD §6.7 and `O7` with what the capture and match found (spec 005's T039).

---

## Lane B2

**Goal:** Goal.com has a rate limit, the new settings reach the live worker, and the capture can run on VPS-2.

**Independent test:** a unit test of the new bucket, then `capture-live` starts on VPS-2 and saves one round from all three sources.

- [ ] T030 [P] [US3] In `backend/tests/adapters/`, test that `www.goal.com` has its own bucket and shares none with the other hosts. Then add `GOAL_BUCKET` to `backend/app/adapters/ratelimit.py`, sized for one list page and `LIVE_PAGE_CAP_GOAL` pages a minute with room for retries.
- [ ] T031 [US3] Confirm that host checks and the fetcher accept `www.goal.com` by `allowed_hosts`, and that a dropped connection (`http.client.IncompleteRead`) comes out of `backend/app/adapters/fetcher.py` as a `FetchError` or `Retryable`, not raw, with a test in `backend/tests/adapters/`. T021 relies on it.
- [ ] T032 [P] [US3] Add `LIVE_GOAL_ENABLED` and `LIVE_PAGE_CAP_GOAL` to `infra/compose/example.env` and the settings table in `infra/README.md`, and remove `LIVE_CONFIRM_WAIT_S` if listed. Any `check_env` step must pass with them unset.
- [ ] T033 [US4] Check that `capture-live` can run on VPS-2 through `infra/compose/vps2.yml` with `/srv/raw` writable, the Telegram settings present and `SCRAPE_USER_AGENT` set. Give B1 the exact command for the runbook, and add disk use for 240 minutes of capture to its section.
- [ ] T034 [US4] Add this spec's Lane B2 items to `docs/owner-actions.md`, if any need the owner.

---

## Done check

- [ ] DC1 Owner: `pytest tests/live/test_replay.py` passes, the capture report from VPS-2 exists, and on a watched match with all three sources, status, minute and score match the broadcast from kickoff to full time.
