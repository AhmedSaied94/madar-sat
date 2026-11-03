# Contract: settings, deploys and CI steps between lanes

## Client IP and the allowlist (B1 ↔ B2)

| Item | Owner | Contract |
|---|---|---|
| `TRUSTED_PROXIES` setting and `client_ip()` | B1 | Comma list, default `10.8.0.1`. Peer in list → right-most `X-Forwarded-For` hop not in list; else the peer (data-model.md) |
| VPS-1 Compose network subnet `172.30.0.0/24`, gateway `172.30.0.1` | B2 | Fixed in `infra/compose/vps1.yml`. `api-public` gets `TRUSTED_PROXIES: ${TRUSTED_PROXIES_PUBLIC:-127.0.0.1,172.30.0.1}` and `--forwarded-allow-ips` with the same value, so uvicorn agrees |
| `RATE_LIMIT_EXEMPT_IPS` | B1 (code), owner (value) | Empty by default. Passed to `api-public` from `.env` as `${RATE_LIMIT_EXEMPT_IPS:-}`. B2 adds the pass-through line |
| Verification | B1 + B2 | After deploy, two clients on different networks hit separate `rl:ip:*` keys (quickstart B1 step 1) |

## Admin deploy (Lane A ↔ B2)

| Item | Owner | Contract |
|---|---|---|
| `pnpm build` → `admin/dist/` | A | Static, no inline scripts or styles (CSP `default-src 'self'`), base `/` |
| `admin.yml` `deploy` job | B2 | On `master` after `check`: download the `dist` artifact; vps1-sync; rsync → `/srv/admin/releases/$GITHUB_SHA/`; `ln -sfn releases/$SHA current.new && mv -T current.new current`; `curl --cacert` the internal CA against `https://10.8.0.1/` over wg0 and compare the `index.html` asset hash; **on a failed check, repoint `current` to the release it named before the swap and fail the job** (constitution IX); only after a pass, keep the newest 5 + `placeholder` |
| Caddy wg0 site | B2 | `root * /srv/admin/current`; everything else unchanged (`infra/Caddyfile:83-108`) |
| `bootstrap-vps.sh` | B2 | Creates `/srv/admin/releases/placeholder/` and a `current` symlink to it |

## Playwright in CI (Lane A ↔ B2)

| Item | Owner | Contract |
|---|---|---|
| `admin/playwright.config.ts`, `admin/e2e/`, the `pnpm e2e` script | A | `E2E_TARGET=mock` (default) starts `pnpm prism` + `pnpm dev` through `webServer`; `E2E_TARGET=live` uses `E2E_BASE_URL` and needs the `E2E_*` values in [e2e-smoke.md](e2e-smoke.md) |
| `admin.yml` step | B2 | After `build`: `pnpm exec playwright install --with-deps chromium`, then `pnpm e2e`; upload `admin/playwright-report/` on failure |

## Service-worker tests (Lane M ↔ B2)

`app.yml` runs `node --test app/test_web/` with `actions/setup-node` (Node 22). Lane M owns the tests; B2 owns the step.

## Import report CLI (B2)

`python -m app.adapters.report runs --hours 48` and `… coverage --days 4`, run on VPS-2 with `docker compose exec worker-imports`. The formats are in data-model.md. It is read-only and opens no network connections except to the database.

## Load test (B1, uses B2's hosts)

`docker run --rm -i grafana/k6:<pinned> run -e HOST=… -e LIVE_RPS=170 -e MATCHES_RPS=50 -e DURATION=10m - < backend/loadtest/mvp.js` on VPS-2. The full runbook is `docs/runbooks/load-testing.md` (B1), including filling and clearing `RATE_LIMIT_EXEMPT_IPS`.
