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
  `ghcr.io/<owner>/madar-backup:stable`, built from `infra/backup/Dockerfile` on `master`
  (`infra.yml` moves `stable` on every build, and `deploy.sh` pulls it on both hosts).
- `bootstrap-vps.sh` creates the folders and installs and enables the timers as root
  (`systemctl enable`), and starts them once the backup keys are in `.env`; a deploy only verifies
  them and names the command to run when one is missing (B2-R1-4).
- The first run creates the restic repository when the bucket is still empty (`restic cat config ||
  restic init`), so the owner does not run `restic init` by hand (B2-R1-5).
- Each job snapshots under a pinned restic host (`madar-vps2` for the database, `madar-vps1` for the
  media) and the database dump always has the same path, `/srv/backup/madar.dump`. `restic forget`
  prunes per group of host and paths, so this is what makes 7/4/6 delete anything at all (B2-R1-3).
- The backup containers run as uid 10001 (the image's user, `cap_drop: ALL`): `/srv/backup` is that
  uid's, mode 700, and the media files are 0600 owned by it, which is why they can write and read
  them without `CAP_DAC_OVERRIDE` (B2-R1-2).
- The Backblaze free tier is 10 GB: a 7/4/6 restic policy over a database of a few hundred MB stays
  inside it. Watch the bucket's used space; if it grows, lower `BACKUP_KEEP_MONTHLY` first.
- Both jobs push a heartbeat to Uptime Kuma (`KUMA_PUSH_URL_BACKUP_DB`, `KUMA_PUSH_URL_BACKUP_MEDIA`,
  `KUMA_PUSH_URL_BACKUP_MEDIA_WEEKLY`). A backup that ran but did not push is a red monitor
  ([uptime-kuma.md](uptime-kuma.md)).

The secrets are in each host's `/srv/madar/.env` (mode 600, owner `deploy`):
`RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY` on both hosts; the
`RCLONE_CONFIG_OCI_*` keys and `RCLONE_BUCKET` on VPS-1 ([secrets.md](secrets.md)).

## Check last night's backup

The commands are the ones the timers run, plus a read-only `restic`/`rclone` subcommand. They need
no `IMAGE_TAG` in the environment: the backup services take their tag from `BACKUP_IMAGE_TAG`
(`stable` unless a host sets it).

On VPS-2 (the database):

```sh
ssh madar-vps2 'sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps2.yml --profile backup run --rm -T backup-db \
  restic snapshots --tag db --latest 3'
```

The image's restic is 0.14, where `--last 3` reads `3` as a snapshot id and lists nothing: use
`--latest 3`.

On VPS-1 (the media):

```sh
ssh madar-vps1 'sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup run --rm -T --entrypoint rclone backup-media \
  lsd oci: --max-depth 1'
```

Both containers exit non-zero on failure, so the timer's state is the second answer:

```sh
ssh madar-vps2 'systemctl list-timers "backup-*" --no-pager'
ssh madar-vps2 'systemctl status backup-db.service --no-pager | head -n 20'
ssh madar-vps2 'journalctl -u backup-db.service -n 50 --no-pager'
```

## Run one by hand

```sh
# database, from VPS-2
ssh madar-vps2 'sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps2.yml --profile backup run --rm -T backup-db'

# media mirror, from VPS-1
ssh madar-vps1 'sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup run --rm -T backup-media'

# media mirror plus this week's snapshot, from VPS-1
ssh madar-vps1 'sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup run --rm -T backup-media-weekly'
```

`systemctl start backup-db.service` and `systemctl start backup-media.service` (as root) run the
same thing through systemd; use them when you want the journal entry.

## Restore the database

Do this on a scratch database first; never point it at `madar` while the API is serving.

```sh
# 1. On VPS-2, restore the newest snapshot into the staging directory the container already mounts.
ssh madar-vps2 'sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps2.yml --profile backup run --rm -T backup-db \
  restic restore latest --tag db --target /srv/backup/restore'

# 2. The dump is now on the host's disk, under the snapshot's own path. `/srv/backup` belongs to the
#    backup user (uid 10001), so root reads it here.
ssh madar-vps2 'sudo ls -lh /srv/backup/restore/srv/backup/'
```

```sh
# 3. From your machine: root on VPS-2 reads the dump, and it goes to VPS-1, which holds the
#    database.
ssh madar-vps2 'sudo cat /srv/backup/restore/srv/backup/madar.dump' > /tmp/madar.dump
scp /tmp/madar.dump madar-vps1:/tmp/madar.dump
```

```sh
# 4. On VPS-1, create a scratch database and load the dump into it.
dc exec -T postgres createdb -U madar madar_restore
dc exec -T postgres pg_restore -U madar -d madar_restore --no-owner --no-privileges \
  < /tmp/madar.dump
dc exec postgres psql -U madar -d madar_restore -c "select count(*) from matches"

# 5. When the numbers look right, swap it in during a quiet window.
dc stop api-public api-admin worker-media
dc exec postgres psql -U madar -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='madar'"
dc exec postgres dropdb -U madar madar
dc exec postgres psql -U madar -d postgres -c "alter database madar_restore rename to madar"
dc up -d api-public api-admin worker-media
```

Restoring an **older** snapshot is the same with `--tag db` plus the snapshot id from
`restic snapshots`.

## Restore the media

The `backup-media` service mounts `/srv/media` **read-only** (`infra/compose/vps1.yml`), so a
restore cannot go through it. Both restores below are one-off containers of the same image, with
the same user as the backup (uid 10001, the owner of the media files) and a writable mount; a
restore as root would leave files `deploy` can neither read nor copy.

```sh
# the image deploy.sh pulls, so the tag is never guessed
image=$(ssh madar-vps1 'sudo -iu deploy docker compose --env-file /srv/madar/.env \
  -f /srv/madar/infra/compose/vps1.yml --profile backup config --images' | grep madar-backup)
```

The mirror is a plain copy, so one file comes back with:

```sh
ssh madar-vps1 "sudo -iu deploy docker run --rm --user 10001:10001 --cap-drop ALL \
  --env-file /srv/madar/.env -e HOME=/tmp -e XDG_CACHE_HOME=/tmp/cache \
  -v /srv/media:/srv/media $image \
  rclone copy oci:madar-media/logos/<file>.webp /srv/media/logos/"
```

A file deleted from the disk by mistake also comes back from the weekly snapshot: it is restored
into the container's own `/tmp` and copied across, so nothing is left on the host:

```sh
ssh madar-vps1 "sudo -iu deploy docker run --rm --user 10001:10001 --cap-drop ALL \
  --env-file /srv/madar/.env -e HOME=/tmp -e XDG_CACHE_HOME=/tmp/cache \
  -v /srv/media:/srv/media $image \
  sh -c 'restic restore latest --tag media --target /tmp/restore --include /srv/media/logos/<file>.webp && cp /tmp/restore/srv/media/logos/<file>.webp /srv/media/logos/'"
```

Both leave the file owned by uid 10001, like the rest of `/srv/media`; the snapshot restore also
keeps its mode 0600.

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
