#!/usr/bin/env bash
# Update the owner's x86-64 home box to the current `stable` image (FR-028, research R21).
#
# Run by infra/scripts/home-box-update.timer every 10 minutes, as root or as a user in the docker
# group. CI never connects to the box, so an offline box fails nothing; it catches up on the next
# run. The box pulls the separate `madar-backend-amd64` package with a read-only token from its own
# .env, logs out at once, and recreates the worker only when the image changed.
#
# Usage: infra/scripts/home-box-update.sh [--dry-run]
set -Eeuo pipefail

infra_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
compose_file=$infra_dir/compose/home-box.yml
env_file=${MADAR_ENV_FILE:-/srv/madar/.env}
dry_run=no
[[ ${1:-} == --dry-run ]] && dry_run=yes

log() { printf '[home-box-update] %s\n' "$*"; }
die() { printf '[home-box-update] error: %s\n' "$*" >&2; exit 1; }

# One value from the env file, without executing it.
env_get() { sed -n "s/^$1=//p" "$env_file" | tail -n 1; }

[[ -r $env_file ]] || die "$env_file is missing (mode 600, owner of the box)"
owner=$(env_get GHCR_OWNER)
token=$(env_get GHCR_READ_TOKEN)
[[ -n $owner ]] || die "GHCR_OWNER is empty in $env_file"
[[ -n $token ]] || die "GHCR_READ_TOKEN is empty in $env_file (a read-only packages token)"

compose=(docker compose --env-file "$env_file" -f "$compose_file")

if [[ $dry_run == yes ]]; then
  "${compose[@]}" config -q
  log "dry run: $compose_file parses with $env_file"
  exit 0
fi

trap 'docker logout ghcr.io >/dev/null 2>&1 || true' EXIT
printf '%s' "$token" | docker login ghcr.io --username "$owner" --password-stdin >/dev/null
unset token
before=$(docker inspect --format '{{.Image}}' "$("${compose[@]}" ps -q worker-scrape 2>/dev/null || true)" 2>/dev/null || true)
log "pulling ghcr.io/$owner/madar-backend-amd64:stable"
"${compose[@]}" pull --quiet worker-scrape
docker logout ghcr.io >/dev/null

# Recreate only when the image moved, so a quiet box doesn't restart its worker every 10 minutes.
"${compose[@]}" up -d worker-scrape
after=$(docker inspect --format '{{.Image}}' "$("${compose[@]}" ps -q worker-scrape)" 2>/dev/null || true)
if [[ -n $before && $before == "$after" ]]; then
  log "already current"
else
  log "updated ($(docker inspect --format '{{.Config.Image}}' "$after" 2>/dev/null || echo unknown))"
fi
