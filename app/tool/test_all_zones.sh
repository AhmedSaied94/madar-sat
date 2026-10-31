#!/usr/bin/env bash
# Runs the whole suite in two host zones (D2 spec, FR-053): a test that reads the host zone
# instead of an injected one passes in one and fails in the other. Run it with the Flutter
# in .flutter-version, on Linux x64, which is what the goldens are rendered by (R18).
#
#   ./tool/test_all_zones.sh
#
# It fails when either run fails, and when the run changed anything under test/goldens (a
# comparison writes nothing, but a mismatch leaves test/goldens/failures/, and
# `--update-goldens` rewrites files). Changes already there when it starts, such as goldens
# you have not committed yet, are not counted: the check is "no change between the runs".
set -uo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"
status=0

goldens_state() { git status --porcelain -- test/goldens; }

before="$(goldens_state)"

for zone in UTC Africa/Cairo; do
  echo "== flutter test (TZ=$zone)"
  if ! TZ="$zone" flutter test; then
    echo "flutter test failed under TZ=$zone" >&2
    status=1
  fi
done

after="$(goldens_state)"
if [[ "$before" != "$after" ]]; then
  echo "the runs changed test/goldens:" >&2
  diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") >&2 || true
  status=1
fi

exit $status
