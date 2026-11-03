# Local development

`infra/compose/dev.yml` runs PostgreSQL 16, Redis 7 and an HTTPS Caddy on your machine, for the backend and for the app's `dev` flavor. Everything listens on `127.0.0.1`, with the fake values from `infra/compose/example.env`. It touches no server. Background: research R16, and `specs/001-d01-foundation/quickstart.md` "Lane B1".

## Start it

From the repository root:

```bash
docker compose -f infra/compose/dev.yml up -d postgres redis caddy
docker compose -f infra/compose/dev.yml ps          # all three healthy
```

From `backend/`, the same file is `../infra/compose/dev.yml`.

| Service | Address | Credentials |
| --- | --- | --- |
| PostgreSQL 16 | `127.0.0.1:5434` | User `madar`, password `changeme`, database `madar`. The user is the container's superuser. |
| Redis 7 | `127.0.0.1:6380` | Password `changeme` |
| Caddy | `https://localhost:8443` | `tls internal`, proxying to the API on your machine at port 8000 |

To move the ports, set `DEV_POSTGRES_PORT` or `DEV_REDIS_PORT` in your shell when you run `docker compose`. The values in `example.env` aren't read for that: `dev.yml` uses the file only as the containers' environment.

## Run the backend against it

B1's settings come only from the environment; there is no `.env` loading. Export these in the shell you run the backend from:

```bash
export DATABASE_URL=postgresql+asyncpg://madar:changeme@localhost:5434/madar
export DATABASE_URL_SYNC=postgresql+psycopg://madar:changeme@localhost:5434/madar
export REDIS_URL=redis://:changeme@localhost:6380/0
export MEDIA_BASE_URL=https://localhost:8443/media
export MEDIA_ROOT=./.media
export MEDIA_REHOST_ALLOWED_HOSTS=<the old app's media hosts>
export CORS_ORIGINS=https://localhost:8443

cd backend
uv run alembic upgrade head
uv run uvicorn app.public:app --host 172.17.0.1 --port 8000
```

- `172.17.0.1` is Docker's `docker0` address on Linux. The dev Caddy reaches the host through it (`host.docker.internal:host-gateway`), and it keeps the API off your LAN. Check yours with `ip -4 addr show docker0`.
- Local media isn't served: `MEDIA_BASE_URL` only shapes the URLs in responses.

The admin API is a second app, and it also needs a signing key of at least 32 bytes (it refuses to start without one) and an account to sign in with ([staff-accounts.md](staff-accounts.md)). Locally any value will do:

```bash
export ADMIN_JWT_SECRET=$(openssl rand -hex 32)
uv run python -m app.cli create-admin --email you@example.com --name "اسمك" --role admin   # asks for the password twice
uv run uvicorn app.admin:app --host 172.17.0.1 --port 8001
```

```bash
curl -s --cacert root.crt https://localhost:8443/healthz | jq .data     # after "The local CA" below
```

## Tests

B1's tests create and drop their own databases through `TEST_DATABASE_URL`. Its default in `backend/tests/conftest.py` expects a `postgres` superuser on port 5434, and Redis on port 6380 **without** a password. `dev.yml` has neither: its superuser is `madar`, and its Redis requires `changeme`. Until B1 changes the defaults or the two are aligned, set them:

```bash
export TEST_DATABASE_URL=postgresql://madar:changeme@localhost:5434/madar
export TEST_REDIS_URL=redis://:changeme@localhost:6380/0
cd backend && uv run pytest
```

If `REDIS_URL` is already exported (from "Run the backend" above), the tests use it instead of `TEST_REDIS_URL`. CI sets its own values in `backend.yml`.

## The app's `dev` flavor

The `dev` flavor calls `https://localhost:8443` (research R16):

- **Emulator or phone:** `adb reverse tcp:8443 tcp:8443`, so the device's `localhost:8443` reaches your machine.
- **The local CA:** the dev Caddy signs with its own root, which no device trusts. Copy it out:

  ```bash
  docker compose -f infra/compose/dev.yml cp caddy:/data/caddy/pki/authorities/local/root.crt ./root.crt
  ```

  - **Android or a phone (Dart over `dart:io`):** Android's `network_security_config.xml`
    and the phone's user certificates do not reach the app's API calls, so a debug build
    takes the root from a dart-define instead:

    ```bash
    flutter run -t lib/main_dev.dart --dart-define-from-file=env/dev.json \
      --dart-define=DEV_CA_PATH="$PWD/root.crt" --flavor dev
    ```

    `DEV_CA_PATH` is read by debug native builds only: a release build and any web build
    ignore it (`app/lib/core/network/dev_ca.dart`). A wrong path fails the first request
    with a message naming the file instead of a silent handshake error. `flutter test` and
    `flutter build` need no dart-define.
  - **A desktop browser:** trust it as in [private-network.md "Install the admin CA root"](private-network.md#install-the-admin-ca-root), or pass `--cacert root.crt` to `curl`.

## Reset

```bash
docker compose -f infra/compose/dev.yml down -v
```

This deletes the local database and Caddy's data. The next start makes a **new** local root, so copy `root.crt` to the app again.

## Troubleshooting

- **`port is already allocated`:** something else uses 5434, 6380 or 8443. Move it with `DEV_POSTGRES_PORT` or `DEV_REDIS_PORT`. 8443 is fixed in `dev.yml`.
- **`https://localhost:8443` answers 502:** the API isn't listening where Caddy looks. Start it on `172.17.0.1:8000`, not `127.0.0.1`.
- **Still 502 with the API on `172.17.0.1:8000`:** a host firewall drops traffic from the compose network. Check from the container with `docker compose -f infra/compose/dev.yml exec -T caddy wget -T 5 -qO- http://host.docker.internal:8000/healthz`; a timeout means the firewall. With `ufw`, allow that bridge only (find it with `docker network inspect madar-dev_default --format '{{.Id}} {{range .IPAM.Config}}{{.Subnet}}{{end}}'`; the bridge is `br-` plus the first 12 characters of the id): `sudo ufw allow in on br-<id12> from <subnet> to 172.17.0.1 port 8000 proto tcp comment 'madar dev caddy to api'`.
- **`password authentication failed`:** an older `madar-dev_pgdata` volume was created with other credentials. `down -v` and start again.
