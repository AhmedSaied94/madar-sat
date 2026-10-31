#!/usr/bin/env bash
# Render, install and check the Redis ACL file (B2-R2-1, B2-R2-11).
#
# `redis:7.4.12` runs as uid/gid 999 and mounts /srv/madar/redis at /etc/redis. It needs the file
# (mode 640) *and* the directory (mode 750) readable by that group: the 640 file inside a 700
# directory still aborted with "error opening the ACL file: Permission denied" (B2-R2-1).
#
# deploy.sh calls this with --out; check-redis-acl.sh calls the same --out and then --check, so CI
# proves the real modes, owner and group instead of building its own directory.
#
# Usage:
#   render-redis-acl.sh --out <dir> [--env-file <file>] [--group <gid>]
#   render-redis-acl.sh --check <dir> [--group <gid>]
#
#   --out    writes <dir>/users.acl (640) in <dir> (750), both group <gid> (default 999), and keeps
#            the file it replaced as <dir>/users.acl.prev. Prints `changed` or `unchanged` on
#            stdout; every other line goes to stderr.
#   --check  proves the directory and the file modes and group; exits 1 with the reason when one
#            is wrong, so a 700 directory fails the check.
#
# The passwords come from the environment, or from --env-file, and are never copied into the repo.
set -Eeuo pipefail

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
template=$infra/redis/users.acl.tmpl
acl_gid=999
out=
check=
env_file=

usage() { echo "usage: $0 (--out <dir> [--env-file <file>] | --check <dir>) [--group <gid>]" >&2; exit 2; }
log() { printf '[redis-acl] %s\n' "$*" >&2; }
die() { printf '[redis-acl] error: %s\n' "$*" >&2; exit 1; }

# One value from an env file, without executing it.
env_get() { sed -n "s/^$1=//p" "$env_file" | tail -n 1; }

# The mode of a path, as three octal digits.
mode_of() { stat -c '%a' "$1"; }

# True when the mode's group digit allows reading and searching (r-x: 5 or 7).
group_can_read() {
  local digits=${1: -3}
  [[ ${digits:1:1} == [57] ]]
}

while (($#)); do
  case $1 in
    --out) out=${2:-}; shift 2 ;;
    --check) check=${2:-}; shift 2 ;;
    --env-file) env_file=${2:-}; shift 2 ;;
    --group) acl_gid=${2:-}; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n $out || -n $check ]] || usage
[[ -z $out || -z $check ]] || usage
[[ $acl_gid =~ ^[0-9]+$ ]] || die "--group takes a numeric gid (the redis user's, 999), not '$acl_gid'"

if [[ -n $check ]]; then
  file=$check/users.acl
  [[ -d $check ]] || die "$check is not a directory"
  [[ -f $file ]] || die "$file is missing"
  dir_mode=$(mode_of "$check")
  file_mode=$(mode_of "$file")
  group_can_read "$dir_mode" \
    || die "$check is mode $dir_mode: the redis user (gid $acl_gid) cannot traverse it, so Redis cannot open the ACL"
  [[ $(stat -c '%g' "$check") == "$acl_gid" ]] \
    || die "$check belongs to gid $(stat -c '%g' "$check"), not $acl_gid"
  [[ $file_mode == 640 ]] || die "$file is mode $file_mode, not 640"
  [[ $(stat -c '%g' "$file") == "$acl_gid" ]] \
    || die "$file belongs to gid $(stat -c '%g' "$file"), not $acl_gid"
  echo "users.acl is mode 640, group $acl_gid, in a mode $dir_mode directory"
  exit 0
fi

[[ $out == /* ]] || die "--out takes an absolute path, not '$out'"
[[ -r $template ]] || die "$template is missing"

redis_password=${REDIS_PASSWORD:-}
homebox_password=${REDIS_HOMEBOX_PASSWORD:-}
if [[ -n $env_file ]]; then
  [[ -r $env_file ]] || die "$env_file is not readable"
  redis_password=$(env_get REDIS_PASSWORD)
  homebox_password=$(env_get REDIS_HOMEBOX_PASSWORD)
fi
[[ -n $redis_password ]] || die "REDIS_PASSWORD is empty (in $env_file or the environment)"
[[ -n $homebox_password ]] || die "REDIS_HOMEBOX_PASSWORD is empty (the home box's user)"

# deploy is a member of the group (bootstrap-vps.sh adds it); without one, install would fail
# silently under a pipe and Docker would later create the directory as root.
getent group "$acl_gid" >/dev/null \
  || die "no group with gid $acl_gid on this host; run bootstrap-vps.sh vps1 once (it creates it)"

tmp=$(mktemp)
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT
# The ACL file accepts `user` lines only (a `#` line aborts Redis), so the template's comments go.
# shellcheck disable=SC2016 # envsubst takes the variable names literally
(umask 077 && REDIS_PASSWORD=$redis_password REDIS_HOMEBOX_PASSWORD=$homebox_password \
  envsubst '${REDIS_PASSWORD} ${REDIS_HOMEBOX_PASSWORD}' < "$template" \
  | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' > "$tmp")

# -d re-applies 750 and the group on every run, so an older 700 directory is corrected (B2-R2-1).
install -d -m 750 -g "$acl_gid" "$out"
changed=0
if [[ -f $out/users.acl ]] && ! cmp -s "$tmp" "$out/users.acl"; then
  install -m 640 -g "$acl_gid" "$out/users.acl" "$out/users.acl.prev"  # the restore point (B2-R2-11)
  changed=1
elif [[ ! -f $out/users.acl ]]; then
  changed=1
fi
# Always install: an unchanged file with a wrong mode or group is still wrong.
install -m 640 -g "$acl_gid" "$tmp" "$out/users.acl"
log "wrote $out/users.acl (mode 640, gid $acl_gid, directory 750)"
[[ $changed == 1 ]] && echo changed || echo unchanged
