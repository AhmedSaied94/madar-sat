# Implementation review: 002-d02-core-flows, lane B2, round 4

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`), no subagents (the delta is small enough to read in full)
- Branch: `d02-features` (the combined checkout of rounds 1–3) · Base: `origin/master` (merge base `68f1752`) · Head: `635919d`, plus the uncommitted work of all four lanes
- Change (lane B2, this round): the round-3 fixes, uncommitted: `backend/app/adapters/tasks.py`, `backend/tests/adapters/test_tasks.py`, `infra/scripts/deploy.sh`, `.github/workflows/{backend,infra}.yml`, `infra/README.md`, `docs/runbooks/{secrets,deploy-and-rollback,ci-workflows}.md`, and the lane's own `tasks.md` section. Nothing in another lane's folder.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 0 · LOW 0 new (round 3's five LOWs are still open, untasked)

All four round-3 MEDIUMs are fixed, and each fix comes with a test or CI step that fails on revert. The fix to B2-R3-2's CI step also repaired the earlier VPS-2 rollback step: its stub never matched, so it had been testing only the healthy path.

## Checks

The checks ran in a snapshot of this working tree, against the dev PostgreSQL 16 (`:5434`) and Redis 7 (`:6380`).

| Check | Command | Result |
| --- | --- | --- |
| ruff, mypy | `uv run ruff check .`; `uv run mypy --strict app` | exit 0, clean |
| pytest | `uv run pytest --cov --cov-report=term` | exit 0; coverage 96.39 % |
| compose | `docker compose -f infra/compose/{vps1,vps2,dev,home-box}.yml --env-file infra/compose/example.env --profile workers --profile tools config -q` | exit 0 for all four |
| shellcheck | `koalaman/shellcheck:v0.11.0 --external-sources infra/scripts/*.sh` | exit 0 |
| actionlint | `rhysd/actionlint:1.7.12 -color=false` | exit 0 (it also shellchecks the new `infra.yml` step) |
| secrets | gitleaks v8.30.1 `dir .` from the snapshot root | exit 0 |
| the new `infra.yml` restore step, run locally | | **NOT RUN**: running a bash script is not on the lean-ctx shell allowlist; its logic was read (below) |
| T086, T087 on the hosts | | **NOT RUN**: nothing is deployed |

Ways around the checks: none in this delta. The new `shellcheck disable=SC2034` lines in `infra.yml` are for variables that only the extracted functions read. Each one has a reason.

## Previous round

| Finding | Now |
| --- | --- |
| B2-R3-1 setup errors leave no run row | fixed: `tasks.py:129-139` builds the date, fetcher and adapter inside the `try`. `_pages_of`/`_http_errors_of` (`:199-204`) cover a fetcher or adapter that was never built, and `finally` closes only a fetcher that exists. `test_a_missing_user_agent_still_writes_a_failed_run` and `test_a_bad_start_argument_still_writes_a_failed_run` (`test_tasks.py:714-749`) assert a `failed`/`fetch_error` row. Both fail on revert. |
| B2-R3-2 the first `up` strands Redis | fixed: `apply_stateful_infra` (`deploy.sh:189-203`) restores `users.acl.prev`, only when this deploy wrote a new file, and retries once. `deploy_vps1` (`:216`) and `--infra-only` (`:346`) both call it, and `reload_redis_acl` shares `restore_previous_acl` (`:162-167`). The `infra.yml:218-269` step fails without the restore and checks that a healthy `up` keeps the new file. |
| B2-R3-3 rotation's VPS-2 step | fixed: `secrets.md:140-149` gives the full command. It matches `deploy.sh:55` (`--profile workers -f …/vps2.yml`), `:51` (the four services) and `:248` (`/srv/madar/current_tag`). |
| B2-R3-4 compose-only push deploys | fixed: `backend.yml:11-20` keeps `infra/compose/**` on `pull_request` only. `ci-workflows.md:9` and `infra/README.md:128` say so, and `deploy-and-rollback.md:3` is true again. |
| B2-R3-5 … B2-R3-9 (LOW) | still open, not tasked |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

None.

### LOW

None new. Round 3's LOWs (B2-R3-5 to -9) stand as written in `b2-round-3.md`.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| FR-025 / SC-005, every fetch writes an `import_runs` row | `adapters/tasks.py:120-196` | `test_tasks.py:489-749` | met |
| R20-R22, a deploy can't leave Redis down on a refused ACL | `deploy.sh:162-203` | `infra.yml:218-269` | met |
| runbooks match the code (rotation, deploy triggers) | `secrets.md`, `deploy-and-rollback.md`, `ci-workflows.md` | read against `deploy.sh`, `backend.yml` | met |

## Task audit

Ticked 4 (the round-3 block), verified 4, not done 0, partly done 0.

## Owner must review

- `infra/scripts/deploy.sh:162-203`: the restore-and-retry around the stateful `up`.

## Outside this change

- Lane M asks Lane B2 for a stale-`*.g.dart` check in `app.yml` (`docs/owner-actions.md:286`, M-R3-2). No B2 task carries it yet. Add one to B2's next day or a follow-up.

## Not reviewed

- The new `infra.yml` step was not executed locally (allowlist), and nothing ran on a host.
