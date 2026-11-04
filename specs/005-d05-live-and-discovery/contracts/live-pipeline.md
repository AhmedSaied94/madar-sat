# Contract: the live pipeline

B1 builds it in `backend/app/live/`. B2 starts its worker and owns the shared adapter parts. SD §6.7 stays the source of the rules; this file fixes names and interfaces.

## Tasks

| Task | Queue | Beat | Lock | Does |
|---|---|---|---|---|
| `live.scheduler` | `live` | every 60 s | `lock:live:scheduler` | Selects matches with `live_window_query`: the 150-minute start window, plus `feed` matches with no final state up to kickoff + 210 min. None or paused: returns without any request. Otherwise queues one `live.poll` |
| `live.poll` | `live` | from the scheduler | `lock:live:poll`, `SET NX EX 90` | One cycle (below). An overlap exits |
| `live.watchdog` | `maintenance` | every 2 min | `lock:live:watchdog` | Moves stale `feed` rows, or those past kickoff + 210 min, to the clock ([R6](../research.md#r6-falling-back-staying-honest-and-the-watchdog)) |
| `live.prune_runs` | `maintenance` | daily | `lock:live:prune` | Deletes `live_poller` runs older than 30 days |
| `live.check_robots` | `live` | daily | `lock:live:robots` | Compares each `robots.txt` with the committed copy. A difference opens `robots:<host>` |
| `adapters.read_raw_page` | `maintenance` | on demand | none | Writes `rawview:<run>:<page>`. B2's ([R13](../research.md#r13-run-detail-reads-raw-pages-over-redis)) |

All use `bind=True`, `autoretry_for`, `retry_backoff`, `retry_jitter`, and a bounded `max_retries` (constitution VII). `live.poll` has `max_retries=0`, because the next cycle is its retry.

## One cycle

1. Fetch both list pages, skipping a host in backoff. Validate each. A failure updates `live_source_state`. A 429, 403 or 5xx sets `live:backoff:<host>` with exponential backoff and jitter, capped at 10 min. A list page with no matches while one is in the window is a validation failure (the zero-items alarm).
2. Parse into `SourceReading` values.
3. Link readings to matches ([R7](../research.md#r7-a-match-is-linked-only-on-both-teams-and-the-kickoff)). Unresolved names go to the queue through `record_unresolved`.
4. Pick the page slots (`pick.py`): existing slots first, then `competitions.priority`, then the earlier kickoff, up to the host's cap. Fetch them.
5. For each match, run `crosscheck.decide` and apply the result in a transaction, ending with the `live` version bump.
6. Open or close `live_problems`, send alerts after commit, write the `import_runs` row, and call `health.record_live_cycle`.

The whole cycle must finish inside 60 s. A cycle that runs out of tokens uses what it has and logs the rest as skipped.

## The pure interfaces

```python
@dataclass(frozen=True, slots=True)
class SourceReading:
    source: str; external_id: str; home: str; away: str; competition: str | None
    kickoff_at: datetime | None
    status: str | None; period: str | None; minute: str | None
    score: Score | None
    events: tuple[Event, ...] | None      # None: this page doesn't carry them
    lineups: Lineups | None

def decide(state: LiveState, filgoal: SideInput, yallakora: SideInput, now: datetime,
           *, wait: timedelta) -> Decision: ...
```

`SideInput` is `valid(reading)`, `not_covering`, or `unavailable`. `Decision` holds the status to write, the score to confirm (or none), the new candidate, the goal-event hold and the problems to open or close. Table-driven tests cover every row of SD §6.7's table, in both source orders.

**Status and minute** come from FilGoal when it's usable, otherwise YallaKora. They need no second source. A status moving backwards (for example `finished` to `live`) needs two polls in a row.

## Shared code B2 owns

| Change | File |
|---|---|
| Buckets for both hosts | `adapters/ratelimit.py` |
| `resolve_team`, `resolve_competition`, new `resolve_channel`: alias step | `adapters/resolve.py` |
| `record_unresolved(session, *, source, kind, name, competition, context)` | new `adapters/unresolved.py` |
| `live` in `HEARTBEAT_QUEUES`, a `heartbeat-live` entry, `KUMA_PUSH_URL_LIVE` | `adapters/tasks.py`, `schedule.py`, `config.py` |
| `record_live_cycle(session, *, status, items_found, finished_at)`: updates `last_success_at` and `consecutive_failures`, and never sets `breaker_opened_at` | `adapters/health.py` |
| `worker-live` started, with `RAW_ROOT` and the `/srv/raw` mount | `infra/scripts/deploy.sh`, `compose/vps2.yml` |

B2 merges these signatures to `master` as stubs in a small morning PR (T045), and B1 rebases on it before T031.

## Alerts

Sent through `app.adapters.alerts.send_alert`, in Arabic, naming the source and the saved raw page.

| Key | Sent when |
|---|---|
| `format:<source>` | Validation failed |
| `down:<source>` | `LIVE_DOWN_AFTER_FAILURES` reached |
| `both_down` | Both unusable while a match is in the window |
| `disagree:<match_id>` | Wait ended without agreement |
| `stale:<match_id>` | The watchdog moved a row |
| `robots:<host>` | A `robots.txt` changed |

Each sends once when opened and once on recovery. `send_alert` returning `False`, as when the token is unset, logs and isn't retried.

## Settings

Environment on VPS-2, defaults in code: `LIVE_PAGE_CAP_FILGOAL=8`, `LIVE_PAGE_CAP_YALLAKORA=2`, `LIVE_CONFIRM_WAIT_S=180`, `LIVE_DOWN_AFTER_FAILURES=3`, `LIVE_STALE_AFTER_S=300`, `LIVE_HARD_LIMIT_MIN=210`. The capture report sets the first, second and third values. No secret is new apart from the optional `KUMA_PUSH_URL_LIVE`.

## Off limits

The deny list in `app/live/robots.py` is checked before each request ([R4](../research.md#r4-the-robotstxt-rules-that-affect-us)). The user agent stays the existing honest `SCRAPE_USER_AGENT`. No proxies. FilGoal's commentary fields aren't read into `SourceReading`, and a test checks that no commentary text reaches any table from a captured page.
