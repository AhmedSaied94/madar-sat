# Uptime Kuma

The monitoring service on VPS-2: how to reach it, the exact monitors to create, and what each one
means (Lane B2's T086, T084, research R20).

Kuma runs as `uptime-kuma` in `infra/compose/vps2.yml`, image `louislam/uptime-kuma:1`, data in
`/srv/kuma`. It is published on **VPS-2's VCN address only** (`:3001`), the firewall accepts that port
from VPS-1 alone (VPS-2's `DOCKER-USER` rule, and the subnet's security list: `10.1.0.97/32` TCP 3001,
[provision-host.md step 1.7](provision-host.md#1-reserve-the-ip-and-create-the-vm); without it `https://kuma.…` answers 502),
and VPS-1's Caddy serves it over WireGuard at:

**`https://<KUMA_HOST>`** (connected to `wg0`; Caddy's internal CA, which your device
already trusts for `https://10.8.0.1` — [private-network.md](private-network.md#install-the-admin-ca-root)).

Kuma has no config file, so the monitors below are created once in its UI. They live in `/srv/kuma`,
which is not backed up by the nightly jobs; recreating them from this page takes ten minutes.

## 1. The first account

1. Connect to WireGuard, open the URL above.
2. Create the admin user. Use the password manager: this account can see every monitor and its
   notification settings.
3. **Settings → General**: set the timezone to `Africa/Cairo`, and the primary base URL to the
   address above.

## 2. The Telegram notification

**Settings → Notifications → Setup Notification → Telegram**:

- **Bot Token**: `TELEGRAM_BOT_TOKEN` from VPS-2's `.env`.
- **Chat ID**: `TELEGRAM_CHAT_ID` from the same file.
- **Default**: on; **Apply on all existing monitors**: on.

Press **Test**. The same chat receives the importer alerts ([source-alerts.md](source-alerts.md)), so
one chat is the whole incident feed.

## 3. HTTP monitors (four)

| Name | URL | Interval | What it proves |
| --- | --- | --- | --- |
| `api-public` | `https://api.<VPS1_IP>.sslip.io/healthz` | 60 s | Caddy, the public app and the database connection |
| `media` | `https://media.<VPS1_IP>.sslip.io/logo/<xx>/<hash>.webp` (a real file) | 5 min | Caddy's media root and the disk |
| `pwa` | `https://<FIREBASE_PROJECT_ID>.web.app/` | 5 min | Firebase Hosting serves the PWA on the live channel. Firebase answers "Site Not Found" (404) until the first `web-v*` release deploys it |
| `pwa-mirror` | `https://app.<VPS1_IP>.sslip.io/release-check.txt` | 5 min | Caddy serves the mirror and the release job wrote the current hash (D4 T047). A 404 means no release has been copied yet |

Use a real, existing file for `media`: media is content-addressed under `/srv/media/{logo,photo,audio}/<xx>/`,
so pick one with `find /srv/media/logo -type f -name '*.webp' | head -1` on VPS-1. A 404 is red
forever otherwise. **Accepted status codes**: `200-299`. Turn on the Telegram notification on each
monitor (**Edit → Notifications**); Kuma alerts only on monitors that have it switched on.

**State on 2026-11-03.** All four exist. `api-public` and `media` are up with the notification on.
`pwa` and `pwa-mirror` are **paused with the notification off**, because both answer 404 until the
first PWA release. After the `web-v0.1.0` release job passes, open each one, **Edit**, switch the
notification on, **Save**, then **Resume**; both should turn green.

`/srv/kuma` belongs to root: the image's entrypoint chowns `/app/data` to `PUID:PGID`, root by default,
on every start. `bootstrap-vps.sh` creates it that way and `deploy.sh` expects it.

## 4. Push monitors (seven)

Each `heartbeat-*` beat entry pings a monitor every 5 minutes, so a dead worker queue, a paused
`beat` or a stopped backup turns the monitor red after its heartbeat interval. Create each as
**Push**, then copy its **token** (not its URL) into VPS-2's (or VPS-1's) `/srv/madar/.env`, in the
form below.

| Monitor | Heartbeat interval | Env variable | Host | Means |
| --- | --- | --- | --- | --- |
| `celery-maintenance` | 300 s | `KUMA_PUSH_URL_MAINTENANCE` | VPS-2 | `worker-maintenance` and `beat` are alive |
| `celery-imports` | 300 s | `KUMA_PUSH_URL_IMPORTS` | VPS-2 | `worker-imports` is alive (ingest, schedule_fetch) |
| `celery-notifications` | 300 s | `KUMA_PUSH_URL_NOTIFICATIONS` | VPS-2 | `worker-notify` is alive (dispatcher, scheduler) |
| `scrape-home` | 300 s | `KUMA_PUSH_URL_SCRAPE_HOME` | VPS-2 | the home box's `scrape_home` queue is draining: `down` (with the count) once more than `SCRAPE_HOME_BACKLOG_MAX` (default 6) fetches wait |
| `backup-db` | every 25 h | `KUMA_PUSH_URL_BACKUP_DB` | VPS-2 | last night's database backup succeeded |
| `backup-media` | every 25 h | `KUMA_PUSH_URL_BACKUP_MEDIA` | VPS-1 | last night's media mirror succeeded |
| `backup-media-weekly` | every 8 days | `KUMA_PUSH_URL_BACKUP_MEDIA_WEEKLY` | VPS-1 | Sunday's restic snapshot succeeded |

The home box cannot reach Kuma (it talks to Redis only), so `scrape-home` is pushed from VPS-2: the
`scrape-home-backlog` beat entry runs `ops.scrape_home_backlog` on `worker-imports`, which reads the
length of `celery:scrape_home`. A worker that hangs with its container up shows here as a growing
queue ([home-box.md](home-box.md#when-the-worker-hangs)).

Set each heartbeat interval a little longer than the job's own period (5 min → 300 s; nightly →
25 h), so one delayed run does not alert. The interval is what makes a silent job detectable: the
push says "I ran", so no push at all is the alarm.

### The push URL on each host

Kuma shows a push monitor's URL as
`https://<KUMA_HOST>/api/push/<token>?status=up&msg=OK&ping=`. Do not paste it: that
address exists on `wg0` only, VPS-2 is not a WireGuard peer, and the backup image does not trust
Caddy's internal CA. The token is the last path segment, between `/api/push/` and the `?`. Write
the host-reachable URL with that token and **no query**; the workers and the backup scripts add
`status` and `msg` themselves (`up`, or `down` with the error).

| Host | Variables | Value in `/srv/madar/.env` |
| --- | --- | --- |
| VPS-2 | `KUMA_PUSH_URL_MAINTENANCE`, `_IMPORTS`, `_NOTIFICATIONS`, `_SCRAPE_HOME`, `_BACKUP_DB` | `http://uptime-kuma:3001/api/push/<token>` (Kuma's name in VPS-2's Compose network, which the workers and the backup container share) |
| VPS-1 | `KUMA_PUSH_URL_BACKUP_MEDIA`, `_BACKUP_MEDIA_WEEKLY` | `http://<VPS2_VCN_IP>:3001/api/push/<token>` (over the VCN; VPS-2's firewall accepts port 3001 from VPS-1 only) |

The backup scripts cut anything after a `?` before they append `status`, so a pasted Kuma URL would
still report `down` correctly; the form above is the one that is also reachable. A backup script with
an **empty** `KUMA_PUSH_URL_BACKUP_*` refuses to start (D4 T030), so a monitor that never turns green
is the first sign the value was never filled in.

After writing the seven values into `/srv/madar/.env` on each host, restart the services that read them:
`worker-maintenance`, `worker-imports` and `worker-notify` on VPS-2, and `worker-media` on VPS-1 for
the media ones (the backup scripts read them from `/srv/madar/.env` at run time, so the timers need
nothing). The runbook step is
[imports-and-sources.md](imports-and-sources.md#switch-where-a-source-fetches), with
`worker-media` added for VPS-1:

```sh
sudo -u deploy sh -c 'cd /srv/madar/infra && IMAGE_TAG=$(cat /srv/madar/current_tag) docker compose --env-file /srv/madar/.env -f compose/vps1.yml up -d worker-media'
```

Keep it on one line, with single quotes, the `cd` and without `-i`: `deploy` cannot read `ubuntu`'s
home, where the command would otherwise start (`stat .: permission denied`); `current_tag` is
readable by `deploy` only, so the `$(cat …)` must run in `deploy`'s shell (expanded in `ubuntu`'s, it reads nothing and
Compose asks GHCR for the tag `none`, which fails as `unauthorized`), and `sudo -i` re-escapes the
command, so a `\` line break reaches Docker as part of the argument (`unknown docker command`).

## 5. Check

1. Every monitor is green within one heartbeat interval.
2. `systemctl list-timers 'backup-*' --no-pager` on both hosts shows the next run. To prove the
   backup URLs without waiting for 03:00, run one by hand
   ([backups.md](backups.md#run-one-by-hand)); its monitor turns green within seconds.
3. Prove one: stop a worker for 10 minutes and watch the matching push monitor go red, then start
   it again (T084).

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar stop worker-notify'
# ... wait ten minutes; celery-notifications goes red and Telegram fires ...
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar start worker-notify'
```

## What each alert means, and what to do

| Alert | First check | Then |
| --- | --- | --- |
| `api-public` down | `docker compose ps api-public` on VPS-1, then `curl -fsS http://127.0.0.1:8000/healthz` | [deploy-and-rollback.md](deploy-and-rollback.md#roll-back) if the last deploy is the cause |
| `media` down | `ls /srv/media/logo/` and Caddy's log | the disk is full: `df -h /srv` |
| `pwa` / `pwa-mirror` down | the Firebase console, and `ls /srv/app-mirror` | [firebase-hosting.md](firebase-hosting.md) |
| `celery-*` down | `docker compose ps` on VPS-2 and `journalctl -u docker` | `docker compose up -d <service>`; if `beat` is the dead one, run it by hand before the next slot |
| `scrape-home` down with a count | on the box: `docker inspect --format '{{.State.Health.Status}}' madar-home-box-worker-scrape-1` and `sudo wg show wg-homebox` | [home-box.md](home-box.md#when-the-worker-hangs); the update timer restarts an unhealthy worker within 10 minutes |
| `scrape-home` silent (no push) | `worker-imports` on VPS-2, as for `celery-*` | the check itself runs there, not on the box |
| `backup-db` down | `systemctl status backup-db.service` and its journal | [backups.md](backups.md#run-one-by-hand) |
| `backup-media*` down | `systemctl status backup-media.service` on VPS-1 | [backups.md](backups.md#run-one-by-hand) |

## Reach it without WireGuard

You cannot: that is deliberate (constitution V). Use the jump host instead:

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" 'curl -fsS http://127.0.0.1:3001/api/status-page/heartbeat/1 | head -c 200'
```

## Backups of Kuma itself

`/srv/kuma` is not in the nightly jobs. Once the monitors above are created, copy it once and keep
the copy in the password manager or on the owner's machine:

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy tar -czf /srv/backup/kuma-config-$(date -u +%Y%m%d).tgz -C /srv kuma'
scp -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP":/srv/backup/kuma-config-*.tgz ~/
```
