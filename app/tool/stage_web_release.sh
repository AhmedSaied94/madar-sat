#!/usr/bin/env bash
# Stages a Flutter web build as the hashed release layout (research R11,
# specs/004-d04-mvp-launch/contracts/web-release.md).
#
# Usage: ./tool/stage_web_release.sh <env-file> <out-dir> [input-dir]
#
#   <env-file>   the flavor file the build used (reads MIRROR_BASE_URL, which may be empty)
#   <out-dir>    where the release is written, e.g. build/web_release
#   [input-dir]  an existing Flutter build (default: build/web)
#
# Output: the layout in specs/004-d04-mvp-launch/data-model.md "Release layout":
# the shell files at the root, everything else under r/<hash>/, release.json, and .br/.gz
# beside every release file. Prints RELEASE_HASH=<hash> as its last line.
#
# Never overwrites a release: a different input is a different hash, and the same input
# gives the same hash.
set -euo pipefail

# Arguments are relative to the caller's directory, whatever this script does next.
script_dir=$(cd "$(dirname "$0")/.." && pwd)

die() { echo "stage_web_release: $*" >&2; exit 1; }

[[ $# -ge 2 && $# -le 3 ]] || die "usage: $0 <env-file> <out-dir> [input-dir]"
env_file=$(realpath -m "$1")
out=$(realpath -m "$2")
in=$(realpath -m "${3:-build/web}")
cd "$script_dir"

[[ -d "$in" ]] || die "no Flutter web build in $in (run flutter build web first)"
[[ -s "$in/index.html" ]] || die "$in/index.html is missing: is this a web build?"
command -v python3 >/dev/null || die "python3 is required to read the env file and stamp files"
command -v brotli >/dev/null || die "brotli is required for the .br files (apt-get install brotli)"
command -v gzip >/dev/null || die "gzip is required for the .gz files"

# 1. The mirror base: https, no path, no trailing slash. Empty on a preview build.
mirror=$(python3 - "$env_file" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding='utf-8') as handle:
        value = json.load(handle).get('MIRROR_BASE_URL') or ''
except FileNotFoundError:
    value = ''
print(value.strip() if isinstance(value, str) else '')
PY
)
mirror=${mirror%/}
if [[ -n $mirror && ! $mirror =~ ^https://[^/]+$ ]]; then
  die "MIRROR_BASE_URL must be https with no path, or empty (got '$mirror')"
fi

# The files the build leaves at the root, which stay there. Everything else is payload and
# belongs to the release folder; `drift_worker.js` is payload (the real worker) and is
# replaced at the root by the shim this script writes, and `release.json` is written here.
is_shell() {
  case "$1" in
    index.html|flutter_bootstrap.js|manifest.json|favicon.png|sw.js|sw_core.mjs|\
    firebase-messaging-sw.js|firebase-config.js) return 0 ;;
    icons/*) return 0 ;;
  esac
  return 1
}

# The root after staging: the build's shell files plus the two this script writes.
is_shell_output() {
  is_shell "$1" && return 0
  case "$1" in
    icons|drift_worker.js|release.json) return 0 ;;
  esac
  return 1
}

# 2. A clean copy of the build, without Flutter's own worker (the pinned Flutter may still
#    emit one when --pwa-strategy is passed; ours replaces it) and without the standalone
#    loader, which the customisable bootstrap already carries inline. Staging into a
#    directory that already holds a release would mix two layouts, so it must be absent or
#    empty.
if [[ -d "$out" && -n $(ls -A "$out" 2>/dev/null) ]]; then
  die "$out already holds files; stage into a fresh directory (release folders are immutable)"
fi
rm -rf "$out"
mkdir -p "$out"
cp -a "$in/." "$out/"
rm -f "$out/flutter_service_worker.js" "$out/flutter.js" "$out/flutter.js.map"

# The build must carry the WebAssembly pieces before they are filed away.
./tool/check_web_assets.sh "$in" >/dev/null

# 3. The hash: the first 16 hex characters of the SHA-256 over the sorted
#    (path, SHA-256) pairs of the non-shell files, so the same input gives the same hash
#    and different content gives a different one.
shell_files=()
release_files=()
while IFS= read -r -d '' entry; do
  relative=${entry#./}
  if is_shell "$relative"; then shell_files+=("$relative"); else release_files+=("$relative"); fi
done < <(cd "$out" && find . -type f -print0 | LC_ALL=C sort -z)

[[ ${#release_files[@]} -gt 0 ]] || die "$in holds no files to put under r/<hash>/"
for required in index.html flutter_bootstrap.js sw.js sw_core.mjs manifest.json; do
  printf '%s\n' "${shell_files[@]}" | grep -qx "$required" || die "$required is missing from the build"
done

hash=$(
  cd "$out"
  for file in "${release_files[@]}"; do
    printf '%s  %s\n' "$(sha256sum "$file" | cut -d' ' -f1)" "$file"
  done | sha256sum | cut -c1-16
)
[[ $hash =~ ^[0-9a-f]{16}$ ]] || die "the computed hash '$hash' is not 16 hex characters"

# 4. Move the release files, keeping sqlite3.wasm and the real drift worker with them: both
#    are megabytes that must come from the mirror. A same-origin shim stands in for the
#    worker, because a browser only starts a worker script from its own origin.
release_dir="$out/r/$hash"
mkdir -p "$release_dir"
for file in "${release_files[@]}"; do
  mkdir -p "$release_dir/$(dirname "$file")"
  mv "$out/$file" "$release_dir/$file"
done

cat > "$out/drift_worker.js" <<'SHIM'
// The same-origin drift worker (research R11): browsers only start a worker script from
// the page's own origin, so this shim loads the real worker out of the release folder on
// the mirror (or from this origin when the mirror base is empty).
importScripts('__MIRROR_BASE__/r/__RELEASE_HASH__/drift_worker.js');
SHIM

# 5. release.json: what the worker and the bootstrap read, and what a bug bash quotes.
cat > "$out/release.json" <<JSON
{
  "hash": "$hash",
  "mirror": "$mirror",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

# 6. Stamp the hash and the mirror into the files that need them at runtime.
stamp() {
  python3 - "$1" "$hash" "$mirror" <<'PY'
import sys
path, hash_value, mirror = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding='utf-8') as handle:
    text = handle.read()
with open(path, 'w', encoding='utf-8') as handle:
    handle.write(text.replace('__RELEASE_HASH__', hash_value).replace('__MIRROR_BASE__', mirror))
PY
}
for stamped in flutter_bootstrap.js sw.js drift_worker.js; do
  [[ -f "$out/$stamped" ]] || die "$stamped is missing from the build (Flutter copies web/ into it)"
  stamp "$out/$stamped"
  grep -q "$hash" "$out/$stamped" || die "$stamped does not carry the release hash after stamping"
done

# 7. Precompress every release file: Caddy serves `precompressed br gzip`, so 1 OCPU never
#    compresses a megabyte of wasm per request.
(
  cd "$release_dir"
  while IFS= read -r -d '' file; do
    gzip -9 -n -c "$file" > "$file.gz"
    brotli -q 11 -f -o "$file.br" "$file"
  done < <(find . -type f -print0 | LC_ALL=C sort -z)
)

# 8. The staged tree must hold shell files and r/<hash>/ only. The directories the move
#    empties (assets/, canvaskit/ and their nested folders) are removed, deepest first, so
#    nothing half-empty ships.
find "$out" -mindepth 1 -depth -type d -empty -delete
./tool/check_web_assets.sh "$out" >/dev/null
for entry in "$out"/*; do
  name=$(basename "$entry")
  [[ $name == r ]] && continue
  is_shell_output "$name" || die "a file outside the shell list would ship at the root: $name"
done

echo "staged $out (mirror: ${mirror:-same origin})"
echo "RELEASE_HASH=$hash"
