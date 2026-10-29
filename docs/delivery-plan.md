# Madar Sat — Delivery Plan

| | |
|---|---|
| Status | Draft 2, 2026-10-29 |
| Scope | Everything from setup to V3: MVP, V1, V2, V3 |
| Inputs | [product-business.md](product-business.md) (what), [system-design.md](system-design.md) (how), [`madar-design/`](../madar-design/README.md) (look) |
| Builders | AI agents: Claude Code sessions planned and driven with Spec Kit. One human (you) orchestrates, reviews, tests on devices and owns the accounts |
| Unit of work | **One Spec Kit spec per working day.** Spec `0NN` is day `DNN`. All four lanes work from the same spec, each on its own section of tasks (§5) |

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
| A4 | The MVP uses a **reduced test bar**. D11 restores your 80 % coverage rule (§7) | If 80 % is required from day 1: the MVP takes about 6 days |
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
- **`SPECIFY_FEATURE` tells Spec Kit which spec is active**, because the lane branch names don't match the spec folder: start each lane session as `SPECIFY_FEATURE=0NN-dNN-<name> claude`.
- `main` is protected: PRs only, CI required, squash merge.

### 5.2 The daily loop

| When | Who | Steps |
|---|---|---|
| **Day N−1, afternoon** | Planning session in `madar_sat/` + you | 1. `git switch main && git pull` · 2. `/speckit.specify` with the template in Appendix A for day N, plus carry-over (§5.3) · 3. `/speckit.clarify` only if questions remain · 4. `/speckit.plan` · 5. `/speckit.tasks` · 6. `/speckit.analyze` · 7. You review the spec and the lane sections · 8. Merge a docs-only PR to `main` |
| **Day N, morning** | Each lane | `git fetch && git switch -C dNN-<lane> origin/main` → `SPECIFY_FEATURE=0NN-dNN-<name> claude` → `/speckit.implement Only the tasks under "Lane <X>" in tasks.md.` |
| **Day N, midday and evening** | Each lane → you | Reviewer agents run; the lane opens a PR; you merge it. **At least two merges per lane per day.** Lanes rebase on `main` after each merge to pick up the others' work |
| **Day N, evening** | You | Run the day's **done check** (Appendix A) on the deployed `main` and on devices. Anything that fails becomes carry-over |

**Required shape of every `tasks.md`**, which the template asks for:
- one section per lane (`## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M`), each written as an independently testable user story;
- a final section, `## Done check`, with that day's acceptance steps.

Lanes tick checkboxes only in their own section, so four PRs touching the same `tasks.md` never conflict.

Planning only one day ahead means each spec is written against the **real** state of `main`: the frozen API contract, what actually merged, and what slipped.

### 5.3 Carry-over

- When a day ends with unchecked tasks, the next day's `/speckit.specify` prompt starts with: *"Carry-over: the unchecked tasks in `specs/0NN-dNN-<name>/tasks.md` come first."*
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
2. Run `/speckit.constitution` with §8.1.
3. Extend the root `CLAUDE.md` and add one per lane (§8.2).
4. Change the design package's wordmark from «مدار» to **Madar Sat / مدار سات**.
5. **Plan spec 001** using the daily loop.

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

### 8.1 Constitution (paste into `/speckit.constitution`)

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
| A day spec mixes unrelated work and gets vague | Medium | Every lane section is a self-contained user story with its own acceptance steps; `/speckit.analyze` before merging the spec |
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

### Prompt template for `/speckit.specify`

```text
Day <N> of docs/delivery-plan.md (spec <0NN>-d<NN>-<name>).
[Carry-over: the unchecked tasks in specs/<previous spec>/tasks.md come first.]
Scope: the "D<N> · <0NN>" row of docs/delivery-plan.md §6, one user story per lane:
  Lane B1: <cell text>   Lane B2: <cell text>   Lane A: <cell text>   Lane M: <cell text>
Use the referenced sections of docs/product-business.md and docs/system-design.md, and for UI the boards
listed in madar-design/app-flutter/SCREENS.md or madar-design/admin-react/SCREENS.md.
tasks.md must have the sections "Lane B1", "Lane B2", "Lane A", "Lane M" and "Done check".
Done check for today: <done check from the table below>.
Follow the constitution.
```

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
