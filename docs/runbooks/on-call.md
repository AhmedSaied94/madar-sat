# On-call

What to do when Telegram or Uptime Kuma says something is wrong, in the order that finds the cause
fastest (D4 T038, FR-013). Every row points at the runbook that owns the fix instead of copying it,
so this page stays one screen.

It is written for a public launch: the API is reachable by strangers, the PWA is served from the
mirror, and imports run unattended. None of the fixes below is destructive; the destructive ones
(restoring a database, rebooting a host) live in their own runbooks.

## Before you start

- WireGuard, and the values from `docs/runbooks/hosts.env`:

  ```bash
  set -a; . docs/runbooks/hosts.env; set +a     # VPS1_IP, VPS2_IP, KUMA_HOST, PWA_HOST
  ssh ubuntu@10.8.0.1                           # VPS-1; VPS-2 is `ssh -J ubuntu@10.8.0.1 ubuntu@$VPS2_VCN_IP`
  ```

- The two shells the commands below assume:

  ```bash
  # VPS-1
  sudo -iu deploy && cd /srv/madar/infra
  export IMAGE_TAG=$(cat /srv/madar/current_tag 2>/dev/null || echo none)
  dc() { docker compose --env-file /srv/madar/.env -f compose/vps1.yml "$@"; }

  # VPS-2
  sudo -iu deploy && cd /srv/madar/infra
  export IMAGE_TAG=$(cat /srv/madar/current_tag 2>/dev/null || echo none)
  dc() { docker compose --env-file /srv/madar/.env -f compose/vps2.yml "$@"; }
  ```

- The Kuma UI: `https://<KUMA_HOST>` over WireGuard ([uptime-kuma.md](uptime-kuma.md)). Hovering a
  monitor shows its last ping's `msg`, which is where the importer and the backup scripts put their
  own words.

## 1. Read the alert first

| Message | Comes from | Means |
| --- | --- | --- |
| `🔴 <name> is down` (Telegram, from Kuma) | Uptime Kuma | The monitor's own check failed, or a push monitor stopped pushing. The interval is what told it: an HTTP monitor fails on its next poll, a push monitor after 300 s (workers) or 25 h (backups). |
| `⛔ المصدر ‹name› متوقف بعد ‹N› محاولات فاشلة` | `app.adapters.alerts` | The breaker opened: N consecutive failed runs ([source-alerts.md](source-alerts.md#-المصدر-name-متوقف-بعد-n-محاولات-فاشلة)). |
| `⚠️ المصدر ‹name› لم يجد أي عناصر` | `app.adapters.alerts` | A run succeeded but found nothing, at most once per source per Cairo day ([source-alerts.md](source-alerts.md#️-المصدر-name-لم-يجد-أي-عناصر)). |

Kuma is the only thing that fires when a whole host or queue is silent; the Telegram messages only
cover one source. If both arrive, work the Kuma one first: a dead worker explains the sources it
served.

## 2. Where the logs are

| What | Command |
| --- | --- |
| The public API | `dc logs --tail 200 api-public` (VPS-1); `api-admin`, `caddy`, `worker-media` the same way |
| Caddy's access log and its errors | `docker logs --tail 200 madar-caddy-1` |
| The import workers and `beat` | `dc logs --tail 200 worker-imports beat` (VPS-2); also `worker-scrape`, `worker-maintenance`, `worker-notify` |
| The home box's scrape worker | `sudo docker compose --env-file /srv/madar/.env -f /srv/madar/infra/compose/home-box.yml logs --tail 200 worker-scrape` ([home-box.md](home-box.md#start-and-check-the-worker)) |
| The backups | `journalctl -u backup-db.service -n 50` on VPS-2; `journalctl -u 'backup-media*' -n 50` on VPS-1 |
| The backup timers | `systemctl list-timers 'backup-*' --no-pager` on either host |
| Whether imports actually ran | `dc exec worker-imports python -m app.adapters.report runs --hours 48` ([§3](#3-the-alerts)) |

Every service logs JSON with a `ts`, and the importers add `source` and `run`. `docker compose logs
--since 2h` narrows a window; `grep '"level": "ERROR"'` finds the failures.

## 3. The alerts

| Alert | What it means | First check | Fix |
| --- | --- | --- | --- |
| `api-public` | Caddy, the public app or the database connection is down; every app read fails | `curl -fsS https://api.$VPS1_IP/healthz` and `dc ps` on VPS-1; the log line names the failing dependency | [deploy-and-rollback.md](deploy-and-rollback.md#roll-back) if the last deploy did it, [workers.md](workers.md) if PostgreSQL or Redis is unhealthy |
| `media` | Caddy's `/srv/media` or the disk; channel logos and match images stop loading | `curl -sI https://media.$VPS1_IP/logos/<a known file>`; `df -h /srv/media` | [workers.md](workers.md#worker-media) for the rehoster, [backups.md](backups.md) for the disk |
| `pwa` | Firebase Hosting does not serve the live shell | `curl -sI https://<PWA_HOST>/index.html` | [pwa-release.md](pwa-release.md#roll-back-the-live-channel): the previous release is one Firebase rollback away |
| `pwa-mirror` | Caddy's `/srv/app-mirror` or `release-check.txt` is missing, so first loads fall back to Firebase (the Spark quota) | `curl -s https://app.$VPS1_IP/release-check.txt` and compare with `release.json` on the live channel | [pwa-release.md](pwa-release.md#check-the-mirror); if the folder is gone, re-run the release job for that tag |
| `celery-maintenance`, `celery-imports`, `celery-notifications` | That queue has no worker, so its tasks pile up in Redis | `dc ps` on VPS-2, then `dc logs --tail 100 <the worker>` | [workers.md](workers.md#deploy-vps-2); a stopped `beat` alone shows as `celery-maintenance` and nothing scheduled |
| `backup-db` | Last night's database backup did not report | `systemctl list-timers 'backup-*'`; `journalctl -u backup-db.service -n 50`; `restic snapshots --tag db --latest 3` | [backups.md](backups.md#run-one-by-hand). A backup with no push URL now refuses to run, so an empty `KUMA_PUSH_URL_BACKUP_DB` is the first thing to check |
| `backup-media`, `backup-media-weekly` | The media mirror or the weekly snapshot did not report | The same journal check on VPS-1, plus `/srv/media` free space | [backups.md](backups.md#run-one-by-hand) |
| `⛔ المصدر ‹name›` | The source failed N times in a row and is paused | `import_runs` for that source, then the run's `log` | [source-alerts.md](source-alerts.md) (the breaker section): fix or wait, then resume in A13. If it is a blocked host, [§4](#4-a-source-is-blocked) |
| `⚠️ المصدر ‹name›` | A run succeeded and found nothing | The same `report runs` output, and the source's page by hand | [source-alerts.md](source-alerts.md) (the zero-items section): a layout change is a parser fix with a saved-page test |
| A slot is missing in `report runs` | The schedule fired but no run row exists: the queue had no consumer, or the fetch never reached `ingest` | `dc logs worker-imports beat` for `scheduled`/`skipped`, and whether it names `scrape_home` | [§4](#4-a-source-is-blocked) |

The report is the evidence for the last two rows:

```bash
dc exec worker-imports python -m app.adapters.report runs --hours 48       # exits 1 on a gap
dc exec worker-imports python -m app.adapters.report coverage --days 4
```

A slot is `missing` when no `import_runs` row started within five minutes of it, and `manual` when
an audited «تشغيل الآن» or resume queued that run. Both are explained in [imports-and-sources.md](imports-and-sources.md#read-what-a-run-did).

## 4. A source is blocked

"Blocked" means the source answers 403/429 or a captcha from the machine that fetched it. The fix is
to move the fetch, not to raise the retry count:

| Where | How | When |
| --- | --- | --- |
| To the home box (default) | `YSSCORES_FETCH_QUEUE=scrape_home`, `LIVESOCCERTV_FETCH_QUEUE=scrape_home` in `.env`, both hosts' workers healthy, the box's timer running ([home-box.md](home-box.md)) | ysscores only answers a residential address (R21) |
| To VPS-2 | The same two variables set to `scrape` in VPS-2's `.env`, then `dc up -d worker-scrape` | The box is offline and the source tolerates a datacenter IP |
| To the bridge | Leave `legacy` (the Sat Air bridge) enabled; it needs nothing on the home box | The source is down and the fixtures are already in Sat Air |

The variables and the per-source commands are in
[imports-and-sources.md](imports-and-sources.md#switch-where-a-source-fetches).

While a fetch queue has no consumer, the tasks expire after two hours and nothing is replayed: a
gap in `report runs` is the visible result. Restore the consumer, then start one run by hand from A13
to close it.

## 5. A mirror alert

`pwa-mirror` red usually means one of three things, in this order:

```bash
curl -sS https://app.$VPS1_IP/release-check.txt              # the hash the release job wrote
curl -sSI -H 'Origin: https://<FIREBASE_PROJECT_ID>.web.app' \
  https://app.$VPS1_IP/r/<hash>/main.dart.js                 # 200, immutable, CORS, content-encoding
curl -sS https://<PWA_HOST>/release.json                     # the hash the live shell asks for
```

- **`release-check.txt` is stale or 404:** the release job's copy step failed; re-run it for that tag
  (`gh run rerun <id>`), or copy it by hand as [pwa-release.md](pwa-release.md#check-the-mirror) shows.
- **`main.dart.js` 404s:** the folder was pruned or never copied. The live shell still names the
  hash, so restore the folder (re-run the release job) rather than rolling Firebase back.
- **The two hashes differ:** the mirror is ahead of Firebase or behind it. If the live shell names a
  hash the mirror has, users still work (Firebase serves the files). Otherwise roll the live channel
  back to the previous release ([pwa-release.md](pwa-release.md#roll-back-the-live-channel)).

An empty `release.json` mirror value means the build was a preview (own origin); that is not an
alert.

## Check

- `curl -fsS https://api.$VPS1_IP/healthz` answers `{"db": "ok", "redis": "ok"}`.
- `dc ps` on both hosts shows every service `healthy`, and exactly one `beat` on VPS-2.
- `report runs --hours 6` exits 0, or every flagged slot has a line in the incident.
- The Kuma monitor you started from is green, and its `msg` is today's.

## If it fails

| Symptom | Do |
| --- | --- |
| Telegram is silent while Kuma is red | Kuma's notification is unset or failing: [uptime-kuma.md §2](uptime-kuma.md#2-the-telegram-notification). A red monitor with no Telegram is the dangerous state |
| No Kuma alert at all, and the host is unreachable | [break-glass.md](break-glass.md); Oracle may have stopped the instance |
| A push monitor goes red every night at the same minute | The job never runs: `systemctl list-timers` and `journalctl -u <unit>`; the timers are installed by the bootstrap, not by a deploy ([backups.md](backups.md#check-last-nights-backup)) |
| A source stays paused after a fix | Resume it in A13 ([imports-and-sources.md](imports-and-sources.md#pause-resume-and-the-breaker)); the breaker does not clear itself |
| The mirror is unreachable from outside but fine on the host | The certificate or the firewall: [tls-certificates.md](tls-certificates.md), then [exposure-check.md](exposure-check.md) |
