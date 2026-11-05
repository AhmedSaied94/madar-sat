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
| [002 D2 core flows](#002-d2-core-flows) | **Lane B1:** none (done 2026-10-31) · **Lane B2:** none left that can run before the merge (the home box's worker and its dry run follow the first deploy) · **Lane A:** 2 items (the editors' devices, and the walk-through over WireGuard with its screenshots) · **Lane M:** 2 items (the screens against the design, and the merge) | **Lane B1:** 5 items (the deploy check, the first admin, one account per editor, the `404` from the internet, and the token-leak drill) · **Lane B2:** 5 items (the first unattended run, the bridge, a logo, the firewall proof, and the queue decision; hosts up, the home box's worker and `/srv/raw` are done) · **Lane A:** 1 item (the first editor walk-through; `admin.yml` is green) · **Lane M:** 5 items (tag `app-v0.2.0`, Play App Signing and the closed-track upload, the testers list, the phone walk-through, and the PWA preview) | **All code lanes are done; the hosts, the first admin, the first run, the first release and the phone walk-through are yours.** Lane B2 builds on B1's `app.workers`, `app.media` and revisions `0003`–`0004`; Lane A is rebased on B1's T015 commit, so it carries the D2 admin client. Lane A's round-1, round-2 and round-3 fixes are closed (A-R1-1 … A-R1-24, A-R2-1 … A-R2-13 and A-R3-1, 176 tests); A-F1 (React Hook Form), A-F2 (`DataTable`) and T107's browser steps are open. Lane M's screens read the `/v1` API on VPS-1; its zones script (T133) and the two `app.yml` checks wait on you and B2. Its round-1, round-2 and round-3 review fixes are in `d02-features` (M-R1-1 to M-R1-17, M-R2-1 to M-R2-10 and M-R3-1 to M-R3-2, 480 tests). |
| [003 D3 follow, push and sources](#003-d3-follow-push-and-sources) | **Lane B1:** 5 items (the contract diff, revisions `0005` and `0006`, the audience query, the rate-limit values) · **Lane B2:** 8 items (the matching, backup and Kuma reviews, the Telegram bot, the B2 and OCI buckets, the FCM key with B1, and the bootstrap re-run for the backup timers) · **Lane A:** 2 items (the WireGuard walk and the screenshots; B1's two contract additions are done) · **Lane M:** the Firebase identifiers, the VAPID key, the privacy and share links, the merge | **Lane B1:** 2 items (the deploy with `0005`, the FCM key and the first real reminder, which also covers T045's step 4) · **Lane B2:** 6 items (the deploy check, the Kuma monitors, the first LiveSoccerTV run, the breaker drill, the first backups, the stopped-worker drill) · **Lane A:** 1 item (the deployed editor walk-through) · **Lane M:** the Android and iPhone walks, the closed-test build, the Remote Config parameters | **Round 2 (2026-11-01/02), all lanes merged on `003-d03-follow-push-sources`:** the 10 open review fixes are done (B1-R2-1/2, B2-R2-1/2, A-R1-1/5, M-R2-1 … 4), with backend 95.21% coverage, 240 admin tests and the app suite green; T045 passes steps 1–3 and 5–8 locally, its step 4 moves to T047; the bare-form `KUMA_PUSH_URL_*` values (T086) are yours. Earlier: **Lane B1 is merged into `003-d03`** (PR #16) and its round-1 review fixes (B1-R1-1 to B1-R1-6) are on `d03-b1`, with revision `0006`; **Lane B2 is written on `d03-b2` and rebased onto it, with `0005` applied and the whole backend suite green** (PR #17, merged); its round-1 review fixes (B2-R1-1 to B2-R1-8) are on `d03-b2`, CI-proven and awaiting review. **Lane A** is written on `d03-a` and merged up: T088–T105 done, and its round-1 fixes are in the main checkout (236 admin tests) except the two that need B1 — per-row `etag` on the competition and satellite lists (A-R1-1) and `kind` in `ChannelPatch` (A-R1-5) — with aliases a third recorded gap (PR #18). Nothing is deployed or run on a host yet. **Lane M is written on `d03-m` in `../madar-d03-M`** and its round-1 review fixes (M-R1-1 … M-R1-12, including the T133 device registration and follow sync) are on that branch (605 app tests green on the test box). |
| [004 D4 MVP launch](#004-d4-mvp-launch) | **Lane B1:** 4 items (the `TRUSTED_PROXIES` and `RATE_LIMIT_EXEMPT_IPS` reads, the load-testing runbook, and the whole-repository security review which needs the `security-reviewer` agent) · **Lane B2:** 7 items (re-run the VPS-1 bootstrap first, the media backup's rclone remote, Kuma's Telegram notification (the home box is back, and its Kuma monitor exists), the one-time network recreation, `TRUSTED_PROXIES_PUBLIC` only if the default is wrong, `MIRROR_BASE_URL` in `APP_ENV_PROD`, Kuma's `pwa-mirror` URL) · **Lane A:** 1 item (the admin polish list — the owner writes it; «none» is an answer) · **Lane M:** 3 items (the phone check of the carry-over, `MIRROR_BASE_URL`, the merge) | **Lane B1:** 4 items (two networks for `SR-1`, the load test and its report, the host review with gitleaks, and any HIGH you must accept) · **Lane B2:** 7 items (the backup heartbeat, the mirror headers, the admin deploy, the `web-v0.1.0` tag, the report re-run, LiveSoccerTV after its fix, the home box healing itself) · **Lane A:** 3 items (the test account and match, the live smoke runs three times, and the screenshots carried from 002 and 003) · **Lane M:** 5 items (the preview channel, tag `app-v0.3.0`, the bug bash, the live timings, the public link) | **Lane B1 is written on `d04-b1`** in `../madar-b1`, cut from `master` (`acbfece`): the client-IP fix, the allowlist, the k6 script and the runbook; `ruff`, `mypy --strict` and the backend suite are green (1374 passed; the 4 `test_homebox_acl.py` failures are this machine's Redis password, as in D3), and the contract is unchanged. Nothing is deployed and nothing ran on a host. **Lane B2 is written on `d04-b2` in `../madar-b2`**, with the report CLI, the Compose subnet and trust list, the mirror and release rules, the admin deploy job and three new `infra.yml` checks. Its import report already found the day's real problem: the home box is offline, so `ysscores` and `livesoccertv` have not ingested since 2026-11-02. Nothing is deployed yet. **Lane A is written on `d04-a`** in `../madar-a`, rebased on this branch: the Playwright smoke test passes against Prism, `pnpm build` loads under the CSP with no console violations, and the Vitest suite is green (241 tests). The live run, the screenshots and FR-023 wait on the owner's list and on B2's admin deploy (T040). Lane M has not started. **Lane M is written on `d04-m`** in `../madar-m`, rebased on this branch: the three D3 fixes, the hashed release (stage script, service worker, bootstrap, the drift wasm URL) and the S16 install row; 657 app tests green on the test box, 90.6 % line coverage excluding generated code, and the staged layout built from a real `flutter build web`. Nothing has run on a host, a console or a device yet. **Round-1 review fixes (2026-11-03) are in on `004-d04-mvp-launch`, uncommitted:** the k6 `matches` query and per-scenario thresholds, the runbook's real allowlist checks, the release job's mirror read, every VPS-1 job in `deploy-vps1` without the `infra/` rsync, the admin symlink check (B2 adds **re-run the bootstrap on VPS-1** first under "Before merge"), the smoke test's live finder and mock isolation, a classic `sw.js` and the bootstrap's mirror fallback. Nothing new is deployed. **Launch checks (2026-11-03, after the merge):** T008 and T012 pass, and the security review has no CRITICAL or HIGH ([security-review.md](../specs/004-d04-mvp-launch/security-review.md)). **The load test failed** ([report](load-tests/2026-11-03-mvp.md): p95 ≈ 5 s, VPS-1's one core saturated), so the fix (more OCPU, or the Caddy `/v1/live` cache) and SR-2 are your decisions. |
| [005 D5 live and discovery](#005-d5-live-and-discovery) | **Lane B1:** 3 items (the `0007` and contract review, merge order, the capture's match) · **Lane B2:** 3 items (T001, the shared-parts PR, the OCI check and resize) · **Lane A:** 1 item (the screenshots against the boards) · **Lane M:** the device walk, the merge | **Lane B1:** 3 items (the live checks, the done-check match, the load re-run after your resize) · **Lane B2:** 5 items (`worker-live` healthy, Telegram on VPS-2, the `celery-live` monitor, the YallaKora run on the live host, the disk check) · **Lane A:** 2 items (the WireGuard walk with SC-007's timing, on rows the importers have filled) · **Lane M:** the `features` switch, tags `app-v0.4.0` and `web-v0.2.0` | **All four lanes and their round 1 review fixes are merged on the spec branch**, which goes to `master` as one PR; nothing is deployed. The combined backend suite and 802 app tests are green locally. The capture waits on a deploy and a live match. |
| [031 D5 follow-up: live sources](#031-d5-follow-up-live-sources) | **Before lanes:** bring #39 or `master` into `d05-b1` and `d05-b2` | **Lane B1:** the `0008` review, the capture night, the watched match. **Lane B2:** T033's host check, before the capture | Lanes B1 and B2 are merged into `005-d05-live-and-discovery`. Parsers, rules, Goal.com and the capture tool pass their tests. B1's round 1 review fixes (B1-R1-1 to R1-5) are in and need a round 2 review. B2's round 1 review approved with notes. The capture and the watched match wait for a deploy and a match night |

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

- [x] **T047 The deploy check.** `backend.yml` is green and ran `0003`; over WireGuard, the [quickstart](../specs/002-d02-core-flows/quickstart.md#lane-b1-admin-api) `curl` checks give `expires_in` 900, an `ETag` on a match, and `precondition_required` for a `PATCH` without `If-Match`. Done on 2026-10-31 against match 1 with the first admin: `900`, an `etag:` header and `"precondition_required"`; the database is at `0004`. → [staff-accounts](runbooks/staff-accounts.md#check-an-account-works)
- [x] **T047 The first admin.** In the "Working on VPS-1" shell, `dc run --rm cli create-admin --email … --name … --role admin`, and type the password at the prompt (it asks twice and shows nothing). There is no password argument on purpose. Done on 2026-10-31: `created admin … (id 1)`. → [staff-accounts](runbooks/staff-accounts.md#create-an-account)
- [ ] **One editor account per editor.** The same command with `--role editor`, then give each person their password over a channel you trust. Lane A's T107 needs the first account. → [staff-accounts](runbooks/staff-accounts.md#create-an-account)
- [x] **T047 Not on the internet.** `https://api.<ip1>.sslip.io/admin/api/…` answers `404` from outside WireGuard. Checked on 2026-10-31: `GET /admin/api/healthz` and `POST /admin/api/auth/login` on `api.130.110.117.215.sslip.io` both answer `404`. → [exposure-check](runbooks/exposure-check.md)
- [ ] **Know the exit.** Deactivating someone, resetting a password and a suspected leak are in one runbook. → [staff-accounts](runbooks/staff-accounts.md#a-token-or-password-may-have-leaked)

### Lane B2: ingestion and hosts

Lane B2 built the ingestion pipeline and the hosts that run it: the `SourceAdapter` base, the ysscores adapter, the read-only Firestore bridge, entity resolution, the upsert pipeline, VPS-2's workers and `beat`, `worker-media` on VPS-1 and the home box ([tasks.md](../specs/002-d02-core-flows/tasks.md#lane-b2), [quickstart](../specs/002-d02-core-flows/quickstart.md#lane-b2-ingestion-and-hosts)).

#### Before merge, in this order

- [x] **T081–T085 Review the changes only you can approve.** Reviewed on 2026-10-31 (delegated to Claude): no blocking issue. The `homebox` user also has `+@scripting`, which is still bounded by its key patterns and excluded from `@admin` and `@dangerous`. The Redis ACL (`infra/redis/users.acl.tmpl`, the `--aclfile` switch in `vps1.yml`, and `infra/scripts/render-redis-acl.sh`, which writes the file 640 and its directory 750 for gid 999, keeps the previous file, and is what `deploy.sh` restores when Redis refuses a new one), the firewall rule that limits 6379 on `wg0` to one peer, `deploy.sh --host vps2` with its rollback, the home box's update script and units, and `backend.yml`'s new jobs (`build-amd64`, `deploy-vps2`, `stable`, the second retention step). → [firewall-changes](runbooks/firewall-changes.md#redis-on-wg0-the-home-box), [workers](runbooks/workers.md), [home-box](runbooks/home-box.md)
- [x] **T081 Re-run `bootstrap-vps.sh vps1` before the first D2 deploy.** Done on 2026-10-31 from `~/madar-infra`: `check-firewall.sh` reports the vps1 expectations in place, `deploy` is in gid 999 and `/srv/madar/redis` is group 999. On VPS-1 gid 999 already existed as `systemd-journal`, so the script reused it; `deploy` can read the journal, which adds nothing to its `docker` membership. It creates gid 999's group, makes `deploy` a member and corrects `/srv/madar/redis` to group 999; `deploy.sh` refuses to render the ACL without them, and Redis aborts on a directory it cannot traverse (B2-R2-1, B2-R2-10). Run it from this branch's `infra/`, not from `/srv/madar/infra` (CI's copy, which predates D2 until the merge deploys): `rsync -a --delete infra/ madar-vps1:madar-infra/`, then `ssh madar-vps1 'sudo ./madar-infra/scripts/bootstrap-vps.sh vps1'`. The 2026-10-31 attempt used CI's copy and changed nothing.
- [x] **The bridge now sends its key in `X-Goog-Api-Key`.** Nothing to configure: `SATAIR_FIREBASE_API_KEY` still lives only in VPS-2's `.env`. It just stops appearing in any URL, log line or error message (B2-R2-5, D15).
- [x] **T078–T080 VPS-2's `.env` and the new secrets.** Done on 2026-10-31: VPS-2 got the five D2 keys on top of its D1 file, and VPS-1 has `REDIS_HOMEBOX_PASSWORD` and `HOME_BOX_WG_IP=10.8.0.4`. VPS-2 does not take `ADMIN_JWT_SECRET`: only `vps1.yml` reads it ([secrets](runbooks/secrets.md#where-they-live)). In `/srv/madar/.env` on VPS-2: `DATABASE_URL`, `DATABASE_URL_SYNC` and `REDIS_URL` pointing at VPS-1's VCN IP, plus `MEDIA_BASE_URL`, `MEDIA_ROOT`, `MEDIA_REHOST_ALLOWED_HOSTS`, `CORS_ORIGINS`, `CELERY_BROKER_URL`, `SATAIR_FIREBASE_PROJECT_ID`, `SATAIR_FIREBASE_API_KEY`, `SCRAPE_USER_AGENT`, `YSSCORES_FETCH_QUEUE`, `RAW_ROOT=/srv/raw`. On VPS-1: `REDIS_HOMEBOX_PASSWORD` and `HOME_BOX_WG_IP`. Generate the passwords with `openssl rand -hex 32`. → [secrets](runbooks/secrets.md#where-they-live)
- [x] **T082–T085 GitHub.** Add the `VPS2_VCN_IP` repository variable, add VPS-2's host key to `DEPLOY_KNOWN_HOSTS`, and make sure the `deploy` user's public key is authorised on **both** VMs (the VPS-2 deploy jumps through VPS-1). Done on 2026-10-31: `VPS2_VCN_IP=10.1.0.118`, `DEPLOY_KNOWN_HOSTS` rebuilt with `10.8.0.1` and `10.1.0.118`, and VPS-2 bootstrapped from `~/madar-infra` with `DEPLOY_SSH_PUBLIC_KEY` copied from VPS-1 (its `authorized_keys` holds `deploy@ci` once, `/srv/raw` is uid 10001, the vps2 expectations are in place). Left for after the first push: give the repository the Admin role on the new `madar-backend-amd64` package.
- [x] **T080–T084 Prepare the home box, before the first deploy.** Done on 2026-10-31: the box (the owner's laptop) joined as peer `home-box` at `10.8.0.4`, on its own interface `wg-homebox` with `Table = off`, so only TCP to `10.8.0.1:6379` uses it and the laptop's `madar` admin tunnel is untouched. `HOME_BOX_WG_IP` is set on VPS-1, `/srv/madar/infra` and `/srv/madar/.env` (mode 600) are on the box, and the timer is enabled. The worker is a container, so the mark is set in `PREROUTING` as well as `OUTPUT` ([home-box](runbooks/home-box.md#a-box-that-already-runs-another-tunnel)). Join it to `wg0` (`wg-add-peer.sh home-box`), write `HOME_BOX_WG_IP` on VPS-1 and re-run `bootstrap-vps.sh vps1` **before the first D2 deploy**: it adds the box's firewall rule, creates gid 999's group and makes `deploy` a member, and `deploy.sh` refuses to render the Redis ACL without it (B2-R2-10). **Start `worker-scrape` only after the first deploy**: before it there is no `madar-backend-amd64:stable` image, no `homebox` Redis user and no firewall rule, so the container would pull-fail forever. Write its `.env` and install the two systemd units at the same time. → [home-box](runbooks/home-box.md), [README](runbooks/README.md) stage 4 (the peer) and step 5.11 (starting the worker)
- [x] **T083–T084 Review `deploy.sh --host vps2` and `home-box-update.sh` once more on the host** (the dry run passed on the box on 2026-10-31): `bash -n` them, and run `home-box-update.sh --dry-run` on the box (it only validates the Compose file). `bash -n` passed on both hosts on 2026-10-31 for `deploy.sh`, `bootstrap-vps.sh`, `render-redis-acl.sh`, `check-firewall.sh` and `home-box-update.sh`. The dry run needs the box's `/srv/madar/.env`, which is written with the worker after the merge.

#### After merge

- [x] **T086 Hosts up.** `backend.yml`'s `deploy` and `deploy-vps2` are green, the amd64 image is tagged `stable`, VPS-1 shows `api-public`, `api-admin` and `worker-media` healthy, VPS-2 shows its four services healthy with exactly one `beat`, and the home box shows one healthy `worker-scrape` on `scrape_home`. Progress on 2026-10-31: run 41212600411 (attempt 3) is green through `stable` and `retention`, VPS-1's three services and VPS-2's four are healthy with one `beat`, and the home box's `worker-scrape` is healthy on `scrape_home` (Redis lists its eight `homebox` connections from `10.8.0.4`). VPS-2's first two attempts failed because the security list did not yet allow `10.1.0.118` → `10.1.0.97` TCP 5432/6379. → [workers](runbooks/workers.md#check-the-fleet)
- [ ] **T087 The first unattended run.** After the next `ysscores-fixtures` slot: `import_runs` shows a `succeeded` (or a `partial` with its reasons in `run.json`) run, `raw_path` exists on VPS-2, tomorrow's Cairo day has ysscores matches with UTC kickoffs, a second run reports `items_upserted = 0`, and a kickoff you locked in the admin is unchanged (SC-004). → [imports-and-sources](runbooks/imports-and-sources.md#read-what-a-run-did)
- [ ] **T087 The bridge.** Stop the home box's worker, start a `legacy` run by hand, and see tomorrow's fixtures with their channel links appear without duplicates; the orphan channel id is skipped and logged. → [imports-and-sources](runbooks/imports-and-sources.md#start-a-run-now)
- [x] **Start the home box's worker.** Now `madar-backend-amd64:stable` exists and the `homebox` user is in the ACL: `sudo docker compose --env-file /srv/madar/.env -f infra/compose/home-box.yml up -d`, then check its log says it is consuming `scrape_home`. Done on 2026-10-31 with `home-box-update.sh`: `Connected to redis://homebox:**@10.8.0.1:6379/0`, then `ready`. → [home-box](runbooks/home-box.md#start-and-check-the-worker)
- [x] **`/srv/raw` exists on VPS-2.** `ls -ld /srv/raw` shows uid 10001 as the owner; if it is `root:root`, re-run `bootstrap-vps.sh vps2` (B2-R1-5). Checked on 2026-10-31: `10001:10001`. → [workers](runbooks/workers.md#raw-pages-and-retention)
- [ ] **T087 A logo arrives.** A new ysscores team with a logo on an allowlisted host gets its `logo_asset_id` filled by `worker-media`, and the app serves it from `media.<VPS1_IP>.sslip.io`. → [workers](runbooks/workers.md#worker-media-and-logos)
- [ ] **T082 Firewall proof.** From a second WireGuard peer (your laptop, not the home box), `nc -vz 10.8.0.1 6379` times out; from the home box, `redis-cli -u "$(sed -n 's/^REDIS_URL=//p' /srv/madar/.env)" --no-auth-warning ping` answers `PONG` (the box's `.env` holds the password inside `REDIS_URL`; it has no separate `REDIS_HOMEBOX_PASSWORD`). → [firewall-changes](runbooks/firewall-changes.md#redis-on-wg0-the-home-box)
- [ ] **A4 saves over WireGuard (the Caddy `ETag` fix).** Found on 2026-10-31: every save in A4 answered `409` because Caddy compressed `/admin/api` and appended `-zstd` to the strong `ETag`, which the editor then sent back as `If-Match`. After the fix's `infra.yml` deploy, `curl --compressed` against `/admin/api/matches/<id>` shows an `etag:` without a `-zstd` or `-gzip` suffix, and a save in A4 (after «إعادة التحميل») succeeds. → [deploy-and-rollback](runbooks/deploy-and-rollback.md)
- [ ] **Decide `YSSCORES_FETCH_QUEUE`.** Keep `scrape_home` (the home box fetches, the default) or switch to `scrape` on VPS-2 if the box is unreliable. → [imports-and-sources](runbooks/imports-and-sources.md#switch-where-a-source-fetches)

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

- [x] **T108 Editors' devices.** Done on 2026-10-31: the owner is the only editor, on the existing `madar` peer, and `~/.config/madar/caddy-root.crt` is installed (`curl --cacert` to `https://10.8.0.1/admin/api/healthz` verifies). Add a peer here for any editor who joins later. Add a WireGuard peer per editor's machine (`wg-add-peer.sh <name>`), give them its config, and install Caddy's internal root CA at `~/.config/madar/caddy-root.crt` (the one the WireGuard setup produced), so `NODE_EXTRA_CA_CERTS=… pnpm dev:wg` can reach `https://10.8.0.1` without a browser warning. → [private-network](runbooks/private-network.md#add-a-peer)
- [ ] **T107 steps 2–4 (T108 shows the same screens).** With Prism up: `/matches/48213?mock=edit_conflict`, `/matches/48213?mock=edit_conflict_source`, `/matches/48213?mock=precondition_required` and `/matches?mock=forbidden_remove_channels` (the save's example is asked for from the page that saves, A-R2-4). Then, after T047, `NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt pnpm dev:wg` and walk [quickstart Lane A](../specs/002-d02-core-flows/quickstart.md#lane-a-admin), including the two-browser conflict. `changeOrigin` is now `true` in `vite.config.ts` so Caddy receives its own site address (A-R2-13); confirm during the walk that every request reaches `https://10.8.0.1`. Take screenshots of A3, A4 and both dialogs at 1440 and 1024 and compare them with `Matches.png`, `MatchEditor.png` and `Dialogs.png`.

#### After merge

- [x] **`admin.yml` on `master`.** The `check` job runs typecheck, lint, test, build and both scripts; read its log rather than assuming. Read on 2026-10-31 (run 41215192967, the PR #13 merge): 177 tests in 16 files pass, lint 0 errors and 25 warnings, the build passes, and both scripts pass.
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


## 003 D3 follow, push and sources

### Lane B1: devices, push, cache and limits

#### Before merge, in this order

- [ ] **T014 The contract PR.** Read the `backend/openapi/*.json` diff against [contracts/public-devices.md](../specs/003-d03-follow-push-sources/contracts/public-devices.md) and [contracts/admin-api.md](../specs/003-d03-follow-push-sources/contracts/admin-api.md): four new `/v1/devices*` paths with `Cache-Control: no-store`, `429 rate_limited` on every `/v1` path, and the A13/A2/A6/A7 admin routes. The generated clients are in the same PR. Merge it first; lanes A, M and B2 rebase on it.
- [ ] **T008 Revision `0005`.** Read `backend/alembic/versions/0005_devices_outbox_sources.py` line by line: expand-only (nullable columns or defaults), one array CHECK (`ck_devices_satellite_ids`), one `>= 0` CHECK on `sources.consecutive_failures`, two partial indexes, one FK to `sources(name)`, and a downgrade that drops exactly those. → [database-migrations](runbooks/database-migrations.md#revision-0005)
- [ ] **B1-R1-4 Revision `0006`.** Read `backend/alembic/versions/0006_outbox_attempts.py`: expand-only (one `attempts integer NOT NULL DEFAULT 0` and one `>= 0` CHECK on `notification_outbox`), so the release before it keeps running, and a downgrade that drops both. It is what stops a reminder with a broken FCM credential from staying `pending` for ever. → [database-migrations](runbooks/database-migrations.md#revision-0006)
- [ ] **T034 The audience query.** The owner's review is in [push-notifications](runbooks/push-notifications.md#the-owners-audience-review): one `DISTINCT` statement, bound parameters, `device_follows` only, the per-device `kickoff_reminder` switch honoured in SQL. It is `AUDIENCE` in `backend/app/notifications/dispatcher.py`.
- [ ] **T037 The rate-limit values.** 120/min per verified device, 600/min per IP, 30 per 10 min for `POST /v1/devices`. They are settings, not contract, and the reasoning is in [response-cache-and-limits](runbooks/response-cache-and-limits.md#the-rate-limits). Say if the IP value is too low for a carrier NAT day.

#### After merge

These need Lane B2's T077 (`worker-notify` mounts the FCM key) and the owner's key.

- [ ] **T047 The deploy, the FCM key and the first real reminder.** `backend.yml` deploys and runs `0005`; install the service account as in [push-notifications](runbooks/push-notifications.md#the-fcm-service-account) (`FCM_CREDENTIALS_FILE`, `FCM_DRY_RUN=false`, `PWA_ORIGIN` on VPS-2, file mode 600, mounted into `worker-notify` only); `dc logs worker-notify` shows `fcm: initialized` after the first send; run one real reminder to your own Android phone through `notifications.dispatch_due` (quickstart step 4 without dry run) and tap it.
- [ ] **The first reminder is the check.** After it lands: the outbox row is `sent` with `sent_at`, `sent` equals the number of followed devices, and the notification opens `/match/<id>` in the app. Then leave `FCM_DRY_RUN` at `false`. → [push-notifications](runbooks/push-notifications.md#read-the-outbox)

### Lane B2: LiveSoccerTV, health, backups and monitoring

Built on 2026-11-01 on `d03-b2` in `../madar-d03-b2`, cut from the planning branch `003-d03-...` and rebased onto it after Lane B1 merged (PR #16), so revision `0005` and B1's code are underneath it ([tasks.md](../specs/003-d03-follow-push-sources/tasks.md#lane-b2), [quickstart](../specs/003-d03-follow-push-sources/quickstart.md#lane-b2-livesoccertv-health-backups-monitoring)).

What the lane added: the LiveSoccerTV adapter (`app/adapters/livesoccertv.py`, `livesoccertv_links.py`) with saved pages and a pure parse, the plan → fetch → ingest split, hidden placeholder channels, `ScrapeResult` v2, `adapters.schedule_fetch`, `ops.heartbeat`, the breaker and zero-items alarm (`health.py`), Telegram alerts (`alerts.py`), the new beat entries, the backup image and scripts, the three systemd timers (installed by `bootstrap-vps.sh`, verified by `deploy.sh`), Uptime Kuma and the FCM secret mount in `vps2.yml`, Kuma's own wg0-only site, the firewall rule, and `infra.yml`'s backup-image build.

Local checks: the whole backend suite (B1's devices, notifications, cache, limits and admin additions included) is green on PostgreSQL 16 with revision `0005` applied, coverage 93 % overall and 88 % on `app/adapters`; `ruff`, `mypy --strict`, `shellcheck`, `systemd-analyze verify`, `actionlint`, `docker compose config -q` (both hosts) and `caddy validate` pass. The round-1 fixes add their own gates to `infra.yml` — a compose render with no `IMAGE_TAG`, the backup uid/capability check on a host-shaped tree, a real-restic init and retention drill, the deploy's no-root-work check with the folder verifier, the media CORS assertions and the FCM doc-command check — and each one fails against the pre-fix tree. Nothing was deployed and nothing ran on a host.

#### Before merge, in this order

- [ ] **Review the matching rules (T062).** `backend/app/adapters/livesoccertv_links.py`: a name that matches an existing channel is linked whatever country lists it; a name from a configured country that matches nothing becomes one hidden placeholder; a soft-deleted placeholder is never recreated; only `livesoccertv` rows are added or removed, never a `manual` one. → [imports-and-sources](runbooks/imports-and-sources.md#livesoccertv)
- [ ] **Review the backup retention and the restore path (T073, T085).** 7 daily / 4 weekly / 6 monthly for the database, 4 weekly for media, and the restore steps in the runbook. → [backups](runbooks/backups.md)
- [ ] **Review the Kuma monitors (T086).** Four HTTP checks and six push monitors, the FCM secret mounted into `worker-notify` alone, Kuma bound to the VCN address and reachable over wg0 only. **Decision for you:** the plan says `https://10.8.0.1/kuma/`, but Uptime Kuma 1 has no supported sub-path mode (its assets and websocket load from the site root), so it is served as its own wg0-only site, `https://kuma.10-8-0-1.sslip.io`. Same protection, working UI. Say so if you prefer to try the path anyway. → [uptime-kuma](runbooks/uptime-kuma.md)
- [ ] **Telegram bot and chat.** Create the bot with @BotFather, add it to the chat, and put `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in VPS-2's `/srv/madar/.env` (mode 600). → [source-alerts](runbooks/source-alerts.md#the-two-settings)
- [ ] **Backblaze B2 bucket and key.** A private bucket, an application key limited to it, and a `RESTIC_PASSWORD` (`openssl rand -hex 32`). Put `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `B2_ACCOUNT_ID` and `B2_ACCOUNT_KEY` in **both** hosts' `.env` (the weekly media snapshot on VPS-1 uses the same repository). → [secrets](runbooks/secrets.md#where-they-live)
- [ ] **OCI bucket and S3 keys.** A bucket in the Always Free tier and a customer secret key; put `RCLONE_CONFIG_OCI_TYPE=s3`, `RCLONE_CONFIG_OCI_ACCESS_KEY_ID`, `RCLONE_CONFIG_OCI_SECRET_ACCESS_KEY`, `RCLONE_CONFIG_OCI_ENDPOINT`, `RCLONE_CONFIG_OCI_REGION` and `RCLONE_BUCKET` in VPS-1's `.env`. `_TYPE` is what defines the `oci` remote: without it rclone fails with `didn't find section in config file` (found on 2026-11-03, media backup monitor red). → [secrets](runbooks/secrets.md#where-they-live)
- [ ] **The FCM key (with Lane B1).** `worker-notify` runs as uid 10001 and mounts `/srv/secrets` (mode 700, that uid) read-only; the key is `fcm.json`, mode 600, same owner. Install it **as root**: `sudo install -d -m 700 -o 10001 -g 10001 /srv/secrets`, then `sudo install -m 600 -o 10001 -g 10001 <key>.json /srv/secrets/fcm.json`, then `sudo shred -u <key>.json`. Prove it with `docker compose exec worker-notify test -r /srv/secrets/fcm.json`. B1's T047 needs it. → [push-notifications](runbooks/push-notifications.md#the-fcm-service-account)
- [ ] **Re-run the bootstrap on both hosts before this deploy (B2-R1-4).** `bootstrap-vps.sh` now creates `/srv/backup` for uid 10001 and installs and enables the backup timers as root; `deploy.sh` only verifies them and stops with the command to run when one is missing. Run `sudo ./madar-infra/scripts/bootstrap-vps.sh vps1` and `… vps2` after pulling this change, then deploy. The timers start once the backup keys below are in `.env` and the infra is synced (the deploy does the sync); the bootstrap says when it left them enabled but not started. → [provision-host §3](runbooks/provision-host.md#3-run-the-bootstrap-script)

#### After merge

- [x] **T081 The deploy check.** `backend.yml` and `infra.yml` are green; `ssh madar-vps2 docker compose ps` shows `uptime-kuma` and `worker-notify` healthy beside the other workers and one `beat`; `systemctl list-timers 'backup-*'` lists the timers on both hosts. → [workers](runbooks/workers.md#check-the-fleet)
- [ ] **T086 The Kuma monitors.** Create the account, the Telegram notification and the ten monitors, then write the six `KUMA_PUSH_URL_*` values into the hosts' `.env` and restart the services that read them. Copy only each monitor's token into the bare form (B2-R2-1): `http://uptime-kuma:3001/api/push/<token>` on VPS-2, `http://<VPS2_VCN_IP>:3001/api/push/<token>` on VPS-1; a `https://kuma.10-8-0-1…` URL is unreachable from both hosts. Then run one backup by hand to see the push land. → [uptime-kuma](runbooks/uptime-kuma.md#4-push-monitors-six)
- [ ] **T082 The first LiveSoccerTV run.** «تشغيل الآن» in A13 (or `adapters.schedule_fetch` in the runbook): one `import_runs` row with `items_found > 0`, `livesoccertv` links on upcoming matches, and the new placeholder names in A8's placeholder filter and nowhere in `/v1`. Run it again: `items_upserted = 0` and no new placeholder. Remove one of its links in A4 and run it again: the link stays hidden. → [imports-and-sources](runbooks/imports-and-sources.md#livesoccertv)
- [ ] **T082 The breaker and the zero-items alarm.** Block LiveSoccerTV on the home box (or point `LIVESOCCERTV_FETCH_QUEUE` at a queue with no fetcher) and run it three times: the breaker opens, A13 shows it paused, and the Telegram message «⛔ المصدر ‹livesoccertv› متوقف بعد ‹3› محاولات فاشلة» arrives within 15 minutes (SC-005). Resume in A13 and see it run. Then feed a saved empty page through the ingest harness on staging data: one «⚠️ … لم يجد أي عناصر» and no second one the same day. → [source-alerts](runbooks/source-alerts.md)
- [ ] **T083 The next morning's backups.** `backup-db restic snapshots --latest 3` lists last night's snapshot on VPS-2, `backup-media rclone lsd oci:` shows the media copy on VPS-1, and Kuma shows both backup heartbeats green (SC-004). Record the snapshot id in the PR. → [backups](runbooks/backups.md#check-last-nights-backup)
- [ ] **T084 A stopped worker alerts.** Stop `worker-notify` for 10 minutes and confirm Kuma alerts on Telegram, then start it again. → [uptime-kuma](runbooks/uptime-kuma.md#5-check)
- [x] **T068 Rebase on `003-d03` after B1's `0005`.** Done on 2026-11-01: rebased onto `ee730cc` (PR #16). The temporary guards are gone, so `test_health.py`, the placeholder cases of `test_livesoccertv_links.py` and `test_ingest_log.py` now run for real, `import_runs.log` is written, and `app.workers` merges both schedule modules (T070). → [tasks.md](../specs/003-d03-follow-push-sources/tasks.md#after-the-1300-merge-b2)


Lane B1 implements devices and follows on `/v1`, the reminder scheduler and the FCM dispatcher on the outbox, the response cache, the `/v1` limits, the admin additions for A2/A6/A7/A13, and revision `0005` ([tasks.md](../specs/003-d03-follow-push-sources/tasks.md#lane-b1), [quickstart](../specs/003-d03-follow-push-sources/quickstart.md#lane-b1-devices-notifications-cache-admin-additions)). It is on `d03-b1` in `../madar-d03-b1`, cut from `003-d03-follow-push-sources`.

What was checked locally: `ruff` and `mypy --strict` are green; `pytest --cov` is green (**1212 passed, 93.49 %**), covering the new `tests/devices/`, `tests/notifications/`, `tests/api/` and `tests/admin/` files; both OpenAPI documents are what `export-openapi` writes; oasdiff against `contract-v1` reports no breaking change for either; the regenerated admin (Orval) and Dart (`swagger_parser` + `build_runner`) clients are in the working tree, and the admin typechecks. One line outside the generated client changed: `admin/src/features/matches/queries.ts` now types the sources list as `SourceHealth` (the `GET /sources` shape), which is what A13 uses. `tests/adapters/test_homebox_acl.py` fails on `master` here too (the dev Redis uses `requirepass`), so it is not part of that figure.

Round 1 of the review (`reviews/b1-round-1.md`) is closed on `d03-b1`: B1-R1-1 to B1-R1-6. The reminder path no longer lets one device's empty push token hold the queue (the API refuses `""` and NUL with `422`, the audience skips blank tokens, and one unusable message is one `failed` device, not a failed page); a token is cleared only when FCM says the registration token is dead; a rescheduled match gets its reminder back; a row whose five attempts fail ends `failed` (revision `0006`) and every row claimed behind a failed page is released instead of stranded in `sending`; a reminder for a kickoff that has passed, or a `live`/`finished` match, is cancelled instead of saying «بعد دقيقة»; and the real `FcmSender` mapping and the three Celery tasks now have tests (`sender.py` 49 % → 84 %, `tasks.py` 32 % → 94 %). The suite is green (**1,326 passed, 95.16 %**, the four `test_homebox_acl.py` cases excluded for the reason above), `ruff`, `mypy --strict`, `export-openapi` (one additive `minLength: 1` on `DeviceUpdate.push_token`) and both generators are clean.

### Lane A: admin

Implemented on 2026-11-01 on `d03-a` in `../madar-d03-A`, cut from `003-d03-follow-push-sources` and rebased on Lane B1's contract merge (`ee730cc`), so the regenerated admin client of T014 is in the branch ([tasks.md](../specs/003-d03-follow-push-sources/tasks.md#lane-a), [quickstart](../specs/003-d03-follow-push-sources/quickstart.md#lane-a-admin)).

T088–T105 are ticked: the `@dnd-kit` dependencies, the Arabic copy for the four new `error.code`s and every new screen, D2's two carry-overs (A-F1's React Hook Form resolver and A-F2's shared `DataTable`), `SortableList`, `AudioPlayer` and `KpiCard`, A5, A6, A7, A8, A10, A13 and A2, the ordering writes to `PUT /competitions/order` and `PUT /satellites/order`, and the router with A2 as the landing page.

Checked locally in `admin/`: `pnpm typecheck`, `pnpm lint` (0 errors, 19 warnings), `pnpm test` (**219 tests in 26 files**), `pnpm build`, `./scripts/check-literals.sh`, `./scripts/check-token-copy.sh`, and `pnpm orval && git diff --exit-code src/api/generated/` is clean. Nothing was opened in a browser and nothing ran over WireGuard.

Three contract gaps found while building are written up at the end of [tasks.md](../specs/003-d03-follow-push-sources/tasks.md#lane-a) and need Lane B1 before the screens are complete: team and competition **aliases** (no field in D2's contract; editors ship without them), **no per-row `etag`** on the competition and satellite lists (T101 reads each moved row's version from its detail just before the reorder, so a change between render and save is not caught), and **`ChannelPatch` has no `kind`** (a platform placeholder can gain a satellite and a frequency but cannot become a satellite channel).

#### Round 1 review fixes (2026-11-01)

`/speckit.implement` on lane A's round 1, run in the main checkout (`madar_sat`, on `003-d03-follow-push-sources`) at your request, so this round sits uncommitted on the spec branch rather than on a `d03-a` worktree. `reviews/a-round-1.md` raised 0 CRITICAL and 8 HIGH.

- **A-R1-2 A stale save can no longer overwrite.** A5, A6, A7, A8 and A10 now keep the ETag **with the baseline it belongs to** (not with the live refetch) and open `ConflictDialog` through `lib/conflict.ts` on `409 edit_conflict`; Save is answered by the dialog until the editor reloads or discards. Tests: one per editor (A changes a field, B saves first, the dialog shows the diff, a second Save sends nothing).
- **A-R1-3 A10's delete sends `If-Match`.** The list rows carry no `etag`, so the delete reads the commentator's own record first; a `409 in_use` now shows the usage count instead of «أعد تحميل الصفحة». The test's DELETE handler answers 428 without the header.
- **A-R1-4 The five editors validate through React Hook Form + Zod over Orval's generated bodies** (`createTeamBody`, `createCompetitionBody`, `createSatelliteBody`, `createChannelBody`, `createCommentatorBody`), show field errors, and send the parsed value. Zod's own messages are Arabic through one error map in `lib/validation.ts`. One invalid-submission test per editor.
- **A-R1-5 (admin half).** `ChannelsPage.test.tsx`'s placeholder is the importers' real shape (`kind: 'platform'`), and, since B1-R2-2 added `kind` to `ChannelPatch`, a platform placeholder becomes a satellite channel in one save (the interim lock on the carriage select is gone); a move without a frequency is refused in the form before anything is sent.
- **A-R1-6 The A5 logo previews on a dark and a light tile** through a shared `LogoField`, labelled «على خلفية داكنة» / «على خلفية فاتحة»; used in A5, A6, A7 and A8.
- **A-R1-7 A7's ordering is tested** like A6's: the keyboard PUT body with each row's version, the 409 dialog, and an https refusal that submits and asserts nothing was sent.
- **A-R1-8 One `FrequencyReadout`** built from the readout tokens (dark well, cyan mono, LTR, glow) replaces the two pale pills in A7 and A8; token test in both themes. A2 shows no frequency, so nothing to replace there.

Checked in `admin/`: `pnpm typecheck`, `pnpm lint` (0 errors, the same 6 warnings in D2 files), `pnpm test` (**236 tests in 27 files**), `pnpm build`, `./scripts/check-literals.sh`, `./scripts/check-token-copy.sh`. Still not opened in a browser.

#### Before merge, in this order

- [x] **Ask Lane B1 for two additive contract changes (A-R1-1, A-R1-5).** Done in round 2: B1-R2-2 added both and A-R1-1 and A-R1-5 are closed. Neither can be done from Lane A: `backend/` and `admin/src/api/generated/` belong to B1. (1) `etag` on each row of `GET /competitions` and `GET /satellites` — and, for A-R1-3, `GET /commentators` — so a reorder sends the version each row was rendered with and the per-row `GET` fan-out goes away (A6 and A7 currently read each row's version at save time, so a stale list never trips the check); both clients regenerate after. (2) `kind` in `ChannelPatch`, with the platform→satellite rule the `kind_errors` in `backend/app/services/admin/channels.py` already state, so A8 can complete a platform placeholder as a satellite channel; until then the editor leaves the carriage locked on those rows. Record both as B1 tasks, not yours.
- [ ] **T106 The WireGuard walk.** After B1's T047 deploy: `NODE_EXTRA_CA_CERTS=~/.config/madar/caddy-root.crt pnpm dev:wg`, then walk [quickstart Lane A](../specs/003-d03-follow-push-sources/quickstart.md#lane-a-admin) steps 1–8 — edit a team's logo, reorder competitions by mouse and keyboard (including the two-browser conflict), set Nilesat's best and worst frequency, complete a placeholder, play a commentator clip, pause/resume/run a source, and read the dashboard. Completing a **platform** placeholder as a satellite channel is part of the walk now: B1-R2-2 added `kind` to `ChannelPatch`.
- [ ] **T107 The screenshots.** At 1440 and 1024 against `Main.png`, `Teams.png`, `Competitions.png`, `Satellites.png`, `Channels.png` (light), `Commentators.png`, `Sources.png` and `SourceRun.png`, in the theme each board uses, attached to the PR.

#### After merge

- [ ] **T108 The editor walk-through.** Sign in over WireGuard and repeat the walk on the deployed admin API; then confirm a team edit reaches the app within 60 s (SC-006, the day's done check).

### Lane M: app

Lane M builds onboarding (S1.1–S1.5), S9, S15's core, S16, S0's states, Remote Config, the media-host rule, drift v3, the new components and the push and crash adapters. T133 (device registration and follow sync over B1's regenerated client) is now built on `d03-m`'s working tree with the rest of round 1's review fixes (M-R1-1 … M-R1-12): registration once per install, `PUT /v1/devices/me` and the full follow set, `DELETE /v1/devices/me` behind «حذف بيانات جهازي», the FCM id kept out of the auth token, S2's channel line ranked by My satellites, the chosen zone applied to the local day, the exit rule on all five tabs, the four new error codes, the push-service and interceptor tests, the PWA's path URLs, the RTL arrows and the 48 dp button targets.

What is checked without a device, in `app/`: `flutter analyze` clean; the new tests under `test/core/{config,settings}`, `test/features/{onboarding,follows,devices,favorites,settings,system,notifications,match_detail}`, `test/goldens/components_d3_test.dart` and `test/architecture/platform_plugins_test.dart`, run with `rtest` on the test box. Not checked: a real phone or iPhone, the Firebase project, Remote Config in the console, and the store build.

#### Before merge, in this order

- [x] **T109–T110 The Firebase project's public identifiers.** Done 2026-11-02 for Android (the three flavors) and the web; the iOS app waits for the Apple account, so `FIREBASE_IOS_APP_ID` stays empty. The values are in the owner's local `app/env/*.json` and in the `APP_ENV_PROD` secret, never in the repo ([secrets](runbooks/secrets.md#update-the-apps-flavor-values)). In the Firebase console, register the Android app (`com.madarsat.app`), the iOS app and the web app, then copy into `app/env/{dev,staging,prod}.json`: `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_WEB_APP_ID`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID` and `FIREBASE_VAPID_KEY` (the last from **Cloud Messaging → Web Push certificates**, public half only). These are identifiers, not secrets. Empty values are why the app currently starts with no Firebase: it still runs, but push, Crashlytics and Remote Config are absent. → [store-releases](runbooks/store-releases.md#push-setup), [remote-config](runbooks/remote-config.md)
- [x] **T138's two links.** Done 2026-11-03: `PRIVACY_URL=https://madar-sat.web.app/privacy.html` (the policy page `app/web/privacy.html`, kept at the release root by the stage script; it is live from the next live PWA deploy, `web-v0.1.0`) and `SHARE_URL=https://madar-sat.web.app` (the PWA works on Android and iPhone; the Play listing is closed-track only), in `app/env/prod.json` and the `APP_ENV_PROD` secret. `staging` stays empty. Set `PRIVACY_URL` and `SHARE_URL` in your local `app/env/prod.json` (and `staging`), then update the `APP_ENV_PROD` secret from it ([secrets](runbooks/secrets.md#update-the-apps-flavor-values)). Empty means the privacy row is not drawn, because the repo has no policy address to invent. `SHARE_URL` is what S16's «شارك التطبيق» shares.
- [ ] **T138 The Remote Config parameters.** Add `api_base_url`, `media_base_url`, `min_supported_build`, `latest_build` and `live_poll_interval_s` in the console and publish them equal to the bundled defaults. Nothing breaks without them, but the app then has no remote switches at all. → [remote-config](runbooks/remote-config.md)
- [ ] **Ask Lane B2 for one CI define (M-R1-4).** `app-release.yml` passes `--build-number`, but the forced-update screen compares `min_supported_build` with a value compiled into Dart. B2's `app-release.yml` should also pass `--dart-define=APP_BUILD_NUMBER=$BUILD_NUMBER`, so the build number the app reports equals the version code Play installed. Until then the number comes from `pubspec.yaml` (`app/lib/core/config/build_info.dart`, guarded by a test), and any `min_supported_build` ≥ 2 would lock out a released build whose button opens Google Play but reports build 1.
- [ ] **Merge the PR** once its checks are green, after B1's T014 lands and Lane M rebases to finish T133.

#### After merge

- [ ] **T136 The Android walk**, on the closed-test build ([quickstart Lane M](../specs/003-d03-follow-push-sources/quickstart.md#lane-m-app)): S1.1–S1.4, S9 with both teams, killing the app in S1.2 and resuming, S3's «تابع المباراة» and «حدد أقمارك» chip, S15's zone/format/theme/size, S16's rows, airplane mode with the banner and its age, and the exit snackbar on every one of the five tabs. Screenshots in both themes next to the boards. Also confirm the two server-side halves now built (M-R1-1, M-R1-3): a follow made in S9 reaches B1's device row and its reminder is queued, and «حذف بيانات جهازي» leaves no row behind (`docker compose exec api-admin python -m app.cli devices` on VPS-1, or ask B1).
- [ ] **T137 The iPhone walk**, iOS ≥ 16.4 in Safari: S1.4 shows S1.5, install from the share sheet, open from the icon, allow notifications, then receive a reminder with the app closed. Record the iOS version and attach a screenshot. The reminder's tap must open `/match/<id>` (M-R1-10: the PWA now uses path URLs, not `#/match/<id>`); if it lands on S2, the worker's link and the URL strategy disagree and that is a bug to report. This is the plan's top risk (delivery-plan §10).
- [ ] **Crashlytics proof.** With the identifiers in place, build the `prod` Android app, crash it once (an uncaught exception in a debug-only button is enough), and confirm the crash appears in the console within a few minutes.
- [ ] **Remote Config proof.** Raise `min_supported_build` above the installed build, relaunch and confirm the forced-update screen; set it back. Then change `live_poll_interval_s` to 60 and confirm S2 still updates.

## 004 D4 MVP launch

Planned on 2026-11-03 in `specs/004-d04-mvp-launch/`; each lane works on `d04-<lane>` in `../madar-<lane>` ([tasks.md](../specs/004-d04-mvp-launch/tasks.md), [quickstart](../specs/004-d04-mvp-launch/quickstart.md)). Four lanes: B1 (the client IP and the load test), B2 (imports, mirror, releases), A (admin), M (app). Hardening only: no new endpoint, screen or feature.

The day's gate: importers cover today to +3; admin edit visible in ≤ 60 s; reminders on both platforms; bug bash without crashes; no CRITICAL security finding; PWA first load < 5 s on 4G and < 1.5 s afterwards; PWA public ([delivery-plan](../delivery-plan.md) Appendix A, row 004).

### Lane B1: client IP, load, security

Code on `d04-b1`, cut from `master` (`acbfece`). What is in: `TRUSTED_PROXIES` behind `client_ip()`, `RATE_LIMIT_EXEMPT_IPS` with its logs and startup warning, `backend/loadtest/mvp.js` (k6, pinned `grafana/k6:2.3.0`), and [load-testing](runbooks/load-testing.md). The load run, the security review and the host checks are yours.

#### Before merge, in this order

- [ ] **T003–T004 The client IP.** Read `backend/app/auth/limits.py` and `backend/app/settings.py`: `TRUSTED_PROXIES` is a comma list, default `10.8.0.1`, validated at startup; the right-most hop that isn't trusted wins, so a forged `X-Forwarded-For` is ignored. `api-public` needs `127.0.0.1,172.30.0.1` from B2's Compose (T034), and the two merges deploy together. → [response-cache-and-limits](runbooks/response-cache-and-limits.md#client-ip)
- [ ] **T005 The allowlist.** Read `backend/app/api/ratelimit.py`: an exact `RATE_LIMIT_EXEMPT_IPS` match skips the limiter, logs at debug per request and once a minute at info, and a non-empty list warns at startup. It is empty in git and in every `.env` except during the window below. Say if you would rather not have the escape hatch at all; the load test then needs another way past 600/min.
- [ ] **T007 The runbook.** Walk [load-testing](runbooks/load-testing.md) once on paper against the hosts: the address VPS-1 sees for VPS-2, the window, the CPU sample, closing it, the 700-request proof. It must be runnable by you months later without this conversation.
- [x] **T010–T011 The security review** (needs the `security-reviewer` agent over the whole repository, against system-design §8 and constitution V, row by row). Every finding gets an `SR-n` entry in `specs/004-d04-mvp-launch/security-review.md`; other lanes' CRITICAL and HIGH are appended to their `tasks.md` sections by 12:00. `SR-1` is the client-IP bug this lane fixes.
  **Done 2026-11-03:** no CRITICAL or HIGH. Yours: accept or fix SR-2 (mirror files run unchecked), run the SR-9 lockout check, and rotate the old Sat Air keys (SR-19).

#### After merge

- [x] **T008 Two networks.** With B2's T034 and this lane deployed: one `curl` to `https://api.<VPS1_IP>.sslip.io/v1/live` from two phones on different networks, then `dc exec redis sh -c 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli --scan --pattern "rl:ip:*"'` shows **two** `rl:ip:` keys with those public addresses, not one gateway key. Record it in the PR and mark `SR-1` fixed. → [load-testing](runbooks/load-testing.md#1-confirm-the-address-vps-1-sees-for-vps-2)
  **Done 2026-11-03:** keys `rl:ip:104.28.228.70` and `rl:ip:130.110.97.25`.
- [ ] **T009 The load test.** Run [load-testing](runbooks/load-testing.md) end to end (the window, k6 from VPS-2, the CPU sample, closing the window, the 700-request proof) and write `docs/load-tests/<date>-mvp.md` in the [data-model format](../specs/004-d04-mvp-launch/data-model.md#load-report-docsload-testsdate-mvpmd-b1). If `/v1/live` misses p95, ask B2 for `-w 3` and re-run; if it still misses, stop and tell Claude before the Caddy cache contingency. A `429` in the summary is a failed run, never a pass.
  **Ran 2026-11-03 and failed** ([report](load-tests/2026-11-03-mvp.md)): p95 ≈ 5 s, VPS-1 CPU-bound. Your decision: check the OCI limits page for the A1 free OCPU count and resize VPS-1, or approve the Caddy `/v1/live` cache (B2). Then a second run.
- [x] **T012 The host review.** [exposure-check](runbooks/exposure-check.md) from the internet; headers and CORS on `api.`, `media.` and `app.` against system-design §8; `https://10.8.0.1` answers nothing from the internet; Postgres and Redis ports closed; `RATE_LIMIT_EXEMPT_IPS` empty on VPS-1; `gitleaks` over the full history. Fix B1's CRITICAL and HIGH with a regression test each, and write "Gate: no open CRITICAL" at the top of the security report when they are closed. Accepting a HIGH is yours alone, with the reason.
  **Done 2026-11-03** (see `specs/004-d04-mvp-launch/security-review.md`). Still yours: with WireGuard down, `https://10.8.0.1` must not answer.
- [ ] **Any HIGH you decline to fix.** Say so and Claude records it as `accepted (owner, reason)` in `security-review.md`; the gate needs no open CRITICAL and no unaccepted HIGH.

### Lane B2: imports, mirror, release, admin deploy

What the lane added: `python -m app.adapters.report` (read-only `runs` and `coverage`, `report.py` with its pure parts tested), the fixed Compose subnet `172.30.0.0/24` with `TRUSTED_PROXIES` and `--forwarded-allow-ips` on `api-public` plus the `RATE_LIMIT_EXEMPT_IPS` pass-through, the backup scripts' refusal to run without a Kuma push URL, the mirror's `/r/*` immutable rule and `precompressed br gzip`, `firebase.json`'s release rules, the `pwa.yml` release job, the `admin.yml` deploy job with its atomic symlink and rollback, `bootstrap-vps.sh`'s `/srv/admin/releases/` layout, and three new checks in `infra.yml`'s `check` job.

Local checks: `report.py`'s tests pass (19), and the report ran on VPS-2 against the live database with the module mounted into a one-off container; `ruff`, `mypy --strict`, `shellcheck`, `actionlint`, `docker compose config -q` (all four), `caddy validate`, `check-backup-heartbeat.sh` (with the new missing-URL cases) and the two new `infra.yml` steps pass. `T042` (Playwright in CI) and `T046` (`node --test app/test_web/`) stay open until Lane A's T051–T053 and Lane M's T063 are on `master`; the steps are absent, not failing.

The import report's finding on 2026-11-03 (T035): of 56 slots in 48 h, 36 were missing. Every `legacy` slot ran (`partial`, 161–216 items found, 2–48 upserted, all skips `channel_not_published`). **No `ysscores` slot ran after 2026-11-02 09:00 and no `livesoccertv` slot ever produced a run**: both `adapters.schedule_fetch` entries reported `skipped, why: no_targets` or `scheduled, queue: scrape_home`, and the home box — the only consumer of `scrape_home` — is offline. No parser edge case appeared (T036/T037: none found; the saved pages parse, and the skips are links to channels Madar does not have).

#### Before merge, in this order

- [x] **Re-run the bootstrap on VPS-1 first (B2-R1-2).** Done 2026-11-03 before the merge: `readlink /srv/admin/current` printed `releases/placeholder`. Copy this branch's `infra/` to `~/madar-infra` on VPS-1, run `sudo ./madar-infra/scripts/bootstrap-vps.sh vps1`, and check `readlink /srv/admin/current` prints `releases/placeholder`. Only the bootstrap creates `/srv/admin/releases/placeholder/` and the `current` symlink; without them the merge's Caddy reload serves the admin as 404, `deploy.sh` stops naming this command, and `admin.yml`'s deploy fails at its first step ([deploy-and-rollback](runbooks/deploy-and-rollback.md#the-admin-deploy)).
- [x] **The media backup's remote (found while diagnosing T030).** Done 2026-11-03: VPS-1's `.env` has `RCLONE_CONFIG_OCI_TYPE=s3` (owner). Kuma's `backup-media` monitor has been red since 2026-11-03 01:31 with `media backup failed (exit 1)`: rclone reports `Failed to create file system for "oci:madar-media": didn't find section in config file`. VPS-1's `.env` has the four credentials, the endpoint, the region and `RCLONE_BUCKET`, but no `RCLONE_CONFIG_OCI_TYPE=s3`, which is what defines the remote. Add it and run the mirror once by hand ([backups](runbooks/backups.md#run-one-by-hand)).
- [x] **Bring the home box back (T030).** Done 2026-11-03. The worker was up but hung: its tunnel ran at MTU 1420 inside Cloudflare WARP (1300), so every full-size Redis reply was dropped and it sat blocked from 2026-11-02 11:26 with 26 fetches queued. `wg-homebox` is now at `MTU = 1200` with the MSS clamp, the worker was restarted, and `ysscores` run #31 succeeded (203 found, 48 upserted) ([home-box](runbooks/home-box.md#mtu-always-1200-with-the-mss-clamp)).
- [x] **Kuma's `scrape-home` push monitor.** Done 2026-11-03: `KUMA_PUSH_URL_SCRAPE_HOME` (Push, 300 s) exists in Kuma, and VPS-2's `/srv/madar/.env` has `KUMA_PUSH_URL_SCRAPE_HOME=http://uptime-kuma:3001/api/push/<token>` and `SCRAPE_HOME_BACKLOG_MAX=6`. It shows down until the deploy that ships `ops.scrape_home_backlog` recreates `worker-imports`.
- [x] **Kuma's Telegram notification (found 2026-11-03).** Done 2026-11-03: the owner switched Madar Monitor on for every push monitor. Update, 2026-11-03 evening: a notification named **Madar Monitor** (Default) now exists, and `api-public` and `media` have it on. Open each of the seven push monitors (**Edit → Notifications**) and switch it on where it is off, then **Test**; `backup-media` is the one that matters today. Earlier: Kuma had no notification set up ("Not available, please setup" on every monitor), so its alerts reach nobody: `backup-media` has been red since 01:31 without a message. **Settings → Notifications → Setup Notification → Telegram** with `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` from VPS-2's `.env`, **Default** on and **Apply on all existing monitors** on, then **Test** ([uptime-kuma](runbooks/uptime-kuma.md#2-the-telegram-notification)).
- [x] **The one-time network recreation (T034).** Done 2026-11-03 after the merge, the hard way. A run before the merge used `master`'s `vps1.yml` and kept `172.18.0.0/16`. The merge's `infra.yml` sync and `backend.yml` deploy then hit the new subnet: `compose up` stopped PostgreSQL and Redis, could not recreate the network under the running APIs, and left `/healthz` at 503 for about ten minutes. Running the runbook's commands brought the stack back on `172.30.0.0/24` (gateway `172.30.0.1`), and the failed jobs were re-run one at a time. `deploy.sh` now refuses a subnet mismatch before anything stops (`check_network`). `vps1.yml` now fixes the default network to `172.30.0.0/24`. Docker only applies a subnet when it creates the network, so the first deploy after this change needs one `dc down` (a few seconds of 502) as [deploy-and-rollback](runbooks/deploy-and-rollback.md#the-one-time-network-recreation-d4) shows. Then the public app sees real client IPs (R1).
- [ ] **`TRUSTED_PROXIES_PUBLIC` (`T034`)** in VPS-1's `.env`, **only if** the default `127.0.0.1,172.30.0.1` is wrong for the host. The Compose file already passes it; leaving the variable unset uses the default.
- [x] **`MIRROR_BASE_URL` in the `APP_ENV_PROD` secret (T045).** Done 2026-11-03 (`https://app.130.110.117.215.sslip.io`); `pwa.yml` wrote `env/prod.json` from it, on the D4 branch and on `master` after the merge. `https://app.<VPS1_IP>.sslip.io`, https only, no path or trailing slash. Without it the release job refuses to stage ([pwa-release](runbooks/pwa-release.md#before-you-start)).
- [x] **Kuma's `pwa-mirror` monitor (T047).** Done 2026-11-03: none of the four HTTP monitors existed, so `api-public`, `media`, `pwa` and `pwa-mirror` (on `/release-check.txt`) were created; `pwa` and `pwa-mirror` are paused until the first release (see "Resume the two PWA monitors" below). The original item: change its URL from `https://app.<VPS1_IP>.sslip.io/` to `https://app.<VPS1_IP>.sslip.io/release-check.txt`, so it proves the last release is served rather than that Caddy answers ([uptime-kuma](runbooks/uptime-kuma.md#3-http-monitors-four)).

#### After merge

- [ ] **The backup heartbeat result (T030).** The diagnosis: on VPS-2 `backup-db.timer` is enabled and ran on 2026-11-03 01:05 UTC with exit 0; `KUMA_PUSH_URL_BACKUP_DB` is set; Kuma's `backup-db` monitor has the `up` push `ok 20261103T010502Z`; `restic snapshots --tag db` lists snapshot `9571f2b4`. The cause of the missing signal was the timer never having been installed before the D3 bootstrap re-run (its first scheduled run is that 01:05 one). Now the script also refuses to run with an empty URL, and `infra.yml` proves the bootstrap installs the timers. Watch the next scheduled run (04:00 Africa/Cairo) report before ticking 003's T083 ([backups](runbooks/backups.md#check-last-nights-backup)).
- [ ] **The mirror headers (T048, quickstart B2 step 4).** `curl -sI -H 'Origin: https://madar-sat.web.app' -H 'Accept-Encoding: br' https://app.<VPS1_IP>/r/<hash>/main.dart.js` shows 200, `immutable`, `content-encoding: br`, the CORS header and `nosniff`; `/r/` returns no listing ([pwa-release](runbooks/pwa-release.md#3-check-the-mirror)).
- [x] **Resume the two PWA monitors (T047).** Done 2026-11-03 after the `web-v0.1.0` release (owner). After the `web-v0.1.0` release job passes: in Kuma, open `pwa` and `pwa-mirror`, **Edit**, switch the Madar Monitor notification on, **Save**, **Resume**; both turn green ([uptime-kuma](runbooks/uptime-kuma.md#3-http-monitors-four)).
- [ ] **VPS-2's `/srv/kuma` owner.** The D4 merge's `deploy-vps2` refused because Kuma's entrypoint had chowned `/srv/kuma` to root; it passed after a VPS-2 bootstrap re-run, and Kuma's restart chowned it back. The follow-up PR (`fix/d04-deploy-followups`) makes `deploy.sh` and the bootstrap expect root, which is what the host has now, so nothing is needed on the host. Until it merges, a VPS-2 deploy stops at that check: merge it before the next backend change.
- [ ] **The admin deploy (T048, quickstart B2 step 6).** Deployed 2026-11-03 on the re-run (`/srv/admin/current` → the merge's SHA); the first run rolled back because it ran before the infra sync reloaded Caddy, which only matters for the D4 merge that moved Caddy's root. Still open: the deliberate failure. A push touching `admin/` deploys on `master`: `readlink /srv/admin/current` names the SHA, `https://10.8.0.1/` serves it over WireGuard, and a deploy failed on purpose before the swap leaves the previous SHA ([deploy-and-rollback](runbooks/deploy-and-rollback.md#the-admin-deploy)).
- [x] **Tag `web-v0.1.0` (T045, T048).** Tagged 2026-11-03 on `1f1704b`; the release run passed at 17:51 UTC, `https://madar-sat.web.app/` and `/privacy.html` answer 200, and the mirror's `release-check.txt` holds `2f79de5be7d759da`. It went out **before** the conditions below (the load test T009, the security gate T010–T012 and the bug bash T071 are still open), so treat it as the first public build, not the MVP gate; the forced-mirror-failure run is still to do. Still open with it: VPS-2's `PWA_ORIGIN` is the preview channel, so web push links open the preview ([push-notifications](runbooks/push-notifications.md)). The original item: after B1's load test, no open CRITICAL and the bug bash: `git tag -a web-v0.1.0 && git push origin web-v0.1.0`. The release job copies the mirror, checks it, deploys the live channel and prunes; a run with the mirror copy forced to fail must stop before the live deploy ([pwa-release](runbooks/pwa-release.md#1-tag-the-release)).
- [ ] **Re-run the import report (T035).** `dc exec worker-imports python -m app.adapters.report runs --hours 48` exits 0 once the home box is back, and `coverage --days 4` has no prioritized competition with matches but no channel ([on-call](runbooks/on-call.md#3-the-alerts)).
- [ ] **LiveSoccerTV after the fix (`a77f023`).** The first `livesoccertv-48h` run after the deploy finishes `succeeded` or `partial` with items: no `layout_changed` from a postponed row, and Newcastle Jets × Shanghai Port style pairs found by name (`import_runs`, [imports-and-sources](runbooks/imports-and-sources.md#read-what-a-run-did)).
- [ ] **The home box heals itself.** The restart lives in `home-box-update.sh`, which the timer runs from the box's own copy; `/srv/madar/infra/scripts/home-box-update.sh` was updated on 2026-11-03 and its 10:01 tick ran clean (the rest of that rsync copy is still older than the repo; re-sync it after the merge). Then `sudo journalctl -u home-box-update.service` shows ticks without errors; if it ever logs `worker unhealthy (…): restarting it`, the next tick finds it `healthy` ([home-box](runbooks/home-box.md#when-the-worker-hangs)).

### Lane A: admin

Written on 2026-11-03 on `d04-a` in `../madar-a`, rebased on `004-d04-mvp-launch` ([tasks.md](../specs/004-d04-mvp-launch/tasks.md#lane-a), [quickstart](../specs/004-d04-mvp-launch/quickstart.md#lane-a-admin)). T050–T053 and T057 are ticked; T054 waits on your polish list, and T055–T056 on the admin deploy.

What landed: `@playwright/test` 1.64.1 (Chromium only, one worker, HTML report to `admin/playwright-report/`), `playwright.config.ts` with the mock and live modes, `e2e/smoke.spec.ts`, and the `e2e` and `preview` scripts. The smoke test signs in, finds the test match, saves a stadium under `If-Match`, expects the success toast and no conflict dialog, and in live mode polls `/v1` for the change. A3's rows already carried `match-row-<id>`; A4's stadium field gained `data-testid="match-stadium"` so the selector cannot drift with the Arabic copy.

Checked in `admin/`: `pnpm typecheck`, `pnpm lint` (0 errors, the same 6 warnings in D2 files), `pnpm test` (**241 tests in 27 files**), `pnpm build`, `./scripts/check-literals.sh`, `./scripts/check-token-copy.sh`, and `pnpm e2e` in mock mode (1 passed, 3.9 s). The built `admin/dist/index.html` was served by `pnpm preview` and opened in Chromium with its own `default-src 'self'` meta: no inline `<script>`, no `style=` attribute in the HTML or the bundle, and no console CSP violation (T050). Nothing ran over WireGuard: the live mode is the one path not exercised here.

#### Before merge, in this order

- [ ] **T054 the admin polish list (FR-023).** Write D3's admin polish list — the one [D3's owner work](#owner-work-the-later-briefs-already-imply) asks for — into your D3 notes, and say which items are visual nits and which block an editor. Lane A fixes each one in `admin/src/` with a test, or moves it to a named day with a reason. If there is nothing to fix, say «none» and FR-023 is met. Nothing is guessed in the meantime.

#### After merge, once B2's T040 has deployed the admin

- [ ] **T055 the live smoke runs.** Create the test `editor` ([staff-accounts](runbooks/staff-accounts.md#create-an-account)) and the one test match in A4 — date `2000-01-01`, two existing teams, stadium `MADAR-E2E`, nobody following it. Then run the live command from [admin-access](runbooks/admin-access.md#the-live-smoke-test-d4) three times from a WireGuard peer; each edit must reach `/v1` in ≤ 60 s (SC-004), and the test prints the seconds it measured. Clear the stadium, run once more, and see the run abort before saving; then restore the marker. Never point the marker at another match.
- [ ] **T056 the screenshots.** On the deployed admin, at 1440 and 1024 and in each board's own theme: 002 T107's `Matches.png`, `MatchEditor.png` and `Dialogs.png`, and 003 T106–T107's `Main.png`, `Teams.png`, `Competitions.png`, `Satellites.png`, `Channels.png`, `Commentators.png`, `Sources.png` and `SourceRun.png`. Attach them to the PR.

### Lane M: app

Lane M closes D3's three fixes, turns the build into a hashed release with its own service
worker, makes the S16 install row read as the product doc says, and runs the bug bash and the
4G timings. The code is on `d04-m` in `../madar-m`; the tasks are
[tasks.md](../specs/004-d04-mvp-launch/tasks.md#lane-m) and the checks are
[quickstart Lane M](../specs/004-d04-mvp-launch/quickstart.md#lane-m-app).

What is checked without a device, in `app/`: `flutter analyze` clean; the carry-over tests
(`test/core/network/dev_ca_test.dart`, `swr_repository_test.dart`,
`test/features/onboarding/teams_step_error_test.dart`), the release-layout test
(`test/core/web/release_layout_test.dart`), the drift wasm URL (`test/core/db/release_assets_test.dart`),
the S16 row (`test/features/settings/more_install_row_test.dart`), and the worker's logic with
`node --test test_web/`. Not checked here: the preview channel, the live mirror, the Android
release build and the iPhone PWA — every item below needs a host, a console or a device.

#### Before merge, in this order

- [ ] **T060–T062 The carry-over, on a phone.** The three fixes are merged-ready: a debug build
  trusts the dev Caddy root named by `--dart-define=DEV_CA_PATH`, a failed read with no cache
  reaches the stream as its error, and S1.2 shows the error copy with «إعادة المحاولة». On a
  device against the dev stack, run `flutter run -t lib/main_dev.dart
  --dart-define-from-file=env/dev.json --dart-define=DEV_CA_PATH="$PWD/root.crt"` and confirm
  S1.2's search answers over `https://localhost:8443` (it failed the handshake before).
  → [local-dev](runbooks/local-dev.md#the-apps-dev-flavor)
- [x] **T073 `MIRROR_BASE_URL`.** Done 2026-11-03 (see Lane B2 above). Add `MIRROR_BASE_URL=https://app.<ip1>.sslip.io` to your local
  `app/env/prod.json` and to the `APP_ENV_PROD` secret ([secrets](runbooks/secrets.md#update-the-apps-flavor-values)).
  It is the PWA's release host: the stage script stamps it into `flutter_bootstrap.js`, `sw.js`
  and the drift worker shim, so an empty value makes every release load from Firebase, which is
  what the Spark quota cannot carry. → [firebase-hosting](runbooks/firebase-hosting.md#the-hashed-release-layout)
- [ ] **Merge the PR** once its checks are green and B2's release job is on `master`. The first
  `web-v*` tag needs both lanes plus B1's load test and the security gate
  ([tasks.md](../specs/004-d04-mvp-launch/tasks.md#dependencies--execution-order)).

#### After merge

- [ ] **T069 The preview channel.** After B2's T045 runs on `master`: DevTools → Application
  shows `sw.js` controlling the page, a reload serves `r/<hash>/` files from the worker, and
  offline the app opens with its banner. → [firebase-hosting](runbooks/firebase-hosting.md#check-a-release-in-devtools)
- [ ] **T070 Tag `app-v0.3.0`**, then install the signed AAB from the closed track. The bug bash
  needs that build, so this comes before T071. After the gate conditions hold, tag `web-v0.1.0`
  (with B2 and B1). → [store-releases](runbooks/store-releases.md#2-tag-the-release)
- [ ] **T071 The bug bash.** Run [bug-bash.md](../specs/004-d04-mvp-launch/bug-bash.md) on the
  Android release build, the installed iPhone PWA (iOS ≥ 16.4) and desktop Chrome at 1440, and
  record it in `bug-bash-results.md`. Any crash or blocker is fixed with a test; cosmetics get a
  named day. → [store-releases](runbooks/store-releases.md#push-setup)
- [ ] **T072 The live timings.** On the live channel: first data < 5 s on Fast 4G and < 1.5 s on
  a repeat open, ≥ 90 % of first-load bytes from `app.<ip1>.sslip.io`, and the PWA still loads
  with the mirror blocked and the site data cleared. Record both numbers in
  `bug-bash-results.md`. → [firebase-hosting](runbooks/firebase-hosting.md#check-a-release-in-devtools)
- [ ] **Announce the public link.** `https://madar-sat.web.app` is the MVP gate's last clause
  (DC7 in [tasks.md](../specs/004-d04-mvp-launch/tasks.md#done-check)).
  → [firebase-hosting](runbooks/firebase-hosting.md)

## 005 D5 live and discovery

Planned on 2026-11-04 in `specs/005-d05-live-and-discovery/`; each lane works on `d05-<lane>` in `../madar-<lane>` ([tasks.md](../specs/005-d05-live-and-discovery/tasks.md), [quickstart](../specs/005-d05-live-and-discovery/quickstart.md)).

### Lane B1: live data, contract, poller

Code on `d05-b1`, rebased on B2's merge to the spec branch `005-d05-live-and-discovery` (`d42c7de`). It must be rebased again after T001 lands. What is in: revision `0007`, the widened public and admin contracts and both regenerated clients, the unresolved-names and rights-holder admin APIs, and the poller in `backend/app/live/` with [its runbook](runbooks/live-poller.md). The parsers work from saved finished and scheduled pages only, so a live status they don't know fails validation until the capture adds it.

Round 1 of the review ([b1-round-1](../specs/005-d05-live-and-discovery/reviews/b1-round-1.md)) is fixed on `d05-b1`, uncommitted: B1-R1-1 to R1-5, R1-7 and R1-8. `backend/app/live/crosscheck.py` changed its rules, so it's worth reading: a final status now waits for the sources to agree, or the match goes to the clock at kickoff + 210 min with no score ([A held final score](runbooks/live-poller.md#a-held-final-score)). B1-R1-6 and T035 wait on B2's fix to `test_schedule_fetch.py`.

#### Before merge, in this order

- [ ] **T017 The migration and contract.** Read `backend/alembic/versions/0007_live_and_aliases.py` and the diffs in `backend/openapi/`. `matches` rows are never deleted, so the new tables have no cascade. The new `sources` rows keep kinds the previous release accepts, so its `GET /admin/api/sources` keeps working during a deploy and after a rollback (B1-R1-8).
- [x] **T017 The `lineups` finding.** Decided by you on 2026-11-05: `oasdiff` reports one `response-property-any-of-added` ERR on `MatchDetail.lineups`, which research R15 predicted and clients already handle, and it gets a one-rule oasdiff exception, made by B2 as B2-R1-12. `contract-v1` doesn't move ([ci-workflows](runbooks/ci-workflows.md)).
- [ ] **Merge order.** B2's T043 (`worker-live`) must be deployed with or before this lane: beat queues `live.scheduler` every minute, and those messages wait unread without a consumer. `backend/tests/adapters/test_schedule_fetch.py` also needs one line from B2: its exact entry count must add `app.live.schedule`'s four entries, or `backend.yml` fails on the merged result (T035).
- [ ] **T020 The capture's match.** Pick the day's first match both lists carry, as early as possible, so a later kickoff is left for T038. Claude runs the capture on VPS-2 ([the capture](runbooks/live-poller.md#the-capture)) and then writes T021's report. A source that turns out to be unusable stops here and comes to you.

#### After merge

- [ ] **T037 The live checks.** `/v1/live` during a match; stop `worker-live` and see the watchdog trip within 7 min; pause and resume in A13 ([live-poller](runbooks/live-poller.md)).
- [ ] **T038 The done-check match.** Watch one real match, later than the capture's, from kickoff to full time against the broadcast on the deployed parsers (SC-001). If no later kickoff fits, it moves to the next match day.
- [ ] **T040 The load re-run.** After your resize (T048), open the window for a re-run by [load-testing](runbooks/load-testing.md).

### Lane B2: YallaKora, the queue, the live worker

Merged on the spec branch (PR #35). The round-1 review fixes are on `d05-b2` in `../madar-b2`, **uncommitted**, on top of the spec branch. Nothing is deployed.

#### Before merge, in this order

- [ ] **T001: merge the d05 docs to `master`.** Planning's task, listed here because both lanes were cut from the spec branch until it's done.
- [ ] **T045: approve the shared-parts PR.** T042–T045 (`live` heartbeat, both rate buckets, `worker-live`, the stubs) are ready to go to `master` on their own, so B1 can rebase. Ask Claude to open it.
- [x] **T046: merge B1's contract PR** (`0007`). Merged (PR #36), and `tests/adapters` passes against it.
- [x] **B1-R1-7: accept the `lineups` finding.** Your decision of 2026-11-05 is in as a one-rule `oasdiff` exception. → [ci-workflows](runbooks/ci-workflows.md#the-breaking-change-exception)
- [ ] **T048: check the OCI limits and resize VPS-1.** If 4 OCPU is confirmed free, resize to 2–3 OCPU and set `API_PUBLIC_WORKERS`, away from a live match, then tell B1 (T040). If it isn't confirmed, tell B2 to start T062. Update SD §2 and §7.1 with the result (T047's last step). → [provision-host](runbooks/provision-host.md#resize-an-instance)

#### After merge

- [ ] **T043: check `worker-live` is healthy on VPS-2.** The deploy starts it. Needed before B1's capture (T020). → [workers](runbooks/workers.md#what-runs-where)
- [ ] **T061: `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` on VPS-2,** if missing. → [source-alerts](runbooks/source-alerts.md#the-two-settings)
- [ ] **T061: create the `celery-live` push monitor** and set `KUMA_PUSH_URL_LIVE` on VPS-2, then restart `worker-live`. It's optional: empty leaves the queue unmonitored. → [uptime-kuma](runbooks/uptime-kuma.md#4-push-monitors-eight)
- [ ] **T060: run `yallakora` on the live host** and put the evidence in the PR: the `import_runs` row, broadcasters on matches, queue rows, 0 new teams, competitions or channels, and `seen_count` rising with no duplicate on a second run. `run.json`'s `waiting` lists cards that wait on a name you can map in A13. Claude can run it if VPS-2 is reachable. Check `report coverage` for duplicate fixtures from the first run. → [imports-and-sources](runbooks/imports-and-sources.md#yallakora)
- [ ] **T061: check the disk on VPS-2 after a busy day.** `ssh madar-vps2 'df -h /srv/raw'`. Research R12 expects well under 1 GB a day from the poller, on top of the importers, with a 5-day prune.

### Lane A: the queue, run detail and rights holders

Code on `d05-a` in `../madar-a`, merged up from the spec branch with B1's and B2's work (`2be5f31`), because T063 generates from B1's contract. All of admin's gates are green: `pnpm typecheck`, `pnpm lint` (0 errors), `pnpm test` (272 tests), `pnpm build`, both copy checks and `pnpm e2e` against Prism.

What is in: A13's unresolved-names queue with map/create/ignore, the Live poller card, the run detail's five stages and the raw page, and A9 (list, drag order, editor, delete). Two D4 test fixtures needed the new `SourceHealth.live` field; nothing else outside `admin/` changed.

Round-1 review fixes (A-R1-1 to A-R1-3) are on `d05-a`, uncommitted, with 285 admin tests: A9's editor now has the logo field (upload and remove), a satellites multi-select on each carriage, and `ConflictDialog` on a stale save and a stale reorder.

#### Before merge

- [ ] **T076 The screenshots.** Compare A13 Sources, A13 Run detail and A9 with their boards at 1440 and 1024 in both themes and attach the screenshots to the PR. The code is done; the comparison is a pair of eyes on the built app (`pnpm dev`, Prism, `?mock=`) — never on the mockup HTML.

#### After merge

- [ ] **T076 The WireGuard walk, with SC-007's timing.** With the admin deployed, open A13 and A9 at `https://10.8.0.1` over `wg0` ([admin-access](runbooks/admin-access.md)) and walk [quickstart A](../specs/005-d05-live-and-discovery/quickstart.md#lane-a): map, create and ignore a queued name; read a failed run's raw page; create a rights holder and see it in `/v1/competitions/{id}`. On A9, also set and remove a logo, save a carriage with two satellites and with none, and try a two-browser stale save and stale reorder (A-R1-1 to A-R1-3). Record how long a map takes (SC-007).
- [ ] **T060's rows in the queue.** The queue fills from B2's YallaKora run and B1's poller, so the walk above is real data only after their first runs on the host.

### Lane M: app

Lane M replaces the `/channel/:id`, `/team/:id` and `/competition/:id` stubs with S6 (the
channel sheet), S7 (the team page) and S8 (the competition page) on `d05-m` in `../madar-m`,
rebased on `005-d05-live-and-discovery` after B1's contract (PR #36), and it wires the entry
points from S2, S3, S5 and S9. The whole lane's task list in
[tasks.md](../specs/005-d05-live-and-discovery/tasks.md#lane-m) is ticked.

Checked without a device, in `app/`: `flutter analyze` clean, `./tool/check_literals.sh`,
`./tool/check_token_copy.sh`, and the whole suite on the test box — 802 tests, 1 skipped
(`env/example.json` is not in a checkout). All three screens have their goldens in
`app/test/goldens/` (`s6_channel_*`, `s7_team_*`, `s8_competition_*`), RTL × {light, dark} ×
{1.0, 1.3}. Two board details are deliberately not drawn, and the review should know why: S8's
«اليوم ·» prefix on today's group (S7's board has none, and both screens share one day header)
and S8's hide/show and share actions (hide/show is D8; the contract keeps S8 to follow and the
rights section).

#### Before merge, in this order

- [ ] **T090 the device walk.** The three screens were compared with
  `madar-design/app-flutter/screens/04-satellites-frequencies/Channel.png`,
  `05-follow-and-search/Team.png` and `05-follow-and-search/Competition.png` in both themes;
  what is left is your walk on a real Android phone: S6 opens from an S3 carriage row and from
  an S5 channel row (expand the row, then «عرض القناة»: two taps, your decision of 2026-11-05)
  with the frequency readable with no tap, S7 opens from S3's crest and from
  S9's teams, S8 opens from S2's section header, S3's competition line and S9's «البطولات»,
  follows survive a restart, and every offline and empty state shows. With TalkBack on, follow,
  «حقوق البث», share and S3's team and competition buttons can each be reached and activated
  (M-R1-1)
  ([quickstart Lane M](../specs/005-d05-live-and-discovery/quickstart.md#lane-m)).
- [ ] **Merge the PR** once its checks are green.

#### After merge

- [ ] **T089 the `features` switch.** In the Firebase console, add `features` with
  `{"live_center": false}` and publish. No code reads it on D5, so nothing changes on screen;
  D6 turns it on when its live centre exists
  (→ [remote-config](runbooks/remote-config.md#features-the-dark-ship-switches)).
- [ ] **T091 the next tags.** Tag `app-v0.4.0` for the D5 build and `web-v0.2.0` for the PWA once
  the day's done check passes, and install the closed-track build for the walk
  (→ [store-releases](runbooks/store-releases.md#2-tag-the-release)).


## 031 D5 follow-up: live sources

Spec: [031](../specs/031-d05-live-sources/spec.md). It acts on the 2026-11-04 capture, adds Goal.com and runs before D6. It replaces spec 005's T020, T021, T022, T038 and T039, so their items above are done here.

### Before lanes start

- [ ] **T001 Start the lanes.** The docs and spec are in PR #39. Bring that branch, or `master` once #39 is merged, into `d05-b1` and `d05-b2`.
- [x] **T002 FootballCo's approval.** Recorded 2026-11-05 from the owner's report: approved that day for scraping, covering scores, match stats and everything else spec 031 plans, with no conditions or exceptions. Keep the written approval somewhere safe, because the repo doesn't hold a copy. To stop reading Goal.com, see [live-poller](runbooks/live-poller.md).

### Lane B1

- [ ] **T017 Review `0008`** before merge: new columns and `match_stats`, expand-only.
- [ ] **T026 Capture night.** Pick a night with live matches, after the lanes are merged and deployed. B1 runs it on VPS-2, and Telegram tells you if a source stops. A source that refuses two rounds in a row (403 or 429) stays stopped until a restart, and whether to restart it is your call. → [the capture](runbooks/live-poller.md#the-capture)
- [ ] **T028 Unresolved names.** Clear the capture's team names in A13 before the watched match.
- [ ] **T029 Watched match.** A later match, against the broadcast, with all three sources.
- [ ] **T035 Extra-time check.** On the first deployed match or capture that reaches extra time or penalties. An `unknown_status:<source>` alert may be the first sign, and its saved pages last 5 days. B1 does the work; it needs you to say when one happens. This doesn't block the Done check, because nobody can schedule such a match.
- [ ] **DC1 Done check** in [tasks.md](../specs/031-d05-live-sources/tasks.md#done-check).

### Other things worth knowing

- The first capture's raw data and scripts are on your laptop in `~/madar-capture/2026-11-04/`, outside the repo.
- `LIVE_CONFIRM_WAIT_S` is removed by this spec. If you set it on VPS-2, delete it after merge.

### Lane B2

Nothing here blocks the merge. These run after the deploy that carries the capture, before T026.

- [ ] **T033 The host check.** Lane B2 confirmed what it can from outside: `worker-live` and `worker-maintenance` render with the live settings, `/srv/raw` is mounted and owned by the image's user (uid 10001), and VPS-2 had 37 GB free on 2026-11-05. The SSH user can't read `.env` or reach Docker, so these three are yours, as in [live-poller](runbooks/live-poller.md#the-capture):

  ```bash
  ssh madar-vps2
  sudo -iu deploy
  cd /srv/madar/infra
  export IMAGE_TAG=$(cat /srv/madar/current_tag)
  dc() { docker compose --env-file /srv/madar/.env -f compose/vps2.yml "$@"; }
  grep -cE '^(SCRAPE_USER_AGENT|TELEGRAM_BOT_TOKEN|TELEGRAM_CHAT_ID)=.' /srv/madar/.env   # 3
  dc run --rm worker-live python -c "import os, redis; print(redis.Redis.from_url(os.environ['CELERY_BROKER_URL']).ping())"   # True
  dc run --rm worker-live sh -c 'mkdir -p /srv/raw/capture && test -w /srv/raw/capture && echo writable'
  ```

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
| ~~Firebase Blaze with a $5 budget alert (A3)~~ Not needed: O6 decided Spark on 2026-11-03; the mirror ships on D4 | D0 | — | — |
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
| A3 / O6 | Blaze with a budget alert, or Spark with the mirror design | D0 | Blaze | **Decided 2026-11-03: Spark** (spec 004) |
| O5 | Apple enrollment as an individual or an organization | D0, to start it | Individual | Unconfirmed |
| O10 | Default satellites when the user skips | D1 | Nilesat + Badr | Default in use; confirm |
| O7 | Live data source for minute, events and lineups | **D4**, before spec 005 is planned | Rejected: manual live entry. If the capture fails: API-Football Pro or the clock estimate alone | **Decided 2026-11-04, changed 2026-11-05: FilGoal, Goal.com and YallaKora** (spec 031). The owner accepts the risk of FilGoal's and YallaKora's terms not yet read (system-design §3.3, §6.7). **Goal.com: FootballCo approved on 2026-11-05, as the owner reports: scraping for scores, match stats and everything else spec 031 plans, with no conditions or exceptions** ([031](#031-d5-follow-up-live-sources)) |
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
  - **decide O7** (decided 2026-11-04; see the table above).
- **D5:**
  - start the AdMob app and consent setup;
  - set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` on VPS-2 if they aren't there yet, since the live poller's alerts use them.
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
2. **Resolved 2026-11-03: the Firebase plan.** O6 is Spark (spec 004); delivery-plan A3 and system-design §3 now say so, matching constitution IX. (Kept so the later gap numbers don't shift.)
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
