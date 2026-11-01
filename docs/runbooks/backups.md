# Backups

What is backed up, where it goes, when, and how to restore it (Lane B2's T085, SC-004, research R19).
Two host timers run one-shot containers outside Celery: a broken worker must not also stop the
backups, which are exactly what an incident needs.

## What, where, when

| What | From | To | When | Retention |
| --- | --- | --- | --- | --- |
| PostgreSQL 16 (`pg_dump -Fc`) | VPS-2 dumps VPS-1's database over the VCN | Backblaze B2, a **restic** repository | nightly 03:00 Africa/Cairo | 7 daily, 4 weekly, 6 monthly |
| `/srv/media` (mirror) | VPS-1's disk | OCI Object Storage bucket, S3-compatible (**rclone sync**) | nightly 03:30 Africa/Cairo | the bucket keeps the current files |
| `/srv/media` (snapshot) | VPS-1's disk | the same restic repository as the database | Sundays 04:00 Africa/Cairo | 4 weekly |

- The timers are in `infra/systemd/`; the scripts are in `infra/backup/`; the image is
  `ghcr.io/<owner>/madar-backup` (built from `infra/backup/Dockerfile` on `master`).
- `deploy.sh` installs and enables the timers on every deploy (`systemctl enable --now`), so a fresh
  host needs no manual step.
- The Backblaze free tier is 10 GB: a 7/4/6 restic policy over a database of a few hundred MB stays
  inside it. Watch the bucket's used space; if it grows, lower `BACKUP_KEEP_MONTHLY` first.
- Both jobs push a heartbeat to Uptime Kuma (`KUMA_PUSH_URL_BACKUP_DB`, `KUMA_PUSH_URL_BACKUP_MEDIA`,
  `KUMA_PUSH_URL_BACKUP_MEDIA_WEEKLY`). A backup that ran but did not push is a red monitor
  ([uptime-kuma.md](uptime-kuma.md)).

The secrets are in each host's `/srv/madar/.env` (mode 600, owner `deploy`):
`RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY` on both hosts; the
`RCLONE_CONFIG_OCI_*` keys and `RCLONE_BUCKET` on VPS-1 ([secrets.md](secrets.md)).

## Check last night's backup

On VPS-2 (the database):

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy env $(sudo cat /srv/madar/.env | xargs) \
   docker compose --env-file /srv/madar/.env -f /srv/madar/infra/compose/vps2.yml --profile backup \
   run --rm -T backup-db restic snapshots --tag db --last 3'
```

On VPS-1 (the media):

```sh
sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup run --rm -T backup-media rclone lsd oci: --max-depth 1
```

Both containers exit non-zero on failure, so the timer's state is the second answer:

```sh
systemctl list-timers 'backup-*' --no-pager
systemctl status backup-db.service --no-pager | head -n 20
journalctl -u backup-db.service -n 50 --no-pager
```

## Run one by hand

```sh
# database, from VPS-2
sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps2.yml --profile backup run --rm -T backup-db

# media mirror, from VPS-1
sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup run --rm -T backup-media

# media mirror plus this week's snapshot, from VPS-1
sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup run --rm -T backup-media-weekly
```

## Restore the database

Do this on a scratch database first; never point it at `madar` while the API is serving.

```sh
# 1. On VPS-2, restore the newest snapshot to /srv/backup inside the container.
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose --env-file /srv/madar/.env \
   -f /srv/madar/infra/compose/vps2.yml --profile backup run --rm -T backup-db \
   restic restore latest --tag db --target /restore'

# 2. Copy the dump out of the container's staging area and inspect it.
sudo -iu deploy ls -lh /srv/backup/restore/srv/backup/
```

```sh
# 3. On VPS-1, create a scratch database and load the dump into it.
dc exec -T postgres createdb -U madar madar_restore
dc exec -T postgres pg_restore -U madar -d madar_restore --no-owner --no-privileges \
  < /srv/backup/restore/srv/backup/madar-<stamp>.dump
dc exec postgres psql -U madar -d madar_restore -c "select count(*) from matches"

# 4. When the numbers look right, swap it in during a quiet window.
dc stop api-public api-admin worker-media
dc exec postgres psql -U madar -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='madar'"
dc exec postgres dropdb -U madar madar
dc exec postgres psql -U madar -d postgres -c "alter database madar_restore rename to madar"
dc up -d api-public api-admin worker-media
```

`pg_restore` from the host needs the dump on the host: the container writes to `/srv/backup`, which
is the same directory vps2.yml mounts, so copy it back over SSH if you restore on VPS-1:

```sh
scp -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP":/srv/backup/restore/srv/backup/madar-*.dump /tmp/
```

Restoring an **older** snapshot is the same with `--tag db` plus the snapshot id from
`restic snapshots`.

## Restore the media

The mirror is a plain copy, so one file comes back with:

```sh
sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup run --rm -T backup-media \
  rclone copy oci:madar-media/logos/<file>.webp /srv/media/logos/
```

A file deleted from the disk by mistake comes back from the weekly snapshot:

```sh
sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup run --rm -T backup-media \
  restic restore latest --tag media --target /restore --include /srv/media/logos
sudo -iu deploy cp /restore/srv/media/logos/<file>.webp /srv/media/logos/
```

## The monthly restore drill

D8 turns this into a scheduled exercise with a report. Until then, do it once a month and write the
result in the owner's log:

1. restore the newest snapshot into a scratch database (above);
2. start a READ-ONLY API against it: `DATABASE_URL=…madar_restore dc up -d api-public`, then
   `curl -fsS https://api.<VPS1_IP>.sslip.io/v1/matches | head -c 200`, and confirm the row counts
   match `import_runs` and `matches`;
3. stop the scratch API and drop `madar_restore`;
4. restore one media file from the weekly snapshot and open it through the media host.

A backup that cannot be restored is not a backup. If any step fails, keep the scratch database and
open a bug against `infra/backup/`.
