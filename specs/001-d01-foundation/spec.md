# Feature Specification: D1 · Foundation

**Feature Branch**: `001-d01-foundation` (lane branches `d01-b1`, `d01-b2`, `d01-a`, `d01-m`)

**Created**: 2026-10-29

**Status**: Draft

**Input**: User description: "Day 1 (D1) spec from the delivery plan — spec 001". Scope is exactly the brief "D1 · 001-d01-foundation" in `docs/delivery-plan.md` Appendix B; the done check is catalog row 001 in Appendix A.

| | |
| --- | --- |
| Goal | All four codebases exist, deploy through CI, and talk to one frozen `/v1` contract backed by the real snapshot |
| Phase | MVP [P], milestone M1 (delivery-plan §1, §6 Phase 1) |
| Starts from | Day 0 done (accounts, VPSs, constitution). `schema.sql` and the snapshot available in `../old_app/migration/` |
| Contract | Alembic `0001` + `0002`; the read endpoints of SD §6.3.2 listed in FR-008; the A1 auth shapes in the admin spec (FR-013). **Tagged `v1` at 13:00** |
| Flags | None yet (the app isn't public) |
| Implements | SD §5.1, §5.4, §6.1–6.3, §6.9, §7.1–7.2, §8, §9, §10 steps 1–3 · PB §8.4, §10 A0–A1, §13 · migration README rules 1–17 |

Shorthand: **SD** = `docs/system-design.md`, **PB** = `docs/product-business.md`, **README** = `../old_app/migration/README.md`, **app:** / **admin:** = a board in `madar-design/app-flutter/SCREENS.md` / `madar-design/admin-react/SCREENS.md`.

## Clarifications

### Session 2026-10-29

- Q: Which coverage bar applies to D1: the constitution's ≥ 80 % or the delivery plan's MVP bar? → A: The MVP bar of delivery-plan §7, with the constitution's Quality Gates amended to match in v1.1.0 (FR-054, Assumptions).
- Q: Should the D1 `/v1` list endpoints return whole lists, or page their results with a cursor? → A: Whole lists, with the matches window capped at 8 days. Only team search (`GET /v1/teams?q`) pages, with `limit` and `meta.next_cursor` (FR-009).
- Q: Which backend should each app flavor call on D1, and in which builds should the component gallery appear? → A: The SD §9 hosts: `dev` → local Compose, `staging` → a LAN backend, `prod` → VPS-1. The gallery is in every debug build and never in a release build. CI's debug APK is the `prod` flavor (FR-025, FR-040, FR-045).
- Q: Should `/v1` on VPS-1 be open to the internet from D1, before the rate limits scheduled for D3 exist? → A: Yes. It is open from D1 with no rate limits until D3, as an accepted, recorded deviation (Assumptions).

## User Scenarios & Testing *(mandatory)*

Each story is one lane's work and maps to that lane's section of `tasks.md` (`## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M`). Stories are ordered by how much the other lanes depend on them.

### User Story 1 - Lane B1: real Sat Air data behind a frozen `/v1` contract (Priority: P1)

As a client developer, I can call `/v1` and get real Sat Air data in the documented envelope and shapes.

The Sat Air snapshot is loaded into the new database by every rule in the migration README, its logos, photos and voice clips are rehosted onto the Madar media host, and the read endpoints serve it in the documented shapes. At 13:00 the contract is tagged `v1`, and the admin and app lanes generate their clients from that tag.

**Why this priority**: Every other lane builds on this contract and this data. Lane A and Lane M can't generate clients until the tag exists, and the done check needs real data on VPS-1.

**Independent Test**: On an empty PostgreSQL 16 database, run the migrations and the snapshot load, then run the contract tests for every read endpoint. Then call the deployed `https://api.<ip1>.sslip.io/v1/matches` and get snapshot data with an `ETag`, and a `304` when the request is repeated with that `ETag`.

**Read**: SD §6.1–6.3, §6.9 (rehosting), §10 steps 1–3; README.

**Acceptance Scenarios**:

1. **Given** an empty database, **When** the migrations run, **Then** revision `0001` is `schema.sql` unchanged, and `0002` adds exactly the MVP additions in FR-002 and nothing from later days.
2. **Given** the snapshot, **When** `load_snapshot.py` runs, **Then** every README rule is applied: the frequency regex (with the Cyrillic `Н` fixed), NULL placeholders, Cairo → UTC, channel kinds, dedupe, external ids, orphans logged and skipped, `legacy_id` kept, and no card-sharing labels.
3. **Given** the snapshot was loaded once, **When** the load runs again on the same snapshot, **Then** no row is duplicated and every count is unchanged.
4. **Given** media URLs in the snapshot, **When** rehosting runs, **Then** each file from an allowlisted host is re-encoded and stored once per content hash in `media_assets` with its `original_url`, content rows reference it by id, and the API returns absolute URLs on `media.<ip1>.sslip.io`.
5. **Given** the loaded data, **When** a client calls each read endpoint in FR-008, **Then** every response matches the exported OpenAPI contract and the envelope, and the contract tests pass for every endpoint.
6. **Given** a response with an `ETag`, **When** the client repeats the request with `If-None-Match`, **Then** it gets a `304`. After the underlying data changes, the same validator gets a `200`.
7. **Given** it is 13:00 on D1, **When** B1 freezes the contract, **Then** the public and admin OpenAPI documents are tagged `v1`, and later changes go only through B1 and stay non-breaking.
8. **Given** B1's work is merged to `master`, **When** CI deploys it, **Then** VPS-1 serves `/v1` with snapshot data over HTTPS.

---

### User Story 2 - Lane B2: push to `master`, and every folder is built, checked and deployed (Priority: P2)

As the owner, I can push to `master` and have each folder built, checked and deployed without touching a server.

**Why this priority**: Without the servers, the network and the pipelines, B1's API can't reach VPS-1, and the done check's "CI green in all four folders" can't happen. It ranks below B1 only because B1 can be verified locally first.

**Independent Test**: Merge a trivial backend change to `master`: CI builds an arm64 image, deploys it to VPS-1 over WireGuard and passes the health check. Then deploy an image whose health check fails and watch the previous version come back automatically. Open a PR containing a fake secret and see it blocked.

**Read**: SD §7.1–7.2, §8 (ports, headers), §9.

**Acceptance Scenarios**:

1. **Given** the two VPSs, **When** the owner brings up `vps1.yml` and `vps2.yml`, **Then** VPS-1 runs Caddy, `api-public`, `api-admin`, PostgreSQL 16 and Redis 7, VPS-2's file defines the worker processes of SD §6.1, and every image is `linux/arm64`.
2. **Given** Caddy on VPS-1, **When** a browser opens `api.`, `media.` and `app.<ip1>.sslip.io`, **Then** each is served over HTTPS with a Let's Encrypt certificate and the SD §8 headers. A WireGuard peer reaches `https://10.8.0.1` through `tls internal`.
3. **Given** the WireGuard hub `10.8.0.1/24` with peers for the owner and CI, **When** the host is scanned from the internet, **Then** only 80/tcp, 443/tcp and 51820/udp answer. SSH, PostgreSQL and Redis do not. The iptables rules survive a reboot.
4. **Given** a merge to `master` that touches `backend/`, **When** `backend.yml` runs, **Then** it lints, type-checks and tests, builds `linux/arm64`, pushes to GHCR and deploys: migrations as a one-off container, then `compose pull && up -d`, then `/healthz`. A failed health check rolls back to the previous image tag.
5. **Given** a change under `app/`, **When** `app.yml` runs, **Then** it runs analyze and test and publishes a `prod`-flavor debug APK as a build artifact.
6. **Given** the web build, **When** `pwa.yml` runs, **Then** the PWA is deployed to a Firebase Hosting preview channel.
7. **Given** any PR, **When** CI runs, **Then** gitleaks scans it, and a PR containing a secret fails.
8. **Given** PRs touching `admin/` or `infra/`, **When** CI runs, **Then** that folder's checks run, so every one of the four folders has a green CI run.

---

### User Story 3 - Lane M: the app shell, built only from Madar tokens and components, shows today's real matches (Priority: P3)

As a user, I open the app and see today's real matches, in a shell built only from Madar tokens and components.

**Why this priority**: Signature components are built once, on D1, and every later screen reuses them (delivery-plan §10: "components built once on D1 with golden tests"). The match list itself stays unstyled until D2.

**Independent Test**: Install the `prod`-flavor debug APK from CI on a phone; it calls the deployed API on VPS-1. The gallery route shows every signature component, the golden tests pass, and the matches route lists today's matches from `/v1/matches` as plain rows, or the empty state when there are none.

**Read**: SD §5.1; PB §13; app: Brand, color & type · Components · Matches · Components · Channels · Components · Core, feedback, platform · S2 Matches.

**Acceptance Scenarios**:

1. **Given** the `dev`, `staging` and `prod` flavors, **When** each one builds, **Then** it reads its own `env/<flavor>.json`, which holds public values only, including the API and media hosts as bundled defaults: `dev` → local Compose, `staging` → a LAN backend, `prod` → VPS-1.
2. **Given** the router, **When** any route in PB §8.4 is opened, **Then** it resolves to a stub screen laid out RTL, with the back arrow pointing right.
3. **Given** the theme, **When** any widget draws, **Then** its colors, type, spacing and radii come only from `madar_tokens.dart`, and the bundled fonts (Changa, IBM Plex Sans Arabic, IBM Plex Mono) load without a network fetch, including on web.
4. **Given** `MatchRow`, `StatusBlock`, `FrequencyReadout`, `CarriageRow`, `AccessBadge`, `DateStrip`, `MadarBottomNav`, `MadarTopBar`, `EmptyState` and `Skeleton`, **When** the golden tests run, **Then** each component passes in RTL, in both themes, at 1.0× and 1.3× text scale, in every state its README lists.
5. **Given** the gallery route, **When** it opens, **Then** it shows every component above in its states.
6. **Given** the client generated from the `v1` tag, **When** the matches route opens, **Then** today's matches for the device's local day render as unstyled rows (teams and local kickoff time in Western digits). No matches shows `EmptyState`, and a failed load shows an error state chosen by `error.code`.
7. **Given** the drift database, **When** a `MatchSummary` from the API is written and read back, **Then** it round-trips unchanged.

---

### User Story 4 - Lane A: the admin shell and log-in screen in the Madar look, on a generated client (Priority: P4)

As an editor, I see the admin shell and log-in screen in the Madar look, wired to a generated client.

**Why this priority**: The admin isn't used until D2 (real auth and CRUD) and isn't deployed on `wg0` until D4. Today it only needs its foundation: tokens, the generated client and the shared components.

**Independent Test**: Run the admin locally against Prism serving the `v1` admin spec. The shell and A1 render in the Madar look; A1 shows its error and lockout states from mock responses; component tests pass.

**Read**: PB §10 A0, A1; SD §5.4; admin: Login · error + lockout, Admin components · all states.

**Acceptance Scenarios**:

1. **Given** the admin project, **When** it builds, **Then** it is Vite + TS strict + Tailwind reading `tokens.css`, with no arbitrary values, and the root is `<html lang="ar" dir="rtl">`.
2. **Given** the `v1` admin spec, **When** Orval runs, **Then** it generates the client and Zod schemas, and Prism serves the same spec as the mock. No API types are written by hand.
3. **Given** `SidebarNav`, `DataTable`, `Field`, `StatusChip` and `Toast`, **When** Vitest runs, **Then** every state in each component's README has a passing test.
4. **Given** the A0 shell, **When** it renders, **Then** the sidebar sits on the right with the PB §10 A0 sections (V2 items marked), and the top bar has search and the user with their role.
5. **Given** A1 against the mock, **When** the mock answers with success, invalid credentials or lockout, **Then** A1 shows the matching state and copy from the Login board («إيميل أو باسوورد غلط» and the lockout message), mapped from `error.code`, never from `error.message`.

---

### Edge Cases

- **The snapshot doesn't cover today.** The snapshot keeps a rolling 7-day window, so by D1 "today" may have no matches. The app shows `EmptyState`, and the owner refreshes the snapshot first (README "Refresh the snapshot"). The load is re-runnable, so refreshing is safe.
- **A match whose kickoff has passed but has no feed or manual status.** It gets the documented clock estimate (FR-011), never `scheduled`, and never a score or minute.
- **Snapshot `is_live` flags.** They were manual overrides on 2026-10-28 and are stale by load time. They don't become manual statuses.
- **An unknown kickoff (`"--:--"`).** `kickoff_at` stays NULL and `time_tbd` is true. The API returns it as unknown, never as a guessed time.
- **Ambiguous or missing team names.** Ties break on the match competition. Otherwise `*_team_id` stays NULL, and the displayed name is kept.
- **References to deleted or unpublished rows.** They are skipped and logged with the reason. They never fail the load.
- **Frequencies that don't parse.** They go to `frequency_note`. Values outside the frequency or symbol-rate domains are rejected and logged.
- **Media failures.** A download fails, is too big, comes from a host outside the allowlist or redirects to another host: the column stays NULL, the failure is logged, and clients show the placeholder.
- **The same file under two URLs.** One `media_assets` row (same SHA-256).
- **Unknown ids and bad queries.** An unknown id returns `404` in the envelope with a stable code (for example `match_not_found`). An invalid query (a malformed date window, a window longer than 8 days, wrong id types, an over-long `q`) returns a validation error in the envelope, never a stack trace.
- **A stale or unknown `If-None-Match`.** It gets a full `200` with the current `ETag`.
- **A contract change needed after 13:00.** B1 makes it only if it is non-breaking. Anything else waits for the next day's spec.
- **A deploy whose health check fails.** It rolls back automatically. A failed migration stops the deploy before any container is replaced.
- **CORS on PWA preview channels.** Their origins differ from `<project>.web.app`. Lane M's D1 check runs the `prod`-flavor debug APK natively, so it doesn't depend on calling the API from a preview channel.
- **Text scale 1.3× and long Arabic names.** Components wrap or truncate as their READMEs say. The goldens catch any overflow.
- **Locales that emit Arabic-Indic digits.** Times, counts and frequencies still render Western digits.

## Requirements *(mandatory)*

### Functional Requirements

#### Contract and data (Lane B1)

- **FR-001**: Revision `0001` MUST be `../old_app/migration/schema.sql` unchanged, run as one script through psycopg. It is the only file copied from `../old_app/`.
- **FR-002**: Revision `0002` MUST add exactly the D1 MVP additions from SD §6.2.1:
  - on `matches`: `status`, `period`, `minute`, `home_score`, `away_score`, `home_pen`, `away_pen`, `status_source`, `status_label`, `status_updated_at`, `time_tbd`, and `locked_fields` with a CHECK against the lockable columns;
  - on `channels`: `locked_fields` with the same CHECK, and `frequency_changed_at`;
  - `pg_trgm` GIN indexes on the `name_norm` columns;
  - the tables `admin_users`, `admin_refresh_tokens`, `audit_log`, `devices`, `device_follows` (exactly one target set) and `notification_outbox` (unique `dedupe_key`, plus a partial index on `due_at` for pending rows);
  - the `import_runs` columns `items_found`, `items_upserted`, `http_errors`, `status` and `raw_path`;
  - `dataset_versions`.

  `is_live` stays for now (expand/contract). Tables that belong to later days (`match_events`, `match_lineups`, `channel_frequency_changes`, alias tables, `unresolved_names`, `reports`) MUST NOT be added.
- **FR-003**: `load_snapshot.py` MUST implement every README rule (1–17) and SD §10 steps 1–3. It reads the snapshot from outside the repository and ends with a load report. For each collection, the report gives counts loaded, merged and skipped, with a reason for every skip.
- **FR-004**: The load MUST be idempotent: re-running it on the same snapshot creates no duplicates and changes no counts.
- **FR-005**: Card-sharing labels and BISS keys MUST NOT be stored, logged into content fields or served (O3, constitution §Content). `encryption` isn't loaded, and `provider` and `package` start empty.
- **FR-006**: Media rehosting MUST:
  - fetch only from allowlisted hosts (the old R2 bucket and `imgs.ysscores.com`);
  - refuse redirects to other hosts;
  - enforce size caps and timeouts;
  - re-encode per SD §6.9: images to WebP ≤ 512 px with metadata stripped, audio to AAC ≤ 30 s;
  - store files content-addressed, with one `media_assets` row per SHA-256 holding the `original_url`.

  If a file fails, its column stays NULL and the failure is logged.
- **FR-007**: The API MUST build absolute media URLs from the configured media base URL. Content rows never store media URLs.
- **FR-008**: The public app MUST serve these read endpoints, with the shapes of SD §6.3.3 (the exported OpenAPI is authoritative):
  - `GET /v1/matches?from&to&sport&competition_id&team_id&satellite_ids&status`
  - `GET /v1/matches/{id}`
  - `GET /v1/live`
  - `GET /v1/satellites`
  - `GET /v1/satellites/{id}/channels?category&q`
  - `GET /v1/channels/{id}`
  - `GET /v1/competitions` and `GET /v1/competitions/{id}`
  - `GET /v1/teams/{id}` and `GET /v1/teams?q`
  - `GET /v1/rights-holders?satellite_id&competition_id` and `GET /v1/rights-holders/{id}`
  - `GET /v1/commentators/{id}`
- **FR-009**: Every response MUST use the envelope `{"success", "data", "error": {"code", "message"}, "meta"}`, with stable error codes, ISO-8601 UTC times and integer ids. Every query parameter is validated, with enum checks and length caps.
  - These lists return whole, in one response: matches, live, satellites, one satellite's channels, competitions and rights holders.
  - A `/v1/matches` window is capped at 8 days; a longer window is a validation error.
  - Only team search (`GET /v1/teams?q`) pages, with `limit` and an opaque `meta.next_cursor`.
- **FR-010**: Every GET MUST return an `ETag` built from `dataset_versions` and answer a matching `If-None-Match` with `304`. Invalidation happens only by bumping a version.
- **FR-011**: Match status MUST be honest from D1 on (constitution II):
  - Snapshot matches start with `status_source = clock`.
  - A clock-sourced match is `live` from kickoff to kickoff + 120 min and `finished` after that, always with `estimated: true` and never with a score or minute (SD §6.2.3).
  - A match with an unknown kickoff (`time_tbd`) has no derived status beyond `scheduled`.
- **FR-012**: Match detail MUST list the manual broadcasters and the preferred carriages first: carriages on the default satellites (O10: Nilesat + Badr) or marked show-in-match. Every satellite carriage follows in `carriages`. Channels hidden on that match, or hidden by name everywhere, MUST NOT be returned.
- **FR-013**: The admin app MUST be a separate application, and no admin route may exist on the public app. Its `v1` OpenAPI MUST declare the A1 auth endpoints (log in, refresh, log out, current admin), with stable error codes for invalid credentials and lockout. Their implementation comes on D2; until then they answer with a not-implemented error in the envelope.
- **FR-014**: The public and admin OpenAPI documents MUST be exported from the code and tagged `v1` by 13:00 on D1. After the tag, changes are non-breaking and made only by B1. Non-breaking means no path, operation, field, enum value or error code is removed or renamed, no type or format changes, and no new input is required.
- **FR-015**: Every read endpoint MUST have contract tests against the exported OpenAPI, run on a real PostgreSQL 16, never SQLite.
- **FR-016**: `/healthz` MUST report the database and Redis, and fail when either is down.
- **FR-017**: The public API MUST allow CORS only from the PWA's `web.app` and `firebaseapp.com` origins.

#### Servers, network and CI (Lane B2)

- **FR-020**: `infra/compose/vps1.yml` MUST define Caddy, `api-public`, `api-admin`, PostgreSQL 16 and Redis 7. `vps2.yml` MUST define the worker processes and the single `beat` of SD §6.1. Every image is `linux/arm64`. PostgreSQL and Redis listen only on private interfaces, with passwords. Secrets come only from host `.env` files (mode 600).
- **FR-021**: The Caddyfile MUST:
  - serve `api.`, `media.` and `app.<ip1>.sslip.io` with Let's Encrypt;
  - serve `https://10.8.0.1` on `wg0` with `tls internal`;
  - set HSTS, `nosniff` and `Referrer-Policy: strict-origin-when-cross-origin` everywhere, plus `X-Frame-Options: DENY` on the admin site;
  - compress responses;
  - serve media with `immutable` cache headers.
- **FR-022**: WireGuard MUST run as a hub on `10.8.0.1/24`, with peers for the owner and CI. The repository holds templates only, never keys.
- **FR-023**: Firewall rules MUST match SD §7.2 and persist across reboots. Port 22 closes to the public only after the OCI serial console has been tested.
- **FR-024**: `backend.yml` MUST, in order:
  1. run ruff, mypy and pytest with a PostgreSQL service;
  2. export `openapi.json` and regenerate the Dart and TS clients, failing if they're stale;
  3. on `master` only: build `linux/arm64`, push to GHCR, and deploy over WireGuard (migrations as a one-off container, then `compose pull && up -d`, then `/healthz`, with automatic rollback to the previous image tag).
- **FR-025**: `app.yml` MUST run `flutter analyze` and `flutter test` and publish a `prod`-flavor debug APK artifact, which calls VPS-1. `pwa.yml` MUST deploy the web build to a Firebase Hosting preview channel.
- **FR-026**: The `admin/` checks (tsc, eslint, vitest, build) and the `infra/` checks (Compose and Caddyfile validation) MUST run on PRs that touch those folders. The admin isn't deployed on D1.
- **FR-027**: gitleaks MUST run on every PR and fail it when it finds a secret.

#### Admin (Lane A)

- **FR-030**: `admin/` MUST be React 18, Vite, TS strict, Tailwind v3 bound to `tokens.css` / `tokens.ts` (no arbitrary values), React Query, React Hook Form + Zod, and React Router. The root is `<html lang="ar" dir="rtl">`, and fonts are bundled.
- **FR-031**: The API client and Zod schemas MUST be generated by Orval from the `v1` admin spec. Prism serves that spec, with examples for success, invalid credentials and lockout. Generated files are never edited by hand.
- **FR-032**: `SidebarNav`, `DataTable`, `Field`, `StatusChip` and `Toast` MUST each be built once and implement every state in their README, with visible keyboard focus. Each state has a Vitest test.
- **FR-033**: The A0 shell MUST have the right-hand sidebar with the PB §10 A0 sections (V2 items marked as such), and a top bar with global search and the signed-in user and role.
- **FR-034**: A1 MUST show email + password and «سجل دخول للوحة التحكم», plus the error and lockout states from the Login board. It maps `error.code` to Arabic copy and never shows `error.message`. Any access token is held in memory only, never in browser storage.

#### App (Lane M)

- **FR-040**: `app/` MUST have the `dev`, `staging` and `prod` flavors, each built with `--dart-define-from-file=env/<flavor>.json`. These files hold public values only, and the package id is `com.madarsat.app` (O1). Their API and media hosts follow SD §9: `dev` → local Compose, `staging` → a LAN backend, `prod` → VPS-1.
- **FR-041**: The app MUST follow the feature-first `data/domain/presentation` layout of SD §5.1. Riverpod (+ generator) is the only state library, and go_router has every PB §8.4 route stubbed.
- **FR-042**: Colors, type, spacing and radii MUST come only from the generated `madar_tokens.dart`. Changa, IBM Plex Sans Arabic and IBM Plex Mono are bundled and never fetched at runtime.
- **FR-043**: `MatchRow`, `StatusBlock`, `FrequencyReadout`, `CarriageRow`, `AccessBadge`, `DateStrip`, `MadarBottomNav`, `MadarTopBar`, `EmptyState`, `Skeleton` and the Logo component (`BrandMark`, `TeamCrest`, `LogoTile`) MUST each be built once, under that name, and implement every state in their README. `FrequencyReadout` stays a dark, LTR well in both themes. `StatusBlock` shows the estimated-live state without a score or minute. `MatchRow` and `CarriageRow` each read as one Arabic screen-reader label (PB §13.8).
- **FR-044**: Each component in FR-043 MUST have golden tests in RTL, in both themes, at 1.0× and 1.3× text scale.
- **FR-045**: A gallery route MUST show every FR-043 component in its states. It exists in every debug build, whatever the flavor, and never in a release build.
- **FR-046**: The network layer MUST be Dio plus the Retrofit client generated (swagger_parser + freezed) from the `v1` tag, with the base URL taken from the flavor's bundled default. Hand-written API types MUST NOT exist.
- **FR-047**: A drift schema for matches MUST exist and round-trip a `MatchSummary`.
- **FR-048**: The matches route MUST request `/v1/matches` for the device's local day, sent as UTC bounds. It renders unstyled rows with local kickoff times in Western digits, `EmptyState` when there are no matches, and an error state chosen by `error.code` on failure.

#### All lanes

- **FR-050**: `tasks.md` MUST have the sections `## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M` and `## Done check`. The Done check is copied word for word from Appendix A, row 001.
- **FR-051**: Each lane MUST change only its own folders (delivery-plan §4) and tick only its own section. Generated files (the API clients, Orval output and the token files) are never edited by hand.
- **FR-052**: No secret, snapshot data file (`migration/data/`) or old Firebase config MUST be committed.
- **FR-053**: Tests MUST be written and seen failing before the code they cover, for: time conversion and local-day bounds, frequency parsing, the clock status rule, the envelope and contract, and bidi/digit formatting (constitution, Test-first).
- **FR-054**: Coverage on D1 MUST meet the MVP bar of delivery-plan §7:
  - **Backend:** ≥ 70 % on `domain/`, `adapters/` and `services/`, plus contract tests on `/v1`.
  - **Admin:** Zod schemas for every response, and tests for every component state.
  - **App:** unit tests for the formatters and repositories, plus goldens for the signature components in both themes at 1.3×.

  The 80 % bar returns on D11 (constitution v1.1.0, Quality Gates).

### Key Entities *(include if feature involves data)*

- **Match**: one fixture. It has a UTC kickoff (or "time to be confirmed"), a competition and stage, home and away teams (by id, or by displayed name only), a status with its source and an estimated flag, an optional score, and links to the channels carrying it. Matches are never deleted.
- **Team / Competition / Commentator**: named entities with normalized names, optional media, and external ids per source.
- **Satellite**: Arabic and English names, a slug, an orbital position (east positive), and best and worst reference frequencies.
- **Channel (carriage)**: a satellite, terrestrial or platform entry. It has a frequency (MHz, polarization, symbol rate) or a note, access (`free` / `encrypted`), beam and category, and edits can lock its fields against importers.
- **Rights holder**: a broadcaster with its competitions and carriages.
- **Media asset**: one rehosted file per content hash, keeping the URL it came from.
- **Source / external id**: where a record came from, and its id there, so imports upsert instead of duplicating.
- **Dataset version**: a counter per dataset. ETags are built from it, and invalidation bumps it.
- **Admin user, refresh token, audit entry; device, device follow, outbox row; import run**: their tables are created today. Their behavior arrives on D2 (admin auth) and D3 (devices, follows, push, imports).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The contract is tagged `v1` at or before 13:00 on D1. From then until the end of D1, a diff against the tag shows zero breaking changes.
- **SC-002**: The snapshot load reconciles 100 %. For every source collection, loaded + merged + skipped (each with a reason) equals the source rows, and zero stored or served values contain a card-sharing label.
- **SC-003**: 100 % of the FR-008 endpoints pass their contract tests. A `304` revalidation is ≤ 1 KB, and a full local day of matches is ≤ 60 KB compressed.
- **SC-004**: Zero API responses point at the old media hosts, and 100 % of media URLs are absolute URLs on the Madar media host.
- **SC-005**: A merge to `master` that touches `backend/` is live on VPS-1 within 15 minutes, with no manual step on a server. A deliberately failing health check restores the previous version without anyone acting (demonstrated once).
- **SC-006**: `master` has a green CI run in each of the four folders at the end of D1. Every PR is scanned for secrets, and a planted test secret is blocked.
- **SC-007**: All 10 app signature components pass their goldens in RTL, in both themes, at 1.0× and 1.3×. All 5 admin components have a passing test for every state their README lists.
- **SC-008**: An automated check finds zero raw color, pixel-size or font-name literals in app widget code and admin component code.
- **SC-009**: From the internet, only 80/tcp, 443/tcp and 51820/udp answer on VPS-1, and every public host presents a valid certificate with the SD §8 headers.
- **SC-010**: The day's **done check** passes, word for word from delivery-plan Appendix A: *"VPS-1 serves `/v1` with snapshot data over HTTPS; contract tagged `v1`; admin login screen renders against the mock; the app shows the component gallery (goldens pass) and loads `/v1/matches`; CI green in all four folders"*.

## Assumptions

- **Day 0 is complete:**
  - both OCI Ampere VPSs exist with reserved public IPs (A2);
  - the Firebase project, its web app and Hosting are set up;
  - GHCR is usable;
  - the GitHub Actions secrets for the CI WireGuard peer, the deploy SSH key and Firebase deploy are in place.

  Anything missing is a blocker for B2 and is resolved first.
- **The MVP test bar applies** (owner decision, 2026-10-29). D1–D10 use delivery-plan A4 and §7, and 80 % returns on D11. Constitution v1.1.0 amended its Quality Gates to match.
- **The default branch is `master`.** It is never renamed to `main` (delivery-plan §5.1). The pipelines deploy from `master`, which is protected before the first D1 merge.
- **The A1 auth shapes are part of the D1 contract.** The brief has A1 render error and lockout states against the mock of the `v1` admin spec, and the constitution forbids hand-written API types. So the admin spec tagged at 13:00 declares the auth endpoints' requests, responses and error codes (FR-013). D2 implements them without changing those shapes.
- **The clock status rule moves to D1 on the read side** (FR-011). Constitution II (non-negotiable) forbids showing a finished match as `scheduled`, and the constitution outranks the delivery plan. D2 keeps the admin manual override and the shared `/v1/live` cache.
- **The snapshot is refreshed before the D1 load**, so it covers the current week, using the README's refresh command. It is copied to VPS-1 out of band and never committed.
- **O1, O3 and O10 use their documented defaults.** The package id is `com.madarsat.app`. Card-sharing labels are dropped. The default satellites are Nilesat + Badr.
- **Brand.** The wordmark in `MadarTopBar` stays «مدار», as drawn in the design package. Madar Sat / مدار سات is the product and store name.
- **`/v1` is public from D1 without rate limits until D3** (owner decision, 2026-10-29). The data is already public, the sslip.io name isn't published, and nothing is announced before D4. This departs from constitution V (rate limits on public endpoints). `plan.md` records it under Complexity Tracking, and reviews on D1–D2 treat it as accepted, not as a finding. The per-IP and per-device limits land on D3 as the brief schedules.
- **Remote Config isn't wired on D1.** Hosts come from the flavor's bundled defaults, and Remote Config arrives on D3.
- **The PWA preview channel only proves the deploy pipeline on D1.** The app's D1 check runs the `prod`-flavor debug APK natively.

### Out of scope (later days)

- **D2:** admin API logic, auth implementation, CRUD and uploads; the manual status override; the ysscores adapter and the Firestore bridge; the styled S2–S5 and stale-while-revalidate from drift; the closed-test build.
- **D3:** devices and follows endpoints, reminders, the outbox dispatcher, the Redis response cache, rate limits (see Assumptions), LiveSoccerTV, backups, Uptime Kuma, onboarding, push, Remote Config.
- **D4:** admin deploy on `wg0`, load tests, the public PWA.
- **Later:** search, channel delta sync, feeds.

### Dependencies between lanes today

- A and M generate their clients only after B1's 13:00 tag. Before then, they build tokens, the scaffold and components.
- B1's VPS-1 deploy needs B2's Compose, Caddy, WireGuard and `backend.yml`. B1 verifies locally until those are merged.
- The "CI green in all four folders" part of the done check needs each lane's checks passing in B2's workflows.
