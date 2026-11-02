#!/usr/bin/env bash
# Run the backups runbook's morning check and both media restores in the real backup image
# (B2-R2-2). Usage: infra/scripts/check-backup-restore-commands.sh   (needs docker and jq)
#
# It builds infra/backup/Dockerfile (or uses $BACKUP_IMAGE), takes real snapshots with the real
# scripts against a local restic repository and an rclone `alias` remote standing in for the OCI
# bucket, then runs the commands the documents give, as the user and with the capabilities the
# Compose services give the backup containers (uid 10001, `cap_drop: ALL`). The three failures it
# stops from coming back:
#
#   * the image's restic 0.14 reads `snapshots --last 3` as a deprecated flag plus the snapshot id
#     `3`, and lists nothing with exit 0, so the SC-004 morning check looked empty. The commands are
#     read out of backups.md, owner-actions.md and the quickstart, not copied here;
#   * `backup-media` mounts /srv/media read-only, so a restore through that service fails with
#     "read-only file system". The restores are one-off `docker run` commands with a writable mount;
#   * a restic restore run as root leaves files owned by 10001, mode 0600, which `deploy` can
#     neither read nor copy. The restores run as 10001, so the files are the media's own.
#
# The wrapper flags of the two restores (`--user 10001:10001`, the writable mount) are pinned in the
# documents by check-doc-commands.sh; the commands inside them are read from backups.md here.
set -Eeuo pipefail

infra=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repo=$(cd "$infra/.." && pwd)
backups_md="$repo/docs/runbooks/backups.md"

for tool in docker jq; do
  command -v "$tool" >/dev/null || { echo "check-backup-restore-commands: $tool is not installed" >&2; exit 2; }
done

image=${BACKUP_IMAGE:-}
if [[ -z $image ]]; then
  image=madar-backup:ci
  docker build -q -t "$image" "$infra/backup" >/dev/null
fi

tmp=$(mktemp -d)
# shellcheck disable=SC2329 # called by the EXIT trap below, which SC2329 doesn't count
cleanup() {
  # The containers wrote as uid 10001, which this user cannot remove; give the tree back first.
  docker run --rm -u 0 -v "$tmp:/t" "$image" chown -R "$(id -u):$(id -g)" /t >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() {
  printf 'check-backup-restore-commands: %s\n' "$*" >&2
  exit 1
}

# --- a host-shaped tree: the restic repository, the staging directory, the media, the bucket -----
work=$tmp/work
mkdir -p "$work/repo" "$work/staging" "$work/media/logos" "$work/oci" "$tmp/stub"
printf 'a logo\n' > "$work/media/logos/one.webp"
cat > "$tmp/stub/pg_dump" <<'STUB'
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
chmod 755 "$tmp/stub/pg_dump"
docker run --rm -u 0 -v "$work:/w" "$image" \
  sh -c 'chown -R 10001:10001 /w && chmod 600 /w/media/logos/one.webp'

cat > "$tmp/env" <<ENV
RESTIC_REPOSITORY=/repo
RESTIC_PASSWORD=ci-password
B2_ACCOUNT_ID=ci-account
B2_ACCOUNT_KEY=ci-key
POSTGRES_PASSWORD=ci-password
BACKUP_DB_HOST=127.0.0.1
RCLONE_CONFIG_OCI_TYPE=alias
RCLONE_CONFIG_OCI_REMOTE=/oci
RCLONE_CONFIG_OCI_ACCESS_KEY_ID=ci
RCLONE_CONFIG_OCI_SECRET_ACCESS_KEY=ci
ENV

# The backup containers' shape (vps1.yml, vps2.yml): the image's user, no capabilities, caches in /tmp.
box() {
  docker run --rm --user 10001:10001 --cap-drop ALL --security-opt no-new-privileges:true \
    --env-file "$tmp/env" -e HOME=/tmp -e XDG_CACHE_HOME=/tmp/cache "$@"
}

# --- what the timers write: one database snapshot, the mirror and one media snapshot -------------
# shellcheck disable=SC2016 # $PATH is the container's, expanded by its sh
box -v "$infra/backup:/opt/backup:ro" -v "$tmp/stub:/stub:ro" \
  -v "$work/staging:/srv/backup" -v "$work/repo:/repo" "$image" \
  sh -c 'PATH=/stub:$PATH exec /opt/backup/backup-db.sh' >/dev/null \
  || fail "backup-db.sh failed in the image"
box -v "$infra/backup:/opt/backup:ro" -v "$work/media:/srv/media:ro" \
  -v "$work/oci:/oci" -v "$work/repo:/repo" "$image" \
  /opt/backup/backup-media.sh --weekly >/dev/null \
  || fail "backup-media.sh --weekly failed in the image"

# --- the morning check: every document's `restic snapshots … --latest N` lists last night's ------
db_id=$(box -v "$work/repo:/repo" "$image" restic snapshots --tag db --json | jq -r '.[0].short_id')
[[ -n $db_id && $db_id != null ]] || fail "the backup left no database snapshot to list"

snapshot_commands() { grep -ohE 'restic snapshots( --tag [a-z]+)? --(last|latest) [0-9]+' "$1" || true; }

for doc in "$backups_md" "$repo/docs/owner-actions.md" \
  "$repo/specs/003-d03-follow-push-sources/quickstart.md"; do
  name=${doc#"$repo/"}
  mapfile -t found < <(snapshot_commands "$doc")
  ((${#found[@]} > 0)) || fail "$name carries no 'restic snapshots … --latest N' morning check"
  for cmd in "${found[@]}"; do
    read -ra words <<<"$cmd"
    listed=$(box -v "$work/repo:/repo" "$image" "${words[@]}" 2>&1) || fail "$name: '$cmd' failed: $listed"
    grep -q "$db_id" <<<"$listed" \
      || fail "$name: '$cmd' does not list last night's snapshot ($db_id); it printed: ${listed:-nothing}"
  done
done

# --- the media restores --------------------------------------------------------------------------
# What the documents say, with the placeholder filled in.
mapfile -t mirror_found < <(grep -oE 'rclone copy oci:madar-media/logos/<file>\.webp /srv/media/logos/' "$backups_md" || true)
((${#mirror_found[@]} > 0)) || fail "backups.md has no 'rclone copy oci:madar-media/logos/<file>.webp' restore"
read -ra mirror_words <<<"${mirror_found[0]//<file>/one}"
mapfile -t snapshot_found < <(grep -oE "restic restore latest --tag media[^']*" "$backups_md" || true)
((${#snapshot_found[@]} > 0)) || fail "backups.md has no 'restic restore latest --tag media' restore"
snapshot_script=${snapshot_found[0]//<file>/one}

lose_logo() { box -v "$work/media:/srv/media" "$image" rm -f /srv/media/logos/one.webp; }
logo_field() { box -v "$work/media:/srv/media:ro" "$image" stat -c "$1" /srv/media/logos/one.webp; }
expect_logo_back() {
  local what=$1
  [[ $(box -v "$work/media:/srv/media:ro" "$image" cat /srv/media/logos/one.webp 2>&1) == "a logo" ]] \
    || fail "$what did not bring the logo back"
  [[ $(logo_field %u) == 10001 ]] || fail "$what left the logo owned by uid $(logo_field %u), not 10001"
}

# The control that says why the Compose service cannot be the restore: it mounts the media read-only.
docker compose -f "$infra/compose/vps1.yml" --env-file "$infra/compose/example.env" \
  --profile backup config --format json \
  | jq -e '.services["backup-media"].volumes | any(.target == "/srv/media" and .read_only == true)' >/dev/null \
  || fail "vps1.yml no longer mounts /srv/media read-only into backup-media; update the restore note in backups.md"
lose_logo
if box -v "$work/media:/srv/media:ro" -v "$work/oci:/oci:ro" "$image" "${mirror_words[@]}" >/dev/null 2>&1; then
  fail "a restore into a read-only mount worked; the control does not describe the backup-media service"
fi

lose_logo
box -v "$work/media:/srv/media" -v "$work/oci:/oci:ro" "$image" "${mirror_words[@]}" >/dev/null \
  || fail "the mirror restore failed: ${mirror_words[*]}"
expect_logo_back "the mirror restore"

lose_logo
box -v "$work/media:/srv/media" -v "$work/repo:/repo" "$image" sh -c "$snapshot_script" >/dev/null \
  || fail "the snapshot restore failed: $snapshot_script"
expect_logo_back "the snapshot restore"
[[ $(logo_field %a) == 600 ]] || fail "the snapshot restore left the logo at mode $(logo_field %a), not 600"

printf 'check-backup-restore-commands: ok (the snapshot list, the mirror restore and the snapshot restore run in the backup image)\n'
