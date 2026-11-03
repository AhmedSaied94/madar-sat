# Data model: D4 · MVP launch

D4 changes no database schema: there is no Alembic revision, and `/v1` and `/admin/api` don't change. This file lists the new settings, on-disk layouts and report formats the lanes share.

## Settings (host `.env`, read by `backend/app/settings.py`)

| Variable | Type | Default | Where set | Rule |
|---|---|---|---|---|
| `TRUSTED_PROXIES` | comma list of IPs | `10.8.0.1` | VPS-1 `.env` → `api-public` (Compose); `api-admin` keeps the default | `client_ip()` reads `X-Forwarded-For` only when the peer is in the list, then takes the right-most hop not in the list (R1). For `api-public` the value is `127.0.0.1,172.30.0.1` |
| `RATE_LIMIT_EXEMPT_IPS` | comma list of IPs | empty | VPS-1 `.env`, only during a load-test window | An exact match on the derived client IP skips the `/v1` limiter. A non-empty value logs a warning at startup and on every exempt request (debug), summarized each minute (info) (R3) |

VPS-1's Compose network gets a fixed subnet `172.30.0.0/24` with gateway `172.30.0.1` (B2), so the trusted peer is stable across recreations.

## App build value (`app/env/prod.json`, public)

| Key | Example | Rule |
|---|---|---|
| `MIRROR_BASE_URL` | `https://app.<ip1>.sslip.io` | `https` only, no path or trailing slash. Empty means the release files are served from the page's own origin (preview channel). Read by `stage_web_release.sh`, not by Dart |

## Release layout (Lane M output, B2 input)

```text
build/web_release/
├── index.html, flutter_bootstrap.js, manifest.json, favicon.png, icons/
├── sw.js                      # stamped with the release hash
├── firebase-messaging-sw.js, firebase-config.js
├── drift_worker.js            # same-origin shim: importScripts(<base>/r/<hash>/drift_worker.js)
├── release.json               # {"hash": "<16 hex>", "mirror": "<url or empty>", "built_at": "<ISO-8601 UTC>"}
└── r/<hash>/                  # main.dart.js (+ parts), canvaskit/, assets/, version.json, sqlite3.wasm, drift_worker.js (the real worker)
    └── each file also as .br and .gz
```

- `<hash>` is the first 16 hex characters of the SHA-256 over the sorted `(relative path, SHA-256)` pairs of the files under `r/`. The same inputs always give the same hash.
- Nothing under `r/<hash>/` ever changes after upload.

## Mirror on VPS-1

```text
/srv/app-mirror/r/<hash>/…     # one folder per release
/srv/app-mirror/release-check.txt   # the current release hash, written by the release job, read by Kuma
```

- Caddy serves `/r/*` with `public, max-age=31536000, immutable`, with precompressed `.br` / `.gz` when the client accepts them.
- Pruning keeps every release from the last 30 days and always the newest 3.

## Admin releases on VPS-1

```text
/srv/admin/releases/<git sha>/   # each built bundle
/srv/admin/releases/placeholder/ # the bootstrap page
/srv/admin/current -> releases/<git sha>   # relative symlink, swapped atomically
```

- Caddy's wg0 site serves `root /srv/admin/current`.
- The deploy keeps the newest 5 releases plus `placeholder`.

## Report formats

### Load report (`docs/load-tests/<date>-mvp.md`, B1)

The report records: the date, the git SHA, the API image tag, and the VPS-1 shape. Then the allowlist window (start and end, UTC), and the k6 version and command. For each scenario it gives the rate, duration, requests, p50, p95 and p99, error share, `429` count, `304` share and cache hit share (from the API's cache log counters). Then VPS-1 CPU and memory (min, avg, max), pass or fail per FR-002 target, and any fix and re-run.

### Security findings (`security-review.md`, B1)

| ID | Severity | Where (file or host) | Owner lane | Finding | Status | Fix |
|---|---|---|---|---|---|---|

- Status is one of `open`, `fixed (<sha>)`, `accepted (owner, reason)` or `false positive (reason)`.
- `SR-1` is R1.
- Only the owner may set `accepted` on a HIGH finding.

### Import report (`python -m app.adapters.report`, B2)

- **`runs --hours 48`:** one row per scheduled slot (source, slot time UTC, run id, status, items found and upserted, manual yes/no, reason).
- **`coverage --days 4`:** one row per Cairo day and prioritized competition (`Competition.priority IS NOT NULL`), with matches, matches with at least 1 visible channel, and the unmatched names.
- The exit code is non-zero when a slot is missing or was run by hand. That is evidence, not an alarm.

### Bug-bash results (`bug-bash-results.md`, Lane M)

One table per platform (Android release build, installed iPhone PWA, desktop Chrome 1440) with the device and OS, the build or release hash, and, per step from [bug-bash.md](bug-bash.md): pass / fail / n/a, the issue or task id, and a note. A timing table follows (first load and repeat, Fast 4G profile and a real network, mirror share of bytes).
