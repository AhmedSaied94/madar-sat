# Research: D5 · Live and discovery

Each item records a decision, why it was made and what was rejected. Items marked **capture** are starting values that T-level capture work must confirm or change.

## What was checked on 2026-11-04

A read-only look from the owner's laptop, not VPS-2, and not during a confirmed live match:

- Both `robots.txt` files were read.
- `https://www.filgoal.com/matches/` answered `200` with about 232 KB. Each match has `data-match-id`, `data-champion`, a competition name, team names, `.home-score`, `.away-score` and a `.status` element.
- `https://www.yallakora.com/match-center` redirected to `/matches-center` and answered `200` with about 229 KB. Each match has `liveScoreMatchId`, a channel, a stage, `.matchStatus`, `.MResult` and a match link.

So the list pages appear to carry what the page-cap decision needs. Live values and status strings are still unknown.

## R1. Parsers start now, and a small recorder completes them

**Decision:** `python -m app.cli capture-live` runs on VPS-2 in the `worker-live` image. It saves both list pages every 60 s and the match pages of chosen IDs while they are live, under `/srv/raw/capture/<date>/`, using the shared fetcher, rate limits and `robots.txt` deny list. B1 commits a trimmed set under `backend/tests/live/fixtures/` (`backend/tests/fixtures/` is B2's) and writes `specs/005-d05-live-and-discovery/capture-report.md`.

**Why:** Finished and scheduled pages show the page structure, FilGoal's JSON model, names, IDs, scores, events and lineups, so parsers can start on them at once. Only live pages show the in-play status codes, the minute format, half-time, extra time, penalties and the update delay. Starting early is safe because an unseen status fails validation instead of being guessed. VPS-2 is where the poller will run, so its IP's treatment is part of the evidence.

**Rejected:** Browser or manual saving (doesn't measure delay). Holding all parser work for the capture (it would tie the day to evening fixtures). Treating parsers from finished pages as complete (status strings and minutes wouldn't be seen).

## R2. B1's code lives in `backend/app/live/`

**Decision:** A new package, outside B2's folder (spec FR-051):

- `sources/filgoal.py`, `sources/yallakora.py`: pure `parse_list` and `parse_match`, returning `SourceReading` values or raising `LayoutChanged`;
- `crosscheck.py`: one pure function from the confirmed state and readings to a decision (SD §6.7's table);
- `links.py`, `pick.py`, `apply.py`, `problems.py`, `tasks.py`, `schedule.py`, `settings`.

`app.live.schedule` joins `SCHEDULE_MODULES`.

**Why not `SourceAdapter`:** It is a fixture contract (`DateWindow`, upsert pipeline). The live path has different inputs and writes, and forcing it through `fetch`/`ingest` would couple it to a two-queue pipeline that adds too much delay. Constitution VII (1.3.0) now limits `SourceAdapter` to fixture importers and keeps its other rules for the readers: pure parsers tested on saved pages, allowlists, rate limits, backoff, a run record, and a zero-items alarm.

**B2 provides:** buckets for `www.filgoal.com` and `www.yallakora.com` in `DEFAULT_LIMITS`, `live` in `HEARTBEAT_QUEUES`, the started `worker-live`, and `resolve.py`'s alias step.

## R3. Rate limits

**Decision:** `www.filgoal.com` and `www.yallakora.com` get `Bucket(capacity=2, refill_seconds=4.0)`, shared by the poller and the `yallakora` importer through the same Redis key. Starting caps are `LIVE_PAGE_CAP_FILGOAL=8` and `LIVE_PAGE_CAP_YALLAKORA=2` (**capture**), read from settings.

**Why:** At one request per 4 s, a 60 s cycle has room for a list page plus about 14 pages. The caps leave room for the importer. YallaKora's match page is only needed for stats, so the list page does the cross-checking.

## R4. The `robots.txt` rules that affect us

**Decision:** A deny list in `app/live/robots.py`, checked before any request, with a test per rule. A daily check compares each live `robots.txt` with a committed copy and alerts on change. It never auto-updates.

- **YallaKora:** `*/Match/EuroMatchStats2`, `*/Match/Matchsquad2`, `*/Match/MatchManOfTheMatch2`, `*MatchMinByMinPaging*`, `*/champions`, `*/arabic`, `/*?*?*`.
- **FilGoal:** `/arabic/*.aspx`, `/login/`, `/register/`, `/account/`.

**Note:** `*/champions` would match a path starting `/champions-league/`. Today's Champions League links use `/uefa/...` (not blocked), and `/asian-champions-league/` isn't blocked. If a match link is ever blocked, that match gets no YallaKora page, and the list page still works. `*/Match/Matchsquad2` is why lineups come from FilGoal only.

**Why not parse `robots.txt` at runtime:** A silent change would widen or narrow behaviour unseen. An alert puts the owner in charge.

## R5. Cross-check state lives in PostgreSQL

**Decision:** `match_live_state` holds the confirmed score and any pending candidate per match. `match_source_readings` holds the latest reading per match and source. `live_problems` holds one row per open problem. See [data-model.md](data-model.md).

**Why:** It must survive worker restarts and retries (spec: one alert per problem, also across restarts). Holding a confirmed score outside `matches` is also required, because `ck_matches_clock_no_score` forbids a score on a clock row, so a fallback must clear `matches` and a recovery must restore it.

**Rejected:** Redis (a flush would lose the pending state and resend alerts).

## R6. Falling back, staying honest and the watchdog

**Decision:**

- **A source is down** after `LIVE_DOWN_AFTER_FAILURES=3` failed cycles in a row (**capture**). A validation failure stops it at once.
- **Fallback** sets `status_source='clock'`, `status='scheduled'` and clears score, minute and period, which is what the existing constraint and `derive_status` expect. `match_live_state` keeps the score.
- **Recovery** requires a valid reading, then goes through the normal rules.
- **`live.watchdog`** runs every 2 min on the `maintenance` queue. It moves a `feed` row to the clock if no reading has arrived for 5 min, or at kickoff + 210 min without a final state, and opens a problem. The scheduler and `/v1/live` keep a `feed` match until that limit, because extra time and penalties can pass the 150-minute start window, and an estimated `finished` match shows no score.

**Why the watchdog:** Nothing else corrects a `feed` row when `worker-live` itself dies. The row would show a stale score as live, which constitution II forbids. Beat and `maintenance` keep running, and it costs one indexed query.

**Backoff and the alarm:** A 429, 403 or 5xx sets `live:backoff:<host>` in Redis with exponential backoff and jitter, capped at 10 min. The cycle skips that host until then and counts a failed cycle. A list page with no matches while one is in the window opens `format:<source>`.

**Health:** `live_poller` health goes through a new B2 function, `health.record_live_cycle`, which never touches the breaker. `record_run` can open the breaker, and `source_is_paused` would then stop the poller for good, which would break recovery. The A13 card reads each source's state from `live_source_state`.

**A13 pause:** Pausing the live card counts as both sources being down, with no alert, so a paused poller can't leave stale scores. "Run now" is refused for it (`check_runnable`).

## R7. A match is linked only on both teams and the kickoff

**Decision:** Link order: an existing `(source, external_id)` in `match_external_ids`; otherwise both team names resolve and exactly one of our matches has those teams in that order, with kickoffs within 45 min. A row with no time of its own, as FilGoal's is once a match starts, needs that one match inside the poll window instead. A reversed order, or more than one match, isn't linked and is logged. `filgoal` writes external IDs on linking, and `yallakora`'s importer writes them for its source too.

**Why:** A wrong link publishes another match's score (spec FR-022a). Reversed order would swap scores.

## R8. Aliases are scoped by competition

**Decision:** `team_aliases` has `competition_norm` (`''` means any competition), with a primary key `(source, alias_norm, competition_norm)`. Lookup tries the row's competition, then `''`.

**Why:** SD's `(source, alias_norm, target_id)` allows one target per name, but `الأهلي` is at least three teams on the A13 board. An unscoped alias would attach an Egyptian match to a Saudi team.

**Resolution order** (`adapters/resolve.py`): external ID → alias (scoped, then any) → name rules as today. `reason` gains `alias`.

## R9. Suggestions use trigrams, and never cross scripts

**Decision:** The queue list adds up to 3 candidates per row: exact `name_norm` matches first, then `similarity() ≥ 0.3` with `pg_trgm`, restricted by kind and sport. Confidence is `round(similarity × 100)`. A Latin name with no same-script candidate shows no suggestion.

**Why:** The board's example maps `Nasaf Qarshi` to `ناساف` at 92 %. Trigrams can't do that, and adding transliteration is too much for D5. An empty suggestion is honest, and the form still lets the editor search. This is a deliberate difference from the board's example data.

## R10. "Create new" reuses the existing create forms

**Decision:** A13 opens the existing team, competition or channel create form pre-filled. After it saves, A13 calls `POST /unresolved-names/{id}/map` with `created: true`. No new create endpoint.

**Why:** Those forms already validate, audit and bump versions, and a channel needs satellite and frequency fields. If the second call fails, the entity exists and the row stays open, and mapping it again is safe.

## R11. LiveSoccerTV's placeholders stay

**Decision:** `livesoccertv_links.py` keeps creating hidden placeholder channels (D3) and additionally records a `channel` queue row. Mapping writes a `channel_aliases` row, used from the next run. Placeholders aren't removed on D5.

**Why:** Placeholders hold links that would otherwise be lost and are already hidden from `/v1`. FR-022's "no entity created" is met for teams, competitions and everything `yallakora` does. This is a recorded exception for one existing LiveSoccerTV path.

## R12. Run records and raw pages

**Decision:**

- One `import_runs` row per cycle under source `live_poller`, with a compact log. `live.prune_runs` deletes those older than 30 days (about 43k rows at most), and importer runs are untouched.
- **A raw page is saved** when its normalized content hash changed, or on a validation failure or disagreement. The 5-day prune applies.
- **Estimate:** at most 8 FilGoal pages a minute, gzipped to about 60 KB (**capture**). A busy day writes well under 1 GB, and the on-call page gets a disk check.

## R13. Run detail reads raw pages over Redis

**Decision:** `GET /admin/api/import-runs/{id}/raw?page=0` returns the cached text from Redis if it is there. Otherwise it sends `adapters.read_raw_page` to VPS-2's `maintenance` queue and returns `state: pending`, and the client polls for up to 10 s. The task writes `rawview:<run>:<page>` with text capped at 512 KB and a 5-min TTL. The path comes from `import_runs.raw_path`, never from the request.

**Why:** Raw pages live on VPS-2 and the admin API on VPS-1. This adds no port, service or mount. The admin shows the text in a `<pre>`, so scraped HTML can't run (constitution V).

**Rejected:** A VPS-2 HTTP service (new attack surface). Copying raw pages to Postgres (size).

## R14. Editor conflicts during a live match

**Decision:** `services/admin/versions.py` stops hashing `matches.minute`, `period` and `status_updated_at`. A change of score or status still conflicts.

**Why:** Every row column is hashed today, so the poller's minute writes would make any open editor's save fail with `409` once a minute. Hash changes don't break anything: a stale tag only causes one retry.

## R15. Old app builds are safe

**Decision:** No version bump or `min_supported_build` change is needed.

**Evidence:** The generated Dart model has `required List<dynamic> events` and `required dynamic lineups`, so `app-v0.3.0` and `web-v0.1.0` parse real values and ignore them. `/v1/live` is unchanged. If the `oasdiff` check flags `lineups` widening from `null` to `object | null`, the owner reviews and accepts that one finding in the contract PR.

## R16. Match stats wait for the capture

**Decision:** No stats table in `0007`. If the capture shows YallaKora fills in stats usefully on pages not blocked by `robots.txt`, a small expand-only `0008` adds `match_stats (match_id, source, stats jsonb, updated_at)`. No client reads stats on D5 or D6.

**Why:** Spec FR-018. The contract merges before evening matches can be captured. This is the one allowed exception to FR-015's single revision.

## R17. App caching and routing

**Decision:** The three screens cache the API documents in the existing drift `CachedDocuments` table, so no drift schema change is needed. The stub routes `/channel/:id`, `/team/:id` and `/competition/:id` already exist and are replaced. S6 uses a `pageBuilder` that shows a modal bottom sheet, and remains deep-linkable.

## R18. Discovery endpoints change only by adding

**Decision:**

- `ChannelDetail.upcoming_matches` is limited to the next 7 days (today: 20 rows, no date limit), as PB S6 says.
- `CompetitionDetail` gains `upcoming`, `recent` (30 each, as `TeamDetail` does) and `rights_holders[].satellites` / `.competition_count`. Its ETag gains `matches` and `teams`, with a 60 s bucket.
- `TeamDetail.upcoming` / `recent` stay at 10 rows. S7 shows these, and "more" is out of scope.

**Rejected:** S8 calling `/v1/matches?competition_id=`: `validate_window` bounds the range, so it would need several calls.

## R19. The load-test carry-over

**Decision:** Follow spec FR-060–FR-063, in order. After a resize, `api-public`'s `gunicorn -w` is reviewed against the core count in `infra/compose/vps1.yml` (B2). `docs/runbooks/load-testing.md`'s step 3 records the result. Caddy's `cache-handler` needs a custom `xcaddy` arm64 image, so it is only built if the resize fails.
