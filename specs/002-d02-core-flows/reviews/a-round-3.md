# Implementation review: 002-d02-core-flows, lane A, round 3

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); a layer subagent on Sonnet, every finding re-checked here
- Branch: `d02-features` (not `d02-a`; the same combined checkout rounds 1 and 2 reviewed) · Base: `origin/master` (merge base `68f1752`) · Head: `635919d`, plus 158 uncommitted files across the four lanes
- Change (lane A, this round): no new commit. The round-2 fixes, uncommitted: 18 hand-written files under `admin/` (`Button`, `ConflictDialog`, `session.ts`, `BulkBar`, `MatchEditor`, `TeamPicker`, `queries.ts`, `editor/{BroadcastSlots,FieldsSection}`, `i18n/ar.ts`, `test/render.tsx`, `vite.config.ts` and their tests), and `docs/runbooks/admin-access.md`. `admin/src/api/generated/*` is Orval output from B1's contract change (matches the generator). Nothing in another lane's folder.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 1 · LOW 8 (1 PLAUSIBLE)

All twelve ticked round-2 fixes are done, and each has a test that fails on revert. The five round-2 HIGHs are gone: the match version survives a refetch, the preset's asset id is sent, the small buttons are 48 px targets with a matching fill, `?mock=` matches path-parameter operations, and the stage presets are offered. One MEDIUM is left: when the refetch after a `409` fails, the conflict dialog is built from the stale cache.

## Checks

Admin checks ran in a snapshot of this working tree (`git ls-files -co --exclude-standard`).

| Check | Command | Result |
| --- | --- | --- |
| install | `pnpm install --frozen-lockfile` | exit 0 |
| typecheck | `pnpm typecheck` | exit 0 |
| lint | `pnpm lint` | exit 0, 25 warnings (the same `tailwindcss/enforces-shorthand` and one `exhaustive-deps` as round 2) |
| test | `pnpm test` | exit 0: 16 files, 175 tests |
| build | `pnpm build` | exit 0 |
| literals | `./scripts/check-literals.sh` | exit 0 |
| token copy | `./scripts/check-token-copy.sh` | exit 0 |
| client current | `pnpm orval`, then `diff -rq src/api/generated` against the working tree | exit 0, no diff |
| secrets | gitleaks v8.30.1 `dir .` from the snapshot root | exit 0 |
| T107 (Prism, `dev:wg`, the screenshots) | | **NOT RUN**: the owner's steps, against a running Caddy and WireGuard |

Ways around the checks: no `.skip(`, `.only(`, `eslint-disable`, `@ts-expect-error` or `any` in this round's hand-written code.

## Previous round

| Finding | Now |
| --- | --- |
| A-R2-1 HIGH, version lost on a changed refetch | fixed: `MatchEditor.tsx:417-424` `structuralSharing: false`; `MatchEditor.test.tsx:342-405` expects `If-Match` after «إعادة التحميل» and after a remount |
| A-R2-2 HIGH, preset `id` sent as `logo_asset_id` | fixed: `BroadcastSlots.tsx:44-57` uses `preset.logo_asset_id`; the fixture's ids and assets differ, so a revert fails |
| A-R2-3 HIGH, Button fill smaller than its target | fixed: `Button.tsx:25-26` `h-12` with a transparent `border-y` and `bg-clip-padding`; `Button.test.tsx:41-67` (see A-R3-5) |
| A-R2-4 HIGH, `?mock=` misses path parameters | fixed: `vite.config.ts:26-32` normalises `{match_id}`; `http.test.ts:176-196` |
| A-R2-5 HIGH, no stage presets | fixed: `FieldsSection.tsx:118-130` datalist, `ar.ts` `stagePresets`; `MatchEditor.test.tsx:316-335` |
| A-R2-6 Escape discards edits | fixed: `ConflictDialog.tsx:57` `onClose={onDismiss}`; editor and component tests |
| A-R2-7 conflict diff | fixed: `diffStates` (`MatchEditor.tsx:278-311`) covers 12 fields with Arabic labels and names; an unknown time says so |
| A-R2-8 picker's hidden sixth | fixed: `TeamPicker.tsx:38,57,72` share one slice (see A-R3-7) |
| A-R2-9 stale bulk `409` | fixed: `BulkBar.tsx:41-57` names rows with `<bdi>`, `queries.ts` invalidates on `edit_conflict` |
| A-R2-10 cache kept after logout | fixed: `session.ts` clears on `signOut` and `onExpired`; `App.test.tsx:86-99` (sign-out only, A-R3-8) |
| A-R2-11 (PLAUSIBLE) `Modal` focus effect | still open, not tasked |
| A-R2-12 overtyped label keeps logo | fixed: `BroadcastSlots.tsx:60-65`; `MatchEditor.test.tsx:300-314` |
| A-R2-13 runbook commands | fixed: CA command, `?mock=` URLs and scripts match the code; the `Host` header stays for the T107 walk |
| A-R2-14 … -16 (LOW) | still open, not tasked |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

#### A-R3-1: a failed refetch after a `409` builds the conflict dialog from the stale cache
- admin · FR-009, US4 scenario 8 · `admin/src/features/matches/MatchEditor.tsx:494-499` · CONFIRMED
- Problem: `openConflict` awaits `match.refetch()` and reads `refreshed.data`. React Query's `refetch` resolves on failure (it doesn't throw by default) and keeps the previous `data`, so `current` is the cached match with the old version. Nothing checks `refreshed.isError`.
- Failure scenario: a save gets `409`, and the refetch then fails (a network blip, a `401` the refresh can't recover). The dialog shows «لم يتغيّر…» with no changes, «إعادة التحميل» adopts the old version, and the next save sends the old `If-Match` and gets another `409`. Nothing is overwritten, but the editor loops and tells the user nothing changed when something did.
- Fix direction: when `refreshed.isError` (or `refreshed.status === 'error'`), keep the dialog closed and show the error copy for the refetch failure (or an error state in the dialog without the reload action). Add a test where the GET after the `409` fails.

### LOW

#### A-R3-2: a reopened editor seeds from the cached match, not the fresh one
- admin · `MatchEditor.tsx:433-441` · CONFIRMED
- On remount within `gcTime`, the first `match.data` is the cache; the background refetch is then ignored (`seeded.current === matchId`). A save from it gets a `409` and the dialog, so it's safe, but the editor shows stale data first. `structuralSharing: false` also relies on this being the only observer of the query key, which the comment doesn't say.

#### A-R3-3: a preset without an asset keeps the old thumbnail but saves `null`
- admin · `BroadcastSlots.tsx:49-56` (`logo: preset.logo ?? current.logo` vs `logoAssetId: preset.logo_asset_id`) · CONFIRMED

#### A-R3-4: the `onDismiss` comment mentions a click outside, which `Modal` doesn't handle
- admin · `ConflictDialog.tsx:36` · CONFIRMED

#### A-R3-5: Button `sm` and `xs` corners may look elliptical
- ui · `Button.tsx:25-26` · PLAUSIBLE
- A 4 or 8 px vertical border under `rounded-lg` shrinks only the vertical inner radius. Compare against `Dialogs.png` at the owner's screenshot step.

#### A-R3-6: only five teams can be reached in the picker
- ui · `TeamPicker.tsx:11,38` · CONFIRMED
- The bound is consistent now, but a sixth same-name team can't be chosen by any input. A scrolling list or a "more results" hint would solve it.

#### A-R3-7: the slot logo thumbnail is untested, and its `alt` joins the input's label
- ui · `BroadcastSlots.tsx:~80` · CONFIRMED

#### A-R3-8: the session-expiry cache clear is untested
- tests · `session.ts` (`onExpired`) · CONFIRMED

#### A-R3-9: Arabic separators outside i18n, and plain-text team names in a toast
- ui · `BulkBar.tsx:~46` (`'، '`), `MatchEditor.tsx:~363,376` (`'، '`, `' · '`) · CONFIRMED

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US4 scenario 8 / FR-009, a stale save shows the conflict, never overwrites | `MatchEditor.tsx` (`If-Match` from `baseline.etag`, `openConflict`, `ConflictDialog`) | `MatchEditor.test.tsx:342-465`, `ConfirmDialog.test.tsx` | met; a failed refetch is mishandled (A-R3-1) |
| US4 scenario 6, broadcast slots with presets and logos | `BroadcastSlots.tsx` | `MatchEditor.test.tsx:~300-314,~512` | met |
| stage presets (A4) | `FieldsSection.tsx:118-130` | `MatchEditor.test.tsx:316-335` | met |
| bulk edit with stale rows (A3) | `BulkBar.tsx`, `queries.ts` | `MatchesPage.test.tsx` | met |
| session: cache cleared on sign-out and expiry | `session.ts` | `App.test.tsx:86-99` | met (expiry untested, A-R3-8) |
| 48 px targets (4.F) | `Button.tsx` | `Button.test.tsx:41-67` | met |

Round 2's table for the rest of US4 still holds.

## Task audit

Ticked 12 (round-2 block), verified 12, not done 0, partly done 0.

## Owner must review

- A4 (`MatchEditor`, `BroadcastSlots`, `FieldsSection`) and the conflict dialog next to their design PNGs (`A4`, `Dialogs.png`), at the T107 screenshot step. The small buttons' corners (A-R3-5).

## Outside this change

- Agent setup in `.specify/`, `.claude/` and `.opencode/`: none changed.

## Not reviewed

- T107 (owner steps against Caddy and WireGuard), so no screenshot was compared with a PNG.
- A-R2-15 and -16 (LOW) were only partly re-checked.
