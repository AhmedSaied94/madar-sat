# Contract: `/v1` D5 changes

B1 builds; Lane M consumes through the generated client. All changes are additive or narrow an untyped field, and are compatible with `app-v0.3.0` and `web-v0.1.0` ([R15](../research.md#r15-old-app-builds-are-safe)). The OpenAPI spec exported from FastAPI is authoritative.

## `MatchDetail`

```jsonc
"events": [{ "type": "goal", "side": "home", "minute": "23", "player": "…" }],  // [] when none
"lineups": null | {
  "home": { "formation": "4-3-3", "players": [{ "name": "…", "number": 1, "position": "GK", "is_starter": true }] },
  "away": { /* same; either side may be null */ }
}
```

- `type` is the enum in [data-model](../data-model.md#match_events).
- Goal-type events are absent while their score is unconfirmed.
- An `estimated: true` match returns `events: []` and `lineups: null`.
- The app shows neither on D5 (`live_center` is off).

## `GET /v1/live`

No shape change. A match on `feed` has `estimated: false` with a real status, minute and score. Clock rows are as before. The set also keeps `feed` matches with no final state up to kickoff + 210 min, so a long match doesn't drop out.

**Budget:** A confirmed score reaches a client within 45 s of confirmation: at most 15 s from the bucket, plus the client's `live_poll_interval_s`. Remote Config keeps that interval at 30 s or less.

## `GET /v1/channels/{id}`

- `upcoming_matches` is limited to `kickoff_at` from now − 150 min to now + 7 days, at most 20 rows.
- `recent_frequency_changes` stays `[]` until D6, typed:

  ```jsonc
  [{ "old": {"frequency_mhz": 11766, "polarization": "H", "symbol_rate": 27500},
     "new": {"frequency_mhz": 11013, "polarization": "H", "symbol_rate": 27500},
     "detected_at": "2026-10-20T09:12:00Z" }]
  ```

  D6's revision fills it. The type is fixed now so that the app section can be tested.

## `GET /v1/teams/{id}`

No change. `upcoming` and `recent` hold 10 rows each.

## `GET /v1/competitions/{id}`

```jsonc
{ "id": 12, "sport": "football", "name": "…", "logo": "…", "priority": 1,
  "upcoming": [MatchSummary],   // ≤ 30, soonest first
  "recent": [MatchSummary],     // ≤ 30, latest first
  "rights_holders": [{ "id": 3, "name": "Eleven Sports", "logo": "…",
                       "satellites": [SatelliteRef], "competition_count": 9 }] }
```

ETag datasets gain `matches`, `teams`, `channels`, `rights_holders`, with `bucket_s=60`.

`/v1/rights-holders*` don't change. S11 arrives on D7.

## Errors and caching

The envelope, `ETag` and `404` follow D1's conventions. Lists are bounded, not paginated.
