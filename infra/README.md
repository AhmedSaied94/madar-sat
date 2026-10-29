# infra/: servers, network and deploys (Lane B2)

Two OCI Always Free Ampere A1 hosts (arm64), Docker Compose, Caddy and WireGuard. No Kubernetes, no CDN, $0/month (constitution IX). Every image is `linux/arm64`.

**No key, password, token or certificate is ever committed.** Real values live only in each host's `/srv/madar/.env` (mode 600, owner `deploy`) and in GitHub Actions secrets. The repo holds templates and fake placeholders only, and `gitleaks.yml` fails any PR that adds a secret.

## Layout

| Path | What it is |
| --- | --- |
| `compose/vps1.yml` | VPS-1: `caddy`, `api-public`, `api-admin`, `postgres`, `redis`, plus `migrate` and `cli` (profile `tools`) |
| `compose/vps2.yml` | VPS-2: the Celery workers, the single `beat` and `flower`, all under profile `workers` (no worker code before D3) |
| `compose/dev.yml` | Local development: PostgreSQL 16, Redis 7 and a `tls internal` Caddy at `https://localhost:8443` |
| `compose/example.env` | Every variable name the Compose files, Caddyfile and scripts use, with fake values |
| `Caddyfile` | The public sites `api.`, `media.` and `app.<ip1>.sslip.io`, and the admin site `https://10.8.0.1` on `wg0` |
| `firewall/vps1.rules`, `vps2.rules`, `rules.v6` | iptables templates, rendered into `/etc/iptables/rules.v4` and `rules.v6` |
| `wireguard/wg0.conf.tmpl`, `peer.conf.tmpl` | The hub and peer configs, with key placeholders only |
| `scripts/bootstrap-vps.sh` | Idempotent host setup (Docker, WireGuard, the `deploy` user, `/srv` folders, firewall) |
| `scripts/check-firewall.sh` | Prints the active and persisted rules and fails if they differ |
| `scripts/wg-add-peer.sh` | Adds a WireGuard peer; generates its keys on the host |
| `scripts/deploy.sh` | Runs on VPS-1: apply infra, migrate, roll out, health-check, roll back |
| `firebase/` | Firebase Hosting config for the PWA preview channel |
| `admin-placeholder/index.html` | Served on `https://10.8.0.1` until the admin ships (D4) |

## Hosts (SD §7.1)

| | VPS-1 "app" (public) | VPS-2 "workers" |
| --- | --- | --- |
| Runs | Caddy, `api-public`, `api-admin`, PostgreSQL 16, Redis 7 | Celery workers, `beat` (exactly one), Flower; Uptime Kuma and backups later (D3) |
| Memory | PostgreSQL ≈ 2 GB (`shared_buffers` 1.5 GB), Redis 512 MB, APIs 0.5 GB | Workers ≈ 1.2 GB, Flower 0.1 GB |
| Disk | Database, `/srv/media`, `/srv/app-mirror` | Raw HTML (5 days), backup staging |

## Hostnames and ports (SD §7.2)

| Name | Served by | Upstream |
| --- | --- | --- |
| `api.<ip1>.sslip.io` | Caddy, Let's Encrypt | `api-public` on `127.0.0.1:8000` |
| `media.<ip1>.sslip.io` | Caddy, Let's Encrypt | `/srv/media`, `immutable` |
| `app.<ip1>.sslip.io` | Caddy, Let's Encrypt | `/srv/app-mirror` (PWA file mirror), CORS `GET` from the two PWA origins |
| `<project>.web.app` | Firebase Hosting | The PWA shell (`pwa.yml`) |
| `https://10.8.0.1` (`wg0` only) | Caddy, `tls internal` | `/admin/api/*` → `api-admin` on `10.8.0.1:8001`; everything else → `/srv/admin` |

| Port | VPS-1 | VPS-2 |
| --- | --- | --- |
| 80/tcp, 443/tcp | Public | Closed |
| 51820/udp | Public (WireGuard hub `10.8.0.1/24`) | Closed |
| 22/tcp | `wg0` only | From VPS-1's VCN IP only |
| 5432, 6379 | Published on VPS-1's VCN IP; allowed from VPS-2 only (Redis also on `wg0`, for the home box later) | n/a |

Docker-published ports skip the `INPUT` chain, so each one is bound to a specific address (`127.0.0.1`, `10.8.0.1` or the VCN IP), and the `DOCKER-USER` rules in `firewall/vps1.rules` limit who can reach them ([R12](../specs/001-d01-foundation/research.md#r12-hosts-networking-and-docker)).

## GitHub configuration

**Secrets:**

| Secret | Value |
| --- | --- |
| `WG_CI_CONFIG` | The CI peer's WireGuard client config (`wg-add-peer.sh ci` on VPS-1) |
| `DEPLOY_SSH_KEY` | The private half of the `deploy` user's SSH key (ed25519), used only by CI |
| `DEPLOY_KNOWN_HOSTS` | VPS-1's host key line for `10.8.0.1`, for example the output of `ssh-keyscan -t ed25519 10.8.0.1` run over WireGuard |
| `FIREBASE_SERVICE_ACCOUNT` | The JSON key of the Hosting deploy service account; its roles are in [firebase-hosting.md](../docs/runbooks/firebase-hosting.md#2-service-account-and-key) |

**Variables:**

| Variable | Value |
| --- | --- |
| `VPS1_IP` | VPS-1's reserved public IP (it is part of every `sslip.io` name) |
| `VPS2_IP` | VPS-2's reserved public IP |
| `ARM_RUNNER` | Optional: the label of a native arm64 runner. When it is empty, `backend.yml` builds with buildx + QEMU on `ubuntu-24.04` |

`backend.yml` pushes to `ghcr.io/<owner>/madar-backend` with the job's `GITHUB_TOKEN`. After the first push, open the package's settings, and under "Manage Actions access" give this repository the **Admin** role. The `retention` job then has the rights to delete old versions.

## Host `.env` (`/srv/madar/.env`, mode 600, owner `deploy`)

Names only; the values are in `compose/example.env` as fakes. Use URL-safe passwords (for example `openssl rand -hex 32`), because some of them are part of connection URLs. Write one `KEY=value` per line, with no quotes and no trailing comments.

| Group | Variables |
| --- | --- |
| Compose | `GHCR_OWNER` (lowercase), `VCN_IP` (this host's VCN private IP). `IMAGE_TAG` and `HEALTHZ_FORCE_FAIL` are set by `deploy.sh`, not in the file |
| Host and network | `VPS1_IP`, `PEER_VCN_IP` (the other host's VCN IP), `ACME_EMAIL`, `FIREBASE_PROJECT_ID`, `DEPLOY_SSH_PUBLIC_KEY` |
| PostgreSQL and Redis | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `REDIS_PASSWORD` |
| Backend (`backend/app/settings.py`) | `DATABASE_URL`, `DATABASE_URL_SYNC`, `REDIS_URL`, `MEDIA_BASE_URL`, `MEDIA_ROOT`, `MEDIA_REHOST_ALLOWED_HOSTS`, `CORS_ORIGINS`, `CONTRACT_VERSION` |
| VPS-2 | `CELERY_BROKER_URL`, `FLOWER_BASIC_AUTH`; `DATABASE_URL` and `REDIS_URL` point at VPS-1's VCN IP |

`MADAR_ENV_FILE` exists only in `example.env`, so CI and `dev.yml` can validate the Compose files without a host. Never set it on a host.

## Procedures

The step-by-step procedures are runbooks in [`docs/runbooks/`](../docs/runbooks/README.md), which also gives the first-time setup order:

| To | Runbook |
| --- | --- |
| Create and bootstrap a host (`bootstrap-vps.sh`, `.env`, closing public SSH, the deploy key) | [provision-host.md](../docs/runbooks/provision-host.md) |
| Add or remove a WireGuard peer, reach the admin site, trust its CA root | [private-network.md](../docs/runbooks/private-network.md) |
| Deploy, read a failed deploy, roll back, run the rollback drill, apply an infra change | [deploy-and-rollback.md](../docs/runbooks/deploy-and-rollback.md) |
| Change the firewall rules | [firewall-changes.md](../docs/runbooks/firewall-changes.md) |
| Get back in when WireGuard or SSH is broken | [break-glass.md](../docs/runbooks/break-glass.md) |
| Load the snapshot on VPS-1 (Lane B1) | [snapshot-load.md](../docs/runbooks/snapshot-load.md) |
| Run PostgreSQL, Redis and Caddy locally (`compose/dev.yml`) | [local-dev.md](../docs/runbooks/local-dev.md) |
| Set up Firebase Hosting (`firebase/`) | [firebase-hosting.md](../docs/runbooks/firebase-hosting.md) |

Two rules from them that apply to every change here:

- `netfilter-persistent` restores the rendered firewall at boot. Never run `netfilter-persistent save`: it would write Docker's own chains into the persisted rules.
- `infra.yml`'s `sync` job keeps `/srv/madar/infra/` on VPS-1 equal to `master`, and `backend.yml` syncs it before every deploy. Nothing syncs to VPS-2, and neither job applies the firewall, WireGuard or sshd: those need `bootstrap-vps.sh`.

## CI

| Workflow | Runs on | Does |
| --- | --- | --- |
| `infra.yml` | `infra/**`, `.github/workflows/**`, `.github/actions/**` | `docker compose config -q` for each Compose file, `caddy validate`, shellcheck, actionlint; on `master`, the `sync` job |
| `gitleaks.yml` | Every PR and push | gitleaks over the whole history, with redacted output |
| `backend.yml` | `backend/**` | ruff, mypy, pytest; OpenAPI export and breaking-change check; client regeneration; on `master`, build, deploy and retention |
| `app.yml` | `app/**`, `backend/openapi/public.json`, `madar-design/**` | `flutter analyze`, the token and literal checks, `flutter test`, the `prod` debug APK artifact |
| `pwa.yml` | `app/**` or `infra/firebase/**` on `master`, manual | Web build → Firebase Hosting preview channel `master` (30 days) |
| `admin.yml` | `admin/**`, `backend/openapi/admin.json`, `madar-design/**` | typecheck, lint, test, build, the literal and token checks |

Every action is pinned to a commit SHA, and every image to an exact version. Failures and re-runs: [ci-workflows.md](../docs/runbooks/ci-workflows.md).
