# Implementation review: 005-d05-live-and-discovery, lane A, round 1

- Date: 2026-11-04 · Reviewer: Claude Code (claude-opus-5-5), layer review by a Sonnet subagent, every HIGH re-checked on Opus
- Branch: d05-a · Base: 2be5f31 (the lane's own parent) · Head: 63d7482, plus 0 uncommitted files
- Change: 1 commit, 25 files (0 in another lane's folders), +2613 −61
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 3 · MEDIUM 8 · LOW 5

## Checks

| Check | Command | Result |
| --- | --- | --- |
| Types | `pnpm typecheck` | exit 0 |
| Lint | `pnpm lint` | exit 0 |
| Unit | `pnpm test` | exit 0, 272 passed. A first run under heavy load hit a 5 s timeout in `ChannelsPage.test.tsx:175`, a file this change doesn't touch |
| Build | `pnpm build` | exit 0 |
| Literals, tokens | `./scripts/check-literals.sh`, `./scripts/check-token-copy.sh` | exit 0 |
| E2E | `pnpm e2e` | exit 0, 4 passed. `e2e/smoke.spec.ts` visits no D5 route |
| Client current | `pnpm orval` on a clean export of a9b4bed | exit 0, no diff |
| Coverage ≥ 80 % | none | NOT RUN: `pnpm test` doesn't collect it |
| PR #37 CI | `gh pr view 37` | green |
| Bypass scan | diff searched for eslint-disable, ts-expect-error, skip, only | none |

## Findings

### HIGH

#### A-R1-1: A9 has no logo field

- ui · FR-032, US4 scenario 4, PB A9 ("name, logo, …"), `contracts/admin-api.md` (`logo_asset_id`) · `admin/src/features/rights/RightsHolderEditor.tsx` · CONFIRMED (grep: `logo` appears only on the list page)
- Failure scenario: an editor can't set or change a rights holder's logo, though the API takes one.
- Fix direction: add the logo field the way the competition and team editors do, sending `logo_asset_id`.

#### A-R1-2: the editor forces each carriage to one satellite, and saving drops the others

- ui · FR-032, PB A9 ("satellites multi-select"), base schema `rights_holder_carriage_satellites` · `admin/src/features/rights/RightsHolderEditor.tsx:59-61,83,106` · CONFIRMED (read). The comment at `:50` credits `admin-api §A9` with "names one satellite", and the contract has no such rule: its example only happens to list one.
- Failure scenario: a migrated holder has a carriage on two satellites. An editor fixes the name and saves. `draftOf` kept only the first id and `PATCH` replaces carriages whole, so the second satellite is gone. A carriage with no satellite can't be saved at all, which blocks any edit to that holder.
- Fix direction: a multi-select per carriage, carrying every id, and allowing zero.

#### A-R1-3: a stale save on A9 doesn't show the conflict state

- ui · US4 scenario 5 ("A stale save shows the existing conflict state"), constitution VI · `admin/src/features/rights/RightsHolderEditor.tsx:193-196`, `admin/src/features/rights/RightsHoldersPage.tsx:66-69` · CONFIRMED (read). `TeamEditor.tsx:225,327` is the pattern to follow.
- Failure scenario: two editors open one holder. The second's save gets `409 edit_conflict` and only a message line. There's no `ConflictDialog` and no refetch, so pressing Save again resends the same stale tag. A stale reorder only shows a toast, where Competitions opens the dialog.
- Fix direction: use `ConflictDialog` in both places, as `TeamEditor` does. Test that `If-Match` equals the detail's ETag and that the dialog opens.

### MEDIUM

- **A-R1-4** · `admin/src/features/sources/SourceRunPage.tsx:359,363`, `backend/app/adapters/tasks.py:554-571` · CONFIRMED. The page reads `errors` and `skipped_channels`, while D5's log writes `error` and `skipped: {count, items}`. The errors list is always empty and skipped is always «—». `detail.error` at `:311` still shows the one run error, so failures aren't hidden, which keeps this below HIGH (FR-031).
- **A-R1-5** · `SourceRunPage.tsx:58-93` · CONFIRMED. `stagesOf` reads only `log.counts`, so a run with no counts shows fetch as done and the rest «لم يبدأ». Use `items_found`, `items_upserted` and `http_errors` from the run.
- **A-R1-6** · `admin/src/features/unresolved/CreateFromName.tsx:32` · CONFIRMED. Always sends `scope_to_competition: false`. Creating a team whose name another team has gets `422 scope_required`: the team exists, the row stays open, and the new team may not be among the 3 suggestions.
- **A-R1-7** · `admin/src/features/unresolved/UnresolvedQueue.tsx:193,273-290` · CONFIRMED. Filter options come from the visible rows, so clearing a source's last row leaves a value with no option. `cursor` is never advanced, so with `limit: 50`, an `open_count` of 300 can only be worked 50 at a time.
- **A-R1-8** · `UnresolvedQueue.tsx:91-96`, `CreateFromName.tsx:374-377` · PLAUSIBLE. On `edit_conflict` the dialog keeps its row and tag until the 30 s poll, so a retry resends the stale tag.
- **A-R1-9** · `admin/src/features/sources/SourcesPage.tsx:78-125` · CONFIRMED. A paused Live poller shows a healthy chip and no paused marker, though pausing moves live matches to the estimate.
- **A-R1-10** · `RightsHolderEditor.tsx:142-152` · PLAUSIBLE. The comment says the form seeds once per opening, but the effect depends on `holder`, and `structuralSharing: false` makes each refetch a new object, so a background refetch can wipe typing. There's also no unsaved-changes guard (PB §10, line 553) and no detail loading or error state.
- **A-R1-11** · tests · CONFIRMED. T069's `SourceRunPage.test.tsx` doesn't exist; its cases are in `SourcesPage.test.tsx`, with no raw-page timeout or stop-after-10-polls test at component level, and `:319` (`calls >= 3`) would pass if polling never stopped. T072 has no `PATCH` success path. T065's keyboard-focus test asserts class names only. `CreateFromName.test.tsx:189-190` can't fail.

### LOW

- **A-R1-12** · `SourceRunPage.tsx:161-164`: a pending-then-error sequence can poll past the 10 s window.
- **A-R1-13** · `RightsHolderEditor.tsx` frequency rows: a blank MHz becomes 0, and the server's 422 has no per-field error.
- **A-R1-14** · `UnresolvedQueue.tsx:71`: in the picker case the first candidate is preselected. Nothing is written before Save, so the rule holds.
- **A-R1-15** · `UnresolvedQueue.tsx:241`, `ar.ts:748`: «اختر الفريق» shows on channel and competition rows.
- **A-R1-16** · `ar.ts:862`: `unresolved_name_not_found` and `rights_holder_not_found` use the generic copy, and several keys are unused.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US4-1 queue rows, picker | `UnresolvedQueue.tsx` | `UnresolvedQueue.test.tsx` | Done, except A-R1-7 |
| US4-2 map, create, ignore | `UnresolvedQueue.tsx`, `CreateFromName.tsx` | both test files | Partial: A-R1-6 |
| US4-3 run detail, inert raw page | `SourceRunPage.tsx` | `SourcesPage.test.tsx` | Raw page done; A-R1-4, A-R1-5 |
| US4-4 A9 editor, drag | `RightsHoldersPage.tsx`, `RightsHolderEditor.tsx` | `RightsHoldersPage.test.tsx` | **Partial: A-R1-1, A-R1-2** |
| US4-5 `If-Match`, conflict | same | same | **Partial: A-R1-3** |
| US4-6 boards, states | all | tests; no screenshots | T076 open |
| FR-030 Live poller card | `SourcesPage.tsx` | `SourcesPage.test.tsx` | Done, except A-R1-9 |
| FR-033 generated only, tokens | all | literals and token checks | Done |
| SC-007 under a minute | none | none | T076 open |

## Task audit

Ticked 14, verified 11, not done 0, partly done 3.

| Task | Ticked | Finding |
| --- | --- | --- |
| T069 | yes | No `SourceRunPage.test.tsx`, and no timeout test (A-R1-11) |
| T072 | yes | No proof of `If-Match` (A-R1-3, A-R1-11) |
| T074 | yes | No logo, one satellite (A-R1-1, A-R1-2) |

## Owner must review

- A13 queue, run detail and A9 next to `Sources.png`, its run-detail board and `Rights.png`, at 1440 and 1024 in both themes (T076, no screenshots yet).

## Outside this change

- none

## Not reviewed

- The screens against their boards in a browser: no screenshots exist yet (T076), so visuals weren't judged here.
- The walk over WireGuard.
