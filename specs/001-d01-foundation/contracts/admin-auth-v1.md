# Contract: admin auth shapes (`/admin/api/auth`, D1 declaration)

Part of `app.admin:app`, exported as `backend/openapi/admin.json` and tagged `contract-v1` with the public spec.

On D1 these routes exist only to fix their shapes:

- every handler answers `501` with `error.code = "not_implemented"` in the envelope;
- D2 implements them without changing any request, response, header or error code (spec FR-013).

The admin API is reachable only over WireGuard (constitution V): its container is published on the `wg0` address `10.8.0.1:8001`, and clients use the `wg0` Caddy site at `https://10.8.0.1/admin/api`. It uses the same envelope and error conventions as [public-api-v1.md](public-api-v1.md).

Sources: SD §5.4, §6.5, PB §10 A1, the admin Login board, constitution V.

## Shapes

```jsonc
// AdminUser
{ "id": 3, "email": "editor@example.com", "name": "…", "role": "editor" }   // role ∈ editor | admin

// Session (data of login and refresh)
{ "access_token": "<JWT>", "token_type": "Bearer", "expires_in": 900, "admin": AdminUser }
```

## Cookies

| Cookie | Attributes | Purpose |
| --- | --- | --- |
| `madar_refresh` | `HttpOnly; Secure; SameSite=Strict; Path=/admin/api/auth; Max-Age=1209600` | Opaque refresh token. It rotates on every use and is stored server-side only as a hash |
| `madar_csrf` | `Secure; SameSite=Strict; Path=/; Max-Age=1209600` (readable by JS) | CSRF value. Refresh and logout must echo it in `X-CSRF-Token` |

The access token lives only in memory in the admin app, never in `localStorage` or `sessionStorage` (spec FR-034).

## Endpoints

### `POST /admin/api/auth/login`

- **Request:** `{ "email": string (email, ≤ 254), "password": string (1–256) }`.

| Status | `error.code` | `data` / `meta` | Prism example name |
| --- | --- | --- | --- |
| 200 | — | `Session`; sets both cookies | `login_ok` |
| 401 | `invalid_credentials` | `meta.attempts_remaining: int` (0–4) | `invalid_credentials` (`attempts_remaining: 3`) |
| 429 | `account_locked` | `meta.retry_after_s: int`; `Retry-After` header | `account_locked` (`retry_after_s: 872`, shown as «14:32») |
| 422 | `validation_error` | `meta.errors` | `validation_error` |

- **Counting:** attempts are counted per email + client IP, whether or not the account exists, so the responses don't reveal which emails are registered. The limit is 5 attempts per 15 minutes, then a temporary lockout (SD §6.5).
- **Copy:** the client renders the A1 board text from these codes:
  - «إيميل أو باسوورد غلط» with «تبقّت N محاولات قبل الإيقاف المؤقت»;
  - «تم إيقاف الدخول مؤقتاً … حاول مرة أخرى بعد mm:ss دقيقة أو تواصل مع المدير».

### `POST /admin/api/auth/refresh`

- **Request:** no body. It needs the `madar_refresh` cookie, plus an `X-CSRF-Token` header equal to the `madar_csrf` cookie.

| Status | `error.code` | Notes |
| --- | --- | --- |
| 200 | — | `Session`; rotates both cookies |
| 401 | `refresh_invalid` | Expired, revoked or reused. Reuse revokes the whole token family |
| 403 | `csrf_failed` | Header missing or mismatched |

### `POST /admin/api/auth/logout`

- **Request:** no body; needs the cookie and `X-CSRF-Token`.
- **Response:** `200` with `data: null`. The refresh token is revoked and both cookies are cleared.
- **Errors:** `403 csrf_failed`.

### `GET /admin/api/auth/me`

- **Request:** `Authorization: Bearer <access_token>`.

| Status | `error.code` |
| --- | --- |
| 200 | — (`data: AdminUser`) |
| 401 | `unauthenticated` (no token or a bad one) or `token_expired` |

### `GET /admin/api/healthz`

Same shape as the public `/healthz`.

## Prism usage (Lane A)

```sh
npx @stoplight/prism-cli mock backend/openapi/admin.json --port 4010
curl -s -X POST localhost:4010/admin/api/auth/login -H 'Prefer: example=account_locked' \
     -H 'Content-Type: application/json' -d '{"email":"a@b.co","password":"x"}'
```

In dev builds, the admin app adds `Prefer: example=<name>` when the page URL has `?mock=<name>` ([research R15](../research.md#r15-tokens-fonts-and-the-generated-client)).
