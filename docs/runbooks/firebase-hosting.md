# Firebase Hosting (PWA preview)

`pwa.yml` builds the Flutter web app and deploys it to the Firebase Hosting preview channel `master`, which expires 30 days after each deploy. This runbook sets up the project, the deploy key and the origins the API allows. It touches no server, except for one `.env` change on VPS-1. The public release (`web-v*` tags, and the VPS-1 mirror at `app.<VPS1_IP>.sslip.io`) arrives on D4. Background: SD §5.2, research R14, and `infra/firebase/`.

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
   - **Service Usage Consumer**, so the CLI can check that the Hosting API is enabled (without it the deploy fails with a 403 on `serviceusage.services.get`);
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

   - `FIREBASE_PROJECT_ID` sets the two origins that may read the PWA mirror (`app.<VPS1_IP>.sslip.io`) in the Caddyfile.
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

The `build` job uploads `app/build/web` as the artifact `pwa-web`, and `deploy` downloads it into `infra/firebase/public/` (git-ignored), because `firebase.json`'s `public` must sit inside the project folder.

The run's summary prints `PWA preview: <url> (expires …)`. The address has the form `https://<project>--master-<suffix>.web.app`, and it stays the same for the channel's life.

**Add that origin to `CORS_ORIGINS`.** The preview is served from its own origin, which isn't one of the two default hostnames, so until you add it the PWA preview can't call the API. Append it in VPS-1's `.env` and recreate the APIs, as in §3.

### Addresses today (project `madar-sat`)

| Address | What it is | State on 2026-10-30 |
| --- | --- | --- |
| `https://<PWA_PREVIEW_HOST>` | The `master` preview channel that `pwa.yml` deploys. The suffix stays while the channel lives and changes if it expires and is created again. | Serves the app. The API blocks it (CORS preflight returns 400) until it is in `CORS_ORIGINS`. |
| `https://<PWA_HOST>`, `https://<FIREBASE_AUTH_DOMAIN>` | The site's live channel. `pwa.yml` never deploys here; the first live deploy arrives with the `web-v*` release on D4. | "Site Not Found" (404). Both are already allowed by the API's CORS. |

The `CORS_ORIGINS` line on VPS-1 should hold all three:

```text
CORS_ORIGINS=https://<PWA_HOST>,https://<FIREBASE_AUTH_DOMAIN>,https://<PWA_PREVIEW_HOST>
```

Then recreate the APIs (`dc up -d --force-recreate api-public api-admin`) and check the preflight:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X OPTIONS https://api.<VPS1_IP>.sslip.io/v1/matches \
  -H 'Origin: https://<PWA_PREVIEW_HOST>' -H 'Access-Control-Request-Method: GET'   # 200
```

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
| 403 `Permission denied to get service firebasehosting.googleapis.com` (`serviceusage.services.get`) | Add **Service Usage Consumer** to the service account (§2) |
| `… is outside of project directory` | `firebase.json`'s `public` points outside `infra/firebase/`. It must be `public`, which `deploy` fills from the artifact. |
| `Failed to get Firebase project` | The ID in `.firebaserc` is wrong, or the account has no access to that project |
| The preview loads but every API call fails with a CORS error. The app shows «تعذّر تحميل البيانات», and the preflight returns `400 Disallowed CORS origin`. | The channel's origin isn't in `CORS_ORIGINS` (§4) |
| `<PWA_HOST>` shows "Site Not Found" | Nothing is deployed to the live channel yet. `pwa.yml` only deploys the preview channel; use the preview address in §4 until the D4 release. |
| Chrome's Network tab shows a request to `fonts.gstatic.com` or `www.gstatic.com` | A build without the Roboto alias in `app/pubspec.yaml` or without `--no-web-resources-cdn` (FR-042). Both are in the current `pwa.yml` build. |
| The channel expired | Run `pwa.yml` again |

Rotating the key: [secrets.md](secrets.md#rotate-the-firebase-service-account-key).
