#!/usr/bin/env bash
# Deploy the backend image to VPS-1, or the workers to VPS-2, or apply only the synced infra
# (research R13 and R22). OWNER REVIEW REQUIRED.
#
# Usage, as `deploy` on either host, from the synced /srv/madar/infra (CI runs it over SSH):
#   deploy.sh [--host vps1] <image-tag>   needs a GHCR token on stdin (VPS-1's APIs and media worker)
#   deploy.sh --host vps2 <image-tag>     needs a GHCR token on stdin (VPS-2's workers and beat)
#   deploy.sh --infra-only                VPS-1 only: applies infra services and reloads Caddy
#
# VPS-1, steps for <image-tag>:
#   0. verify the D3 folders and the backup timers bootstrap created (B2-R1-4);
#   1. render the Redis ACL from infra/redis/users.acl.tmpl and /srv/madar/.env (the file mode 640
#      and its directory 750, group 999, so the redis user in the container can read it), apply the
#      synced infra (`compose up -d caddy postgres redis` and `caddy reload`), and restart Redis
#      when the file changed, then prove both passwords work (B2-R2-1, B2-R2-11). Both the `up` and
#      the reload put the previous ACL back when Redis refuses the new one (B2-R3-2);
#   2. record the running tag in /srv/madar/previous_tag;
#   3. log in to GHCR with the token from stdin, pull the APIs, the media worker and
#      `madar-backup:stable`, log out (also on exit);
#   4. run `alembic upgrade head` as a one-off container, and stop before touching any running
#      container if it fails;
#   5. start api-public, api-admin and worker-media on the new tag;
#   6. poll both /healthz endpoints and worker-media's healthcheck for 60 s;
#   7. on failure, start the previous tag again, re-check, and exit non-zero.
#
# Both hosts also verify the D3 folders (/srv/backup, /srv/kuma, /srv/secrets) and their backup
# timers, which bootstrap-vps.sh creates as root: a deploy only checks them and names the command
# to run when one is missing (B2-R1-4). Each deploy also pulls `madar-backup:stable`, the image the
# timers run, while it is logged in to GHCR (B2-R1-1).
#
# VPS-2, steps for <image-tag>:
#   1. record the running tag;
#   2. verify the D3 folders and backup-db.timer;
#   3. pull with the token from stdin (nothing to migrate: migrations run on VPS-1);
#   4. `compose --profile workers up -d worker-imports worker-scrape worker-maintenance worker-notify
#      uptime-kuma beat`;
#   5. wait up to 90 s for all of them to report healthy (each worker answers `celery inspect ping`;
#      beat is healthy when its pid file's process lives);
#   6. on failure, restore the previous tag and exit non-zero.
#
# HEALTHZ_FORCE_FAIL=true in the environment deploys the new tag with a failing /healthz, for the
# rollback drill (backend.yml, break_healthcheck). It applies to VPS-1 only.
set -Eeuo pipefail

infra_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
env_file=/srv/madar/.env
# MADAR_STATE_DIR, MADAR_SRV_ROOT and MADAR_UNITS_DIR exist for the CI checks, which drive the
# read-only verifiers against a temporary tree; on a host they are never set.
state_dir=${MADAR_STATE_DIR:-/srv/madar}
acl_dir=$state_dir/redis
acl_target=$acl_dir/users.acl
acl_previous=$acl_dir/users.acl.prev
caddy_config=/etc/madar/infra/Caddyfile # where vps1.yml mounts $infra_dir inside the caddy container
health_urls=(http://127.0.0.1:8000/healthz http://10.8.0.1:8001/admin/api/healthz)
health_timeout=60
workers_timeout=90
acl_gid=999  # the `redis` user's gid in redis:7.4.12, and the group bootstrap-vps.sh gives deploy
app_uid=10001  # the `madar` user inside the backend image (backend/Dockerfile)
redis_acl_changed=0
api_services=(api-public api-admin)
media_service=worker-media
vps1_stateful=(postgres redis caddy)
# `worker-notify` holds the outbox dispatcher and `uptime-kuma` watches every host (D3, R20).
vps2_services=(worker-imports worker-scrape worker-maintenance worker-notify uptime-kuma beat)
vps1_timers=(backup-media.timer backup-media-weekly.timer)
vps2_timers=(backup-db.timer)

compose=(docker compose --env-file "$env_file")
vps1_compose=("${compose[@]}" -f "$infra_dir/compose/vps1.yml")
vps2_compose=("${compose[@]}" --profile workers -f "$infra_dir/compose/vps2.yml")

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] error: %s\n' "$*" >&2; exit 1; }
usage() { echo "usage: $0 [--host vps1|vps2] <image-tag> | --infra-only" >&2; exit 2; }

# One value from the env file, without executing it.
env_get() { sed -n "s/^$1=//p" "$env_file" | tail -n 1; }

# compose_for <vps1|vps2>: sets the compose_cmd array for the host.
compose_for() {
  if [[ $1 == vps2 ]]; then compose_cmd=("${vps2_compose[@]}"); else compose_cmd=("${vps1_compose[@]}"); fi
}

# The tag of the image a container runs now, or nothing.
running_tag() {
  local host=$1 service=$2 cid image
  compose_for "$host"
  # The Compose file requires IMAGE_TAG to parse; `ps` doesn't use it.
  cid=$(IMAGE_TAG=${IMAGE_TAG:-none} "${compose_cmd[@]}" ps -q "$service" 2>/dev/null || true)
  [[ -n $cid ]] || return 0
  image=$(docker inspect --format '{{.Config.Image}}' "$cid")
  printf '%s\n' "${image##*:}"
}

# healthy_services <host> <timeout> <service...>: every container exists and reports healthy.
healthy_services() {
  local host=$1 timeout=$2 deadline cid status ok service
  shift 2
  compose_for "$host"
  deadline=$((SECONDS + timeout))
  while ((SECONDS < deadline)); do
    ok=1
    for service in "$@"; do
      cid=$(IMAGE_TAG=${IMAGE_TAG:-none} "${compose_cmd[@]}" ps -q "$service" 2>/dev/null || true)
      if [[ -z $cid ]]; then ok=0; break; fi
      status=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid")
      if [[ $status != healthy ]]; then ok=0; break; fi
    done
    ((ok)) && return 0
    sleep 3
  done
  "${compose_cmd[@]}" ps || true
  return 1
}

healthy_apis() {
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

start_apis() {
  local tag=$1 force_fail=$2
  IMAGE_TAG=$tag HEALTHZ_FORCE_FAIL=$force_fail "${vps1_compose[@]}" up -d "${api_services[@]}" "$media_service"
}

# Render the Redis ACL file from the template, so the passwords come from .env and never the repo.
# The directory, the file's mode and its group all come from infra/scripts/render-redis-acl.sh, the
# same script CI runs: a 640 file in a 700 directory still made Redis abort (B2-R2-1).
render_redis_acl() {
  local result
  result=$("$infra_dir/scripts/render-redis-acl.sh" --out "$acl_dir" --env-file "$env_file" --group "$acl_gid") \
    || die "could not render $acl_target"
  case $result in
    changed)
      redis_acl_changed=1
      log "rendered $acl_target"
      ;;
    unchanged) redis_acl_changed=0 ;;
    *) die "render-redis-acl.sh answered '$result'" ;;
  esac
}

# A password never goes on a command line: it would sit in the host's process list (B2-R2-23).
acl_ping() {
  local user=$1 password=$2
  "${vps1_compose[@]}" exec -T -e REDISCLI_AUTH="$password" redis \
    redis-cli --user "$user" --no-auth-warning ping 2>/dev/null | grep -qx PONG
}

# Both users, because a wrong REDIS_HOMEBOX_PASSWORD is what breaks the home box (B2-R2-11).
acl_answers() {
  local redis_password homebox_password deadline
  redis_password=$(env_get REDIS_PASSWORD)
  homebox_password=$(env_get REDIS_HOMEBOX_PASSWORD)
  deadline=$((SECONDS + 30))
  while ((SECONDS < deadline)); do
    if acl_ping default "$redis_password" && acl_ping homebox "$homebox_password"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

# The D3 directories and the backup timers are created by bootstrap-vps.sh as root: `deploy` cannot
# write /etc/systemd/system, reload systemd, or chown to another uid, and under `set -Eeuo pipefail`
# a refused `install` aborted the deploy before the migrations and the pull (B2-R1-4). Deploy only
# verifies what bootstrap did, and names the command to run when something is missing.
srv_root=${MADAR_SRV_ROOT:-/srv}
units_dir=${MADAR_UNITS_DIR:-/etc/systemd/system}

# check_dir <path> <mode> <owner uid>: a directory bootstrap created, with its mode and owner.
check_dir() {
  local path=$1 mode=$2 owner=$3 actual_mode actual_owner
  if [[ ! -d $path ]]; then
    log "$path is missing"
    return 1
  fi
  actual_mode=$(stat -c %a "$path")
  actual_owner=$(stat -c %u "$path")
  if [[ $actual_mode != "$mode" ]]; then
    log "$path is mode $actual_mode, expected $mode"
    return 1
  fi
  if [[ $actual_owner != "$owner" ]]; then
    log "$path is owned by uid $actual_owner, expected $owner"
    return 1
  fi
}

# check_admin_current: Caddy's wg0 site serves /srv/admin/current, the symlink bootstrap points at
# releases/placeholder before the first admin deploy (D4 T039). Without it the admin answers 404.
check_admin_current() {
  local link=$srv_root/admin/current
  if [[ ! -L $link ]]; then
    log "$link is not a symlink"
    return 1
  fi
  if [[ ! -f $link/index.html ]]; then
    log "$link points at $(readlink "$link"), which has no index.html"
    return 1
  fi
}

# check_dirs <vps1|vps2>: the folders the D3 services mount. /srv/backup belongs to the backup
# image's user (uid 10001), because that container runs as it and writes the dump there (B2-R1-2).
# On VPS-1, the admin release symlink (D4).
check_dirs() {
  local role=$1 ok=0
  check_dir "$state_dir" 750 "$(id -u)" || ok=1
  if [[ $role == vps1 ]]; then
    check_admin_current || ok=1
  fi
  if [[ $role == vps2 ]]; then
    check_dir "$srv_root/backup" 700 "$app_uid" || ok=1
    check_dir "$srv_root/kuma" 755 "$(id -u)" || ok=1
    check_dir "$srv_root/secrets" 700 "$app_uid" || ok=1
  fi
  return "$ok"
}

# role_timers <vps1|vps2>: the timers bootstrap installs on that host.
role_timers() {
  if [[ $1 == vps2 ]]; then printf '%s\n' "${vps2_timers[@]}"; else printf '%s\n' "${vps1_timers[@]}"; fi
}

# check_timers <vps1|vps2>: the units on the host are the repository's, and the timers are enabled.
check_timers() {
  local role=$1 ok=0 timer unit file
  while IFS= read -r timer; do
    unit=${timer%.timer}.service
    for file in "$unit" "$timer"; do
      if ! cmp -s "$infra_dir/systemd/$file" "$units_dir/$file"; then
        log "$units_dir/$file is missing or differs from the repository"
        ok=1
      fi
    done
    if ! systemctl is-enabled --quiet "$timer" 2>/dev/null; then
      log "$timer is not enabled"
      ok=1
    fi
  done < <(role_timers "$role")
  return "$ok"
}

require_host_setup() {
  local role=$1
  if check_dirs "$role" && check_timers "$role"; then
    return 0
  fi
  die "this host is missing its D3/D4 folders (the admin's /srv/admin/current on VPS-1) or backup timers, which only root can create: run 'sudo ./madar-infra/scripts/bootstrap-vps.sh $role' on it (docs/runbooks/provision-host.md §3), then deploy again"
}

# Put back the ACL the last render replaced, so Redis can start on it (B2-R2-11, B2-R3-2).
restore_previous_acl() {
  [[ -f $acl_previous ]] || return 1
  log "restoring $acl_previous"
  install -m 640 -g "$acl_gid" "$acl_previous" "$acl_target"
}

# Redis reads an ACL file only at start-up, and Compose recreates a container only when its
# definition changes, not when a mounted file's content does. So a changed file means a restart, and
# then both passwords must work before anything else is deployed (B2-R1-7).
reload_redis_acl() {
  ((redis_acl_changed)) || return 0
  log "restarting Redis to load the new ACL"
  "${vps1_compose[@]}" restart redis >/dev/null || true
  if acl_answers; then
    log "Redis accepted the new ACL (default and homebox)"
    return 0
  fi
  if restore_previous_acl; then
    "${vps1_compose[@]}" restart redis >/dev/null || true
    die "Redis rejected the new ACL; the previous one is back at $acl_target. Check REDIS_PASSWORD and REDIS_HOMEBOX_PASSWORD, and 'compose logs redis'"
  fi
  die "Redis did not accept $acl_target; check the passwords, the directory's group (gid $acl_gid) and 'compose logs redis'"
}

# The stateful services (caddy, postgres, redis) with the ACL restore around them: this `up` is what
# recreates Redis on a changed definition, before `reload_redis_acl` runs, so a file Redis refuses
# would leave it down with the good one still in `users.acl.prev` (B2-R3-2).
apply_stateful_infra() {
  local failed=0
  "${vps1_compose[@]}" up -d --wait --wait-timeout 120 "${vps1_stateful[@]}" || failed=1
  if ((failed == 0)); then
    return 0
  fi
  # Only when this deploy wrote a new file: `users.acl.prev` is then exactly what was in place
  # before it. An unchanged render that fails to start is not an ACL-content problem.
  if ((redis_acl_changed)) && restore_previous_acl; then
    log "infra did not come up; retrying with the previous ACL"
    "${vps1_compose[@]}" up -d --wait --wait-timeout 120 "${vps1_stateful[@]}" || true
    die "the stateful services did not come up with the new ACL; the previous one is back at $acl_target. Check 'compose ps' and 'compose logs redis'"
  fi
  die "the stateful services did not come up; check 'compose ps' and 'compose logs redis'"
}

deploy_vps1() {
  local tag=$1 previous current started
  exec 9>"$state_dir/.deploy.lock"
  flock -n 9 || die "another deploy is running"

  current=$(running_tag vps1 api-public)
  # Step 1 doesn't touch the APIs; the tag is only needed to interpolate vps1.yml.
  export IMAGE_TAG=${current:-none} HEALTHZ_FORCE_FAIL=false

  # 1. Verify what bootstrap created, render the ACL, apply the synced infra, and load a changed ACL
  # before the APIs move.
  require_host_setup vps1
  render_redis_acl
  apply_stateful_infra
  reload_redis_acl
  "${vps1_compose[@]}" exec -T caddy caddy reload --config "$caddy_config" --adapter caddyfile

  # 2. Record the running tag; it is the rollback target.
  if [[ -n $current ]]; then
    printf '%s\n' "$current" > "$state_dir/previous_tag"
  fi
  previous=$(cat "$state_dir/previous_tag" 2>/dev/null || true)

  # 3. Pull with the token read from stdin; never keep the credential.
  local owner token
  token=$GHCR_TOKEN
  owner=$(env_get GHCR_OWNER)
  printf '%s' "$token" | docker login ghcr.io --username "$owner" --password-stdin >/dev/null
  unset token
  log "pulling $tag"
  IMAGE_TAG=$tag "${vps1_compose[@]}" pull "${api_services[@]}" "$media_service"
  # The backup image is tagged by `infra.yml` (the run SHA and `stable`), not by this deploy's tag,
  # and the timer needs it locally (B2-R1-1). Pull it here, while the GHCR credential is still open;
  # a missing backup image must not fail a backend deploy, so it is a warning, not a `die`.
  if ! IMAGE_TAG=$tag "${vps1_compose[@]}" --profile backup pull backup-media backup-media-weekly; then
    log "could not pull the backup image; the backup timers stay red until 'infra.yml' builds it"
  fi
  docker logout ghcr.io >/dev/null

  # 4. Migrate first. Expand/contract keeps the running API compatible with the new schema.
  log "running migrations"
  if ! IMAGE_TAG=$tag "${vps1_compose[@]}" run --rm -T migrate; then
    die "migration failed; the running containers were not touched (still ${current:-none})"
  fi

  # 5–6. Roll out and check health, including the media worker. A failed `up` rolls back too:
  # under `set -e` it would otherwise exit before the rollback branch (B2-R1-24).
  log "starting $tag"
  started=1
  start_apis "$tag" "$force_fail" || started=0
  if ((started)) && healthy_apis && healthy_services vps1 "$health_timeout" "$media_service"; then
    printf '%s\n' "$tag" > "$state_dir/current_tag"
    log "deployed $tag"
    return 0
  fi

  # 7. Roll back the APIs and the media worker together.
  log "health check failed for $tag"
  [[ -n $previous ]] || die "no previous tag to roll back to; $tag is left running for inspection"
  log "rolling back to $previous"
  start_apis "$previous" false
  if healthy_apis && healthy_services vps1 "$health_timeout" "$media_service"; then
    printf '%s\n' "$previous" > "$state_dir/current_tag"
    die "rolled back to $previous, which is healthy"
  fi
  die "rolled back to $previous, but it is not healthy either"
}

deploy_vps2() {
  local tag=$1 previous current owner token started
  exec 9>"$state_dir/.deploy.lock"
  flock -n 9 || die "another deploy is running"

  current=$(running_tag vps2 worker-imports)
  export IMAGE_TAG=${current:-none}
  if [[ -n $current ]]; then
    printf '%s\n' "$current" > "$state_dir/previous_tag"
  fi
  previous=$(cat "$state_dir/previous_tag" 2>/dev/null || true)

  require_host_setup vps2

  token=$GHCR_TOKEN
  owner=$(env_get GHCR_OWNER)
  printf '%s' "$token" | docker login ghcr.io --username "$owner" --password-stdin >/dev/null
  unset token
  log "pulling $tag on vps2"
  IMAGE_TAG=$tag "${vps2_compose[@]}" pull "${vps2_services[@]}"
  # The backup image's own tag, pulled while the credential is open (B2-R1-1). Non-fatal: a backend
  # deploy must not fail because a separate workflow has not built `madar-backup:stable` yet.
  if ! IMAGE_TAG=$tag "${vps2_compose[@]}" --profile backup pull backup-db; then
    log "could not pull the backup image; the backup timer stays red until 'infra.yml' builds it"
  fi
  docker logout ghcr.io >/dev/null

  log "starting vps2 services on $tag"
  # Guarded like VPS-1: under `set -e` a failed `up -d` would exit before the rollback (B2-R2-12).
  started=1
  IMAGE_TAG=$tag "${vps2_compose[@]}" up -d "${vps2_services[@]}" || started=0
  if ((started)) && healthy_services vps2 "$workers_timeout" "${vps2_services[@]}"; then
    printf '%s\n' "$tag" > "$state_dir/current_tag"
    log "deployed $tag to vps2"
    return 0
  fi

  log "health check failed for $tag on vps2"
  if [[ -z $previous ]]; then
    "${vps2_compose[@]}" ps
    die "no previous tag to roll back to; $tag is left running for inspection"
  fi
  log "restoring $previous on vps2"
  IMAGE_TAG=$previous "${vps2_compose[@]}" up -d "${vps2_services[@]}" || true
  healthy_services vps2 "$workers_timeout" "${vps2_services[@]}" \
    && die "rolled back to $previous on vps2, which is healthy"
  die "rolled back to $previous on vps2, but it is not healthy either"
}

host=vps1
mode=
while (($#)); do
  case $1 in
    --host)
      host=${2:-}
      [[ $host == vps1 || $host == vps2 ]] || usage
      shift 2
      ;;
    *)
      [[ -z $mode ]] || usage
      mode=$1
      shift
      ;;
  esac
done
[[ -n $mode ]] || usage
if [[ $mode != --infra-only && ! $mode =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]]; then
  die "invalid image tag: $mode"
fi
[[ $mode == --infra-only && $host == vps2 ]] && usage
force_fail=${HEALTHZ_FORCE_FAIL:-false}
[[ $force_fail == true || $force_fail == false ]] || die "HEALTHZ_FORCE_FAIL must be true or false"
[[ -r $env_file ]] || die "$env_file is missing"

# Take the GHCR token off stdin before anything else runs: `docker compose exec` and `run` forward
# stdin to the container and would swallow it.
GHCR_TOKEN=
if [[ $mode != --infra-only ]]; then
  [[ ! -t 0 ]] || die "pass the GHCR token on stdin"
  IFS= read -r GHCR_TOKEN || true
  [[ -n $GHCR_TOKEN ]] || die "no GHCR token on stdin"
fi
exec </dev/null
trap 'docker logout ghcr.io >/dev/null 2>&1 || true; unset GHCR_TOKEN' EXIT

if [[ $mode == --infra-only ]]; then
  require_host_setup vps1
  render_redis_acl
  export IMAGE_TAG=${IMAGE_TAG:-none} HEALTHZ_FORCE_FAIL=false
  apply_stateful_infra
  reload_redis_acl
  "${vps1_compose[@]}" exec -T caddy caddy reload --config "$caddy_config" --adapter caddyfile
  log "infra applied"
  exit 0
fi

if [[ $host == vps2 ]]; then
  deploy_vps2 "$mode"
else
  deploy_vps1 "$mode"
fi
