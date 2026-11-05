# Implementation review: 005-d05-live-and-discovery, lane B2, round 1

- Date: 2026-11-04 · Reviewer: Claude Code (claude-opus-5-5), layer review by a Sonnet subagent, every HIGH re-checked on Opus
- Branch: d05-b2 · Base: 0847dff (the lane's own parent) · Head: e598d6d, plus 0 uncommitted files. Tests ran at the merged head, because the lane branch has no `0007` (T046)
- Change: 1 commit, 48 files (0 in another lane's folders), +13248 −87
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 3 · MEDIUM 6 · LOW 2

## Checks

| Check | Command | Result |
| --- | --- | --- |
| ruff, mypy | `uv run ruff check .`, `uv run mypy --strict app`, at bccbf7a | exit 0 |
| pytest | `uv run pytest --cov` on throwaway `postgres:16.15` and `redis:7.4.12`, at bccbf7a | **exit 1: 1 failed**, `tests/adapters/test_schedule_fetch.py:210`. Every other adapter test passes |
| Coverage | same run | `yallakora.py` 98 %, `unresolved.py` 100 %, `resolve.py` 97 %, `raw_store.py` 94 % |
| PR #35 CI | `gh pr view 35` | `test` failed with 90 failures at merge, because the tables weren't there yet (the lane's Notes say so). T046's re-run is the check above |
| Layout change on a real page | `parse` on `tests/fixtures/yallakora/2026-11-04.html` with `matchesList` renamed | **returned 0 items, no `LayoutChanged`** (B2-R1-2) |
| Compose and CI expectations | `docker compose config` with `infra.yml`'s jq and grep checks (by the subagent) | pass |
| Bypass scan | diff searched for skip, xfail, noqa, type: ignore | No skips; `type: ignore[import-untyped]` for lxml as elsewhere, and one `[arg-type]` in a test |

## Findings

### HIGH

#### B2-R1-1: the importer links on text alone, against FR-022a, and the poller trusts that link

- pipelines · FR-022a, R7, constitution II · `backend/app/adapters/upsert.py:351-364`, `backend/app/live/links.py:53-57` · CONFIRMED (read)
- Problem: if either team is unresolved, `_duplicate_probe` matches on normalized text and `match_date`, with no kickoff check, and takes the first of however many rows match. YallaKora then writes its `liveScoreMatchId` to that row, and `link_reading` returns a known id with no further check.
- Failure scenario: «الأهلي» v «الاتحاد» on one date exists in both Egypt and Saudi Arabia. The name is shared and unresolved, so YallaKora's id lands on the wrong match. That row gets the wrong broadcaster, and if FilGoal doesn't cover it, two polls publish the other match's score. Plan and research chose both-teams-plus-kickoff linking for exactly this reason.
- Fix direction: for `yallakora`, link only with both teams resolved, within 45 min, and exactly one candidate. Otherwise don't write an external id. Also check other importers' behaviour stays as is. Add the same-name, same-date test.

#### B2-R1-2: a layout change on a real page isn't detected as one

- pipelines · T049 ("a page with no match list raises `LayoutChanged`"), US3 scenario 6, constitution VII · `backend/app/adapters/yallakora.py:134-137` · CONFIRMED (ran it)
- Problem: `NO_MATCHES_TEXT` also sits in a hidden `<div id="noLiveMatch" style="display:none">` on pages that have matches (`2026-11-04.html:1352`), so the check is true for nearly any real page.
- Failure scenario: YallaKora renames `matchesList`. `parse` returns `[]`, and the run is `succeeded`, not `layout_changed`. Only the generic zero-items alarm is left, reading as a quiet day. T049's test passes because its page was made by hand.
- Fix direction: detect the real empty-day element (`.noStats` / `.noStatsDiv`, as in `2027-07-21.html`). Add a test that renames the class on a real saved page.

#### B2-R1-3: `test_schedule_fetch.py` fails on the merged head

- tests · Quality gates · `backend/tests/adapters/test_schedule_fetch.py:210` · CONFIRMED
- Problem: `assert len(loaded) == len(BEAT_SCHEDULE) + len(NOTIFY_SCHEDULE)` gives 19 against 15 now that `app.live.schedule` exists. B1 caused it, but the file is B2's. It blocks `build` on `master`.
- Fix direction: rebase on the spec branch (T046), and include `app.live.schedule` in the count and the disjointness checks.

### MEDIUM

- **B2-R1-4** · `backend/app/adapters/upsert.py:432-436` · PLAUSIBLE. Freezing depends only on `match.source != "yallakora"`. A YallaKora-created row adopted by ysscores keeps that source, so the two importers rewrite each other, bumping `matches` and `live` and staling open editors, the very thing the comment avoids.
- **B2-R1-5** · `backend/app/adapters/yallakora.py:135`, `backend/app/adapters/health.py:126` · CONFIRMED in code. A real empty day counts as zero items with one page, so it's a failure. Three such runs open the breaker, and the source stays paused until someone resumes it. The runbook calls this rare. `2027-07-21.html` is a future date, so how often it happens is unknown. Treat a recognised empty day as a success.
- **B2-R1-6** · `backend/app/adapters/upsert.py:351` · CONFIRMED. Both teams resolved with `kickoff_at=None` skips every probe branch, so a postponed card first seen by YallaKora creates a duplicate match. Probe on the date and teams.
- **B2-R1-7** · `backend/app/adapters/yallakora.py:181`, `backend/app/services/match_detail.py:255` · CONFIRMED. `local_broadcaster_eg` reaches `/v1` with no `find_card_sharing_label` check (`backend/CLAUDE.md` content rule, O3). Saved pages show plain broadcaster names, so the path is unlikely, but the check is one line. Same for the stage and competition text.
- **B2-R1-8** · `docs/runbooks/README.md:101`, `deploy-and-rollback.md:151`, `secrets.md:148` · CONFIRMED. These still say VPS-2 has "four services", and `deploy.sh` now starts seven.
- **B2-R1-9** · `docs/owner-actions.md` · CONFIRMED. D5's row still lists T001, the shared-parts PR and B1's contract as "before merge", though all are overtaken. Bring it up to date.

### LOW

- **B2-R1-10** · `backend/app/adapters/resolve.py`: `resolve_channel` has no production caller; the poller and LiveSoccerTV use their own alias queries.
- **B2-R1-11** · T049's note: pages came from the owner's laptop. Re-save one from VPS-2 during T060, as already noted.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US3-1 schedule, run row | `schedule.py`, `tasks.py` | `test_schedule.py`, `test_yallakora_ingest.py` | Done; live run is T060 |
| US3-2 pure parser, Cairo time, broadcaster | `yallakora.py`, `upsert.py` | `test_yallakora.py`, `test_upsert.py` | Done |
| US3-3 alias used | `resolve.py` | `test_resolve.py` | Done |
| US3-4 queue, no entity | `unresolved.py`, `upsert.py` | `test_unresolved.py`, `test_yallakora_ingest.py` | Done |
| US3-5 repeat, ignored | `unresolved.py` | `test_unresolved.py` | Done |
| US3-6 block or layout change | `yallakora.py`, shared fetcher | `test_yallakora.py` | **Partial: B2-R1-2** |
| FR-022a link rule | `upsert.py` | none for the text path | **Broken: B2-R1-1** |
| FR-023 locks, upsert | `upsert.py` | `test_upsert.py` | Done |
| SC-006 live run | none | none | T060 open (needs a deploy) |

## Task audit

Ticked 14, verified 13, not done 0, partly done 1.

| Task | Ticked | Finding |
| --- | --- | --- |
| T049 | yes | The no-match-list case doesn't raise on a real page (B2-R1-2) |
| T043 | no | Code is present (`vps2.yml`, `deploy.sh`, `infra.yml`, runbooks); only the deploy is left |
| T045 | no | Real code, not stubs, merged. The early PR is moot now |
| T046 | no | The precondition holds on the spec branch. The re-run passes except B2-R1-3 |
| T047 | no | Steps are present; SD §2 and §7.1 wait on the owner's T048 |

## Owner must review

- `backend/app/adapters/upsert.py`: `_duplicate_probe` and `_fields_are_frozen` (B2-R1-1, B2-R1-4).
- `infra/compose/vps1.yml`, `vps2.yml`, `infra/scripts/deploy.sh`: `API_PUBLIC_WORKERS` and `worker-live`.

## Outside this change

- The lane branch is behind the spec branch and lacks `0007`. Rebase first for any fix.

## Not reviewed

- T060 and anything on the live host. The DB-backed tests ran at the merged head, not on `d05-b2`.

## After the review

- **B2-R1-12** (HIGH, added 2026-11-05): the owner settled B1-R1-7 with a one-rule `oasdiff` exception. `.github/` is B2's, so the change is B2's task.
