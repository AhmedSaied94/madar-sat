#!/usr/bin/env bash
# Prove that the rendered Redis ACL is readable by the redis user and works (B2-R1-1, B2-R2-1, T081).
#
# Usage: infra/scripts/check-redis-acl.sh        (needs docker; no root on the host)
#
# It renders infra/redis/users.acl.tmpl through the same script deploy.sh calls
# (render-redis-acl.sh), so the directory and file modes checked here are the ones a deploy writes,
# then starts redis:7.4.12 with the compose command against that file and pings as `default` and as
# `homebox`. A 700 directory must fail the check: that is the outage B2-R2-1 fixed.
set -Eeuo pipefail

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
image=${REDIS_IMAGE:-redis:7.4.12}
acl_gid=999
container=madar-acl-check-$$
default_password=ci-default-password-0123456789
homebox_password=ci-homebox-password-0123456789
render=$infra/scripts/render-redis-acl.sh

tmp=$(mktemp -d)
# shellcheck disable=SC2329 # called by the EXIT trap below, which SC2329 doesn't count
cleanup() {
  docker rm -f "$container" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

# The render CI runs as an unprivileged user with no gid 999, so it renders into its own group and
# a container gives the result gid 999 afterwards. The modes are the ones deploy.sh writes.
render_group=$(id -g)
REDIS_PASSWORD=$default_password REDIS_HOMEBOX_PASSWORD=$homebox_password \
  "$render" --out "$tmp/good" --group "$render_group" >/dev/null
chown_to_redis() {
  # Keep the runner as the owner (so it can still stat and remove the tree) and give the result the
  # redis user's gid, which is what the container needs.
  docker run --rm -u 0 -v "$tmp:/acl" "$image" chown "$(id -u):$acl_gid" "/acl/$1" "/acl/$1/users.acl"
}
chown_to_redis good

"$render" --check "$tmp/good" --group "$acl_gid" >/dev/null \
  || { echo "check-redis-acl: the rendered ACL is not readable by gid $acl_gid" >&2; exit 1; }

# The negative fixture: the same file and group in a 700 directory, which Redis cannot traverse.
mkdir -m 700 "$tmp/bad"
cp "$tmp/good/users.acl" "$tmp/bad/users.acl"
chown_to_redis bad
if "$render" --check "$tmp/bad" --group "$acl_gid" 2>/dev/null; then
  echo "check-redis-acl: a mode 700 directory passed the check; it must fail (B2-R2-1)" >&2
  exit 1
fi

docker run -d --name "$container" -v "$tmp/good:/etc/redis:ro" "$image" \
  sh -c 'exec docker-entrypoint.sh redis-server --aclfile /etc/redis/users.acl --save "" --appendonly no' \
  >/dev/null

ping_as() {
  docker exec "$container" redis-cli --user "$1" --pass "$2" --no-auth-warning ping 2>/dev/null | grep -qx PONG
}

deadline=$((SECONDS + 30))
until ping_as default "$default_password"; do
  if ((SECONDS >= deadline)); then
    docker logs "$container" >&2 || true
    echo "check-redis-acl: redis never answered as default; is the ACL unreadable?" >&2
    exit 1
  fi
  sleep 1
done

ping_as homebox "$homebox_password" || { echo "check-redis-acl: the homebox user cannot PING" >&2; exit 1; }
if ping_as homebox "$default_password"; then
  echo "check-redis-acl: the homebox user accepted the default password" >&2
  exit 1
fi

# A rotation (B2-R2-11): render again with a new `default` password and reload the way a deploy does.
# The new password must work and the old one must not, or "rotate the Redis password" ends in
# WRONGPASS on every client.
rotated_password=ci-rotated-password-0123456789
REDIS_PASSWORD=$rotated_password REDIS_HOMEBOX_PASSWORD=$homebox_password \
  "$render" --out "$tmp/rotated" --group "$render_group" >/dev/null
chown_to_redis rotated
"$render" --check "$tmp/rotated" --group "$acl_gid" >/dev/null
docker rm -f "$container" >/dev/null
docker run -d --name "$container" -v "$tmp/rotated:/etc/redis:ro" "$image" \
  sh -c 'exec docker-entrypoint.sh redis-server --aclfile /etc/redis/users.acl --save "" --appendonly no' \
  >/dev/null
deadline=$((SECONDS + 30))
until ping_as default "$rotated_password"; do
  if ((SECONDS >= deadline)); then
    docker logs "$container" >&2 || true
    echo "check-redis-acl: the rotated ACL never answered as default" >&2
    exit 1
  fi
  sleep 1
done
if ping_as default "$default_password"; then
  echo "check-redis-acl: the previous password still works after a rotation" >&2
  exit 1
fi

echo "check-redis-acl: $image read the ACL as uid 999, both users answered, and a rotated password replaced the old one"
