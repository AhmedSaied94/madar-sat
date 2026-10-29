# Contract: public API `/v1` (D1 read endpoints)

This is the design target for `app.public:app`. The OpenAPI document exported from the code (`backend/openapi/public.json`) is authoritative once it is tagged `contract-v1` at 13:00 on D1. Before tagging, the owner reviews any difference between that export and this file. After the tag, changes are additive only (constitution VI).

Sources: SD §6.3, spec FR-008–FR-012, [research.md](../research.md) R1–R8.

## Conventions

- **Base URL:** `https://api.<ip1>.sslip.io`. Clients read it from their flavor's bundled default (D1) and from Remote Config (D3).
- **Envelope.** Every non-`304` response:

  ```jsonc
  { "success": true,  "data": <payload>, "error": null, "meta": { ... } }
  { "success": false, "data": null, "error": { "code": "match_not_found", "message": "for logs only" }, "meta": {} }
  ```

  - `meta.generated_at` (ISO-8601 UTC) is on every success.
  - Clients map `error.code` to Arabic copy and never show `error.message`.
- **Types:**
  - ids are integers;
  - times are ISO-8601 UTC with `Z`;
  - `match_date` is `YYYY-MM-DD`;
  - media URLs are absolute or `null`;
  - optional values are `null`, never missing.
- **Headers on every GET:**
  - `ETag: W/"<16 hex>"`;
  - `Cache-Control: no-cache`;
  - `Vary: Accept-Encoding`.

  A matching `If-None-Match` returns `304` with no body.
- **CORS:**
  - allowed origins: only `https://<project>.web.app` and `https://<project>.firebaseapp.com`;
  - methods: `GET`;
  - allowed request header: `If-None-Match`;
  - exposed response header: `ETag`.
- **Rate limits:** none until D3 (plan.md Complexity Tracking). `rate_limited` (429) is reserved.

## Shared shapes

```jsonc
// Frequency
{ "mhz": 11843, "pol": "H", "sr": 27500 }                     // pol ∈ H | V | L | R

// SatelliteRef
{ "id": 2, "slug": "nilesat-7-0w", "name_ar": "نايل سات", "name_en": "Nilesat 7.0W", "orbital_position": -7.0 }

// TeamRef
{ "id": 101, "name": "الأهلي", "logo": "https://media…/logo/1a/1a….webp" }    // id null when unresolved; name always set

// CompetitionRef
{ "id": 12, "name": "الدوري المصري الممتاز", "logo": "…", "stage": "الجولة 9", "priority": 3 }   // id null when unresolved

// Score
{ "home": 1, "away": 0, "home_pen": null, "away_pen": null }

// CommentatorRef
{ "id": 7, "name": "…", "image": "…", "audio": "https://media…/audio/3c/3c….m4a" }
```

## Status fields (on every match and live state)

| Field | Type | Rule |
| --- | --- | --- |
| `status` | enum | `scheduled`, `live`, `halftime`, `extra_time`, `penalties`, `finished`, `postponed`, `cancelled`, `abandoned` |
| `estimated` | bool | `true` only for clock-derived `live` and `finished` |
| `period` | `1H` \| `2H` \| `ET1` \| `ET2` \| null | always null when `estimated` |
| `minute` | string \| null | `"67"`, `"45+2"`; always null when `estimated` |
| `score` | `Score` \| null | always null when `estimated` or `scheduled` |
| `status_label` | string \| null | a source's label for an unusual state |

The clock rule is in [data-model.md](../data-model.md#match-status-sd-623). On D1 every match is clock-sourced.

## Endpoints

### `GET /v1/matches`

| Param | Type | Rule |
| --- | --- | --- |
| `from`, `to` | UTC datetime, required | `from < to`, and `to − from ≤ 8 days` |
| `sport` | enum, optional | `football`, `basketball`, `handball`, `volleyball`, `tennis` |
| `competition_id`, `team_id` | int, optional | filters |
| `satellite_ids` | comma-separated ints (≤ 32), optional | **filter**: only matches with ≥ 1 visible carriage on these satellites (S4) |
| `my_satellite_ids` | comma-separated ints (≤ 32), optional | **ranking only**: orders `broadcast.headline` ([research R2](../research.md#r2-personal-channel-line-on-match-rows)) |
| `status` | enum, optional | filters on the derived status (S2 live chip: `status=live`) |

- **Window:** a match is in the window when `kickoff_at ∈ [from, to)`, or, when `time_tbd`, when `match_date 12:00 Africa/Cairo ∈ [from, to)`.
- **Order:** `kickoff_at`, then `id`. TBD matches come last.
- **`data`:** `MatchSummary[]`.
- **`meta`:** `{ generated_at, count }`.

```jsonc
// MatchSummary
{
  "id": 48213, "sport": "football",
  "kickoff_at": "2026-10-28T18:00:00Z", "time_tbd": false, "match_date": "2026-10-28",
  "status": "live", "estimated": true, "period": null, "minute": null, "score": null, "status_label": null,
  "competition": CompetitionRef, "home": TeamRef, "away": TeamRef,
  "broadcast": {
    "channel_count": 14,            // visible links of every kind
    "has_free": true,
    "headline": [                   // ≤ 2, ranked as in research R2
      { "channel_id": 5512, "name": "أون سبورت 1", "access": "free",
        "satellite": SatelliteRef, "frequency": Frequency }   // satellite and frequency null for platforms
    ]
  },
  "commentator": CommentatorRef,     // match-level commentator, or null
  "updated_at": "2026-10-28T17:59:10Z"
}
```

`home.logo` and `away.logo` use the match's own logo when it is set (`*_logo_asset_id`), otherwise the team's logo.

### `GET /v1/matches/{id}`

- **`data`:** `MatchDetail`.
- **Errors:** `404 match_not_found`.

```jsonc
// MatchDetail = MatchSummary +
{
  "stadium": "استاد القاهرة",
  "local_broadcaster_eg": null,                       // always null on D1 (column arrives with YallaKora, D5)
  "broadcasts": [                                     // manual broadcasters first, then preferred carriages, free first
    { "kind": "custom", "label": "ON Sport 1", "logo": "…", "commentators": [CommentatorRef] },
    { "kind": "channel", "channel_id": 5512, "label": "أون سبورت 1", "logo": "…", "access": "free",
      "satellite": SatelliteRef, "frequency": Frequency, "commentators": [CommentatorRef] }
  ],
  "carriages": [ChannelCarriage & { "commentators": [CommentatorRef] }],   // every visible satellite + terrestrial link
  "platforms": [ { "region": "الشرق الأوسط",
                   "items": [ { "channel_id": 9001, "name": "Shahid", "country": "السعودية", "logo": "…" } ] } ],
  "events": [],                                       // D5
  "lineups": null,                                    // D5
  "feed_id": null
}
```

- **Preferred** means a carriage on the default satellites (`nilesat-7-0w`, `badr-26-0e`) or one with `show_in_match`.
- **Region order:** الشرق الأوسط، أوروبا، آسيا، الأمريكتان، أفريقيا، أوقيانوسيا، أخرى.
- **Hidden links** (per match, or by name everywhere) never appear in any section.

### `GET /v1/live`

- **`data`:** `LiveState[]` for matches with `kickoff_at ∈ [now − 150 min, now + 10 min]`.

```jsonc
// LiveState
{ "match_id": 48213, "status": "live", "estimated": true, "period": null, "minute": null,
  "score": null, "status_label": null, "status_updated_at": null }
```

### `GET /v1/satellites`

- **`data`:** `Satellite[]`, ordered by `priority` (nulls last), then `orbital_position`.

```jsonc
// Satellite = SatelliteRef +
{ "kind": "satellite", "logo": null, "channel_count": 63,
  "best_frequency": Frequency, "worst_frequency": Frequency,  // null when unknown
  "reception_url": "https://www.youtube.com/…" }
```

### `GET /v1/satellites/{id}/channels`

| Param | Type | Rule |
| --- | --- | --- |
| `category` | enum, optional | `sports`, `entertainment` |
| `q` | string ≤ 64, optional | matches `ar_normalize(q)` within `name_norm`, or a digit prefix of the frequency |

- **`data`:** `ChannelCarriage[]` (whole list), ordered by `sort_order` (nulls last), then `name`.
- **Errors:** `404 satellite_not_found`.

```jsonc
// ChannelCarriage
{ "id": 5512, "kind": "satellite", "name": "beIN SPORTS 1 HD", "display_name": "beIN SPORTS 1", "logo": "…",
  "category": "sports", "satellite": SatelliteRef, "frequency": Frequency, "frequency_note": null,
  "access": "encrypted", "provider": null, "package": null, "beam": "wide", "country": null,
  "frequency_changed_at": null }
```

### `GET /v1/channels/{id}`

- **`data`:** `ChannelCarriage` plus:
  - `other_carriages: ChannelCarriage[]` (same `name_norm`, not deleted);
  - `upcoming_matches: MatchSummary[]` (≤ 20, `kickoff_at ≥ now − 150 min`);
  - `recent_frequency_changes: []` (empty until D6).
- **Errors:** `404 channel_not_found`.

### `GET /v1/competitions` and `GET /v1/competitions/{id}`

- **List `data`:** `Competition[]` = `{ id, sport, name, logo, priority }`, ordered by `priority` (nulls last), then `name`.
- **Detail:** adds `rights_holders: [{ id, name, logo }]`.
- **Errors:** `404 competition_not_found`.

### `GET /v1/teams` (search) and `GET /v1/teams/{id}`

| Param | Type | Rule |
| --- | --- | --- |
| `q` | string, required, 1–64 | normalized with `ar_normalize` |
| `limit` | int 1–50 | default 20 |
| `cursor` | opaque string, optional | from `meta.next_cursor` |

- **Search `data`:** `[{ id, sport, name, country, logo, primary_competition: { id, name } | null }]`.
  - **Order:** exact `name_norm` match, then prefix match, then trigram similarity (descending), then `id`.
  - **`meta`:** `{ generated_at, next_cursor }`, with `next_cursor` null on the last page.
- **Detail `data`:** the summary plus:
  - `stadium`;
  - `competitions: [{ id, name, logo }]`;
  - `upcoming: MatchSummary[]` (≤ 10);
  - `recent: MatchSummary[]` (≤ 10, most recent first).
- **Errors:** `404 team_not_found`.

### `GET /v1/rights-holders` and `GET /v1/rights-holders/{id}`

- **List params:** `satellite_id` (through carriage satellites) and `competition_id`, both optional.
- **List `data`:** `[{ id, name, logo, sort_order }]`, ordered by `sort_order`.
- **Detail** adds:
  - `competitions: [{ id, name, logo }]`;
  - `carriages: [{ id, access, beam, satellites: [SatelliteRef], frequencies: [Frequency & { "is_primary": bool }] }]`.
- **Errors:** `404 rights_holder_not_found`.

### `GET /v1/commentators/{id}`

- **`data`:** `CommentatorRef` plus `upcoming: MatchSummary[]` (≤ 20).
- **Errors:** `404 commentator_not_found`.

### `GET /healthz` (operational, outside `/v1`)

- `200 { success: true, data: { db: "ok", redis: "ok" } }`.
- `503` with `error.code = "unhealthy"` when either dependency fails.
- Checked live on every request, never from a cache. A `200` carries the usual headers, with `ETag: W/"<16 hex>"` hashed from the `data` object, so a matching `If-None-Match` returns `304` only while the status is unchanged. A `503` carries no `ETag`.

## Errors

| HTTP | `error.code` | When |
| --- | --- | --- |
| 404 | `not_found` | Unknown route |
| 404 | `<entity>_not_found` | Unknown id on a detail endpoint |
| 405 | `method_not_allowed` | Wrong method |
| 422 | `validation_error` | Bad query; `meta.errors = [{ loc, type }]` |
| 429 | `rate_limited` | Reserved (D3) |
| 500 | `internal_error` | Never a stack trace |

## ETag inputs per endpoint ([research R4](../research.md#r4-etags-304-and-time))

| Endpoint | Dataset versions | Time bucket |
| --- | --- | --- |
| `/v1/matches` | matches, channels, satellites, competitions, teams, commentators | 60 s |
| `/v1/matches/{id}` | the same | 15 s |
| `/v1/live` | matches, live | 15 s |
| `/v1/satellites` | satellites, channels | none |
| `/v1/satellites/{id}/channels` | channels, satellites | none |
| `/v1/channels/{id}` | channels, satellites, matches, competitions, teams | 60 s |
| `/v1/competitions[/{id}]` | competitions, rights_holders | none |
| `/v1/teams`, `/v1/teams/{id}` | teams, competitions, matches, channels, satellites, commentators | 60 s (detail only) |
| `/v1/rights-holders[/{id}]` | rights_holders, satellites, competitions | none |
| `/v1/commentators/{id}` | commentators, matches, channels, satellites, competitions, teams | 60 s |

Every ETag also hashes the normalized query, `MEDIA_BASE_URL` and the contract version.
