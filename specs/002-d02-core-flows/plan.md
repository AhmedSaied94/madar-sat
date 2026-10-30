# Implementation Plan: D2 · Core flows

**Branch**: `002-d02-core-flows` (lanes: `d02-b1`, `d02-b2`, `d02-a`, `d02-m`) | **Date**: 2026-10-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-d02-core-flows/spec.md`

## Summary

D2 joins the four codebases into the product's core loop:

- **B1** implements D1's auth shapes, adds the admin API (CRUD for six entities, the A3/A4 match operations, the manual status, uploads) with `If-Match`, audit, `locked_fields` and version bumps on every write, adds revision `0003` (two columns), and creates the Celery app that B2's tasks plug into.
- **B2** builds the `SourceAdapter` base, the ysscores adapter and the read-only Firestore bridge, the upsert pipeline with entity resolution v0, and the hosts that run them: VPS-2's workers and `beat`, a scrape worker on the owner's x86-64 home box, and a small media worker on VPS-1 for importer-found logos.
- **A** builds A3 and A4 against the generated client, running on the editor's machine over WireGuard.
- **M** builds S2, S3, S4 and S5 with stale-while-revalidate from drift, live polling and voice clips, and ships the first closed-test AAB and the PWA preview.

The technical approach is in [research.md](research.md) (R1–R28). The key choices:

- content-hash entity versions, so any writer, importer included, makes an open editor's copy stale;
- one admin unit of work for audit, locks and bumps;
- imported links that an editor removes are kept as hidden `manual` links;
- a versioned scrape → ingest message, so the home box needs only Redis;
- a separate amd64 image package for the home box;
- the admin always works in Cairo time.

## Technical Context

**Language/Version**: as D1. Python 3.13, TypeScript 5 (strict) on Node 22 LTS, Dart 3 / Flutter stable pinned in `app/.flutter-version`, Bash and Docker Compose v2.

**Primary Dependencies**: D1's, plus:

- **Backend:** `argon2-cffi`, `PyJWT`, `python-multipart`, `celery[redis]`, `lxml`. ffmpeg and Pillow are already in the image.
- **Admin:** `date-fns` and `date-fns-tz`.
- **App:** `just_audio`, `url_launcher`, `cached_network_image` (all in SD §5.1's package list).
- **Infra:** a Redis ACL file, and a systemd timer on the home box.

Each one beyond the system design is listed under [Complexity Tracking](#complexity-tracking).

**Storage**:

- PostgreSQL 16: revision `0003` ([data-model.md](data-model.md));
- Redis 7: the login limits, rate-limit buckets, job locks and the Celery broker;
- `/srv/media` on VPS-1 (uploads and importer logos), and `/srv/raw` on VPS-2 (raw pages, 5 days);
- drift on the app: `match_windows` and `cached_documents`.

**Testing**: as D1:

- **Backend:** pytest on PostgreSQL 16, plus schemathesis over the admin OpenAPI, plus a Redis ACL test.
- **Admin:** Vitest with MSW handlers from Orval.
- **App:** flutter_test with goldens on the pinned runner.
- **Infra:** Compose and Caddy validation, shellcheck.

The Playwright smoke test is D4's (spec Clarifications).

**Target Platform**:

- VPS-1 (`api-public`, `api-admin`, `worker-media`, PostgreSQL, Redis) and VPS-2 (workers, `beat`), both arm64;
- the owner's x86-64 home box (`worker-scrape` only);
- Android: the signed `prod` AAB on the Play closed track;
- the PWA on a Firebase preview channel;
- the admin on the editor's machine, desktop at 1440, usable at 1024.

**Project Type**: the D1 monorepo: a web service with two ASGI apps and Celery workers, an admin SPA, a Flutter mobile and web app, and infrastructure as code.

**Performance Goals**:

- admin edit → client ≤ 60 s (SC-001);
- cached S2 first screen < 1.5 s on a 4 GB Android;
- S3 with 130 or more links: the answer in < 1 s, and smooth scrolling (SC-006);
- `304` ≤ 1 KB, unchanged from D1;
- an ysscores run (4 pages) finishes in under 1 minute.

**Constraints**:

- $0/month;
- VPS images are `linux/arm64`, and only the home box image is `linux/amd64`;
- the admin API only on `wg0`, with no CORS;
- no secret, snapshot data or old Firebase config in the repo (the bridge's config is in VPS-2's `.env`);
- no public contract change;
- the MVP test bar;
- no rate limits on `/v1` until D3 (D1 owner decision).

**Scale/Scope**:

- 2–5 editors;
- about 100–300 fixtures per ysscores run (4 Cairo days), and the same from the bridge;
- up to 171 links on one match;
- about 36 admin routes, plus D1's 4 auth routes ([contracts/admin-api.md](contracts/admin-api.md));
- 4 app screens and 5 new app components (`SatelliteBadge` exists since D1); 2 admin screens and 3 new admin components (`Button`, `ConfirmDialog`, `ConflictDialog`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against constitution v1.1.0, before research and again after design.

| # | Gate | Before research | After design (how it is met) |
| --- | --- | --- | --- |
| 1 | Answer ≤ 2 taps; My satellites and free first; no ads before the answer (I) | PASS | S2 row → S3 shows carriages with readouts collapsed (FR-042); «على أقمارك» first, using the O10 default until D3 ([R26](research.md#r26-polling-audio-lists-and-links)); `broadcast.headline` ranking from D1; S3's no-channels state offers «تحديث» as its next action until the follow action arrives on D3; no ads until D9 |
| 2 | No guessed or stale-as-live data; UTC storage; local-day grouping (II) | PASS with one recorded deviation | The manual status is validated against the state machine and the DB checks (data-model); importers write no status or score ([R16](research.md#r16-the-ysscores-adapter)); resolution never guesses ([R17](research.md#r17-entity-resolution-v0)); cached states never shown as live and `StaleHint` past freshness targets ([R25](research.md#r25-stale-while-revalidate-with-drift)); matches never deleted (A3 has no delete). **Unmatched names are logged per run until D5's queue** (Complexity Tracking) |
| 3 | RTL, isolated LTR islands, Western digits, externalized Arabic copy (III) | PASS | New components with RTL goldens; frequencies and Latin names as islands; Western digits in the admin's Cairo-time formatter (`ar-EG-u-nu-latn`, [R24](research.md#r24-session-forms-and-time-in-the-admin)) and the app's D1 formatters; ARB and `error.code` → copy maps extended for the D2 codes |
| 4 | Token-only values, shared components with every state, screens vs PNG (IV) | PASS | Every new component built once under its INDEX name with every state and tests or goldens; D1's literal checks still run; A3, A4 and S2–S5 checked against their PNGs (quickstart) |
| 5 | Admin only on `wg0`, no client secrets, server-side authz, validated input, bound SQL (V) | PASS with D1's recorded deviation | argon2id, rotating hashed refresh tokens, CSRF, lockout, a role dependency on every route with a test that enumerates them ([R1–R4](research.md#r1-passwords-the-cli-and-accounts)); the admin reached through a same-origin proxy over WireGuard ([R23](research.md#r23-reaching-the-admin-api-over-wireguard-on-d2)); uploads checked by magic bytes and re-encoded ([R10](research.md#r10-uploads)); SSRF guard in the fetcher and the logo worker ([R14](research.md#r14-the-sourceadapter-base), [R20](research.md#r20-importer-found-logos-a-media-worker-on-vps-1)); the home box limited by a Redis ACL ([R21](research.md#r21-the-x86-64-home-box)). **`/v1` rate limits still wait for D3** (D1 Complexity Tracking, "D1–D2") |
| 6 | Envelope, ETags, generated clients, `If-Match` + audit + version bump on admin writes (VI) | PASS with one recorded deviation | One unit of work runs every admin write ([R6](research.md#r6-one-unit-of-work-per-admin-write)); content-hash versions with `428`/`409` ([R5](research.md#r5-entity-versions-and-if-match)); list ETags from `dataset_versions`; Orval and swagger_parser regenerated with the staleness check; the public contract unchanged. **Creates and the hidden-name add and remove take no `If-Match`** (Complexity Tracking) |
| 7 | Idempotent upserts, `locked_fields` respected, retrying tasks, outbox-only push (VII) | PASS with one recorded deviation | Upsert by `(source, external_id)` with the duplicate probe; `locked_fields` re-read under a row lock ([R18](research.md#r18-the-upsert-pipeline)); importers remove only their own links; base task class with backoff and jitter, plus `SET NX EX` locks ([R13](research.md#r13-the-celery-app-and-queues)); raw pages kept 5 days; no push on D2. **Circuit breaker and zero-items alarm arrive on D3** (Complexity Tracking) |
| 8 | drift stale-while-revalidate, platform adapters, budgets, Remote Config (VIII) | PASS with one recorded deviation | drift SWR for every D2 dataset, with S4's filtered day in its own cache key ([R25](research.md#r25-stale-while-revalidate-with-drift)); live states in memory; polling only while visible and resumed; virtualized lists; budgets in SC-006. **Hosts and the poll interval come from bundled defaults until Remote Config on D3** (Complexity Tracking) |
| 9 | $0/month, arm64 images, Compose + Caddy only, health-checked deploys (IX) | PASS with two recorded deviations | VPS-2 deploy with health checks and rollback through a ProxyJump ([R22](research.md#r22-deploying-vps-2)); no new paid service; GHCR retention for both packages. **An amd64 image for the home box** and **one worker on VPS-1** (Complexity Tracking) |
| — | Test-first; MVP coverage bar (Quality Gates) | PASS with one recorded reading | The FR-053 tests listed in [R28](research.md#r28-what-is-written-first) and [quickstart.md](quickstart.md); the MVP bar per FR-054. **The admin Playwright smoke test lands on D4** (Complexity Tracking) |

**Result:** PASS. Each deviation is justified below.

## Project Structure

### Documentation (this feature)

```text
specs/002-d02-core-flows/
├── spec.md
├── plan.md                  # this file
├── research.md              # Phase 0: decisions R1–R28
├── data-model.md            # Phase 1: revision 0003, write rules, Redis keys, raw pages, drift tables
├── quickstart.md            # Phase 1: validation per lane + done check
├── contracts/
│   ├── admin-api.md         # /admin/api D2 additions (B1 builds; A consumes)
│   └── ingestion.md         # adapters, tasks, ScrapeResult, hosts, Redis ACL (B1 ↔ B2)
├── checklists/requirements.md
└── tasks.md                 # /speckit-tasks (not created here)
```

### Source Code (repository root)

New or changed in D2 only; D1's layout is in [001 plan](../001-d01-foundation/plan.md#project-structure).

```text
backend/                                  # Lane B1 (except app/adapters/, Lane B2)
├── alembic/versions/0003_audit_source_link_origin.py
├── app/
│   ├── auth/                             # passwords (argon2), tokens (JWT, refresh rotation), csrf, login limits, roles
│   ├── api/admin/                        # auth.py (now real), matches.py, teams.py, competitions.py, satellites.py,
│   │                                     # channels.py, commentators.py, lists.py (presets, hidden names, sources), media.py
│   ├── schemas/admin.py                  # the admin contract (Pydantic)
│   ├── services/admin/                   # writer.py (unit of work), versions.py, matches.py, links.py, bulk.py, status.py, …
│   ├── media/                            # encode.py + fetch helpers, moved from etl/media.py (shared with the rehoster)
│   ├── workers/                          # Celery app `app.workers`, base task class, locks.py
│   ├── cli.py                            # + create-admin, set-admin-password, deactivate-admin
│   └── adapters/                         # Lane B2
│       ├── base.py · fetcher.py · ratelimit.py · messages.py (ScrapeResult)
│       ├── ysscores.py · satair_bridge.py
│       ├── resolve.py (v0 + competitionSimilarity port) · upsert.py · raw_store.py
│       └── tasks.py · media_tasks.py · schedule.py
├── openapi/admin.json                    # regenerated; public.json unchanged
└── tests/
    ├── auth/ · admin/ · contract/test_admin_*.py   # B1
    ├── adapters/                         # B2
    └── fixtures/ysscores/ · fixtures/satair_bridge/   # saved pages (no personal data, no snapshot files)

infra/                                    # Lane B2
├── compose/vps1.yml                      # + worker-media; Redis also on 10.8.0.1:6379; api-admin flags + /srv/media rw
├── compose/vps2.yml                      # workers + beat env; /srv/raw
├── compose/home-box.yml                  # worker-scrape -Q scrape_home only
├── redis/users.acl.tmpl                  # the homebox ACL user (password filled from .env at deploy)
├── firewall/vps1.rules                   # 6379 on wg0 from the home-box peer only
└── scripts/deploy.sh (--host vps2) · home-box-update.sh · home-box-update.{service,timer}

.github/workflows/backend.yml             # Lane B2: + amd64 package build, + deploy-vps2 job, stable tag, retention

admin/src/                                # Lane A
├── components/Button/ · ConfirmDialog/ (ConfirmDialog, ConflictDialog)
├── features/matches/                     # A3 page, A4 editor, pickers (TeamPicker, ChannelPicker), bulk bar
├── lib/cairoTime.ts                      # date-fns-tz wrappers, latn digits
└── api/http.ts                           # CSRF header, single-flight refresh

app/lib/                                  # Lane M
├── core/db/                              # + match_windows, cached_documents (schema v2)
├── core/network/                         # SWR repository base on the ETag interceptor
├── design/components/                    # + CommentatorRow, FilterChipRow, SearchField, Segmented, StaleHint
└── features/matches/ (S2) · match_detail/ (S3) · my_satellites/ (S4) · frequencies/ (S5.1, S5.2) · live/ (polling)

docs/runbooks/                            # staff-accounts.md (B1); imports-and-sources.md, home-box.md, workers.md (B2);
                                          # store-releases.md (M); README.md setup order + "After setup" rows
```

**Structure Decision:** the D1 monorepo with one top-level folder per lane. Ownership follows delivery-plan §4:

- B1 owns everything in `backend/` outside `app/adapters/`, including `app/workers/` and `app/media/`;
- B2's ingestion code lives only in `app/adapters/` and uses B1's models, `app.domain` and `app.media` without changing them ([contracts/ingestion.md](contracts/ingestion.md#who-builds-what)).

## Delivery sequence within D2

| Time | B1 | B2 | A | M |
| --- | --- | --- | --- | --- |
| Morning | Admin Pydantic schemas + routers as stubs with Prism examples → export `admin.json`; `0003`; `app/workers/` skeleton; `app/media/` move | Saved ysscores pages + `parse` tests; `SourceAdapter` base, fetcher, rate limit; `vps1.yml` / `vps2.yml` / `home-box.yml`, the ACL, the firewall | `Button`, `ConfirmDialog`, `ConflictDialog` with tests; A3 and A4 layouts from components; `cairoTime` tests | S2 with the SWR repository (its tests first); new components with goldens |
| **13:00** | **Admin contract merged** (non-breaking vs `contract-v1`), with the regenerated admin client (D14; CI's `clients` job fails on a stale one) and B2's blockers; the owner reviews `0003` | Rebase on `master` | Rebase on `master` and build on the regenerated client; Prism mock | — |
| Afternoon | Auth for real, the writer unit of work, match PATCH/bulk/status, CRUD, uploads, contract tests; deploy | Resolution, upsert, the bridge, tasks and schedule; the `deploy-vps2` job; the amd64 package; the home box up | A3 and A4 against Prism, then over WireGuard; conflict and unsaved flows | S3 (lists, clips), S4, S5.1, S5.2; live polling |
| Evening | First admin created on VPS-1 (owner) | First unattended run checked; runbooks | Screens vs PNGs | `app-v0.2.0` tag → AAB → closed track (owner); PWA preview check |

Tests are written first within each block (FR-053).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| II: unmatched names logged in each run's `run.json` instead of `unresolved_names` | The brief puts the alias tables and the queue on D5. D2's importers must still run, and they must not guess | Creating the queue now pulls D5 work into D2 without its admin screen. Guessing breaks II. Dropping the fixtures would lose real matches. Each name keeps its text, so the app shows it honestly |
| VI: creates (`POST` of a new entity) and the hidden-name add and remove take no `If-Match` | `If-Match` guards an existing representation against a silent overwrite. A new entity has none, and adding or removing one hidden name is idempotent | Requiring `If-None-Match: *` or a list version adds a header that prevents no real conflict. Unique rules (`409 already_exists`) still stop duplicate creates. Every such write is audited and bumps versions |
| VII: no circuit breaker or zero-items alarm on D2 | The brief schedules both for D3, with the Telegram alerts | Building alerts today without their routing pulls D3's B2 work forward. Until then, failures and zero-item runs are visible in `import_runs` and the logs, and the bridge and the home box cover a block |
| IX: a `linux/amd64` image (`madar-backend-amd64`), for the owner's home box only | The owner's home box is x86-64 (spec Clarifications), and ysscores blocks datacenter IPs | QEMU on the box is slow and fragile. A multi-arch manifest under one tag breaks GHCR retention. Every VPS image stays arm64 |
| IX: one worker on VPS-1 (`worker-media`, `-c 1`, 256 MB) | Media files live on VPS-1's disk (SD §6.9), and VPS-2's import workers can't reach it (owner decision during planning) | Uploading through the admin API from VPS-2 needs a bot account, the Caddy CA and a WireGuard peer on VPS-2. rsync opens SSH from VPS-2 to VPS-1. Deferring leaves new teams without logos |
| VIII: hosts and the live poll interval come from bundled defaults, not Remote Config, until D3 | The brief puts Remote Config (with Crashlytics and S0) on D3, as on D1; both clients already read their hosts from the bundled flavor defaults | Wiring Remote Config today pulls D3's app work into Lane M's heaviest day, and the defaults are the values Remote Config will serve. The 30 s poll interval and the hosts change only with a new build until then |
| Quality Gates: the admin Playwright smoke test lands on D4, not when the flows first exist | The owner reads "once those flows exist" as once the admin is deployed on `wg0` (D4); the delivery plan schedules it there | Running Playwright today needs a backend service in admin CI, on Lane A's heaviest day. D2 covers A3 and A4 with Vitest and the generated MSW handlers instead |

### Tools beyond the system design

The constitution fixes the stack but doesn't restrict supporting libraries, so these aren't deviations. They are listed so a reviewer sees each one and why it's there:

- **PyJWT** (backend): signs and checks the 15-minute access token. It is the standard, small JWT library; hand-rolled HMAC tokens would be riskier.
- **python-multipart** (backend): FastAPI's required parser for `multipart/form-data` uploads.
- **lxml** (backend): parses ysscores HTML. SD §7.1 already sizes the worker for it.
- **date-fns + date-fns-tz** (admin): convert Cairo wall time to and from UTC across DST, which `Intl` can't parse ([R24](research.md#r24-session-forms-and-time-in-the-admin)).
- **A Redis ACL file** (infra): limits the home box to its own key patterns ([R21](research.md#r21-the-x86-64-home-box)).

`argon2-cffi`, Celery, `just_audio`, `url_launcher` and `cached_network_image` are named in the system design.
