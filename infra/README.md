# infra/: servers, network and deploys (Lane B2)

Three hosts: two OCI Always Free Ampere A1 VMs (arm64) for the API and the workers, and the owner's
x86-64 home box for the scrape worker. Docker Compose, Caddy and WireGuard. No Kubernetes, no CDN,
$0/month (constitution IX). Every VPS image is `linux/arm64`; only the home box runs `linux/amd64`.

**No key, password, token or certificate is ever committed.** Real values live only in each host's `/srv/madar/.env` (mode 600, owner `deploy`) and in GitHub Actions secrets. The repo holds templates and fake placeholders only, and `gitleaks.yml` fails any PR that adds a secret.

## Layout

| Path | What it is |
| --- | --- |
| `compose/vps1.yml` | VPS-1: `caddy`, `api-public`, `api-admin`, `worker-media`, `postgres`, `redis` (ACL file), plus `migrate` and `cli` (profile `tools`) and the one-shot `backup-media` / `backup-media-weekly` (profile `backup`) |
| `compose/vps2.yml` | VPS-2: `worker-imports`, `worker-scrape`, `worker-maintenance`, `worker-notify` (the only service that mounts `/srv/secrets`), `worker-live`, the single `beat` and `uptime-kuma`, all under profile `workers`; `flower` stays down, and `backup-db` is a one-shot (profile `backup`) |
| `compose/home-box.yml` | The owner's x86-64 box: one `worker-scrape` on `scrape_home`, from `madar-backend-amd64:stable`, with no database credentials |
| `compose/dev.yml` | Local development: PostgreSQL 16, Redis 7 and a `tls internal` Caddy at `https://localhost:8443` |
| `compose/example.env` | Every variable name the Compose files, Caddyfile and scripts use, with fake values |
| `redis/users.acl.tmpl` | The `default` and `homebox` Redis users; `scripts/render-redis-acl.sh` renders it with the two passwords (file 640, directory 750, group 999) |
| `Caddyfile` | The public sites `api.`, `media.` and `app.130.110.117.215.sslip.io`, and two `wg0`-only sites: the admin at `https://10.8.0.1` and Uptime Kuma at `https://kuma.10-8-0-1.sslip.io` |
| `firewall/vps1.rules`, `vps2.rules`, `rules.v6` | iptables templates, rendered into `/etc/iptables/rules.v4` and `rules.v6` |
| `wireguard/wg0.conf.tmpl`, `peer.conf.tmpl` | The hub and peer configs, with key placeholders only |
| `scripts/bootstrap-vps.sh` | Idempotent host setup (Docker, WireGuard, the `deploy` user, `/srv` folders, the backup timers, firewall) |
| `scripts/check-firewall.sh` | Prints the active and persisted rules, fails if they differ, and checks the Redis rules |
| `scripts/render-redis-acl.sh` | Renders `redis/users.acl.tmpl` into `/srv/madar/redis/users.acl` (640, directory 750, group 999) and keeps the previous file; `--check` proves the modes (B2-R2-1, B2-R2-11) |
| `scripts/check-redis-acl.sh` | CI: renders through `render-redis-acl.sh`, refuses a 700 directory, boots `redis:7.4.12` as uid 999 and rotates the password once |
| `scripts/check-backup-retention.sh` | CI: runs the real backup scripts against local restic repositories — an empty one is created, and 7/4 retention prunes (B2-R1-3, B2-R1-5) |
| `scripts/check-backup-permissions.sh` | CI: reads the rendered Compose files for each backup service's uid and capabilities, then proves them on a host-shaped tree (B2-R1-2) |
| `scripts/check-doc-commands.sh` | CI: the FCM key install is one root command in `push-notifications.md`, `secrets.md` and `owner-actions.md` (B2-R1-7) |
| `scripts/wg-add-peer.sh` | Adds a WireGuard peer; generates its keys on the host |
| `scripts/deploy.sh` | Runs on VPS-1 (APIs and `worker-media`) or on VPS-2 (`--host vps2`: workers and `beat`): pull, roll out, health-check, roll back |
| `scripts/home-box-update.sh`, `.service`, `.timer` | Pull `madar-backend-amd64:stable` on the home box every 10 minutes and recreate the worker if it moved |
| `backup/` | The `madar-backup` image (`Dockerfile`: postgres client 16, restic, rclone) and the two scripts the timers run |
| `systemd/` | The three backup timers and their services (database nightly on VPS-2, media nightly and weekly on VPS-1) |
| `firebase/` | Firebase Hosting config for the PWA preview channel |
| `admin-placeholder/index.html` | Served on `https://10.8.0.1` until the admin ships (D4) |

## Hosts (SD §7.1)

| | VPS-1 "app" (public) | VPS-2 "workers" | Home box (x86-64) |
| --- | --- | --- | --- |
| Runs | Caddy, `api-public`, `api-admin`, `worker-media`, PostgreSQL 16, Redis 7, the media backup timer | `worker-imports`, `worker-scrape`, `worker-maintenance`, `worker-notify`, `worker-live`, `beat` (exactly one), Uptime Kuma, the database backup timer; Flower off | `worker-scrape -Q scrape_home`, and a 10-minute systemd timer that updates it |
| Memory | PostgreSQL ≈ 2 GB (`shared_buffers` 1.5 GB), Redis 512 MB, APIs 0.5 GB, `worker-media` ≤ 256 MB | Workers ≈ 1.2 GB, Flower 0.1 GB | The owner's machine; one worker process |
| Disk | Database, `/srv/media`, `/srv/app-mirror` | Raw pages `/srv/raw` (5 days), backup staging | None; it holds no data |
| Reaches | The internet, both VCN peers, `wg0` peers | VPS-1's VCN addresses only | `10.8.0.1:6379` only, as the `homebox` Redis user |
| Database | local | VPS-1's VCN IP | **none** |

## Hostnames and ports (SD §7.2)

| Name | Served by | Upstream |
| --- | --- | --- |
| `api.130.110.117.215.sslip.io` | Caddy, Let's Encrypt | `api-public` on `127.0.0.1:8000` |
| `media.130.110.117.215.sslip.io` | Caddy, Let's Encrypt | `/srv/media`, `immutable`; CORS `GET`/`HEAD` only to the PWA origins, preview channels included (constitution V) |
| `app.130.110.117.215.sslip.io` | Caddy, Let's Encrypt | `/srv/app-mirror` (PWA file mirror), CORS `GET` from the two PWA origins |
| `<project>.web.app` | Firebase Hosting | The PWA shell (`pwa.yml`) |
| `https://10.8.0.1` (`wg0` only) | Caddy, `tls internal` | `/admin/api/*` → `api-admin` on `10.8.0.1:8001`; everything else → `/srv/admin` |

| Port | VPS-1 | VPS-2 | Home box |
| --- | --- | --- | --- |
| 80/tcp, 443/tcp | Public | Closed | n/a |
| 51820/udp | Public (WireGuard hub `10.8.0.1/24`) | Closed | outbound |
| 22/tcp | `wg0` only | From VPS-1's VCN IP only | n/a |
| 5432, 6379 | Published on VPS-1's VCN IP, allowed from VPS-2 only; Redis is also published on `10.8.0.1:6379` and allowed from `HOME_BOX_WG_IP` only | n/a | n/a |

Docker-published ports skip the `INPUT` chain, so each one is bound to a specific address (`127.0.0.1`, `10.8.0.1` or the VCN IP), and the `DOCKER-USER` rules in `firewall/vps1.rules` limit who can reach them ([R12](../specs/001-d01-foundation/research.md#r12-hosts-networking-and-docker), [D2 R21](../specs/002-d02-core-flows/research.md#r21-the-x86-64-home-box)).

## GitHub configuration

**Secrets:**

| Secret | Value |
| --- | --- |
| `WG_CI_CONFIG` | The CI peer's WireGuard client config (`wg-add-peer.sh ci` on VPS-1) |
| `DEPLOY_SSH_KEY` | The private half of the `deploy` user's SSH key (ed25519), used only by CI; authorised on **both** VPS-1 and VPS-2 |
| `DEPLOY_KNOWN_HOSTS` | VPS-1's host key line for `10.8.0.1` **and** VPS-2's host key line, for the ProxyJump |
| `FIREBASE_SERVICE_ACCOUNT` | The JSON key of the Hosting deploy service account; its roles are in [firebase-hosting.md](../docs/runbooks/firebase-hosting.md#2-service-account-and-key) |

**Variables:**

| Variable | Value |
| --- | --- |
| `VPS1_IP` | VPS-1's reserved public IP (it is part of every `sslip.io` name) |
| `VPS2_IP` | VPS-2's reserved public IP |
| `VPS2_VCN_IP` | VPS-2's private VCN address; the `deploy-vps2` job reaches SSH there through VPS-1 |
| `ARM_RUNNER` | Optional: the label of a native arm64 runner. When it is empty, `backend.yml` builds with buildx + QEMU on `ubuntu-24.04` |

`backend.yml` pushes to `ghcr.io/<owner>/madar-backend` (arm64) and `ghcr.io/<owner>/madar-backend-amd64` (the home box) with the job's `GITHUB_TOKEN`. After the first push, open each package's settings, and under "Manage Actions access" give this repository the **Admin** role. The `retention` job then has the rights to delete old versions of both.

## Host `.env` (`/srv/madar/.env`, mode 600, owner `deploy`)

Names only; the values are in `compose/example.env` as fakes. Use URL-safe passwords (for example `openssl rand -hex 32`), because some of them are part of connection URLs. Write one `KEY=value` per line, with no quotes and no trailing comments.

| Group | Variables |
| --- | --- |
| Compose | `GHCR_OWNER` (lowercase), `VCN_IP` (this host's VCN private IP). `IMAGE_TAG` and `HEALTHZ_FORCE_FAIL` are set by `deploy.sh`, not in the file; the backup services take `BACKUP_IMAGE_TAG`, which defaults to the moving `stable` |
| Host and network | `VPS1_IP`, `PEER_VCN_IP` (the other host's VCN IP), `ACME_EMAIL`, `FIREBASE_PROJECT_ID`, `DEPLOY_SSH_PUBLIC_KEY`, `HOME_BOX_WG_IP` (VPS-1 only: the home box on `wg0`) |
| PostgreSQL and Redis | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `REDIS_PASSWORD`, `REDIS_HOMEBOX_PASSWORD` |
| Backend (`backend/app/settings.py`) | `DATABASE_URL`, `DATABASE_URL_SYNC`, `REDIS_URL`, `MEDIA_BASE_URL`, `MEDIA_ROOT`, `MEDIA_REHOST_ALLOWED_HOSTS`, `CORS_ORIGINS`, `CONTRACT_VERSION`, `ADMIN_JWT_SECRET` |
| VPS-2 | `CELERY_BROKER_URL`, `FLOWER_BASIC_AUTH`; `DATABASE_URL`, `DATABASE_URL_SYNC` and `REDIS_URL` point at VPS-1's VCN IP |
| Lane B2's adapters (`backend/app/adapters/config.py`) | `SATAIR_FIREBASE_PROJECT_ID`, `SATAIR_FIREBASE_API_KEY`, `SCRAPE_USER_AGENT`, `YSSCORES_FETCH_QUEUE`, `LIVESOCCERTV_FETCH_QUEUE`, `LIVESOCCERTV_COUNTRIES`, `SOURCE_BREAKER_THRESHOLD`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `RAW_ROOT` |
| D3 notifications (VPS-2) | `FCM_CREDENTIALS_FILE`, `FCM_DRY_RUN`, `PWA_ORIGIN` |
| D3 backups and Kuma | `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`, `BACKUP_STAGING`, `RCLONE_CONFIG_OCI_*`, `RCLONE_BUCKET` (VPS-1), the `KUMA_PUSH_URL_*` values (VPS-2 keeps `_MAINTENANCE`, `_IMPORTS`, `_NOTIFICATIONS`, `_LIVE`, `_SCRAPE_HOME`, `_BACKUP_DB`; VPS-1 keeps `_BACKUP_MEDIA`, `_BACKUP_MEDIA_WEEKLY`) |
| Home box only | `GHCR_OWNER`, `REDIS_URL=redis://homebox:<password>@10.8.0.1:6379/0`, `SCRAPE_USER_AGENT`, `GHCR_READ_TOKEN` (a read-only packages token). **No database URL** |

`MADAR_ENV_FILE` exists only in `example.env`, so CI and the scripts can validate the Compose files without a host. Never set it on a host.

## Procedures

The step-by-step procedures are runbooks in [`docs/runbooks/`](../docs/runbooks/README.md), which also gives the first-time setup order:

| To | Runbook |
| --- | --- |
| Create and bootstrap a host (`bootstrap-vps.sh`, `.env`, closing public SSH, the deploy key) | [provision-host.md](../docs/runbooks/provision-host.md) |
| Check the scrape box: join it, its `.env`, the timer, take it offline | [home-box.md](../docs/runbooks/home-box.md) |
| Add or remove a WireGuard peer, reach the admin site, trust its CA root | [private-network.md](../docs/runbooks/private-network.md) |
| Deploy, read a failed deploy, roll back, run the rollback drill, apply an infra change | [deploy-and-rollback.md](../docs/runbooks/deploy-and-rollback.md) |
| Run an import now, read `import_runs` and `run.json`, pause a source | [imports-and-sources.md](../docs/runbooks/imports-and-sources.md) |
| Check VPS-2's workers and `beat`, `worker-media`, the VPS-2 deploy, raw-page retention | [workers.md](../docs/runbooks/workers.md) |
| Change the firewall rules | [firewall-changes.md](../docs/runbooks/firewall-changes.md) |
| Get back in when WireGuard or SSH is broken | [break-glass.md](../docs/runbooks/break-glass.md) |
| Load the snapshot on VPS-1 (Lane B1) | [snapshot-load.md](../docs/runbooks/snapshot-load.md) |
| Run PostgreSQL, Redis and Caddy locally (`compose/dev.yml`) | [local-dev.md](../docs/runbooks/local-dev.md) |
| Set up Firebase Hosting (`firebase/`) | [firebase-hosting.md](../docs/runbooks/firebase-hosting.md) |

Two rules from them that apply to every change here:

- `netfilter-persistent` restores the rendered firewall at boot. Never run `netfilter-persistent save`: it would write Docker's own chains into the persisted rules.
- `infra.yml`'s `sync` job keeps `/srv/madar/infra/` on VPS-1 equal to `master`, and `backend.yml` syncs it before every deploy. `deploy-vps2` rsyncs the same folder to VPS-2. Neither job applies the firewall, WireGuard, sshd or the backup timers: those need `bootstrap-vps.sh` on the host, and a deploy stops with the command to run when one is missing. CI never connects to the home box.

## CI

| Workflow | Runs on | Does |
| --- | --- | --- |
| `infra.yml` | `infra/**`, `.github/workflows/**`, `.github/actions/**`, and `docs/runbooks/**` on PRs | `docker compose config -q` for each Compose file (including `home-box.yml`), the backup image tag and uid, the backup retention/init drill (real restic), the backup container's permissions, `systemd-analyze verify` on the home-box units, the ACL placeholder check, the ACL render-and-rotate check, the bootstrap gid lookup, the D3 folders/timers check, the deploy's no-root-work check, the FCM doc commands, the media CORS assertion, the action's `ssh-config.sh` path, the VPS-2 rollback dry run, `caddy validate`, shellcheck, actionlint; on `master`, the `sync` job |
| `gitleaks.yml` | Every PR and push | gitleaks over the whole history, with redacted output |
| `backend.yml` | `backend/**`; `infra/compose/**` on PRs only (the api-admin command check) | ruff, mypy, pytest; OpenAPI export and breaking-change check; client regeneration; on `master`, build both architectures, deploy VPS-1 and VPS-2, move `stable`, retention |
| `app.yml` | `app/**`, `backend/openapi/public.json`, `madar-design/**` | `flutter analyze`, the token and literal checks, `flutter test`, the `prod` debug APK artifact |
| `pwa.yml` | `app/**` or `infra/firebase/**` on `master`, manual | Web build → Firebase Hosting preview channel `master` (30 days) |
| `admin.yml` | `admin/**`, `backend/openapi/admin.json`, `madar-design/**` | typecheck, lint, test, build, the literal and token checks |

Every action is pinned to a commit SHA, and every image to an exact version. Failures and re-runs: [ci-workflows.md](../docs/runbooks/ci-workflows.md).
