# Implementation Plan: D1 · Foundation

**Branch**: `001-d01-foundation` (lanes: `d01-b1`, `d01-b2`, `d01-a`, `d01-m`) | **Date**: 2026-10-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-d01-foundation/spec.md`

## Summary

D1 creates the four codebases and connects them through one frozen contract:

- **B1** loads the Sat Air snapshot into PostgreSQL through Alembic `0001` (`schema.sql` unchanged) and `0002` (the MVP additions), rehosts its media, and serves the FR-008 read endpoints. At 13:00 it tags the public and admin OpenAPI documents `contract-v1`.
- **B2** stands up both VPSs (Compose, Caddy, WireGuard, firewall) and the CI/CD that builds, checks and deploys each folder, with health-checked rollback.
- **A** scaffolds the admin on tokens, with an Orval client against a Prism mock, the A0 shell, A1 login and five components.
- **M** scaffolds the Flutter app on tokens, with three flavors, stub routes, ten signature components with goldens, a debug gallery, and a matches route reading `/v1/matches`.

The technical approach is in [research.md](research.md) (R1–R21). The key choices:

- whole lists except team search;
- a `my_satellite_ids` ranking input for the match-row channel line;
- clock status derived on read, with time-bucketed ETags;
- admin auth shapes declared on D1 and implemented on D2.

## Technical Context

**Language/Version**:

- backend: Python 3.13;
- admin: TypeScript 5 (strict) on Node 22 LTS;
- app: Dart 3 / Flutter stable, pinned in `app/.flutter-version`;
- infra: Bash, Docker Compose v2.

**Primary Dependencies**:

- **Backend:** FastAPI, SQLAlchemy 2 async (asyncpg), Alembic (psycopg 3), Pydantic v2 + pydantic-settings, redis-py, httpx, Pillow, ffmpeg (system package), gunicorn + uvicorn.
- **Admin:** React 18, Vite, Tailwind v3, React Router v6, TanStack Query v5, React Hook Form + Zod, Orval, Prism, MSW.
- **App:** flutter_riverpod + riverpod_generator, go_router, dio + retrofit via swagger_parser, freezed + json_serializable, drift + drift_flutter, intl.
- **Infra:** Caddy 2, PostgreSQL 16, Redis 7, WireGuard, iptables-persistent, GitHub Actions, GHCR, Firebase Hosting.

New dependencies are justified under [Complexity Tracking](#complexity-tracking).

**Storage**:

- PostgreSQL 16 with `pg_trgm`; schema in [data-model.md](data-model.md);
- Redis 7 (only `/healthz` uses it on D1);
- media files on VPS-1 disk at `/srv/media`, served by Caddy.

**Testing**:

- **Backend:** pytest + pytest-asyncio + httpx ASGI transport + schemathesis, against a real PostgreSQL 16 (CI service, local Compose).
- **Admin:** Vitest + Testing Library + MSW.
- **App:** flutter_test with goldens rendered by a pinned Flutter version on a pinned Linux OS ([R18](research.md#r18-golden-tests)).
- **Infra:** `docker compose config`, `caddy validate`, shellcheck.

**Target Platform**:

- 2 × OCI Ampere A1 (arm64, Ubuntu);
- Android (debug APK);
- the Flutter web PWA on a Firebase Hosting preview channel;
- the admin in desktop browsers at 1440 px, usable at 1024 px.

**Project Type**: Monorepo: a web service (two ASGI apps), an admin SPA, a Flutter mobile and web app, and infrastructure as code.

**Performance Goals**:

- `304` ≤ 1 KB;
- one local day of matches ≤ 60 KB gzipped;
- API p95 < 400 ms uncached, measured informally; the load test is on D4.

**Constraints**:

- $0/month;
- `linux/arm64` images only;
- admin only on `wg0`;
- no secrets, snapshot data or old Firebase config in the repo;
- contract frozen at 13:00;
- the MVP test bar (constitution v1.1.0);
- no rate limits until D3 (owner decision).

**Scale/Scope**:

- the 2026-10-28 snapshot has 32 satellites, 2,418 channel rows, 1,513 teams, 134 competitions, 75 rights holders, about 470 matches and 5,979 media URLs;
- 11 public read routes, 4 admin auth routes and 2 health routes;
- 11 app components (10 plus Logo) and 5 admin components.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against constitution v1.1.0, before research and again after design.

| # | Gate | Before research | After design (how it is met) |
| --- | --- | --- | --- |
| 1 | Answer ≤ 2 taps; My satellites and free first; no ads before the answer (I) | PASS | `broadcast.headline` ranks My satellites, then free ([R2](research.md#r2-personal-channel-line-on-match-rows)); detail sections free first ([R6](research.md#r6-match-detail-sections)); no ads exist on D1 |
| 2 | No guessed or stale-as-live data; UTC storage; local-day grouping (II) | PASS | Clock status derived on read with `estimated` and a DB CHECK that forbids clock scores ([R3](research.md#r3-clock-status-and-the-estimated-flag), data-model); UTC `kickoff_at`; local-day windows and the TBD anchor ([R5](research.md#r5-matches-whose-kickoff-time-is-unknown)); placeholders NULL; matches never deleted |
| 3 | RTL, isolated LTR islands, Western digits, externalized Arabic copy (III) | PASS | RTL roots in the app and admin; `MadarFormat` and LTR islands, tested first ([R19](research.md#r19-western-digits-and-time-formatting)); ARB and `error.code` → copy maps |
| 4 | Token-only values, shared components with every state, screens vs PNG (IV) | PASS | Verbatim token and font copies with CI checks; literal checks ([R20](research.md#r20-detecting-hard-coded-visual-values)); each component built once; goldens RTL × 2 themes × 2 scales |
| 5 | Admin only on `wg0`, no client secrets, server-side authz, validated input, bound SQL (V) | PASS with one recorded deviation | Separate admin app published only on the `wg0` address `10.8.0.1:8001`, behind a Caddy site with `bind 10.8.0.1` ([R12](research.md#r12-hosts-networking-and-docker)); env JSON holds public values only; Pydantic caps ([R8](research.md#r8-error-codes-and-validation)); SQLAlchemy only; CORS allowlist; SSRF guard in rehosting ([R10](research.md#r10-snapshot-loader-and-media-rehosting)). **Rate limits wait for D3** (Complexity Tracking) |
| 6 | Envelope, ETags, generated clients, `If-Match` + audit + version bump on admin writes (VI) | PASS | Envelope on every route; ETags from `dataset_versions` plus a time bucket, and on `/healthz` from the check result ([R4](research.md#r4-etags-304-and-time)); Orval and swagger_parser clients with a staleness check in `backend.yml` ([R14](research.md#r14-ci-layout)); no admin writes on D1 |
| 7 | Idempotent upserts, `locked_fields` respected, retrying tasks, outbox-only push (VII) | PASS | Loader and rehost are idempotent ([R10](research.md#r10-snapshot-loader-and-media-rehosting)); `locked_fields` columns created; no adapters, Celery tasks or push on D1 |
| 8 | drift stale-while-revalidate, platform adapters, budgets, Remote Config (VIII) | PASS with one recorded deviation | drift schema + ETag interceptor; budgets in SC-003; hosts from bundled flavor defaults (Remote Config D3). **The D1 matches route reads the API without the SWR repository** (Complexity Tracking) |
| 9 | $0/month, arm64 images, Compose + Caddy only, health-checked deploys (IX) | PASS | buildx arm64 build; GHCR retention of 3 versions ([R13](research.md#r13-image-build-deploy-and-rollback)); deploy with migration-first abort and `/healthz` rollback |
| — | Test-first; MVP coverage bar (Quality Gates) | PASS | FR-053 tests listed in [quickstart.md](quickstart.md); MVP bar per FR-054 |

**Result:** PASS. The two deviations are justified below.

## Project Structure

### Documentation (this feature)

```text
specs/001-d01-foundation/
├── spec.md
├── plan.md                  # this file
├── research.md              # Phase 0: decisions R1–R21
├── data-model.md            # Phase 1: revision 0002 + read models
├── quickstart.md            # Phase 1: validation per lane + done check
├── contracts/
│   ├── public-api-v1.md     # /v1 read endpoints (B1 builds; A and M consume)
│   ├── admin-auth-v1.md     # A1 auth shapes (declared D1, implemented D2)
│   └── load-report.md       # snapshot load / rehost report
├── checklists/requirements.md
└── tasks.md                 # /speckit-tasks (not created here)
```

### Source Code (repository root)

```text
backend/                                  # Lane B1 (except app/adapters/, Lane B2)
├── pyproject.toml · uv.lock · Dockerfile · alembic.ini
├── alembic/
│   ├── sql/0001_base_schema.sql          # verbatim copy of ../old_app/migration/schema.sql
│   └── versions/0001_base_schema.py · 0002_mvp_additions.py
├── app/
│   ├── public.py · admin.py              # the two ASGI apps; admin routers never imported by public.py
│   ├── settings.py · cli.py              # pydantic-settings; load-snapshot, rehost-media, export-openapi
│   ├── db/                               # engine, session, SQLAlchemy models, naming convention
│   ├── domain/                           # status.py (clock rule), time.py, frequency.py, regions.py, ranking.py
│   ├── api/                              # envelope, errors, etag, cors; public/*.py routers; admin/auth.py (501 stubs)
│   ├── schemas/                          # Pydantic response models = the contract
│   ├── services/                         # read queries per endpoint
│   ├── etl/                              # snapshot loader, media rehoster, load report
│   └── adapters/                         # Lane B2 (empty on D1)
├── openapi/public.json · admin.json      # exported, committed, tagged contract-v1
└── tests/
    ├── fixtures/snapshot/                # synthetic snapshot with every README edge case
    ├── unit/                             # domain: status, time, frequency, regions, ranking
    ├── db/                               # migrations, loader idempotency, CHECKs (PostgreSQL 16)
    └── contract/                         # every FR-008 route + admin auth stubs vs openapi

admin/                                    # Lane A
├── package.json · pnpm-lock.yaml · vite.config.ts · tailwind.config.ts · orval.config.ts
├── scripts/check-literals.sh · check-token-copy.sh
└── src/
    ├── styles/tokens.css · tokens.ts     # verbatim copies; fonts/ copied likewise
    ├── api/generated/ · mocks/           # Orval output (never hand-edited)
    ├── components/SidebarNav/ · DataTable/ · Field/ · StatusChip/ · Toast/   # each with *.test.tsx
    ├── features/shell/ (A0) · auth/ (A1)
    └── app/ (router, query client, RTL root)

app/                                      # Lane M
├── pubspec.yaml · .flutter-version · swagger_parser.yaml · build.yaml
├── env/dev.json · staging.json · prod.json           # public values only
├── assets/fonts/                                      # copied from madar-design
├── tool/check_literals.sh · check_token_copy.sh
├── lib/
│   ├── main_dev.dart · main_staging.dart · main_prod.dart
│   ├── core/config/ · network/ (dio, etag interceptor, generated/) · db/ (drift) · theme/ (madar_tokens.dart copy)
│   │   · format/ (digits, time, bidi) · router/ (PB §8.4 stubs + debug-only /gallery)
│   ├── design/components/                # MatchRow, StatusBlock, FrequencyReadout, CarriageRow, AccessBadge,
│   │                                     # DateStrip, MadarBottomNav, MadarTopBar, EmptyState, Skeleton,
│   │                                     # Logo (BrandMark, TeamCrest, LogoTile)
│   └── features/matches/ (data, domain, presentation) · gallery/
└── test/ (flutter_test_config.dart, goldens/, core/format/, core/db/)

infra/                                    # Lane B2
├── compose/vps1.yml · vps2.yml · dev.yml · example.env
├── Caddyfile
├── wireguard/wg0.conf.tmpl · peer.conf.tmpl          # templates, no keys
├── firewall/vps1.rules · vps2.rules
└── scripts/bootstrap-vps.sh · deploy.sh · check-firewall.sh

.github/workflows/                        # Lane B2
└── backend.yml · admin.yml · app.yml · pwa.yml · infra.yml · gitleaks.yml
```

**Structure Decision:** this is the monorepo layout of SD §9 with one top-level folder per lane, which matches the ownership rules in delivery-plan §4. Generated code lives in clearly named `generated/` folders that only the generators write ([R14](research.md#r14-ci-layout)).

## Delivery sequence within D1

| Time | B1 | B2 | A | M |
| --- | --- | --- | --- | --- |
| Morning | Pydantic schemas + routers as stubs → export OpenAPI → owner review | Bootstrap hosts, WireGuard, firewall; `infra.yml`, `gitleaks.yml` | Scaffold, tokens, fonts, the five components with tests | Scaffold, flavors, tokens, fonts, router stubs, components with goldens |
| **13:00** | **Tag `contract-v1`** | Compose + Caddy live on VPS-1 | Orval + Prism from the tag | swagger_parser client from the tag |
| Afternoon | `0001`/`0002`, loader, rehost, queries, contract tests; first deploy | `backend.yml` deploy + rollback drill; `app.yml`, `admin.yml`, `pwa.yml` | A0 shell, A1 states against Prism | drift schema, matches route against VPS-1, gallery |
| Evening | Load the refreshed snapshot on VPS-1; rehost media | GHCR retention; done-check scans | Screens vs PNGs | `prod` debug APK on a phone |

Tests are written first within each block (FR-053).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| V: `/v1` public without rate limits on D1–D2 | Owner decision (spec Clarifications). The done check needs a phone to reach VPS-1 over HTTPS, and the brief schedules the limiter for D3 | A per-IP limiter on D1 pulls D3 work into the busiest day. The data is already public, the host isn't published, and nothing is announced before D4 |
| VIII: the D1 matches route reads `/v1/matches` without the stale-while-revalidate repository | The brief puts SWR from drift on D2. D1 only proves the generated client, the drift schema and the ETag interceptor | Building SWR on D1 duplicates D2's S2 work on the lane already carrying 11 components with goldens. The route is replaced by the real S2 repository on D2, before any tester sees it |

### Tools beyond the system design

The constitution fixes the stack but doesn't restrict supporting libraries, so these aren't deviations. They are listed so a reviewer sees each one and why it's there:

- **schemathesis** (backend, test only): checks every route against the exported OpenAPI, including that no input produces a 500 (FR-015). Hand-written per-route assertions miss generated edge inputs and drift from the spec.
- **MSW** (admin, dev and test only): Orval generates handlers from the same spec, so tests use spec-true responses for A1's states instead of hand-written fetch mocks.
- **eslint-plugin-tailwindcss** (admin, dev only): enforces "no arbitrary values" (constitution IV) at lint time. A grep alone misses class strings built with `clsx` or `cva`.
- **oasdiff** (CI container only): reports breaking changes against the `contract-v1` tag (FR-014, SC-001).
- **Prism** is named in the brief.

The rest (for example pydantic-settings, pytest-cov, `@hookform/resolvers` and Testing Library) are the usual companions of the fixed stack.
