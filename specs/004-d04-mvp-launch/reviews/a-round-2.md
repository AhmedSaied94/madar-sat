# Implementation review: 004-d04-mvp-launch, lane A, round 2

- Date: 2026-11-03 · Reviewer: Claude Code (Opus 5.5)
- Branch: 004-d04-mvp-launch (all four lanes merged; reviewed here at the owner's request, as in round 1) · Base: master (merge base acbfece) · Head: 2a270b1, plus 21 uncommitted files and 3 untracked files across the four lanes
- Change: the round-1 fixes only. Lane A's share is `admin/e2e/smoke.spec.ts`, `admin/playwright.config.ts`, `admin/eslint.config.js`, `admin/CLAUDE.md` and `docs/runbooks/admin-access.md`.
- Verdict: APPROVE WITH NOTES · CRITICAL 0 · HIGH 0 · MEDIUM 0 new (4 open from round 1) · LOW 1 new (4 open from round 1)

## Checks
| Check | Command | Result |
| --- | --- | --- |
| typecheck | `pnpm typecheck` | exit 0 |
| lint | `pnpm lint` | exit 0 (the same 6 warnings as round 1, in files outside this change) |
| unit | `pnpm test` | exit 0, 241 tests in 27 files |
| build | `pnpm build` | exit 0 |
| literals | `./scripts/check-literals.sh` | exit 0 |
| token copy | `./scripts/check-token-copy.sh` | exit 0 |
| e2e (mock) | `pnpm e2e` | exit 0, 4 passed: the flow, and the guard with 0, 2 and 1 marked rows (zero PATCHes for 0 and 2; only `/admin/api/matches/48214` written for 1) |
| e2e (live) | — | NOT RUN (needs a WireGuard peer and the deployed admin; T055) |

## Previous round
| Finding | Now |
| --- | --- |
| A-R1-1 the live finder read the editor before it loaded (HIGH) | **fixed**: `findMarkedMatch` waits for `match-stadium` (`await expect(stadium).toBeVisible()`), and a read error now fails the run. Routed Prism stubs prove that 0 and 2 marked rows abort with no PATCH and that 1 marked row is the only match written |
| A-R1-2 mock mode could edit a real match (HIGH) | **fixed**: mock mode uses only constant fixture credentials and marker, `E2E_TARGET` must be `mock` or `live` (in both the spec and the config), and the mock run starts its own Vite on `:5179` with `--strictPort` and never reuses a server (Prism's either), so a `pnpm dev:wg` on `:5173` is never touched |
| A-R1-3 missing live variables skipped the test | **fixed**: `required()` throws for a blank `E2E_EMAIL`, `E2E_PASSWORD`, `E2E_PUBLIC_API` or `E2E_MATCH_MARKER` |
| A-R1-4 empty marker / date | partly fixed: the marker must be non-blank. `E2E_MATCH_DATE` is still unvalidated (`smoke.spec.ts:46`), and the opened editor's date isn't checked |
| A-R1-5 no proof of the guard | **fixed** (the stubbed tests above) |
| A-R1-6 "no conflict dialog" checks `dialog`, not `alertdialog` | still open (`smoke.spec.ts:133`) |
| A-R1-7 `NODE_EXTRA_CA_CERTS` doesn't reach Chromium | still open (PLAUSIBLE until T055) |
| A-R1-8 the CSP blocks cross-origin media | still open (PLAUSIBLE until T056) |
| LOW (4) | still open |

## Findings
### LOW
- **A-R2-1:** `admin-access.md:80` says "the mock run proves this on every CI run". No CI step runs `pnpm e2e` yet: that is B2's T042 (B2-R1-11). Until T042 lands, the sentence should say "on every `pnpm e2e` run".

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US4 AC3 / FR-022 (mock) | `smoke.spec.ts`, `playwright.config.ts` | `pnpm e2e` exit 0, 4 tests | met; not in CI yet (T042) |
| US4 AC3 / FR-022 (live, exactly one marked match) | `findMarkedMatch` | the three stubbed guard tests | met in code; the live run is T055 |
| US4 AC3 (credentials from env only, never another match) | `required()`, mock constants, own Vite port | the code; the target check | met |
| US4 AC1, AC2, AC4 | as in round 1 | — | unchanged |

## Task audit
Ticked 7 (5 from round 1 plus A-R1-1 and A-R1-2), verified 6, not done 0, partly done 1 (T052: the vacuous dialog check, A-R1-6).

## Owner must review
- `admin/e2e/smoke.spec.ts`: the mock/live split and `findMarkedMatch`. This is the only code that writes to production data from a test.

## Outside this change
- The 6 Tailwind lint warnings, as in round 1.

## Not reviewed
- The live smoke run, the deployed CSP and the screenshots (no WireGuard peer in this session).
