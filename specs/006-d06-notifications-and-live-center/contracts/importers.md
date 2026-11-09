# Contract: the two importers

Lane B2 owns `backend/app/adapters/`, `infra/` and their runbook rows. Both adapters implement `SourceAdapter` and meet constitution VII. Neither ever writes a logo, a team or a competition row. Background is in research [R21](../research.md#r21-sporteventz) and [R22](../research.md#r22-api-football).

## Registering a source

Each one changes the same places:

| Place | Change |
|---|---|
| `upsert.py:52` | Source rank, or its fill-only rule |
| `tasks.py` :135, router :87-95, queue map :692 | The adapter and its fetch queue, `scrape`, in both the router and the map, as `legacy` and `yallakora` do. The map raises on an unknown source. `worker-scrape` fetches and parses, and `adapters.ingest` stays on `imports` |
| `schedule.py` | Beat entry |
| `ratelimit.py:39` | Host bucket. Unlisted hosts have no limit, so this isn't optional |
| `raw_store.py:25` | The raw store's source list |
| `tests/adapters/test_report.py:44` | The expected slots |
| `docs/runbooks/imports-and-sources.md` | The sources table |

A13's card appears by itself (`services/admin/sources.py:111`).

## Changes both need

| Change | Where | Rule |
|---|---|---|
| Sport on records | `ParsedFixture`, `normalize_fixture`, `upsert._apply` (:480-490) | A record's `sport` is written and compared. The default stays `football` |
| Sport in merges | `_may_be_a_near_row` (:386-413), name merge (:432-444) | Rows of different sports never merge or count as near |
| Skip resolving | A per-source flag in `_apply` (:181-199, :209, :213) | `sporteventz` skips resolve and queue |
| Page limit | `messages.py:31` | `MAX_PAGES` per source, 8 for `sporteventz`. Update `test_messages.py:160` |
| Stopped runs | `tasks.py:386`, `:405`, `health.py` | [Below](#a-run-that-stops-on-purpose) |
| LiveSoccerTV target list | `plan_targets` (`livesoccertv.py:512-518`) | Football only |
| Link changes | `upsert._apply` after `_reconcile_links`, `apply_broadcasts` | [`report_link_change`](push-pipeline.md#the-call-importers-make) |

### A run that stops on purpose

`import_runs.status` gains `stopped`, with `error` set to `budget_reached` or `not_configured`.

- It counts toward neither the breaker nor the zero-items alarm.
- `report.py` treats it as a filled slot, so the daily report doesn't call it missing.
- A13 shows the reason, and `not_configured` reads as a state rather than a failure.

An unreadable counter is a fault, not a stop: it ends the run `failed`, with `budget_unreadable`.

## `sporteventz`

| | |
|---|---|
| Host | `www.sporteventz.com`, 1 request per 700 ms, with the standard backoff |
| Schedule | Every 6 h, today to +3 |
| Sports | Basketball, handball, volleyball, tennis. Others are skipped and counted in the run's log |
| Requests | Sport page (for the access key), then its data. 8 pages per run |

**Fetch.** `GET /en/other-sport/<slug>.html`, read the access key with a tested regex, then the data URL with that key and a fixed `client_tz_offset`. An empty body means the key expired: re-read the page once. The site's `robots.txt` allows both paths for `*` as of 2026-11-06. Importers have no shared robots check: `yallakora.py` records its reading in its docstring. This adapter does the same, and a test checks both paths with `urllib.robotparser` against a copy committed under `backend/tests/fixtures/sporteventz/`. `imports-and-sources.md` says to re-check it when the source is reviewed.

**Parse.** Pure, on saved pages. JSON `Result`/`Records`: `Sport, Begin, Team1, Team2, Tournament, Category, @id, Channels`. A missing access key or `Records` key raises a format error, which alarms at once.

| Field | Written as |
|---|---|
| `external_id` | `@id` |
| `sport` | Mapped from `Sport`, from a fixed table |
| `home_team_name`, `away_team_name` | `Team1`, `Team2` as text. Team IDs NULL. A same-name pair is skipped |
| `competition_name` | `Tournament`, else `Category`, else the sport. Competition ID NULL |
| `kickoff_at` | From `Begin` and the sent offset, in UTC. No time: `time_tbd = true` |
| Logos | NULL |

The old tool's `+0300` is wrong in winter, and `domain/time.py:43` reads unmarked 1–11 as PM, so this doesn't use either.

**Broadcasters.** Rank channels: Arabic script, then an Arab country, then the rest. Slot 1 is the first. Slot 2 is the next four joined with ` · `, cut at a whole name within 80 characters. Each name passes `find_card_sharing_label` and the 80-character limit before it's written, because importers don't go through the admin schema.

A match with `broadcasts` in `locked_fields` is left alone.

**Zero items.** A valid response with no records in any sport isn't an alarm until 7 days have passed since the last run with records. `health.py` gains that grace per source.

## `api_football`

| | |
|---|---|
| Host | `v3.football.api-sports.io`, its own bucket |
| Auth | `x-apisports-key`, from `API_FOOTBALL_KEY` (`SecretStr | None`) in VPS-2's `.env` |
| Schedule | Twice a day, today to +3 |
| Requests | `GET /fixtures?date=<d>&timezone=UTC`, one per date. 8 a day |
| Settings | `API_FOOTBALL_DAILY_BUDGET` (90), `API_FOOTBALL_LEAGUES` (`233,39,2`) |

**Before building on this,** the checks in the [quickstart](../quickstart.md#before-lane-b2-builds-on-api-football) must pass.

**Key handling.** The header is added at send time, like `satair_bridge.py:80`. A test asserts it reaches no log, raw page or `import_runs.log`. With no key: `stopped`, `not_configured`, and no request.

**Budget.** `app/adapters/budget.py`, with a hook in `fetcher._request`'s loop (:149-151), so each attempt counts, including retries and «تشغيل الآن».

```python
count = redis.incr(f"budget:api_football:{utc_date}")   # EXPIRE 48 h on first use
if count > limit: raise BudgetReached
```

| Case | Result |
|---|---|
| Over budget | No request. `stopped`, `budget_reached` |
| Redis error | No request. `failed`, `budget_unreadable` |
| Non-empty `errors` in a 200 | `failed`, with the provider's message, the key never included |

The key's date follows the provider's reset, which check 3 confirms.

**Parse and normalize.** Pure, on saved responses. Filter by `league.id` before anything else, so only allowlisted leagues reach the resolver.

| Field | Written as |
|---|---|
| `external_id` | `fixture.id` |
| Teams, competition | English names through the resolver. A miss queues the name |
| `kickoff_at` | `fixture.date` |
| `venue` | Only if the row has none |

FT, AET and PEN fixtures are skipped. Logos are ignored (constitution IV).

**Fill only.** Through the strict probe (`_yallakora_probe`, `upsert.py:345`) and frozen fields (`_fields_are_frozen`, `:510`), which today test `self.source == "yallakora"`, so they become a set of sources holding both names. An unresolved team raises `WaitForEditor`, as it does for YallaKora. A match is created only when both teams and the competition resolve, and existing fields of other sources are never overwritten.

## What B1 provides

- `broadcasts` in `MATCH_LOCKABLE` and the CHECK, and A4's save setting it.
- `report_link_change`.
- `stopped` in the CHECK and the schema.
- The dashboard's football filter.
- `repair-matches sport`, in `app/cli.py`.
