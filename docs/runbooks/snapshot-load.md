# Load the Sat Air snapshot

Loads the old app's data snapshot into VPS-1's PostgreSQL, then copies its media (logos, photos, voice clips) onto the media host. Both are Lane B1's commands (`python -m app.cli`), run as one-off `cli` containers of the deployed image. Re-running either is safe: rows are upserted, nothing is deleted, and media that is already hosted is skipped. It writes to production's database and `/srv/media`. Background: SD §10, research R10, `specs/001-d01-foundation/contracts/load-report.md`, and B1's task T048.

## Before you start

- A successful backend deploy, so the schema is migrated and `/srv/madar/current_tag` exists ([deploy-and-rollback.md](deploy-and-rollback.md)).
- `MEDIA_REHOST_ALLOWED_HOSTS` set in VPS-1's `/srv/madar/.env`: the hosts that the snapshot's media URLs point to, comma-separated. Only those hosts are downloaded from.
- The snapshot on your machine: `../old_app/migration/data/` next to this repository. It holds the old app's data, so it never goes into the repository or through GitHub (D15). Copy it straight to the host.
- Your WireGuard tunnel up.

The loader reads these files. A missing file loads as an empty list, so check the counts in step 2:

| Folder | Files |
| --- | --- |
| `hosting/` | `satellites.json`, `channels.json`, `competitions.json`, `teams.json`, `rights.json` |
| `firestore/` | `settings.json`, `matchDays.json`, `teamDict.json`, `feeds.json` |

## 1. Copy the snapshot

From the repository root on your machine:

```bash
rsync -a --delete ../old_app/migration/data/ ubuntu@10.8.0.1:madar-snapshot/
ssh ubuntu@10.8.0.1
sudo rsync -a --delete --chown=deploy:deploy madar-snapshot/ /srv/snapshot/
ls /srv/snapshot/hosting /srv/snapshot/firestore
rm -r madar-snapshot
```

The `cli` container mounts `/srv/snapshot` read-only, and writes to `/srv/reports` and `/srv/media`.

## 2. Load the data

In the "Working on VPS-1" shell ([deploy-and-rollback.md](deploy-and-rollback.md#working-on-vps-1)):

```bash
dc run --rm cli load-snapshot --snapshot-dir /srv/snapshot --report-dir /srv/reports
```

It prints one line per collection and the report's path:

```text
load-snapshot: reconciled=True
  satellites: source=… loaded=… merged=… skipped=…
  …
report: /srv/reports/load-report-<UTC timestamp>.json
```

- **Exit 0** only when the run reconciles. Otherwise it rolls the whole load back, exits 1, and says `(not reconciled: rolled back)`. The details are in the `load-report-<timestamp>.details.jsonl` file next to the report.
- A card-sharing label found in the data also stops the load (FR-005): `checks` in the report shows it.
- **Run it a second time.** It must print the same counts and change nothing (FR-004).

Compare the counts with SD §1.2 (the snapshot of 2026-10-28): 32 satellites, 2,418 channel rows, 134 competitions, 1,513 teams, 75 rights holders.

## 3. Rehost the media

```bash
dc run --rm cli rehost-media --snapshot-dir /srv/snapshot --report-dir /srv/reports
```

It downloads each media URL from an allowed host, re-encodes it, and stores it under `/srv/media`, served at `https://media.<ip1>.sslip.io` with `immutable` caching. The summary line reads:

```text
  media: urls=… already_hosted=… rehosted=… deduplicated=… failed=… {reasons}
```

| Failure reason | Do |
| --- | --- |
| `host_not_allowed` | The URL's host isn't in `MEDIA_REHOST_ALLOWED_HOSTS`. If it's a legitimate media host, add it to `/srv/madar/.env` and run the command again. `dc run` reads the file afresh, so nothing needs recreating. |
| `http_404`, `http_…`, `timeout`, `http_error` | The old host doesn't serve it. Those columns stay empty. Re-run later for timeouts. |
| `too_large`, `decode_error`, `redirect_off_host` | Refused by the safety checks. Leave it, or fix it by hand in the admin later. |

## 4. Check

```bash
ls /srv/reports                                    # one report and one details file per run
curl -s https://api.<ip1>.sslip.io/healthz | jq .data
```

Open a media URL from an API response and check that it loads with `Cache-Control: public, max-age=31536000, immutable`.

The snapshot stays in `/srv/snapshot` for re-runs. Delete it once the old app's data is no longer needed: `sudo rm -r /srv/snapshot/*`.

## If it fails

- `error: …` from Compose about `IMAGE_TAG`: export it first (the "Working on VPS-1" shell does).
- A Python traceback about a missing setting: a key is missing from `/srv/madar/.env` ([provision-host.md §4](provision-host.md#4-fill-the-env-file-and-re-run)).
- `Permission denied` under `/srv/media` or `/srv/reports`: both must belong to uid `10001`, the image's user. `bootstrap-vps.sh` sets that. Re-run it.
