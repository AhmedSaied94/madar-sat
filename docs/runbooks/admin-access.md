# Admin access from a machine

How an editor gets the admin app (A1–A4) running on their own machine against the deployed admin API,
instead of the Prism mock. It is the walk-through T107 step 3 uses and the one a new editor follows
after their account exists ([staff-accounts.md](staff-accounts.md)). Background: research R23, R24,
FR-030, FR-031; the app is `admin/`, the API is `app.admin:app` on `10.8.0.1:8001` behind Caddy.

The admin API is reachable **only over WireGuard** and the browser only ever talks to `localhost`, so
no CORS rule exists anywhere and the session cookies stay host-only.

## What the machine needs

| Item | Where it comes from |
| --- | --- |
| A WireGuard peer that routes `10.8.0.1/32` | [private-network.md "Peers"](private-network.md#peers); the owner adds one peer per editor |
| Caddy's root CA (`~/.config/madar/caddy-root.crt`) | [private-network.md "Install the admin CA root"](private-network.md#install-the-admin-ca-root) |
| Node ≥ 22.12 and pnpm 10 | `admin/package.json` (`packageManager`) |
| An admin account (`editor` unless the owner made you `admin`) | [staff-accounts.md](staff-accounts.md) |

Put the CA where `NODE_EXTRA_CA_CERTS` expects it. Caddy keeps its root inside the container, so fetch it
through VPS-1 (the command from [private-network.md "Install the admin CA root"](private-network.md#install-the-admin-ca-root)):

```bash
mkdir -p ~/.config/madar
ssh ubuntu@10.8.0.1 sudo docker exec madar-caddy-1 cat /data/caddy/pki/authorities/local/root.crt \
  > ~/.config/madar/caddy-root.crt
openssl x509 -in ~/.config/madar/caddy-root.crt -noout -subject
```

## Run it against the deployed API

```bash
cd admin
pnpm install --frozen-lockfile
NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt pnpm dev:wg
```

`dev:wg` is `vite --mode wg`: `/admin/api` is proxied to `https://10.8.0.1` with `secure: true` and
`changeOrigin: true`, so Caddy sees its own site address (`https://10.8.0.1`) in the `Host` header
instead of `localhost:5173` (A-R2-13; the T107 walk re-checks it end to end). Node trusts that host
through the CA file above. Open `http://localhost:5173`. Signing in lands on `/` («هذا القسم قيد
البناء»), because the login route only returns to a `from` page when the guard sent you there; open
«المباريات» (A3) from the sidebar.

Check the tunnel and the API before blaming the app:

```bash
sudo wg show                                   # a handshake within the last two minutes
curl -s --cacert ~/.config/madar/caddy-root.crt https://10.8.0.1/admin/api/healthz | jq .data
# {"db": "ok", "redis": "ok"}
```

## Run it against the mock

No WireGuard, no account: Prism serves the committed contract and answers with the spec's named
examples.

```bash
cd admin
pnpm prism        # :4010, from ../backend/openapi/admin.json
pnpm dev          # :5173, /admin/api proxied to Prism
```

In dev builds `?mock=<example>` asks Prism for one named example, and the status that example lives on.
The `Prefer` header goes on the request the operation makes, so a save's example is asked for from the
match page that saves (a `PATCH /admin/api/matches/{id}`), never from the list. The D2 screens use:

| URL | What it shows |
| --- | --- |
| `/login?mock=invalid_credentials` | «إيميل أو باسوورد غلط» |
| `/login?mock=account_locked` | the lockout panel with its countdown |
| `/matches/48213?mock=edit_conflict` | saving A4 answers `409` and opens `ConflictDialog` |
| `/matches/48213?mock=edit_conflict_source` | the same dialog for a save by a source |
| `/matches/48213?mock=precondition_required` | `428` on save: reload the page, then save again |
| `/matches?mock=forbidden_remove_channels` | the bulk removal refused for an editor |

Each example needs the page's own request to Prism to match an operation the spec gives that example;
`/matches/48213` works with Prism because it answers the detail `GET` from the same spec.

## When it doesn't work

- **`fetch failed` or `ECONNREFUSED` on `/admin/api`:** WireGuard is down. `sudo wg show`; bring the
  tunnel up with `wg-quick up wg0` (or the NetworkManager profile), then reload.
- **`unable to verify the first certificate` / `SELF_SIGNED_CERT_IN_CHAIN`:** `NODE_EXTRA_CA_CERTS` is
  missing from the command, points at a file that isn't Caddy's root, or Caddy was rebuilt and made a
  new root ([private-network.md "Install the admin CA root"](private-network.md#install-the-admin-ca-root)).
- **The browser warns about the certificate:** the browser is talking to `https://10.8.0.1` directly
  instead of through the proxy. Use `localhost:5173`.
- **`401 unauthenticated` after a reload:** the refresh cookie is gone (a private window, or a host
  change); sign in again.
- **`403 forbidden` on a bulk removal:** the account is `editor`; only `admin` may remove channels.
- **`pnpm dev:wg` still answers from Prism:** the `wg` mode is in `vite.config.ts` and selected by
  `--mode wg`; check that the script is `vite --mode wg`.

## After a change to the contract

`backend/openapi/admin.json` belongs to Lane B1. After B1's change lands:

```bash
cd admin
pnpm orval && git diff --exit-code src/api/generated/   # the committed client must match the spec
```

The check fails when the generated client is stale, which is what `backend.yml`'s `clients` job runs.
