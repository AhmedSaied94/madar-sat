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
| `REDIS_PASSWORD` | Both `.env` files, and inside `REDIS_URL` and `CELERY_BROKER_URL` | Redis, the APIs, the workers | [Below](#rotate-the-redis-password) |
| `FLOWER_BASIC_AUTH` | VPS-2's `.env` | Flower (from D3) | Edit it, then recreate `flower` |
| `DEPLOY_SSH_KEY` | GitHub secret. The public half is in VPS-1's `.env` and in `/home/deploy/.ssh/authorized_keys`. | `backend.yml` deploy, `infra.yml` sync | [deploy-and-rollback.md "Replacing a deploy key"](deploy-and-rollback.md#replacing-a-deploy-key) |
| `WG_CI_CONFIG` | GitHub secret; the peer `ci` in VPS-1's `wg0.conf` | The same jobs | [private-network.md "Rotate the CI peer"](private-network.md#rotate-the-ci-peer) |
| WireGuard device keys | Each device; its peer in `wg0.conf` | You | [private-network.md "Remove a peer"](private-network.md#remove-a-peer), then add it again |
| WireGuard hub key | `/etc/wireguard/wg0.key` on VPS-1 | `wg0` | [break-glass.md "Re-key the hub"](break-glass.md#re-key-the-hub-key-lost-or-exposed) |
| `FIREBASE_SERVICE_ACCOUNT` | GitHub secret | `pwa.yml` | [Below](#rotate-the-firebase-service-account-key) |
| Android upload keystore | `~/.config/madar-sat/upload-keystore.jks` and `keystore-password` on the owner's machine (mode 600), **backed up in the owner's password manager**. GitHub secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`), `ANDROID_KEY_PASSWORD`. | `app-release.yml` (tag `app-v*`) | [Below](#rotate-the-android-upload-key) |
| `ubuntu` console passwords | Your password manager, one per VM | The serial console | `sudo passwd ubuntu`, then test the console again ([provision-host.md §2](provision-host.md#2-console-password-then-test-the-serial-console)) |
| Caddy's internal CA key | VPS-1's `madar_caddy_data` volume | The admin site's certificates | Only by letting Caddy make a new CA, which means a new root on every admin device |
| `GITHUB_TOKEN` | Created per job, expires when the job ends | GHCR push and pull | Nothing to rotate. `deploy.sh` logs out of GHCR on exit. |

Not secrets: the public and private IPs, the hostnames, the Firebase project ID, the WireGuard hub's public key, and `DEPLOY_KNOWN_HOSTS` (VPS-1's public host key, kept as a secret only for convenience).

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

## Rotate the Redis password

Redis reads `requirepass` when it starts, so it and every client restart together. Redis keeps its data (`appendonly yes`).

1. Make a new password, and put it into `REDIS_PASSWORD`, `REDIS_URL` and `CELERY_BROKER_URL` in both VMs' `.env` files.
2. Recreate Redis and its clients:

   ```bash
   dc up -d --force-recreate redis api-public api-admin
   curl -fsS http://127.0.0.1:8000/healthz
   ```

   From D3, recreate VPS-2's workers too.

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
