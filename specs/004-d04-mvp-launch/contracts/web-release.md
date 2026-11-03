# Contract: web release (Lane M ↔ B2)

Lane M owns what the build produces. B2 owns the workflow, Caddy and Firebase config that ship it. Neither edits the other's files.

## Lane M provides

1. **`app/tool/stage_web_release.sh <env-file> <out-dir>`**
   - Inputs: the env file (reads `MIRROR_BASE_URL`, which may be empty) and an existing `app/build/web` from:

     ```text
     flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
       -t lib/main_prod.dart --dart-define-from-file=env/prod.json
     ```

     If `--pwa-strategy` no longer exists on the pinned Flutter, the script still works, because it ignores and removes any `flutter_service_worker.js`.
   - Output: the layout in [data-model.md](../data-model.md#release-layout-lane-m-output-b2-input).
   - Prints `RELEASE_HASH=<hash>` as its last line. Exits non-zero if a shell file is missing (it extends `tool/check_web_assets.sh`), or if any file outside `r/<hash>/` and the shell list exists.
2. **`app/web/flutter_bootstrap.js`**: loads the release from `<mirror or own origin>/r/<hash>/` at once: through `sw.js` when it already controls the page; on a first visit straight from the mirror while `sw.js` registers in the background, retrying once from the own origin if the mirror fails. It sets `window.MADAR_RELEASE` for drift's wasm URL.
3. **`app/web/sw.js` + `app/web/sw_core.mjs`**: the behaviour in research R12. Tests: `node --test app/test_web/` (no npm install).

## B2 provides

1. **`pwa.yml`**
   - On push to `master`: builds and stages with an **empty** mirror base, then deploys `build/web_release` to the `master` preview channel, as today.
   - On tag `web-v<semver>`:
     1. build once and stage with `MIRROR_BASE_URL` from `APP_ENV_PROD`;
     2. rsync `build/web_release/r/<hash>/` to `vps1:/srv/app-mirror/r/<hash>/` through `.github/actions/vps1-sync`. Never `--delete` at the `r/` level;
     3. `curl` one release file and its `.br` from `https://app.<ip1>.sslip.io/r/<hash>/main.dart.js` with `Origin: https://madar-sat.web.app`: expect `200`, the immutable cache header and the CORS header;
     4. deploy the whole `build/web_release` (shell and full copy) to the **live** channel (`action-hosting-deploy` with `channelId: live`);
     5. prune mirror releases older than 30 days, keeping the newest 3.

     A failure in steps 2–3 fails the job before step 4, so the live shell never points at a release the mirror lacks.
2. **`infra/Caddyfile`, the `app.` site:** `/r/*` → `Cache-Control: public, max-age=31536000, immutable`; `file_server { precompressed br gzip }`; the existing CORS rule (the two exact Firebase origins, `GET`/`HEAD`); `nosniff`; no listing. Remove `encode` from this site.
3. **`infra/firebase/firebase.json`:** add an immutable rule for `^/r/[0-9a-f]{16}/.*$`. Keep `sw.js`, `release.json` and the `drift_worker.js` shim on `no-cache` (add `release.json` and the shim to the existing `no-cache` list; `sqlite3.wasm` now lives under `r/<hash>/`).
4. **`app.yml`:** a step that runs `node --test app/test_web/` on Node 22.
5. **Uptime Kuma:** the existing `pwa-mirror` monitor targets `https://app.<ip1>.sslip.io/release-check.txt`, a small file the release job writes with the current hash, so the monitor proves files are served.

## Owner provides

- `MIRROR_BASE_URL=https://app.<ip1>.sslip.io` in the `APP_ENV_PROD` secret, plus the key in `app/env/example.json` (Lane M).
- The tag `web-v0.1.0` on `master` after the gate items in plan.md "Delivery sequence".

## Invariants

- Live `index.html` and `sw.js` reference only a hash whose folder exists on both the mirror and Firebase.
- The previous release's folder stays on both for at least 30 days.
- No file under `r/` is ever overwritten. A different content gives a different hash.
