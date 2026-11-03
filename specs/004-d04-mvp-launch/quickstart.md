# Quickstart: validating D4 · MVP launch

Each lane's steps prove its story; the last section is the MVP gate. Host commands use the `madar-vps1` / `madar-vps2` aliases and `dc` (= `docker compose -f /srv/madar/infra/compose/<host>.yml --env-file /srv/madar/.env`), as in `docs/runbooks/`.

## Prerequisites

- 003 merged and deployed (`docs/owner-actions.md` "Open now"). The FCM key is on VPS-2 (003 B1 T047).
- The owner has written the D3 admin polish list (or recorded "none").
- The owner has created the Playwright editor account and the test match (2000-01-01, stadium `MADAR-E2E`) ([e2e-smoke.md](contracts/e2e-smoke.md)).
- `MIRROR_BASE_URL` is in the `APP_ENV_PROD` secret ([web-release.md](contracts/web-release.md)).
- O7 is decided and recorded.

## Lane B1: client IP, load, security

1. **Client IP (R1).** After the deploy with `TRUSTED_PROXIES`, from two phones on different networks run `curl -s -o /dev/null -w '%{http_code}\n' https://api.<ip1>.sslip.io/v1/live` a few times each. On VPS-1, `dc exec redis redis-cli --scan --pattern 'rl:ip:*'` shows two keys with the phones' public IPs, not one gateway key.
2. **Unit and contract tests:** in `backend/`, `uv run pytest tests/api/test_ratelimit.py tests/auth/test_client_ip.py` passes, including the forged-hop and empty-allowlist cases.
3. **Load test.** Follow `docs/runbooks/load-testing.md`:
   1. confirm VPS-2's public IP in the access log;
   2. set `RATE_LIMIT_EXEMPT_IPS`, recreate `api-public`;
   3. run k6 on VPS-2;
   4. clear the value and recreate;
   5. a 700-request loop from VPS-2 now gets `429`s.

   The report in `docs/load-tests/` shows each FR-002 target as pass or fail.
4. **Security.** `security-review.md` lists every finding. There are 0 open CRITICAL and 0 open HIGH not accepted by the owner. `SR-1` (R1) is `fixed`. The host checks include `curl https://10.8.0.1` from the internet (no answer) and an empty `RATE_LIMIT_EXEMPT_IPS`.

## Lane B2: imports, mirror, release, admin deploy

0. **Backup heartbeat (FR-016):** on VPS-2, `systemctl list-timers 'backup-*'` shows the timers enabled; after `systemctl start backup-db.service`, Kuma's `backup-db` monitor turns green and `restic snapshots --tag db` lists the new snapshot; the next scheduled run reports too.
1. On VPS-2: `dc exec worker-imports python -m app.adapters.report runs --hours 48` exits 0 (every slot ran, none by hand), or every flagged slot is explained in the PR.
2. `… report coverage --days 4` lists each Cairo day from today to +3 with the prioritized competitions' matches and channel counts. Gaps are explained.
3. `uv run pytest tests/adapters` passes, including each new `edge-*` fixture, which failed before its fix.
4. **Mirror:**
   - `curl -sI -H 'Origin: https://madar-sat.web.app' -H 'Accept-Encoding: br' https://app.<ip1>.sslip.io/r/<hash>/main.dart.js` shows `200`, `cache-control: public, max-age=31536000, immutable`, `content-encoding: br`, `access-control-allow-origin: https://madar-sat.web.app` and `x-content-type-options: nosniff`.
   - `https://app.<ip1>.sslip.io/r/` returns no listing.
5. **Release:** a `web-v*` tag runs `pwa.yml`'s release job green (mirror copy, mirror check, live deploy, prune). A run with the mirror copy forced to fail stops before the live deploy.
6. **Admin deploy:** a push touching `admin/` deploys. `readlink /srv/admin/current` names the new SHA; `https://10.8.0.1/` serves it over WireGuard. A failed deploy leaves the previous SHA.
7. `docs/runbooks/on-call.md` exists, is linked from `docs/runbooks/README.md`, and each alert row leads to a command that works on the hosts.

## Lane A: admin

1. `pnpm e2e` (mock) passes locally and in `admin.yml`.
2. From a WireGuard peer:

   ```text
   E2E_TARGET=live E2E_BASE_URL=https://10.8.0.1 E2E_PUBLIC_API=https://api.<ip1>.sslip.io \
     E2E_EMAIL=… E2E_PASSWORD=… E2E_MATCH_MARKER=MADAR-E2E \
     NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt pnpm e2e
   ```

   This passes, reports the edit-to-`/v1` time, and changes only the test match's stadium. Run it 3 times; each time is ≤ 60 s (SC-004).
3. Delete the marker from the test match in A4. The live run aborts before editing anything.
4. Every polish-list item is closed or moved to a named day. Screenshots of 002 T107 and 003 T106–T107 are taken on the deployed admin.

## Lane M: app

1. Through `rtest`: the tests for M-T045-1 (a release build ignores the dev CA), M-T045-2 (a stream error, no uncaught error) and M-T045-3 (the error state with retry) pass.
2. `node --test app/test_web/` passes:
   - the cache hit returns without a network call;
   - a slow mirror (> 3 s) falls back to the own origin;
   - a failing mirror falls back;
   - activation keeps the current and previous release caches only.
3. Stage a release locally with `app/tool/stage_web_release.sh env/prod.json build/web_release`. Only shell files are at the root, `r/<hash>/` holds the rest, `release.json` matches the hash, and re-staging the same build gives the same hash.
4. **Preview channel** (empty mirror base): DevTools → Application shows `sw.js` controlling the page. A reload loads `r/<hash>/` files from the service worker. Offline, the app opens with its offline banner.
5. **Live** (after B2's release job):
   - **First load:** DevTools → Network with "Fast 4G" and cache disabled until the worker installs. `main.dart.js` and `canvaskit.wasm` come from `app.<ip1>.sslip.io`, and ≥ 90 % of bytes come from the mirror (SC-008a). First data appears in < 5 s.
   - **Repeat open:** < 1.5 s, with no release files over the network.
   - **Failover:** block `app.<ip1>.sslip.io` in DevTools, clear the site data, and reload: the PWA still loads, from Firebase.
6. **Bug bash:** run [bug-bash.md](bug-bash.md) on the Android release build (`app-v0.3.0` from the closed track), the installed iPhone PWA and desktop Chrome at 1440. Record the results in `bug-bash-results.md`: 0 crashes and 0 open blockers.
7. **Install guide:** on an iPhone in Safari, S16 → «تثبيت التطبيق» opens S1.5. On Android Chrome and desktop the row is hidden.

## Done check (spec SC-009)

> **MVP gate:** importers cover today to +3; admin edit visible in ≤ 60 s; reminders on both platforms; bug-bash script without crashes; no CRITICAL security findings; PWA first load < 5 s on 4G and < 1.5 s afterwards; PWA public

| Clause | Evidence |
|---|---|
| Importers cover today to +3 | B2 steps 1–2 |
| Admin edit visible in ≤ 60 s | Lane A step 2 (3 runs) |
| Reminders on both platforms | Bug-bash step R1 on the Android release build and the installed iPhone PWA |
| Bug-bash script without crashes | `bug-bash-results.md` |
| No CRITICAL security findings | `security-review.md` |
| PWA first load < 5 s on 4G and < 1.5 s afterwards | Lane M step 5, timing table in `bug-bash-results.md` |
| PWA public | `https://madar-sat.web.app` opens for anyone; the live channel shows the `web-v0.1.0` release |
