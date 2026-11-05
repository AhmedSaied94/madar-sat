# Contract: the live rules

This replaces the "Cross-check" table in SD §6.7 and in `specs/005-d05-live-and-discovery/contracts/live-pipeline.md`. No `/v1` shape changes. `/v1/live` and `MatchDetail` get better values in their existing fields.

## The pure interface

```python
ORDER = ("filgoal", "goal", "yallakora")   # status preference; also events and lineups, without yallakora

def decide(
    state: LiveState,
    sides: Mapping[str, SideInput],  # one entry per enabled source
    now: datetime,
    *,
    drop_hold: timedelta,
    disagree_after: timedelta,
    fulltime_hold: timedelta,
) -> Decision: ...
```

`SideInput` keeps `valid`, `not_covering` and `unavailable`. A disabled source has no entry.

`LiveState` also carries the stored `minute` and each source's `peak_minute` and `peak_period`, for the minute rules below.

A reading can carry `unknown_status`: the label of a status nobody has seen, with `status`, `period` and `minute` empty. The cycle passes it as `valid` only if it has a score, and otherwise as `not_covering`, so a row with a score keeps the match from going stale and a row without one doesn't.

"Covers" means each of home and away is at least the other's, and penalties too when both carry them. So 2–1 covers 1–1, and 0–2 doesn't cover 1–1. A reading with no penalties never erases accepted ones (B1-R1-2).

## Score

| Situation (usable readings with a score) | What happens |
|---|---|
| No accepted score yet | Accept the one covering the most goals, in `ORDER` on a tie |
| A reading covers the accepted score and differs | Accept the highest of those at once. Record its first source and time. Clear `drop_since` |
| A reading equals or covers the accepted score | Keep it. Clear `drop_since` |
| No reading covers the accepted score | Set `drop_since`, keep the score. At `drop_hold`, accept the highest reading |
| No reading has a score | Nothing changes |

Agreement alone never lowers a score. A manual status and `locked_fields` win, as in spec 005.

A reading with `unknown_status` counts in this table only if it equals or covers the accepted score. A lower score on it is left out, as if the source had no score this poll. If there's no accepted score yet, its 0–0 isn't accepted, but any other score is.

## Status and minute

Stages run in this order: `scheduled`, first half, halftime, second half, extra time, penalties. `finished` comes after all of them and has its own table below.

| Situation | What happens |
|---|---|
| A usable reading shows a stage later than the stored one | Write the latest stage shown, from the first source in `ORDER` on a tie. Clear `status_drop_since` |
| No reading is later, and at least one shows the stored stage | Keep the stage. The label comes from the first source in `ORDER` showing it. Clear `status_drop_since` |
| All usable readings show an earlier stage | Set `status_drop_since`, keep the status. At `drop_hold`, write the latest stage shown |
| `live` with no period, as on a YallaKora match page | It says nothing about the half. It moves a `scheduled` row to `live`, and counts as showing the stored stage at any later one, extra time and penalties included. The cycle fills in the stage from the page's list row first, when that row has one |
| A reading has `unknown_status` | It's left out of this table |
| A stored status is `finished` | The match has left the window, and only a person changes it |
| `cancelled`, `abandoned`, `postponed` | Only from the first usable source, as in spec 005. A postponed match stays as stored, unpolled |
| Anything else, such as a lone full time or only `unknown_status` rows | Keep the stage. Clear `status_drop_since` |

The minute follows these rules, in order:

1. It comes from the source that supplied the status, then the next source in `ORDER` showing the same stage.
2. If a reading's period equals its source's `peak_period`, a minute more than 5 below `peak_minute` counts as no minute. That's FilGoal's wrap ([R4](../research.md#r4-filgoals-minute)), not a late answer. In another period it stands: 47 in the second half is real after a first half that reached 53.
3. A minute lower than the stored one in the same period is ignored, and the stored one stays.
4. If the poll has readings but none gives a minute for the stored stage, the minute is cleared. This covers the full-time hold, `unknown_status` rows and list rows with no minute, so a frozen minute never looks current.
5. A poll with no readings at all changes nothing, and the stale check takes over.

## Full time

`finished` is held back from the table above, because polling ends with it and only a person can undo it. Each poll takes the first row that applies:

| Situation (usable readings) | What happens |
|---|---|
| Two or more readings show full time | The condition is met, even if another reading shows extra time, penalties, an `unknown_status` or `live` with no period |
| Any reading shows extra time, penalties, an `unknown_status` or `live` with no period, which may be either | A lone full time doesn't count. Clear `fulltime_source`, `fulltime_since` and `finish_wait_since`. The + 210 limit still bounds the match |
| One reading shows it, from `fulltime_source`, and `fulltime_since` is `fulltime_hold` old or more | The condition is met |
| One reading shows it, from `fulltime_source`, for less time | Keep waiting |
| One reading shows it, from another source or with nothing held | Set `fulltime_source` to it and `fulltime_since` to now. Clear `finish_wait_since` |
| `fulltime_source` read something else | Clear all three. The 10 minutes start again |
| `fulltime_source` has no reading this poll, as after a failed request | Keep waiting, with nothing cleared |

Once the condition is met:

| Situation | What happens |
|---|---|
| No drop is open and usable scores are the same | Finished, with the accepted score |
| A drop is open or usable scores differ | Set `finish_wait_since`. When they agree, or at `drop_hold`, finish on the accepted score. Alert if they still differ (B1-R1-1) |

## Sources going away

| Situation | What happens |
|---|---|
| Some sources are down or invalid | The others carry on, under the same rules |
| All enabled sources are down or invalid | Clock estimate and `both_down`, as in spec 005, unless `to_clock` refuses the row ([below](#stuck-matches-watchdog)) |
| A source doesn't cover a match | It has no opinion on it, and no disagreement arises |

## Alerts

| Key | When |
|---|---|
| `disagree:<match_id>` | Usable scores have differed for `disagree_after`, or differ when the match finishes |
| `unknown_status:<source>` | A row had an unknown status |
| `stuck:<match_id>` | A match was finished by the limit |
| `format:`, `down:`, `both_down`, `stale:` | As in spec 005 |

One alert per problem, and one on recovery.

## Stuck matches (watchdog)

```text
status = live, period = 2H, status_source = feed,
kickoff < now − LIVE_STUCK_AFTER_MIN,
score_changed_at < now − LIVE_STUCK_QUIET_MIN (or null),
no usable source has peak_minute < 90,
no usable source's reading has no period and a status of NULL or live
   → finished, keeping the score, open stuck:<match_id>
```

The last line is for extra time and penalties that no parser maps yet. Those rows come in as `unknown_status`, or as a match page saying only `live`, and `decide` keeps the stored `live`, `2H`. Such a reading says the match may still be on, so the row waits for the hard limit. An ordinary second-half reading has a period, so it doesn't hold the row.

"Usable" here means the source's `live_source_state` is `ok` or `failing`, and its `match_source_readings` row was read within `LIVE_STALE_AFTER_S`. A source with no `peak_minute` has no say.

At the hard limit (`LIVE_HARD_LIMIT_MIN`, kickoff + 210), `run_watchdog` handles a row by how far it got:

| Stored state | What happens |
|---|---|
| Second half, extra time or penalties | Finished, keeping the score, open `stuck:<match_id>` |
| Never reached the second half | `to_clock`, as in spec 005 |

Before the stuck limit, a row with no reading for `LIVE_STALE_AFTER_S` still goes to the clock, as in spec 005.

Past the stuck limit, `to_clock` refuses a row in the second half, extra time or penalties (FR-010). It takes the limit and returns `False`, so the one guard covers all three callers: the stale branch of `run_watchdog`, `apply_decision` on `decide`'s fallback, and `pause_feed_rows`. The row keeps its status and score, and no `stale:` alert opens. The stuck step finishes a second-half row, and the hard limit finishes the rest. A row that hasn't reached the second half still goes to the clock.

`peak_minute` is written in `apply`, never in `decide`, from readings whose status is `live` or `extra_time`: `90+3` counts as 93. It never goes down. `peak_period` is the period of the reading that set it, and changes only with it. FilGoal's clock counts during halftime, so that stage is left out. `decide` reads both through `LiveState`.

## Readers

Each reader gives the same `SourceReading`. A new `goal.py` adds `parse_list` and `parse_match`, with `SOURCE`, `HOST` and `LIST_PATH`. A new optional `stats` field carries Goal.com's summary. `cycle.py` reads the sources from one table: name, host, list path, parsers, page cap, enabled.

A parser gives a row with an unknown status a reading with `unknown_status` set and its score if it has one, and the cycle opens `unknown_status:<source>`. `LayoutChanged` still stops the source.

## D6's goal push bar (spec FR-019)

A goal push is due for an accepted rise when either:

- a second source has shown a score covering it; or
- 3 minutes have passed with no other source covering the match, and its source still shows it.

A rise that a usable source contradicts by showing a lower score, with no second source agreeing, doesn't push. On the replay, this delays a push by the lag between sources (median 70 s, max 7 min) or 3 minutes. D6 builds it, and `score_first_source` and `score_changed_at` are there for it.
