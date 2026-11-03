# Contract: the admin smoke test (Lane A)

## Flow

1. Open `/login` and sign in with `E2E_EMAIL` / `E2E_PASSWORD`.
2. Open A3. In live mode, set the date input (`copy.pickDate`) to `E2E_MATCH_DATE` (default `2000-01-01`).
3. Find the match row:
   - **live:** exactly one row whose stadium starts with `E2E_MATCH_MARKER`; zero or more than one aborts the test before any edit;
   - **mock:** the first row.
4. Open A4. Set `stadium` to `<marker> <run id>` (run id = UTC timestamp) and save. Expect the success toast and no conflict dialog.
5. **Live only:** poll `GET ${E2E_PUBLIC_API}/v1/matches/<id>` every 5 s until `data.stadium` equals the new value. Fail after 60 s and report the elapsed time either way (feeds SC-004).

## Environment

| Variable | Mode | Notes |
|---|---|---|
| `E2E_TARGET` | both | `mock` (default) or `live` |
| `E2E_BASE_URL` | live | `https://10.8.0.1` |
| `E2E_EMAIL`, `E2E_PASSWORD` | live | An `editor` account created with `create-admin` (`docs/runbooks/staff-accounts.md`); never in the repo |
| `E2E_MATCH_MARKER` | live | For example `MADAR-E2E` |
| `E2E_MATCH_DATE` | live | Default `2000-01-01` |
| `E2E_PUBLIC_API` | live | `https://api.<ip1>.sslip.io` |
| `NODE_EXTRA_CA_CERTS` | live | The Caddy internal root (`~/.config/madar/caddy-root.crt`, `admin-access.md`); the test never sets `ignoreHTTPSErrors` |

## Rules

- The test never deletes, never edits another match, and never touches teams, channels or sources.
- In live mode it runs from a WireGuard peer only. CI runs mock mode only.
- Mock mode checks the UI flow and the `If-Match` header on the save; it can't check `/v1`.
- The test match is created once by the owner: in A4, 2000-01-01, two existing teams, stadium `<marker>`. Nobody follows it, so it triggers no reminder.
