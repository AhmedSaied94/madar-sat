# The live poller

How live scores work on VPS-2, what its alerts mean, and how to fix a parser. The rules are in [system-design §6.7](../system-design.md) and [the rules contract](../../specs/031-d05-live-sources/contracts/live-rules.md); the names are in [the pipeline contract](../../specs/005-d05-live-and-discovery/contracts/live-pipeline.md). The commands use the `dc` shell from [on-call.md](on-call.md#before-you-start).

No operator is needed during a match. While a parser waits for a fix, users stay on the other sources or on the clock estimate, which shows no score.

Three sources are read: FilGoal, YallaKora and Goal.com. Goal.com has [an off switch](#switching-goalcom-off).

## What runs

| Task | Worker on VPS-2 | When | Does |
| --- | --- | --- | --- |
| `live.scheduler` | `worker-live` | Every 60 s | Finds matches in the window. None or paused: no request. Otherwise queues one `live.poll` |
| `live.poll` | `worker-live` | From the scheduler | One cycle under `lock:live:poll`. An overlap exits |
| `live.check_robots` | `worker-live` | Daily 03:50 UTC | Compares each `robots.txt` with `backend/app/live/robots/` |
| `live.watchdog` | `worker-maintenance` | Every 2 min | Finishes a [stuck match](#stuck-matches), moves a `feed` row with no reading for 5 min to the clock, and reports a [capture](#the-capture) that stopped |
| `live.prune_runs` | `worker-maintenance` | Daily 03:40 UTC | Deletes `live_poller` runs older than 30 days |

The window is a kickoff from 150 minutes ago to 10 minutes ahead, plus matches on `feed` with no final state up to kickoff + 210 minutes. A `postponed` match stays on `/v1/live` as stored, but isn't polled.

One cycle: FilGoal's and YallaKora's list pages, link rows to matches, pick the page slots, fetch them. Then the same for Goal.com, only if the cycle's 50 s aren't up, because it answers slowly and mustn't cost the others their reads. Then the rules run on each match, and it's written. Each cycle writes one `import_runs` row under `live_poller`, which A13's run detail shows. Any parser error counts as that source failing validation. One match's error appears as `match_errors` in the run's `log`, with `log.exception` output in `worker-live`, and the others still get their poll. If the cycle itself breaks, its run closes as `failed`, with the exception's type in `error`, and the next cycle is the retry.

## The rules, in short

- **A higher score or a later stage** from any usable source goes out in the first poll that shows it. A false goal shows until the drop rule corrects it, which is the price of speed. D6's goal push has a stricter bar.
- **A lower score, an earlier stage or a missing event** waits until no usable source has shown the current one for `LIVE_DROP_HOLD_S`. A goal event stays while the score still counts it.
- **Sources that differ** keep the accepted score. After `LIVE_DISAGREE_AFTER_S` the owner gets a `disagree:` alert.
- **An unknown status** doesn't stop a source. The row's score counts only if it equals or covers the accepted one, and its status is left out.
- **The minute** comes from the source that gave the status. FilGoal's clock wraps once a period passes 60 minutes, so a minute more than 5 below that source's `peak_minute` in the same period counts as no minute. A poll with readings but no minute clears it, so a frozen one never looks current.
- **Order, when sources show the same stage:** FilGoal, Goal.com, YallaKora. Events and lineups come from FilGoal if it has any, then Goal.com. Each source's events stay stored under its own name, and `/v1` serves one source per match, so a goal can't show twice.
- **Stats** come from Goal.com's summary and are stored in `match_stats` on change. No client reads them.

## Full time

`finished` ends polling, and only a person can undo it, so one source isn't enough:

- Two usable sources showing it meet the condition, even if a third still shows extra time or penalties.
- One source alone must hold it for `LIVE_FULLTIME_HOLD_S`. If that source reads anything else, or any source shows extra time or penalties, the wait starts again.
- A source that merely failed a request keeps the wait going, with nothing cleared.

**So a match can stay live for up to 10 minutes after one source's full time.** That's on purpose: a level match may be going to extra time. While it waits it shows no minute, and that isn't a fault.

Once the condition is met, a drop still open or scores that differ hold it until they agree or for `LIVE_DROP_HOLD_S`. Then it finishes on the accepted score, with a `disagree:` alert if they still differ. An editor can correct the result in A3.

`cancelled` and `abandoned` need only the first usable source.

## Stuck matches

A match no source closes, like Bristol City v Wolves in the first capture, is finished by the watchdog on its last accepted score, with one `stuck:<match_id>` alert. It never goes back to scheduled.

| When | Row | What happens |
| --- | --- | --- |
| Kickoff + `LIVE_STUCK_AFTER_MIN` | `live`, second half, score unchanged for `LIVE_STUCK_QUIET_MIN`, no usable source's `peak_minute` below 90, and no usable source's reading with no period and a status of `NULL` or `live` | Finished |
| Kickoff + `LIVE_HARD_LIMIT_MIN` | Second half, extra time or penalties | Finished, whatever the score or the minutes say |
| Kickoff + `LIVE_HARD_LIMIT_MIN` | Never reached the second half | The clock, with a `stale:` alert |

"Usable" means `live_source_state` is `ok` or `failing` and its reading is under `LIVE_STALE_AFTER_S` old. A source with no `peak_minute` has no say in the minute condition. A status locked in A3 or a manual row is left alone.

A reading with no period and a status of `NULL` or `live` is an unmapped status, or a match page saying only «مباشر». It may be extra time or a shoot-out that no parser knows yet, so the row waits for the hard limit, showing `live`, second half, with no minute. If an `unknown_status:` alert came with it, see [what each alert means](#what-each-alert-means).

Up to the stuck limit, a stale row, every source being down and a pause all send a row to the clock. Past it, a row that reached its second half stays as it is with no `stale:` alert, and the steps above finish it.

## Postponed matches

A reading of `postponed` is written as usual, then polling stops for that match. The watchdog, a fallback and a pause all leave it as stored, so it raises no `stale:` alert and never shows as estimated live. If it's replayed or rescheduled, nothing reads the sources for it any more: in A3, set a manual status and then clear it. That returns the row to the clock, and it's polled again once it's back in the window.

## Settings

Environment on VPS-2 (`/srv/madar/.env`), with the defaults in code. `specs/031-d05-live-sources/capture-report.md` checks the page caps and the timers. After a change, recreate both workers with `dc up -d worker-live worker-maintenance`, because the watchdog reads the stuck settings too.

| Variable | Default | Means |
| --- | --- | --- |
| `LIVE_PAGE_CAP_FILGOAL` | 8 | Match pages a cycle on FilGoal |
| `LIVE_PAGE_CAP_YALLAKORA` | 2 | Match pages a cycle on YallaKora |
| `LIVE_PAGE_CAP_GOAL` | 4 | Match pages a cycle on Goal.com |
| `LIVE_GOAL_ENABLED` | `true` | Whether Goal.com is read at all |
| `LIVE_DROP_HOLD_S` | 300 | How long a lower score, an earlier stage or a missing event must last |
| `LIVE_DISAGREE_AFTER_S` | 600 | How long sources may differ before the owner hears |
| `LIVE_FULLTIME_HOLD_S` | 600 | How long one source must show full time alone |
| `LIVE_STUCK_AFTER_MIN` | 150 | Kickoff + this: the stuck check starts, and the clock stops taking a row that reached its second half |
| `LIVE_STUCK_QUIET_MIN` | 15 | No score change for this long, for the stuck check |
| `LIVE_DOWN_AFTER_FAILURES` | 3 | Failed cycles in a row before a source is down |
| `LIVE_STALE_AFTER_S` | 300 | No reading for this long sends a `feed` row to the clock |
| `LIVE_HARD_LIMIT_MIN` | 210 | The latest a `feed` row stays after kickoff |

`LIVE_CONFIRM_WAIT_S` is gone: if it's still in `.env`, delete it. The poller also needs `SCRAPE_USER_AGENT` (it refuses to fetch without one) and `RAW_ROOT` (default `/srv/raw`).

## Pause and resume

Use the live card in A13. A paused poller sends no requests, sends `feed` rows in the window to the clock on its next tick, and raises no alert. A `postponed` row stays as stored, and so does a row past the stuck limit that reached its second half. Resuming is enough: a valid reading then goes through the normal rules, and the kept score comes back. "Run now" is refused for this card.

## What each alert means

Each one is sent once when the problem opens and once when it closes. `alerted_at` is set inside the transaction, and the alert goes out after commit, so a crash in between loses one message and never repeats one. A missing Telegram token only logs ([source-alerts.md](source-alerts.md)).

| Alert | Key | What it means | What to do |
| --- | --- | --- | --- |
| `تغيّر شكل صفحة ‹source›` | `format:<source>` | A page failed validation, or a list had no matches while one is in the window. That source is out until it's valid again | [Update the parser](#updating-a-parser-from-a-saved-page) when free. Nothing is urgent while another source works |
| `ظهرت حالة غير معروفة في ‹source›` | `unknown_status:<source>` | A row has a status nobody has seen, most likely extra time or penalties. The source stays in use, its higher score counts and that row's status is left out. It closes on a cycle with no unknown row | [Add the wording](#updating-a-parser-from-a-saved-page) from the saved page, within 5 days, before the prune. On a match that reached extra time, this is also [T035](../../specs/031-d05-live-sources/tasks.md): check that its goals and shoot-out reached fans |
| `المصدر ‹source› متوقف` | `down:<source>` | `LIVE_DOWN_AFTER_FAILURES` failed cycles in a row, or a 429, 403 or 5xx backoff that keeps failing | Read `error` on the runs below. It closes by itself. Blocks are never worked around with proxies or another user agent |
| `كل المصادر المفعّلة متوقفة` | `both_down` | Every enabled source is unusable: matches in the window are on the clock estimate, except rows [past the stuck limit](#stuck-matches). The key keeps its old name | As above. It closes when any source is valid |
| `المصادر مختلفة على نتيجة المباراة ‹id›` | `disagree:<match_id>` | Usable scores differed for `LIVE_DISAGREE_AFTER_S`, or still differed when the match finished. The accepted score stays | Compare with the broadcast. If it's wrong, set a manual status in A3. It closes on agreement, or an hour after the match's limit |
| `المباراة ‹id› بلا قراءة حديثة` | `stale:<match_id>` | The watchdog moved the row to the clock, because no reading came for `LIVE_STALE_AFTER_S`, or it reached `LIVE_HARD_LIMIT_MIN` without reaching its second half | If several arrive together, `worker-live` has probably stopped: see [What to check](#what-to-check). It closes on the next reading |
| `أُنهيت المباراة ‹id› عند الحد الزمني` | `stuck:<match_id>` | No source closed it, so [the limit](#stuck-matches) finished it on its last score | Check the score against another source, and correct it in A3 if needed. It closes an hour after the match's limit |
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

A match's own readings, to compare the sources (never served to clients):

```bash
dc exec postgres psql -U madar -d madar -c "select source, status, period, minute, peak_minute, peak_period, home_score, away_score, read_at, changed_at from match_source_readings where match_id = <id>"
dc exec postgres psql -U madar -d madar -c "select * from match_live_state where match_id = <id>"
```

## Updating a parser from a saved page

A raw page is saved when its content changed, or when it failed validation, under `/srv/raw/live_poller/<date>/<run>/` for 5 days. The alert and `raw_ref` name the folder. A13's run detail shows the same page as text.

1. Copy the page to `backend/tests/live/fixtures/`, trimmed, with no personal data. Pages are untrusted: don't open them in a browser.
2. Add a test in `backend/tests/live/test_filgoal_parse.py`, `test_yallakora_parse.py` or `test_goal_parse.py`, and see it fail.
3. Change `backend/app/live/sources/`. A new status goes in that file's `STATUS_MAP` (`STATUSES` or `LIVE_PERIODS` in `goal.py`), and a new event type in `EVENT_TYPES`. Leave anything uncertain out: an unknown status doesn't fail validation, it opens `unknown_status:<source>` and its status is left out, which is the safe path.
4. A new stage must be in `_RANKS` in `crosscheck.py`, with a test in `test_crosscheck.py`, since the stage order is what decides a later status. Anything missing from it counts as `scheduled`.
5. Deploy by the normal PR. The source recovers by itself on its next valid page, and the alert closes.

Event types a parser doesn't map appear under `ignored_event_types` in the run's `log`, and unknown statuses under `unknown_statuses`. Neither fails validation.

## Switching Goal.com off

On VPS-2, set `LIVE_GOAL_ENABLED=false` in `/srv/madar/.env`, then:

```bash
dc up -d worker-live worker-maintenance
```

From the next cycle it gets no request at all, from the poller, the daily `robots.txt` check or the capture, and nothing new is stored from it. Scores it already gave stay until another source changes them under the usual rules.

Its `live_source_state` row stays with its last state, so A13's card keeps showing it. Nothing updates that row or closes its problems while it's off. If it had a problem open, close it by hand:

```bash
dc exec postgres psql -U madar -d madar -c "update live_problems set closed_at = now() where closed_at is null and key in ('format:goal', 'down:goal', 'unknown_status:goal', 'robots:www.goal.com')"
```

To remove what it stored, for instance if the approval ends, with the setting already off:

```bash
dc exec -T postgres psql -U madar -d madar -v ON_ERROR_STOP=1 -1 <<'SQL'
delete from match_stats where source = 'goal';
delete from match_events where source = 'goal';
delete from match_lineups where source = 'goal';
delete from match_source_readings where source = 'goal';
delete from match_external_ids where source = 'goal';
delete from unresolved_names where source = 'goal';
delete from team_aliases where source = 'goal';
delete from competition_aliases where source = 'goal';
delete from channel_aliases where source = 'goal';
delete from live_source_state where source = 'goal';
update dataset_versions set version = version + 1 where name = 'live';
SQL
```

The `sources` row stays, since revision `0008` owns it. Raw pages under `/srv/raw/live_poller/` go with the 5-day prune. Pages from a capture are `/srv/raw/capture/<date>/*_goal_*`, and delete those by hand. The committed fixtures are `backend/tests/live/fixtures/goal_*`, with `test_goal_parse.py`.

## When `robots.txt` changes

1. Read the diff between the live file and `backend/app/live/robots/<site>.txt`.
2. If a rule affects us, update `DENY_RULES` in `backend/app/live/robots.py` and its tests.
3. Replace the committed copy. The problem closes on the next daily check after the deploy.

## The capture

Records real pages for `specs/031-d05-live-sources/capture-report.md` (T026–T028). It reads only, and writes nothing to the database. Start it before the night's first kickoff:

```bash
ssh madar-vps2
sudo -iu deploy
cd /srv/madar/infra
export IMAGE_TAG=$(cat /srv/madar/current_tag)
dc() { docker compose --env-file /srv/madar/.env -f compose/vps2.yml "$@"; }
dc run -d --name madar-capture worker-live python -m app.cli capture-live --minutes 240
docker logs -f madar-capture
```

It runs detached, so leaving the log or the SSH session doesn't stop it. Its container stays after it ends, because the report needs the log's `capture_failed` lines, with each failure's `page` and `why`. After writing the report, and before any new capture, run `docker rm madar-capture`. Before the first capture, run the host check in [owner-actions](../owner-actions.md).

About once a minute it reads all three list pages, then the pages of the matches each list shows being played, up to `--page-cap` per source (default 12). No IDs are needed. A row with an unknown status gets a page too, because it may be extra time. A 5xx, a dropped connection or an empty rate-limit bucket on one page is logged and the rest go on. A 403 or 429 on any page ends that source's round and tells you at once. If the next round is refused too, the capture sends that source nothing more until it's restarted, and the other sources carry on. With `LIVE_GOAL_ENABLED=false` it skips Goal.com, and a missing `SCRAPE_USER_AGENT` stops it before any request.

Pages land in `/srv/raw/capture/<date>/` as `<UTC time>_<source>_<list or id>.html.gz`, by Cairo date. That folder isn't pruned, so delete it when the fixtures are committed.

| Telegram | What it means | What to do |
| --- | --- | --- |
| `بدأ التسجيل، وينتهي نحو ‹time›` | It started, and that's its expected end in Cairo time | Nothing |
| `انتهى التسجيل` | It ended normally | Write the report |
| `التسجيل: فشل ‹source› في 5 جولات متتالية` | That source's list failed 5 rounds in a row. The others go on | Check `docker logs madar-capture`. If VPS-2 is blocked, that's a result: don't get around it, and say so in the report |
| `التسجيل: عاد ‹source› للعمل` | It recovered | Nothing |
| `التسجيل: رفض ‹source› طلبًا (403 أو 429)` | It refused a page, so its round ended. It gets one more try next round | Nothing yet. A second message decides it |
| `التسجيل: عاد ‹source› يقبل الطلبات` | The next round wasn't refused, so reading goes on | Note it for the report |
| `التسجيل: رفض ‹source› الطلبات جولتين متتاليتين` | Refused twice in a row, so nothing more goes to it until a restart. The others go on | That's a result: don't get around it. Say so in the report, and let the owner decide about that source before any restart |
| `التسجيل: ‹source› بلا مباريات جارية منذ 5 جولات` | Its list reads fine but shows no live rows, while another source shows some. A changed status wording looks like this | Look at its latest `*_list.html.gz` with `zcat` |
| `التسجيل: عاد ‹source› يعرض مباريات جارية` | It shows live rows again | Nothing |
| `توقف التسجيل قبل نهايته` | No round for over 5 minutes, so the process died. `live.watchdog` sends this within about 7 minutes | Find the stopped container in `docker ps -a --filter name=madar-capture`, read the end of `docker logs madar-capture`, and check `df -h /srv/raw`. If the night isn't over, save the log with `docker logs madar-capture > ~/madar-capture.log 2>&1`, run `docker rm madar-capture` and start it again |

To stop it early, run `docker stop madar-capture`. Only a normal end clears its Redis key `live:capture:heartbeat`, so the "stopped" message follows a few minutes later. That's expected, and it's sent once. The container stays either way, so `docker rm madar-capture` still comes after the report.

## The disk check

At most 8 FilGoal pages a minute gzip to about 60 KB each, so a busy day stays well under 1 GB, and a 5-day prune applies (`adapters.prune_raw_pages`).

A 240-minute capture adds about 360 MB at most, from the page sizes on 2026-11-04: three list pages of about 170 KB gzipped together, and up to 12 match pages each from FilGoal (about 60 KB gzipped), YallaKora (about 20 KB) and Goal.com (about 30 KB), so about 1.5 MB a round. VPS-2 had 37 GB free on 2026-11-05. The capture's folder isn't pruned.

```bash
ssh madar-vps2 'df -h /srv/raw; du -sh /srv/raw/live_poller /srv/raw/capture'
```

Above 80% full, delete `/srv/raw/capture/` first, then look for a parser saving every page: a page that changes on each fetch defeats the hash, and `pages` in the run `log` stays above zero every minute.
