# Data model: D5 follow-up · Live sources

One expand-only revision, `backend/alembic/versions/0008_live_sources.py`, revising `0007`. Nothing is removed, and no `/v1` schema changes. `0007` isn't edited.

## `match_live_state`: new columns

| Column | Type | Rules |
|---|---|---|
| `score_first_source` | text, null | The source that first showed the accepted score. D6 uses it for the goal-push bar (spec FR-019) |
| `score_changed_at` | timestamptz, null | When the accepted score last changed. The stuck-match check reads it |
| `drop_since` | timestamptz, null | When no usable source began to show the accepted score or higher |
| `status_drop_since` | timestamptz, null | The same for a status moving backward |

`candidate` is no longer written, and stays for rollback. `disagreement_since` keeps its meaning: when usable sources began to differ. The goal-event filter in `match_detail.py` stops depending on `candidate`, because a rise has no pending state.

## `match_events`: new column

| Column | Type | Rules |
|---|---|---|
| `missing_since` | timestamptz, null | Set when a stored event is absent from its source's reading, cleared when it returns. The row is deleted after 5 minutes, and a goal type waits until the score no longer needs it |

`side` is the side the goal counts for ([R7](research.md#r7-own-goals-and-event-sides)). No row has been written in production yet, so nothing needs correcting.

## `match_stats`: new table

| Column | Type | Rules |
|---|---|---|
| `match_id` | FK, PK with `source` | `ON DELETE CASCADE` |
| `source` | text, PK with `match_id` | Only `goal` for now |
| `stats` | jsonb | `[{type, home, away}]` from `stats.summary`. No names, no images |
| `updated_at` | timestamptz | Written only on change |

Never served to clients. Removing a source's rows is in the runbook.

## `sources`: new row

`('goal', 'internal')`, as `filgoal`. Since round 1's review (B1-R1-8), source kinds stay inside what the previous release accepts, and the code tells live sources apart by name, so `goal` joins that list and stays hidden from `GET /sources`.

## `live_source_state`

One row per source, created on first use, as today. A disabled source has no row changes. The runbook lists what that row means when the setting goes off.

## `live_problems`: new keys

| Key | Opened by | Closed by |
|---|---|---|
| `unknown_status:<source>` | A row with an unknown status | A cycle with no unknown row on that source |
| `stuck:<match_id>` | A match finished by the limit in FR-009 | The watchdog's existing past-match cleanup, with its prefix added |

`both_down` stays as the key. It now means every enabled source is down, and its Arabic text says so. `disagree:<match_id>` keeps its key under the new timing.

## Settings

| Setting | Default | Meaning |
|---|---|---|
| `LIVE_GOAL_ENABLED` | `true` | Whether Goal.com is read |
| `LIVE_PAGE_CAP_GOAL` | 4 | Match pages a cycle on Goal.com. The capture checks it |
| `LIVE_DROP_HOLD_S` | 300 | How long a lower score, an earlier status or a missing event must last |
| `LIVE_DISAGREE_AFTER_S` | 600 | Replaces `LIVE_CONFIRM_WAIT_S`, which is removed from settings, the runbook and `example.env` if listed |
| `LIVE_STUCK_AFTER_MIN` | 150 | Kickoff + this, for FR-009 |
| `LIVE_STUCK_QUIET_MIN` | 15 | No score change for this long, for FR-009 |

`LIVE_STALE_AFTER_S`, `LIVE_HARD_LIMIT_MIN`, `LIVE_DOWN_AFTER_FAILURES` and the other page caps are unchanged.
