# Data Model: D2 · Core flows

Phase 1 of [plan.md](plan.md). D1's model ([001 data-model](../001-d01-foundation/data-model.md)) is the base, and nothing in it changes meaning. D2 adds:

- one small expand-only revision, `0003`;
- the write rules that D1's tables were created for;
- the Redis keys and raw-page files that ingestion and auth use;
- two app-side drift tables.

The API shapes are in [contracts/admin-api.md](contracts/admin-api.md) and [contracts/ingestion.md](contracts/ingestion.md).

## Revision `0003`: audit source and link origin

Run through psycopg like `0002`. Both changes are additive, and `/v1` doesn't change. The owner reviews this revision line by line (delivery-plan §5.4).

### `audit_log`: new column

| Column | Type | Rule |
| --- | --- | --- |
| `source` | `text` → `sources (name)` | The importer that made the change. NULL for admin and CLI actions |

- `ck_audit_log_actor`: `admin_user_id IS NULL OR source IS NULL`. A row is an admin's, a source's, or a CLI or system action (both NULL).

### `match_channels`: new column

| Column | Type | Rule |
| --- | --- | --- |
| `imported_by` | `text` → `sources (name)` | The source that first brought the link. NULL means an editor added it. It never changes after insert |

- **Backfill:** `UPDATE match_channels SET imported_by = source WHERE source <> 'manual'`. Snapshot links become `imported_by = 'legacy'`.
- **Index:** none. The column is read only together with the primary key.

**Downgrade:** drop both columns and the CHECK. No data outside them is touched.

## Write rules

### Entity version (`ETag` / `If-Match`)

| Entity | Hashed state (canonical JSON, sorted keys and rows) |
| --- | --- |
| Match | every `matches` column except `created_at` and `updated_at`; its `match_channels` rows (`channel_id`, `source`, `imported_by`, `is_hidden`, `commentator_id`, `commentator2_id`); its `match_custom_broadcasts` rows |
| Team | `teams` columns + its `team_competitions` competition ids |
| Competition, satellite, channel, commentator | their own columns |

The version is the first 32 hex characters of the SHA-256, in quotes ([research R5](research.md#r5-entity-versions-and-if-match)). It is computed on GET, and again under `SELECT … FOR UPDATE` when a write arrives. Any writer changes it, whether an editor, an importer or the media worker.

### `locked_fields`

- An admin write adds the names of the lockable columns whose value changed (001 data-model lists them). A value sent unchanged locks nothing.
- Setting a manual status locks the status and score columns whose value changed. Clearing it removes `status`, `home_score`, `away_score`, `home_pen` and `away_pen` again.
- Nothing unlocks a field on D2 otherwise; the unlock action comes later.
- Importers re-read `locked_fields` under the row lock and skip those fields ([research R18](research.md#r18-the-upsert-pipeline)).

### Match status: manual override (adds to 001's "Match status")

| Action | `status_source` | Stored columns | API |
| --- | --- | --- | --- |
| Set | `manual` | `status`, plus optional `period`, `minute` and `status_label`, plus the score where allowed; `status_updated_at = now()` | as stored, `estimated: false` |
| Clear | `clock` | `status = 'scheduled'`; score, penalties, `minute` and `period` set to NULL (`ck_matches_clock_no_score`) | derived again (D1 R3) |

Validation, before the DB checks:

| Status | Score | Penalties | `period` | `minute` |
| --- | --- | --- | --- | --- |
| `scheduled`, `postponed`, `cancelled` | not allowed | not allowed | not allowed | not allowed |
| `live` | required | not allowed | optional `1H`, `2H` | optional, ≤ 8 characters, `^\d{1,3}(\+\d{1,2})?$` |
| `halftime` | required | not allowed | not allowed | not allowed |
| `extra_time` | required | not allowed | optional `ET1`, `ET2` | optional, as above |
| `penalties` | required | optional | not allowed | not allowed |
| `finished` | required | optional | not allowed | not allowed |
| `abandoned` | optional | not allowed | not allowed | optional |

`status_label` is optional for every status, ≤ 80 characters (the column allows 120).

### Match–channel link lifecycle

```
             importer adds                    editor edits (hide, commentators)
 (none) ───────────────────▶ source = S ─────────────────────────────▶ source = manual
                             imported_by = S                          imported_by = S
                                  │                                        │
                 importer drops it│                                        │ editor removes it
                                  ▼                                        ▼
                               deleted                        source = manual, is_hidden = true
                                                              (kept; no importer re-adds it)

             editor adds                      editor removes it
 (none) ───────────────────▶ source = manual ─────────────────────────▶ deleted
                             imported_by = NULL
```

- An importer inserts with `source = imported_by = <its source>`, deletes only rows whose `source` is its own, and never touches `source = 'manual'` rows.
- A row with `source = 'manual'` and `is_hidden = true` is never shown in `/v1` (D1 R6 already excludes hidden links). A4 lists it as hidden, and «إظهار» clears `is_hidden` and keeps it `manual`.
- `ck_match_channels_commentators` (base schema) still holds: commentator 2 needs commentator 1, and the two differ.

### Hidden channel names

- «إخفاء دائماً» inserts `ar_normalize(name)` (the base CHECK requires the normalized form). «إظهار» deletes it.
- Both write an `audit_log` row with `entity = 'hidden_channel_names'`, `entity_id = NULL` and `diff = {"name": [old, new]}`, and bump `matches`.

### Audit entries

| Writer | `admin_user_id` | `source` | `action` | `diff` |
| --- | --- | --- | --- | --- |
| Admin save | the admin | NULL | `create`, `update`, `delete` | `{field: [old, new]}` for changed fields; links under `channels: {added, removed, changed}`, slots under `broadcasts` |
| Admin bulk | the admin | NULL | `bulk` | as above, one row per match |
| Importer | NULL | the source | `create`, `update` | changed fields, and link changes |
| Media worker | NULL | the source that found the logo | `update` | `{logo_asset_id: [null, id]}` |
| CLI (`create-admin`, …) | NULL | NULL | `create`, `update` | never a password or hash |

### Dataset bumps

The table is in [research R6](research.md#r6-one-unit-of-work-per-admin-write). Importers bump `matches`, and `live` when a kickoff changed, once per run. The media worker bumps `teams` or `competitions`, plus `matches`.

## Redis keys

| Key | Type | TTL | Written by | Purpose |
| --- | --- | --- | --- | --- |
| `auth:fail:<h>:<ip>` | sorted set of failure times | 15 min | api-admin | login attempts per email hash + IP (R3) |
| `auth:lock:<h>:<ip>` | string | 900 s | api-admin | lockout; its TTL is `retry_after_s` |
| `ratelimit:<host>` | hash (tokens, timestamp) | 1 h idle | scrape tasks | per-host token bucket (R14) |
| `lock:fetch:<source>`, `lock:ingest:<source>` | string | run length + margin | tasks | no overlapping runs (constitution VII) |
| `lock:media:<sha256(url)>` | string | 10 min | ingest | one rehost per URL at a time (R20) |
| `celery:*` | Celery's keys | — | Celery | the broker, under the prefix that the home box's ACL allows (R21) |

`<h>` is the first 32 hex characters of `sha256(lower(email))`, so the keys never hold an email address.

## Raw pages and run records

```
/srv/raw/<source>/<YYYY-MM-DD>/<run_id>/
    1.html.gz, 2.html.gz, …     the fetched pages (ysscores HTML; the bridge's Firestore JSON)
    run.json                    {counts, skipped[{ref, reason}], unresolved[{name, competition, match_ref}]}
```

- `import_runs.raw_path` is the run folder. `status` follows D1's CHECK:
  - `running`: the row is written when `ingest` starts;
  - `succeeded`: every item was upserted;
  - `partial`: some items failed in their savepoint;
  - `failed`: a fetch or layout failure, with `http_errors` set and `error` holding a short reason.
- `items_found` counts the parsed fixtures, and `items_upserted` the rows created or changed. `matches_imported` (base column) is kept equal to `items_upserted` until a later contract step drops it.
- Folders older than 5 days are deleted by `prune_raw_pages` (constitution VII).

## Identity during imports

| Source | Match key | Also recorded |
| --- | --- | --- |
| `ysscores` | `match_external_ids (ysscores, <match id from the href>)` | the match page URL in `url`; a team's id in `team_external_ids` when the page gives one |
| `legacy` (bridge) | `matches.legacy_id` = the Sat Air match id (D1's key for these rows) | `ysMatchId` as `match_external_ids (ysscores, …)`, so the two sources converge |

The duplicate probe, used when no key matches, is described in [research R18](research.md#r18-the-upsert-pipeline): the same resolved teams with kickoffs within 45 minutes, or, without team ids, the same normalized names on the same `match_date`.

## App: drift tables (Lane M)

| Table | Columns | Purpose |
| --- | --- | --- |
| `matches` (D1) | as on D1 | match rows by id; the S2 and S4 queries by local day |
| `match_windows` (new) | `day` (local `YYYY-MM-DD`) PK, `etag`, `fetched_at` | one revalidation record per local day |
| `cached_documents` (new) | `key` PK (`match:<id>`, `satellites`, `satellite:<id>:channels`, `matches:<day>:sat:<sorted ids>`), `etag`, `body` (JSON text), `fetched_at` | match detail, satellites, channel lists, and S4's satellite-filtered day ([research R25](research.md#r25-stale-while-revalidate-with-drift)) |

- Schema version 2, with a drift migration step from version 1.
- `matches` and `match_windows` hold only S2's full local days. S4 requests `/v1/matches?…&satellite_ids=` and stores the answer as a document under `matches:<day>:sat:<sorted ids>`. It never writes to `matches` or `match_windows`, so a filtered list never replaces S2's day.
- Local days outside today−1 … today+6 are pruned on start.
- Freshness targets: 5 minutes for matches and match detail, 24 hours for satellites and channels.
- Live states are never stored.

## Validation rules (from the spec)

- **Admin text caps:**
  - names ≤ 120 characters;
  - `competition_stage` ≤ 80, `stadium` ≤ 120;
  - broadcaster `label` ≤ 80, `status_label` ≤ 80;
  - `q` ≤ 64;
  - up to 300 links per match, and up to 200 items per bulk request.
- **Content:** no free-text field that reaches `/v1` may hold a card-sharing label, matched as whole words by D1's `find_card_sharing_label` (moved to `app/domain/content.py`); such a write is a `422 validation_error`.
- **Kickoff:** an ISO-8601 UTC instant, or `time_tbd: true` with a `match_date`. A4 converts from Cairo wall time ([research R24](research.md#r24-session-forms-and-time-in-the-admin)).
- **Uploads:** the magic signatures and caps in [research R10](research.md#r10-uploads).
- **Frequencies** (channel editor): D1's rule, `^(\d{4,5})\s+([HVLR])\s+(\d{4,5})$`, plus the base domains. A channel's `kind` decides which fields it may have (`ck_channels_kind_fields`).
- **Passwords:** ≥ 12 characters and ≤ 256.
