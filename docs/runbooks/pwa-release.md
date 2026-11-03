# The PWA release

How a public PWA release is cut, checked and rolled back (D4 T047, FR-025, contracts/web-release.md,
research R8 and R11). It touches production: a `web-v*` tag moves `https://<PWA_HOST>` and fills
the VPS-1 mirror under `https://app.<VPS1_IP>.sslip.io`.

## What a release is

`pwa.yml` builds the app and `app/tool/stage_web_release.sh` lays the output out as a
content-addressed release:

```text
build/web_release/
├── index.html, flutter_bootstrap.js, manifest.json, favicon.png, icons/   # the shell
├── sw.js, firebase-messaging-sw.js, firebase-config.js                    # the workers
├── drift_worker.js                       # same-origin shim for the real worker
├── release.json                          # {"hash": …, "mirror": …, "built_at": …}
└── r/<hash>/                             # everything Flutter loads, plus .br and .gz copies
```

- `<hash>` is the first 16 hex characters of the SHA-256 over the sorted (path, file hash) pairs of
  what goes under `r/`. The same build always gives the same hash, and a different byte gives a
  different one.
- Nothing under `r/<hash>/` changes after upload, so it is cached for a year.
- The shell is small and revalidates every time, so a new release is visible on the next open.

## Before you start

- The Android and web apps are on the same API, so the API (`api-public`) must be healthy:
  `curl -fsS https://api.<VPS1_IP>/healthz`.
- `MIRROR_BASE_URL=https://app.<VPS1_IP>.sslip.io` is in the `APP_ENV_PROD` secret. Without it the
  build refuses to release (`Stage the release layout (release)` fails), because a release with no
  mirror would spend the Spark quota.
- `gh`, signed in, and WireGuard for the checks that run from your machine.

## 1. Tag the release

The tag is cut on `master`, after the load test and the bug bash that plan.md lists:

```bash
R=AhmedSaied94/madar-sat
git fetch -q && git switch master && git pull -q
git tag -a web-v0.1.0 -m "PWA 0.1.0" && git push origin web-v0.1.0
gh run watch -R "$R" "$(gh run list -R "$R" --workflow pwa.yml -L 1 --json databaseId -q '.[0].databaseId')"
```

The tag format is checked in the build job: `web-v<major>.<minor>.<patch>`, nothing else. The
release job then refuses a tag whose commit is not an ancestor of `origin/master`, before it touches
VPS-1. It runs in the `deploy-vps1` concurrency group, so it waits for a running backend, infra or
admin deploy, and it never rsyncs `infra/` to the host ([deploy-and-rollback](deploy-and-rollback.md#how-a-release-reaches-vps-1)).

## 2. What the job does

| Step | Effect |
| --- | --- |
| Build | `flutter build web --release --no-web-resources-cdn --pwa-strategy=none` with `APP_ENV_PROD`, then the stage script with `env/prod.json` |
| Mirror copy | `rsync` of `build/web_release/r/<hash>/` to `vps1:/srv/app-mirror/r/<hash>/`, and `/srv/app-mirror/release-check.txt` gets the hash. `--delete` stays inside that hash; the parent `r/` is never deleted from |
| Mirror check | The mirror comes from the artifact's `release.json` (`.mirror`), the origin from `infra/firebase/.firebaserc`'s default project. `curl` of `main.dart.js` and its `.br` with `Origin: https://<FIREBASE_PROJECT_ID>.web.app`: `200`, `cache-control: …immutable`, the CORS header, `content-encoding: br`, `nosniff`. **A failure here stops before the live deploy** |
| Live deploy | `action-hosting-deploy` with `channelId: live`, deploying the shell and the full copy |
| Prune | Releases older than 30 days are removed from the mirror, always keeping the newest 3 |

The run's summary carries `Staged release <hash>` and `Mirror verified for <hash>`.

## 3. Check the mirror

From a machine with WireGuard (or any machine, the mirror is public):

```bash
hash=$(curl -sS https://app.<VPS1_IP>/release-check.txt) && echo "$hash"
curl -sI -H 'Origin: https://<FIREBASE_PROJECT_ID>.web.app' -H 'Accept-Encoding: br' \
  "https://app.<VPS1_IP>/r/$hash/main.dart.js"
# 200, cache-control: public, max-age=31536000, immutable,
# access-control-allow-origin: https://<FIREBASE_PROJECT_ID>.web.app,
# content-encoding: br, x-content-type-options: nosniff
curl -sS "https://app.<VPS1_IP>/r/" -o /dev/null -w '%{http_code}\n'     # 404, never a listing
curl -sS https://<PWA_HOST>/release.json                                  # the same hash
```

If the copy step failed and you need it by hand, from VPS-1 ([deploy-and-rollback.md](deploy-and-rollback.md#working-on-vps-1)):

```bash
# after rsyncing build/web_release/r/<hash>/ to /srv/app-mirror/r/<hash>/
printf '%s\n' <hash> | sudo -iu deploy tee /srv/app-mirror/release-check.txt
```

Writing `release-check.txt` is also what turns Kuma's `pwa-mirror` monitor green: it polls exactly
that URL ([uptime-kuma.md §3](uptime-kuma.md#3-http-monitors-four)).

## 4. Roll back the live channel

Firebase Hosting keeps every live release. Rolling back moves the shell, not the mirror: older
folders stay, so the previous hash is still served.

1. Firebase console → **Hosting** → the site's **Release history**.
2. Find the previous release and choose **Rollback**.
3. Confirm the served shell names the previous hash:

   ```bash
   curl -sS https://<PWA_HOST>/release.json
   curl -sS https://<PWA_HOST>/index.html | grep -o 'main.dart.js'   # shell present
   ```

   Then the mirror check in §3 with that hash.

A rollback does not delete `r/<hash>/`, so `pwa-mirror` stays green. To go forward again, re-run the
release job for the tag you want (`gh run rerun <run id> --failed`), which is idempotent: the same
hash rewrites the same files.

## 5. Pruning

The release job prunes after a successful deploy. To prune by hand on VPS-1:

```bash
sudo -iu deploy
cd /srv/app-mirror/r
cutoff=$(($(date +%s) - 30*24*3600))
ls -1dt */ | tail -n +4 | while IFS= read -r old; do
  [ "$(stat -c %Y "$old")" -lt "$cutoff" ] && echo "removing $old" && rm -rf -- "$old"
done
```

The newest three always stay, so at least one rollback target remains on the mirror. Never delete
the hash that the live `release.json` names.

## Check

- `gh run list -R AhmedSaied94/madar-sat --workflow pwa.yml -L 3` shows the release green.
- §3's three commands answer as annotated.
- The PWA opens from `https://<PWA_HOST>`, and DevTools → Application shows `sw.js` controlling the
  page.
- Kuma's `pwa` and `pwa-mirror` are green.

## If it fails

| Symptom | Do |
| --- | --- |
| `Stage the release layout (release)` fails on `MIRROR_BASE_URL` | Add `MIRROR_BASE_URL` to the `APP_ENV_PROD` secret and re-run ([contracts/web-release.md](../specs/004-d04-mvp-launch/contracts/web-release.md)) |
| The tag build fails validation | The tag is not `web-v<major>.<minor>.<patch>`; delete it and tag again |
| The mirror check fails on `content-encoding` | The stage script produced no `.br` files, or Caddy's `precompressed` was lost: [deploy-and-rollback.md "Updating the edge or infra"](deploy-and-rollback.md#updating-the-edge-or-infra) |
| The mirror check fails on CORS | `FIREBASE_PROJECT_ID` in VPS-1's `.env` is wrong, or the request's `Origin` is not the live host ([firebase-hosting.md §3](firebase-hosting.md#3-firebaserc-and-the-hosts)) |
| The live channel serves "Site Not Found" | The release job stopped before its deploy step: read the failed step, the mirror copy is the usual cause |
| First loads still come from Firebase | `release.json`'s `mirror` is empty: the build had no `MIRROR_BASE_URL` (a preview). Re-tag after fixing the secret |
| Every open reloads a file the mirror 404s | The folder was pruned while the live shell still names it. Roll the live channel back (§4) or re-run the release job |

The preview channel, the deploy key and the CORS origins are in [firebase-hosting.md](firebase-hosting.md).
