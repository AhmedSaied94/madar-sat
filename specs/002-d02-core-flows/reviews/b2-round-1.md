# Implementation review: 002-d02-core-flows, lane B2, round 1

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); layer subagents on Sonnet, every finding re-checked here
- Branch: `d02-features` (the four D2 lane PRs, #8–#11, merged into it; not yet on `master`) · Base: `master` (merge base `68f1752`) · Head: `6f81c90`, clean tree
- Change (lane B2): 7 commits (`717b605`, `edaee3d`, `11c9aa2`, `b4419d8`, `f000e90`, `b0fcde2`, `ae8c0af`, merged as PR #9). That is `backend/app/adapters/`, `backend/tests/adapters/`, the ysscores and Sat Air fixtures, `infra/`, `.github/`, 11 runbooks, `docs/owner-actions.md` and the spec files. No code file is in another lane's folder; `b0fcde2` also ticked Lane B1's section (B2-R1-38).
- Verdict: **BLOCK** · CRITICAL 2 · HIGH 9 (1 PLAUSIBLE) · MEDIUM 17 (5 PLAUSIBLE) · LOW 10

The adapter design is right: a pure `parse`, a strict allowlist, a typed `ScrapeResult`, an upsert that never writes status, and resolution that never guesses. What fails is how it runs. As written, the first deploy after merge takes Redis down, which takes down the public API. ysscores runs delete the channel links that the snapshot loaded. The 4-day fetch can never finish under its own rate limit, and when a fetch fails, nothing is written to `import_runs`. Four separate host and CI steps also fail before a single fixture can arrive.

Nothing is deployed yet: the PRs merged into `d02-features`, not `master`.

## Checks

The checks ran in a `git archive` copy of HEAD `6f81c90`, against the dev PostgreSQL 16.15 (`:5434`) and Redis 7 (`:6380`).

| Check | Command | Result |
| --- | --- | --- |
| backend gates | `uv run ruff check .`, `uv run mypy --strict app`, `uv run pytest --cov` (see `b1-round-1.md`) | ruff and mypy exit 0. pytest exit 1, from the two NUL failures in B1's and D1's routes; every `tests/adapters/` test passed. Coverage 95.80 % on domain/services/adapters |
| compose valid | `docker compose -f infra/compose/{vps1,vps2,dev,home-box}.yml --env-file infra/compose/example.env config -q` | exit 0 for each of the four files |
| platforms and ports | the same with `--profile workers --profile tools config` | arm64 on every VPS service, amd64 only in `home-box.yml`. Postgres on the VCN IP; Redis on the VCN IP and `10.8.0.1`; api-admin on `10.8.0.1:8001`; api-public on `127.0.0.1:8000` |
| exactly one `beat` | `grep beat infra/compose/*.yml` | only `vps2.yml` (`madar-beat`) |
| api-admin command | `gunicorn app.admin:app -k uvicorn.workers.UvicornWorker -w 1 -b 0.0.0.0:8001 --proxy-headers --forwarded-allow-ips=10.8.0.1` in the backend venv (gunicorn 26.2.0) | **exit 2**: `gunicorn: error: unrecognized arguments: --proxy-headers` (B2-R1-3) |
| Redis reads the rendered ACL | `docker run` of `redis:7.4.12` with the compose command and a mode-0600 `users.acl` owned by uid 1000, mounted `:ro` | **exit 1**: `Aborting Redis startup because of ACL errors: Error loading ACLs, opening file '/etc/redis/users.acl': Permission denied` (B2-R1-1) |
| home-box runbook `ps` | `env -u GHCR_OWNER -u REDIS_URL -u SCRAPE_USER_AGENT docker compose -f infra/compose/home-box.yml config -q` | exit 1, required variables missing (B2-R1-20c) |
| CI ACL regex | the `infra.yml:51-52` regex on the real template and two scratch templates | the real file and a mid-line literal password are **not** flagged; only an end-of-line literal is (B2-R1-17) |
| task routing in a fresh process | a scratch script that imports `app.workers` only, as `celery call` does | `adapters.fetch(legacy)` routes to `maintenance` (B2-R1-19) |
| 4-day fetch under the bucket | a scratch simulation of the bucket's Lua plus Celery's `retry_backoff`/`retry_jitter`/`max_retries=5`, 20,000 trials | 0.00 % complete at 0.3, 0.8, 1.5 and 2.5 s per POST (B2-R1-8) |
| doc links | a scratch relative-link and anchor checker over the runbooks, `owner-actions.md` and the infra docs | 1 broken link (B2-R1-21) |
| `systemd-analyze verify` on the home-box units | | **NOT RUN**: lean-ctx allowlist (`lean-ctx allow systemd-analyze`) |
| `ssh -v -J` reproduction, `zcat` of the ssh man page | | **NOT RUN**: allowlist (`lean-ctx allow ssh`, `lean-ctx allow zcat`). B2-R1-4 rests on OpenSSH's documented `-J` behaviour |
| `bash -n` and shellcheck on the scripts | | **NOT RUN**: nested bash blocked; shellcheck not installed (CI runs it) |
| T086, T087 on the live hosts | | **NOT RUN**: not deployed |

I scanned the diff for ways around the checks. There are no `skip`, `xfail` or `noqa`, and coverage and lint config are unchanged. `pyproject.toml` gains dependencies and a mypy `ignore_missing_imports` override for celery and kombu. The two new `# type: ignore`s (`ysscores.py:18-19`, `messages.py:55`) are commented and narrow. Actions are SHA-pinned.

## Findings

### CRITICAL

#### B2-R1-1: Redis cannot read the rendered ACL file, so the first D2 deploy takes Redis and the public API down
- Layer `ops` · Source constitution IX (health-checked deploys with automatic rollback), constitution V, T078, T081 · `infra/scripts/deploy.sh:131` (`install -m 600 "$tmp" "$acl_target"`); `infra/compose/vps1.yml:167-180` (`redis:7.4.12`, `/srv/madar/redis/users.acl:/etc/redis/users.acl:ro`, `exec docker-entrypoint.sh redis-server --aclfile /etc/redis/users.acl`) · CONFIRMED (docker run above)
- Problem: the file is written as mode 0600 and owned by `deploy`. The official entrypoint drops to the `redis` user (uid 999) before starting the server, and that user can't open the file.
- Failure scenario: `infra.yml`'s `sync`, or `backend.yml`'s `deploy`, renders the ACL (`deploy.sh:147`/`:271`) and runs `compose up -d --wait postgres redis caddy`. Redis is recreated because its command changed, then crash-loops on "Permission denied". `set -e` aborts before any rollback. The old container is already gone, `/healthz` returns 503, and the public API is down until someone fixes the file by hand. The data is safe in the AOF volume. No test loads the file: `test_homebox_acl.py` applies the rule with `ACL SETUSER`.
- Fix direction: make the file readable by uid 999 and nobody else. For example, `bootstrap-vps.sh` can create a host group with gid 999 that `deploy` belongs to, and the render can use `install -m 640 -g <that group>`. Then prove it in CI: boot `redis:7.4.12` from a file rendered with the same mode and owner, and `PING` it as both users.

#### B2-R1-2: a ysscores run deletes every channel link the snapshot gave a match
- Layer `pipelines` · Source constitution I (the channel and frequency are the product's answer), constitution VII and FR-022 ("an importer removes only the `match_channels` links it added"), data-model "Match–channel link lifecycle" · `backend/app/adapters/upsert.py:174` (always calls `_reconcile_links`), `:371-377` (deletes own-source rows missing from `desired`); `backend/app/adapters/ysscores.py:153-168` (no links, so `item.links == ()`); snapshot loader `backend/app/etl/matches.py:243` (`source="ysscores"`) · CONFIRMED
- Problem: the D1 snapshot stored the old app's imported links with `source='ysscores'`. D2's ysscores adapter supplies no links at all, so `desired` is empty and every `ysscores` link on every match it touches is deleted.
- Failure scenario: the first scheduled run finds a snapshot match by its `ysMatchId` and deletes all its channels. It audits `channels.removed`, bumps `matches`, and S3 shows «لم تُضف القنوات الناقلة بعد» for matches that had 100+ channels. They come back only if the Sat Air bridge is configured and still lists them, and then as `legacy` links. `test_links_follow_the_importer_rules` only uses `legacy`.
- Fix direction: reconcile links only for an adapter that supplies a link set (`links is None` for "not provided", or a capability flag on the adapter). Add a test in which a snapshot match with `source='ysscores'` links keeps them all after a ysscores run.

### HIGH

#### B2-R1-3: `--proxy-headers` stops api-admin starting, and a rollback can't fix it
- Layer `ops` · Source FR-003 (XFF trusted only from Caddy), research R3, T078, constitution IX · `infra/compose/vps1.yml:85` · CONFIRMED (gunicorn exit 2 above)
- Problem: `--proxy-headers` is a uvicorn flag, and gunicorn's strict argparse rejects it. The flag lives in the compose file, not the image, so rolling back `IMAGE_TAG` keeps it. D1's command didn't have it.
- Failure scenario: every deploy after merge restart-loops api-admin. The health wait fails, the rollback uses the same command and fails too, and the admin is unreachable.
- Fix direction: drop `--proxy-headers`. `UvicornWorker` already enables proxy headers and takes `--forwarded-allow-ips` (also `FORWARDED_ALLOW_IPS`) from gunicorn. Add a CI step that runs the api-admin command from the compose file with `--check-config`, or boots it, so a bad flag fails the PR.

#### B2-R1-4: `deploy-vps2` can't authenticate the jump to VPS-1, so VPS-2 never deploys
- Layer `ops` · Source FR-029, US2 scenario 9, R22, T085, constitution IX · `.github/workflows/backend.yml:338` (`read -ra ssh <<<"$SSH_COMMAND -J deploy@10.8.0.1"`); `.github/actions/vps1-sync/action.yml:49` (`-i`, `UserKnownHostsFile`, `StrictHostKeyChecking` on the command line) · CONFIRMED (OpenSSH documents that command-line options apply to the destination, not to `-J` jump hosts; the local reproduction was blocked)
- Failure scenario: the jump connection gets no key and no pinned `known_hosts`, so it fails with "Permission denied (publickey)" or "Host key verification failed". `deploy-vps2` goes red, `stable` (which needs it) and `retention` are skipped, the home box never gets an image, and GHCR is never pruned.
- Fix direction: have the composite action write an ssh config with a `Host vps1` block (identity, `UserKnownHostsFile`, `IdentitiesOnly`, `BatchMode`) and a `Host vps2` block with `ProxyJump vps1`, and use `-F` with it. Alternatively use an explicit `ProxyCommand` that carries the same options. Write the VPS-2 host-key step down (B2-R1-20f).

#### B2-R1-5: `/srv/raw` is never created, so every ingest fails
- Layer `ops` · Source FR-029, FR-025, T079, US2 scenario 9 ("no manual step on a server") · `infra/scripts/bootstrap-vps.sh:158-162` (`ensure_dirs` creates only `/srv/media` and `/srv/reports` for uid 10001); `infra/compose/vps2.yml:44-45,67-68` (short-syntax bind `/srv/raw:/srv/raw`); `backend/Dockerfile` (uid 10001) · CONFIRMED
- Problem: Docker creates the missing bind source as `root:root 0755`, so the uid-10001 workers (with `cap_drop: ALL`) can't write to it.
- Failure scenario: `adapters.ingest` commits a `running` row (`tasks.py:204`), then `RawStore.save` raises `PermissionError` at `raw_store.py:42`. No fixture is upserted, and every run leaves a stuck `running` row (B2-R1-12). `prune_raw_pages` fails the same way.
- Fix direction: create `/srv/raw` for uid 10001 in `ensure_dirs` on the VPS-2 role, and say so in `workers.md`.

#### B2-R1-6: `check-firewall.sh` fails on VPS-2, so `bootstrap-vps.sh vps2` always ends non-zero
- Layer `ops` · Source T082, constitution IX · `infra/scripts/check-firewall.sh:70-88` (`check_expectations` requires VPS-1's `DOCKER-USER … 10.8.0.1 … 6379` rule on every host); `infra/scripts/bootstrap-vps.sh:249,264` · CONFIRMED
- Failure scenario: on VPS-2 the "already up to date" test never passes, so every re-run re-applies the firewall and restarts Docker, stopping every worker. The run then exits 1 at `:264`, before "done", and the reboot check in provision-host §9 can't pass.
- Fix direction: gate the VPS-1 expectations by host role (the role argument, or which rules file is installed), and give VPS-2 its own expectations. Add a test or CI step that runs the check against both rendered rulesets.

#### B2-R1-7: ACL changes never take effect, and the Redis rotation runbooks would cause an outage
- Layer `ops` · Source constitution V, FR-055, T088 ("every command must match the code") · `infra/scripts/deploy.sh:118-135` (renders the file only); `docs/runbooks/secrets.md:68` ("a deploy renders the ACL and recreates Redis"), `:119` ("Redis reads `requirepass`"), `:125` (`dc up -d --force-recreate redis api-public api-admin`); `docs/runbooks/home-box.md:59` ("Compose restarts Redis to read it") · CONFIRMED
- Problem: Redis reads the ACL file only at start. Compose recreates a container only when its definition changes, not when a mounted file's content does, and nothing runs `ACL LOAD`. `install` also replaces the inode under a single-file bind mount.
- Failure scenario: after a leak the owner rotates `REDIS_HOMEBOX_PASSWORD` as written, and the old password keeps working. Following "Rotate the Redis password" instead (`.env` edit plus `--force-recreate`, no re-render) brings Redis back with the old ACL while every client sends the new password. The result is `WRONGPASS` everywhere and `/healthz` 503.
- Fix direction: when the rendered file changes, have `deploy.sh` run `redis-cli ACL LOAD` (or restart Redis) and check the result. Rewrite both rotation procedures to render, then load, then recreate the clients. Make them match the code.

#### B2-R1-8: a 4-day ysscores fetch can never finish under its own rate limit
- Layer `pipelines` · Source FR-020, FR-021, US2 scenarios 1 and 6, SC-004, research R14 and R16 (burst 2, one request per 4 s), plan ("an ysscores run … finishes in under 1 minute") · `backend/app/adapters/fetcher.py:122-123` (`if not self.limiter.take(...): raise Retryable`); `backend/app/adapters/ratelimit.py:28` (`Bucket(capacity=2, refill_seconds=4.0)`); `backend/app/adapters/ysscores.py:101-111` (four POSTs back to back) · CONFIRMED (code plus the simulation above)
- Problem: the third POST finds the bucket empty and raises `Retryable`, which aborts the whole `fetch`. Celery retries from day 0 and spends the refilled tokens on days 0 and 1 again. After 5 retries it gives up.
- Failure scenario: no scheduled ysscores run ever delivers a `ScrapeResult`, so no fixtures arrive. That is US2's headline and SC-004. B2-R1-9 means nothing records the failure either. The tests pass because they use an allow-all limiter.
- Fix direction: make the fetcher wait for the next token, sleeping up to `refill_seconds` with a bounded total deadline, or make the fetch resumable per day. Add a test with the real `RateLimiter` against a four-day window and a fake clock.

#### B2-R1-9: failed fetches never reach `import_runs`
- Layer `pipelines` · Source FR-025, SC-005 ("a deliberately failed fetch is recorded with its HTTP errors"), constitution VII ("loud when it fails"), research R15 and R16 · `backend/app/adapters/tasks.py:30` (imports `LayoutChanged` from `satair_bridge`); `backend/app/adapters/ysscores.py:55,134` (a separate `LayoutChanged`); `tasks.py:128-158` (only the bridge's `LayoutChanged` and `BridgeNotConfigured` are caught, both with `http_errors=0`) · CONFIRMED
- Problem: ysscores' own `LayoutChanged`, `Retryable` once the retries run out, `FetchError` (404/400), `HostNotAllowed`, `ResponseTooLarge` and `RedirectLimit` all escape `fetch`, so no `ScrapeResult.failed(...)` is sent. No production code ever sets `http_errors` above 0.
- Failure scenario: ysscores starts answering the home box with 403, or returns a challenge page with no `.matches-wrapper`. The task dies after 5 retries, and `import_runs` has no row, no `failed` and no error count. The pages already fetched aren't saved. `imports-and-sources.md:87` ("marks the run `failed` with `layout_changed`, and the page is saved") is false for ysscores. The first sign is a week of stale fixtures.
- Fix direction: use one shared `LayoutChanged` in `adapters/base.py`. Count HTTP errors in the fetcher. On the final retry (an `on_failure` hook, or a check of `self.request.retries >= self.max_retries`) and on non-retryable errors, send `ScrapeResult.failed(...)` with the error count, a short reason and the pages fetched so far. Add `fetch`-level tests for 403 × N, for 404 and for a page with no wrapper.

#### B2-R1-10: postponed fixtures are imported as scheduled, so the D1 clock rule later shows them as live
- Layer `pipelines` · Source constitution II (never present a guess as fact), research R16 (importers write no status), T052 ("a postponement") · `backend/app/adapters/ysscores.py:145-151` (skips only an item with no `.match-date`); `backend/tests/adapters/test_ysscores_parse.py:79-83` (`test_postponed_items_keep_their_time` asserts the current behaviour); `backend/tests/fixtures/ysscores/2026-10-31.html` (10 of 129 items are `match-postponed` with `data-status="14"` and «تأجلت»; `2026-10-30.html` has 3 of 53) · CONFIRMED
- Failure scenario: a postponed match is stored as "18:00, scheduled". The app counts down to it, then shows estimated «مباشر» for the whole clock window. The importer may not write status, so nothing corrects it.
- Fix direction: this needs an owner decision. Either skip postponed items, or import them with `time_tbd = true` and no kickoff. Then reverse `test_postponed_items_keep_their_time` to match. That is an ask task.

#### B2-R1-23: the `worker-media` health wait is too short, and a rollback puts it on the D1 image
- Layer `ops` · Source constitution IX, R20, R22, T083 · `infra/scripts/deploy.sh:39,176,187` (60 s budget); `infra/compose/vps1.yml:114-119` (60 s healthcheck `interval`, `celery inspect ping --timeout 10`) · PLAUSIBLE (the arithmetic is from the code and Docker's semantics; only a real deploy settles it)
- Problem: Docker runs the first healthcheck one `interval` (60 s) after start. `inspect ping` with no `limit` waits its whole 10 s, so the first `healthy` comes at about t0+73 s. The wait ends at about t0+66–72 s. The first D2 rollback target is the D1 tag, which has no `app.workers`, so `worker-media` crash-loops on it.
- Fix direction: add `start_interval` (or a shorter interval during `start_period`) to the worker healthchecks, budget at least interval + timeout + start-up, and don't roll a service back onto a tag that lacks it.

### MEDIUM

#### B2-R1-11: `time_tbd` is written under a locked kickoff, so the CHECK rejects the whole item
- Layer `pipelines` · Source FR-022, US2 scenario 3, the edge case "An editor changes a field an importer also writes" · `backend/app/adapters/upsert.py:319-345`; `backend/app/domain/lockable.py:12-30` (`time_tbd` is not lockable); `backend/alembic/versions/0002_mvp_additions.py:122` (`CHECK (time_tbd = (kickoff_at IS NULL))`) · CONFIRMED
- Failure scenario: an editor sets the kickoff of a match the feed lists as `--:--`. On every run the item fails at flush and its savepoint rolls back, so its teams, stage and links stop updating, and the run is `partial` every 3 hours.
- Fix direction: derive `time_tbd` from the resulting `kickoff_at`, and write it only when `kickoff_at` is written. Add a test with a locked kickoff and a TBD item.

#### B2-R1-12: `ingest` has no failure path, so runs stay `running` forever
- Layer `pipelines` · Source FR-025, data-model "Raw pages and run records", constitution VII · `backend/app/adapters/tasks.py:190-236` (the `running` row is committed at `:204` with no `try`; `normalize` runs for all items at `:223`, outside the per-item savepoints; nothing sets `finished_at`); `backend/app/adapters/base.py:168`, `backend/app/domain/time.py:46` (`"12:99 م"` matches the regex and raises in `time()`) · CONFIRMED
- Failure scenario: one bad time string, a full disk, or B2-R1-5's `PermissionError` leaves a committed `running` row and no result. A redelivery adds a second row. The runbook's "stuck after 10 minutes means the worker died" points the owner the wrong way.
- Fix direction: on any exception, mark the run `failed` with an `error`, set `finished_at`, then re-raise. Normalise per item inside the savepoint. Set `finished_at` on every terminal state. Add tests for both.

#### B2-R1-13: the home-box message is decompressed without a size limit
- Layer `security` · Source constitution V (size caps), the T062 note "validated before use" · `backend/app/adapters/messages.py:146` (`gzip.decompress(base64.b64decode(page.gz_b64))`; the 2 MB cap at `:83-87` bounds only the compressed JSON) · CONFIRMED
- Failure scenario: a compromised home box sends about 1.5 MB of gzip that inflates to about 1.5 GB. `worker-imports` on VPS-2 is OOM-killed.
- Fix direction: decompress with a bounded reader (`zlib.decompressobj` with `max_length`, at the fetcher's 5 MB cap) and reject anything larger. Add a test with a gzip bomb.

#### B2-R1-14: an orphan channel is skipped silently, though the code says it is logged
- Layer `pipelines` · Source FR-027, T061 ("skipped and logged"), the edge case "The old data links a channel Madar doesn't have" · `backend/app/adapters/upsert.py:412-414` (`continue  # an orphan channel id: skipped and logged (R19)` with no log call and no outcome entry) · CONFIRMED
- Fix direction: record each orphan ref in `outcome.skipped` with the reason `channel_not_published`, so it reaches `run.json`, and assert it in `test_satair_bridge.py`.

#### B2-R1-15: the workers log nothing below WARNING, and every `extra=` field is dropped
- Layer `ops` · Source constitution IX (structured JSON logs to stdout), US2 scenario 6 and the "Overlapping runs … the skip is recorded" edge case · `infra/compose/vps2.yml:41,51,64` and `vps1.yml:108` (workers start with no `-l`); no logging config under `backend/app/workers/` · CONFIRMED
- Failure scenario: the `skipped` (lock held), `fetched`, `ingested`, `source_paused` and `logo_filled` events never appear. Warnings such as `layout_changed` lose their `why`, `url` and `source`. The "skip is recorded" requirement is met only by a log line nobody can see.
- Fix direction: B2 adds `--loglevel=INFO` to every worker command. B1 owns `app/workers/`, so ask B1 for a JSON formatter that keeps `extra=` (a `setup_logging` signal handler).

#### B2-R1-16: the tests don't prove the behaviours the tasks claim
- Layer `tests` · Source constitution (test-first for `locked_fields`, adapter parse and entity resolution), T060, T061, T064 · CONFIRMED
  - `backend/tests/adapters/test_upsert.py:81-107`: the "concurrent" editor commits on the same connection, so removing `.with_for_update()` at `upsert.py:301` would not fail the test.
  - `test_upsert.py:209-224`: the "manual hidden link never re-added" case never puts the manual channel in the source's desired set, so the re-add path (`upsert.py:386-388`) is untested.
  - `test_upsert.py:227-237`: only `SkipItem` is exercised. The `except Exception` savepoint at `upsert.py:107-113` has no test.
  - `test_tasks.py` never runs `fetch` through a failure, a layout change or the real limiter (B2-R1-8, B2-R1-9).
  - `test_rehost_logo.py:111` (`… .exists() or asset.path`) is always true. `test_satair_bridge.py:104-109` checks for a key that is never read.
  - `flushdb()` on the shared test Redis (`test_tasks.py:36-40`, `test_ratelimit.py:14-20`, `test_rehost_logo.py:31-37`, `test_homebox_acl.py:24-31`) wipes other lanes' keys. `backend/CLAUDE.md` and `tests/conftest.py:182-183` say to clear only your own prefixes.
- Fix direction: add a two-connection lock test, the re-add and exception-path tests, and the `fetch` failure tests. Fix the two vacuous asserts. Replace `flushdb()` with prefix-scoped deletes.

#### B2-R1-17: T067's placeholder check can't fail on the real template
- Layer `ops` · Source T067 (ticked), FR-052 · `.github/workflows/infra.yml:51-52` · CONFIRMED (the regex run above)
- Problem: the regex flags a `>password` only at the end of a line. In `users.acl.tmpl` the password sits mid-line (`>${…} ~* &* …`). A literal password on the `default` line passes.
- Fix direction: on every `user` line, flag any `>` token that isn't exactly `>${REDIS_PASSWORD}` or `>${REDIS_HOMEBOX_PASSWORD}`. Add the two bad scratch templates as negative fixtures that the step must reject.

#### B2-R1-18: the `homebox` ACL was not narrowed (T081), and its test never runs Celery
- Layer `security` · Source T081 (ticked: "Narrow the categories to the commands Celery and the token-bucket script actually send"), contracts/ingestion.md "The home box's Redis ACL", constitution V · `infra/redis/users.acl.tmpl:11` (the contract's starting point, byte for byte, including `+@scripting`, `+@pubsub &*` and `+@keyspace`); `backend/tests/adapters/test_homebox_acl.py:65-77` (hand-typed raw commands) · CONFIRMED that it isn't narrowed; PLAUSIBLE that something is over-granted
- Fix direction: derive the command list from a real worker run under the ACL (`MONITOR` or `ACL LOG`), narrow to it, and add a smoke test: a real kombu connection with `global_keyprefix` as `homebox` sends and receives one task.

#### B2-R1-19: the documented `celery call` sends `adapters.fetch` to the `maintenance` queue
- Layer `ops` · Source contracts/ingestion.md ("On demand … lands on the same queue"), T064, T088 · `docs/runbooks/imports-and-sources.md:39-45`; `backend/app/adapters/tasks.py:82-83` (`IngestionRouter` is registered only when the module is imported through `include`); `backend/tests/adapters/test_tasks.py:94-98` (passes only because the test imports the module) · CONFIRMED (the fresh-process run above)
- Failure scenario: the owner's on-demand ysscores fetch runs on `worker-maintenance` on VPS-2, which ysscores answers with 403, instead of on the home box. The T087 on-demand `legacy` run misroutes the same way.
- Fix direction: register the router in `create_app()`. B1 owns `app/workers`, so either ask B1 for that, or pass `-Q` explicitly in the runbook. Add a test that runs in a fresh subprocess.

#### B2-R1-20: several runbook commands don't run as written (T088)
- Layer `ops` · Source CLAUDE.md "Every command in a runbook must match the code", T088 · CONFIRMED (a–e; c by running compose)
  - a) `docs/runbooks/workers.md:29-37,60-63,101-102`, `imports-and-sources.md:39-51,79` and `home-box.md:97` SSH as `deploy@10.8.0.1` from the owner's machine. `deploy` holds only the CI key (`provision-host.md:340`). Every other runbook uses `ssh ubuntu@10.8.0.1`, then `sudo -iu deploy`.
  - b) `imports-and-sources.md:60,96,97` run `psql "$DATABASE_URL_SYNC"`. That variable is a SQLAlchemy URL (`postgresql+psycopg://…`) that psql rejects, and no shell exports it. The convention is `dc exec postgres psql -U madar -d madar`.
  - c) `home-box.md:65-66` run `docker compose -f infra/compose/home-box.yml ps` and `logs` without `--env-file`, which exits 1.
  - d) `home-box.md:76` runs `docker exec madar-redis redis-cli -a "$REDIS_PASSWORD" ACL LIST`. The container is `madar-redis-1`, and `$REDIS_PASSWORD` expands on the host, where it's empty.
  - e) `imports-and-sources.md:116` ends in `up -d` with no service names under `--profile workers`, which also starts `flower`, `worker-live` and `worker-notify`, though `deploy.sh` and the same runbook keep them down on D2.
  - f) No runbook says how to get VPS-2's host key into `DEPLOY_KNOWN_HOSTS`. `provision-host.md §8` covers only `10.8.0.1`, and `ssh-keyscan` can't jump.
- Fix direction: correct each command and run it once against the dev stack or a host before ticking.

#### B2-R1-21: `docs/owner-actions.md`'s D2 section is wrong in places
- Layer `ops` · Source CLAUDE.md "Owner actions", T089, T108 · `docs/owner-actions.md:13,195-198,208-215,233` · CONFIRMED
  - Lane B2 "Before merge" asks the owner to start `worker-scrape` and install the units on the home box. Before the first merge there is no `madar-backend-amd64:stable` image, `homebox` user or firewall rule. README step 4.11 also puts it after the first deploy.
  - The "Open now" counts don't match the lists: B2 before 4 vs 5 listed, B2 after 5 vs 6, B1 after 4 vs 5, A before 3 vs 2 plus 4 follow-ups.
  - Lane A's T108 items have no task IDs. The WireGuard peer for editors is missing, and the walk-through bullet has no quickstart link.
  - Line 211's link `../../specs/002-d02-core-flows/tasks.md#lane-a-follow-ups-open` is broken; it should be `../specs/…`.
  - The `ADMIN_JWT_SECRET` bullet says a deploy without it "leaves it restarting". `${ADMIN_JWT_SECRET:?}` in fact fails every compose command at parse time, including the infra `sync`.
  - The firewall-proof `redis-cli … --user homebox ping` has no `--pass`, so it answers `NOAUTH`, not `PONG`.
- Fix direction: correct each item. The Lane A and Lane M rows are shared, so keep the edits to facts.

#### B2-R1-22: stale host and index docs
- Layer `ops` · Source FR-055 · `docs/runbooks/provision-host.md:110-250`; `docs/runbooks/README.md` ("Planned runbooks") · CONFIRMED
- Problem: `bootstrap-vps.sh vps1` now requires `REDIS_HOMEBOX_PASSWORD` and `HOME_BOX_WG_IP`, but provision-host §4's env blocks list neither, nor VPS-2's keys, so a rebuild dies on a key the runbook never mentions. `exposure-check.md` has no check for `10.8.0.1:6379` from a wg0 peer. README still lists `staff-accounts.md` as planned.
- Fix direction: update all three.

#### B2-R1-24: a failing `compose up -d` exits before any rollback
- Layer `ops` · Source constitution IX · `infra/scripts/deploy.sh:175` (`start_apis`), `:215` (VPS-2) · PLAUSIBLE
- Problem: under `set -Eeuo pipefail`, a non-zero `up -d` exits at once, and the rollback branch runs only when health polling fails. B2-R1-3 is one way in: api-public ends up on the new tag, api-admin down, and nothing rolled back.
- Fix direction: route start failures into the same rollback path as health failures.

#### B2-R1-25: Redis is published on wg0 before the firewall rule that limits it exists
- Layer `security` · Source constitution V, T082 · `infra/scripts/deploy.sh:147-148,270-274`; `docs/runbooks/README.md:86` (the home box after the first deploys) vs `docs/owner-actions.md:197-200` · PLAUSIBLE
- Problem: the `DOCKER-USER` rule needs `HOME_BOX_WG_IP` and a `bootstrap-vps.sh vps1` re-run, which CI never does. Once merged, `sync` publishes `10.8.0.1:6379`, and every wg0 peer can reach Redis, protected only by its password.
- Fix direction: make "peer, `HOME_BOX_WG_IP`, bootstrap" a hard before-merge step, and have `deploy.sh` refuse to publish Redis on wg0 while the rule is missing.

#### B2-R1-26: the bridge can flip `matches.legacy_id` on every run
- Layer `pipelines` · Source SC-004 ("a second run changes nothing"), FR-027 · `backend/app/adapters/upsert.py:226-241,307-311,449-450` · PLAUSIBLE (the logic is confirmed by reading; it needs double-listed data in the window)
- Problem: 11 `ysMatchId`s are listed on two days in the old data. The survivor is found by its ysscores id, and `match.legacy_id = item.legacy_id` alternates between the two listings, so each run writes audit rows and bumps `matches`.
- Fix direction: don't overwrite an existing `legacy_id` on a row found by its ysscores id. Add a two-listing test.

#### B2-R1-27: the ysscores list time is assumed to be Cairo, while the old importer corrected it per match
- Layer `pipelines` · Source constitution II, R16 · `backend/app/adapters/base.py:168-171`, `ysscores.py:5-6`; `../old_app/public/IMPORT.html:1675-1679,2135-2138` · PLAUSIBLE
- Problem: the old importer corrected each list time from the match page's JSON-LD `startDate`, because the site shows times in the browser session's zone. The port relies on a fixture saved from the developer's machine.
- Fix direction: the owner checks once from the home box (one list time against a match page's UTC start) and records the result in `imports-and-sources.md`. Optionally add a runtime sanity check.

#### B2-R1-28: api-admin may never see `10.8.0.1` as the peer, so every login would count under one IP
- Layer `security` · Source FR-003 · `infra/compose/vps1.yml:86-89` (`--forwarded-allow-ips=10.8.0.1`, `FORWARDED_ALLOW_IPS`) · PLAUSIBLE
- Problem: if Caddy reaches api-admin through Docker's bridge, or Docker's DNAT shows the bridge gateway, the peer is never `10.8.0.1`. `client_ip()` then ignores `X-Forwarded-For`, every editor shares one limiter key per email, and any WireGuard peer can lock any editor out.
- Fix direction: at T047, log the peer address api-admin sees for a request through Caddy, and set the trusted address to match.

### LOW

- B2-R1-29 `backend/app/adapters/fetcher.py:167`: `ResponseTooLarge` carries `response.url`, which includes the bridge's `?key=<Firebase API key>`, so an oversize reply writes the key into a Celery traceback. Use the URL without its query. CONFIRMED.
- B2-R1-30 `backend/app/adapters/raw_store.py:41`: `source` is joined into the path unvalidated. It's safe today only because of the foreign key on `import_runs.source`. Validate it against the adapter registry. CONFIRMED.
- B2-R1-31 `backend/app/adapters/fetcher.py:171-177`: redirects check the host only. They don't require `https` or a standard port, and there is no total-time bound. CONFIRMED.
- B2-R1-32: nothing writes `team_external_ids`, though data-model.md:148 says a team's ysscores id is recorded. `upsert.py:145-147` always passes `external_id=None` for competitions. `tasks.py:119` is `fetch(source, start=None)`, not the contract's `(source, window, run_id)`. CONFIRMED.
- B2-R1-33: `upsert.py:338-341` keeps the old team id when a renamed team doesn't resolve but overwrites `*_team_name`, so the two can disagree. A paused source records `succeeded` with 0 upserts (`tasks.py:219-222`), which looks like a quiet day. CONFIRMED.
- B2-R1-34 `docs/runbooks/home-box.md`: the `git clone` at line 13 gives `/srv/madar/infra/infra/…`. No command creates or refreshes that checkout. The unit install is only in the unit file's header. `infra/compose/home-box.yml:18` loads the whole `.env`, which puts `GHCR_READ_TOKEN` into the worker's environment despite its "only what the fetch path needs" comment. CONFIRMED.
- B2-R1-35 firewall: `infra/firewall/vps1.rules:55` lacks the `-i wg0` that the 8001 rule has, and `check-firewall.sh:71` accepts any `/32`, not `HOME_BOX_WG_IP`. CONFIRMED.
- B2-R1-36 `.github/workflows/backend.yml`: `deploy-vps2` rsyncs `infra/` to VPS-1 outside the `deploy-vps1` concurrency group. If VPS-2 fails after VPS-1 succeeds, the hosts diverge, and `deploy-and-rollback.md` doesn't say so. CONFIRMED.
- B2-R1-37 wording: the root `CLAUDE.md:44` still says "2 OCI Ampere arm64 VMs", with no home-box or amd64 exception. `secrets.md`'s JWT rotation says it "signs every admin out", then says refresh tokens still work. It uses `openssl rand -hex 32` where T049 said `-base64 48`. CONFIRMED.
- B2-R1-38 process: `b0fcde2`, a B2 commit, ticked Lane B1's tasks (FR-051: a lane ticks only its own section). Code and tests landed in the same commits, so test-first (FR-053) can't be shown. T052 saved no real `--:--` page. CONFIRMED.

## Requirements

| Requirement | Status | Where | Test |
| --- | --- | --- | --- |
| FR-020 adapter base: bucket, allowlist, caps, backoff, raw pages | **Partial** | `fetcher.py`, `ratelimit.py`, `raw_store.py` | `test_fetcher`, `test_ratelimit`, `test_raw_store`; B2-R1-8 |
| FR-021 ysscores port, pure parse | Built, with postponed and zone gaps | `ysscores.py`, `base.py` | `test_ysscores_parse`, `test_ysscores_normalize`; B2-R1-10, B2-R1-27 |
| FR-022 upsert by key, locked fields, own links only, ±45 min probe | **Partial** | `upsert.py` | `test_upsert`; B2-R1-2, B2-R1-11 |
| FR-023 resolution v0 | Built | `resolve.py` | `test_resolve` |
| FR-024 importer logos on VPS-1 | Built | `media_tasks.py` | `test_rehost_logo` |
| FR-025 `import_runs` for every run | **Not met** for failures | `tasks.py` | `test_tasks` (happy path only); B2-R1-9, B2-R1-12 |
| FR-026 task options, `SET NX EX`, beat every 3 h | Built | `workers/base.py`, `tasks.py`, `schedule.py` | `test_tasks`, `test_schedule` |
| FR-027 bridge read-only, orphans logged | **Partial** | `satair_bridge.py`, `upsert.py` | `test_satair_bridge`; B2-R1-14, B2-R1-26 |
| FR-028 home box reaches only Redis | Built; ACL broad, logs blind | `home-box.yml`, `users.acl.tmpl` | `test_homebox_acl`; B2-R1-18 |
| FR-029 CI deploys VPS-2 on merge | **Not met** | `backend.yml`, `deploy.sh` | B2-R1-4, B2-R1-5, B2-R1-6 |
| US2 scenario 6 overlap skipped and recorded | **Partial** | `locks.py` | B2-R1-15 |
| SC-004 tomorrow's fixtures after the first run | **Not met** | | B2-R1-1, B2-R1-5, B2-R1-8 |
| SC-005 a failed fetch recorded with its errors | **Not met** | | B2-R1-9 |
| constitution IX health-checked deploy and rollback | **Partial** | `deploy.sh` | B2-R1-1, B2-R1-3, B2-R1-23, B2-R1-24 |
| FR-051 own folders only | Code yes; ticks in B1's section | | B2-R1-38 |
| FR-052 no secret committed | Met: no real keys; the template holds placeholders | | gitleaks unchanged; B2-R1-17 |
| FR-055 runbooks | Present; several commands wrong | `docs/runbooks/` | B2-R1-7, B2-R1-20, B2-R1-22 |

## Task audit

- **Ticked but not done:**
  - T067: the ACL check can't fail (B2-R1-17).
  - T079: `/srv/raw` is not provisioned (B2-R1-5).
  - T081: the ACL is not narrowed and is unreadable (B2-R1-18, B2-R1-1).
  - T082: the check breaks VPS-2 (B2-R1-6).
  - T083: the health wait and the start failure (B2-R1-23, B2-R1-24).
  - T085: VPS-2 is unreachable from CI (B2-R1-4).
  - T088: the runbooks (B2-R1-7, B2-R1-19, B2-R1-20).
  - T089: owner actions (B2-R1-21).
  - T060, T061, T064: the claims their tests don't prove (B2-R1-16).
  - T078: the api-admin command (B2-R1-3).
- **Verified done:** T053, T054, T062, T063, T065, T066, T068–T077 (code), and T080 and T084 (with the gaps above).
- **Open, correctly:** T086 and T087, the owner's checks on the live hosts.

## Owner must review

- B2-R1-10: **decided 2026-10-31**. Postponed items are imported with `time_tbd = true` and no kickoff (a locked kickoff is kept), and listed in `run.json`. research.md R16 "Postponed items" records this.
- B2-R1-27: the one-time zone check from the home box.
- B2-R1-15: who owns the worker logging config (B1's `app/workers`, B2's compose).
- B2-R1-25: whether the home-box peer and the `DOCKER-USER` rule become a before-merge step.

## Outside this change

- The two NUL 500s in the pytest run are B1's and D1's routes (`b1-round-1.md`).
- The shared `env_file` across all VPS-1 services is D1's pattern.

## Not reviewed

- Live ysscores and Firestore responses: nothing was fetched from the network.
- Redis under a real Celery worker as `homebox` (B2-R1-18 asks for that test).
