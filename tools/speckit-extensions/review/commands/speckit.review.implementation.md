---
description: "Review one lane's implementation across spec, API, database, pipelines, app, UI, admin, security, tests and ops; write a review file and append fix tasks to the lane's section"
---

# Review Implementation

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty). It may contain:

- `lane=<b1|b2|a|m>`: the lane to review. Without it, the lane comes from `MADAR_LANE`, the worktree
  folder (`madar-b1`, `madar-b2`, `madar-a`, `madar-m`) or a current branch named `dNN-<lane>`.
- `base=<ref>`: compare against this ref instead of the default branch.
- `layers=<a,b,...>`: review only these layers (the names in step 2's table). Spec conformance,
  lane ownership and security always run.
- `no-run`: skip the test suites and builds and review the code only. The report must say so.
- `fix`: after the report, fix the confirmed CRITICAL and HIGH findings yourself (step 8).
- Anything else is an area to look at harder.

## Goal

Another agent, often a different model, ran `__SPECKIT_COMMAND_IMPLEMENT__` for one lane of the
day's spec. Review what it built as the senior engineer who will answer for it in production.
Nothing it claimed is true until you have seen the evidence yourself. A ticked task, a "tests pass"
note, a commit message or a `// done` comment is a claim, not evidence.

A review covers exactly one lane (B1, B2, A or M; `docs/delivery-plan.md` §4): its section of
`tasks.md`, its user story in `spec.md`, and its branch `dNN-<lane>`. Below, `<LANE>` is the lane in
upper case (`B1`) and `<lane>` in lower case (`b1`).

The review produces:

1. `FEATURE_DIR/reviews/<lane>-round-<K>.md`: the verified findings, graded, each with its evidence,
   plus every check you ran and its result.
2. A `### Review fixes (round K)` block at the end of the `## Lane <LANE>` section of `tasks.md`,
   with one task for each confirmed finding that needs a change, so the lane's next
   `__SPECKIT_COMMAND_IMPLEMENT__` run fixes them.

## Operating Constraints

- **Read-only on code.** Without `fix`, the only writes are the round file and the appended block.
  Never stash, reset, check out, commit or discard anything.
- **Append-only, and only inside the lane's section.** Never edit, untick, renumber or delete an
  existing task, and never touch another lane's section or `## Done check`. Four lanes edit the same
  `tasks.md` in parallel PRs; staying inside one section is what keeps them from conflicting. A task
  that is ticked but not done gets a new task that cites it.
- **Authority.** The constitution (`.specify/memory/constitution.md`) overrides everything. Next
  come `docs/system-design.md` (how), `docs/product-business.md` (what and copy), `madar-design/`
  (look) and `docs/delivery-plan.md` (when and who). Then the agent instructions (`CLAUDE.md` and
  `AGENTS.md`, plus the lane folder's own `CLAUDE.md` once it exists), then the spec's `plan.md` and
  `spec.md`. Docs win on data and behaviour; the design package wins on visuals. A finding cites the
  rule it breaks.
- **Evidence or nothing.** Every finding names a `file:line` and what you saw there. Every passed
  check names the command you ran and its exit code. A check you did not run is `NOT RUN`, never
  passed.
- **No noise.** Skip what formatters and linters own. Don't pad the report: one real finding
  outweighs ten guesses.
- **Stay on the change.** Review the change set, and read the code around it as far as needed to
  judge its effect. A problem that predates the change goes under "Outside this change" (no task),
  unless the change makes it worse or newly depends on it. Work that belongs to another lane is that
  lane's to review: note a broken dependency on it, don't review its code.

## Execution Steps

### 1. Load the context

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from
   the repo root and parse `FEATURE_DIR`. If `spec.md`, `plan.md` or `tasks.md` is missing, stop and
   name the command that makes it (`__SPECKIT_COMMAND_SPECIFY__`, `__SPECKIT_COMMAND_PLAN__`,
   `__SPECKIT_COMMAND_TASKS__`). In a lane worktree, `.specify/feature.json` usually doesn't exist:
   if no spec is found, tell the user to start the session with
   `SPECIFY_FEATURE_DIRECTORY=specs/0NN-dNN-<name>`.
2. Run `.specify/extensions/review/scripts/bash/review-scope.sh --json` (add `--lane <lane>` and
   `--base <ref>` when given) and parse it: `LANE`, `LANE_BRANCH`, `BRANCH`, `ON_LANE_BRANCH`,
   `BASE`, `MERGE_BASE`, `HEAD`, `TOTALS`, `COMMITS`, `FILES` (each with `status`, `owner`, line
   counts, `committed` and `uncommitted`).
   - The script fails because no lane was found: stop and ask which lane to review.
   - `ON_LANE_BRANCH` false: stop and tell the user to check out `LANE_BRANCH`. Don't switch.
   - `FILES` empty: stop. There is nothing to review.
   - Files that are plainly not part of the lane's work (an agent's own setup in `.specify/`,
     `.claude/` or `.opencode/`, editor files) are listed once under "Outside this change" and not
     reviewed.
3. Read, in full:
   - the constitution, `CLAUDE.md`, `AGENTS.md` and the lane folder's `CLAUDE.md` if it exists: the
     principles and their NON-NEGOTIABLE marks, the Constitution Check gates, the fixed stack, the
     CI gates and the commands;
   - `spec.md`: the lane's user story with its acceptance scenarios, plus every FR, SC, edge case and
     clarification that applies to the lane's folders;
   - `plan.md`: the Constitution Check, Complexity Tracking, technical decisions and the files it
     names for this lane;
   - `tasks.md`: the whole `## Lane <LANE>` section and `## Done check`; the other lanes' sections
     only to learn what this lane depends on or provides;
   - `research.md`, `data-model.md`, `contracts/` and `quickstart.md` when present;
   - the system-design and product-doc sections, and the screens (S*, A*) the lane's story cites;
     for UI work, their rows in `madar-design/app-flutter/SCREENS.md` or
     `madar-design/admin-react/SCREENS.md`, the PNGs and the component READMEs;
   - the latest `FEATURE_DIR/reviews/<lane>-round-*.md`, if any. Its number plus one is this round's
     `K` (else `K` = 1). Each of its findings is re-checked in this round.
4. Read `.github/workflows/*.yml`, once they exist, to learn which jobs this change set triggers (they
   run per folder: `backend.yml`, `admin.yml`, `app.yml`, `pwa.yml`; system-design §9).

### 2. Map the change

Check ownership first. Every file's `owner` must be the lane, `shared` (`specs/`, `docs/`, the root
`CLAUDE.md`, `AGENTS.md`, `README.md`) or `none`:

- `owner` is another lane: a finding, unless the lane's own tasks assign that file. The known cases
  are the Dart and TS clients that B1 regenerates with the contract, and the Flutter platform work
  (M2) that lane A takes from D9. Only B1 changes Alembic migrations and the OpenAPI contract; only
  the generators change generated clients and token files.
- `owner` is `none` (for example `madar-design/`): a finding unless a task of the lane names it.
- In `tasks.md`, the diff touches only the lane's section. In `specs/`, only this spec changed.

Then put every changed file in one or more layers. Security and tests apply to every file.

| Layer | Paths in this repo | Checklist |
| --- | --- | --- |
| `spec` | every file | 4.A |
| `api` | `backend/app/{public,admin,domain}/`, services, schemas, settings, the exported `openapi.json` | 4.B |
| `db` | `backend/app/db/`, `backend/alembic/`, models; `app/lib/core/db/` (drift) | 4.C |
| `pipelines` | `backend/app/adapters/`, `backend/app/workers/`, outbox, dispatcher, live poller, raw-page fixtures | 4.D |
| `app` | `app/lib/**/{data,domain}/`, `app/lib/core/` (except `theme/` and `l10n/`), `app/web/`, `app/env/`, `pubspec.yaml` | 4.E |
| `ui` | `app/lib/**/presentation/`, `app/lib/core/{theme,l10n}/`, admin pages and components, `madar-design/design-system/` | 4.F |
| `admin` | `admin/` | 4.G |
| `security` | every file | 4.H |
| `tests` | every test file, goldens, saved raw pages, coverage and lint config | 4.I |
| `ops` | `infra/`, `.github/`, Dockerfiles, `codemagic.yaml`, `docs/`, `specs/`, `CLAUDE.md`, `AGENTS.md`; its runbook and owner-actions checks run for every lane | 4.J |

Then build two maps (keep them internal; they feed steps 4 and 6):

- **Intent → code.** For each acceptance scenario of the lane's story, each FR and SC it covers,
  edge case, plan decision and task in the lane's section: the code that does it and the test that
  proves it, or "none found".
- **Code → intent.** Each changed file that no task, plan decision or requirement explains is
  scope creep. Each file a task of the lane or the plan names that did not change is a likely gap.

### 3. Run the checks

Unless `no-run` was given:

- For each CI job the change triggers, run its commands locally exactly as `CLAUDE.md` and the lane
  folder's `CLAUDE.md` give them (right directory, right tool runner). The constitution's CI gates
  are the minimum: `backend/` runs `ruff`, `mypy` and `pytest` against PostgreSQL 16, exports
  `openapi.json` and regenerates the Dart and TS clients (stale clients fail); `admin/` runs `tsc`,
  `eslint`, `vitest` and the build; `app/` runs `flutter analyze` and `flutter test`. Add what the
  change calls for: the Alembic upgrade on a fresh database and an autogenerate diff when models
  changed, the adapter parse tests when an adapter changed, the goldens when a component changed,
  the token generator diff when `tokens.json` changed, and Playwright or `integration_test` flows
  that `quickstart.md` names.
- Don't guess commands. If neither `CLAUDE.md` file documents one, mark the check `NOT RUN` with the
  reason; the missing documentation is a finding under 4.J.
- Backend tests need PostgreSQL 16 and Redis 7. If the dev stack is down, start it with the
  documented command; if it won't start, mark those checks `NOT RUN` with the reason.
- Run independent suites in the background or in parallel, and review the code while they run.
- Record each check as `command → exit code → one-line result`. A failing check is a finding.
- Look at the diff for ways around the checks, each a finding: deleted or skipped tests (`skip`,
  `xfail`, `@Skip`, `.skip(`, `.only(`), weaker assertions, goldens rewritten without a UI change
  that explains them, new `# noqa`, `# type: ignore`, `// ignore:`, `ignore_for_file`,
  `eslint-disable` or `@ts-expect-error`, changes to ruff, mypy, analysis, ESLint, TS or coverage
  config, lowered CI thresholds, SQLite swapped in for PostgreSQL, and generated files (API clients,
  Orval schemas, token files, `*.g.dart`, `*.freezed.dart`) edited by hand.

### 4. Review each layer

If your agent can run subagents, review the touched layers in parallel: one subagent per layer, and
spec conformance always gets its own. Give each one its checklist below, its file list, the lane,
the paths of `FEATURE_DIR`, the constitution and `CLAUDE.md`, the base and head commits, and the
finding format of step 5. Ask it to report what it checked as well as what it found. Use a
specialized reviewer (security, database, Python, TypeScript, Flutter) where your agent has one.
Give subagents the code and the checklist, not your suspicions. Without subagents, review the
layers yourself, one at a time.

Each checklist is the minimum. Every MUST, NEVER and "only" in the constitution and `CLAUDE.md`
that touches the layer is a check too.

**4.A Spec conformance**

- Each acceptance scenario of the lane's story, and each FR, buildable SC, edge case and
  clarification answer it covers: built, where, and proven by which test. Walk each `quickstart.md`
  scenario for this lane through the code.
- Each ticked task in the lane's section: the work exists, in the files the task names, and does
  what the task says. Stubs, `TODO`/`FIXME`, `NotImplementedError`, `UnimplementedError`, bare
  `pass`, hard-coded returns, placeholder text and commented-out code mean not done.
- Each unticked task: really not done? Was it needed?
- The code follows `research.md`'s decisions, `data-model.md`'s fields, constraints and states, and
  `contracts/` exactly (paths, names, types, status codes, `error.code` values).
- Each `## Done check` step that depends on this lane: does the code make it possible?
- Unfinished user-facing work ships dark behind its Remote Config `features.*` flag
  (delivery-plan §5.5).
- Behaviour the spec didn't ask for, and changes outside the plan's files.

**4.B Backend API and domain**

- Routers stay thin; logic sits in the domain and services. Pydantic v2 validates every request at
  the boundary with enums and length caps (reports ≤ 280 chars).
- Admin routers are mounted only on `app.admin:app`, never on `app.public:app`. Every admin route
  has the role dependency (`editor` / `admin`).
- Every response uses the envelope `{"success", "data", "error": {"code", "message"}, "meta"}`.
  `error.code` is stable and listed; nothing internal leaks into `message`. IDs are integers, times
  ISO-8601 UTC, media URLs absolute, long lists cursor-paginated with `meta.next_cursor` and
  bounded.
- Every GET returns an `ETag` built from `dataset_versions` and answers `If-None-Match` with a 304.
- Every admin mutation requires `If-Match`, writes `audit_log` (who, what, diff), bumps the affected
  `dataset_versions` and adds the edited field names to `locked_fields`. Invalidation bumps a
  version; nothing deletes cache keys found by scan.
- Match status follows the state machine (system-design §6.2.3): `status_source`, a manual status
  wins until cleared, a clock status carries `estimated: true` and no score or minute. Matches are
  never deleted.
- `kickoff_at` is UTC `timestamptz`; source wall-clock times convert from their real zone
  (`AT TIME ZONE 'Africa/Cairo'`); an unknown kickoff sets `time_tbd`. Placeholders become NULL.
- `/v1` stays compatible with every build ≥ `min_supported_build`: no removed or renamed fields,
  no changed types, no new required inputs without a new path.
- `openapi.json` is re-exported and both generated clients are regenerated in the same change.
- Async correctness: no blocking I/O in async code, no session shared across tasks, no `await`
  missing on a coroutine.
- New settings are in the environment contract, validated at startup, and hold no secret default.
- Performance: no N+1 (`selectinload`/`joinedload`), payloads within budget (home ≤ 60 KB gzipped,
  304 ≤ 1 KB).

**4.C Database**

- Alembic only. `0001` is `schema.sql` unchanged; an applied revision is never edited. Each change
  is expand/contract, so the running API still works against the new schema mid-deploy (no drop or
  rename of what old code reads; a new NOT NULL gets a default or a backfill step). Data migrations
  batch and don't import app models.
- Models and migrations agree: autogenerate produces no diff.
- New query patterns have indexes. Invariants have unique or check constraints: `(source,
  external_id)` for upserts, `dedupe_key` on the outbox. `ON DELETE` is deliberate, and nothing
  cascades into `matches`.
- SQL goes through SQLAlchemy with bound parameters only; `text()` uses bind params; no SQL built
  from strings.
- Concurrency: claims use `FOR UPDATE SKIP LOCKED` inside a transaction; upserts use
  `INSERT … ON CONFLICT`; no read-modify-write races on counters or versions.
- drift (app): a table change bumps `schemaVersion` with its migration step and keeps existing rows;
  only the owning repository writes its tables; multi-table writes run in one transaction.

**4.D Pipelines: ingestion, live and push**

- Each adapter implements `SourceAdapter` (`name`, `allowed_hosts`, `fetch`, `parse`, `normalize`;
  system-design §6.6). `parse` is pure (no I/O, clock or database) and tested against saved raw
  pages committed as fixtures.
- Upserts by `(source, external_id)`; fields in `locked_fields` are never written; an importer
  removes only the `match_channels` links it added. Entity resolution goes no further than exact
  alias, then disambiguation within the competition; everything else goes to `unresolved_names`.
- Per source: per-host token-bucket limits, exponential backoff with jitter on 429, 403 and 5xx, a
  circuit breaker that pauses the source and alerts, a zero-items alarm, an `import_runs` record.
- SSRF: the host allowlist is enforced, redirects to other hosts are refused, sizes are capped and
  timeouts set, for scrapers and media rehosting alike.
- Card-sharing labels and BISS keys (O3) are dropped, not stored or exposed.
- Celery tasks use `bind=True`, `autoretry_for`, `retry_backoff`, `retry_jitter` and a bounded
  `max_retries`, run on the right queue, are idempotent, and take a Redis `SET NX EX` lock against
  overlapping runs. Exactly one `beat`.
- Push: producers only insert `notification_outbox` rows with a unique `dedupe_key`; only the
  dispatcher calls FCM. It claims with `FOR UPDATE SKIP LOCKED`, resolves the audience with
  `SELECT DISTINCT` over `device_follows`, collapses by `match_<id>` and deletes `UNREGISTERED`
  tokens. Read every audience query as if it could spam every device. Push copy builds scores from
  isolated parts (no raw `1 - 0`).
- The live poller runs only inside the window (now − 150 min … now + 10 min) and feeds one shared,
  cached `GET /v1/live`.

**4.E App architecture and Dart**

- Feature-first `data/domain/presentation`; `domain/` imports neither `data/`, `presentation/` nor
  Flutter. Riverpod with the generator is the only state library; navigation is go_router; business
  logic lives in providers, not in widgets or `setState`.
- Networking only through the generated Retrofit client and freezed models; no hand-written DTOs.
- drift is the only structured cache; Hive, Isar and SharedPreferences hold no structured data. The
  device token lives only in `flutter_secure_storage`.
- Repositories are stale-while-revalidate: emit the drift copy, then revalidate with
  `If-None-Match` (a 200 updates drift, a 304 changes nothing). Skeletons only on a true first load;
  data older than its freshness target shows its age; cache never shows as live.
- Native-only capabilities (`AdsService`, `LocalNotifier`, `HomeWidgetUpdater`, `CrashReporter`,
  `InstallGuide`) sit behind interfaces with web no-ops chosen by conditional import; feature code
  never imports those plugins; shared code never imports `dart:io`, so the web build compiles.
- Hosts, update builds, maintenance, ad pacing, feature flags and the live poll interval come from
  Remote Config with bundled defaults. `env/*.json` holds public values only.
- Ads: the interstitial never before an answer, never within 60 s of launch, ≥ 90 s apart, ≤ 4 per
  session; the banner is Android-only and takes space only once loaded (constitution I).
- Async: `mounted` checked after every `await` before using `context`; fire-and-forget wrapped in
  `unawaited`; errors mapped from `error.code` to Arabic copy, never `error.message` shown.
- Lifecycle: controllers, streams, subscriptions, timers and `AnimationController`s disposed.
- Performance: growing lists virtualized (`ListView.builder` or slivers; up to 171 channels on a
  match), `const` where it qualifies, narrow rebuilds, heavy work off the UI isolate.

**4.F UI, design and RTL (app and admin)**

- Each screen the lane builds matches its `SCREENS.md` row, PNG and HTML (structure, Arabic copy,
  states), rebuilt with real widgets, not pasted. For UI work, "done" needs a screenshot next to the
  design PNG (delivery-plan §8.1, item 12); its absence is a finding.
- Token values only: no raw hex, pixel sizes or font names (`context.madarColors`, `MadarText`,
  `MadarRadii`; admin token CSS variables with Tailwind bound to tokens and no arbitrary values).
  Token files change only through `tokens.json` plus `generate_tokens.py`.
- Components are built once under their `INDEX.md` names, with every state in their README.
- RTL: forward chevrons point left, back arrows right, the home team on the right, tabs right to
  left, the admin root `<html lang="ar" dir="rtl">` with the sidebar on the right.
- Frequencies, Latin channel and satellite names, orbital positions and source codes are isolated
  LTR islands (`TextDirection.ltr` / `<bdi dir="ltr">`), never concatenated into Arabic strings.
- Western tabular digits everywhere, without relying on the `ar` locale; `ص`/`م` in 12-hour mode.
- Color semantics: `live` red only for live; `error` for errors, red cards and deletes; one `accent`
  per screen; `encrypted` neutral with a lock; never meaning by color alone. `FrequencyReadout` stays
  a dark well with cyan IBM Plex Mono digits, LTR, in both themes.
- Answer first: channel, satellite and frequency ≤ 2 taps from launch; up to 2 channel names on the
  match row; the frequency readout visible collapsed; My satellites and free channels first.
- Honest states: loading, empty (why, plus the next action), error, offline, stale age, first run;
  «لم يُحدد» for an unknown kickoff; estimated live without score or minute.
- Every string externalized (ARB in Flutter) and in the voice and glossary of product doc §14.
- Accessibility: WCAG AA in both themes, touch targets ≥ 48 dp, layouts that survive 1.3× text
  scale, reduced motion honored, visible keyboard focus on web and admin, Arabic screen-reader labels
  on composite rows. No emoji as icons; fonts bundled, never fetched at runtime.
- Admin: desktop-first at 1440, usable at 1024.

**4.G Admin web**

- TS strict: no `any` without a justifying comment, no non-null `!` without a runtime guard.
- Only the Orval-generated client and Zod schemas; React Query for server state (no bare
  `useEffect` + fetch); RHF + Zod for forms. Mutations send `If-Match` from the ETag they read and
  handle a 412 with a conflict state, not a silent overwrite.
- Session: the access token only in memory (never `localStorage`), the refresh token in the
  `HttpOnly` cookie, the CSRF header on refresh, everything cleared on logout.
- No `dangerouslySetInnerHTML` without DOMPurify; nothing that needs more than CSP
  `default-src 'self'`.
- Correct hook dependency arrays; stable keys (never the index) for lists that reorder (drag
  priority and order); clsx or cva for conditional classes.
- Destructive actions (delete, merge) confirm the way the product doc's screen says.

**4.H Security (every file)**

- No secret in code, config, tests, fixtures or logs; no `.env` committed; `env/*.json` and admin
  builds hold public values only. Nothing from `../old_app/` except `migration/schema.sql`; never
  `migration/data/` or the old Firebase web config (D15).
- Admin reachable only over `wg0`: no admin router on the public app, no public Caddy site for it,
  admin services bound to `wg0`, Postgres and Redis on private interfaces with passwords.
- Admin auth, when touched: argon2id with ≥ 12 chars, no default credentials, 5 attempts per 15 min
  per account+IP then lockout, 15-min access JWTs, 14-day refresh tokens rotated on use, stored
  hashed and revocable, cookie `HttpOnly; Secure; SameSite=Strict` plus the CSRF header.
- Device tokens: 256 random bits generated by the server, stored hashed, compared in constant time;
  `DELETE /v1/devices/me` erases the device and its follows.
- Rate limits: Redis sliding windows keyed by device token, else client IP, with `X-Forwarded-For`
  trusted from Caddy only and per-IP limits generous enough for CGNAT.
- No injection: SQL built from strings, shell (`shell=True`, string-built commands), path traversal
  (uploads, media paths), unsafe deserialization (`pickle`, `yaml.load`), SSRF on outbound URLs.
- Uploads: magic-byte check, size caps (image ≤ 2 MB, audio ≤ 1 MB), images re-encoded to WebP
  ≤ 512 px with metadata stripped, audio to AAC ≤ 30 s, content-addressed, served with `nosniff`.
- Headers: HSTS, `nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`,
  `X-Frame-Options: DENY` on the admin; public CORS allows only the PWA's `web.app` and
  `firebaseapp.com` origins.
- Privacy: consent (AdMob UMP) before ads and analytics where required.
- New dependencies exist, are maintained, are pinned in the lockfile, have an acceptable license and
  are justified in `plan.md`.

**4.I Tests**

- Each acceptance scenario of the lane's story has a test that fails if the behaviour breaks. Read
  the assertions and ask: if I flip this condition, does a test fail?
- The constitution's test-first areas have real tests that cover the edges: the status state machine
  and the estimated rule, time-zone conversion and local-day grouping, entity resolution,
  `locked_fields`, outbox dedupe and audience, adapter `parse` against saved raw pages, contract
  tests against the exported OpenAPI, and bidi-island and digit formatting. Where the history shows
  it, the test came before or with the code, not after.
- Database tests run against real PostgreSQL 16, never SQLite.
- Flutter widget tests for `MatchRow`, `StatusBlock` and the bottom nav run RTL, at 1.3× text scale,
  in both themes; signature components have goldens.
- The admin has a Zod schema for every response and the Playwright flows the phase bar asks for
  (delivery-plan §7).
- Coverage ≥ 80 % in the lane's folder (the constitution's gate, which outranks the delivery plan's
  MVP bar), with no new exclusions.
- No sleeps, wall-clock time, network or order dependence in tests.

**4.J Ops and docs**

- Infra stays $0/month: `linux/arm64` images, Docker Compose and Caddy only, no Kubernetes or CDN;
  a recurring cost needs its decision in system-design §3 first.
- Deploys run `alembic upgrade head` as a one-off container, then `compose pull && up -d`, then check
  `/healthz`, and roll back on failure. Exactly one `beat` in the Compose files.
- CI: path filters per folder, gitleaks on every PR, the generated-client stale check, no lowered
  thresholds.
- Monitoring: new jobs have heartbeats; `/healthz` covers the database and Redis; logs are
  structured JSON.
- A new `features.*` key is in the Remote Config defaults on the day that introduces it.
- Runbooks: each part this change adds or changes that someone sets up, deploys, rolls back,
  recovers, rotates or checks by hand (a host step, a service, a job, an environment variable, a
  secret, a CI job) has its runbook in `docs/runbooks/` updated in the same change. Every command,
  flag, path and variable in it matches the code, and `docs/runbooks/README.md`'s setup order and
  "After setup" table point to it. A missing or stale runbook is a finding.
- `docs/owner-actions.md` has this day's section for the lane: each owner-only item (accounts,
  consoles, secrets, devices, live checks) under "Before merge" or "After merge", with its task ID
  and its runbook or quickstart link, and the "Open now" table is current.
- `CLAUDE.md` (root and the lane folder's) lists new commands, files and rules. If a decision
  (D*, P*, O*) changed, system-design §3 or product doc §18 changed with it. Nothing open was
  resolved by guessing.

### 5. Verify every finding

Before anything reaches the report, re-open the cited code yourself (always for a subagent's
finding) and try to disprove it: is it handled elsewhere (a base class, middleware, a dependency, a
guard test)? Does the cited rule really require it? Can the path be reached? Is it another lane's
job that this lane's tasks don't cover?

- Keep it as **CONFIRMED** when you have seen it and can state the failing scenario.
- Keep it as **PLAUSIBLE** when only running the code would settle it.
- Drop it otherwise.

Each finding records: id `<LANE>-R<K>-<n>` (for example `B1-R2-4`), severity, layer, `file:line`,
the problem, a concrete failure scenario (input or state → wrong outcome), its source (acceptance
scenario, FR, task, constitution principle, system-design or product-doc section, `CLAUDE.md` rule,
plan decision), the direction of the fix (not a patch), and CONFIRMED or PLAUSIBLE.

Severity:

- **CRITICAL**: breaks a NON-NEGOTIABLE principle (II Honest Data, V Trust Lives on the Server); a
  security hole someone can use (an admin route on the public app, a committed secret, missing
  authorization); data loss or corruption (a deleted match, an overwritten `locked_fields` value);
  a push that can reach the wrong audience or send twice; a migration that breaks the running
  release.
- **HIGH**: an acceptance scenario of the lane's story missing or wrong; a task ticked but not done;
  a failing check; a breach of another principle (I, III, IV, VI, VII, VIII, IX) on a normal path;
  a crash or unhandled error on a normal path; a test-first area without real tests; a way around
  the checks (step 3); an edit in another lane's folder or to a generated file.
- **MEDIUM**: a secondary requirement partly met; an unhandled edge case; missing docs; a
  maintainability problem with a concrete future failure.
- **LOW**: minor polish.

Verdict: **BLOCK** if any CRITICAL, **CHANGES REQUESTED** if any HIGH, **APPROVE WITH NOTES** if
only MEDIUM or LOW, **APPROVE** if none.

### 6. Write the round file

Create `FEATURE_DIR/reviews/<lane>-round-<K>.md`:

```markdown
# Implementation review: <feature dir name>, lane <LANE>, round <K>

- Date: <YYYY-MM-DD> · Reviewer: <agent and model>
- Branch: <BRANCH> · Base: <BASE> (merge base <short sha>) · Head: <short sha>, plus <n> uncommitted files
- Change: <commits> commits, <files> files (<n> in another lane's folders), +<added> −<deleted>
- Verdict: <verdict> · CRITICAL <n> · HIGH <n> · MEDIUM <n> · LOW <n>

## Checks
| Check | Command | Result |

## Previous round
| Finding | Now |   (fixed / still open / regressed / no longer applies; omit in round 1)

## Findings
### CRITICAL
#### <LANE>-R<K>-1: <title>
- Layer · Source · Location (`file:line`) · CONFIRMED | PLAUSIBLE
- Problem:
- Failure scenario:
- Fix direction:
### HIGH
### MEDIUM
### LOW

## Requirements
| Requirement | Built in | Proven by | Status |   (every acceptance scenario of the lane's story, and each FR and buildable SC it covers)

## Task audit
Ticked <n>, verified <n>, not done <n>, partly done <n>. Then a table of the mismatches only.

## Owner must review
The files in this change that the owner reviews line by line (delivery-plan §5.4): the API contract,
Alembic migrations, auth and permissions code, push audience queries, and each UI screen next to its
design PNG. One line each, with what to look at. Write "none" if the change has none.

## Outside this change

## Not reviewed
What you did not check or run, and why.
```

### 7. Append the fix tasks

If there are CONFIRMED findings of MEDIUM or higher, append to the end of the `## Lane <LANE>`
section of `tasks.md` (just before the next `## ` heading):

1. Write the header `### Review fixes (round <K>)` and one line saying the tasks come from
   `reviews/<lane>-round-<K>.md`.
2. One task per finding, CRITICAL first, in the file's own task format, with the finding id as the
   task id. Lanes append in parallel, so new `T` numbers would collide; finding ids can't.

   ```markdown
   - [ ] B1-R2-4 <imperative fix> in `<path>`: <what is wrong and what must be true after>. Add a test that fails before the fix. (HIGH, per FR-007)
   ```

   Write each task so an agent that has not read the review can do it: the files, the wrong
   behaviour, the right behaviour and the test that proves it. A fix that needs a decision from the
   owner (a spec, plan, doc or constitution change) becomes a task to ask, not a guess. A fix that
   belongs in another lane's folder becomes a task to ask that lane, not an edit.

LOW and PLAUSIBLE findings stay in the round file only. With no CONFIRMED finding of MEDIUM or
higher, leave `tasks.md` byte for byte unchanged.

### 8. Fix mode (only with `fix`)

For each CONFIRMED CRITICAL and HIGH finding, in order: write the failing test first where the area
is test-first, make the smallest fix that follows the plan and the constitution, inside the lane's
own folders only, rerun the checks it affects, tick its appended task, and add
`Fixed in round <K> by the reviewer.` under the finding in the round file. Never make a check pass by
weakening it. Stop and ask when a fix needs a decision from the owner or another lane's folder. When
done, rerun every check from step 3 and update the Checks table.

### 9. Report

Reply in chat with the lane, the verdict, the counts by severity, one line per CRITICAL and HIGH
finding, any check marked `NOT RUN`, the "Owner must review" files, the round file's path, and how
many tasks were appended to the lane's section. Then give the next step:

- With appended tasks: run `__SPECKIT_COMMAND_IMPLEMENT__ Only the tasks under "Lane <LANE>" in tasks.md.`
  (in whichever agent implements) to fix them, then run
  `__SPECKIT_COMMAND_REVIEW_IMPLEMENTATION__ lane=<lane>` again for round K+1.
- With APPROVE or APPROVE WITH NOTES: the lane is ready for its PR once the owner has read the notes
  and the "Owner must review" files.

Do not commit. The user decides when to commit.
