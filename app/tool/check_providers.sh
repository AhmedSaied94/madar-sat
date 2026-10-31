#!/usr/bin/env bash
# Every provider is generated with @riverpod (M-R1-16, constitution VIII). A hand-written
# Provider(, NotifierProvider(, StreamProvider(, FutureProvider(, StateProvider( or
# AsyncNotifierProvider( in lib/ means the two styles have mixed again.
#
# Usage: ./tool/check_providers.sh        (exit 1 and list the files when one is found)
set -euo pipefail
cd "$(dirname "$0")/.."

hand_written='^[[:space:]]*(late )?final [A-Za-z_][A-Za-z0-9_<>, ?]*Provider[[:space:]]*=[[:space:]]*(Provider|NotifierProvider|StreamProvider|FutureProvider|StateProvider|AsyncNotifierProvider|AutoDispose[A-Za-z]*Provider)[.(<]'

if matches=$(grep -rnE "$hand_written" lib --include='*.dart' --exclude='*.g.dart' --exclude-dir=generated); then
  echo "Hand-written providers found; use @riverpod and run build_runner:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "all providers are generated with @riverpod"
