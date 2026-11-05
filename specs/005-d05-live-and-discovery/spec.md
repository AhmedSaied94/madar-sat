# Feature Specification: D5 · Live and discovery

**Feature Branch**: `005-d05-live-and-discovery` (lane branches `d05-b1`, `d05-b2`, `d05-a`, `d05-m`)

**Created**: 2026-11-04

**Status**: Draft

**Input**: User description: "lets start day 05 with the current changes". Scope is exactly the brief "D5 · 005-d05-live-and-discovery" in `docs/delivery-plan.md` Appendix B, as changed by the 2026-11-04 O7 decision (the uncommitted edits to `docs/delivery-plan.md`, `docs/system-design.md`, `docs/product-business.md` and `docs/owner-actions.md`, which this spec depends on). The done check is catalog row 005 in Appendix A.

| | |
| --- | --- |
| Goal | Real live scores replace the clock estimate, and a fan can open a channel, a team and a competition |
| Phase | V1, first day of Phase 2 (delivery-plan §6) |
| Starts from | MVP public (`web-v0.1.0` is live on `https://madar-sat.web.app`; see Assumptions for what is still open from 004). Code carry-over from 004: the failed load test's fix (FR-060–FR-063); O7 decided, pending the live capture; parsers start on saved finished and scheduled pages, and samples captured from real live matches complete them |
| Contract | One new revision (the next free number is `0007`; the brief's `0003` is stale): `match_events`, `match_lineups`, match stats where YallaKora fills them in (this spec's plan designs the storage), `team_aliases`, `competition_aliases`, `channel_aliases`, `unresolved_names`. `MatchDetail.events/lineups`; `GET /v1/channels/{id}`, `/v1/teams/{id}`, `/v1/competitions/{id}` complete. Admin: unresolved-names queue endpoints, rights-holder CRUD |
| Flags | `live_center` stays off until D6's UI lands |
| Implements | SD §3 (O7), §6.2.3 (status), §6.6 (entity resolution, YallaKora row, safety), §6.7 (live scores and sources), §11 (freshness), §13 (R1) · PB §9 S6, S7, S8 · PB §10 A9, A13 |

Shorthand: **SD** = `docs/system-design.md`, **PB** = `docs/product-business.md`, **app:** / **admin:** = a board in `madar-design/app-flutter/SCREENS.md` / `madar-design/admin-react/SCREENS.md`.

## Clarifications

### Session 2026-11-04

- Q: When a goal happens, should the 45 s limit for a live score reaching the app start when the score is confirmed, rather than when a source first shows it? → A: Yes. The 45 s starts at confirmation. Time spent waiting for the second source isn't counted, and the capture measures and records it. Constitution VIII and SD §11 get reworded to match.
- Q: Should D5 include the fix for the failed D4 load test, and if so, which fix? → A: Yes, as carry-over. The owner checks the account's limits page and, if 4 OCPU is confirmed free, resizes VPS-1 to 2–3 OCPU. B1 re-runs the load test. If the limit isn't confirmed or the re-run still fails, B2 builds the Caddy `/v1/live` cache (FR-060–FR-063).
- Q: On a busy match day, should the live poller open match pages for every linked match, or only some of them? → A: Only some. It reads the list page for every linked match and opens match pages for up to N matches per cycle, chosen by competition priority. The capture and the plan set N.
- Q: Must the live parsers wait for a capture of a real live match? → A: No. They start on saved finished and scheduled pages, any status they haven't seen fails validation, and the capture confirms and completes them.

### Session 2026-11-05

- Q: S3's carriage row shows «عرض القناة» only once it's expanded, which is two taps to S6. Should S3's row get a one-tap way to S6, or should SC-008 change? → A: Keep two taps, per PB S5.2. S6 is reached by expanding a carriage row and tapping «عرض القناة», and the frequency is already visible on the row with no tap. S7 and S8 stay one tap. US2 scenario 1 and SC-008 get reworded to match.

## User Scenarios & Testing *(mandatory)*

Each story is one lane's work and maps to that lane's section of `tasks.md` (`## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M`). The order reflects how early each must finish: the contract comes first, and every other lane builds on it.

### User Story 1 - Lane B1: the score and minute a fan sees come from a real feed, never from a guess (Priority: P1)

As a fan, the score and minute I see come from a real feed, never from a guess.

B1 builds the scheduler, the poller and the parsers, starting the parsers straight away on saved finished and scheduled pages. Neither site has been seen live yet, so any status a parser hasn't seen fails validation instead of being guessed. B1 then captures real live matches from FilGoal and YallaKora. The capture confirms the fields, the status values and the update delay, completes the parsers, and sets how long the poller waits for the second source. FilGoal supplies status, minute, score, events and lineups. YallaKora confirms goals and supplies stats where it fills them in. A new score is published only when both sources show it, or, with one source down, when the remaining source shows it in two polls in a row. If both are down, the match falls back to the honest clock estimate. Problems reach the owner by Telegram, and no operator is needed during a match.

**Why this priority**: This is the day's headline and the riskiest work. The sources' live behaviour is unconfirmed until the capture runs, and the contract and the alias tables that B2 and Lane A need also come from B1.

**Independent Test**: Replay a saved live capture through the poller and check each transition against SD §6.7's table. Then watch a real live match on the deployed hosts: `/v1/live` shows its status, minute and score with `estimated: false`, and the score matches the broadcast.

**Read**: SD §3 (O7), §6.2.3, §6.6 (adapter contract, safety), §6.7; `.specify/memory/constitution.md` II and VII.

**Acceptance Scenarios**:

1. **Given** real live matches, **When** the capture runs from VPS-2, **Then** saved pages from both sources cover at least pre-match, first half, a goal, half-time, second half and full time. A capture report records the fields, status values and update delay found, the chosen wait for the second source, and any way the sources differ from SD §6.7. If the capture shows the sources can't work, the owner is told at once (Edge Cases).
2. **Given** no match has `kickoff_at` between now − 150 min and now + 10 min outside a final state, **When** the scheduler runs every 60 s, **Then** it queues nothing and neither source is requested.
3. **Given** a match in the window, **When** the poller runs, **Then** status, minute and score are updated and events are diffed. Every write bumps the `live` dataset version, and `/v1/live` is rebuilt at most every 15 s.
4. **Given** both sources show the same new score, **Then** the score updates at once.
5. **Given** only one source shows a new score, **Then** nothing changes until the other shows it or the wait set by the capture ends. **Given** they still differ after the wait, **Then** the last confirmed score stays and the owner gets one alert.
6. **Given** one source is down or fails validation, **Then** the other is used, and a new score needs two polls in a row.
7. **Given** a source's response is missing expected fields or has an unknown status value, **Then** that source stops being used, so a changed format can't publish a wrong score, and the owner gets one alert referring to the saved raw page. **Given** it passes validation again, **Then** it is used again and the owner gets one recovery alert.
8. **Given** both sources are down or fail validation, **Then** the match falls back to the clock estimate (`estimated: true`, no score or minute) and the owner gets one alert.
9. **Given** an admin has set a manual status, **Then** the feed doesn't change it until it is cleared, and fields in `locked_fields` are never written.
10. **Given** repeated polls of the same match, **Then** no event is inserted twice, and an event the source later removes (for example, a disallowed goal) leaves the timeline.
11. **Given** a saved page, **Then** only structured facts are stored, never FilGoal's written commentary, and no request goes to a path in either site's `robots.txt`.

---

### User Story 2 - Lane M: a fan opens a channel, a team or a competition and sees what's on (Priority: P2)

As a fan, I open a channel, a team or a competition and see what's on.

Lane M builds three screens and connects them to S2 and S3: S6 as a sheet with the carriage, its other carriages, upcoming matches and frequency history; S7 with upcoming and results tabs and follow; S8 with matches by date and a rights section.

**Why this priority**: It's half the day's goal and half the done check. It can run alongside the live work because these endpoints already exist and need only completing.

**Independent Test**: On a real Android phone, from S2 or S3, open a channel, a team and a competition. Each screen opens with real data in both themes, follows work and survive a restart, and each screen's offline and empty states show.

**Read**: PB §9 S6, S7, S8; SD §6.3.2; app: S6 Channel sheet, S7 Team, S8 Competition; `madar-design/README.md`.

**Acceptance Scenarios**:

1. **Given** a carriage row in S3, **When** it is expanded and «عرض القناة» is tapped (two taps from S3, with the frequency already visible on the row with no tap), **Then** S6 opens as a sheet with logo, name, category and country; a carriage card with satellite, the frequency readout with copy, access and provider or package; other carriages; upcoming matches for 7 days, whose rows open S3; and the follow action.
2. **Given** a channel with recorded frequency changes, **Then** S6 shows the last 3 with dates. **Given** none, which is every channel until D6 starts recording them, **Then** the section is hidden and nothing is invented.
3. **Given** a team name or crest in S3's hero (a row in S2 keeps opening S3), **When** it is tapped, **Then** S7 opens with logo, name, main competition, stadium and follow, plus «القادمة» and «النتائج» tabs of S2-style rows with channel lines. **Given** no upcoming matches, **Then** it shows «لا توجد مباريات قادمة».
4. **Given** a competition in S2 or S3, **When** it is tapped, **Then** S8 opens with logo, name, follow, matches by date (upcoming and results) and a «حقوق البث» section listing rights holders.
5. **Given** any of the three screens opened before, **When** it is opened offline, **Then** the cached copy shows with its age. **Given** no cache, **Then** the no-connection state shows.
6. **Given** a match on these screens, **Then** dates group by the user's local day, an unknown kickoff shows «لم يُحدد», and an estimated live match shows no score or minute.

---

### User Story 3 - Lane B2: names the importers can't match wait in a queue instead of creating duplicates (Priority: P3)

As an editor, names the importers can't match wait in a queue instead of creating duplicates.

B2 adds the `yallakora` fixtures adapter, with the Egyptian broadcaster, and the unresolved-names backend: every importer looks in the alias tables first, and anything still unmatched goes to `unresolved_names` with its match context.

**Why this priority**: It's in the done check, and the live poller depends on it: FilGoal and YallaKora name teams their own way, so a match can only be polled once it is linked to our record.

**Independent Test**: Run the adapter against saved pages, then once on the live host. Its `import_runs` row shows the counts, Egyptian broadcasters appear on matches, and an invented team name lands in `unresolved_names` with its context and creates no team.

**Read**: SD §6.6 (entity resolution, YallaKora row, safety); `docs/runbooks/imports-and-sources.md`, `source-alerts.md`.

**Acceptance Scenarios**:

1. **Given** the schedule, **When** beat runs, **Then** `yallakora` runs daily and every 6 h for today, and each run writes an `import_runs` row.
2. **Given** a saved YallaKora page, **Then** the parser is pure and tested against it. Cairo wall-clock times are stored as UTC, and the Egyptian broadcaster is stored on the match unless that field is locked.
3. **Given** a name with an alias for that source, **Then** the alias is used, for any importer and for the live poller.
4. **Given** a name with no alias and no match within its competition, **Then** one queue row holds the name, source, kind and match context. No team, competition or channel is created, and the match keeps the text name.
5. **Given** the same unmatched name in later runs, **Then** the existing row is updated, never duplicated. **Given** an entry an editor ignored, **Then** it doesn't come back.
6. **Given** YallaKora blocks or changes layout, **Then** the existing rate limit, backoff, circuit breaker, zero-items alarm and host allowlist apply.

---

### User Story 4 - Lane A: an editor clears unmatched names and maintains broadcast rights (Priority: P4)

As an editor, I clear unmatched names and maintain broadcast rights.

Lane A adds the unresolved-names queue to A13, completes run detail, and builds the A9 rights holders editor.

**Why this priority**: It's in the done check, but it needs B1's contract and B2's rows first. Until names are cleared, the affected matches stay on the honest clock estimate, so nothing is wrong in the meantime.

**Independent Test**: Over WireGuard, map a queued name to an existing team and see the next import use the alias. Create a new one, ignore another, and open a failed run and read its log, counts, errors and raw page. In A9, create a rights holder with competitions, carriages and a primary frequency, and see it in `/v1/competitions/{id}`.

**Read**: PB §10 A9, A13; admin: A13 Sources + unresolved names, A13 Run detail, A9 Rights holders.

**Acceptance Scenarios**:

1. **Given** the A13 queue, **Then** each row shows name, source, kind, match context and a suggested match with its confidence, with the actions map to existing, create new and ignore. **Given** several candidates with the same name, **Then** the editor picks one from a list, and no suggestion is applied without an editor's save.
2. **Given** map to existing or create new, **When** it is saved, **Then** the alias is written, the row leaves the queue, and the next run for that source resolves the name. **Given** ignore, **Then** the row leaves the queue and stays out.
3. **Given** a run in A13's history, **When** it is opened, **Then** run detail shows its log, counts, errors and raw page. The raw page is shown as inert text and can't run in the admin.
4. **Given** A9, **Then** an editor can drag the order and edit name, logo, competitions, and carriages (satellites, a frequency list with one primary, access, package).
5. **Given** any of these saves, **Then** it needs `If-Match`, writes `audit_log`, bumps the affected dataset version and checks the role on the server. A stale save shows the existing conflict state.
6. **Given** all new screens, **Then** they match their boards at 1440 and work at 1024, in RTL, with loading, empty and error states.

---

### Edge Cases

- **The capture finds a source unusable** (no live data in the page, or an update delay too long to be useful). B1 stops and tells the owner. SD §3's alternatives are API-Football Pro (about $19/month, which must first be recorded as a decision, constitution IX) or the clock estimate alone. Lane M, Lane A and B2's other work continue.
- **No second live match today.** The capture uses one match, and the done check needs a later one with the deployed parsers. If no later kickoff fits today, or no suitable match exists at all, the poller is built and tested against whatever samples exist and the done check moves to the next match day. That is reported rather than passed on replay alone, and no other lane is held.
- **A match is on only one source, or a source doesn't cover it.** This isn't a source failure and sends no alert. It uses the single-source rule (two polls in a row). A match on neither stays on the clock estimate.
- **One failed poll.** A source counts as down only after a set number of failed polls in a row, which the plan sets, so a brief failure doesn't drop a live match to the clock estimate and hide its score. A validation failure stops the source at once (FR-005).
- **A match can't be linked to a source because its team names are unmapped.** The names go to the queue and the match stays on the clock estimate until an editor clears them, then is polled on the next cycle.
- **More matches are live than the page cap allows.** The highest-priority competitions get pages. A tie goes to the earlier kickoff, and a match keeps its page slot until it ends, so events don't stop midway. The rest stay on list-page data and aren't reported as failures.
- **A score goes down** (a disallowed goal). This is a new score and needs the same confirmation. It never publishes on one source's word alone while the other is healthy.
- **The sources disagree on the status or minute but not the score.** FilGoal wins for status and minute; only the score is cross-checked.
- **An event appears before its score is confirmed.** The goal event isn't served until the score is confirmed, so the timeline and the score can't contradict each other.
- **Extra time and penalties.** The status follows SD §6.2.3, with penalty scores in `home_pen` / `away_pen`, confirmed like any score. If the capture doesn't include them, the parsers treat an unseen value as a validation failure, not a guess.
- **A match is postponed, cancelled or abandoned while in the window.** The status moves to that state, with the source's reason in `status_label`, and polling stops.
- **A match runs long or kickoff moves.** A match already on `feed` stays polled until it reaches a final state or kickoff + 210 min, so extra time and penalties keep their score. Past that limit it moves to the clock estimate and the owner gets one alert.
- **A problem keeps recurring within a match.** One alert per problem, then quiet until recovery, also across worker restarts and retries.
- **`TELEGRAM_BOT_TOKEN` or `TELEGRAM_CHAT_ID` is missing on VPS-2.** The poller still runs and logs each alert, and a deploy check says so. Setting them is an owner action.
- **A source blocks us.** No disguised requests and no proxies. The source is reported as failed and users stay on the other source or the clock estimate.
- **Raw page volume.** A FilGoal coverage page is about 450 KB, and polling multiplies that. The plan sizes the 5-day raw store for this, and repeated identical pages must not fill the disk.
- **Create new is used for a name that already exists under another spelling.** The existing uniqueness rules on normalized names reject it, and the editor is told to map instead.
- **A rights holder has several frequencies.** Exactly one is primary, enforced on the server as well as in the form.
- **Mapping a name doesn't rewrite past matches.** Existing rows keep their text name until the next import touches them.
- **Other parts of a linked screen.** The S8 rights rows' destination (S11.4) arrives on D7, so on D5 the rows are shown without a link to it. Follow on S7 and S8 uses the plain toggle, since the S10 sheet arrives on D8. A followed channel gets its frequency alerts from D6.

## Requirements *(mandatory)*

### Functional Requirements

#### Live data (Lane B1)

- **FR-001**: B1 MAY write the live parsers before any capture, against saved finished and scheduled pages, with any status they haven't seen failing validation. Before the done check, B1 MUST capture real live matches from both sources from VPS-2, correct the parsers and complete their status maps from them, and commit the samples as fixtures, with no personal data, plus a report covering fields, status values, update delay, the wait for the second source and any change needed to SD §6.7.
- **FR-002**: `live_scheduler` MUST run every 60 s, select matches with `kickoff_at` from now − 150 min to now + 10 min that aren't in a final state, plus matches already on `feed` with no final state up to kickoff + 210 min, and do nothing when there are none. `/v1/live` MUST serve the same set. Runs MUST NOT overlap, and only one beat runs.
- **FR-003**: `poll_live` MUST read FilGoal for status, minute, score, events and lineups, and YallaKora to confirm goals and for stats where filled in. It MUST request a list page every 60 s at most for every linked match, and open a match's page only while that match is live or has changed, for at most N matches per cycle per host, chosen by competition priority. The capture and the plan set N, as a setting that needs no code change.
- **FR-003a**: A match without an opened page MUST still get real status and score from the list pages if they carry them, under the same cross-check, and has no events or lineups until it gets a page. If the list pages don't carry them, it stays on the clock estimate. This updates SD §6.7's Requests rule, which is reworded to match.
- **FR-004**: A new score MUST be published only as SD §6.7's table says: both sources agree; or, with one source down, invalid or not covering the match, the remaining source shows it in two polls in a row. After the capture's wait without agreement, the last confirmed score stays and the owner is alerted.
- **FR-005**: Every source response MUST be validated for expected fields and known status values. A failure MUST stop that source being used until it passes again.
- **FR-006**: If both sources are down or invalid, the match MUST fall back to the clock estimate, with `estimated: true` and no score or minute in the API.
- **FR-007**: Format changes, source failures, disagreements, both sources down and recovery MUST alert the owner on Telegram through `app/adapters/alerts.py`, with a reference to the saved raw page, once per problem until recovery.
- **FR-008**: Each write MUST bump the `live` dataset version, and `/v1/live` MUST be rebuilt at most every 15 s and served to all clients from the shared cache.
- **FR-009**: A manual status MUST win until cleared, and the poller MUST NOT write any field in `locked_fields`.
- **FR-010**: Event diffs MUST be idempotent on `(match_id, source, external_id)`. An event the source removes MUST leave what clients are served.
- **FR-011**: `MatchDetail.events` and `MatchDetail.lineups` MUST be filled from stored data, and MUST stay empty or null when the source has none, so that S3's live center can cope with missing data (PB O7).
- **FR-012**: The poller MUST NOT request any path in either site's `robots.txt`, disguise its requests or evade blocks with proxies, and MUST store structured facts only, never FilGoal's written commentary.
- **FR-013**: The poller's sources MUST use the existing safety controls: host allowlist, per-host rate limits shared with B2's `yallakora` adapter, exponential backoff with jitter on 429, 403 and 5xx, a zero-items alarm when a list page has no matches while one is in the window, size caps, timeouts and retrying tasks.
- **FR-014**: The poller MUST NOT write goal, kickoff or full-time `notification_outbox` rows on D5. Those producers arrive with D6's copy and preferences. It MUST keep what D6 needs to write each confirmed goal once.

#### Contract (Lane B1)

- **FR-015**: B1 MUST add the tables in the Contract row as one Alembic revision after `0006`, with a tested downgrade, and export both OpenAPI documents, regenerating both clients unedited in the same PR. Changes MUST be non-breaking for builds at or above `min_supported_build`.
- **FR-016**: `GET /v1/channels/{id}`, `/v1/teams/{id}` and `/v1/competitions/{id}` MUST return everything S6, S7 and S8 need, with ETags: for channels, carriage, other carriages, 7 days of upcoming matches and recent frequency changes (empty until D6); for teams, upcoming and recent matches; for competitions, matches by date and rights holders. Lists that can grow MUST be bounded or paginated.
- **FR-017**: B1 MUST add the admin endpoints for the unresolved-names queue (list, map to existing, create new, ignore) and rights-holder CRUD with ordering, each with a role check, `If-Match`, `audit_log` and a version bump.
- **FR-018**: The match stats storage MUST be designed in this spec's plan from what the capture shows. If YallaKora doesn't fill stats in usefully, the plan records that and doesn't add it.

#### Importer and resolution (Lane B2)

- **FR-020**: A `yallakora` adapter MUST implement `SourceAdapter`, with a pure parser tested on saved pages, run daily and every 6 h for today, and store Egyptian and Arab fixtures with the Egyptian broadcaster.
- **FR-021**: Entity resolution MUST normalize the name, try an exact alias, then disambiguate within the competition, as SD §6.6 says, for all importers and the live poller. It MUST NOT guess beyond those rules.
- **FR-022**: Anything unmatched MUST go to `unresolved_names` with its source, kind (team, competition or channel) and match context, one row per name per source and kind, and MUST NOT create an entity. The match keeps the text name.
- **FR-022a**: A source's match MUST be linked to ours only when both teams resolve and the kickoffs are within 45 min (SD §6.6's cross-source rule). A row with no time of its own, as FilGoal's is once a match starts, MUST instead fit exactly one match inside the poll window (found on 2026-11-05). With one team unresolved, it MUST NOT be linked, because a wrong link would publish another match's score; the unresolved name is queued and the match stays on the clock estimate.
- **FR-023**: Importers MUST NOT write fields in `locked_fields`, and MUST upsert by `(source, external_id)`.

#### Admin (Lane A)

- **FR-030**: A13 MUST show the unresolved-names queue as drawn on its board: a source filter, a suggested match with confidence, a candidate picker for shared names, and map to existing, create new and ignore. A suggestion only pre-fills the form; it MUST NOT write an alias without an editor's save (constitution II). A13 MUST also show the board's single Live poller card.
- **FR-031**: A13's run detail MUST show the log, counts, errors and raw page, with the raw page shown as inert text.
- **FR-032**: A9 MUST provide drag order and an editor with name, logo, a competitions multi-select, and carriages with satellites, a frequency list with one primary, access and package.
- **FR-033**: Lane A's screens MUST use only generated clients and schemas, tokens and components from the design package, and MUST be checked against their boards.

#### App (Lane M)

- **FR-040**: S6 MUST open as a sheet on the phone from S3's channel rows, with the content in PB S6, a frequency readout that stays visible with no tap, and other carriages ordered with My satellites first and free first. The desktop pane is later.
- **FR-041**: S7 MUST have upcoming and results tabs, follow, and the PB empty state, reachable from S3's hero and from S9; a row in S2 keeps opening S3, so the answer stays one tap away.
- **FR-042**: S8 MUST have matches by date, follow and the rights section, reachable from S2 and S3. Hide/show arrives with S15's competition controls on D8.
- **FR-043**: The three screens MUST use drift-backed stale-while-revalidate repositories, show cached data's age, use the existing components, render RTL with LTR islands and Western digits, and be checked against their PNGs in both themes.
- **FR-044**: Follows from these screens MUST use the existing follow set and server mirror.
- **FR-045**: `live_center` MUST stay off in Remote Config until D6's UI lands; the app reads no feature flag yet, so D5 adds no flag code and builds no live center. SD §5.1's example value (`true`) doesn't apply on D5. Real scores and minutes still show on existing screens through `/v1/live`.

#### Load-test carry-over from 004 (owner, B1, B2 if needed)

- **FR-060**: The owner MUST check the OCI account's limits page for the Ampere A1 Always Free allowance. If 4 OCPU is confirmed free, the owner resizes VPS-1 to 2–3 OCPU, at $0, and the runbook records the steps. SD §2 and §7.1 are updated to the confirmed allowance and shape.
- **FR-061**: B1 MUST re-run the load test by `docs/runbooks/load-testing.md` after the resize, against 004's targets: `/v1/live` at 170 requests/s and `/v1/matches` at 50 requests/s for 10 minutes each, p95 under 150 ms from cache and under 400 ms uncached, fewer than 1 % errors. The result is added to the Re-runs section of `docs/load-tests/2026-11-03-mvp.md`, and the exempt-IP allowlist is confirmed empty afterwards.
- **FR-062**: If the limit isn't confirmed or the re-run still fails, B2 MUST build the Caddy `/v1/live` cache (SD §11) and B1 MUST re-run the test. The cache MUST keep `/v1/live` within the 45 s budget, keep `ETag` and `304` behaviour for clients, and stay $0 and `linux/arm64`. If the resize passes, this work isn't done.
- **FR-063**: The live poller's rollout MUST NOT be held for this carry-over, since it adds no client traffic on its own, but the public link MUST NOT be announced until a run passes.

#### All lanes

- **FR-050**: `tasks.md` MUST have `## Lane B1`, `## Lane B2`, `## Lane A`, `## Lane M` and `## Done check`, the Done check copied word for word from Appendix A, row 005.
- **FR-051**: Each lane MUST change only its own folders and tick only its own section. B1's live readers and poller live outside `backend/app/adapters/` (B2's folder) and may use its shared fetcher, raw store, rate limiter and alerts; a change those shared parts need is B2's task. Generated files are never edited by hand.
- **FR-052**: Tests come first for parsers, the cross-check rules, status changes and resolution. Parsers MUST be tested against real saved pages, finished and scheduled at first and then captured live pages, never hand-written samples.
- **FR-053**: No secret MUST be committed.
- **FR-054**: Every changed operated part (the live poller and its alerts, the `yallakora` source, the unresolved queue) MUST add or update its runbook in the same change, including what to do for each new alert in the on-call page, and each lane adds its D5 items to `docs/owner-actions.md` when it finishes.

### Key Entities *(include if feature involves data)*

- **Live capture**: dated samples of both sources across a real match, with a report that confirms the parsers' fields and status values and sets the cross-check wait.
- **Source reading**: what one source reported for one match in one poll, valid or not. It is kept only as long as the cross-check needs it, and it is never served to clients.
- **Match event**: a goal, own goal, penalty, missed penalty or red card, with side, minute, player and source. Unique per match, source and external ID.
- **Match lineup**: formation and players per side, where the source has them.
- **Match stats**: figures per match where YallaKora fills them in. The plan designs its storage.
- **Alias**: a source's normalized name for one team, competition or channel.
- **Unresolved name**: a name no rule could match, with source, kind, match context, state (open, mapped, created, ignored) and who cleared it.
- **Rights holder**: a broadcaster with its order, logo, competitions and carriages, one frequency marked primary. These tables already exist.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For at least one real live match on the deployed hosts, status and score in the app match the broadcast from kickoff to full time, and no unconfirmed score is shown at any point.
- **SC-002**: Replaying the capture and the failure cases (one source down, both down, disagreement, changed format, recovery) gives the outcome in SD §6.7's table in 100 % of cases, each with one alert at most per problem.
- **SC-003**: A changed source format publishes 0 wrong scores in the test suite.
- **SC-004**: On a day with no match in the window, neither live source receives any request.
- **SC-005**: A confirmed score reaches the app within 45 s of its confirmation. The time from a source first showing it to confirmation isn't counted, and is recorded in the capture report.
- **SC-006**: A YallaKora run completes on the live host, and 100 % of its unmatched names are in the queue with 0 new teams, competitions or channels created by it.
- **SC-007**: An editor clears a queued name in under 1 minute, and the next import resolves it.
- **SC-008**: On a real Android phone, a fan reaches S6 in two taps from S3 (expand a carriage row, then «عرض القناة»), S7 in one tap from S3 and S8 in one tap from S2 or S3, and a channel's frequency is visible on S3's row and on S6 with no tap.
- **SC-010**: A re-run of the load test at 004's targets passes on the deployed VPS-1, with its result committed.
- **SC-009**: The day's **done check** passes, word for word from delivery-plan Appendix A: *"A real live match updates status and score from FilGoal, cross-checked with YallaKora (O7); YallaKora imports; unresolved names visible in the admin; S6, S7, S8 on a device"*.

## Assumptions

- **The uncommitted O7 doc edits are part of this spec.** The four changed docs carry over to the spec branch, uncommitted. They should be committed before lanes branch from `master`, because lane worktrees are created from `origin/master` and won't see them otherwise.
- **The live budget counts from confirmation (owner's decision, Clarifications).** Constitution VIII and SD §11 say live score → client ≤ 45 s, and SD §11 computes that as source poll + 15 s cache. The cross-check adds delay: it waits for the second source, or for a second poll when one is down. The 45 s therefore starts at confirmation (SC-005), and the wait before it isn't counted. The capture measures and records that wait and the first-source-to-client delay. Constitution VIII (now 1.3.0) and SD §11 are reworded to match.
- **The load-test fix is D5 carry-over (owner's decision, Clarifications).** 004's load test failed on 2026-11-03: `/v1/live` p95 ≈ 5 s against a 150 ms target, with VPS-1's one core saturated. The fix follows FR-060–FR-063. A larger VPS-1 is the first choice because the report found the cost is the Python request path, cache hits included. SR-2, T071, T072 and the public announcement stay open with the owner and aren't D5 work.
- **O7 is decided pending the capture**, and the owner accepts the risk of terms not yet read (SD §3, R1). FilGoal and YallaKora's terms aren't reviewed in this spec.
- **No push from the poller on D5** (FR-014). SD §6.7 lists outbox rows as the poller's job, but the D5 brief doesn't, and D6's brief adds the `match_started`, `goal` and `final_score` producers with copy and preferences. D5 fans see scores in the app and get no goal push yet.
- **Frequency history has no data until D6**, whose revision adds `channel_frequency_changes`. S6's section is built and hidden while empty.
- **Live readers don't implement `SourceAdapter`** (constitution VII, as amended in 1.3.0, which also adds the 210-minute limit). They keep its other rules.
- **The poller's owner is B1** (brief), including its live readers. `backend/app/adapters/` remains B2's (FR-051). B2's resolver is shared by the poller, so its interface is agreed in the plan, and B1 tests against it from the morning.
- **Live source health appears in A13 as one Live poller card**, as on the board, with alerts naming the source at fault. The plan decides how polls are recorded so that `import_runs` stays useful at one poll a minute.
- **Raw pages reach the admin through the admin API.** They are stored on VPS-2 and the admin API runs on VPS-1, so the plan decides how run detail reads them.
- **Football only.** Other sports stay on sporteventz (D6) and the sport switcher (D7).
- **Owner steps:** check the OCI limits page and resize VPS-1 first (FR-060); set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` on VPS-2 if missing; review the migration and contract; watch a live match for the done check; check S6–S8 on a phone; start the AdMob app and consent setup (delivery-plan D5, separate from this spec's code).

### Out of scope (later days)

- **D6:** all push types, including goal pushes; the live center UI (timeline, lineups, score animation); frequency-change detection and history; `sporteventz`, API-Football; turning `live_center` on.
- **D7:** S11 rights screens, S14 search, team and channel merge tools, retiring the Firestore bridge.
- **D8:** S10 follow sheet, S15 competition order and hide.
- **V2:** the S6 report action.
- **Later:** the S6 desktop pane.

### Dependencies between lanes today

- B1's capture needs a real live match, so check the day's fixtures first. Parser and contract work don't wait for it; completing the parsers does.
- B1's contract PR merges first; Lane A and Lane M generate their clients from it, and B2 rebases on the revision.
- B1's poller needs B2's resolver and aliases to link matches; they agree the interface in the plan.
- B1's readers and B2's `yallakora` adapter share one rate limit for the YallaKora host.
- Lane A's queue needs B2's rows to show real data; until then it runs against the mock.
- Lane M needs only B1's contract.
- B1's load re-run needs the owner's resize. B2's Caddy cache starts only if the limit isn't confirmed or that re-run fails.
