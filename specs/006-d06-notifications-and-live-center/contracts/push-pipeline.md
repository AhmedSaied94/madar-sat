# Contract: the push pipeline

Lane B1 owns everything here, except that Lane B2 calls [`report_link_change`](#the-call-importers-make) from `backend/app/adapters/`. Why each rule exists is in [research.md](../research.md).

## Modules

| Module | Holds | Pure? |
|---|---|---|
| `app/notifications/goal_bar.py` | The goal bar: memory + readings + now → new memory + messages due | Yes |
| `app/notifications/policy.py` | Per-type lateness and audience defaults | Yes |
| `app/notifications/messages.py` | Copy for every type | Yes |
| `app/notifications/producers.py` | Decides and inserts rows: match start, goal, correction, final score, frequency | No |
| `app/notifications/channel_changes.py` | `report_link_change`, sync and async | No |
| `app/notifications/dispatcher.py` | Claims, audiences, sends, cancels | No |

Only `sender.py` talks to FCM (constitution VII).

## The goal bar

`evaluate(memory, accepted, readings, now, held_for) → (memory, messages)`. `held_for` is 3 minutes.

1. No accepted score: send nothing.
2. Empty memory: store the accepted score as the baseline, with generation 0, and send nothing (FR-002).
3. Accepted below what was pushed on either side: the [correction](#corrections) runs first, and the rest goes on from the corrected score. This holds under a manual status or locked score too.
4. A manual status or locked score: send no goal, and move `home` and `away` in memory to the accepted score.
5. Readings with a score, per side. `bar` starts at `pushed` and never falls below it:
   - 2 or more: `bar = max(pushed, min(second highest, accepted))`, and held memory is cleared;
   - exactly 1: the lowest value above `pushed` shown without a break for `held_for`, if there is one. A value at or below `pushed` clears that side's hold;
   - none: held memory is cleared, and nothing passes.
6. Each side whose `bar` is above `pushed` adds one message. All messages carry `(bar.home, bar.away)`, and `pushed` becomes that score.

**Why the floor.** With 2–0 pushed and sources at 2–1 and 1–1, home's second-highest value is 1. Without the floor the next push would say 1–1 and `pushed` would fall, while a falling score is the correction's job. The capture has no such case, so the replay gives the same totals with or without it, and only `evaluate`'s table test can catch its loss.

The replay test runs the 2026-11-04 capture through `decide` and `evaluate`, with these pinned:

| Match | Must happen |
|---|---|
| Whole capture | 58 goal messages, 0 corrections |
| Mouloudia Alger (FilGoal only) | One message, `1–0`, at +240 s. No `2–0` |
| Porto v Napoli | 2–1, 3–1 and 4–1 as separate messages |

## Rows and when they appear

| Row | Produced from | Condition | `due_at` | Audience |
|---|---|---|---|---|
| `match_started` | `_apply_match`, after `apply_decision` | Status becomes live, `status_source = feed`, within 15 min of kickoff | now | `match_core` |
| `goal` | Same | The bar passes | now | `match_core` |
| correction | Same, and admin `matches.update` | [Corrections](#corrections) | now | `match_core` |
| `final_score` | `_apply_match`, admin `matches.update` | Status becomes `finished` from the feed with a real score, or an editor sets `finished` with one, including over a finish at the limit. Never from watchdog `_finish` (FR-007) | now | `match_core` |
| `channels_updated` | `report_link_change` | [Channel changes](#channel-changes) | first change + 5 min | `match_followers`, or `match_only` for a first channel |
| `frequency_changed` | A8's save | [Frequency changes](#frequency-changes) | first save + 5 min | `channel` |
| `announcement` | Composer | | now or `send_at` | as chosen |
| test | Test send | Type `announcement`, `audience.kind = device` | now | `device` |

Every row is inserted in the transaction of the change behind it, with `ON CONFLICT (dedupe_key) DO NOTHING`. Keys are in [research R4](../research.md#r4-dedupe-keys). After commit, a poll that wrote a row calls `Deps.kick_dispatch`, which queues `dispatch_due` on `notifications`. Admin saves due now do the same.

**The poller's producers run in `session.begin_nested()`.** An error rolls back only the push rows and `push_memory`, and is logged as an error, while the score commits (FR-008). The next poll tries again. A test makes `evaluate` raise and asserts the score was saved and the next poll sends the message.

`match_started` reads `push_memory.live_seen`: false with an in-play status means it's due, and the row sets it. The first evaluation of a match already in play sets it and sends nothing.

Shootout kicks send nothing: the goal bar judges only `home` and `away`, never the shootout's own count, and doesn't run while `status` is `penalties`. `final_score` reads the shootout from the stored score. "In play" for `live_seen` means `live`, `halftime`, `extra_time` or `penalties`.

## Corrections

When accepted falls below `pushed` on either side:

1. If a `goal` or `final_score` row of this generation has `status = sent`, insert `goal_correction:<match>:<generation>`.
2. Generation + 1, and `pushed` becomes the accepted score.

Producing the correction doesn't change any other row.

**An editor's save.** `apply_status` is sync with no session, so the check runs in `matches.update`, through `save_update`'s `then` (below), under the match's row lock, which the poller takes too. When `body.status` was sent and the match has a `match_live_state` row:

- A score below `pushed` on either side, live or finished: steps 1 and 2.
- Any other score: `pushed` moves to it, and nothing is sent.
- A save with no score, or a cleared manual status: nothing changes.

No state row means nothing was pushed, so there's nothing to correct. An editor's `finished` with a score adds `final_score` here too, and the key makes it once.

## Channel changes

`report_link_change(session, match_id, channel_id, action, source, now)` runs in the caller's transaction:

1. Skip if the match has no known kickoff or is in a final state.
2. Inside the window (kickoff − 6 h to a final state): insert into `match_channel_changes` with `ON CONFLICT DO NOTHING`. If nothing was inserted, stop. If no row is pending for the match, insert one with key `channels_updated:<match>:<first change id>` and audience `match_followers`.
3. Before the window: only if `action = added` and the match had no visible link before this one. Audience `match_only`, `payload.first_channels = true`. Otherwise stop.

At first dispatch, in one transaction:

1. Read unannounced changes, and net them: an `added` link that's visible now, and a `removed` link that isn't.
2. Store `added` and `removed` on the payload, and set `announced_at`.
3. Neither list: cancel with `no_net_change`.

Visible means the dispatcher's existing `_VISIBLE_LINKS` rule. A retry reads the stored lists, so it sends the same message.

### The call importers make

```python
from app.notifications.channel_changes import report_link_change
report_link_change(session, match_id, channel_id, "added", source="legacy", now=now)
```

Lane B2 calls it from `upsert._apply` after `_reconcile_links`, and from `livesoccertv_links.apply_broadcasts` for each link added or removed. It takes a sync `Session`, doesn't commit, and never talks to FCM. A4's `reconcile_links` uses the async twin, including when `is_hidden` changes.

## Frequency changes

The one compare is `frequency_diff(old, new)` in `producers.py`: both sides complete (`frequency_mhz`, `polarization` and `symbol_rate` all set), and at least one differs. `channels.update` is the only live caller. `channels.create` isn't one, since a new channel has no old values and no followers. Note-only, empty and snapshot-loader values never count.

At save: `channels.update` already holds the old values in `before = versions.row_state(channel)`, and calls the producer through `save_update`'s `then`, because the key needs the audit row's ID. `_set_frequency` stays as it is, a sync helper with no session that also runs on create. If the diff is real and no row is pending for the channel, insert one with `payload.old`, keyed on the save's audit row, with `audit_log_id` set.

**What the writer gives.** `save_update` returns `bool` and `bulk.py:90` ORs it, so its return stays. `add_audit` now returns the `AuditLog` it added. `save_update` gains `then: Callable[[AuditLog], Awaitable[None]] | None`, awaited after the audit row is flushed and before the bump, so the bump stays last and `then` doesn't run when nothing changed.

When due:

1. Current equal to `old`, or incomplete: cancel with `no_net_change`.
2. Otherwise, in one transaction: write `channel_frequency_changes` (`ON CONFLICT (outbox_id) DO NOTHING`), with `audit_log_id` copied from the outbox row, set `frequency_changed_at`, bump `writer.CHANNEL_CHANGED` as A8's save does, then send.
3. `frequency_changed_at` joins `NOT_HASHED` in `versions.py`, as `MATCH_CLOCK_COLUMNS` does for matches, so a hold ending doesn't make an open A8 stale.

The off switch skips only the send: step 2's history is still written, then the row is cancelled with `type_off`.

## Dispatch

`dispatch_due` keeps its Redis lock and adds, in a loop until nothing is due or 50 s have passed:

```sql
SELECT id FROM notification_outbox
 WHERE status = 'pending' AND due_at <= :now
 ORDER BY CASE WHEN type IN ('goal', 'match_started', 'final_score') THEN 0 ELSE 1 END, due_at, id
 LIMIT 1
 FOR UPDATE SKIP LOCKED
```

- A claimed row sends up to 20 pages (10,000 devices), then returns to `pending`, keeping `cursor_device_id`.
- A retryable failure ends the run, as it does today.
- Work left when the run ends queues the task again.
- Stuck-row reclaim, `MAX_ATTEMPTS` and tokens FCM rejects are unchanged.
- The existing `sent` and `failed` counters carry across turns.

**The failure reason.** A row that ends `failed` keeps a short reason in `error`, read by `sender.py` from FCM's failure: `FCM <http status>`, or `FCM <code>` when there's none. `SendOutcome` gains `last_error: str | None = None`, so existing fakes keep working. A new `PushRetryable(Retryable)` carries `reason` from `sender.py:127` and `dispatcher.py:269`, and `_MARK_FAILED` gains `error`. It never holds a token or `repr(exc)`.

Before the first page, in this order: `PUSH_TYPES_OFF`, then `policy.decide`.

### Lateness (FR-019)

| Type | Cancelled when | `error` |
|---|---|---|
| `goal` | older than 15 min, or the match finished | `late`, `match_finished` |
| `goal` | the side's current score is below the row's | `score_fell` |
| `match_started` | older than 15 min, or the match finished | `late`, `match_finished` |
| `final_score`, correction | older than 2 h | `late` |
| `channels_updated` | the match finished | `match_finished` |
| `announcement` | scheduled, and over 2 h late | `late` |
| `kickoff_reminder` | today's rule, unchanged | `late` |

"Older" counts from `due_at`. A test send never goes late.

### Audiences

Three fixed queries, chosen by `audience.kind`. Parameters a kind doesn't use are NULL, and the follow query's `=` and `IN` are false for them. The reach count wraps the same text in `COUNT(*)`. `AUDIENCE_*` replace the existing `AUDIENCE`, and existing reminder rows keep their meaning.

```sql
-- AUDIENCE: every kind with follows
SELECT DISTINCT d.id, d.push_token, d.satellite_ids, d.prefs
  FROM devices d
  JOIN device_follows f ON f.device_id = d.id
 WHERE d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
   AND d.id > :cursor
   AND (f.match_id = CAST(:match_id AS bigint)
        OR f.competition_id = CAST(:competition_id AS bigint)
        OR f.team_id IN (CAST(:home_team_id AS bigint), CAST(:away_team_id AS bigint))
        OR f.channel_id = CAST(:channel_id AS bigint))
   AND COALESCE((d.prefs ->> 'enabled')::boolean, true)
   AND COALESCE((d.prefs -> 'types' -> CAST(:type AS text) ->> 'on')::boolean, :default_on)
 ORDER BY d.id
 LIMIT :limit

-- AUDIENCE_ALL: no follows, so nothing to de-duplicate
SELECT d.id, d.push_token, d.satellite_ids, d.prefs
  FROM devices d
 WHERE d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
   AND d.id > :cursor
   AND COALESCE((d.prefs ->> 'enabled')::boolean, true)
   AND COALESCE((d.prefs -> 'types' -> CAST(:type AS text) ->> 'on')::boolean, :default_on)
 ORDER BY d.id
 LIMIT :limit

-- AUDIENCE_DEVICE: a test send, whatever its prefs
SELECT d.id, d.push_token, d.satellite_ids, d.prefs
  FROM devices d
 WHERE d.id = :device_id
   AND d.id > :cursor
   AND d.push_token IS NOT NULL
   AND btrim(d.push_token) <> ''
```

| `kind` | Parameters set |
|---|---|
| `match_followers` | `match_id`, `competition_id`, `home_team_id`, `away_team_id` |
| `match_core` | `match_id`, `home_team_id`, `away_team_id` |
| `match_only` | `match_id` |
| `channel` | `channel_id` |
| `team` | `home_team_id` |
| `competition` | `competition_id` |

Defaults: `match_started` off, every other type on. A correction reads the `goal` switch.

## Copy

Every name, score digit, minute and readout is wrapped by `isolate()`. A score is never one isolated string, because each score must sit beside its team in an RTL line, so the parts are:

```text
⁨home⁩ ⁨1⁩ – ⁨0⁩ ⁨away⁩
```

| Type | Title | Body |
|---|---|---|
| `match_started` | بدأت المباراة | ‹home› × ‹away› |
| `goal` | هدف لـ ‹team›! | score, then ` · ‹player› 23′` when known |
| `goal`, own goal | هدف لـ ‹team›! | score · ‹player› عكسي 23′ |
| correction | تصحيح النتيجة | score |
| `final_score` | انتهت المباراة | score |
| `final_score`, shootout | انتهت المباراة | score · بركلات الترجيح 4 – 3 |
| `channels_updated`, one added | قنوات جديدة لمباراة ‹home› × ‹away› | أُضيفت ‹channel› على ‹satellite› |
| `channels_updated`, several added | Same | أُضيفت ‹channel› على ‹satellite› و‹3› غيرها |
| `channels_updated`, removed only | تغيّرت قنوات مباراة ‹home› × ‹away› | لم تعد ‹channel› تنقل المباراة |
| `frequency_changed` | تغيّر تردد ‹channel› | على ‹satellite›: ‹11843 H 27500› (كان ‹11766 H 27500›) |
| `announcement`, test | Admin text | Admin text |

- **Scorer.** Only when the count of goal-type events on that side equals the side's score in the row, taking the last by minute. An event's `side` is the credited team.
- **Channel named.** `choose_channel` as for the reminder: the device's satellites, then Nilesat and Badr, then any, free first.
- **A channel with no satellite.** Drop «على ‹satellite›», as the reminder does.

## FCM fields

| Type | `data.type` | `data.route` | Tag |
|---|---|---|---|
| Match types | the type | `/match/<id>` | `match_<id>` |
| `channels_updated` | `channels_updated` | `/match/<id>?section=channels` | `match_<id>` |
| `frequency_changed` | `frequency_changed` | `/channel/<id>` | `channel_<id>` |
| `announcement` | `announcement` | the server-built route | `announcement_<row id>` |

The Android channel stays `reminders` for every type: a new channel needs a client release, and old builds would drop to a fallback channel. `data.*` values are strings.

## Off switch

`PUSH_TYPES_OFF=goal,match_started` in VPS-2's `.env`, then `docker compose ... up -d worker-notify`. `kickoff_reminder` can be listed too. An unknown name logs an error and is ignored. Runbook: `push-notifications.md`.

## Failure alert

In `dispatch_row`, after a row finishes. Problem key `push`, through `live/problems.py`:

- **Opens:** a row ends `failed`, or a finished row with `sent + failed ≥ 10` has `failed / (sent + failed) > 0.20`.
- **Closes:** the next finished row under that rate, on the same size rule.
- **Ignored:** `audience.kind = device`, and cancelled rows.

The copy goes in `_OPENED` and `_CLOSED`. The alert is sent after commit.
