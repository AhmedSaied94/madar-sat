# Contract: admin API changes

Lane B1 owns these, under `/admin/api` on `wg0` only. All use the standard envelope, are documented in the admin OpenAPI document with examples, and have contract tests on PostgreSQL. Mutations write `audit_log`. Lists use `meta.next_cursor`, with a page size of 50.

Every `GET` returns an `ETag` (constitution VI). Those without one named below use a dataset and a 30 s bucket: `admin_users` for users, `channels` for frequency history, and `outbox` for reach (`ETag("admin_reach", ("outbox",), bucket_s=30)`), which moves on the bucket because devices don't bump a dataset. The test device's `GET` returns its entity version, as a single channel's does, so that `PUT` has something to send.

## Roles

| Route | `editor` | `admin` |
|---|---|---|
| `GET notifications` | Yes | Yes |
| `GET channels/{id}/frequency-changes` | Yes | Yes |
| `POST auth/change-password` | Yes | Yes |
| Everything else here | `403 forbidden` | Yes |

### `password_change_required`

While `admin_users.must_change_password` is true, `require_role` refuses with `403 password_change_required`, so every route using it is covered. `auth/me` uses `require_editor` today, so it moves to a new `require_signed_in = require_role("editor", allow_flagged=True)` in `auth/roles.py`. That keeps the authentication, the `is_active` check and the role check, and sets `required_role` for the route-walking test, and skips only the flag (constitution V). `auth/change-password` uses it too. `EXEMPT_PREFIXES` in `test_admin_routes_have_roles.py` skips all of `auth/`, so the test gains an explicit check on these two. Login, refresh and logout don't use a role dependency, so they keep working. `auth/refresh` must stay exempt, because a `403` on refresh ends the admin's session.

`AdminUser` and `Session` gain `must_change_password: bool`.

## Notifications

### `GET notifications`

Query: `type`, `status`, `cursor`, `limit`. ETag: `ETag("admin_notifications", ("outbox",), bucket_s=15)`. Newest first by `created_at`, `id`.

```json
{
  "id": 9012, "type": "goal", "status": "sent", "error": null,
  "target": { "kind": "match_core", "label": "الأهلي × الزمالك", "id": 48213 },
  "is_test": false, "is_correction": false,
  "recipients": 2410, "sent": 2398, "failed": 12,
  "due_at": "2026-11-06T18:40:00Z", "sent_at": "2026-11-06T18:40:09Z", "created_at": "2026-11-06T18:40:00Z"
}
```

- `recipients` is `sent + failed` once sending has begun. A pending row shows the live count from the reach query.
- `label` is built from current data, and is `null` for `all`. The client's copy supplies «جميع الأجهزة».
- `error` is one of `late`, `match_finished`, `score_fell`, `no_net_change`, `type_off`, `admin`, or the push service's text, such as `FCM 503`.
- `is_test` is `audience.kind = device`, and `is_correction` is `payload.kind = correction`.

The outbox producers don't bump a dataset for each row, since a goal night would invalidate every cache. The 15 s bucket is what brings new rows, with the client's 30 s `refetchInterval`.

### `GET notifications/reach`

Query: `kind` (`all`, `team`, `competition`, `match`, `channel`), `id`. Returns `{ "devices": 41230 }`, using the audience's conditions with type `announcement`.

### `POST notifications/announcements`

```json
{
  "title": "...", "body": "...",
  "target": { "type": "match", "id": 48213 },
  "audience": { "kind": "all", "id": null },
  "send_at": null
}
```

| Field | Rule |
|---|---|
| `title` | 1–65 characters, plain text, `find_card_sharing_label` passes |
| `body` | 1–180 characters, same |
| `target.type` | `none`, `match` or `channel`. The server builds the route, and never takes one as text |
| `audience.kind` | `all`, `team`, `competition`, `match`, `channel`. `match` maps to `match_core` |
| `send_at` | Null means now. Must be in the future, sent in UTC |

Returns `201` and the row. Errors: `422 validation_error`, `422 send_at_in_past`, `422 text_not_allowed`, `404` for an unknown target or audience ID. The dedupe key is `announcement:<uuid>`, one per request.

### `POST notifications/{id}/cancel`

`If-Match` required. Only a `pending` `announcement` that isn't a test. Otherwise `409 notification_not_cancellable`. Sets `status = cancelled` and `error = admin`.

### `POST notifications/test`

Same `title`, `body` and `target` as an announcement. It goes to the admin's saved test device through the outbox, with `audience.kind = device`. Errors: `422 test_device_not_set`, `422 test_device_no_token`.

### `GET` and `PUT notifications/test-device`

`PUT` takes `{ "device_id": 812 }`, with `404 device_not_found`. Both return:

```json
{ "device_id": 812, "platform": "android", "app_version": "0.6.0+60", "has_push_token": true }
```

`GET` returns `data: null` when none is saved, still with its `ETag`. Only an account's own device is read or set. `PUT` requires `If-Match` (constitution VI), checked with `lock_and_check` on the caller's row: `428` without it and `409 edit_conflict` when stale. The version hashes only `test_device_id`, so a login doesn't make it stale. `PUT` writes `audit_log`, bumps `admin_users`, and returns the new `ETag`.

## Users

The account list is small, so `GET users` has no cursor.

| Route | Body | Response |
|---|---|---|
| `GET users` | | `AdminUserRow[]` |
| `POST users` | `{ "email", "name", "role" }` | `201`, `{ "user": AdminUserRow, "temporary_password": "..." }` |
| `PATCH users/{id}` | Any of `name`, `role`, `is_active`. `If-Match` | `AdminUserRow` |
| `POST users/{id}/reset-password` | `If-Match` | `{ "user": AdminUserRow, "temporary_password": "..." }` |

```json
{
  "id": 3, "email": "x@example.com", "name": "...", "role": "editor", "is_active": true,
  "locked_for_s": 660, "last_login_at": "2026-11-06T09:12:00Z", "must_change_password": false
}
```

- `locked_for_s` is the TTL of `auth:locked:<h>`, or null ([R19](../research.md#r19-admin-accounts)).
- A response with `temporary_password` carries `Cache-Control: no-store`. The password is at least 12 characters from `secrets` and stored as argon2id only. It's never logged, and never in `audit_log`.
- `role` changes an account's role, and `is_active: true` reactivates it, which needs a new login since its tokens were revoked.
- `is_active: false` and reset revoke every refresh token. `require_role` already reads the account per request, so the next request is refused.
- Errors: `409 email_taken`; `409 cannot_change_self` for deactivating or demoting yourself; `409 last_admin` for the last active admin.

**The writer.** `versions.row_state` hashes every column and `save_update` diffs it, so this service passes an explicit state, `{email, name, role, is_active}`. A test asserts that no audit row, response or log line from these routes contains `password_hash` or a temporary password. Reset's diff is `{"password": "changed"}`, the shape the CLI already writes.

### `POST auth/change-password`

`{ "current_password", "new_password" }`. New is at least 12 characters and differs from the current one. On success it clears the flag, revokes the account's other refresh tokens, keeps this session, and returns `Session`. Errors: `401 invalid_credentials`, `422 password_too_short`, `422 password_unchanged`. It counts failures through the login limiter. It writes `audit_log` with `{"password": "changed"}` and bumps `admin_users`. It takes no `If-Match`, because the current password is the check ([plan](../plan.md#complexity-tracking)). Neither password reaches a log, a response or an audit row.

## Audit

### `GET audit`

Query: `admin_user_id` or `source`, `entity`, `entity_id`, `from`, `to`, `cursor`, `limit`. Newest first. ETag: content datasets with `bucket_s=30`. Uses the existing `(entity, entity_id, created_at)` and `(admin_user_id, created_at)` indexes.

```json
{
  "id": 7711, "created_at": "2026-11-06T17:00:00Z",
  "actor": { "kind": "admin", "id": 3, "name": "..." },
  "entity": "channel", "entity_id": 412, "action": "update",
  "summary_fields": ["frequency_mhz"], "has_notification": true
}
```

`actor.kind` is `admin`, `importer` or `system`, for a CLI action with neither. `name` is null for `system`.

### `GET audit/{id}`

The row, plus `diff` exactly as stored, and:

```json
"notification": { "id": 9012, "type": "frequency_changed", "status": "sent", "sent": 118, "failed": 0 }
```

`notification` is the outbox row with this `audit_log_id`, or null. The endpoints are read-only (FR-026).

## Channel history

`GET channels/{id}/frequency-changes` returns the newest 100, with no cursor, because a channel's history is short:

```json
{ "id": 55, "old": "11766 H 27500", "new": "11843 H 27500", "source": "admin", "actor": "...", "detected_at": "..." }
```

`actor` comes from the row's own `audit_log_id`, not the outbox row, which is pruned after 30 days. It's null for an importer.

## Changed schemas

| Schema | Change |
|---|---|
| `locked_fields` | `broadcasts` can appear. `matches.py` adds it when A4 saves slots |
| `ImportRunRow.status` | Adds `stopped`, with the reason in `error` |
| `AdminUser`, `Session` | `must_change_password` |

## New error codes

`password_change_required`, `notification_not_cancellable`, `send_at_in_past`, `text_not_allowed`, `test_device_not_set`, `test_device_no_token`, `device_not_found`, `email_taken`, `cannot_change_self`, `last_admin`, `password_too_short`, `password_unchanged`.

Each is added to `ErrorCode` and `errorCopy` in Lane A's `ar.ts`.
