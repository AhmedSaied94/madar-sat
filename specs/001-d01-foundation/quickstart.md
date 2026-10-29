# Quickstart: validating D1 · Foundation

These are the runnable checks that prove each lane's story and the day's done check. The commands are what the D1 implementation provides; the folder `README`/`CLAUDE.md` files have the full detail. Shapes live in [contracts/](contracts/) and tables in [data-model.md](data-model.md). They aren't repeated here.

## Prerequisites

- **Day 0 done:**
  - both VPSs, with reserved IPs;
  - the Firebase project and web app;
  - GHCR access;
  - the GitHub secrets `WG_CI_CONFIG`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS` (VPS-1's host key line for `10.8.0.1`) and `FIREBASE_SERVICE_ACCOUNT`, and the repo variable `VPS1_IP`.
- **A local machine** with:
  - Docker with Compose v2;
  - `uv` (Python 3.13);
  - Node 22 with corepack (pnpm);
  - Flutter stable at the version pinned in `app/.flutter-version`;
  - WireGuard, with your peer config;
  - `rg`, `jq`, `curl`.
- **A fresh snapshot outside the repo.** From `../old_app`, run the README "Refresh the snapshot" commands, then copy `migration/data/` to `~/madar-snapshot/` (never into `madar_sat/`).

## Lane B1: data and contract

```sh
cd backend
docker compose -f ../infra/compose/dev.yml up -d postgres redis          # PostgreSQL 16 + Redis 7, local only
uv run alembic upgrade head                                              # 0001 (schema.sql) + 0002
uv run python -m app.cli load-snapshot --snapshot-dir ~/madar-snapshot --report-dir /tmp
uv run python -m app.cli load-snapshot --snapshot-dir ~/madar-snapshot --report-dir /tmp   # second run
uv run python -m app.cli rehost-media --report-dir /tmp                 # MEDIA_ROOT=./.media locally
uv run pytest                                                            # unit + contract tests on PostgreSQL 16
uv run python -m app.cli export-openapi && git diff --exit-code openapi/
```

**Expected:**

- **Migrations:** `0001`'s SQL file hash test passes.
- **Load:** both runs print `reconciled: true` with identical counts ([contracts/load-report.md](contracts/load-report.md)). `checks.card_sharing_labels_found = 0`.
- **Rehost:** `media.urls_total` adds up. Failures are listed in the details file, and their columns are NULL.
- **Tests:** pytest is green, including:
  - `test_clock_status.py` (live and finished `estimated`, no score);
  - `test_time.py` (Cairo → UTC, DST, `"--:--"`);
  - `test_frequency.py` (regex, Cyrillic `Н`);
  - `test_contract_*.py` (schema conformance for every FR-008 endpoint, `304`, `422`, `404`).

```sh
uv run uvicorn app.public:app --port 8000 &
curl -si "localhost:8000/v1/matches?from=$(date -u +%FT00:00:00Z)&to=$(date -u -d tomorrow +%FT00:00:00Z)" | head -20
ETAG=$(curl -sI "localhost:8000/v1/satellites" | awk -F': ' '/^etag/I{print $2}' | tr -d '\r')
curl -s -o /dev/null -w '%{http_code} %{size_download}\n' -H "If-None-Match: $ETAG" localhost:8000/v1/satellites   # 304 0
curl -s "localhost:8000/v1/matches?from=2026-10-01T00:00:00Z&to=2026-10-20T00:00:00Z" | jq .error.code            # "validation_error"
curl -s localhost:8000/v1/matches/999999999 | jq .error.code                                                        # "match_not_found"
```

**Contract freeze (13:00):** the owner reviews `git diff` of `backend/openapi/*.json` against [contracts/](contracts/), then:

```sh
git tag -a contract-v1 -m "D1 contract freeze" && git push origin contract-v1
```

**After the tag**, every contract change must be non-breaking as FR-014 defines it. This check must exit `0` (run it from the repo root):

```sh
for f in public admin; do
  git show contract-v1:backend/openapi/$f.json > /tmp/$f-v1.json
  docker run --rm -v /tmp:/base:ro -v "$PWD/backend/openapi":/head:ro tufin/oasdiff \
    breaking /base/$f-v1.json /head/$f.json --fail-on ERR
done
```

## Lane B2: servers and CI

```sh
# Once per host, as root, from the repo checkout on the VPS (over the OCI serial console the first time):
sudo infra/scripts/bootstrap-vps.sh vps1      # or vps2: Docker, WireGuard, deploy user, /srv dirs, firewall
sudo infra/scripts/check-firewall.sh          # prints the persisted rules
```

**From outside, on a machine not on WireGuard:**

```sh
nmap -Pn -p 22,80,443,5432,6379,8000,8001 <ip1>    # only 80, 443 open
nmap -Pn -sU -p 51820 <ip1>                        # open|filtered (WireGuard)
curl -sI https://api.<ip1>.sslip.io/healthz | grep -Ei 'strict-transport|nosniff|referrer-policy|etag'
curl -s https://api.<ip1>.sslip.io/healthz | jq .data           # {"db":"ok","redis":"ok"}
```

**Over WireGuard:** `curl -sk https://10.8.0.1/admin/api/healthz` returns `200`. The same request from the public internet must fail to connect.

**CI:**

- **Backend deploy:** merge a trivial `backend/` change to `master`. `backend.yml` runs lint → test → openapi + clients → arm64 build → GHCR → deploy, and `/healthz` is green within 15 minutes (SC-005).
- **Rollback drill:** run the `backend.yml` `workflow_dispatch` input `break_healthcheck=true`, which deploys an image that sets `HEALTHZ_FORCE_FAIL=1`. The job fails, and `docker ps` on VPS-1 shows the previous tag running again.
- **Secret scan:** a PR adding `AKIA` plus 16 fake characters to a test file fails `gitleaks.yml`.
- **Other folders:** PRs touching `admin/`, `app/` and `infra/` run their workflows. `app.yml` attaches `app-prod-debug.apk`, and `pwa.yml` prints the preview-channel URL.

## Lane A: admin

```sh
cd admin
corepack enable && pnpm install
pnpm orval                                   # client + Zod + MSW from ../backend/openapi/admin.json (tag contract-v1)
pnpm prism &                                 # Prism mock on :4010
pnpm dev                                     # Vite on :5173, API proxied to Prism
pnpm test && pnpm lint && pnpm typecheck && pnpm build && ./scripts/check-literals.sh && ./scripts/check-token-copy.sh
```

**Expected:** open `http://localhost:5173/login`.

- `?mock=invalid_credentials` shows «إيميل أو باسوورد غلط» and «تبقّت 3 محاولات…».
- `?mock=account_locked` shows the lockout panel with «14:32».
- `?mock=login_ok` lands on the A0 shell, with the sidebar on the right.

Vitest covers every README state of `SidebarNav`, `DataTable`, `Field`, `StatusChip` and `Toast`. Compare the screens with the Login and Admin components PNGs.

## Lane M: app

```sh
cd app
flutter pub get && dart run build_runner build -d          # swagger_parser client, freezed, drift, riverpod
./tool/check_token_copy.sh && ./tool/check_literals.sh
flutter analyze
docker run --rm -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:$(cat .flutter-version) flutter test   # goldens in the pinned image
flutter build apk --debug --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json
```

**Expected:**

- **Tests:**
  - golden tests pass for 11 components (FR-043, Logo included) × their states × RTL × {light, dark} × {1.0, 1.3};
  - `MatchRow` and `CarriageRow` each expose one Arabic screen-reader label;
  - `test/core/format/` covers Western digits, `ص`/`م` and the LTR frequency island;
  - the drift round-trip test passes.
- **On a phone:** install the `prod` debug APK. The matches route lists today's local-day matches from VPS-1, or shows `EmptyState`. `/gallery` opens in this debug build, and a release build has no `/gallery` route.
- **On the web:** `flutter build web --release -t lib/main_prod.dart --dart-define-from-file=env/prod.json`, serve `build/web`, and open `/gallery` and the matches route in Chrome with DevTools → Network. No request goes to `fonts.gstatic.com` or `fonts.googleapis.com` (FR-042). If one does, a glyph is missing from the bundled fonts: add it to the bundle rather than allowing the fetch.

## Done check (spec SC-010)

| Check | How |
| --- | --- |
| VPS-1 serves `/v1` with snapshot data over HTTPS | `curl -s https://api.<ip1>.sslip.io/v1/satellites \| jq '.data \| length'` returns > 0 (32 with the 2026-10-28 snapshot) |
| Contract tagged `v1` | `git ls-remote --tags origin contract-v1` |
| The admin login screen renders against the mock | Lane A steps above |
| The app shows the gallery (goldens pass) and loads `/v1/matches` | Lane M steps above, with the CI `app.yml` run green |
| CI green in all four folders | The latest `master` runs of `backend.yml`, `admin.yml`, `app.yml` and `infra.yml` are all ✓ |
