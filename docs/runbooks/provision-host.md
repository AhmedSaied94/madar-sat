# Provision a host

Madar Sat runs on two Oracle Cloud Always Free VMs. VPS-1 serves the public API, media and PWA mirror over HTTPS, and is the WireGuard hub for SSH and the admin. VPS-2 runs the background workers and has nothing public. This runbook sets up one VM. Run it once per VM, with that VM's values from the table below. Background: SD §7.1–§7.2 and `specs/001-d01-foundation/research.md` R12.

This is stage 2 of the first-time setup. [README.md](README.md#first-time-setup) gives the order across all the runbooks.

**Time each VM's run**, from step 1 until `bootstrap-vps.sh` closes public SSH. Write the times down for step 10.

## The two VMs

The commands below use `<role>`, `<ip>` and `<private-ip>` for the VM you're working on.

| | VPS-1 "app" | VPS-2 "workers" |
| --- | --- | --- |
| `<role>` (`bootstrap-vps.sh` argument) | `vps1` | `vps2` |
| Shape | `VM.Standard.A1.Flex`, 1 OCPU / 6 GB | `VM.Standard.A1.Flex`, 1 OCPU / 6 GB |
| Boot volume | 100 GB | 47 GB |
| `<ip>`, the reserved public IP | `<VPS1_IP>` | `<VPS2_IP>` |
| `<private-ip>`, the VCN private IP (`VCN_IP` in its `.env`) | `10.1.0.97` | `10.1.0.118` |
| `PEER_VCN_IP` in its `.env` | `10.1.0.118` | `10.1.0.97` |
| WireGuard | Hub `10.8.0.1/24`, UDP 51820 | None |
| SSH after step 6 | `ssh ubuntu@10.8.0.1`, over WireGuard | `ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118`, through VPS-1 |
| Public ports after step 6 | 80/tcp, 443/tcp, 51820/udp | None |
| Runs | Caddy, `api-public`, `api-admin`, PostgreSQL 16, Redis 7 | Celery workers, `beat`, Flower: profile `workers`, off until the worker code exists (D3) |
| Deploy peer and key | `ci`, the `deploy` user | None yet: nothing deploys to VPS-2 before D3 |

- Both VMs sit in **one** VCN and subnet, and talk over their private IPs: VPS-2 reaches PostgreSQL and Redis on `10.1.0.97`, and VPS-1 reaches VPS-2's SSH.
- Each `.env` names the other VM's private IP, so do step 1 for **both** VMs before step 3 on either. Then do steps 2–9 on VPS-1 first: once VPS-2's public SSH closes, you reach it through VPS-1's WireGuard.
- A rebuilt VM keeps its reserved IP, so the hostnames stay the same. Its private IP can change: read it in step 1, update **both** `.env` files, the security list's `/32` rules and the runbooks (step 10), then re-run the script on both VMs (the firewall rules use `PEER_VCN_IP`).

## Before you start

- **The OCI tenancy**, signed in, with room for two A1 VMs. SD §7.1 sizes each at 1 OCPU / 6 GB, and the two boot volumes take 147 GB of the 200 GB block-storage allowance, which leaves 53 GB for one rescue volume ([break-glass.md](break-glass.md#path-2-boot-volume-rescue)). Check the tenancy's limits page first. If another project already uses A1 or block storage in this tenancy, these VMs may not fit.
- **The Firebase project ID** ([firebase-hosting.md §1](firebase-hosting.md#1-create-the-project)). VPS-1's script refuses to finish without it.
- **An SSH key pair** on your machine (`ssh-keygen -t ed25519` if you have none).
- **WireGuard** on the device you'll administer from (`wireguard-tools` on Linux, the WireGuard app elsewhere).
- **A password manager entry** for each VM's `ubuntu` console password. Each VM has its own.
- **This repository**, checked out at `master`, with `infra/`.

Create **only Always Free resources**. Every item on the create pages must show the "Always Free-eligible" label. If one doesn't, stop.

## 1. Reserve the IP and create the VM

The console labels below are the ones in use when this was written. If a label has changed, look for the same intent.

1. **Reserve the IP:** Networking → IP management → Reserved public IPs → Reserve public IP address. Name it `madar-vps1` or `madar-vps2` and note the address. The hostnames are built from it, so it must survive rebuilds.
2. **The VCN, once, for VPS-1:** Networking → Virtual cloud networks → Start VCN Wizard → Create VCN with Internet Connectivity. Name it `madar`. VPS-2 goes into the same VCN and the same public subnet.
3. **Create the instance:** Compute → Instances → Create instance:
   - Image: **Canonical Ubuntu 24.04**, the aarch64 platform image. `bootstrap-vps.sh` assumes Ubuntu (apt, Docker's Ubuntu repository).
   - Shape: **`VM.Standard.A1.Flex`, 1 OCPU, 6 GB**.
   - Networking: VCN `madar`, its public subnet, and **no** public IPv4 address. You attach the reserved one next.
   - SSH key: paste your public key.
   - Boot volume: **100 GB** for VPS-1, **47 GB** for VPS-2. Boot volume performance: **Balanced (10 VPUs/GB)**, the default, on both, with auto-tune off. Higher Performance and Ultra High add a per-GB VPU charge outside Always Free, and auto-tune can raise the VPUs on its own. Lower Cost saves nothing here and slows PostgreSQL. Check that the cost estimate on the create page shows no charge.
4. On **"Out of host capacity"**, retry later, or pick another availability domain if the region has more than one.
5. Once the instance runs, open **Attached VNICs → the VNIC → IPv4 addresses → Edit**, and pick **Reserved public IP** with this VM's address.
6. Note the VM's **private IP** (`<private-ip>`) from the instance page. On the VM, `ip route get 1.1.1.1` shows it as `src`.
7. **The security list.** The public subnet's security list applies to both VMs, so set it up once both exist. Each VM's own firewall (step 3) then allows only its own ports. Ingress rules, all stateful:

   | Source | Protocol and port | For | Keep |
   | --- | --- | --- | --- |
   | `0.0.0.0/0` | TCP 80, TCP 443 | Caddy: Let's Encrypt and HTTPS on VPS-1 | Always |
   | `0.0.0.0/0` | UDP 51820 | The WireGuard hub on VPS-1 | Always |
   | `<your public ip>/32` | TCP 22 | Your first SSH sessions | Until step 7 |
   | `10.1.0.97/32` | TCP 22 | VPS-1 → VPS-2, the SSH jump | Always |
   | `10.1.0.118/32` | TCP 5432, TCP 6379 | VPS-2's workers → PostgreSQL and Redis on VPS-1 | Always |
   | `10.1.0.97/32` | TCP 3001 | VPS-1's Caddy → Uptime Kuma on VPS-2 ([uptime-kuma.md](uptime-kuma.md)), and VPS-1's media backup heartbeats (D3) | Always |

   The wizard's default list allows TCP 22 from anywhere. Narrow that rule to `<your public ip>/32`. Leave the default ICMP rules and the egress rule as they are.

## 2. Console password, then test the serial console

```bash
ssh ubuntu@<ip>
sudo passwd ubuntu          # store it in the password manager; it is only for the serial console
```

SSH stays key-only: step 3 turns password logins off for SSH, and this password doesn't change that.

Test the break-glass path once on this VM, now that you can still fix it:

1. On the instance page, open **Console connection → Launch Cloud Shell connection**.
2. Press Enter, sign in as `ubuntu` with that password, then `exit` and close Cloud Shell.

If you get no login prompt, the serial console doesn't work on this VM. Don't pass `--serial-console-tested` in step 6 (FR-023 relies on it). Note it in research.md R12 and decide with the planning session. [break-glass.md "Path 2"](break-glass.md#path-2-boot-volume-rescue) is then the only way back in.

## 3. Run the bootstrap script

From the repository root on your machine:

```bash
rsync -a --delete infra/ ubuntu@<ip>:madar-infra/
ssh ubuntu@<ip>
sudo ./madar-infra/scripts/bootstrap-vps.sh <role>
```

The script finds its files next to itself, so a copy of `infra/` is all the VM needs. The first run:

- installs the packages (`iptables-persistent`, `netfilter-persistent`, `wireguard`, `rsync` and others) and Docker from `download.docker.com`;
- creates the `deploy` user (docker group, no password, SSH key only);
- installs `/etc/ssh/sshd_config.d/05-madar.conf`: no password logins and no root login for SSH;
- creates `/srv/madar/.env` from `example.env`, and **stops**:

```text
[bootstrap] error: created /srv/madar/.env from example.env. Replace every value with the real one, then re-run.
```

That is expected. The firewall hasn't changed yet.

Keep `~/madar-infra` on the VM. Break-glass and firewall changes run the script from it. Refresh it with the same `rsync` before every later run.

## 4. Fill the env file and re-run

`/srv/madar/.env` is owned by `deploy`, with mode `600`. Edit it with:

```bash
sudoedit /srv/madar/.env
```

Write one `KEY=value` per line, with no quotes and no trailing comments (Docker reads the values verbatim). Passwords are generated on the VM and never shown: not in chat, email, the repository or your scrollback. They are part of connection URLs, so they are hex (`openssl rand -hex 32`), which is URL-safe.

The two blocks below write the whole file in one go: they check they're on the right VM, generate or copy the passwords into shell variables inside a subshell, and write the file with `sudo tee`, which keeps its `deploy` owner and mode `600`. Use `sudoedit /srv/madar/.env` only for later changes.

**VPS-1.** Set `ACME` on the first line to your email, then paste the block on VPS-1:

```bash
(
set -eu
ACME='your-email-here'
ip -4 -o addr show | grep -q 'inet 10.1.0.97/' || { echo "STOP: this is not VPS-1"; exit 1; }
PG=$(openssl rand -hex 32)
RD=$(openssl rand -hex 32)
sudo tee /srv/madar/.env >/dev/null <<EOF
GHCR_OWNER=ahmedsaied94
VCN_IP=10.1.0.97
PEER_VCN_IP=10.1.0.118
VPS1_IP=<VPS1_IP>
ACME_EMAIL=$ACME
FIREBASE_PROJECT_ID=madar-sat
DEPLOY_SSH_PUBLIC_KEY=
POSTGRES_USER=madar
POSTGRES_PASSWORD=$PG
POSTGRES_DB=madar
REDIS_PASSWORD=$RD
DATABASE_URL=postgresql+asyncpg://madar:$PG@postgres:5432/madar
DATABASE_URL_SYNC=postgresql+psycopg://madar:$PG@postgres:5432/madar
REDIS_URL=redis://:$RD@redis:6379/0
MEDIA_BASE_URL=https://media.<VPS1_IP>.sslip.io
MEDIA_ROOT=/srv/media
MEDIA_REHOST_ALLOWED_HOSTS=pub-01ffc6064b9b435aa726a53a561a6f53.r2.dev,imgs.ysscores.com
CORS_ORIGINS=https://<PWA_HOST>,https://<FIREBASE_AUTH_DOMAIN>
CONTRACT_VERSION=1.0.0
CELERY_BROKER_URL=redis://:$RD@redis:6379/0
EOF
sudo ls -l /srv/madar/.env
sudo grep -cE '^[A-Z_]+=' /srv/madar/.env
)
```

It prints `-rw------- 1 deploy deploy … /srv/madar/.env` and `20`. What each value is:

| Key | Value |
| --- | --- |
| `GHCR_OWNER` | `ahmedsaied94` (the repository owner, lowercase) |
| `VCN_IP`, `PEER_VCN_IP` | `10.1.0.97`, `10.1.0.118` |
| `VPS1_IP` | `<VPS1_IP>` |
| `ACME_EMAIL` | Your email, for Let's Encrypt |
| `FIREBASE_PROJECT_ID` | `madar-sat` (as in `infra/firebase/.firebaserc`) |
| `DEPLOY_SSH_PUBLIC_KEY` | Leave it empty for now (`DEPLOY_SSH_PUBLIC_KEY=`). Step 8 fills it. |
| `POSTGRES_USER`, `POSTGRES_DB` | `madar`, `madar` |
| `POSTGRES_PASSWORD`, `REDIS_PASSWORD` | Two new passwords, generated by the block |
| `DATABASE_URL` | `postgresql+asyncpg://madar:<POSTGRES_PASSWORD>@postgres:5432/madar` |
| `DATABASE_URL_SYNC` | `postgresql+psycopg://madar:<POSTGRES_PASSWORD>@postgres:5432/madar` |
| `REDIS_URL` | `redis://:<REDIS_PASSWORD>@redis:6379/0` |
| `MEDIA_BASE_URL` | `https://media.<VPS1_IP>.sslip.io` |
| `MEDIA_ROOT` | `/srv/media` |
| `MEDIA_REHOST_ALLOWED_HOSTS` | The old app's media hosts, comma-separated. A scan of every URL in `../old_app/migration/data/` (the 2026-10-28 snapshot) finds two: the old R2 bucket (5,973 logos, commentator images and audio) and `imgs.ysscores.com` (6 team logos). Its other hosts, `www.livesoccertv.com` (match links) and `www.youtube.com` (reception videos), aren't media. A new host after a re-export shows up as `host_not_allowed` ([snapshot-load.md](snapshot-load.md)) |
| `CORS_ORIGINS` | `https://<PWA_HOST>,https://<FIREBASE_AUTH_DOMAIN>` ([firebase-hosting.md §3](firebase-hosting.md#3-firebaserc-and-the-hosts)) |
| `CONTRACT_VERSION` | `1.0.0` |
| `CELERY_BROKER_URL` | `redis://:<REDIS_PASSWORD>@redis:6379/0` (unused until the workers exist, D3) |

From D2 on, VPS-1's file also needs these keys (the deploy refuses to start without them):

| Key | Value |
| --- | --- |
| `ADMIN_JWT_SECRET` | `openssl rand -base64 48`, at least 32 bytes. Only `api-admin` uses it; a compose command fails at parse time without it ([secrets.md](secrets.md#where-they-live)) |
| `REDIS_HOMEBOX_PASSWORD` | A new password, on VPS-1 and the home box. It is the `homebox` Redis user's ([home-box.md](home-box.md)) |
| `HOME_BOX_WG_IP` | The home box's peer address on `wg0`; the firewall admits only it to Redis |
| `VPS2_VCN_IP` (GitHub variable) | VPS-2's VCN private IP, for the `deploy-vps2` job |
| VPS-2's `.env` | Its own file: `DATABASE_URL`, `DATABASE_URL_SYNC` and `REDIS_URL` on VPS-1's VCN IP, `CELERY_BROKER_URL`, `RAW_ROOT=/srv/raw`, `SATAIR_FIREBASE_PROJECT_ID`, `SATAIR_FIREBASE_API_KEY`, `SCRAPE_USER_AGENT`, `YSSCORES_FETCH_QUEUE`, `MEDIA_*` and `CORS_ORIGINS` ([workers.md](workers.md), [owner-actions.md](../owner-actions.md#lane-b2-ingestion-and-hosts)) |

The block leaves out the keys VPS-1 doesn't use: `IMAGE_TAG` and `HEALTHZ_FORCE_FAIL` (`deploy.sh` sets them), `FLOWER_BASIC_AUTH` (VPS-2's), and `DEV_POSTGRES_PORT` and `DEV_REDIS_PORT` (local only). Add the Firebase preview channel's origin to `CORS_ORIGINS` once `pwa.yml` has printed it ([firebase-hosting.md](firebase-hosting.md)).

**VPS-2** uses VPS-1's database and Redis passwords. First copy them from your machine, VPS-1 to VPS-2, without printing them. In the order above, VPS-1 has finished steps 2–9 before this: its step 4 re-run started the WireGuard hub (`wg0`, `10.8.0.1`), step 5 connected your device, and step 6 closed its public SSH. So VPS-1 is reached over WireGuard (`madar-vps1`), and VPS-2 still by its public IP:

```bash
ssh madar-vps1 "sudo grep -E '^(POSTGRES_PASSWORD|REDIS_PASSWORD)=' /srv/madar/.env" \
  | ssh madar-vps2-public "sudo sh -c 'umask 077; cat > /root/madar-shared.env'"
```

If you're setting up VPS-2 before VPS-1 reached step 6, VPS-1's public SSH is still open and WireGuard may not be up yet: use `madar-vps1-public` in place of `madar-vps1`.

Then paste this on VPS-2. It also generates Flower's password and deletes the copied file:

```bash
(
set -eu
ip -4 -o addr show | grep -q 'inet 10.1.0.118/' || { echo "STOP: this is not VPS-2"; exit 1; }
PG=$(sudo sed -n 's/^POSTGRES_PASSWORD=//p' /root/madar-shared.env)
RD=$(sudo sed -n 's/^REDIS_PASSWORD=//p' /root/madar-shared.env)
[ -n "$PG" ] && [ -n "$RD" ] || { echo "STOP: copy the passwords from VPS-1 first"; exit 1; }
FL=$(openssl rand -hex 16)
sudo tee /srv/madar/.env >/dev/null <<EOF
GHCR_OWNER=ahmedsaied94
VCN_IP=10.1.0.118
PEER_VCN_IP=10.1.0.97
VPS1_IP=<VPS1_IP>
POSTGRES_USER=madar
POSTGRES_PASSWORD=$PG
POSTGRES_DB=madar
REDIS_PASSWORD=$RD
DATABASE_URL=postgresql+asyncpg://madar:$PG@10.1.0.97:5432/madar
DATABASE_URL_SYNC=postgresql+psycopg://madar:$PG@10.1.0.97:5432/madar
REDIS_URL=redis://:$RD@10.1.0.97:6379/0
MEDIA_BASE_URL=https://media.<VPS1_IP>.sslip.io
MEDIA_ROOT=/srv/media
MEDIA_REHOST_ALLOWED_HOSTS=pub-01ffc6064b9b435aa726a53a561a6f53.r2.dev,imgs.ysscores.com
CORS_ORIGINS=https://<PWA_HOST>,https://<FIREBASE_AUTH_DOMAIN>
CONTRACT_VERSION=1.0.0
CELERY_BROKER_URL=redis://:$RD@10.1.0.97:6379/0
FLOWER_BASIC_AUTH=admin:$FL
EOF
sudo shred -u /root/madar-shared.env
sudo ls -l /srv/madar/.env
sudo grep -cE '^[A-Z_]+=' /srv/madar/.env
)
```

It prints the same owner and mode, and `18`. The differences from VPS-1:

| Key | Value |
| --- | --- |
| `VCN_IP`, `PEER_VCN_IP` | `10.1.0.118`, `10.1.0.97` |
| `DATABASE_URL`, `DATABASE_URL_SYNC` | As on VPS-1, with host `10.1.0.97` instead of `postgres` |
| `REDIS_URL`, `CELERY_BROKER_URL` | `redis://:<REDIS_PASSWORD>@10.1.0.97:6379/0` |
| `FLOWER_BASIC_AUTH` | `admin:<a new password>` |

VPS-2's block leaves out `ACME_EMAIL`, `FIREBASE_PROJECT_ID`, `DEPLOY_SSH_PUBLIC_KEY`, `IMAGE_TAG`, `HEALTHZ_FORCE_FAIL` and the `DEV_` lines. The script then warns `DEPLOY_SSH_PUBLIC_KEY is missing or invalid`, which is expected: nothing deploys to VPS-2 yet. VPS-2 holds the same database and Redis passwords as VPS-1: rotate them together ([secrets.md](secrets.md)).

**Check `VCN_IP` and `PEER_VCN_IP` twice.** The script refuses the obvious placeholders (`example`, `changeme`, `192.0.2.`), but `example.env`'s `10.0.0.10` and `10.0.0.20` look like real VCN addresses and pass. A wrong `PEER_VCN_IP` opens PostgreSQL and Redis to whichever VM holds that address.

Then re-run the script:

```bash
sudo ./madar-infra/scripts/bootstrap-vps.sh <role>
```

It checks the required keys, warns about any value still left from `example.env`, and creates the `/srv` folders. On VPS-1 it also lays out the admin releases: `/srv/admin/releases/placeholder/` holds the bootstrap page and `/srv/admin/current` is a relative symlink to it, which CI's deploy repoints atomically ([deploy-and-rollback.md "The admin deploy"](deploy-and-rollback.md#the-admin-deploy)). An older host with a flat `/srv/admin/index.html` is migrated once, and the script refuses a non-empty `/srv/admin/current` rather than deleting it. It also installs and enables the host's backup timers as root (B2-R1-4): they start on the next trigger, or straight away once the backup keys (`RESTIC_*`, `B2_ACCOUNT_*`, and on VPS-1 the `RCLONE_CONFIG_OCI_*` keys) are in `.env` — the script says which ones are still missing.

Re-run it on **VPS-1 before the first D2 deploy**: `deploy.sh` refuses to render the Redis ACL without
gid 999's group, and the script is what creates it and makes `deploy` a member (`ensure_redis_acl_group`).
An already-provisioned host needs nothing else; the re-run corrects `/srv/madar/redis`'s group too (B2-R2-10). On VPS-1 it also sets up the WireGuard hub (it prints `hub public key: …`) and makes Docker start after `wg0`. It then asks:

```text
[bootstrap] Have you logged in through this host's OCI serial console? Type 'serial console tested' to close public SSH:
```

Press Enter. Public SSH closes in step 6, once you have a way in over WireGuard. It then applies the firewall with public SSH still open, restarts Docker, and prints the active and persisted rules from `check-firewall.sh`. It ends with `done: <role> is bootstrapped`.

Check what it did:

```bash
sudo ls -l /srv/madar/.env                         # -rw------- deploy deploy (/srv/madar is 750, so sudo)
sudo ls -ld /srv/backup /srv/secrets               # VPS-2: drwx------ 10001 10001 (the backup and worker user)
sudo ls -l /srv/admin/current                      # VPS-1: current -> releases/placeholder
systemctl list-timers 'backup-*' --no-pager        # the role's timers, enabled by the script
sudo iptables -S INPUT | grep -- '--dport 22'      # VPS-1: the wg0 rule and the public rule; VPS-2: -s 10.1.0.97/32 and the public rule
ip -4 -o addr show wg0                             # VPS-1 only: 10.8.0.1/24
systemctl show docker -p After | grep -o 'wg-quick@wg0.service'   # VPS-1 only
```

Nothing serves yet. Caddy, PostgreSQL and Redis start with the first infra sync (README.md stage 5).

## 5. Your WireGuard peer

VPS-1 only. On VPS-1:

```bash
sudo ./madar-infra/scripts/wg-add-peer.sh <your-device>    # for example owner-laptop
```

It writes the client config to `/root/wireguard-peers/<your-device>.conf`. That file holds the device's private key: move it to the device, then delete it on the VM. [private-network.md "Add a peer"](private-network.md#add-a-peer) has the steps for a laptop and a phone.

Connect, then open a **second** SSH session, over WireGuard:

```bash
ssh ubuntu@10.8.0.1
sudo wg show wg0          # your peer shows a "latest handshake"
```

**On VPS-2**, there is no peer to add. Instead, check that the jump through VPS-1 works before step 6 closes VPS-2's public SSH:

```bash
ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118 true && echo jump works
```

It needs VPS-1 through step 5, your tunnel up, and the `10.1.0.97/32` TCP 22 rule from step 1.

## 6. SSH over WireGuard only

On VPS-1, in the WireGuard session:

```bash
sudo ./madar-infra/scripts/bootstrap-vps.sh vps1 --serial-console-tested
```

On VPS-2, through the jump:

```bash
ssh -J ubuntu@10.8.0.1 ubuntu@10.1.0.118
sudo ./madar-infra/scripts/bootstrap-vps.sh vps2 --serial-console-tested
```

- The flag records your confirmation in `/etc/madar/serial-console-tested`, so later runs don't need it.
- On VPS-1 the script also needs a WireGuard peer that has completed a handshake since `wg0` came up. Without one it keeps public SSH open and says `no WireGuard peer has connected yet`.
- It then re-renders the firewall without public TCP 22 and restarts Docker. Your open sessions survive.

Check:

```bash
sudo iptables -S INPUT | grep -- '--dport 22'   # VPS-1: only "-i wg0"; VPS-2: only "-s 10.1.0.97/32"
```

The script makes this decision again on **every** run. On VPS-1, a run when no peer has a handshake (right after a reboot, or from the serial console with nobody connected) opens public SSH again. Step 7 is what keeps it shut then.

## 7. Close TCP 22 in the security list

Once both VMs are through step 6, remove the `<your public ip>/32` TCP 22 rule from the security list. Keep the `10.1.0.97/32` TCP 22 rule: it is the jump to VPS-2. Then, **off** WireGuard:

```bash
nc -vz -w 5 <VPS1_IP> 22     # times out
nc -vz -w 5 <VPS2_IP> 22     # times out
```

## 8. Deploy peer and keys

VPS-1 only. CI deploys over WireGuard as the `deploy` user, with its own peer and SSH key. This sets up the three secrets it needs. Run the first part on your machine:

```bash
d=$(mktemp -d) && chmod 700 "$d"
ssh-keygen -t ed25519 -N '' -C deploy@ci -f "$d/deploy"
cat "$d/deploy.pub"          # the public half, for VPS-1's .env
```

On VPS-1, over WireGuard:

```bash
sudoedit /srv/madar/.env                     # DEPLOY_SSH_PUBLIC_KEY=<the deploy.pub line>
sudo ./madar-infra/scripts/bootstrap-vps.sh vps1   # adds it to /home/deploy/.ssh/authorized_keys
sudo ./madar-infra/scripts/wg-add-peer.sh ci       # the CI peer
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub   # note this fingerprint
```

Back on your machine, with your tunnel up. `DEPLOY_KNOWN_HOSTS` must hold **both** host keys,
because `deploy-vps2` jumps from VPS-1 to VPS-2:

```bash
R=AhmedSaied94/madar-sat
ssh-keyscan -t ed25519 10.8.0.1 > "$d/known_hosts"
# `ssh-keyscan` has no jump option, and ssh looks the key up by the address it connects to, so scan
# VPS-2 from VPS-1 and keep the VCN IP (ssh-config.sh sets `HostName $VPS2_VCN_IP`, no alias).
ssh ubuntu@10.8.0.1 ssh-keyscan -t ed25519 "$VPS2_VCN_IP" >> "$d/known_hosts"
ssh-keygen -lf "$d/known_hosts"              # two lines: 10.8.0.1 and the VPS-2 VCN IP
ssh -i "$d/deploy" -o IdentitiesOnly=yes -o UserKnownHostsFile="$d/known_hosts" deploy@10.8.0.1 true && echo deploy login works

gh secret set DEPLOY_SSH_KEY -R "$R" < "$d/deploy"
gh secret set DEPLOY_KNOWN_HOSTS -R "$R" < "$d/known_hosts"
ssh ubuntu@10.8.0.1 sudo cat /root/wireguard-peers/ci.conf | gh secret set WG_CI_CONFIG -R "$R"
ssh ubuntu@10.8.0.1 sudo shred -u /root/wireguard-peers/ci.conf
shred -u "$d/deploy" && rm -r "$d"
gh secret list -R "$R"                       # the three secrets, plus FIREBASE_SERVICE_ACCOUNT
```

- `gh secret set … < file` reads the value from the file, so it never shows on screen.
- The `ci` config's `Endpoint` is `<VPS1_IP>:51820` and its `AllowedIPs` is `10.8.0.1/32`.
- `bootstrap-vps.sh` only ever **adds** keys to `authorized_keys`. Replacing a key: [deploy-and-rollback.md "Replacing a deploy key"](deploy-and-rollback.md#replacing-a-deploy-key).
- The deploy key has no forced command: whoever holds it and the `ci` config gets a shell as `deploy`, which is in the docker group. Keep both only in GitHub.

## 9. Reboot check

On each VM, from a WireGuard session (through the jump for VPS-2):

```bash
sudo reboot
```

After a minute, reconnect and check:

```bash
sudo ./madar-infra/scripts/check-firewall.sh --role vps1   # or vps2; exit 0: "IPv4: active rules match /etc/iptables/rules.v4", and the same for IPv6
systemctl is-active netfilter-persistent docker # active, active
systemctl is-active wg-quick@wg0                # VPS-1 only: active
sudo wg show wg0                                # VPS-1 only: your peer, with a fresh handshake once you reconnect
```

`check-firewall.sh` exits 1 and prints a diff if the live rules differ from the persisted ones. See [firewall-changes.md](firewall-changes.md#if-it-fails).

## Resize an instance

For VPS-1 when the load test fails on CPU (D5 FR-060). Run it only once step 1 confirms the shape stays free.

**1. Check the allowance.** In the console, open Governance & Administration → Tenancy Management → Limits, Quotas and Usage, with service **Compute** and your availability domain. Read **Cores for Standard.A1 based VM instances** and **Memory for Standard.A1 based VM instances**: the limit and how much is used. Also check the Always Free page in Oracle's documentation for the A1 allowance on the day you do this. SD §2 assumes 2 OCPU in total, so a larger number here is what changes the plan.

Go on only if both say the total stays inside the allowance. VPS-2 keeps 1 OCPU, so a 4 OCPU allowance leaves VPS-1 at most 3. If the limit or the free label is unclear, stop and tell B2 to build the Caddy cache instead (D5 T062).

**2. Resize.** Compute → Instances → `madar-vps1` → Edit → Edit shape. Keep `VM.Standard.A1.Flex`, set **Number of OCPUs** to 2 or 3, and keep 6 GB: the load test ran out of CPU, not memory. Before saving, check that the page still shows the shape as Always Free-eligible and the estimate shows no charge. Saving reboots the VM.

**What restarts:** VPS-1 is down for a few minutes, so the public API, the admin and the WireGuard hub are all unreachable, and VPS-2 can't be reached through it. Do this away from a live match. Docker brings its services back by themselves. VPS-2's workers lose PostgreSQL and Redis until then, and retry.

**3. Give the API the cores.** Set the workers to the core count plus one, in `/srv/madar/.env` on VPS-1, and recreate the service. That means 3 at 2 OCPU and 4 at 3 OCPU, at about 100 MB each, which the memory plan in SD §7.1 can hold:

```bash
ssh madar-vps1
sudoedit /srv/madar/.env    # API_PUBLIC_WORKERS=3
sudo -u deploy sh -c 'cd /srv/madar/infra && IMAGE_TAG=$(cat /srv/madar/current_tag) docker compose --env-file /srv/madar/.env -f compose/vps1.yml up -d api-public'
```

**4. Check afterwards.**

```bash
ssh madar-vps1 'nproc; free -h | head -2'                                    # the new core count, 6 GB
ssh madar-vps1 'sudo -iu deploy docker compose -p madar ps --format "{{.Service}} {{.Status}}"'   # all healthy
ssh madar-vps1 'curl -fsS http://127.0.0.1:8000/healthz'
ssh madar-vps1 'sudo -iu deploy docker compose -p madar top api-public | grep -c "gunicorn"'     # the workers plus the master
ssh madar-vps2 'sudo -iu deploy docker compose -p madar ps --format "{{.Service}} {{.Status}}"'   # the workers came back
```

The next day, open Billing → Cost Analysis and confirm the instance cost nothing. Then tell B1 to re-run the [load test](load-testing.md), and update SD §2 and §7.1 with the allowance and the shape.

**To go back:** edit the shape again, which reboots again, and set `API_PUBLIC_WORKERS=2`.

## 10. Record

For each VM:

- **Values:** the reserved and private IPs are recorded (2026-10-29) in the hosts table in [README.md](README.md), in "The two VMs" above, and in every runbook command. If one changes, replace it everywhere (`git grep -n '<old ip>' -- docs infra`). IPs and hostnames aren't secrets. Keys and passwords never go in the repository.
- **Setup time:** from step 1 until step 6 closed public SSH.
- **Firewall:** paste the output of these into research.md R12, under this VM:

  ```bash
  sudo diff /etc/iptables/rules.v4.oci-original /etc/iptables/rules.v4   # Oracle's rules vs the rendered ones
  sudo iptables -S
  ```

- **Serial console:** whether step 2 worked on A1.

When both VMs are through step 9, tick T064 in `specs/001-d01-foundation/tasks.md`.
