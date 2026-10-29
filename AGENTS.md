# AGENTS.md

## Read first
- `.specify/memory/constitution.md` is the highest authority: principles, quality gates, fixed stack.
- `CLAUDE.md` is the architecture/UI brief (API envelope, ingestion, cache, push, client and design rules). Read it before planning code and keep it in sync.
- Source-of-truth order: constitution > `docs/system-design.md` (how) > `docs/product-business.md` (what/copy) > `madar-design/` (look) > `docs/delivery-plan.md` (when/who). Docs win on data and behaviour; the design package wins on visuals. If they conflict or are silent, stop and ask; never invent product behaviour.

## Current state
- As of this writing, design/spec phase only: no `backend/`, `admin/`, `app/`, `infra/`, `specs/`, or CI workflows exist yet. Do not scaffold them freehand; a day's Spec Kit spec creates them.
- There is no root package manifest, Makefile, or test suite. Do not guess commands.
- The only project tool today:
  ```bash
  python3 madar-design/design-system/code/generate_tokens.py
  ```
  It rewrites `tokens.css`, `code/flutter/madar_tokens.dart`, and `code/react/tokens.ts` from `tokens.json`. Edit `tokens.json`, never the generated files.
- The default branch is `master`, and it stays `master` (never renamed to `main`). Cut every branch from it.

## Spec Kit workflow
- One spec per working day (`specs/001-d01-foundation` … `030-d30-...`), never more. The default integration is Claude Code (`.claude/skills/speckit-<step>/SKILL.md`): `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-analyze` → `/speckit-implement` → `/speckit-review-implementation`. opencode is installed too (`.opencode/commands/speckit.<step>.md`, invoked as `/speckit.<step>`), so a lane can implement there on another model and be reviewed in Claude Code.
- `tasks.md` must contain `## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M`, and `## Done check`. A lane edits and ticks only its own section.
- Lane ownership: B1 `backend/` (except `app/adapters/`) + Alembic + OpenAPI contract; B2 `infra/`, `backend/app/adapters/`, CI; A `admin/`; M `app/`. Never edit another lane's folder.
- Branch names do not match spec folders. This Spec Kit version resolves the active spec from `SPECIFY_FEATURE_DIRECTORY=specs/0NN-dNN-<name>` or `.specify/feature.json`; `SPECIFY_FEATURE` alone (as in delivery-plan §5.1) is not enough.
- Worktrees must be siblings of this repo (`../madar-b1`, etc.) so `../old_app/` resolves the same way everywhere. Cut `dNN-<lane>` from the base branch.
- Branches are handled by the project's `feature-branch` hook (`.specify/extensions.yml`), which runs after specify and before clarify, plan, tasks, analyze, checklist, implement, converge and taskstoissues. In a lane session (`MADAR_LANE`, else a `madar-<lane>` worktree folder, else a current `dNN-<lane>` branch) it checks out `dNN-<lane>`, or creates it from `origin/master` (falling back to `master`); in the planning checkout it checks out or creates the spec branch `0NN-dNN-<name>` from HEAD. It never stashes, resets or discards; if git refuses the switch, the step stops. Don't force past it; ask the user.
- `/speckit-review-implementation` reviews one lane (`lane=<b1|b2|a|m>`, else detected like the hook) against the merge base: it runs the CI checks the change triggers, reviews each layer against the constitution, writes `specs/<spec>/reviews/<lane>-round-<K>.md`, and appends a `### Review fixes (round K)` block to the end of that lane's section in `tasks.md`. Arguments: `lane=`, `base=`, `layers=`, `no-run`, `fix`.
- The extension sources are `tools/speckit-extensions/{feature-branch,review}/`; never edit the installed copies under `.specify/extensions/`. After a change, run `specify extension add --dev tools/speckit-extensions/<name> --force` (it registers for the default integration only), then `specify integration use opencode`, `specify integration use claude`, and `chmod +x .specify/scripts/bash/*.sh` (the switch drops the bit).

## Fixed stack and contract (do not substitute)
- Backend: FastAPI (not Django), SQLAlchemy 2 async, Alembic, Pydantic v2, PostgreSQL 16, Redis 7. Two ASGI apps: public `app.public:app` (`/v1`) and admin `app.admin:app` (`/admin/api`, WireGuard only). Never mount admin routers on the public app.
- API: envelope `{"success", "data", "error": {"code", "message"}, "meta"}`, ISO-8601 UTC, integer IDs, cursor pagination, ETag on GETs, and `If-Match` + `audit_log` + `dataset_versions` on admin writes. B1 owns the contract.
- App: Flutter + Riverpod only, go_router, Dio + Retrofit, drift (not Hive/Isar), feature-first `data/domain/presentation`.
- Admin: React 18 + Vite + TS strict + Tailwind v3 + React Query + RHF/Zod.
- Never hand-edit generated artifacts: design tokens, Dart/TS API clients, Orval Zod schemas.
- Ship unfinished features dark behind Remote Config `features.*`; API and media hosts come from Remote Config, not hardcoded.

## UI work
- Start at `madar-design/README.md`. Hierarchy: `tokens.json` > component READMEs > screen HTML > PNG.
- Before building a screen, open its row in `madar-design/app-flutter/SCREENS.md` or `admin-react/SCREENS.md`, view the PNG, and read the HTML for structure, Arabic copy, and states. Rebuild it; never paste mockup HTML.
- The wordmark is «مدار», as drawn in the design package. Madar Sat / مدار سات is the product, app and store name; don't change the wordmark to it.
- Hard rules: RTL first; Latin channel/satellite names and frequencies are isolated LTR; Western tabular digits; `live` red only for live (use `error` for errors, red cards, deletes); one `accent` per screen; `FrequencyReadout` stays dark and LTR in both themes; touch targets ≥ 48 dp.
- Path traps: design docs' `new_app/docs/...` means this repo's `docs/`; `old_app/` means sibling `../old_app/`; `components/bundle.css` does not exist—use `madar-design/design-system/components.css`.

## Tests and safety
- Tests are mandatory in `tasks.md`; write them failing first. Database tests use real PostgreSQL 16, never SQLite. Coverage gate: ≥ 80% in `backend/`, `admin/`, and `app/`.
- Adapter `parse` is pure and tested against saved raw pages. Flutter widget tests run RTL at 1.3× text scale in both themes.
- From `../old_app/`, copy only `migration/schema.sql`; never commit `migration/data/` or the old Firebase web config (D15). No secrets in the repo.
- Commits use Conventional Commits. A new recurring cost or stack substitution needs a decision in `docs/system-design.md` §3, plus a constitution amendment if it changes a rule.

<!-- lean-ctx -->
## lean-ctx

lean-ctx is active — the MCP tools replace native equivalents.
Full rules: LEAN-CTX.md (open on demand — do not auto-load).
<!-- /lean-ctx -->
