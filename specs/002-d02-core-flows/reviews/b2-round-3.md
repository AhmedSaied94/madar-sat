# Implementation review: 002-d02-core-flows, lane B2, round 3

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); a layer subagent on Sonnet, every finding re-checked here
- Branch: `d02-features` (not `d02-b2`; the same combined checkout rounds 1 and 2 reviewed) · Base: `origin/master` (merge base `68f1752`) · Head: `635919d`, plus 158 uncommitted files across the four lanes
- Change (lane B2, this round): no new commit. The round-2 fixes, uncommitted: `backend/app/adapters/{fetcher,messages,satair_bridge,tasks,ysscores}.py` and six adapter test files, `.github/actions/vps1-sync/action.yml`, `.github/workflows/{app,backend,infra}.yml`, `infra/redis/users.acl.tmpl`, `infra/scripts/{bootstrap-vps,deploy}.sh`, three untracked scripts (`check-redis-acl.sh`, `render-redis-acl.sh`, `ssh-config.sh`), `infra/README.md`, eight runbooks and `docs/owner-actions.md`. Nothing in another lane's folder.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 4 · LOW 5 (1 PLAUSIBLE)

The three round-2 blockers are fixed and each one is guarded by a check that fails on revert: the ACL directory is `750` with group 999, the action calls `ssh-config.sh` by its real path, and a real Celery worker runs as `homebox`. `infra.yml`'s shellcheck and actionlint now pass, and the Firebase key is in a header and out of the logs. Four MEDIUMs remain: one fetch path still leaves no `import_runs` row, the deploy's first `up` can strand Redis on a refused ACL, a rotation step uses a VPS-1 helper on VPS-2, and the new `infra/compose/**` filter makes an infra-only push build and deploy a release, which the runbook says it doesn't.

## Checks

Checks ran in a snapshot of this working tree (`git ls-files -co --exclude-standard`), against the dev PostgreSQL 16 (`:5434`) and Redis 7 (`:6380`).

| Check | Command | Result |
| --- | --- | --- |
| ruff, mypy | `uv run ruff check .`; `uv run mypy --strict app` | exit 0, clean |
| pytest (whole backend) | `uv run pytest --cov --cov-report=term` | exit 0; coverage 96.28 % (the adapter tests, including `test_homebox_acl.py`'s real worker, are in it) |
| compose | `docker compose -f infra/compose/{vps1,vps2,dev,home-box}.yml --env-file infra/compose/example.env config -q`, each also with `--profile workers --profile tools` (as `infra.yml:35-37` runs it) | exit 0 for all eight |
| shellcheck | `docker run koalaman/shellcheck:v0.11.0 --external-sources infra/scripts/*.sh` (as `infra.yml:219`) | **exit 0** |
| actionlint | `docker run rhysd/actionlint:1.7.12 -color=false` (as `infra.yml:222`) | **exit 0** |
| api-admin command | `uv run gunicorn --check-config …` (the `vps1.yml` command) with the CI env | exit 0 |
| secrets | gitleaks v8.30.1 `dir .` from the snapshot root with `.gitleaks.toml` | exit 0, no leaks |
| `ssh-keyscan`, `envsubst`, a real Redis restart with a refused ACL | | **NOT RUN**: not on the lean-ctx shell allowlist / needs a host |
| T086, T087 on the hosts | | **NOT RUN**: nothing is deployed |

Ways around the checks: no new skip, `xfail`, `# type: ignore` or config change. `render-redis-acl.sh` and `check-redis-acl.sh` each carry one scoped `shellcheck disable` with a reason.

## Previous round

| Finding | Now |
| --- | --- |
| B2-R2-1 CRITICAL, ACL directory unreadable by Redis | fixed: `render-redis-acl.sh` installs the directory `750` and the file `640`, both group 999, on every run; `bootstrap-vps.sh:178` agrees; `check-redis-acl.sh` has a 700-directory negative fixture |
| B2-R2-2 HIGH, wrong `ssh-config.sh` path | fixed: `.github/actions/vps1-sync/action.yml:55`; an `infra.yml` step extracts the path and runs it |
| B2-R2-3 HIGH, `homebox` kills a worker | fixed: `users.acl.tmpl:13` adds `&celery:/0.celery.pidbox`; `test_homebox_acl.py:135-201` starts a real worker (B2-R3-5) |
| B2-R2-4 HIGH, shellcheck and actionlint fail | fixed: both exit 0 |
| B2-R2-5 HIGH, Firebase key logged | fixed: `satair_bridge.py:78-82` sends `X-Goog-Api-Key`; `fetcher.py` strips the query from messages; `test_satair_bridge.py:209-253` |
| B2-R2-6 HIGH, no `import_runs` row on some failures | mostly fixed: `tasks.py:158-173` adds the transport and catch-all paths, `ysscores.py:126` the empty body. Setup errors still escape (B2-R3-1) |
| B2-R2-7 VPS-2 host key | fixed: `provision-host.md:364-367` |
| B2-R2-8 Redis rotation | mostly fixed: steps 2 and 4 are right; step 3 is not (B2-R3-3) |
| B2-R2-9 home-box ACL command | fixed: `home-box.md:84` |
| B2-R2-10 gid without a group | fixed: `bootstrap-vps.sh:56`, guarded by an `infra.yml` step |
| B2-R2-11 reload not atomic | fixed for the restart: `deploy.sh:164-179` restores `users.acl.prev` and pings both users. The `up` before it is not covered (B2-R3-2) |
| B2-R2-12 VPS-2 `up -d` unguarded | fixed: `deploy.sh:264,277`, driven by an `infra.yml` step under `set -e` |
| B2-R2-13 Lane M's CI asks | fixed: `app.yml:69-73` builds the web app and runs `check_web_assets.sh`; the providers check moved into `flutter test` (Lane M) |
| B2-R2-14 api-admin check path filter | fixed, with a side effect (B2-R3-4) |
| B2-R2-15 runbooks | mostly fixed; `deploy-and-rollback.md:3` is now wrong (B2-R3-4) |
| B2-R2-16 total bound | fixed: `messages.py` `MAX_PAGES`, `MAX_TOTAL_BYTES`, before-parse check, `tracemalloc` test |
| B2-R2-17 sleeping test | fixed: `test_fetcher.py:147-188` uses a fake clock |
| B2-R2-18 unproven guards | fixed: `test_upsert.py:293`, `test_tasks.py:659-695` |
| B2-R2-19 (PLAUSIBLE) no total fetch deadline | still open, not tasked |
| B2-R2-20, -21 (LOW) | still open, not tasked |
| B2-R2-23 (LOW) password in argv | partly fixed (B2-R3-6) |
| B2-R2-22 (LOW) | fixed |
| B2-R2-24 … -27 (LOW) | not re-checked |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

#### B2-R3-1: a setup error in `adapters.fetch` still leaves no `import_runs` row
- pipelines · FR-025, SC-005, B2-R2-6 · `backend/app/adapters/tasks.py:124,130-131` · CONFIRMED
- Problem: `date.fromisoformat(start)` (`:124`), `http_fetcher()` and `adapter_for()` (`:130-131`) run outside the `try` that sends the failed result. `http_fetcher()` calls `get_adapter_settings().require_user_agent()` and `redis_client()`.
- Failure scenario: `SCRAPE_USER_AGENT` is missing on the home box. Every scheduled fetch raises before the `try`, so no `failed` result reaches `ingest`, no `import_runs` row is written, and the first sign is a day of stale fixtures: the case B2-R2-6 was meant to close.
- Fix direction: build the fetcher and adapter inside the guarded block (with `fetcher.close()` only when it exists), or send `_send_failure(..., "fetch_error")` for a setup error. Test with a missing user agent.

#### B2-R3-2: the deploy's first `up` can leave Redis down on a refused ACL
- ops · constitution IX, B2-R2-11 · `infra/scripts/deploy.sh:190-192` (`deploy_vps1`) and `:320-322` (`--infra-only`) · CONFIRMED
- Problem: `render_redis_acl` installs the new file, then `up -d --wait … redis` runs before `reload_redis_acl`. The restore from `users.acl.prev` lives only in `reload_redis_acl`, and `deploy.sh` has no ERR trap (`:317` traps EXIT for the GHCR logout only).
- Failure scenario: a change recreates the Redis container (an image bump, or a changed environment) in the same deploy as an ACL Redis refuses. `--wait` fails, `set -e` exits, and Redis stays down on the bad file with the good one sitting in `users.acl.prev`.
- Fix direction: put the restore around the `up` too (one function both paths call), and cover it in `check-redis-acl.sh` or an `infra.yml` step.

#### B2-R3-3: the Redis rotation's VPS-2 step uses VPS-1's `dc` helper
- ops · runbook rule (CLAUDE.md), B2-R2-8 · `docs/runbooks/secrets.md:143` · CONFIRMED
- Problem: `dc up -d --force-recreate worker-imports worker-scrape worker-maintenance beat`. `dc` is defined only in `deploy-and-rollback.md:49`, as `docker compose --env-file /srv/madar/.env -f compose/vps1.yml`, with no `--profile workers` and no `IMAGE_TAG`.
- Failure scenario: the owner runs it on VPS-2: `dc` is undefined, or, copied over, it targets `vps1.yml`, where those services don't exist. The workers stay on the old password and fail to connect.
- Fix direction: write the full command, as `imports-and-sources.md:125` does (`IMAGE_TAG=$(cat /srv/madar/current_tag) docker compose --env-file /srv/madar/.env --profile workers -f /srv/madar/infra/compose/vps2.yml up -d --force-recreate …`).

#### B2-R3-4: an infra-only compose change on `master` now builds and deploys a release, and the runbook says it doesn't
- ops · runbook rule, B2-R2-14 · `.github/workflows/backend.yml:15`; `docs/runbooks/deploy-and-rollback.md:3,218-222` · CONFIRMED
- Problem: `infra/compose/**` was added to the `push` filter, not only to `pull_request`. A merge that touches only `infra/compose/vps1.yml` now runs `backend.yml`'s build, GHCR push and both deploys, alongside `infra.yml`'s `sync`. `deploy-and-rollback.md:3` still says such a push "applies the infra files without a new image".
- Failure scenario: the owner merges a Caddy-adjacent compose tweak expecting a short infra sync; instead a full release rolls out to both VPSes (new tag, migrations, worker restarts), and the runbook gives no reason.
- Fix direction: keep `infra/compose/**` on `pull_request` only (or move the api-admin command check into `infra.yml`), or keep it and correct the runbook. The first matches what the task asked for.

### LOW

#### B2-R3-5: the `homebox` worker test differs from how the box runs
- tests · `backend/tests/adapters/test_homebox_acl.py:135-201` vs `infra/compose/home-box.yml:22,33` · PLAUSIBLE
- The test runs `--pool=solo --without-heartbeat` and pings as `default`; the box runs prefork `-c 1` with heartbeat and its health check pings as `homebox`. Ping with the `homebox` URL to cover the health check's path.

#### B2-R3-6: the `redis-cli` password is still in the `docker` client's argv
- security · `infra/scripts/deploy.sh:141` · CONFIRMED
- `exec -e REDISCLI_AUTH="$password"` puts the value on the host's `ps`; the comment says it isn't. Export it and pass `-e REDISCLI_AUTH` by name.

#### B2-R3-7: the gid step's `awk` range sources more than one function
- ci · `.github/workflows/infra.yml` (the `group_for_gid` step) · CONFIRMED
- `/^group_for_gid\(\)/,/^}/` on a one-line function runs to the next function's `}`. Harmless today.

#### B2-R3-8: three new scripts are untracked
- ops · `infra/scripts/{ssh-config,check-redis-acl,render-redis-acl}.sh` · CONFIRMED
- `action.yml`, `deploy.sh` and `infra.yml` depend on them; the commit must add them.

#### B2-R3-9: `render-redis-acl.sh` doesn't reject whitespace in a password
- ops · `infra/scripts/render-redis-acl.sh` (`env_get`) · CONFIRMED
- A password with a space splits the ACL line. The generated ones are hex, so document or reject it.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| FR-025 / SC-005, every fetch writes an `import_runs` row | `adapters/tasks.py:130-173` | `test_tasks.py:489,511,524` | partly met (B2-R3-1) |
| D15 / FR-027, no key in logs | `satair_bridge.py:78-82`, `fetcher.py` | `test_satair_bridge.py:209-253` | met |
| R20-R22, deploy migrates, checks health and rolls back on both hosts | `deploy.sh` | `infra.yml` VPS-2 rollback step | met; Redis ACL restore partial (B2-R3-2) |
| Redis ACL loads as deployed and `homebox` runs a worker | `render-redis-acl.sh`, `users.acl.tmpl` | `check-redis-acl.sh`, `test_homebox_acl.py` | met |
| message size bounds | `messages.py` | `test_messages.py` (`tracemalloc`) | met |

## Task audit

Ticked 18 (round-2 block), verified 16, not done 0, partly done 2:

| Task | Gap |
| --- | --- |
| B2-R2-6 | setup errors before the `try` (B2-R3-1) |
| B2-R2-8 | the VPS-2 step is not runnable there (B2-R3-3) |

## Owner must review

- `infra/scripts/deploy.sh` and `render-redis-acl.sh`: the ACL render, restore and reload order (B2-R3-2).
- `infra/redis/users.acl.tmpl`: the `homebox` grants (`~celery:* ~ratelimit:* ~lock:fetch:*`, `&celery:* &celery:/0.celery.pidbox`).
- `.github/workflows/backend.yml:10-20`: whether an infra-only compose change should deploy a release (B2-R3-4).

## Outside this change

- Agent setup in `.specify/`, `.claude/` and `.opencode/`: none changed.

## Not reviewed

- Anything on the hosts (T086, T087), `ssh-keyscan`, and a real Redis restart with a refused ACL.
- B2-R2-24 … -27 (LOW) were not re-checked.
