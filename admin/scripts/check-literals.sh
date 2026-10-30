#!/usr/bin/env bash
# SC-008 / research R20: no raw colors, pixel sizes or font names in admin code.
# Visual values live only in src/styles/ (token copies and global CSS); generated code is skipped.
# The eslint rule tailwindcss/no-arbitrary-value covers bracketed Tailwind values.
set -euo pipefail

cd "$(dirname "$0")/.."

pattern='#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?([0-9a-fA-F]{2})?\b|\brgba?\(|\bhsla?\(|\b[0-9]+(\.[0-9]+)?px\b|font-family|fontFamily'

if rg --line-number --color never \
  --glob '!src/styles/**' \
  --glob '!src/api/generated/**' \
  --glob '!src/assets/**' \
  -e "$pattern" src; then
  echo "check-literals: raw color, px or font literal found above; use the token classes instead" >&2
  exit 1
fi

echo "check-literals: no raw visual literals in src/"
