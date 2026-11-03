#!/usr/bin/env bash
# Writes a flavor file for CI from the JSON in $APP_ENV_JSON (a GitHub secret). The flavor files
# hold the hosts and the Firebase identifiers, so they stay out of the repo; env/example.json
# lists their keys, and the JSON must have exactly those keys, each a string. The values are
# never printed.
#
# --or-example writes env/example.json instead when $APP_ENV_JSON is empty (a pull request that
# gets no secrets, such as Dependabot's): the build compiles, with no host and no Firebase.
# In that mode a key the template has and the secret lacks is written as an empty string with a
# warning, so the PR that introduces a key still runs its checks before the owner has updated
# the secret. The release workflows call this without the flag and keep failing until the
# secret and the template agree exactly.
#
# Usage: APP_ENV_JSON=... ./tool/write_env.sh env/prod.json [--or-example]
set -euo pipefail
cd "$(dirname "$0")/.."

out="${1:?usage: ./tool/write_env.sh env/<flavor>.json [--or-example]}"
fallback="${2:-}"

if [[ -z ${APP_ENV_JSON:-} ]]; then
  if [[ $fallback == --or-example ]]; then
    cp env/example.json "$out"
    echo "::warning::no flavor secret in this run; $out is env/example.json (no host, no Firebase)"
    exit 0
  fi
  echo "::error::APP_ENV_JSON is empty: set the flavor's secret (docs/runbooks/secrets.md)" >&2
  exit 1
fi

python3 - "$out" "$fallback" <<'PY'
import json, os, sys
path, fallback = sys.argv[1], sys.argv[2]
tolerant = fallback == '--or-example'
try:
    values = json.loads(os.environ['APP_ENV_JSON'])
except ValueError:
    sys.exit('::error::the flavor secret is not valid JSON')
if not isinstance(values, dict):
    sys.exit('::error::the flavor secret must be a JSON object')
expected = set(json.load(open('env/example.json', encoding='utf-8')))
missing, extra = sorted(expected - set(values)), sorted(set(values) - expected)
if extra:
    sys.exit(f'::error::the flavor secret has keys env/example.json does not: {extra}')
if missing and not tolerant:
    sys.exit(f'::error::the flavor secret does not match env/example.json: missing {missing}')
if missing:
    print(
        f'::warning file=app/env/example.json::the flavor secret lacks {missing}; '
        'written as empty here. Add them to the secret before a release build '
        '(docs/runbooks/secrets.md, "Update the app\'s flavor values").'
    )
    for key in missing:
        values[key] = ''
not_strings = sorted(k for k, v in values.items() if not isinstance(v, str))
if not_strings:
    sys.exit(f'::error::these flavor keys must be strings: {not_strings}')
with open(path, 'w', encoding='utf-8') as f:
    json.dump(values, f, indent=2, ensure_ascii=False)
    f.write('\n')
PY

echo "wrote $out from the flavor secret"
