# Imports and sources

How tomorrow's fixtures arrive: the schedule, starting a run by hand, reading what a run did,
pausing a source, and switching where ysscores is fetched (Lane B2's T086–T088, FR-020 to FR-028).
The code is in `backend/app/adapters/`; the contract is
[`specs/002-d02-core-flows/contracts/ingestion.md`](../../specs/002-d02-core-flows/contracts/ingestion.md).

Two sources run on D2:

| Source | `sources.name` | Where it fetches | What it brings |
| --- | --- | --- | --- |
| ysscores | `ysscores` | `scrape_home` on the home box by default, `scrape` on VPS-2 when switched | Today … +3 Cairo days of fixtures: teams, logos, kickoff, competition, stage |
| Sat Air, through Firestore | `legacy` | `scrape` on VPS-2 | The same days from the old app: channel links, hidden flags, per-channel commentators, a second name when ysscores misses one |

Nothing writes a status or a score: importers bring fixtures only (constitution II).

## The schedule

All times UTC, from `backend/app/adapters/schedule.py`; exactly one `beat` runs on VPS-2
([workers.md](workers.md)).

| Beat entry | When | Task and queue |
| --- | --- | --- |
| `ysscores-fixtures` | every 3 h, on the hour (`0 */3 * * *`) | `adapters.fetch("ysscores")` on `scrape_home` (or `scrape`) |
| `satair-bridge` | every 3 h, at :30, from 01:30 (`30 1-22/3 * * *`) | `adapters.fetch("legacy")` on `scrape` |
| `prune-raw-pages` | daily at 03:15 (`15 3 * * *`) | `adapters.prune_raw_pages()` on `maintenance` |

The pipeline is `adapters.fetch` → a `ScrapeResult` message on `imports` → `adapters.ingest`.
A run that finds its lock held (`lock:fetch:<source>` or `lock:ingest:<source>`) exits and logs
`skipped`: the schedule never overlaps itself.

## Start a run now

On VPS-2, inside the worker image (the repo is at `/srv/madar/infra`, the env file at
`/srv/madar/.env`):

```sh
# ysscores: fetch and parse on the home box, then ingest on VPS-2
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-scrape celery -A app.workers call adapters.fetch --queue scrape_home --args "[\"ysscores\"]"'

# the bridge, on the same host
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-scrape celery -A app.workers call adapters.fetch --queue scrape --args "[\"legacy\"]"'
```

`--queue` is explicit because `celery call` imports only `app.workers`: the routing table is
resolved lazily, and naming the queue makes the destination true even if that changes (B2-R1-19).

`celery call` only queues the task; the worker runs it. To see the queue back up:

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-imports celery -A app.workers inspect active'
```

The home box fetches only when it is online. If it is off, start the ysscores run on VPS-2 instead
by switching `YSSCORES_FETCH_QUEUE` (below), or accept that day from the bridge alone.

## Read what a run did

```sh
dc exec postgres psql -U madar -d madar -c "
  select id, source, status, started_at, finished_at, items_found, items_upserted, http_errors, error, raw_path
  from import_runs order by started_at desc limit 10"
```

`dc` is the VPS-1 Compose helper ([deploy-and-rollback.md](deploy-and-rollback.md#working-on-vps-1)):
`docker compose --env-file /srv/madar/.env -f /srv/madar/infra/compose/vps1.yml`.

| `status` | Means |
| --- | --- |
| `running` | `ingest` started and has not finished; a row stuck here after 10 minutes means the worker died |
| `succeeded` | every item was upserted |
| `partial` | some items failed in their savepoint; the reasons are in `run.json` |
| `failed` | the fetch or the layout failed; `error` holds a short reason: `layout_changed`, `retries_exhausted` (403/429/5xx after six attempts), `fetch_failed` (a 404 or another non-retryable answer), `bridge_not_configured`, or `TypeError: …` from an ingest that crashed |

`items_upserted` counts rows created or changed. A second run on unchanged fixtures reports `0`
(SC-004), which is the normal quiet result.

The pages of a run are on VPS-2 at `import_runs.raw_path`
(`/srv/raw/<source>/<YYYY-MM-DD>/<run_id>/`), with `run.json` beside them:

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" 'sudo -iu deploy cat /srv/raw/ysscores/2026-10-30/*/run.json'
```

`run.json` holds `counts`, `skipped[{ref, reason}]`, `postponed[{ref}]` and
`unresolved[{name, competition, match_ref}]`.
An unresolved team is not a bug: v0 never guesses (research R17). The alias tables and the queue
that resolves names arrive on D5; until then the name keeps its text, so the app still shows it.
Folders older than 5 days are deleted nightly.

A layout change marks the run `failed` with `layout_changed`, and every page the run had already
fetched is saved with it. A failed fetch is recorded the same way: the pages it collected, its
HTTP error count and a short `error` (B2-R1-9). The parser did not guess; check the saved page
before touching `backend/app/adapters/ysscores.py` ([`base.LayoutChanged`](../../backend/app/adapters/base.py)).

## Pause a source

`sources.is_enabled` and `sources.paused_until` are what `ingest` reads:

```sh
dc exec postgres psql -U madar -d madar -c "update sources set is_enabled = false where name = 'ysscores'"
dc exec postgres psql -U madar -d madar -c "update sources set is_enabled = true  where name = 'ysscores'"
```

The check lives in `ingest`, on VPS-2, because the home box has no database. So a paused source is
still fetched, its pages are still saved, and its run is recorded as `succeeded` with
`items_upserted = 0` plus a `source_paused` log line: nothing reaches the matches. That is the
safe direction — the alternative (a pause the fetch host cannot see) would stall the run silently.

To stop the fetch itself, remove or disable the beat entry in `backend/app/adapters/schedule.py`
and deploy VPS-2 ([workers.md](workers.md)); an on-demand run still works. Pausing ysscores is safe
for a day: the bridge still brings its own fixtures, and the next ysscores run merges into the
same rows through `(source, external_id)` and the 45-minute duplicate probe.

## Switch where ysscores fetches

`YSSCORES_FETCH_QUEUE` is read by the schedule and by `adapters.fetch`:

1. On VPS-2, set `YSSCORES_FETCH_QUEUE=scrape` in `/srv/madar/.env` (mode 600, owner `deploy`).
2. Restart the four services (not `flower`, `worker-live` or `worker-notify`, which stay down on
   D2) so the new value is read:
   `IMAGE_TAG=$(cat /srv/madar/current_tag) docker compose --env-file /srv/madar/.env -f infra/compose/vps2.yml --profile workers up -d worker-imports worker-scrape worker-maintenance beat`
3. Check the next run's `import_runs.source` and that `worker-scrape` handled it.

Set it back to `scrape_home` when ysscores stops blocking VPS IPs (it answers `403` to a plain
client and to datacenter addresses; the home box is why it exists).

## The bridge's configuration

The old Sat Air project's id and web API key live only in VPS-2's `.env` as
`SATAIR_FIREBASE_PROJECT_ID` and `SATAIR_FIREBASE_API_KEY` (D15, FR-052). They never appear in the
repo, a log line or a test. Rotating them: [secrets.md](secrets.md).

The bridge is read-only by construction: it issues `GET` on
`firestore.googleapis.com/v1/projects/<id>/databases/(default)/documents/matchDays/<day>` and
nothing else.
