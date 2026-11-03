# Implementation Plan: D4 · MVP launch

**Branch**: `004-d04-mvp-launch` (lanes: `d04-b1`, `d04-b2`, `d04-a`, `d04-m`) | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-d04-mvp-launch/spec.md`

## Summary

D4 hardens the MVP and makes the PWA public. No feature, screen or endpoint is added.

- **B1** fixes the client-IP bug that puts every anonymous caller in one rate-limit bucket (R1, a launch blocker found while planning), adds an env-only rate-limit allowlist for the test window, load-tests `/v1/live` and `/v1/matches` from VPS-2 with k6, and runs the code and host security review.
- **B2** proves 48 h of unattended imports and today-to-+3 coverage with a read-only report CLI, fixes parser edge cases from saved pages, and writes the on-call page. It also finishes the PWA mirror (release-folder caching, precompression, pruning), adds the `web-v*` release to the live Firebase channel plus the mirror, and the admin deploy job.
- **A** adds the Playwright smoke test (log in → edit the past-dated test match's stadium → see it in `/v1`) and closes the owner's polish list. B2 ships the bundle to `https://10.8.0.1`.
- **M** closes D3's three fixes, builds the hashed release layout and the service worker (cache → mirror → Firebase), runs the bug bash on three platforms, and cuts the release builds.

The technical approach is in [research.md](research.md) (R1–R15). The key choices:

- the public API trusts Caddy's fixed bridge gateway (`TRUSTED_PROXIES`);
- k6 runs in Docker on VPS-2 with arrival-rate scenarios;
- a release folder `/r/<hash>/` instead of per-file hashes, because Flutter loads CanvasKit and assets by fixed names;
- a module-tested `sw.js` beside FlutterFire's own messaging worker;
- an atomic symlink swap for admin releases.

## Technical Context

**Language/Version**: as D1–D3. Python 3.13, TypeScript 5 (strict) on Node 22 LTS, Dart 3.13 / Flutter 3.47.7 (`app/.flutter-version`), Bash, Docker Compose v2. Service-worker JavaScript runs as ES modules with Node 22's built-in test runner.

**Primary Dependencies**: D3's, plus:

- **Load:** the `grafana/k6` image (pinned tag, arm64), run on demand. Not a project dependency.
- **Admin:** `@playwright/test` (devDependency, Chromium only).
- **App:** none. `sw.js` is hand-written, with no Workbox.
- **Infra:** none. Caddy's `precompressed` is built in.

**Storage**: no schema change and no Alembic revision. New on disk:

- `/srv/app-mirror/r/<hash>/` on VPS-1;
- `/srv/admin/releases/<sha>/` plus a `current` symlink on VPS-1;
- the load report in `docs/load-tests/`;
- the security, bug-bash and bug-bash-results files in this spec folder.

**Testing**:

- **Backend:** pytest on PostgreSQL 16 for the client-IP, allowlist and report CLI rules and the parser edge fixtures.
- **Admin:** Vitest as before, plus Playwright against Prism in CI and against the deployed host from a WireGuard peer.
- **App:** `flutter_test` through `rtest` for the carry-over fixes; `node --test app/test_web/` for the service-worker core; a Dart test that the release layout and shell files are as specified.
- **Infra:** Compose and Caddy validation in `infra.yml`.
- **Manual:** the k6 run, the bug bash, and the 4G timing.

**Target Platform**: VPS-1 (`api-public`, Caddy sites `api.`, `media.`, `app.`, `10.8.0.1`), VPS-2 (k6 run, workers), the live Firebase Hosting channel `madar-sat.web.app`, the Android closed track, Chrome on Android, Safari on an iPhone (iOS ≥ 16.4, installed PWA), and desktop Chrome at 1440.

**Project Type**: the D1 monorepo: web service, admin SPA, Flutter mobile and web app, infrastructure as code.

**Performance Goals**:

- `/v1/live` at 170 requests/s and `/v1/matches` at 50 requests/s for 10 min each, p95 < 150 ms cached and < 400 ms uncached, < 1 % errors (FR-002);
- PWA first data < 5 s on Fast 4G and < 1.5 s on a repeat open (FR-034);
- ≥ 90 % of first-load bytes from the mirror (SC-008a);
- admin edit → `/v1` ≤ 60 s (SC-004).

**Constraints**:

- $0/month: Firebase Spark (O6), so the Spark transfer quota is protected by the mirror (spec Clarifications);
- 1 OCPU / 6 GB on VPS-1;
- no contract change unless a security fix needs one, non-breaking only;
- constitution V: trust Caddy only, the allowlist empty by default, the admin only on `wg0`;
- the CSP `default-src 'self'` on the admin, so the built bundle has no inline styles or scripts.

**Scale/Scope**: about 5k concurrent PWA users at peak (SD §11); a one-day hardening spec across four lanes; 4 carry-over fixes and roughly 40 tasks.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Gate | Status | Notes |
|---|---|---|---|
| 1 | Answer ≤ 2 taps; My satellites and free first; ads never before the answer (I) | Pass | No screen changes. The bug bash checks the existing flows (bug-bash.md) |
| 2 | No guessed, stale-as-live or invented data (II) | Pass | The service worker serves only the shell and release files; API data is never cached by `sw.js`. Drift's stale-while-revalidate is unchanged, and M-T045-2 makes failures visible instead of crashing |
| 3 | RTL, LTR islands, Western digits, Arabic copy (III) | Pass | The M-T045-3 error copy comes from the ARB through the `error.code` mapping |
| 4 | Tokens and components (IV) | Pass | No new widgets. The fonts stay bundled and the PWA never fetches fonts (R11 keeps `assets/fonts` in the release folder) |
| 5 | Admin on `wg0` only, no client secrets, server authz, validated input, bound SQL (V) | Pass after R1 | R1 restores "X-Forwarded-For trusted from Caddy only" on the public app, which is broken today. The allowlist is empty by default and lives only in host `.env` (R3). The admin bundle is served only at `10.8.0.1`. `MIRROR_BASE_URL` is public. The Playwright credentials stay on the owner's peer |
| 6 | Envelope, ETags, generated clients, `If-Match` + audit on admin writes (VI) | Pass | No contract change planned. The smoke test's edit goes through the normal `If-Match` + audit path |
| 7 | Idempotent pipelines, retrying tasks, outbox-only push (VII) | Pass | Parser fixes keep `parse` pure, with fixtures first (R7). The report CLI is read-only |
| 8 | drift SWR, platform adapters, budgets, Remote Config (VIII) | Pass, with a note | The mirror base is a build-time bundled value, because it is needed before Dart starts, so Remote Config can't supply it. Like the other hosts, it has a bundled default in `env/prod.json`. The budgets are measured (R2, R13) |
| 9 | $0, arm64, Compose + Caddy, health-checked deploys (IX) | Pass | Spark kept (constitution IX unchanged). k6 runs as a one-off arm64 container. The admin deploy checks the served `index.html` before pruning. No CDN. The Caddy cache plugin is only a contingency (Complexity Tracking) |

**Re-check after Phase 1 design:** unchanged. Every gate passes once R1 is fixed, and `SR-1` tracks R1 in the security report.

## Project Structure

### Documentation (this feature)

```text
specs/004-d04-mvp-launch/
├── spec.md
├── plan.md                  # this file
├── research.md              # R1–R15
├── data-model.md            # settings, on-disk layouts, report formats (no schema change)
├── quickstart.md            # validation steps per lane and the done check
├── bug-bash.md              # the script all three platforms run (written now)
├── contracts/
│   ├── web-release.md       # Lane M build output ↔ B2 release workflow and mirror
│   ├── ops-and-ci.md        # TRUSTED_PROXIES, RATE_LIMIT_EXEMPT_IPS, admin deploy, CI steps, report CLI
│   └── e2e-smoke.md         # Playwright modes, env, the test match
├── checklists/requirements.md
├── security-review.md       # written by B1 (FR-004)
├── bug-bash-results.md      # written by Lane M (FR-031)
└── tasks.md                 # /speckit-tasks
```

### Source Code (repository root)

```text
backend/                                   # B1 (except app/adapters/)
├── app/auth/limits.py                     # client_ip() reads TRUSTED_PROXIES (R1)
├── app/api/ratelimit.py                   # RATE_LIMIT_EXEMPT_IPS early return (R3)
├── app/settings.py                        # trusted_proxies, rate_limit_exempt_ips
├── loadtest/mvp.js                        # k6 scenarios (R2)
├── tests/api/test_ratelimit.py            # + proxy and allowlist cases
└── tests/auth/test_client_ip.py           # new
backend/app/adapters/                      # B2
├── report.py                              # `runs` and `coverage` sub-commands (R6)
└── <source>.py                            # parser fixes (R7)
backend/tests/adapters/test_report.py      # B2
backend/tests/fixtures/<source>/edge-*.html.gz   # B2

infra/                                     # B2
├── Caddyfile                              # app.: /r/* immutable + precompressed; 10.8.0.1: root /srv/admin/current
├── compose/vps1.yml                       # fixed network subnet; TRUSTED_PROXIES to api-public
├── firebase/firebase.json                 # /r/<hash>/ immutable rule
└── scripts/bootstrap-vps.sh               # /srv/admin/releases/placeholder + current symlink
.github/workflows/                         # B2
├── pwa.yml                                # + web-v* release job: stage → Firebase live → rsync mirror → prune
├── admin.yml                              # + e2e (mock) step, deploy job (R10)
└── app.yml                                # + `node --test app/test_web/`
docs/runbooks/                             # each lane its own pages
├── on-call.md                             # B2, new (FR-013)
├── load-testing.md                        # B1, new
├── pwa-release.md                         # B2 + M, new (or extends firebase-hosting.md)
├── admin-access.md                        # A + B2: deployed admin, e2e on a peer
└── README.md                              # index and "After setup" rows
docs/load-tests/2026-11-04-mvp.md          # B1

admin/                                     # Lane A
├── e2e/smoke.spec.ts
├── playwright.config.ts
└── package.json                           # @playwright/test, "e2e" script

app/                                       # Lane M
├── web/flutter_bootstrap.js               # custom template (R11)
├── web/sw.js, web/sw_core.mjs             # service worker (R12)
├── test_web/sw_core.test.mjs              # node --test
├── tool/stage_web_release.sh              # release layout, release.json, precompression
├── env/example.json                       # + MIRROR_BASE_URL
├── lib/core/network/…                     # M-T045-1 (dev CA), M-T045-2 (SWR errors)
├── lib/features/onboarding/presentation/steps/teams_step.dart   # M-T045-3
└── test/…                                 # tests for the three fixes and the release layout
```

**Structure Decision**: the existing monorepo. Each change sits in its lane's folder. Where two lanes meet, the interface is a contract file:
- `contracts/web-release.md`: Lane M's build output and B2's workflow;
- `contracts/ops-and-ci.md`: B1's settings and B2's Compose file, and Lane A's scripts and B2's CI steps.

## Delivery sequence within D4

| When | B1 | B2 | A | M |
|---|---|---|---|---|
| Morning | R1 fix + tests (with B2's subnet); allowlist; k6 script | Compose subnet + `TRUSTED_PROXIES`; report CLI; run `runs`/`coverage` | Playwright setup; smoke test against Prism | M-T045-1/2/3 |
| By 12:00 | Merge R1 (deploy); start code review; file other lanes' `SR-n` tasks | Caddy mirror changes, `firebase.json`; admin deploy job; `app.yml` node step | Polish list items (once written) | Owner tags `app-v0.3.0` once M-T045-1/2/3 merge (the bug bash needs it); `stage_web_release.sh`, bootstrap, `sw.js` + tests |
| Afternoon | Load test window (before the public tag); host review; report | `web-v*` release job; parser edge fixes; on-call page | Deployed smoke run from a peer; screenshots | Preview-channel checks of the release layout; bug bash on 3 platforms; fixes |
| Evening | Close CRITICAL/HIGH | Release check on the mirror | — | Tag `web-v0.1.0` (owner) after B1's load test and the bug bash |

The public tag waits for: R1 deployed, the load test passed, no open CRITICAL, the mirror live, and the bug bash without crashes.

## Complexity Tracking

| Item | Why needed | Simpler alternative rejected because |
|---|---|---|
| Release folder `/r/<hash>/` with a custom bootstrap and service worker | Spark's transfer quota (about 120 first loads a day) can't carry a public launch; the mirror must serve the files, and immutable caching needs addresses that change with content | Per-file hashed names break Flutter's CanvasKit and asset loading; serving everything from Firebase exhausts the quota |
| `RATE_LIMIT_EXEMPT_IPS` | One load generator must reach 170 requests/s through the real path (spec Clarification 2) | Raising limits for everyone leaves the API unprotected during the window |
| Contingency only: Caddy `cache-handler` for `/v1/live` (SD §11) | Only if the load test fails after raising `api-public` workers | Not adopted unless measured; needs a custom Caddy image |

### Tools beyond the system design

- **k6** (one-off container, not deployed).
- **Playwright** (admin devDependency; named by the constitution's MVP test bar).
- **Node's built-in test runner** for `sw_core.mjs` (no new dependency).
