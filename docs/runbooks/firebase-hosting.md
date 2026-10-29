# Firebase Hosting (PWA preview)

`pwa.yml` builds the Flutter web app and deploys it to the Firebase Hosting preview channel `master`, which expires 30 days after each deploy. This runbook sets up the project, the deploy key and the origins the API allows. It touches no server, except for one `.env` change on VPS-1. The public release (`web-v*` tags, and the VPS-1 mirror at `app.130.110.117.215.sslip.io`) arrives on D4. Background: SD §5.2, research R14, and `infra/firebase/`.

The rest of the Firebase project (the Android and web apps, the FCM web-push key, Remote Config defaults) is Day 0 work in delivery-plan §6 ([../owner-actions.md](../owner-actions.md)).

## Before you start

- A Google account for the project.
- `gh`, signed in with access to `AhmedSaied94/madar-sat`.

## 1. Create the project

1. In the Firebase console, add a project. The Spark (free) plan is enough. Google Analytics isn't needed.
2. Note the **project ID** (`<project>`). It is in the default hostnames `<project>.web.app` and `<project>.firebaseapp.com`, and VPS-1's `.env` needs it ([provision-host.md §4](provision-host.md#4-fill-the-env-file-and-re-run)).
3. Open **Hosting → Get started** and click through, so the default site exists. Skip its `firebase init` and `firebase deploy` steps: `infra/firebase/` already holds the config, and `pwa.yml` deploys.

## 2. Service account and key

`pwa.yml` signs in with a service account's JSON key (secret `FIREBASE_SERVICE_ACCOUNT`).

1. In the Google Cloud console for the same project: IAM & Admin → Service accounts → Create service account, named `github-pwa-deploy`.
2. Give it these roles:
   - **Firebase Hosting Admin**, to deploy;
   - **API Keys Viewer** and **Firebase Authentication Admin**. `firebase init hosting:github`, the official setup for `FirebaseExtended/action-hosting-deploy`, grants these too. The CLI uses the second to add a preview channel's address to Auth's authorized domains.

   It doesn't need **Cloud Run Viewer**: `firebase.json` has no Cloud Run rewrites. If a deploy fails with a permission error, check the action's README for the current role list.
3. Under the account's **Keys**, add a JSON key. It downloads once. Store it straight into the secret and delete the file:

   ```bash
   gh secret set FIREBASE_SERVICE_ACCOUNT -R AhmedSaied94/madar-sat < <downloaded>.json
   shred -u <downloaded>.json
   ```

If key creation is refused because of the organization policy `iam.disableServiceAccountKeyCreation`, the project sits in a Google Cloud organization that forbids keys. Lift the policy for this project, or move the project out of that organization.

## 3. `.firebaserc` and the hosts

1. In `infra/firebase/.firebaserc`, replace `your-firebase-project-id` with `<project>`, and commit it in a Lane B2 change. The project ID isn't a secret.
2. On VPS-1, `sudoedit /srv/madar/.env`:

   ```text
   FIREBASE_PROJECT_ID=<project>
   CORS_ORIGINS=https://<project>.web.app,https://<project>.firebaseapp.com
   ```

   - `FIREBASE_PROJECT_ID` sets the two origins that may read the PWA mirror (`app.130.110.117.215.sslip.io`) in the Caddyfile.
   - `CORS_ORIGINS` is the API's list of allowed browser origins, matched exactly.
3. If VPS-1 is already running, recreate what reads them ([deploy-and-rollback.md "Working on VPS-1"](deploy-and-rollback.md#working-on-vps-1)):

   ```bash
   dc up -d --force-recreate caddy api-public api-admin
   ```

## 4. The preview channel

`pwa.yml` runs on pushes to `master` that change `app/**`, `infra/firebase/**` or `pwa.yml`, and by hand:

```bash
R=AhmedSaied94/madar-sat
gh workflow run pwa.yml -R "$R" --ref master
gh run watch -R "$R" "$(gh run list -R "$R" --workflow pwa.yml -L 1 --json databaseId -q '.[0].databaseId')"
```

The run's summary prints `PWA preview: <url> (expires …)`. The address has the form `https://<project>--master-<suffix>.web.app`, and it stays the same for the channel's life.

**Add that origin to `CORS_ORIGINS`.** The preview is served from its own origin, which isn't one of the two default hostnames, so until you add it the PWA preview can't call the API. Append it in VPS-1's `.env` and recreate the APIs, as in §3.

Check the cache headers:

```bash
curl -sI <url>/ | grep -i cache-control                       # no-cache
curl -sI <url>/flutter_bootstrap.js | grep -i cache-control   # no-cache
```

Files whose names carry a content hash (`.<8+ hex>.`) get `public, max-age=31536000, immutable`. Flutter's default web build doesn't hash its file names, so until Lane M adds that (SD §5.2), most files get `no-cache`.

## If it fails

| Symptom | Do |
| --- | --- |
| The `build` job fails reading `app/.flutter-version` | Lane M hasn't merged `app/` yet. Expected until then. |
| `Failed to authenticate`, or a 403 | Check `FIREBASE_SERVICE_ACCOUNT` and the roles in §2 |
| `Failed to get Firebase project` | The ID in `.firebaserc` is wrong, or the account has no access to that project |
| The preview loads but every API call fails with a CORS error | The channel's origin isn't in `CORS_ORIGINS` (§4) |
| The channel expired | Run `pwa.yml` again |

Rotating the key: [secrets.md](secrets.md#rotate-the-firebase-service-account-key).
