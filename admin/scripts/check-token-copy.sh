#!/usr/bin/env bash
# Fails when a token or font copy in admin/src differs from its source in madar-design (research R15).
# The copies are never edited by hand: change tokens.json, run generate_tokens.py, then copy again.
set -euo pipefail

cd "$(dirname "$0")/.."
design=../madar-design/design-system
status=0

check() {
  local source="$1" copy="$2"
  if [ ! -f "$copy" ]; then
    echo "missing copy: $copy (source: $source)" >&2
    status=1
  elif ! cmp -s "$source" "$copy"; then
    echo "copy differs from its source: $copy (source: $source)" >&2
    status=1
  fi
}

check "$design/tokens.css" src/styles/tokens.css
check "$design/code/react/tokens.ts" src/styles/tokens.ts

for source in "$design"/fonts/*.ttf "$design"/fonts/OFL-*.txt; do
  check "$source" "src/assets/fonts/$(basename "$source")"
done

for copy in src/assets/fonts/*; do
  if [ ! -f "$design/fonts/$(basename "$copy")" ]; then
    echo "font file without a source in madar-design: $copy" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "token and font copies match madar-design"
fi
exit "$status"
