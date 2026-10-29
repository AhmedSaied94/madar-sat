# Research: D1 · Foundation

Phase 0 of [plan.md](plan.md). Each entry is a decision the lanes build on. The stack is fixed by the constitution, so this file covers how to use it, not which stack to pick. Exact package versions are pinned in each folder's lockfile on D1; a version named here is a floor, not a pin.

## Contract (Lane B1, frozen at 13:00)

### R1. Paging and list shapes

- **Decision:** Lists return whole, except team search.
  - Whole lists: matches (window ≤ 8 days), live, satellites, one satellite's channels, competitions, rights holders.
  - Paged: `GET /v1/teams?q` only, with `limit` (1–50, default 20) and an opaque `meta.next_cursor`.
- **Rationale:** This is the clarification answer. Every whole list is bounded. The biggest satellite in the snapshot (Hotbird 13.0E) has 189 channels, about 10 KB gzipped, and one local day of matches stays well under the 60 KB budget. One ETag per list keeps revalidation at one request.
- **Alternatives:** Paging every list (rejected: the client loops for no gain). Paging later (rejected: it silently truncates lists for builds that ignore the cursor).

### R2. Personal channel line on match rows

- **Decision:** `GET /v1/matches` takes an optional `my_satellite_ids` (≤ 32 ids). It only ranks results and never filters them. It is separate from `satellite_ids`, which filters (S4). `broadcast.headline` holds ≤ 2 entries, ranked:
  1. on `my_satellite_ids`, or on `satellite_ids` when filtering;
  2. on the default satellites (O10: slugs `nilesat-7-0w`, `badr-26-0e`) or `show_in_match`, when `my_satellite_ids` is absent;
  3. free before encrypted;
  4. `channels.sort_order`, then `id`.

  Each headline entry carries its satellite, access and tuning, so S4 rows can show a readout without another call.
- **Rationale:** PB S2 asks for "ones on my satellites first, free first", and My satellites live on the device (SD §5.1). The server can only rank them if it is told which they are. Principle I requires the answer on the row.
- **Alternatives:** Sending every carriage per match (rejected: the payload breaks the 60 KB budget). Ranking on the client from a per-satellite summary (rejected: a bigger shape for the same result).

### R3. Clock status and the `estimated` flag

- **Decision:** A pure domain function `derive_status(stored, now)` runs on the read path for rows with `status_source = 'clock'`:
  - no kickoff (`time_tbd`) → `scheduled`;
  - `now < kickoff` → `scheduled`;
  - `kickoff ≤ now < kickoff + 120 min` → `live`;
  - `now ≥ kickoff + 120 min` → `finished`.

  A clock-derived `live` or `finished` is `estimated: true`; `scheduled` is `estimated: false`, because nothing is being guessed yet. Every clock row has `score`, `minute` and `period` null. A DB CHECK enforces the same rule (data-model.md), so even a bad write can't attach a score to a clock row. Stored `status` stays `scheduled` for clock rows; `feed` and `manual` rows are returned as stored. Snapshot `is_live` flags are ignored (spec Edge Cases).
- **Rationale:** Constitution II and spec FR-011. Deriving at read time needs no scheduler on D1 and never goes stale.
- **Alternatives:** A periodic job writing derived statuses (rejected: there are no workers on D1, and it adds a stale window). Keeping `scheduled` until D2 (rejected: it violates Principle II).

### R4. ETags, `304` and time

- **Decision:** Weak ETag `W/"<first 16 hex of sha256>"` over:
  - the route id and the normalized query;
  - the versions of the datasets the endpoint reads;
  - a hash of `MEDIA_BASE_URL` and the contract version;
  - for endpoints whose payload carries clock-derived status, a time bucket: `floor(now / 60 s)` for matches, channel, team and commentator detail, and `floor(now / 15 s)` for match detail and live.

  The ETag is computed before the main query, so a `304` costs one small read of `dataset_versions`. Every GET sends `Cache-Control: no-cache`, so clients always revalidate.
- **Rationale:** Constitution VI requires version-built ETags. Clock statuses change with time, not data, so a version-only ETag would serve a stale "scheduled" with a `304`. Weak ETags survive Caddy's response compression. The time bucket changes the ETag only on the freshness cadence SD §6.3.2 already sets.
- **Alternatives:** A body-hash ETag (rejected: it builds the full response for every `304`). `max-age` caching (rejected: freshness targets need revalidation, and `304`s are ≤ 1 KB).

### R5. Matches whose kickoff time is unknown

- **Decision:** A `time_tbd` match is in a `/v1/matches` window when `match_date 12:00 Africa/Cairo` falls inside `[from, to)`. `MatchSummary` always carries `match_date`. Clients put these matches in the «موعد لم يُحدد» group of the local day the window represents.
- **Rationale:** SD §6.2.2 groups TBD matches by `match_date`. A midday anchor puts each one in exactly one local day for every time zone within ±11 h of Cairo, which covers the audience.
- **Alternatives:** Midnight anchors (rejected: a match lands in two local days, or none, around midnight).

### R6. Match detail sections

- **Decision:**
  - `broadcasts`: the manual broadcasters (`match_custom_broadcasts`, by slot) first, then the preferred carriages (default satellites or `show_in_match`), free first.
  - `carriages`: every visible satellite and terrestrial link, ordered by satellite priority, then free first, then `sort_order`.
  - `platforms`: `kind = 'platform'` links, grouped by region in the PB S3 order (الشرق الأوسط، أوروبا، آسيا، الأمريكتان، أفريقيا، أوقيانوسيا، أخرى), then by country.
  - Hidden links are never returned: `match_channels.is_hidden`, plus names in `hidden_channel_names` matched on `name_norm` or `ar_normalize(display_name)`.
  - `local_broadcaster_eg` is in the contract as nullable and always `null` on D1, because no column holds it yet (YallaKora, D5). `events` is `[]` and `lineups` is `null` until D5.
- **Rationale:** This follows the SD §6.3.3 shape. Declaring later fields now, as nullable or empty, keeps D5 additive and non-breaking.

### R7. Platform regions

- **Decision:** A curated, tested mapping in `backend/app/domain/regions.py`. Keys are `ar_normalize`d country names, including the English spellings, typos and region words in the snapshot (201 distinct values: «البرايزل», "United States", «الشرق الأوسط», «عالمي» and so on). Anything unmapped goes to «أخرى» and is logged once per load.
- **Rationale:** `channels` has no region column, and the snapshot's country text is messy. A table in code is the smallest correct step. A `region` column can come later (expand/contract) once admins edit countries.
- **Alternatives:** A migration adding `channels.region` now (rejected: no admin edits it before D2–D3, and it isn't in the D1 contract list).

### R8. Error codes and validation

- **Decision:**
  - Stable codes: `validation_error` (422, with `meta.errors[] = {loc, type}`), `not_found` (unknown route), one `<entity>_not_found` per detail endpoint, `method_not_allowed` (405), `not_implemented` (501), `internal_error` (500). `rate_limited` (429) is reserved for D3.
  - FastAPI's default 422 body and HTML error pages are replaced by the envelope.
  - Query caps:
    - `q` ≤ 64 characters;
    - id lists ≤ 32 entries;
    - `to − from` ≤ 8 days;
    - enums for `sport`, `status` and `category`.
- **Rationale:** Constitution VI (stable `error.code`), Principle V (validate every input), and the spec's edge cases.

## Data load (Lane B1)

### R9. Running revision `0001`

- **Decision:** `0001` reads `backend/alembic/sql/0001_base_schema.sql`, a byte-for-byte copy of `../old_app/migration/schema.sql` checked by a test that compares its SHA-256 with a recorded value. It runs `op.get_bind().exec_driver_sql(sql)` on a psycopg (v3) connection. Alembic runs synchronously through psycopg; the app uses asyncpg.
- **Rationale:** README "Applying the schema": asyncpg can't run multi-statement scripts.

### R10. Snapshot loader and media rehosting

- **Decision:**
  - **Load:** `python -m app.cli load-snapshot --snapshot-dir <path>` runs in one transaction through psycopg. It upserts by `legacy_id`, or by natural keys where there is no `legacy_id` (commentators by `name_norm`, presets by `name`, `livesoccertv_teams` by its unique key, links by their PKs). Merges are deterministic, so a re-run produces the same rows. The last statements bump every dataset version. The command writes the load report ([contracts/load-report.md](contracts/load-report.md)) and exits non-zero when the counts don't reconcile.
  - **Rehost:** `python -m app.cli rehost-media` is a separate, re-runnable command. It skips any `original_url` already in `media_assets`.
    - Allowlist: `pub-01ffc6064b9b435aa726a53a561a6f53.r2.dev` (the old R2 public bucket, 5,973 URLs in the snapshot) and `imgs.ysscores.com`. It comes from `MEDIA_REHOST_ALLOWED_HOSTS`, not code.
    - Fetching: httpx with redirects off, 10 s timeout, 5 MB download cap and 4 concurrent downloads.
    - Encoding: Pillow to WebP ≤ 512 px with metadata stripped; `ffmpeg -t 30` to AAC in MP4.
    - Output: written under `MEDIA_ROOT` at `<kind>/<sha[:2]>/<sha>.<ext>`.
  - **Where it runs:** on VPS-1, as one-off containers of the backend image (which includes ffmpeg), with `/srv/media` mounted.
- **Rationale:** SD §6.9, §10 and README rules 1–17. Splitting rehosting from the load keeps a slow or failing CDN from blocking the data. Both are idempotent (FR-004).
- **Alternatives:** Celery tasks (rejected: no workers run on D1). Rehosting inside the load transaction (rejected: holds the transaction open over network calls).

### R11. Test data without committing the snapshot

- **Decision:** `backend/tests/fixtures/snapshot/` holds a small synthetic snapshot in the real file format. Every README edge case has a row: Cyrillic `Н`, `"--:--"`, `⚽`, «غير مدرج», the duplicate `ysMatchId`, orphan ids, ambiguous team names, `" Eutel 16.0E"`, `DVB T2`, card-sharing labels. Tests load it into PostgreSQL 16. The real snapshot is used only for SC-002 runs, locally and on VPS-1.
- **Rationale:** Constitution V and D15: `migration/data/` is never committed.

## Infrastructure and CI (Lane B2)

### R12. Hosts, networking and Docker

- **Decision:**
  - **Caddy** runs with `network_mode: host`. It serves `api.`, `media.` and `app.<ip1>.sslip.io` on the public interface, and a `https://10.8.0.1` site with `bind 10.8.0.1` and `tls internal`.
  - **APIs:** `api-public` publishes to `127.0.0.1:8000` and `api-admin` to `127.0.0.1:8001`. Only the `wg0` site proxies `/admin/api` to the admin API.
  - **Data stores:** PostgreSQL and Redis publish only on the VCN private IP (`${VCN_IP}:5432`, `${VCN_IP}:6379`), with passwords from `.env`.
  - **Host setup:** `infra/scripts/bootstrap-vps.sh` is idempotent. It installs Docker and WireGuard, creates the `deploy` user, makes the `/srv` directories, and applies `infra/firewall/vps<N>.rules` via `netfilter-persistent`, inserting ACCEPT rules before OCI's default REJECT.
- **Rationale:** Docker-published ports bypass the host's INPUT chain, so the only safe exposure control is binding each published port to a specific address. Binding the admin site to `10.8.0.1` keeps it off the public listener entirely (constitution V, D10).
- **Alternatives:** Ports published on `0.0.0.0` behind a firewall (rejected: Docker's DNAT skips INPUT rules). Caddy in bridge mode (rejected: it can't bind the `wg0` address).

### R13. Image build, deploy and rollback

- **Decision:**
  - **Build:** `backend.yml` builds `linux/arm64` with buildx and QEMU on `ubuntu-24.04`, with the GHA layer cache. A repository variable `ARM_RUNNER` switches to a native arm64 runner when one is available.
  - **Push:** images go to `ghcr.io/<owner>/madar-backend:<git-sha>`.
  - **Deploy:** the runner joins WireGuard (secret `WG_CI_CONFIG`), SSHes as `deploy` (secret `DEPLOY_SSH_KEY`), and runs `infra/scripts/deploy.sh <sha>`. That script:
    1. records the current tag;
    2. pulls the new image;
    3. runs `alembic upgrade head` in a one-off container, aborting before any container changes if it fails;
    4. runs `compose up -d`;
    5. polls `http://127.0.0.1:8000/healthz` for 60 s;
    6. on failure, restores the previous tag, runs `up -d` again and exits non-zero.

    A `concurrency: deploy-vps1` group stops two deploys from overlapping.
  - **Retention:** after a successful deploy, `actions/delete-package-versions` keeps only the newest 3 image versions: current, previous for rollback, and one spare. The image is `python:3.13-slim` plus Debian `ffmpeg`, multi-stage, with no build tools in the final stage.
- **Rationale:** SD §9 and constitution IX. GitHub's free arm64 runners cover only public repositories, and QEMU works anywhere. GHCR is free for public packages, but private packages on the free plan get only 500 MB of storage. Retention keeps a private repo inside that at $0.

### R14. CI layout

- **Decision:** One workflow per folder, each filtered to its own paths.
  - **`backend.yml`:**
    - ruff, mypy (strict), and pytest against a PostgreSQL 16 service;
    - `python -m app.cli export-openapi` writes `backend/openapi/{public,admin}.json` and fails if the committed files differ;
    - a `clients` job (Node + Flutter) regenerates the Orval and swagger_parser clients from those files and fails on `git diff`;
    - build and deploy on `master` only.
  - **`admin.yml`:** tsc, eslint, vitest, build, and the token-copy check.
  - **`app.yml`:**
    - analyze, test (goldens included), the token-copy and literal checks;
    - a `prod`-flavor debug APK artifact.
  - **`pwa.yml`:** `flutter build web` for `prod` → Firebase Hosting preview channel `master` (expires in 30 days) via `FirebaseExtended/action-hosting-deploy`, using secret `FIREBASE_SERVICE_ACCOUNT`.
  - **`infra.yml`:** `docker compose config -q` with `infra/compose/example.env`, `caddy validate`, shellcheck.
  - **`gitleaks.yml`:** the gitleaks CLI container on every PR.
- **Rationale:** These are the constitution's CI gates, with client regeneration inside `backend.yml` as the table requires. The gitleaks CLI avoids the GitHub Action's license requirement for organization accounts.
- **Contract-change PRs:** generated client folders are written only by the generators. A B1 PR that changes the contract carries the regenerated clients, which is the one sanctioned cross-folder write (D14).

## Admin (Lane A)

### R15. Tokens, fonts and the generated client

- **Decision:**
  - **Tokens and fonts:** `admin/src/styles/tokens.css`, `admin/src/styles/tokens.ts` and the font files are verbatim copies from `madar-design/design-system/`. A check script fails CI when a copy differs from its source.
  - **Tailwind:** `admin/tailwind.config.ts` maps theme colors to `var(--<token>)`, so `data-theme` switches the theme. Spacing, radii and shadows come from `tokens.ts`. `eslint-plugin-tailwindcss` `no-arbitrary-value` is an error.
  - **Client:** Orval generates React Query hooks plus Zod schemas into `admin/src/api/generated/`, and MSW handlers into `admin/src/api/mocks/` for Vitest.
  - **Manual mock:** Prism (`@stoplight/prism-cli`) serves `backend/openapi/admin.json`. In dev builds only, a `?mock=<example>` URL parameter adds `Prefer: example=<example>`, so A1's error and lockout states can be shown on demand.
- **Rationale:** Constitution IV says tokens are generated once in the design package, so a copy check keeps them identical without editing the generator. Prism serves the real spec's named examples, and MSW gives deterministic tests.

## App (Lane M)

### R16. Flavors, hosts and HTTPS

- **Decision:**
  - **Entry points and config:** `lib/main_dev.dart`, `main_staging.dart` and `main_prod.dart`, each with `env/<flavor>.json` holding public values (API and media base URLs).
  - **Hosts:**
    - `prod` → `https://api.<ip1>.sslip.io` and `https://media.<ip1>.sslip.io`;
    - `dev` → `https://localhost:8443`, a local Caddy with `tls internal`, reached from a device with `adb reverse`;
    - `staging` → the LAN Caddy over HTTPS.
  - **Local CA:** debug builds trust the local Caddy root CA through a `debug-overrides` network security config; release builds trust only system CAs. No flavor uses cleartext HTTP.
  - **Gallery:** registered only when `kDebugMode` is true.
- **Rationale:** This is the clarification answer (SD §9 hosts, gallery in debug builds). It also follows constitution V (HTTPS everywhere) and the owner's "never HTTP" rule.

### R17. Generated client, drift and fonts

- **Decision:**
  - **Client:** swagger_parser reads `backend/openapi/public.json` and writes Retrofit + freezed sources into `app/lib/core/network/generated/`, then build_runner runs.
  - **Dio:** one Dio instance with an ETag interceptor. The interceptor is created on D1; the stale-while-revalidate repository arrives on D2.
  - **drift:** a `matches` table holding the `MatchSummary` fields (JSON columns for nested parts), with web support through `drift_flutter` (SQLite WASM). It has a round-trip test.
  - **Fonts and tokens:** fonts are bundled from the design package under the family names in `MadarFonts` (`Changa`, `IBM Plex Sans Arabic`, `IBM Plex Mono`). `madar_tokens.dart` is a verbatim copy, checked by CI.
- **Rationale:** SD §5.1, P6, constitution VI and VIII.

### R18. Golden tests

- **Decision:**
  - **Harness:** Flutter's built-in `matchesGoldenFile`, with the bundled fonts loaded through `FontLoader` in `test/flutter_test_config.dart`. A helper renders each component state in four variants: RTL × {light, dark} × text scale {1.0, 1.3}.
  - **Where goldens are made:** goldens are generated and checked in one pinned Linux container image (`ghcr.io/cirruslabs/flutter:<pinned>`), locally and in CI, so font rasterization is identical.
- **Rationale:** No new dependency is needed, and one rendering environment avoids per-machine golden drift.
- **Alternatives:** `alchemist` (rejected: the built-in API covers this, and constitution "Simplicity" asks for justification of new dependencies).

### R19. Western digits and time formatting

- **Decision:** All numbers go through `MadarFormat`, which uses the `en` number formatting with tabular figures. Times render as `9:00 م` / `21:00` with `ص`/`م` markers built explicitly; they are never left to the `ar` locale. LTR islands use `Directionality(textDirection: TextDirection.ltr)`. These are tested first.
- **Rationale:** Constitution III.

## Literal checks (SC-008)

### R20. Detecting hard-coded visual values

- **Decision:** Each client has a check script in its own folder, run by its workflow:
  - `app/tool/check_literals.sh`: `rg` over `lib/` outside `core/theme/` and `generated/`, failing on `Color(0x`, `Colors.`, `fontFamily:`, and numeric literals inside `EdgeInsets`, `SizedBox`, `BorderRadius` and `TextStyle(fontSize:`.
  - `admin/scripts/check-literals.sh`: fails on hex colors, `px` values and `font-family` in `src/` outside `styles/`. The eslint `no-arbitrary-value` rule complements it.
- **Rationale:** Constitution IV. Grep checks are cheap, local and explicit.

## Owner-approved deviation

### R21. No rate limits on `/v1` until D3

- **Decision:** `/v1` is public from the first deploy with no rate limit (clarification answer). It is recorded in plan.md Complexity Tracking. The D3 work adds Redis sliding-window limits keyed by device token, else by client IP (`X-Forwarded-For` trusted from Caddy only).
- **Rationale:** The data is public, the host isn't published, and nothing is announced before D4.
