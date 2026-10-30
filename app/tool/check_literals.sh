#!/usr/bin/env bash
# Fails on hard-coded visual values (constitution IV, research R20, SC-008).
# Values come from MadarColors/MadarText/MadarRadii in lib/core/theme/madar_tokens.dart.
set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"
status=0

scan() {
  local label="$1" pattern="$2"
  local hits
  hits="$(rg -n --pcre2 "$pattern" lib \
    --glob '!lib/core/theme/**' \
    --glob '!lib/core/network/generated/**' \
    --glob '!lib/core/db/*.g.dart' \
    --glob '!lib/l10n/**' || true)"
  if [[ -n "$hits" ]]; then
    echo "hard-coded $label:" >&2
    echo "$hits" >&2
    status=1
  fi
}

scan "colours" 'Color\(0x|(?<!Madar)\bColors\.'
scan "font family" 'fontFamily\s*:'
scan "numeric literals in insets and boxes" \
  '(EdgeInsets\w*|SizedBox|BorderRadius\.circular|Divider)[^;\n]*\b\d+(\.\d+)?\b'
scan "numeric literals in text, strokes and rules" \
  '(fontSize|strokeWidth|thickness)\s*[:=][^;\n]*\b\d+(\.\d+)?\b'
# A token plus a bare number is the same offence as a bare number; a token *multiplied* is
# how the app builds a size the scale lacks (40dp = s5 * 2), so those wait for a size group
# in tokens.json rather than being flagged here.
scan "arithmetic on a token" 'Madar\w+\.\w+\s*[+-]\s*\d'

if [[ $status -ne 0 ]]; then
  echo "use MadarSpace/MadarRadii/MadarText/MadarColors from core/theme" >&2
fi
exit $status
