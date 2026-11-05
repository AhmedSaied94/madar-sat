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
T035 (extra-time check): the first deployed match that reaches extra time or penalties. It doesn't block the Done check
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
3. **Capture from VPS-2 on the next match night.** It settles live list parsing, datacenter access and [R13](research.md#r13-the-final-rules-replayed)'s assumption about list rows.
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

- [X] T003 [P] [US1] In `backend/tests/live/test_yallakora_parse.py`, add trimmed real pages from `~/madar-capture/2026-11-04/live/yallakora/` under `backend/tests/live/fixtures/`, with no commentary: test `مباشر` on a live match page gives `live` with no period. Add list-row tests built from the capture's rows for `الشوط الأول` (live, 1H), `استراحة` (halftime) and `الشوط الثاني` (live, 2H). Test that a row with an unknown status gives a reading with `unknown_status` set, `status`, `period` and `minute` empty, and its score if it has one, on both the list and the match page, and that the other rows parse as usual. A page with no match center still raises `LayoutChanged`.
- [X] T004 [P] [US1] In `backend/tests/live/test_filgoal_parse.py`, with trimmed models from `~/madar-capture/2026-11-04/live/filgoal/`: `TimeElapsed.Minutes` of −98 in the first half gives `22`; −109 in the second half gives `56`; a positive value still works; `MatchStatusMaxTime` overflow gives `45+n` in the first half and `90+n` in the second; the limit is on elapsed time in the period, not on the result ([R4](research.md#r4-filgoals-minute)), so 60 minutes into the second half gives `90+15`, and 61 gives no minute; no result is negative. Types 4, 20 and 9 give `red_card`, `own_goal` and `missed_penalty`. Leipzig's own goal (home team, score 0–1) has `side = away`. A red card's side stays the player's team. An unknown status behaves as in T003. −59 in the second half gives `46`, which is the wrap in [R4](research.md#r4-filgoals-minute); T010 and T014 prove it can't move the minute or the peak back. `minute_value` gives 93 for `90+3`, and none for an empty minute.
- [X] T005 [P] [US3] In new `backend/tests/live/test_goal_parse.py`, with trimmed match pages from `~/madar-capture/2026-11-04/live-goal/`. No Goal.com list page was saved, so first save one: one request for its list path, under `SCRAPE_USER_AGENT`, into `~/madar-capture/<date>/live-goal/`, and commit it trimmed under `backend/tests/live/fixtures/`. If it's blocked, stop and tell the owner. If it has no live rows at that moment, build those rows from the fields in the capture's `change` records, say so in a comment, and let T027 replace them. List rows give ID, teams, kickoff, status, period, minute and score, with page links from `href`s; `LIVE` with `FIRST_HALF`, `HALF_TIME`, `SECOND_HALF`, plus `RESULT` and `FIXTURE`, map correctly; extra minutes show as `45+n`; an unknown status behaves as in T003; a missing `__NEXT_DATA__` raises `LayoutChanged`. On a match page: `GOAL`, `GOAL_OWN`, `GOAL_PENALTY` map to ours, keep Goal.com's side and get a stable hashed `external_id`; `PERIOD_*` and `CARD_YELLOW` are skipped; other types are logged. Lineups have formation, names and shirt numbers, with no ratings. `stats.summary` gives `[{type, home, away}]`. No reading holds commentary, an article, a venue or an image.

### Parsers: implementation (B1)

- [X] T006 [US3] In `backend/app/live/types.py`, add `unknown_status` and `stats` fields on `SourceReading`, and source order `("filgoal", "goal", "yallakora")`. In `backend/app/live/sources/common.py`, add `minute_value`, which turns a minute such as `90+3` into 93. In `backend/app/live/config.py`, add the settings in [data-model](data-model.md#settings) and remove `LIVE_CONFIRM_WAIT_S`. Importing `app.workers` must still load neither `app.settings` nor `app.db`.
- [X] T007 [US1] In `backend/app/live/sources/yallakora.py`, add the statuses, and give a row with an unknown status a reading with `unknown_status` set, from both `parse_list` and `parse_match`, instead of raising. T003 passes.
- [X] T008 [US1] In `backend/app/live/sources/filgoal.py`, fix `_minute` by [R4](research.md#r4-filgoals-minute), map types 4, 20 and 9, flip an own goal's side by [R7](research.md#r7-own-goals-and-event-sides), and treat an unknown row status as in T007. T004 passes.
- [X] T009 [US3] Write `backend/app/live/sources/goal.py` by [R8](research.md#r8-goalcoms-reader) with pure `parse_list` and `parse_match`, treating an unknown status as in T007. Add `GOAL_HOST` and an empty deny list to `backend/app/live/robots.py`, and commit its `robots.txt` as `backend/app/live/robots/goal.txt`, extending `backend/tests/live/test_robots.py`. T005 passes.

### Rules: tests first (B1)

- [X] T010 [P] [US1] Rewrite `backend/tests/live/test_crosscheck.py` as a table test of [the contract](contracts/live-rules.md) with 1, 2 and 3 sources in every order: first score; a rise from any source goes out at once; the highest of two rises wins; a lagging source neither blocks nor lowers it; a lower reading keeps the score while any reading covers it; a drop held under 5 minutes changes nothing, and at 5 minutes goes out; two sources agreeing on a lower score don't lower it before 5 minutes; a reappearing score clears `drop_since`; 1–1 to 0–2 counts as a drop; penalty scores; disagreement at 10 minutes, on a finished match, and its closing; a source without penalties doesn't erase them; a failed request can't move a match back; a backward status holds for 5 minutes; a finished status never returns; a source not covering. It also covers:

  - **Later status (FR-007, FR-017):** it goes out at once from any usable source, with FilGoal behind, and a tie on stage follows `ORDER`. `live` with no period moves a `scheduled` row to `live`, and never counts as a move back from half-time or the second half.
  - **The minute (FR-017):** it comes from the source that supplied the status, then the next in `ORDER` at the same stage. A late answer within 5 of the peak keeps the stored minute. A minute more than 5 below its source's `peak_minute`, in the same period as `peak_period`, counts as no minute, so FilGoal's wrap from 104 to 46 never shows. In another period it stands, so 47 in the second half shows after a first half that reached 53. If the poll has readings but none gives a minute for the stored stage, the minute is cleared: during the full-time hold, with only `unknown_status` rows, and on list rows with no minute. A poll with no readings at all changes nothing.
  - **Full time (FR-008):** two sources showing it finish at once, even if a third shows extra time or penalties. One source alone finishes only at 10 minutes, including when it's the only source covering the match. That source reading anything else, including `unknown_status`, restarts the 10 minutes, and a poll with no reading from it doesn't. Any source showing extra time or penalties stops a lone full time counting and clears the hold. Once the condition is met, it waits while a drop is open or scores differ, then finishes on the accepted score with an alert at 5 minutes.
  - **Unknown status (FR-001):** a higher score on an `unknown_status` row is accepted, an equal one stops a drop, and a lower one is ignored. Its status and minute change nothing, and its 0–0 isn't accepted as a first score.
  - **Sources going away:** some sources down; all enabled sources down; a disabled source having no effect.
- [X] T011 [P] [US1] Write `backend/tests/live/test_replay.py`, feeding [replay-timelines-2026-11-04.json](replay-timelines-2026-11-04.json) through `decide`, a poll at a time, for each expectation in [quickstart](quickstart.md#b1-replay-and-tests): every new score ≤ 60 s after the first source (SC-001); 0 scores shown backward; all 16 final scores right, including the 11 in SC-001; at most 1 disagreement alert (SC-002); Mouloudia Alger ends on 1–0; 0 status moves undone; each match the capture saw reach full time ends finished (SC-005). SC-003 is asserted over the saved fixtures.

  For SC-004, the timelines hold no minutes. So commit `backend/tests/live/fixtures/replay-filgoal-clock-2026-11-04.json`, holding only `t`, `match`, the status name, `TimeElapsed.Minutes`, `MatchStatusMaxTime` and `IsCounterEnabled` from the `clock` records in the same `events.jsonl`. Feed each match's records, in order, through the FilGoal minute code and the minute rules. Expect at least 95% of the 1,367 live readings to show a minute (measured: 98.2%, 1,343, [R4](research.md#r4-filgoals-minute)), none negative, and no wrapped minute shown on Bristol City v Wolves.

  The timelines alone can't replay full time, because the capture stopped reading a match's page when it left FilGoal's live list. So commit `backend/tests/live/fixtures/replay-filgoal-live-set-2026-11-04.json`, holding only `t` and `ids` from the `live-set` records for `filgoal` in `~/madar-capture/2026-11-04/live/events.jsonl`. Then model each poll as [R13](research.md#r13-the-final-rules-replayed) does, and state this assumption in a comment: inside the set, FilGoal's last row stands; outside it, a last row at the second half or later reads full time, and anything else is no reading; YallaKora's last row stands. Expect 14 of 16 finished, 10 by a second source and 4 by the hold, with Bristol City v Wolves and Mouloudia Alger left open. If `decide` gives other figures, find out why before changing the test, and correct R13 if R13 is what's wrong.

### Rules: implementation (B1)

- [X] T012 [US1] Rewrite `backend/app/live/crosscheck.py`: `decide(state, sides, now, *, drop_hold, disagree_after, fulltime_hold)` per the contract, still one pure function with no database access. Add `drop_since`, `status_drop_since`, `score_first_source`, `score_changed_at`, `fulltime_source`, `fulltime_since` and `finish_wait_since` to `LiveState` and `Decision`, add `minute` and each source's `peak_minute` and `peak_period` to `LiveState` for the minute rules, and remove `candidate`, `previous_status` and `previous_primary` from `LiveState`. T010 and T011 pass.

### Storage and cycle: tests first (B1)

- [X] T013 [P] [US3] Extend or add `backend/tests/db/test_0008_live_sources.py`: upgrade and downgrade on an empty database and the snapshot; the new `match_live_state` columns are nullable; `match_source_readings.peak_minute` is a nullable smallint and `peak_period` is nullable text; `match_events.missing_since` is nullable; `match_stats` has PK `(match_id, source)`, `stats` jsonb and `ON DELETE CASCADE`; `sources` holds `('goal', 'internal')`, inside the kinds the previous release accepts, and `GET /sources` hides it by name.
- [X] T014 [P] [US2] Extend `backend/tests/live/test_apply.py` and `test_watchdog.py`: an event missing under 5 minutes stays, and at 5 minutes is deleted; it returning clears `missing_since`; lineups come from the first source in order that has them and don't alternate; stats are stored only on change and bump no client dataset; `manual` and `locked_fields` win.

  - **`peak_minute`:** it's written from `live` and `extra_time` readings, with `90+3` as 93. It never goes down, from 104 to 46 for example. `peak_period` is the period of the reading that set it, and stays when a lower reading comes from a later period. A halftime reading or an `unknown_status` row leaves both alone.
  - **Stuck at + 150 (FR-009):** a `live` 2H match with no score change for 15 minutes and no usable source's peak below 90 finishes with its score and opens `stuck:<id>` once. Test Bristol City v Wolves' numbers: peak 104, current minute 72, finishing on 1–2. A goal inside those 15 minutes keeps it open. A usable source with a peak below 90 keeps it open, as after a late kickoff. A source with no peak, one not usable, or one not read within `LIVE_STALE_AFTER_S` has no say.
  - **The limit at + 210 (FR-009, FR-010):** a row in the second half, extra time or penalties finishes with its score and opens `stuck:<id>`, and never goes back to `scheduled`. Extra time and penalties aren't touched before + 210. A row that never reached the second half goes to the clock, as in spec 005.
  - **Stale rows:** a stale row before + 150 still goes to the clock.
  - **The clock past + 150 (FR-010):** `to_clock` refuses a row in the second half, extra time or penalties, from each of its three callers: the watchdog's stale branch, `apply_decision` on `decide`'s fallback, and `pause_feed_rows`. The row keeps its status and score, no `stale:` alert opens, and the stuck step finishes it. A row that hasn't reached the second half still goes to the clock.
- [X] T015 [P] [US3] Extend `backend/tests/api/test_match_detail_live.py`: events come from FilGoal if it has any, otherwise Goal.com, and never both; goal events no longer vanish during a `drop_since`; `/v1` schema unchanged, by the committed OpenAPI files.
- [X] T016 [P] [US3] Extend `backend/tests/live/test_cycle.py`, with a fake fetcher: three sources in one cycle; `LIVE_GOAL_ENABLED=false` sends Goal.com 0 requests and writes nothing from it (SC-006); Goal.com's requests come after the other two, stop at the deadline and never cost them a read; Goal.com failing, blocked or invalid leaves the others working; an unknown status opens `unknown_status:<source>` once and doesn't stop the source; a row with an unknown status and a score reaches `decide` as `valid` and keeps the match from going stale, and one with no score comes in as `not_covering`; `both_down` only when all enabled sources are down; Goal.com names reach `record_unresolved` under `goal`, with no team created.

### Storage and cycle: implementation (B1)

- [X] T017 [US3] Write `backend/alembic/versions/0008_live_sources.py` (revises `0007`), expand-only, per [data-model.md](data-model.md), and add the columns and `MatchStats` to `backend/app/db/models.py`. Add `goal` to the live-source names in `backend/app/services/admin/sources.py`. T013 passes. **Owner reviews the migration before merge.**
- [X] T018 [US2] In `backend/app/live/apply.py`, write the new state, `peak_minute` and `peak_period` per [the contract](contracts/live-rules.md#stuck-matches-watchdog), events with `missing_since`, one lineup source and stats, and remove `_last_primary`, which nothing needs now. `load_state` also loads the stored minute and each source's `peak_minute` and `peak_period`. Give `to_clock` the stuck limit, and make it refuse a row past that limit in the second half, extra time or penalties ([the contract](contracts/live-rules.md#stuck-matches-watchdog)). In `backend/app/services/match_detail.py`, serve one events source and drop the `candidate` filter. T014's apply tests and T015 pass.
- [X] T019 [US2] In `backend/app/live/watchdog.py`, add the stuck-match step per [the contract](contracts/live-rules.md#stuck-matches-watchdog), reading `match_source_readings.peak_minute` and `live_source_state`. At the hard limit, finish a row that reached the second half and keep `to_clock` for one that didn't. Pass the stuck limit to `to_clock` from `run_watchdog` and `pause_feed_rows`. Add `stuck:` to `MATCH_PROBLEM_PREFIXES`. In `backend/app/live/problems.py`, add the Arabic text for `unknown_status` and `stuck`, and reword `both_down` and `disagree` for any number of sources. T014's watchdog tests pass.
- [X] T020 [US3] In `backend/app/live/cycle.py`, replace `HOSTS`, `LIST_PATHS` and the two-source calls with one table of enabled sources, in the order in [R8](research.md#r8-goalcoms-reader). Pass `sides` and `fulltime_hold` to `decide`, and the stuck limit to `apply_decision`. Handle `unknown_status` rows per [the contract](contracts/live-rules.md#the-pure-interface), and add `LIVE_PAGE_CAP_GOAL`. Use `backend/app/live/tasks.py` for any settings it passes. T016 passes, and the existing cycle tests pass or are updated only where the rules changed.

### Capture tool (B1)

- [X] T021 [P] [US4] Extend `backend/tests/live/test_capture.py`: `capture-live` reads all three list pages; picks live match pages from each list up to a cap, with no IDs given; saves list and match pages gzipped; a read error of any kind, including `http.client.IncompleteRead` from the fetcher, is logged and the next page goes on; a source failing 5 rounds in a row sends one alert and one on recovery; a source whose list reads fine but shows no live rows for 5 rounds while another shows some sends one alert and one on recovery; it sends one alert at the start, naming its expected end, and one at the end; each round writes its time to a Redis key, and a normal end deletes the key; a failed heartbeat write is logged and the capture goes on; the check `live.watchdog` calls sends one alert when the key is more than 5 minutes old, and none when the key is fresh or gone; it writes nothing to the database.
- [X] T022 [US4] Extend `backend/app/live/capture.py` and the `capture-live` command in `backend/app/cli.py` to match, using `app.adapters.alerts.send_alert`. Call the heartbeat check from `live_watchdog` in `backend/app/live/tasks.py`, as [R12](research.md#r12-capture) describes. T021 passes.

### Ops and validation (B1)

- [X] T023 [US4] Update `docs/runbooks/live-poller.md`: the three sources, the new rules, each new setting (and the removal of `LIVE_CONFIRM_WAIT_S`), the new alerts, `capture-live` on VPS-2 as B2 sets it up, what its start, end, quiet and stopped alerts mean, switching Goal.com off, and removing its data. Correct the parser-fix steps: an unknown status no longer fails validation (FR-001), and `_RANKS` changes with `crosscheck.py`. Say what to do on an `unknown_status` alert (T035) and why a match can stay live after one source's full time (FR-008). Add the new alerts to `docs/runbooks/on-call.md`. Make [quickstart](quickstart.md#b1-and-b2-capture-from-vps-2)'s command match the code.
- [X] T024 [US4] Run `uv run ruff check . && uv run mypy --strict app && uv run pytest`, `uv run python -m app.cli export-openapi && git diff --exit-code openapi/`, and confirm `app/live` meets the coverage bar spec 005's T035 sets. Local run on 2026-11-05: ruff, `mypy --strict` and the OpenAPI diff are clean, `app/live` is at 96% with branches against a bar of 70, and everything passes except the four `tests/adapters/test_homebox_acl.py` tests. Those are Lane B2's file, stop at Redis authentication on the local Redis, and fail the same way in `../madar-b2`, so CI has to settle them.
- [X] T025 [US4] Add any new Lane B1 items to `docs/owner-actions.md`, beyond the migration review, the capture night and the watched match already there. T035 goes there as an open item that doesn't block the Done check.
- [ ] T026 [US4] After T022 and B2's T030–T033 are merged and deployed, run the capture on VPS-2 for a night's whole match, starting before kickoff ([quickstart](quickstart.md#b1-and-b2-capture-from-vps-2)). Prefer a night with a cup match that can reach extra time, but don't wait for one. This replaces spec 005's T020. If a source blocks VPS-2, stop using it and tell the owner. **If no suitable match is available, say so in `docs/owner-actions.md` and move it to the next match night.**
- [ ] T027 [US4] Commit a trimmed set from the capture under `backend/tests/live/fixtures/`, covering every status and mapped event type, and live list rows from all three sources, with no personal data and no commentary. Add them to T003–T005's tests, see the differences fail, then correct the parsers (FR-022).
- [ ] T028 [US4] Write `specs/031-d05-live-sources/capture-report.md` (FR-023): fields per page; every status and its state; each source's delays, reversals, errors and blocks from VPS-2; the three-way comparison the first capture couldn't give; gzip page sizes; the values for page caps and timers; unresolved team names per source, handed to the owner (spec 005's T022). Check [R13](research.md#r13-the-final-rules-replayed)'s assumption against the saved list pages: what a list row shows when a match leaves the live list, and whether the finish figures in T011 still hold. Say whether the capture saw extra time or penalties, and leave T035 open if it didn't. Stats storage is already decided, so no further revision follows from it. If a rule is wrong, change it with `crosscheck.py`, `spec.md` and SD §6.7 together (FR-025).
- [ ] T029 [US4] Watch one real match, later than T026's, against the broadcast on the deployed hosts with all three sources ([quickstart](quickstart.md#b1-a-real-match)). This replaces spec 005's T038. For each goal, record its time on the broadcast, first source, acceptance and arrival in the app, and check ≤ 45 s from acceptance (SC-008). Add the results to `capture-report.md`, and update SD §6.7 and `O7` with what the capture and match found (spec 005's T039). Record how long the match took to finish after the first full time.
- [ ] T035 [US2] The extra-time check, on the first deployed match or capture that reaches extra time or penalties. An `unknown_status:<source>` alert may be the first sign, and raw pages last 5 days. Read the saved pages for each source: add its wording to its `STATUS_MAP` in `backend/app/live/sources/`, with a trimmed fixture and a failing test first in `backend/tests/live/`. Check that FR-008 kept the match open and that its goals and shoot-out reached fans, against what the source showed. Add the results to `specs/031-d05-live-sources/capture-report.md`. If a rule is wrong, change it with FR-025. This doesn't block the Done check, because no one can schedule such a match.

### Review fixes (round 1)

These come from [reviews/b1-round-1.md](reviews/b1-round-1.md), which has the evidence for each.

- [X] B1-R1-1 Keep a match in an unmapped extra time or shoot-out open until the hard limit in `backend/app/live/watchdog.py`: `_finish_stuck` finishes a `live` 2H row at kickoff + 150 on a quiet score while its sources show a status no parser knows, so a 1–1 cup match ends `finished` and its shoot-out is lost for good. After the fix, a fresh reading from a usable source with no period, and a status of `NULL` or `live`, counts as still playing, so the row waits for + 210. An ordinary second-half row, such as Bristol City v Wolves, still finishes at + 150. `live` is included because YallaKora's match page says `مباشر`, and `_with_list_stage` in `cycle.py` leaves it with no period when its list row's status is unknown. Change `contracts/live-rules.md`, FR-009 in `spec.md`, SD §6.7 and the stuck table in `docs/runbooks/live-poller.md` with it (FR-025). Add a test that fails before the fix, going through `decide`, `apply_decision` and `run_watchdog`, and a test of an unknown row over two polls 6 minutes apart that asserts `status_drop_since` stays empty. (CRITICAL, per constitution II and VII, FR-009)
- [X] B1-R1-2 Let a replaced goal event land in `_write_events` in `backend/app/live/apply.py`: `goals` counts stored rows the source no longer lists, so the insert guard refuses the new event and `_event_gone` refuses to delete the old one. At 1–0 a replaced goal never changes, and at 2–0 the timeline shows the first goal twice and leaves out the second. Goal.com's event ID hashes the minute and scorer, so filling in a scorer is enough to cause this. After the fix, a missing goal whose hold has passed goes when the goals the source still lists for that side already cover the accepted score, and its replacement lands in the same poll, so the two never show together. A goal missing with nothing to replace it still stays with the score. Add tests that fail before the fix: the same score with a changed ID, and the 2–0 case. (HIGH, per FR-011, FR-017, T018)
- [X] B1-R1-3 Stop reading a source that blocks the capture in `backend/app/live/capture.py`: `_save_page` treats a 403 or 429 like any other error, and `_watch_round` counts only list failures, so a blocked source gets up to 13 more requests every round for hours, with no alert if only its match pages are refused. After the fix, a 403 or 429 on any page ends that source's round and tells the owner at once, and if the next round is refused too, the capture sends that source nothing more until it's restarted. A 5xx, a dropped connection and an empty bucket stay logged failures, and the other sources carry on. Update the capture's alert table in `docs/runbooks/live-poller.md`. Add a test that fails before the fix. (HIGH, per US4 scenario 2, constitution VII, T022)
- [X] B1-R1-4 Make the capture's errors reach a log that outlasts it, in `cmd_capture_live` in `backend/app/cli.py` and the capture command in `docs/runbooks/live-poller.md` and `specs/031-d05-live-sources/quickstart.md`: `setup_logging` only runs on Celery's signal, so `capture-live` prints a bare `capture_failed` with no `page` or `why`, and `--rm` then deletes the container's log when it ends, so T028 can't report each source's errors. After the fix, `cmd_capture_live` calls `setup_logging()`, the command has no `--rm`, and the runbook says to run `docker rm madar-capture` after the report and before a new capture, with its `docker ps -a` row corrected. Add a test on the real entry point that fails before the fix: a failed page's `page` and `why` reach the output. (HIGH, per FR-020, US4 scenario 3, T022)
- [X] B1-R1-5 Restore the three deleted problem tests in `backend/tests/live/test_apply.py`: `test_a_problem_alerts_once_while_open_and_once_on_recovery`, `test_the_alert_text_names_the_saved_page` and `test_closing_a_problem_that_never_opened_says_nothing`, from 7c1d1b7. No rule change explains their removal, and without them no test re-opens a problem (`problems.py` branch `61->63` is never taken). Remove the stray `close_problem` assertion at line 609, and add one open, close and re-open case for `unknown_status:` and for `stuck:`. Check that the branch is now covered, and that removing the re-open path fails a test. (HIGH, per the review checklist on deleted tests, FR-006)

### Review fixes (round 2)

These come from [reviews/b1-round-2.md](reviews/b1-round-2.md), which has the evidence.

- [X] B1-R2-1 Stop a lone full time finishing a match another source may still be playing, in `_fulltime_step` in `backend/app/live/crosscheck.py`: its guard looks for `extra_time` or `penalties`, which no parser produces, and it reads only `known`, which leaves out rows with an unknown status. So FilGoal on `finished` at 1–1 and Goal.com on an unmapped `LIVE/EXTRA_TIME_FIRST_HALF` finish the match at minute 10, polling ends, and extra time and the shoot-out are lost. After the fix, a valid `unknown_status` reading from any source other than `fulltime_source` clears the lone hold, like the "extra time or penalties" row, and the 10 minutes start again. Two sources showing full time still finish the match, and + 210 still bounds it. Change the full-time table in `contracts/live-rules.md`, SD §6.7's row and the Full time section of `docs/runbooks/live-poller.md` with it (FR-025). Add a `decide` test that fails before the fix, through the minute-10 case above, and one showing two full times still finish with an unknown row present. (HIGH, per FR-008, the edge case "A source shows full time before extra time", constitution II)

---

## Lane B2

**Goal:** Goal.com has a rate limit, the new settings reach the live worker, and the capture can run on VPS-2.

**Independent test:** a unit test of the new bucket, then `capture-live` starts on VPS-2 and saves one round from all three sources.

- [X] T030 [P] [US3] In `backend/tests/adapters/`, test that `www.goal.com` has its own bucket and shares none with the other hosts. Then add `GOAL_BUCKET` to `backend/app/adapters/ratelimit.py`, sized for one list page and `LIVE_PAGE_CAP_GOAL` pages a minute with room for retries.
- [X] T031 [US3] Confirm that host checks and the fetcher accept `www.goal.com` by `allowed_hosts`, and that a dropped connection (`http.client.IncompleteRead`) comes out of `backend/app/adapters/fetcher.py` as a `FetchError` or `Retryable`, not raw, with a test in `backend/tests/adapters/`. T021 relies on it.
- [X] T032 [P] [US3] Add `LIVE_GOAL_ENABLED` and `LIVE_PAGE_CAP_GOAL` to `infra/compose/example.env` and the settings table in `infra/README.md`, and remove `LIVE_CONFIRM_WAIT_S` if listed. List the timers T028 may change too: `LIVE_DROP_HOLD_S`, `LIVE_DISAGREE_AFTER_S`, `LIVE_FULLTIME_HOLD_S`, `LIVE_STUCK_AFTER_MIN` and `LIVE_STUCK_QUIET_MIN`. Confirm that `worker-live` and `maintenance` in `infra/compose/vps2.yml` receive all of them (FR-021), since the watchdog reads the stuck settings. Any `check_env` step must pass with them unset.
- [X] T033 [US4] Check that `capture-live` can run on VPS-2 through `infra/compose/vps2.yml` with `/srv/raw` writable, Redis reachable for its heartbeat, the Telegram settings present and `SCRAPE_USER_AGENT` set. Give B1 the exact command for the runbook, and add disk use for 240 minutes of capture to its section. Checked 2026-11-05 from outside the host. The `.env` and Redis check on the host needs the deploy user, so it's an owner item in `docs/owner-actions.md`.
- [X] T034 [US4] Add this spec's Lane B2 items to `docs/owner-actions.md`, if any need the owner.

---

## Done check

- [ ] DC1 Owner: `pytest tests/live/test_replay.py` passes, the capture report from VPS-2 exists, and on a watched match with all three sources, status, minute and score match the broadcast from kickoff to full time, apart from FR-008's wait for full time.
