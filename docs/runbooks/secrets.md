# Secrets

Where each secret lives, how to rotate it, and what to do when one leaks or gitleaks fails a PR. Rotations touch production. Background: constitution V, SD §8, research R14, and `.gitleaks.toml`.

The rules:

- No secret ever goes into the repository, a chat, an email or an issue. `gitleaks.yml` scans the whole history on every push and PR.
- Generate secrets where they're used: passwords on the VM (`openssl rand -hex 32`), keys on the machine that holds them.
- Put GitHub secrets in from a file or a pipe (`gh secret set <NAME> -R AhmedSaied94/madar-sat < <file>`), then `shred -u` the file.

## Where they live

| Secret | Lives in | Used by | Rotate |
| --- | --- | --- | --- |
| `POSTGRES_PASSWORD` | `/srv/madar/.env` on **both** VMs, and inside `DATABASE_URL` and `DATABASE_URL_SYNC` | PostgreSQL, the APIs, `migrate`, `cli`, the workers | [Below](#rotate-the-postgresql-password) |
| `REDIS_PASSWORD` | Both `.env` files, and inside `REDIS_URL` and `CELERY_BROKER_URL`; one line of the rendered `/srv/madar/redis/users.acl` (`default` user) | Redis, the APIs, the workers | [Below](#rotate-the-redis-password) |
| `REDIS_HOMEBOX_PASSWORD` | VPS-1's `.env` and the home box's `.env`; the `homebox` line of the rendered `/srv/madar/redis/users.acl` | The home box's worker, as the `homebox` Redis user | [Below](#rotate-the-home-box-redis-password) |
| `ADMIN_JWT_SECRET` | VPS-1's `.env` only; at least 32 bytes. Every VPS-1 container loads that file, so the other services can read it, but only `api-admin` uses it (it refuses to start without it). VPS-2 never needs it. | `api-admin` | [Below](#rotate-the-admin-jwt-secret) |
| `SATAIR_FIREBASE_PROJECT_ID`, `SATAIR_FIREBASE_API_KEY` | VPS-2's `.env` only; never in the repo, a log line or a test (D15, FR-052) | The Firestore bridge | [Below](#rotate-the-sat-air-bridge-credentials) |
| `GHCR_READ_TOKEN` | The home box's `.env` | `home-box-update.sh` (read-only `read:packages`) | [Below](#rotate-the-home-boxs-ghcr-token) |
| `SCRAPE_USER_AGENT` | VPS-2's and the home box's `.env` | The fetcher's `User-Agent`; not a secret, but keep it a real contact | Edit it and recreate the workers |
| FCM service account JSON | VPS-2 only: `/srv/secrets/fcm.json`, mode 600, owned by uid 10001 (the image's user), in a directory 700 owned by the same uid; mounted read-only into `worker-notify` and no other service. `FCM_CREDENTIALS_FILE` in `/srv/madar/.env` points at it. Installed as root, once: [push-notifications.md](push-notifications.md#the-fcm-service-account) | `firebase_admin` in the notifications worker | [Below](#rotate-the-fcm-service-account) |
| `FLOWER_BASIC_AUTH` | VPS-2's `.env` | Flower (from D3) | Edit it, then recreate `flower` |
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | VPS-2's `.env` only | The importer alerts ([source-alerts.md](source-alerts.md)) and Uptime Kuma's notifications | [Below](#rotate-the-telegram-bot) |
| `API_FOOTBALL_KEY` | VPS-2's `.env` only, read by `worker-scrape`. Never in the repo, a log line, a raw page or `import_runs.log` | The API-Football adapter (D6, FR-034) | [Below](#rotate-the-api-football-key) |
| `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY` | Both VMs' `.env` (the database backup runs on VPS-2, the weekly media snapshot on VPS-1) | `backup-db.sh`, `backup-media.sh` ([backups.md](backups.md)) | [Below](#rotate-the-backup-keys) |
| `RCLONE_CONFIG_OCI_*` (`_TYPE=s3`, `_ACCESS_KEY_ID`, `_SECRET_ACCESS_KEY`, `_ENDPOINT`, `_REGION`) | VPS-1's `.env` only | The nightly media mirror | [Below](#rotate-the-backup-keys) |
| `KUMA_PUSH_URL_*` (six) | VPS-2's `.env` (`_MAINTENANCE`, `_IMPORTS`, `_NOTIFICATIONS`, `_BACKUP_DB`) and VPS-1's (`_BACKUP_MEDIA`, `_BACKUP_MEDIA_WEEKLY`) | `ops.heartbeat` and the backup scripts ([uptime-kuma.md](uptime-kuma.md)) | Recreate the monitor in Kuma and replace the value; they are not secrets, but they are bearer URLs |
| `DEPLOY_SSH_KEY` | GitHub secret. The public half is in VPS-1's `.env` and in `/home/deploy/.ssh/authorized_keys`. | `backend.yml` deploy, `infra.yml` sync | [deploy-and-rollback.md "Replacing a deploy key"](deploy-and-rollback.md#replacing-a-deploy-key) |
| `WG_CI_CONFIG` | GitHub secret; the peer `ci` in VPS-1's `wg0.conf` | The same jobs | [private-network.md "Rotate the CI peer"](private-network.md#rotate-the-ci-peer) |
| WireGuard device keys | Each device; its peer in `wg0.conf` | You | [private-network.md "Remove a peer"](private-network.md#remove-a-peer), then add it again |
| WireGuard hub key | `/etc/wireguard/wg0.key` on VPS-1 | `wg0` | [break-glass.md "Re-key the hub"](break-glass.md#re-key-the-hub-key-lost-or-exposed) |
| `FIREBASE_SERVICE_ACCOUNT` | GitHub secret | `pwa.yml` | [Below](#rotate-the-firebase-service-account-key) |
| `APP_ENV_PROD` | GitHub secret: the whole `app/env/prod.json` (the API and media hosts, the privacy and share links, the Firebase identifiers and the VAPID public key). Public values, kept out of the repo by choice; the flavor files are git-ignored and live on the machines that build. | `app.yml`, `pwa.yml`, `app-release.yml`, through `app/tool/write_env.sh` | [Below](#update-the-apps-flavor-values) |
| Android upload keystore | `~/.config/madar-sat/upload-keystore.jks` and `keystore-password` on the owner's machine (mode 600), **backed up in the owner's password manager**. GitHub secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`), `ANDROID_KEY_PASSWORD`. | `app-release.yml` (tag `app-v*`) | [Below](#rotate-the-android-upload-key) |
| `ubuntu` console passwords | Your password manager, one per VM | The serial console | `sudo passwd ubuntu`, then test the console again ([provision-host.md §2](provision-host.md#2-console-password-then-test-the-serial-console)) |
| Caddy's internal CA key | VPS-1's `madar_caddy_data` volume | The admin site's certificates | Only by letting Caddy make a new CA, which means a new root on every admin device |
| `GITHUB_TOKEN` | Created per job, expires when the job ends | GHCR push and pull | Nothing to rotate. `deploy.sh` logs out of GHCR on exit. |

Also set on the hosts, and **not** secrets: `FCM_CREDENTIALS_FILE` (the path `/srv/secrets/fcm.json`, not the file), `FCM_DRY_RUN` (VPS-2), `PWA_ORIGIN` (VPS-2), `RESPONSE_CACHE_ENABLED`, `RESPONSE_CACHE_MAX_BYTES`, `RATE_LIMIT_DEVICE_PER_MIN`, `RATE_LIMIT_IP_PER_MIN`, `RATE_LIMIT_REGISTER_PER_10MIN` (VPS-1). They live in the same `.env` and are documented in [push-notifications.md](push-notifications.md) and [response-cache-and-limits.md](response-cache-and-limits.md).

Not secrets: the public and private IPs, the hostnames, the Firebase project ID, the WireGuard hub's public key, and `DEPLOY_KNOWN_HOSTS` (VPS-1's public host key, kept as a secret only for convenience).

## `PUSH_TYPES_OFF` is a setting, not a secret

`PUSH_TYPES_OFF=goal,match_started` in VPS-2's `/srv/madar/.env` is a plain list of notification types
to stop sending, so it does not belong in `/srv/secrets` and is not rotated. Recreating `worker-notify`
(`dc up -d worker-notify`) applies it; see [push-notifications.md](push-notifications.md#the-off-switch-under-a-minute).

## Rotate the PostgreSQL password

`POSTGRES_PASSWORD` only takes effect when the data volume is first created. Changing the `.env` alone breaks every client, so change it in the database first. In the "Working on VPS-1" shell ([deploy-and-rollback.md](deploy-and-rollback.md#working-on-vps-1)):

1. Make a new password: `openssl rand -hex 32`.
2. Set it in PostgreSQL. `\password` prompts for it, so it never reaches the shell history or the logs:

   ```bash
   dc exec postgres psql -U madar -d madar
   ```

   ```text
   \password madar
   \q
   ```

3. Put it into `POSTGRES_PASSWORD`, `DATABASE_URL` and `DATABASE_URL_SYNC`, in **both** VMs' `.env` files (`sudoedit /srv/madar/.env`).
4. Recreate the clients. The APIs drop their connections for a few seconds:

   ```bash
   dc up -d --force-recreate api-public api-admin
   curl -fsS http://127.0.0.1:8000/healthz
   ```

   From D3, recreate VPS-2's workers too.

## Rotate the home box Redis password

The home box authenticates to Redis as the ACL user `homebox`; its password is
`REDIS_HOMEBOX_PASSWORD` on both VPS-1 and the box. The rendered ACL file is the only place Redis
reads it.

1. On VPS-1, make a new value and put it in `/srv/madar/.env` as `REDIS_HOMEBOX_PASSWORD`.
2. Deploy (any deploy does it, or `deploy.sh --infra-only`). It renders `/srv/madar/redis/users.acl`,
   finds it changed, restarts Redis, and proves that both the `default` and the `homebox` password
   work before it touches the APIs ([deploy-and-rollback.md](deploy-and-rollback.md)). The `homebox`
   user's old password stops working at that restart.
3. Put the same value in the box's `/srv/madar/.env`, and update `REDIS_URL` there
   (`redis://homebox:<new>@10.8.0.1:6379/0`).
4. Recreate the box's worker:
   `sudo docker compose -f /srv/madar/infra/compose/home-box.yml --env-file /srv/madar/.env up -d`
   (without `--env-file`, compose fails on the required variables).
5. Check the box's log has no `NOPERM` or `WRONGPASS`, and start a run
   ([imports-and-sources.md](imports-and-sources.md)).

## Rotate the admin JWT secret

Rotating it signs every admin out: an access token minted with the old key stops verifying (the
refresh token still works, so the admin continues after one refresh).

1. `openssl rand -hex 32` on VPS-1.
2. Put it in VPS-1's `/srv/madar/.env` as `ADMIN_JWT_SECRET`. VPS-2 doesn't use it and must not hold
   it: no worker verifies an admin token (only `api-admin` does).
3. `dc up -d --force-recreate api-admin` on VPS-1.
4. Check `/admin/api/healthz` and that a login works.

## Rotate the Sat Air bridge credentials

The bridge reads the old Sat Air project's public web configuration. It lives only in VPS-2's
`.env`; nothing in the repository or the tests knows it (D15, FR-052).

1. Get the current web configuration from the old project (Firebase console → project settings →
   your apps), and take the API key that is restricted to Firestore reads.
2. Put the project id and the key in VPS-2's `/srv/madar/.env` as `SATAIR_FIREBASE_PROJECT_ID` and
   `SATAIR_FIREBASE_API_KEY`.
3. Re-run the VPS-2 deploy, then start a bridge run by hand and read `import_runs`
   ([imports-and-sources.md](imports-and-sources.md)).

If the key was exposed, revoke it in the old project and issue a new one first. A `403` from
`firestore.googleapis.com` in the run's log means the key or its restrictions are wrong.

## Rotate the API-Football key

The key is one header (`x-apisports-key`) read from VPS-2's `.env` as `API_FOOTBALL_KEY`, and it is
added at send time so it reaches no log, raw page or `import_runs.log` (D6 T061's test).

1. In the API-Football dashboard, revoke the old key and create a new one.
2. Put it in VPS-2's `/srv/madar/.env` as `API_FOOTBALL_KEY` (empty means the source stops on
   purpose with `not_configured`).
3. Recreate `worker-scrape`, which fetches the source:
   `IMAGE_TAG=$(cat /srv/madar/current_tag) docker compose --env-file /srv/madar/.env -f /srv/madar/infra/compose/vps2.yml --profile workers up -d worker-scrape`.
4. Run it by hand and read the run row: `stopped`/`not_configured` means the worker still reads the
   old value, and a `401` means the key is wrong ([imports-and-sources.md](imports-and-sources.md#api-football-and-stopped-runs)).

## Rotate the home box's GHCR token

`GHCR_READ_TOKEN` is a fine-grained GitHub token with only `read:packages`, used by
`home-box-update.sh` to pull `madar-backend-amd64:stable`.

1. Create a new token (GitHub → settings → developer settings → fine-grained tokens), scope: this
   repository, permission: Packages → read.
2. Put it in the box's `/srv/madar/.env`.
3. Run `sudo /srv/madar/infra/scripts/home-box-update.sh` and check it pulls and logs out.
4. Revoke the old token.

The script logs in, pulls and logs out in one run, so the token is on disk only in the box's `.env`
(mode 600).

## Rotate the Redis password

Redis reads the ACL file when it starts, and `deploy.sh` restarts it when the rendered file changed.
Rotate in this order, or every client answers `WRONGPASS`:

1. Make a new password, and put it into `REDIS_PASSWORD`, `REDIS_URL` and `CELERY_BROKER_URL` in
   both VMs' `.env` files. Do not restart anything yet: Redis still holds the old ACL.
2. Render the new ACL and load it, then let the clients come up on it. On VPS-1, as `deploy`:

   ```bash
   /srv/madar/infra/scripts/deploy.sh --infra-only   # renders, restarts Redis, proves both users
   dc up -d --force-recreate api-public api-admin worker-media
   curl -fsS http://127.0.0.1:8000/healthz
   ```

   `deploy.sh --infra-only` is what renders `/srv/madar/redis/users.acl` and restarts Redis: a
   changed file takes effect only at a restart, because Compose recreates a container only when its
   definition changes. It pings `default` and `homebox`, and puts the previous ACL back if the new
   one is refused. A plain `dc restart redis` would load nothing and leave every client on the new
   password against the old ACL ([deploy-and-rollback.md "How a release reaches VPS-1"](deploy-and-rollback.md#how-a-release-reaches-vps-1)).
3. On VPS-2 (as `deploy`), recreate the four services on the new password. They exist only in
   `vps2.yml`, so VPS-1's `dc` helper (which points at `vps1.yml` and has no `--profile workers`)
   does not work here; this is the command `deploy.sh --host vps2` runs:

   ```bash
   IMAGE_TAG=$(cat /srv/madar/current_tag) \
     docker compose --env-file /srv/madar/.env --profile workers \
       -f /srv/madar/infra/compose/vps2.yml up -d --force-recreate \
       worker-imports worker-scrape worker-maintenance worker-notify worker-live uptime-kuma beat
   ```
4. On the home box, update `REDIS_URL` in its `/srv/madar/.env`, then recreate its worker:

   ```bash
   sudo docker compose -f /srv/madar/infra/compose/home-box.yml --env-file /srv/madar/.env up -d
   ```
5. Check `/healthz` (its `redis` field) and one worker per host.

## Rotate the Firebase service account key

1. Add a new JSON key to the service account, and store it ([firebase-hosting.md §2](firebase-hosting.md#2-service-account-and-key)).
2. Prove it works: `gh workflow run pwa.yml -R AhmedSaied94/madar-sat --ref master`.
3. In the Google Cloud console, delete the **old** key under the service account's Keys.

## Rotate the Android upload key

The upload key signs the AAB you give Google Play. It is not the app's signing key once Play App Signing is on, so a lost or leaked upload key is replaced through Play, and users are not affected. Without Play App Signing, losing it means no more updates, so keep the backup.

How it was made (2026-10-30), for reference. It is a PKCS12 keystore, RSA 4096, alias `upload`, valid 10,000 days, one random password for store and key:

```bash
umask 077; d=~/.config/madar-sat; mkdir -p "$d"
export KS_PASS="$(head -c 32 /dev/urandom | base64 | tr -d '/+=\n' | head -c 32)"
printf '%s' "$KS_PASS" > "$d/keystore-password"
keytool -genkeypair -keystore "$d/upload-keystore.jks" -storetype PKCS12 -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Madar Sat, O=Madar Sat" \
  -storepass:env KS_PASS -keypass:env KS_PASS
```

To replace it:

1. In Play Console, **Setup → App signing → Request upload key reset** and give Google the new certificate (`keytool -export -rfc -alias upload -keystore <jks> -file upload_cert.pem`).
2. Make the new keystore as above, in a new folder, and back it up.
3. Update the four secrets from files, never from the command line:

   ```bash
   R=AhmedSaied94/madar-sat; d=<new folder>
   base64 -w0 "$d/upload-keystore.jks" | gh secret set ANDROID_KEYSTORE_BASE64 -R "$R"
   gh secret set ANDROID_KEYSTORE_PASSWORD -R "$R" < "$d/keystore-password"
   gh secret set ANDROID_KEY_PASSWORD -R "$R" < "$d/keystore-password"
   ```

4. Prove it: push a throwaway tag such as `app-v0.0.1` and check that `app-release.yml` is green. Its "Check the AAB is signed with the upload key" step prints the key's SHA-256, which must match the new certificate. Delete the tag afterwards (`git push --delete origin app-v0.0.1`).

To build a signed AAB on your machine, write `app/android/key.properties` (git-ignored) with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`, then run the `flutter build appbundle` command from `app-release.yml`. Without that file, `release` falls back to the debug key.

## Update the app's flavor values

`app/env/{dev,staging,prod}.json` are not in the repo. Each machine that builds keeps its own copy, made from `app/env/example.json`, and CI writes `env/prod.json` from `APP_ENV_PROD`. A new checkout or worktree has none: copy them from a checkout that has them (they are git-ignored, so `git` never moves them).

**Before you merge the change that untracked them into another checkout** (for example `../madar-m`), copy that checkout's `app/env/*.json` aside. The merge deletes tracked files that the change removed, and the copies come back only from your backup.

To change a value (a host, a link, a Firebase identifier, the VAPID key) or add a key:

1. Edit your local `app/env/prod.json` (and `staging`, `dev` if they change). A new key also goes into `app/env/example.json` with an empty value, in the same change as the code that reads it: `write_env.sh` fails when the secret's keys differ from the template's.
   - The release workflows (`pwa.yml`, `app-release.yml`) call it without `--or-example`, so they fail until the secret has the new key. Update the secret in the same sitting.
   - `app.yml`'s check job calls it with `--or-example`: a key the template has and the secret lacks is written empty there, with a `::warning::` naming it, so a pull request that introduces a key still runs its checks. That warning on `master` means the secret is behind.
2. Update the secret from the file:

   ```bash
   gh secret set APP_ENV_PROD -R AhmedSaied94/madar-sat < app/env/prod.json
   ```

3. Prove it: re-run `pwa.yml` by hand (`gh workflow run pwa.yml -R AhmedSaied94/madar-sat --ref master`) and check its "Write env/prod.json from APP_ENV_PROD" step prints `wrote env/prod.json from the flavor secret`.

A value that changes for phones already installed (the hosts) belongs in Remote Config too ([remote-config.md](remote-config.md)); the flavor file is only the bundled default.

## Rotate the Telegram bot

1. In @BotFather, `/revoke` the token (or `/newbot` for a new bot and a new chat membership).
2. Put the new token and chat id in VPS-2's `/srv/madar/.env`, then restart the two workers that read them: `worker-imports` (alerts) and
   `worker-notify` (alerts and the sender).
3. Update the Telegram notification in Kuma ([uptime-kuma.md](uptime-kuma.md#2-the-telegram-notification)) and press **Test**.
4. Prove both paths: the `send_alert` command in [source-alerts.md](source-alerts.md#the-two-settings), and one Kuma test.

## Rotate the FCM service account

1. In the Firebase console, **Project settings → Service accounts → Generate new private key** for the
   same project. The old key stays valid until you delete it.
2. Install the new JSON on VPS-2 **as root**, with the worker's uid and mode 600 (the same commands
   as [push-notifications.md](push-notifications.md#the-fcm-service-account)):
   `sudo install -d -m 700 -o 10001 -g 10001 /srv/secrets`, then
   `sudo install -m 600 -o 10001 -g 10001 <new>.json /srv/secrets/fcm.json`, then `sudo shred -u <new>.json`.
   The same install run as `deploy` fails with EPERM: `deploy` is not root, and only root can give
   the file uid 10001. Prove the worker can read it:
   `docker compose exec worker-notify test -r /srv/secrets/fcm.json && echo readable`.
3. Restart `worker-notify` only: `docker compose -p madar restart worker-notify`, and check
   `docker compose logs worker-notify | grep 'fcm: initialized'`.
4. With `FCM_DRY_RUN=true`, queue one dispatch and read the log; then set it back to `false`
   (Lane B1's `push-notifications.md`).
5. Delete the old key in the Firebase console once the new one has sent one real message.

## Rotate the backup keys

**restic (both hosts).** The repository password cannot be changed in place; leave the old repository
as it is and start a new one:

1. Create a new Backblaze B2 bucket and application key.
2. On VPS-2 and VPS-1, put the new `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID` and
   `B2_ACCOUNT_KEY` in `/srv/madar/.env`.
3. Run both backups by hand ([backups.md](backups.md#run-one-by-hand)) and confirm a snapshot exists.
4. Keep the old bucket for one retention window (a month), then delete it and revoke its key.

**OCI (VPS-1).** Create a new customer secret key in the OCI console, replace
`RCLONE_CONFIG_OCI_SECRET_ACCESS_KEY` in VPS-1's `.env`, run the mirror by hand, then delete the old
key in the console. `rclone` reads the value per run, so no restart is needed; the next 03:30 timer
uses it.

**Kuma push URLs.** Recreate only the affected monitor in Kuma (**Edit → Push URL**), put the new
token into the host's `.env` value (the form is in [uptime-kuma.md](uptime-kuma.md#the-push-url-on-each-host);
never paste the URL Kuma shows), and restart the service that reads it (or wait for the next backup run).

## When gitleaks fails

1. Open the failed `gitleaks` run. The log names the file, line, rule and commit, with the value redacted.
2. **A false positive?** An allowlist entry is allowed only for a synthetic value under `backend/tests/fixtures/`, by its exact path and value, in `.gitleaks.toml` (its comment shows the form). Never allowlist a folder, a rule, or anything outside that folder.
3. **A real secret:** treat it as leaked, even on an unmerged branch, because it is already on GitHub.
   1. **Rotate it first** (above, or the runbook in the table).
   2. Remove it from the branch: rewrite the PR's commits without it, then force-push the branch.
   3. If it reached `master`, rewrite `master`'s history too (for example `git filter-repo --replace-text`), then force-push. `gitleaks.yml` scans the full history, so it keeps failing until the value is gone.
   4. Every clone keeps the old history, so ask anyone with a clone to re-clone. Rotation is what actually protects you; the rewrite only cleans up.

The T067 proof (a throwaway PR with a fake key) is in [ci-workflows.md](ci-workflows.md#prove-the-secret-scan).

## A secret leaked some other way

1. Rotate it first, using the table above.
2. Then find out how it leaked: a log, a screenshot, a paste, a lost device.
3. Look for use: `sudo journalctl -u ssh --since '<date>'` for SSH logins, and `sudo wg show wg0` for peer endpoints you don't recognise.
