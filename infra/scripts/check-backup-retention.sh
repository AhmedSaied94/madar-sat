#!/usr/bin/env bash
# Prove the backup scripts prune, initialise their repository, and can run night after night
# (B2-R1-3, B2-R1-5). Usage: infra/scripts/check-backup-retention.sh   (needs restic and jq)
#
# It runs the real scripts, with `pg_dump` and `rclone` stubbed, against two local restic
# repositories, exactly the way the timers run them in the container:
#
#   * both repositories start empty, so the first run must create them (`restic init`); before
#     B2-R1-5 it failed with "unable to open config file";
#   * every database run snapshots the same host and the same path, so `forget` sees one group and
#     prunes: 8 runs in one day leave a handful of snapshots, and 8 more do not add any. Before
#     B2-R1-3 the host was the container's random hostname and the dump was timestamped, so each run
#     was its own group and every snapshot was kept for ever;
#   * the weekly media run does the same with `--keep-weekly 4`.
#
# The exact count is restic's business: besides the newest snapshot of each period, `ApplyPolicy`
# also keeps the oldest one while the bucket still has counts left, so a same-day batch settles at 2.
# What the check asserts is the property the timers depend on: the repository does not grow.
#
# No database, no bucket and no network: the two stubs are the only things the scripts call out to.
set -Eeuo pipefail

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

command -v restic >/dev/null || { echo "check-backup-retention: restic is not installed" >&2; exit 2; }
command -v jq >/dev/null || { echo "check-backup-retention: jq is not installed" >&2; exit 2; }

tmp=$(mktemp -d)
cleanup() {
  chmod -R u+w "$tmp" 2>/dev/null || true
  rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/bin" "$tmp/staging" "$tmp/media/logos" "$tmp/db-repo" "$tmp/media-repo"
printf 'a logo\n' > "$tmp/media/logos/one.webp"

# The scripts' only two external commands, replaced: pg_dump writes a few bytes to --file, and
# rclone mirrors nothing.
cat > "$tmp/bin/pg_dump" <<'STUB'
#!/usr/bin/env bash
file=
while (($#)); do
  case $1 in
    --file) file=$2; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n $file ]] || { echo "pg_dump stub: no --file" >&2; exit 2; }
printf 'not really a dump\n' > "$file"
STUB
cat > "$tmp/bin/rclone" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$tmp/bin/pg_dump" "$tmp/bin/rclone"
export PATH="$tmp/bin:$PATH"

export RESTIC_PASSWORD=ci-restic-password
export B2_ACCOUNT_ID=ci-account
export B2_ACCOUNT_KEY=ci-key
export POSTGRES_PASSWORD=ci-postgres
export BACKUP_DB_HOST=127.0.0.1
export BACKUP_STAGING="$tmp/staging"
export BACKUP_KEEP_DAILY=7
export BACKUP_KEEP_WEEKLY=4
export BACKUP_KEEP_MONTHLY=6
export MEDIA_ROOT="$tmp/media"
export RCLONE_CONFIG_OCI_ACCESS_KEY_ID=ci
export RCLONE_CONFIG_OCI_SECRET_ACCESS_KEY=ci
export RCLONE_BUCKET=madar-media
# No heartbeat: a Kuma push is not what this check is about, and an empty value is a no-op.
# D4 T030: the scripts refuse to run without a heartbeat URL. Nothing listens on this one, so each
# push fails and is only logged, which keeps this drill about retention.
export KUMA_PUSH_URL_BACKUP_DB=http://127.0.0.1:1/api/push/ci
export KUMA_PUSH_URL_BACKUP_MEDIA=http://127.0.0.1:1/api/push/ci
export KUMA_PUSH_URL_BACKUP_MEDIA_WEEKLY=http://127.0.0.1:1/api/push/ci

fail() {
  printf 'check-backup-retention: %s\n' "$*" >&2
  exit 1
}

count_snapshots() { restic snapshots --json | jq 'length // 0'; }

# --- the database: an empty repository, nightly runs that must not accumulate --------------------
export RESTIC_REPOSITORY="$tmp/db-repo"
if restic cat config >/dev/null 2>&1; then
  fail "the test repository must start empty"
fi

run_database_backups() {
  local _
  for _ in 1 2 3 4 5 6 7 8; do
    "$infra/backup/backup-db.sh" >/dev/null || fail "backup-db.sh failed on an empty repository"
  done
}

run_database_backups
first=$(count_snapshots)
((first >= 1 && first < 8)) || fail "8 nightly runs left $first database snapshots; retention did not prune"

# The property that matters: a second batch of runs must not grow the repository. Without the pinned
# host and the fixed dump path every run is its own group, so this doubles.
run_database_backups
second=$(count_snapshots)
((second <= first + 1)) || fail "8 more nightly runs grew the repository from $first to $second snapshots"

restic snapshots --json | jq -e '
  all(.[]; .hostname == "madar-vps2")
  and all(.[]; (.paths | length) == 1 and (.paths[0] | endswith("/madar.dump")))
' >/dev/null || fail "a database snapshot is not pinned to madar-vps2 and one fixed dump path"

# --- the media: the same repository story for the weekly snapshot --------------------------------
export RESTIC_REPOSITORY="$tmp/media-repo"
run_media_backups() {
  local _
  for _ in 1 2 3 4 5; do
    "$infra/backup/backup-media.sh" --weekly >/dev/null \
      || fail "backup-media.sh --weekly failed on an empty repository"
  done
}

run_media_backups
first=$(count_snapshots)
((first >= 1 && first < 5)) || fail "5 weekly runs left $first media snapshots; retention did not prune"
run_media_backups
second=$(count_snapshots)
((second <= first + 1)) || fail "5 more weekly runs grew the repository from $first to $second snapshots"

restic snapshots --json | jq -e 'all(.[]; .hostname == "madar-vps1")' >/dev/null \
  || fail "a media snapshot is not pinned to madar-vps1"

printf 'check-backup-retention: ok (init on an empty repository, and the repository does not grow)\n'
