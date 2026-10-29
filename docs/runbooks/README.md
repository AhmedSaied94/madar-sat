# Runbooks

Each runbook covers one area. The first-time setup crosses several of them, so this page gives the order. Do the steps top to bottom. Each one links to the section that has the commands.

Madar Sat runs on two Oracle Cloud Always Free VMs in one VCN. VPS-1 is public; VPS-2 has nothing public and is reached through VPS-1:

| | VPS-1 "app" | VPS-2 "workers" |
| --- | --- | --- |
| Reserved public IP | `<ip1>` | `<ip2>` |
| VCN private IP | `<vcn1>` | `<vcn2>` |
| WireGuard | Hub `10.8.0.1`, UDP 51820 | None: `ssh -J ubuntu@10.8.0.1 ubuntu@<vcn2>` |
| Public hostnames | `api.<ip1>.sslip.io`, `media.<ip1>.sslip.io`, `app.<ip1>.sslip.io` | None |
| Admin | `https://10.8.0.1`, over WireGuard only | None |
| Runs | Caddy, `api-public`, `api-admin`, PostgreSQL 16, Redis 7 | Celery workers, `beat`, Flower: off until D3. Uptime Kuma and backups later. |

| Runbook | What it covers |
| --- | --- |
| [provision-host.md](provision-host.md) | Creating a VM and preparing it, up to its deploy key. Run once per VM. |
| [private-network.md](private-network.md) | WireGuard peers, the admin site, the admin CA root on each device |
| [deploy-and-rollback.md](deploy-and-rollback.md) | How releases reach VPS-1, reading a failed deploy, rollbacks, the drill, GHCR images, the one-time GitHub setup, deploy keys, infra updates |
| [break-glass.md](break-glass.md) | Getting back into a VM when WireGuard or SSH doesn't work, and an instance Oracle stopped |
| [firebase-hosting.md](firebase-hosting.md) | The Firebase project, the deploy key, `.firebaserc`, the PWA preview channel and its CORS origin |
| [database-migrations.md](database-migrations.md) | How migrations run in a deploy, reading the state, a failed migration, the expand/contract rules |
| [snapshot-load.md](snapshot-load.md) | Loading the Sat Air snapshot into VPS-1 and rehosting its media |
| [firewall-changes.md](firewall-changes.md) | Changing, testing and applying the iptables rules on either VM |
| [exposure-check.md](exposure-check.md) | What the internet can reach, and the certificates and headers (T065) |
| [tls-certificates.md](tls-certificates.md) | Let's Encrypt on sslip.io, failed issuance, a changed public IP |
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

### 4. First deploys

1. **Merge Lane B2** (`infra/`) to `master`. `infra.yml`'s `sync` job starts Caddy, PostgreSQL and Redis on VPS-1 ([deploy-and-rollback.md "Updating the edge or infra"](deploy-and-rollback.md#updating-the-edge-or-infra)). If it ran before stage 3 and failed, re-run it ([ci-workflows.md "Re-running"](ci-workflows.md#re-running)).
2. **Certificates:** [tls-certificates.md "First issuance"](tls-certificates.md#first-issuance). That completes T058.
3. **Merge Lane B1** (`backend/`). `backend.yml` builds the image and deploys it ([deploy-and-rollback.md](deploy-and-rollback.md#how-a-release-reaches-vps-1)). Then give the repository access to the package: [deploy-and-rollback.md "Images in GHCR"](deploy-and-rollback.md#images-in-ghcr).
4. **The admin site:** the CA root on your device, then `https://10.8.0.1` ([private-network.md](private-network.md#the-admin-site)).
5. **The snapshot:** [snapshot-load.md](snapshot-load.md) (B1's T048).
6. **Exposure check:** [exposure-check.md](exposure-check.md) (T065).
7. **Rollback drill:** [deploy-and-rollback.md "Rehearse the failure path"](deploy-and-rollback.md#rehearse-the-failure-path) (T066).
8. **Secret-scan proof:** [ci-workflows.md "Prove the secret scan"](ci-workflows.md#prove-the-secret-scan) (T067, first half).
9. **Once Lanes A and M have merged:** the PWA preview and its CORS origin ([firebase-hosting.md §4](firebase-hosting.md#4-the-preview-channel)), then a green `master` run for every workflow (T067, second half).
10. **Record:** [provision-host.md §10](provision-host.md#10-record), for each VM.

Feature-specific checks (task IDs, scenarios to walk, decisions due) are in [owner-actions.md](../owner-actions.md).

## After setup

| When | Go to |
| --- | --- |
| Releasing, or a deploy failed | [deploy-and-rollback.md](deploy-and-rollback.md) |
| A bad release is serving | [deploy-and-rollback.md "Roll back"](deploy-and-rollback.md#roll-back) |
| `infra/` or `.github/` changed | [deploy-and-rollback.md "Updating the edge or infra"](deploy-and-rollback.md#updating-the-edge-or-infra) |
| `/srv/madar/.env` changed | [deploy-and-rollback.md "Updating the edge or infra"](deploy-and-rollback.md#updating-the-edge-or-infra), the table |
| A firewall rule must change | [firewall-changes.md](firewall-changes.md) |
| A migration failed, or you need the schema's state | [database-migrations.md](database-migrations.md) |
| A deploy key leaked or needs replacing | [deploy-and-rollback.md "Replacing a deploy key"](deploy-and-rollback.md#replacing-a-deploy-key) |
| Rotating a password or key, gitleaks failed, or a secret leaked | [secrets.md](secrets.md) |
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
| `staff-accounts.md` | Admin accounts and roles, password resets, lockouts | D2; TOTP on D16 |
| `imports-and-sources.md` | The source adapters, `import_runs`, source health, restarting a source, the Firestore bridge, the unresolved-names queue | D2–D7 (runbook v0 on D4) |
| `home-box.md` | The home scrape worker over WireGuard | D2 |
| `workers.md` | Deploying VPS-2's workers, `beat` and Flower. Nothing deploys to VPS-2 yet. | D2–D3 |
| `push-notifications.md` | FCM, the outbox and its dispatcher, the admin composer | D3, D6 |
| `backup-and-restore.md` | Nightly backups, the restore drill, the monthly routine | D3; drill and runbook v1 on D8 |
| `monitoring.md` | Uptime Kuma, alert routing, the monitoring review | D3, D7, D12 |
| `remote-config.md` | Maintenance mode, soft updates, moving hosts | D8 |
| `store-releases.md` | Android closed testing and production; Codemagic, TestFlight and the App Store | D2, D12; iOS D13–D20 |

Existing runbooks grow too: `firebase-hosting.md` with the public PWA release and the VPS-1 mirror (D4) and the emergency install link (D10); `tls-certificates.md` with the domain move (O4); `secrets.md` with the Play service account (D27).

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
