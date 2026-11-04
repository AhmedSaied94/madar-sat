# Imports and sources

How tomorrow's fixtures and their channels arrive: the schedule, starting a run by hand, reading what
a run did, pausing a source, and moving a fetch between the home box and VPS-2 (Lane B2's T072,
FR-020 to FR-028, research R14–R18). The code is in `backend/app/adapters/`; the contracts are
[`specs/002-d02-core-flows/contracts/ingestion.md`](../../specs/002-d02-core-flows/contracts/ingestion.md)
and [`specs/003-d03-follow-push-sources/contracts/pipelines-and-ops.md`](../../specs/003-d03-follow-push-sources/contracts/pipelines-and-ops.md).

Four sources run after D5:

| Source | `sources.name` | Where it fetches | What it brings |
| --- | --- | --- | --- |
| ysscores | `ysscores` | `scrape_home` on the home box by default, `scrape` on VPS-2 when switched | Today … +3 Cairo days of fixtures: teams, logos, kickoff, competition, stage |
| Sat Air, through Firestore | `legacy` | `scrape` on VPS-2 | The same days from the old app: channel links, hidden flags, per-channel commentators, a second name when ysscores misses one |
| LiveSoccerTV | `livesoccertv` | `scrape_home` by default (`LIVESOCCERTV_FETCH_QUEUE`) | The broadcasters of the matches Madar already has in the next 48 h, and hidden placeholders for names Madar lacks |
| YallaKora | `yallakora` | `scrape` on VPS-2 | Today … +3 Cairo days of Egyptian and Arab fixtures, and the Egyptian broadcaster (`matches.local_broadcaster_eg`). On a row another source holds it adds only the broadcaster and its id |

Nothing writes a status or a score: importers bring fixtures and channels only (constitution II). The
live poller writes those ([workers.md](workers.md)), and shares `www.yallakora.com`'s rate bucket with
this importer.

## The schedule

All times UTC, from `backend/app/adapters/schedule.py`; exactly one `beat` runs on VPS-2
([workers.md](workers.md)). Every source entry calls `adapters.schedule_fetch`, never
`adapters.fetch` directly: the pause and the breaker live in the database, and only VPS-2 can read
them (R17).

| Beat entry | When | Task and queue |
| --- | --- | --- |
| `ysscores-fixtures` | every 3 h, on the hour (`0 */3 * * *`) | `adapters.schedule_fetch("ysscores")` on `imports` |
| `satair-bridge` | every 3 h, at :30, from 01:30 (`30 1-22/3 * * *`) | `adapters.schedule_fetch("legacy")` on `imports` |
| `livesoccertv-48h` | every 2 h at :45 (`45 */2 * * *`) | `adapters.schedule_fetch("livesoccertv")` on `imports` |
| `livesoccertv-t60` | every 10 min (`*/10 * * * *`) | `adapters.schedule_fetch("livesoccertv", window="t60")`: only kickoffs 55–70 minutes away |
| `yallakora-daily` | daily at 02:20 (`20 2 * * *`) | `adapters.schedule_fetch("yallakora")` on `imports`: today to +3 |
| `yallakora-today` | at 08:20, 14:20 and 20:20 (`20 8,14,20 * * *`) | `adapters.schedule_fetch("yallakora", window="today")`: today only |
| `prune-raw-pages` | daily at 03:15 (`15 3 * * *`) | `adapters.prune_raw_pages()` on `maintenance` |
| `heartbeat-maintenance`, `-imports`, `-notifications`, `-live` | every 5 min (`*/5 * * * *`) | `ops.heartbeat(<queue>)` on that queue (R20, [uptime-kuma.md](uptime-kuma.md)) |

`schedule_fetch` then sends the fetch to the source's own queue. The pipeline is `adapters.fetch` →
a `ScrapeResult` message on `imports` → `adapters.ingest`. A run that finds its lock held
(`lock:fetch:<source>` or `lock:ingest:<source>`) exits and logs `skipped`: the schedule never
overlaps itself.

## Start a run now

From A13, «تشغيل الآن» sends `adapters.schedule_fetch` with `manual=True`; it ignores the pause and
the breaker, and it does **not** resume the source. It is refused while the source's fetch lock is
held (`409 run_in_progress`).

By hand, on VPS-2 (the repo is at `/srv/madar/infra`, the env file at `/srv/madar/.env`):

```sh
# through the pause and the breaker, exactly like the beat entry
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-imports celery -A app.workers call adapters.schedule_fetch --queue imports --args "[\"livesoccertv\"]"'

# one source even if it is paused (A13's «تشغيل الآن» without the API)
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-imports celery -A app.workers call adapters.schedule_fetch --queue imports --args "[\"ysscores\"]" --kwargs "{\"manual\":true}"'
```

`--queue` is explicit because `celery call` imports only `app.workers`: the routing table is
resolved lazily, and naming the queue makes the destination true even if that changes (B2-R1-19).

`adapters.fetch` on its own still works for debugging, but it skips the pause check and plans no
LiveSoccerTV targets:

```sh
# ysscores: fetch and parse on the home box, then ingest on VPS-2
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-scrape celery -A app.workers call adapters.fetch --queue scrape_home --args "[\"ysscores\"]"'

# the bridge, on the same host
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-scrape celery -A app.workers call adapters.fetch --queue scrape --args "[\"legacy\"]"'
```

`celery call` only queues the task; the worker runs it. To see the queue back up:

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" \
  'sudo -iu deploy docker compose -p madar exec -T worker-imports celery -A app.workers inspect active'
```

The home box fetches only when it is online. If it is off, start the ysscores run on VPS-2 instead
by switching `YSSCORES_FETCH_QUEUE` (below), or accept that day from the bridge alone.

## Read what a run did

A13 shows the same rows with a run detail; from a shell:

```sh
dc exec postgres psql -U madar -d madar -c "
  select id, source, status, started_at, finished_at, items_found, items_upserted, http_errors, error,
         left(log::text, 200) as log
  from import_runs order by started_at desc limit 10"
```

`dc` is the VPS-1 Compose helper ([deploy-and-rollback.md](deploy-and-rollback.md#working-on-vps-1)):
`docker compose --env-file /srv/madar/.env -f /srv/madar/infra/compose/vps1.yml`.

| `status` | Means |
| --- | --- |
| `running` | `ingest` started and has not finished; a row stuck here after 10 minutes means the worker died |
| `succeeded` | every item was upserted, or the source is paused |
| `partial` | some items failed in their savepoint, or LiveSoccerTV could not find every planned match; the reasons are in `log` and `run.json` |
| `failed` | the fetch or the layout failed; `error` holds a short reason: `layout_changed`, `retries_exhausted` (403/429/5xx after six attempts), `fetch_failed` (a 404 or another non-retryable answer), `bridge_not_configured`, or `TypeError: …` from an ingest that crashed |

`items_upserted` counts rows created or changed. A second run on unchanged fixtures reports `0`
(SC-004), which is the normal quiet result. A LiveSoccerTV run counts a match only when its links
changed.

`import_runs.log` (revision `0005`) is the run detail A13 reads from VPS-1, because VPS-1 cannot read
VPS-2's disk: it holds the counts, the plan's coverage for LiveSoccerTV (`plan.mapped`,
`plan.unmapped_sample`), the placeholders a run created, and bounded lists of what was skipped
(20 items, with the real count; the whole log is capped at 64 KB). `import_runs.raw_path` still
points at the pages:

```sh
ssh -J ubuntu@10.8.0.1 ubuntu@"$VPS2_VCN_IP" 'sudo -iu deploy cat /srv/raw/livesoccertv/2026-11-07/*/run.json'
```

`run.json` holds `counts`, `skipped`, `unresolved`, `unmatched`, `placeholders_created` and
`health`. An unresolved team is not a bug: v0 never guesses (research R17). The alias tables and the
queue that resolves names arrive on D5; until then the name keeps its text, so the app still shows
it. Folders older than 5 days are deleted nightly.

A layout change marks the run `failed` with `layout_changed`, and every page the run had already
fetched is saved with it. A failed fetch is recorded the same way: the pages it collected, its HTTP
error count and a short `error` (B2-R1-9). The parser did not guess; check the saved page before
touching the adapter.

## Pause, resume, and the breaker

Pausing is A13's «إيقاف» (`POST /admin/api/sources/{name}/pause`), which sets
`is_enabled = false` and is audited. From a shell:

```sh
dc exec postgres psql -U madar -d madar -c "update sources set is_enabled = false where name = 'ysscores'"
dc exec postgres psql -U madar -d madar -c "update sources set is_enabled = true, consecutive_failures = 0, breaker_opened_at = null, paused_until = null where name = 'ysscores'"
```

The pause check is in `schedule_fetch`, on VPS-2, because the home box has no database: a paused
source is not fetched at all. `ingest` checks it again, so a fetch already in flight still records
its run as `succeeded` with `items_upserted = 0` plus a `source_paused` log line.

A source also pauses itself when it keeps failing: three failed runs in a row (or a zero-items run)
open the breaker (`breaker_opened_at`), alert on Telegram and stop the source until someone looks
(research R17). A13's «استئناف» clears `consecutive_failures`, `breaker_opened_at` and
`paused_until`, resets the health fields, and queues one manual run so you see at once whether the
fix worked. See [source-alerts.md](source-alerts.md) for what each alert means.

## Switch where a source fetches

`YSSCORES_FETCH_QUEUE` and `LIVESOCCERTV_FETCH_QUEUE` are read by `schedule_fetch`:

1. On VPS-2, set the value in `/srv/madar/.env` (mode 600, owner `deploy`): `scrape` for VPS-2 or
   `scrape_home` for the home box.
2. Restart the services that read it, so the new value is loaded:
   `IMAGE_TAG=$(cat /srv/madar/current_tag) docker compose --env-file /srv/madar/.env -f /srv/madar/infra/compose/vps2.yml --profile workers up -d worker-imports worker-scrape worker-maintenance worker-notify worker-live uptime-kuma beat`
3. Check the next run's `import_runs.source` and which worker handled it
   (`docker compose exec -T worker-scrape celery -A app.workers inspect active`).

Set ysscores back to `scrape_home` when it stops blocking VPS IPs (it answers `403` to a plain client
and to datacenter addresses; the home box is why it exists). LiveSoccerTV has no such block, so it may
run from either side; it is on the home box by default so the VPS keeps its CPU for the app.

## YallaKora

`/matches-center?date=YYYY-MM-DD`, one page per Cairo day, from `www.yallakora.com`'s shared bucket
(one request per 4 s, a burst of 2). `robots.txt` allows that URL. It forbids `/*?*?*`, so never add a
second `?`. The times on the page are a 24-hour Cairo clock.

Run it by hand on VPS-2:

```sh
ssh madar-vps2 \
  'sudo -iu deploy docker compose -p madar exec -T worker-imports celery -A app.workers call adapters.schedule_fetch --queue imports --args "[\"yallakora\"]" --kwargs "{\"manual\":true}"'
```

Then check it on VPS-1, which has the database:

```sh
dc exec postgres psql -U madar -d madar -c "
  select id, status, items_found, items_upserted, error from import_runs
   where source = 'yallakora' order by id desc limit 3"
dc exec postgres psql -U madar -d madar -c "select count(*) from matches where local_broadcaster_eg is not null"
```

**What it may write.** On a row it created, every field that isn't locked. On a row another source
holds (the duplicate probe found it), only `local_broadcaster_eg` and its own external id, so two
importers don't rewrite each other's spelling. A card with no channel leaves the broadcaster alone.

**A first run can add duplicates.** The probe joins rows on both team ids and a kickoff within 45 min,
or on the same normalized names on the same day. A team spelled differently from ysscores, and with
no alias yet, matches neither, so that fixture appears twice until an editor maps the name in A13 and
someone removes the extra row. Compare `report coverage` before and after the first run.

## The unresolved queue

Anything an importer can't match waits in `unresolved_names`, and nothing is created: the match keeps
the text name. One row per `(source, kind, name_norm, competition_norm)`: a repeat raises `seen_count`
and refreshes `context`. An editor works it in A13: map to an existing entity, create one, or ignore.

- **Who writes it:** `ysscores`, `legacy`, `yallakora` (teams and competitions), `livesoccertv`
  (channels, while keeping the hidden placeholder, D5 R11), and the live poller.
- **Mapping takes effect on the next run.** Resolution goes external id → alias for this competition
  → alias for any competition → the name rules, and an alias belongs to one source.
- **A decided row stays decided.** `ignored`, `mapped` and `created` rows never reopen, and their count
  stops rising. Ignoring is permanent until someone changes that row in SQL.

```sh
# what waits, most seen first (on VPS-1)
dc exec postgres psql -U madar -d madar -c "
  select source, kind, name, seen_count, last_seen_at from unresolved_names
   where state = 'open' order by seen_count desc limit 30"
```

## LiveSoccerTV

What it reads: for each planned match, the home team's page `/teams/<country>/<slug>/`, then the match
page it links to on the same Cairo date with the same two teams. The match page's broadcaster table
gives `{name, country}` pairs. Nothing is fetched from the schedule pages, and the Cloudflare worker
proxy the old `LVS.html` page used is not used at all (R14).

Which matches are planned (`backend/app/adapters/livesoccertv.py`):

- Madar matches with a kickoff in the next 48 h, `status = 'scheduled'` and a known time;
- both teams must map through the `livesoccertv_teams` dictionary, by `team_id` or by the exact
  normalized Arabic name; the rest are counted as `unmapped` and their names appear in the run log's
  `plan.unmapped_sample`, so you can see which teams to add;
- at most **12 matches per run** (24 pages), so the message stays under its 2 MB cap; the next beat
  slot plans the rest;
- a match planned in the last 30 minutes is skipped (`lstv:fetched:<match_id>` in Redis, 30-minute
  TTL), so the 48-hour pass and the T−60 pass never fetch the same one twice;
- the T−60 pass only looks at kickoffs 55–70 minutes away, which is when late channel announcements
  usually land.

`LIVESOCCERTV_COUNTRIES` is the list of countries whose listings are read, comma-separated and
normalized (`LIVESOCCERTV_COUNTRIES="Egypt,Saudi Arabia,Middle East"`). Leaving it empty means the
built-in MENA list in `backend/app/adapters/config.py`. Changing it needs a restarted worker: it is
read when the module loads.

### Placeholders

A name from a configured country that matches no Madar channel becomes a hidden **placeholder**:
`kind = 'platform'`, `show_in_match = false`, `placeholder_source = 'livesoccertv'`, `country` = the
listing's country, and a link to the match. It never reaches `/v1` until an editor completes it.

In A8, filter by «ناقص البيانات» (the `placeholder=true` filter):

- **complete it**: give it a satellite and frequency (or leave it a platform), turn on
  «إظهار في صفحة المباراة», and save. The same save clears `placeholder_source`, so it becomes a
  normal channel and from then on appears in the app;
- **reject it**: soft-delete it. The adapter never recreates a soft-deleted name, so the listing
  keeps arriving and the name stays out;
- a name from a country outside the configured list is skipped and counted
  (`skipped_channels`, `why = country_not_listed`); add that country to the list if you want it.

Editor changes win: touching a link in A4 makes it `manual`, and the importer never edits or removes
a `manual` row again. It only removes `livesoccertv` links that its page no longer lists (D2 FR-008).

## The bridge's configuration

The old Sat Air project's id and web API key live only in VPS-2's `.env` as
`SATAIR_FIREBASE_PROJECT_ID` and `SATAIR_FIREBASE_API_KEY` (D15, FR-052). They never appear in the
repo, a log line or a test. Rotating them: [secrets.md](secrets.md).

The bridge is read-only by construction: it issues `GET` on
`firestore.googleapis.com/v1/projects/<id>/databases/(default)/documents/matchDays/<day>` and
nothing else.
