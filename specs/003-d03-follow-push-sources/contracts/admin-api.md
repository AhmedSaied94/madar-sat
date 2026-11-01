# Contract: `/admin/api` D3 additions

B1 builds; Lane A consumes through Orval. Non-breaking against D2's admin spec ([002 admin-api](../../002-d02-core-flows/contracts/admin-api.md)): conventions, roles, `If-Match`, audit, errors and media fields are D2's. Merged with the regenerated admin client by **13:00** (spec Dependencies). The OpenAPI spec exported from FastAPI is authoritative.

## Sources (A13)

| Method & path | Role | Request | Response | Errors |
| --- | --- | --- | --- | --- |
| `GET /sources` | editor | — | `SourceHealth[]` (replaces D2's `SourceItem[]`, fields added only) | |
| `POST /sources/{name}/run` | editor | — | `202` `{queued: true}` | `404 not_found`, `409 run_in_progress`, `409 source_not_runnable` (`manual`, `legacy` without the bridge configured) |
| `POST /sources/{name}/pause` | editor | — | `SourceHealth` | `404` |
| `POST /sources/{name}/resume` | editor | — | `SourceHealth` | `404` |
| `GET /sources/{name}/runs?cursor&limit` | editor | — | `ImportRunRow[]`, `meta.next_cursor` (newest first, `limit` ≤ 50) | `404` |
| `GET /import-runs/{id}` | editor | — | `ImportRunDetail` | `404` |

Pause, resume and run are audited (`entity = source`, D2's writer). Resume also queues one manual run. Pause, resume and every finished run (B2's `health.record_run`) bump the `sources` dataset, so `GET /sources`, the runs list and run detail (all `ETag`s from `sources`) never answer a stale `304`; no `/v1` route reads `sources`. They take no `If-Match`: each sets a state rather than editing a representation, and repeating one is harmless (plan, Complexity Tracking).

```jsonc
// SourceHealth
{ "name": "livesoccertv", "kind": "scraper",
  "is_enabled": true,                              // false = paused by an editor
  "breaker": "closed",                             // closed | open
  "breaker_opened_at": null,
  "consecutive_failures": 0,
  "paused": false,                                 // is_enabled false, breaker open, or paused_until in the future
  "last_success_at": "2026-11-01T08:00:41Z",
  "last_run": { "id": 9123, "status": "succeeded", "started_at": "…", "items_found": 64, "items_upserted": 12 },
  "items_24h": [41, 0, 64, 58],                    // items_found of the last runs in 24 h, oldest first (sparkline)
  "error_rate_24h": 0.25,                          // failed runs ÷ runs, last 24 h; null with no runs
  "running": false }                               // the fetch lock is held

// ImportRunRow
{ "id": 9123, "status": "succeeded", "started_at": "…", "finished_at": "…",
  "items_found": 64, "items_upserted": 12, "http_errors": 0, "error": null }

// ImportRunDetail = ImportRunRow + the run's log, read from run.json on VPS-2's raw store when still kept (5 days)
{ …, "raw_path": "livesoccertv/2026-11-01/…", "log": { "unmatched_matches": [...], "placeholders_created": [...],
  "skipped_channels": 7, "errors": [...] }, "log_available": true }
```

`ImportRunDetail.log` is read by `api-admin` on VPS-1, which can't see VPS-2's disk. So `adapters.ingest` also writes a compact copy of `run.json` (≤ 64 KB, truncated lists) to `import_runs.log jsonb`. **This adds one column to revision `0005`**: `import_runs.log jsonb` (see data-model).

## Dashboard (A2)

| Method & path | Role | Response |
| --- | --- | --- |
| `GET /dashboard?from&to` | editor | `Dashboard` (`from`/`to`: the Cairo day's UTC bounds, sent by the admin as for A3; ≤ 2 days). `ETag` from `matches`, `channels` and `sources` with a 60 s bucket (`recent_changes` has no dataset version) |

```jsonc
// Dashboard
{ "missing_channels": [                            // matches in the window with no visible channel, by competition priority then kickoff
    { "competition": {"id": 12, "name": "…", "priority": 3},
      "matches": [ {"id": 48213, "kickoff_at": "…", "home": "…", "away": "…"} ] } ],
  "missing_channels_count": 9,
  "placeholders_to_complete": 14,                  // channels with placeholder_source, not deleted
  "sources": [ SourceHealth, … ],                  // same shape as GET /sources
  "recent_changes": [                              // last 10 audit entries
    { "at": "…", "by": {"kind": "admin", "name": "…"}, "entity": "match", "entity_id": 48213, "action": "update" } ] }
```

## Ordering (A6, A7)

| Method & path | Role | Request | Response | Errors |
| --- | --- | --- | --- | --- |
| `PUT /competitions/order` | editor | `OrderRequest` | `{updated: [{id, etag}]}` | `409 edit_conflict` (`meta.stale_ids`), `422 validation_error` (unknown or repeated ids) |
| `PUT /satellites/order` | editor | `OrderRequest` | same | same |

```jsonc
// OrderRequest: the full new order of the rows being moved, top first. Each item carries its version.
{ "items": [ {"id": 12, "if_match": "W/\"…\""}, {"id": 4, "if_match": "W/\"…\""}, … ] }
```

The server sets `priority` 1…n in the given order for those rows (rows not listed keep theirs, after the listed ones), in one transaction: one stale item rejects all. It writes an audit entry per changed row (no `locked_fields`: no importer writes `priority`) and bumps `competitions` (and `matches`, whose group order uses it) or `satellites`.

## Channels (A8)

- `GET /channels` gains `placeholder=true|false` and `show_in_match=true|false` (A8's "shown on match pages" filter; D2's list has `satellite_id`, `category`, `kind` (platform-only is `kind=platform`), `access` and `missing_logo`), and returns `placeholder_source` on each row.
- `PATCH /channels/{id}` on a placeholder: setting `show_in_match: true` also clears `placeholder_source` (same audit entry). The D2 validation applies, so a placeholder moved to `kind: "satellite"` needs a satellite and access.
- «إضافة على قمر آخر» uses D2's `POST /channels` with the fields copied by the client; the D2 carriage unique rule answers `409 already_exists` for a duplicate carriage.

## Teams, competitions, satellites, commentators (A5, A6, A7, A10)

No change: D2's endpoints serve every field the D3 screens edit. The team list gains one filter, `missing_logo=true`; A7 needs no list filter, and A8's filters are listed under Channels above.
