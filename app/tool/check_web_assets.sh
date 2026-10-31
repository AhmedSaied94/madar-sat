#!/usr/bin/env bash
# The PWA opens the drift database, so a web build must ship both WebAssembly pieces
# (M-R1-2, FR-049, SC-009). Run after `flutter build web`.
#
# Usage: ./tool/check_web_assets.sh [build dir]   (default: build/web)
set -euo pipefail
cd "$(dirname "$0")/.."

build_dir="${1:-build/web}"
missing=0
for asset in sqlite3.wasm drift_worker.js; do
  if [[ ! -s "$build_dir/$asset" ]]; then
    echo "missing from $build_dir: $asset" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "copy them from web/ into the build output, or keep web/ as the Flutter web asset root" >&2
  exit 1
fi

echo "the web build ships sqlite3.wasm and drift_worker.js"
