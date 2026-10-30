# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. It holds only what applies across projects. Each project folder has its own `CLAUDE.md` with its commands, layout and rules: `backend/`, `admin/`, `app/`, `infra/` and `tools/speckit-extensions/`. Read the one for the folder you are changing.

## What this repo is

Madar Sat (مدار سات) is an Arabic-first, RTL guide for football fans who watch on a satellite dish. For each match it answers: which channel, on which satellite, at what frequency, and can my dish receive it. It replaces Sat Air 3.8 (`com.satair.app`), whose recovered source is in the sibling folder `../old_app/`. That folder is outside this repo on purpose (D15): copy only `old_app/migration/schema.sql` in, and never commit `migration/data/` or the old Firebase web config.

- `backend/`, `admin/`, `app/`, `infra/`, `.github/workflows/`: the code, one lane each (below).
- `docs/system-design.md`: architecture, decisions (D1–D15 decided, P1–P6 proposed, O1–O7 open), API shapes (§6.3.3), the security checklist (§8), repo layout and CI (§9), delivery phases (§12).
- `docs/product-business.md`: screen specs S0–S20 (app) and A0–A17 (admin), notification copy (§11), data dictionary (§12), design-system requirements (§13), Arabic voice and glossary (§14).
- `docs/delivery-plan.md`: phases (MVP, V1, V2, V3), one Spec Kit spec per working day (specs 001–030 = D1–D30), work per lane (B1, B2, A, M) inside each day, ownership rules, the daily loop and quality gates.
- `madar-design/`: the exported UI design package (tokens, 24 components, 46 app boards, 21 admin boards). Start with `madar-design/README.md`.
- `.specify/`: Spec Kit. `.specify/memory/constitution.md` (principles I–IX, quality gates, fixed stack) is the highest authority and overrides this file.
- `docs/runbooks/`: how to operate every part. `docs/runbooks/README.md` gives the first-time setup order and an "After setup" table.
- `docs/owner-actions.md`: what only the owner can do, per day spec and lane, with an "Open now" table.

Both docs cite each other by section number (for example "system-design §6.3", "product doc S3"). Follow those references instead of guessing. When docs and design disagree on data or behavior, the docs win; on visuals, the design package wins.

Design tokens are generated: edit `madar-design/design-system/tokens.json`, run `python3 madar-design/design-system/code/generate_tokens.py`, and never edit `tokens.css`, `madar_tokens.dart` or `tokens.ts` by hand. `admin/` and `app/` keep verbatim copies that their token-copy checks compare.

## Spec Kit workflow and lanes

Work is one Spec Kit spec per working day (`specs/0NN-dNN-<name>`; delivery-plan §5 and Appendix B), built by four lanes in parallel.

- Steps: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` (Constitution Check) → `/speckit-tasks` → `/speckit-analyze` → `/speckit-implement` → `/speckit-review-implementation`. Claude Code is the default integration (`.claude/skills/speckit-*`). opencode is installed too (`.opencode/commands/speckit.*`, invoked as `/speckit.<step>`), so a lane can implement there on another model and be reviewed here.
- Lanes and ownership (delivery-plan §4): B1 `backend/` except `backend/app/adapters/`, plus Alembic and the OpenAPI contract; B2 `infra/`, `backend/app/adapters/` and CI; A `admin/`; M `app/`. A lane implements and ticks only its own `## Lane <X>` section of `tasks.md`, and never edits another lane's folder or a generated file (API clients, Orval schemas, token files).
- Each lane runs in a sibling worktree (`../madar-b1`, `../madar-b2`, `../madar-a`, `../madar-m`) on branch `dNN-<lane>`, started as `SPECIFY_FEATURE_DIRECTORY=specs/0NN-dNN-<name> claude`. `.specify/feature.json` is per checkout, and `SPECIFY_FEATURE` alone selects no spec.
- **The default branch is `master`**, and it stays `master` (never renamed to `main`).
- **Branches are handled by the `feature-branch` hook** (`.specify/extensions.yml`), which runs after `/speckit-specify` and before every later step. In a lane session (`MADAR_LANE`, else the worktree folder name, else a current `dNN-<lane>` branch) it checks out `dNN-<lane>`, or creates it from `origin/master` (falling back to `master`). In the planning checkout it checks out or creates the spec branch `0NN-dNN-<name>` from HEAD. If git refuses the switch, the step stops: don't stash, reset or discard to get past it; ask the user.
- **Review:** `/speckit-review-implementation [lane=…] [base=…] [layers=…] [no-run] [fix]` reviews one lane against the merge base. It runs the CI checks the change triggers, checks every layer against the constitution, writes `specs/<spec>/reviews/<lane>-round-<K>.md`, and appends a `### Review fixes (round K)` block to the end of that lane's section. It never commits.
- Tests are mandatory in every `tasks.md`, even though `tasks-template.md` calls them optional (constitution, Quality Gates).
- **Runbooks.** Every part someone operates has a runbook in `docs/runbooks/`. A change that adds or changes how something is set up, deployed, rolled back, recovered, rotated or checked by hand (a host step, a service, a job, an environment variable, a secret, a CI job) adds or updates its runbook in the same change, and keeps `docs/runbooks/README.md`'s setup order and "After setup" table pointing to it. Every command in a runbook must match the code. Don't wait for the runbook milestones in the delivery plan.
- **Owner actions.** When `/speckit-implement` finishes a lane, add or update that day's section in `docs/owner-actions.md`. It lists everything only the owner can do (accounts, consoles, secrets, devices, live checks), split into before and after merge, each with its task ID and its runbook or quickstart link. Keep the "Open now" table current, and tick items as the owner reports them done.
- The Specify CLI generates and hash-tracks `.claude/skills/speckit-*`, `.opencode/commands/speckit.*`, `.specify/templates/` and `.specify/scripts/`; don't hand-edit them. The project's own extensions live in `tools/speckit-extensions/`, whose `CLAUDE.md` says how to change and reinstall them.

## Architecture (big picture)

The stack is fixed by the constitution. Each folder's `CLAUDE.md` has the details.

- **Backend** (`backend/`): FastAPI, not Django (D5); SQLAlchemy 2 async, Alembic, Pydantic v2, Celery + beat, PostgreSQL 16, Redis 7. Two ASGI apps: `app.public:app` (`/v1`) and `app.admin:app` (`/admin/api`, WireGuard `wg0` only). Admin routers are never mounted on the public app.
- **App** (`app/`): Flutter, Riverpod, go_router, Dio + Retrofit and freezed generated from OpenAPI, drift for the offline cache (P6: not Hive or Isar). Repositories are stale-while-revalidate: emit the drift copy, then revalidate with `If-None-Match`. iOS ships as the Flutter web PWA until an Apple account exists.
- **Admin** (`admin/`): React 18 + Vite + TS strict + Tailwind v3 + React Query + RHF/Zod, with the client and Zod schemas generated by Orval from the admin OpenAPI spec.
- **Infra** (`infra/`): $0/month on 2 OCI Ampere arm64 VMs with Docker Compose and Caddy.

The contract between them: the API envelope is `{"success", "data", "error": {"code", "message"}, "meta"}`, and clients map `error.code` to Arabic copy. IDs are integers, times are ISO-8601 UTC, long lists use cursor pagination. Devices are anonymous (no user accounts); auth is `Authorization: Device <token>`. Clients read the API and media hosts from Firebase Remote Config, group matches by the user's local date (not `match_date`), and never show a score or minute for a live state marked `estimated: true`.

## Client UI rules (admin and app)

From `madar-design/README.md`; read it before building any screen. Each client's `CLAUDE.md` adds its token API and checks.

- Values come only from tokens. Never copy a hex value or pixel size from a screen file. `madar-design/design-system/TOKEN-ALIASES.md` maps the short mockup variables (`--s1`, `--tx2`, `--rd`) to tokens.
- Before building a screen, find its row in `app-flutter/SCREENS.md` or `admin-react/SCREENS.md`, look at the PNG, and read the HTML for structure, Arabic copy and states. The HTML is a mockup: rebuild it, never paste it.
- Build each component in `design-system/components/INDEX.md` once, under its component name (`MatchRow`, `StatusBlock`, `FrequencyReadout`, ...), and follow its README's states and rules.
- The wordmark is «مدار», as drawn in the design package. Madar Sat / مدار سات is the product, app and store name; don't change the wordmark to it.
- RTL first; back arrows point right; the home team sits on the right. Latin channel and satellite names, frequencies and source codes are LTR islands.
- The frequency readout (`11843 H 27500`, IBM Plex Mono, cyan digits on a dark well) stays dark and LTR in both themes.
- `live` red is only for live matches; errors, red cards and deletes use `error`. Only one `accent` (volt) element per screen.
- Always render Western digits (0–9) with tabular figures. Do not rely on the `ar` locale, which can emit Arabic-Indic digits.
- Data is honest: an unknown kickoff shows «لم يُحدد», an estimated live state has no score, and stale data shows its age.

## Path gotchas

- `madar-design/**/SCREENS.md` and `madar-design/README.md` refer to `new_app/docs/...`; in this repo that is `docs/`.
- `madar-design/design-system/README.md` mentions `components/bundle.css`; the actual file is `madar-design/design-system/components.css`.
- Docs that mention `old_app/` mean the sibling `../old_app/`, which is not in this repo.
