#!/usr/bin/env bash
# Fails when a copy of a design token/font artefact differs from the design package.
# Copies are verbatim (constitution IV, research R17): fix the design package, then re-copy.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
design="$here/../madar-design/design-system"

check() {
  local src="$1" dst="$2"
  if ! cmp -s "$src" "$dst"; then
    echo "copy differs from source: $dst" >&2
    echo "  source: $src" >&2
    exit 1
  fi
}

check "$design/code/flutter/madar_tokens.dart" "$here/lib/core/theme/madar_tokens.dart"

for f in "$design"/fonts/*.ttf; do
  check "$f" "$here/assets/fonts/$(basename "$f")"
done

echo "token and font copies match the design package"
