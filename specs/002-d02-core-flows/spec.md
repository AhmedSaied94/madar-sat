# Feature Specification: D2 · Core flows

**Feature Branch**: `002-d02-core-flows` (lane branches `d02-b1`, `d02-b2`, `d02-a`, `d02-m`)

**Created**: 2026-10-30

**Status**: Draft

**Input**: User description: "Day 2 spec (D2) per docs/delivery-plan.md". Scope is exactly the brief "D2 · 002-d02-core-flows" in `docs/delivery-plan.md` Appendix B; the done check is catalog row 002 in Appendix A.

| | |
| --- | --- |
| Goal | An editor's change reaches the phone, fixtures arrive without anyone clicking, and the four core screens work on real data |
| Phase | MVP [P], milestone M1 (delivery-plan §1, §6 Phase 1) |
| Starts from | 001, signed off by the owner on 2026-10-30. Contract `v1` frozen (tag `contract-v1`). No task in 001's `tasks.md` is unchecked; the owner items D1 carried into D2 are under Assumptions |
| Contract | Admin app `/admin/api`: CRUD for matches, teams, competitions, satellites, channels and commentators; the A3/A4 match operations; media upload; `If-Match`; audit writes; `locked_fields`. The D1 auth endpoints implemented as declared (SD §6.5). The `status_source = manual` override. **No public changes:** `/v1` paths, fields and shapes stay as tagged |
| Flags | None (closed testers only) |
| Implements | SD §5.1 (data flow), §6.2.3, §6.4, §6.5, §6.6, §6.9 (uploads), §7.2 (home box), §8 · PB §9 S2, S3, S4, S5, §10 A3, A4 and the common admin states · `../old_app/public/IMPORT.html` |

Shorthand: **SD** = `docs/system-design.md`, **PB** = `docs/product-business.md`, **D1 contracts** = `specs/001-d01-foundation/contracts/`, **app:** / **admin:** = a board in `madar-design/app-flutter/SCREENS.md` / `madar-design/admin-react/SCREENS.md`.

## Clarifications

### Session 2026-10-30

- Q: What machine is the home box that runs the scrape worker? → A: An x86-64 Linux box with Docker. B2 builds a `linux/amd64` variant of the backend image for it only; the VPS images stay `linux/arm64` (FR-028, FR-029, Assumptions).
- Q: What does the Firestore bridge import on D2? → A: Fixtures plus each match's channel links, hidden flags and per-channel commentators, by the snapshot rules, so new matches have channels before LiveSoccerTV on D3 (FR-027).
- Q: Does the admin Playwright smoke test (log in → edit a match → see the change) land on D2 or D4? → A: D4, as the delivery plan schedules, against the admin deployed on `wg0`. D2 covers A3 and A4 with Vitest and mocked-API tests (FR-054, Assumptions).
- Q: When an editor removes a channel link that an importer brought, what stops the next import from adding it back? → A: The link stays as a hidden `manual` link: the app never shows it and importers leave it alone. Removing an editor-added link deletes it (FR-008, Edge Cases).
- Q: If an importer changes a match while an editor has it open, is the editor's save refused? → A: Yes. A match's version covers its fields, links, broadcaster slots and status, whoever changed them, so the save gets `409` and the conflict dialog names the source and shows the diff (FR-009, Edge Cases).
- Q: Who may use «إخفاء دائماً» on D2, and how is a mistake undone before A11 arrives on D7? → A: Any editor, after a confirmation. In A4, a channel hidden this way shows as «مخفية دائماً» with «إظهار», which removes the name from the hidden list (FR-008, FR-032).
- Q: Which time zone do A3's day tabs and A4's kickoff entry use? → A: Always Cairo (Africa/Cairo, DST-aware), labelled «بتوقيت القاهرة», for every editor whatever their computer's zone. This reads PB A4's "the admin's zone" as the zone of the sources editors copy from. Storage stays UTC (FR-007, FR-032, Edge Cases).
- Q (during planning): How do logos an importer finds reach VPS-1's media disk, when the import workers run on VPS-2? → A: A small media worker on VPS-1 does the rehosting. VPS-2 only queues the request. It is the one worker on VPS-1, a recorded deviation from constitution IX (FR-024, FR-029, Assumptions).

## User Scenarios & Testing *(mandatory)*

Each story is one lane's work and maps to that lane's section of `tasks.md` (`## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M`). Stories are ordered by how much the other lanes depend on them.

### User Story 1 - Lane B1: an editor edits any MVP entity safely, and the edit is live within 60 s (Priority: P1)

As an editor, I log in and edit any MVP entity safely, and my edit is live within 60 s.

The admin API implements the auth shapes declared on D1 and serves the six MVP entities, the match operations A3 and A4 need, and media upload. Every write is checked against the editor's role, refused if it would overwrite someone else's newer edit, recorded in the audit log, protected from importers, and made visible in `/v1` by a dataset-version bump, with no publish step. An editor can also set a match's status and score by hand, and that status wins over the clock estimate until it is cleared.

**Why this priority**: Lane A builds A3 and A4 on this contract, and the first clause of the done check (an admin edits a match over WireGuard and the app shows it) runs through it.

**Independent Test**: On a database loaded with the snapshot, create the first admin with the CLI, log in, and update one match's kickoff and channels with `If-Match`. Check the audit entry and its diff, the bumped `matches` version, the edited fields in `locked_fields`, a `409` when the old `If-Match` is sent again, and the change with a new `ETag` from `/v1/matches`. Then set the match to manual live, 1–0, and see `/v1/live` serve it with `estimated: false`. Clear it, and the clock estimate returns.

**Read**: SD §6.2.3, §6.4, §6.5, §6.9 (uploads), §8; D1 contracts `admin-auth-v1.md`; `specs/001-d01-foundation/data-model.md` (`admin_users`, `admin_refresh_tokens`, `audit_log`, `dataset_versions`, `locked_fields`, match status).

**Acceptance Scenarios**:

1. **Given** no admin exists, **When** the owner runs the CLI create-admin command on VPS-1, **Then** an admin is created with an argon2id hash. The password is read from a prompt, never from the command line, and is refused under 12 characters. No default account exists.
2. **Given** valid credentials, **When** an editor logs in, **Then** the response and cookies are exactly the D1 `Session` declaration: a 15-minute access JWT, a 14-day refresh cookie that rotates on every use, and a CSRF cookie that refresh and logout must echo. Reusing a rotated refresh token revokes its whole family, and logout revokes the token.
3. **Given** 5 failed attempts for one email from one IP within 15 minutes, **When** a sixth arrives, **Then** it gets `429 account_locked` with `retry_after_s` and `Retry-After`. Registered and unregistered emails get the same responses and the same counting.
4. **Given** any admin route, **When** it is called with no token, an expired token or a role below its requirement, **Then** it answers `401 unauthenticated`, `401 token_expired` or `403 forbidden`. Every route checks the role in one shared dependency.
5. **Given** any mutation, **When** it succeeds, **Then** in the same transaction it writes an `audit_log` entry (who, entity, action, field diff), adds the names of the fields whose value changed to `locked_fields` on matches and channels, bumps every affected dataset version, and returns the new `ETag`.
6. **Given** a change to an existing entity without `If-Match`, **When** it arrives, **Then** it gets `428 precondition_required`. **Given** an `If-Match` older than the stored version, **Then** it gets `409 edit_conflict` naming who changed the entity last (an admin or an importer's source) and when, and nothing is written.
7. **Given** a match past its kickoff with no manual or feed status, **When** `/v1/live` is read, **Then** it is `live` with `estimated: true` and no score or minute, as on D1. **When** an editor sets it to manual `live`, 1–0, minute `67`, **Then** `/v1/live`, `/v1/matches` and `/v1/matches/{id}` serve that state with `estimated: false`. **When** the editor clears the override, **Then** the clock estimate returns.
8. **Given** an upload, **When** its magic bytes show an allowed image ≤ 2 MB or an allowed audio file ≤ 1 MB, **Then** the image is stored as WebP ≤ 512 px with metadata stripped, or the audio as AAC trimmed to 30 s, content-addressed, with one `media_assets` row per content hash. A mismatched type or an oversize file is refused with a stable error code.
9. **Given** an edit saved at time T, **When** a phone is showing that match's day, **Then** the change is on screen by T + 60 s, with no publish step.

---

### User Story 2 - Lane B2: tomorrow's fixtures arrive without anyone opening a browser (Priority: P2)

As the owner, I get tomorrow's fixtures without opening a browser, even if ysscores blocks Oracle.

In Sat Air, an editor pressed a button on `IMPORT.html` in a browser to import a day. Now a scheduled ysscores adapter fetches today to +3 days, saves each raw page, parses it and upserts the fixtures by their ysscores id, without touching anything an editor locked. If ysscores blocks the Oracle IPs, the scrape worker runs from the owner's home box over WireGuard, and a read-only bridge from the old Sat Air Firestore fills the gap.

**Why this priority**: The snapshot holds a rolling 7-day window from 2026-10-28, so without imports the app runs out of matches within days. The done check needs tomorrow's fixtures to arrive with no one acting.

**Independent Test**: Run the ysscores `parse` tests against the saved pages. Then let beat start a run with no one acting: tomorrow's fixtures appear with UTC kickoffs and resolved teams, an `import_runs` row records the counts and the raw page path, and a second run creates no rows. Lock a match's kickoff in the admin and see the next run leave it alone. Pause ysscores and run the bridge: it adds the fixtures ysscores doesn't have, with their channels, and duplicates none.

**Read**: SD §6.1, §6.6 (contract, pipeline, safety), §6.9 (rehosting), §7.2 (home box); `../old_app/public/IMPORT.html`; `../old_app/migration/README.md` (normalization rules); `../old_app/migration/export-firestore.mjs` (what the bridge reads).

**Acceptance Scenarios**:

1. **Given** the `SourceAdapter` base, **When** any adapter fetches, **Then** it keeps to a per-host token-bucket rate limit, fetches only from its allowlisted hosts, refuses redirects to other hosts, enforces timeouts and a response size cap, backs off with jitter on 429, 403 and 5xx, and saves each raw page gzipped. Raw pages older than 5 days are removed.
2. **Given** saved ysscores pages, **When** `parse` runs, **Then** it is pure (no network, no database), its tests pass, and it yields each fixture's ysscores id, teams, logos, competition and stage. **When** `normalize` runs, **Then** Cairo wall-clock times become UTC, `"--:--"` sets `time_tbd`, placeholders become NULL, and doubled stage text is cleaned.
3. **Given** a fixture already imported, **When** its day is imported again, **Then** the row is updated in place by `(source, external_id)`. No duplicate appears, and no field listed in `locked_fields` changes.
4. **Given** a team name, **When** entity resolution v0 runs, **Then** it uses a known external id first, then an exact normalized-name match, then chooses among same-name teams by competition similarity ≥ 0.5. Anything else keeps the text name with no team id, and the run's log lists it.
5. **Given** a fixture another source already holds (same resolved teams, kickoffs within 45 min), **When** ysscores imports it, **Then** the existing row gains the ysscores external id, and no second row is created.
6. **Given** beat, **When** its schedule fires every 3 hours, **Then** exactly one ysscores run for today … +3 starts. A run that would overlap a running one is skipped. Tasks retry with backoff up to a bounded count. Every run writes an `import_runs` row with `items_found`, `items_upserted`, `http_errors`, `status` and `raw_path`.
7. **Given** ysscores is failing or paused, **When** the Firestore bridge runs, **Then** it reads the old Sat Air data without writing to it, and upserts tomorrow's fixtures with their channel links, hidden flags and per-channel commentators through the same path. It never creates a second row for a fixture that ysscores or the snapshot already has, and never overwrites a match that ysscores updates.
8. **Given** the x86-64 home box joined as a WireGuard peer, **When** the scrape worker runs there from its `linux/amd64` image, **Then** it fetches from the home network, reaches only Redis on `wg0`, and hands the fetched pages to the import workers on VPS-2, where they are saved, normalized and upserted.
9. **Given** a merge to `master` that touches the workers, **When** CI deploys it, **Then** VPS-2 runs the import, scrape and maintenance workers and exactly one `beat`, and VPS-1 runs its media worker, with no manual step on a server.
10. **Given** an imported fixture whose team or competition has no logo, **When** the import finds a logo on an allowlisted host, **Then** VPS-1's media worker rehosts it, and the API serves it from the Madar media host. A team or competition that already has a logo keeps it.

---

### User Story 3 - Lane M: a fan finds where today's match is on and which frequency to tune, on a real phone (Priority: P3)

As a fan, I find where today's match is on and which frequency to tune, on a real phone.

S2 lists the local day's matches by competition, with the channel line. S3 answers "where to watch" in three parts, with the frequency readout visible on every carriage. S4 lists the matches on my satellites, and S5 lists the satellites and their channels. Every screen shows its cached copy first and then revalidates, so a phone that was online once still answers offline and shows the data's age. The first Android build goes to the Play closed track, and the PWA runs on a preview channel.

**Why this priority**: These four screens are the product's answer (constitution I). They need no contract change, only the deployed `/v1`, so Lane M can start in the morning. The done check needs them on a real phone and the closed-test build uploaded.

**Independent Test**: Install the closed-test build on a real Android phone. On S2, page through the week, filter to live and open a match. S3 lists the carriages on Nilesat and Badr first, with readouts and access badges, then the other satellites, then platforms. Play a commentator clip. On S4, see only matches carried on the selected satellites. On S5.1 open Nilesat; on S5.2 switch to entertainment and search by frequency digits. Switch to airplane mode and reopen: the same screens show the cached data with its age. Open the PWA preview channel in a browser and repeat S2 and S3.

**Read**: PB §8.4, §9 S2, S3, S4, S5, §13.8; SD §5.1 (data flow and the datasets table); D1 contracts `public-api-v1.md`; app: S2 Matches, S2 Live filter (light), S2 First load skeleton, S3 Before kickoff, S3 130 channels, S3 No channels yet, S4 My satellites, S5.1 Satellite list, S5.2 Satellite detail; the READMEs of `CommentatorRow`, `Chip`, `FormControls`, `Banner`, `Badges` and `CarriageRow` in `madar-design/design-system/components/`.

**Acceptance Scenarios**:

1. **Given** S2, **When** it opens, **Then** it shows the date strip (7 days, RTL week paging, «اليوم» back to today, the selected date in words), the chips «الكل» and «مباشر ‹count›» (with a red dot while any match is live), competition groups ordered by admin priority then earliest kickoff, and a «موعد لم يُحدد» group last. Days are the device's local days, computed from `kickoff_at` (P2).
2. **Given** a match row, **When** it renders, **Then** the home team is on the right, the away team on the left, and the `StatusBlock` between them shows the PB S2 variant for the match's state, including the imminent countdown, the estimated live state without a score, and «لم يُحدد». Under the row, the channel line shows up to 2 names (my satellites first, free first), «مجانية» when any free channel exists, and `+N`. It is hidden when there are no channels.
3. **Given** S2, **When** the user pulls to refresh or swipes sideways, **Then** the day revalidates, or the day changes with RTL semantics. A first load with no cache shows the skeleton (3 groups × 3 rows). An empty day and an empty live filter show their PB copy.
4. **Given** S3 for a match before kickoff, **When** it opens, **Then** the hero shows competition and stage, both teams (home on the right), the kickoff or status, the local date and time, and a countdown. "Where to watch" shows its toolbar (count, «المجانية فقط», and a search field when there are more than 6 entries), then «على أقمارك» (free first; «على نايل سات وبدر» with «حدد أقمارك» when none are chosen), then «أقمار أخرى» grouped by satellite with the first group open, then «منصات وقنوات أخرى» by region and country, collapsed.
5. **Given** a carriage row, **When** it is collapsed, **Then** the channel, the satellite's short name, the `FrequencyReadout` (LTR) and the access badge are visible with no tap. **When** it is expanded, **Then** it shows the satellite in Arabic and English with its position, the frequency, polarization and symbol rate, access, provider and package, and category, with "copy frequency" and the satellite's reception video.
6. **Given** a channel's commentators, **When** the user taps play, **Then** the clip goes through its idle, loading, playing («جاري التشغيل...») and error states, and starting one clip stops any other.
7. **Given** manual broadcasters, a stadium, an Egyptian broadcaster or a match-level commentator, **When** S3 renders, **Then** each has its card: «يعرض على» for the first broadcaster and «يعرض أيضاً على» for the rest. A card with no data isn't shown.
8. **Given** a match with no channels, **When** S3 opens, **Then** it shows «لم تُضف القنوات الناقلة بعد» with a «تحديث» action that revalidates the match (the «تابع المباراة» follow action replaces it on D3). **Given** a match with 130–171 channels, **Then** the list is virtualized, groups start collapsed, and a floating «العودة لأعلى القنوات» button appears.
9. **Given** S4, **When** it opens, **Then** chips select among my satellites («الكل» selects all), and the list shows only matches with at least one carriage on the selected satellites. They are grouped by competition with finished matches last in each group, and each row shows those carriages with their readouts. Both empty states (no matches on the satellite, no satellites chosen) show their PB copy.
10. **Given** S5.1, **When** it opens, **Then** satellites appear in admin priority order with my satellites pinned first and marked, and search filters them. **Given** S5.2, **Then** it shows the names and position, «أقوى تردد» and «أضعف تردد», the reception video button, the رياضة / ترفيه switch (also by swipe), search by name or frequency digits, and rows with the readout always visible and the access badge. Expanding a row shows the S3 details.
11. **Given** any of S2–S5 loaded once, **When** it is reopened offline, **Then** the cached copy shows at once, with a "last updated" hint when it is older than its freshness target, and never as live. Online, a `200` updates the copy and a `304` changes nothing. A skeleton appears only when there is no copy.
12. **Given** S2, S3 or S4 in the foreground, **When** time passes, **Then** matches revalidate every 60 s, and `/v1/live` is polled every 30 s while a live or imminent match is on screen. An estimated live state shows «مباشر» with the quieter treatment and no score or minute.
13. **Given** an `app-v*` tag, **When** the release pipeline runs, **Then** it produces a signed `prod` release AAB, the owner uploads it to the Play closed track, and testers can install it. The web build runs on a Firebase preview channel and loads its data from VPS-1.

---

### User Story 4 - Lane A: an editor fixes the day's matches and their channels in one screen (Priority: P4)

As an editor, I fix the day's matches and their channels in one screen.

A3 shows one day of matches grouped by competition, with what is missing visible at a glance. A4 edits everything about one match: teams, time, competition and stage, status and score, the manual broadcasters, which channels carry it, who commentates on each, and which channels to hide. A4 guards against losing unsaved work and against overwriting another editor.

**Why this priority**: It needs B1's admin contract, and its users are 2–5 editors behind WireGuard. It is the visible half of the done check's first clause.

**Independent Test**: Run the admin against Prism serving the updated admin spec, then against the deployed admin API over WireGuard. Log in, open tomorrow in A3, filter to "missing channels", and open a match in A4. Add two channels with commentators, hide one channel from this match only, set a manual score, and save: «تم الحفظ» appears, and then the change appears in the app. Save the same match from a second browser, then save again from the first: the conflict dialog appears.

**Read**: PB §10 A3, A4 and "Common admin states"; SD §5.4; admin: A3 Matches, A4 Match editor (light), "Conflict, typed confirm, unsaved guard, toasts, empty, skeleton"; the READMEs of `DataTable`, `FormField`, `StatusChip` and `ConfirmDialog` in `madar-design/design-system/components/`.

**Acceptance Scenarios**:

1. **Given** A1, **When** an editor logs in against the real admin API, **Then** the access token stays in memory, the session refreshes silently with the CSRF header before the token expires, a failed refresh returns to A1, and the D1 error and lockout states still work.
2. **Given** A3, **When** it opens, **Then** the day tabs «أمس / اليوم / غداً / بعد غد / تاريخ…» select Cairo days (Africa/Cairo, DST-aware, labelled «بتوقيت القاهرة») for every editor, the filters (competition, source, missing channels, status) narrow the list, and the rows, grouped by competition, show time, teams with logos, status, channel count, commentator, source badges, and a lock icon when any field is locked. «إضافة مباراة» opens an empty A4.
3. **Given** rows selected in A3, **When** an editor changes their competition in bulk, **Then** all of them change in one save. **When** an admin removes their channels in bulk, **Then** a typed confirmation comes first. Editors don't see the remove action.
4. **Given** A4, **When** the editor picks teams, **Then** same-name teams are told apart by competition and logo, and a free-text name is still allowed. Date and time are entered and shown in Cairo time, labelled «بتوقيت القاهرة», whatever the computer's zone, and saved as UTC, and "time to be confirmed" is available. Competition and stage use the presets (الجولة الأولى، ذهاب/إياب دور 16، ربع النهائي، نصف النهائي، النهائي) or free text. Stadium is a text field.
5. **Given** A4's status section, **When** the editor sets a status with a score (and penalties where allowed), **Then** it saves as a manual status. Clearing it returns the match to the automatic status.
6. **Given** A4's two manual broadcaster slots, **When** the editor fills one, **Then** its label comes from the presets or free text, with a logo and an optional commentator.
7. **Given** the channel picker, **When** the editor searches, **Then** results filter by satellite and by رياضة / ترفيه, and include platforms without a satellite. Each chosen channel shows its source badge, «إخفاء من هذا الماتش فقط», «إخفاء دائماً» (confirmed first), and commentators 1 and 2. A channel hidden everywhere shows as «مخفية دائماً», and «إظهار» brings it back on every match.
8. **Given** unsaved changes, **When** the editor navigates away, **Then** the unsaved guard asks first. **Given** a save answered with `409`, **Then** the conflict dialog «عدّل ‹user› هذا العنصر — اعرض التغييرات» names the other editor or the importer's source, shows the other version and offers to reload it. Every save ends in «تم الحفظ» or «فشل الحفظ».
9. **Given** the updated admin spec, **When** Orval runs, **Then** it regenerates the client and Zod schemas, Zod validates every response, and no API type is written by hand. Errors map from `error.code` to Arabic copy.

---

### Edge Cases

- **Two editors on one match.** The second save with an old version gets `409`, never a silent overwrite. A bulk change with one stale item changes nothing and names the stale rows.
- **An importer run lands while an editor has the match open.** If the run changed the match, its links or its slots, the editor's save gets `409` naming the source (for example «عدّل ysscores هذا العنصر»), with the diff. The editor reloads and saves again. A run that changes nothing on the match leaves its version alone.
- **An editor changes a field an importer also writes.** The field is locked, and later imports leave it as edited. The match's other fields keep updating.
- **A manual status left on.** It stays until an editor clears it (constitution II); no timer clears it. The match list and detail serve the stored manual status even after the match leaves `/v1/live`'s window.
- **Impossible manual values.** A score on `scheduled`, `postponed` or `cancelled`, penalties on any status but `penalties` or `finished`, a negative score, or an over-long minute is a validation error.
- **Login probing.** Registered and unregistered emails get the same responses and the same counting. A deactivated admin can't log in, and their refresh tokens stop working.
- **Refresh token replay.** Reusing a rotated refresh token revokes the whole family, so both sessions must log in again.
- **The same file uploaded twice.** The existing asset is returned, with no second row. A file named `.png` that holds something else is refused by its magic bytes.
- **An entity in use.** Deleting a team, competition or commentator that something references is refused with the usage count. Channels are soft-deleted. Matches are never deleted, so A3 has no delete action: PB §10 A3 lists one, and constitution II wins.
- **«إخفاء دائماً».** It hides every channel whose normalized name or display name matches, including stubs that importers add later. A mistaken hide is undone from A4 with «إظهار», which shows the channel again on every match that carries it. The full list of hidden names waits for A11 on D7.
- **A second commentator without a first, or the same commentator twice on one channel.** Refused, as the schema's check requires.
- **ysscores blocks us or changes its layout.** The run records the HTTP errors or the zero items in `import_runs`. The circuit breaker and the zero-items alarm arrive on D3; until then, the bridge and the home box cover a block.
- **A fixture with no time (`"--:--"`).** `time_tbd` is set, and the app lists it under «موعد لم يُحدد».
- **A fixture whose kickoff moves.** The row updates in place and never becomes a second row. A locked kickoff stays as the editor set it.
- **Unmatched team names.** The match keeps the text name and no team id, and the run lists the names. The unresolved-names queue arrives on D5.
- **Overlapping runs.** A run that starts while another holds the job's lock is skipped, and the skip is recorded.
- **The home box is offline.** Its fetches stop and the runs record the failure. The bridge still runs from VPS-2.
- **The old data links a channel Madar doesn't have** (added to Sat Air after the snapshot, or deleted there). The link is skipped and logged in the run, as the snapshot load does. The bridge doesn't import channels themselves.
- **An editor changed a link the bridge also brings.** Editing made it a `manual` link (FR-008), so the bridge leaves it, even when the old data hides or drops it.
- **An editor removes a channel an importer brought, and the source still lists it.** The link was kept as a hidden `manual` link (FR-008), so the next run doesn't bring it back and the app doesn't show it. The same holds for D3's LiveSoccerTV links.
- **The old data drops a channel from a match.** The bridge removes that `legacy` link. Links from editors or other sources stay.
- **The device's day differs from Cairo's.** S2 groups by the device's local day, so a 01:00 Cairo kickoff can fall on the previous local day in Morocco. The admin always works in Cairo days, so A3 and the app can file one match under different dates.
- **An editor's computer isn't set to Cairo, or Egypt changes its clocks.** A3 and A4 still show and take Cairo time, by the Africa/Cairo rules for that date, so a kickoff entered in late October or late April lands at the right UTC instant.
- **171 channels on one match.** The list stays virtualized and scrolls smoothly, and group headers show their counts.
- **No satellites chosen.** The default Nilesat + Badr (O10) applies, with «حدد أقمارك».
- **A clip fails, or the browser blocks autoplay.** The row shows its error state. On the iOS PWA a clip plays only after a tap.
- **First launch offline with no cache.** The screen shows its load-failed state by `error.code`. Nothing is invented.
- **Locales that emit Arabic-Indic digits.** Times, counts, scores and frequencies still render Western digits.
- **The PWA preview's origin isn't allowed by CORS.** The preview can't load data until the owner adds it on VPS-1 (Assumptions). The Android build is unaffected.

## Requirements *(mandatory)*

### Functional Requirements

#### Admin API and auth (Lane B1)

- **FR-001**: The auth endpoints (login, refresh, logout, current admin) MUST implement the D1 declaration in `admin-auth-v1.md` without changing any request, response, cookie, header or error code.
- **FR-002**: Passwords MUST be hashed with argon2id and be at least 12 characters, and there are no default credentials. A CLI command MUST create an admin (email, name, role), reading the password from an interactive prompt or standard input, never from the command line. It refuses a duplicate email. Until A16 (D6), every admin account is created this way.
- **FR-003**: Login MUST allow 5 attempts per 15 minutes per email + client IP, counted whether or not the email exists, then lock out with `429 account_locked`, `retry_after_s` and `Retry-After`. A successful login resets the count. The client IP comes from `X-Forwarded-For` only when the request comes through Caddy. A deactivated admin can't log in.
- **FR-004**: Access JWTs MUST last 15 minutes and be signed with a key that exists only in the host environment. Refresh tokens MUST last 14 days, be opaque, be stored only as a hash, rotate on every use, and revoke their whole family when a rotated token is reused. Refresh and logout MUST require the CSRF header to equal the CSRF cookie. Logout revokes the token and clears both cookies.
- **FR-005**: Every admin route MUST declare its required role through one shared dependency. `editor` covers content CRUD and the match operations; `admin` adds destructive bulk actions. Errors are `401 unauthenticated`, `401 token_expired` and `403 forbidden`.
- **FR-006**: The admin API MUST serve list, read, create and update for matches, teams, competitions, satellites, channels and commentators, with every input validated (enums, length caps, id types, and no card-sharing label in any free-text field that reaches `/v1`) and every response in the envelope. Deletes:
  - matches are never deleted;
  - channels are soft-deleted;
  - teams, competitions and commentators are deleted only when nothing references them, otherwise `409 in_use` with the usage count.
- **FR-007**: The admin lists MUST give A3 and A4 what they show:
  - matches for a UTC window (Cairo day bounds sent by the admin, at most 8 days), filtered by competition, source, missing channels and status. Each row has time, teams with logos, status, channel count, commentator, its sources, and whether any field is locked;
  - team search by normalized name, returning each team's competitions and logo for disambiguation;
  - channel search filtered by satellite, category and kind, including platforms without a satellite;
  - the broadcast presets, read-only (their editor is A11, on D7).

  Lists that can grow use cursor pagination (`meta.next_cursor`).
- **FR-008**: The match operations MUST cover:
  - teams by id or as text only; kickoff in UTC, or `time_tbd`; competition and stage; stadium;
  - manual broadcaster slots 1 and 2 (label, logo asset, optional commentator);
  - channel links: add, remove, hide on this match, and commentators 1 and 2 per link (2 needs 1 and differs from it);
  - «إخفاء دائماً»: add the channel's normalized name to the hidden channel names; and «إظهار»: remove a name from that list (both `editor`, audited like any mutation);
  - bulk change of competition on selected matches (`editor`);
  - bulk removal of channels from selected matches (`admin`).

  A link an editor adds or edits (hides it, or sets its commentators) is recorded with the `manual` source from then on, so no importer changes or removes it. Removing a link, one at a time or in bulk, deletes it only when an editor added it. A link an importer brought becomes a hidden `manual` link instead: the app never shows it, A4 lists it as hidden so it can be shown again, and no importer re-adds it.
- **FR-009**: Every admin GET of a single entity MUST return an `ETag`, and every change to an existing entity (update, delete, or a bulk item) MUST require `If-Match`. Creating a new entity, and adding or removing a hidden channel name, have no earlier version to protect, so they need none (plan, Complexity Tracking); they are still audited and bump versions. A missing header gets `428 precondition_required`. A stale one gets `409 edit_conflict`, with `meta` naming who last changed the entity (an admin, or an importer's source) and when, and nothing is written. A match's version covers its fields, its channel links, its broadcaster slots and its status, so a change by an importer makes an open editor's version stale just as another editor's change does. A bulk request carries each item's version, and one stale item rejects the whole request and lists the stale ids.
- **FR-010**: Every successful mutation MUST, in one transaction:
  - write an `audit_log` entry with the admin, entity, id, action and a field-level before/after diff;
  - add to `locked_fields`, on matches and channels, the names of the fields whose value changed (a field sent with its current value isn't locked);
  - bump every affected dataset version, as the transaction's last statement;
  - return the entity's new `ETag`.

  A media change bumps the dataset of the row that references the asset.
- **FR-011**: A manual status MUST:
  - take a status from the SD §6.2.3 state machine, with an optional period, an optional minute (text such as `45+2`, ≤ 8 characters) and an optional `status_label` (≤ 80 characters);
  - allow a score only for `live`, `halftime`, `extra_time`, `penalties`, `finished` and `abandoned`, and penalty scores only for `penalties` and `finished`;
  - set `status_source = manual` and `status_updated_at`, and bump `live` and `matches`.

  Clearing it sets `status_source` back to `clock`. While it is manual, `/v1/live`, `/v1/matches` and `/v1/matches/{id}` serve it with `estimated: false`. The D1 clock rule is unchanged for every other match.
- **FR-012**: Uploads MUST go through the admin API only, and MUST:
  - check the type by magic bytes: images (PNG, JPEG, WebP) up to 2 MB, audio (MP3, AAC/M4A, OGG, WAV) up to 1 MB;
  - re-encode images to WebP ≤ 512 px with metadata stripped, and audio to AAC trimmed to 30 s, as the D1 rehosting does;
  - store files content-addressed, returning the existing asset when its content hash is already stored;
  - return the asset id and its absolute media URL;
  - refuse anything else with a stable code: `unsupported_media_type`, `file_too_large` or `media_invalid`.
- **FR-013**: Every admin endpoint MUST have contract tests against the exported admin OpenAPI, run on a real PostgreSQL 16. The admin additions are non-breaking against `contract-v1`, and the public spec doesn't change.
- **FR-014**: A client revalidating with its `ETag` MUST see an admin edit as soon as the edit commits. Nothing between the database and the client may hold an older copy, so the end-to-end delay is at most the client's 60 s refresh interval.

#### Ingestion (Lane B2)

- **FR-020**: Every source MUST implement `SourceAdapter` (`name`, `allowed_hosts`, `fetch`, `parse`, `normalize`; SD §6.6). The base MUST provide:
  - per-host token-bucket rate limits in Redis;
  - a host allowlist, with no redirects to other hosts;
  - timeouts and a response size cap;
  - exponential backoff with jitter on 429, 403 and 5xx;
  - gzipped raw pages, kept 5 days on VPS-2 wherever the fetch ran.
- **FR-021**: The `ysscores` adapter MUST port the fetch and parse logic of `../old_app/public/IMPORT.html` for today … +3 days. `parse` is pure and tested against saved pages committed as test fixtures. `normalize` applies the migration README rules: Cairo wall clock → UTC (DST-aware), `"--:--"` → `time_tbd`, placeholders → NULL, doubled stage text cleaned.
- **FR-022**: Imports MUST upsert by `(source, external_id)` through the `*_external_ids` tables, MUST NOT write any field listed in `locked_fields`, and MUST remove only the match–channel links their own source added. A fixture another source already holds (same resolved home and away teams, kickoffs within 45 min) gains the new external id instead of a new row.
- **FR-023**: Entity resolution v0 MUST try, in order: a known external id, an exact `ar_normalize` name match, then a choice among same-name candidates by competition similarity ≥ 0.5 (the old app's rule). Anything else keeps its text name with no id and is listed in the run's log. Nothing is guessed beyond these rules.
- **FR-024**: Logos an importer finds MUST be rehosted from allowlisted hosts only, with the D1 rehosting rules, and only for a team or competition that has no logo; an existing logo is never replaced. The import workers on VPS-2 only queue the request. A media worker on VPS-1, next to the media disk, downloads, re-encodes and stores the file and sets the logo, writing an audit entry with the source and bumping the affected datasets. A failed or refused download leaves the logo empty, and the failure is logged and retried with backoff.
- **FR-025**: Every run MUST write an `import_runs` row with `items_found`, `items_upserted`, `http_errors`, `status` and `raw_path`, and bump the affected dataset versions when it changes data.
- **FR-026**: Tasks MUST use `bind=True`, `autoretry_for`, `retry_backoff`, `retry_jitter` and a bounded `max_retries`, with a Redis `SET NX EX` lock per job so that runs never overlap. Beat runs ysscores every 3 hours, and exactly one `beat` runs.
- **FR-027**: The Firestore bridge MUST read the old Sat Air data read-only. The old project's configuration lives only in VPS-2's host environment and is never committed (D15). The bridge upserts fixtures for today … +3 with their channel links, hidden flags and per-channel commentators, applying the snapshot rules of the migration README (orphan references skipped and logged, no card-sharing labels). It goes through the FR-022 path as the Sat Air (`legacy`) source, keyed by the Sat Air match id, so a snapshot row and its bridge update are the same row, and it adds and removes only `legacy` links. It never duplicates a fixture ysscores holds, and never overwrites fields on a match that ysscores updates. It runs on beat every 3 hours, offset from ysscores, and on demand.
- **FR-028**: The scrape worker MUST be deployable to the owner's x86-64 home box, as a WireGuard peer that reaches only Redis on `wg0`. It fetches there, while saving, normalizing and upserting stay on VPS-2. The home box has its own Compose file, runs only `worker-scrape`, and holds no database credentials.
- **FR-029**: CI MUST deploy VPS-2's workers (`worker-imports`, `worker-scrape`, `worker-maintenance`) and its single `beat` on a merge to `master`, with health checks and automatic rollback, the way `backend.yml` deploys VPS-1. Every VPS image stays `linux/arm64`. CI also publishes a `linux/amd64` variant of the same backend image, used only by the home box. VPS-1's deploy also brings up its media worker (FR-024) and checks its health.

#### Admin (Lane A)

- **FR-030**: A1 MUST log in against the real admin API. The access token stays in memory only, the session refreshes silently with the CSRF header before expiry, and a failed refresh returns to A1.
- **FR-031**: A3 MUST have the day tabs, the four filters, the competition groups and the row contents of PB §10 A3 (the FR-007 data), bulk change of competition, bulk removal of channels (admin role only, typed confirmation first) and «إضافة مباراة». It has no delete action.
- **FR-032**: A4 MUST have the parts the D2 brief lists:
  - the team picker with disambiguation, plus free text;
  - date and time in Cairo time (Africa/Cairo, DST-aware, labelled «بتوقيت القاهرة») whatever the computer's zone, stored as UTC, with "time to be confirmed";
  - competition and stage presets, and stadium;
  - the status override with score and penalties;
  - the two manual broadcaster slots;
  - the channel picker with its filters, and, for each chosen channel, its source badge, «إخفاء من هذا الماتش فقط», «إخفاء دائماً» and commentators 1 and 2. A channel hidden everywhere shows as «مخفية دائماً» with «إظهار».
- **FR-033**: A3 and A4 MUST implement the common admin states: table skeletons, empty states, the «تم الحفظ» and «فشل الحفظ» toasts, the unsaved-changes guard, the `409` conflict dialog «عدّل ‹user› هذا العنصر — اعرض التغييرات», and typed confirmation for destructive actions.
- **FR-034**: The client and Zod schemas MUST be regenerated by Orval from the updated admin spec. Zod validates every response, React Query does all data fetching, forms use React Hook Form + Zod, and `error.code` maps to Arabic copy. Generated files are never edited by hand.
- **FR-035**: A3 and A4 MUST be built from the existing shared components, and any new one (`ConfirmDialog`, `ConflictDialog`, ...) is built once under its `components/INDEX.md` name, with tokens only, RTL, visible keyboard focus, and a Vitest test for each state its README lists.

#### App (Lane M)

- **FR-040**: S2 MUST implement the [P] parts of PB S2: the header (wordmark, and the search action to the `/search` stub), the date strip with RTL paging and «اليوم», the selected date in words, the chips «الكل» and «مباشر ‹count›», competition groups (admin priority, then earliest kickoff), match rows with the channel line, every `StatusBlock` variant, the «موعد لم يُحدد» group, pull to refresh, swiping between days, the skeleton, and the empty day and empty live states.
- **FR-041**: Matches MUST be grouped by the device's local date, computed from `kickoff_at` (P2) and requested as UTC bounds. `match_date` is never used.
- **FR-042**: S3 MUST implement:
  - the hero;
  - the three-part "where to watch" with its toolbar;
  - `CarriageRow`, collapsed with the readout, and expanded with the details and the copy-frequency and reception-video actions;
  - `CommentatorRow` with voice clips, one playing at a time, in all four states;
  - the manual broadcaster cards, and the stadium, Egyptian broadcaster and match-level commentator cards when they have data;
  - the no-channels state, with «تحديث» as its next action until follows arrive on D3;
  - a virtualized list for long carriage lists, with the back-to-top button.
- **FR-043**: My satellites MUST default to Nilesat + Badr (O10) until the user chooses; the picker arrives with S1.3 and S15 on D3. S3, S4 and the S2 channel line MUST put my satellites first and free channels first.
- **FR-044**: S4 MUST implement the satellite chips, the filtered list grouped by competition with finished matches last, rows with their carriages and readouts, and both empty states.
- **FR-045**: S5.1 and S5.2 MUST implement the [P] parts of PB S5: search, satellite cards with my satellites pinned first, the header, the alignment aids, the reception video, the category switch with swipe, channel search by name or frequency digits, rows with the readout always visible and the access badge, expansion with the S3 details, and the empty state.
- **FR-046**: The repositories for matches, match detail, satellites and satellite channels MUST be stale-while-revalidate from drift: emit the drift copy, then revalidate with `If-None-Match`; a `200` updates drift and a `304` changes nothing. Matches keep the local days today−1 … today+6. `StaleHint` shows a copy's age once it is older than its freshness target, and cached data is never shown as live.
- **FR-047**: While S2, S3 or S4 is in the foreground, matches MUST revalidate every 60 s, and `/v1/live` MUST be polled every 30 s (the bundled default until Remote Config arrives on D3) while a live or imminent match is on screen. Live states are kept in memory only.
- **FR-048**: Every new component (`CommentatorRow`, `FilterChipRow`, `SearchField`, `Segmented`, `StaleHint`, ...; `SatelliteBadge` exists since D1) MUST be built once under its INDEX name, with every README state and goldens in RTL, both themes, at 1.0× and 1.3×. Screens use tokens only. Frequencies, Latin names and orbital positions are LTR islands, digits are Western, and composite rows read as one Arabic screen-reader label (PB §13.8).
- **FR-049**: The release pipeline MUST build a signed `prod` AAB from an `app-v*` tag, with `versionCode` from the run number. The owner uploads it to the Play closed track; an automated upload waits for the Play service account. The web build MUST deploy to a Firebase preview channel and load its data from VPS-1.

#### All lanes

- **FR-050**: `tasks.md` MUST have the sections `## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M` and `## Done check`. The Done check is copied word for word from Appendix A, row 002.
- **FR-051**: Each lane MUST change only its own folders (delivery-plan §4) and tick only its own section. Only B1 changes the admin OpenAPI and the Alembic migrations. Generated files (API clients, Orval output, token files) are never edited by hand. The PR that changes an OpenAPI spec runs both client generators and commits their output unedited (D14), because CI fails on a stale client.
- **FR-052**: No secret MUST be committed: not the JWT signing key, the old Sat Air Firebase configuration, a keystore, a WireGuard key nor snapshot data (`migration/data/`). They live in host `.env` files or GitHub Actions secrets.
- **FR-053**: Tests MUST be written and seen failing before the code they cover, for: the manual status rules; `locked_fields` protection; `If-Match` conflicts; the auth flow and lockout; audit entries and version bumps; upload validation; ysscores `parse` on saved pages; time conversion (including A4's Cairo entry across a DST change) and entity resolution; importer-removed links staying hidden; the stale-while-revalidate repositories; local-day grouping; and the S2/S3 status and channel-line formatting (constitution, Test-first).
- **FR-054**: Coverage MUST meet the MVP bar of delivery-plan §7 and constitution v1.1.0:
  - **Backend:** ≥ 70 % on `domain/`, `adapters/` and `services/`, plus contract tests on `/v1` and `/admin/api`.
  - **Admin:** Zod schemas for every response, tests for every component state, and A3/A4 flow tests against a mocked API. The Playwright smoke test (log in → edit a match → see the change) lands on D4 with the `wg0` deploy (Clarifications).
  - **App:** unit tests for the formatters and repositories, and goldens for every new component.
- **FR-055**: Every new operated part MUST get its runbook in the same change, listed in `docs/runbooks/README.md`: `staff-accounts.md` (B1), `imports-and-sources.md`, `home-box.md` and `workers.md` (B2), and `store-releases.md` (M). When each lane finishes, `docs/owner-actions.md` gets its D2 items.

### Key Entities *(include if feature involves data)*

- **Admin user**: an editor or admin with an email, a name, a role (`editor` / `admin`), an argon2id password hash and an active flag. Created by the CLI on D2.
- **Refresh token**: an opaque, hashed, revocable token in a family. It rotates on use, and reuse of a rotated token revokes the family.
- **Audit entry**: who changed which entity, the action, and a field-level before/after diff.
- **Dataset version**: a counter per dataset (`matches`, `live`, `channels`, `satellites`, `competitions`, `teams`, `commentators`, `rights_holders`). Every write bumps the ones it affects, and ETags are built from them.
- **Locked fields**: the field names on a match or channel that an editor set, which importers never write.
- **Match status**: a state from SD §6.2.3 with its source (`clock`, `manual`, later `feed`), an estimated flag, an optional period, minute and label, and a score with penalties.
- **Match–channel link**: a channel carrying a match, with the source that added it, a hidden-on-this-match flag, and commentators 1 and 2.
- **Manual broadcaster slot**: a free-text broadcaster (slot 1 or 2) with a logo and an optional commentator.
- **Hidden channel name**: a normalized name that hides matching channels on every match.
- **Broadcast preset**: a named broadcaster label with a logo, offered in A4's slots.
- **Media asset**: one stored file per content hash, with its kind and, for imported files, the URL it came from.
- **Source, raw page, import run, external id**: where a record came from, the saved page it was parsed from (kept 5 days), one row per run with its counts and status, and the record's id at that source.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An admin edit to a match is on the screen of a phone showing that day within 60 s of the save, in 3 out of 3 tries, with no publish step.
- **SC-002**: 100 % of admin mutations in the contract tests write an audit entry, bump the affected versions and lock the edited fields, and 100 % of changes to an existing entity with a missing or stale `If-Match` are refused. Every admin endpoint passes its contract test.
- **SC-003**: The sixth login attempt within 15 minutes is refused, for a registered and an unregistered email alike, with identical responses.
- **SC-004**: After the first unattended run (ysscores, or the bridge), tomorrow's fixtures are in the database with UTC kickoffs. A second run on the same day creates zero new rows and changes zero locked fields.
- **SC-005**: 100 % of import runs have an `import_runs` record, and a deliberately failed fetch is recorded with its HTTP errors.
- **SC-006**: On a 4 GB Android phone, S2 for a cached day shows its content in under 1.5 s from launch. S3 for a match with 130 or more channels shows the answer in under 1 s and scrolls to the last channel without visible stutter.
- **SC-007**: The channel, satellite and frequency for a match are reachable in 2 taps or fewer from launch, and the readout is visible without a tap on every carriage row of S3, S4 and S5.2.
- **SC-008**: Zero screens show a score or minute for an estimated live state, and zero show cached data as live, in the widget tests and on the device walk-through.
- **SC-009**: The closed-test build is on the Play closed track and installs on at least one tester's phone. The PWA preview loads S2 and S3 with data from VPS-1.
- **SC-010**: The day's **done check** passes, word for word from delivery-plan Appendix A: *"An admin logs in over WireGuard and edits a match, and the change appears in the app; ysscores (or the bridge) imports tomorrow's fixtures; S2–S5 work on a real Android phone; closed-test build uploaded"*.

## Assumptions

- **D1 is closed** (owner sign-off, 2026-10-30), with no unchecked tasks. These owner items carry into D2 (`docs/owner-actions.md`, "Open now"):
  - add `https://madar-sat--master-p2bbuj53.web.app` to `CORS_ORIGINS` on VPS-1, or the PWA preview can't load data (FR-049);
  - back up the upload keystore;
  - prove `app-release.yml` with a tag; D2's first `app-v*` tag does this;
  - enrol in Play App Signing before the first upload;
  - re-check the preview's Network tab after the PR #7 deploy.
- **Owner steps today:** create the first admin with the CLI on VPS-1 once B1 deploys; give each editor device a WireGuard peer and trust Caddy's internal CA on it; add the home box as a peer; put the old Sat Air Firestore configuration in VPS-2's `.env`; upload the AAB to the closed track; keep recruiting the 12 testers (delivery-plan §3).
- **The admin runs on the editor's machine on D2.** Its dev server forwards `/admin/api` to `https://10.8.0.1/admin/api` over WireGuard, so the app and the API share one origin and the cookies and CSRF header work. Deploying the admin on `wg0` stays on D4 (its brief).
- **Bulk channel removal is the only destructive action today**, so it alone needs the `admin` role (SD §6.5). Changing the competition in bulk is an editor action.
- **Entity resolution v0 runs without alias tables.** "Exact alias" means a known external id or an exact normalized name; the alias tables and the unresolved-names queue arrive on D5. Until then, unmatched names are listed in each run's log, not queued. That departs from constitution II ("anything else goes to `unresolved_names`"), and `plan.md` records it under Complexity Tracking.
- **Source health alarms wait for D3.** The circuit breaker, the zero-items alarm and Telegram alerts are D3 work. Today, failures show in `import_runs` and the logs.
- **There is no response cache yet.** The Redis cache keyed by dataset versions is D3's. The 60 s target rests on version-based ETags and the client's refresh interval.
- **`/v1` stays without rate limits until D3**, as the owner decided on D1. The admin API is reachable only over WireGuard, and its login is limited (FR-003).
- **Remote Config arrives on D3.** Hosts and the live poll interval come from the bundled defaults today. Constitution VIII says they come from Remote Config, so `plan.md` records this under Complexity Tracking.
- **My satellites use the default set until D3** (FR-043). `StaleHint` covers stale data today; the offline banner arrives with S0 on D3.
- **The S3 follow call-to-action waits for follows (D3).** Until then, the no-channels state offers «تحديث», so it still gives a next action (constitution I), and D3 swaps in «تابع المباراة» as designed.
- **The Play upload is manual.** An automated upload needs the Play service account, which comes later (SD §9).
- **The bridge writes as the `legacy` source.** The old Firestore holds the same data the snapshot came from, so no new source row or migration is needed.
- **The home box is x86-64** (Clarifications). CI publishes a `linux/amd64` variant of the backend image for it alone. Constitution IX says every image is `linux/arm64`; the VPSs still run only arm64, and `plan.md` records the extra variant under Complexity Tracking.
- **One worker runs on VPS-1** (Clarifications): the media worker of FR-024, because the media files live on VPS-1's disk. Constitution IX says VPS-2 runs the workers. This worker runs one task at a time with a small memory cap, handles a few logos a day, and does what D1's rehosting already does on VPS-1. `plan.md` records it under Complexity Tracking.
- **The admin Playwright smoke test lands on D4** (Clarifications). The constitution asks for it "once those flows exist"; the owner reads that as once the admin is deployed on `wg0`, which is D4's work. `plan.md` records this reading.
- **The Celery app `app.workers`** that `vps2.yml` already names doesn't exist yet. It sits outside `backend/app/adapters/`, so B1 creates it (queues, task defaults, the beat schedule hook) early in the day, and B2's tasks and schedules live under `backend/app/adapters/`. B2 uses B1's models and ETL helpers without changing them, and asks B1 for any change there.

### Out of scope (later days)

- **D3:** devices and follows, reminders, the outbox and push; the Redis response cache and rate limits; LiveSoccerTV; the circuit breaker, zero-items alarm and alerts; backups and Uptime Kuma; the A2, A5–A8, A10 and A13 screens (their entities' admin API lands today); onboarding with the satellite picker, S9, S15, S16, S0, Remote Config and Crashlytics.
- **D4:** the admin deployed on `wg0` and its Playwright smoke test, load tests, the public PWA.
- **D5–D7:** the live feed and match events, the alias tables and unresolved-names queue, S6–S8 (S5.2's "عرض القناة" waits for S6); A16 admin users and A17 audit view; A11 lists, search, channel delta sync, merge tools, and retiring the bridge.
- **In A4, not today:** the events section, the history tab, and the locked-fields indicator and unlock.
- **V1 parts of S2–S5:** «مبارياتي», the sport switcher, long-press actions, the competition overflow menu, share, and the "changed recently" and "changes this week" badges.

### Dependencies between lanes today

- Lane A builds on the admin client generated from B1's admin spec additions, so B1 merges the admin OpenAPI (routes, shapes and Prism examples), with the regenerated client, by 13:00. Until then, A builds layouts from the shared components.
- The done check's first clause needs B1's admin API deployed on VPS-1, A3/A4 working against it, and M's 60 s refresh.
- B2's tasks need B1's `app.workers` app, and B2's VPS-2 deploy needs `vps2.yml` and the workers' image from `backend.yml`.
- Lane M needs nothing new from B1. The PWA preview needs the owner's CORS change on VPS-1.
