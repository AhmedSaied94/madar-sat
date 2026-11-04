# Contract: `/admin/api` D5 additions

B1 builds; Lane A consumes through Orval. Non-breaking against D3's admin spec. Conventions, roles, `If-Match`, `audit_log`, errors and media fields are as in [002 admin-api](../../002-d02-core-flows/contracts/admin-api.md). The OpenAPI spec is authoritative.

Every mutation goes through `services/admin/writer.py`. All routes need `require_editor`.

## Unresolved names (A13)

### `GET /admin/api/unresolved-names`

Query: `source?`, `kind?`, `state?` (default `open`), `cursor?`, `limit` (≤ 100). Ordered by `last_seen_at` descending. The list's `ETag` is built from the `unresolved_names` dataset.

```jsonc
{ "id": 91, "source": "yallakora", "kind": "team", "name": "Al Ahli",
  "context": { "match_id": 48213, "home": "…", "away": "…", "competition": "…", "kickoff_at": "…" },
  "seen_count": 4, "last_seen_at": "…", "state": "open", "etag": "\"…\"",
  "suggestions": [{ "id": 101, "name": "الأهلي", "detail": "الدوري القطري",
                    "confidence": 100, "exact": true }] }
```

`suggestions` holds at most 3 ([R9](../research.md#r9-suggestions-use-trigrams-and-never-cross-scripts)), and is `[]` if none reach the threshold. Rows with several `exact` entries show the picker.

`meta` includes `open_count`, for the board's count.

### `POST /admin/api/unresolved-names/{id}/map`

`If-Match` required.

```jsonc
{ "target_id": 101, "scope_to_competition": true, "created": false }
```

- Writes the alias and sets `state` to `mapped`, or `created` if `created: true`.
- `scope_to_competition` applies to teams, and uses the row's `competition_norm`. It is required to be `true` when more than one team shares the name.
- An existing alias for the same key with another target returns `409 alias_conflict`.
- Target not found: `404`. Row not `open`: `409 edit_conflict`.
- Bumps `unresolved_names`. Audited as `unresolved_name`.

### `POST /admin/api/unresolved-names/{id}/ignore`

`If-Match` required. Sets `ignored`. Bumps and audits as above.

**Create new** uses the existing `POST /teams`, `/competitions` or `/channels`, then `map` with `created: true` ([R10](../research.md#r10-create-new-reuses-the-existing-create-forms)).

## Run detail (A13)

### `GET /admin/api/import-runs/{id}/raw?page=0`

```jsonc
{ "state": "ready", "page": 0, "pages": 3, "url": "…", "content_type": "text/html",
  "text": "…", "truncated": false }
```

`state` is `pending` (poll again, up to 10 s), `ready` or `gone` (pruned, or none was saved). The `ETag` is built from the run ID, the page and the state, so a `pending` tag never matches a `ready` one. `text` is capped at 512 KB and always shown as inert text. `url` is the stored page's address, shown as an LTR island and never as a link.

`ImportRunDetail` gains `pages` (count) and `worker` (nullable). `stages` isn't added: the board's fetch, parse, normalize, resolve and upsert rows are derived from the existing compact log, and a stage the log doesn't record shows «لم يبدأ».

## Sources (A13)

`GET /admin/api/sources` includes the `live_poller` card, and not `filgoal`. `SourceHealth` gains:

```jsonc
"live": { "matches_live": 6, "error_share": 0.01, "sources": [{ "name": "filgoal", "state": "ok" }] } | null
```

`POST /sources/live_poller/run` answers `409 source_not_runnable`. Pause and resume work ([R6](../research.md#r6-falling-back-staying-honest-and-the-watchdog)).

## Rights holders (A9)

| Route | Notes |
|---|---|
| `GET /admin/api/rights-holders` | `sort_order`, then name. The list's `ETag` is built from `rights_holders`. Each row has `etag`, logo, competition names, satellite names |
| `GET /admin/api/rights-holders/{id}` | The full editor shape |
| `POST /admin/api/rights-holders` | |
| `PATCH /admin/api/rights-holders/{id}` | `If-Match`. `competitions` and `carriages`, if sent, replace the whole list atomically |
| `DELETE /admin/api/rights-holders/{id}` | `If-Match`. Admin role |
| `POST /admin/api/rights-holders/reorder` | The same `ordering.py` shape as competitions |

```jsonc
{ "name": "Eleven Sports", "logo_asset_id": 77, "competition_ids": [12, 14],
  "carriages": [{ "access": "encrypted", "beam": "wide", "package": "…",
                  "satellite_ids": [3],
                  "frequencies": [{ "frequency_mhz": 11013, "polarization": "H",
                                    "symbol_rate": 27500, "is_primary": true }] }] }
```

**Validation:**

- Each carriage with frequencies has exactly one `is_primary`, or `422`. This is enforced in the service, not by an index, because snapshot rows aren't guaranteed to meet it.
- `name` uses `Name120`.
- Frequencies use the existing bounds.

Saves bump `rights_holders` and `competitions`, and are audited.
