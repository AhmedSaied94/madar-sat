# Contract: public API changes

Lane B1 owns these, and every change is additive (constitution VI). `oasdiff` must report nothing breaking for builds at or above `min_supported_build`. The envelope, auth and caching stay as they are.

| Endpoint | Change | Who it affects |
|---|---|---|
| `GET /v1/matches` | With no `sport`, returns football only. With `sport`, returns that sport | Every build sends no `sport`, so old builds keep today's data |
| `GET /v1/live` | Football only, through `live_window_query` | Scheduler, poller and watchdog too |
| `GET /v1/live` | `LiveState` gains `event_count: int` | Old builds ignore it |
| `GET /v1/channels/{id}` | `recent_frequency_changes` filled, last 5, newest first | S6 |
| `GET /v1/channels` and any field carrying `frequency_changed_at` | Now set when a hold ends | S5.2 badge |
| `PUT /v1/devices/me` | `prefs` accepts `enabled` | New builds only |

## `event_count`

The count of `match_events` rows from the source `match_detail` serves (`EVENT_SOURCES`), read through `live_window_query`. It's the same number the timeline would show, so a change in it means the timeline changed. It needs no new index, because the live window is at most about 30 matches.

```json
{ "match_id": 48213, "status": "live", "estimated": false, "period": "2H", "minute": "67′",
  "score": { "home": 2, "away": 1 }, "event_count": 4, "status_label": null,
  "status_updated_at": "2026-11-06T18:42:10Z" }
```

An estimated state gives `event_count: 0`, alongside its null score and minute.

## `recent_frequency_changes`

The shape already exists as `FrequencyChange`, and only the value changes from `[]`. It reads `channel_frequency_changes`, so it holds only what followers were told.

```json
{ "old": "11766 H 27500", "new": "11843 H 27500", "detected_at": "2026-11-06T17:05:00Z" }
```

Writing a history row bumps the channel datasets, so `ETag` changes when it appears, as SC-005 needs.

## `NotificationPrefs`

```json
{ "enabled": true, "types": { "goal": { "on": false } } }
```

- `enabled` is optional and defaults to true. `extra="forbid"` stays.
- `with_defaults` reads `enabled` on its own, so it never falls into the flat-document fallback.
- A response always includes `enabled` and every type, with its SD §6.8 default.

**After a backend rollback,** the old release's `extra="forbid"` refuses a new build's `enabled` with `422`. The app's dirty flag keeps it pending, and it reaches the server once the release returns. Other device fields are held back in that gap too, which `deploy-and-rollback.md` must say.

## Routes and tags

A route in `data.route` is one of these exact shapes:

| Route | Opens |
|---|---|
| `/` | S1 |
| `/match/<id>` | S3 |
| `/match/<id>?section=channels` | S3, at its channels |
| `/channel/<id>` | S6 |

Old builds ignore the query string and show S3 from the top. They drop `/channel/<id>`, which opens the app on its current screen, and that's safe.
