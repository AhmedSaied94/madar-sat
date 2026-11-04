# Data model: D5 · Live and discovery

One expand-only Alembic revision, `0007`, owned by B1. `0003`–`0006` are taken, so the brief's `0003` is stale. `0008` exists only if the capture justifies match stats ([research R16](research.md#r16-match-stats-wait-for-the-capture)).

`rights_holders` and its child tables already exist, and gain only one column (below).

## New tables

### `match_events`

| Column | Type | Rules |
|---|---|---|
| `id` | bigint PK | |
| `match_id` | FK `matches` | |
| `side` | text | `home` or `away` |
| `type` | text | `goal`, `own_goal`, `penalty`, `missed_penalty`, `red_card` |
| `minute` | text | Same pattern as `matches.minute` |
| `player_name` | text, null | Structured fact only |
| `source` | FK `sources` | |
| `external_id` | text | From the source, or a stable hash of type, side, minute and player if it has none |
| `created_at` | timestamptz | When it was first served. D6's goal producer reads this |

Unique `(match_id, source, external_id)`, index `(match_id, minute)`.

- **Lifecycle:** Inserted by the diff. Deleted when the source removes it. While a score is pending for the match, goal-type rows are neither inserted nor deleted that cycle, so the timeline can't contradict the score.

### `match_lineups`

| Column | Type | Rules |
|---|---|---|
| `match_id` | FK | PK with `side` |
| `side` | text | `home` or `away` |
| `formation` | text, null | |
| `players` | jsonb | `[{name, number, position, is_starter}]`, capped at 40 entries |
| `source` | FK `sources` | |
| `updated_at` | timestamptz | |

### `match_live_state`

One row per polled match. This is the cross-check's memory.

| Column | Type | Rules |
|---|---|---|
| `match_id` | PK, FK | |
| `confirmed_home`, `confirmed_away`, `confirmed_home_pen`, `confirmed_away_pen` | smallint, null | Survive a clock fallback (`ck_matches_clock_no_score`) |
| `candidate` | jsonb, null | `{home, away, home_pen, away_pen, source, first_seen_at, polls}` |
| `disagreement_since` | timestamptz, null | Set when the wait ran out |
| `has_page_slot` | boolean | A match keeps its slot until it ends |
| `last_reading_at` | timestamptz, null | The watchdog reads this, indexed |
| `updated_at` | timestamptz | |

**Pending candidate:**

```
none ─(one source shows a new score)─▶ pending
pending ─(the other source shows it)─▶ confirmed, candidate cleared
pending ─(other source down/invalid/not covering, same score in 2 polls)─▶ confirmed
pending ─(wait ends without agreement)─▶ disagreement: last confirmed score stays, one alert
disagreement ─(sources agree)─▶ confirmed, problem closed, recovery alert
```

### `match_source_readings`

The latest reading per match and source, overwritten each cycle only when it changed.

| Column | Type | Rules |
|---|---|---|
| `match_id`, `source` | PK | |
| `status`, `period`, `minute` | text, null | Normalized values |
| `home_score`, `away_score`, `home_pen`, `away_pen` | smallint, null | |
| `read_at`, `changed_at` | timestamptz | `changed_at` gives the source's update delay |

Never served to clients.

### `live_source_state`

| Column | Type | Rules |
|---|---|---|
| `source` | PK, FK | `filgoal` or `yallakora` |
| `state` | text | `ok`, `failing`, `down`, `invalid` |
| `consecutive_failures` | int | ≥ 0 |
| `last_ok_at` | timestamptz, null | |

```
ok ─(failed cycle)─▶ failing ─(LIVE_DOWN_AFTER_FAILURES)─▶ down ─(valid cycle)─▶ ok
any ─(validation failure)─▶ invalid ─(valid cycle)─▶ ok
```

A source in `invalid` or `down` is still read at list-page rate so that recovery is seen, but its values aren't used. A `403`/`429` follows backoff.

### `live_problems`

One alert per problem.

| Column | Type | Rules |
|---|---|---|
| `key` | text PK | `format:filgoal`, `down:yallakora`, `both_down`, `disagree:<match_id>`, `stale:<match_id>`, `robots:<host>` |
| `opened_at`, `closed_at` | timestamptz | A reopened key clears `closed_at` |
| `raw_ref` | text, null | The saved raw page |
| `alerted_at`, `recovered_alerted_at` | timestamptz, null | Set in the same transaction as the state change, sent after commit |

### `team_aliases`, `competition_aliases`, `channel_aliases`

| Column | Type | Rules |
|---|---|---|
| `source` | FK `sources` | PK |
| `alias_norm` | text | PK, `ar_normalize` output |
| `competition_norm` | text, default `''` | PK. `team_aliases` only; `''` means any competition ([R8](research.md#r8-aliases-are-scoped-by-competition)) |
| `team_id` / `competition_id` / `channel_id` | FK, `ON DELETE CASCADE` | Target |
| `created_by` | FK `admin_users`, null | |
| `created_at` | timestamptz | |

### `unresolved_names`

| Column | Type | Rules |
|---|---|---|
| `id` | bigint PK | |
| `source` | FK `sources` | |
| `kind` | text | `team`, `competition`, `channel` |
| `name` | text | As the source wrote it, capped at 200 |
| `name_norm` | text | |
| `competition_norm` | text, default `''` | Context, part of the key |
| `context` | jsonb | Latest `{match_id, home, away, competition, kickoff_at}` |
| `seen_count` | int | |
| `first_seen_at`, `last_seen_at` | timestamptz | |
| `state` | text | `open`, `mapped`, `created`, `ignored` |
| `target_id` | bigint, null | Required when `mapped` or `created` |
| `resolved_by` | FK `admin_users`, null | |
| `resolved_at` | timestamptz, null | |

Unique `(source, kind, name_norm, competition_norm)`, partial index on `last_seen_at` where `state = 'open'`.

```
open ─map─▶ mapped        open ─create+map─▶ created        open ─ignore─▶ ignored
```

- A later run upserts: an `open` row gets a new count and context. An `ignored`, `mapped` or `created` row doesn't reopen.
- **No names with card-sharing labels reach `/v1`:** aliases aren't served, and create-new uses the existing `Name120` screening.

## Changed tables

| Table | Change |
|---|---|
| `sources` | New rows: `filgoal` (`kind='live_reader'`), `yallakora` (`kind='fixtures'`), `live_poller` (`kind='live'`). `filgoal` is hidden from A13's cards; `live_poller` carries the board's one Live poller card. `yallakora` keeps its importer card |
| `dataset_versions` | The check allows a new `unresolved_names` |
| `rights_holder_carriages` | New nullable `package` text, which PB A9 asks for and the table lacks |
| `matches` | New nullable `local_broadcaster_eg` text. `MatchDetail` already has the field, always `null`, and nothing stores it. It joins `MATCH_LOCKABLE` and `ck_matches_locked_fields`. Written by `yallakora`, served by `match_detail.py` |

## Writes by the poller

| Target | Rule |
|---|---|
| `matches.status`, `period`, `minute`, `status_label`, `status_updated_at`, `status_source` | Skipped while `status_source='manual'`. `status` is skipped if in `locked_fields` |
| Scores | Written only after confirmation, and skipped per field if in `locked_fields` |
| `dataset_versions.live` | Bumped as the last statement of each changing transaction. Not `matches`, so `/v1/matches`' cache isn't invalidated every minute |
| `audit_log` | Not written per poll. It records human edits, and `import_runs.log` records the poller |

`matches.status_source` moves `clock → feed` on the first valid reading after kickoff, and `feed → clock` on fallback. `manual` is only cleared by an admin.

## Status mapping

`app/live/sources/*.py` map each source's strings to the §6.2.3 states (`scheduled`, `live` with `1H`/`2H`, `halftime`, `extra_time` with `ET1`/`ET2`, `penalties`, `finished`, `postponed`, `cancelled`, `abandoned`). Each mapping table starts from saved pages and the capture completes it. An unknown string fails validation. Strings seen so far: «لم تبدأ», «تأجيل».

The final states `finished`, `cancelled` and `abandoned` end polling. `postponed` stays as stored and leaves the window normally.
