# Research: D4 · MVP launch

Each entry: **Decision**, **Rationale**, **Alternatives considered**. File references are to `master` at `acbfece`.

## Lane B1: load, security, client IP

### R1. The public API can't see the client's IP (launch blocker)

**Finding.** Public Caddy runs with `network_mode: host` and proxies `api.` to `127.0.0.1:8000` (`infra/Caddyfile:33`), the port Docker publishes for `api-public` (`infra/compose/vps1.yml:65`). Inside the container the peer is therefore the Docker bridge gateway, never `10.8.0.1`, so `client_ip()` (`backend/app/auth/limits.py:67`) ignores `X-Forwarded-For` and returns the gateway for every request. `api-public` also runs without `--forwarded-allow-ips` (`backend/Dockerfile:31`). As a result every anonymous request shares one bucket (`RATE_LIMIT_IP_PER_MIN=600` for the whole internet) and device registration is capped at 30 per 10 min for everyone (`rl:reg:{ip}`). This is a HIGH finding. B1 fixes it first, because the launch, the allowlist (R3) and the load test (R2) all depend on a correct client IP.

**Decision.**
- **B2:** give VPS-1's Compose network a fixed subnet and gateway (`172.30.0.0/24`, gateway `172.30.0.1`) so the peer Caddy's traffic arrives from is known and stable.
- **B1:** replace the single `TRUSTED_PROXY` constant with a setting `TRUSTED_PROXIES` (comma list, default `10.8.0.1`). The public app trusts `127.0.0.1` and `172.30.0.1` (from the host `.env`, set by B2's Compose file); the admin app keeps `10.8.0.1` only. `client_ip()` keeps its right-most-untrusted-hop rule.
- **Tests:** a request from the gateway with `X-Forwarded-For: <client>` gives `<client>`; a forged left-most hop is ignored; a request from any other peer ignores the header.
- **Verify on the host:** after deploy, two phones on different networks get separate buckets (quickstart B1 step 1).

**Rationale.** It is the smallest change that keeps the "trust Caddy only" rule (constitution V). Port 8000 is published on loopback only, so nothing outside the host can reach the API from the trusted gateway.

**Alternatives considered.**
- Running `api-public` with host networking: it needs a Compose change for both hosts and changes healthchecks and ports.
- A Unix socket between Caddy and gunicorn: it needs a shared volume and changes the deploy script.
- Trusting any private address: a container compromise could then forge client IPs.

### R2. The load tool and where it runs

**Decision.** k6 (`grafana/k6` image, pinned, arm64), run with `docker run --rm` on VPS-2 against `https://api.<ip1>.sslip.io`. The script is `backend/loadtest/mvp.js`, with rates, duration, host and the `If-None-Match` share as `-e` variables. Two scenarios use the `constant-arrival-rate` executor:
- `live`: 170 requests/s for 10 min. About half the requests send the previous `ETag`.
- `matches`: 50 requests/s for 10 min, spread over today to +3, plus 10 % match-detail reads.

k6 thresholds encode FR-002 with requests tagged by cache outcome (`p(95)<150` for cached reads and `p(95)<400` for uncached ones, on both endpoints, `http_req_failed<0.01`, and a `429` counted as failed via `responseCallback`). VPS-1 CPU and memory are sampled with `docker stats --no-stream` every 10 s over SSH during the run. The report goes to `docs/load-tests/2026-11-04-mvp.md`.

**Rationale.** k6 has a true open-model arrival-rate executor, so latency doesn't throttle the load, and it publishes an official arm64 image, so there is no install. VPS-2 is in the same region, so the result measures the API and Caddy, not the owner's home link.

**Alternatives considered.**
- Locust: closed-model by default, and Python workers on 1 OCPU skew the result.
- `hey` / `vegeta`: no mixed scenarios or thresholds.
- Running from the laptop: it measures the home uplink.

### R3. The rate-limit allowlist for the test window

**Decision.**
- **Setting:** `RATE_LIMIT_EXEMPT_IPS` (`Annotated[list[str], NoDecode]` with `_split_comma_list`, beside `settings.py:57-59`), empty by default.
- **Check:** `rate_limit()` returns early when `client_ip(request)` is in the set, right after the IP is derived (`backend/app/api/ratelimit.py:88`). Every exempt request logs `ratelimit.exempt` with the IP at debug level, and once a minute at info level.
- **Startup:** `/healthz` stays unaffected. The app logs a warning at startup when the list is non-empty.
- **Runbook:** `docs/runbooks/load-testing.md` sets the value in VPS-1's `.env`, recreates `api-public`, runs the test, clears the value and recreates again. Its last step is a `curl` loop that shows `429` returns.
- **Source IP:** VPS-2 → VPS-1's public IP leaves through OCI's internet gateway, so the API sees VPS-2's public IP. The runbook confirms this with one request and the access log before the run.

**Rationale.** It matches spec Clarification 2 and FR-007. It is env-driven, so nothing in git holds an IP, and it is visible in logs.

**Alternatives considered.** A header token for load tests: that is a secret in a header, and it bypasses limits wherever it leaks.

### R4. Meeting the targets on 1 OCPU

**Decision.** Run as deployed first.
- **If `/v1/live` misses p95 or CPU saturates:** first raise `api-public` to `-w 3` (memory allows it, `infra/README.md:42`); second, apply SD §11's fallback, Caddy answering `/v1/live` from a short-lived cache (the `cache-handler` plugin, which means a custom Caddy build). The second step is a B2 change and is taken only if the first fails, recorded in Complexity Tracking.
- **Matches reads:** they are already Redis-cached with versioned keys (`backend/app/api/cache.py:25`), so a miss there points at the DB path; B1 profiles with `EXPLAIN ANALYZE` on the matches-by-day query.

**Rationale.** The cache and `304` path should hold 170 requests/s on two workers. Measuring before tuning keeps the change small.

**Alternatives considered.** Pre-emptively adding the Caddy cache: it needs a custom Caddy image, which is extra build and supply-chain surface before any evidence it is needed.

### R5. The security review

**Decision.** Two passes, both recorded in `specs/004-d04-mvp-launch/security-review.md`:
- **Code:** the `security-reviewer` agent over the whole repository (not only the diff), driven by SD §8 and constitution V row by row.
- **Hosts:** a run of `docs/runbooks/exposure-check.md` plus header and CORS checks against each public host, the admin host from the internet, Postgres and Redis ports from the internet, and a gitleaks scan of the full history.

Each finding gets an ID (`SR-n`), severity, file or host, owner lane, status and fix commit. B1 adds other lanes' findings to their `tasks.md` sections as `SR-n` tasks by 12:00. R1 is pre-registered as `SR-1` (HIGH, B1 + B2).

**Rationale.** The gate is about the deployed system, so a code-only review would miss Caddy and firewall issues.

**Alternatives considered.** Built-in `/security-review` alone: it reviews the branch diff, not the existing code base.

## Lane B2: imports, mirror, release, admin deploy

### R6. Evidence of unattended imports

**Decision.** A read-only CLI, `python -m app.adapters.report`, run with `dc exec worker-imports` on VPS-2. It has two sub-commands:
- `runs --hours 48`: every scheduled slot from `backend/app/adapters/schedule.py` set against the `import_runs` rows, matched by `source` and `started_at` within the slot's window, flagging missing slots and manual triggers, with status and reason. `import_runs` has no trigger column; manual runs are the A13 «تشغيل الآن» and resume actions in `audit_log`, joined by source and time, so no migration is needed.
- `coverage --days 4`: per Cairo day from today to +3, the matches of competitions with a non-null `Competition.priority`, how many have at least one visible channel link, and the unmatched names from the last run logs.

Output is plain text tables, pasted into the PR and into the B2 runbook. The pure functions behind them are tested.

**Rationale.** It is repeatable by the owner (FR-012), adds no endpoint (FR-041), and lives in B2's folder.

**Alternatives considered.** An admin endpoint: that is a contract change on a no-contract day. Hand-written SQL in the runbook: it can drift from the schema.

**"Prioritized competitions".** There is no flag; `Competition.priority IS NOT NULL` is used (`backend/app/db/models.py:113`), as A6's drag order already sets it.

### R7. Parser edge cases

**Decision.**
- **Find:** list failed or `partial` runs over the last 5 days; their raw pages are in `/srv/raw/<source>/<day>/<run_id>/` (`backend/app/adapters/raw_store.py`).
- **Fix:** each distinct failure becomes a fixture under `backend/tests/fixtures/<source>/edge-<slug>.html.gz`, with a failing `parse` test first, then the fix.
- **Privacy:** fixtures are trimmed to the match block and checked for personal data (none expected; the pages are public fixture lists).

**Rationale.** It follows constitution VII, which keeps `parse` pure and tested on saved pages.

### R8. The PWA mirror on VPS-1

**Decision.**
- **Caddy:** the `app.` site already exists (`infra/Caddyfile:58-78`, root `/srv/app-mirror`).
  - Release folders are made immutable with `@release path /r/*`, beside the existing `.<hash>.` regex, so the R11 layout is covered.
  - `encode zstd gzip` is replaced by `file_server { precompressed br gzip }`, so 1 OCPU never compresses multi-megabyte wasm per request; R11 produces the `.br` and `.gz` files.
  - Directory listing stays off, as `file_server` without `browse` already does.
- **Firebase:** `firebase.json` gets the same immutable rule for `^/r/[0-9a-f]{16}/`.
- **Pruning:** releases older than 30 days are deleted, always keeping the newest 3 (resolves the spec's "pruned by age"). A step in the release workflow runs it after a successful copy.

**Rationale.** Most of the host side exists; the gaps are the release-path rule and precompression.

### R9. The test match for the smoke test

**Decision.**
- **Marker:** matches have no name field (A4's `MatchFields`), so the marker is a fixed prefix of the test match's `stadium`, from `E2E_MATCH_MARKER` (for example `MADAR-E2E`).
- **The match:** the owner creates it once in A4 on 2000-01-01 between two existing teams, with that stadium.
- **The test:** it opens A3, picks 2000-01-01 with the date input (`MatchesPage.tsx:246`), and finds the one row whose stadium starts with the marker. It sets `stadium` to `<marker> <run-id>` in A4, saves, and polls `GET /v1/matches/<id>` until `stadium` matches, failing after 60 s.
- **Why `stadium`:** it is editable in A4 (`FieldsSection.tsx:133`), top-level in public `MatchDetail`, and lockable, which is harmless on this match.

**Rationale.** The marker survives every run, because the prefix stays. The date keeps the match out of the app's date strip, and no fan follows it.

**Alternatives considered.** A test team: it would appear in S1.2's team search, where fans could follow it.

### R10. Deploying the admin bundle

**Decision.**
- **CI:** `admin.yml` gains a `deploy` job (B2), on `master` only, after `check`.
  - It downloads the `check` job's `dist` artifact and joins wg0 with `.github/actions/vps1-sync` (secrets `WG_CI_CONFIG`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`).
  - It rsyncs to `/srv/admin/releases/<sha>/`, then atomically repoints `/srv/admin/current` (`ln -sfn` to a temporary name + `mv -T`).
  - It checks `https://10.8.0.1/` returns the new `index.html`. If that check fails, it points `current` back at the previous release (read before the swap) and fails the job, as constitution IX requires of a failed health check. Only after a passing check does it prune to the last 5 releases.
- **Caddy:** the wg0 site's root becomes `/srv/admin/current`, a relative symlink inside the mounted directory.
- **Failure:** a failed rsync or check leaves `current` on the previous release (US4 scenario 1).
- **Bootstrap:** the placeholder from `bootstrap-vps.sh` moves to `releases/placeholder`.

**Rationale.** It reuses the existing deploy action and the SPA site that already serves `/srv/admin` (`infra/Caddyfile:83-108`). The symlink swap is atomic for Caddy.

**Alternatives considered.** rsync `--delete` straight into `/srv/admin`: a half-copied bundle would be served mid-deploy.

## Lane M: release build, service worker, bug bash

### R11. Hashed release layout

**Decision.**
- **Build:** `flutter build web --release --no-web-resources-cdn --pwa-strategy=none` (the flag disables Flutter's own `flutter_service_worker.js`; verify it on 3.47.7, and if it has been removed the build no longer emits that worker, which is the same result). Lane M's new `app/tool/stage_web_release.sh` then:
  1. computes `H` = the first 16 hex characters of the SHA-256 over the sorted list of (path, file hash) for every non-shell file;
  2. moves those files to `build/web_release/r/<H>/` (main.dart.js and its parts, `canvaskit/`, `assets/`, `version.json`);
  3. leaves the shell at the root: `index.html`, `flutter_bootstrap.js`, `manifest.json`, `sw.js`, `firebase-messaging-sw.js`, `firebase-config.js`, `favicon.png`, `icons/`, and a tiny same-origin `drift_worker.js` shim (browsers only run same-origin worker scripts) that `importScripts` the real worker from `<base>/r/<H>/drift_worker.js`. `sqlite3.wasm` and the real worker move into `r/<H>/`: together they are about 1.1 MB raw, which would otherwise come from Firebase on every first load, against SC-008a and the Spark quota. Drift opens the wasm from `<base>/r/<H>/sqlite3.wasm`, a URL the app reads from `window.MADAR_RELEASE` (set by the bootstrap), falling back to `sqlite3.wasm` when the value is absent (debug and tests). If the shim fails on the pinned drift version (checked on the preview channel), the real worker stays at the root as a fallback (about 100 KB gzipped from Firebase), and `sqlite3.wasm` still moves;
  4. writes `release.json` (`{"hash": H, "mirror": <MIRROR_BASE_URL or "">, "built_at": …}`) at the root;
  5. precompresses `r/<H>/**` to `.br` and `.gz`.
- **Bootstrap:** a custom `app/web/flutter_bootstrap.js` (Flutter's `{{flutter_js}}` and `{{flutter_build_config}}` template) reads the release values that the stage script substitutes. If `sw.js` already controls the page, it loads at once through the worker. On a first visit it registers `sw.js` without waiting for it (so the 5 s first-load budget isn't spent on worker start-up) and loads straight from the mirror; caching through the worker starts from the next open. If the entrypoint fails to load from the mirror (blocked or down), it retries once with the own-origin base, which gives first visits the Firebase fallback the worker gives later ones. It sets `window.MADAR_RELEASE = {base, hash}` for Dart (drift's wasm URL) and calls `_flutter.loader.load` with `entrypointBaseUrl`, `assetBase` and `canvasKitBaseUrl` set to `<base>/r/<H>/`, where `<base>` is the mirror, or `""` for the same origin.
- **Mirror base:** it comes from a new public key `MIRROR_BASE_URL` in `env/prod.json`. It is added to `app/env/example.json`, and the owner adds it to the `APP_ENV_PROD` secret. The preview channel leaves it empty, so preview builds run the same layout and worker on their own origin.

**Rationale.** Flutter can't rename CanvasKit or individual asset files, because they are loaded by fixed names from a base URL. A content-addressed release folder gives every app file an address that changes whenever its content can, which is what immutable caching needs. The cost is that each release re-downloads unchanged files such as CanvasKit, which is acceptable at MVP release frequency.

**Alternatives considered.**
- Per-file `name.<hash>.ext` renaming: it breaks Flutter's asset and CanvasKit loading.
- Keeping unhashed files with `no-cache`: every open revalidates every file against the Spark quota.

### R12. One service worker for files, FCM's worker for push

**Decision.** `app/web/sw.js` (scope `/`) handles fetches:
- **Release files** (any request whose path contains `/r/<H>/`, on the mirror or the own origin): cache first (`madar-r-<H>`), then the mirror with a 3 s `AbortController` timeout, then the same path on the own origin (Firebase). Successful responses are cached.
- **Shell files and navigations:** network first, falling back to the cache, so the installed app opens offline.
- **`activate`:** it calls `clients.claim()` and deletes release caches other than the current and previous hash.
- **Release discovery:** `install` fetches `release.json` (`no-store`) to learn `H`. A new `release.json` changes `sw.js`, because the stage script stamps `H` into it, so the browser installs the new worker on the next open.

The pure decision logic lives in `app/web/sw_core.mjs`, imported by `sw.js` (module worker, with a classic fallback build if needed). It chooses the source order, handles timeouts and fallback, and decides which caches to delete. It is tested with Node's built-in runner (`node --test app/test_web/`), which adds no dependency. B2 adds that step to `app.yml`.

`firebase-messaging-sw.js` stays as it is. FlutterFire's web `getToken` registers it itself under `/firebase-cloud-messaging-push-scope`, so it can't be merged into `sw.js` without forking the plugin; disjoint scopes are allowed. The spec's FR-038 records this.

**Rationale.** It follows SD §5.2's failover order, and is testable without a browser.

**Alternatives considered.** Workbox: it is a dependency and a build step for about 120 lines of logic.

### R13. First-load target on 4G

**Decision.**
- **Profile:** Chrome DevTools "Fast 4G" (about 9 Mbps down, 150 ms RTT) on desktop, plus a real Android phone on mobile data.
- **Measure:** time from navigation to the first S2 frame with data. That is the `flutter-first-frame` event plus the first `/v1/matches` response, logged with `performance.now()` from a debug-only `?perf=1` query that the release build ignores unless passed.
- **Budget levers, in order:** precompressed `.br` (R8), no font downloads (already bundled), and the `--tree-shake-icons` default.
- **Results:** recorded in `specs/004-d04-mvp-launch/bug-bash-results.md` with the release hash.

**Rationale.** It matches the gate's wording and is reproducible.

### R14. The three D3 carry-over fixes

- **M-T045-1:** a debug-only `SecurityContext` that adds the dev Caddy root from the file named by `--dart-define=DEV_CA_PATH`. It is guarded by `kReleaseMode` and `kIsWeb`, with a test that a release configuration ignores it. `docs/runbooks/local-dev.md:74-80` is corrected.
- **M-T045-2:** `_conditional` (`app/lib/core/network/swr_repository.dart` around `:285-302`) and the 304-with-no-cache path (`:85`) push their `ApiFailure` into the stream's error instead of throwing, with a failing-adapter test.
- **M-T045-3:** in `teams_step.dart:85-86`, check `hasError` before the skeleton branch and show the copy for `ApiFailure.code` with «إعادة المحاولة», which invalidates `team_search_provider`, with a widget test.

### R15. The bug-bash script

**Decision.**
- **Script:** written in the planning session as `specs/004-d04-mvp-launch/bug-bash.md`, so all three platforms run the same steps.
- **Results:** Lane M records them in `bug-bash-results.md` (platform, device, build or release hash, per-step pass, fail or n/a, issue link).
- **Triage:** a crash or blocker is fixed with a test; cosmetic issues are listed with a target day.

**Rationale.** The script is a spec artefact the owner reads anyway, and having it ready saves Lane M's morning.

## Owner decisions and inputs

- **O7:** the owner decides it today and records it in SD §3.2 and `docs/owner-actions.md`. No D4 code depends on it.
- **O6:** decided as Spark (spec Clarifications). The planning session updates `docs/system-design.md` §3.2 and R4, delivery-plan A3 and §6 (D9/D10 rows), and `docs/owner-actions.md` in the spec PR.
- **New owner inputs:**
  - `MIRROR_BASE_URL` in `APP_ENV_PROD`;
  - `TRUSTED_PROXIES` in VPS-1's `.env` (B2 documents the value);
  - the Playwright test account, the test match, and `E2E_*` values on the owner's WireGuard peer;
  - the D3 polish list;
  - tagging `web-v0.1.0` and `app-v0.3.0`.
