# Data model: D3 · Follow, push and sources

Phase 1 design for [plan.md](plan.md). D1's tables ([001 data-model](../001-d01-foundation/data-model.md)) and D2's revisions `0003`–`0004` ([002 data-model](../002-d02-core-flows/data-model.md)) are the base. `devices`, `device_follows` and `notification_outbox` already exist from `0002`; D3 is their first writer.

## Revision `0005_devices_outbox_sources` (Lane B1)

Expand-only: every change is a new nullable column or one with a default, so the D2 API keeps running against it (constitution, Migrations). The owner reviews it before merge.

| Table | Change | Rule | Why |
| --- | --- | --- | --- |
| `devices` | `satellite_ids bigint[] NOT NULL DEFAULT '{}'` | `ck_devices_satellite_ids`: `cardinality(satellite_ids) <= 32` | Words reminders for the device's dish ([R3](research.md#r3-my-satellites-on-the-server)). Not a foreign key (arrays can't be); the API checks ids on write, and the dispatcher ignores ids that no longer exist |
| `notification_outbox` | `claimed_at timestamptz` | | Reclaims rows stuck in `sending` ([R7](research.md#r7-the-dispatcher)) |
| `notification_outbox` | `cursor_device_id bigint NOT NULL DEFAULT 0` | | Resumes a partly sent row without re-sending ([R7](research.md#r7-the-dispatcher)) |
| `notification_outbox` | index `notification_outbox_sending_idx ON (claimed_at) WHERE status = 'sending'` | | The reclaim query |
| `sources` | `consecutive_failures integer NOT NULL DEFAULT 0` | `>= 0` | Circuit breaker ([R17](research.md#r17-source-health-breaker-and-zero-items-alarm)) |
| `sources` | `breaker_opened_at timestamptz` | | Non-NULL = open = paused until resumed |
| `sources` | `last_success_at timestamptz` | | A13 cards and A2 tiles |
| `sources` | `last_zero_alert_on date` | | Zero-items alarm at most once per source per Cairo day |
| `import_runs` | `log jsonb` | ≤ 64 KB, written by ingest | A13's run detail on VPS-1, which can't read VPS-2's `run.json` ([contracts/admin-api.md](contracts/admin-api.md#sources-a13)) |
| `channels` | `placeholder_source text REFERENCES sources(name)` | | Marks an importer-created placeholder ([R18](research.md#r18-placeholder-channels)) |
| `channels` | index `channels_placeholder_idx ON (placeholder_source) WHERE placeholder_source IS NOT NULL` | | A8's filter and A2's count |

Downgrade drops the added columns and indexes. No data migration: existing rows get the defaults. `device_follows` already has one partial index per target column from `0002`, which the audience query uses.

## Entities and rules

### Device

| Field | Source | Rule |
| --- | --- | --- |
| `install_id` | app | UUIDv4, unique; re-registering rotates the token ([R1](research.md#r1-device-registration-and-the-token)) |
| `token_hash` | server | `sha256(token)` hex; the token itself is never stored or logged |
| `platform` | app | `android` \| `ios` \| `web` (an iPhone PWA registers as `web`, a future native iOS app as `ios`) |
| `push_token` | app | ≤ 4096 characters, unique: a token arriving for another device moves (the old device's is set NULL); set NULL on `UNREGISTERED` |
| `app_version` | app | ≤ 32 |
| `locale` | app | ≤ 16, BCP 47 |
| `tz` | app | ≤ 64, a valid IANA name (checked with `zoneinfo`) |
| `satellite_ids` | app | ≤ 32 existing satellite ids, de-duplicated |
| `prefs` | app | `NotificationPrefs` ([R4](research.md#r4-notification-preferences)); unknown types refused |
| `last_seen_at` | server | refreshed at most hourly |

`DELETE /v1/devices/me` deletes the row; `device_follows` cascades. Outbox rows hold no device ids, so nothing else references a device.

### Follow set

- One row per target in `device_follows`, exactly one target column set (D1 check), unique per device and target.
- Replaced whole in one transaction under a device row lock ([R5](research.md#r5-replacing-the-follow-set)); ≤ 500 rows per device.
- Deleting a team, competition, channel or commentator cascades its follows; matches are never deleted.

### Outbox row lifecycle

```text
          scheduler upsert (due_at moves while pending)
pending ──────────────────────────────────────────────► pending
   │  dispatcher claim (FOR UPDATE SKIP LOCKED)
   ▼
sending ── stuck > 10 min ──► pending   (cursor_device_id kept)
   │  every audience page sent and recorded
   ├──────────────────────────► sent      (sent_at set)
   │  retries exhausted
   ├──────────────────────────► failed
pending/sending ── match tbd / postponed / cancelled / kickoff > 24 h ──► cancelled
```

- `kickoff_reminder` rows: `dedupe_key = kickoff_reminder:<match_id>`, `payload = {match_id, kickoff_at}`, `audience = {kind: "match_followers", match_id}`.
- A `sent`, `failed` or `cancelled` row is never changed by the scheduler (`ON CONFLICT … WHERE status = 'pending'`), so a moved kickoff can't produce a second reminder.
- Rows are kept 30 days for A15 (D6), then pruned by a maintenance task (B1, `notifications.prune_outbox`, daily).

### Source health

| Field | Written by | Read by |
| --- | --- | --- |
| `is_enabled` | A13 pause / resume (B1 admin API) | `schedule_fetch`, ingest |
| `consecutive_failures`, `breaker_opened_at`, `last_success_at`, `last_zero_alert_on` | `app/adapters/health.py` after every run (B2) | A13, A2, `schedule_fetch` |

- Paused = `is_enabled = false` OR `breaker_opened_at IS NOT NULL` OR `paused_until > now()` (D2's column, kept).
- Resume: `is_enabled = true`, `breaker_opened_at = NULL`, `consecutive_failures = 0`, `paused_until = NULL`, audited, then one manual run queued.
- Every health write (a finished run, a pause, a resume) bumps the `sources` dataset, which the admin sources `ETag`s are built from.
- Error rate (A13) = failed runs ÷ runs over the last 24 h, from `import_runs`.

### Placeholder channel

- `kind = 'platform'`, `satellite_id`, frequency fields, `beam` and `frequency_note` NULL (D1's `ck_channels_kind_fields` holds), `show_in_match = false`, `placeholder_source = 'livesoccertv'`, `country` = the listing country (normalized), `name` = the listed name.
- Unique by D1's `channels_platform_key (name_norm, country)`; the adapter also checks soft-deleted rows so a rejected name is never recreated.
- Hidden from every public read ([R13](research.md#r13-placeholders-in-the-public-api)).
- Becomes a normal channel when an editor saves it with `show_in_match = true` (`placeholder_source` cleared in the same write, audited). An editor may first move it to `kind = 'satellite'` with a satellite and frequency.

### LiveSoccerTV links

- `match_channels` rows with `source = 'livesoccertv'` and `imported_by = 'livesoccertv'` (D2 `0003`).
- The adapter adds and removes only rows where `source = 'livesoccertv'`. An editor's edit or removal makes the row `manual` (D2 FR-008), which the adapter never touches again.

## Redis keys (new)

| Key | Owner | TTL | Use |
| --- | --- | --- | --- |
| `rc:<etag>` | B1 | route TTL (SD §6.3.2) | Response cache ([R10](research.md#r10-the-response-cache)) |
| `dv:<token_hash>` | B1 | 10 min valid / 60 s invalid | Whether a token belongs to a live device, for the rate limiter; deleted on rotate and delete ([R11](research.md#r11-rate-limits-on-v1)) |
| `rl:d:<token_hash[:16]>:<minute>` | B1 | 2 min | Per-device window, only for a checked token |
| `rl:ip:<ip>:<minute>` | B1 | 2 min | Per-IP window |
| `rl:reg:<ip>:<10-min slot>` | B1 | 20 min | `POST /v1/devices` |
| `lock:fetch:livesoccertv`, `lock:ingest:livesoccertv` | B2 | D2's TTLs | Job locks, as ysscores |
| `lock:notifications:schedule` | B1 | 4 min | One scheduler at a time |

The home box's Redis ACL (D2) is unchanged: it never sees these keys.

## Drift (app, schema v3) (Lane M)

| Table | Columns | Use |
| --- | --- | --- |
| `app_settings` | `key text PK`, `value text`, `updated_at` | Onboarding step and done flag, theme, time zone, 12/24 h, font scale, my satellites (JSON id list) ([R27](research.md#r27-onboarding-state-device-registration-and-follow-sync)) |
| `follows` | `kind text`, `target_id int`, `created_at`; PK (`kind`, `target_id`) | The device's follow set, the source of truth (P1) |
| `sync_state` | `key text PK` (`follows`, `device`), `dirty bool`, `last_error text`, `attempted_at` | Retry on launch, resume and reconnect |

The device token and install id are in `flutter_secure_storage`, never in drift. Migration v2 → v3 adds the three tables; D2's tables are untouched.
