# Implementation review: 031-d05-live-sources, lane B1, round 2

- Date: 2026-11-05 · Reviewer: Claude Code, Opus 5.5, with five Sonnet review agents whose findings were re-checked here
- Branch: d05-b1 · Base: 7c1d1b7 (merge base 7c1d1b7) · Head: d0717a3, plus 0 uncommitted files
- Change: 1 commit, 59 files (0 in another lane's folders), +6589 −1175
- Verdict: CHANGES REQUESTED · CRITICAL 0 · HIGH 1 · MEDIUM 1 · LOW 7 (new this round; the notes still open from round 1 are under [Previous round](#previous-round))

All five of round 1's fix tasks hold, including the CRITICAL. The one HIGH below is new: the same kind of gap as B1-R1-1, in the full-time rule instead of the stuck rule.

## Checks

Run from `backend/` in `madar-b1`, with `TEST_DATABASE_URL` and `TEST_REDIS_URL` pointed at the dev stack.

| Check | Command | Result |
| --- | --- | --- |
| Lint | `uv run ruff check .` | Exit 0 |
| Format (not in CI) | `uv run ruff format --check .` | Exit 0 |
| Types | `uv run mypy --strict --explicit-package-bases app` | Exit 0, 172 files. The flag is local only: plain `mypy --strict app` printed "saied-dev contains `__init__.py`" and exit 2 on one run, because `/mnt/endeavour/home/saied-dev/__init__.py` exists outside the repo. CI's command isn't affected |
| Tests and coverage | `uv run pytest -p no:cacheprovider --tb=line -q --no-header --cov --cov-branch --cov-report=term` | Exit 1: 2259 passed, 4 failed. Total 94%, `app/live` 94–100% per file, against CI's bar of 70 and the constitution's 80. All 4 are in `tests/adapters/test_homebox_acl.py` (see [Outside this change](#outside-this-change)) |
| Contract | `uv run python -m app.cli export-openapi && git diff --exit-code openapi/`, with `backend.yml`'s environment | Exit 0 |
| Models and migrations | A scratch database: `alembic upgrade head`, then `compare_metadata` | Head `0008`. 84 differences, the same count as round 1, and none mentions a name this change added |
| B1 and B2 merged | The whole suite, `ruff` and `mypy` on `005-d05-live-and-discovery` with `d05-b2` merged | Same 4 failures only. Ruff and mypy exit 0 |
| The lone full time, through the real `decide` | A scratch harness | A match finishes at minute 10 while another source reads an unmapped status ([B1-R2-1](#b1-r2-1-a-lone-full-time-finishes-a-match-another-source-may-still-be-playing)) |
| Bad paths, through the real `HttpFetcher` | A scratch script with a mock transport | `:abc/x` and a path with a newline raise `httpx.InvalidURL`, which `FetchError`, `Retryable` and `httpx.HTTPError` don't cover ([B1-R2-2](#b1-r2-2-one-page-derived-path-can-stop-the-whole-poll)) |
| Mutants | 14 one-line changes in a scratch copy, then the tests named in Previous round. Baseline green | 5 of 5 on round 1's fixes caught. 8 of 9 others survive: see B1-R1-14 |
| Runbook literals (from the repo root) | `infra/scripts/check-doc-commands.sh` | Exit 0. It doesn't look at `live-poller.md`, so it says nothing about B1-R1-11 |
| Secrets | `gitleaks` | NOT RUN: not installed here. CI runs it. A reviewer searched the added lines and found none |
| The rest of `infra.yml` | Its other steps | NOT RUN: nothing under `infra/` or `.github/` changed in this lane |
| Generated clients | Regenerate Dart and TS | NOT RUN: the OpenAPI files didn't change |
| Image build | `docker build` | NOT RUN: no Dockerfile or dependency changed |

**Ways around the checks.** No `skip` or `xfail`, and no change to `pyproject.toml`, `uv.lock`, `.github/` or `alembic.ini`. Suppressions are as in round 1. Two tests that round 1 didn't list were deleted with no replacement: see B1-R1-14.

## Previous round

The round 1 fixes were re-read. B1-R1-1 to B1-R1-3 were also mutated, to see that a test catches their removal.

| Finding | Now |
| --- | --- |
| B1-R1-1 CRITICAL, extra time or a shoot-out finished at + 150 | **Fixed.** `watchdog.py:46-58`. Removing the clause fails `test_a_quiet_cup_match_on_a_status_no_parser_knows_waits_for_the_hard_limit` |
| B1-R1-2 HIGH, a replaced goal | **Fixed.** `apply.py:203-250`. Both mutants fail `test_a_goal_whose_id_changes_at_the_same_score_is_replaced_in_one_poll` or `test_a_replaced_goal_is_not_shown_alongside_its_replacement_at_two_nil` |
| B1-R1-3 HIGH, the capture keeps reading a block | **Fixed.** `capture.py:97-111`, `:163-176`. The mutant fails `test_a_refused_match_page_ends_that_sources_round_and_tells_the_owner_at_once` |
| B1-R1-4 HIGH, the capture's errors never logged | **Fixed.** `cli.py:122`, and the runbook has no `--rm` |
| B1-R1-5 HIGH, deleted problem tests | **Fixed.** The three are back, and `problems.py` is at 100% with branches |
| B1-R1-6 MEDIUM, shared buckets, slow rounds | Still open. One more effect, PLAUSIBLE: `_beat` runs only before each source (`capture.py:238`), so one source's pages under a contended bucket can pass the 5-minute heartbeat and raise a false "capture stopped" |
| B1-R1-7 MEDIUM, page data as a URL path | Still open. Its worse failure is now B1-R2-2 |
| B1-R1-8 MEDIUM, score and shirt-number ranges | Still open (`goal.py:72-80`, `:215`; `filgoal.py:157-168`, `:214`). A non-numeric shirt number is still PLAUSIBLE. It fails `/v1/matches/{id}` for that match, through `match_detail.py:283` and `schemas/public.py:233` |
| B1-R1-9 MEDIUM, one bad row on Goal.com's list | Still open (`goal.py:156-160`) |
| B1-R1-10 MEDIUM, rolling back after Goal.com has rows | Still open: no rollback step in the runbooks |
| B1-R1-11 MEDIUM, `psql` blocks on the wrong host | Still open (`live-poller.md:109-130`, `:144-176`). This is the removal path if the approval ends. The `dc exec redis` line at `:109-123` has the same problem |
| B1-R1-12 MEDIUM, the off switch and a running capture | Still open (`live-poller.md:152`) |
| B1-R1-13 MEDIUM, `owner-actions.md` | Partly fixed by the merge of B2, which corrected row 031's state. Still open: the dead `#a-held-final-score` link at `:543` and its rule, the `0008` review under "After merge" against T017, and no before and after split |
| B1-R1-14 MEDIUM, unpinned boundaries | Partly fixed. `known = list(readings)` is now caught. Still surviving when run: `_same` ignoring penalties, `_covers` ignoring away penalties, `MINUTE_SLACK = 20`, the minute falling through to no minute instead of the next source, `FULL_MATCH_MINUTES = 80`, the + 210 finish ignoring a locked status, and `goal_enabled` or `hard_limit_min` defaults changed. The code is right in each. `test_penalties_both_sources_carry_are_still_compared` and `test_penalties_one_source_carries_need_two_polls_and_never_become_a_disagreement` were deleted from `test_crosscheck.py` with no replacement, which is why the penalty mutants survive. T010 asks for these cases |
| B1-R1-15 MEDIUM, B2's bucket merges first | No longer applies to the merge: `d05-b2` is merged into `005-d05-live-and-discovery` as `3fc8a4e`, so `www.goal.com` has `GOAL_BUCKET` there. `d05-b1` itself still has none, so don't deploy it alone. No test ties `ROBOTS_COPIES` to `DEFAULT_LIMITS` yet |
| B1-R1-16 to B1-R1-20, B1-R1-23, B1-R1-24, LOW | Still open, no code change. B1-R1-16 was re-run: `disagree:1` opens at minute 10 with one reading |
| B1-R1-21 LOW, the one-source choice | Still open, with a sharper case: a FilGoal row of any type wins, so a red card alone hides the goal Goal.com stored and the timeline can miss a goal beside its score. It follows R9's wording, so the owner decides, with T028's data |
| B1-R1-22 LOW, document drift | Still open. See also B1-R2-9 |

## Findings

### CRITICAL

None.

### HIGH

#### B1-R2-1: A lone full time finishes a match another source may still be playing

- Layer: pipelines · Source: FR-008, the spec's edge case "A source shows full time before extra time" (`spec.md:133`), constitution II and VII · Location: `backend/app/live/crosscheck.py:30`, `:267-279`, `:328`; `contracts/live-rules.md:73`, `:77` · CONFIRMED by a run
- Problem: the guard is `any(reading.status in EXTRA_STATUSES for reading in known)`, and it can't fire on real data. No parser maps a wording to `extra_time` or `penalties`, because the first capture saw none, and rows with an unknown status are left out of `known`. An unknown row only clears the hold if it comes from `fulltime_source` itself, which is the contract's row at `:77`, so the contract has this gap too. B1-R1-1's fix taught `watchdog.py:46-58` to read the same kind of row as "may still be on", and the full-time rule never got the same treatment.
- Failure scenario, from the run with the real `decide`: FilGoal reads `finished` at 1–1. Goal.com reads `LIVE/EXTRA_TIME_FIRST_HALF`, which no map holds, also 1–1. At minute 5 the match is `live`, and at minute 10 it's `finished`. Polling ends there, so extra-time goals and the shoot-out are never read, and only a person can undo a false final result. It needs one source to stay on full time for 10 minutes while another has moved on, which is less common than B1-R1-1's path, hence HIGH. But it's the exact case the spec's edge case says stays open, and the first cup night is when it would happen.
- Fix direction: until a parser maps extra time, treat a valid `unknown_status` reading from any source other than `fulltime_source` like the "extra time or penalties" row, so it clears the lone hold. + 210 still bounds the match, and two sources showing full time still finish it. Change the contract's table, SD §6.7's row and the runbook with it (FR-025).

### MEDIUM

#### B1-R2-2: One page-derived path can stop the whole poll

- Layer: pipelines, security · Source: FR-013 ("a failure stops only this source"), constitution VII, spec 005 research R4 · Location: `backend/app/live/cycle.py:209-213`, `:284`, `:293`, `:584`, `:541-544`; `backend/app/live/capture.py:137`; `backend/app/live/sources/yallakora.py:111`, `goal.py:48`, `filgoal.py:62-63` · CONFIRMED by a run for the exceptions, and by reading for what follows
- Problem: this is B1-R1-7's worse case. `_read_pages` catches `(FetchError, httpx.HTTPError)`, and `httpx.InvalidURL` is neither. `urlsplit` raising `ValueError` on `//[x/y` isn't caught at `cycle.py:284` either, and `capture.py:137` makes that call outside any `try`.
- Failure scenario: a linked list row carries an href of `:abc/x`, or a control character in a path. `_read_pages` raises through `_poll`, before any match is applied, `run_cycle` re-raises, and `live.poll` has `max_retries=0`. This repeats every minute while the row is on the page, so no source updates any match. After 5 minutes the watchdog moves first-half rows to the clock estimate. In the capture, the same row ends the run, which costs the match night.
- Fix direction: B1-R1-7's path check, and treat `httpx.InvalidURL` and `ValueError` as a failed page in `_read_list`, `_read_pages` and `capture_source`.

### LOW

#### B1-R2-3: Cancelled and abandoned wait for the full-time score check

- Layer: spec · Source: `contracts/live-rules.md`'s status table · Location: `backend/app/live/crosscheck.py:285-286`, `:349-358` · CONFIRMED by reading
- Problem: `_closing` returns these from the first usable source, and `decide` then runs the score wait on them, which the contract only puts under full time.
- Failure scenario: FilGoal says `abandoned` at 1–0 and YallaKora shows 0–0. It's held 5 minutes, then written with a `disagree:` alert.
- Fix direction: skip the wait when the closing status isn't `finished`, or record the choice in the contract.

#### B1-R2-4: `capture-live` isn't in `backend/CLAUDE.md`'s CLI list

- Layer: ops · Source: review checklist 4.J · Location: `backend/CLAUDE.md:121-131`, `:104` · CONFIRMED by reading
- Problem: only a passing mention at `:104` names it, and its `--minutes` and `--page-cap` flags aren't listed.
- Failure scenario: an agent working from that file doesn't find the command.
- Fix direction: add a line that points to `docs/runbooks/live-poller.md#the-capture`.

#### B1-R2-5: The hard-limit setting and the poll window can disagree

- Layer: pipelines · Source: FR-023, FR-025 (the report may change the timers) · Location: `backend/app/live/config.py:30`, `backend/app/services/live.py:18` · CONFIRMED by reading
- Problem: `LIVE_HARD_LIMIT_MIN` is only `ge=1`, and `FEED_WINDOW_BEFORE` stays at 210. Nothing checks `stuck_after < hard_limit`.
- Failure scenario: at 240, a stuck row between + 210 and + 240 stays `live` while nothing polls it and `/v1/live` doesn't list it.
- Fix direction: derive the window from the setting, or validate the range at startup.

#### B1-R2-6: The capture takes its pages in list order

- Layer: pipelines · Source: SC-007, T020 · Location: `backend/app/live/capture.py:132` · CONFIRMED by reading
- Problem: `[:page_cap]` is always the first rows of the list.
- Failure scenario: on a 16-match night with a cap of 12, a match late in the list gets no pages from any source, which is how the first capture lost Mouloudia (R13).
- Fix direction: rotate across rounds, or take an optional match list.

#### B1-R2-7: A malformed `LIVE_*` value fails at task time, with no alert

- Layer: ops · Source: review checklist 4.B ("validated at startup") · Location: `backend/app/live/config.py:61-63`, `backend/app/live/tasks.py:99` · CONFIRMED by reading
- Problem: `LiveSettings` is built inside the tasks, not at worker start.
- Failure scenario: `LIVE_GOAL_ENABLED=disable` makes the scheduler and the watchdog raise on every tick, and only the Kuma heartbeat says so.
- Fix direction: read the settings once at worker start.

#### B1-R2-8: `0008` takes its table locks before it needs `matches` and `sources`

- Layer: db · Source: review checklist 4.C · Location: `backend/alembic/versions/0008_live_sources.py:40-55` · PLAUSIBLE: only a deploy under load would show it
- Problem: the `ALTER TABLE`s take exclusive locks that last until commit, and then `CREATE TABLE match_stats` needs a lock on `matches` and `sources`.
- Failure scenario: an importer write holds `matches` during the deploy, and reads of `match_events` queue behind the migration. It fails safe, as a stopped deploy. `0007` did worse (`ALTER TABLE matches`).
- Fix direction: create the table first, or set a `lock_timeout`.

#### B1-R2-9: More document drift

- Layer: ops · Source: root `CLAUDE.md`, Runbooks · Location: as listed · CONFIRMED by reading
- Problem:
  - `docs/system-design.md:507` says every response is checked for "known status values", and that a failure stops the source. FR-001 removed that.
  - `specs/005-d05-live-and-discovery/quickstart.md:14-15` still runs `capture-live --filgoal <id> --yallakora <match-path>`, flags that are gone.
  - `docs/runbooks/live-poller.md:223`'s disk figure doesn't count the third source, and B2 added the capture's figure beside it.
- Failure scenario: a reader trusts the older sentence, or runs a command argparse refuses.
- Fix direction: correct each with the next change that touches it.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US1.1, FR-001, SC-003: YallaKora statuses, an unknown one affects its row only | `yallakora.py:33-41`; `cycle.py:254-264`, `:429-438` | `test_the_list_reads_every_status_the_capture_saw`, `test_mubashir_on_a_live_match_page_is_live_with_no_half`, the replay's status maps | Met |
| US1.2, FR-002, SC-004: FilGoal's minute, never negative | `filgoal.py:131-155` | `test_the_minute_handles_both_forms_of_the_clock`, `test_no_minute_is_ever_negative`, the replay (97.9%) | Met |
| FR-003, US2.4: types 4, 20, 9, and an own goal's side | `filgoal.py:54`, `:189-201` | `test_filgoal_parse.py:208-250` | Met |
| US1.3, FR-004, SC-001: a rise in the first poll | `crosscheck.py:131-147` | `test_a_rise_from_any_source_goes_out_at_once`, the replay | Met |
| US1.4, US1.5, FR-005: a drop waits 5 minutes, and the goal leaves | `crosscheck.py:136-147`; `apply.py:203-250` | `test_only_mouloudias_false_score_ever_goes_down`, `test_a_goal_past_what_the_score_needs_goes_at_the_hold` | Met |
| US1.6, FR-006, SC-002: disagreement alerts | `crosscheck.py:331-337` | `test_a_disagreement_alerts_at_ten_minutes`, `test_apply.py:678-716`, the replay | Met, see B1-R1-16 |
| FR-007: status moves | `crosscheck.py:158-228` | `test_a_later_status_goes_out_at_once_from_any_source`, `test_a_backward_status_holds_for_five_minutes` | Met |
| US2.1, FR-008: the full-time rules | `crosscheck.py:258-288`, `:349-358` | `test_crosscheck.py:686-853`, the cycle's hold tests | **Partly met**: [B1-R2-1](#b1-r2-1-a-lone-full-time-finishes-a-match-another-source-may-still-be-playing). The rules run as written, and the guard against extra time can't fire on real readings |
| US2.2: finished stays finished | `crosscheck.py:317` | `test_a_final_status_never_returns` | Met |
| US2.3, FR-009, FR-010, SC-005: stuck matches, the clock guard | `watchdog.py:40-112`; `apply.py:73-95` | `test_watchdog.py:215-560`, `test_apply.py:807-843`, the replay | Met, with B1-R1-14's locked row untested at + 210 |
| FR-011: missing events and replaced goals | `apply.py:203-250` | `test_apply.py:232-382` | Met |
| FR-012: one pure function, the clock only when all enabled sources are down | `crosscheck.py:307-371`; `cycle.py:429-438` | `test_every_enabled_source_must_be_down_before_the_clock` | Met |
| US3.1–US3.3, FR-013–FR-016, SC-006: Goal.com's reader, off switch, names, order | `goal.py`; `cycle.py:556-613`; `robots_check.py` | `test_goal_parse.py`, `test_switched_off_goal_com_gets_no_request_and_writes_nothing`, `test_three_sources_are_read_in_one_cycle_goal_com_last` | **Partly met**: FR-013 by B1-R2-2, B1-R1-8, B1-R1-9. The bucket is B2's and now merged |
| FR-017: minute rules, one events source, one lineup source | `crosscheck.py:231-244`; `apply.py:116-150`, `:277-312`; `match_detail.py:268-282` | `test_crosscheck.py:553-648`, `test_apply.py:398-445`, `test_match_detail_live.py:120`, `:138` | Met, see B1-R1-21 |
| US3.4, FR-018: stats stored, `/v1` unchanged | `0008_live_sources.py`; `apply.py:315-324` | `test_0008_live_sources.py`, `test_apply.py:445`, OpenAPI diff exit 0 | Met |
| FR-019: D6's bar stated | `spec.md`; stored `score_first_source`, `score_changed_at` | `test_crosscheck.py:83` | Met |
| US3.5, FR-014: the off switch and the removal runbook | `live-poller.md`, `owner-actions.md` T002 | docs only | **Partly met**: B1-R1-11, B1-R1-12 |
| US4.1, US4.2, FR-020, FR-021: the capture, its alerts, a block | `capture.py`; `cli.py:109-137`; `tasks.py:136-139` | `test_capture.py` | Met in code, apart from B1-R2-2. The run itself is T026 |
| FR-022: fixtures from the capture | `tests/live/fixtures/` | parse tests. A reviewer compared the real ones with `~/madar-capture/2026-11-04` | Partly: the Goal.com and YallaKora live lists are built and labelled so, and T027 replaces them |
| US4.3, US4.4, FR-023, FR-024, SC-007, SC-008 | none yet | none yet | Not yet: T026–T029, correctly unticked |
| FR-025–FR-028: docs, moved notes, lane boundaries | `owner-actions.md`, runbooks, `specs/005-…/tasks.md` | 0 files in another lane's folders | Met, apart from B1-R1-13 |

## Task audit

Ticked 28, verified 20, not done 0, partly done 8. Unticked and correctly open: T026, T027, T028, T029, T035.

| Task | State | Why |
| --- | --- | --- |
| T010 | Partly done | "1, 2 and 3 sources in every order" isn't met for penalties or the minute's next source (B1-R1-14) |
| T011 | Partly done | SC-003 is only implied through the status maps |
| T012 | Partly done | The contract's full-time table is built, and it doesn't deliver FR-008's guard (B1-R2-1) |
| T013 | Partly done | No upgrade and downgrade "on the snapshot" |
| T014 | Partly done | "`manual` and `locked_fields` win" isn't tested at + 210. The mutant survives |
| T021 | Partly done | The 5-round boundaries aren't pinned |
| T023 | Partly done | B1-R1-11, B1-R1-12 |
| T025 | Partly done | B1-R1-13 |

## Owner must review

- `backend/alembic/versions/0008_live_sources.py` (T017): expand-only, all columns nullable, `match_stats` with `ON DELETE CASCADE`, `sources` gets `('goal', 'internal')`, and what its downgrade deletes. A reviewer found its delete list complete. This is still yours to read before merge, and `owner-actions.md` still shows it as open.

There's no API contract change, auth or permissions code, push audience query or UI screen in this change.

## Outside this change

- `tests/adapters/test_homebox_acl.py`: 4 tests fail on the local Redis with `AuthenticationError`, in this tree and the merged one. It's B2's file, so CI must settle it.
- Autogenerate reports 84 differences at head, the same count as round 1, and no test checks for them.
- Round 1's other notes in this section stand: the page caps mostly out of reach, `cycle.py:237` clearing page strikes, `robots_check.py:31` and `OutOfTokens`, `POST /admin/api/sources/{goal,filgoal}/pause` having no effect, `links.py` trusting a stored link.
- B2-R1-1, now merged: a dropped connection raises `Retryable`, and `cycle.py:228` and `:288` trip the host's backoff for it. The fix needs one line here. See `reviews/b2-round-1.md`.
- `docs/runbooks/database-migrations.md` has no section for `0007`.

## Not reviewed

- Anything on VPS-2 or against the live sites, and T026–T029, T035 and DC1, which need a deploy and match nights. `robots/goal.txt` wasn't compared with the live file.
- `gitleaks`, image builds and client regeneration, as in Checks.
- Mutants beyond the 14 listed. Other "untested" claims in B1-R1-14, such as the capture's 5-round boundary, rest on reading the tests.
