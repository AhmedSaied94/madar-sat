#!/usr/bin/env bash
# Nightly PostgreSQL backup from VPS-2 (R19, SC-004). Run by backup-db.timer through Compose:
#   docker compose -f compose/vps2.yml run --rm -T backup-db
#
# 1. `pg_dump -Fc` over the VCN into /srv/backup;
# 2. `restic backup` that file into the Backblaze B2 repository;
# 3. `restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune`;
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

heartbeat_url=${KUMA_PUSH_URL_BACKUP_DB:-}
keep_daily=${BACKUP_KEEP_DAILY:-7}
keep_weekly=${BACKUP_KEEP_WEEKLY:-4}
keep_monthly=${BACKUP_KEEP_MONTHLY:-6}

log() { printf '[backup-db] %s\n' "$*"; }

# One push, logged and never fatal: the backup's own exit code is what systemd reports.
heartbeat() {
  local status=$1 message=$2
  [[ -n $heartbeat_url ]] || return 0
  curl -fsS -m 10 --retry 2 -o /dev/null \
    "${heartbeat_url}?status=${status}&msg=$(printf '%s' "$message" | tr ' ' '+')" \
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
dump="$staging/madar-$stamp.dump"

log "dumping $db_name from $db_host:$db_port into $dump"
PGPASSWORD=$POSTGRES_PASSWORD pg_dump \
  --format=custom --compress=6 --no-owner --no-privileges \
  --host "$db_host" --port "$db_port" --username "$db_user" --dbname "$db_name" \
  --file "$dump"

log "uploading to $RESTIC_REPOSITORY"
restic backup --tag db --tag "madar-$stamp" "$dump"

log "applying retention (daily $keep_daily, weekly $keep_weekly, monthly $keep_monthly)"
restic forget --tag db --keep-daily "$keep_daily" --keep-weekly "$keep_weekly" \
  --keep-monthly "$keep_monthly" --prune

# The staged dump is disposable: the snapshot in B2 is the backup.
rm -f "$dump"
heartbeat up "ok $stamp"
log "done: $stamp"
