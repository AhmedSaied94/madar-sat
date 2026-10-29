# Madar Sat (مدار سات) Constitution

## Core Principles

### I. The Answer First

Madar Sat exists to answer one question: which channel, on which satellite, at what frequency,
and can my dish receive it (product doc §1, §8.1).

- The channel, satellite and frequency for a match MUST be reachable in ≤ 2 taps from launch.
  Part of the answer (up to 2 channel names, free first) MUST be visible on the match row.
- Carriage rows MUST show the frequency readout collapsed, with no tap needed to see it.
- Every channel list MUST put the user's **My satellites** first and free channels first. When
  the user has chosen none, the documented default (product doc S1.3, O10) applies, and the
  UI prompts «حدد أقمارك».
- Ads MUST NEVER block the answer. The interstitial fires only on return from match detail or
  on switching to a secondary tab, never before an answer opens, never within 60 s of launch,
  at least 90 s apart, and at most 4 per session (P5, Remote Config `ads`). The banner is
  Android-only and above the bottom nav. It takes space only once an ad has loaded, and it
  never appears in onboarding, settings, the privacy policy, or while a sheet or search is
  open. The PWA is ad-free and its layouts MUST look complete without a banner slot.
- A screen with no data MUST explain why and offer the next action. Example: no channels shows
  «لم تُضف القنوات الناقلة بعد» with a follow CTA.

Rationale: Sat Air hid frequencies behind expansion, ignored the user's dish and put an ad in
front of the answer. Those are the failures this product replaces.

### II. Honest Data (NON-NEGOTIABLE)

The UI and API MUST NEVER present a guess, a stale copy or an invented value as fact.

- Match status MUST follow the state machine in system-design §6.2.3. `status_source` is
  `feed`, `manual` or `clock`. A manual status wins until an admin clears it.
- A clock-derived status MUST carry `estimated: true` (P4). Clients MUST show «مباشر» for it with
  the quieter estimated treatment and MUST NOT show a score or minute.
- `kickoff_at` MUST be stored as UTC `timestamptz`. Source wall-clock times are converted from
  their real zone (`AT TIME ZONE 'Africa/Cairo'` for the Arabic sources). An unknown kickoff
  sets `time_tbd` and shows «لم يُحدد».
- Clients MUST group matches by the user's local date, computed from `kickoff_at` (P2).
  `match_date` is for ingestion only.
- Cached data older than its freshness target MUST show its age (StaleHint or OfflineBanner).
  Cached data MUST NEVER be presented as live.
- Unknown values stay unknown. Placeholders (`""`, `⚽`, `غير مدرج`) become NULL. Logos fall
  back to the documented placeholders. Nothing is filled with a plausible guess.
- Entity resolution MUST NOT guess beyond the documented rules (exact alias, then
  disambiguation within the competition). Anything else goes to `unresolved_names`.
- Matches MUST NOT be deleted; they are history (system-design §6.2.5).

Rationale: Sat Air showed "live" for two hours whatever happened. Users act on this data (they
align a dish, tune a receiver, open the app at kickoff), so a confident wrong answer costs more
than an honest gap.

### III. Arabic-Native, RTL First

Arabic is the layout direction everywhere: app, PWA, desktop web and admin.

- Layouts MUST be RTL: forward chevrons point left, back arrows point right, the home team sits
  on the right, tabs run right to left, and the desktop nav rail and admin sidebar sit on the
  right. The admin root is `<html lang="ar" dir="rtl">`.
- These MUST be rendered as isolated LTR islands (`TextDirection.ltr` / `<bdi dir="ltr">`) and
  never concatenated into Arabic strings: frequencies, Latin channel and satellite names,
  orbital positions, source codes and feed lines. A long island truncates at its own end.
- Scores and other composite strings MUST be built from isolated parts, with each number beside
  its own team. A raw `1 - 0` string MUST NOT appear in RTL text, including push copy
  (product doc §11).
- All digits MUST be Western (0–9), with tabular lining figures for times, scores, minutes,
  counts and frequencies. Formatting MUST NOT rely on the `ar` locale default, which can emit
  Arabic-Indic digits.
- Every user-facing string MUST be externalized (ARB in Flutter). v1 ships Arabic only. Copy
  MUST follow the voice and glossary in product doc §14 (short, pan-Arab MSA). Clients map API
  `error.code` to Arabic copy and never show `error.message` to users.
- Composite rows MUST carry Arabic screen-reader labels (product doc §13.8).

Rationale: the audience reads Arabic, and the data mixes Arabic with Latin brand names and
numeric readouts. Without explicit isolation the bidi algorithm reorders frequencies and scores
into wrong answers.

### IV. Tokens and Components Own the Visuals

The design package is the only source of visual values and component behavior.

- `madar-design/design-system/tokens.json` is the single source of truth for color, type,
  spacing, radii and shadows. The generated files (`tokens.css`, `madar_tokens.dart`,
  `tokens.ts`) MUST be regenerated with `generate_tokens.py` and MUST NOT be hand-edited.
- Widgets and components MUST NOT contain raw hex values, pixel sizes or font names. Flutter uses
  `context.madarColors`, `MadarText` and `MadarRadii`. The admin uses the token CSS variables
  and `tokens.ts`, with Tailwind bound to tokens and no arbitrary values.
- Each component in `design-system/components/INDEX.md` MUST be built once, under the same name
  (`MatchRow`, `StatusBlock`, `FrequencyReadout`, ...), implementing every state in its README
  (default, hover on web, pressed, focus, selected, disabled, loading, error).
- A screen MUST be built from its `SCREENS.md` row, PNG and HTML, and checked against the PNG.
  Mockup HTML MUST be rebuilt with real widgets, never pasted.
- Color semantics are fixed. `live` red is only for live matches. Errors, red cards, failures
  and deletes use `error`. There is one `accent` (volt) element per screen. `encrypted` is
  neutral with a lock, never an error color. Meaning is never carried by color alone.
- `FrequencyReadout` MUST stay a dark well with cyan IBM Plex Mono digits, LTR, in both themes.
- Both themes MUST be complete, with these minimums: WCAG AA contrast, touch targets ≥ 48 dp,
  layouts that survive 1.3× in-app font scale on top of the OS scale, reduced motion honored
  (no pulse or shimmer), and visible keyboard focus on web and admin.
- No emoji as icons. Logos sit in neutral frames. The fonts (Changa, IBM Plex Sans Arabic,
  IBM Plex Mono) MUST be bundled; the PWA never fetches fonts at runtime.

Rationale: the rebrand is meant to look intentional and consistent across Flutter and React.
Tokens and shared components are the only way two stacks stay visually identical.

### V. Trust Lives on the Server (NON-NEGOTIABLE)

Authorization is enforced on the server, and no client or commit ever holds a secret
(system-design §8, G7).

- The admin API MUST be a separate ASGI app (`app.admin:app`) bound to WireGuard `wg0`. Admin
  routers MUST NEVER be mounted on `app.public:app`, and Caddy has no public admin site. The
  admin panel, admin API and SSH are reachable only over WireGuard.
- Server secrets live only in host `.env` files (mode 600) and GitHub Actions secrets. Flutter
  `env/*.json` and admin builds hold public values only. No storage or API keys reach a browser.
  Media uploads go through the admin API.
- From `../old_app/`, only `migration/schema.sql` may be copied in. `migration/data/` and the old
  Firebase web config MUST NEVER be committed (D15).
- Admin auth works as follows:
  - passwords are argon2id with at least 12 characters, and there are no default credentials
    (the first admin is created by CLI);
  - login is limited to 5 attempts per 15 min per account+IP, with a lockout after that;
  - access JWTs last 15 min, held in memory;
  - refresh tokens last 14 days, rotate on use, are stored hashed and are revocable, and travel
    in an `HttpOnly; Secure; SameSite=Strict` cookie with a CSRF header;
  - a dependency on every admin route checks the role (`editor` / `admin`).
- Devices are anonymous, and there are no user accounts in v1. The device token is 256 random
  bits, generated by the server and stored there hashed. The client keeps it in
  `flutter_secure_storage` and sends `Authorization: Device <token>`. `DELETE /v1/devices/me`
  erases the device and its follows.
- Every request is validated by Pydantic, with enums and length caps (reports ≤ 280 chars). SQL
  goes through SQLAlchemy with bound parameters only; string-built SQL is forbidden.
- The admin relies on React escaping. Any `dangerouslySetInnerHTML` goes through DOMPurify, and
  the CSP is `default-src 'self'`.
- Rate limits are Redis sliding windows, keyed by device token, otherwise by client IP
  (`X-Forwarded-For` trusted from Caddy only). Per-IP limits MUST be generous, because CGNAT
  puts many users behind one IP.
- Scrapers and media rehosting use per-adapter host allowlists, no redirects to other hosts,
  size caps and timeouts (SSRF).
- Uploads get a magic-byte check and size caps (image ≤ 2 MB, audio ≤ 1 MB). Images are
  re-encoded to WebP ≤ 512 px with metadata stripped, and audio to AAC ≤ 30 s. Files are stored
  content-addressed and served with `nosniff`.
- HTTPS everywhere, with HSTS, `nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, and
  `X-Frame-Options: DENY` on the admin. Public CORS allows only the PWA's `web.app` and
  `firebaseapp.com` origins. Postgres and Redis listen only on private interfaces, with passwords.

Rationale: Sat Air checked the admin UID in the browser, kept R2 keys in browser storage and
gated the web app with a hash in public JS. None of that may return.

### VI. Contract-First API

The OpenAPI specs exported from FastAPI are the contract. Clients are generated from them, never
hand-written.

- Every response uses the envelope `{"success", "data", "error": {"code", "message"}, "meta"}`.
  `error.code` is a stable identifier that clients map to Arabic copy.
- Times are ISO-8601 UTC, IDs are integers, media URLs are absolute, and long lists use cursor
  pagination (`meta.next_cursor`).
- Every GET MUST return an `ETag`, and clients MUST send `If-None-Match`.
- The Dart client (Retrofit via `swagger_parser`, plus freezed models) and the admin TS client
  and Zod schemas (Orval) MUST be generated. CI regenerates both and fails when they are stale.
  Hand-written API DTOs MUST NOT exist.
- Every admin mutation MUST require `If-Match`, write `audit_log` (who, what, diff), bump the
  affected `dataset_versions`, and add the edited field names to `locked_fields`.
- Cache keys and ETags MUST be built from `dataset_versions`. Invalidation happens by bumping a
  version, never by deleting keys found by scan.
- Live data is served as one shared, cached `GET /v1/live` that clients poll (P3). No WebSockets.
- `/v1` changes MUST stay compatible with every app build ≥ `min_supported_build`. A breaking
  change needs a new version path, or raising `min_supported_build` once the new build is out.

Rationale: one PR can change an endpoint and both clients (D14). Generation and stale-checks
keep three codebases from drifting, and versioned caches keep admin edits visible in ≤ 60 s
without a publish step.

### VII. Idempotent, Observable Pipelines

Ingestion, live polling and push run unattended, so every task MUST be safe to retry and loud
when it fails (G3).

- Every source adapter MUST implement `SourceAdapter` (`name`, `allowed_hosts`, `fetch`, `parse`,
  `normalize`; system-design §6.6). `parse` MUST be pure and tested against saved raw pages.
  Raw pages are kept gzipped for 5 days.
- Records MUST be upserted by `(source, external_id)`. Importers MUST NOT write any field listed
  in `locked_fields`, and they remove only the `match_channels` links they added themselves.
- Each source MUST have:
  - per-host token-bucket rate limits;
  - exponential backoff with jitter on 429, 403 and 5xx;
  - a circuit breaker that pauses the source and alerts admins;
  - a zero-items alarm;
  - an `import_runs` record for every run.
- Every Celery task MUST use `bind=True`, `autoretry_for`, `retry_backoff`, `retry_jitter` and a
  bounded `max_retries`. Overlapping runs of a job are prevented with a Redis `SET NX EX` lock.
  Exactly one `beat` instance runs, ever.
- Push MUST go through the outbox. Producers only insert `notification_outbox` rows with a unique
  `dedupe_key`, and only the dispatcher talks to FCM. The dispatcher:
  - claims rows with `FOR UPDATE SKIP LOCKED`;
  - resolves the audience with `SELECT DISTINCT` over the server-mirrored `device_follows` (P1),
    so each device gets one push per event;
  - collapses by tag `match_<id>`;
  - deletes `UNREGISTERED` tokens.
- The live poller runs only when a match falls in the window (now − 150 min … now + 10 min).
  Quiet days cost nothing.

Rationale: the sources block, throttle and change layout (R1). Retries without idempotency
double-send goals, and failures without alarms leave stale fixtures nobody notices.

### VIII. Offline-Tolerant, Lean Clients

Clients show cached content first and stay within explicit budgets (G5, system-design §11).

- The Flutter app MUST use feature-first `data/domain/presentation` layers, with Riverpod
  (+ generator) as the only state library. Navigation is go_router and networking is Dio with
  the generated Retrofit client. Business logic lives in providers, not in widgets or `setState`.
- The offline cache MUST be drift (P6). Hive, Isar and SharedPreferences MUST NOT hold
  structured data. Secrets go only in `flutter_secure_storage`.
- Repositories MUST be stale-while-revalidate: emit the drift copy, then revalidate with
  `If-None-Match` (a 200 updates drift, a 304 changes nothing). Skeletons appear only on a true
  first load.
- Native-only capabilities (`AdsService`, `LocalNotifier`, `HomeWidgetUpdater`, `CrashReporter`,
  `InstallGuide`) MUST sit behind interfaces, with web no-ops chosen by conditional import.
  Feature code MUST NOT import those plugins directly.
- Lists that can grow (up to 171 channels on one match) MUST be virtualized.
- Budgets:
  - cached first screen < 1.5 s on a 4 GB Android;
  - home payload ≤ 60 KB gzipped, and a 304 ≤ 1 KB;
  - API p95 < 150 ms cached and < 400 ms uncached;
  - admin edit → client ≤ 60 s, and live score → client ≤ 45 s;
  - crash-free sessions ≥ 99.5 %.
- API and media hosts, forced/soft update builds, maintenance, ad pacing, feature flags and the
  live poll interval MUST come from Firebase Remote Config, with bundled defaults. Unfinished
  features ship behind a `features` flag.
- The admin MUST use React 18, Vite, TS strict, Tailwind v3, React Query (no bare
  `useEffect` + fetch) and RHF + Zod. It is desktop-first at 1440 and usable at 1024.

Rationale: users are on low- to mid-range Android phones and flaky mobile networks, and the
whole backend runs on 1 OCPU. The cache has to carry the experience.

### IX. Zero-Cost, Boring Operations

Infrastructure MUST cost $0/month and stay operable by a small team (G6).

- Hosting is OCI Always Free (2 × Ampere A1 arm64), Firebase Spark and the Backblaze B2 free
  tier. Any recurring cost or plan change (a domain, O4; Blaze, O6; a licensed feed) MUST first
  be recorded as a decision in system-design §3.
- Every container image MUST be `linux/arm64`. Deployment is Docker Compose with Caddy, with no
  Kubernetes and no CDN (D9). VPS-1 runs the public app and data; VPS-2 runs the workers (D7).
- Public hosts are `sslip.io` names, and clients read them from Remote Config. Clients MUST NOT
  hardcode hosts beyond the bundled defaults.
- Backups: nightly `pg_dump` → restic → B2 (7 daily, 4 weekly, 6 monthly) plus the media copy.
  A restore MUST be tested monthly and recorded in the runbook.
- Uptime Kuma watches `/healthz` (DB + Redis), media, both PWA origins, and the Celery and backup
  heartbeats. Logs are structured JSON to stdout, with rotation.
- Deploys run `alembic upgrade head` as a one-off container, then `compose pull && up -d`, then
  check `/healthz`. A failed health check rolls back to the previous image tag automatically.

Rationale: there is no budget and no ops team. Free tiers and boring tools keep the product
alive, and tested restores keep the data alive when the single public box fails.

## Platform, Stack and Content Constraints

**Fixed stack.** These decisions are settled (system-design §3.1). For this repository they
override the owner's general stack defaults, such as Django or Hive/Isar.

| Area | Decision |
|---|---|
| Backend | FastAPI, SQLAlchemy 2 async, Alembic, Pydantic v2, Celery + beat, PostgreSQL 16, Redis 7. One package `backend/app`, two ASGI apps (D5) |
| App | Flutter for Android, desktop web and the iOS PWA (D2, D3) |
| Admin | React + Vite + TS + Tailwind + React Query, served on `wg0` (D4, D10) |
| Push / config | FCM everywhere (D12); Firebase Remote Config, not RTDB (D11) |
| Media | Stored on VPS-1 disk and served by Caddy, mirrored to the OCI bucket; offsite backup to B2 (D13) |
| Repo | One monorepo: `backend/`, `admin/`, `app/`, `infra/`, `docs/`, `.github/workflows/` (D14) |

**Platform limits** (system-design §5.3). iOS ships as the Flutter web PWA until an Apple account
exists. On iOS, push works only after "Add to Home Screen", so the app shows its install guide
instead. Reminders are server pushes in v1, not scheduled local notifications.

**v1 non-goals.** No user accounts, no video streaming, no English UI (strings stay
externalized), no multi-region HA. A feature that needs any of these needs an amendment.

**Content and legal.**
- Until O3 is decided, the system MUST behave as if card-sharing labels and BISS keys are
  dropped. That covers labels such as `Mega Share`, `Apollo`, `VIP` and «ليست مكسورة». They are
  not migrated, stored in API fields or shown. Access is only `free | encrypted`, plus the
  official provider or package.
- Third-party logos and voice clips keep their source in `media_assets.original_url`.
  Takedown requests are answered within 48 h.
- Privacy: anonymous devices, a data-deletion option, a privacy policy and the Play data-safety
  form. AdMob UMP consent is required for EEA/UK users. Analytics run only after consent where
  consent is required.

**Source-of-truth order.** This constitution comes first. Next, `docs/system-design.md` governs
architecture, API and security, and `docs/product-business.md` governs screens, copy and data.
Last comes `madar-design/` for visuals. When the docs and the design disagree, the docs win on
data and behavior and the design package wins on visuals. Specs cite these sources by section
and screen ID (S*, A*) instead of restating them.

## Development Workflow and Quality Gates

**Feature flow.** `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` (Constitution Check)
→ `/speckit-tasks` → `/speckit-implement`. Each spec names the product doc screens (S0–S20,
A0–A17) and the system-design sections it implements, along with their phase tags
([P], [V1], [V2], [V3]).

**Test-first.** The tests listed here MUST be written and seen failing before implementation.
Test tasks are mandatory in `tasks.md`.
- Domain rules: the status state machine and the estimated rule, time-zone conversion and
  local-day grouping, entity resolution, `locked_fields`, and outbox dedupe and audience.
- Adapter `parse`, tested against saved raw pages.
- Public and admin endpoints, as contract tests against the exported OpenAPI.
- Formatting of bidi islands and digits.
- Database tests run against a real PostgreSQL 16 service, never SQLite.
- Flutter widget tests for `MatchRow`, `StatusBlock` and the bottom nav run RTL, at 1.3× text
  scale, in both themes.
- Coverage follows the phased bar of delivery-plan §7 (assumption A4):
  - **MVP and V1 build-out (D1–D10):**
    - backend: line coverage ≥ 70 % on `domain/`, `adapters/` and `services/`, plus contract
      tests on `/v1`;
    - admin: Zod schemas for every response, plus a Playwright smoke test (log in → edit a
      match → see the change) once those flows exist;
    - app: unit tests for formatters (time, digits, frequency, bidi) and repositories, plus
      golden tests for the signature components in both themes at 1.3× text scale.
  - **From D11 on:** line coverage MUST be ≥ 80 % in each of `backend/`, `admin/` and `app/` on
    every PR.
  - The reduced bar never relaxes test-first or the test list above.

**CI gates** (system-design §9). A PR merges only when its folder's checks pass.

| Folder | Checks |
|---|---|
| `backend/` | `ruff`, `mypy`, `pytest` with Postgres, `openapi.json` export, Dart and TS client regeneration (fails if stale) |
| `admin/` | `tsc`, `eslint`, `vitest`, build |
| `app/` | `flutter analyze`, `flutter test`; builds use `--dart-define-from-file=env/<flavor>.json` |

**Migrations.** Alembic only. Revision `0001` is `schema.sql` unchanged. Every later change
follows expand/contract so that the old and new API run against the same schema. An applied
revision is never edited.

**Review.** Every PR is checked against Principles I–IX. Changes that touch auth, input
handling, SQL, files, uploads or external fetches get a security review. Reviews skip style
that linters handle. Commits follow Conventional Commits (`feat`, `fix`, `refactor`, `docs`,
`test`, `chore`, `perf`, `ci`).

**Environments and release.** There are two environments: dev (local Compose with a snapshot
load) and prod. There is no staging server. Android ships from `app-v*` tags to the Play
internal track before production, and the PWA ships from `web-v*` tags. Public launch requires
the gate in product doc §17:
- crash-free sessions ≥ 99.5 %;
- ≥ 95 % channel coverage at T−2 h;
- live status verified on a 2-week sample;
- push verified on Android and on an installed iOS PWA;
- consent, privacy policy and data-safety form done.

## Governance

This constitution supersedes every other practice in this repository. If a doc, design board or
spec contradicts it, that is a defect. Fix the source, or amend the constitution in the same PR.
Never let them drift silently.

**Amendments.** An amendment is a PR that edits `.specify/memory/constitution.md`. It states the
rationale and the version bump, carries a Sync Impact Report during review (removed before
merge), and needs the product owner's approval. If it changes a decision (D*, P* or O*), the
PR also updates system-design §3 or product doc §18. When an open item is resolved or a proposal
is confirmed or rejected, the docs are updated first, and the constitution is amended if a rule
here changes.

**Versioning.** Semantic versioning:
- MAJOR removes or redefines a principle, or makes a rule incompatible with existing work.
- MINOR adds a principle or section, or materially expands guidance.
- PATCH clarifies wording without changing meaning.

**Compliance.** Each `/speckit-plan` Constitution Check MUST pass these gates before research and
again after design:
1. Answer ≤ 2 taps; My satellites and free channels first; ads never before the answer (I).
2. No guessed, stale-as-live or invented data; UTC storage, local-day grouping (II).
3. RTL layout, isolated LTR islands, Western tabular digits, externalized Arabic copy (III).
4. Token-only values, shared components with full states, screen checked against its PNG (IV).
5. Admin only on `wg0`, no client secrets, server-side authz, validated input, bound SQL (V).
6. Envelope, ETags, generated clients, `If-Match` + audit + version bump on admin writes (VI).
7. Idempotent upserts, `locked_fields` respected, retrying tasks, outbox-only push (VII).
8. drift stale-while-revalidate, platform adapters, budgets met, config from Remote Config (VIII).
9. $0/month, arm64 images, Compose + Caddy only, health-checked deploys (IX).

A violation is allowed only when the plan's Complexity Tracking records why it is needed and why
the simpler compliant option was rejected. Reviewers verify compliance on every PR. The whole
constitution is re-read at each delivery-phase boundary (system-design §12).

**Runtime guidance.** `CLAUDE.md`, `madar-design/README.md` and the component READMEs give the
day-to-day detail. They MUST stay consistent with this document.

**Version**: 1.1.0 | **Ratified**: 2026-10-29 | **Last Amended**: 2026-10-29
