# Owner actions

This file lists the work only you can do: accounts, consoles, secrets, devices, and checks against the live hosts. Each day spec gets a section when its `/speckit-implement` finishes, with one subsection per lane. Tick an item when it's done, or say so and Claude ticks it.

The detailed steps stay in each spec's `tasks.md`, its quickstart and the [runbooks](runbooks/README.md). This file says what is left, in what order, and where to look. Your daily routine (merges, contract and migration reviews, the evening done check on devices: [delivery-plan.md](delivery-plan.md) §5.2, §5.4) isn't repeated here.

- **Before merge** items block the lane's PR.
- **After merge** items are checks on the live hosts. The day passes once they and its done check (delivery-plan Appendix A) pass.
- When a check fails, tell Claude what you saw. The fix goes in a follow-up PR, or in the next day's carry-over (delivery-plan §5.3).

## Open now

| Feature | Before merge | After merge | State |
| --- | --- | --- | --- |
| [001 D1 foundation](#001-d1-foundation) | none | none | **Done: signed off by the owner on 2026-10-30.** All tasks and owner items are ticked. Some were ticked without evidence (see [Day sign-off](#day-sign-off) and tasks.md "Done check"). **Carried into D2:** add `https://madar-sat--master-p2bbuj53.web.app` to `CORS_ORIGINS` on VPS-1 (the preview cannot load matches until then); back up the upload keystore; prove `app-release.yml` with a throwaway tag; enrol in Play App Signing; re-check the preview's Network tab after the PR #7 deploy. |
| [002 D2 core flows](#002-d2-core-flows) | **Lane B1:** none (done 2026-10-31) · **Lane B2:** none left that can run before the merge (the home box's worker and its dry run follow the first deploy) · **Lane A:** 2 items (the editors' devices, and the walk-through over WireGuard with its screenshots) · **Lane M:** 2 items (the screens against the design, and the merge) | **Lane B1:** 5 items (the deploy check, the first admin, one account per editor, the `404` from the internet, and the token-leak drill) · **Lane B2:** 8 items (hosts up, the first unattended run, the bridge, the home box's worker, `/srv/raw`, a logo, the firewall proof, and the queue decision) · **Lane A:** 2 items (`admin.yml` green, the first editor walk-through) · **Lane M:** 5 items (tag `app-v0.2.0`, Play App Signing and the closed-track upload, the testers list, the phone walk-through, and the PWA preview) | **All code lanes are done; the hosts, the first admin, the first run, the first release and the phone walk-through are yours.** Lane B2 builds on B1's `app.workers`, `app.media` and revisions `0003`–`0004`; Lane A is rebased on B1's T015 commit, so it carries the D2 admin client. Lane A's round-1, round-2 and round-3 fixes are closed (A-R1-1 … A-R1-24, A-R2-1 … A-R2-13 and A-R3-1, 176 tests); A-F1 (React Hook Form), A-F2 (`DataTable`) and T107's browser steps are open. Lane M's screens read the `/v1` API on VPS-1; its zones script (T133) and the two `app.yml` checks wait on you and B2. Its round-1, round-2 and round-3 review fixes are in `d02-features` (M-R1-1 to M-R1-17, M-R2-1 to M-R2-10 and M-R3-1 to M-R3-2, 480 tests). |

## Every month

This starts once production is live (B2's deploy, T066). Each item is one the docs define:

- Test a restore on a scratch container and record the result in `runbooks/restore.md`, which arrives on D8 (constitution IX, system-design §7.3, delivery-plan D8). Backups start on D3.
- Sign in to the OCI console and check that both instances run. Oracle may reclaim Always Free instances it considers idle; the pay-as-you-go upgrade, still free, reportedly removes the risk (system-design §7.2 and R5). → [provision-host](runbooks/provision-host.md)
- Check that Backblaze B2 is well under its 10 GB free tier, from D3 (system-design §7.3).
- Check that nothing charges: OCI, Firebase (with the $5 budget alert if on Blaze, delivery-plan A3) and GitHub Actions minutes on the private repo (constitution IX, system-design §2 G6).
- After V3: dependency updates and the KPI review (delivery-plan §6 "After V3", product-business §5).

Not monthly, but standing: answer takedown requests within 48 h (product-business §16, constitution).

## 001 D1 foundation

Planned on 2026-10-29 and merged to `master` as docs ([tasks.md](../specs/001-d01-foundation/tasks.md), [quickstart](../specs/001-d01-foundation/quickstart.md)). All four codebases exist, deploy through CI, and talk to one frozen `/v1` contract backed by the real snapshot. Each lane works on `d01-<lane>` in its own worktree.

The day's done check: VPS-1 serves `/v1` with snapshot data over HTTPS; the contract is tagged `v1`; the admin login screen renders against the mock; the app shows the component gallery (goldens pass) and loads `/v1/matches`; CI is green in all four folders ([quickstart](../specs/001-d01-foundation/quickstart.md#done-check-spec-sc-010)).

### Lane B1: data and contract

PR #2 merged on 2026-10-29. T024 and T048 were done the same day. T047 and T049 were ticked at the D1 sign-off on 2026-10-30 ([tasks.md](../specs/001-d01-foundation/tasks.md#lane-b1)).

#### Before merge, in this order

- [x] **T024 Contract freeze.** Review `git diff` of `backend/openapi/*.json` against [contracts/](../specs/001-d01-foundation/contracts/), then push the tag: `git tag -a contract-v1 -m "D1 contract freeze" && git push origin contract-v1` ([quickstart](../specs/001-d01-foundation/quickstart.md#lane-b1-data-and-contract)). Lane A's T082 and Lane M's T121 generate their clients from this tag, so it blocks both lanes. Then tell them.

  Tagged on 2026-10-29 at your request, on `master` at `231c221`. The contract files there are unchanged since B1's `390ba8a`. The diff review against `contracts/` wasn't done separately. Lanes A and M can now run T082 and T121, and `backend.yml`'s breaking-change check now runs.
- [x] **T025–T027 Migrations.** PR #2 already merged them, so read them on `master` line by line, as tasks.md "The owner must review" and delivery-plan §5.4 ask. → [database-migrations](runbooks/database-migrations.md)

#### After merge

These need B2's hosts up (T058, T060).

- [x] **Fresh snapshot.** In `../old_app`, run the README's "Refresh the snapshot" commands, then copy `migration/data/` to `~/madar-snapshot/`. Never copy it into `madar_sat/` ([quickstart Prerequisites](../specs/001-d01-foundation/quickstart.md#prerequisites); spec Edge Cases).
- [x] **T048 Snapshot on VPS-1.** Over WireGuard, `scp` the snapshot to `/srv/snapshot/<date>/` on VPS-1 (T048 step 1), and tell B1 to run the load. → [snapshot-load](runbooks/snapshot-load.md)

  Done on 2026-10-29. Both loads reconciled with the same counts (`load-report-20261029T180143Z`, `…180718Z`). `rehost-media` hosted 4,056 URLs with none failed (3,595 rehosted, 461 deduplicated). The API returns `304` on `If-None-Match`, and no media URL points at the old hosts.

### Lane B2: servers and CI

Merged on 2026-10-29 in PRs #3 and #4. T050–T063 are ticked; T064–T067 were ticked at the D1 sign-off on 2026-10-30 ([tasks.md](../specs/001-d01-foundation/tasks.md#lane-b2), [quickstart](../specs/001-d01-foundation/quickstart.md#lane-b2-servers-and-ci)).

The bootstrap and the GitHub secrets come before the merge. Merging touches `infra/` and `.github/`, so `infra.yml`'s `sync` job runs on `master` straight away and needs the hosts and the secrets.

#### Before merge, in this order

- [x] **Host facts.** Tell Claude:
  - whether both OCI VMs exist (delivery-plan A2);
  - each one's reserved public IP and VCN private IP;
  - the OS image (`bootstrap-vps.sh` assumes Ubuntu);
  - the login user.

  → [provision-host](runbooks/provision-host.md)
- [x] **T064 step 1 Serial console.** Test the OCI serial console on both hosts before any SSH change. It's the only way back in if SSH breaks (system-design §7.2, FR-023). → [provision-host](runbooks/provision-host.md#2-console-password-then-test-the-serial-console), [break-glass](runbooks/break-glass.md)
- [x] **OCI security list.** Open the ports in the security list (or an NSG), not only in iptables. VPS-1 needs 80/tcp, 443/tcp and 51820/udp from anywhere, plus 5432 and 6379 from VPS-2 inside the VCN. OCI's default list allows only 22 (Gaps 3). → [provision-host](runbooks/provision-host.md), [firewall-changes](runbooks/firewall-changes.md)
- [x] **Private repo, no `master` protection.** Decided 2026-10-29: the repo stays private and you're its only contributor, so `master` stays unprotected (GitHub Free can't protect a private repo's branch). Changes reach `master` through a green PR by convention (delivery-plan §5.1).
- [x] **Actions minutes.** A private repo's free Actions minutes are capped, and `backend.yml` builds arm64 images under QEMU, which is slow. Watch the usage after the first deploys.

  See Gaps 1. → [ci-workflows](runbooks/ci-workflows.md)
- [x] **Who runs the bootstrap.** Either you run it on the hosts and Claude gives you the commands, or you give a lane SSH access.
- [x] **Who generates the deploy key.** Either you do, or Claude generates the ed25519 pair locally and loads the private half into `DEPLOY_SSH_KEY` with `gh secret set`, without printing it. → [secrets](runbooks/secrets.md)
- [x] **T055, T057, T059 Review.** Read these yourself (tasks.md "The owner must review"):
  - the firewall rules: `infra/firewall/`, plus `decide_public_ssh` and `apply_firewall` in `infra/scripts/bootstrap-vps.sh`;
  - the `https://10.8.0.1` admin site in `infra/Caddyfile`;
  - `infra/scripts/deploy.sh`.

  → [firewall-changes](runbooks/firewall-changes.md), [deploy-and-rollback](runbooks/deploy-and-rollback.md)
- [x] **Commit and push the branch.** First run `/speckit-review-implementation lane=b2` until no CRITICAL or HIGH finding is left (delivery-plan §5.2). Then ask Claude to commit `d01-b2` and push it.
- [x] **T062 Firebase project.** Create the project if Day 0 step 2 isn't done. Give Claude its project ID: it goes into `infra/firebase/.firebaserc` and `CORS_ORIGINS`. Then set the secret `FIREBASE_SERVICE_ACCOUNT` yourself, from a service account with the Firebase Hosting Admin role. → [firebase-hosting](runbooks/firebase-hosting.md)
- [x] **ACME email and GHCR owner.** Give `ACME_EMAIL` for Let's Encrypt, and confirm the GHCR owner `ahmedsaied94`, which comes from the git remote. → [tls-certificates](runbooks/tls-certificates.md)
- [x] **T064 Bootstrap both hosts.**
  1. Run `bootstrap-vps.sh vps1` (then `vps2`). The first run creates `/srv/madar/.env` and stops.
  2. Fill in that `.env` (mode 600), then run the script again.
  3. Add WireGuard peers for your devices and for CI.
  4. Connect over WireGuard, then close public SSH with `--serial-console-tested`.
  5. Reboot both hosts, and confirm that `check-firewall.sh` passes and WireGuard comes back.

  The first run needs the repo's `infra/` on the host, and the repo is private (Gaps 23). → [provision-host](runbooks/provision-host.md), [private-network](runbooks/private-network.md)
- [x] **T050 GitHub secrets and variables.**
  - Secrets: `WG_CI_CONFIG` (the CI peer from T064), `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS` (VPS-1's host key line for `10.8.0.1`, taken over WireGuard) and `FIREBASE_SERVICE_ACCOUNT`.
  - Variables: `VPS1_IP` and `VPS2_IP`, plus `ARM_RUNNER` if you have one.

  Today none of them is set. → [secrets](runbooks/secrets.md), [ci-workflows](runbooks/ci-workflows.md)
- [x] **Merge the PR** once its checks are green.

#### After merge

- [x] **T058 Certificates.** After the first `infra.yml` `sync` run (or a manual `deploy.sh --infra-only`), confirm that `api.`, `media.` and `app.<ip1>.sslip.io` have Let's Encrypt certificates. → [tls-certificates](runbooks/tls-certificates.md)
- [x] **T065 Scan from outside.** On a machine not connected to WireGuard:
  - `nmap` shows only 80 and 443 open, and UDP 51820 answers;
  - each public host has a valid certificate and the system-design §8 headers;
  - `https://10.8.0.1` doesn't answer from the internet but does over WireGuard.

  nmap isn't installed on the dev machine. → [exposure-check](runbooks/exposure-check.md)
- [x] **T066 Deploy and rollback drill.**
  - Merge a trivial `backend/` change and confirm it's live within 15 minutes with no server step.
  - Run `backend.yml` with `break_healthcheck=true`: the job fails, and the previous tag is running again.
  - Confirm that GHCR keeps 3 versions.

  → [deploy-and-rollback](runbooks/deploy-and-rollback.md)
- [x] **GHCR package access.** After the first image push, give this repo the Admin role on the `madar-backend` package (`infra/README.md`), or the `retention` job can't delete old versions. → [ci-workflows](runbooks/ci-workflows.md)
- [x] **T067 Secret scan and green CI.**
  - Open a throwaway PR that adds a fake `AKIA…` key to a test file, confirm `gitleaks.yml` fails, then close it.
  - Get green `master` runs for `backend.yml`, `admin.yml`, `app.yml`, `infra.yml` and `pwa.yml`. The last three wait for Lanes A and M.

  → [secrets](runbooks/secrets.md), [ci-workflows](runbooks/ci-workflows.md)

### Lane A: admin

Implemented on 2026-10-29 on `d01-a` in the main checkout (`madar_sat`, not a `../madar-a` worktree), and opened as a PR. T068–T090 are ticked; T091 was ticked at the D1 sign-off on 2026-10-30, without the screenshots ([tasks.md](../specs/001-d01-foundation/tasks.md#lane-a), [quickstart](../specs/001-d01-foundation/quickstart.md#lane-a-admin)).

The client was generated from `contract-v1` (`master` at `231c221`) plus the contract fix below.

#### Before merge, in this order

- [x] **Contract fix, outside Lane A's folder.** Decided 2026-10-29: it merges with Lane A's PR. `d01-a` changes Lane B1's backend because the exported specs didn't match what the API sends: examples lost `"data": null` / `"error": null` (FastAPI drops `None` when it writes the document), error responses had no schema, and 422 was FastAPI's `HTTPValidationError` instead of the envelope. Prism served bodies the generated client rejected, and Orval's mocks didn't type-check.
  - Code: `backend/app/api/openapi.py` (new), `ErrorEnvelope` in `backend/app/api/envelope.py`, one line each in `backend/app/admin.py` and `backend/app/public.py`; test `backend/tests/contract/test_openapi_envelope.py`; re-exported `backend/openapi/public.json` and `admin.json`.
  - It comes after the `contract-v1` tag, so FR-014 applies: CI's oasdiff check (`--fail-on ERR`) against the tag reports no breaking change for either document (run locally on 2026-10-29). The API's behaviour is unchanged; only the documents now say what it sends. Lane M's client (T121) sees the new `ErrorEnvelope` once it regenerates after this merge.
- [x] **T091 Screens against the design.** Compare the screenshots with `Login.png` and `Main.png` (the A0 shell): `/login?mock=invalid_credentials`, `/login?mock=account_locked`, and the shell after `/login?mock=login_ok`, each at 1440 px and 1024 px (constitution "Done means", delivery-plan §5.4). Claude took them with the app in a fixed-size frame, because the window manager ignores browser resizes. Attach them to the PR.
- [x] **Commit and push.** Done 2026-10-29 at your request, without a `/speckit-review-implementation lane=a` round first; run one on the PR if you want it before merging. The untracked `.claude/settings.json` (Claude Code's local browser permission record) is left out.
- [x] **Merge the PR** once its checks are green.

### Lane M: app

Implemented on 2026-10-29 on `d01-m` in `../madar-m`; T092–T135 are ticked, T136 was ticked at the D1 sign-off on 2026-10-30, with its device steps (3, 4, 6) accepted without evidence ([tasks.md](../specs/001-d01-foundation/tasks.md#lane-m), [quickstart](../specs/001-d01-foundation/quickstart.md#lane-m-app)).

#### Before merge, in this order

- [x] **T136 step 3 On a phone.** Install the CI `app-prod-debug.apk` on an Android phone. Confirm that the matches route lists today's matches from VPS-1 (or `EmptyState`), and that `/gallery` opens. It needs VPS-1 serving `/v1` (B1's T048). A local debug build is at `app/build/app/outputs/flutter-apk/app-prod-debug.apk`.
- [x] **T136 step 4 Screens against the design.** Compare the gallery screenshots, in both themes, with the four design-system PNGs and `Matches.png` (delivery-plan §5.4).
- [x] **T136 step 5 No runtime font fetch.** Serve `app/build/web` and open `/gallery` and the matches route in Chrome DevTools → Network: no request to `fonts.gstatic.com` or `fonts.googleapis.com` (FR-042). Fix a hit by bundling the glyph, never by allowing the fetch. Two facts from the 2026-10-30 build, so the check doesn't surprise you: every glyph the app draws is bundled (Changa, IBM Plex Sans Arabic, IBM Plex Mono), so the engine's Noto fallback — the only `fonts.gstatic.com` string in `main.dart.js` — should never fire; but a default `flutter build web` loads CanvasKit from `www.gstatic.com/flutter-canvaskit`, which breaks the same rule. Lane B2 owns the fix in `.github/workflows/pwa.yml`: add `--no-web-resources-cdn` to the web build, which sets `useLocalCanvasKit: true` and serves `build/web/canvaskit/` (verified locally 2026-10-30).
- [x] **T136 step 6 Attach the evidence.** Put the screenshots and the Network result in the PR (constitution "Done means").
- [x] **Staging host.** Replace the placeholder LAN address in `app/env/staging.json` with the real LAN Caddy host (public value only). The `prod` values already point at `api.130.110.117.215.sslip.io` and `media.130.110.117.215.sslip.io`.
- [x] **Golden container tag: choose an image (blocks `app.yml`).** The pin `app/.flutter-version` = 3.47.7 has no `ghcr.io/cirruslabs/flutter` image. The newest tag is `3.44.0`, and it ships Dart 3.12.0, below `app/pubspec.yaml`'s `sdk: ^3.13.5`, so it can't build the app. Checked 2026-10-30 with `docker manifest inspect` on every 3.45–3.47 tag (none) and `flutter pub get` inside `3.44.0` ("version solving failed"). The goldens were therefore regenerated with Flutter 3.47.7 on the host (they now carry a dark ≠ light byte check and pass under `TZ=UTC`, `Africa/Cairo`, `America/New_York` and `Asia/Tokyo`). **Decided 2026-10-30:** drop the container. `app.yml` now installs the version in `app/.flutter-version` with `subosito/flutter-action` on `ubuntu-24.04`, as `backend.yml`'s `clients` job does; `app/.flutter-version` stays the only pin (research R18, amended). **Left:** the goldens were rendered on the host, not the runner, so the first `app.yml` run may show pixel diffs. If it does, take the goldens from the CI run and commit them (the runbook below gives the steps). `pwa.yml`'s `build` job got the same change (2026-10-30), so it no longer pulls the image either. → [ci-workflows](runbooks/ci-workflows.md#goldens-and-the-flutter-pin)
- [x] **Release signing (before the first release).** Done 2026-10-30. The upload keystore (PKCS12, RSA 4096, alias `upload`) is in `~/.config/madar-sat/` on the owner's machine, and the secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` are set on the repo. `app/android/app/build.gradle.kts` signs `release` with it when `android/key.properties` exists (else the debug key), and `.github/workflows/app-release.yml` builds the signed `prod` AAB on a tag `app-v<x.y.z>`. **Left for you:** (1) **back up the keystore and `keystore-password` to your password manager** (the only copy besides GitHub, which cannot return secrets); (2) prove the workflow once with a throwaway tag (`app-v0.0.1`, steps in the runbook); (3) enrol in Play App Signing and upload the AAB by hand until a Play service account exists. → [secrets](runbooks/secrets.md#rotate-the-android-upload-key), [ci-workflows](runbooks/ci-workflows.md)

### Day sign-off

**D1 was marked done by the owner on 2026-10-30, with every item below ticked in one step.** What was seen, what was accepted without evidence and what carries into D2 are listed in [tasks.md "Done check"](../specs/001-d01-foundation/tasks.md#done-check). Items that were ticked on trust, not on evidence, include: the serial-console test, the OCI security list, the reboot and `check-firewall.sh`, UDP 51820, the `break_healthcheck` drill, the throwaway gitleaks PR, the fresh snapshot copy, the review reads (T055, T057, T059), the admin and app screenshots, and the phone install.

- [x] **Done check 001.** Run it on the deployed `master` and on devices once all four lanes have merged, as in the [quickstart table](../specs/001-d01-foundation/quickstart.md#done-check-spec-sc-010). Write the carry-over notes for anything that fails (delivery-plan §5.2, §5.3).
- [x] **Defaults spec 001 used.** Confirm or change them (spec 001 Assumptions; delivery-plan §9):
  - O1: package ID `com.madarsat.app`;
  - O3: drop the card-sharing labels;
  - O10: default satellites Nilesat + Badr, which is due on D1.

## 002 D2 core flows

### Lane B1: admin API

Implemented on 2026-10-30 on `d02-b1` in `../madar-b1-d02` (a worktree off `master`; the main checkout stays on `d02-b2`). Every Lane B1 task is ticked except T015 (the PR) and T047 (the deploy check), which need you ([tasks.md](../specs/002-d02-core-flows/tasks.md#lane-b1), [quickstart](../specs/002-d02-core-flows/quickstart.md#lane-b1-admin-api)). Nothing is committed or pushed yet: say so when you want the contract PR.

What was checked locally: `ruff`, `mypy --strict` and the full `pytest --cov` run are green (coverage 97% on `app/domain` and `app/services`); the committed `admin.json` is what `export-openapi` writes; oasdiff against `contract-v1` reports no breaking change for either document, and `public.json` has no diff; Prism serves all 234 named response examples; the regenerated admin client type-checks, lints and passes its 78 tests. The Flutter generator (`swagger_parser` and `build_runner`) found `master`'s app client already stale: it lacks the `ErrorEnvelope` model that `public.json` has had since the D1 contract fix. That is the only difference (one line in `export.dart` and three new `error_envelope*.dart` files), and it is in the working tree for T015's PR, as CLAUDE.md allows. Nothing was run on a host.

#### Before merge, in this order

- [x] **T015 The contract PR (merge it first).** Reviewed on 2026-10-31 (delegated to Claude): `admin.json` matches `contracts/admin-api.md`, with `ETag`/`304` on exactly the nine list GETs and `logo_asset_id` required-nullable. It reached `d02-features` in PR #8 and goes to `master` with PR #12. It carries `backend/openapi/admin.json`, the regenerated admin client, and B2's morning blockers: the settings, `app.workers`, `app.media` and revision `0003` (T001, T006–T010). Lane B2 and Lane A wait for it. Read the `admin.json` diff against [contracts/admin-api.md](../specs/002-d02-core-flows/contracts/admin-api.md): round 3 adds a `304` and the `ETag` header to the nine admin list GETs, and `BroadcastPreset.logo_asset_id` (a required nullable field, which Lane A's A4 saves in a slot). Once it is on `master`, B2 and A rebase on it.
- [x] **T010 Revisions `0003` and `0004`.** Reviewed on 2026-10-31 (delegated to Claude): additive, idempotent, correct downgrades. Note for later migrations: 0003's CHECK validates in one step under an `ACCESS EXCLUSIVE` lock, fine at today's size; use `NOT VALID` + `VALIDATE` on a large table. Read `backend/alembic/versions/0003_audit_source_link_origin.py` and `0004_list_datasets.py` line by line: 0003 adds two nullable columns, one CHECK and one backfill; 0004 widens the dataset-name CHECK by `broadcast_presets` and `sources` and inserts their rows. All additive. → [database-migrations](runbooks/database-migrations.md#revision-0003)
- [x] **T031–T034 and T019 `backend/app/auth/` and the role dependency.** Reviewed on 2026-10-31 (delegated to Claude): no issues. The login reservation runs before the off-loop argon2 check, and reuse of a rotated token revokes the whole family. Read the password hashing, the tokens, refresh rotation with family revocation, the CSRF check, the login limits, and `require_editor` / `require_admin` with the test that walks every admin route. This is the code that guards the admin API.
- [x] **`ADMIN_JWT_SECRET`.** Set on VPS-1 by the owner on 2026-10-31. Put a value of at least 32 bytes in `/srv/madar/.env` on VPS-1 (`openssl rand -hex 32`, never committed). Every Compose command for VPS-1 (including the infra `sync`) fails at parse time when it is missing (`${ADMIN_JWT_SECRET:?…}`), so set it before the first deploy; `api-admin` also refuses to start with a value under 32 bytes. → [secrets](runbooks/secrets.md#where-they-live)

#### After merge

These need Lane B2's host changes (T078, T085).

- [ ] **T047 The deploy check.** `backend.yml` is green and ran `0003`; over WireGuard, the [quickstart](../specs/002-d02-core-flows/quickstart.md#lane-b1-admin-api) `curl` checks give `expires_in` 900, an `ETag` on a match, and `precondition_required` for a `PATCH` without `If-Match`. → [staff-accounts](runbooks/staff-accounts.md#check-an-account-works)
- [ ] **T047 The first admin.** In the "Working on VPS-1" shell, `dc run --rm cli create-admin --email … --name … --role admin`, and type the password at the prompt (it asks twice and shows nothing). There is no password argument on purpose. → [staff-accounts](runbooks/staff-accounts.md#create-an-account)
- [ ] **One editor account per editor.** The same command with `--role editor`, then give each person their password over a channel you trust. Lane A's T107 needs the first account. → [staff-accounts](runbooks/staff-accounts.md#create-an-account)
- [ ] **T047 Not on the internet.** `https://api.<ip1>.sslip.io/admin/api/…` answers `404` from outside WireGuard. → [exposure-check](runbooks/exposure-check.md)
- [ ] **Know the exit.** Deactivating someone, resetting a password and a suspected leak are in one runbook. → [staff-accounts](runbooks/staff-accounts.md#a-token-or-password-may-have-leaked)

### Lane B2: ingestion and hosts

Lane B2 built the ingestion pipeline and the hosts that run it: the `SourceAdapter` base, the ysscores adapter, the read-only Firestore bridge, entity resolution, the upsert pipeline, VPS-2's workers and `beat`, `worker-media` on VPS-1 and the home box ([tasks.md](../specs/002-d02-core-flows/tasks.md#lane-b2), [quickstart](../specs/002-d02-core-flows/quickstart.md#lane-b2-ingestion-and-hosts)).

#### Before merge, in this order

- [x] **T081–T085 Review the changes only you can approve.** Reviewed on 2026-10-31 (delegated to Claude): no blocking issue. The `homebox` user also has `+@scripting`, which is still bounded by its key patterns and excluded from `@admin` and `@dangerous`. The Redis ACL (`infra/redis/users.acl.tmpl`, the `--aclfile` switch in `vps1.yml`, and `infra/scripts/render-redis-acl.sh`, which writes the file 640 and its directory 750 for gid 999, keeps the previous file, and is what `deploy.sh` restores when Redis refuses a new one), the firewall rule that limits 6379 on `wg0` to one peer, `deploy.sh --host vps2` with its rollback, the home box's update script and units, and `backend.yml`'s new jobs (`build-amd64`, `deploy-vps2`, `stable`, the second retention step). → [firewall-changes](runbooks/firewall-changes.md#redis-on-wg0-the-home-box), [workers](runbooks/workers.md), [home-box](runbooks/home-box.md)
- [x] **T081 Re-run `bootstrap-vps.sh vps1` before the first D2 deploy.** Done on 2026-10-31 from `~/madar-infra`: `check-firewall.sh` reports the vps1 expectations in place, `deploy` is in gid 999 and `/srv/madar/redis` is group 999. On VPS-1 gid 999 already existed as `systemd-journal`, so the script reused it; `deploy` can read the journal, which adds nothing to its `docker` membership. It creates gid 999's group, makes `deploy` a member and corrects `/srv/madar/redis` to group 999; `deploy.sh` refuses to render the ACL without them, and Redis aborts on a directory it cannot traverse (B2-R2-1, B2-R2-10). Run it from this branch's `infra/`, not from `/srv/madar/infra` (CI's copy, which predates D2 until the merge deploys): `rsync -a --delete infra/ madar-vps1:madar-infra/`, then `ssh madar-vps1 'sudo ./madar-infra/scripts/bootstrap-vps.sh vps1'`. The 2026-10-31 attempt used CI's copy and changed nothing.
- [x] **The bridge now sends its key in `X-Goog-Api-Key`.** Nothing to configure: `SATAIR_FIREBASE_API_KEY` still lives only in VPS-2's `.env`. It just stops appearing in any URL, log line or error message (B2-R2-5, D15).
- [x] **T078–T080 VPS-2's `.env` and the new secrets.** Done on 2026-10-31: VPS-2 got the five D2 keys on top of its D1 file, and VPS-1 has `REDIS_HOMEBOX_PASSWORD` and `HOME_BOX_WG_IP=10.8.0.4`. VPS-2 does not take `ADMIN_JWT_SECRET`: only `vps1.yml` reads it ([secrets](runbooks/secrets.md#where-they-live)). In `/srv/madar/.env` on VPS-2: `DATABASE_URL`, `DATABASE_URL_SYNC` and `REDIS_URL` pointing at VPS-1's VCN IP, plus `MEDIA_BASE_URL`, `MEDIA_ROOT`, `MEDIA_REHOST_ALLOWED_HOSTS`, `CORS_ORIGINS`, `CELERY_BROKER_URL`, `SATAIR_FIREBASE_PROJECT_ID`, `SATAIR_FIREBASE_API_KEY`, `SCRAPE_USER_AGENT`, `YSSCORES_FETCH_QUEUE`, `RAW_ROOT=/srv/raw`. On VPS-1: `REDIS_HOMEBOX_PASSWORD` and `HOME_BOX_WG_IP`. Generate the passwords with `openssl rand -hex 32`. → [secrets](runbooks/secrets.md#where-they-live)
- [x] **T082–T085 GitHub.** Add the `VPS2_VCN_IP` repository variable, add VPS-2's host key to `DEPLOY_KNOWN_HOSTS`, and make sure the `deploy` user's public key is authorised on **both** VMs (the VPS-2 deploy jumps through VPS-1). Done on 2026-10-31: `VPS2_VCN_IP=10.1.0.118`, `DEPLOY_KNOWN_HOSTS` rebuilt with `10.8.0.1` and `10.1.0.118`, and VPS-2 bootstrapped from `~/madar-infra` with `DEPLOY_SSH_PUBLIC_KEY` copied from VPS-1 (its `authorized_keys` holds `deploy@ci` once, `/srv/raw` is uid 10001, the vps2 expectations are in place). Left for after the first push: give the repository the Admin role on the new `madar-backend-amd64` package.
- [ ] **T080–T084 Prepare the home box, before the first deploy.** Progress on 2026-10-31: the box (the owner's laptop) joined as peer `home-box` at `10.8.0.4`, on its own interface `wg-homebox` with `Table = off`, so only TCP to `10.8.0.1:6379` uses it and the laptop's `madar` admin tunnel is untouched. `HOME_BOX_WG_IP` is set on VPS-1. Left: the T081 bootstrap above, then the worker after the merge. Join it to `wg0` (`wg-add-peer.sh home-box`), write `HOME_BOX_WG_IP` on VPS-1 and re-run `bootstrap-vps.sh vps1` **before the first D2 deploy**: it adds the box's firewall rule, creates gid 999's group and makes `deploy` a member, and `deploy.sh` refuses to render the Redis ACL without it (B2-R2-10). **Start `worker-scrape` only after the first deploy**: before it there is no `madar-backend-amd64:stable` image, no `homebox` Redis user and no firewall rule, so the container would pull-fail forever. Write its `.env` and install the two systemd units at the same time. → [home-box](runbooks/home-box.md), [README](runbooks/README.md) stage 4 (the peer) and step 5.11 (starting the worker)
- [ ] **T083–T084 Review `deploy.sh --host vps2` and `home-box-update.sh` once more on the host**: `bash -n` them, and run `home-box-update.sh --dry-run` on the box (it only validates the Compose file). `bash -n` passed on both hosts on 2026-10-31 for `deploy.sh`, `bootstrap-vps.sh`, `render-redis-acl.sh`, `check-firewall.sh` and `home-box-update.sh`. The dry run needs the box's `/srv/madar/.env`, which is written with the worker after the merge.

#### After merge

- [ ] **T086 Hosts up.** `backend.yml`'s `deploy` and `deploy-vps2` are green, the amd64 image is tagged `stable`, VPS-1 shows `api-public`, `api-admin` and `worker-media` healthy, VPS-2 shows its four services healthy with exactly one `beat`, and the home box shows one healthy `worker-scrape` on `scrape_home`. → [workers](runbooks/workers.md#check-the-fleet)
- [ ] **T087 The first unattended run.** After the next `ysscores-fixtures` slot: `import_runs` shows a `succeeded` (or a `partial` with its reasons in `run.json`) run, `raw_path` exists on VPS-2, tomorrow's Cairo day has ysscores matches with UTC kickoffs, a second run reports `items_upserted = 0`, and a kickoff you locked in the admin is unchanged (SC-004). → [imports-and-sources](runbooks/imports-and-sources.md#read-what-a-run-did)
- [ ] **T087 The bridge.** Stop the home box's worker, start a `legacy` run by hand, and see tomorrow's fixtures with their channel links appear without duplicates; the orphan channel id is skipped and logged. → [imports-and-sources](runbooks/imports-and-sources.md#start-a-run-now)
- [ ] **Start the home box's worker.** Now `madar-backend-amd64:stable` exists and the `homebox` user is in the ACL: `sudo docker compose --env-file /srv/madar/.env -f infra/compose/home-box.yml up -d`, then check its log says it is consuming `scrape_home`. → [home-box](runbooks/home-box.md#start-and-check-the-worker)
- [ ] **`/srv/raw` exists on VPS-2.** `ls -ld /srv/raw` shows uid 10001 as the owner; if it is `root:root`, re-run `bootstrap-vps.sh vps2` (B2-R1-5). → [workers](runbooks/workers.md#raw-pages-and-retention)
- [ ] **T087 A logo arrives.** A new ysscores team with a logo on an allowlisted host gets its `logo_asset_id` filled by `worker-media`, and the app serves it from `media.<VPS1_IP>.sslip.io`. → [workers](runbooks/workers.md#worker-media-and-logos)
- [ ] **T082 Firewall proof.** From a second WireGuard peer (your laptop, not the home box), `nc -vz 10.8.0.1 6379` times out; from the home box, `redis-cli -u "$(sed -n 's/^REDIS_URL=//p' /srv/madar/.env)" --no-auth-warning ping` answers `PONG` (the box's `.env` holds the password inside `REDIS_URL`; it has no separate `REDIS_HOMEBOX_PASSWORD`). → [firewall-changes](runbooks/firewall-changes.md#redis-on-wg0-the-home-box)
- [ ] **Decide `YSSCORES_FETCH_QUEUE`.** Keep `scrape_home` (the home box fetches, the default) or switch to `scrape` on VPS-2 if the box is unreliable. → [imports-and-sources](runbooks/imports-and-sources.md#switch-where-ysscores-fetches)

### Lane A: admin

Implemented on 2026-10-30 on `d02-a` in `../madar-a` (a worktree off `d02-b1`, so the D2 admin client of T015 is already there), pushed and opened as a PR into `d02-features`. T090–T105 and T108 are ticked; T106 (the React Hook Form resolver) and T107's browser steps are open, with the rest of the first pass's shortcuts in [tasks.md](../specs/002-d02-core-flows/tasks.md#lane-a-follow-ups-open) ([quickstart](../specs/002-d02-core-flows/quickstart.md#lane-a-admin)).

Checked locally in `admin/`: `pnpm typecheck`, `pnpm lint`, `pnpm test` (165 tests), `pnpm build`, `./scripts/check-literals.sh`, `./scripts/check-token-copy.sh`, and `pnpm orval && git diff --exit-code src/api/generated/` is clean. Nothing was opened in a browser and nothing ran over WireGuard.

The review's round-1 items (A-R1-1 … A-R1-24) are closed in the same branch on 2026-10-31; [tasks.md](../specs/002-d02-core-flows/tasks.md#lane-a) records what each one changed. A-F1, A-F2 and T107's browser steps are below and at the end of that section. Round 2 (A-R2-1 … A-R2-13) and round 3 (A-R3-1) are closed on `d02-features` on the same date: `pnpm typecheck`, `pnpm lint` (0 errors, the same 25 warnings), `pnpm test` (176 tests), `pnpm build`, `./scripts/check-literals.sh` and `./scripts/check-token-copy.sh` all pass, and nothing was opened in a browser or over WireGuard. Round 3's one MEDIUM: a `409` whose refetch fails now says so instead of opening the conflict dialog from the cached version, and a failed background refetch no longer replaces the editor.

#### Code follow-ups, before the PR

Tracked here as well as at the end of [tasks.md](../specs/002-d02-core-flows/tasks.md#lane-a-follow-ups-open), so the first pass's shortcuts are not forgotten:

- [ ] **A-F1 React Hook Form.** A4 validates its assembled patch with Orval's `patchMatchBody` but does not resolve through React Hook Form yet (T106 stays unticked until it does).
- [ ] **A-F2 `DataTable`.** A3 draws its own table markup; move it onto the shared `DataTable` (grouping, bulk bar, skeleton, J/K/X/E) and delete the local markup.
- [x] **A-F3 Row version.** Done in round 1: B1's contract carries `AdminMatchRow.etag`, so a bulk action sends each row's version and never reads the match again.
- [ ] **A-F4 Create responses.** Orval emits no schema for 201-only operations, so the five `POST` creates are validated with the entity's `PATCH` envelope (same `$ref`). Revert when the spec gives creates their own schema.
- [x] **The 40 px button step (design tokens).** Withdrawn in round 2 (A-R2-3): the two smaller Button sizes are 48 px targets whose 40 and 32 px fills are clipped inside the element with a transparent band of border, so no `space-10` token is needed.
- [ ] **«أعد تطبيق تعديلاتي» in the conflict dialog.** Dropped on purpose on 2026-10-31: replaying a stale patch against a newer version is what the `If-Match`/`409` contract exists to prevent. The dialog keeps «إعادة التحميل» and «تجاهل تعديلاتي». Say so if you want the replay instead, and the API's conflict contract needs a decision first.

#### Before merge, in this order

- [ ] **T108 Editors' devices.** Add a WireGuard peer per editor's machine (`wg-add-peer.sh <name>`), give them its config, and install Caddy's internal root CA at `~/.config/madar/caddy-root.crt` (the one the WireGuard setup produced), so `NODE_EXTRA_CA_CERTS=… pnpm dev:wg` can reach `https://10.8.0.1` without a browser warning. → [private-network](runbooks/private-network.md#add-a-peer)
- [ ] **T107 steps 2–4 (T108 shows the same screens).** With Prism up: `/matches/48213?mock=edit_conflict`, `/matches/48213?mock=edit_conflict_source`, `/matches/48213?mock=precondition_required` and `/matches?mock=forbidden_remove_channels` (the save's example is asked for from the page that saves, A-R2-4). Then, after T047, `NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt pnpm dev:wg` and walk [quickstart Lane A](../specs/002-d02-core-flows/quickstart.md#lane-a-admin), including the two-browser conflict. `changeOrigin` is now `true` in `vite.config.ts` so Caddy receives its own site address (A-R2-13); confirm during the walk that every request reaches `https://10.8.0.1`. Take screenshots of A3, A4 and both dialogs at 1440 and 1024 and compare them with `Matches.png`, `MatchEditor.png` and `Dialogs.png`.

#### After merge

- [ ] **`admin.yml` on `master`.** The `check` job runs typecheck, lint, test, build and both scripts; read its log rather than assuming.
- [ ] **The first editor walk-through.** Sign in with an editor account, open tomorrow in A3, filter to missing channels, add two channels with commentators in A4, hide one channel from that match only, set a manual score, save, and confirm the change reaches the app.

### Lane M: app

Implemented on 2026-10-30 on `d02-m` in `../madar-m`, rebased onto `d02-features` after Lane A's PR #10, pushed and opened as a PR into `d02-features`. Every Lane M task is ticked except T133 (its script was blocked, below) and T135–T137, which are your device and release checks ([tasks.md](../specs/002-d02-core-flows/tasks.md#lane-m), [quickstart](../specs/002-d02-core-flows/quickstart.md#lane-m-app)).

What was checked locally, on Linux x64 with Flutter 3.47.7: `flutter analyze` reports no issues; `tool/check_literals.sh` and `tool/check_token_copy.sh` pass; the whole suite is 436 tests, all green under `TZ=UTC` and under `TZ=Africa/Cairo`, and `git status test/goldens` is the same before and after both runs. Not checked: anything on a phone or in a browser (T135–T137), the real VPS-1 API, and `./tool/test_all_zones.sh` itself.

#### Before merge, in this order

- [x] **T133 Run `./tool/test_all_zones.sh`.** Run by the owner on 2026-10-31. Claude's shell allowlist blocked the script, so its three steps were run by hand (above) instead. Run it once in `../madar-m/app` and tell Claude, who then ticks T133. If you'd rather Claude runs it, add it with `lean-ctx allow test_all_zones.sh`.
- [ ] **Look at the five screens against the design.** In `../madar-m/app` run `flutter run -d chrome -t lib/main_prod.dart --dart-define-from-file=env/prod.json` and compare S2, S3, S4, S5.1 and S5.2, in both themes, with `madar-design/app-flutter/screens/` (`Matches.png`, `Match-Prematch.png`, `Match-Live.png`, `Match-Channels.png`, `Match-NoChannels.png`, `MySatellites.png`, `Frequencies.png`, `Satellite.png`). Known differences from the boards: no pre-kickoff countdown boxes, bell or share button on S3 (D3); no date strip, live chip or «تعديل» on S4; group headers on S3 are full-bleed bars, not rounded cards.
- [x] **`CORS_ORIGINS` on VPS-1.** Done on 2026-10-31; the merge deploy recreates the APIs with it. Add `https://madar-sat--master-p2bbuj53.web.app` to `CORS_ORIGINS` in VPS-1's `/srv/madar/.env` and recreate the APIs; without it the PWA preview cannot load matches (carried over from D1). → [firebase-hosting](runbooks/firebase-hosting.md#4-the-preview-channel)
- [x] **Back up the upload keystore.** Done by the owner on 2026-10-31. Copy `~/.config/madar-sat/upload-keystore.jks` and `keystore-password` into your password manager, and check the fingerprint. GitHub cannot return a secret, so this is the only other copy. → [store-releases](runbooks/store-releases.md#1-back-up-the-upload-keystore)
- [ ] **Merge the PR** once its checks are green. The release tag is built from the commit it points at, so merge first.

#### After merge

- [ ] **T135 Tag `app-v0.2.0`.** `git switch master && git pull --ff-only && git tag app-v0.2.0 && git push origin app-v0.2.0`. `app-release.yml` builds the signed `prod` AAB, and its summary prints the upload key's SHA-256; it must match the one you noted when you backed the keystore up. Never re-run a finished run to get a new build. → [store-releases](runbooks/store-releases.md#2-tag-the-release)
- [ ] **T135 Enrol in Play App Signing and upload the AAB by hand.** Download `app-prod-release.aab` from the run, choose Google's key when Play asks, create the closed track, upload, write Arabic release notes and start the rollout. → [store-releases](runbooks/store-releases.md#3-get-the-aab)
- [ ] **T135 The testers list.** Add 12 or more testers (Google's rule for a new personal account is a closed test with 12 testers for 14 continuous days), send the opt-in link, and have one install from Play (SC-009). This starts the 14-day clock in [Calendar gates](#calendar-gates). → [store-releases](runbooks/store-releases.md#6-the-testers-list)
- [ ] **T136 Walk the app on a real Android phone**, from the closed-test build: S2 week paging, the live filter and pull to refresh; S3 on a match with 130 or more channels (the answer in under 1 s, smooth scrolling to the end), a commentator clip, copying a frequency, the reception video; S4 only Nilesat or Badr matches; S5.2 category switch and the `11843` search; then airplane mode, where S2–S5 show their cached copies with their age (SC-006 to SC-008). Take a screenshot of each screen in both themes and attach them to the PR. → [quickstart](../specs/002-d02-core-flows/quickstart.md#lane-m-app)
- [ ] **T137 The PWA preview.** After the `CORS_ORIGINS` change, open `https://madar-sat--master-p2bbuj53.web.app`, confirm S2 and S3 load data from VPS-1, and that DevTools → Network shows no request to `fonts.gstatic.com`, `fonts.googleapis.com` or a CanvasKit CDN. → [firebase-hosting](runbooks/firebase-hosting.md#4-the-preview-channel)

#### Round 1 review fixes (2026-10-31)

The review found one CRITICAL, six HIGH and eleven MEDIUM (M-R1-1 to M-R1-17). The code fixes are in `app/` on `d02-features`; these are the parts only you or Lane B2 can do.

- [x] **Lane B2's one `app.yml` step** (M-R1-2, M-R2-7). Checked on 2026-10-31: it is in the `check` job, right after `flutter test`. after the web build, `./tool/check_web_assets.sh build/web` fails when the output lacks `sqlite3.wasm` or `drift_worker.js`; without them the PWA cannot open its database, so S2–S5 all show «تعذّر تحميل البيانات». B2 owns `.github/workflows/`, so this is their edit, and their round-2 change already adds the web build and that step, with a comment saying the provider check stays out of CI; check it on the PR. The provider check is no longer a script: `app/test/architecture/providers_test.dart` runs inside `flutter test`, so no step is needed for it.
- [x] **T133 Run `./tool/test_all_zones.sh`** in `app/`. Run by the owner on 2026-10-31, so the Cairo pass is no longer owed. It runs the whole suite twice (UTC, then `Africa/Cairo`); the round-2 fixes were checked with one full run on the test box (480 tests, green), so the Cairo pass is still owed. The round-2 goldens were regenerated with the pinned Flutter 3.47.7 on that box (Ubuntu 24.04, the `app.yml` image); the round-1 ones came from this workstation, so the first `app.yml` run may still show pixel diffs on those. → [ci-workflows](runbooks/ci-workflows.md#goldens-and-the-flutter-pin)
- [ ] **T137 now also proves the database opens on the web.** The preview check above is the only place the PWA's drift database is exercised for real (M-R1-2). If a screen shows «تعذّر تحميل البيانات» while `/v1` answers, look for a missing `sqlite3.wasm` or `drift_worker.js` in the deployed `build/web`.
- [ ] **S3 copy and layout, on the device walk (T136).** Two owner decisions from 2026-10-31 are now built and worth a look next to the boards: the part is titled «على نايل سات وبدر» until the user has chosen satellites (the «حدد أقمارك» chip is deferred to D3 with its picker), and the expanded carriage row keeps its `FrequencyReadout` and adds «القمر / التردد / الاستقطاب / معدل الترميز / الوصول / الفئة» with the English satellite name (which carries its position) as an LTR island. The countdown line «تبدأ بعد …» appears in the hero more than an hour before kickoff.

#### Round 2 review fixes (2026-10-31)

The review found three HIGH and seven MEDIUM (M-R2-1 to M-R2-10); all are fixed in `app/`. The suite is 480 tests, green on the test box with Flutter 3.47.7, and the `carriage_row_*` and `segmented_*` goldens were regenerated there (Ubuntu 24.04, the same image `app.yml` uses), not on this workstation. The B2 step and T133 above are already updated for this round; what is new for you to look at:

- [ ] **S3's expanded carriage row next to `Match-Channels.png`** (M-R2-1, M-R2-8, M-R2-10) on the T136 walk: the tuning line now reads «11843 MHz» (number first) and the orbital position appears once, inside the English name («Nilesat 7.0W»), with «13.0°E» added only when the name leaves it out. The access row shows the provider and the package («مشفرة · beIN», «beIN Sports»).
- [ ] **The category tabs on S3 and S5.2 next to the FormControls board** (M-R2-9): the visible track is 48 dp with a 36 dp pill inside it, up from the board's 42 dp and down from round 1's 56 dp. If you prefer the board's exact look, say so and the 48 dp stays only as the hit area.
- [ ] **The polling policy** (M-R2-3), which the reviewer flagged for you: each screen now holds its own claim on the one `livePollingProvider`, so covering S2 with S3 stops S2's timers and leaves S3 polling. Nothing changes on screen; the check is that a live match on S3 keeps its score past a minute with S2 underneath.

#### Round 3 review fixes (2026-10-31)

Round 3 is **approve with notes**: no CRITICAL and no HIGH; two MEDIUM and three LOW. Both MEDIUMs are fixed in `app/`; the LOWs (a dispose test per notifier, the substring that de-duplicates the orbital position, and a `304` read after the generated client has parsed the body) are still open and not tasked. The suite is 480 tests, green on the test box, and `flutter analyze` is clean.

- [x] **Ask Lane B2 for one more `app.yml` step** (M-R3-2). Done on 2026-10-31: the `check` job runs `build_runner build -d` after `flutter pub get` and fails on any change or new file under `app/lib`. What was asked: a stale-`*.g.dart` check. It runs `dart run build_runner build -d` in `app/`, then `git diff --exit-code` over `app/lib`; `backend.yml`'s `clients` job only compares `app/lib/core/network/generated` and the admin client, so a provider `*.g.dart` left behind by a source change passes CI today. B2 owns the workflow.


## Known for later features

### Day 0 leftovers

Delivery-plan §6 Day 0 lists these, but nothing in the repo or on GitHub shows them done:

- the Play Console app with listing placeholders;
- the Apple enrollment;
- the Backblaze B2 account and a Telegram alert bot (both needed on D3);
- 12+ Android testers.

Confirm each one, or do it.

### Calendar gates

From delivery-plan §3. The docs count working days, not dates.

| Gate | Latest start | Takes | Blocks |
| --- | --- | --- | --- |
| Recruit 12+ Android testers | D0–D2 | — | The Play closed test |
| Play closed test: 12 testers for 14 days (if A1) | D2, the first AAB to the closed track | 14 calendar days, then a production-access review (a few days) | Android production; D12 submits "when the Play gate clears" |
| Play app review | Every submission | Hours to several days | Each Android release |
| Apple Developer enrollment | **D0** | Individual: 1–2 days. Organization: weeks (D-U-N-S) | The iOS days D13 and D16–D18 (A7 is checked on D13) |
| Firebase Blaze with a $5 budget alert (A3) | D0 | Minutes | The PWA launch on D4 without the quota risk |
| Bridge shadow run: 3 days of clean diffs | D2, when the bridge starts | ≥ 3 days (system-design §10: 1–2 weeks) | Retiring the bridge on D7 |
| AdMob app and consent setup | D5 | AdMob reviews the app once it's on the Play Store | Ads in Android production (D12) |
| Claude Design pass for the V3 screens | D17 | 1–2 days | D21. Delivery-plan §9 wants them by D20 |
| App Store review | D20 | 1–3 days, longer when rejected | iOS public |
| Public launch timing | Before launch | Be stable 2–3 weeks *before* a high-traffic period, such as the Champions League knockouts in February–March (product-business §17) | The launch date |

### Decisions due

From delivery-plan §9 and system-design §3.

| # | Decision | Needed by | Default | State |
| --- | --- | --- | --- | --- |
| A4 | Test bar | D0 | MVP bar | Decided 2026-10-29 (spec 001; constitution v1.1.0) |
| O1 | Package ID, after trademark and store-name checks (product-business §18) | D0; fixed before the first Play upload on D2 (A6) | `com.madarsat.app` | Default in use; confirm |
| O3 | Drop the card-sharing labels and BISS keys | D0 | Drop | Default in use; confirm |
| A1 | Play account type | D0 | Personal, created after Nov 2023 | Unconfirmed |
| A2 | Both VPSs running, with reserved IPs | D0 | — | Unconfirmed (B2 "Host facts") |
| A3 / O6 | Blaze with a budget alert, or Spark with the mirror design | D0 | Blaze | Unconfirmed (Gaps 2) |
| O5 | Apple enrollment as an individual or an organization | D0, to start it | Individual | Unconfirmed |
| O10 | Default satellites when the user skips | D1 | Nilesat + Badr | Default in use; confirm |
| O7 | Live data source for minute, events and lineups | **D4**, before spec 005 is planned | Manual live entry on D5 | Open |
| O8 | Keep Feeds | D7 | Drop from the app, keep the table | Open |
| O9 | Interstitial placement (P5) | D8 | On return from match detail | Open |
| O4 | Buy a domain (about $10/year) | D13 | Stay on sslip.io | Open |
| — | V3 designs ready | D20 | V3 starts with backend-first days | Open |
| — | Accounts provider | D20 | Firebase Auth | Open |
| O2 | The v1 feature cut (product-business §6) | Not scheduled; system-design §3.3 says it blocks phase 3 | Product-business §6 proposal | Open (Gaps 10) |
| P1–P6 | Confirm the proposals in system-design §3.2 | Not scheduled. P3, P4 and P6 are used from D1, P2 from D2, P1 from D3, P5 by D8 | As proposed | Built on; confirm (Gaps 10) |

### Owner work the later briefs already imply

Each day gets its full section when it's implemented. These lines come from the day briefs in delivery-plan Appendix B. Days not listed imply nothing beyond the daily routine.

- **D2:**
  - the first AAB to the Play closed track, which needs the upload keystore, Play App Signing and the closed track with testers (system-design §9 `app.yml`; Gaps 4);
  - a home scrape box on WireGuard;
  - access to the Firestore export the bridge reads (Gaps 11);
  - create the first admin with the CLI;
  - a WireGuard peer and Caddy's internal CA root on each admin device (system-design §5.4, §7.2);
  - test S2–S5 on a real Android phone.
- **D3:**
  - the Backblaze B2 bucket, its keys and the restic password on the host;
  - an OCI bucket for the media copy (Gaps 6);
  - the Telegram bot for alarms and Kuma;
  - FCM sender credentials for the dispatcher (Gaps 5);
  - review the push audience query ("reviewed by you");
  - test push on a real iPhone on iOS ≥ 16.4;
  - write the admin polish list that Lane A closes on D4.
- **D4:**
  - read the load-test report and the security-review results (no CRITICAL may stay open);
  - run the bug-bash on Android, the iPhone PWA and desktop;
  - approve making the PWA public (Gaps 13);
  - **decide O7**.
- **D5:** start the AdMob app and consent setup.
- **D6:**
  - an API-Football account and key on the host (Gaps 9);
  - review the audience queries for every push type;
  - send a test push from the composer.
- **D7:**
  - **decide O8**;
  - read the shadow-run diffs before the bridge is retired;
  - say who gets which alert, for the routing.
- **D8:**
  - **decide O9**;
  - give Lane A your admin bug notes;
  - check the restore drill;
  - switch maintenance and soft update in Remote Config on a device.
- **D9:**
  - the AdMob ad units;
  - an EEA test device for UMP consent;
  - read the load-test report at 5k concurrent users.
- **D10:** keep the emergency install link unpublished. It's only for a Firebase outage (system-design §5.2).
- **D12:**
  - the privacy policy (Gaps 14), the Play data-safety form and consent;
  - the store listing, with screenshots from real screens;
  - link the AdMob app;
  - turn on the V1 flags;
  - submit Android production once the Play gate clears.
- **D13:**
  - check A7;
  - **decide O4**;
  - a Codemagic account, iOS signing, and the APNs key added to Firebase.
- **D14:** if O4 bought a domain, its DNS records, then switch `api_base_url` and `media_base_url` in Remote Config once both names answer.
- **D15:** watch the ongoing notification during a real live match you follow. Pick a day that has one.
- **D16:**
  - enrol TOTP on your admin account and keep the recovery codes;
  - add yourself as a TestFlight internal tester.
- **D17:**
  - an App Store Connect API key for Codemagic;
  - start the Claude Design pass for the V3 screens.
- **D19:**
  - set up the external TestFlight testers;
  - enter the App Store assets and privacy labels.
- **D20:**
  - submit iOS to App Review (guideline 4.2 needs native value, product-business §16);
  - turn on the V2 flags;
  - **decide** that the V3 designs are ready, and choose the accounts provider.
- **D21:**
  - turn on Google, Apple and email-link sign-in in the accounts provider;
  - update the privacy policy for accounts (Gaps 15).
- **D22:** enter the web deletion URL wherever the store rules ask for it.
- **D24:** read the leaderboard load-test report.
- **D27:**
  - the ad-free in-app product and license testers in Play Console (Gaps 16);
  - a Play Developer API service account, with its key on the host only (mode 600, never in CI logs).
- **D29:** approve the English copy (Gaps 17).
- **D30:**
  - a sponsor and the slot's schedule (Gaps 18);
  - turn on the V3 flags;
  - submit the store releases.

## Gaps

Places where the docs conflict, or say nothing about an owner step. Fix each one in the doc it names, then delete it here.

1. **Resolved 2026-10-29: `master` protection.** The repo stays private with one contributor, so `master` is unprotected; delivery-plan §5.1, Day 0 step 4 and the D1 spec now say so. (Kept here so the later gap numbers don't shift.)
2. **The Firebase plan.** Delivery-plan A3 assumes Blaze. System-design §2 (G6 and the constraints) and constitution IX describe Spark at $0, and system-design §3.3 still lists O6 as open.
3. **The OCI security list.** No task or delivery-plan step opens the ports in OCI's security list. System-design §7.2 only mentions it in passing ("even when the security list allows them").
4. **The Play tracks:**
   - system-design §9 `app.yml` uploads to the **internal** track;
   - delivery-plan D2 and §3 use the **closed** track with 12 testers;
   - product-business §17 plans an internal-track beta with 20–50 testers.

   No day schedules the upload keystore, Play App Signing or the first upload.
5. **FCM sender credentials.** System-design §6.8 sends with `firebase-admin`, but no doc says which service account it uses or where its key lives.
6. **The media bucket.** The OCI bucket for the media copy (system-design §6.9, §7.3) isn't on the Day 0 list, and its credentials aren't described.
7. **The home scrape box.** Delivery-plan D2 and system-design §7.2 need one by D2. It isn't on the Day 0 list, and no doc describes its hardware or setup.
8. **The admin's internal CA root.** It must be on each admin device for D2's done check (system-design §5.4), but no day lists it.
9. **API-Football.** The account it needs (delivery-plan D6, system-design §6.6) isn't on the Day 0 list.
10. **O2 and P1–P6 have no date.** Delivery-plan §9 schedules neither the v1 cut nor the confirmation of the proposals. Product-business §18 places O1–O3 and O7 in system-design §3.2; they are in §3.3.
11. **The bridge's source.** The bridge diffs against "a fresh Firestore export" (delivery-plan D2; system-design §10 step 5). But system-design §3.1 D1 says owner access to `satair-6983b` returns 403. The docs don't say whether `export-firestore.mjs` works without it.
12. **The laptop's WireGuard key.** Delivery-plan Day 0 step 6 creates the laptop's key on the laptop. T056's `wg-add-peer.sh` generates every peer's keys on the host.
13. **What "public" means on D4.** Delivery-plan makes the PWA public on D4. Product-business §17 plans a closed beta, then an open beta, then a launch timed before a high-traffic period, and the docs don't say which stage D4 is.
14. **The privacy policy.** Product-business §16 requires the page, and the V1 gate checks it. No doc says where it's hosted or who writes it.
15. **Accounts in V3.** Product-business §16 assumes no accounts. No doc says who updates the privacy policy and the store forms on D21–D22, or how the Apple and email-link providers are set up.
16. **Selling ad-free.** No doc covers the Play Console setup needed to sell an in-app product (D27).
17. **The English copy.** Product-business §14's voice and glossary are Arabic only. No doc says who writes and approves the English strings for D29.
18. **The sponsor.** Product-business §5 lists sponsorship as "Later", and delivery-plan schedules it on D30. Neither says where the sponsor comes from.
19. **Secret rotation.** System-design §8 says where secrets live, but nothing sets a rotation schedule.
20. **The admin API's port.** System-design §4 puts `api-admin` on 10.8.0.1:8100. The tasks, R12, the plan and B1's Dockerfile use 8001.
21. **D1 departs from system-design §9:**
    - `pwa.yml` deploys a preview channel from `master`, not `web-v*` tags;
    - `admin.yml` doesn't deploy;
    - `app.yml` builds a debug APK.

    System-design §9 should say these are D1's shape.
22. **Missing runbooks.** These owner procedures have no runbook in the list yet: Play Console and releases, Apple and App Store Connect, AdMob, Telegram and Kuma alerts, and Remote Config changes. The restore runbook, `runbooks/restore.md`, comes with D8.
23. **Getting `infra/` onto a host the first time.** The README and quickstart run `bootstrap-vps.sh` "from a checkout of this repo" on the host. The repo is private, and no doc says how the first checkout gets there.
24. **Unused repo variables.** T050 and `infra/README.md` list the repo variables `VPS1_IP` and `VPS2_IP`, but B2's implementation reports that no workflow reads them.
