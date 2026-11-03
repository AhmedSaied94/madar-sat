# Feature Specification: D4 · MVP launch

**Feature Branch**: `004-d04-mvp-launch` (lane branches `d04-b1`, `d04-b2`, `d04-a`, `d04-m`)

**Created**: 2026-11-03

**Status**: Draft

**Input**: User description: "day 04". Scope is exactly the brief "D4 · 004-d04-mvp-launch" in `docs/delivery-plan.md` Appendix B, plus carry-over from 002 and 003 (§5.3); the done check is catalog row 004 in Appendix A.

| | |
| --- | --- |
| Goal | Pass the MVP gate and make the PWA public. Hardening only: no new features |
| Phase | MVP [P], milestone M1 (delivery-plan §1, §6 Phase 1). D4 is a hardening day (§5.3) |
| Starts from | 001–003 merged to `master` (003: PRs #16–#23, plus #24–#26). Open code carry-over: Lane M's M-T045-1, M-T045-2 and M-T045-3 from 003, which come first in Lane M, and the nightly database backup's Kuma heartbeat that 003 T083 expected and never arrived (reported by the owner on 2026-11-03), which comes first in Lane B2 (FR-016). Open owner checks from 002 and 003 are under Assumptions; the MVP gate needs several of them |
| Contract | None, unless a security or load fix needs one. B1 decides; non-breaking only, and the PR that changes a spec regenerates both clients unedited |
| Flags | None |
| Implements | SD §5.2 (PWA, iOS limits), §5.4 (admin hosting), §6.6 (pipeline safety), §7 (hosts, backups, monitoring), §8 (security checklist), §11 (non-functional targets) · PB §17 (launch gate) · delivery-plan §9 (O7 decided today) |

Shorthand: **SD** = `docs/system-design.md`, **PB** = `docs/product-business.md`, **app:** / **admin:** = a board in `madar-design/app-flutter/SCREENS.md` / `madar-design/admin-react/SCREENS.md`.

## Clarifications

### Session 2026-11-03

- Q: The Firebase plan (O6 / delivery-plan A3) is unconfirmed and the constitution says Spark. Which plan does the public PWA launch on, given that this decides whether the VPS-1 PWA mirror is in D4? → A: Stay on Spark. Per A3, the mirror moves into D4: B2 serves the hashed app files from `app.<ip1>.sslip.io` and the `web-v*` release copies them there; Lane M builds with content-hashed names and a service worker that loads files from its cache, then the mirror, then Firebase (SD §5.2). Spark's hosting transfer quota (about 360 MB/day, so roughly 120 first loads at 2–3 MB) makes the mirror a launch requirement, not an option. O6 is recorded as decided in `docs/system-design.md` §3.2 and delivery-plan A3 (FR-037, FR-014, FR-015).
- Q: How does the load test get past the per-IP rate limiter, given 170 requests/s from one machine would get `429`? → A: It runs from VPS-2 against the public API host. VPS-1's `.env` gets a limiter allowlist that is empty by default; it holds VPS-2's public IP only during the test window and is cleared afterwards. The runbook says how, and the security review checks it is empty (FR-007).
- Q: Which match does the Playwright smoke test edit on the live admin, given fans see any edit within 60 s? → A: A dedicated test match dated in the past (for example 2000-01-01), created once by the owner and found by a fixed marker in its name. The test edits a harmless field on it and checks `/v1/matches/<id>`, and touches no other match (FR-022). Matches have no name field, so the marker is a fixed prefix of the match's `stadium` (research R9).

## User Scenarios & Testing *(mandatory)*

Each story is one lane's work and maps to that lane's section of `tasks.md` (`## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M`). The MVP gate needs all four, so the order reflects how early each must finish for the evening done check.

### User Story 1 - Lane B1: the owner knows the API holds the launch load and has no critical security hole (Priority: P1)

As the owner, I know the API holds the launch load and has no critical security hole.

B1 load-tests the two endpoints every open app hits, `/v1/live` and `/v1/matches`, against the deployed VPS-1 at the MVP target, and writes a report. The security review runs over the whole repository against the SD §8 checklist; B1 fixes every CRITICAL and HIGH finding in its folders and files each finding in another lane's folder as a task in that lane's section.

**Why this priority**: The gate requires no CRITICAL security finding, and a public link can bring traffic on day one. Findings in other lanes must reach them by midday so they can be fixed the same day.

**Independent Test**: Run the load script from outside VPS-1 against the public API host: `/v1/live` at the target rate for 10 minutes with a realistic share of `If-None-Match` requests, then `/v1/matches` for today and the next 3 days. The report shows p50/p95/p99, error rate, `304` share, cache hit share and VPS-1 CPU and memory, and states pass or fail against the targets. Run the security review: its report lists every finding with severity, owner lane and status, and none is CRITICAL or HIGH and open.

**Read**: SD §6.3.1–6.3.2 (cache, ETags, rate limits), §8, §11; `docs/runbooks/response-cache-and-limits.md`; `.specify/memory/constitution.md` (security rules).

**Acceptance Scenarios**:

1. **Given** the deployed API on VPS-1, **When** the load test runs `/v1/live` at 170 requests/s for 10 minutes (SD §11's 5k-concurrent polling figure) with about half the requests revalidating with `If-None-Match`, **Then** p95 latency stays under 150 ms, fewer than 1 % of responses are errors, and the box stays responsive.
2. **Given** the same run for `/v1/matches` (today and +3) at 50 requests/s, **Then** p95 stays under 150 ms from cache and under 400 ms for uncached reads, with fewer than 1 % errors.
3. **Given** the load test runs from VPS-2 against the public API host, **Then** VPS-2's public IP is in the limiter allowlist only for the test window, every other client is still limited during the run, and the allowlist is empty again afterwards. The report records the window, and a `429` is never counted as a pass.
4. **Given** a target is missed, **Then** B1 fixes the cause (cache, query, worker count) or applies the SD §11 fallback (Caddy caching `/v1/live`), re-runs, and records both runs.
5. **Given** the security review, **When** it finishes, **Then** every finding has a severity, a file, an owner lane and a status. B1's CRITICAL and HIGH findings are fixed with a regression test each; other lanes' findings appear as tasks in their sections the same morning.
6. **Given** the SD §8 checklist, **Then** the report confirms each row against the deployed hosts (headers, CORS origins, admin unreachable from the internet, rate limits, upload checks, secrets only in `.env` and Actions secrets), not only against the code.

---

### User Story 2 - Lane M: a fan installs the public PWA and the Android test build without hitting a crash (Priority: P2)

As a fan, I can install the public PWA and the Android test build without hitting a crash.

Lane M first closes D3's three open fixes. Then a written bug-bash script is run on a real Android phone, an installed iPhone PWA and desktop Chrome, and every crash or blocker it finds is fixed. Release builds are made: a signed Android build for the closed track and the web build deployed to the live Firebase Hosting channel, so the PWA has a public address. Because Firebase stays on Spark (Clarifications), the web build uses content-hashed file names and a service worker that loads each app file from its own cache, then the VPS-1 mirror, then Firebase, so the public launch barely touches the Spark transfer quota. The PWA meets the load-time targets and the install guide is reachable from More.

**Why this priority**: «PWA public» is the day's goal; the bug bash, load times and reminders on both platforms are gate items checked on these builds.

**Independent Test**: On a phone throttled to 4G with an empty cache, open the public PWA address: the first screen with data shows in under 5 s; reload: under 1.5 s. Walk the bug-bash script on each platform and finish with zero crashes and zero open blockers. Install the PWA on an iPhone (iOS ≥ 16.4) from S16 → «تثبيت التطبيق», follow a team, and receive its kickoff reminder. Install the release Android build from the closed track and receive the same reminder.

**Read**: PB §9 (the S0–S16 screens built so far), §17; SD §5.2, §11; `docs/runbooks/firebase-hosting.md`, `docs/runbooks/store-releases.md`, `docs/runbooks/push-notifications.md`; `specs/003-d03-follow-push-sources/tasks.md` (M-T045-1 … 3).

**Acceptance Scenarios**:

1. **Given** D3's open Lane M tasks, **Then** the `dev` flavor trusts the dev Caddy root on a real phone in debug builds only (M-T045-1), a failed request with no cache reaches the stream as an error and never as an uncaught exception (M-T045-2), and S1.2's team search shows its error state with «إعادة المحاولة» (M-T045-3), each with the test the task names.
2. **Given** the bug-bash script, **Then** it lists the steps for onboarding, S2 (dates, filters, pull to refresh), S3 (short and 130+ channel lists, clip, copy frequency), S4, S5.1–S5.2, follow and S9, S15 (each setting), S16, the S0 states (offline with and without cache, load failed, forced update), and a reminder end to end. Each step says what to see.
3. **Given** the script run on Android, the installed iPhone PWA and desktop Chrome at 1440, **When** a step crashes or blocks the flow, **Then** it is fixed with a test and the step re-run. Cosmetic issues are listed and either fixed or moved to a later day in the notes.
4. **Given** a release, **Then** the web build is deployed to the live Firebase Hosting channel by a tagged release workflow, never by hand, and the preview channel keeps working for `master`.
5. **Given** a phone on a throttled 4G profile with an empty cache, **When** it opens the public address, **Then** the first screen with data shows in under 5 s; **given** a second open, **then** under 1.5 s. The measurements are recorded with the build they used.
6. **Given** a signed Android release build, **Then** it is produced by `app-release.yml` from a tag and installs from the closed track.
7. **Given** S16 on the iOS web build, **Then** «تثبيت التطبيق» opens the install guide (S1.5); on other platforms the row is hidden.
8. **Given** the release web build, **Then** every app file except the shell (`index.html`, `flutter_bootstrap.js`, the manifest, the service workers, icons and a small same-origin drift worker shim) sits under a release folder named by the build's content hash (`/r/<hash>/…`), so its address changes whenever its content can, and the bootstrap loads them from the mirror's address.
9. **Given** the PWA opened once, **When** it is opened again, **Then** hashed files come from the service worker's cache with no network request for them. **Given** an empty cache, **Then** each file is fetched from the VPS-1 mirror first, and from Firebase only if the mirror doesn't answer within about 3 s. DevTools → Network on a first load shows the app files coming from `app.<ip1>.sslip.io`, and only the shell from `web.app`.
10. **Given** the mirror blocked (for example by a DevTools request block), **When** the PWA is opened with an empty cache, **Then** it still loads, from Firebase. **Given** the device offline after one visit, **Then** the cached app opens and API screens show their offline state.
11. **Given** the app's service worker at the origin root, **Then** FCM background messages still arrive and open their match through the existing `firebase-messaging-sw.js`, which keeps its own FCM scope (FlutterFire registers it itself, so it can't be merged; research R12), and a new release replaces the app's worker on the next open.

---

### User Story 3 - Lane B2: imports have run unattended since D2 and the owner has a first runbook (Priority: P3)

As the owner, imports have run unattended since D2 and I have a first runbook.

B2 proves the importers ran on their own for two days, fixes the parser edge cases those runs and the saved pages reveal, and checks that today to +3 is covered. It completes the "runbook v0": the existing `docs/runbooks/` files already cover deploy, rollback and sources; today adds a short on-call page that says what to do for each alert and links the existing procedures, and checks every command against the code. Because Firebase stays on Spark, B2 also brings up the PWA mirror on VPS-1 (`app.<ip1>.sslip.io`) and the `web-v*` release path that fills it (Clarifications).

**Why this priority**: The gate's first item is «importers cover today to +3»; the runbook is what the owner uses on launch night; the mirror must be live before the PWA goes public.

**Independent Test**: Query `import_runs` for the last 48 h: every scheduled ysscores and LiveSoccerTV slot has a run, none started by hand, each `succeeded` or `partial` with reasons. For each of today to +3, the Cairo day has ysscores fixtures for the prioritized competitions, and matches within 48 h have LiveSoccerTV channels. Each saved edge page has a parser test. Open the on-call page, pick an alert, and follow it to a working command.

**Read**: SD §6.6, §7; `docs/runbooks/imports-and-sources.md`, `source-alerts.md`, `uptime-kuma.md`, `deploy-and-rollback.md`, `workers.md`, `home-box.md`, `backups.md`; `docs/runbooks/README.md`.

**Acceptance Scenarios**:

1. **Given** the last 48 h of `import_runs`, **Then** every scheduled slot has a run with no manual trigger, and failures were recovered by the next slot or the breaker without help. The evidence (a query and its output) is in the PR.
2. **Given** pages the importers failed to parse or parsed wrongly (from the raw pages saved on VPS-2), **Then** each becomes a saved fixture with a failing test first, then a parser fix. The fixtures contain no personal data.
3. **Given** today to +3 (Cairo days), **Then** a coverage check lists, per day, the prioritized competitions' matches and how many have at least one channel; gaps are explained (no fixture yet, unmatched team) in the PR.
4. **Given** the on-call page, **Then** it covers deploy, rollback, restarting or pausing a source, reading Kuma and Telegram alerts (each alert → its cause → its fix), and where logs are, linking the existing runbooks instead of copying them. `docs/runbooks/README.md` points to it, and every command in it matches the code.
5. **Given** VPS-1's Caddy, **Then** `https://app.<ip1>.sslip.io` serves the mirrored files with a Let's Encrypt certificate, `public, max-age=31536000, immutable` on hashed files and `no-cache` on anything unhashed, CORS allowing `GET` from the two Firebase origins only, and `nosniff`. It serves no directory listing and nothing outside the mirror folder.
6. **Given** a `web-v*` tag, **When** the release workflow runs, **Then** it builds the web app once, deploys the shell and a full copy to the live Firebase channel, and copies the hashed files to the VPS-1 mirror, keeping the previous release's files so open sessions don't break. A failed mirror copy fails the workflow. `master` still deploys only the preview channel.
7. **Given** Uptime Kuma, **Then** it watches the mirror's address beside both PWA origins, and the on-call page covers a mirror alert.

---

### User Story 4 - Lane A: an editor uses the admin end to end on the real WireGuard host (Priority: P4)

As an editor, the admin works end to end on the real WireGuard host.

Today the admin app runs only from a developer's machine (`pnpm dev:wg`). Lane A builds it into a static bundle that CI deploys behind Caddy at `https://10.8.0.1`, reachable only over `wg0`, adds a Playwright smoke test (log in → edit a match → the change is visible in `/v1`), and closes the polish list from the owner's D3 review.

**Why this priority**: The gate's «admin edit visible in ≤ 60 s» is measured on the deployed admin; editors need it before launch.

**Independent Test**: Over WireGuard, open `https://10.8.0.1`: the admin loads, log in, edit the dedicated test match, and see `/v1/matches/<id>` return the change within 60 s. From the internet, the admin host answers nothing. Run the Playwright smoke test against the deployed admin with a test account: it passes and changes nothing but the test match.

**Read**: SD §5.4, §7.2, §8; `docs/runbooks/admin-access.md`, `private-network.md`, `ci-workflows.md`, `staff-accounts.md`; the owner's D3 polish list in `docs/owner-actions.md`.

**Acceptance Scenarios**:

1. **Given** a push to `master` that touches `admin/`, **Then** CI builds the admin and deploys it to VPS-1, served by Caddy on `wg0` at `https://10.8.0.1` with `tls internal`, the admin CSP (`default-src 'self'`) and `X-Frame-Options: DENY`, next to `/admin/api`. A failed deploy keeps the previous bundle.
2. **Given** a request to the admin from the public internet, **Then** it gets no admin page and no `/admin/api` (verified as in `docs/runbooks/exposure-check.md`).
3. **Given** the Playwright smoke test, **When** it runs against a target set by environment (Prism mock in CI, the deployed host from a WireGuard peer), **Then** it logs in, finds the dedicated test match (dated in the past, with a fixed marker as the prefix of its stadium) through A3, edits a harmless field in A4, saves, and checks the change in the public `/v1/matches/<id>` response within 60 s. It refuses to run if the marker matches no match or more than one. Test credentials and the marker come from the environment, never the repo.
4. **Given** the owner's D3 polish list, **Then** each item is fixed or moved to a named later day with a reason, and the 002/003 screenshot tasks (002 T107, 003 T106–T107) are run on the deployed admin.

---

### Edge Cases

- **The load test trips the rate limiter.** A `429` is not a success; the allowlist must hold VPS-2's IP for the window (US1 scenario 3).
- **The allowlist is left filled after the test.** The security review and the runbook's last step check it is empty; a filled allowlist is a HIGH finding.
- **An allowlisted IP is spoofed through `X-Forwarded-For`.** The allowlist matches the client IP exactly as the limiter derives it (trusting Caddy only), so a forged header can't reach it.
- **The load test hurts real users.** It runs before the PWA is public, or at a quiet hour, and stops if real `/v1` errors rise.
- **A security finding sits in another lane's folder.** It becomes a task in that lane's section; B1 never edits it.
- **A CRITICAL fix needs a contract change.** Only a non-breaking one, by B1, with both clients regenerated in the same PR; a breaking fix blocks the gate and is escalated to the owner.
- **A finding is a false positive or accepted risk.** It is marked so in the report with a reason; only the owner can accept a HIGH.
- **A secret is found in git history.** It is rotated first, then the report records the rotation (constitution: security response).
- **An importer slot was missed during the 48 h window** because of a deploy or host restart. The run log explains it; one missed slot recovered by the next one still counts as unattended, but a slot recovered only by hand does not.
- **A source is blocked from Oracle IPs on launch day.** The home-box worker or the Firestore bridge covers it, as on D2–D3, and the on-call page says how to switch.
- **Today to +3 has few fixtures because it is an international break.** The coverage check reports it; the gate item passes if every listed fixture was imported.
- **The live channel deploy fails or ships a bad build.** Firebase Hosting rolls back to the previous release from its history; the runbook says how.
- **The PWA's first load misses 5 s on 4G.** The usual causes are the CanvasKit download and unhashed files served `no-cache`; the fix is in the web build, and the measurement is re-taken.
- **An old service worker serves a stale shell after the public release.** A new release must reach users on their next open; the bug bash checks it.
- **A release lands while users have the old shell open.** The previous release's hashed files stay on the mirror and on Firebase, so an open session never requests a file that's gone.
- **The mirror is down or slow.** The service worker falls back to Firebase after about 3 s; Kuma alerts. Spark quota use rises only while the mirror is down.
- **Firebase is over quota.** Users who opened the PWA before load the shell from their cache and files from the mirror; new visitors can't load the shell until the quota resets (SD §5.2). The emergency install link stays on D10.
- **The mirror serves a file with the wrong type or no CORS header.** The browser refuses it and the service worker falls back to Firebase; the release check catches it before the tag is announced.
- **The iPhone push test fails on the day.** The gate fails; the PWA can still go public with push marked "not yet on iPhone" only if the owner accepts it in writing in the PR.
- **WireGuard is down for an editor.** The admin is unreachable by design; `admin-access.md` covers the fix.
- **The Playwright test runs against production data.** It edits only the dedicated past-dated test match, found by its marker; it never edits another match and never deletes. A past date keeps it out of the app's date strip, and nobody follows it, so it triggers no reminder.
- **The test match is missing or duplicated.** The test stops before editing anything and says why.

## Requirements *(mandatory)*

### Functional Requirements

#### Load and security (Lane B1)

- **FR-001**: A repeatable load script MUST live in the repository (B1's folder), take the target host and rates as parameters, and test `/v1/live` and `/v1/matches` with a realistic mix of fresh and `If-None-Match` requests.
- **FR-002**: The MVP targets MUST be: `/v1/live` at 170 requests/s and `/v1/matches` at 50 requests/s, each for 10 minutes, p95 under 150 ms from cache and under 400 ms uncached, fewer than 1 % errors (`5xx`, timeouts, and `429` from the load itself counted as failures).
- **FR-007**: The load test MUST run from VPS-2 against the public API host. The rate limiter MUST read an exempt-IP allowlist from VPS-1's host environment, empty by default, matched against the client IP as the limiter derives it (`X-Forwarded-For` trusted from Caddy only). It holds VPS-2's public IP only during a test window; the runbook gives the steps to fill and clear it, and tests prove an empty list exempts nobody and a forged header can't match it.
- **FR-003**: The load report MUST be committed under `docs/` with the date, build, host size, rates, latency percentiles, error and `304` shares, cache hit share, CPU and memory, and pass or fail per target, plus any re-run after a fix.
- **FR-004**: A full security review MUST run over the repository and the deployed hosts against SD §8 and the constitution. Its report under `specs/004-d04-mvp-launch/` MUST list each finding with severity, file, owner lane and status.
- **FR-005**: Every CRITICAL and HIGH finding MUST be fixed with a regression test before the gate, by the lane that owns the file; B1 adds findings for other lanes to their sections of `tasks.md`.
- **FR-006**: Any contract change a fix needs MUST be non-breaking, made only by B1, and ship with both regenerated clients in the same PR.

#### Imports and runbook (Lane B2)

- **FR-010**: B2 MUST show two consecutive days of scheduled `import_runs` for every enabled source with no manual trigger, and explain every failed slot.
- **FR-011**: Each parser edge case found in saved raw pages MUST get a committed fixture and a test written and seen failing before the fix.
- **FR-012**: A coverage check MUST report, for each Cairo day from today to +3, the prioritized competitions' imported matches and how many have a visible channel, and be repeatable by the owner from the runbook.
- **FR-013**: An on-call page in `docs/runbooks/` MUST map each Kuma and Telegram alert to its cause and fix, cover deploy, rollback, restarting and pausing a source, and log locations, link the existing runbooks, and be listed in `docs/runbooks/README.md`. It is the brief's "runbook v0".
- **FR-014**: VPS-1's Caddy MUST serve the PWA mirror at `app.<ip1>.sslip.io` (SD §5.2, §7.2): static files only from the mirror folder, Let's Encrypt, SD §5.2 cache headers, CORS `GET` from the two Firebase origins only, `nosniff`, no listing. Kuma MUST watch it.
- **FR-015**: A `web-v*` tag MUST build the web app once, deploy the shell and full copy to the live Firebase channel, and copy the hashed files to the mirror without deleting the previous release's files (old releases are pruned by age, not on every deploy). Pushes to `master` keep deploying only the preview channel. B2 owns the workflow and the host side; Lane M owns the build output it consumes.
- **FR-016**: The nightly database backup MUST report its Kuma heartbeat. B2 finds why the expected heartbeat never arrived after D3 (timers not installed or enabled, push URL unset or malformed, or the job failing), fixes it, adds a check so a missing timer or push URL fails loudly, and proves it with one manual and one scheduled run plus a `restic` snapshot listing. The monthly restore drill stays manual until D8.

#### Admin (Lane A)

- **FR-020**: The admin MUST be built by CI and deployed to VPS-1, served by Caddy only on `wg0` at `https://10.8.0.1`, with the SD §8 admin headers, and keep the previous bundle on a failed deploy.
- **FR-021**: The admin MUST be unreachable from the public internet, checked after deploy.
- **FR-022**: A Playwright smoke test MUST cover log in → edit a match → change visible in `/v1`, run in CI against the mock, and run against the deployed host from a WireGuard peer with credentials from the environment. Against the deployed host it edits only the dedicated test match: dated in the past, found by a fixed prefix of its `stadium`, created once by the owner. It refuses to run unless exactly one match carries the marker.
- **FR-023**: Every item on the owner's D3 polish list MUST be fixed or moved to a named day with a reason. The list doesn't exist yet (an open owner to-do in `docs/owner-actions.md`); the owner writes it before Lane A starts, and an empty list means FR-023 is met.

#### App (Lane M)

- **FR-030**: Lane M MUST close 003's M-T045-1, M-T045-2 and M-T045-3 first, each with its test.
- **FR-031**: A bug-bash script MUST be committed (Lane M's folder or the spec) and run on a real Android phone, an installed iPhone PWA (iOS ≥ 16.4) and desktop Chrome, with results recorded per step.
- **FR-032**: Every crash or flow-blocking issue the bug bash finds MUST be fixed with a test before the gate.
- **FR-033**: A tagged release workflow MUST deploy the web build to the live Firebase Hosting channel; `master` keeps deploying to the preview channel. The public address is the live channel's.
- **FR-034**: The PWA's first load MUST show data in under 5 s on a throttled 4G profile, and under 1.5 s on a repeat open, measured on the release build.
- **FR-035**: A signed Android release build MUST be produced by `app-release.yml` from a tag.
- **FR-036**: The install guide (S1.5) MUST be reachable from S16 on the iOS web build.
- **FR-037**: The release web build MUST put every app file outside the shell under a release folder named by the build's content hash (`/r/<hash>/`), point the bootstrap at the mirror, and bundle the Arabic fonts (no runtime font downloads).
- **FR-038**: The app's service worker MUST serve release files from its own cache, then the mirror, then Firebase, with about a 3 s timeout per source, keep the cached app usable offline, and replace itself on a new release. FCM background messages keep working through `firebase-messaging-sw.js` on its own scope (research R12). The source-order and fallback logic MUST have automated tests.

#### All lanes

- **FR-040**: `tasks.md` MUST have `## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M` and `## Done check`, the Done check copied word for word from Appendix A, row 004.
- **FR-041**: No new feature, screen or endpoint MUST be added; only fixes, tests, release plumbing and documentation.
- **FR-042**: Each lane MUST change only its own folders and tick only its own section; generated files are never edited by hand.
- **FR-043**: No secret MUST be committed, including load-test allowances, Playwright credentials and release keys.
- **FR-044**: Every changed operated part (the load script, the admin deploy, the PWA mirror and the live PWA release, the on-call page) MUST update its runbook in the same change, and each lane adds its D4 items to `docs/owner-actions.md` when it finishes.
- **FR-045**: Coverage MUST stay at or above the MVP bar (delivery-plan §7); fixes add tests, never remove them.

### Key Entities *(include if feature involves data)*

- **Load report**: one dated run of the load script with its targets, measurements and verdict.
- **Security finding**: one issue with severity, location, owner lane, status and, for accepted risks, the owner's reason.
- **Bug-bash run**: one platform's pass through the script, with per-step result, build, device and issues raised.
- **Coverage check**: per Cairo day from today to +3, the imported matches and their channel coverage.
- **Release**: a tagged build deployed to the live Firebase channel or the Play closed track.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `/v1/live` sustains 170 requests/s and `/v1/matches` 50 requests/s for 10 minutes each, with p95 under 150 ms for cached reads and under 400 ms for uncached reads on both, and under 1 % errors.
- **SC-002**: The security report shows 0 open CRITICAL findings and 0 open HIGH findings not accepted by the owner.
- **SC-003**: Over 48 h, 100 % of scheduled import slots ran without a manual trigger, and each of today to +3 has its prioritized fixtures imported.
- **SC-004**: An admin edit made on the deployed admin over WireGuard is visible in the app within 60 s, 3 out of 3 tries.
- **SC-005**: A kickoff reminder arrives on the Android release build and on an installed iPhone PWA, once each.
- **SC-006**: The bug-bash script completes on Android, the iPhone PWA and desktop with 0 crashes and 0 open blockers.
- **SC-007**: The public PWA shows data in under 5 s on first load over 4G and under 1.5 s on a repeat open.
- **SC-008**: The PWA is reachable at its public address by anyone with the link.
- **SC-008a**: On a first load of the public PWA, at least 90 % of the transferred bytes come from the VPS-1 mirror rather than Firebase, and a repeat open transfers no app files; with the mirror blocked, the PWA still loads.
- **SC-009**: The day's **done check** passes, word for word from delivery-plan Appendix A: *"MVP gate: importers cover today to +3; admin edit visible in ≤ 60 s; reminders on both platforms; bug-bash script without crashes; no CRITICAL security findings; PWA first load < 5 s on 4G and < 1.5 s afterwards; PWA public"*.

## Assumptions

- **003 is merged** (PRs #16–#23, #24–#26). Code carry-over is Lane M's M-T045-1 … 3 only (FR-030). 002's A-F4 is a standing note, not work.
- **Owner checks carried over, which the gate needs:** 002 B1 T047 (deploy check and first admin), B2 T086–T087 (hosts and first unattended run), M T135–T137 (`app-v0.2.0`, closed track, phone walk, PWA preview); 003 B1 T047 (FCM key and first real reminder), B2 T082–T084 (LiveSoccerTV run, breaker, backups, Kuma drill), A T106–T107 (WireGuard walk and screenshots), M T136–T137 (Android and iPhone walks). They are listed in the Done check's preconditions; the gate can't pass while the reminder, unattended-import and admin items among them are open.
- **The MVP load target is SD §11's peak polling figure** (170 requests/s on `/v1/live`), since one 10-minute run at that rate is cheap; D9's 5k-concurrent full-mix test stays on D9.
- **"Runbook v0" is an on-call index**, because `docs/runbooks/` already holds the deploy, rollback, source and Kuma procedures; the brief's `docs/runbook.md` is not created as a separate copy.
- **The security review** uses the `/security-review` command and the security-reviewer agent; the report is the spec folder's `security-review.md`.
- **Public means the live Firebase channel's default address** (`<project>.web.app`), shared as the open beta link (PB §17 step 2). No domain (O4, D13).
- **O7 (live data source) is the owner's decision today**, recorded in `docs/system-design.md` §3.2 and `docs/owner-actions.md` before spec 005 is planned. It changes no D4 code.
- **Firebase stays on Spark (O6 decided, Clarifications).** No constitution change is needed (IX already says Spark). The planning session records O6 in `docs/system-design.md` §3.2 and §13 (R4), delivery-plan A3 and §6 (the mirror rows of D9–D10 move to D4; D9 keeps the 5k load test and D10 keeps the emergency install link, share links and the failover polish), and `docs/owner-actions.md` (the Blaze row closes). `docs/runbooks/firebase-hosting.md` already expects the mirror and the `web-v*` release on D4.
- **Lane M's day is about one day larger** than the brief because of the mirror build and service worker (A3). By the quarter-day rule (§5.3), cosmetic bug-bash items (not crashes or blockers) move to D11 first if Lane M runs late; the mirror, the service worker and the gate items don't move.
- **Owner steps today:** decide O7; accept or reject any HIGH finding marked as accepted risk; create the Playwright test account and the dedicated past-dated test match; tag the web and Android releases; run the iPhone and Android device walks; announce the public link.

### Out of scope (later days)

- **D5–D6:** live feed, all push types beyond the kickoff reminder, the outbox log and composer.
- **D8:** restore drill, per-type preferences.
- **D9:** 5k-concurrent full-mix load test, ads.
- **D10:** the emergency install link on `app.<ip1>.sslip.io`, share links, install-guide polish, and failover tests beyond FR-038's.
- **D11:** 80 % coverage.

### Dependencies between lanes today

- B1's security findings for other lanes must land in their sections by midday.
- The load test runs on the deployed API before Lane M's public release, or at a quiet hour after it.
- Lane A's admin deploy needs B2's Caddy and CI (B2 owns `infra/` and CI, Lane A owns `admin/`): B2 adds the Caddy site and the deploy job; Lane A adds the build and the smoke test.
- The PWA mirror needs both B2 and Lane M: B2 serves `app.<ip1>.sslip.io` and copies files there on a `web-v*` tag; Lane M produces the hashed build and the service worker. They agree the mirror's address, folder layout and build-output path in `plan.md` so both can start in the morning. The public tag waits for both.
- The reminder gate item needs 003's B1 T047 (FCM on VPS-2) done by the owner and Lane M's release builds.
