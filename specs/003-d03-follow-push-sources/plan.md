# Implementation Plan: D3 · Follow, push and sources

**Branch**: `003-d03-follow-push-sources` (lanes: `d03-b1`, `d03-b2`, `d03-a`, `d03-m`) | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-d03-follow-push-sources/spec.md`

## Summary

D3 adds the product's personal loop and makes the pipeline look after itself:

- **B1** adds anonymous devices and follows to `/v1`, the reminder scheduler and the FCM dispatcher on the outbox, the Redis response cache, rate limits on `/v1`, and the admin endpoints A2, A6, A7 and A13 need, with revision `0005`.
- **B2** ports LiveSoccerTV from `LVS.html` (with hidden placeholder channels for names Madar lacks), adds a circuit breaker and a zero-items alarm with Telegram alerts to every source, nightly backups to Backblaze B2 and the OCI bucket, and Uptime Kuma.
- **A** closes D2's two follow-ups and builds A5, A6, A7, A8, A10, A13 and a basic A2.
- **M** builds onboarding, device registration, follow sync and push on Android and the web (iPhone PWA included), S9, S15 core, S16, the S0 screens, Remote Config and Crashlytics.

The technical approach is in [research.md](research.md) (R1–R30). The key choices:

- one outbox row per match, and a per-device message built at send time from the device's satellites;
- a dispatcher cursor, so a retried row never sends twice to a device;
- the response cache keyed by D1's ETag, which already holds the route, query and dataset versions;
- LiveSoccerTV split into plan (VPS-2) → fetch (home box) → ingest (VPS-2), because the home box has no database;
- every beat entry goes through `schedule_fetch` on VPS-2, which applies pauses and the breaker;
- backups on host systemd timers, outside Celery.

## Technical Context

**Language/Version**: as D1 and D2. Python 3.13, TypeScript 5 (strict) on Node 22 LTS, Dart 3 / Flutter stable pinned in `app/.flutter-version`, Bash and Docker Compose v2.

**Primary Dependencies**: D2's, plus:

- **Backend:** `firebase-admin` (SD §6.8).
- **Admin:** `@dnd-kit/core`, `@dnd-kit/sortable`.
- **App:** `firebase_core`, `firebase_messaging`, `firebase_remote_config`, `firebase_crashlytics`, `flutter_secure_storage`, `share_plus` (all in SD §5.1).
- **Infra:** `louislam/uptime-kuma:1`, `restic`, `rclone`, `postgresql-client-16` in a backup image; systemd timers on both VPSs.

**Storage**:

- PostgreSQL 16: revision `0005` ([data-model.md](data-model.md));
- Redis 7: the response cache, rate-limit windows, the new job locks;
- `/srv/backup` on VPS-2 (dump staging), `/srv/kuma` on VPS-2, `/srv/secrets/fcm.json` on VPS-2;
- Backblaze B2 (restic repository) and the OCI bucket (media mirror);
- drift on the app: schema v3 (`app_settings`, `follows`, `sync_state`); `flutter_secure_storage` for the device token and install id.

**Testing**: as D2. Backend pytest on PostgreSQL 16 with schemathesis on both specs and a fake `PushSender`; admin Vitest with Orval's MSW handlers; app flutter_test with goldens, run with `rtest` on the test box; infra Compose validation and shellcheck. Device checks for push on a real Android phone and a real iPhone (quickstart).

**Target Platform**: VPS-1 (`api-public`, `api-admin`, `worker-media`, PostgreSQL, Redis, `backup-media`) and VPS-2 (workers, `beat`, Kuma, `backup-db`), both arm64; the home box (`worker-scrape`, now also LiveSoccerTV); Android closed-test build; the PWA preview channel (Chrome, Safari on an iPhone with iOS ≥ 16.4); the admin on the editor's machine over WireGuard.

**Project Type**: the D1 monorepo: web service (two ASGI apps + Celery), admin SPA, Flutter mobile and web app, infrastructure as code.

**Performance Goals**:

- a reminder within 2 min of its due time (SC-001); the dispatcher sends 500 devices per FCM call;
- cached public reads within the constitution's p95 < 150 ms, uncached < 400 ms;
- admin edit → client ≤ 60 s, unchanged (the cache keys on versions);
- a LiveSoccerTV run of 50 matches (≤ 100 pages at 1 request / 4 s) finishes in under 8 min;
- onboarding to a followed team in favorites in under 2 min (SC-007).

**Constraints**:

- $0/month: FCM, Remote Config and Crashlytics on Spark; B2 within its 10 GB free tier; OCI Always Free bucket;
- every VPS image `linux/arm64`; the home box keeps its `linux/amd64` package (D2);
- no secret in the repo: FCM key, Telegram token, restic password, B2 and OCI keys live in host `.env` files;
- public contract changes are additive (four device paths, `429`); admin changes are additive;
- the MVP test bar.

**Scale/Scope**:

- MVP launch audience: up to about 5k devices (D9 load-tests 5k concurrent), ≤ 500 follows each, about 30–80 followed matches a day;
- LiveSoccerTV: about 50 matches per 48 h window;
- 4 public routes, about 12 admin routes added ([contracts/](contracts/));
- 7 app screens or flows and 6 new app components; 7 admin screens and 3 new admin components (`SortableList`, `AudioPlayer`, `KpiCard`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against constitution v1.1.0, before research and again after design.

| # | Gate | Before research | After design (how it is met) |
| --- | --- | --- | --- |
| 1 | Answer ≤ 2 taps; My satellites and free first; no ads before the answer (I) | PASS | S1.3 and S15 set My satellites, and S2–S5 put them first; the «حدد أقمارك» chip arrives with the picker (D2's recorded gap closes); the reminder names a channel on the device's satellites, free first ([R8](research.md#r8-the-kickoff-reminder-message)); S3's no-channels state offers «تابع المباراة» as designed; no ads until D9 |
| 2 | No guessed, stale-as-live or invented data; UTC; local-day grouping (II) | PASS with one recorded deviation | Placeholders never reach `/v1` until an editor completes them ([R13](research.md#r13-placeholders-in-the-public-api), [R18](research.md#r18-placeholder-channels)); LiveSoccerTV matches channels by exact normalized name and country only ([R15](research.md#r15-matching-livesoccertv-channels)); the reminder says «بعد ‹N› دقيقة» with the real minutes and names no channel when none is visible; the offline banner shows the data's age ([R29](research.md#r29-s0-and-the-offline-banner)). **Unmatched names and unfound matches are still logged per run until D5's queue** (Complexity Tracking, carried from D2) |
| 3 | RTL, LTR islands, Western digits, externalized copy (III) | PASS | Push copy isolates every name with FSI/PDI and uses Western digits ([R8](research.md#r8-the-kickoff-reminder-message)); new components with RTL goldens; all app copy in ARB, admin copy in its i18n files; new `error.code`s (`rate_limited`, `unknown_follow_target`, `too_many_follows`, `unknown_satellite`, `run_in_progress`, `source_not_runnable`) mapped to Arabic in both clients |
| 4 | Token-only values, shared components with all states, screens vs PNG (IV) | PASS | New components built once under their INDEX names ([contracts/app-screens.md](contracts/app-screens.md#components-built-once-under-their-index-names), R22–R23); literal and token-copy checks still run; every screen compared with its PNG (quickstart) |
| 5 | Admin only on `wg0`, no client secrets, server-side authz, validated input, bound SQL (V) | PASS | Device tokens 256-bit, stored hashed, `Authorization: Device` ([R1](research.md#r1-device-registration-and-the-token), [R2](research.md#r2-device-authentication)); `/v1` rate limits by device, else trusted IP, generous for CGNAT ([R11](research.md#r11-rate-limits-on-v1)), which closes D1–D2's recorded gap; FCM and backup secrets in host `.env` only ([contracts/pipelines-and-ops.md](contracts/pipelines-and-ops.md#host-environment-added-on-d3)); Kuma reachable only over `wg0`; LiveSoccerTV and Telegram behind the fetcher's host allowlist; the third-party proxy in `LVS.html` not used; Remote Config hosts accepted only as `https` ([R28](research.md#r28-remote-config)) |
| 6 | Envelope, ETags, generated clients, `If-Match` + audit + bump on admin writes (VI) | PASS with one recorded deviation | The cache key is the ETag, built from `dataset_versions`; nothing is deleted by scan ([R10](research.md#r10-the-response-cache)); device routes `no-store` by design; ordering carries each row's version ([R12](research.md#r12-admin-additions)); both clients regenerated. **Source pause, resume and run take no `If-Match`** (Complexity Tracking) |
| 7 | Idempotent upserts, `locked_fields`, retrying tasks, outbox-only push (VII) | PASS | One outbox row per match with a unique `dedupe_key`; `SKIP LOCKED` claim, one `DISTINCT` audience, batches of 500, `UNREGISTERED` cleanup, collapsing tag ([R6](research.md#r6-the-reminder-scheduler), [R7](research.md#r7-the-dispatcher)); LiveSoccerTV removes only its own links and never touches `manual` ones; breaker and zero-items alarm per source ([R17](research.md#r17-source-health-breaker-and-zero-items-alarm)), which closes D2's recorded gap; every new task on the D2 base class with locks |
| 8 | drift SWR, platform adapters, budgets, Remote Config (VIII) | PASS with one recorded reading | Follows, settings and onboarding in drift, token in secure storage ([R27](research.md#r27-onboarding-state-device-registration-and-follow-sync)); `CrashReporter`, `PushService` and `InstallGuide` behind adapters ([R25](research.md#r25-firebase-in-the-flutter-app)); hosts and the poll interval from Remote Config with bundled defaults, which closes D2's recorded gap. **Maintenance and the soft-update banner read their keys but render on D8** (Complexity Tracking) |
| 9 | $0/month, arm64, Compose + Caddy, health-checked deploys (IX) | PASS with one recorded deviation | Spark is enough for FCM, Remote Config and Crashlytics; B2 free tier with retention; Kuma and backups on arm64 images; deploys through D2's path. **The media backup runs on VPS-1** (Complexity Tracking) |
| — | Test-first; MVP coverage bar (Quality Gates) | PASS with D2's recorded reading | The tests in [R30](research.md#r30-what-is-written-first), seen failing first; the MVP bar per FR-054. The admin Playwright smoke test stays on D4 (D2's recorded reading) |

**Result:** PASS. Each deviation is justified below.

## Project Structure

### Documentation (this feature)

```text
specs/003-d03-follow-push-sources/
├── spec.md
├── plan.md                    # this file
├── research.md                # Phase 0: decisions R1–R30
├── data-model.md              # Phase 1: revision 0005, lifecycles, Redis keys, drift v3
├── quickstart.md              # Phase 1: validation per lane + done check
├── contracts/
│   ├── public-devices.md      # /v1 devices, follows, limits, push message (B1 builds; M consumes)
│   ├── admin-api.md           # /admin/api additions (B1 builds; A consumes)
│   ├── pipelines-and-ops.md   # tasks, queues, ScrapeResult v2, health, alerts, heartbeats, env (B1 ↔ B2)
│   └── app-screens.md         # routes, screens, components, adapters (M)
├── checklists/requirements.md
└── tasks.md                   # /speckit-tasks (not created here)
```

### Source Code (repository root)

New or changed in D3 only; earlier layouts are in the [001](../001-d01-foundation/plan.md#project-structure) and [002](../002-d02-core-flows/plan.md#project-structure) plans.

```text
backend/                                    # Lane B1 (except app/adapters/, Lane B2)
├── alembic/versions/0005_devices_outbox_sources.py
├── app/
│   ├── devices/                            # registration, auth dependency, follows, prefs model
│   ├── notifications/                      # scheduler.py, dispatcher.py, messages.py (copy, channel choice), sender.py (PushSender, FCM), schedule.py
│   ├── api/public/devices.py               # the four device routes
│   ├── api/cache.py · api/ratelimit.py     # response cache on the ETag, sliding-window middleware
│   ├── api/admin/sources.py · dashboard.py · ordering.py
│   ├── services/admin/sources.py · dashboard.py · ordering.py
│   ├── services/*                          # placeholders excluded from public channel reads
│   ├── workers/__init__.py                 # several schedule and task modules
│   └── adapters/                           # Lane B2
│       ├── livesoccertv.py · livesoccertv_links.py (matching, placeholders, link rules)
│       ├── health.py · alerts.py
│       ├── messages.py (ScrapeResult v2) · tasks.py (schedule_fetch, heartbeat) · schedule.py · config.py
├── openapi/public.json · admin.json        # regenerated
└── tests/
    ├── devices/ · notifications/ · api/test_cache.py · api/test_ratelimit.py · contract/   # B1
    ├── adapters/test_livesoccertv*.py · test_health.py · test_schedule_fetch.py          # B2
    └── fixtures/livesoccertv/              # saved team and match pages

infra/                                      # Lane B2
├── compose/vps1.yml                        # + backup-media (one-shot)
├── compose/vps2.yml                        # + uptime-kuma, backup-db (one-shot); worker-notify mounts /srv/secrets/fcm.json
├── compose/example.env                     # the D3 variables, empty
├── backup/Dockerfile · backup-db.sh · backup-media.sh
├── systemd/backup-db.{service,timer} · backup-media.{service,timer} · backup-media-weekly.{service,timer}
├── Caddyfile                               # wg0: /kuma/ → VPS-2
└── scripts/deploy.sh                       # installs the timers

.github/workflows/backend.yml               # Lane B2: backup image build (arm64), deploy steps

admin/src/                                  # Lane A
├── components/SortableList/ · AudioPlayer/ · KpiCard/
├── features/matches/                       # A-F1 (RHF resolver), A-F2 (DataTable)
├── features/teams/ (A5) · competitions/ (A6) · satellites/ (A7) · channels/ (A8 + drawer) · commentators/ (A10)
└── features/sources/ (A13, run detail) · dashboard/ (A2)

app/                                        # Lane M
├── lib/core/config/                        # remote_config.dart, media host helper
├── lib/core/db/                            # schema v3
├── lib/core/platform/                      # push_service, crash_reporter, install_guide (+ web no-ops)
├── lib/design/components/                  # list_row, button (follow/bell), dialog, banner (offline, snackbar), form_controls, progress_dots
├── lib/features/onboarding/ · devices/ · follows/ · favorites/ (S9) · settings/ (S15) · more/ (S16) · system/ (S0) · notifications/
├── web/firebase-messaging-sw.js
└── env/*.json                              # + Firebase web options, VAPID public key (public values)

docs/runbooks/                              # push-notifications.md, response-cache-and-limits.md (B1);
                                            # livesoccertv in imports-and-sources.md, source-alerts.md, backups.md, uptime-kuma.md (B2);
                                            # remote-config.md, push-setup in store-releases.md (M); README.md order + "After setup"
```

**Structure Decision:** the D1 monorepo, one folder per lane (delivery-plan §4). B1 owns everything in `backend/` outside `app/adapters/`, including the new `app/devices/` and `app/notifications/`, the migration and both OpenAPI specs. B2 owns `app/adapters/`, `infra/` and CI, and writes source health and placeholders only through `app/adapters/health.py` and `livesoccertv_links.py` ([contracts/pipelines-and-ops.md](contracts/pipelines-and-ops.md#who-builds-what)).

## Delivery sequence within D3

| Time | B1 | B2 | A | M |
| --- | --- | --- | --- | --- |
| Morning | Device and admin Pydantic schemas + routes as stubs with examples → export both specs; `0005`; `app.workers` multi-module loading | Saved LiveSoccerTV pages + `parse` tests; matching and placeholder tests; `ScrapeResult` v2; backup scripts and image; Kuma in `vps2.yml` | A-F1 and A-F2 first; `SortableList`, `AudioPlayer`, `KpiCard` with tests; A5, A7, A8, A10 on D2's endpoints | Onboarding, S9, S15, S16, S0 on local state and bundled defaults; drift v3; new components with goldens; Firebase init and the service worker |
| **13:00** | **Contracts merged** (non-breaking), with the regenerated Dart and admin clients (D14) and `0005`; the owner reviews `0005` | Rebase on `master` | Rebase; A13, A2 and ordering against the new client | Rebase; device registration and follow sync against the new client |
| Afternoon | Device services, scheduler, dispatcher, cache, limits, admin services; contract tests; deploy | `schedule_fetch`, LiveSoccerTV plan/fetch/ingest, health, alerts, heartbeats; deploy; timers installed | Flows against Prism, then over WireGuard; conflict and keyboard paths | Push on Android and web; Remote Config; Crashlytics; S3's follow action and chip |
| Evening | Owner: FCM key on VPS-2, audience query reviewed | Owner: Telegram, B2, OCI keys; first LiveSoccerTV run checked | Screens vs PNGs | **iPhone push test on a real device**; closed-test build |
| Next morning | — | First nightly backup checked (done check) | — | — |

Tests are written first within each block (FR-053).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| II: LiveSoccerTV's unfound matches, and every source's unmatched names, logged in the run instead of `unresolved_names` (carried from D2) | The alias tables and the queue are D5's (brief). D3's importers must run and must not guess | Building the queue now pulls D5 into D3 without its A13 section; guessing breaks II. Placeholders capture channel names honestly (hidden until completed), and `import_runs.log` keeps the rest visible in A13 |
| VI: source pause, resume and «تشغيل الآن» take no `If-Match` | Each sets a state (paused, running) rather than editing a representation, so there is no stale copy to protect, and repeating one is harmless. Each is audited | An `If-Match` on the source row would make an editor reload A13 before pausing a failing source, the moment speed matters. Pause and resume bump no `/v1` dataset, since nothing public changes |
| IX: the media backup (`backup-media`) runs on VPS-1, not VPS-2 | Media lives on VPS-1's disk (SD §6.9), as D2 found for `worker-media` | Pulling media to VPS-2 needs SSH from VPS-2 to VPS-1 (D2 rejected it), or a full copy over the VCN each night. A one-shot container started by a timer, outside the request path, costs nothing while idle |
| VIII: Remote Config's `maintenance` and `latest_build` are fetched but the maintenance screen and soft-update banner render only on D8 | The D3 brief lists forced update, no connection, load failed, the offline banner and the exit snackbar for S0; the D8 brief schedules maintenance and soft update | Building them today adds two screens to Lane M's heaviest day with no way to exercise them before D8's admin and flag work. The keys already have bundled defaults, so D8 adds UI only |

### Tools beyond the system design

The constitution fixes the stack but not supporting libraries. Listed so a reviewer sees each one:

- **`@dnd-kit/core` + `@dnd-kit/sortable`** (admin): drag ordering with a keyboard path and screen-reader announcements for A6 and A7 ([R22](research.md#r22-ordering-with-drag-and-keyboard)). HTML5 drag and drop has no keyboard path.

`firebase-admin`, the Firebase Flutter plugins, `flutter_secure_storage`, `share_plus`, Uptime Kuma, restic and rclone are named in the system design (§5.1, §6.8, §7.3, §7.4).
