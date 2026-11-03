# Implementation review: 004-d04-mvp-launch, lane A, round 1

- Date: 2026-11-03 · Reviewer: Claude Code (Opus 5.5; layer subagents on Sonnet, every finding re-checked)
- Branch: 004-d04-mvp-launch (all four lanes merged; reviewed here at the owner's request, not on `d04-a`) · Base: master (merge base acbfece) · Head: 2a270b1, plus 0 uncommitted files
- Change: Lane A's commit eb01dd2; 11 files under `admin/`, plus `docs/runbooks/admin-access.md` and the A rows of `owner-actions.md`
- Verdict: CHANGES REQUESTED · CRITICAL 0 · HIGH 2 · MEDIUM 6 · LOW 4

## Checks
| Check | Command | Result |
| --- | --- | --- |
| install | `pnpm install --frozen-lockfile` | exit 0 |
| typecheck | `pnpm typecheck` | exit 0 |
| lint | `pnpm lint` | exit 0 (6 warnings, all in files outside this change) |
| unit | `pnpm test` | exit 0, 241 tests in 27 files |
| build | `pnpm build` | exit 0 |
| literals | `./scripts/check-literals.sh` | exit 0 |
| token copy | `./scripts/check-token-copy.sh` | exit 0 |
| e2e (mock) | `pnpm exec playwright install chromium && pnpm e2e` | exit 0, 1 passed |
| e2e (live) | — | NOT RUN (needs a WireGuard peer and the deployed admin; T055) |

## Findings
### HIGH
#### A-R1-1: The live run reads the editor before it loads, so it can never find the test match
- e2e · FR-022, US4 AC3, contracts/e2e-smoke.md step 3 · `admin/e2e/smoke.spec.ts:73-81` · CONFIRMED
- Problem:
  - `openEditor` returns as soon as the URL changes. `stadium.isVisible()` doesn't wait, and `MatchEditor` renders `<EditorSkeleton />` while `useGetMatch` is pending (`MatchEditor.tsx:629`).
  - `.catch(() => false)` also turns any error into "not marked".
- Failure scenario: every live row reads as unmarked, the run throws "found 0", and SC-004 can't be measured. The planned negative check ("clear the marker, see it abort") passes for the wrong reason. A row whose editor failed to load is silently left out of the "exactly one" count.
- Fix direction: wait for the field (`await expect(stadium).toBeVisible()`, or wait for the skeleton to detach), then read it, and let errors fail the run. Prove the guard with routed stubs (A-R1-5).

#### A-R1-2: Mock mode can edit a real match
- e2e · FR-022, spec edge case "the Playwright test runs against production data", contracts/e2e-smoke.md rules · `admin/e2e/smoke.spec.ts:23-24, 126`; `admin/playwright.config.ts:22, 28` · CONFIRMED
- Problem: mock mode reads `E2E_EMAIL`/`E2E_PASSWORD` from the environment, edits `ids[0]` with no marker check, and locally reuses whatever server already listens on :5173 (`reuseExistingServer: process.env.CI === undefined`).
- Failure scenario:
  - The owner has `pnpm dev:wg` open (the documented way to reach the deployed API; it proxies to `https://10.8.0.1`).
  - Their live credentials are exported, and they run `pnpm e2e` without `E2E_TARGET=live` (or with a typo).
  - The test signs in for real and overwrites the stadium on the first match of today's real list. The field also lands in `locked_fields`, so importers won't repair it.
- Fix direction: in mock mode, ignore the `E2E_*` credentials and use only the Prism fixtures; reject any `E2E_TARGET` other than `mock`/`live`; don't reuse an existing dev server (or start on a dedicated port).

### MEDIUM
- **A-R1-3: In live mode, missing `E2E_EMAIL`, `E2E_PASSWORD` or `E2E_PUBLIC_API` skips the test and exits 0** (`smoke.spec.ts:111-114`). That can be read as a pass. Throw instead.
- **A-R1-4: An empty `E2E_MATCH_MARKER=` matches every row** (`??` doesn't catch `''`). An empty `E2E_MATCH_DATE` stays on today's tab. In live mode, require a non-blank marker of reasonable length and a past `YYYY-MM-DD`, and check the opened editor's date before saving.
- **A-R1-5: The "exactly one marker" refusal and `waitForPublic` have no automated proof in any mode.** Add `page.route` stubs on the mock run for 0, 1 and 2 marked rows, asserting zero PATCHes in the refusal cases.
- **A-R1-6: "No conflict dialog" checks role `dialog`, but `ConflictDialog` uses `Modal`'s default `alertdialog`** (`smoke.spec.ts:141`, `Modal.tsx:27`). The assertion can't fail.
- **A-R1-7: `NODE_EXTRA_CA_CERTS` reaches Node, not Chromium** (`playwright.config.ts:3-8`, `admin-access.md`). The browser checks `https://10.8.0.1` against its own trust store, so the documented live setup likely fails at `page.goto` unless Caddy's root is in the peer's OS/NSS store. Document that (private-network.md "Install the admin CA root"), and verify it in T055. PLAUSIBLE.
- **A-R1-8: The admin CSP `default-src 'self'` blocks cross-origin media on the deployed host.**
  - Crests, logos, photos and audio come from `https://media.<VPS1_IP>.sslip.io` (`backend/app/services/common.py:18`; `<img>` in `MatchesPage.tsx:60`, `TeamsPage.tsx:43`, `ChannelsPage.tsx:55`; `<audio>` in `AudioPlayer.tsx:98`).
  - T050 checked only the login shell under `pnpm preview`.
  - Owner or B2 decision: add `img-src`/`media-src` for the media host to the CSP (and SD §8), or serve media same-origin on `10.8.0.1`. PLAUSIBLE until seen on the deployed admin (T056).

### LOW
- `waitForPublic` (`smoke.spec.ts:97-108`):
  - no `response.ok()` check, so one 502 ends the run;
  - the clock starts after the toast;
  - an edit landing at 58–60 s is never seen.
- `trace: 'retain-on-failure'` writes the login body and tokens to the git-ignored `test-results/` on a failed live run; keep them out of PRs. The runbook's inline `E2E_PASSWORD=…` lands in shell history (use `read -rs`).
- A wrong password waits for the 120 s timeout instead of failing on the error banner.
- `admin-access.md` names `E2E_MATCH_DATE` only in prose, and calls the not-yet-added CI step (B2's T042) present.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US4 AC1 / FR-020 | B2's `admin.yml` and Caddy; Lane A's `pnpm build` | not deployed | Lane A part met (CSP-clean shell); see A-R1-8 |
| US4 AC2 / FR-021 | B1/B2 host check | not run | open |
| US4 AC3 / FR-022 (mock) | `e2e/smoke.spec.ts`, `playwright.config.ts` | `pnpm e2e` exit 0 | met; not in CI yet (B2's T042) |
| US4 AC3 / FR-022 (live, exactly one marked match, ≤ 60 s) | `findMarkedMatch`, `waitForPublic` | none | not met (A-R1-1, A-R1-4, A-R1-5) |
| US4 AC3 (credentials from env only, never another match) | `smoke.spec.ts:23-27` | read | not met (A-R1-2, A-R1-3) |
| US4 AC4 / FR-023 | — | — | open, waiting on the owner's polish list (T054) |

## Task audit
Ticked 5, verified 4, not done 0, partly done 1.
| Task | Finding |
| --- | --- |
| T052 | partly done: step 3's live finder doesn't work (A-R1-1) and the "no conflict dialog" check is vacuous (A-R1-6) |

## Owner must review
- `admin/e2e/smoke.spec.ts`: the only code that writes to production data from a test; read the marker guard and the mock/live split.
- Admin screens next to their design PNGs: T056's screenshots are not taken yet (they need the deployed admin).

## Outside this change
- 6 Tailwind shorthand lint warnings in `ChannelsSection.tsx` and `StatusSection.tsx` predate this change.

## Not reviewed
- The live smoke run, the deployed CSP and the screenshots (no WireGuard peer in this session).
