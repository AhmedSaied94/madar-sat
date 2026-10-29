# Data Model: D1 · Foundation

Phase 1 of [plan.md](plan.md).

- **`0001`** is `../old_app/migration/schema.sql` unchanged (FR-001). It isn't repeated here; read the file for every base table, constraint and trigger.
- **`0002`** is defined below (FR-002). It follows the base file's conventions:
  - CHECK constraints are named `ck_<table>_<rule>`;
  - other constraints keep PostgreSQL's default names;
  - `updated_at` is maintained by `set_updated_at`.
- **Read models** are at the end. The API shapes are in [contracts/public-api-v1.md](contracts/public-api-v1.md).

## Revision `0002`: MVP additions

Run on PostgreSQL 16 through psycopg. Every statement is additive (expand only). `matches.is_live` stays until the status backfill is proven (expand/contract).

### `matches`: status and protection

| Column | Type | Rule |
| --- | --- | --- |
| `status` | `text NOT NULL DEFAULT 'scheduled'` | `ck_matches_status`: `scheduled`, `live`, `halftime`, `extra_time`, `penalties`, `finished`, `postponed`, `cancelled`, `abandoned` |
| `period` | `text` | `ck_matches_period`: `1H`, `2H`, `ET1`, `ET2`, or NULL |
| `minute` | `text` | `ck_matches_minute`: `^\d{1,3}(\+\d{1,2})?$` (`"45+2"`) |
| `home_score`, `away_score` | `smallint` | `≥ 0` |
| `home_pen`, `away_pen` | `smallint` | `≥ 0` |
| `status_source` | `text NOT NULL DEFAULT 'clock'` | `ck_matches_status_source`: `feed`, `manual`, `clock` |
| `status_label` | `text` | ≤ 120 characters (a source's reason for an unusual state) |
| `status_updated_at` | `timestamptz` | |
| `time_tbd` | `boolean NOT NULL DEFAULT false` | `ck_matches_time_tbd`: `time_tbd = (kickoff_at IS NULL)` |
| `locked_fields` | `text[] NOT NULL DEFAULT '{}'` | `ck_matches_locked_fields`: `locked_fields <@` the lockable columns below |

These CHECK constraints enforce the honest-data rules (constitution II):

- `ck_matches_clock_no_score`: when `status_source = 'clock'`, then `status = 'scheduled'` and `home_score`, `away_score`, `home_pen`, `away_pen`, `minute` and `period` are all NULL. Clock rows never store a derived state or a score; the read path derives the state ([research R3](research.md#r3-clock-status-and-the-estimated-flag)).
- `ck_matches_scores_pair`: `(home_score IS NULL) = (away_score IS NULL)` and `(home_pen IS NULL) = (away_pen IS NULL)`.

**Lockable match columns:** `kickoff_at`, `competition_id`, `competition_name`, `competition_stage`, `home_team_id`, `home_team_name`, `home_logo_asset_id`, `away_team_id`, `away_team_name`, `away_logo_asset_id`, `stadium`, `commentator_id`, `status`, `home_score`, `away_score`, `home_pen`, `away_pen`.

New index: `matches_live_window_idx ON matches (kickoff_at) WHERE status NOT IN ('finished', 'cancelled', 'abandoned')`, used by `/v1/live` and later by the live scheduler.

### `channels`

| Column | Type | Rule |
| --- | --- | --- |
| `locked_fields` | `text[] NOT NULL DEFAULT '{}'` | `ck_channels_locked_fields`: subset of `name`, `display_name`, `logo_asset_id`, `category`, `country`, `satellite_id`, `frequency_mhz`, `polarization`, `symbol_rate`, `frequency_note`, `access`, `provider`, `package`, `beam`, `show_in_match`, `sort_order` |
| `frequency_changed_at` | `timestamptz` | Set when the tuning changes (D6 writes it; NULL from the snapshot) |

### Search indexes

`CREATE EXTENSION IF NOT EXISTS pg_trgm`, then a GIN `(name_norm gin_trgm_ops)` index on `teams`, `competitions`, `channels` and `commentators`. The existing b-tree `name_norm` indexes stay, for equality lookups.

### `admin_users`

| Column | Type | Rule |
| --- | --- | --- |
| `id` | `bigint` identity PK | |
| `email` | `text NOT NULL` | unique on `lower(email)`; ≤ 254 characters |
| `name` | `text NOT NULL` | ≤ 80 characters |
| `role` | `text NOT NULL` | `ck_admin_users_role`: `editor`, `admin` |
| `password_hash` | `text NOT NULL` | argon2id encoded string (D2 writes it) |
| `is_active` | `boolean NOT NULL DEFAULT true` | |
| `last_login_at` | `timestamptz` | |
| `created_at`, `updated_at` | `timestamptz NOT NULL DEFAULT now()` | `set_updated_at` trigger |

Login attempt counters and lockouts live in Redis (D2), not in this table.

### `admin_refresh_tokens`

| Column | Type | Rule |
| --- | --- | --- |
| `id` | `bigint` identity PK | |
| `admin_user_id` | `bigint NOT NULL` → `admin_users ON DELETE CASCADE` | indexed |
| `token_hash` | `char(64) NOT NULL UNIQUE` | SHA-256 of the opaque token; the token itself is never stored |
| `family_id` | `uuid NOT NULL` | rotation chain; reusing a rotated token revokes the whole family |
| `expires_at` | `timestamptz NOT NULL` | issue time + 14 days |
| `revoked_at` | `timestamptz` | |
| `replaced_by_id` | `bigint` → `admin_refresh_tokens` | |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | |

### `audit_log`

| Column | Type | Rule |
| --- | --- | --- |
| `id` | `bigint` identity PK | |
| `admin_user_id` | `bigint` → `admin_users ON DELETE SET NULL` | NULL for CLI or system actions |
| `entity` | `text NOT NULL` | table name |
| `entity_id` | `bigint` | |
| `action` | `text NOT NULL` | `ck_audit_log_action`: `create`, `update`, `delete`, `merge`, `bulk` |
| `diff` | `jsonb NOT NULL DEFAULT '{}'` | `{field: [old, new]}` |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | |

Indexes: `(entity, entity_id, created_at DESC)` and `(admin_user_id, created_at DESC)`. Rows are never deleted (`forbid_delete` trigger).

### `devices`

| Column | Type | Rule |
| --- | --- | --- |
| `id` | `bigint` identity PK | |
| `install_id` | `uuid NOT NULL UNIQUE` | |
| `token_hash` | `char(64) NOT NULL UNIQUE` | SHA-256 of the 256-bit device token |
| `platform` | `text NOT NULL` | `ck_devices_platform`: `android`, `ios`, `web` |
| `push_token` | `text UNIQUE` | ≤ 4096 characters |
| `app_version` | `text` | ≤ 32 characters |
| `locale` | `text` | ≤ 16 characters |
| `tz` | `text` | ≤ 64 characters (IANA name) |
| `prefs` | `jsonb NOT NULL DEFAULT '{}'` | |
| `created_at`, `last_seen_at` | `timestamptz NOT NULL DEFAULT now()` | |

### `device_follows`

| Column | Type | Rule |
| --- | --- | --- |
| `device_id` | `bigint NOT NULL` → `devices ON DELETE CASCADE` | |
| `team_id` | `bigint` → `teams ON DELETE CASCADE` | |
| `competition_id` | `bigint` → `competitions ON DELETE CASCADE` | |
| `match_id` | `bigint` → `matches` | matches are never deleted |
| `channel_id` | `bigint` → `channels ON DELETE CASCADE` | |
| `commentator_id` | `bigint` → `commentators ON DELETE CASCADE` | |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | |

- `ck_device_follows_one_target`: `num_nonnulls(team_id, competition_id, match_id, channel_id, commentator_id) = 1`.
- `UNIQUE NULLS NOT DISTINCT (device_id, team_id, competition_id, match_id, channel_id, commentator_id)`.
- One partial index per target column (`WHERE <col> IS NOT NULL`), for the audience query (D3).

### `notification_outbox`

| Column | Type | Rule |
| --- | --- | --- |
| `id` | `bigint` identity PK | |
| `type` | `text NOT NULL` | `ck_notification_outbox_type`: `kickoff_reminder`, `match_started`, `goal`, `final_score`, `channels_updated`, `frequency_changed`, `announcement` |
| `dedupe_key` | `text NOT NULL UNIQUE` | ≤ 200 characters (`goal:48213:23:home`) |
| `payload` | `jsonb NOT NULL` | |
| `audience` | `jsonb NOT NULL` | |
| `due_at` | `timestamptz NOT NULL` | |
| `status` | `text NOT NULL DEFAULT 'pending'` | `ck_notification_outbox_status`: `pending`, `sending`, `sent`, `failed`, `cancelled` |
| `sent`, `failed` | `integer NOT NULL DEFAULT 0` | |
| `created_at` | `timestamptz NOT NULL DEFAULT now()` | |
| `sent_at` | `timestamptz` | |

Index: `notification_outbox_pending_due_idx ON (due_at) WHERE status = 'pending'`.

### `import_runs`: new columns

The base columns `matches_imported` and `error` stay (expand/contract).

| Column | Type | Rule |
| --- | --- | --- |
| `items_found` | `integer NOT NULL DEFAULT 0` | |
| `items_upserted` | `integer NOT NULL DEFAULT 0` | |
| `http_errors` | `integer NOT NULL DEFAULT 0` | |
| `status` | `text NOT NULL DEFAULT 'running'` | `ck_import_runs_status`: `running`, `succeeded`, `partial`, `failed` |
| `raw_path` | `text` | gzipped raw page location |

### `dataset_versions`

| Column | Type | Rule |
| --- | --- | --- |
| `name` | `text` PK | `ck_dataset_versions_name`: `matches`, `live`, `channels`, `satellites`, `competitions`, `teams`, `commentators`, `rights_holders` |
| `version` | `bigint NOT NULL DEFAULT 0` | |
| `updated_at` | `timestamptz NOT NULL DEFAULT now()` | |

- `0002` seeds one row per name.
- Writers bump with `UPDATE … SET version = version + 1, updated_at = now()` as the last statement of their transaction (SD §6.2.1).
- Media changes bump the dataset of the row that references the asset.

## Lifecycle and state

### Match status (SD §6.2.3)

```
scheduled ─▶ live(1H) ─▶ halftime ─▶ live(2H) ─▶ [extra_time ─▶ penalties] ─▶ finished
scheduled ─▶ postponed | cancelled          live ─▶ abandoned
```

On D1 only the `clock` source exists. It is derived at read time ([research R3](research.md#r3-clock-status-and-the-estimated-flag)):

| Condition (`status_source = 'clock'`) | API `status` | `estimated` | score, minute, period |
| --- | --- | --- | --- |
| `time_tbd` | `scheduled` | `false` | null |
| `now < kickoff_at` | `scheduled` | `false` | null |
| `kickoff_at ≤ now < kickoff_at + 120 min` | `live` | `true` | null |
| `now ≥ kickoff_at + 120 min` | `finished` | `true` | null |

`feed` (D5) and `manual` (D2) rows are returned as stored, with `estimated: false`. A `manual` status wins until an admin clears it, which sets `status_source` back to `clock`.

### Identity and upserts during the snapshot load

| Table | Upsert key |
| --- | --- |
| `satellites`, `competitions`, `teams`, `channels`, `rights_holders`, `matches`, `feeds` | `legacy_id` |
| `commentators` | `name_norm` |
| `broadcast_presets` | `name` |
| `hidden_channel_names` | `name` (normalized) |
| `livesoccertv_teams` | `(ar_name, country, slug)` |
| `*_external_ids` | `(source, external_id)` |
| `match_channels` | `(match_id, channel_id)` |
| `match_custom_broadcasts` | `(match_id, slot)` |
| `media_assets` | `sha256`; rehosting skips any `original_url` already present |

Matches are never deleted: the base trigger refuses it. A refreshed snapshot only adds or updates rows.

## Read models (the API's view of the data)

| Read model | Built from | Notes |
| --- | --- | --- |
| `MatchSummary` | `matches` + `competitions` + `teams` + `media_assets` + a ranked subquery over visible `match_channels` → `channels` | Visible means not `is_hidden`, not `deleted_at`, and the name isn't in `hidden_channel_names` |
| `MatchDetail` | `MatchSummary` + `match_custom_broadcasts` + `match_channels` (with per-channel commentators) + `feeds.match_id` | Grouped into `broadcasts`, `carriages` and `platforms` ([research R6](research.md#r6-match-detail-sections)) |
| `LiveState` | `matches` with `kickoff_at` in `[now − 150 min, now + 10 min]` | Status derived as above |
| `Satellite` | `satellites` + a count of visible carriages | Ordered by `priority` (nulls last), then `orbital_position` |
| `ChannelCarriage` | `channels` + `satellites` + `media_assets` | `frequency` is null when the tuning is NULL; `frequency_note` carries the text |
| `RightsHolder` | `rights_holders` + carriages + carriage satellites + frequencies + competitions | Filters `satellite_id` and `competition_id` go through the link tables |
| `Team`, `Competition`, `Commentator` | The base tables + `media_assets` | Detail endpoints add upcoming or recent `MatchSummary` lists, bounded |

Media URLs are always `MEDIA_BASE_URL + "/" + media_assets.path`. A NULL `*_asset_id` gives a `null` URL, and the client shows its placeholder.

## Validation rules (from the spec)

- **Frequencies:** `^(\d{4,5})\s+([HVLR])\s+(\d{4,5})$`, after replacing the Cyrillic `Н`. Domains: 2000–13000 MHz and 500–60000 ksym/s, enforced by the base domains (README rule 5).
- **Placeholders** `""`, `⚽` and «غير مدرج» become NULL (README rule 6).
- **Kickoff:** Cairo wall clock → UTC with `AT TIME ZONE 'Africa/Cairo'`; `"--:--"` gives `kickoff_at = NULL` and `time_tbd = true` (README rule 7).
- **No card-sharing labels:** `encryption` is never read into any column, and `provider` and `package` start NULL (README rule 9, FR-005). A test asserts that no stored text contains the known labels.
