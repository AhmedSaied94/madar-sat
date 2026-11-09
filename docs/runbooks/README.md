# Runbooks

Each runbook covers one area. The first-time setup crosses several of them, so this page gives the order. Do the steps top to bottom. Each one links to the section that has the commands.

**Placeholders.** The runbooks never carry the deployment's public IPs or its own hostnames: they write `<VPS1_IP>`, `<VPS2_IP>`, `<KUMA_HOST>`, `<PWA_HOST>`, `<PWA_PREVIEW_HOST>` and `<FIREBASE_AUTH_DOMAIN>` (a public host reads `api.<VPS1_IP>.sslip.io`). The values are in `docs/runbooks/hosts.env`, which is git-ignored: copy [hosts.env.example](hosts.env.example) to it once per checkout and fill it in, or copy the file from a checkout that has it. Load it with `set -a; . docs/runbooks/hosts.env; set +a` and paste a command with `$VPS1_IP` where the runbook says `<VPS1_IP>`. A new IP or host goes into both files, never into a runbook. The private addresses (`10.1.0.x`, `10.8.0.x`) stay written out: nothing outside the VCN and WireGuard reaches them.

Madar Sat runs on two Oracle Cloud Always Free VMs in one VCN, plus the owner's x86-64 home box. VPS-1 is public; VPS-2 has nothing public and is reached through VPS-1; the home box reaches only Redis:

| | VPS-1 "app" | VPS-2 "workers" | Home box |
| --- | --- | --- | --- |
| Reserved public IP | `<VPS1_IP>` | `<VPS2_IP>` | none |
| VCN private IP | `10.1.0.97` | `10.1.0.118` | none |
| WireGuard | Hub `10.8.0.1`, UDP 51820 | None: `ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118` | Peer, outbound only |
| Public hostnames | `api.<VPS1_IP>.sslip.io`, `media.<VPS1_IP>.sslip.io`, `app.<VPS1_IP>.sslip.io` | None | None |
| Admin | `https://10.8.0.1`, over WireGuard only | None | None |
| Runs | Caddy, `api-public`, `api-admin`, `worker-media`, PostgreSQL 16, Redis 7, the media backup timer | `worker-imports`, `worker-scrape`, `worker-maintenance`, `worker-notify`, `worker-live`, `beat`, Uptime Kuma, the database backup timer; Flower off | `worker-scrape -Q scrape_home` and a 10-minute update timer |

| Runbook | What it covers |
| --- | --- |
| [provision-host.md](provision-host.md) | Creating a VM and preparing it, up to its deploy key. Run once per VM. |
| [private-network.md](private-network.md) | WireGuard peers, the admin site, the admin CA root on each device |
| [deploy-and-rollback.md](deploy-and-rollback.md) | How releases reach VPS-1, reading a failed deploy, rollbacks, the drill, GHCR images, the one-time GitHub setup, making the repository private, deploy keys, infra updates |
| [break-glass.md](break-glass.md) | Getting back into a VM when WireGuard or SSH doesn't work, and an instance Oracle stopped |
| [firebase-hosting.md](firebase-hosting.md) | The Firebase project, the deploy key, `.firebaserc`, the PWA preview channel and its CORS origin |
| [pwa-release.md](pwa-release.md) | Cutting a `web-v*` PWA release: the tag, what the job does, the mirror check, rolling the live channel back, pruning |
| [on-call.md](on-call.md) | An alert just fired: the order to work it, where the logs are, one row per Kuma monitor and Telegram alert |
| [store-releases.md](store-releases.md) | Android releases: tagging `app-v<x.y.z>`, the signed AAB, Play App Signing, the closed-track upload and the testers list, backing up the upload keystore, and push setup (the notification channel, the VAPID key, the service worker, the iPhone PWA test) |
| [remote-config.md](remote-config.md) | The app's Remote Config keys and their bundled defaults, changing a host safely, raising `min_supported_build`, the live poll interval |
| [database-migrations.md](database-migrations.md) | How migrations run in a deploy, reading the state, a failed migration, the expand/contract rules |
| [snapshot-load.md](snapshot-load.md) | Loading the Sat Air snapshot into VPS-1 and rehosting its media |
| [imports-and-sources.md](imports-and-sources.md) | The import schedule, starting a run, reading `import_runs`, `log` and `run.json`, pausing a source, the breaker, sporteventz and other sports, API-Football and stopped runs, LiveSoccerTV and its placeholders, switching a fetch queue, the bridge's configuration |
| [source-alerts.md](source-alerts.md) | The Telegram bot and chat, what "⛔ المصدر متوقف" and "⚠️ لم يجد أي عناصر" mean, the quiet-day rules, and why a stopped run is not an alert |
| [backups.md](backups.md) | Nightly database and media backups, retention, running one by hand, restoring the database and one media file, the monthly restore drill |
| [uptime-kuma.md](uptime-kuma.md) | Reaching Kuma over WireGuard, the first account, the exact four HTTP and eight push monitors, the Telegram notification, what each alert means |
| [home-box.md](home-box.md) | Joining the scrape box to `wg0`, its `.env`, the update timer, checking it, taking it offline |
| [workers.md](workers.md) | VPS-2's services and `beat`, `worker-media` and logos, the VPS-2 deploy and rollback, raw-page retention |
| [live-poller.md](live-poller.md) | Live scores on VPS-2: what runs, the settings, pausing, each alert, updating a parser, the capture, the disk check |
| [firewall-changes.md](firewall-changes.md) | Changing, testing and applying the iptables rules on either VM |
| [exposure-check.md](exposure-check.md) | What the internet can reach, and the certificates and headers (T065) |
| [tls-certificates.md](tls-certificates.md) | Let's Encrypt on sslip.io, failed issuance, a changed public IP |
| [staff-accounts.md](staff-accounts.md) | Creating admin and editor accounts, password resets, deactivating an account, a suspected token leak |
| [admin-access.md](admin-access.md) | Running the admin app on an editor's machine: `pnpm dev:wg` over WireGuard, Caddy's root CA, the Prism mock and its `?mock=` states |
| [push-notifications.md](push-notifications.md) | FCM credentials, the reminder scheduler and dispatcher, reading and re-sending outbox rows, the audience query |
| [response-cache-and-limits.md](response-cache-and-limits.md) | What `/v1` caches and for how long, turning it off, the device/IP/register limits and a CGNAT false positive |
| [load-testing.md](load-testing.md) | The k6 load test: the allowlist window on VPS-1, the run from VPS-2, the CPU sampling, closing the window again, and the report |
| [secrets.md](secrets.md) | Where every secret lives, rotating them, gitleaks failures and leaks |
| [local-dev.md](local-dev.md) | PostgreSQL, Redis and HTTPS Caddy on your machine; the test settings |
| [ci-workflows.md](ci-workflows.md) | What each workflow checks, common failures, re-runs, the T067 proofs |

## First-time setup

Keep every secret (passwords, keys, the console passwords) in your password manager as you create it. You paste them into each VM's `.env` in stage 2.

### 1. Accounts (no host needed)

These need only your machine and a browser, so you can do them before the VMs exist.

1. **Firebase project, deploy key and `.firebaserc`:** [firebase-hosting.md §1–§3](firebase-hosting.md#1-create-the-project), up to step 1 of §3. Keep the project ID: VPS-1's `.env` needs it in stage 2.
2. **GitHub:** [deploy-and-rollback.md "One-time setup"](deploy-and-rollback.md#one-time-setup), steps 2–4: the Actions minutes, failure emails, and who can reach the secrets. The secrets come in stages 2 and 3.

### 2. The VMs

Each `.env` names the other VM's private IP, so create both VMs before you bootstrap either. Then finish VPS-1 before VPS-2: once VPS-2's public SSH closes, you reach it through VPS-1. Each VM's values are in [provision-host.md "The two VMs"](provision-host.md#the-two-vms).

1. **Both VMs, reserved IPs, VCN and security list:** [provision-host.md §1](provision-host.md#1-reserve-the-ip-and-create-the-vm), for VPS-1 and then VPS-2.
2. **Then, on VPS-1 first and VPS-2 second:**
   1. **Console password and serial console test:** [§2](provision-host.md#2-console-password-then-test-the-serial-console).
   2. **Bootstrap script:** [§3](provision-host.md#3-run-the-bootstrap-script). The first run stops after creating `/srv/madar/.env`.
   3. **The env file:** [§4](provision-host.md#4-fill-the-env-file-and-re-run), then re-run the script.
   4. **Your WireGuard peer** on VPS-1, or the jump test on VPS-2: [§5](provision-host.md#5-your-wireguard-peer).
   5. **SSH over WireGuard only:** [§6](provision-host.md#6-ssh-over-wireguard-only).
3. **Close TCP 22 in the security list** once both VMs are through §6: [§7](provision-host.md#7-close-tcp-22-in-the-security-list).
4. **The repository variables** `VPS1_IP` and `VPS2_IP`: [deploy-and-rollback.md "One-time setup"](deploy-and-rollback.md#one-time-setup) step 1.

### 3. Deploy access

1. **The CI peer, the deploy key and the pinned host key**, on VPS-1: [provision-host.md §8](provision-host.md#8-deploy-peer-and-keys). `gh secret list` then shows four secrets.
2. **Reboot check**, on both VMs: [provision-host.md §9](provision-host.md#9-reboot-check). That completes T064.

### 4. The home box's peer (before the first deploy)

The firewall rule and the `homebox` Redis user have to exist before anything starts, and
`bootstrap-vps.sh vps1` is what writes them (T080–T084). Do this now, not after the merges:

1. **Add the box to `wg0`** (`wg-add-peer.sh home-box`), write `HOME_BOX_WG_IP` on VPS-1, and **re-run
   `bootstrap-vps.sh vps1`** so the firewall carries its Redis rule and `deploy` joins gid 999. Then
   write the box's `.env` and install its timer: [home-box.md](home-box.md). Don't start
   `worker-scrape` yet: before the first deploy there is no `madar-backend-amd64:stable` image.

### 5. First deploys

1. **Merge Lane B2** (`infra/`) to `master`. `infra.yml`'s `sync` job starts Caddy, PostgreSQL and Redis on VPS-1 ([deploy-and-rollback.md "Updating the edge or infra"](deploy-and-rollback.md#updating-the-edge-or-infra)). If it ran before stage 3 and failed, re-run it ([ci-workflows.md "Re-running"](ci-workflows.md#re-running)).
2. **Certificates:** [tls-certificates.md "First issuance"](tls-certificates.md#first-issuance). That completes T058.
3. **Merge Lane B1** (`backend/`). `backend.yml` builds the image and deploys it ([deploy-and-rollback.md](deploy-and-rollback.md#how-a-release-reaches-vps-1)). The infra sync in step 1 runs `deploy.sh --infra-only`, which never starts the API. So if `backend/` reached `master` before the stage 3 secrets existed (as on 2026-10-29), nothing triggers `backend.yml` again: start it by hand with `gh workflow run backend.yml --ref master`. Until then Caddy answers `api.` with 502 (`dial tcp 127.0.0.1:8000: connect: connection refused`). Then give the repository access to the package: [deploy-and-rollback.md "Images in GHCR"](deploy-and-rollback.md#images-in-ghcr).
4. **The admin site:** the CA root on your device, then `https://10.8.0.1` ([private-network.md](private-network.md#the-admin-site)). **Then the first admin account**, and one account per editor ([staff-accounts.md](staff-accounts.md#create-an-account)); it needs `ADMIN_JWT_SECRET` in `/srv/madar/.env` first ([secrets.md](secrets.md#where-they-live)).
5. **The snapshot:** [snapshot-load.md](snapshot-load.md) (B1's T048).
6. **Exposure check:** [exposure-check.md](exposure-check.md) (T065).
7. **Rollback drill:** [deploy-and-rollback.md "Rehearse the failure path"](deploy-and-rollback.md#rehearse-the-failure-path) (T066).
8. **Secret-scan proof:** [ci-workflows.md "Prove the secret scan"](ci-workflows.md#prove-the-secret-scan) (T067, first half).
9. **Once Lanes A and M have merged:** the PWA preview and its CORS origin ([firebase-hosting.md §4](firebase-hosting.md#4-the-preview-channel)), then a green `master` run for every workflow (T067, second half).
10. **VPS-2's workers:** the `deploy-vps2` job needs the `VPS2_VCN_IP` variable and VPS-2's host key in `DEPLOY_KNOWN_HOSTS` ([workers.md](workers.md#deploy-vps-2)). Check the four services are healthy and exactly one `beat` runs.
11. **Monitoring and backups:** create the Kuma monitors and the Telegram notification ([uptime-kuma.md](uptime-kuma.md) §1–§4) with the eight `KUMA_PUSH_URL_*` values and the Telegram pair in `/srv/madar/.env`, then check the first night's backups ([backups.md](backups.md#check-last-nights-backup)). The directories and the timers come from `bootstrap-vps.sh` (run it on each host after pulling D3, then deploy); a deploy only verifies them (B2-R1-4). The first run creates the restic repository (B2-R1-5).
12. **Start the home box's worker:** its peer, `.env`, the Redis ACL, the firewall rule and its timer happened in stage 4, before the first deploy ([home-box.md](home-box.md)). Starting it is what makes ysscores arrive from the box; without it, switch `YSSCORES_FETCH_QUEUE=scrape` ([imports-and-sources.md](imports-and-sources.md#switch-where-a-source-fetches)).
13. **The first unattended run:** after the next `ysscores-fixtures` slot, read `import_runs` ([imports-and-sources.md](imports-and-sources.md#read-what-a-run-did)).
14. **Reminders (D3):** the FCM service account on VPS-2 and `FCM_DRY_RUN=false`, one real reminder to the owner's phone ([push-notifications.md](push-notifications.md#the-fcm-service-account)), and the `/v1` limits left at their defaults ([response-cache-and-limits.md](response-cache-and-limits.md)).
15. **Record:** [provision-host.md §10](provision-host.md#10-record), for each VM.
16. **The first Android release** (after Lane M has merged): back up the upload keystore, tag `app-v0.2.0`, enrol in Play App Signing, upload the AAB to the closed track and add the testers ([store-releases.md](store-releases.md)).
17. **Before merging D4 (the admin deploy):** re-run `sudo ./madar-infra/scripts/bootstrap-vps.sh vps1` from a fresh copy of `infra/`, so `/srv/admin/current` and its placeholder release exist before Caddy's admin root moves to them ([deploy-and-rollback.md "The admin deploy"](deploy-and-rollback.md#the-admin-deploy)). A fresh host gets them from its first bootstrap in stage 2.

Feature-specific checks (task IDs, scenarios to walk, decisions due) are in [owner-actions.md](../owner-actions.md).

## After setup

| When | Go to |
| --- | --- |
| Something is alerting right now | [on-call.md](on-call.md) |
| Releasing the PWA | [pwa-release.md](pwa-release.md) |
| Releasing, or a deploy failed | [deploy-and-rollback.md](deploy-and-rollback.md) |
| Releasing the Android app, or a Play upload was refused | [store-releases.md](store-releases.md) |
| No fixtures arrived, or a run is `failed`/`partial` | [imports-and-sources.md](imports-and-sources.md) |
| A match shows twice since YallaKora's runs of 5 Nov 2026 | [imports-and-sources.md](imports-and-sources.md#merging-duplicate-matches) |
| A Telegram alert about a source, or one is still paused | [source-alerts.md](source-alerts.md) |
| A live score is wrong or stale, a live alert, or fixing a live parser | [live-poller.md](live-poller.md) |
| A backup monitor is red, or you need to restore something | [backups.md](backups.md) |
| A monitor is red, or you need to add one | [uptime-kuma.md](uptime-kuma.md) |
| A worker on VPS-2 or `worker-media` is unhealthy | [workers.md](workers.md) |
| The home box is offline, or a logo did not arrive | [home-box.md](home-box.md) |
| A bad release is serving | [deploy-and-rollback.md "Roll back"](deploy-and-rollback.md#roll-back) |
| `infra/` or `.github/` changed | [deploy-and-rollback.md "Updating the edge or infra"](deploy-and-rollback.md#updating-the-edge-or-infra) |
| `/srv/madar/.env` changed | [deploy-and-rollback.md "Updating the edge or infra"](deploy-and-rollback.md#updating-the-edge-or-infra), the table |
| A firewall rule must change | [firewall-changes.md](firewall-changes.md) |
| A migration failed, or you need the schema's state | [database-migrations.md](database-migrations.md) |
| A deploy key leaked or needs replacing | [deploy-and-rollback.md "Replacing a deploy key"](deploy-and-rollback.md#replacing-a-deploy-key) |
| Every development phase is done and the repository goes private | [deploy-and-rollback.md "Making the repository private"](deploy-and-rollback.md#making-the-repository-private) |
| Rotating a password or key, gitleaks failed, or a secret leaked | [secrets.md](secrets.md) |
| A reminder or any other push didn't arrive, FCM rejects the credentials, or every push must stop now | [push-notifications.md](push-notifications.md) |
| An announcement must go out, or a test send fails with `test_device_not_set` | [push-notifications.md "The composer and the test device"](push-notifications.md#the-composer-and-the-test-device) |
| A push failed, or more than 20 % of a send failed | [on-call.md "A push row failed"](on-call.md#3b-a-push-row-failed) |
| Editor accounts in A16, or a temporary password | [staff-accounts.md](staff-accounts.md#add-an-account-in-a16-temporary-password) |
| A sporteventz row is labelled with the wrong sport | [imports-and-sources.md "Relabelling a sporteventz row's sport"](imports-and-sources.md#relabelling-a-sporteventz-rows-sport) |
| A 429 appears in the API log, or public reads feel slow | [response-cache-and-limits.md](response-cache-and-limits.md) |
| You are about to load-test the API, or p95 misses its target | [load-testing.md](load-testing.md) |
| VPS-1 needs more CPU | [provision-host.md "Resize an instance"](provision-host.md#resize-an-instance) |
| A name didn't match, or YallaKora added a duplicate | [imports-and-sources.md "The unresolved queue"](imports-and-sources.md#the-unresolved-queue) |
| A new editor, a forgotten password, someone leaves, or an admin session may have leaked | [staff-accounts.md](staff-accounts.md) |
| An editor needs the admin app on their machine, or the mock's states | [admin-access.md](admin-access.md) |
| A device needs the private network, or one is lost | [private-network.md "Peers"](private-network.md#peers) |
| A browser warns about the admin's certificate | [private-network.md "Install the admin CA root"](private-network.md#install-the-admin-ca-root) |
| WireGuard or SSH doesn't let you into a VM | [break-glass.md](break-glass.md) |
| Oracle stopped an instance | [break-glass.md "Instance stopped by Oracle"](break-glass.md#instance-stopped-by-oracle) |
| A certificate didn't renew, or a public IP changed | [tls-certificates.md](tls-certificates.md) |
| After any firewall, Caddy or Compose change | [exposure-check.md](exposure-check.md) |
| Reloading the snapshot, or more media to rehost | [snapshot-load.md](snapshot-load.md) |
| The PWA preview, or rotating the Firebase key | [firebase-hosting.md](firebase-hosting.md) |
| A CI check failed | [ci-workflows.md](ci-workflows.md) |
| Setting up a new development machine | [local-dev.md](local-dev.md) |

## Planned runbooks

Later days add these. Each arrives with the change that builds the part it covers:

| Runbook | Covers | From |
| --- | --- | --- |
| `push-notifications.md` (grows) | The admin composer and the other six notification types | D6 |
| `monitoring.md` | Alert routing and the monitoring review (Kuma itself is covered now) | D7, D12 |
| `remote-config.md` | Maintenance mode, soft updates, moving hosts | D8 |
| `store-releases.md` (grows) | Android production, then Codemagic, TestFlight and the App Store; the closed track is covered since D2 | D12; iOS D13–D20 |

The monthly restore drill already has its commands in `backups.md`; D8 adds the schedule, report and
`monitoring.md`'s alert review. Existing runbooks grow too: `firebase-hosting.md` with the emergency
install link (D10); `tls-certificates.md` with the domain move (O4); `secrets.md` with the Play
service account (D27).

**Keep these current.** A change that adds or changes an operated part (anything in `infra/` or `.github/`, a deploy step, a secret, a host setting, or a step the owner does by hand) adds or updates its runbook, and [owner-actions.md](../owner-actions.md), in the same change. A review flags a change that doesn't.

## Template

New runbooks follow the shape of the ones above:

```markdown
# <Title>

<What it covers, when to use it, and whether it touches production. Background: <SD sections, research IDs, files>.>

## Before you start

- <access, secrets, tools>

## 1. <Step>

<Commands, each with what you should see.>

## Check

## If it fails

| Symptom | Do |
| --- | --- |
```
