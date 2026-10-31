# Implementation review: 002-d02-core-flows, lane B2, round 2

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); layer subagents on Sonnet (pipelines, ops), every finding re-checked here
- Branch: `d02-features` · Base: `master` (merge base `68f1752`) · Head: `6f81c90` when reviewed, plus 106 uncommitted files (the round-1 fixes of B1, B2 and A). `3ac2bf5` has since committed Lane A's and Lane M's fixes; B2's files are still uncommitted and unchanged from what was reviewed.
- Change (lane B2, this round): no new commit. 27 tracked files under `infra/`, `.github/`, `backend/app/adapters/` and `backend/tests/adapters/` (+981 −174), 2 new ones (`infra/scripts/check-redis-acl.sh`, `backend/tests/adapters/test_homebox_acl.py`), and the runbooks and `docs/owner-actions.md`. Nothing in another lane's folder.
- Verdict: **BLOCK** · CRITICAL 1 · HIGH 5 · MEDIUM 13 (1 PLAUSIBLE) · LOW 8 (1 PLAUSIBLE)

The data path holds up. The round-1 importer fixes (links, postponed items, TBD kickoffs, the ingest failure record, savepoints) are real and each one has a test that fails on revert. The hosts do not hold up yet. Round 1's CRITICAL comes back with a new cause: the ACL file is readable now, but its directory is not, so Redis still aborts on the first deploy. Two other round-1 fixes break something new. The narrowed `homebox` ACL kills a real Celery worker. The deploy action calls `ssh-config.sh` by a wrong path. `infra.yml`'s own shellcheck and actionlint steps fail. On the pipeline side, INFO logging now prints the bridge's Firebase key, and a transport error still leaves no `import_runs` row.

## Checks

Backend checks ran in a snapshot of this working tree (`git ls-files -co --exclude-standard`), against the dev PostgreSQL 16 (`:5434`) and Redis 7 (`:6380`). Its `infra/`, `.github/` and `docs/` are identical to the working tree (`diff -rq`, empty).

| Check | Command | Result |
| --- | --- | --- |
| ruff, mypy | `uv run ruff check .`; `uv run mypy --strict app` | exit 0, clean |
| pytest (whole backend) | `uv run pytest --cov` | exit 0: 1068 passed, 1 skipped (pre-existing, `tests/db/test_migrations.py:150`) |
| adapter tests by mutation | 14 one-line mutants of `upsert.py`, `tasks.py`, `fetcher.py` and `messages.py`, each followed by its test file (in a second copy) | 12 killed, 2 survived (B2-R2-16, B2-R2-18) |
| compose | `docker compose -f infra/compose/{vps1,vps2,dev,home-box}.yml config -q`, and vps1/vps2 with `--profile workers --profile tools` | exit 0 for all |
| shellcheck | `docker run koalaman/shellcheck:v0.11.0 --external-sources infra/scripts/*.sh` (as `infra.yml` runs it) | **exit 1**: SC2016 at `check-redis-acl.sh:30` (B2-R2-4) |
| actionlint | `docker run rhysd/actionlint:1.7.12` (as `infra.yml:137-138` runs it) | **exit 1**: SC2016 at `infra.yml:52` (three places) and `:87` (B2-R2-4) |
| Redis reads the ACL as deployed | `redis:7.4.12` with the rendered file `0:999` mode 640, in a directory of mode 700, 750 and 755 | **700: exit 1, 750: exit 1** (`opening file '/etc/redis/users.acl': Permission denied`); 755: `PONG` for both users (B2-R2-1) |
| a real worker as `homebox` | `celery worker -Q scrape_home --without-gossip --without-mingle` (Celery 5.6.3) as `homebox` against `redis:7.4.12` loaded from the real template | **exits**: `NoPermissionError('No permissions to access a channel')`; `ACL LOG` names `celery:/0.celery.pidbox`, `psubscribe` (B2-R2-3) |
| firewall expectations by role | `check-firewall.sh --role {vps1,vps2}` on rendered rulesets | rc 0 on the right host, rc 1 on the wrong one; an open SSH rule on VPS-2 also gives rc 0 (B2-R2-21) |
| ssh config | `ssh-config.sh` into scratch, then `ssh -G -F config vps2` | exit 0: `user deploy`, `proxyjump vps1`, `stricthostkeychecking true`, `batchmode yes`; no `hostkeyalias` |
| the action's script path | `ls .github/actions/vps1-sync/../../infra/scripts/ssh-config.sh` | **no such file** (B2-R2-2) |
| api-admin command | `uv run gunicorn --check-config …` (the command in `infra/compose/vps1.yml`) | exit 0 |
| secrets | gitleaks v8.30.1, `git` over the snapshot and `dir` over `infra/`, `.github/` and the runbooks | exit 0, no leaks |
| runbook links | a relative-link and anchor checker over `docs/` | 0 broken |
| `ssh-keyscan` for VPS-2, `envsubst` | | **NOT RUN**: neither is on the lean-ctx shell allowlist (`sed` stood in for `envsubst` in the firewall render) |
| T086, T087 on the hosts | | **NOT RUN**: nothing is deployed |

Ways around the checks: no new skip, `xfail` or config change; one new `# type: ignore[arg-type]` (`backend/tests/adapters/test_fetcher.py:218`, B2-R2-17).

## Previous round

| Finding | Now |
| --- | --- |
| B2-R1-1 CRITICAL Redis can't read the ACL | **Regressed**: same outage, new cause (B2-R2-1) |
| B2-R1-2 ysscores wiped the snapshot's links | **Fixed** (`base.py:96,122`, `upsert.py:187-190`; mutants killed) |
| B2-R1-3 `--proxy-headers` | **Fixed** (`vps1.yml:76-85`, `backend.yml:86-106` runs `gunicorn --check-config`); the check's path filter misses `infra/` (B2-R2-14) |
| B2-R1-4 the VPS-2 SSH hop | **Partly fixed**: `ssh-config.sh` is right, but the action calls it by a wrong path (B2-R2-2) and the known-hosts procedure can't work (B2-R2-7) |
| B2-R1-5 `/srv/raw` on VPS-2 | **Fixed** (`bootstrap-vps.sh` `ensure_dirs`) |
| B2-R1-6 firewall checks by role | **Fixed** (`check-firewall.sh --role`); one dead expectation (B2-R2-21) |
| B2-R1-7 Redis password rotation | **Partly fixed**: `deploy.sh:149-165` restarts on a change, but not atomically and checking `default` only (B2-R2-11); the runbook's step renders nothing (B2-R2-8) |
| B2-R1-8 rate-limited runs fail | **Fixed** (`fetcher.py:179-189`: a 4-day run waits 8.0 s from a fresh bucket); its test sleeps for real (B2-R2-17); no total time bound (B2-R2-19) |
| B2-R1-9 a failed fetch leaves no record | **Partly fixed**: transport errors, an empty body and an oversize result still escape (B2-R2-6) |
| B2-R1-10 postponed fixtures | **Fixed** (decided: imported with no kickoff); `run.json["postponed"]` untested (B2-R2-18) |
| B2-R1-11 locked kickoff and TBD | **Fixed** (`upsert.py:335-340`; the CHECK violation mutant is killed) |
| B2-R1-12 ingest failure record | **Fixed** (`tasks.py:219-264`, `upsert.py:112-125`) |
| B2-R1-13 gzip bomb | **Partly fixed**: one page is bounded, the message is not (B2-R2-16) |
| B2-R1-14 orphan channels | **Fixed** (`upsert.py:438`), with a side effect (B2-R2-25) |
| B2-R1-15 worker logs at INFO | **Fixed** in compose; INFO now prints the bridge key (B2-R2-5) and whole task payloads (B1-R2-7) |
| B2-R1-16 tests that can't fail | **Partly fixed**: the lock and savepoint tests are real now; the re-add path still can't fail (B2-R2-18) |
| B2-R1-17 the ACL placeholder check | **Fixed** (`infra.yml:51-80`); `nopass` and `#<hash>` slip through (B2-R2-20) |
| B2-R1-18 `homebox` ACL | **Regressed**: a real worker can't start (B2-R2-3) |
| B2-R1-19 ysscores routing | **Fixed** (the runbook passes `--queue`; B1 routes lazily) |
| B2-R1-20 runbook commands | a, b, e **fixed**; c partly (B2-R2-8); d still wrong (B2-R2-9); f still wrong (B2-R2-7) |
| B2-R1-21 owner actions | **Partly fixed**: counts, links and IDs are right; the T082 proof uses a variable the box doesn't have (B2-R2-15) |
| B2-R1-22 host docs | **Fixed** |
| B2-R1-23, B2-R1-28 (PLAUSIBLE) | Still open, unchanged |
| B2-R1-24 unguarded `up -d` | **Partly fixed**: VPS-1 is guarded, VPS-2 is not (B2-R2-12) |
| B2-R1-25 the home-box Redis rule | **Partly fixed**: the before-merge step exists; README's order disagrees (B2-R2-15) |
| B2-R1-26 `legacy_id` overwritten | Still open, CONFIRMED again: two listings with one `ys_match_id` give `(0, 2, 0)` every run |
| B2-R1-27 list times assumed Cairo | Still open: owner check, not recorded anywhere |
| B2-R1-29 the key in `ResponseTooLarge` | Still open, now logged (B2-R2-5) |
| B2-R1-30 to B2-R1-38 (LOW) | Still open, unchanged (`raw_store` source join, no `https`/port check, `team_external_ids` never written, team name overwrite, home-box install steps, `vps1.rules:55` without `-i wg0`, VPS-2 deploy group, docs drift, no saved `--:--` page) |

## Findings

### CRITICAL

#### B2-R2-1: the ACL directory is mode 700 (or 750) for `deploy`, so Redis (uid 999) still can't open the ACL file
- Layer `ops` · Source constitution IX (a deploy never takes the running release down) and V, T081, B2-R1-1 · `infra/scripts/deploy.sh:131` (`install -d -m 700 "$state_dir/redis"`, re-applied on every run), `infra/scripts/bootstrap-vps.sh:173` (`install -d -m 750 -o deploy -g deploy /srv/madar/redis`), `infra/compose/vps1.yml:181` (`/srv/madar/redis:/etc/redis:ro`), `infra/scripts/check-redis-acl.sh:26` (`chmod 755 "$tmp"`) · CONFIRMED (Redis boot above)
- Problem: the round-1 fix mounts the directory and makes the file 640 with group 999. The directory, though, is owned by `deploy` with mode 700 or 750, and the `redis` user (uid 999) is neither its owner nor in its group, so it can't traverse it.
- Failure scenario: the first D2 `sync` or `deploy` runs `up -d --wait … redis`. Redis aborts with `Error loading ACLs … Permission denied`, `--wait` fails under `set -e`, and `/healthz` answers 503 with no rollback: the round-1 outage again. CI is green because `check-redis-acl.sh` builds its own 755 directory, and never runs `deploy.sh`'s render code or modes.
- Fix direction: make the directory group 999 with mode 750 (or 755; the 640 file is the protection). Move the render into one script that both `deploy.sh` and the CI check call, so CI sees the real directory mode, file mode, owner and group. Add a negative fixture: a 700 directory must fail the check.

### HIGH

#### B2-R2-2: the `vps1-sync` action calls `ssh-config.sh` by a wrong path, so every deploy and sync fails
- Layer `ops` · Source FR-029, T085, constitution IX, B2-R1-4 · `.github/actions/vps1-sync/action.yml:55` (`"$GITHUB_ACTION_PATH/../../infra/scripts/ssh-config.sh"`) · CONFIRMED (`ls` above)
- Problem: `GITHUB_ACTION_PATH` is `.github/actions/vps1-sync`, so `../../` is `.github/`. The script is at `../../../infra/scripts/ssh-config.sh`.
- Failure scenario: the action's "ssh" step exits 127, so `deploy`, `deploy-vps2` and `infra.yml`'s `sync` all fail before they connect. Production is untouched, but nothing can deploy. CI doesn't notice, because `infra.yml:118` calls the script from the repo root.
- Fix direction: `"$GITHUB_WORKSPACE/infra/scripts/ssh-config.sh"` (or `../../../`). Add a CI step that runs the path the action uses.

#### B2-R2-3: the narrowed `homebox` ACL makes a real Celery worker exit on start
- Layer `security` · Source T081 (ticked), research R21, FR-028, B2-R1-18 · `infra/redis/users.acl.tmpl:13` (`&celery:*`); `backend/tests/adapters/test_homebox_acl.py:71-95` · CONFIRMED (real worker above)
- Problem: the worker's control channel `PSUBSCRIBE`s `celery:/0.celery.pidbox`, and Redis matches a `PSUBSCRIBE` pattern literally against the user's channel patterns, so `&celery:*` doesn't allow it. With `&celery:/0.celery.pidbox` added, the same worker started, answered `inspect ping` and ran a task.
- Failure scenario: the home-box worker never starts, and its health check (`celery inspect ping`) fails too. ysscores is fetched only from the home box (R21), so no ysscores fixtures arrive and SC-004 fails. The test passes because it runs a kombu producer and a `SimpleQueue`, never a worker. The round-1 closing note ("a real kombu run showed the transport needs sets and pub/sub") does not hold for a worker.
- Fix direction: add `&celery:/0.celery.pidbox` (db-specific) to the `homebox` line, and fix the template comment that says it "may not touch a `set`" (`+@write` grants `SADD`). Make the test start a real worker as `homebox` and `inspect ping` it.

#### B2-R2-4: `infra.yml`'s own shellcheck and actionlint steps fail
- Layer `ops` · Source constitution quality gates, B2-R1-1, B2-R1-17 · `infra/scripts/check-redis-acl.sh:30`; `.github/workflows/infra.yml:52` (script lines 5 and 20) and `:87` · CONFIRMED (both images above, exit 1)
- Problem: SC2016 on each `envsubst '${…}'` line. `deploy.sh` already carries `# shellcheck disable=SC2016` for the same pattern.
- Failure scenario: the infra `check` job is red on every PR, so `sync` (`needs: check`) never runs.
- Fix direction: add the disable comment above each line, with the same reason as `deploy.sh`, and re-run both pinned images.

#### B2-R2-5: the bridge's Firebase key is written to the logs on every bridge request
- Layer `security` · Source FR-027 and D15 (the old project's configuration lives only in VPS-2's host environment), constitution V, the bridge's module docstring, B2-R1-29 · `backend/app/adapters/satair_bridge.py:78` (`params={"key": api_key}`); `backend/app/workers/logs.py:46` (root at INFO); `backend/app/adapters/fetcher.py:197` (`ResponseTooLarge` uses `response.url`); `backend/app/adapters/tasks.py:160` (`log.error("fetch_failed", extra={"why": str(exc)})`) · CONFIRMED (a probe through `logs.setup_logging()` printed `HTTP Request: GET https://firestore.googleapis.com/…?key=SECRETKEY123`)
- Problem: B2-R1-15 turned on INFO for every logger, and `httpx` logs each request's full URL at INFO. The key is a query parameter, so it is in that URL. The new `fetch_failed` line carries it too, through `ResponseTooLarge`'s message.
- Failure scenario: every 3-hour bridge run on VPS-2 writes the old project's key to `docker logs`, and to any log shipper added later.
- Fix direction: send the key in the `X-Goog-Api-Key` header, so no URL holds it (`get()` needs a `headers` argument). Build `ResponseTooLarge`'s message from the URL without its query. Ask B1 to quiet `httpx` and `httpcore` as a second layer (B1-R2-7). Add a test that captures the logs of a bridge fetch, including an oversize one, and asserts the key is absent.

#### B2-R2-6: a transport error, an empty 200 or an oversize result still leaves no `import_runs` row
- Layer `pipelines` · Source FR-025, SC-005, B2-R1-9 · `backend/app/adapters/tasks.py:132-162` (no catch-all; `httpx.TransportError` is retried by `autoretry_for` and re-raised on the last attempt) · CONFIRMED (probe: `ConnectError` gives `sent: []` for both sources; I read the handlers)
- Problem: only `LayoutChanged`, `BridgeNotConfigured`, `Retryable` and `FetchError` send a `failed` result. These escape:
  - `httpx.TransportError` (connect, DNS, timeout);
  - an empty 200, where `lxml_html.fromstring("")` raises `ParserError`, not `LayoutChanged`;
  - `MessageTooLarge` from `ScrapeResult.build` (also from `_failed`, whose pages can exceed the 2 MB cap);
  - a pydantic `ValidationError`, or any bug.
- Failure scenario: the home box loses its uplink for a day. Every run dies after its retries with a Celery traceback, no row and no `failed` result, and the first sign is a day of stale fixtures.
- Fix direction: catch `httpx.TransportError` on the final attempt (the same `retries >= max_retries` rule), then a last `except Exception` that sends a `failed` result with a code such as `fetch_error` and re-raises. Treat a page with no document as `LayoutChanged` in `ysscores.parse`. Build `failed` without pages when the pages trip the cap. Add `fetch` tests for a transport error on every attempt, an empty 200 and an oversize failure.

### MEDIUM

#### B2-R2-7: the runbook's way to get VPS-2's host key into `DEPLOY_KNOWN_HOSTS` can't work
- Layer `ops` · Source T088, the root `CLAUDE.md` runbook rule ("every command must match"), B2-R1-20f · `docs/runbooks/provision-host.md:361` · CONFIRMED by reading (`ssh-keyscan` not run, see Checks)
- Problem: `ssh-keyscan` has no `-J` option. The `sed` that follows renames the host to `vps2`, but `ssh-config.sh` sets no `HostKeyAlias`, so ssh looks the key up under the VCN IP.
- Failure scenario: the owner follows §8, and `deploy-vps2` fails with `Host key verification failed` under `StrictHostKeyChecking yes`.
- Fix direction: scan from VPS-1 (`ssh ubuntu@10.8.0.1 ssh-keyscan -t ed25519 "$VPS2_VCN_IP"`) and keep the IP. Or add `HostKeyAlias vps2` to the generated config. Add the VPS-2 line to the CI `ssh -G` fixture.

#### B2-R2-8: the Redis password rotation still renders no new ACL, and the home-box step has no `--env-file`
- Layer `ops` · Source constitution V, T088, B2-R1-7, B2-R1-20c · `docs/runbooks/secrets.md:122-128` (step 2's only command is `dc restart redis`), `:74` (`docker compose -f infra/compose/home-box.yml up -d`) · CONFIRMED
- Problem: step 2 is titled "Render the new ACL and load it" but renders nothing, so Redis restarts on the old ACL while the clients send the new password. Step 4 on the box omits the env file, so compose fails on the required variables.
- Failure scenario: a rotation ends in `WRONGPASS` on every client and `/healthz` 503.
- Fix direction: step 2 runs `deploy.sh --infra-only`, as the home-box procedure does; step 4 adds `--env-file /srv/madar/.env`; write out the VPS-2 recreate command. No test (docs).

#### B2-R2-9: the home-box ACL listing command is wrong in two ways
- Layer `ops` · Source the runbook rule, B2-R1-20d · `docs/runbooks/home-box.md:82-83` · CONFIRMED
- Problem: `docker exec -T` is not a flag (only `docker compose exec` has `-T`). The `sed` prints the rest of the line (`PW ~* &* +@all`), not the password.
- Failure scenario: the owner's check fails with `unknown shorthand flag: 'T'`, and with that fixed, `redis-cli` authenticates with a wrong string.
- Fix direction: `docker exec madar-redis-1 sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ACL LIST'`, the form the container's own health check uses. No test (docs).

#### B2-R2-10: `bootstrap-vps.sh` stops silently when gid 999 has no group, and the re-run isn't documented
- Layer `ops` · Source constitution IX · `infra/scripts/bootstrap-vps.sh:166` (`existing=$(getent group "$acl_gid" | cut -d: -f1)` under `set -Eeuo pipefail`) · CONFIRMED (a scratch copy exits 2 with no output for an unused gid)
- Problem: `getent` exits 2 for a missing group, `pipefail` carries it into the assignment, and the script aborts before its `groupadd` branch, which is dead code. Where gid 999 is taken (`docker`, `adm`), that whole group can read the ACL. No runbook or owner action says an already-provisioned VPS-1 must re-run `bootstrap-vps.sh vps1` before the first D2 deploy, and `deploy.sh:129` refuses without it.
- Failure scenario: on a fresh host whose gid 999 is free, bootstrap stops mid-way with no message.
- Fix direction: `getent group "$acl_gid" || true` in the pipeline, or a dedicated group; document the re-run in `provision-host.md` and `owner-actions.md`. Add a CI case for an unused gid.

#### B2-R2-11: the Redis reload is not atomic and checks only `default`
- Layer `ops` · Source constitution IX and V, B2-R1-7 · `infra/scripts/deploy.sh:138-164` · CONFIRMED by reading
- Problem: the file is replaced, then `compose restart redis`. A bad file leaves Redis down with the old ACL gone, and the check pings as `default` only, so a wrong `homebox` password isn't caught. The render-twice CI step that B2-R1-7 asked for isn't there.
- Failure scenario: a typo in `REDIS_HOMEBOX_PASSWORD` passes the deploy and the home box gets `WRONGPASS` on every run.
- Fix direction: keep the old file and use `ACL LOAD` (which keeps the old ACL on error), or restore it when the restart fails; check `homebox` too; add the render-twice step.

#### B2-R2-12: the VPS-2 `up -d` is still unguarded
- Layer `ops` · Source constitution IX, B2-R1-24 · `infra/scripts/deploy.sh:248,261` · CONFIRMED
- Problem: VPS-1 now uses `start_apis … || started=0` and rolls back; VPS-2's `up -d` under `set -e` just exits.
- Failure scenario: a bad worker image on VPS-2 leaves the old containers stopped and nothing rolled back.
- Fix direction: guard it the same way and roll back to the previous tag. Add it to the deploy script's test if one exists, or a dry-run step.

#### B2-R2-13: Lane M's two CI asks were not delivered
- Layer `ops` · Source M-R1-2, M-R1-16 (both ask B2), SC-009, constitution VIII · `.github/workflows/app.yml:63-70`, `.github/workflows/pwa.yml` · CONFIRMED
- Problem: no workflow runs `app/tool/check_web_assets.sh` or `app/tool/check_providers.sh`, and B2's round-1 block has no task for them. Both scripts exist only on `d02-m` (`2383482`). `app.yml` doesn't build the web, and `pwa.yml`'s build runs only on `master`, so a PR would not exercise the web check.
- Failure scenario: the drift web assets or a hand-written provider can come back, and CI stays green.
- Fix direction: when `d02-m` lands, add `check_providers.sh` to `app.yml`, and a web build with `check_web_assets.sh` on PRs that touch `app/**`. Lane M may move the provider check into `flutter test` instead (`m-round-2.md` M-R2-7); agree which first.

#### B2-R2-14: the api-admin command check runs only when `backend/**` changes
- Layer `ops` · Source B2-R1-3 · `.github/workflows/backend.yml:10-18` (path filters), the step at `:86-106` · CONFIRMED
- Problem: the step parses `infra/compose/vps1.yml`, but a PR that edits only that file doesn't trigger `backend.yml`, and `infra.yml` doesn't run the step.
- Failure scenario: a later edit brings back a flag gunicorn rejects, and nothing fails until the deploy.
- Fix direction: add `infra/compose/**` to the backend path filters, or run the step in `infra.yml` too.

#### B2-R2-15: runbooks and owner actions still describe the old mechanism
- Layer `ops` · Source T088, FR-055, B2-R1-21, B2-R1-25 · CONFIRMED
- Problems:
  - `docs/runbooks/deploy-and-rollback.md:16-17` says `deploy.sh` runs "as `deploy@10.8.0.1`" with `-J deploy@10.8.0.1`, doesn't say that `deploy.sh` restarts Redis when the ACL changes, and has no VPS-2 divergence note (B2-R1-36).
  - `docs/owner-actions.md` (T082 proof) uses `--pass "$REDIS_HOMEBOX_PASSWORD"`, a key the box's `.env` doesn't have.
  - `docs/runbooks/README.md` step 11 puts the home-box peer and firewall rule after the first deploys; `owner-actions.md` says before.
  - `provision-host.md:390` and `firewall-changes.md:87` run `check-firewall.sh` with no `--role`, which exits 2 on a host bootstrapped before D2.
- Failure scenario: the owner follows the docs and gets an empty password, a wrong order and a failing check.
- Fix direction: correct each to match the code. No test (docs).

#### B2-R2-16: the gzip fix bounds each page, not the message
- Layer `security` · Source B2-R1-13 · `backend/app/adapters/messages.py:145-149` (`raw_pages()` inflates every page into one list), `:158-168` · CONFIRMED (250 pages of 5 MB zeros make a 1,739,185-byte message, under the 2 MB cap, that inflates to 1,250 MB)
- Problem: the page count is unbounded, so the round-1 attack still works when it is spread over many pages.
- Failure scenario: a compromised home box sends 1.7 MB, and `worker-imports` is OOM-killed while `ingest` writes the pages.
- Fix direction: cap the page count (a window is at most four pages) and a total inflated budget (for example 20 MB), and check the message length before pydantic parses it. The bomb test (`test_messages.py:126`) only proves rejection: a mutant that swaps `decompressobj(max_length)` for `gzip.decompress` survives. Add a many-page case.

#### B2-R2-17: the new "no sleeps" fetcher test sleeps for a real 60 seconds
- Layer `tests` · Source B2-R1-16, constitution test rules · `backend/tests/adapters/test_fetcher.py:147-161` (`test_a_rate_limited_host_raises_retryable_without_a_request`), `:218` · CONFIRMED (`pytest --durations`: 60.02 s)
- Problem: with the waiting fetcher, `Denied()` with the real clock busy-waits the whole `WAIT_BUDGET`. `assert calls == []` is vacuous (`calls` is never wired to the transport). Line 218 adds a `# type: ignore[arg-type]`.
- Failure scenario: every backend CI run spends a minute here, and the test passes even if the fetcher sends the request.
- Fix direction: inject a fake clock and sleep and a small budget, wire `calls` to the transport, assert the poll count, and build the window with `DateWindow.next_days(date(2026, 10, 31))`.

#### B2-R2-18: two new guards can be removed without failing a test
- Layer `tests` · Source B2-R1-16 ("each new test fails when its guard is removed"), R16 · `backend/app/adapters/upsert.py:408-409` with `backend/tests/adapters/test_upsert.py:268`; `backend/app/adapters/tasks.py:322` · CONFIRMED (mutant survived)
- Problem: deleting `if channel_id in existing: continue` leaves all 21 tests green: the duplicate insert fails inside the savepoint, the item lands in `skipped`, and the test never checks `skipped`. `run.json["postponed"]` is asserted nowhere.
- Failure scenario: a refactor drops either guard and nothing fails.
- Fix direction: assert `outcome.skipped == []` and the unchanged link row; add a task-level assertion that `run.json["postponed"]` lists the refs.

#### B2-R2-19: nothing bounds the total time of a fetch
- Layer `pipelines` · Source B2-R1-31, the Celery task rules · `backend/app/adapters/fetcher.py:29-30,185-189`; no `task_time_limit` or `soft_time_limit` in `app/workers/` or the compose commands · PLAUSIBLE
- Problem: `WAIT_BUDGET` is per request, `READ_TIMEOUT` is per chunk, and `expires` applies only before the task starts.
- Failure scenario: a host that drips a byte every 19 s holds the single-concurrency `scrape_home` worker indefinitely; the 30-minute lock expires and later fetches queue behind it.
- Fix direction: a total deadline in `_request` (waits and redirects included) and a `soft_time_limit` of a few minutes on `adapters.fetch`.

### LOW

- B2-R2-20 `.github/workflows/infra.yml:51-80`: the placeholder check flags only `>` tokens, so a `user default on nopass …` or `#<sha256>` line passes. Flag anything on a `user` line that isn't a placeholder. CONFIRMED.
- B2-R2-21 `infra/scripts/check-firewall.sh`: the VPS-2 "SSH from anywhere" expectation greps `-A INPUT -s 0.0.0.0/0 …`, which `iptables-save` never prints, so a ruleset with an open port 22 passes. CONFIRMED.
- B2-R2-22 `infra/redis/users.acl.tmpl:2-3` still says "mode 600, owner deploy", and `deploy.sh`'s `cmp` skip leaves a wrong mode or group in place when the content is unchanged. CONFIRMED.
- B2-R2-23 `infra/scripts/deploy.sh:157-158`: `redis-cli --pass "$redis_password"` puts the password in the host's process list for up to 30 s; use `REDISCLI_AUTH` through `sh -c`, as the health check does. `docs/runbooks/imports-and-sources.md:40-44` hard-codes `--queue scrape_home`, which overrides `YSSCORES_FETCH_QUEUE`. CONFIRMED.
- B2-R2-24 tidy-ups: `ruff format --check` flags `app/adapters/base.py:29` and `tests/adapters/test_tasks.py:37` (CI runs `ruff check` only); `app/adapters/tasks.py:84` overwrites B1's lazy `task_routes` at import (same answer, two sources); `tasks.py:172` `_failed` duplicates `ScrapeResult.failed`; `ratelimit.py:102` `seconds_until_token` is unused. CONFIRMED.
- B2-R2-25 `backend/app/adapters/upsert.py:438`: each orphan channel adds a `skipped` entry, so every bridge run with an orphan is `partial`, and the entry's `ref` is a channel where the other skips carry a match. Consider a separate `orphans` list in `run.json`. CONFIRMED.
- B2-R2-26 `backend/app/adapters/upsert.py:277-290`: a new postponed or TBD item (kickoff `None`) never reaches the duplicate probe's name branch, so it can't adopt a bridge-created row that has no `ysMatchId`. PLAUSIBLE.
- B2-R2-27 `backend/tests/adapters/test_tasks.py:461`: `http_errors` counts only the final attempt, so 403 on all six attempts records 1. SC-005 asks for the run's HTTP errors. CONFIRMED.

## Requirements

Only the rows that changed since round 1. Every other row of `b2-round-1.md` stands.

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| FR-025, SC-005 every run leaves a record | `adapters/tasks.py:132-264` | `test_tasks.py:441,463,476,537,552` | **Partial** (B2-R2-6) |
| SC-004 ysscores arrives from the home box | `home-box.yml`, `users.acl.tmpl:13` | `test_homebox_acl.py` (no worker) | **Not met**: the worker can't start (B2-R2-3) |
| FR-022 importer rules (links, locks, postponed, TBD) | `adapters/upsert.py` | `test_upsert.py`, mutants killed | **Met**, except the re-add guard's test (B2-R2-18) |
| FR-028 home-box isolation | `users.acl.tmpl:13`, `bootstrap-vps.sh` | `test_homebox_acl.py` | **Partial** (B2-R2-3, B2-R2-10) |
| FR-029, T085 deploys reach both hosts | `.github/actions/vps1-sync/action.yml`, `infra/scripts/ssh-config.sh` | `infra.yml` `ssh -G` step | **Not met**: wrong path (B2-R2-2), VPS-2 host key (B2-R2-7) |
| constitution IX a deploy never takes the release down | `deploy.sh`, `vps1.yml:181` | `check-redis-acl.sh` (755 only) | **Not met** (B2-R2-1, B2-R2-11, B2-R2-12) |
| FR-027, D15 the old project's key stays in VPS-2's environment | `satair_bridge.py:78` | none | **Not met**: it reaches the logs (B2-R2-5) |
| quality gates: shellcheck, actionlint | `infra.yml` | the two images | **Failing** (B2-R2-4) |
| FR-055 runbooks | `docs/runbooks/` | link checker | **Partial** (B2-R2-7 to B2-R2-9, B2-R2-15) |

## Task audit

Round-1 fix tasks: 22 ticked, 13 verified, 7 partly done (B2-R1-4, 7, 9, 13, 16, 20, 21), 2 not done (B2-R1-1, B2-R1-18: both regressed into a new failure). The closing note's claim that B2-R1-1's test "must fail on today's script" doesn't hold: the check builds a 755 directory of its own.

| Task | Mismatch |
| --- | --- |
| B2-R1-1 | Redis still can't read the ACL (B2-R2-1) |
| B2-R1-4 | the action's path (B2-R2-2), VPS-2 known hosts (B2-R2-7) |
| B2-R1-7 | reload not atomic, `homebox` unchecked (B2-R2-11); runbook renders nothing (B2-R2-8) |
| B2-R1-9 | transport errors, empty bodies and oversize results escape (B2-R2-6) |
| B2-R1-13 | the message's total is unbounded (B2-R2-16) |
| B2-R1-16 | the re-add test can't fail; the new fetcher test sleeps 60 s (B2-R2-17, B2-R2-18) |
| B2-R1-18 | a real worker can't start (B2-R2-3) |
| B2-R1-20 | c, d and f (B2-R2-7 to B2-R2-9) |
| B2-R1-21 | the T082 proof's variable (B2-R2-15) |

## Owner must review

- `infra/redis/users.acl.tmpl`, `infra/scripts/deploy.sh:125-165` and `infra/scripts/bootstrap-vps.sh` `ensure_redis_acl_group`: the ACL, its directory and group, and the reload (B2-R2-1, B2-R2-3, B2-R2-10, B2-R2-11).
- `.github/actions/vps1-sync/action.yml` and `infra/scripts/ssh-config.sh`: the deploy path to both hosts (B2-R2-2, B2-R2-7).
- `backend/app/adapters/satair_bridge.py:78`: how the bridge key travels (B2-R2-5).
- B2-R1-27 (from round 1): whether ysscores list times really are Cairo time. Still not recorded.

## Outside this change

- `backend/app/workers/logs.py` (B1's): it logs whole task payloads and httpx URLs. Asked in `b1-round-2.md` B1-R2-7.
- `docs/runbooks/admin-access.md` (Lane A's): its CA copy command fetches a file nothing creates (`a-round-2.md` A-R2-13).
- `docs/runbooks/ci-workflows.md` on `d02-m` (Lane M's): a paragraph inserted mid-table (`m-round-2.md` M-R2-20).

## Not reviewed

- No real SSH connection or jump, so the jump hop's use of `-F` is untested.
- `ssh-keyscan` and `envsubst` runs (not allowlisted), and `systemd-analyze verify` on the home-box units.
- T086 and T087 on live hosts: nothing is deployed.
