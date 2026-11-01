# Contract: `/v1` D3 additions (devices, follows, limits, cache)

B1 builds; Lane M consumes through the regenerated Dart client. Non-breaking against `contract-v1`: four new paths, one new error code on every path (`429`), and new response headers. Existing paths, fields and shapes don't change, except that placeholder channels ([data-model](../data-model.md#placeholder-channel)) no longer appear in any channel list. The OpenAPI spec exported from FastAPI is authoritative; this file is its design.

## Conventions

- Envelope, IDs and times as D1 ([public-api-v1](../../001-d01-foundation/contracts/public-api-v1.md)).
- **Device auth:** `Authorization: Device <token>` is required on `/v1/devices/me*` (missing, malformed or unknown → `401 unauthenticated`). The app also sends it on every other `/v1` request once it has a token; those routes ignore it except for rate limiting, and a bad token there is never an error, it just counts against the IP.
- **Caching:** every `/v1/devices*` response has `Cache-Control: no-store` and no `ETag`.

## Endpoints

| Method & path | Auth | Request | Response | Errors |
| --- | --- | --- | --- | --- |
| `POST /v1/devices` | none | `DeviceRegister` | `201` `DeviceRegistered` | `422 validation_error`, `429 rate_limited` |
| `PUT /v1/devices/me` | Device | `DeviceUpdate` | `200` `Device` | `401`, `422` (`validation_error`, `unknown_satellite`) |
| `PUT /v1/devices/me/follows` | Device | `FollowSet` | `200` `FollowSet` | `401`, `422` (`validation_error`, `unknown_follow_target`, `too_many_follows`) |
| `DELETE /v1/devices/me` | Device | — | `204` | `401` |

```jsonc
// DeviceRegister
{ "install_id": "6f1c0b8e-2d3a-4c8b-9f0e-1a2b3c4d5e6f", "platform": "android" }   // android | ios | web

// DeviceRegistered (201). The token is returned once; the server keeps only its hash.
{ "device_id": 812, "device_token": "Q2hhbmdlTWUtNDMtY2hhcnMtYmFzZTY0dXJsLXRva2Vu" }

// DeviceUpdate: every field optional; an omitted field is unchanged, null clears it.
{ "push_token": "fcm-token…",                      // ≤ 4096
  "app_version": "0.3.0+31",                       // ≤ 32
  "tz": "Africa/Cairo",                            // valid IANA name
  "locale": "ar-EG",                               // ≤ 16
  "satellite_ids": [3, 7],                         // ≤ 32 existing satellites
  "prefs": { "types": {
      "kickoff_reminder": { "on": true, "lead_min": 15 },   // lead_min ∈ {5, 15, 30, 60}; stored, honoured from D8
      "goal": { "on": true }, "final_score": { "on": true },
      "match_started": { "on": false }, "channels_updated": { "on": true },
      "frequency_changed": { "on": true }, "announcement": { "on": true } } } }

// Device (200): what the server stores, without the token or its hash.
{ "device_id": 812, "platform": "android", "app_version": "0.3.0+31", "tz": "Africa/Cairo", "locale": "ar-EG",
  "satellite_ids": [3, 7], "has_push_token": true, "prefs": { "types": { … all seven, defaults filled … } } }

// FollowSet (request and response). ≤ 500 ids in total; duplicates are collapsed.
{ "teams": [101, 205], "competitions": [12], "matches": [48213], "channels": [], "commentators": [] }
```

Error `meta`:

| `error.code` | `meta` |
| --- | --- |
| `unknown_follow_target` | `unknown: {teams: [...], competitions: [...], …}` (only the kinds with unknown ids) |
| `too_many_follows` | `max: 500` |
| `unknown_satellite` | `unknown: [ids]` |
| `rate_limited` | `retry_after_s` |

Behaviour:

- `POST /v1/devices` with a known `install_id` returns the same `device_id` and a **new** token; the old token stops working at once. Follows and settings are kept.
- `PUT /v1/devices/me` with a `push_token` held by another device moves it here (the other device's becomes null).
- `PUT /v1/devices/me/follows` is atomic: on any error nothing changes.
- `DELETE /v1/devices/me` removes the device and its follows; the token stops working.

## Rate limits (every `/v1` path except `/healthz`)

| Key | Limit |
| --- | --- |
| Device (requests whose `Authorization: Device` token belongs to an existing device) | 120 per minute |
| Client IP (everything else, including unknown or made-up tokens) | 600 per minute |
| `POST /v1/devices`, per IP | 30 per 10 minutes |

Over a limit: `429` with `Retry-After: <s>` and the envelope `{"success": false, "data": null, "error": {"code": "rate_limited", "message": "…"}, "meta": {"retry_after_s": 12}}`. The values are settings, not contract; the code and headers are.

## Response cache

No contract change: the same `ETag`, the same `304`, the same body. Reads are served from Redis until a dataset version they depend on is bumped ([research R10](../research.md#r10-the-response-cache)).

## Push message (FCM, not HTTP)

The app relies on these fields of a kickoff reminder ([research R8](../research.md#r8-the-kickoff-reminder-message)):

| Field | Value |
| --- | --- |
| `notification.title` | «‹home› × ‹away› بعد ‹N› دقيقة» (names FSI/PDI-isolated) |
| `notification.body` | «على ‹channel› · ‹satellite› — اضغط لعرض القنوات والترددات», or «اضغط لعرض القنوات والترددات» |
| `data.type` | `kickoff_reminder` |
| `data.match_id` | string id |
| `data.route` | `/match/<id>` (go_router path; native builds prepend `‹scheme›://`) |
| Android `tag` / `collapse_key` | `match_<id>`; notification channel id `reminders` |
| Web `tag`, `fcm_options.link` | `match_<id>`, `<pwa origin>/match/<id>` |
