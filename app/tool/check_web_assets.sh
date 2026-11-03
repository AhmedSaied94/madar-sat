#!/usr/bin/env bash
# The PWA opens the drift database and takes push, so a web build (and a staged release)
# must ship the files they need (M-R1-2, FR-049, SC-009; research R11, R12).
#
# Usage: ./tool/check_web_assets.sh [build dir]   (default: build/web)
#
# Two shapes:
#   * a Flutter build (`build/web`): sqlite3.wasm and drift_worker.js at the root;
#   * a staged release (`build/web_release`): the shell at the root, the app's files under
#     r/<hash>/, including sqlite3.wasm, the real drift_worker.js and main.dart.js.
set -euo pipefail
cd "$(dirname "$0")/.."

build_dir="${1:-build/web}"
missing=0
require() {
  [[ -s "$build_dir/$1" ]] || { echo "missing from $build_dir: $1" >&2; missing=1; }
}

if [[ -d "$build_dir/r" ]]; then
  # A staged release: the shell, then the release folder the shell points at.
  for asset in index.html flutter_bootstrap.js manifest.json favicon.png \
    sw.js sw_core.mjs release.json drift_worker.js \
    firebase-messaging-sw.js firebase-config.js; do
    require "$asset"
  done
  shopt -s nullglob
  release_dirs=("$build_dir"/r/*/)
  shopt -u nullglob
  if [[ ${#release_dirs[@]} -ne 1 ]]; then
    echo "$build_dir must hold exactly one r/<hash>/ folder, found ${#release_dirs[@]}" >&2
    missing=1
  else
    release=${release_dirs[0]#"$build_dir"/}
    for asset in main.dart.js sqlite3.wasm drift_worker.js; do
      require "$release$asset"
    done
  fi
else
  for asset in sqlite3.wasm drift_worker.js firebase-messaging-sw.js firebase-config.js; do
    require "$asset"
  done
fi

if [[ "$missing" -ne 0 ]]; then
  echo "copy them from web/ into the build output, or keep web/ as the Flutter web asset root" >&2
  exit 1
fi

echo "the web build ships sqlite3.wasm, drift_worker.js and the FCM worker"
