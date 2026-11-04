# The live poller

How live scores work on VPS-2, what its alerts mean, and how to fix a parser. The rules are in [system-design §6.7](../system-design.md); the names are in [the contract](../../specs/005-d05-live-and-discovery/contracts/live-pipeline.md). The commands use the `dc` shell from [on-call.md](on-call.md#before-you-start).

No operator is needed during a match. While a parser waits for a fix, users stay on the other source or on the clock estimate, which shows no score.

## What runs

| Task | Worker on VPS-2 | When | Does |
| --- | --- | --- | --- |
| `live.scheduler` | `worker-live` | Every 60 s | Finds matches in the window. None or paused: no request. Otherwise queues one `live.poll` |
| `live.poll` | `worker-live` | From the scheduler | One cycle under `lock:live:poll`. An overlap exits |
| `live.check_robots` | `worker-live` | Daily 03:50 UTC | Compares each `robots.txt` with `backend/app/live/robots/` |
| `live.watchdog` | `worker-maintenance` | Every 2 min | Moves a `feed` row with no reading for 5 min, or past kickoff + 210 min, to the clock |
| `live.prune_runs` | `worker-maintenance` | Daily 03:40 UTC | Deletes `live_poller` runs older than 30 days |

The window is a kickoff from 150 minutes ago to 10 minutes ahead, plus matches on `feed` with no final state up to kickoff + 210 minutes.

One cycle: both list pages, link rows to matches, pick the page slots, fetch them, cross-check each match, write it. Each cycle writes one `import_runs` row under `live_poller`, which A13's run detail shows.

## Settings

Environment on VPS-2 (`/srv/madar/.env`), with the defaults in code. `specs/005-d05-live-and-discovery/capture-report.md` sets the first three. Restart `worker-live` and `worker-maintenance` after a change.

| Variable | Default | Means |
| --- | --- | --- |
| `LIVE_PAGE_CAP_FILGOAL` | 8 | Match pages a cycle on FilGoal |
| `LIVE_PAGE_CAP_YALLAKORA` | 2 | Match pages a cycle on YallaKora |
| `LIVE_CONFIRM_WAIT_S` | 180 | How long one source may be ahead before it counts as a disagreement |
| `LIVE_DOWN_AFTER_FAILURES` | 3 | Failed cycles in a row before a source is down |
| `LIVE_STALE_AFTER_S` | 300 | No reading for this long sends a `feed` row to the clock |
| `LIVE_HARD_LIMIT_MIN` | 210 | The latest a `feed` row stays after kickoff |

The poller also needs `SCRAPE_USER_AGENT` (it refuses to fetch without one) and `RAW_ROOT` (default `/srv/raw`).

## Pause and resume

Use the live card in A13. A paused poller sends no requests, sends `feed` rows in the window to the clock on its next tick, and raises no alert. Resuming is enough: a valid reading then goes through the normal rules, and the kept score comes back. "Run now" is refused for this card.

## What each alert means

Each one is sent once when the problem opens and once when it closes. `alerted_at` is set inside the transaction, and the alert goes out after commit, so a crash in between loses one message and never repeats one. A missing Telegram token only logs ([source-alerts.md](source-alerts.md)).

| Alert | Key | What it means | What to do |
| --- | --- | --- | --- |
| `تغيّر شكل صفحة ‹source›` | `format:<source>` | A page failed validation, or a list had no matches while one is in the window. That source is out until it's valid again | [Update the parser](#updating-a-parser-from-a-saved-page) when free. Nothing is urgent while the other source works |
| `المصدر ‹source› متوقف` | `down:<source>` | `LIVE_DOWN_AFTER_FAILURES` failed cycles in a row, or a 429, 403 or 5xx backoff that keeps failing | Read `error` on the runs below. It closes by itself. Blocks are never worked around with proxies or another user agent |
| `المصدران متوقفان` | `both_down` | Both unusable: matches in the window are on the clock estimate | As above. It closes when either source is valid |
| `المصدران مختلفان على نتيجة المباراة ‹id›` | `disagree:<match_id>` | One source stayed ahead past `LIVE_CONFIRM_WAIT_S`. The last confirmed score stays and goal events are held | Compare with the broadcast. If needed, set a manual status in A3. It closes on agreement, or an hour after the match's limit |
| `المباراة ‹id› بلا قراءة حديثة` | `stale:<match_id>` | The watchdog moved the row to the clock | If several arrive together, `worker-live` has probably stopped: see [What to check](#what-to-check). It closes on the next reading |
| `تغيّر ملف robots.txt` | `robots:<host>` | The site's rules differ from the committed copy. Nothing changes by itself | [The robots rules](#when-robotstxt-changes) |

## What to check

```bash
# VPS-2: the workers and their logs
dc ps worker-live worker-maintenance beat
dc logs --tail 200 worker-live

# VPS-2: open problems, source states, the latest runs
dc exec postgres psql -U madar -d madar -c "select key, opened_at, raw_ref from live_problems where closed_at is null order by opened_at"
dc exec postgres psql -U madar -d madar -c "select source, state, consecutive_failures, last_ok_at from live_source_state"
dc exec postgres psql -U madar -d madar -c "select id, started_at, status, items_found, http_errors, error, raw_path from import_runs where source = 'live_poller' order by id desc limit 10"

# VPS-2: how a host's backoff stands, in seconds (-2: none)
dc exec redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ttl live:backoff:www.filgoal.com'
```

If PostgreSQL runs on VPS-1 in your setup, run the `psql` lines there with VPS-1's `dc`.

A match's own readings, to compare the two sources (never served to clients):

```bash
dc exec postgres psql -U madar -d madar -c "select source, status, period, minute, home_score, away_score, read_at, changed_at from match_source_readings where match_id = <id>"
dc exec postgres psql -U madar -d madar -c "select * from match_live_state where match_id = <id>"
```

## Updating a parser from a saved page

A raw page is saved when its content changed, or when it failed validation, under `/srv/raw/live_poller/<date>/<run>/` for 5 days. The alert and `raw_ref` name the folder. A13's run detail shows the same page as text.

1. Copy the page to `backend/tests/live/fixtures/`, trimmed, with no personal data. Pages are untrusted: don't open them in a browser.
2. Add a test in `backend/tests/live/test_filgoal_parse.py` or `test_yallakora_parse.py`, and see it fail.
3. Change `backend/app/live/sources/`. A new status goes in that file's `STATUS_MAP`, and a new event type in `EVENT_TYPES`. Leave anything uncertain out, since an unknown status failing validation is the safe path.
4. A status your rank order doesn't know counts as `scheduled` in `crosscheck.py`, so add it to `_RANKS`.
5. Deploy by the normal PR. The source recovers by itself on its next valid page, and the alert closes.

Event types a parser doesn't map appear under `ignored_event_types` in the run's `log`. They don't fail validation.

## When `robots.txt` changes

1. Read the diff between the live file and `backend/app/live/robots/<site>.txt`.
2. If a rule affects us, update `DENY_RULES` in `backend/app/live/robots.py` and its tests.
3. Replace the committed copy. The problem closes on the next daily check after the deploy.

## The capture

Records real pages for `capture-report.md` (delivery T020–T021). It reads only, and writes nothing to the database.

```bash
ssh madar-vps2 'docker compose -f /srv/madar/infra/compose/vps2.yml run --rm worker-live \
  python -m app.cli capture-live --filgoal <id> --yallakora <match-path> --minutes 130'
```

Take `<id>` from `data-match-id` on FilGoal's list and `<match-path>` from the row's link on YallaKora's. A path the deny list covers stops the command before any request, and so does a missing `SCRAPE_USER_AGENT`. Pages land in `/srv/raw/capture/<date>/` as `<time>_<name>.html`. That folder isn't pruned, so delete it when the fixtures are committed.

## The disk check

At most 8 FilGoal pages a minute gzip to about 60 KB each, so a busy day stays well under 1 GB, and a 5-day prune applies (`adapters.prune_raw_pages`).

```bash
ssh madar-vps2 'df -h /srv/raw; du -sh /srv/raw/live_poller /srv/raw/capture'
```

Above 80% full, delete `/srv/raw/capture/` first, then look for a parser saving every page: a page that changes on each fetch defeats the hash, and `pages` in the run `log` stays above zero every minute.
