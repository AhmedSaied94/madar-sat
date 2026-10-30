# CI workflows

One workflow per folder, each filtered to its own paths, plus `gitleaks` on everything. This runbook lists what each one checks, the usual failures and their fixes, how to re-run, and the T067 proofs. Only `backend.yml`'s `deploy` and `infra.yml`'s `sync` touch production. Background: research R14, and `.github/workflows/`.

## What runs where

| Workflow | Runs on | Jobs | Secrets |
| --- | --- | --- | --- |
| `backend.yml` | Pushes to `master` and PRs that change `backend/**` or the workflow; by hand, with `break_healthcheck` | `test`, `openapi`, `clients`; on `master` also `build`, `deploy`, `retention` | `WG_CI_CONFIG`, `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS` |
| `infra.yml` | Pushes to `master` and PRs that change `infra/**`, `.github/workflows/**` or `.github/actions/**` | `check`: `docker compose config` for the three Compose files, `caddy validate`, shellcheck, actionlint. On a `master` push also `sync`. | The same three, for `sync` |
| `gitleaks.yml` | Every push to any branch, and every PR | `scan`: the full history, redacted | None |
| `app.yml` | Pushes to `master` and PRs that change `app/**`, `backend/openapi/public.json`, `madar-design/**` or the workflow | `check`: `flutter analyze`, the token-copy and literal checks, `flutter test` (goldens), the `prod` debug APK as the artifact `app-prod-debug.apk` | None |
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
| `backend` `deploy`, `infra` `sync` | Anything | [deploy-and-rollback.md "Reading a failed deploy"](deploy-and-rollback.md#reading-a-failed-deploy) |
| `backend` `retention` | 403 or 404 | The repository lacks the Admin role on the package ([deploy-and-rollback.md "Images in GHCR"](deploy-and-rollback.md#images-in-ghcr)) |
| `infra` `check`, Compose | `required variable … is missing a value` | Add the variable to `infra/compose/example.env`, which must list every variable the Compose files use |
| `infra` `check`, Caddy | `adapting config using caddyfile: …` | Fix `infra/Caddyfile`. The check runs with `example.env`'s values. |
| `infra` `check`, shellcheck or actionlint | Findings | Fix the script or workflow |
| `gitleaks` | A finding | [secrets.md "When gitleaks fails"](secrets.md#when-gitleaks-fails) |
| `app` | Goldens differ | Regenerate them in the pinned image `ghcr.io/cirruslabs/flutter:<app/.flutter-version>`, never on your machine (research R18). No image exists for the current pin: see "The golden image is not published" below. |
| `admin` | `pnpm install --frozen-lockfile` fails | Run `pnpm install` in `admin/` and commit `pnpm-lock.yaml` |
| `pwa` | Anything | [firebase-hosting.md "If it fails"](firebase-hosting.md#if-it-fails) |

## The golden image is not published

`app/.flutter-version` pins Flutter 3.47.7, and `app.yml` and `pwa.yml` use it as the image
tag, which is how the goldens stay host-independent (R18). `ghcr.io/cirruslabs/flutter` has
no `3.47.7` tag — its newest is `3.44.0`, which ships Dart 3.12.0 and cannot resolve
`app/pubspec.yaml` (`sdk: ^3.13.5`):

```bash
docker manifest inspect ghcr.io/cirruslabs/flutter:3.47.7     # no such manifest
docker run --rm ghcr.io/cirruslabs/flutter:3.44.0 flutter --version   # Dart 3.12.0
docker run --rm -v "$PWD/app":/app -w /app ghcr.io/cirruslabs/flutter:3.44.0 flutter pub get
```

Until the owner picks one of these, both workflows fail at the image pull and the `app`
gates can only be run on a host with Flutter 3.47.7:

- wait for the `3.47.7` image, then push any commit to re-run;
- publish the image from this repo (a one-stage job on `python`/`debian` plus the SDK);
- approve moving the app to Flutter 3.44.0: lower `sdk:` in `app/pubspec.yaml`, re-resolve
  `app/pubspec.lock`, then regenerate every golden in that image.

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
