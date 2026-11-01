#!/usr/bin/env bash
# Prove the backup containers can write the staging directory and read the media with the uid and
# the capabilities their Compose services give them (B2-R1-2). Usage:
#   infra/scripts/check-backup-permissions.sh        (needs docker; no root on the host)
#
# Before the fix both services ran as root with `cap_drop: ALL`: root without CAP_DAC_OVERRIDE is
# still bound by the owner and mode bits, and /srv/backup was `deploy`'s mode 700 while the media
# files are 0600 owned by uid 10001. `pg_dump --file` and rclone/restic therefore failed with EACCES
# every night.
#
# The check reads the *rendered* Compose files (not a copy of their values), then runs a throwaway
# container with the same uid and capabilities over a tree shaped like the hosts': /srv/backup mode
# 700 owned by the backup uid with a 0600 dump, /srv/media with a 0600 file, and another uid's 0600
# file that must stay unreadable.
set -Eeuo pipefail

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# The backup image's base (infra/backup/Dockerfile): sh and coreutils, nothing else needed here.
image=${BACKUP_BASE_IMAGE:-postgres:16.15-bookworm}
backup_uid=10001

tmp=$(mktemp -d)
# shellcheck disable=SC2329 # called by the EXIT trap below, which SC2329 doesn't count
cleanup() {
  # The container wrote as uid 10001, which this user cannot remove; give the tree back first.
  docker run --rm -u 0 -v "$tmp:/t" "$image" chown -R "$(id -u):$(id -g)" /t >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  printf 'check-backup-permissions: %s\n' "$*" >&2
  exit 1
}

render() {
  docker compose -f "$infra/compose/$1.yml" --env-file "$infra/compose/example.env" \
    --profile backup config --format json
}

vps1=$(render vps1)
vps2=$(render vps2)

# --- what the Compose files give each backup service --------------------------------------------
check_service() {
  local file=$1 service=$2 rendered user caps
  if [[ $file == vps1 ]]; then rendered=$vps1; else rendered=$vps2; fi
  user=$(jq -r --arg s "$service" '.services[$s].user // ""' <<<"$rendered")
  [[ $user == "$backup_uid:$backup_uid" ]] \
    || fail "$file.yml: $service runs as '${user:-root}', not the uid that owns its paths ($backup_uid)"
  caps=$(jq -c --arg s "$service" '.services[$s].cap_drop // []' <<<"$rendered")
  [[ $caps == '["ALL"]' ]] || fail "$file.yml: $service does not drop every capability ($caps)"
}
check_service vps2 backup-db
check_service vps1 backup-media

# --- what the host side gives those paths --------------------------------------------------------
awk '/^ensure_dirs\(\)/,/^}/' "$infra/scripts/bootstrap-vps.sh" > "$tmp/ensure_dirs.sh"
# shellcheck disable=SC2016 # the literal line bootstrap writes, with its variables
grep -qF 'install -d -m 700 -o "$app_uid" -g "$app_uid" /srv/backup' "$tmp/ensure_dirs.sh" \
  || fail "bootstrap-vps.sh does not create /srv/backup for the backup uid, mode 700"
# shellcheck disable=SC2016 # the literal line the deploy verifies, with its variables
grep -qF 'check_dir "$srv_root/backup" 700 "$app_uid"' "$infra/scripts/deploy.sh" \
  || fail "deploy.sh does not expect /srv/backup to be the backup uid's, mode 700"
grep -q 'app_uid=10001' "$infra/scripts/bootstrap-vps.sh" \
  || fail "bootstrap-vps.sh's app_uid is no longer 10001, which the Compose files hard-code"

# --- the kernel side: the container's uid and capabilities, against a host-shaped tree -----------
mkdir -p "$tmp/host/backup" "$tmp/host/media/logos" "$tmp/host/secret"
printf 'not really a dump\n' > "$tmp/host/backup/madar.dump"
printf 'a logo\n' > "$tmp/host/media/logos/one.webp"
printf 'not a real key\n' > "$tmp/host/secret/key"
docker run --rm -u 0 -v "$tmp/host:/host" "$image" sh -c "
  chown -R $backup_uid:$backup_uid /host/backup /host/media
  chmod 700 /host/backup
  chmod 600 /host/backup/madar.dump /host/media/logos/one.webp
  chown 0:0 /host/secret/key
  chmod 755 /host/secret
  chmod 600 /host/secret/key
" >/dev/null

# The backup container's own shape: write the staging dump, read a media file, and `install -d` the
# staging directory the script creates at start-up.
docker run --rm --user "$backup_uid:$backup_uid" --cap-drop ALL \
  -v "$tmp/host/backup:/srv/backup" -v "$tmp/host/media:/srv/media:ro" \
  --entrypoint sh "$image" -c '
    printf "more\n" >> /srv/backup/madar.dump &&
    cat /srv/media/logos/one.webp >/dev/null &&
    install -d -m 700 /srv/backup
  ' >/dev/null \
  || fail "the backup uid could not write /srv/backup or read /srv/media with cap_drop ALL"

# And the negative: without CAP_DAC_OVERRIDE, another uid's 0600 file stays unreadable. This is the
# rule that made root fail before the fix.
if docker run --rm --user "$backup_uid:$backup_uid" --cap-drop ALL \
  -v "$tmp/host/secret:/secret:ro" --entrypoint sh "$image" -c 'cat /secret/key' >/dev/null 2>&1; then
  fail "the backup uid read another uid's 0600 file; the host's permission model is not being tested"
fi

printf 'check-backup-permissions: ok (uid %s, cap_drop ALL, /srv/backup 700, media 0600)\n' "$backup_uid"
