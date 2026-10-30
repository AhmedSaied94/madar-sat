# Owner actions

This file lists the work only you can do: accounts, consoles, secrets, devices, and checks against the live hosts. Each day spec gets a section when its `/speckit-implement` finishes, with one subsection per lane. Tick an item when it's done, or say so and Claude ticks it.

The detailed steps stay in each spec's `tasks.md`, its quickstart and the [runbooks](runbooks/README.md). This file says what is left, in what order, and where to look. Your daily routine (merges, contract and migration reviews, the evening done check on devices: [delivery-plan.md](delivery-plan.md) §5.2, §5.4) isn't repeated here.

- **Before merge** items block the lane's PR.
- **After merge** items are checks on the live hosts. The day passes once they and its done check (delivery-plan Appendix A) pass.
- When a check fails, tell Claude what you saw. The fix goes in a follow-up PR, or in the next day's carry-over (delivery-plan §5.3).

The runbooks are being written on lane B2's branch `d01-b2`. Their links work once it merges.

## Open now

| Feature | Before merge | After merge | State |
| --- | --- | --- | --- |
| [001 D1 foundation](#001-d1-foundation) | B1 2 · B2 13 · A 1 · M 6 | B1 2 · B2 5, then the done check | **B1:** PR #2 merged on 2026-10-29; 45 of 49 tasks ticked in `../madar-b1`; the `contract-v1` tag isn't on GitHub, and T024 and T047–T049 are open. **B2:** implemented and uncommitted on `d01-b2` in `../madar-b2`; 13 of 18 ticked, with T058's live step and T064–T067 open. **A:** started in `../madar-a` (only `admin/package.json` so far), 0 of 24 ticked. **M:** implemented and uncommitted on `d01-m` in `../madar-m`; 45 of 45 tasks and all 7 round-1 review fixes ticked, with T136's phone, screenshot and browser steps open, plus the golden-image decision and release signing. |

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

PR #2 merged on 2026-10-29. T024 and T047–T049 are open ([tasks.md](../specs/001-d01-foundation/tasks.md#lane-b1)).

#### Before merge, in this order

- [ ] **T024 Contract freeze.** Review `git diff` of `backend/openapi/*.json` against [contracts/](../specs/001-d01-foundation/contracts/), then push the tag: `git tag -a contract-v1 -m "D1 contract freeze" && git push origin contract-v1` ([quickstart](../specs/001-d01-foundation/quickstart.md#lane-b1-data-and-contract)). Lane A's T082 and Lane M's T121 generate their clients from this tag, so it blocks both lanes. Then tell them.
- [ ] **T025–T027 Migrations.** PR #2 already merged them, so read them on `master` line by line, as tasks.md "The owner must review" and delivery-plan §5.4 ask. → [database-migrations](runbooks/database-migrations.md)

#### After merge

These need B2's hosts up (T058, T060).

- [ ] **Fresh snapshot.** In `../old_app`, run the README's "Refresh the snapshot" commands, then copy `migration/data/` to `~/madar-snapshot/`. Never copy it into `madar_sat/` ([quickstart Prerequisites](../specs/001-d01-foundation/quickstart.md#prerequisites); spec Edge Cases).
- [ ] **T048 Snapshot on VPS-1.** Over WireGuard, `scp` the snapshot to `/srv/snapshot/<date>/` on VPS-1 (T048 step 1), and tell B1 to run the load. → [snapshot-load](runbooks/snapshot-load.md)

### Lane B2: servers and CI

Implemented on 2026-10-29 and uncommitted on `d01-b2` in `../madar-b2`. T050–T057 and T059–T063 are ticked; T058's live step and T064–T067 are left ([tasks.md](../specs/001-d01-foundation/tasks.md#lane-b2), [quickstart](../specs/001-d01-foundation/quickstart.md#lane-b2-servers-and-ci)).

The bootstrap and the GitHub secrets come before the merge. Merging touches `infra/` and `.github/`, so `infra.yml`'s `sync` job runs on `master` straight away and needs the hosts and the secrets.

#### Before merge, in this order

- [ ] **Host facts.** Tell Claude:
  - whether both OCI VMs exist (delivery-plan A2);
  - each one's reserved public IP and VCN private IP;
  - the OS image (`bootstrap-vps.sh` assumes Ubuntu);
  - the login user.

  → [provision-host](runbooks/provision-host.md)
- [ ] **T064 step 1 Serial console.** Test the OCI serial console on both hosts before any SSH change. It's the only way back in if SSH breaks (system-design §7.2, FR-023). → [provision-host](runbooks/provision-host.md#2-console-password-then-test-the-serial-console), [break-glass](runbooks/break-glass.md)
- [ ] **OCI security list.** Open the ports in the security list (or an NSG), not only in iptables. VPS-1 needs 80/tcp, 443/tcp and 51820/udp from anywhere, plus 5432 and 6379 from VPS-2 inside the VCN. OCI's default list allows only 22 (Gaps 3). → [provision-host](runbooks/provision-host.md), [firewall-changes](runbooks/firewall-changes.md)
- [x] **Private repo, no `master` protection.** Decided 2026-10-29: the repo stays private and you're its only contributor, so `master` stays unprotected (GitHub Free can't protect a private repo's branch). Changes reach `master` through a green PR by convention (delivery-plan §5.1).
- [ ] **Actions minutes.** A private repo's free Actions minutes are capped, and `backend.yml` builds arm64 images under QEMU, which is slow. Watch the usage after the first deploys.

  See Gaps 1. → [ci-workflows](runbooks/ci-workflows.md)
- [ ] **Who runs the bootstrap.** Either you run it on the hosts and Claude gives you the commands, or you give a lane SSH access.
- [ ] **Who generates the deploy key.** Either you do, or Claude generates the ed25519 pair locally and loads the private half into `DEPLOY_SSH_KEY` with `gh secret set`, without printing it. → [secrets](runbooks/secrets.md)
- [ ] **T055, T057, T059 Review.** Read these yourself (tasks.md "The owner must review"):
  - the firewall rules: `infra/firewall/`, plus `decide_public_ssh` and `apply_firewall` in `infra/scripts/bootstrap-vps.sh`;
  - the `https://10.8.0.1` admin site in `infra/Caddyfile`;
  - `infra/scripts/deploy.sh`.

  → [firewall-changes](runbooks/firewall-changes.md), [deploy-and-rollback](runbooks/deploy-and-rollback.md)
- [ ] **Commit and push the branch.** First run `/speckit-review-implementation lane=b2` until no CRITICAL or HIGH finding is left (delivery-plan §5.2). Then ask Claude to commit `d01-b2` and push it.
- [ ] **T062 Firebase project.** Create the project if Day 0 step 2 isn't done. Give Claude its project ID: it goes into `infra/firebase/.firebaserc` and `CORS_ORIGINS`. Then set the secret `FIREBASE_SERVICE_ACCOUNT` yourself, from a service account with the Firebase Hosting Admin role. → [firebase-hosting](runbooks/firebase-hosting.md)
- [ ] **ACME email and GHCR owner.** Give `ACME_EMAIL` for Let's Encrypt, and confirm the GHCR owner `ahmedsaied94`, which comes from the git remote. → [tls-certificates](runbooks/tls-certificates.md)
- [ ] **T064 Bootstrap both hosts.**
  1. Run `bootstrap-vps.sh vps1` (then `vps2`). The first run creates `/srv/madar/.env` and stops.
  2. Fill in that `.env` (mode 600), then run the script again.
  3. Add WireGuard peers for your devices and for CI.
  4. Connect over WireGuard, then close public SSH with `--serial-console-tested`.
  5. Reboot both hosts, and confirm that `check-firewall.sh` passes and WireGuard comes back.

  The first run needs the repo's `infra/` on the host, and the repo is private (Gaps 23). → [provision-host](runbooks/provision-host.md), [private-network](runbooks/private-network.md)
- [ ] **T050 GitHub secrets and variables.**
  - Secrets: `WG_CI_CONFIG` (the CI peer from T064), `DEPLOY_SSH_KEY`, `DEPLOY_KNOWN_HOSTS` (VPS-1's host key line for `10.8.0.1`, taken over WireGuard) and `FIREBASE_SERVICE_ACCOUNT`.
  - Variables: `VPS1_IP` and `VPS2_IP`, plus `ARM_RUNNER` if you have one.

  Today none of them is set. → [secrets](runbooks/secrets.md), [ci-workflows](runbooks/ci-workflows.md)
- [ ] **Merge the PR** once its checks are green.

#### After merge

- [ ] **T058 Certificates.** After the first `infra.yml` `sync` run (or a manual `deploy.sh --infra-only`), confirm that `api.`, `media.` and `app.<ip1>.sslip.io` have Let's Encrypt certificates. → [tls-certificates](runbooks/tls-certificates.md)
- [ ] **T065 Scan from outside.** On a machine not connected to WireGuard:
  - `nmap` shows only 80 and 443 open, and UDP 51820 answers;
  - each public host has a valid certificate and the system-design §8 headers;
  - `https://10.8.0.1` doesn't answer from the internet but does over WireGuard.

  nmap isn't installed on the dev machine. → [exposure-check](runbooks/exposure-check.md)
- [ ] **T066 Deploy and rollback drill.**
  - Merge a trivial `backend/` change and confirm it's live within 15 minutes with no server step.
  - Run `backend.yml` with `break_healthcheck=true`: the job fails, and the previous tag is running again.
  - Confirm that GHCR keeps 3 versions.

  → [deploy-and-rollback](runbooks/deploy-and-rollback.md)
- [ ] **GHCR package access.** After the first image push, give this repo the Admin role on the `madar-backend` package (`infra/README.md`), or the `retention` job can't delete old versions. → [ci-workflows](runbooks/ci-workflows.md)
- [ ] **T067 Secret scan and green CI.**
  - Open a throwaway PR that adds a fake `AKIA…` key to a test file, confirm `gitleaks.yml` fails, then close it.
  - Get green `master` runs for `backend.yml`, `admin.yml`, `app.yml`, `infra.yml` and `pwa.yml`. The last three wait for Lanes A and M.

  → [secrets](runbooks/secrets.md), [ci-workflows](runbooks/ci-workflows.md)

### Lane A: admin

Started in `../madar-a`, with none of its tasks ticked yet. This subsection is refreshed when its `/speckit-implement` finishes ([tasks.md](../specs/001-d01-foundation/tasks.md#lane-a), [quickstart](../specs/001-d01-foundation/quickstart.md#lane-a-admin)).

#### Before merge

- [ ] **T091 Screens against the design.** Compare the PR's screenshots with `Login.png` and `Comp-Admin.png`: `/login?mock=invalid_credentials`, `/login?mock=account_locked`, and the shell at 1440 px and 1024 px (constitution "Done means", delivery-plan §5.4). Its client generation waits for B1's T024 tag.

### Lane M: app

Implemented on 2026-10-29 on `d01-m` in `../madar-m`; T092–T135 are ticked, T136's device and browser steps are the items below ([tasks.md](../specs/001-d01-foundation/tasks.md#lane-m), [quickstart](../specs/001-d01-foundation/quickstart.md#lane-m-app)).

#### Before merge, in this order

- [ ] **T136 step 3 On a phone.** Install the CI `app-prod-debug.apk` on an Android phone. Confirm that the matches route lists today's matches from VPS-1 (or `EmptyState`), and that `/gallery` opens. It needs VPS-1 serving `/v1` (B1's T048). A local debug build is at `app/build/app/outputs/flutter-apk/app-prod-debug.apk`.
- [ ] **T136 step 4 Screens against the design.** Compare the gallery screenshots, in both themes, with the four design-system PNGs and `Matches.png` (delivery-plan §5.4).
- [ ] **T136 step 5 No runtime font fetch.** Serve `app/build/web` and open `/gallery` and the matches route in Chrome DevTools → Network: no request to `fonts.gstatic.com` or `fonts.googleapis.com` (FR-042). Fix a hit by bundling the glyph, never by allowing the fetch. Two facts from the 2026-10-30 build, so the check doesn't surprise you: every glyph the app draws is bundled (Changa, IBM Plex Sans Arabic, IBM Plex Mono), so the engine's Noto fallback — the only `fonts.gstatic.com` string in `main.dart.js` — should never fire; but a default `flutter build web` loads CanvasKit from `www.gstatic.com/flutter-canvaskit`, which breaks the same rule. Lane B2 owns the fix in `.github/workflows/pwa.yml`: add `--no-web-resources-cdn` to the web build, which sets `useLocalCanvasKit: true` and serves `build/web/canvaskit/` (verified locally 2026-10-30).
- [ ] **T136 step 6 Attach the evidence.** Put the screenshots and the Network result in the PR (constitution "Done means").
- [ ] **Staging host.** Replace the placeholder LAN address in `app/env/staging.json` with the real LAN Caddy host (public value only). The `prod` values already point at `api.130.110.117.215.sslip.io` and `media.130.110.117.215.sslip.io`.
- [ ] **Golden container tag: choose an image (blocks `app.yml`).** The pin `app/.flutter-version` = 3.47.7 has no `ghcr.io/cirruslabs/flutter` image. The newest tag is `3.44.0`, and it ships Dart 3.12.0, below `app/pubspec.yaml`'s `sdk: ^3.13.5`, so it can't build the app. Checked 2026-10-30 with `docker manifest inspect` on every 3.45–3.47 tag (none) and `flutter pub get` inside `3.44.0` ("version solving failed"). The goldens were therefore regenerated with Flutter 3.47.7 on the host (they now carry a dark ≠ light byte check and pass under `TZ=UTC`, `Africa/Cairo`, `America/New_York` and `Asia/Tokyo`), but `app.yml` and `pwa.yml` still fail at the image pull. Pick one and tell Lane M: wait for the `3.47.7` image; publish one for this repo; or approve moving the app to 3.44.0 (lower `sdk:` in `app/pubspec.yaml`, re-resolve `app/pubspec.lock`, regenerate every golden in that image) (research R18). → [ci-workflows](runbooks/ci-workflows.md#the-golden-image-is-not-published)
- [ ] **Release signing (before the first release).** `app/android/app/build.gradle.kts` still signs `release` with the debug key under a `// TODO`. D1 ships only the debug APK, so nothing breaks yet; when the first AAB is cut, add the upload keystore as a GitHub secret and a real `signingConfigs.release` (system-design §9, A6).

### Day sign-off

- [ ] **Done check 001.** Run it on the deployed `master` and on devices once all four lanes have merged, as in the [quickstart table](../specs/001-d01-foundation/quickstart.md#done-check-spec-sc-010). Write the carry-over notes for anything that fails (delivery-plan §5.2, §5.3).
- [ ] **Defaults spec 001 used.** Confirm or change them (spec 001 Assumptions; delivery-plan §9):
  - O1: package ID `com.madarsat.app`;
  - O3: drop the card-sharing labels;
  - O10: default satellites Nilesat + Badr, which is due on D1.

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
