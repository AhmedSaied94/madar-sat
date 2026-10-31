# Implementation review: 002-d02-core-flows, lane A, round 4

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`), no subagents (the delta is two files)
- Branch: `d02-features` (the combined checkout of rounds 1–3) · Base: `origin/master` (merge base `68f1752`) · Head: `635919d`, plus the uncommitted work of all four lanes
- Change (lane A, this round): the round-3 fix, uncommitted: `admin/src/features/matches/MatchEditor.tsx`, `MatchEditor.test.tsx`, and the lane's own `tasks.md` section. Nothing in another lane's folder.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 0 · LOW 1 (plus round 3's LOWs, still open and untasked)

A-R3-1 is fixed. After a `409` whose refetch fails, the dialog stays closed, the banner shows the refetch's own error, and the edits stay on screen. A test fails on revert.

## Checks

The admin checks ran in a snapshot of this working tree.

| Check | Command | Result |
| --- | --- | --- |
| typecheck | `pnpm typecheck` | exit 0 |
| lint | `pnpm lint` | exit 0, the same 25 warnings |
| test | `pnpm test` | exit 0: 16 files, 176 tests |
| build | `pnpm build` | exit 0 |
| literals | `./scripts/check-literals.sh` | exit 0 |
| secrets | gitleaks v8.30.1 `dir .` | exit 0 |
| T107 | | **NOT RUN**: the owner's walk over WireGuard |

Ways around the checks: none in this delta.

## Previous round

| Finding | Now |
| --- | --- |
| A-R3-1 a failed refetch builds the dialog from the cache | fixed: `MatchEditor.tsx:494-502` returns on `refreshed.isError` with `copyForErrorCode(refreshed.error?.code ?? NETWORK_ERROR)`. `:619` replaces the editor only when the first load failed (`match.data === undefined`), so a failed refetch keeps the form. Test `MatchEditor.test.tsx:803-831`: `409`, then a failing GET; it expects the network copy, no `alertdialog`, and `23:00` still in the field. With the old code the dialog opens and the test fails. |
| A-R3-2 … A-R3-9 (LOW) | still open, not tasked |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

None.

### LOW

#### A-R4-1: the comment promises a banner that a plain background refetch failure doesn't show
- admin · `admin/src/features/matches/MatchEditor.tsx:617-619` · CONFIRMED
- Problem: "the banner above says what happened". Only `openConflict` sets `saveError`. A refetch that fails outside a save (window refocus, invalidation) keeps the form, as intended, but shows nothing.
- Failure scenario: an editor's WireGuard drops while A4 is open. The form looks current, and nothing says the last check failed until they save.
- Fix direction: show a quiet "couldn't refresh" note while `match.isError && match.data !== undefined`, or correct the comment.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US4 scenario 8 / FR-009, a stale save shows the conflict and never overwrites, even when the refetch fails | `MatchEditor.tsx:489-530,619` | `MatchEditor.test.tsx:342-465,803-831` | met |

## Task audit

Ticked 1 (the round-3 block), verified 1.

## Owner must review

- none new; T107's screenshots of A3, A4 and the dialogs still stand (round 3).

## Outside this change

- A-F1 (React Hook Form) and A-F2 (`DataTable`) are still open in `docs/owner-actions.md` "Code follow-ups".

## Not reviewed

- T107 (the browser walk over WireGuard).
