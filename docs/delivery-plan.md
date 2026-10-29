# Madar Sat — Delivery Plan

| | |
|---|---|
| Status | Draft 3, 2026-10-29: day briefs added (Appendix B) |
| Scope | Everything from setup to V3: MVP, V1, V2, V3 |
| Inputs | [product-business.md](product-business.md) (what), [system-design.md](system-design.md) (how), [`madar-design/`](../madar-design/README.md) (look) |
| Builders | AI agents: Claude Code sessions planned and driven with Spec Kit. One human (you) orchestrates, reviews, tests on devices and owns the accounts |
| Unit of work | **One Spec Kit spec per working day, never more.** Spec `0NN` is day `DNN`. All four lanes work from the same spec, each on its own section of tasks (§5). Each day's scope is its brief in Appendix B |

---

## 1. Summary

| Milestone | Day | Specs | What ships |
|---|---|---|---|
| **M0** Setup | D0 (half a day) | none | Accounts, decisions, Spec Kit initialized, constitution, spec 001 planned |
| **M1** MVP | **D4** | 001–004 | **Public PWA** (Android Chrome, iPhone, desktop). Android in closed testing since D2 |
| **M2** V1 | D12 | 005–012 | Every [P] and [V1] feature. Android production as soon as the Play gate allows (§3) |
| **M3** V2 | D20 | 013–020 | Satellite finder, widgets, commentator profiles, reports, TOTP, viewing links. iOS app submitted, if the Apple account is active |
| **M4** V3 | D30 | 021–030 | Accounts, predictions and leaderboards, share cards, calendar, ad-free purchase, English UI, sponsorship slot |

- **"D" is one working day** with four agent lanes in parallel. Store reviews and test periods run on **calendar** days and are listed separately in §3.
- **Day estimates assume no external blockers.** Work a day doesn't finish rolls into the next day's spec as carry-over (§5.3). The buffer is in the hardening days: D4, D11–D12, D19–D20, D30.

### Assumptions (change the plan if they're wrong)

| # | Assumption | If it's wrong |
|---|---|---|
| A1 | The Play Console account is **personal and created after Nov 2023**, so it needs a closed test with 12 testers for 14 days before production | Older or organization account: Android production ships with V1 on D12 |
| A2 | Both OCI Ampere VPSs are already running, with reserved public IPs | Ampere capacity is often unavailable. Provision now; D1 slips until the boxes exist |
| A3 | Firebase moves to **Blaze with a $5 budget alert** for the launch, so the PWA mirror can wait until D9–D10 | If staying on Spark: move the mirror work into D3–D4. Lane M then needs about one extra day |
| A4 | The MVP uses a **reduced test bar**. D11 restores your 80 % coverage rule (§7). The ratified constitution (v1.0.0) requires 80 % on every PR, so this needs a constitution amendment on D0 | If 80 % is required from day 1: the MVP takes about 6 days |
| A5 | Card-sharing labels and BISS keys are dropped (O3), as the design assumes | Keeping them changes the schema and the S3/S12 screens |
| A6 | Package ID `com.madarsat.app` (O1) | Any other ID is fine; it must be fixed before the first Play upload on D2 |
| A7 | The Apple account is active by D13 | Otherwise the iOS work on D13 and D16–D18 moves after D30, and those slots pull V3 work forward |

---

## 2. Scope by phase

| Area | MVP (D1–D4) | V1 rest (D5–D12) | V2 (D13–D20) | V3 (D21–D30) |
|---|---|---|---|---|
| **App screens** | S0 system screens · S1 onboarding · S2 matches with the channel line · S3 match detail (where to watch, readout, commentators, stadium) · S4 my satellites · S5 frequencies · S9 favorites · S15 settings (core) · S16 more | S3 live center · S6 channel · S7 team · S8 competition · S10 follow sheet · S11 rights · S12 feeds (if O8 keeps them) · S13 sport switcher · S14 search · S15 competition order/hide · desktop two-pane | S17 commentator · S18 satellite finder · S19 report · S20 widget + ongoing notification | Sign-in and profile · predictions · leaderboards · share card · add to calendar · ad-free purchase · English UI |
| **Push** | Kickoff reminder | Match started, goal, final score, channels updated, frequency changed, announcement · per-type preferences | Commentator follow · report resolved | Prediction results |
| **Live data** | Clock estimate + admin override | Real live feed: status, minute, score, events; lineups where available (O7) | Ongoing live notification | — |
| **Ingestion** | ysscores fixtures · LiveSoccerTV channels · bridge from the old Firestore (fallback) | YallaKora · sporteventz · API-Football · unresolved-names queue · bridge retired | — | English names (`name_en`) |
| **Admin** | A1 login · A0 shell · A2 dashboard (basic) · A3 matches · A4 match editor · A5 teams · A6 competitions · A7 satellites · A8 channels · A10 commentators · A13 sources (basic) | A9 rights · A11 lists · A12 feeds · A13 unresolved queue + run detail · A15 push · A16 users · A17 audit · team and channel merge tools | A14 reports · TOTP · viewing-link fields | App users lookup · display-name moderation · English name fields · sponsor slots |
| **Platform** | PWA on Firebase Hosting · Android closed testing · Remote Config · Crashlytics | AdMob + UMP consent · PWA mirror service worker · share links · soft update · maintenance · channel delta sync | iOS native (Codemagic, APNs, widget, local reminders) | Play Billing (later StoreKit) |
| **Ops** | Compose, Caddy, WireGuard, CI/CD, nightly backups, Uptime Kuma | Restore drill, runbook, alert routing, load test, security audit | Domain move (if bought) | — |

---

## 3. External gates (calendar-bound)

| Gate | Starts | Takes | Unblocks |
|---|---|---|---|
| Play closed test: 12 testers opted in for 14 days (if A1) | D2: first build to the closed track. Recruit testers on D0–D2 | 14 calendar days, then a production-access review (usually a few days) | Android production |
| Play app review (each release) | Every submission | Hours to several days | Android releases |
| Apple Developer enrollment | **D0** | Individual: about 1–2 days. Organization: weeks (D-U-N-S number) | iOS days (D13, D16–D18) |
| App Store review | D20 | 1–3 days, longer when rejected | iOS public |
| Firebase Blaze switch (A3) | D0 | Minutes | PWA launch without the quota risk |
| AdMob app + consent setup | D5 | AdMob reviews the app after it's on the Play Store | Ads in Android production |
| Claude Design pass for V3 screens (sign-in, profile, predictions, leaderboards, paywall, share card, sponsor slot) | D17 | 1–2 days | D21 |

---

## 4. Team model: four lanes plus you

| Lane | Code area | Main work | Later |
|---|---|---|---|
| **B1** Core backend | `backend/` (API, domain, migrations, push) | Data model, `/v1`, `/admin/api`, auth, notifications, live, performance | Accounts, predictions, purchases |
| **B2** Ops + ingestion | `infra/`, `backend/app/adapters`, CI | Servers, CI/CD, scrapers, source health, backups | iOS pipeline, domain move, English names data |
| **A** Admin web | `admin/` | Every admin screen | Also takes Flutter platform work (**M2**) from D9, when the admin queue is light |
| **M** App | `app/` | Every app screen and component | Shares app work with M2 from D9 |
| **You** | — | Decisions, contract review, merges, device testing, accounts, store listings, testers | — |

- **One Claude Code session per lane**, each in its own git worktree (§5.1). A fifth, short planning session plans the next day's spec (§5.2).
- **Ownership rules:**
  - **B1 owns Alembic migrations and the API contract.** Other lanes ask B1 for changes; they never edit them directly.
  - **Generated clients are never hand-edited.** That means the Dart Retrofit client (`swagger_parser`) and the TypeScript client (Orval). CI regenerates them and fails the build if they're stale.
  - **Each lane changes only its own folders**, as tagged in the day's `tasks.md`.

---

## 5. One spec per day: how it runs

### 5.1 Folders and branches

```
NewSatApp/
├── old_app/        recovered Sat Air source (outside the repo; agents read it as ../old_app/)
├── madar_sat/      main checkout: planning session, merges          branch main
├── madar-b1/       worktree, lane B1                                 branch dNN-b1
├── madar-b2/       worktree, lane B2                                 branch dNN-b2
├── madar-a/        worktree, lane A                                  branch dNN-a
└── madar-m/        worktree, lane M                                  branch dNN-m
```

- Worktrees must be **siblings** of `madar_sat/`, so `../old_app/` resolves the same way in every lane.
- Git can't check out one branch in two worktrees. So the day's spec lives on `main`, and each lane works on its own branch `dNN-<lane>`, cut from `main` each morning.
- **`SPECIFY_FEATURE_DIRECTORY` tells Spec Kit which spec is active**, because the lane branch names don't match the spec folder and `.specify/feature.json` is per checkout (git-ignored): start each lane session as `SPECIFY_FEATURE_DIRECTORY=specs/0NN-dNN-<name> claude`. `SPECIFY_FEATURE` alone doesn't select a spec in this Spec Kit version.
- **The `feature-branch` hook switches branches** before every Spec Kit step (and right after `/speckit-specify`). In a lane worktree it checks out `dNN-<lane>`, creating it from `origin/main` if it doesn't exist. In the planning checkout it checks out the spec branch `0NN-dNN-<name>`, creating it from the current HEAD. It never stashes, resets or discards: if the switch is blocked, the step stops and you decide.
- `main` is protected: PRs only, CI required, squash merge.

### 5.2 The daily loop

| When | Who | Steps |
|---|---|---|
| **Day N−1, afternoon** | Planning session in `madar_sat/` + you | 1. `git switch main && git pull` · 2. `/speckit-specify` with the template in Appendix A for day N (its scope is the day's brief in Appendix B), plus carry-over (§5.3); the hook then creates the spec branch `0NN-dNN-<name>` · 3. `/speckit-clarify` only if questions remain · 4. `/speckit-plan` · 5. `/speckit-tasks` · 6. `/speckit-analyze` · 7. You review the spec and the lane sections · 8. Merge the spec branch to `main` as a docs-only PR |
| **Day N, morning** | Each lane | `git fetch && git switch -C dNN-<lane> origin/main` → `SPECIFY_FEATURE_DIRECTORY=specs/0NN-dNN-<name> claude` → `/speckit-implement Only the tasks under "Lane <X>" in tasks.md.` |
| **Day N, midday and evening** | Each lane → you | `/speckit-review-implementation`, ideally on a different model from the implementer, reviews the lane and appends its fix tasks to the lane's section; the lane fixes them with `/speckit-implement` and reviews again until there is no CRITICAL or HIGH finding. Then the lane opens a PR, and you merge it after reading the review's "Owner must review" files. **At least two merges per lane per day.** Lanes rebase on `main` after each merge to pick up the others' work |
| **Day N, evening** | You | Run the day's **done check** (Appendix A) on the deployed `main` and on devices. Anything that fails becomes carry-over |

**Required shape of every `tasks.md`**, which the template asks for:
- one section per lane (`## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M`), each written as an independently testable user story;
- a final section, `## Done check`, with that day's acceptance steps.

Lanes tick checkboxes only in their own section, so four PRs touching the same `tasks.md` never conflict.

Planning only one day ahead means each spec is written against the **real** state of `main`: the frozen API contract, what actually merged, and what slipped.

### 5.3 Carry-over

- When a day ends with unchecked tasks, the next day's `/speckit-specify` prompt starts with: *"Carry-over: the unchecked tasks in `specs/0NN-dNN-<name>/tasks.md` come first."*
- If carry-over exceeds about a quarter of a lane's day, move that lane's lowest-priority item for the new day to the next hardening day (D4, D11, D19 or D30), and note it in the spec.

### 5.4 Your daily rhythm

| Time | You | Agents |
|---|---|---|
| Morning (1 h) | Review and merge overnight PRs. Check any **contract diff** and **migration** line by line. Start the lane sessions | Implement |
| Midday (30 min) | Merge; deploy `main` to production (from D1 the API is live, with unfinished features behind flags) | Continue |
| Afternoon (1–2 h) | Plan tomorrow's spec with the planning session. Accounts, store work, testers, decisions | Continue |
| Evening (1 h) | Done check on devices (Android + iPhone PWA); write carry-over notes | Fix issues overnight, if run unattended |

**What you must review yourself:**
- the API contract;
- Alembic migrations;
- auth and permissions code;
- push audience queries (a wrong one can spam everyone);
- the UI compared with the design PNGs.

Agents self-review everything else, with CI as the gate.

### 5.5 Feature flags

Everything not ready ships **dark** behind Remote Config `features.*` (system-design §5.1). That way all lanes can merge to `main` every day without exposing half-built screens. Flags are removed one phase after a feature launches.

The briefs in Appendix B use these keys: `live_center`, `lineups`, `reports`, `satellite_finder` (already in system-design §5.1) and `home_widget`, `commentators`, `ongoing_live`, `viewing_links`, `accounts`, `predictions`, `share_card`, `calendar`, `ad_free`, `english_ui` (new; B1 adds each one to the Remote Config defaults on the day that introduces it). Ads use the existing `ads.enabled` key.

---

## 6. Day-by-day plan

### Day 0: setup (no spec)

**Accounts and decisions:**
1. Confirm O1, O3 and A1–A4.
2. Create the Firebase project: Android app, web app, FCM web-push key, Remote Config defaults.
3. Create the Play Console app with listing placeholders.
4. **Start Apple enrollment.**
5. Backblaze B2 account; a Telegram bot for alerts.
6. Check both VPSs, reserve their IPs, create a WireGuard key for your laptop.
7. **Recruit 12+ Android testers.**

**Repo:**
1. Install Spec Kit (`uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`) and run `specify init --here --ai claude`.
2. Run `/speckit-constitution` with §8.1. *Done: v1.0.0 is in `.specify/memory/constitution.md`. Still to do: amend its Quality Gates for A4 (or drop A4), and delete its Sync Impact Report comment.*
3. Extend the root `CLAUDE.md` and add one per lane (§8.2).
4. Change the design package's wordmark from «مدار» to **Madar Sat / مدار سات**.
5. Rename the default branch `master` → `main` (§5.1 assumes `main`) and protect it.
6. **Plan spec 001** using the daily loop, from its brief in Appendix B.

### Phase 1: MVP (D1–D4)

| Day · spec | B1 · Core backend | B2 · Ops + ingestion | A · Admin | M · App |
|---|---|---|---|---|
| **D1 · 001** | Alembic `0001` from `schema.sql` + MVP additions, snapshot load, media rehosting job, `/v1` read endpoints. **Contract frozen by 13:00**, then deployed to VPS-1 | Compose for both VPSs, Caddy, WireGuard, firewall, CI (backend arm64 image + deploy, Firebase Hosting, Android build artifact) | Vite + TS + Tailwind + tokens, A0 shell, A1 login, DataTable and FormField components, Orval client against a Prism mock | Scaffold (flavors, go_router, Riverpod, drift, Dio/Retrofit), `madar_tokens.dart` + fonts, signature components with golden tests |
| **D2 · 002** | Admin API (argon2, JWT, roles), CRUD, media upload, audit writes, estimated live + manual override | ysscores adapter (ported from `../old_app/public/IMPORT.html`), Firestore bridge, `import_runs`, home-box scrape worker | A3 matches, A4 match editor (channel picker, per-channel commentators, hide channel) | S2, S3, S4, S5 on the live API. **First Android build to closed testing.** PWA on a preview channel |
| **D3 · 003** | Devices + follows, reminder scheduler, outbox, FCM dispatcher, Redis cache + ETags | LiveSoccerTV adapter (from `LVS.html`), source health, circuit breaker, zero-items alarm, nightly backups, Uptime Kuma | A5, A6, A7, A8, A10 (image and audio upload), A13 basic, A2 basic | S1 onboarding, S9 favorites + follow, push on Android and web, S15 core, S16, S0, Remote Config |
| **D4 · 004** | Load test `/v1/live`; fix security-review findings | Imports running unattended; parser edge cases; runbook v0 | Polish, Playwright smoke (login → edit match), deploy on `wg0` | Real-device bug bash, release builds, **public PWA** |

### Phase 2: V1 (D5–D12)

| Day · spec | B1 | B2 | A → M2 | M |
|---|---|---|---|---|
| **D5 · 005** | Live poller, `match_events`, `match_lineups` (needs O7) | YallaKora adapter; unresolved-names backend (alias tables, queue) | A13 unresolved queue + run detail; A9 rights editor | S6 channel, S7 team, S8 competition |
| **D6 · 006** | All push types, per-type preferences, frequency-change detection + history | sporteventz; API-Football with a daily request budget | A15 outbox + composer, A16 users, A17 audit + diff | S3 live center (timeline, lineups, score animation) |
| **D7 · 007** | `/v1/channels/sync` delta sync, `/v1/search`, cache review | Retire the Firestore bridge once 3 days of diffs are clean; alert routing | Team and channel merge tools, A11 lists, A12 feeds | S14 search, S11 rights, S13 sport switcher |
| **D8 · 008** | Announcements; maintenance and soft-update config end to end | Restore drill, runbook v1 | Admin bug queue | S10 follow sheet, S15 competition order/hide, S12 feeds (if O8 keeps them), maintenance + soft-update UI |
| **D9 · 009** | Load test at 5k concurrent; optional Caddy cache-handler | PWA mirror on VPS-1, content-hashed build in CI, CORS | **M2:** AdMob banner + paced interstitial (O9), UMP consent | Desktop two-pane (≥ 1024), hover and focus states |
| **D10 · 010** | Integration bug fixes | Service-worker failover tests, emergency install link | **M2:** custom service worker (cache, mirror, FCM), share links, install-guide polish | Accessibility pass: font scale 1.3, screen-reader labels, RTL/bidi audit |
| **D11 · 011** | Coverage to 80 %, contract tests, `pip-audit` | Secret scan, dependency audit, backup verification | Admin coverage to 80 %, Playwright suite | App coverage to 80 %, `integration_test` flows, golden updates |
| **D12 · 012** | Release fixes | Production deploy, monitoring review | Android release build with ads | Store screenshots from real screens; final PWA release; Android production submitted when the Play gate clears |

### Phase 3: V2 (D13–D20)

| Day · spec | B1 | B2 | A / M2 | M |
|---|---|---|---|---|
| **D13 · 013** | Satellite orbital positions checked; commentator profile API; reports API started | Codemagic iOS pipeline, signing, APNs key in Firebase (A7) | A14 reports queue | S18 satellite finder: math, location, readouts |
| **D14 · 014** | Reports API complete, rate limits, "report resolved" push | Domain move (if O4) or Caddy cache tuning | **M2:** Android home widget (`home_widget`) | S18 compass dial, camera overlay (native), calibration hint |
| **D15 · 015** | Commentator-follow push; viewing-link field and API | Alert dashboards, log retention review | **M2:** ongoing live notification on Android (FCM data messages) | S17 commentator profile + follow |
| **D16 · 016** | Admin TOTP | TestFlight internal build | TOTP UI; viewing-link fields in A9; commentator admin tweaks | S19 report sheet; viewing-link buttons in S3 and S11.4 |
| **D17 · 017** | iOS push payload details (APNs through FCM) | Codemagic release workflow, App Store Connect API key | **M2:** iOS permission flow, native local reminders | V2 polish; fixes from D13–D16 |
| **D18 · 018** | Bug fixes, performance | Bug fixes | **M2:** iOS WidgetKit widget; Live Activity as a stretch goal | iOS QA: safe areas, gestures, layout |
| **D19 · 019** | Coverage ≥ 80 % on new code | TestFlight external beta | App Store assets, privacy labels | E2E flows for finder and report |
| **D20 · 020** | Release fixes | Release deploy, monitoring | iOS submitted to App Review | Android + PWA V2 release |

### Phase 4: V3 (D21–D30)

| Day · spec | B1 | B2 | A / M2 | M |
|---|---|---|---|---|
| **D21 · 021** | Firebase Auth ID-token verification, users table, device → user link, follows merge | `name_en` columns; fill from LiveSoccerTV and API-Football | App users lookup screen | Sign-in UI (Google, Apple, email link), profile |
| **D22 · 022** | Account deletion: in-app + web deletion URL | `name_en` backfill + coverage report | `name_en` fields on teams, competitions, channels | Delete-account flow; anonymous data linking; settings integration |
| **D23 · 023** | Predictions model, lock at kickoff, settlement on final, scoring rules | Backups cover the new tables; Redis memory check | Display-name moderation | Prediction input on S3 (pre-match); my predictions |
| **D24 · 024** | Leaderboards (Redis sorted sets: weekly, season, per competition) + API | Load test leaderboards | Predictions admin view (settlement override) | Leaderboard screens |
| **D25 · 025** | Prediction-results push; abuse limits per device and account | Bug fixes | Bug queue | Results UI; prediction polish |
| **D26 · 026** | Optional Open Graph share page on VPS-1 (`/s/m/:id`) | Caddy route for share pages | Bug queue | Share card (`RepaintBoundary` → PNG → share sheet); add to calendar (native; ICS on web) |
| **D27 · 027** | Play purchase verification (Google Play Developer API), entitlements | Service-account secret handling | Entitlement lookup | In-app purchase flow, paywall, restore |
| **D28 · 028** | Entitlements turn ads off (Remote Config condition + API flag) | `name_en` completion for prioritized competitions | English names QA view | Entitlement handling; extract strings for English |
| **D29 · 029** | `lang` parameter: `name_en` with Arabic fallback | Bug fixes | Missing-translation report | ARB `en`, language switch in S15, LTR mirroring QA |
| **D30 · 030** | Sponsor-slot API; release fixes | Release deploy | Sponsor slots admin (scheduling, "برعاية" label) | Sponsor slot on S5.2; V3 release |

### After V3: steady state

- **B2 keeps about 20 % of its time for scraper maintenance and data operations.**
- **Monthly:** restore drill, dependency updates, KPI review (product-business §5).
- New work keeps the same rhythm: one spec per day, flags until ready.

---

## 7. Quality bar and CI gates

| | MVP (D1–D4) | From D11 on |
|---|---|---|
| Backend | Tests first for domain logic, time and frequency parsing, auth, and scraper parsers (against saved HTML fixtures). Contract tests on `/v1`. Coverage ≥ 70 % on `domain/`, `adapters/`, `services/` | ≥ 80 % overall; integration tests against Postgres and Redis containers |
| Admin | Zod schemas for every response; Playwright smoke (login → edit match → see the change) | ≥ 80 % (Vitest); Playwright suite for A3/A4/A8/A13 |
| App | Unit tests for formatters (time, digits, frequency, bidi) and repositories; golden tests for signature components in both themes and at font scale 1.3 | ≥ 80 %; `integration_test`: onboarding → matches → detail → copy frequency; follow → push received |
| Every PR | Lint, type check and tests green; generated clients up to date; no secrets (gitleaks); dependency audit; reviewer agents run | Same, plus the coverage threshold |

---

## 8. Agent guidance files

### 8.1 Constitution seed

This seed was used on D0. The ratified text is `.specify/memory/constitution.md` (v1.0.0), and that file wins where they differ.

```text
Madar Sat constitution
1. Sources of truth: docs/product-business.md decides WHAT, docs/system-design.md decides HOW,
   madar-design/ decides the LOOK (tokens > component READMEs > screen HTML > screen PNG),
   docs/delivery-plan.md decides WHEN and WHO. When they conflict or are silent, stop and ask;
   never invent product behaviour.
2. One spec per working day. tasks.md has one section per lane (Lane B1, Lane B2, Lane A, Lane M),
   each an independently testable user story, plus a final "Done check". A lane implements and ticks
   only its own section and touches only its own folders: B1 backend/ (except adapters), B2 infra/,
   backend/app/adapters/ and CI, A admin/, M app/.
3. Contract first: the FastAPI OpenAPI spec is the contract and lane B1 owns it and all Alembic
   migrations. Clients are generated (Dart: swagger_parser + Retrofit; TS: Orval + Zod) and never
   edited by hand. Breaking changes use expand/contract.
4. Backend: FastAPI, SQLAlchemy 2 async, Pydantic v2. ORM or bound parameters only. Celery tasks use
   bind=True, autoretry with exponential backoff and jitter, and are idempotent (upsert by external id).
   Admin routes exist only in the admin app.
5. Admin: React 18, TypeScript strict (no any without a justifying comment), Vite, Tailwind with design
   tokens (no arbitrary values), React Query, React Hook Form + Zod, clsx/cva for conditional classes.
6. App: Flutter, Riverpod only, go_router, Dio + Retrofit, drift, feature-first clean architecture.
   const constructors, mounted checks after await, dispose controllers, ListView.builder for lists,
   native-only plugins behind interfaces with web no-op implementations, colours and text only from
   madar_tokens.dart. Secrets never in Dart source; tokens in flutter_secure_storage.
7. Design fidelity: RTL first; Latin names and frequencies are LTR isolates; red only for live;
   the frequency readout stays dark in both themes; Western tabular digits; honest data states;
   touch targets >= 48 dp. Compare every finished screen with its PNG.
8. Security: no secrets in code or the repo; validate every input at the boundary; rate limits on
   public endpoints; upload type and size checks; host allowlists for scrapers.
9. Testing: write the test first. MVP bar and V1 bar as in docs/delivery-plan.md §7.
10. Ship dark: unfinished features stay behind Remote Config flags.
11. Simplicity: reuse before adding; any new dependency is justified in plan.md.
12. Done means: CI green, reviewer agents run with CRITICAL/HIGH fixed, the lane's acceptance steps
    demonstrated (a screenshot next to the design PNG for UI work).
```

### 8.2 `CLAUDE.md` files

| File | Contents |
|---|---|
| `/CLAUDE.md` | Exists. Add: lane ownership (§4), the daily loop and worktree rules (§5), "never edit generated clients or another lane's folder" |
| `backend/CLAUDE.md` | How to run (compose, `alembic upgrade head`, pytest), module layout (system-design §6), migration ownership, Celery task template, adapter contract |
| `admin/CLAUDE.md` | How to run (Vite + Prism mock or local API), Orval regeneration, `tokens.css` usage, `SCREENS.md` lookup, Playwright commands |
| `app/CLAUDE.md` | Flavors and run commands, codegen commands, `madar_tokens.dart` and fonts, `SCREENS.md` lookup, platform-adapter pattern, golden-test update command |

---

## 9. Decision schedule

| # | Decision | Decide by | Default if undecided |
|---|---|---|---|
| O1 | Package ID | D0 | `com.madarsat.app` |
| O3 | Drop card-sharing labels and BISS keys | D0 | Drop |
| A1–A4 | Play account type · VPSs · Blaze · test bar | D0 | As assumed in §1 |
| O5 | Apple enrollment type | D0 (to start it) | Individual |
| O10 | Default satellites when the user skips | D1 | Nilesat + Badr |
| O7 | Live data source (minute, events, lineups) | **D4** (before spec 005 is planned) | D5's live work shrinks to manual live entry; the clock estimate stays |
| O8 | Keep Feeds | D7 | Drop from the app; keep the table |
| O9 | Interstitial placement | D8 | On return from match detail |
| O4 | Buy a domain | D13 | Stay on sslip.io |
| — | V3 designs ready | D20 | V3 starts with backend-first days |
| — | Accounts provider | D20 | Firebase Auth |

---

## 10. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Scrapers blocked on Oracle IPs, or source layouts change | High | Home-box worker over WireGuard from D2; Firestore bridge during the MVP; zero-items alarm; parsers tested against saved pages; admin manual entry |
| Your review time is the bottleneck | High | Four lanes at most; you review contracts, migrations, auth and UI, and CI plus reviewer agents gate the rest; small PRs twice a day |
| A day spec mixes unrelated work and gets vague | Medium | Every lane section is a self-contained user story with its own acceptance steps; `/speckit-analyze` before merging the spec |
| Carry-over snowballs | Medium | The quarter-day rule in §5.3; hardening days absorb overflow |
| Agents drift from the design | Medium | Constitution rule 7; components built once on D1 with golden tests; PNG comparison in the definition of done |
| Contract churn breaks the admin and app lanes | Medium | Contract frozen D1 13:00; changes through B1 only; generated clients checked in CI |
| No affordable live data source (O7) | Medium | Live center behind a flag; the clock estimate stays honest ("تقديري") |
| Play 14-day test or review delays | Certain under A1 | The PWA is the public channel until Android clears |
| iPhone push fails in the PWA | Medium | Test on a real iPhone (iOS ≥ 16.4) on D3, not D4 |
| Apple enrollment is slow | Medium for organizations | Start on D0; A7 fallback swaps the iOS days for V3 work |
| Oracle reclaims or loses a VPS | Low | Nightly off-site backups, restore drill on D8, infra as code in `infra/` |
| Store removal over intellectual property | Low if O3 drops the labels | O3; act on takedowns within 48 h |

---

## Appendix A. Day specs

### Prompt template for `/speckit-specify`

Each day has exactly **one** spec. Its full brief (the four lane stories, what to read, lane acceptance, flags) is in Appendix B, so the prompt only names the day:

```text
Day <N> of docs/delivery-plan.md: spec <0NN>-d<NN>-<name>.
[Carry-over: the unchecked tasks in specs/<previous spec>/tasks.md come first.]
Scope: exactly the brief "D<N> · <0NN>" in docs/delivery-plan.md Appendix B. Write one user story
per lane (Lane B1, Lane B2, Lane A, Lane M) from its lane row, with that row's acceptance as the
story's acceptance scenarios. Nothing outside the brief goes in this spec; anything extra waits for a
later day.
Read the sections and design boards each lane row lists (boards are in madar-design/app-flutter/SCREENS.md
and madar-design/admin-react/SCREENS.md).
tasks.md must have the sections "Lane B1", "Lane B2", "Lane A", "Lane M" and "Done check"; the Done check
is the brief's done check, copied word for word.
Follow .specify/memory/constitution.md.
```

A lane row that says **none** still gets a `## Lane X` section with the single task "No work today: review and merge support". This keeps the `tasks.md` shape fixed.

### Catalog

| Spec | Name | Done check (end of day) |
|---|---|---|
| **001** | `001-d01-foundation` | VPS-1 serves `/v1` with snapshot data over HTTPS; contract tagged `v1`; admin login screen renders against the mock; the app shows the component gallery (goldens pass) and loads `/v1/matches`; CI green in all four folders |
| **002** | `002-d02-core-flows` | An admin logs in over WireGuard and edits a match, and the change appears in the app; ysscores (or the bridge) imports tomorrow's fixtures; S2–S5 work on a real Android phone; closed-test build uploaded |
| **003** | `003-d03-follow-push-sources` | A kickoff reminder arrives on Android and on an installed iPhone PWA; LiveSoccerTV adds channels to upcoming matches; all MVP admin entities editable; one nightly backup completed; onboarding → follow → favorites works |
| **004** | `004-d04-mvp-launch` | **MVP gate:** importers cover today to +3; admin edit visible in ≤ 60 s; reminders on both platforms; bug-bash script without crashes; no CRITICAL security findings; PWA first load < 5 s on 4G and < 1.5 s afterwards; PWA public |
| **005** | `005-d05-live-and-discovery` | A real live match updates status and score (or manual live entry, if O7 is still open); YallaKora imports; unresolved names visible in the admin; S6, S7, S8 on a device |
| **006** | `006-d06-notifications-and-live-center` | A goal push arrives with the correct score; the live center shows events; a frequency change pushes to followers; the admin composer sends a test push; audit diff visible |
| **007** | `007-d07-sync-search-sources` | A second channel sync downloads < 5 KB; search matches Arabic letter variants; sporteventz and API-Football import; the bridge is retired (or the reason it can't be is logged); S11, S13, S14 on a device |
| **008** | `008-d08-preferences-and-ops` | Restore drill passed; maintenance and soft-update switch from Remote Config on a device; per-type preferences respected by the dispatcher; merge tools work |
| **009** | `009-d09-ads-and-desktop` | Banner + paced interstitial with UMP consent (EEA test device); desktop two-pane at 1440 with keyboard focus; load-test report at 5k concurrent |
| **010** | `010-d10-pwa-and-accessibility` | The PWA loads from the mirror with Firebase blocked; a share link opens the match in the PWA and the app; the accessibility checklist passes at font scale 1.3 |
| **011** | `011-d11-v1-hardening` | Coverage ≥ 80 % in all three apps; E2E suites green; no CRITICAL/HIGH security findings open |
| **012** | `012-d12-v1-release` | **V1 gate:** all [P] and [V1] items done; live status correct over 3 match days; ≥ 95 % channel coverage at T−2 h; store listing, privacy policy, data safety and consent done; PWA V1 released; Android production submitted when the Play gate clears |
| **013** | `013-d13-finder-and-ios-pipeline` | Finder azimuth and elevation match a reference calculator for 3 cities; Codemagic produces a signed iOS build (A7); the admin reports queue lists test reports |
| **014** | `014-d14-widget-and-reports` | The Android widget shows the next followed match; report → admin → resolve → push works; the compass works on a device |
| **015** | `015-d15-commentators-and-live-notification` | The ongoing notification updates during a live followed match; commentator profile + follow; viewing-link API live |
| **016** | `016-d16-totp-reports-links` | TOTP required for the admin role; report sheet and viewing-link buttons on a device; TestFlight internal build installed |
| **017** | `017-d17-ios-native-1` | On iOS: push and native local reminders work on a device; permission flow matches the design |
| **018** | `018-d18-ios-native-2` | The iOS widget shows the next match; iOS QA list closed |
| **019** | `019-d19-v2-hardening` | ≥ 80 % coverage on new code; TestFlight external beta live; App Store assets ready |
| **020** | `020-d20-v2-release` | **V2 gate:** Android + PWA released with V2 features; iOS submitted to App Review |
| **021** | `021-d21-accounts` | Sign-in with Google, Apple and email link on Android and PWA; anonymous follows merged into the account |
| **022** | `022-d22-account-deletion-and-names` | Account deletion works in-app and through the web URL; `name_en` filled for the teams in prioritized competitions |
| **023** | `023-d23-predictions` | A prediction can be made before kickoff, locks at kickoff, and is scored correctly when the match finishes |
| **024** | `024-d24-leaderboards` | Weekly, season and competition leaderboards are correct against a fixture dataset |
| **025** | `025-d25-prediction-results` | Results push arrives; abuse limits enforced |
| **026** | `026-d26-share-cards-calendar` | A share card is generated and shared from S3; add to calendar works on Android and as ICS on web |
| **027** | `027-d27-ad-free-purchase` | A license-tester purchase is verified on the server and removes ads |
| **028** | `028-d28-entitlements-and-english-data` | Purchase restores after reinstall; English names cover ≥ 90 % of prioritized competitions |
| **029** | `029-d29-english-ui` | The whole app passes the screen QA list in English (LTR); Arabic unchanged |
| **030** | `030-d30-sponsorship-v3-release` | **V3 gate:** a sponsor slot scheduled in the admin appears on S5.2; V3 released |

---

## Appendix B. Day briefs (one spec each)

Each brief is the whole scope of one day's spec. The planning session turns it into `spec.md`, `plan.md` and `tasks.md` (Appendix A). Shorthand: **PB** = product-business.md, **SD** = system-design.md, **app:** / **admin:** = a board in `madar-design/app-flutter/SCREENS.md` / `madar-design/admin-react/SCREENS.md`.

Rules for every brief:
- **Starts from** lists what must already be on `main`. If it isn't, the missing part is carry-over and comes first (§5.3).
- **Contract** lists the endpoint and schema changes B1 makes that day. Only these change the OpenAPI spec and Alembic. A lane that needs anything else asks B1, and the change moves to the next day.
- **Flags** lists the Remote Config `features.*` keys the day's work hides behind until its launch day (§5.5).
- The **done check** is the catalog's text in Appendix A.

### Phase 1: MVP

#### D1 · 001-d01-foundation

**Goal:** all four codebases exist, deploy through CI, and talk to one frozen `/v1` contract backed by the real snapshot.
**Starts from:** Day 0 done (accounts, VPSs, constitution). `schema.sql` and the snapshot available in `../old_app/migration/`.
**Contract:** Alembic `0001` (`schema.sql` as-is, which already has `sources`, `media_assets`, the external-id tables, channel `kind`/`access`/`provider`/`package`/`beam`, satellite `slug`/`orbital_position` and `name_norm`) + `0002` with the remaining MVP additions from SD §6.2.1: match status columns, `time_tbd`, `locked_fields`; `channels.locked_fields/frequency_changed_at`; `pg_trgm` indexes; `admin_users`, `admin_refresh_tokens`, `audit_log`; `devices`, `device_follows`, `notification_outbox`; `import_runs` columns; `dataset_versions`. Read endpoints of SD §6.3.2: matches, match detail, live, satellites, satellite channels, channel, competitions, teams, rights holders, commentators. **Tagged `v1` at 13:00.**

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a client developer, I can call `/v1` and get real Sat Air data in the documented envelope and shapes | SD §6.1–6.3, §6.9 (rehosting), §10 steps 1–3; `../old_app/migration/README.md` | `load_snapshot.py` loads the snapshot with every README rule (frequency regex, NULL placeholders, Cairo → UTC, channel kinds, dedupe, external ids, orphans logged, no card-sharing labels); media rehosted into `media_assets` and served from `media.<ip1>.sslip.io`; contract tests pass for every read endpoint; ETag + `304` works; deployed on VPS-1 |
| B2 | As the owner, I can push to `main` and have each folder built, checked and deployed without touching a server | SD §7.1–7.2, §8 (ports, headers), §9 | `vps1.yml` and `vps2.yml` Compose files; Caddy with Let's Encrypt for `api.`, `media.`, `app.` and `tls internal` on `wg0`; WireGuard hub with peers for you and CI; iptables persisted; `backend.yml` builds `linux/arm64`, pushes to GHCR, deploys with health check and rollback; `app.yml` builds a debug APK artifact; `pwa.yml` deploys to a Firebase preview channel; gitleaks on every PR |
| A | As an editor, I see the admin shell and log-in screen in the Madar look, wired to a generated client | PB §10 A0, A1; SD §5.4; admin: Login · error + lockout, Admin components · all states | Vite + TS strict + Tailwind reading `tokens.css`; Orval client + Zod from the `v1` admin spec served by Prism; `SidebarNav`, `DataTable`, `Field`, `StatusChip`, `Toast` built with Vitest tests; A1 renders error and lockout states against the mock |
| M | As a user, I open the app and see today's real matches, in a shell built only from Madar tokens and components | SD §5.1; PB §13; app: Brand, color & type, Components · Matches/Channels/Core, S2 Matches | Flavors dev/staging/prod; go_router routes of PB §8.4 stubbed; Riverpod; drift schema for matches; Dio + generated Retrofit client; `madar_tokens.dart` + bundled fonts; `MatchRow`, `StatusBlock`, `FrequencyReadout`, `CarriageRow`, `AccessBadge`, `DateStrip`, `MadarBottomNav`, `MadarTopBar`, `EmptyState`, `Skeleton` with goldens (RTL, both themes, 1.3×); a gallery route; `/v1/matches` renders unstyled rows |

**Flags:** none yet (the app isn't public).
**Done check:** 001 in Appendix A.

#### D2 · 002-d02-core-flows

**Goal:** an editor's change reaches the phone, fixtures arrive without anyone clicking, and the four core screens work on real data.
**Starts from:** 001. Contract `v1` frozen.
**Contract:** admin app `/admin/api` (SD §6.4 CRUD for matches, teams, competitions, satellites, channels, commentators; media upload; `If-Match`; audit writes; `locked_fields`); auth endpoints (SD §6.5); `status_source = manual` override. No public changes.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As an editor, I log in and edit any MVP entity safely, and my edit is live within 60 s | SD §6.2.3, §6.4, §6.5, §6.9 uploads, §8 | argon2id; CLI creates the first admin; 15-min JWT + rotating refresh cookie + CSRF header; 5 attempts / 15 min lockout; roles in a dependency; every mutation writes `audit_log`, bumps `dataset_versions`, adds `locked_fields`, rejects a stale `If-Match` with `409`; clock estimate (`estimated: true`) and manual override in `/v1/live`; upload checks magic bytes, re-encodes to WebP / AAC |
| B2 | As the owner, I get tomorrow's fixtures without opening a browser, even if ysscores blocks Oracle | SD §6.6 (contract, pipeline, safety), §7.2 home box; `../old_app/public/IMPORT.html` | `SourceAdapter` base with rate limit, host allowlist, size cap, raw page saved gzipped; `ysscores` adapter with `parse` tested on saved pages; upsert by `(source, external_id)`, never touching `locked_fields`; entity resolution v0 (exact alias + competition similarity); `import_runs` rows; Firestore bridge task (read-only export → same upsert) as fallback; `worker-scrape` runs on the home box over WireGuard |
| A | As an editor, I fix the day's matches and their channels in one screen | PB §10 A3, A4; admin: A3 Matches, A4 Match editor, Conflict / typed confirm / unsaved guard / toasts | A3 day tabs, filters, grouped rows, bulk change competition / remove channels; A4 team picker with disambiguation, kickoff shown in admin zone, stage presets, status override + score, two manual broadcaster slots, channel picker with satellite and category filters, per-channel commentators 1 and 2, "hide from this match" and "hide always"; unsaved guard; conflict dialog on `409` |
| M | As a fan, I find where today's match is on and which frequency to tune, on a real phone | PB S2, S3, S4, S5; SD §5.1 data flow; app: S2 Matches (+ Light, Loading), S3 Before kickoff, S3 130 channels, S3 No channels, S4, S5.1, S5.2 | S2 date strip, chips, competition groups, channel line, every `StatusBlock` variant, local-day grouping (P2); S3 hero, "where to watch" in three parts, virtualized long lists, commentator voice clip, stadium and Egyptian broadcaster cards; S4 multi-satellite list; S5.1 and S5.2 with the readout always visible; stale-while-revalidate from drift. **First AAB to the Play closed track; PWA on a preview channel** |

**Flags:** none (closed testers only).
**Done check:** 002 in Appendix A.

#### D3 · 003-d03-follow-push-sources

**Goal:** a fan follows a team and gets a reminder with the channel; channels arrive by themselves; every MVP entity is editable.
**Starts from:** 002.
**Contract:** `POST /v1/devices`, `PUT /v1/devices/me`, `PUT /v1/devices/me/follows`, `DELETE /v1/devices/me` (SD §6.3.2); outbox + dispatcher; Redis response cache keyed by dataset versions.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan who follows a team, I get exactly one reminder before its match, naming the channel | SD §6.3.2 devices, §6.8; PB §11 kickoff reminder | Device token (256 bits, stored hashed, `Authorization: Device`); follow set replaced atomically; reminder scheduler writes outbox rows with `dedupe_key`; dispatcher claims with `SKIP LOCKED`, resolves the audience with one `SELECT DISTINCT`, sends through FCM in batches of 500, deletes `UNREGISTERED` tokens; collapsing tag `match_<id>`; audience query reviewed by you; Redis cache + version keys; rate limits per device / IP |
| B2 | As the owner, I trust the data pipeline to run and to tell me when it breaks | SD §6.6 LiveSoccerTV + safety, §7.3, §7.4; `../old_app/public/LVS.html` | `livesoccertv` adapter using `livesoccertv_teams`, every 2 h for 48 h and again at T−60; writes `match_channels` with `source`; per-source circuit breaker and zero-items alarm to Telegram; nightly `pg_dump` → restic → B2 and media → OCI bucket; Uptime Kuma checks API, media, both PWA origins, Celery and backup heartbeats |
| A | As an editor, I can maintain every MVP entity and see at a glance what today is missing | PB §10 A2, A5–A8, A10, A13; admin: A2 Dashboard, A5 Teams, A6 Competitions, A7 Satellites, A8 Channels, A10 Commentators, A13 Sources | A5 table + editor (no merge yet); A6 drag priority; A7 drag order + best / worst frequency + video; A8 filters + editor drawer + "add on another satellite"; A10 photo and audio upload with player; A13 cards: status, last success, items, breaker, "run now", pause / resume; A2 basic: matches without channels, source tiles, recent changes |
| M | As a new user, I set up my teams and dish once and start getting reminders | PB S0, S1, S9, S15 (core), S16, §7 push permission; SD §5.1 Remote Config, §5.2 iOS limits; app: Splash, S1.1–S1.5, S9, S15, S16, S0 boards, Push catalog | Onboarding with skip and resume; device registration on first launch; follows mirrored to the server (P1); FCM token on Android and on web (minimal `firebase-messaging-sw.js` for now); iOS install guide when not installed; S9 favorites; S15 time zone, 12/24 h, theme, font scale, satellites; S16 More; S0 forced update, no connection, load failed, offline banner, exit snackbar; Remote Config fetch with bundled defaults; Crashlytics on Android. **Test push on a real iPhone (iOS ≥ 16.4) today** |

**Flags:** none.
**Done check:** 003 in Appendix A.

#### D4 · 004-d04-mvp-launch

**Goal:** pass the MVP gate and make the PWA public. Hardening only: no new features.
**Starts from:** 001–003, carry-over first.
**Contract:** none, unless a fix needs one (B1 decides; non-breaking only).

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As the owner, I know the API holds the launch load and has no critical security hole | SD §8, §11 | Load test of `/v1/live` and `/v1/matches` at the MVP target (report in `docs/`); `/security-review` run; CRITICAL and HIGH fixed |
| B2 | As the owner, imports have run unattended since D2 and I have a first runbook | SD §6.6, §7 | Two days of `import_runs` without manual help; parser fixes for saved edge pages; `docs/runbook.md` v0: deploy, rollback, restart a source, read Kuma alerts |
| A | As an editor, the admin works end to end on the real WireGuard host | SD §5.4, §7.2 | Admin served on `https://10.8.0.1`; Playwright smoke: log in → edit a match → change visible in `/v1`; polish list from your D3 review closed |
| M | As a fan, I can install the public PWA and the Android test build without hitting a crash | PB §17 launch gate; SD §5.2 | Bug-bash script run on Android + iPhone PWA + desktop; release builds; PWA deployed to the live Firebase channel; first load < 5 s on 4G, < 1.5 s afterwards; install guide reachable from More |

**Flags:** none.
**Done check:** 004 in Appendix A. **Decide O7 today** (§9).

### Phase 2: V1

#### D5 · 005-d05-live-and-discovery

**Goal:** real live scores replace the clock estimate, and a fan can open a channel, a team and a competition.
**Starts from:** MVP public; O7 decided (if not, B1 does manual live entry instead of the poller).
**Contract:** `0003`: `match_events`, `match_lineups`, alias tables (`team_aliases`, `competition_aliases`, `channel_aliases`), `unresolved_names`. `MatchDetail.events/lineups`; `GET /v1/channels/{id}`, `/v1/teams/{id}`, `/v1/competitions/{id}` complete. Admin: unresolved-names queue endpoints, rights-holder CRUD.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, the score and minute I see come from a real feed, never from a guess | SD §6.2.3, §6.7 | `live_scheduler` every 60 s, no polling on quiet days; `poll_live` updates status, minute, score and diffs events, each write bumping the `live` version; manual status still wins; `/v1/live` rebuilt at most every 15 s |
| B2 | As an editor, names the importers can't match wait in a queue instead of creating duplicates | SD §6.6 entity resolution, YallaKora row | `yallakora` adapter daily + every 6 h for today, with the Egyptian broadcaster; unmatched names written to `unresolved_names` with match context; existing aliases used first |
| A | As an editor, I clear unmatched names and maintain broadcast rights | PB §10 A9, A13; admin: A13 Sources + unresolved names, A13 Run detail, A9 Rights holders | Unresolved queue: map to existing, create new, ignore; run detail with log, counts, errors and raw page; A9 editor with competitions, carriages and a primary frequency |
| M | As a fan, I open a channel, a team or a competition and see what's on | PB S6, S7, S8; app: S6 Channel sheet, S7 Team, S8 Competition | S6 as a sheet (pane later on desktop) with other carriages, upcoming matches, frequency history; S7 upcoming / results tabs and follow; S8 matches by date and rights section; all reachable from S2 / S3 taps |

**Flags:** `live_center` stays off until D6's UI lands.
**Done check:** 005 in Appendix A.

#### D6 · 006-d06-notifications-and-live-center

**Goal:** every push type works and a live match has a timeline.
**Starts from:** 005.
**Contract:** `0004`: `channel_frequency_changes`; notification prefs in `devices.prefs`; outbox producers for all SD §6.8 types. Admin: outbox log, composer, test send, admin users, audit log + diff endpoints.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a follower, I get each kind of alert I asked for, once, with the right copy | SD §6.8 table; PB §11 | Producers for `match_started`, `goal`, `final_score`, `channels_updated`, `frequency_changed`, `announcement`; per-type prefs filter the audience; frequency-change detection on import and admin save writes history; bidi-safe copy templates with tests |
| B2 | As the owner, other sports and fill-in fixtures arrive without hitting free-tier limits | SD §6.6 sporteventz and API-Football rows | `sporteventz` every 6 h writing `match_custom_broadcasts`; `apifootball` with a Redis daily request counter and a hard stop; both with saved-page tests |
| A | As an admin, I can see what was sent, send an announcement, and see who changed what | PB §10 A15, A16, A17; admin: A15 Notifications, A16 Admin users, A17 Audit log + diff | Outbox log; composer (admin role) with deep link picker, audience, schedule, test send, Android + iOS previews; users create / role / deactivate / reset; audit filters and side-by-side diff |
| M | As a fan watching a match, I see goals and cards as they happen | PB S3 live center; app: S3 Live match, S3 Live center — lineups | Events timeline (goal, own goal, penalty, missed penalty, red card); lineups tab only when data exists; score change highlight; estimated note when no feed; `live_center` flag on for testers |

**Flags:** `live_center`, `lineups`.
**Done check:** 006 in Appendix A.

#### D7 · 007-d07-sync-search-sources

**Goal:** the offline channel cache syncs by delta, search works across everything, and the old Firestore bridge is gone.
**Starts from:** 006.
**Contract:** `GET /v1/channels/sync`, `GET /v1/search`, `GET /v1/rights-holders*`, `sport` filter on `/v1/matches`. Admin: team / channel merge, lists (presets, hidden names), feeds CRUD.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, the app stays light: channels update by delta and search finds names however I spell them | SD §6.2.4, §6.3.2 sync + search | Cursor-based upserts + deleted IDs; `ar_normalize` tests (أ/إ/آ, ى, ة, tashkeel); trigram search across teams, competitions, channels, commentators, satellites; cache keys reviewed |
| B2 | As the owner, I run on my own pipeline only, and alerts reach the right place | SD §10 step 5 shadow run | 3 days of clean diffs, then the bridge task is disabled (or the reason is logged); alert routing per severity |
| A | As an editor, I can merge duplicates and maintain the lists the importers use | PB §10 A5 merge, A8, A11, A12; admin: A5 Teams + merge tool, A11 Lists, A12 Feeds | Merge: pick duplicates → survivor → preview affected matches → typed confirm; same for channels; A11 presets and hidden names; A12 feeds (if O8 keeps them) |
| M | As a fan, I search everything, browse rights, and switch sports | PB S11, S13, S14; app: S14 Search, S11.1–3 Broadcast rights, S11.4 Rights holder | Search with recent queries, grouped results and follow shortcuts; S11 by satellite / by competition / holder detail; sport switcher on S2 hidden when only football; drift channel table fed from `/v1/channels/sync` |

**Flags:** none new.
**Done check:** 007 in Appendix A. **Decide O8 today.**

#### D8 · 008-d08-preferences-and-ops

**Goal:** fans control every alert, the owner can switch maintenance and updates remotely, and a restore has been proven.
**Starts from:** 007.
**Contract:** announcement send path; preference shape finalized. Remote Config keys unchanged.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As an admin, an announcement reaches exactly the audience I chose | SD §6.8 announcement; §5.1 Remote Config | Audience "all" and "followers of X" with a dry-run count; maintenance and soft-update keys documented end to end |
| B2 | As the owner, I've seen a full restore work | SD §7.3 | Restore drill on a scratch container recorded in the runbook; `docs/runbook.md` v1 |
| A | As an editor, the bugs I reported this week are fixed | Admin bug queue | Queue from your notes closed or moved to D11 |
| M | As a fan, I choose exactly which alerts I get per team, competition, match and channel | PB S10, S12, S15, S0; app: S10 Follow sheet, S15 Settings, S12 Feeds, S0 Maintenance, S0 Offline / soft update | S10 sheet with lead time and per-type toggles plus platform-state footer; S15 competition order / hide and notification group; S12 (if kept); maintenance screen and soft-update banner from Remote Config |

**Flags:** none new.
**Done check:** 008 in Appendix A. **Decide O9 today.**

#### D9 · 009-d09-ads-and-desktop

**Goal:** Android earns with ads that never block the answer, and desktop web gets its two-pane layout.
**Starts from:** 008.
**Contract:** none.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As the owner, I know the API survives peak traffic | SD §11 scale assumption | Load test at 5k concurrent on `/v1/live`; Caddy cache-handler only if needed; report in `docs/` |
| B2 | As an iPhone user, the app still loads if Firebase Hosting runs out of quota | SD §5.2 | Content-hashed web build in CI; rsync to `app.<ip1>.sslip.io`; CORS for the `web.app` origins; cache headers in `firebase.json` and Caddyfile |
| A → M2 | As the owner, ads earn without breaking Google's interstitial policy | PB §5 revenue rules, §16; SD §5.1 `ads` key | `AdsService` (native) + web no-op; banner above the bottom nav that takes space only once loaded; interstitial on return from S3 only, ≥ 90 s apart, ≤ 4 per session, never in the first 60 s; UMP consent for EEA/UK |
| M | As a desktop user, I browse the list and details side by side, with the keyboard | PB §7, §8.3; app: Desktop ≥1024, Desktop frequencies + channel pane | Nav rail on the right, list ≈ 420 px + detail pane ≥ 1024; hover and visible focus on every interactive component; width capped ≈ 1200 |

**Flags:** `ads` (Remote Config `ads.enabled`).
**Done check:** 009 in Appendix A.

#### D10 · 010-d10-pwa-and-accessibility

**Goal:** the PWA survives either origin being down, shared links open the right place, and the app passes accessibility.
**Starts from:** 009.
**Contract:** none.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a developer, integration bugs found this week are fixed | — | Bug list closed or moved to D11 |
| B2 | As the owner, failover is tested, not hoped for | SD §5.2 failure modes | Automated test with Firebase blocked and with VPS-1 blocked; emergency install link prepared (unpublished) |
| A → M2 | As an iPhone user, one service worker handles caching, failover and push | SD §5.2 service worker; PB §5 growth loops | Custom SW with own cache → mirror → Firebase; FCM logic merged into it; share links `/match/<id>` open the PWA or the app; install-guide polish |
| M | As a user with large text or a screen reader, every screen still works | PB §13.3, §13.4, §13.8 | Every screen at 1.3× in-app scale; Arabic semantics labels for composite rows; bidi audit of readouts and scores; reduced motion honored |

**Flags:** none new.
**Done check:** 010 in Appendix A.

#### D11 · 011-d11-v1-hardening

**Goal:** bring all three codebases to the full quality bar. No features.
**Starts from:** 010, plus anything moved here by the quarter-day rule.
**Contract:** none.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As the owner, backend changes are safe to make | §7; constitution Quality Gates | Coverage ≥ 80 %; contract tests for every `/v1` and admin endpoint; `pip-audit` clean |
| B2 | As the owner, nothing secret or vulnerable ships and backups are real | SD §7.3, §8 | Secret scan of history; dependency audit; backup restore verified again |
| A | As the owner, the admin is covered by tests | §7 | Vitest ≥ 80 %; Playwright suite for A3, A4, A8, A13 |
| M | As the owner, the app is covered by tests | §7 | `flutter test` ≥ 80 %; `integration_test`: onboarding → matches → detail → copy frequency, follow → push received; goldens refreshed |

**Flags:** none.
**Done check:** 011 in Appendix A.

#### D12 · 012-d12-v1-release

**Goal:** pass the V1 gate and release.
**Starts from:** 011.
**Contract:** none.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, the release has no known blocking bug | — | Release fixes only |
| B2 | As the owner, production runs the release and monitoring covers it | SD §7.4 | Release deploy; Kuma and alert review |
| A → M2 | As the owner, the Android release build carries ads correctly | PB §5 | Production AAB with ads and UMP; AdMob app linked |
| M | As the owner, the store listing shows the real product | PB §5 ASO, §16, §17 | Screenshots from real screens; privacy policy, data safety, consent; PWA V1 released; Android production submitted when the Play gate clears |

**Flags:** turn on everything [V1]; remove MVP-era flags that launched in phase 1.
**Done check:** 012 in Appendix A.

### Phase 3: V2

#### D13 · 013-d13-finder-and-ios-pipeline

**Goal:** the satellite finder math is right, iOS can be built, and reports have an admin queue.
**Starts from:** V1 released; A7 (Apple account) checked.
**Contract:** `0005`: `reports` table; `POST /v1/reports` (draft); `GET /v1/commentators/{id}`; orbital positions verified for all 32 satellites. Admin: report queue endpoints.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, the finder and profiles have correct data behind them | SD §6.2.1 satellites, §6.3.2 commentators, reports | Positions checked against a reference list; commentator profile + upcoming matches; reports API accepting and listing |
| B2 | As the owner, iOS builds come out of CI signed | SD §9 `codemagic.yaml` | Codemagic workflow; signing; APNs key in Firebase. If A7 is false: domain move (O4) or cache tuning instead |
| A | As an editor, reports wait in a queue I can work through | PB §10 A14; admin: A14 Reports | Queue with kind, channel, match, age; detail with current carriage data; accept → channel editor pre-filled; reject |
| M | As a dish owner, the app tells me where to point my dish | PB S18; app: S18 Satellite finder | Satellite choice (mine first), location permission or city; azimuth (true + magnetic), elevation, LNB skew; unit tests against a reference calculator for 3 cities |

**Flags:** `satellite_finder`, `reports`.
**Done check:** 013 in Appendix A.

#### D14 · 014-d14-widget-and-reports

**Goal:** a report flows from fan to editor and back, and Android gets a home widget.
**Starts from:** 013.
**Contract:** `POST /v1/reports` final with rate limit; "report resolved" outbox type; widget summary endpoint if needed.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan who reported a problem, I hear back when it's fixed | SD §6.8; PB S19 | Rate limits per device; note ≤ 280 chars; resolved push to the reporter |
| B2 | As the owner, the domain move (if bought) or cache tuning is done | O4 | Hosts switched in Remote Config with both names live, or Caddy cache tuned |
| A → M2 | As a fan, my next followed match is on my home screen | PB S20; app: S20 Widgets | `HomeWidgetUpdater` (native) + web no-op; small and medium widgets |
| M | As a dish owner, the compass guides me to the satellite | PB S18 | Compass dial with target needle; calibration hint; camera overlay native only |

**Flags:** `satellite_finder`, `reports`, `home_widget`.
**Done check:** 014 in Appendix A.

#### D15 · 015-d15-commentators-and-live-notification

**Goal:** fans follow commentators, see a live notification during a followed match, and can reach official viewing links.
**Starts from:** 014.
**Contract:** commentator as a follow target type; `viewing_links` on rights holders and matches (`0006`); ongoing-notification data messages.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, I'm alerted when my commentator has a match, and I can find a legal stream | PB §5 official-viewing links, S17 | Commentator-follow push; viewing-link field and API |
| B2 | As the owner, logs and alerts are tuned for the new load | SD §7.4 | Alert dashboards; log retention reviewed |
| A → M2 | As a fan, a followed live match stays in my notification shade | PB S20 | Android ongoing notification fed by FCM data messages, updated on goal and status |
| M | As a fan, I open a commentator's profile and follow them | PB S17; app: S17 Commentator | Photo, name, clip, follow, upcoming matches with channel |

**Flags:** `commentators`, `ongoing_live`.
**Done check:** 015 in Appendix A.

#### D16 · 016-d16-totp-reports-links

**Goal:** admins use a second factor, and fans see report and viewing-link entry points.
**Starts from:** 015.
**Contract:** TOTP enrol / verify on the admin API.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As an admin, my account needs a second factor | SD §6.5 | TOTP enrol, verify, recovery codes; required for the `admin` role |
| B2 | As the owner, testers can install the iOS app | — | TestFlight internal build (if A7) |
| A | As an editor, I set up TOTP and enter viewing links | PB §10 A1 TOTP step, A9 | TOTP step in A1 and enrol screen; viewing-link fields in A9; commentator admin tweaks |
| M | As a fan, I report a broken channel and open legal streams | PB S19, S3, S11.4; app: S19 Report a problem | Report sheet with kinds, note and thank-you state; viewing-link buttons in S3 and S11.4 |

**Flags:** `reports`, `viewing_links`.
**Done check:** 016 in Appendix A.

#### D17 · 017-d17-ios-native-1

**Goal:** the native iOS app gets push and local reminders.
**Starts from:** 016; A7 true (otherwise swap in D21's work and move this brief after D30).
**Contract:** APNs payload details through FCM (no new endpoints).

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As an iPhone user, pushes look right and collapse per match | SD §6.8 | APNs headers, `thread-id` per match, badge rules |
| B2 | As the owner, iOS releases build from a tag | SD §9 | Codemagic release workflow; App Store Connect API key |
| A → M2 | As an iPhone user, I grant permission at the right moment and get reminders | PB S1.4, §7; SD §5.3 | iOS permission flow matching the priming design; `LocalNotifier` native implementation |
| M | As the owner, V2 issues from D13–D16 are closed | — | Polish and fixes |

**Flags:** none new.
**Done check:** 017 in Appendix A.

#### D18 · 018-d18-ios-native-2

**Goal:** iOS gets its widget and passes QA.
**Starts from:** 017.
**Contract:** none.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, the release is fast and stable | — | Bug fixes, performance |
| B2 | As the owner, open bugs are fixed | — | Bug fixes |
| A → M2 | As an iPhone user, my next match is on my home screen | PB S20 | WidgetKit widget; Live Activity as a stretch goal |
| M | As an iPhone user, every screen fits the device | PB §13.7 | Safe areas, gestures and layout checked on a device; iOS QA list closed |

**Flags:** none new.
**Done check:** 018 in Appendix A.

#### D19 · 019-d19-v2-hardening

**Goal:** V2 code meets the quality bar and the iOS beta is public.
**Starts from:** 018.
**Contract:** none.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As the owner, V2 backend code is covered | §7 | ≥ 80 % on new code |
| B2 | As the owner, external testers have the iOS beta | — | TestFlight external beta |
| A | As the owner, the App Store listing is ready | PB §16 | App Store assets, privacy labels |
| M | As the owner, finder and report flows are tested end to end | §7 | `integration_test` for finder and report |

**Flags:** none.
**Done check:** 019 in Appendix A.

#### D20 · 020-d20-v2-release

**Goal:** pass the V2 gate.
**Starts from:** 019.
**Contract:** none.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, the release has no known blocking bug | — | Release fixes |
| B2 | As the owner, production runs V2 | SD §7.4 | Release deploy; monitoring |
| A | As the owner, iOS is in review | PB §16 guideline 4.2 | Submitted to App Review |
| M | As a fan on Android or the PWA, I have V2 | — | Android + PWA released with V2 flags on |

**Flags:** turn on V2; remove V1 flags.
**Done check:** 020 in Appendix A. V3 designs and the accounts provider decided (§9).

### Phase 4: V3

#### D21 · 021-d21-accounts

**Goal:** a fan can sign in and keep their follows across devices.
**Starts from:** V2 released; V3 designs ready (§3); accounts provider decided.
**Contract:** `0007`: `users`, `devices.user_id`; Firebase ID-token verification; follows merge on sign-in; admin user lookup.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, signing in keeps everything I set up anonymously | SD §8 privacy | ID-token verification on the server; device → user link; follows merged without duplicates; tests for the merge |
| B2 | As a fan, team and competition names exist in English | — | `name_en` columns; fill from LiveSoccerTV and API-Football |
| A | As an editor, I can find an app user for support | V3 design board | App users lookup |
| M | As a fan, I sign in with Google, Apple or an email link | V3 design board | Sign-in and profile screens; optional at every step |

**Flags:** `accounts`.
**Done check:** 021 in Appendix A.

#### D22 · 022-d22-account-deletion-and-names

**Goal:** account deletion meets store rules, and English names reach the prioritized competitions.
**Starts from:** 021.
**Contract:** `DELETE /v1/me` + a public web deletion page.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, I can delete my account in the app or on the web | PB §16 privacy | In-app deletion and web deletion URL; data removed; audit entry |
| B2 | As the owner, I know how far English names cover | — | `name_en` backfill; coverage report |
| A | As an editor, I can enter and fix English names | — | `name_en` fields on teams, competitions, channels |
| M | As a fan, I delete my account and my anonymous data links correctly | V3 design board | Delete-account flow; anonymous data linking; settings integration |

**Flags:** `accounts`.
**Done check:** 022 in Appendix A.

#### D23 · 023-d23-predictions

**Goal:** a signed-in fan predicts a score before kickoff and gets it scored at full time.
**Starts from:** 022.
**Contract:** `0008`: `predictions`; create / update before kickoff, read mine; settlement task.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, my prediction locks at kickoff and is scored fairly | — | Lock at `kickoff_at`; settlement on `finished` only; scoring rules unit-tested, including postponed and abandoned |
| B2 | As the owner, the new tables are backed up and Redis has room | SD §7.1, §7.3 | Backups include them; Redis memory checked |
| A | As an editor, I can hide abusive display names | — | Display-name moderation |
| M | As a fan, I enter a prediction on the match page | V3 design board | Prediction input on S3 before kickoff; my predictions list |

**Flags:** `predictions`.
**Done check:** 023 in Appendix A.

#### D24 · 024-d24-leaderboards

**Goal:** leaderboards rank fans correctly.
**Starts from:** 023.
**Contract:** leaderboard endpoints (weekly, season, per competition).

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, I see my rank this week, this season and per competition | — | Redis sorted sets rebuilt from `predictions`; API with my rank; tests on a fixture dataset |
| B2 | As the owner, leaderboards hold under load | — | Load test report |
| A | As an editor, I can override a wrong settlement | — | Predictions admin view with settlement override (audited) |
| M | As a fan, I browse leaderboards | V3 design board | Leaderboard screens |

**Flags:** `predictions`.
**Done check:** 024 in Appendix A.

#### D25 · 025-d25-prediction-results

**Goal:** fans hear their results, and abuse is capped.
**Starts from:** 024.
**Contract:** `prediction_result` outbox type; abuse limits.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a fan, I'm told how my prediction did | SD §6.8 | Results push with dedupe; limits per device and account |
| B2 | As the owner, open bugs are fixed | — | Bug fixes |
| A | As an editor, my bug queue is clear | — | Bug queue |
| M | As a fan, I see results and points clearly | V3 design board | Results UI; prediction polish |

**Flags:** `predictions`.
**Done check:** 025 in Appendix A.

#### D26 · 026-d26-share-cards-calendar

**Goal:** fans share a match card into WhatsApp and Telegram, and add matches to their calendar.
**Starts from:** 025.
**Contract:** optional Open Graph share page `/s/m/:id`.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As someone who receives a shared link, I see a proper preview | PB §5 growth loops | Share page with OG tags on VPS-1 (optional) |
| B2 | As the owner, share pages are served safely | SD §8 headers | Caddy route for share pages |
| A | As an editor, my bug queue is clear | — | Bug queue |
| M | As a fan, I share a match card and add the match to my calendar | PB §5; V3 design board | Card rendered from a `RepaintBoundary` to PNG → share sheet; add to calendar on native; ICS on web |

**Flags:** `share_card`, `calendar`.
**Done check:** 026 in Appendix A.

#### D27 · 027-d27-ad-free-purchase

**Goal:** a fan can pay once to remove ads.
**Starts from:** 026.
**Contract:** `0009`: `entitlements`; purchase verification endpoint.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a buyer, my purchase is checked on the server and can't be faked | PB §5 ad-free upgrade | Google Play Developer API verification; entitlement stored per user or device |
| B2 | As the owner, the Play service-account key is handled safely | SD §8 secrets | Service-account secret on the host only (mode 600), never in CI logs |
| A | As an editor, I can look up an entitlement for support | — | Entitlement lookup |
| M | As a fan, I buy ad-free and restore it | V3 design board | Paywall, purchase flow, restore |

**Flags:** `ad_free`.
**Done check:** 027 in Appendix A.

#### D28 · 028-d28-entitlements-and-english-data

**Goal:** ad-free actually turns ads off everywhere, and English data is ready for the English UI.
**Starts from:** 027.
**Contract:** entitlement flag on the device / user response.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a buyer, I never see an ad again on that account | SD §5.1 `ads` | Remote Config condition + API flag |
| B2 | As the owner, English names cover the competitions that matter | — | `name_en` ≥ 90 % for prioritized competitions |
| A | As an editor, I can check English names before release | — | English names QA view |
| M | As a buyer, my entitlement survives reinstall; as a developer, strings are ready to translate | — | Entitlement handling and restore on reinstall; all strings extracted to ARB |

**Flags:** `ad_free`.
**Done check:** 028 in Appendix A.

#### D29 · 029-d29-english-ui

**Goal:** the app works fully in English, left to right.
**Starts from:** 028.
**Contract:** `lang` query parameter returns `name_en` with an Arabic fallback.

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As an English user, names come back in English where they exist | — | `lang` param; fallback tested |
| B2 | As the owner, open bugs are fixed | — | Bug fixes |
| A | As an editor, I see which names are still missing in English | — | Missing-translation report |
| M | As an English user, the whole app reads naturally LTR | PB §13.4 | ARB `en`; language switch in S15; LTR mirroring QA on every screen |

**Flags:** `english_ui`.
**Done check:** 029 in Appendix A.

#### D30 · 030-d30-sponsorship-v3-release

**Goal:** pass the V3 gate, with one sponsor slot.
**Starts from:** 029.
**Contract:** sponsor-slot endpoint (scheduled, labelled).

| Lane | Story | Read | Acceptance |
|---|---|---|---|
| B1 | As a sponsor, my slot shows only when scheduled and is clearly labelled | PB §5 sponsorship | Sponsor-slot API with schedule windows; release fixes |
| B2 | As the owner, production runs V3 | SD §7.4 | Release deploy |
| A | As an admin, I schedule a sponsor slot | — | Sponsor slots admin with scheduling and the «برعاية» label |
| M | As a fan, I see the sponsor slot on satellite pages and V3 is released | PB §5 | Sponsor slot on S5.2; V3 release on all platforms |

**Flags:** turn on V3; remove V2 flags.
**Done check:** 030 in Appendix A.
