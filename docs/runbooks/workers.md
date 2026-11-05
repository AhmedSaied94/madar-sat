# Workers: VPS-2, `worker-media`, and the VPS-2 deploy

The Celery processes of SD §6.1, the one `beat`, and the deploy that keeps them current
(FR-024, FR-029, research R20 and R22). The schedule each task runs on is in
[imports-and-sources.md](imports-and-sources.md); the fetch host is in [home-box.md](home-box.md).

## What runs where

| Host | Service | Command | Health |
| --- | --- | --- | --- |
| VPS-2 | `worker-imports` | `-Q imports` | `celery inspect ping` |
| VPS-2 | `worker-scrape` | `-Q scrape` | `celery inspect ping` |
| VPS-2 | `worker-maintenance` | `-Q maintenance` | `celery inspect ping` |
| VPS-2 | `worker-notify` | `-Q notifications`, `-c 2`, `/srv/secrets` read-only (FCM only) | `celery inspect ping` |
| VPS-2 | `worker-live` | `-Q live`, `-c 1`, `/srv/raw` read-write (the live poller and `capture-live`, D5) | `celery inspect ping` |
| VPS-2 | `beat` | `celery beat` with a fixed `container_name` | `kill -0 $(cat /tmp/celerybeat.pid)` |
| VPS-2 | `uptime-kuma` | `louislam/uptime-kuma:1`, `/srv/kuma`, the VCN address `:3001` | `extra/healthcheck` |
| VPS-1 | `worker-media` | `-Q media`, `-c 1`, 256 MB, `/srv/media` read-write | `celery inspect ping` |

`flower` is defined in `compose/vps2.yml` and is **not** started. Exactly one
`beat` runs: the fixed `container_name: madar-beat` makes a second one fail instead of
double-scheduling everything.

`worker-notify` is the only service that mounts `/srv/secrets`: the FCM service account is mode 600,
owned by the image's uid 10001, and no other worker can read it (R9). Uptime Kuma and its monitors
are in [uptime-kuma.md](uptime-kuma.md); the backups it watches are in [backups.md](backups.md).

`worker-media` exists because importer-found logos must land on VPS-1's disk, where Caddy serves
them. VPS-2's import workers only queue `adapters.rehost_logo`; they never download media
themselves. It is deployed with the APIs and rolled back with them.

## Check the fleet

The VMs take SSH as `ubuntu`; the Compose commands run as `deploy`, so each line is
`ssh … 'sudo -iu deploy <command>'` from your machine (`deploy` holds only CI's key).

```sh
# VPS-1
ssh ubuntu@10.8.0.1 'sudo -iu deploy docker compose -p madar ps --format "{{.Service}} {{.Status}}"'

# VPS-2 (SSH only from VPS-1)
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose --env-file /srv/madar/.env -f /srv/madar/infra/compose/vps2.yml --profile workers ps'

# the queues and what is in flight
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-imports celery -A app.workers inspect active'
```

A worker that is `unhealthy` but `running` usually cannot reach Redis or PostgreSQL: read its log
(`docker compose -p madar logs --tail 100 worker-imports`) and check `/srv/madar/.env`'s
`DATABASE_URL`, `DATABASE_URL_SYNC`, `REDIS_URL` and `CELERY_BROKER_URL` — on VPS-2 all of them
point at VPS-1's VCN address.

`beat` healthy but no runs happening means the schedule lost its tasks or the queue has no
consumer: check `celery -A app.workers inspect registered` and the `import_runs` table.

## Deploy VPS-2

CI does it: `backend.yml`'s `deploy-vps2` runs after the VPS-1 deploy, reaches VPS-2 through a
`ProxyJump` from VPS-1, rsyncs `infra/` to `/srv/madar/infra/`, and runs
`deploy.sh --host vps2 <sha>`. It needs the `VPS2_VCN_IP` repository variable and VPS-2's host key
in `DEPLOY_KNOWN_HOSTS` ([provision-host.md §8](provision-host.md#8-deploy-peer-and-keys)).
`vps1-sync` writes one ssh config for both hops ([`infra/scripts/ssh-config.sh`](../../infra/scripts/ssh-config.sh)),
because command-line options are not passed to a `-J` jump host.

By hand, from your machine (the token goes on stdin, never as an argument):

```sh
read -rs GHCR_TOKEN                                  # a token with read:packages
sha=$(git rev-parse HEAD)
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" 'sudo -iu deploy mkdir -p /srv/madar/infra'
rsync -a --delete -e "ssh -J ubuntu@10.8.0.1" --rsync-path="sudo -u deploy rsync" \
  infra/ ubuntu@"$VPS2_VCN_IP":/srv/madar/infra/
printf '%s\n' "$GHCR_TOKEN" \
  | ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" "sudo -iu deploy /srv/madar/infra/scripts/deploy.sh --host vps2 $sha"
```

The script pulls its services (and `madar-backup:stable`), starts them, waits up to 90 s for each to
report healthy, and verifies the D3 folders and the backup timer that `bootstrap-vps.sh` installed:
it does not create or enable anything itself (B2-R1-4). Migrations are not run here: VPS-1's deploy
runs `alembic upgrade head` first, and this job runs after it.

## Roll back VPS-2

The script rolls back by itself when the new tag does not get healthy: it starts
`/srv/madar/previous_tag` again and exits non-zero. To roll back deliberately, run the same command
with the earlier tag:

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" 'sudo -iu deploy cat /srv/madar/previous_tag'
printf '%s\n' "$GHCR_TOKEN" \
  | ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
    "sudo -iu deploy /srv/madar/infra/scripts/deploy.sh --host vps2 <tag>"
```

Rolling back VPS-2 alone is safe while the schema is expand-only (D2's `0003` adds two nullable
columns). Never roll VPS-1 back past a migration that dropped something: [database-migrations.md](database-migrations.md).

## `worker-media` and logos

`worker-media` runs on VPS-1 next to `/srv/media`. For a resolved team or competition whose logo is
empty and whose logo URL is on `MEDIA_REHOST_ALLOWED_HOSTS`:

1. the import worker queues `adapters.rehost_logo(entity, id, url, source)` on `media` after the
   commit;
2. the task takes `lock:media:<sha256(url)>` so a duplicate in flight is dropped, downloads with the
   allowlist and the 5 MB cap, re-encodes to WebP ≤ 512 px, and stores it content-addressed;
3. it fills `logo_asset_id` only where it is still NULL, writes an `audit_log` row with the source,
   and bumps `teams` (or `competitions`) and `matches`.

An existing logo is never replaced. A host outside the allowlist, an oversize file or a decode
failure is logged and dropped with the logo still NULL; network errors and 5xx retry with backoff.

```sh
ssh ubuntu@10.8.0.1 'sudo -iu deploy docker compose -p madar logs --tail 100 worker-media'
ssh ubuntu@10.8.0.1 'sudo -iu deploy docker compose -p madar exec -T worker-media celery -A app.workers inspect active'
```

Check the URL the app serves: a rehosted logo answers on `media.<VPS1_IP>.sslip.io`, never on the
source's host.

## Raw pages and retention

`ingest` writes `/srv/raw/<source>/<YYYY-MM-DD>/<run_id>/` on VPS-2 (mounted read-write into
`worker-imports` and `worker-maintenance`), and `import_runs.raw_path` points at it. The nightly
`prune-raw-pages` (03:15 UTC) deletes run folders older than 5 days. `bootstrap-vps.sh vps2`
creates `/srv/raw` for uid 10001; without that, Docker would create it as `root:root` and every
ingest would fail with `PermissionError` (B2-R1-5).

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" 'sudo -iu deploy sh -c "du -sh /srv/raw/*; find /srv/raw -maxdepth 2 -type d | head"'
```

Disk pressure means the prune is not running: check `worker-maintenance`'s log and
`celery -A app.workers inspect registered`. Deleting a folder by hand is safe; the pages are
evidence for a failed run, not a dependency of anything.
