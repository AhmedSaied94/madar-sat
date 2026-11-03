# D4 security review (T010–T012)

Whole repository at `master` `614ff5f`, plus the live hosts, on 2026-11-03.

- **Repo (T010, T011):** a static read of `backend/app`, `infra`, `.github`, `app/web`, `admin/src` and the key `app/lib` files. Secrets were checked with `git grep` and the pickaxe over the tracked files and history, and with gitleaks v8.30.1 and `.gitleaks.toml` over all 131 commits (no leaks).
- **Hosts (T012):** checked from outside.

**Gate: no open CRITICAL.** There is no HIGH finding either.
- SR-2 is MEDIUM. It becomes HIGH if the owner doesn't accept it, so the owner decides it before the PWA is announced.
- No dependency or CVE audit was run (SR-12).

## Findings

| ID | Severity | Where (file or host) | Owner lane | Finding | Status | Fix |
|---|---|---|---|---|---|---|
| SR-1 | HIGH | `infra/compose/vps1.yml`, `backend/app/auth/limits.py` | B1, B2 | Behind Docker every client looked like the bridge gateway, so all users shared one rate-limit bucket (R1) | fixed (`1f1704b`) | Fixed subnet `172.30.0.0/24`. `TRUSTED_PROXIES` = `127.0.0.1,172.30.0.1`; take the right-most untrusted hop. Live check T008: two clients gave two `rl:ip:` keys (`104.28.228.70`, `130.110.97.25`) |
| SR-2 | MEDIUM (HIGH unless accepted) | `app/web/flutter_bootstrap.js:37-123`, `app/web/sw_core.mjs:113-130`, `app/tool/stage_web_release.sh:124-138`, `app/lib/core/db/release_assets.dart:22-24` | M, B2 | `main.dart.js`, CanvasKit and the wasm files run in the `web.app` origin, loaded from the mirror. Nothing checks their bytes: the hash is only the folder name. Whoever controls VPS-1's `/srv/app-mirror` or the `sslip.io` name serves code to every new PWA user, and the service worker caches it until the next release | open | Put SHA-256 digests in `release.json` (served from Firebase). Verify them in the bootstrap and in `sw_core` before `cache.put`. See also SR-11 |
| SR-3 | MEDIUM | `infra/Caddyfile:30-34`, `backend/app/schemas/public.py:530-534` | B2, B1 | The public API has no request-body cap, and FastAPI parses the body before the rate limiter or device auth run. Large JSON on `POST /v1/devices` or `PUT /v1/devices/me/follows` costs memory and CPU on the single core | open | Caddy `request_body { max_size 64KB }` on the api site; `Field(max_length=…)` on every `FollowSet` list |
| SR-4 | MEDIUM | `backend/app/api/etag.py:30-52`, `backend/app/api/cache.py:82-113`, `infra/compose/vps1.yml:237` | B1 | The response-cache key hashes every query parameter, undeclared ones included. Junk parameters fill Redis (`volatile-lru`), which evicts rate-limit counters, `dv:` entries, `auth:lock` and `lock:*` keys, and every such request also reaches Postgres | open | Build the key from the route's declared parameters only, and answer 422 to unknown ones |
| SR-5 | MEDIUM | `backend/app/api/ratelimit.py:121-133`, `backend/app/devices/service.py:133-154` | B1 | A request with a live device token skips the per-IP bucket. One IP can register about 4,300 devices a day (30 per 10 min), each with its own 120/min bucket, and devices are never pruned | open | Add an aggregate per-IP ceiling for token-bearing requests; prune devices not seen for 90+ days |
| SR-6 | MEDIUM | `infra/compose/vps1.yml:13`, `infra/compose/vps2.yml:15` | B2 | Every container gets the whole host `.env`, so `api-public` and `worker-scrape` hold `ADMIN_JWT_SECRET`, the backup keys and the database passwords. Code execution in the public API could forge admin JWTs and reach `api-admin` on the same bridge | open | Give each service only the variables it needs (`environment:` lists or separate env files); put `api-admin` on its own network |
| SR-7 | MEDIUM | `infra/compose/example.env:32-35`, `infra/redis/users.acl.tmpl:14` | B1, B2 | One Postgres superuser and the Redis `default` user (`+@all`) serve every service | open | Separate roles per app (`madar_public`, `madar_admin`, `madar_worker`, `madar_migrate`) and per-app Redis ACL users |
| SR-8 | MEDIUM | `admin/index.html:5`, `infra/Caddyfile:106` | A, B2 | The admin CSP `default-src 'self'` blocked every crest, logo and audio file from the media host (A-R1-8). The owner reported it on the deployed admin | open (fix on branch `fix/admin-session-restore-and-media-csp`) | `img-src` and `media-src` for the media host only, with a constitution amendment (1.2.0) and SD §8 |
| SR-9 | MEDIUM (unverified) | `infra/compose/vps1.yml:98-115`, `backend/app/auth/limits.py:65-88` | B1, B2 | `api-admin` probably sees the Docker gateway as its peer, not `10.8.0.1` (B2-R1-28). If so, the login lockout is per account rather than per account+IP, and any WireGuard peer can lock an editor out with 5 bad attempts | open | Owner check: one wrong login on `https://10.8.0.1`, then `redis-cli --scan --pattern 'auth:fail:*'`. If the suffix is `172.30.0.1`, trust it for `api-admin` and change the `infra.yml` guard |
| SR-10 | MEDIUM | `.github/actions/vps1-sync/action.yml`, `infra/scripts/bootstrap-vps.sh:157-163` | B2 | Deploy secrets (WireGuard plus SSH as `deploy`, effectively root) are available to any workflow on any branch; `master` is unprotected | accepted (owner, `deploy-and-rollback.md`: single-owner repo) | Keep write access to the owner only. Restrict the CI key in `authorized_keys` (`restrict,command=`) |
| SR-11 | LOW | `infra/firebase/firebase.json` | B2 | The PWA host sends no `nosniff`, Referrer-Policy, `frame-ancestors` or CSP (also seen live in T012) | open | Add the headers, and a CSP naming the mirror, gstatic, the API and media |
| SR-12 | LOW | `.github/`, `backend/Dockerfile:4,14`, `infra/compose/vps2.yml:96` | B2 | No dependency or image scanning; base images and Uptime Kuma use floating tags | open | Dependabot (pip, npm, actions, docker), and pin images by digest |
| SR-13 | LOW | `backend/app/schemas/public.py:530-534` | B1 | `FollowSet` ids have no upper bound: `2**70` makes asyncpg raise and the API answers 500 instead of 422 | open | `ge=1, le=2**63-1` on the ids, as `satellite_ids` already has |
| SR-14 | LOW | `backend/app/auth/limits.py:104-107`, `backend/app/api/admin/auth.py:207-214` | B1, B2 | The login limiter keys on (email, IP) only, and argon2 takes 64 MiB per attempt with no concurrency cap. A WireGuard peer cycling emails can use about 2.5 GiB | open | A per-IP cap across emails, a semaphore around argon2, and `mem_limit` on `api-admin` |
| SR-15 | LOW | `backend/app/settings.py:84-97` | B1 | An IP can be both exempt and trusted (B1-R1-8). That's a configuration hazard, not a remote bypass | open | Reject the overlap in the settings validator |
| SR-16 | LOW | `backend/app/devices/service.py:133-154` | B1 | `install_id` is stored in clear and re-registers a device without its old token, so a database read can mint tokens | open | Store a hash of `install_id`, or require the old token to rotate |
| SR-17 | LOW | `backend/app/adapters/fetcher.py:162-215`, `backend/app/media/fetch.py:25-41` | B2, B1 | The fetchers check only the host: no https or port rule, and no total deadline (B2-R1-31) | open | Require https on 443 and a total deadline |
| SR-18 | LOW | `infra/firewall/vps1.rules:29-55` | B2 | WireGuard peers have no per-peer ACL: the home box and the CI peer can reach 22, 443 and 8001 | open | Limit 22, 443 and 8001 to the owner's peers |
| SR-19 | LOW (unverified) | host `.env`, `backend/app/adapters/satair_bridge.py` | B2, owner | The old Sat Air R2 bucket and Firestore are trusted import sources, and the old app exposed their keys | open | Owner: rotate or lock the old R2 keys and the Firestore rules |
| SR-20 | LOW | `infra/scripts/deploy.sh:160` | B2 | The Redis password is passed on the `docker exec` command line, so it shows in the process list (B2-R2-23) | open | Pass it through a file or stdin |
| SR-21 | LOW | `backend/app/media/encode.py:111-114`, `infra/compose/vps1.yml:134` | B1, B2 | A 40 MP image can exceed `worker-media`'s 256 MB limit and loop on retries | open | Lower the cap to about 4 MP, or use Pillow draft mode |
| SR-22 | LOW | `media.<ip>.sslip.io` (host) | B2 | Caddy's own 404 on the media site still sends `server: Caddy` | open | Strip `Server` on that error path too |
| SR-23 | — | VPS-1, VPS-2 (host) | B2 | Repo review: public SSH might still be open (`bootstrap-vps.sh:307-329`) | false positive (T012: only 80 and 443 answer on VPS-1, nothing on VPS-2) | — |

## Host review (T012), 2026-11-03

From the owner's laptop (WARP), with WireGuard up.

| Check | Result |
|---|---|
| Open ports | VPS-1: 80 and 443 only. VPS-2: none |
| TLS | Let's Encrypt, valid until 2027-01-27. `http` → `https` 308 |
| Headers (api, media, app) | HSTS, `nosniff`, Referrer-Policy, no `Server` (except SR-22) |
| CORS | Only the PWA origins. api and media also accept preview channels (a D1 carry-over); the app mirror refuses them |
| Admin off the public listener | The admin host returns nothing on the public IP; `/admin/api` on the api host is 404 |
| Allowlist | Empty before and after the load window (closed 2026-11-03T19:31:59Z; 700-request check: 600 × `200`, 100 × `429`) |
| Secrets in history | gitleaks v8.30.1, 131 commits: no leaks |
| Not done | The off-WireGuard check of `https://10.8.0.1` (owner, with WireGuard down) |

## SD §8 and constitution V, row by row

Clean except where a finding is noted:
- Secrets in clients or the repo: clean.
- Admin not public: clean (SR-9, SR-18).
- Authentication and authorization: clean.
- Input validation (SR-3, SR-13).
- SQL injection: clean; every `text()` is a constant with bound parameters.
- XSS: clean in code (SR-8, SR-11).
- CSRF: clean.
- Rate limiting (SR-4, SR-5, SR-9, SR-15).
- CORS: clean.
- SSRF (SR-17).
- Uploads: clean.
- Transport and headers (SR-11, SR-22).
- Data at rest (SR-7).
- Privacy (SR-16).
- Push audience: clean.
- CI/CD (SR-10, SR-12).
