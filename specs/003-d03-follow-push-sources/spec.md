# Feature Specification: D3 · Follow, push and sources

**Feature Branch**: `003-d03-follow-push-sources` (lane branches `d03-b1`, `d03-b2`, `d03-a`, `d03-m`)

**Created**: 2026-11-01

**Status**: Draft

**Input**: User description: "Day 3 (D3) per docs/delivery-plan.md". Scope is exactly the brief "D3 · 003-d03-follow-push-sources" in `docs/delivery-plan.md` Appendix B; the done check is catalog row 003 in Appendix A.

| | |
| --- | --- |
| Goal | A fan follows a team and gets a reminder with the channel; channels arrive by themselves; every MVP entity is editable |
| Phase | MVP [P], milestone M1 (delivery-plan §1, §6 Phase 1) |
| Starts from | 002, merged to `master` (PR #12, plus fixes #13–#15). Its open code tasks (Lane A's A-F1 and A-F2) are carry-over and come first in Lane A (§5.3). Its open owner checks are under Assumptions |
| Contract | Public: `POST /v1/devices`, `PUT /v1/devices/me`, `PUT /v1/devices/me/follows`, `DELETE /v1/devices/me` (SD §6.3.2); rate limits on `/v1`. Internal: the outbox and its dispatcher; the Redis response cache keyed by dataset versions. Admin (non-breaking additions A2 and A13 need): source health and actions, the dashboard summary, and ordering competitions and satellites. Existing `/v1` read paths and shapes don't change |
| Flags | None |
| Implements | SD §5.1 (Remote Config, data flow), §5.2 (iOS limits), §6.3.1–6.3.2 (cache, devices), §6.6 (LiveSoccerTV, safety), §6.8, §7.3, §7.4, §8 (rate limits) · PB §7 (push permission), §9 S0, S1, S9, S15 (core), S16, §10 A2, A5–A8, A10, A13, §11 kickoff reminder · `../old_app/public/LVS.html` |

Shorthand: **SD** = `docs/system-design.md`, **PB** = `docs/product-business.md`, **D1 data model** = `specs/001-d01-foundation/data-model.md`, **app:** / **admin:** = a board in `madar-design/app-flutter/SCREENS.md` / `madar-design/admin-react/SCREENS.md`.

## Clarifications

### Session 2026-11-01

- Q: When LiveSoccerTV lists a channel name that matches no Madar channel, should the adapter create a placeholder channel for it, or only log it? → A: Create a hidden placeholder (name only, no satellite or frequency, not shown on match pages), link it, and list it in A8 and A2 for an editor to complete (FR-021, FR-031, FR-032).
- Q: LiveSoccerTV lists broadcasters for every country, so which countries' channels should the adapter import? → A: A configurable list, defaulting to the MENA countries (Egypt, Saudi Arabia, the other Arab League countries, and "Middle East / North Africa" entries). A channel already in Madar (so carried on a Madar satellite, such as a free-to-air channel on Nilesat, Badr or Hotbird) is linked whatever country lists it; only names from listed countries become placeholders (FR-020, FR-021).
- Q: Which channel should a kickoff reminder name: one on the user's own satellites, or one picked by the default order? → A: The user's own. The app sends its satellite ids with `PUT /v1/devices/me`, and each reminder names the best channel on that device's satellites (free first), falling back to the default order (Nilesat + Badr first, free first) when none of them carries the match or the device sent none (FR-003, FR-007, FR-008, FR-041).
- Q: Should B1 add the admin endpoints A2, A6, A7 and A13 need today, though the brief's contract lists only the device endpoints? → A: Yes, all of them: source health and actions, run history and detail, the A2 summary, one-call ordering of competitions and satellites, and the placeholder filter. They are admin-only and non-breaking, and merge with the regenerated admin client by 13:00 (FR-011, Assumptions).

## User Scenarios & Testing *(mandatory)*

Each story is one lane's work and maps to that lane's section of `tasks.md` (`## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M`). Stories are ordered by how much the other lanes depend on them.

### User Story 1 - Lane B1: a fan who follows a team gets exactly one reminder before its match, naming the channel (Priority: P1)

As a fan who follows a team, I get exactly one reminder before its match, naming the channel.

A device registers anonymously and receives a secret token. It tells the server its push token and settings, and replaces its follow set in one call. A scheduler turns upcoming matches of followed teams, competitions and matches into reminder rows in the outbox, each with a unique dedupe key. A dispatcher claims due rows, finds every device that should receive one with a single de-duplicating query, sends through FCM in batches, and drops tokens FCM reports as gone. The public API gets a response cache keyed by dataset versions, so a write is visible as soon as it commits, and rate limits that tolerate many users behind one carrier IP.

**Why this priority**: Lane M registers devices, mirrors follows and receives pushes through this contract, and the done check's first clause (a reminder on Android and on an installed iPhone PWA) runs through it.

**Independent Test**: Register a device, set its push token, and follow a team and that team's competition. Insert a match for the team with a kickoff 20 minutes ahead and a channel on Nilesat. Run the scheduler: one `kickoff_reminder` row exists for the match. Run it again: still one. Let the dispatcher run at kickoff − 15 min: the device receives one notification whose title and body follow PB §11 and name the channel, tagged `match_<id>`. Send a token FCM calls `UNREGISTERED` and see the device's push token cleared. Read `/v1/matches` twice and see the second served from the cache; edit the match in the admin and see the next read return the new data with a new `ETag`.

**Read**: SD §6.3.1–6.3.2 (cache, devices), §6.8, §8 (rate limiting); PB §11 (kickoff reminder copy, bidi rule), §13.4; D1 data model (`devices`, `device_follows`, `notification_outbox`, `dataset_versions`).

**Acceptance Scenarios**:

1. **Given** a first launch, **When** the app calls `POST /v1/devices` with its install id and platform, **Then** it gets a device id and a 256-bit random token, which the server stores only as a hash. A second call with the same install id issues a new token and invalidates the old one, so a reinstall never leaves two live devices.
2. **Given** a device token, **When** the app calls `/v1/devices/me*` with `Authorization: Device <token>`, **Then** the call is accepted. A missing, malformed or unknown token gets `401 unauthenticated`, and no other device's data is ever reachable.
3. **Given** `PUT /v1/devices/me` with a push token, app version, time zone, locale, my satellite ids and notification preferences, **When** it is valid, **Then** the device is updated and `last_seen_at` refreshed. A push token already held by another device moves to this one.
4. **Given** `PUT /v1/devices/me/follows` with a set of teams, competitions and matches, **When** it is valid, **Then** the device's follow set is replaced by exactly that set in one transaction. Unknown ids or more than the follow cap are refused, and nothing changes.
5. **Given** a match with a kickoff time and a device following its home team, its away team, its competition and the match itself, **When** the scheduler runs any number of times, **Then** there is one `kickoff_reminder` outbox row for the match, due at kickoff − 15 min, and the device receives it once.
6. **Given** a due reminder, **When** the dispatcher runs, **Then** it claims the row so that a second dispatcher can't, resolves the audience with one `SELECT DISTINCT` over the follows, sends in batches of at most 500, records `sent` and `failed`, and deletes push tokens reported as `UNREGISTERED`. The notification's title is «‹home› × ‹away› بعد 15 دقيقة», its body names the best channel and its satellite on that device's satellites, free first, falling back to the default order (PB §11), its tag is `match_<id>`, and it opens the match.
7. **Given** a kickoff that moves before its reminder is sent, **When** the scheduler runs, **Then** the pending reminder moves to the new time. A match whose time becomes "to be confirmed", or that is postponed or cancelled, has its pending reminder cancelled.
8. **Given** two identical public reads, **When** no dataset they depend on has changed, **Then** the second is served from the cache. **When** an admin edit or an import commits, **Then** the next read returns the new data and a new `ETag`, and a `304` is never given for the old copy.
9. **Given** many requests from one IP, **When** they exceed the per-IP limit, **Then** they get `429 rate_limited` with `Retry-After`. Requests carrying a device token are counted per device, and the per-IP limit is generous enough for a carrier NAT.

---

### User Story 2 - Lane M: a new user sets up their teams and dish once and starts getting reminders (Priority: P2)

As a new user, I set up my teams and dish once and start getting reminders.

On first launch the app shows a short onboarding: theme, teams, satellites and notifications, each step skippable and resumable. It registers the device, mirrors the follows to the server, and gets push working on Android and on the web; on an iPhone that hasn't installed the PWA, it shows the install guide first. Favorites lists what the user follows; Settings and More cover the core options; the system screens handle forced updates, no connection and failed loads; Remote Config supplies the hosts and switches, with bundled defaults.

**Why this priority**: The done check needs a reminder on a real Android phone and on an installed iPhone PWA, and onboarding → follow → favorites working end to end. iPhone push is the plan's riskiest item (delivery-plan §10), so it is tested on a real device today.

**Independent Test**: On a fresh Android install, go through S1.1–S1.4: pick dark, choose two teams, choose Nilesat and Hotbird, allow notifications. Open S9: both teams are there. Close the app in S1.2 on a second fresh install and reopen it: onboarding resumes at S1.2. Have B1 schedule a test match for a followed team: the reminder arrives and opens S3. In Safari on an iPhone (iOS ≥ 16.4), S1.4 shows the install guide; after «إضافة إلى الشاشة الرئيسية» and opening from the icon, allow notifications and receive a test push. Switch to airplane mode: the offline banner shows with the data's age. Raise `min_supported_build` in Remote Config: the forced-update screen appears.

**Read**: PB §7 (push permission row), §9 S0, S1, S9, S15, S16, §11, §13.8; SD §5.1 (Remote Config keys, data flow), §5.2 (iOS limits, `firebase-messaging-sw.js`), §5.3; app: Splash, S1.1–S1.5, S9 Favorites, S15 Settings, S16 More, S0 Offline cache / soft update / exit, S0 Forced update, S0 No connection, S0 Load failed, §11 Notification catalog.

**Acceptance Scenarios**:

1. **Given** a fresh install, **When** the app starts, **Then** the splash shows, then S1.1. Each step has progress dots, back and «تخطي». Quitting during onboarding and reopening resumes at the same step; finishing or skipping it never shows it again, and each step can be reopened from S15.
2. **Given** S1.1, **When** the user picks داكن, فاتح or تلقائي, **Then** the preview tiles and the whole app follow it at once, and the choice is kept.
3. **Given** S1.2, **When** the user searches «الاهلي» or «الأهلي», **Then** the same teams are found, grouped under their competitions with popular ones first, and chosen teams collect in the tray.
4. **Given** S1.3, **When** the user chooses satellites, **Then** S3, S4, S5 and the S2 channel line put them first from then on, and the app sends them to the server so reminders name a channel on them. Skipping keeps Nilesat + Badr and shows «حدد أقمارك».
5. **Given** S1.4 on Android 13 or later, **When** the user taps «تفعيل التنبيهات», **Then** the system dialog opens; on «ليس الآن», no dialog opens, and the step can be reopened from S15. **Given** Safari on an iPhone with the PWA not installed, **Then** S1.4 shows S1.5 instead, and S1.5 is reachable from S16.
6. **Given** the first launch online, **When** the app starts, **Then** it registers the device once and keeps the token in secure storage. Every change to follows sends the full set to the server; a failed send is retried on the next launch or reconnect, and the device's own set stays the source of truth (P1).
7. **Given** notifications allowed on Android, on the web, or in an installed iPhone PWA, **When** FCM issues or refreshes a token, **Then** the app sends it with `PUT /v1/devices/me`. A push received in the foreground or background opens its match on tap.
8. **Given** S9, **When** the user follows or unfollows a team or a match, **Then** S9 shows «مبارياتي القادمة» (the next 3) and the Teams section with a remove action; the change reaches the server. Competitions, channels and commentators get their S9 sections with their follow actions (S8 on D5, later days). With nothing followed, S9 shows its empty state with «أضف فرقاً».
9. **Given** S3 for a match with no channels, **Then** its next action is «تابع المباراة», which follows the match, as designed (it replaces D2's «تحديث»).
10. **Given** S15, **When** the user changes the time zone (automatic or GMT−12 … GMT+14), the 12 / 24 h format, the theme, the font size (1.0 / 1.15 / 1.3×) or my satellites, **Then** every screen follows. «حذف بيانات جهازي» deletes the device on the server after a confirmation, and the app starts fresh.
11. **Given** S16, **Then** it lists the rows of PB S16 that exist today (الإعدادات, شارك التطبيق, سياسة الخصوصية, تثبيت التطبيق on the iOS PWA only) and the about card with the version.
12. **Given** Remote Config, **When** it can't be fetched, **Then** the bundled defaults apply. **When** the build is below `min_supported_build`, **Then** the forced-update screen blocks the app. API and media hosts and `live_poll_interval_s` come from Remote Config, and images load only from the configured media host.
13. **Given** no connection and nothing cached, **Then** the no-connection screen shows with «إعادة المحاولة». A server error with nothing cached shows the load-failed screen. Offline with a cache shows the slim banner with the data's age. Back on a root tab on Android shows the exit snackbar.
14. **Given** a native Android crash, **Then** Crashlytics records it. The web build has no crash reporter.

---

### User Story 3 - Lane B2: the owner trusts the data pipeline to run and to say when it breaks (Priority: P3)

As the owner, I trust the data pipeline to run and to tell me when it breaks.

A LiveSoccerTV adapter, ported from Sat Air's `LVS.html`, finds the channels for upcoming matches and adds them as links from its own source. Every source gets a circuit breaker that pauses it after repeated failures, and a zero-items alarm, both alerting the owner on Telegram. The database is backed up every night, encrypted and off-site, and media is mirrored. Uptime Kuma watches the API, media, both PWA origins, the workers and the backups.

**Why this priority**: The done check needs LiveSoccerTV to add channels by itself and one nightly backup completed. Lane A's A13 shows the breaker state and pause flags this lane maintains.

**Independent Test**: Run the LiveSoccerTV `parse` tests on saved pages. Let beat run it: upcoming matches within 48 h of a followed team gain `livesoccertv` channel links, a second run adds none, and a link an editor removed stays hidden. Make the fetch fail N times in a row: the source pauses, its breaker shows open, and a Telegram alert arrives; resume it and it runs. Make a run find zero items: an alert arrives. The next morning, restic lists last night's database snapshot in Backblaze B2, and the OCI bucket holds the media. Stop a worker: Kuma alerts.

**Read**: SD §6.6 (LiveSoccerTV row, safety, cross-source duplicates), §7.3, §7.4; `../old_app/public/LVS.html`; `../old_app/migration/README.md` (channel normalization); `docs/runbooks/` (existing imports, home box and workers runbooks).

**Acceptance Scenarios**:

1. **Given** saved LiveSoccerTV pages, **When** `parse` runs, **Then** it is pure and its tests pass, yielding each match's teams, kickoff and channels by country, as `LVS.html` reads them.
2. **Given** a Madar match whose teams map through `livesoccertv_teams`, **When** the adapter runs, **Then** each listed channel that matches a Madar channel by normalized name (by country when the Madar channel has one, as `LVS.html` does) becomes a match–channel link with source `livesoccertv`, whatever country lists it. A name from a configured country (MENA by default) that matches no channel gets one hidden placeholder channel (name only, no satellite or frequency, not shown on match pages), linked the same way and reused by later runs; the app never shows it until an editor completes it. Matches it can't find are listed in the run's log. It never touches `manual` links or links of other sources, and removes only its own links when the source drops them.
3. **Given** beat, **Then** the adapter runs every 2 h for matches in the next 48 h, and again about 60 min before each kickoff, with the same lock, retry and `import_runs` rules as ysscores.
4. **Given** any source, **When** it fails N consecutive runs, **Then** its breaker opens, the source pauses, and the owner gets a Telegram alert naming it. While open, beat doesn't run it. An editor's resume (A13) closes the breaker and runs it again.
5. **Given** a run that parses zero items where the source normally has some, **Then** the run is recorded as such and the owner gets a zero-items alert, at most once per source per day.
6. **Given** 03:00 on VPS-2, **Then** a `pg_dump -Fc` is taken, encrypted by restic and stored in Backblaze B2 with 7 daily, 4 weekly and 6 monthly kept; media is copied to the OCI bucket nightly and into restic weekly. Each job reports a heartbeat, and a failure alerts.
7. **Given** Uptime Kuma on VPS-2, **Then** it checks API `/healthz` (database and Redis), media, both PWA origins, and push heartbeats from Celery and both backup jobs, and alerts by Telegram. Kuma is reachable only over `wg0`.
8. **Given** any new secret (Telegram bot token, restic password, Backblaze and OCI keys), **Then** it lives only in VPS-2's `.env` or GitHub Actions secrets, never in the repo.

---

### User Story 4 - Lane A: an editor maintains every MVP entity and sees at a glance what today is missing (Priority: P4)

As an editor, I can maintain every MVP entity and see at a glance what today is missing.

D2 built matches. Today adds the screens for teams, competitions, satellites, channels and commentators on the admin API D2 already serves, the sources page with health and controls, and a basic dashboard. Lane A first finishes D2's open follow-ups.

**Why this priority**: The done check needs every MVP admin entity editable. The screens use D2's entity endpoints, so most of the work can start in the morning; A2 and A13 wait for B1's admin additions.

**Independent Test**: Against the admin API over WireGuard: in A5, find a team, change its logo and alias, and see the change in the app. In A6, drag a competition up and see S2's group order change. In A7, reorder satellites and set Nilesat's best and worst frequency and reception video. In A8, filter to Nilesat sports channels, edit one in the drawer, then add the same channel on Badr. In A10, upload a commentator photo and a clip and play it. In A13, pause and resume ysscores and press «تشغيل الآن». A2 lists today's matches without channels and the source tiles.

**Read**: PB §10 A2, A5–A8, A10, A13, common admin states; SD §5.4, §6.4, §6.6 (safety); admin: A2 Dashboard, A5 Teams, A6 Competitions, A7 Satellites, A8 Channels + editor drawer, A10 Commentators, A13 Sources, A13 Run detail; the READMEs of the components these use in `madar-design/design-system/components/`.

**Acceptance Scenarios**:

1. **Given** D2's open Lane A tasks, **Then** A4's form resolves through the generated Zod schema with React Hook Form (A-F1), and A3's table runs on the shared `DataTable` (A-F2), with their existing tests green.
2. **Given** A5, **Then** the table has search and the competition and missing-logo filters. The editor covers name, aliases, logo upload with a preview on dark and light tiles, main and other competitions, stadium and external ids (read-only). There is no merge tool today.
3. **Given** A6, **When** an editor drags a competition to a new place, **Then** the new order is saved as one change, conflict-checked, and the app's competition order follows. The editor covers name, aliases and logo.
4. **Given** A7, **When** an editor drags a satellite, **Then** the order is saved as one change. The editor covers Arabic and English names, orbital position, best and worst frequency, reception video (`https` only) and logo.
5. **Given** A8, **Then** the table filters by satellite, category, access, missing logo, platform-only and shown on match pages. The drawer edits matching name, display name, logo, satellite, frequency (MHz, H/V/L/R, symbol rate) or a note, access, provider, package, category, country and shown on match pages. «إضافة على قمر آخر» creates a carriage of the same channel on another satellite, prefilled. A "placeholders to complete" filter lists the hidden channels LiveSoccerTV created, and completing one (satellite and frequency, or platform) and showing it on match pages makes it appear in the app.
6. **Given** A10, **Then** the table shows photo, name and a play button; an editor renames, replaces the photo or clip (upload, with the player), and deletes only after seeing the usage count, which refuses when in use.
7. **Given** A13, **Then** each source's card shows status, last success, items found, error rate and breaker state, with «تشغيل الآن» and «إيقاف» / «استئناف». The run history opens a run's counts, errors and log. The unresolved-names queue waits for D5.
8. **Given** A2, **Then** it shows today's matches without channels by competition priority, the count of placeholder channels to complete, the source health tiles, and recent changes, each linking to its screen.
9. **Given** any of these screens, **Then** they have the common admin states (skeletons, empty states, toasts, the unsaved guard, the `409` conflict dialog, typed confirmation for destructive actions), are built from the shared components with tokens only, RTL, with visible keyboard focus.

---

### Edge Cases

- **A device follows a team, its competition and the match.** One reminder, from one row, to one device (P1's `DISTINCT`).
- **Both teams of a match are followed by the same device.** Still one reminder.
- **A match is imported or created less than 15 min before kickoff.** The scheduler sends it right away if kickoff hasn't passed; a match whose kickoff has passed gets no reminder.
- **A kickoff moves after its reminder was sent.** No second reminder.
- **None of a device's satellites carries the match.** The reminder names the channel by the default order, so it still gives an answer; the device's own satellites win whenever one carries it.
- **A device changes its satellites after the reminder was queued.** The channel is chosen at send time, from the satellites the device last sent.
- **A match with no channel yet at reminder time.** The body reads «اضغط لعرض القنوات والترددات» without a channel name; nothing is invented.
- **A reminder fails for some tokens.** `sent` and `failed` count them; `UNREGISTERED` tokens are deleted; other errors are retried within the bounded count, and the row is never re-sent to devices that got it.
- **Two dispatchers or a retried task.** `SKIP LOCKED` and `dedupe_key` prevent a double send.
- **A device's token leaks.** Re-registering with the same install id rotates it; `DELETE /v1/devices/me` removes the device and its follows.
- **Follows sent while offline.** The app keeps its set and sends it when back online; the last full set wins.
- **A followed team or competition is deleted.** Its follows disappear with it; matches are never deleted.
- **An iPhone in Safari, not installed.** No permission prompt is shown (iOS refuses it); the install guide explains why.
- **Notification permission denied.** The app works without push, and S15 says how to enable it.
- **Remote Config returns a bad host or value.** Only `https` hosts are accepted; otherwise the bundled default stays.
- **The cache and a write race.** A read that started before a write may serve the old copy once; the next read sees the new version, because keys include the dataset versions.
- **LiveSoccerTV names a channel Madar doesn't have.** One hidden placeholder is created per normalized name and linked; it stays off every app screen until an editor gives it a satellite and frequency (or a platform) and shows it on match pages. A second run, or another match, reuses the same placeholder.
- **A channel name from an unlisted country (for example a US cable channel).** Skipped unless it already matches a Madar channel; no placeholder.
- **An editor deletes a placeholder.** It is soft-deleted, and its normalized name is not recreated by later runs.
- **LiveSoccerTV and an editor disagree.** An editor's removal keeps the link as a hidden `manual` link (D2 FR-008), so LiveSoccerTV doesn't bring it back.
- **LiveSoccerTV blocks Oracle IPs.** The fetch can run on the home box's scrape worker, as ysscores does.
- **The breaker opens at night.** The source stays paused until an editor resumes it; other sources keep running.
- **The backup target is unreachable or B2 nears 10 GB.** The job fails loudly with an alert; old snapshots are pruned by the retention rule.
- **Two editors reorder competitions at once.** The second save gets `409`, never a silent mix of orders.
- **«إضافة على قمر آخر» for a carriage already on that satellite.** Refused with a clear message.
- **A commentator in use is deleted.** Refused with the usage count (D2 FR-006).

## Requirements *(mandatory)*

### Functional Requirements

#### Devices, notifications, cache and limits (Lane B1)

- **FR-001**: `POST /v1/devices` MUST take an install id and platform (`android`, `ios`, `web`) and return a device id and a 256-bit random token generated by the server. Only the token's hash is stored. Registering an install id again replaces its token. The endpoint has its own stricter per-IP limit.
- **FR-002**: `/v1/devices/me*` MUST authenticate with `Authorization: Device <token>`, compared by hash in constant time, and answer `401 unauthenticated` otherwise. Responses are `no-store`.
- **FR-003**: `PUT /v1/devices/me` MUST validate and store the push token (≤ 4096 characters), app version, IANA time zone, locale, the device's satellite ids (existing satellites only, at most 32) and notification preferences (the SD §6.8 types with on/off and a lead time of 5, 15, 30 or 60 min). A push token held by another device moves to this one. The device stays the source of truth for my satellites; the server copy is used only to word its notifications.
- **FR-004**: `PUT /v1/devices/me/follows` MUST replace the device's follow set atomically with the given teams, competitions, matches, channels and commentators, refusing unknown ids and more than 500 follows with no change.
- **FR-005**: `DELETE /v1/devices/me` MUST delete the device and its follows.
- **FR-006**: The reminder scheduler MUST run on beat at least every 5 minutes and, for every match with a kickoff time in the next 24 h that has at least one follower, keep one `kickoff_reminder` outbox row with `dedupe_key = kickoff_reminder:<match_id>`, due at kickoff − 15 min. It moves a pending row when the kickoff moves, cancels it when the match becomes `time_tbd`, `postponed` or `cancelled`, and never creates a second row for a match. Per-device lead times are stored today and honoured from D8 (Assumptions).
- **FR-007**: The dispatcher MUST claim due `pending` rows with `FOR UPDATE SKIP LOCKED`, resolve the audience with one `SELECT DISTINCT` over `device_follows` (team, competition or match) for devices with a push token and the type not switched off, and send through FCM in batches of at most 500, each device's message worded for its satellites (FR-008). It records `sent`, `failed` and `sent_at`, deletes push tokens FCM reports as `UNREGISTERED`, retries other failures with bounded backoff, and never sends one row twice to a device.
- **FR-008**: A kickoff reminder MUST follow PB §11: title «‹home› × ‹away› بعد ‹N› دقيقة», body «على ‹channel› · ‹satellite› — اضغط لعرض القنوات والترددات», with the channel chosen among the match's visible links on the device's satellites (free first, then the S3 order); when none of them carries the match or the device sent no satellites, by the default order (Nilesat + Badr first, free first); and «اضغط لعرض القنوات والترددات» when the match has no visible channel. Names are bidi-isolated (PB §13.4). The tag is `match_<id>` and the data carries the deep link `/match/<id>`. Only `kickoff_reminder` has a producer today.
- **FR-009**: Public `GET` responses MUST be cached in Redis under a key built from the normalized path and query and the versions of the datasets they depend on, with the TTLs of SD §6.3.2. A bump makes the next read miss. `ETag`/`304` behaviour is unchanged, and device endpoints are never cached.
- **FR-010**: `/v1` MUST be rate-limited with Redis sliding windows: by device when the request carries the token of an existing device, otherwise by client IP (from `X-Forwarded-For` only through Caddy), with per-IP limits sized for carrier NAT. An unknown or made-up token counts against the IP, so rotating fake tokens can't escape the limit. Over the limit answers `429 rate_limited` with `Retry-After`.
- **FR-011**: The admin API MUST add, as non-breaking changes: the sources list with status, last success, items found, error rate, breaker state and paused flag; «تشغيل الآن» (queues one run, refused while one runs) and pause / resume (resume also closes the breaker and queues one run), all `editor`-role and audited; every change to a source's health (a run, a pause, a resume) changes the sources list's `ETag`, so A13 and A2 never show a stale state; a source's run history and run detail; the A2 summary (today's matches without channels by competition priority, the count of placeholder channels to complete, the source tiles, the latest audit entries); a channel-list filter for placeholders; and one-call ordering of competitions and of satellites, conflict-checked against each row's version, bumping the affected datasets.
- **FR-012**: The FCM service-account credentials MUST live only in VPS-2's (and, if needed, VPS-1's) host environment.

#### Pipelines, backups and monitoring (Lane B2)

- **FR-020**: The `livesoccertv` adapter MUST implement `SourceAdapter`, port the fetch and parse logic of `../old_app/public/LVS.html`, find matches through `livesoccertv_teams`, and have a pure `parse` tested on saved pages committed as fixtures. The countries it imports from MUST be a configurable list, defaulting to the MENA countries (Egypt, Saudi Arabia, the other Arab League countries, and "Middle East / North Africa" entries); changing it needs no release.
- **FR-021**: It MUST write match–channel links with source `livesoccertv` for channels that match an existing Madar channel by normalized name (and by country when the Madar channel has one), whatever country lists it. For a name from a listed country that matches none, it MUST create one hidden placeholder channel (name and source only, no satellite or frequency, not shown on match pages, audited with the source) and link it; later runs reuse it, and a soft-deleted placeholder is never recreated. It never changes `manual` or other sources' links, removes only its own links, and logs unmatched matches and the placeholders it created in the run.
- **FR-022**: Beat MUST run LiveSoccerTV every 2 h for matches in the next 48 h and once about 60 min before each kickoff, with the D2 lock, retry and `import_runs` rules, on a queue the home box's scrape worker can serve.
- **FR-023**: Every source MUST have a circuit breaker that opens after N consecutive failed runs (N set in config, default 3), pauses the source and alerts the owner on Telegram; while open or paused, beat skips the source. The state is kept where the admin API reads it (FR-011).
- **FR-024**: A run that parses zero items MUST raise a zero-items alert to Telegram, at most once per source per day.
- **FR-025**: Backups MUST run nightly at 03:00: `pg_dump -Fc` through restic to Backblaze B2 (retention 7 daily, 4 weekly, 6 monthly), media through rclone to the OCI bucket nightly and through restic weekly (4 weekly). Each job pushes a heartbeat to Kuma; a failure alerts.
- **FR-026**: Uptime Kuma MUST run on VPS-2, reachable only over `wg0`, and check API `/healthz`, media, both PWA origins, and push heartbeats from Celery beat/workers and both backup jobs, alerting by Telegram.
- **FR-027**: CI MUST deploy the new jobs and Kuma with the D2 deploy path, with no manual step on a server beyond the owner's one-time secrets and the Kuma monitors, which the owner creates once in Kuma's UI from its runbook (Kuma has no configuration file).

#### Admin (Lane A)

- **FR-030**: Lane A MUST close D2's A-F1 (React Hook Form with the Orval resolver in A4) and A-F2 (A3 on `DataTable`) before new screens, keeping their tests green.
- **FR-031**: A5, A6, A7, A8 and A10 MUST implement the parts of PB §10 the D3 brief lists (acceptance 2–6 of User Story 4) on the D2 admin endpoints, with uploads through the D2 media endpoint.
- **FR-032**: A13 MUST show each source's card and actions and its run history and run detail (FR-011). A2 MUST show the basic dashboard (FR-011). Both refresh while open.
- **FR-033**: The client and Zod schemas MUST be regenerated by Orval from B1's updated admin spec, never edited by hand. Zod validates every response, React Query fetches all data, forms use React Hook Form + Zod, and `error.code` maps to Arabic copy.
- **FR-034**: New shared components (for example a drag-sortable list or an audio player) MUST be built once under their `components/INDEX.md` names, with tokens only, RTL, visible focus and a Vitest test per README state.

#### App (Lane M)

- **FR-040**: Onboarding MUST implement S1.1–S1.5 with progress dots, back and skip, resuming at the last step after a restart, never shown again once finished or skipped, and each step reopenable from S15.
- **FR-041**: The app MUST register the device on first launch, keep the token in secure storage, send it on every `/v1` request (so rate limits count per device), mirror the full follow set on every change with retry, send the FCM token, settings and my satellite ids on change, and delete the device from S15.
- **FR-042**: Push MUST work on Android and on the web, with a minimal `firebase-messaging-sw.js` at the origin root; tapping a notification opens its route. On iOS Safari without installation, the app shows S1.5 instead of asking for permission.
- **FR-043**: S9 MUST show «مبارياتي القادمة» (next 3), the Teams section with remove, the add button and the empty state. The Competitions, Channels and Commentators sections stay hidden until a screen offers their follow action (S8 on D5, later days), so S9 never shows a section nobody can fill. Follow toggles exist in S1.2 and S9 (teams) and S3 (the match). The server accepts every follow kind today (FR-004).
- **FR-044**: S15 (core) MUST cover time zone, 12/24 h, theme, font scale, my satellites, reopening onboarding steps, «حذف بيانات جهازي» and the version. S16 MUST list the rows that exist today and the about card.
- **FR-045**: S0 MUST implement splash, forced update, no connection, load failed, the offline banner and the Android exit snackbar.
- **FR-046**: Remote Config MUST be fetched on start with bundled defaults for every SD §5.1 key, accepting only `https` hosts; the API, media hosts and `live_poll_interval_s` come from it, and every network image goes through one helper pinned to the media host.
- **FR-047**: My satellites MUST be chosen in S1.3 and S15 and stored on the device, replacing D2's fixed default once chosen.
- **FR-048**: Crashlytics MUST be enabled on Android only, behind the `CrashReporter` adapter with a web no-op.
- **FR-049**: New components MUST be built once under their INDEX names with every README state and goldens in RTL, both themes, at 1.0× and 1.3×; tokens only; Western digits; LTR islands for Latin names and frequencies.

#### All lanes

- **FR-050**: `tasks.md` MUST have the sections `## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M` and `## Done check`. The Done check is copied word for word from Appendix A, row 003.
- **FR-051**: Each lane MUST change only its own folders and tick only its own section. Only B1 changes the OpenAPI specs and Alembic; the PR that changes a spec regenerates both clients unedited. Generated files are never edited by hand.
- **FR-052**: No secret MUST be committed: FCM service-account key, Telegram token, restic password, Backblaze and OCI keys, Firebase server credentials.
- **FR-053**: Tests MUST be written and seen failing first for: device auth and token rotation; atomic follow replacement; reminder scheduling, moving and cancelling; dedupe and `DISTINCT` audiences; dispatcher batching and `UNREGISTERED` cleanup; reminder copy; cache invalidation by version; rate limits; LiveSoccerTV `parse` and channel matching; breaker and zero-items logic; reorder conflicts; onboarding resume; follow mirroring with retry; Remote Config defaults and host validation.
- **FR-054**: Coverage MUST meet the MVP bar (delivery-plan §7, constitution): backend ≥ 70 % on `domain/`, `adapters/` and `services/` with contract tests on `/v1` and `/admin/api`; admin Zod schemas and component-state tests with flow tests against a mocked API; app unit tests for repositories and formatters and goldens for new components.
- **FR-055**: Every new operated part MUST get or update its runbook in the same change and be listed in `docs/runbooks/README.md`: push and FCM credentials, the dispatcher and the cache (B1); LiveSoccerTV, source alerts, backups and Uptime Kuma (B2); Remote Config and push setup on Android, web and iPhone (M). Each lane adds its D3 items to `docs/owner-actions.md` when it finishes.

### Key Entities *(include if feature involves data)*

- **Device**: an anonymous install with a hashed token, platform, push token, app version, time zone, locale, a copy of its satellite ids (for wording notifications) and notification preferences.
- **Follow**: a device's interest in one team, competition, match, channel or commentator; the set is replaced as a whole.
- **Outbox row**: one notification to send, with a type, a unique dedupe key, a payload, an audience rule, a due time, a status and sent/failed counts.
- **Response cache entry**: a public response stored under its query and the dataset versions it depends on.
- **Source health**: per source, its paused flag, consecutive failures, breaker state and last success, beside its `import_runs`.
- **Backup snapshot**: a nightly encrypted database dump and the media copies, with their retention.
- **Remote Config**: the hosts, build gates, maintenance, feature flags and poll interval the app reads on start.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A kickoff reminder for a followed team arrives on a real Android phone and on an installed iPhone PWA (iOS ≥ 16.4), within 2 minutes of its due time, once each, naming the channel, in 3 out of 3 tries.
- **SC-002**: In tests, a device following a match through its team, its competition and the match itself receives exactly 1 reminder, and re-running the scheduler or dispatcher 5 times creates 0 extra sends.
- **SC-003**: After its first scheduled runs, LiveSoccerTV has added channel links to upcoming matches with none, and a second run adds 0 duplicates and re-adds 0 links an editor removed.
- **SC-004**: One nightly backup has completed and is listed in Backblaze B2, and a forced backup failure produces an alert within 15 minutes.
- **SC-005**: A deliberately broken source pauses itself after its configured failure count and an alert arrives within 15 minutes.
- **SC-006**: An editor can open and save every MVP entity (match, team, competition, satellite, channel, commentator) from the admin, and each save is visible in the app within 60 s.
- **SC-007**: A new user goes from first launch to a followed team shown in favorites in under 2 minutes, and can skip onboarding entirely in 1 tap.
- **SC-008**: Repeated public reads with no data change are served from the cache, and 100 % of reads after a write return the new data.
- **SC-009**: The day's **done check** passes, word for word from delivery-plan Appendix A: *"A kickoff reminder arrives on Android and on an installed iPhone PWA; LiveSoccerTV adds channels to upcoming matches; all MVP admin entities editable; one nightly backup completed; onboarding → follow → favorites works"*.

## Assumptions

- **002 is merged** (PR #12 and fixes #13–#15). Carry-over code work is Lane A's A-F1 and A-F2 (FR-030). The owner's D2 checks stay open in `docs/owner-actions.md` and don't block D3 code: B1's deploy check and first admin (T047), B2's host bring-up and first unattended run (T086, T087), Lane A's browser walk (T107 steps 2–4), and Lane M's `app-v0.2.0` tag, closed-track upload, phone walk and PWA preview (T135–T137). Lane M's T133 waits on `lean-ctx allow test_all_zones.sh`.
- **The admin additions are part of today's contract** (Clarifications). The brief lists only the device endpoints, but A2 and A13's acceptance ("run now", pause / resume, breaker, source tiles) and A6/A7's drag ordering can't be built without them. They are admin-only and non-breaking, so B1 adds them (FR-011) and merges the admin spec with the regenerated client by 13:00. `plan.md` records the reading of the brief.
- **One fixed lead time today.** Reminders go 15 min before kickoff (SD §6.8 default). Devices may send other lead times and per-type switches; the dispatcher honours the type switches, and per-device lead times and the S10 sheet arrive on D8 with preferences.
- **Only the kickoff reminder is produced today.** Goal, final score, channels updated and frequency changed have no producer until D5–D6; the outbox and dispatcher already handle every type.
- **Owner steps today:** create the FCM service account and put it in the host `.env`; create the Kuma monitors from its runbook (FR-027); enable web push (VAPID key) in Firebase; create the Telegram bot and chat; create the Backblaze B2 bucket and key, the restic password, and the OCI bucket and key; check the first backup; test push on a real iPhone (iOS ≥ 16.4) with the PWA installed; set Remote Config defaults in the Firebase console.
- **D3 needs no Firebase plan change.** FCM, Remote Config and Crashlytics are free on Spark (constitution IX). Spark vs Blaze (O6, delivery-plan A3) only affects the PWA mirror, which waits for D9–D10.
- **The PWA's service worker stays minimal** today: FCM background messages only. Caching and mirror failover arrive on D9–D10.
- **The A13 unresolved-names queue, the A5 merge tool and A8's frequency history and cleanup tools** wait for D5–D8.
- **Crashlytics only on Android.** Sentry for the API, admin and web stays optional (SD §7.4).
- **Restore drills** start on D8 (`runbooks/restore.md`); today proves a backup is taken and stored.

### Out of scope (later days)

- **D4:** load tests, the security review, the admin on `wg0` and its Playwright smoke test, the public PWA.
- **D5–D6:** live feed, goal and final-score pushes, channels-updated and frequency-changed pushes, the A15 composer and outbox log, A16, A17, the unresolved-names queue, YallaKora.
- **D7–D8:** S10 follow sheet and per-type preferences, maintenance and soft-update switching, A11, merge tools, channel delta sync, restore drill.
- **V1/V2 parts of S1, S9, S15, S16:** popular-in-region suggestions, the notifications group of S15, competition order and hide, rights, feeds, the satellite finder.

### Dependencies between lanes today

- Lane M's registration, follows and push need B1's device endpoints, so B1 merges the public spec changes and the regenerated app client by 13:00. Until then, M builds onboarding, S9, S15, S16 and S0 on local state and the bundled defaults.
- Lane A's A2 and A13 need B1's admin additions (by 13:00); A5–A8 and A10 use D2's endpoints and can start at once.
- B2's breaker state and pause flags must be stored where B1's admin API reads them; B1 owns the model and migration, and B2 updates the state from `backend/app/adapters/`.
- The done check's first clause needs B1's dispatcher deployed with the FCM credentials, M's push on both platforms, and an iPhone with the PWA installed.
