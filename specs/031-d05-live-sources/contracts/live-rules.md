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
) -> Decision: ...
```

`SideInput` keeps `valid`, `not_covering` and `unavailable`. A disabled source has no entry.

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

## Status and minute

| Situation | What happens |
|---|---|
| Any usable reading is `finished`, no drop is open and usable scores are the same | Finished, with the accepted score |
| Any usable reading is `finished`, with a drop open or scores differing | Wait until they agree or `drop_hold` passes, then finish on the accepted score. Alert if they still differ (B1-R1-1) |
| The first usable source in `ORDER` has a later or equal status | Write it. Clear `status_drop_since` |
| All usable readings show an earlier status | Set `status_drop_since`, keep the status. At `drop_hold`, write the first one |
| A stored status is `finished` | The match has left the window, and only a person changes it |
| `cancelled`, `abandoned`, `postponed` | Only from the first usable source, as in spec 005. A postponed match stays as stored, unpolled |

The minute comes from the status source, then the next source in `ORDER` in the same period. It doesn't move backward inside a period.

## Sources going away

| Situation | What happens |
|---|---|
| Some sources are down or invalid | The others carry on, under the same rules |
| All enabled sources are down or invalid | Clock estimate and `both_down`, as in spec 005 |
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
score_changed_at < now − LIVE_STUCK_QUIET_MIN (or null)
   → finished, keeping the score, open stuck:<match_id>
```

The hard-limit case in `run_watchdog` keeps `to_clock` only for a row that never reached the second half. A row with no reading for `LIVE_STALE_AFTER_S` before the stuck limit still goes to the clock, as in spec 005.

## Readers

Each reader gives the same `SourceReading`. A new `goal.py` adds `parse_list` and `parse_match`, with `SOURCE`, `HOST` and `LIST_PATH`. A new optional `stats` field carries Goal.com's summary. `cycle.py` reads the sources from one table: name, host, list path, parsers, page cap, enabled.

A row with an unknown status raises `UnknownStatus`, and its list parser records it and goes on. `LayoutChanged` still stops the source.

## D6's goal push bar (spec FR-019)

A goal push is due for an accepted rise when either:

- a second source has shown a score covering it; or
- 3 minutes have passed with no other source covering the match, and its source still shows it.

A rise that a usable source contradicts by showing a lower score, with no second source agreeing, doesn't push. On the replay, this delays a push by the lag between sources (median 70 s, max 7 min) or 3 minutes. D6 builds it, and `score_first_source` and `score_changed_at` are there for it.
