#!/usr/bin/env bash
# Deploy the backend image to VPS-1, or apply only the synced infra (research R13).
# OWNER REVIEW REQUIRED.
#
# Usage, as `deploy` on VPS-1, from the synced /srv/madar/infra (CI runs it over SSH):
#   deploy.sh <image-tag>     needs a GHCR token on stdin
#   deploy.sh --infra-only    applies the infra services and reloads Caddy; reads no token
#
# Steps for <image-tag>:
#   1. apply the synced infra: `compose up -d caddy postgres redis` (only changed services are
#      recreated), then `caddy reload`;
#   2. record the running tag in /srv/madar/previous_tag;
#   3. log in to GHCR with the token from stdin, pull, log out (also on exit), so no registry
#      credential stays on the host;
#   4. run `alembic upgrade head` as a one-off container, and stop before touching any running API
#      container if it fails;
#   5. start api-public and api-admin on the new tag;
#   6. poll both /healthz endpoints for 60 s;
#   7. on failure, start the previous tag again, re-check health, and exit non-zero.
#
# HEALTHZ_FORCE_FAIL=true in the environment deploys the new tag with a failing /healthz, for the
# rollback drill (backend.yml, break_healthcheck). The rollback itself always runs with false.
set -Eeuo pipefail

infra_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file=/srv/madar/.env
state_dir=/srv/madar
caddy_config=/etc/madar/infra/Caddyfile # where vps1.yml mounts $infra_dir inside the caddy container
health_urls=(http://127.0.0.1:8000/healthz http://10.8.0.1:8001/admin/api/healthz)
health_timeout=60

compose=(docker compose --env-file "$env_file" -f "$infra_dir/compose/vps1.yml")

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] error: %s\n' "$*" >&2; exit 1; }
usage() { echo "usage: $0 <image-tag> | --infra-only" >&2; exit 2; }

# The tag of the image api-public runs now, or nothing.
running_tag() {
  local cid image
  # vps1.yml requires IMAGE_TAG to parse; `ps` doesn't use it.
  cid=$(IMAGE_TAG=${IMAGE_TAG:-none} "${compose[@]}" ps -q api-public 2>/dev/null || true)
  [[ -n $cid ]] || return 0
  image=$(docker inspect --format '{{.Config.Image}}' "$cid")
  printf '%s\n' "${image##*:}"
}

# start_apis <tag> <healthz-force-fail>
start_apis() {
  IMAGE_TAG=$1 HEALTHZ_FORCE_FAIL=$2 "${compose[@]}" up -d api-public api-admin
}

healthy() {
  local deadline=$((SECONDS + health_timeout)) url ok
  while ((SECONDS < deadline)); do
    ok=1
    for url in "${health_urls[@]}"; do
      if ! curl -fsS -o /dev/null --max-time 5 "$url" 2>/dev/null; then
        ok=0
        break
      fi
    done
    ((ok)) && return 0
    sleep 3
  done
  return 1
}

mode=${1:-}
[[ $# -eq 1 ]] || usage
if [[ $mode != --infra-only && ! $mode =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
  die "invalid image tag: $mode"
fi
force_fail=${HEALTHZ_FORCE_FAIL:-false}
[[ $force_fail == true || $force_fail == false ]] || die "HEALTHZ_FORCE_FAIL must be true or false"
[[ -r $env_file ]] || die "$env_file is missing"

# Take the GHCR token (step 3) off stdin before anything else runs: `docker compose exec` and
# `run` forward stdin to the container and would swallow it.
token=
if [[ $mode != --infra-only ]]; then
  [[ ! -t 0 ]] || die "pass the GHCR token on stdin"
  IFS= read -r token || true
  [[ -n $token ]] || die "no GHCR token on stdin"
fi
exec </dev/null

exec 9>"$state_dir/.deploy.lock"
flock -n 9 || die "another deploy is running"

current=$(running_tag)
# Step 1 doesn't touch the APIs; the tag is only needed to interpolate vps1.yml.
export IMAGE_TAG=${current:-none} HEALTHZ_FORCE_FAIL=false

# 1. Apply the synced infra.
"${compose[@]}" up -d --wait --wait-timeout 120 caddy postgres redis
"${compose[@]}" exec -T caddy caddy reload --config "$caddy_config" --adapter caddyfile
if [[ $mode == --infra-only ]]; then
  log "infra applied"
  exit 0
fi
tag=$mode

# 2. Record the running tag; it is the rollback target.
if [[ -n $current ]]; then
  printf '%s\n' "$current" > "$state_dir/previous_tag"
fi
previous=$(cat "$state_dir/previous_tag" 2>/dev/null || true)

# 3. Pull with the token read from stdin; never keep the credential.
owner=$(sed -n 's/^GHCR_OWNER=//p' "$env_file" | tail -n 1)
trap 'docker logout ghcr.io >/dev/null 2>&1 || true' EXIT
printf '%s' "$token" | docker login ghcr.io --username "$owner" --password-stdin >/dev/null
unset token
log "pulling $tag"
IMAGE_TAG=$tag "${compose[@]}" pull api-public api-admin
docker logout ghcr.io >/dev/null

# 4. Migrate first. Expand/contract keeps the running API compatible with the new schema.
log "running migrations"
if ! IMAGE_TAG=$tag "${compose[@]}" run --rm -T migrate; then
  die "migration failed; the running containers were not touched (still ${current:-none})"
fi

# 5–6. Roll out and check health.
log "starting $tag"
start_apis "$tag" "$force_fail"
if healthy; then
  printf '%s\n' "$tag" > "$state_dir/current_tag"
  log "deployed $tag"
  exit 0
fi

# 7. Roll back.
log "health check failed for $tag"
if [[ -z $previous ]]; then
  die "no previous tag to roll back to; $tag is left running for inspection"
fi
log "rolling back to $previous"
start_apis "$previous" false
if healthy; then
  printf '%s\n' "$previous" > "$state_dir/current_tag"
  die "rolled back to $previous, which is healthy"
fi
die "rolled back to $previous, but it is not healthy either"
