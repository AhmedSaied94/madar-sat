---

description: "D4 · MVP launch: tasks per lane"
---

# Tasks: D4 · MVP launch

**Input**: Design documents from `specs/004-d04-mvp-launch/`: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md), [bug-bash.md](bug-bash.md).

**Tests**: Mandatory (constitution, Quality Gates). In every lane, the test tasks come first and must be seen failing before the code they cover. Fixes add tests and never remove them (FR-045).

**Organization**: one `## Lane` section per lane, each an independently testable user story, plus a final `## Done check`.

- A lane implements and ticks **only its own section** and changes only its own folders (FR-042). Hardening only: no new feature, screen or endpoint (FR-041).
- Review fix tasks are appended at the end of a lane's section by `/speckit-review-implementation`. Security findings for other lanes are appended by B1 as `SR-n` tasks (T011).
- **Carry-over** (delivery-plan §5.3):
  - Lane M's M-T045-1/2/3 from 003 come first in Lane M (T060–T062).
  - The missing nightly backup heartbeat, which 003 T083 expected and never arrived, comes first in Lane B2 (T030).
  - The owner's open 002/003 checks stay in their `tasks.md` files and `docs/owner-actions.md`. The ones the gate needs are listed under the Done check's preconditions.

| Section | Spec story | Story label | Branch | Folders |
| --- | --- | --- | --- | --- |
| Lane B1 | User Story 1 (P1) | `[US1]` | `d04-b1` | `backend/` except `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/`; `docs/load-tests/`; `specs/004-d04-mvp-launch/security-review.md` |
| Lane B2 | User Story 3 (P3) | `[US3]` | `d04-b2` | `infra/`, `.github/`, `backend/app/adapters/`, `backend/tests/adapters/`, `backend/tests/fixtures/` |
| Lane A | User Story 4 (P4) | `[US4]` | `d04-a` | `admin/` |
| Lane M | User Story 2 (P2) | `[US2]` | `d04-m` | `app/`; `specs/004-d04-mvp-launch/bug-bash-results.md` |

Every lane may also edit `docs/runbooks/` for its own parts and its own section of `docs/owner-actions.md` (FR-044).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task).
- **[USn]**: the spec story the task belongs to.
- Paths are repo-relative.

## Dependencies & execution order

### Between lanes

- **Client IP (R1):**
  - B1's T003–T005 (`TRUSTED_PROXIES` in code) and B2's T034 (fixed subnet and the env pass-through) merge together, in either order. The code default (`10.8.0.1`) keeps today's behaviour until B2's Compose values arrive.
  - The deploy of both blocks B1's T008 (host check) and T009 (load test).
- **Security findings:** B1's T011 appends `SR-n` tasks to the other lanes' sections by 12:00. Each lane fixes its own.
- **Admin deploy:**
  - Lane A's T050 (`pnpm build` stays CSP-clean) and B2's T040–T041 (deploy job and Caddy root) are independent.
  - The live smoke run (A's T055) needs B2's T040 deployed.
- **Playwright in CI:** B2's T042 adds the step after Lane A's T051–T053 exist on `master`. Until then the step is absent, not failing.
- **Web release:**
  - Lane M's T063–T067 (stage script, bootstrap, `sw.js`) and B2's T043–T046 (Caddy, `firebase.json`, `pwa.yml`, the `app.yml` step) follow [contracts/web-release.md](contracts/web-release.md) and can start in the morning.
  - The first `web-v*` tag needs both, plus B1's T009 passed and T012 with no open CRITICAL.
- **Reminders on both platforms** (gate): 003 B1 T047 (FCM on VPS-2, owner) and Lane M's release builds (T070).

### Inside each lane

Tests first (seen failing) → code → host or device validation → runbook and owner-actions.

### Parallel examples

- **B1:** T001 and T002 (tests in different files) in parallel; T006 (k6 script) in parallel with T003–T005.
- **B2:** T031 (report tests), T036 (fixture tests) and T043 (Caddy) in parallel; T040 and T045 touch different workflows.
- **A:** T051 (Playwright config) and T054 (polish list) in parallel.
- **M:** T060–T062 in parallel (different files); T063 (`sw_core` tests) in parallel with T065 (stage-script test).

## Implementation strategy

1. **Morning:**
   - B1 and B2 land the client-IP fix (SR-1) first; it is the one change that makes a public launch safe.
   - Lane M closes the carry-over.
   - B2 diagnoses the backup heartbeat.
2. **By 12:00:**
   - B1 files the security findings.
   - B2 merges the mirror, `firebase.json` and the admin deploy.
   - Lane M has the release layout and the worker green on the preview channel.
3. **Afternoon:** the load test window before the public tag, the bug bash on three platforms, the live smoke runs.
4. **Evening:** the owner tags `web-v0.1.0` and `app-v0.3.0` once plan.md's release conditions hold, then runs the Done check.

---

## Lane B1

**Story (US1, P1):** as the owner, I know the API holds the launch load and has no critical security hole.

**Independent test:** see spec US1 and [quickstart B1](quickstart.md#lane-b1-client-ip-load-security).

### Tests first (B1): write them and see them fail

- [X] T001 [P] [US1] Write `backend/tests/auth/test_client_ip.py` for `client_ip()` (`backend/app/auth/limits.py`) driven by a `trusted_proxies` setting. Cases:
  - a peer `172.30.0.1` with `X-Forwarded-For: 203.0.113.7` gives `203.0.113.7`;
  - `X-Forwarded-For: 6.6.6.6, 203.0.113.7` from that peer gives `203.0.113.7` (the forged left hop is ignored);
  - a peer not in the list ignores the header;
  - a list of `127.0.0.1,172.30.0.1` trusts both;
  - an invalid hop falls back to the peer;
  - the default list is exactly `10.8.0.1`.

  All fail today, because the trust list is the constant `TRUSTED_PROXY` (research R1).
- [X] T002 [P] [US1] Extend `backend/tests/api/test_ratelimit.py` for `RATE_LIMIT_EXEMPT_IPS` (research R3, FR-007):
  - an empty list exempts nobody;
  - an exempt IP is never counted or limited, while another IP in the same test still gets `429` with `Retry-After`;
  - a forged `X-Forwarded-For` naming the exempt IP from an untrusted peer is limited;
  - the startup warning is logged when the list is non-empty.

### Implementation (B1)

- [X] T003 [US1] Add `trusted_proxies: Annotated[list[str], NoDecode]` (alias `TRUSTED_PROXIES`, default `["10.8.0.1"]`) and `rate_limit_exempt_ips: Annotated[list[str], NoDecode]` (alias `RATE_LIMIT_EXEMPT_IPS`, default `[]`) to `backend/app/settings.py`, registered with `_split_comma_list`. Validate each entry with `ipaddress.ip_address`, so a bad value fails startup.
- [X] T004 [US1] Make `client_ip()` in `backend/app/auth/limits.py` read `get_settings().trusted_proxies` instead of `TRUSTED_PROXY`. Keep the right-most-untrusted-hop rule. Every hop in the list is skipped, not only `10.8.0.1`. The admin app keeps the default. T001 passes.
- [ ] T005 [US1] In `backend/app/api/ratelimit.py`, return early from `rate_limit()` when `client_ip(request)` is in `settings.rate_limit_exempt_ips`, right after the IP is derived (around `:88`). Log `ratelimit.exempt` at debug per request plus one info summary a minute, and log a warning at app startup in `backend/app/public.py` when the list is non-empty. T002 passes. Then file `SR-1` (R1) in `specs/004-d04-mvp-launch/security-review.md` as `fixed (<sha>)` once B2's T034 is deployed.
- [X] T006 [P] [US1] Write `backend/loadtest/mvp.js` (k6), following research R2:
  - **Scenario `live`:** `constant-arrival-rate` at `__ENV.LIVE_RPS` (default 170) for `__ENV.DURATION` (default `10m`) on `GET /v1/live`. A share `__ENV.REVALIDATE_SHARE` (default 0.5) resends the last `ETag` as `If-None-Match`.
  - **Scenario `matches`:** at `__ENV.MATCHES_RPS` (default 50) on `GET /v1/matches?from=&to=` (one UTC day each, `Z` bounds) for today to +3, with 10 % `GET /v1/matches/<id>` from ids seen.
  - **Tags:** each request is tagged `cache:hit` or `cache:miss` from the API's cache response header (or, if none exists, `304`/repeat requests count as `hit` and the first request per URL per minute as `miss`; record which in the report).
  - **Thresholds:** `http_req_duration{cache:hit}` `p(95)<150` on both scenarios; `http_req_duration{cache:miss}` `p(95)<400`; `http_req_failed<0.01`, with a `responseCallback` that counts only `200` and `304` as success, so `429` fails.
  - **Output:** a `handleSummary` that writes JSON for the report.
- [X] T007 [US1] Write `docs/runbooks/load-testing.md` and add it to `docs/runbooks/README.md` (index and "After setup"). It covers:
  1. confirm VPS-2's public IP as the API sees it (one request + `dc logs caddy`);
  2. put it in `RATE_LIMIT_EXEMPT_IPS` in VPS-1's `.env` and `dc up -d --force-recreate api-public`;
  3. run `docker run --rm -i grafana/k6:<pinned arm64 tag> run -e HOST=… - < backend/loadtest/mvp.js` on VPS-2, with `docker stats --no-stream` sampled on VPS-1 every 10 s;
  4. clear the value and recreate;
  5. prove the limit is back with a 700-request loop that gets `429`.

  Pin the k6 tag. Every command must match the code.

### Validation (B1)

- [x] T008 [US1] After B2's T034 and T003–T005 are deployed, run quickstart B1 step 1: two phones on different networks give two `rl:ip:*` keys with their public IPs. Record the output in the PR and mark `SR-1` fixed.
  **Done 2026-11-03:** two clients on different networks gave `rl:ip:104.28.228.70` and `rl:ip:130.110.97.25`; SR-1 is fixed.
- [ ] T009 [US1] Run the load test by T007 (before the public tag, or at a quiet hour) and write `docs/load-tests/2026-11-04-mvp.md` in the format of [data-model.md](data-model.md#load-report-docsload-testsdate-mvpmd-b1).
  - **If a target fails:** raise `api-public` to `-w 3` (ask B2 for the Compose `command`), re-run, and record both runs.
  - **If it still fails:** stop and tell the owner before the Caddy cache-handler contingency (plan.md Complexity Tracking).
  **Ran 2026-11-03, FAILED** ([report](../../docs/load-tests/2026-11-03-mvp.md)): 0 errors and 0 `429`s, but p95 ≈ 5 s on both scenarios at about 124 req/s; VPS-1's one core is saturated. Waits on the owner's fix (more OCPU or the Caddy `/v1/live` cache) and a second run.
- [x] T010 [US1] Run the code security review with the `security-reviewer` agent over the whole repository against SD §8 and constitution V, row by row (research R5). Record every finding in `specs/004-d04-mvp-launch/security-review.md` in the data-model format (ID `SR-n`, severity, file, owner lane, status).
  **Done 2026-11-03:** [security-review.md](security-review.md), SR-1 to SR-23. Gate PASS; SR-2 needs the owner's accept-or-fix.
- [x] T011 [US1] By 12:00, append each other-lane finding of CRITICAL or HIGH severity as a task `SR-n` under a `### Security review findings` heading at the end of that lane's section in this file, with file, line, the fix expected and a test to add. MEDIUM and LOW go in the report with a target day.
  **Done 2026-11-03:** no CRITICAL or HIGH finding, so no `SR-n` task is appended. The MEDIUM and LOW findings are in [security-review.md](security-review.md) for the owner to schedule.
- [x] T012 [US1] Run the host review (research R5):
  - `docs/runbooks/exposure-check.md` from the internet;
  - headers and CORS on `api.`, `media.` and `app.` against SD §8;
  - `https://10.8.0.1` from the internet (no answer);
  - Postgres and Redis ports from the internet (closed);
  - `RATE_LIMIT_EXEMPT_IPS` empty on VPS-1;
  - gitleaks over the full history.
  **Done 2026-11-03** ([security-review.md](security-review.md#host-review-t012-2026-11-03)): only 80/443 on VPS-1, nothing on VPS-2; TLS, headers, CORS and the admin's absence from the public listener as expected. Left for the owner: the off-WireGuard check of `https://10.8.0.1`.

  Fix B1's CRITICAL and HIGH with a regression test each. When every CRITICAL is fixed and every HIGH is fixed or `accepted (owner, reason)`, write "Gate: no open CRITICAL" at the top of the report.
- [X] T013 [US1] Add B1's D4 items to `docs/owner-actions.md` (the allowlist window, accepting any HIGH, reading the load report) with the runbook links.

### Status after implement (2026-11-03, opencode)

Lane B1's code and its tests are in on `d04-b1`, cut from `master` (`acbfece`).

- **Done locally:** T001–T004 (the `TRUSTED_PROXIES` setting behind `client_ip()`, validated at startup), T006 (the k6 script, `k6 inspect`-clean and smoke-run against a local server), T007 (the load-testing runbook, plus the client-IP section in `response-cache-and-limits.md`), T013 (the owner's items below).
- **T005 is half done:** the exempt-IP early return, the `ratelimit.exempt` logs, the once-a-minute summary and the startup warning are in and green (T002). Its last clause — `SR-1` filed as `fixed (<sha>)` — needs B2's T034 deployed, so it stays open.
- **Not run here (they need the hosts, or a review that this session does not perform):** T008 (two networks), T009 (the load test and `docs/load-tests/…`), T010–T011 (the security review and the other lanes' `SR-n` tasks), T012 (the host review).
- **Checked:** `ruff check` and `ruff format --check` clean, `mypy --strict app` clean, `pytest` **1374 passed, 4 failed**; the four are `tests/adapters/test_homebox_acl.py`, which fail on this machine because the dev Redis requires a password (the environment note in `docs/owner-actions.md` from D3), not from this lane. `export-openapi` writes no change, so the contract is untouched.

### Review fixes (round 1)

From [reviews/b1-round-1.md](reviews/b1-round-1.md).

- [X] B1-R1-1 Fix the `matches` scenario in `backend/loadtest/mvp.js`: it calls `/v1/matches?date=…`, which the API rejects with 422 (the route requires `from` and `to`, `backend/app/api/public/matches.py:30-31`). Send `from`/`to` as UTC day bounds (ISO, `Z`) for today to +3, and add a `check()` that a 200 body has a `data` array. Correct the `date=` wording in T006, research R2 and `docs/runbooks/load-testing.md`. Prove it with a short local run against `uvicorn app.public:app` that shows zero 422s. (HIGH, per FR-001, FR-002, US1 AC2)
- [X] B1-R1-2 Hold `/v1/live`'s full responses to 150 ms in `backend/loadtest/mvp.js`: today every request without `If-None-Match` is tagged `cache:miss` and gets the 400 ms budget (`:68-73`, `:110-113`). Add `http_req_duration{scenario:live}: ['p(95)<150']` (and a per-scenario threshold for `matches`), tag `miss` only as T006 says, and make the `If-None-Match` share an `-e` variable. Show with `k6 inspect` that the thresholds exist. (HIGH, per US1 AC1, FR-002, SC-001)
- [X] B1-R1-3 Make `docs/runbooks/load-testing.md`'s open and close checks real (`:72`, `:120`): `docker logs … | grep ratelimit.exempt_enabled` never sees the warning, because it goes to stderr, so step 4's `# 0` can't fail. Check the effective value instead (`docker exec madar-api-public-1 printenv RATE_LIMIT_EXEMPT_IPS`, empty after closing), and run every docker command as `deploy` (`sudo -iu deploy docker …`). (HIGH, per the spec edge case "the allowlist is left filled" and T007)

---

## Lane B2

**Story (US3, P3):** as the owner, imports have run unattended since D2, I have a first runbook, and the PWA mirror and admin deploy are live.

**Independent test:** see spec US3 and [quickstart B2](quickstart.md#lane-b2-imports-mirror-release-admin-deploy).

### Carry-over (B2, first)

- [x] T030 [US3] Find out why the nightly database backup's Kuma heartbeat never arrived (003 T083 expected it the next morning; the owner reports no signal), fix the cause, and prove it. Check in this order, recording each result in the PR:
  1. on VPS-2, `systemctl list-timers 'backup-*'` shows `backup-db.timer` enabled with a next run. 003's "bootstrap re-run for the backup timers" was an open owner item, so the timers may never have been installed;
  2. `journalctl -u backup-db.service --since -2d` shows a run and its exit code;
  3. `KUMA_PUSH_URL_BACKUP_DB` (and `_MEDIA`, `_MEDIA_WEEKLY` on VPS-1) are set in the host `.env` in the form `infra/backup/backup-db.sh:36` expects. 003 T086 left "the bare-form `KUMA_PUSH_URL_*` values" with the owner;
  4. the script reaches Kuma: from VPS-2, `curl` the push URL by hand and see the monitor turn green;
  5. `restic snapshots --tag db` lists a snapshot from the last run.

  **After the fix:**
  - run `systemctl start backup-db.service` once and see the heartbeat and the snapshot;
  - if the cause was code, add a regression check to `infra/scripts/check-backup-restore-commands.sh` or the `infra.yml` checks (for example, the timer units are installed and enabled by `bootstrap-vps.sh`, and the script fails loudly when the push URL is empty instead of skipping the heartbeat);
  - update `docs/runbooks/backups.md` and `docs/runbooks/uptime-kuma.md` with the check;
  - tick 003 T083 only when the next scheduled run also reports.

  The monthly restore drill itself stays manual until D8 (`backups.md` "The monthly restore drill").

  **Result (2026-11-03).** 1. `backup-db.timer` enabled, next run 2026-11-04 01:00 UTC, last run 2026-11-03 01:05 UTC. 2. The journal shows that run finishing with exit 0 and snapshot `9571f2b4`. 3. `KUMA_PUSH_URL_BACKUP_DB` is set in VPS-2's `.env` (`http://uptime-kuma:3001`). 4. The push landed: Kuma's `backup-db` heartbeat at 01:05:21 says `ok 20261103T010502Z`. 5. `restic snapshots --tag db` lists the same snapshot. The cause was the open 003 item itself: the timer was never installed before D3's bootstrap re-run, so 01:05 was its first scheduled run — and it reported. Code fix: both backup scripts now refuse to start when their `KUMA_PUSH_URL_*` is empty (a skipped heartbeat is how the monitor stayed grey), with the missing-URL cases added to `check-backup-heartbeat.sh`; `infra.yml` asserts `bootstrap-vps.sh` still installs all three timers. 003's T083 stays open until the next scheduled run (2026-11-04 01:00 UTC) also reports.

### Tests first (B2): write them and see them fail

- [x] T031 [P] [US3] Write `backend/tests/adapters/test_report.py` for the pure functions behind `python -m app.adapters.report` (research R6):
  - **Slots:** expected slots from `backend/app/adapters/schedule.py` for a 48 h window, including `ysscores-fixtures` every 3 h and `livesoccertv-48h` every 2 h.
  - **Matching:** runs matched to slots by `source` and `started_at` within the slot window.
  - **Manual runs:** detected from `audit_log` source actions (run now and resume) by source and time.
  - **Coverage:** per Cairo day for competitions with `priority IS NOT NULL`, counting matches with ≥ 1 visible channel link.
  - **Exit code:** non-zero when a slot is missing or manual.
- [x] T032 [P] [US3] Write the infra checks in `infra.yml`'s `check` job, failing today:
  - the rendered `vps1.yml` has the fixed network subnet `172.30.0.0/24` with gateway `172.30.0.1`;
  - `api-public` gets `TRUSTED_PROXIES` and `--forwarded-allow-ips`;
  - `RATE_LIMIT_EXEMPT_IPS` defaults to empty;
  - the `app.` site in `infra/Caddyfile` has `/r/*` immutable and `precompressed br gzip` with no `encode`;
  - the wg0 site's root is `/srv/admin/current`;
  - `infra/firebase/firebase.json` has the `^/r/[0-9a-f]{16}/` immutable rule and `no-cache` on `sw.js`, `release.json` and the `drift_worker.js` shim.

### Implementation (B2)

- [x] T033 [US3] Implement `backend/app/adapters/report.py`, with sub-commands `runs --hours N` and `coverage --days N`. It is read-only and outputs plain text tables in the formats of [data-model.md](data-model.md#import-report-python--m-appadaptersreport-b2). T031 passes.
- [x] T034 [US3] In `infra/compose/vps1.yml`:
  - give the default network a fixed IPAM subnet `172.30.0.0/24` with gateway `172.30.0.1`;
  - pass `TRUSTED_PROXIES: ${TRUSTED_PROXIES_PUBLIC:-127.0.0.1,172.30.0.1}` and `RATE_LIMIT_EXEMPT_IPS: ${RATE_LIMIT_EXEMPT_IPS:-}` to `api-public`;
  - give it a `command` with `--forwarded-allow-ips` set to the same trust list (keeping `-w 2`).

  Note the network recreation in `docs/runbooks/deploy-and-rollback.md`, because changing a network's subnet needs `dc down` of the attached services once. Merge with B1's T003–T005 (`contracts/ops-and-ci.md`). T032's Compose checks pass.
- [x] T035 [US3] Run `report runs --hours 48` and `report coverage --days 4` on VPS-2 (`dc exec worker-imports python -m app.adapters.report …`). Paste the output in the PR, and explain every missing or manual slot and every coverage gap (FR-010, FR-012).

  **Output (2026-11-03 03:30 UTC, run in a one-off container with the module mounted from this branch, since the image predates it).** `runs --hours 48`: **56 slots, 36 flagged**. Every one of the 16 `legacy` slots ran and is `partial` (161–216 found, 2–48 upserted; the run log's only skip is `channel_not_published`). **No `ysscores` slot after 2026-11-02 09:00 and no `livesoccertv` slot at all**: `worker-imports` logs `scheduled … queue: scrape_home` for both, and the home box — `scrape_home`'s only consumer — is offline (`home-box.md` "Take it offline": queued fetches expire after two hours, nothing is replayed). That is why no `import_runs` row exists and the slot reads `missing`. `coverage --days 4` lists every prioritized competition for 2026-11-03 … 11-06; the gaps are the Iraqi, Dutch, Moroccan, Omani, Libyan, Kuwaiti and Bahraini leagues with matches but no visible channel link, plus the competitions with no match yet that far out. No slot was `manual`, so no admin action queued a run in the window.
- [x] T036 [P] [US3] For each distinct failed or `partial` run in the last 5 days of `/srv/raw/<source>/<day>/<run_id>/` on VPS-2, add a trimmed fixture `backend/tests/fixtures/<source>/edge-<slug>.html.gz` with no personal data, and a `parse` test in `backend/tests/adapters/` that fails before the fix (research R7, FR-011).

  **None found.** The run query
  `select id, source, started_at, status, items_found, items_upserted, error, raw_path from import_runs where started_at > now() - interval '5 days' and status <> 'succeeded' order by started_at desc`
  returns 20 rows, all `legacy` (the Sat Air bridge), ids 1–29. Every one is `partial` for the same non-parse reason: 16 of 161–216 links name a legacy channel that is not in `channels` (`channel_not_published`, `upsert.py`), which is recorded in `run.json` by design. No fetched page failed, so there is no saved page a `parse` test could fail on.
- [x] T037 [US3] Fix each parser in `backend/app/adapters/<source>.py` until T036's tests pass, keeping `parse` pure. If no edge pages exist, record "none found" with the run query in the PR.

  **None found** — see T036. The 20 `partial` runs are the bridge's unpublished channel links, not a parser defect, so no adapter changed.
- [x] T038 [US3] Write `docs/runbooks/on-call.md` (FR-013) and list it in `docs/runbooks/README.md` (index and the top of "After setup"). It has one row per Kuma monitor and Telegram alert (source breaker, zero items, backup heartbeats, `api-public`, media, `pwa`, `pwa-mirror`, Celery heartbeats): what it means → the first check → the fix, linking `deploy-and-rollback.md`, `imports-and-sources.md`, `source-alerts.md`, `backups.md`, `workers.md`, `home-box.md` and `uptime-kuma.md` instead of copying them. It also covers:
  - log locations (`dc logs <service>`, `journalctl -u backup-*`);
  - switching a blocked source to the home box or the bridge;
  - a mirror alert.

  Check every command against the code.

### Mirror, releases and admin deploy (B2)

- [x] T039 [US3] Update `infra/scripts/bootstrap-vps.sh`:
  - create `/srv/admin/releases/placeholder/` from `infra/admin-placeholder/index.html` and a relative symlink `/srv/admin/current -> releases/placeholder`, migrating an existing flat `/srv/admin` once;
  - keep `/srv/app-mirror`;
  - ensure the backup timers are installed and enabled (feeds T030).

  Update `docs/runbooks/provision-host.md`.
- [x] T040 [US3] Add a `deploy` job to `.github/workflows/admin.yml` (research R10, `contracts/ops-and-ci.md`). It runs on `master` only, after `check`, with `concurrency: deploy-vps1-admin`:
  1. download the `check` job's `admin/dist` artifact (add the upload to `check`);
  2. join wg0 with `.github/actions/vps1-sync` (`WG_CI_CONFIG`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`);
  3. rsync to `vps1:/srv/admin/releases/$GITHUB_SHA/`;
  4. `ln -sfn releases/$GITHUB_SHA /srv/admin/current.new && mv -T /srv/admin/current.new /srv/admin/current`;
  5. fetch `https://10.8.0.1/` with the internal CA and check it references the new bundle's entry asset. On failure, repoint `current` to the release recorded before step 4 (`readlink` saved first) and fail the job (constitution IX);
  6. keep the newest 5 releases plus `placeholder`;
  7. always leave wg0.

  A failure before step 4 leaves `current` unchanged; a failure at step 5 restores it. Prune only after step 5 passes. T048 forces each case once.
- [x] T041 [US3] In `infra/Caddyfile`, change the wg0 site's `root` to `/srv/admin/current`, keeping every header and the `/admin/api/*` handler unchanged. T032's check passes.
- [ ] T042 [US3] After Lane A's T051–T053 are on `master`, add to `admin.yml`'s `check` job, after `build`: `pnpm exec playwright install --with-deps chromium` and `pnpm e2e` (mock mode). Upload `admin/playwright-report/` on failure.

  **Waiting on Lane A.** `admin/e2e/`, `admin/playwright.config.ts` and the `e2e` script are Lane A's T051–T053, which are not on `master`; the step stays absent (not failing) until they are. Please fix this in a follow-up commit of this lane once `d04-a` merges.
- [x] T043 [P] [US3] In `infra/Caddyfile`'s `app.` site (research R8, `contracts/web-release.md`):
  - add `@release path /r/*` with `Cache-Control: public, max-age=31536000, immutable`;
  - replace `encode zstd gzip` with `file_server { precompressed br gzip }`;
  - serve `/release-check.txt` with `no-cache`;
  - keep the CORS rule (the two exact Firebase origins, `GET`/`HEAD`), `nosniff` and no listing.
- [x] T044 [P] [US3] In `infra/firebase/firebase.json`, add the `^/r/[0-9a-f]{16}/.*$` immutable rule and add `release.json` and `drift_worker.js` (the shim) to the `no-cache` list. T032 passes.
- [x] T045 [US3] Rework `.github/workflows/pwa.yml` per `contracts/web-release.md`:
  - **On `master`:** build with `--pwa-strategy=none`, run `app/tool/stage_web_release.sh` with an empty mirror base, and deploy `build/web_release` to the `master` preview channel.
  - **On tag `web-v<semver>`** (validate the format):
    1. build once and stage with `MIRROR_BASE_URL` from `APP_ENV_PROD`;
    2. rsync `r/<hash>/` to `vps1:/srv/app-mirror/r/<hash>/` (never `--delete` at `r/`) and write `/srv/app-mirror/release-check.txt`;
    3. `curl` `main.dart.js` and its `.br` with `Origin: https://madar-sat.web.app` and check `200`, the immutable header and the CORS header;
    4. deploy to the **live** channel (`channelId: live`);
    5. prune mirror releases older than 30 days, keeping the newest 3.

    A failure in steps 2–3 stops before step 4.
- [ ] T046 [US3] Add a step to `.github/workflows/app.yml` that runs `node --test app/test_web/` with `actions/setup-node` (Node 22), after Lane M's T063 exists.

  **Waiting on Lane M.** `app/test_web/` is Lane M's T063; the step stays absent until it is on `master`.
- [x] T047 [US3] Point Kuma's `pwa-mirror` monitor at `https://app.<ip1>.sslip.io/release-check.txt` in `docs/runbooks/uptime-kuma.md` (owner updates the monitor). Write `docs/runbooks/pwa-release.md`, or extend `docs/runbooks/firebase-hosting.md` and replace its "arrives on D4" notes. It covers: tagging `web-v*`, what the job does, checking the mirror, rolling back the live channel from Firebase Hosting's release history, and pruning. Update `docs/runbooks/README.md`.

### Validation (B2)

- [ ] T048 [US3] After deploy, run quickstart B2 steps 4–6:
  - the mirror headers with `curl`, and no listing at `/r/`;
  - a push touching `admin/` deploys, and `readlink /srv/admin/current` names the SHA;
  - a deploy forced to fail before the swap leaves the previous SHA;
  - on the first `web-v*` tag (owner), the release job runs green, and a run with the mirror copy forced to fail stops before the live deploy (use `workflow_dispatch` on a throwaway tag).

  **After the merge.** None of these can run before the branch is deployed: the mirror has no `r/<hash>/` yet, `admin.yml`'s deploy job starts on `master`, and the first `web-v*` tag is the owner's. They are listed in `docs/owner-actions.md` under D4 Lane B2 "After merge".
- [x] T049 [US3] Add B2's D4 items to `docs/owner-actions.md`: `TRUSTED_PROXIES_PUBLIC` only if the default changes, the one-time network recreation, the Kuma monitor change, the backup heartbeat result from T030, and tagging `web-v0.1.0`, each with its runbook link.

### Review fixes (round 1)

From [reviews/b2-round-1.md](reviews/b2-round-1.md).

- [X] B2-R1-1 Make the `web-v*` release job readable past its mirror check in `.github/workflows/pwa.yml` (`:187`): the `release` job runs `jq … app/env/prod.json`, which exists only in the `build` job, so every release dies before the live deploy. Read the mirror from the artifact's `web_release/release.json` (`.mirror`) or a `build` job output, keep the `https://` check, and derive the `Origin` header from the Firebase project instead of hard-coding `madar-sat.web.app`. Prove it by running the step's script in a clean checkout with only the artifact present. (HIGH, per T045, FR-015, US3 AC6)
- [X] B2-R1-2 Stop the merge from breaking the admin site: only `bootstrap-vps.sh` creates `/srv/admin/releases/placeholder` and the `current` symlink, `infra/scripts/deploy.sh` doesn't check them, and the owner's D4 "Before merge" list doesn't say to re-run the bootstrap. So the Caddy reload serves 404, and `.github/workflows/admin.yml:95`'s `readlink` fails with a bare exit 1. Add a `deploy.sh` check that fails naming `sudo bootstrap-vps.sh vps1`, give the `readlink` an `::error::` with the same fix, and put the bootstrap re-run first in `docs/owner-actions.md` D4 B2 "Before merge" and in `docs/runbooks/README.md`'s setup order. Add the missing-`current` case to `infra.yml`'s checks. (HIGH, per FR-020, US4 AC1, infra/CLAUDE.md)
- [X] B2-R1-3 Put the admin `deploy` job (`.github/workflows/admin.yml:70-72`) and the PWA `release` job (`pwa.yml`) in `concurrency: deploy-vps1`. Give `.github/actions/vps1-sync` an input that skips the `infra/` rsync (`action.yml:62`) and use it in both jobs, so they don't overwrite `/srv/madar/infra/`. In `pwa.yml`, refuse a tag that isn't an ancestor of `origin/master`. Update `docs/runbooks/deploy-and-rollback.md:36`. Add an `infra.yml` check that every job using `vps1-sync` is in `deploy-vps1`. (HIGH, per constitution IX and deploy-and-rollback.md "deploys never overlap")

---

## Lane A

**Story (US4, P4):** as an editor, the admin works end to end on the real WireGuard host.

**Independent test:** see spec US4 and [quickstart A](quickstart.md#lane-a-admin).

### Setup (A)

- [x] T050 [US4] Confirm `pnpm build` output has no inline `<script>` or `style=` attributes that `default-src 'self'` would block: open `admin/dist/index.html` under the CSP with `pnpm preview` and see no console CSP errors. Fix any in `admin/src/` and note the result in the PR.
- [x] T051 [P] [US4] Add `@playwright/test` (pinned) as a devDependency, `admin/playwright.config.ts` and the `"e2e": "playwright test"` script in `admin/package.json`:
  - **`E2E_TARGET=mock` (default):** `webServer` starts `pnpm prism` and `pnpm dev`, with base URL `http://localhost:5173`.
  - **`E2E_TARGET=live`:** no `webServer`, base URL `E2E_BASE_URL`, and the internal CA comes from `NODE_EXTRA_CA_CERTS` (never `ignoreHTTPSErrors`).
  - Chromium only, retries 0, an HTML report to `admin/playwright-report/` (git-ignored).

### Tests first (A)

- [x] T052 [US4] Write `admin/e2e/smoke.spec.ts` per [contracts/e2e-smoke.md](contracts/e2e-smoke.md):
  1. log in;
  2. A3; in live mode, set the date input (`copy.pickDate`) to `E2E_MATCH_DATE` (default `2000-01-01`);
  3. find exactly one row whose stadium starts with `E2E_MATCH_MARKER`, or the first row in mock mode. Zero or more than one aborts before any edit;
  4. A4: set `stadium` to `<marker> <UTC timestamp>` and save. Expect the success toast and no conflict dialog, and assert the save request carried `If-Match`;
  5. live only: poll `GET ${E2E_PUBLIC_API}/v1/matches/<id>` every 5 s until `data.stadium` matches, failing after 60 s, and print the elapsed seconds.

  Credentials and the marker come only from the environment. See it fail before T053 if selectors are missing.
- [x] T053 [US4] Add any stable `data-testid` or accessible labels the test needs to A3's rows and A4's stadium field (`admin/src/features/matches/`), with no visual change. Keep the Vitest suite green. `pnpm e2e` (mock) passes locally.

### Polish and validation (A)

- [ ] T054 [P] [US4] Close the owner's D3 polish list (FR-023) once it is written in `docs/owner-actions.md`. Fix each item in `admin/src/` with a test, or move it to a named day with a reason. If the owner records "none", note that FR-023 is met.

  **Open:** the D3 polish list is still an owner to-do, so this task has nothing to close yet. It is
  recorded as the one before-merge owner item in [docs/owner-actions.md](../../docs/owner-actions.md#004-d4-mvp-launch);
  "none" is a valid answer.
- [ ] T055 [US4] After B2's T040 deploys, run the live smoke test from a WireGuard peer three times (quickstart A step 2), recording each edit-to-`/v1` time (≤ 60 s, SC-004). Clear the marker in A4 and see a live run abort before editing, then restore it. Document the live run in `docs/runbooks/admin-access.md`: the `E2E_*` variables, the test account, the test match, and never pointing it at another match.

  **Partly done:** the runbook section is written ([admin-access.md "The live smoke test (D4)"](../../docs/runbooks/admin-access.md#the-live-smoke-test-d4)).
  The three live runs wait on B2's T040 deploy and on the owner's account and test match.
- [ ] T056 [US4] On the deployed admin, take the screenshots carried from 002 T107 (`Matches.png`, `MatchEditor.png`, `Dialogs.png`) and 003 T106–T107 (`Main.png`, `Teams.png`, `Competitions.png`, `Satellites.png`, `Channels.png`, `Commentators.png`, `Sources.png`, `SourceRun.png`) at 1440 and 1024, and attach them to the PR.

  **Open:** needs the deployed admin (B2's T040); nothing here can be captured from the mock.
- [x] T057 [US4] Add Lane A's D4 items to `docs/owner-actions.md`: the polish list, the test account and test match, and the live smoke runs.

### Review fixes (round 1)

From [reviews/a-round-1.md](reviews/a-round-1.md).

- [X] A-R1-1 Fix the live finder in `admin/e2e/smoke.spec.ts` (`findMarkedMatch`, `:73-81`): it calls `stadium.isVisible()` without waiting while `MatchEditor` still shows `EditorSkeleton`, and `.catch(() => false)` hides errors. So every live row reads as unmarked and the run aborts with "found 0". Wait for the stadium field before reading it, let read errors fail the run, and add mock-mode `page.route` stubs proving that 0 and 2 marked rows abort with zero PATCH requests and 1 marked row is the one edited. (HIGH, per FR-022, US4 AC3, contracts/e2e-smoke.md step 3)
- [X] A-R1-2 Stop mock mode from editing a real match in `admin/e2e/smoke.spec.ts` and `admin/playwright.config.ts`: mock mode reads `E2E_EMAIL`/`E2E_PASSWORD`, edits `ids[0]` without a marker check, and locally reuses any server on :5173, which can be `pnpm dev:wg` proxying to the deployed API. In mock mode use only the Prism fixture credentials, reject an `E2E_TARGET` other than `mock` or `live`, and don't reuse a running dev server (or use a dedicated port). Also make missing live variables (`E2E_EMAIL`, `E2E_PASSWORD`, `E2E_PUBLIC_API`, a non-blank `E2E_MATCH_MARKER`) throw instead of skipping. (HIGH, per FR-022, the spec edge case "the Playwright test runs against production data")

---

## Lane M

**Story (US2, P2):** as a fan, I can install the public PWA and the Android test build without hitting a crash.

**Independent test:** see spec US2 and [quickstart M](quickstart.md#lane-m-app).

### Carry-over from 003 (M, first)

- [x] T060 [P] [US2] M-T045-1 (research R14): add a debug-only `SecurityContext` for the app's Dio that trusts the dev Caddy root from the file named by `--dart-define=DEV_CA_PATH`, guarded by `kReleaseMode` and `kIsWeb` (`app/lib/core/network/`). Write the test first: a release configuration ignores `DEV_CA_PATH`. Correct `docs/runbooks/local-dev.md:74-80`.
- [x] T061 [P] [US2] M-T045-2: route `ApiFailure` from `_conditional` (`app/lib/core/network/swr_repository.dart` around `:285-302`) and from the 304-with-no-cache path (around `:85`) into the stream as an error instead of throwing. Write the test first: a failing adapter with no cache gives one stream error and no uncaught error.
- [x] T062 [P] [US2] M-T045-3: in `app/lib/features/onboarding/presentation/steps/teams_step.dart:85-86`, check `hasError` before the skeleton branch and show the copy for the `ApiFailure.code` (`error_copy.dart`) with «إعادة المحاولة», which invalidates `team_search_provider`. Write the widget test first: a failing search shows the error state, and retry calls the provider again. Then tick M-T045-1/2/3 in `specs/003-d03-follow-push-sources/tasks.md`.

### Tests first (M): write them and see them fail

- [x] T063 [P] [US2] Write `app/test_web/sw_core.test.mjs` (`node:test`, no npm install) for `app/web/sw_core.mjs` (research R12). Cases:
  - a cached release request returns without a fetch;
  - a cache miss fetches the mirror URL first;
  - a mirror slower than the timeout (3 s, injectable) or failing falls back to the same path on the own origin;
  - a successful response is cached under `madar-r-<hash>`;
  - non-release requests are not intercepted by the release path;
  - navigations are network-first with the cached `index.html` as fallback;
  - activation deletes release caches other than the current and previous hash.
- [x] T064 [P] [US2] Write `app/test/core/web/release_layout_test.dart`, a Dart test over a fixture directory, for `app/tool/stage_web_release.sh` (research R11, `contracts/web-release.md`). Cases:
  - only shell files at the root;
  - every other file under `r/<hash>/`;
  - `release.json` holds the hash and the mirror;
  - the same input gives the same hash;
  - a missing shell file or a stray root file makes the script exit non-zero;
  - `.br` and `.gz` exist for each `r/` file.

### Implementation (M)

- [x] T065 [US2] Write `app/tool/stage_web_release.sh <env-file> <out-dir>` per research R11 and `contracts/web-release.md`:
  1. read `MIRROR_BASE_URL` (`https`, no path, empty allowed);
  2. remove any `flutter_service_worker.js`;
  3. compute the hash: the first 16 hex characters of the SHA-256 over sorted (path, SHA-256) pairs of the non-shell files;
  4. move the non-shell files to `r/<hash>/`, including `sqlite3.wasm` and the real `drift_worker.js`, and write the same-origin `drift_worker.js` shim at the root that `importScripts` `<base>/r/<hash>/drift_worker.js` (research R11);
  5. write `release.json` (`{"hash", "mirror", "built_at"}`, ISO-8601 UTC);
  6. stamp the hash and mirror into `flutter_bootstrap.js`, `sw.js` and the shim;
  7. precompress `r/**` to `.br` and `.gz`;
  8. reuse `tool/check_web_assets.sh`;
  9. print `RELEASE_HASH=<hash>` last.

  T064 passes. Add `MIRROR_BASE_URL` to `app/env/example.json` (the owner adds it to `APP_ENV_PROD`).
- [x] T066 [US2] Write `app/web/sw_core.mjs` (pure logic) and `app/web/sw.js` (event wiring) per research R12:
  - **`install`:** fetch `release.json` with `no-store`.
  - **`fetch`:** release paths go cache → mirror (3 s `AbortController`) → own origin; shell files and navigations are network-first with a cache fallback.
  - **`activate`:** `clients.claim()` and cache pruning.

  Leave `app/web/firebase-messaging-sw.js` unchanged on its own scope. T063 passes. Add `sw.js` and `release.json` to the list in `tool/check_web_assets.sh`.
- [x] T067 [US2] Write the custom `app/web/flutter_bootstrap.js` template (`{{flutter_js}}`, `{{flutter_build_config}}`):
  1. register `/sw.js`;
  2. never wait for it: if a worker already controls the page, load through it; on a first visit load straight from the mirror while the worker registers in the background, and if the entrypoint fails to load from the mirror, retry once with the own-origin base (research R11);
  3. set `window.MADAR_RELEASE = {base, hash}`, and make drift open `sqlite3.wasm` from `<base>/r/<hash>/sqlite3.wasm` read from it in `app/lib/core/db/app_database.dart:179` (web only, through the existing conditional import), falling back to `sqlite3.wasm` when absent. Write the test first (a Dart test of the URL helper with and without the value);
  4. call `_flutter.loader.load` with `config.entrypointBaseUrl`, `config.assetBase` and `config.canvasKitBaseUrl` set to `<mirror or ''>/r/<hash>/`, with the values stamped by T065.

  Keep `index.html`'s splash and the `flutter-first-frame` hook. Add `--pwa-strategy=none` to the canonical web build in `app/CLAUDE.md` if the flag exists on 3.47.7; otherwise note that the build emits no default worker. Add a debug-only `?perf=1` timing log (research R13) that the release build ignores without the query.
- [x] T068 [US2] Check the install row on S16 (`app/lib/features/more/presentation/more_page.dart:58-96`): it shows only on iOS Safari when not standalone, its label reads «تثبيت التطبيق» (fix the ARB key if it resolves to other copy), and it opens S1.5. Add a widget test if none covers the label (FR-036).

### Validation (M)

- [ ] T069 [US2] On the preview channel after B2's T045 (empty mirror base), run quickstart M steps 3–4:
  - the release layout on disk;
  - `sw.js` controlling the page;
  - release files served by the worker on reload;
  - offline open with the banner.

  Fix any issue with a test.
- [ ] T070 [US2] By 12:00, as soon as T060–T062 are merged and before T071, ask the owner to tag `app-v0.3.0` and confirm `app-release.yml` produces the signed AAB, then install it from the closed track. After the gate conditions in plan.md hold, ask the owner to tag `web-v0.1.0`.
- [ ] T071 [US2] Run [bug-bash.md](bug-bash.md) on the Android release build, the installed iPhone PWA (iOS ≥ 16.4) and desktop Chrome at 1440. Record the results in `specs/004-d04-mvp-launch/bug-bash-results.md` in the data-model format.
  - Fix every crash and blocker with a test, and re-run the step.
  - List cosmetic issues with a target day. If Lane M runs late, they move to D11 first (spec Assumptions).
- [ ] T072 [US2] On the live channel, run quickstart M step 5 and record the timings in `bug-bash-results.md`:
  - first data < 5 s on Fast 4G and < 1.5 s on a repeat open;
  - ≥ 90 % of first-load bytes from `app.<ip1>.sslip.io`;
  - with the mirror blocked and site data cleared, the PWA still loads.
- [x] T073 [US2] Update `docs/runbooks/firebase-hosting.md` / `pwa-release.md` (with B2) for the app side: the stage script, `MIRROR_BASE_URL`, the service worker, and how to check a release in DevTools. Add Lane M's D4 items to `docs/owner-actions.md`: `MIRROR_BASE_URL`, the tags, the device walks and announcing the public link.

### Status after implement (2026-11-03, opencode)

Lane M's code is in on `d04-m` in `../madar-m`, rebased on this branch.

- **Done locally:** T060–T062 (the dev CA behind `DEV_CA_PATH` for debug native builds, the SWR failure reaching the stream as its error, S1.2's error state with «إعادة المحاولة», and the three M-T045 ticks in `specs/003-d03-follow-push-sources/tasks.md`), T063–T068 (the hashed release layout and its stage script, the module-tested service worker, the custom bootstrap, drift's wasm URL from `window.MADAR_RELEASE`, and S16's «تثبيت التطبيق» row), T073 (the hosting runbook's layout and DevTools sections, and the D4 owner items).
- **Checked:** `flutter analyze` clean; the app suite **657 tests green** on the test box with **90.6 % line coverage excluding generated code**; `node --test app/test_web/` 12/12; a real `flutter build web` staged end to end (hash `5db26a4bd373e254`, 46.2 MB raw → 12.0 MB in brotli, one release hash referenced by the shell, `.br` and `.gz` beside every release file).
- **Not run here (a host, a console or a device is needed):** T069 (the preview channel), T070 (the `app-v0.3.0` tag), T071 (the bug bash — `bug-bash-results.md` is a template with "not run" per platform), T072 (the live timings).
- **For the other lanes:** `pwa.yml` must `apt-get install -y brotli` before staging (the script refuses to run without it), and `app.yml` still needs B2's T046 step for `node --test app/test_web/`. The spec's `data-model.md` layout does not list `sw_core.mjs` at the root (or that 3.47.7 emits `flutter_service_worker.js`/`flutter.js`, which the stage script deletes).

### Review fixes (round 1)

From [reviews/m-round-1.md](reviews/m-round-1.md).

- [X] M-R1-1 Make `app/web/sw.js` registrable: it starts with a static `import` from `./sw_core.mjs`, but `app/web/flutter_bootstrap.js:37` registers it as a classic worker (`register('/sw.js')`), which throws a SyntaxError. So no worker ever controls the page: no cached repeat open, no offline app, no release replacement. Either register with `{ type: 'module' }` (confirm iOS Safari ≥ 16.4 supports module service workers) or have `tool/stage_web_release.sh` emit a classic `sw.js` with the core inlined. Add a test under `app/test_web/` that loads `sw.js` the way it is registered, and log a registration failure without `?perf`. (HIGH, per FR-038, US2 AC9–11, T066)
- [X] M-R1-2 Make the bootstrap's mirror fallback real in `app/web/flutter_bootstrap.js` (`:43-64`): on Flutter 3.47.7, `_flutter.loader.load()` always passes a callback, injects the entrypoint `<script>` and resolves without waiting or rejecting (`flutter_js/src/entrypoint_loader.js:62-65, 118-128`), so a blocked mirror never reaches the `catch` and the splash never leaves. Detect the entrypoint failure yourself (an `error` listener on the injected script, or a probe, plus a timeout for a hung mirror), then load once from the own origin; the loader's `_scriptLoaded` guard means a second `load()` won't inject again. Add a node test that stubs `_flutter.loader` and a failing mirror and expects one own-origin load. (HIGH, per US2 AC10, FR-038, T067)

---

## Done check

Copied word for word from delivery-plan Appendix A, row 004:

> **MVP gate:** importers cover today to +3; admin edit visible in ≤ 60 s; reminders on both platforms; bug-bash script without crashes; no CRITICAL security findings; PWA first load < 5 s on 4G and < 1.5 s afterwards; PWA public

**Preconditions (owner, carried from 002/003):**
- 003 B1 T047: the FCM key on VPS-2 and a first real reminder;
- 002 B2 T086–T087: hosts and the first unattended run;
- 003 B2 T082–T084: the LiveSoccerTV run, the breaker and the Kuma drill;
- 003 B2 T083: the backup heartbeat, via this spec's T030;
- O7 decided.

- [ ] DC1 Importers cover today to +3: B2 T035 output (every slot unattended; coverage per day).
- [ ] DC2 Admin edit visible in ≤ 60 s: Lane A T055, 3 runs ≤ 60 s.
- [ ] DC3 Reminders on both platforms: bug-bash R1–R2 pass on the Android release build and the installed iPhone PWA.
- [ ] DC4 Bug-bash script without crashes: `bug-bash-results.md` shows 0 crashes and 0 open blockers on all three platforms.
- [ ] DC5 No CRITICAL security findings: `security-review.md` says "Gate: no open CRITICAL" and no HIGH is open without the owner's acceptance.
- [ ] DC6 PWA first load < 5 s on 4G and < 1.5 s afterwards: Lane M T072 timings.
- [ ] DC7 PWA public: `https://madar-sat.web.app` serves the `web-v0.1.0` release to anyone, and its files come from the mirror.
