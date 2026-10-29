# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Madar Sat (مدار سات) is an Arabic-first, RTL guide for football fans who watch on a satellite dish. For each match it answers: which channel, on which satellite, at what frequency, and can my dish receive it. It replaces Sat Air 3.8 (`com.satair.app`), whose recovered source is in the sibling folder `../old_app/`. That folder is outside this repo on purpose (D15): copy only `old_app/migration/schema.sql` in, and never commit `migration/data/` or the old Firebase web config.

**Current state: design only. There is no application code yet.** The repo holds:

- `docs/system-design.md`: architecture, decisions (D1–D15 decided, P1–P6 proposed, O1–O7 open), API shapes (§6.3.3), the security checklist (§8), repo layout and CI (§9), delivery phases (§12).
- `docs/product-business.md`: screen specs S0–S20 (app) and A0–A17 (admin), notification copy (§11), data dictionary (§12), design-system requirements (§13), Arabic voice and glossary (§14).
- `docs/delivery-plan.md`: phases (MVP, V1, V2, V3), one Spec Kit spec per working day (specs 001–030 = D1–D30), work per lane (B1, B2, A, M) inside each day, ownership rules, the daily loop and quality gates. A lane implements only its own section of the day's `tasks.md`.
- `madar-design/`: the exported UI design package (tokens, 24 components, 46 app boards, 21 admin boards). Start with `madar-design/README.md`.
- `.specify/`: Spec Kit. `.specify/memory/constitution.md` (principles I–IX, quality gates, fixed stack) is the highest authority and overrides this file.
- `tools/speckit-extensions/`: source of the project's own Spec Kit extensions, `feature-branch` and `review` (see "Spec Kit workflow and lanes").

Both docs cite each other by section number (for example "system-design §6.3", "product doc S3"). Follow those references instead of guessing. When docs and design disagree on data or behavior, the docs win; on visuals, the design package wins.

## Commands

The only runnable tool today is the token generator:

```bash
python3 madar-design/design-system/code/generate_tokens.py
```

It rewrites `tokens.css`, `code/flutter/madar_tokens.dart` and `code/react/tokens.ts` from `design-system/tokens.json`. Edit `tokens.json`, never the generated files.

Once the code folders exist, CI (system-design §9) runs these per folder:

| Folder | Checks |
|---|---|
| `backend/` | `ruff`, `mypy`, `pytest` (needs Postgres); exports `openapi.json`, regenerates the Dart and TS clients, and fails if they are stale |
| `admin/` | `tsc`, `eslint`, `vitest` |
| `app/` | `flutter analyze`, `flutter test`; builds use `--dart-define-from-file=env/<flavor>.json` (dev, staging, prod) |

## Spec Kit workflow and lanes

Work is one Spec Kit spec per working day (`specs/0NN-dNN-<name>`; delivery-plan §5 and Appendix B), built by four lanes in parallel.

- Steps: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` (Constitution Check) → `/speckit-tasks` → `/speckit-analyze` → `/speckit-implement` → `/speckit-review-implementation`. Claude Code is the default integration (`.claude/skills/speckit-*`). opencode is installed too (`.opencode/commands/speckit.*`, invoked as `/speckit.<step>`), so a lane can implement there on another model and be reviewed here.
- Lanes and ownership (delivery-plan §4): B1 `backend/` except `backend/app/adapters/`, plus Alembic and the OpenAPI contract; B2 `infra/`, `backend/app/adapters/` and CI; A `admin/`; M `app/`. A lane implements and ticks only its own `## Lane <X>` section of `tasks.md`, and never edits another lane's folder or a generated file (API clients, Orval schemas, token files).
- Each lane runs in a sibling worktree (`../madar-b1`, `../madar-b2`, `../madar-a`, `../madar-m`) on branch `dNN-<lane>`, started as `SPECIFY_FEATURE_DIRECTORY=specs/0NN-dNN-<name> claude`. `.specify/feature.json` is per checkout, and `SPECIFY_FEATURE` alone selects no spec.
- **The default branch is `master`**, and it stays `master` (never renamed to `main`).
- **Branches are handled by the `feature-branch` hook** (`.specify/extensions.yml`), which runs after `/speckit-specify` and before every later step. In a lane session (`MADAR_LANE`, else the worktree folder name, else a current `dNN-<lane>` branch) it checks out `dNN-<lane>`, or creates it from `origin/master` (falling back to `master`). In the planning checkout it checks out or creates the spec branch `0NN-dNN-<name>` from HEAD. If git refuses the switch, the step stops: don't stash, reset or discard to get past it; ask the user.
- **Review:** `/speckit-review-implementation [lane=…] [base=…] [layers=…] [no-run] [fix]` reviews one lane against the merge base. It runs the CI checks the change triggers, checks every layer against the constitution, writes `specs/<spec>/reviews/<lane>-round-<K>.md`, and appends a `### Review fixes (round K)` block to the end of that lane's section. It never commits.
- Tests are mandatory in every `tasks.md`, even though `tasks-template.md` calls them optional (constitution, Quality Gates).
- To change an extension, edit `tools/speckit-extensions/<name>/`, never the installed copy in `.specify/extensions/`. Then run `specify extension add --dev tools/speckit-extensions/<name> --force`, then `specify integration use opencode && specify integration use claude` (an extension registers only for the default integration), then `chmod +x .specify/scripts/bash/*.sh` (the switch drops the bit). The Specify CLI generates and hash-tracks `.claude/skills/speckit-*`, `.opencode/commands/speckit.*`, `.specify/templates/` and `.specify/scripts/`; don't hand-edit them.

## Planned architecture (big picture)

One monorepo: `backend/`, `admin/`, `app/`, `infra/`, `docs/`, `.github/workflows/`.

- **Backend is FastAPI, not Django** (D5): SQLAlchemy 2 async, Alembic, Pydantic v2, Celery + beat, PostgreSQL 16, Redis 7. One package `backend/app` with two ASGI apps: `app.public:app` (the `/v1` API) and `app.admin:app` (`/admin/api`, bound to WireGuard `wg0` only). Admin routers must never be mounted on the public app.
- **Ingestion** uses scraper adapters (ysscores, LiveSoccerTV, sporteventz, YallaKora, API-Football) that implement the `SourceAdapter` protocol (§6.6): `fetch` → `parse` (pure, tested against saved raw pages) → `normalize`. They upsert by `(source, external_id)`, skip any field listed in `locked_fields` (admin edits win), and send unmatched names to `unresolved_names`.
- **Cache invalidation** uses `dataset_versions`. Each write bumps a version; Redis cache keys and ETags are built from the versions, so nothing is deleted by key scan. Admin mutations also write `audit_log` and require `If-Match`.
- **Push** uses an outbox. Producers only insert `notification_outbox` rows with a unique `dedupe_key`. One dispatcher claims rows with `FOR UPDATE SKIP LOCKED`, resolves devices with `SELECT DISTINCT` over `device_follows`, and sends through FCM. Devices are anonymous (no user accounts); auth is `Authorization: Device <token>`.
- **Match status** is an explicit state machine (§6.2.3). A clock-guessed "live" carries `estimated: true` and must never show a score or minute.
- **Time:** `kickoff_at` is UTC. Source times are Cairo wall-clock and are converted with `AT TIME ZONE 'Africa/Cairo'`. Clients group matches by the user's local date, not by `match_date`.
- **Flutter app** uses Riverpod, go_router, Dio + Retrofit generated from OpenAPI, freezed, and **drift** for the offline cache (P6: not Hive or Isar). It is feature-first with `data/domain/presentation` per feature. Native-only capabilities (ads, local notifications, widgets, Crashlytics) sit behind interfaces with web no-op implementations chosen by conditional import; feature code never imports those plugins directly. Repositories are stale-while-revalidate: emit the drift copy, then revalidate with `If-None-Match`. iOS ships as the Flutter web PWA until an Apple account exists.
- **Admin** is React 18 + Vite + TS strict + Tailwind v3 + React Query + RHF/Zod. The client and Zod schemas are generated by Orval from the admin OpenAPI spec.
- **Infra** must stay $0/month: 2 OCI Ampere arm64 VMs (every image `linux/arm64`), Docker Compose, Caddy, no Kubernetes and no CDN. Hosts are `sslip.io` names, and clients read API and media hosts from Firebase Remote Config.

API envelope: `{"success", "data", "error": {"code", "message"}, "meta"}`. Clients map `error.code` to Arabic copy. IDs are integers, times are ISO-8601 UTC, long lists use cursor pagination.

## UI implementation rules

From `madar-design/README.md`. Read it before building any screen.

- Values come only from tokens: `madar_tokens.dart` (Flutter; `context.madarColors`, `MadarText`, `MadarRadii`) or `tokens.css` / `tokens.ts` (admin). Never copy a hex value or pixel size from a screen file. `madar-design/design-system/TOKEN-ALIASES.md` maps the short mockup variables (`--s1`, `--tx2`, `--rd`) to tokens.
- Before building a screen, find its row in `app-flutter/SCREENS.md` or `admin-react/SCREENS.md`, look at the PNG, and read the HTML for structure, Arabic copy and states. The HTML is a mockup: rebuild it, never paste it.
- Build each component in `design-system/components/INDEX.md` once and follow its README's states and rules. Widget names match the component names (`MatchRow`, `StatusBlock`, `FrequencyReadout`, ...).
- The wordmark is «مدار», as drawn in the design package. Madar Sat / مدار سات is the product, app and store name; don't change the wordmark to it.
- RTL first; back arrows point right; the home team sits on the right. Latin channel and satellite names, frequencies and source codes are LTR islands (`TextDirection.ltr` / `<bdi dir="ltr">`).
- The frequency readout (`11843 H 27500`, IBM Plex Mono, cyan digits on a dark well) stays dark and LTR in both themes.
- `live` red is only for live matches; errors, red cards and deletes use `error`. Only one `accent` (volt) element per screen.
- Always render Western digits (0–9) with tabular figures. Do not rely on the `ar` locale, which can emit Arabic-Indic digits.
- Data is honest: an unknown kickoff shows «لم يُحدد», an estimated live state has no score, and stale data shows its age.

## Path gotchas

- `madar-design/**/SCREENS.md` and `madar-design/README.md` refer to `new_app/docs/...`; in this repo that is `docs/`.
- `madar-design/design-system/README.md` mentions `components/bundle.css`; the actual file is `madar-design/design-system/components.css`.
- Docs that mention `old_app/` mean the sibling `../old_app/`, which is not in this repo.
