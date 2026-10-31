# Implementation review: 002-d02-core-flows, lane M, round 4

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`), no subagents (the delta is one test and the generator's output)
- Branch: `d02-features` (the combined checkout of rounds 1–3) · Base: `origin/master` (merge base `68f1752`) · Head: `635919d`, plus the uncommitted work of all four lanes
- Change (lane M, this round): the round-3 fixes, uncommitted: `app/test/architecture/providers_test.dart`, six regenerated provider `*.g.dart`, `app/CLAUDE.md`, `docs/runbooks/ci-workflows.md`, `docs/owner-actions.md` and the lane's own `tasks.md` section. Nothing in another lane's folder.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 0 · LOW 1 (plus round 3's LOWs, still open and untasked)

Both round-3 MEDIUMs are fixed. The providers guard now catches the Riverpod 3 modifier forms. The provider code matches what `build_runner` writes. The whole suite passes on the test box.

## Checks

The app checks ran in a snapshot of this working tree.

| Check | Command | Result |
| --- | --- | --- |
| analyze | `flutter analyze` | exit 0, no issues |
| generated code current | `dart run build_runner build -d`, then `diff -rq lib` against the working tree | exit 0, **no diff** (round 3 found six files that differed) |
| tests | `RTEST_HOST=flutter-tests rtest` (on the test box) | exit 0: 480 passed |
| secrets | gitleaks v8.30.1 `dir .` | exit 0 |
| zones | `./tool/test_all_zones.sh` | **NOT RUN**: it runs `flutter test` on the laptop (T133 is the owner's) |

Ways around the checks: none. The `*.g.dart` changes are the generator's output, byte for byte.

## Previous round

| Finding | Now |
| --- | --- |
| M-R3-1 the guard misses `.autoDispose` and `.family` | fixed: `providers_test.dart:19-26` adds `(\.(autoDispose|family))*` before `<`/`(`, with six new offender fixtures (each modifier, both orders) and a commented-out one in `allowed`. The skip is now `path.startsWith('lib/core/network/generated/')` (`:44`). The old pattern fails the new fixtures. |
| M-R3-2 stale provider `*.g.dart` | fixed in `app/`: regenerating changes nothing. The CI check was asked of Lane B2 (`docs/owner-actions.md:286`) and isn't in `app.yml` yet (M-R4-1). |
| M-R3-3 … M-R3-5 (LOW) | still open, not tasked |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

None.

### LOW

#### M-R4-1: the stale-`*.g.dart` check is asked for, but no lane owns it yet
- ops · M-R3-2 · `docs/owner-actions.md:286`; `.github/workflows/app.yml` (no `build_runner` step) · CONFIRMED
- Problem: the request sits in the owner's list, not in Lane B2's tasks, so nothing schedules it.
- Failure scenario: a provider edited without regenerating passes CI again, and round 3's drift comes back.
- Fix direction: put it in Lane B2's next day (or a follow-up task), since `.github/` is B2's.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| constitution VIII, generated providers only | `providers_test.dart` | its fixture test and the `lib/` scan | met |
| generated files come from their generator | the six `*.g.dart` | `build_runner` gives no diff | met; no CI guard yet (M-R4-1) |

## Task audit

Ticked 2 (the round-3 block), verified 2.

## Owner must review

- none new.

## Outside this change

- none.

## Not reviewed

- `tool/test_all_zones.sh` (the owner's rule; T133).
