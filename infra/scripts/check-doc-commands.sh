#!/usr/bin/env bash
# The FCM key install steps are one command, repeated identically in the three places that document
# them (B2-R1-7). Usage: infra/scripts/check-doc-commands.sh   (no docker, no root)
#
# `worker-notify` runs as uid 10001 with `cap_drop: ALL`, and bootstrap-vps.sh creates
# /srv/secrets as that uid, mode 700. Only root can give a file that owner, so `sudo -iu deploy
# install … -o 10001` fails with EPERM and a `deploy`-owned key is unreadable to the worker. This
# check fails when a document drifts back to a command that cannot work, or when one of the three
# files stops carrying the correct one.
set -Eeuo pipefail

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo=$(cd "$infra/.." && pwd)

dir_install='install -d -m 700 -o 10001 -g 10001 /srv/secrets'
file_install='install -m 600 -o 10001 -g 10001'
verify='docker compose exec worker-notify test -r /srv/secrets/fcm.json'

fail=0
problem() {
  printf 'check-doc-commands: %s\n' "$*" >&2
  fail=1
}

docs=(
  "$repo/docs/runbooks/push-notifications.md"
  "$repo/docs/runbooks/secrets.md"
  "$repo/docs/owner-actions.md"
)

for doc in "${docs[@]}"; do
  name=${doc#"$repo/"}
  [[ -f $doc ]] || { problem "$name is missing"; continue; }
  grep -qF "$dir_install" "$doc" \
    || problem "$name does not install /srv/secrets as root, uid 10001, mode 700 ('$dir_install')"
  grep -qF "$file_install" "$doc" \
    || problem "$name does not install the key as root, uid 10001, mode 600 ('$file_install')"
  # The two ways a reader used to be led into a key the worker cannot read.
  if grep -nE '(install .*-o deploy|-o deploy .*install)' "$doc" | grep -q 'secrets'; then
    problem "$name still installs a secret as 'deploy'; only root can give it uid 10001"
  fi
  if grep -n 'sudo -iu deploy install' "$doc"; then
    problem "$name runs 'sudo -iu deploy install'; deploy is not root and the install fails with EPERM"
  fi
done

# The runbook that T047 links to is also the one that proves the result.
grep -qF "$verify" "$repo/docs/runbooks/push-notifications.md" \
  || problem "push-notifications.md does not verify the key with '$verify'"
grep -qF "$verify" "$repo/docs/runbooks/secrets.md" \
  || problem "secrets.md does not verify the rotated key with '$verify'"

# And the code the documents describe: the mount, the directory and the uid.
grep -qF '/srv/secrets:/srv/secrets:ro' "$infra/compose/vps2.yml" \
  || problem "vps2.yml no longer mounts /srv/secrets read-only into worker-notify"
# shellcheck disable=SC2016 # the literal line bootstrap writes, with its variables
grep -qF 'install -d -m 700 -o "$app_uid" -g "$app_uid" /srv/secrets' "$infra/scripts/bootstrap-vps.sh" \
  || problem "bootstrap-vps.sh no longer creates /srv/secrets for the image's user"
grep -q 'app_uid=10001' "$infra/scripts/bootstrap-vps.sh" \
  || problem "bootstrap-vps.sh's app_uid is no longer 10001, which the documents hard-code"

((fail == 0)) || exit 1
printf 'check-doc-commands: ok (one root install command in all three documents)\n'
