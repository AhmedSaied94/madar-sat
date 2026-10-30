# CI workflows

One workflow per folder, each filtered to its own paths, plus `gitleaks` on everything. This runbook lists what each one checks, the usual failures and their fixes, how to re-run, and the T067 proofs. Only `backend.yml`'s `deploy` and `infra.yml`'s `sync` touch production. Background: research R14, and `.github/workflows/`.

## What runs where

| Workflow | Runs on | Jobs | Secrets |
| --- | --- | --- | --- |
| `backend.yml` | Pushes to `master` and PRs that change `backend/**` or the workflow; by hand, with `break_healthcheck` | `test`, `openapi`, `clients`; on `master` also `build`, `build-amd64`, `deploy`, `deploy-vps2`, `stable`, `retention` | `WG_CI_CONFIG`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS`, and the `VPS2_VCN_IP` variable |
| `infra.yml` | Pushes to `master` and PRs that change `infra/**`, `.github/workflows/**` or `.github/actions/**` | `check`: `docker compose config` for the four Compose files, `systemd-analyze verify` on the home-box units, the Redis ACL placeholder check, `caddy validate`, shellcheck, actionlint. On a `master` push also `sync`. | The same three, for `sync` |
| `gitleaks.yml` | Every push to any branch, and every PR | `scan`: the full history, redacted | None |
| `app.yml` | Pushes to `master` and PRs that change `app/**`, `backend/openapi/public.json`, `madar-design/**` or the workflow | `check`: `flutter analyze`, the token-copy and literal checks, `flutter test` (goldens), the `prod` debug APK as the artifact `app-prod-debug.apk` | None |
| `app-release.yml` | A pushed tag `app-v<major>.<minor>.<patch>` | `aab`: writes the upload keystore from the secrets, builds the signed `prod` AAB (`--build-name` from the tag, `--build-number` = run number), checks it is signed by the `Madar Sat` upload key and not the debug key, uploads `app-prod-release.aab`. Play upload is not wired. | `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` |
| `pwa.yml` | Pushes to `master` that change `app/**`, `infra/firebase/**` or the workflow; by hand | `build` (web), `deploy` to the preview channel `master` | `FIREBASE_SERVICE_ACCOUNT` |
| `admin.yml` | Pushes to `master` and PRs that change `admin/**`, `backend/openapi/admin.json`, `madar-design/**` or the workflow | `check`: typecheck, lint, test, build, the literal and token-copy checks | None |

Every action is pinned to a commit SHA, and every image to an exact version. To update one, change the SHA and its version comment together.

## Before the folders exist

Some failures are expected while the lanes merge for the first time:

- `app.yml` and `pwa.yml` fail until Lane M merges `app/` (with `app/.flutter-version`). `admin.yml` fails until Lane A merges `admin/`.
- `backend.yml`'s `deploy` and `infra.yml`'s `sync` fail until the hosts and secrets exist (README.md stages 2 and 3). Re-run them afterwards.
- `clients` is skipped until both `admin/orval.config.ts` and `app/swagger_parser.yaml` exist. The breaking-change check is skipped until the `contract-v1` tag exists.

## Common failures

| Where | Symptom | Fix |
| --- | --- | --- |
| `backend` `test` | ruff, mypy or pytest | Run the same locally ([local-dev.md](local-dev.md)): `cd backend && uv run ruff check . && uv run mypy --strict app && uv run pytest` |
| `backend` `openapi` | "The committed OpenAPI documents are current" shows a diff | Re-export and commit `backend/openapi/`: export the same placeholder settings as the job's `env:` block, then `cd backend && uv run python -m app.cli export-openapi` |
| `backend` `openapi` | "No breaking change against contract-v1" fails | The change breaks the frozen contract (FR-014). Make it additive. |
| `backend` `clients` | "The generated clients are stale" | Regenerate both and commit them in the contract-change PR (D14): `cd admin && pnpm install && pnpm orval`, then `cd app && flutter pub get && dart run swagger_parser && dart run build_runner build -d` |
| `backend` `build` | Very slow, or Actions minutes run out | QEMU arm64 builds: [deploy-and-rollback.md "One-time setup"](deploy-and-rollback.md#one-time-setup) step 2 |
| `backend` `build-amd64` | Fails where `build` passes | It builds natively on `ubuntu-24.04`; read the build log, not the QEMU path. The home box then pulls `madar-backend-amd64:stable` ([home-box.md](home-box.md#updates)) |
| `backend` `deploy`, `infra` `sync` | Anything | [deploy-and-rollback.md "Reading a failed deploy"](deploy-and-rollback.md#reading-a-failed-deploy) |
| `backend` `deploy-vps2` | "set the VPS2_VCN_IP repository variable", or a jump/known-host failure | Set the variable; add VPS-2's host key to `DEPLOY_KNOWN_HOSTS` and the `deploy` user's key to VPS-2 ([workers.md](workers.md#deploy-vps-2)) |
| `backend` `stable` | `imagetools create` 403 or 404 | The repository lacks the Admin role on `madar-backend-amd64` ([deploy-and-rollback.md "Images in GHCR"](deploy-and-rollback.md#images-in-ghcr)) |
| `backend` `retention` | 403 or 404 | The repository lacks the Admin role on the package ([deploy-and-rollback.md "Images in GHCR"](deploy-and-rollback.md#images-in-ghcr)) |
| `infra` `check`, Compose | `required variable … is missing a value` | Add the variable to `infra/compose/example.env`, which must list every variable the Compose files use |
| `infra` `check`, Caddy | `adapting config using caddyfile: …` | Fix `infra/Caddyfile`. The check runs with `example.env`'s values. |
| `infra` `check`, shellcheck or actionlint | Findings | Fix the script or workflow |
| `infra` `check`, home-box units | `systemd-analyze verify` reports a directive | Fix `infra/scripts/home-box-update.service` or `.timer` |
| `infra` `check`, ACL | A literal password in the template | Use a `${...}` placeholder; `deploy.sh` fills it from `/srv/madar/.env` ([firewall-changes.md](firewall-changes.md#redis-on-wg0-the-home-box)) |
| `gitleaks` | A finding | [secrets.md "When gitleaks fails"](secrets.md#when-gitleaks-fails) |
| `app` | Goldens differ | Regenerate them only with the Flutter version in `app/.flutter-version`, on Linux x64. If only the runner differs, take them from the runner: see "Goldens and the Flutter pin" below (research R18). |
| `admin` | `pnpm install --frozen-lockfile` fails | Run `pnpm install` in `admin/` and commit `pnpm-lock.yaml` |
| `pwa` | Anything | [firebase-hosting.md "If it fails"](firebase-hosting.md#if-it-fails) |

## Goldens and the Flutter pin

`app/.flutter-version` (one stable `x.y.z`, now 3.47.7) is the only Flutter pin. `app.yml`'s
`check` job and `backend.yml`'s `clients` job read it, check it against
`^[0-9]+\.[0-9]+\.[0-9]+$`, and install that version with `subosito/flutter-action` (SDK
cached) on `ubuntu-24.04`. That pinned version on that pinned OS, with the fonts bundled
through `FontLoader`, renders the goldens, so the `app.yml` run is the reference (R18).

`app.yml` used to run in `ghcr.io/cirruslabs/flutter:<pin>`. That image has no `3.47.7` tag
(its newest, `3.44.0`, ships Dart 3.12.0, below `app/pubspec.yaml`'s `sdk: ^3.13.5`), so on
2026-10-30 the owner approved dropping the container (review finding M-R1-7). `pwa.yml`'s
`build` job had the same container and got the same change: it installs the pin with
`subosito/flutter-action` on `ubuntu-24.04`.

**When goldens differ in CI.** The committed goldens were rendered with Flutter 3.47.7 on a
Linux x64 host, not on the runner. If `flutter test (goldens included)` fails on pixel diffs:

1. Run the same on your machine with the pinned version:
   `cd app && flutter --version && flutter test`. If it fails there too, the change moved
   pixels: review it, run `flutter test --update-goldens`, and commit the PNGs.
2. If your machine passes and the runner doesn't, the two rasterize differently. Take the
   goldens from the runner: on a throwaway branch, change the step to
   `flutter test --update-goldens` and upload `app/test/goldens/` with
   `actions/upload-artifact`. Download the artifact, copy its PNGs into `app/test/goldens/`
   on the real branch, review the diffs and commit them. Lane M can make the throwaway change.

**Bumping Flutter.** Put the new stable version in `app/.flutter-version`. In `app/`, with
that version installed, run `flutter pub get`, `flutter analyze` and `flutter test`;
regenerate the goldens as above if they differ, and commit them with the pin.

## Re-running

```bash
R=AhmedSaied94/madar-sat
gh run list -R "$R" --workflow backend.yml -L 5
gh run view <id> -R "$R" --log-failed
gh run rerun <id> -R "$R" --failed        # same commit, current secrets
```

- `backend.yml` and `pwa.yml` also run by hand: `gh workflow run <file> -R "$R" --ref master`. For `backend.yml` that builds and deploys `master`'s newest commit.
- `infra.yml` has no manual trigger. To run `sync` again, re-run its newest `master` run.

## Prove the secret scan

The first half of T067 (SC-006):

```bash
git switch -c throwaway/gitleaks-proof
key="AKIA$(LC_ALL=C tr -dc 'A-Z2-7' < /dev/urandom | head -c 16)"   # the shape of gitleaks' aws-access-token rule
mkdir -p backend/tests && printf 'AWS_ACCESS_KEY_ID = "%s"\n' "$key" > backend/tests/fake_key.py
git add backend/tests/fake_key.py && git commit -m "test: gitleaks proof (do not merge)"
git push -u origin throwaway/gitleaks-proof
gh pr create -R AhmedSaied94/madar-sat --draft --title "gitleaks proof (do not merge)" --body "Throwaway PR for T067."
```

The `gitleaks` check must fail on the PR, naming `backend/tests/fake_key.py`. Then clean up:

```bash
gh pr close -R AhmedSaied94/madar-sat --delete-branch throwaway/gitleaks-proof
git switch master && git branch -D throwaway/gitleaks-proof
```

The key is random and fake, so nothing needs rotating. It stays in the closed PR's history on GitHub, which is fine for a fake.

The second half: a green run on `master` for each of `backend.yml`, `admin.yml`, `app.yml`, `infra.yml` and `pwa.yml`. That needs every lane merged at least once:

```bash
for w in backend admin app infra pwa; do
  gh run list -R AhmedSaied94/madar-sat --workflow "$w.yml" --branch master -L 1 --json conclusion,headSha -q ".[0] | \"$w \(.conclusion) \(.headSha[0:7])\""
done
```
