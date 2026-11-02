#!/usr/bin/env bash
# Nightly PostgreSQL backup from VPS-2 (R19, SC-004). Run by backup-db.timer through Compose:
#   docker compose -f compose/vps2.yml run --rm -T backup-db
#
# 1. `pg_dump -Fc` over the VCN into /srv/backup/madar.dump (one fixed name, so every snapshot is
#    the same path: `restic forget` prunes per group of host and paths, B2-R1-3);
# 2. `restic init` when the repository is still empty, then `restic backup --host madar-vps2` that
#    file into the Backblaze B2 repository;
# 3. `restic forget --host madar-vps2 --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`;
# 4. one push to the Kuma heartbeat, `up` or `down` with the error.
#
# Every value comes from /srv/madar/.env. No secret is ever echoed: `set -x` is never used and the
# password travels in PGPASSWORD, which `ps` does not show.
set -Eeuo pipefail

staging=${BACKUP_STAGING:-/srv/backup}
: "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is not set}"
: "${RESTIC_PASSWORD:?RESTIC_PASSWORD is not set}"
: "${B2_ACCOUNT_ID:?B2_ACCOUNT_ID is not set}"
: "${B2_ACCOUNT_KEY:?B2_ACCOUNT_KEY is not set}"
db_host=${BACKUP_DB_HOST:-${PEER_VCN_IP:-}}
db_port=${BACKUP_DB_PORT:-5432}
db_user=${POSTGRES_USER:-madar}
db_name=${POSTGRES_DB:-madar}
: "${db_host:?BACKUP_DB_HOST (or PEER_VCN_IP) is not set}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is not set}"
export RESTIC_REPOSITORY RESTIC_PASSWORD B2_ACCOUNT_ID B2_ACCOUNT_KEY

# `restic forget` applies its policy per group, and a group is the host plus the paths. The
# container's hostname changes every night, so the host is pinned; and the dump has a fixed name, so
# every night's snapshot is the same path (B2-R1-3). Without both, 7/4/6 keeps every snapshot.
restic_host=${RESTIC_HOST:-madar-vps2}
keep_daily=${BACKUP_KEEP_DAILY:-7}
keep_weekly=${BACKUP_KEEP_WEEKLY:-4}
keep_monthly=${BACKUP_KEEP_MONTHLY:-6}
heartbeat_url=${KUMA_PUSH_URL_BACKUP_DB:-}

log() { printf '[backup-db] %s\n' "$*"; }

# One push, logged and never fatal: the backup's own exit code is what systemd reports. Kuma shows a
# push URL as `…/api/push/<token>?status=up&msg=OK&ping=`; only the path is kept, or a `down` push
# would land inside `ping` and Kuma would record `up` (B2-R2-1).
heartbeat() {
  local status=$1 message=$2
  [[ -n $heartbeat_url ]] || return 0
  curl -fsS -m 10 --retry 2 -o /dev/null \
    "${heartbeat_url%%\?*}?status=${status}&msg=$(printf '%s' "$message" | tr ' ' '+')" \
    || log "heartbeat push failed (status=${status})"
}

on_error() {
  local code=$?
  heartbeat down "pg_dump or restic failed (exit ${code})"
  log "failed with exit ${code}"
  exit "$code"
}
trap on_error ERR

install -d -m 700 "$staging"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
dump="$staging/madar.dump"

# The first night has an empty bucket: `restic backup` would fail with "unable to open config file"
# and the repository would never exist (B2-R1-5). `cat config` is the cheapest existence test.
ensure_repository() {
  if restic cat config >/dev/null 2>&1; then
    return 0
  fi
  log "initialising the restic repository"
  restic init
}

log "dumping $db_name from $db_host:$db_port into $dump"
PGPASSWORD=$POSTGRES_PASSWORD pg_dump \
  --format=custom --compress=6 --no-owner --no-privileges \
  --host "$db_host" --port "$db_port" --username "$db_user" --dbname "$db_name" \
  --file "$dump"

ensure_repository
log "uploading to $RESTIC_REPOSITORY (host $restic_host)"
restic backup --host "$restic_host" --tag db "$dump"

log "applying retention (daily $keep_daily, weekly $keep_weekly, monthly $keep_monthly)"
restic forget --host "$restic_host" --tag db --keep-daily "$keep_daily" --keep-weekly "$keep_weekly" \
  --keep-monthly "$keep_monthly" --prune

# The staged dump is disposable: the snapshot in B2 is the backup.
rm -f "$dump"
heartbeat up "ok $stamp"
log "done: $stamp"
