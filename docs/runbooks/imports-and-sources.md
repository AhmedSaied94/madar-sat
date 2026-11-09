# Imports and sources

How tomorrow's fixtures and their channels arrive: the schedule, starting a run by hand, reading what
a run did, pausing a source, and moving a fetch between the home box and VPS-2 (Lane B2's T072,
FR-020 to FR-028, research R14–R18). The code is in `backend/app/adapters/`; the contracts are
[`specs/002-d02-core-flows/contracts/ingestion.md`](../../specs/002-d02-core-flows/contracts/ingestion.md)
and [`specs/003-d03-follow-push-sources/contracts/pipelines-and-ops.md`](../../specs/003-d03-follow-push-sources/contracts/pipelines-and-ops.md).

Four sources run after D5, and sporteventz joins them on D6:

| Source | `sources.name` | Where it fetches | What it brings |
| --- | --- | --- | --- |
| ysscores | `ysscores` | `scrape_home` on the home box by default, `scrape` on VPS-2 when switched | Today … +3 Cairo days of fixtures: teams, logos, kickoff, competition, stage |
| Sat Air, through Firestore | `legacy` | `scrape` on VPS-2 | The same days from the old app: channel links, hidden flags, per-channel commentators, a second name when ysscores misses one |
| LiveSoccerTV | `livesoccertv` | `scrape_home` by default (`LIVESOCCERTV_FETCH_QUEUE`) | The broadcasters of the matches Madar already has in the next 48 h, and hidden placeholders for names Madar lacks |
| YallaKora | `yallakora` | `scrape` on VPS-2 | Today … +3 Cairo days of Egyptian and Arab fixtures, and the Egyptian broadcaster (`matches.local_broadcaster_eg`). On a row another source holds it adds only the broadcaster and its id |
| sporteventz | `sporteventz` | `scrape` on VPS-2 | Basketball, handball, volleyball and tennis for today to +3, with their broadcasters as two custom slots (D6 FR-037). Names stay text; nothing is resolved or queued |

API-Football (`api_football`) is built behind the owner's checks and ships off until they pass
([below](#api-football-and-stopped-runs)); until then its key is unset and a scheduled run stops on
purpose. Nothing a fan sees depends on either other-sport source before D7.

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
| `sporteventz-6h` | every 6 h at :10 (`10 */6 * * *`) | `adapters.schedule_fetch("sporteventz")` on `imports`: today to +3, eight pages a run |
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
| `stopped` | the run stopped on purpose and sent nothing: `error` is `budget_reached` (API-Football's daily allowance is spent) or `not_configured` (its key is unset). It is neither a failure nor a quiet source: it does not touch the breaker or the zero-items alarm, and `report runs` counts it as a filled slot (D6 FR-035) |

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

`run.json` holds `counts`, `skipped`, `unresolved`, `waiting`, `unmatched`, `placeholders_created` and
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
holds, only `local_broadcaster_eg` and its own external id, so two importers don't rewrite each other's
spelling. A card with no channel leaves the broadcaster alone.

**When it links to another source's row.** Only when both teams resolve, in that order, and exactly
one match has them with a kickoff within 45 min (FR-022a, research R7). The live poller trusts a stored
id, so a wrong link would publish another match's score. Text is never enough. For a card it has no
stored id for:

| The card | What happens |
| --- | --- |
| Both teams resolve, one match within 45 min | Linked: the row gains the id and the broadcaster |
| Both teams resolve, more than one match within 45 min | **Waits** (`more_than_one_match`): no id, no broadcaster, no new row |
| Both teams resolve, no match within 45 min, and a row may be this fixture | **Waits** (`may_be_a_near_row`): no id, no broadcaster, no new row. "May be" means a row within 12 h has either team, or its text on a side with no id, because a club plays once a day. Or a row within 45 min has a side with no id and a spelling at least 0.3 similar. With no kickoff on the card, the row must be that day |
| Both teams resolve, and no such row | A new row |
| A team is unresolved | **Waits** (`unresolved_team`): the names are queued, with no id, no broadcaster and no new row |

A waiting card is listed under `waiting` in `run.json` and in A13's run detail, and leaves the run
`succeeded`. There's nothing to clean up, and what clears it depends on its reason:

| Reason | What clears it |
| --- | --- |
| `unresolved_team` | Map its names in A13. The next run links it, or gives it a row if no source holds it |
| `may_be_a_near_row` | Usually the row has no team ids: map that row's own names in A13 too, under the source that holds them, which fills the row. If the kickoffs differ by more than 45 min, correct the row's kickoff in A3. If a name on the row points at another club, fix that alias |
| `more_than_one_match` | Two rows hold this fixture: see [merging duplicate matches](#merging-duplicate-matches) |

`ysscores` and `legacy` still join on the same names on the same day.

**Why so much waits.** On 2026-11-05 the first run made 75 rows, 73 of them copies of fixtures we held under other spellings. A copy has no channels, and a polled copy takes the score away from the row that has them. So a fixture only YallaKora knows gets its row after its names are mapped, which is a smaller cost than a copy. Compare `report coverage` before and after a first run on a new host.

## sporteventz

Other-sport fixtures and their broadcasters for D7 (FR-037–FR-039). Four sport pages —
`/en/other-sport/basketball.html`, `handball`, `volleyball`, `tennis` — and one data answer each:
`/index.php?option=com_magictable&…&table=1&accesskey=<n>`, a JSON `Result`/`Records` with
`Sport, Begin, Team1, Team2, Tournament, Category, @id, Channels`. One request every 700 ms, eight
pages a run, every 6 h.

- **The access key dies on the next page load.** The adapter reads the page fresh, uses its link at
  once, and on an empty answer re-reads the page once before failing with `layout_changed`. Never
  cache the page or the link.
- **Times** are the site's, in the offset the request sent (`+0300`). The adapter converts with that
  same offset, so the UTC kickoff is right in winter too. Do not change it to Cairo's own clock.
- **Robots:** on 2026-11-06 `robots.txt` allowed both paths for `*`. Re-check it whenever the source
  is reviewed (the adapter's docstring records the reading), and keep the committed copy in
  `backend/tests/fixtures/sporteventz/` in step with it.
- **What it writes:** its own rows only. Team and competition names stay text, with no id and no
  `unresolved_names` entry, because no other-sport catalog exists. Broadcasters go to
  `match_custom_broadcasts` slots 1 and 2, ranked Arabic name → Arab country → the rest; a name with
  a card-sharing label is refused and counted, and no label passes 80 characters. A match with
  `broadcasts` in `locked_fields` is left alone, which is what A4's save sets.
- **Empty days are normal** at ~40 events in two weeks: a valid answer with no records alarms only
  after 7 days without any. A changed page fails the run (`layout_changed`) and counts toward the
  breaker at once: a missing `Records` key or access key, or a sport whose records are there but none
  reads (a renamed `Team1`/`Team2` or `Sport`, a new `Begin` format). Another sport and a team playing itself are
  skipped without failing the run.
- **Skips are counted by reason** in `import_runs.log` (`parse_skipped`, also under `counts`) and in
  `run.json`: `football`, `other_sport`, `same_team_twice`, `missing_sport`, `missing_teams`,
  `unreadable_begin`, `not_an_object`. A run that comes back light with `missing_sport`, `missing_teams`
  or `unreadable_begin` counts means
  part of the answer changed shape: update the parser and its saved pages.
- **No fan sees it yet.** `/v1` lists football only, so these rows wait for D7.

```sh
# VPS-2, as deploy: one run now
ssh madar-vps2
cd /srv/madar/infra
export IMAGE_TAG=$(cat /srv/madar/current_tag)
dc() { docker compose --env-file /srv/madar/.env -f compose/vps2.yml "$@"; }
dc exec worker-imports celery -A app.workers call adapters.schedule_fetch --args '["sporteventz"]' --queue imports

# VPS-1, which has the database (`dc` is the vps1.yml helper of deploy-and-rollback.md)
dc exec postgres psql -U madar -d madar -c "select id, status, items_found, items_upserted, error from import_runs where source = 'sporteventz' order by id desc limit 3"
dc exec postgres psql -U madar -d madar -c "select sport, count(*) from matches where source = 'sporteventz' group by sport"
# what the parser refused, by reason, on the last runs
dc exec postgres psql -U madar -d madar -c "select id, status, error, log->'parse_skipped' from import_runs where source = 'sporteventz' order by id desc limit 3"
```

## API-Football and stopped runs

`v3.football.api-sports.io`, one request per date for today to +3, allowlisted by league id. **It is not
built yet:** the adapter and its budget are T060–T064, and the plan starts them only after the owner's
five checks pass (T059). Until then the names below are placeholders in `example.env`, the key stays
unset, and nothing is scheduled for this source.

| Setting (VPS-2 `.env`) | Means |
| --- | --- |
| `API_FOOTBALL_KEY` | The `x-apisports-key` header, added at send time. Empty means `stopped`, `not_configured`. Never appears in a log, a raw page or `import_runs.log` |
| `API_FOOTBALL_DAILY_BUDGET` | Requests allowed per UTC day (default 90) |
| `API_FOOTBALL_LEAGUES` | The league ids the parse keeps (default `233,39,2`) |

When it is built, the budget is one Redis key per day (`budget:api_football:<date>`, 48 h): every
attempt counts before it is sent, retries and «تشغيل الآن» included. Over it, the run is `stopped` with
`budget_reached`. Redis unavailable is a fault, not a stop: `failed` with `budget_unreadable`. A
non-empty `errors` in a 200 is `failed` with the provider's message.

```sh
dc exec worker-imports celery -A app.workers call adapters.schedule_fetch --args '["api_football"]' --queue imports
dc exec postgres psql -U madar -d madar -c "select id, status, items_found, error from import_runs where source = 'api_football' order by id desc limit 3"
```

Changing the budget or a league will need a restarted `worker-scrape`: the settings are read when the
module loads. The daily reset's time is the provider's, confirmed by the owner's check 3.

## Relabelling a sporteventz row's sport

Sporteventz carries other sports under English names, and an early row could be stored as football. The
command takes a map the owner reviews, never a guess from the snapshot, and changes nothing without
`--apply`:

```bash
# what the command sees today: sporteventz rows labelled football, and nothing changed
docker compose -f /srv/madar/compose.yml exec -T worker-imports \
  python -m app.cli repair-matches sport

# the map is {"<match id>": "<sport>"}, built by the owner where old_app/migration/data/ is kept
cat sport-map.json | docker compose -f /srv/madar/compose.yml exec -T worker-imports \
  python -m app.cli repair-matches sport - --apply
```

It sets only the mapped sports, writes one `audit_log` row per change (`{"sport": [old, new]}`), and
prints the rows the map left alone. An id in the map that isn't a sporteventz row refuses the whole run,
and a second run changes nothing. No match is ever deleted.

## Merging duplicate matches

`repair-matches` is for one incident: YallaKora's first runs on 2026-11-05 made 74 copies of fixtures we held, listed in [the reviewed pairs](../../specs/031-d05-live-sources/repair/duplicate-pairs-2026-11-05.md). The older row keeps its channels and takes the copy's score, links, readings, events and broadcaster.

Matches are never deleted, and a trigger enforces that. **The owner approved one exception on 2026-11-05 for these rows.** The command refuses any row outside those runs, and turns the trigger off only inside its own transaction, so a failure restores it. Writers to `matches` wait while it runs, and it gives up after 10 s if it can't get the lock. It can't be undone, though `audit_log` keeps what each copy held. Without `--apply` it does all the work and rolls it back.

```bash
# from your laptop, in the repo
scp specs/031-d05-live-sources/repair/duplicate-pairs-2026-11-05.json madar-vps2:/tmp/duplicate-pairs.json
ssh madar-vps2 chmod 644 /tmp/duplicate-pairs.json

# VPS-2, as deploy
cd /srv/madar/infra
export IMAGE_TAG=$(cat /srv/madar/current_tag)
dc() { docker compose --env-file /srv/madar/.env -f compose/vps2.yml "$@"; }

# read the output, in particular `differs` and any REFUSED line
dc exec -T worker-imports python -m app.cli repair-matches merge - < /tmp/duplicate-pairs.json

# then, the same with the change made
dc exec -T worker-imports python -m app.cli repair-matches merge --apply - < /tmp/duplicate-pairs.json

# fill empty teams from names decided before the queue did this itself
dc exec -T worker-imports python -m app.cli repair-matches fill-teams
dc exec -T worker-imports python -m app.cli repair-matches fill-teams --apply
```

To check, on VPS-1 (with `compose/vps1.yml` in `dc`) this lists fixtures still held twice, and should show only what you chose to leave:

```bash
dc exec postgres psql -U madar -d madar -c "select a.id, b.id, a.kickoff_at, a.home_team_name, a.away_team_name from matches a join matches b on a.id < b.id and a.home_team_id = b.home_team_id and a.away_team_id = b.away_team_id and abs(extract(epoch from a.kickoff_at - b.kickoff_at)) <= 2700 where a.kickoff_at > now() - interval '1 day'"
```

Rows that waited as `more_than_one_match` link on the next run. Once it has run, delete the merge from `backend/app/services/match_repair.py` and `backend/app/cli.py`, so the exception can't be used again.

## The unresolved queue

Anything an importer can't match waits in `unresolved_names`, and nothing is created: the match keeps
the text name. One row per `(source, kind, name_norm, competition_norm)`: a repeat raises `seen_count`
and refreshes `context`. An editor works it in A13: map to an existing entity, create one, or ignore.

- **Who writes it:** `ysscores`, `legacy`, `yallakora` (teams and competitions), `livesoccertv`
  (channels, while keeping the hidden placeholder, D5 R11), and the live poller.
- **A team mapping also fills matches.** Coming and in-play matches with no id on that side, the same
  text name and the same competition get the team at once, with an audit row. The same words in another
  competition are left alone, and a queue row with no competition fills nothing. Without this, a match
  with only a text name can't link however many aliases exist.
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

### Working the queue in A13

The queue sits under the source cards at `/sources`. Its count is `meta.open_count`, and the source
dropdown filters the list; rows are ordered by `last_seen_at`, newest first.

- **ربط (map).** Opens the suggestions. Nothing is written until you press حفظ. With more than one
  `exact` candidate the row shows «اختر الفريق» instead, and the alias is scoped to the competition in
  the row's context — that is what «حصر الربط على البطولة» means, and it is locked on for that case.
- **جديد (create).** Opens the team, competition or channel form filled with the source's name. Saving
  it creates the entity and then maps the name to it. If that map fails, the row stays open and the
  toast says so; map it again from ربط.
- **تجاهل (ignore).** Permanent; the row leaves the open list.
- Errors: `409 alias_conflict` means the same name is already bound to another entity — reload the row
  before deciding; `409 edit_conflict` means someone else cleared or changed it first.

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
