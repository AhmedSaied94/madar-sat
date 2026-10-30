# Quickstart: validating D2 · Core flows

These are the runnable checks that prove each lane's story and the day's done check. The commands are what the D2 implementation provides; each folder's `README`/`CLAUDE.md` and the runbooks have the full detail. Shapes live in [contracts/](contracts/) and tables in [data-model.md](data-model.md); they aren't repeated here.

## Prerequisites

- **D1 is on `master`**, with the contract tagged `contract-v1` and VPS-1 serving `/v1`.
- **The owner has done the D2 "before" items** (`docs/owner-actions.md`, section 002):
  - `ADMIN_JWT_SECRET` and `REDIS_HOMEBOX_PASSWORD` in VPS-1's `.env`;
  - `CORS_ORIGINS` on VPS-1 including `https://madar-sat--master-p2bbuj53.web.app`;
  - VPS-2's `.env`: the base values `Settings` requires (database and Redis URLs to VPS-1's VCN IP, `MEDIA_BASE_URL`, `MEDIA_ROOT`, `MEDIA_REHOST_ALLOWED_HOSTS`, `CORS_ORIGINS`), plus `SATAIR_FIREBASE_PROJECT_ID`, `SATAIR_FIREBASE_API_KEY` and `SCRAPE_USER_AGENT`;
  - `HOME_BOX_WG_IP` in VPS-1's `.env`, for the firewall rule that limits Redis on `wg0` to the home box;
  - the GitHub variable `VPS2_VCN_IP`, and VPS-2's host key added to `DEPLOY_KNOWN_HOSTS`;
  - the home box: Docker, a WireGuard peer (`infra/scripts/wg-add-peer.sh home-box`), and its `.env` with `REDIS_URL` and `GHCR_READ_TOKEN`;
  - each editor device: a WireGuard peer, with Caddy's internal root CA trusted.
- **A local machine** as on D1, plus the WireGuard peer config and Caddy's root CA saved at `~/.config/madar/caddy-root.crt`.

## Lane B1: admin API

```sh
cd backend
docker compose -f ../infra/compose/dev.yml up -d postgres redis
uv run alembic upgrade head                                   # 0001, 0002, 0003
uv run alembic downgrade 0002 && uv run alembic upgrade head  # 0003 is reversible
uv run pytest                                                 # unit, db and contract tests, PostgreSQL 16
uv run python -m app.cli export-openapi && git diff --exit-code openapi/
uv run python -m app.cli create-admin --email editor@example.com --name "محرر" --role editor   # prompts twice
```

**Expected:**

- **Tests:** pytest is green, including:
  - `test_auth_*.py`: login, the sixth attempt locked out with identical responses for unknown emails, refresh rotation, family revocation on reuse, `csrf_failed`, a deactivated admin;
  - `test_admin_writes.py`: `428`, `409` with `changed_by`, the audit diff of changed fields only, `locked_fields`, the dataset bumps, imported-link removal kept hidden, bulk all-or-nothing;
  - `test_manual_status.py`: every row of the data-model validation table, and clear back to clock;
  - `test_uploads.py`: each signature, oversize, a fake `.png`, a decompression bomb, a duplicate, audio trimmed to 30 s;
  - `test_edit_reaches_v1.py`: after a save, the old `/v1/matches` and `/v1/live` ETags get `200` with the change;
  - `test_admin_routes_have_roles.py`.
- **Contract:** `export-openapi` leaves no diff, and the D1 oasdiff loop (001 quickstart) still exits `0`. `/v1` is unchanged.
- **CLI:** `create-admin` refuses a password under 12 characters, a mismatch and a duplicate email, and never echoes the password.

**Over WireGuard, after the deploy** (from a peer):

```sh
API=https://10.8.0.1/admin/api; CA=--cacert ~/.config/madar/caddy-root.crt
curl $CA -s -c /tmp/jar -X POST $API/auth/login -H 'Content-Type: application/json' \
     -d '{"email":"editor@example.com","password":"…"}' | jq '.data.expires_in'                      # 900
TOKEN=…   # data.access_token
curl $CA -s -D - -o /dev/null -H "Authorization: Bearer $TOKEN" $API/matches/48213 | grep -i etag
curl $CA -s -X PATCH $API/matches/48213 -H "Authorization: Bearer $TOKEN" \
     -H 'Content-Type: application/json' -d '{"fields":{"stadium":"اختبار"}}' | jq .error.code       # "precondition_required"
```

From the internet, `https://api.<ip1>.sslip.io/admin/api/…` must answer `404`: no admin route exists on the public app.

## Lane B2: ingestion and hosts

```sh
cd backend
uv run pytest tests/adapters                      # parse on saved pages, resolution, upsert, bridge, prune, locks
uv run pytest tests/adapters -k homebox_acl       # applies the ACL template to the test Redis with ACL SETUSER
```

**Expected:**

- `test_ysscores_parse.py` passes on the three saved pages, including a pinned kickoff.
- `test_resolve.py` passes, including the ported `competitionSimilarity` cases.
- `test_upsert.py` passes: a second run creates 0 rows, a locked kickoff survives, the 45-minute duplicate probe, imported links removed only by their own source, manual links untouched.
- `test_satair_bridge.py` passes on a saved Firestore REST response: typed values, `hiddenChannels`, `channelCommentators`, an orphan channel id skipped.
- `test_rehost_logo.py` passes: only empty logos are filled, and hosts outside the allowlist are refused.
- The `homebox` ACL can queue and consume a task, but can't read `auth:*` or run `CONFIG`.

**On the hosts, after the merge:**

```sh
# CI: backend.yml's deploy (VPS-1, now also worker-media) and deploy-vps2 jobs are green; the amd64 image is tagged stable
ssh deploy@10.8.0.1 'docker compose -p madar ps --format "{{.Service}} {{.Health}}"'   # api-public, api-admin, worker-media healthy
ssh -J deploy@10.8.0.1 deploy@$VPS2_VCN_IP 'docker compose -p madar ps --format "{{.Service}} {{.Health}}"'
#   worker-imports, worker-scrape, worker-maintenance healthy; exactly one beat
# On the home box:
docker compose -f home-box.yml ps                                  # worker-scrape healthy, consuming scrape_home
```

- **Unattended run:** wait for the next `ysscores-fixtures` slot (every 3 h, on the hour, UTC), or start one with the command in `docs/runbooks/imports-and-sources.md`. Then:

  ```sh
  psql "$DATABASE_URL_SYNC" -c "select source, status, items_found, items_upserted, http_errors, raw_path
                                from import_runs order by started_at desc limit 3"
  ```

  The run is `succeeded` (or `partial` with its reasons in `run.json`), `raw_path` exists on VPS-2, and tomorrow's Cairo day has ysscores matches with UTC kickoffs. A second run reports `items_upserted = 0` for unchanged fixtures.
- **Bridge:** stop the home box's worker, start a `legacy` run, and see tomorrow's fixtures, with their channel links, appear without duplicates.
- **Logos:** a new ysscores team with a logo on an allowlisted host gets `logo_asset_id` filled by `worker-media`, and its URL is on `media.<ip1>.sslip.io`.

## Lane A: admin

```sh
cd admin
pnpm install && pnpm orval && git diff --exit-code src/api/generated/    # generated from the committed admin.json
pnpm typecheck && pnpm lint && pnpm test                                  # Vitest + MSW: A3, A4, dialogs, Cairo time
pnpm prism & pnpm dev                                                     # against Prism serving backend/openapi/admin.json
NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt pnpm dev:wg            # proxies /admin/api to https://10.8.0.1 over WireGuard
```

**Expected:**

- **Tests:** green, including:
  - A3 grouping and filters;
  - A4 Cairo entry on each side of the DST change (stored UTC differs by the right offset);
  - the `409` dialog with `changed_by`, for an admin and for a source;
  - the unsaved guard;
  - typed confirmation for bulk removal, which an editor doesn't see;
  - Zod parsing of every response.
- **Against Prism:** `?mock=edit_conflict`, `?mock=precondition_required` and `?mock=forbidden_remove_channels` show the right states.
- **Against the real API:** log in, then:
  1. open tomorrow in A3 and filter to missing channels;
  2. open a match and add two channels with commentators;
  3. hide one channel on this match only, and set manual live 1–0;
  4. save, and see «تم الحفظ».
- **Conflict:** save the same match from a second browser, then save again from the first: the conflict dialog appears, naming the other editor.
- **Visuals:** A3 and A4 match `screens/02-content/Matches.png` and `MatchEditor.png` at 1440, and stay usable at 1024.

## Lane M: app

```sh
cd app
flutter pub get && dart run build_runner build --delete-conflicting-outputs
flutter analyze && flutter test                               # unit, widget and golden tests
tool/check_literals.sh && tool/check_token_copy.sh
git tag app-v0.2.0 && git push origin app-v0.2.0              # the owner, once M is merged: app-release.yml builds the AAB
```

**Expected:**

- **Tests:** green, including:
  - local-day grouping across Cairo/Morocco/Gulf zones;
  - the channel-line ranking (my satellites, then free);
  - every `StatusBlock` variant (estimated live without a score);
  - the SWR repository (`200` updates, `304` keeps, offline emits the cache);
  - `StaleHint` thresholds;
  - one audio player at a time;
  - goldens for `CommentatorRow`, `FilterChipRow`, `SearchField`, `Segmented` and `StaleHint` (RTL, both themes, 1.0× and 1.3×).
- **Release:** `app-release.yml` produces a signed `prod` AAB artifact. The owner enrols in Play App Signing, uploads it to the closed track, and a tester installs it (`docs/runbooks/store-releases.md`).
- **On a real Android phone, with the closed-test build:**
  - **S2:** page the week, filter to live, pull to refresh.
  - **S3:** a match with 130 or more channels shows its answer in under 1 s and scrolls to the end smoothly; a clip plays; copying a frequency works; the reception video opens.
  - **S4** lists only matches on Nilesat or Badr.
  - **S5.2:** switch categories and search `11843`.
  - **Offline:** in airplane mode, S2–S5 show their cached copies with a "last updated" hint.
- **PWA:** the preview channel URL loads S2 and S3 with data from VPS-1 (after the CORS change), and the Network tab shows no font or CanvasKit request to Google.

## Done check (spec SC-010)

*"An admin logs in over WireGuard and edits a match, and the change appears in the app; ysscores (or the bridge) imports tomorrow's fixtures; S2–S5 work on a real Android phone; closed-test build uploaded"*

1. **Edit → app:** from a WireGuard peer, log in to the admin (`pnpm dev:wg`) and change tomorrow's match: kickoff, one channel, a manual status. On the phone, S2 and S3 show the change within 60 s. Do this 3 times (SC-001).
2. **Fixtures:** `import_runs` shows an unattended `ysscores` (or `legacy`) run since the morning, and tomorrow's Cairo day has its fixtures (SC-004).
3. **Phone:** the Lane M device walk-through above passes on the closed-test build (SC-006 to SC-008).
4. **Closed test:** the AAB is on the Play closed track, and at least one tester has installed it (SC-009).

Record the evidence on each lane's PR, and tick the owner items in `docs/owner-actions.md`.
