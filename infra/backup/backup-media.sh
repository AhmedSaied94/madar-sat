#!/usr/bin/env bash
# The media backup from VPS-1 (R19, SC-004). Run by backup-media.timer every night at 03:30
# Africa/Cairo and by backup-media-weekly.timer on Sundays at 04:00:
#   docker compose -f compose/vps1.yml run --rm -T backup-media
#   docker compose -f compose/vps1.yml run --rm -T backup-media-weekly
#
# Nightly: `rclone sync /srv/media` to the OCI bucket, so the mirror always matches the disk.
# Weekly (`--weekly`): also `restic backup /srv/media` to the same B2 repository as the database,
# with `forget --host madar-vps1 --keep-weekly 4`, so a deleted or corrupted file can be recovered
# from a snapshot rather than only from the mirror. The host is pinned because `forget` prunes per
# group of host and paths, and the container's hostname changes every night (B2-R1-3).
#
# Media lives on VPS-1's disk, which is why this runs there and not on VPS-2 (R19). No secret is
# echoed: the OCI keys arrive as RCLONE_CONFIG_OCI_* and never appear on a command line.
set -Eeuo pipefail

mode=nightly
case ${1:-} in
  --weekly) mode=weekly ;;
  --nightly | "") mode=nightly ;;
  *)
    echo "usage: $0 [--nightly|--weekly]" >&2
    exit 2
    ;;
esac

media_root=${MEDIA_ROOT:-/srv/media}
remote=oci
bucket=${RCLONE_BUCKET:-madar-media}
: "${RCLONE_CONFIG_OCI_ACCESS_KEY_ID:?RCLONE_CONFIG_OCI_ACCESS_KEY_ID is not set}"
: "${RCLONE_CONFIG_OCI_SECRET_ACCESS_KEY:?RCLONE_CONFIG_OCI_SECRET_ACCESS_KEY is not set}"

if [[ $mode == weekly ]]; then
  heartbeat_url=${KUMA_PUSH_URL_BACKUP_MEDIA_WEEKLY:-}
else
  heartbeat_url=${KUMA_PUSH_URL_BACKUP_MEDIA:-}
fi
# `forget` prunes per group (host + paths) and the container's hostname changes every night, so the
# host is pinned or every weekly snapshot is kept for ever (B2-R1-3).
restic_host=${RESTIC_HOST:-madar-vps1}
keep_weekly=${BACKUP_KEEP_WEEKLY:-4}

log() { printf '[backup-media] %s\n' "$*"; }

heartbeat() {
  local status=$1 message=$2
  [[ -n $heartbeat_url ]] || return 0
  curl -fsS -m 10 --retry 2 -o /dev/null \
    "${heartbeat_url}?status=${status}&msg=$(printf '%s' "$message" | tr ' ' '+')" \
    || log "heartbeat push failed (status=${status})"
}

on_error() {
  local code=$?
  heartbeat down "media backup failed (exit ${code})"
  log "failed with exit ${code}"
  exit "$code"
}
trap on_error ERR

[[ -d $media_root ]] || { log "$media_root is missing"; exit 1; }

log "mirroring $media_root to $remote:$bucket"
# --checksum compares content, not timestamps: media files are content-addressed and immutable.
rclone sync --checksum --fast-list --stats-one-line --stats 1m "$media_root" "$remote:$bucket"

if [[ $mode == weekly ]]; then
  : "${RESTIC_REPOSITORY:?RESTIC_REPOSITORY is not set for the weekly snapshot}"
  : "${RESTIC_PASSWORD:?RESTIC_PASSWORD is not set for the weekly snapshot}"
  : "${B2_ACCOUNT_ID:?B2_ACCOUNT_ID is not set for the weekly snapshot}"
  : "${B2_ACCOUNT_KEY:?B2_ACCOUNT_KEY is not set for the weekly snapshot}"
  export RESTIC_REPOSITORY RESTIC_PASSWORD B2_ACCOUNT_ID B2_ACCOUNT_KEY
  # The repository is shared with the database backup and may not exist yet (B2-R1-5).
  if ! restic cat config >/dev/null 2>&1; then
    log "initialising the restic repository"
    restic init
  fi
  log "snapshotting $media_root into $RESTIC_REPOSITORY (host $restic_host, keep-weekly $keep_weekly)"
  restic backup --host "$restic_host" --tag media "$media_root"
  restic forget --host "$restic_host" --tag media --keep-weekly "$keep_weekly" --prune
fi

heartbeat up "ok $mode"
log "done: $mode"
