# Data model: D6 · Notifications and live center

One expand-only revision, `0009_notifications_and_accounts` (Lane B1), with a tested downgrade. The release before it keeps running against it, except where [Rollback](#rollback) says otherwise. Why each piece exists is in [research.md](research.md).

## New tables

### `channel_frequency_changes`

What followers of a carriage were told. Written when a hold ends, not at save (R6).

| Column | Type | Notes |
|---|---|---|
| `id` | `bigint` PK | |
| `channel_id` | `bigint` NOT NULL | FK `channels`, `ON DELETE CASCADE` |
| `old_frequency_mhz`, `new_frequency_mhz` | `integer` NOT NULL | Same range as `channels.frequency_mhz` |
| `old_polarization`, `new_polarization` | `varchar(1)` NOT NULL | H, V, L or R |
| `old_symbol_rate`, `new_symbol_rate` | `integer` NOT NULL | Same range as `channels.symbol_rate` |
| `source` | `text` NOT NULL | `admin`, or an importer's name |
| `outbox_id` | `bigint` UNIQUE | FK `notification_outbox`, `ON DELETE SET NULL`. Stops a retry writing twice |
| `audit_log_id` | `bigint` | FK `audit_log`, `ON DELETE SET NULL`. Copied from the outbox row, so A8 still names the editor after `prune_outbox` removes that row at 30 days. NULL for an importer |
| `detected_at` | `timestamptz` NOT NULL | The end of the hold |

Index: `(channel_id, detected_at DESC)`. S6 reads the last 5 and A8 reads all, newest first.

### `match_channel_changes`

Append-only record of links fans could see being added or removed (R5).

| Column | Type | Notes |
|---|---|---|
| `id` | `bigint` PK | |
| `match_id` | `bigint` NOT NULL | FK `matches`, `ON DELETE CASCADE` |
| `channel_id` | `bigint` NOT NULL | FK `channels`, `ON DELETE CASCADE` |
| `action` | `text` NOT NULL | CHECK `added` or `removed` |
| `source` | `text` NOT NULL | `admin`, or an importer's name |
| `created_at` | `timestamptz` NOT NULL | |
| `announced_at` | `timestamptz` | Set when a push took it, or when netting removed it |

Unique: `(match_id, channel_id, action)`, which gives one push per direction, per channel, per match. Partial index on `match_id` where `announced_at IS NULL`. Announced rows older than 30 days go with `prune_outbox`.

## Changed tables

| Table | Change | Why |
|---|---|---|
| `notification_outbox` | `error text` | The reason a row failed or was cancelled (R9). Short: `FCM 503`, `late`, `type_off` |
| `notification_outbox` | `audit_log_id bigint`, FK `audit_log`, `ON DELETE SET NULL` | Links a push to the save behind it, for A17 (R20) |
| `match_live_state` | `push_memory jsonb NOT NULL DEFAULT '{}'` | What the goal bar remembers (R2) |
| `admin_users` | `must_change_password boolean NOT NULL DEFAULT false` | Forces a change after a temporary password (R19) |
| `admin_users` | `test_device_id bigint`, FK `devices`, `ON DELETE SET NULL` | "My test device" for test sends |
| `matches` | `ck_matches_locked_fields` gains `broadcasts` | Protects an editor's broadcaster entries from importers (R23) |
| `import_runs` | status CHECK gains `stopped` | A run that stopped on purpose (R22) |

## Seeds

- `dataset_versions`: `outbox`, `admin_users`. `ck_dataset_versions_name` is dropped and re-added to allow them, as `0007` does, and the downgrade removes them first.
- `sources`: nothing. `sporteventz` and `api_football` are in `0001`. Their rate-limit buckets and settings are Lane B2's.

## JSON shapes

### `devices.prefs`

Additive. `enabled` absent means on. A type absent means its SD §6.8 default.

```json
{ "enabled": true, "types": { "goal": { "on": false }, "match_started": { "on": true } } }
```

`NotificationPrefs.with_defaults` reads `enabled` separately. Today it treats a document with no `types` key as if the document were the types, where `enabled` would be ignored as an unknown type. A test covers that.

### `match_live_state.push_memory`

Read and written only by the goal bar's pure function. `{}` means no baseline yet.

```json
{ "home": 1, "away": 0, "generation": 0, "live_seen": true,
  "held": { "away": { "value": 1, "since": "2026-11-04T19:37:00+00:00" } } }
```

### `notification_outbox.audience`

| `kind` | Other fields | Receives |
|---|---|---|
| `match_followers` | `match_id` | Match, team or competition follows (reminders, `channels_updated`) |
| `match_core` | `match_id` | Match or team follows (`match_started`, `goal`, `final_score`, a match announcement) |
| `match_only` | `match_id` | Follows of that match only (a first channel outside the window) |
| `channel` | `channel_id` | Follows of that channel |
| `team` | `team_id` | Follows of that team |
| `competition` | `competition_id` | Follows of that competition |
| `all` | | Every device with a token and the type on |
| `device` | `device_id` | One device, prefs ignored: a test send |

`kind = device` is how a row is marked as a test, so no column is added.

### `notification_outbox.payload`

| Type | Fields |
|---|---|
| `match_started`, `final_score` | `match_id` |
| `goal` | `match_id`, `side`, `home`, `away`, `generation` |
| correction (type `goal`) | `match_id`, `kind: "correction"`, `home`, `away`, `generation` |
| `channels_updated` | `match_id`, then `added` and `removed` channel IDs, stored at dispatch |
| `frequency_changed` | `channel_id`, `old: {mhz, pol, sr}` |
| `announcement` | `title`, `body`, `route` |

## State transitions

Outbox rows keep their existing states.

```text
pending ──claimed──▶ sending ──all pages──▶ sent
   ▲                    │ ├── page budget used ──▶ pending (keeps cursor)
   │                    │ ├── retryable, attempts left ──▶ pending
   │                    │ └── attempts exhausted ──▶ failed (error set)
   └────────────────────┘
pending or sending ──policy says no──▶ cancelled (error set)
pending announcement ──admin cancels──▶ cancelled (error = "admin")
```

`match_channel_changes.announced_at` and the `payload` lists are set in the same transaction as the row's first claim, so a retry sends the same message.

## Rollback

`locked_fields` gaining `broadcasts` and `import_runs.status` gaining `stopped` are the only new values an older release can read. Both schemas are plain strings or a Literal that only the admin reads: `locked_fields` is `list[str]`, and `ImportRunRow.status` needs `stopped` added. After a rollback, a run row with `stopped` would fail that response's validation in the old release. So the downgrade rewrites `stopped` runs to `failed`, strips `broadcasts` from every array, and then restores both CHECKs. Runbook: `database-migrations.md`.
