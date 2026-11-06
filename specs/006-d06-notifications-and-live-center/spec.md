# Feature Specification: D6 · Notifications and live center

**Feature Branch**: `006-d06-notifications-and-live-center` (lane branches `d06-b1`, `d06-b2`, `d06-a`, `d06-m`)

**Created**: 2026-11-06

**Status**: Draft

**Input**: User description: "lets start d06". Scope is the brief "D6 · 006-d06-notifications-and-live-center" in `docs/delivery-plan.md` Appendix B. The done check is catalog row 006 in Appendix A: a goal push arrives with the correct score; the live center shows events; a frequency change pushes to followers; the admin composer sends a test push; the audit diff is visible.

| | |
| --- | --- |
| Goal | Every push type works and a live match has a timeline |
| Phase | V1 (delivery-plan §6) |
| Starts from | 005 and its follow-up 031, both merged to `master`. Their open owner items stay open in `docs/owner-actions.md` (see Assumptions) |
| Contract | One expand-only revision; the next free number is `0009` (the brief's `0004` is stale): `channel_frequency_changes`, plus what FR-023 to FR-025 and FR-031 need. Notification prefs stay in `devices.prefs` (stored since D3), and gain a master switch. Outbox producers for all SD §6.8 types. Public: `ChannelDetail.recent_frequency_changes` filled; other sports kept off football reads (FR-022). Admin: outbox log, composer, test send, admin users, audit log + diff |
| Flags | `live_center`, `lineups` (both off in the bundle; on for testers through Remote Config) |
| Implements | SD §6.6 (sporteventz and API-Football rows), §6.7 (goal push bar), §6.8 · PB §9 S3 live center, S5.2 badge, S6 history, S15 notification group · PB §10 A8 history, A15, A16, A17 · PB §11 · spec 031 FR-019 |

Shorthand: **SD** = `docs/system-design.md`, **PB** = `docs/product-business.md`, **app:** / **admin:** = a board in `madar-design/app-flutter/SCREENS.md` / `madar-design/admin-react/SCREENS.md`.

## Clarifications

### Session 2026-11-06

- Q: The new pushes start on D6, but S15's switches were planned for D8. Should they move? → A: Yes. S15's notification group ships on D6 (master switch, per-type switches, platform state). The S10 sheet and the lead-time control stay on D8 (FR-063).
- Q: What happens when a goal that was pushed is reversed? → A: One correction push under the `goal` switch, titled «تصحيح النتيجة», with the corrected score and no reason given, replacing the wrong notification through the match tag (FR-009).
- Q: Where do sporteventz's team and competition names go, with no other-sport teams in the catalog? → A: They stay as text on the match, with no team or competition rows and no queue entry. The plan records this as an exception to constitution II (FR-032).
- Q: Who gets the new automatic pushes the first time they're deployed? → A: Every follower, from the first deploy. There is no test-devices-only stage, and the off switch in FR-021 is the safeguard.
- Q: How long should a channel or frequency change wait before its push goes out? → A: 5 minutes for both (FR-011, FR-014).
- Q: Should A17 get the board's restore-previous-value button? → A: No. A17 stays read-only on D6, and each entry links to the entity's editor (FR-045).
- Q: How should the owner hear about pushes that fail? → A: One Telegram alert per problem, when a push ends `failed` or more than 20 % of a send's devices fail, then quiet until it recovers. Dead tokens don't count (FR-029).
- Q: Is the new Arabic copy for PB §11 and S3 approved? → A: Yes, as drafted (see Assumptions; FR-006, FR-009, FR-012, FR-060).
- Q: Should `final_score` go out for a match the system finishes at the limit in SD §6.7? → A: No. The sources have gone quiet by then and a push can't be taken back, so the app shows the finish, the owner gets the alert, and followers hear only if an editor then finishes the match by hand (FR-007).
- Q: Should automatic pushes wait until the new PWA is out, since builds in the field navigate when a push arrives in the foreground? → A: No. They start for every follower from the first deploy, PWA users included, on whichever build they have (FR-021). The owner weighed this against holding them back and chose not to wait. The new PWA follows as soon as Lane M finishes. See Assumptions for what it means until a device updates.
- Q: With three sources, is two agreeing enough for a goal push when the third is slower or shows less? → A: Yes. Two of three is enough (FR-004).
- Q: Can changing your own password go without `If-Match`, since it already proves the current password? → A: Yes. It's the one exception in FR-024, recorded in the plan's Complexity Tracking.

## User Scenarios & Testing *(mandatory)*

The four stories are the four lanes of the day (delivery-plan §4). Each lane can be built and tested on its own against the agreed contract.

### User Story 1 - Lane B1: a follower gets each kind of alert they asked for, once, with the right copy (Priority: P1)

A fan follows a team, a match or a channel and hears about what matters: the goal, the final score, a new channel before kickoff, a changed frequency. Each alert arrives once, reads correctly in Arabic and opens the right screen. A goal that one source may have got wrong doesn't go out.

**Why this priority**: The kickoff reminder is the only push today, while S1.4 and S16 already promise goals, final scores and frequency changes. The done check's first and third items depend on it.

**Independent Test**: With a fake sender, replay the 2026-11-04 capture through the producers: every real goal gives one message with the right score, and Mouloudia Alger's false 2–0 gives none. Save a changed frequency through the admin API and see one history row and one message to that channel's followers.

**Acceptance Scenarios**:

1. **Given** a followed match, **When** one source shows a higher score and a second source then shows it, **Then** followers of the match or either team get one goal push with the score at that moment.
2. **Given** one source shows a higher score and no other source covers the match, **When** it has shown that score without a break for 3 minutes, **Then** the goal push goes out. **Given** a usable source shows a lower score and no second source agrees with the higher one, **Then** no push goes out while it does (spec 031 FR-019).
3. **Given** the scorer or minute isn't known when the bar is met, **Then** the push goes out without them, with nothing invented and no waiting for them.
4. **Given** a device follows the match and both teams, **Then** it gets one message per event.
5. **Given** a device turned `goal` off, **Then** it gets no goal push and still gets its other alerts. **Given** a device with no stored prefs, **Then** it gets SD §6.8's defaults, so `match_started` stays off for it.
6. **Given** a match goes live from the feed, **Then** devices that turned `match_started` on get one push. **Given** a clock or manual status, **Then** no push goes out.
7. **Given** a match reaches `finished` with a real score, **Then** `final_score` goes out once. **Given** a clock-estimated finish, a finish at the limit, or `abandoned`, `postponed` or `cancelled`, **Then** nothing goes out.
8. **Given** a kickoff within 6 h, **When** an editor adds three channels in two saves a few minutes apart, **Then** followers get one `channels_updated` push naming a channel on their own satellites if there is one, and counting the rest.
9. **Given** an editor changes a carriage's frequency in A8, **Then** screens show the new value at once, and after the hold a history row is written, `frequency_changed_at` is set, and followers of that channel get one push showing the new and old readouts.
10. **Given** an editor fixes a mistyped frequency within the hold, **Then** followers get one push with the corrected value. **Given** the value went back to where it was, **Then** there is no push, history row or badge, and A17 still shows both saves.
11. **Given** the workers were down, **When** they come back, **Then** a goal push that is too old is cancelled instead of sent (FR-019).
12. **Given** the producers are switched on while matches are in play, **Then** no push goes out for goals accepted before that.
13. **Given** every type in PB §11, **Then** its message matches the catalog, with each name and readout isolated, each score beside its team, and Western digits.
14. **Given** a goal was pushed, **When** the accepted score falls under the drop rule, or an editor lowers it, **Then** devices with `goal` on get one «تصحيح النتيجة» push with the corrected score, replacing the wrong one. **Given** the score falls before any goal push went out, **Then** nothing is sent.
15. **Given** a device turned the master switch off, **Then** it gets no push of any type, and turning it back on restores its earlier per-type choices.

---

### User Story 2 - Lane M: a fan watching a match sees goals and cards as they happen (Priority: P2)

A fan on S3 during a match sees the timeline fill up without leaving the screen, the score draws the eye when it changes, and the lineups appear when the source has them. When there's no feed the screen says so honestly, and the answer to "where do I watch" stays where it was. In Settings, the same fan chooses which alerts they get.

**Why this priority**: It is the visible half of the day, and D5's live data has nowhere to show until it exists. The switches give fans control from the day the new pushes start. It needs only B1's contract.

**Independent Test**: With `live_center` on and a stubbed match, S3 shows the timeline and lineups as on the boards. With the flag off, or with no feed data, S3 looks as it does today. Changing a switch in S15 sends the new prefs to the server, and they survive a restart.

**Acceptance Scenarios**:

1. **Given** `live_center` is on and a match has stored events, **Then** S3 shows them newest first while live and in order once finished, with minute, player and side, home on the right, with period markers as on the board (app: S3 Live match).
2. **Given** an own goal, a penalty, a missed penalty or a red card, **Then** each shows its label («عكسي», «ركلة جزاء», ...), and a red card uses `error`, never `live`.
3. **Given** an event with no player, **Then** the row shows its type and minute only.
4. **Given** a fan is on S3, **When** the score rises, **Then** the score is highlighted once. **Given** reduced motion, **Then** it changes with no animation. **Given** the score falls, or the screen has just opened, **Then** there is no highlight.
5. **Given** a new event is stored, **When** the fan stays on S3, **Then** the timeline shows it within the time in SC-006.
6. **Given** the score shows 2–0 and only one goal event is known, **Then** the known goal row shows no running score, and no row is invented.
7. **Given** `lineups` is on and lineups exist, **Then** a التشكيل tab appears (app: S3 Live center — lineups). **Given** there are none, or the flag is off, **Then** there's no tab.
8. **Given** an estimated status, **Then** there is no timeline, score or minute, and a note says the score isn't available.
9. **Given** a match with no feed data, or `live_center` off, **Then** S3 shows no live center and no empty frame.
10. **Given** a fan taps a frequency push, **Then** S6 opens for that channel. **Given** a channel push, **Then** S3 opens at its channels. **Given** a route the app doesn't recognise, **Then** the app opens normally and goes nowhere unexpected.
11. **Given** the device is offline with a cached match, **Then** cached events show with their age and nothing presents them as live.
12. **Given** a fan opens S15's الإشعارات group, **Then** they see a master switch and a switch per type, with SD §6.8's defaults for a device that never chose. **Given** they turn one off while offline, **Then** the change reaches the server when the device reconnects.
13. **Given** notification permission is denied, **Then** S15 shows the steps to enable it. **Given** an iPhone browser where the app isn't installed, **Then** it links to S1.5 instead of offering switches that can't work.

---

### User Story 3 - Lane A: an admin sees what was sent, sends an announcement, and sees who changed what (Priority: P3)

The admin checks whether last night's goal pushes reached anyone, tests an announcement on their own phone and schedules it, adds an editor without touching a server, and answers "who changed this frequency?" with a side-by-side diff.

**Why this priority**: It closes the operating loop for pushes and replaces the CLI for staff accounts. Two done-check items live here, but fans notice nothing if it slips a day.

**Independent Test**: Against the mock, then the real API on `wg0`: the log, composer, users and audit screens work end to end and match their boards; an editor is refused the admin-only parts by the server and doesn't see them in the UI.

**Acceptance Scenarios**:

1. **Given** the log (admin: A15 Notifications), **Then** each row shows type, target, recipients, succeeded, failed, time and status with its reason, and can be filtered by type and status.
2. **Given** an admin writes an announcement, **Then** they pick a deep link from a match or channel picker, choose all devices or followers of something with a reach estimate, choose now or a time, and see Android and iPhone previews.
3. **Given** an admin taps «إرسال تجريبي لجهازي», **Then** only their saved test device gets it, whatever its prefs, the composer says which device, and the log marks it as a test.
4. **Given** a scheduled announcement that hasn't gone out, **When** the admin cancels it, **Then** it never sends and the log shows it cancelled.
5. **Given** an admin sends to all devices, **Then** a confirmation showing the reach comes first.
6. **Given** an editor, **Then** they can read the log but can't compose, and A16 and A17 are hidden and refused by the server.
7. **Given** an admin creates an account (admin: A16 Admin users), **Then** a generated temporary password is shown once with a copy button, and the new user must change it at first login before doing anything else.
8. **Given** an admin deactivates an account or resets its password, **Then** its sessions end at once. **Given** an admin tries to deactivate or demote themselves or the last active admin, **Then** it is refused with a clear message.
9. **Given** the audit log (admin: A17 Audit log + diff), **Then** it filters by user or importer, entity and period, and an entry shows both sides. An entry that caused a push links to it, with its counts.
10. **Given** two admins edit one account, **When** the second saves, **Then** the common conflict dialog appears.

---

### User Story 4 - Lane B2: other sports and fill-in fixtures arrive without hitting free-tier limits (Priority: P4)

Other-sport events and their broadcasters are collected ready for D7's sport switcher, and API-Football fills the gaps in fixtures without ever passing its daily allowance. Football fans notice nothing today.

**Why this priority**: No fan sees sporteventz data until D7 and API-Football only fills gaps, so it can slip without hurting the day's goal. Appendix A checks the live imports on 007.

**Independent Test**: From saved pages and responses: sporteventz produces other-sport matches and broadcaster entries, a re-run changes nothing, and football lists are untouched. API-Football stops at its budget in a simulated day, and does nothing without a key.

**Acceptance Scenarios**:

1. **Given** saved sporteventz pages, **When** the adapter runs twice, **Then** each event is one match with its own sport and broadcaster entries, with no duplicates.
2. **Given** an editor saved a match's broadcaster entries, **When** the importer runs, **Then** they stay as the editor left them.
3. **Given** other-sport events are stored, **Then** a client that doesn't ask for a sport sees football only, in lists and in `/v1/live`, and the live poller never polls them.
4. **Given** API-Football reaches its daily budget, **Then** no further request goes out that day, the run says why in A13, and neither the breaker nor the zero-items alarm fires.
5. **Given** the counter can't be read, **Then** no request goes out.
6. **Given** no key is set, **Then** the source shows as not configured, sends nothing and raises no alarm.
7. **Given** the provider reports an error inside a successful response, **Then** the run counts as failed, not as zero items.
8. **Given** an API-Football fixture with a name no alias matches, **Then** the name goes to the unresolved queue and no team or competition is created.
9. **Given** a sporteventz run, **Then** its team and competition names stay as text on the match, and the unresolved queue doesn't grow.

---

### Edge Cases

- **A pushed goal is later reversed.** The 5-minute drop rule (SD §6.7) can undo a goal that met the bar, for example one the referee disallows. One correction goes out (FR-009), and it says nothing about why, because the system doesn't know.
- **Two goals between polls.** One team going 0–0 to 2–0 is one push with the latest score. Both teams scoring gives one push each. Pushes for a match replace each other on the device (tag `match_<id>`).
- **A goal lost and scored again.** 1–0, back to 0–0, then a real 1–0: the second goal still pushes, so the key can't be the score alone.
- **Sources disagree on the minute.** One goal must not push twice because sources say 23′ and 24′, so the key can't rest on the minute, as SD §6.8's example `goal:48213:23:home` does.
- **Own goal.** The push credits the team whose score rose, and marks the scorer «عكسي».
- **Penalty shootout.** Shootout kicks send no goal push. `final_score` adds the shootout result when it's known.
- **A score changes after `final_score`.** No second final push. If the score that was pushed falls, FR-009's correction goes out, with the 2-hour limit in FR-019.
- **A manual status or score holds.** No goal or start push while it does, because the feed's score isn't accepted then. An editor's score edit isn't a goal. An editor's manual finish with a score does send `final_score`, and an editor lowering a score below what was pushed does send FR-009's correction.
- **A match finished at the limit** (kickoff + 150 or + 210, SD §6.7). No `final_score` goes out, because the sources have gone quiet and the last score may be wrong. The app shows the finish as spec 031 decided, and the owner gets an alert. An editor who checks the score and finishes the match by hand sends it.
- **Hidden channels.** A placeholder, a hidden name or a deleted channel never triggers `channels_updated`, because fans can't see it on S3.
- **A channel that an importer drops and re-adds.** At most one push per direction, per channel, per match.
- **Channels added and removed within the hold.** If the net change is nothing, no push goes out.
- **The first channels for a match with none.** S3 promises «تابع المباراة وسننبهك عند إضافتها», which can fall outside the 6-h window. That one push goes to the match's own followers at any time before kickoff, not to team or competition followers, who could get dozens during a first import.
- **A frequency that is empty or a note.** Empty to filled, filled to empty, and note-only carriages (`UHF 32`) aren't changes: PB §11's copy needs both readouts.
- **A channel moved to another satellite.** With a new tuning it counts, and the copy names the new satellite. With the same tuning it doesn't count.
- **A big announcement while goals are going in.** A send of any size must not delay live pushes (FR-020).
- **A scheduled time in the past.** Refused. The admin picks times in their own zone, and they are stored in UTC.
- **A failing send.** A row that ends `failed` keeps its reason for the log (`FCM 503`).
- **Old audit rows.** Diffs written since D2 aren't all one shape. A shape A17 doesn't know shows raw on both sides and never breaks the screen.
- **Snapshot rows.** Rows loaded from the old app with a sporteventz ID are labelled `football`, because the loader sets it on every row (FR-033).
- **Other sports on the dashboard.** They carry broadcaster entries, not channel links, so A2's "matches without channels" must not count them.
- **A lineup with no positions.** S3 falls back to two lists instead of guessing a pitch.
- **Timeline and score out of step.** The score can move before its event arrives from the match page, which is honest. The timeline simply catches up.

## Requirements *(mandatory)*

### Functional Requirements

#### Lane B1: producers

- **FR-001**: Each automatic SD §6.8 type (`match_started`, `goal`, `final_score`, `channels_updated`, `frequency_changed`) MUST have a producer that only inserts `notification_outbox` rows with a unique `dedupe_key` (constitution VII). A row MUST exist only if the state change behind it was saved. Retries, overlapping polls and restarts MUST NOT create a second message for one event.
- **FR-002**: Switching a producer on MUST push nothing for state that already exists: matches in play keep their score with no goal push, and frequencies aren't backfilled.
- **FR-003**: `match_started` MUST go out once, the first time a match's status becomes live with `status_source = feed`, and only within 15 minutes of kickoff, so a match first linked at 30′ doesn't announce a start. Clock and manual statuses MUST NOT send it.
- **FR-004**: `goal` MUST use the bar in spec 031 FR-019 and SD §6.7, judged per goal: a side's value that at least two sources now show, or, when only one source covers the match, a value that source has shown without a break for 3 minutes. A rise a usable source contradicts by going lower MUST NOT push on one source's word; with three sources, two agreeing is enough. The bar MUST be judged from saved state on every poll, so a restart loses no goal ([research R1](research.md#r1-the-goal-bar-judged-per-goal)).
- **FR-005**: There MUST be one `goal` message per team per rise, carrying the score that met the bar, which can be behind the score the app shows while a false goal is being held. The dedupe key MUST NOT depend on the minute, and MUST let a goal scored again after a reversal push.
- **FR-006**: `goal` copy MUST include the scorer and minute only when a stored event has them, and MUST NOT wait for them. An own goal credits the team whose score rose and marks the scorer «عكسي». Shootout kicks MUST NOT push. While a manual status or score holds, no goal MUST push.
- **FR-007**: `final_score` MUST go out once, the first time a match reaches `finished` with a real score from the feed or from an editor's manual finish, including a manual finish over one at the limit. A finish at the limit in SD §6.7, a clock-estimated finish, `abandoned`, `postponed` and `cancelled` MUST NOT send it. A shootout result is added when known.
- **FR-008**: The poller's push rows MUST NOT change what fans see or when. The score rule in SD §6.7 stays as it is.
- **FR-009**: When the accepted score falls below a score that was pushed, whether under the drop rule or because an editor lowered it, live or finished, one correction MUST go out per reversal, to the same audience, under the `goal` switch and the tag `match_<id>`, opening S3. Its title is «تصحيح النتيجة», and its body is the corrected score, built like any other score. It MUST NOT give a reason. If no goal or final push carried the higher score, nothing is sent. A goal scored afterwards pushes as normal.
- **FR-010**: `channels_updated` MUST go out when a link fans can see on S3 is added or removed, from kickoff − 6 h until the match reaches a final state, to followers of the match, team or competition. It MUST NOT go out for a match with no known kickoff. As an exception, a match's first visible channel pushes at any time before kickoff, to that match's own followers only.
- **FR-011**: Channel changes for a match MUST be held for 5 minutes and sent as one push. If the net change is nothing, nothing MUST be sent. The message MUST name a channel on the device's satellites first, then Nilesat or Badr, then any, with free channels first, as the reminder does.
- **FR-012**: `channels_updated` copy MUST follow PB §11. The added-and-more and removed cases, which the catalog doesn't cover, use the approved copy in Assumptions.
- **FR-013**: A carriage's frequency, polarization and symbol rate MUST be compared in one place that every writer of those values goes through. A difference between two complete sets MUST start the hold in FR-014. No importer writes these values today, so A8's save is the only live path, and an importer that starts to MUST use the same place. The snapshot loader MUST NOT count as a change.
- **FR-014**: A frequency change MUST be held for 5 minutes. Screens show the saved value at once. When the hold ends, the value last announced is compared with the current one. If they are equal, nothing is recorded or sent. Otherwise the system MUST write one `channel_frequency_changes` row with old values, new values, source and time, set `channels.frequency_changed_at`, and send one `frequency_changed` message showing both to the channel's followers. A later change is a new event and pushes again. A17 keeps every save either way.
- **FR-015**: `GET /v1/channels/{id}` MUST return `recent_frequency_changes`, and the admin channel read MUST return its history, so S6 and A8 have data.
- **FR-016**: The composer MUST create an `announcement` row through the same outbox, for all devices or the followers of a team, competition, match or channel. A test send MUST also go through the outbox, reach only the named device, ignore its prefs and be marked as a test.
- **FR-017**: The dispatcher's audience MUST follow SD §6.8 per type, with one `SELECT DISTINCT` per page and bound parameters, and MUST honour the device's master switch and its switch for that type, using the SD default when none is stored (`match_started` off, the rest on). Team and competition follows follow SD's table, so a competition follow doesn't receive `goal`, `match_started` or `final_score`. `all` doesn't need a follow.
- **FR-018**: All copy MUST match PB §11, built from isolated parts, with each score beside its team, Western digits, and no raw `1 - 0`. `frequency_changed` uses tag `channel_<id>` and opens S6. `announcement` uses `announcement_<id>` and opens its link. Match types use `match_<id>`, and `channels_updated` opens S3 at its channels. Routes MUST stay safe for builds already in the field.
- **FR-019**: A row too late to be true or useful MUST be cancelled, not sent: `goal` and `match_started` after 15 minutes or once the match has finished, `final_score` and a correction after 2 hours, `channels_updated` once the match has finished, and a scheduled `announcement` after 2 hours. The log shows it as cancelled.
- **FR-020**: A send of any size MUST NOT hold `goal`, `match_started` or `final_score` beyond SC-002.
- **FR-021**: Every automatic type MUST be on for all followers from the first deploy, PWA users included, with no test-devices-only stage and no wait for a new app build ([the deploy order](quickstart.md#deploy-order)). The owner MUST be able to switch any type off with a host setting and no release. While a type is off, nothing is sent and no backlog builds: its rows are cancelled at once and show in the log, and FR-002 applies when it comes back. Frequency history is still recorded. This switch is the safeguard for the first night of goal pushes, when a false goal reaches every follower, so `push-notifications.md` MUST say how to use it within a minute.
- **FR-029**: The owner MUST get one Telegram alert when a push ends `failed`, or when more than 20 % of a send's devices fail, and one more on recovery, with nothing in between (the live poller's pattern, SD §6.7). Dead tokens MUST NOT count as failures, because they are normal. Test sends and cancelled rows MUST NOT alert.

#### Lane B1: other sports on public reads

- **FR-022**: A client that doesn't ask for a sport MUST get football only from `GET /v1/matches` and `GET /v1/live`, because every build in the field asks for no sport and must keep working (constitution VI). Asking for a sport MUST return it. The live scheduler and poller MUST skip other sports. A2's "matches without channels" MUST NOT count them either (FR-039, in B1's `dashboard.py`).

#### Lane B1: admin API and contract

- **FR-023**: The admin API MUST add: the outbox log (cursor pagination; filter by type and status; recipients, succeeded, failed, time, status and failure reason per row); a reach count per audience; create, schedule and cancel an announcement; test send; save "my test device"; list, create, update and reset admin users; change my own password; audit list with filters and entry detail. Title is 1–65 characters and body is 1–180, plain text. The deep link is built by the server from a target type and ID, never accepted as text.
- **FR-024**: A role check on every route MUST enforce: composing, cancelling and test sends, and A16 and A17, are `admin` only; the log is readable by `editor` too. Mutations MUST require `If-Match` where a row exists and MUST write `audit_log` (constitution VI). The one exception is changing your own password, which proves the current password instead ([plan](plan.md#complexity-tracking)).
- **FR-025**: A new account or a reset MUST use a server-generated password of at least 12 characters, returned once, stored as argon2id only, and flagged for change. Until it is changed, every admin route except change-password MUST refuse with a stable error code. Reset and deactivate MUST revoke refresh tokens. The API MUST refuse deactivating or demoting yourself or the last active admin. No password or hash may reach a log or an audit row. The CLI stays for the first admin.
- **FR-026**: The audit endpoints MUST be read-only, name importers as actors, and link an entry to the outbox row it caused, when there is one.
- **FR-027**: B1 MUST add one expand-only revision with a tested downgrade, export both OpenAPI documents and regenerate both clients unedited in the same PR. `/v1` changes stay non-breaking for builds at or above `min_supported_build`.
- **FR-028**: Tests written first MUST cover: each producer's trigger and dedupe, the bar replayed on the 2026-11-04 capture, the correction after a reversal, the audience per type with the master switch, prefs and defaults, frequency comparison, holds and stale rules, exact copy per type with isolates and digits, and every admin endpoint as a contract test against real PostgreSQL.

#### Lane B2: sporteventz

- **FR-030**: A `sporteventz` adapter MUST run every 6 h for today to +3, reading basketball, handball, volleyball and tennis, and skip and count any other sport. It MUST write matches with their own sport, source names as text, UTC kickoffs from the source's real zone (`time_tbd` when unknown) and no logo. It MUST upsert by `(source, external_id)`. The old tool's emoji logos become NULL (constitution II, IV).
- **FR-031**: Broadcaster names MUST go into `match_custom_broadcasts`: the first in slot 1, the next in slot 2 within its 80-character label, cut at a whole name. An editor's entries MUST NOT be overwritten. `locked_fields` has no value for them today, so one is added, and A4's save sets it.
- **FR-032**: Team and competition names from sporteventz MUST stay as text on the match, with no team or competition rows and no `unresolved_names` entry. Nothing is guessed, but constitution II sends unmatched names to the queue, so the plan MUST record this in Complexity Tracking. Until these sports have a catalog, their events can't be followed by team.
- **FR-033**: Rows with a sporteventz ID labelled `football` MUST be counted on the host and corrected with a tested repair (B1's `repair-matches`), which sets a sport only from the old data and never guesses one. The adapter MUST set the sport on any row it updates. Matches aren't deleted. Upsert and merge MUST compare sport, because today they force `football` and can merge rows across sports.

#### Lane B2: API-Football

- **FR-034**: An `api_football` adapter (the source name seeded since `0001`) MUST only fill in fixtures and IDs other sources lack, going through the same resolve, upsert and cross-source merge. It MUST create a match only when both teams and the competition resolve, and MUST NOT overwrite another source's fields, because its English names would otherwise make duplicates against the Arabic catalog. Only allowlisted leagues reach the resolver, and their unmatched names go to the queue. It MUST NOT create teams, competitions or channels, or write locked fields, and it doesn't read lineups (SD §6.6).
- **FR-035**: A shared daily counter MUST count each request before it is sent, including retries and «تشغيل الآن», and stop at a setting (default 90 of the free 100), resetting on the provider's day. An unreadable counter means no request. Reaching the budget ends the run with that reason, and fires neither the breaker nor the zero-items alarm.
- **FR-036**: With no key, the source MUST show as not configured, send nothing and raise no alarm. The key lives only in VPS-2's `.env` and MUST NOT reach logs, raw pages or run detail. An error reported inside a successful response counts as a failure.

#### Lane B2: both importers

- **FR-037**: Both MUST implement `SourceAdapter` and have an allowed-host list, rate limits, backoff, a breaker, a zero-items alarm, an `import_runs` record, raw pages kept 5 days, `parse` tests on saved pages, a card in A13 and a beat schedule (constitution VII). Each source's `robots.txt` MUST be honoured. A run that stops on purpose (budget reached, not configured) MUST end as `stopped` with its reason, and MUST count toward neither the breaker nor the zero-items alarm. sporteventz is a low-volume source, so a valid response with no events isn't an alarm until 7 days pass without any; a changed page shape still is one at once.
- **FR-038**: Importers that add or remove a match's channel links MUST report it to B1's producer (FR-010), so a change from any importer pushes the same way as one from A4. Names written to broadcaster entries MUST pass the same length and card-sharing checks as the admin API, which importers don't get for free.
- **FR-039**: A2's "matches without channels" MUST NOT count other-sport matches. LiveSoccerTV's target list MUST skip them too.

#### Lane A

- **FR-040**: A15, A16 and A17 MUST be rebuilt from their boards with shared components and tokens, in RTL, and every API shape validated by the generated Zod schemas.
- **FR-041**: A15's log MUST show the columns and filters in FR-023, with status text that says why a row failed or was cancelled. New rows MUST appear without a manual reload while the page is open.
- **FR-042**: A15's composer MUST have live character counts, a match or channel picker, audience with reach, now or a time, Android and iPhone previews that update as you type, and an honest test-send result. Sending to all devices needs a confirmation showing the reach. A scheduled row can be cancelled until it goes out.
- **FR-043**: A16 MUST list accounts with role, status (active, temporarily locked with time left, deactivated) and last login, and create, change role, deactivate, reactivate and reset. A temporary password shows once with a copy button. The TOTP column stays as the board's V2 mark.
- **FR-044**: The login flow MUST add a change-password step for a flagged account. No board draws it, so it follows A1's form.
- **FR-045**: A17 MUST filter by user or importer, entity and period, show a side-by-side diff, and link to the entity and to the push it caused. The board's «استرجاع القيمة السابقة» MUST NOT be built on D6 (see Assumptions).
- **FR-046**: A8 MUST show a channel's frequency history (PB §10 A8).
- **FR-047**: The shell MUST hide what a role can't use. A direct address shows a not-permitted state, and the server's refusal remains the real check.

#### Lane M

- **FR-050**: The app MUST read `features` from Remote Config with bundled `live_center: false` and `lineups: false`. A bad value keeps the bundled one.
- **FR-051**: With `live_center` on and stored events or lineups, S3 MUST show the live center above «أين تشاهد», as on the boards. Otherwise S3 stays as it is today, with no empty frame.
- **FR-052**: The timeline MUST show goal, own goal, penalty, missed penalty and red card, newest first while live and chronological once finished (`EventTimeline`'s README), with minute, player and side, home on the right, and period markers. Meaning is never carried by color alone.
- **FR-053**: A goal row MUST show a running score only when the known goal events add up to the current score. Otherwise it shows none.
- **FR-054**: The hero MUST highlight a rising score while on screen, with no highlight on first paint or on a fall, and no motion under reduced motion.
- **FR-055**: While a match is live on screen, S3 MUST re-read the match when the live score, status or event count changes and at its normal polling, so the timeline meets SC-006 with no extra polling. `LiveState` gains `event_count` for this. Live values still come only from `/v1/live`.
- **FR-056**: The التشكيل tab MUST appear only with `lineups` on and data for at least one side. S3 draws a pitch only when formation and positions are usable, and otherwise two lists.
- **FR-057**: An estimated status MUST show the note «بدون نتيجة», the boards' words for it, and no timeline, score or minute.
- **FR-058**: Cached events MUST show with their age when offline and MUST NOT present as live.
- **FR-059**: The app MUST open pushes by route when tapped: S3, S3 at its channels, S6, or an announcement's link, including S6, which today's route filter drops. It MUST accept only known route shapes (today it accepts anything starting with `/` or a listed prefix), in the app and in the web push worker. A push received while the app is open MUST NOT navigate, which it does today: a goal mid-browse would pull the fan off their screen. It shows an in-app banner with a «عرض» action instead.
- **FR-060**: S3's note for following a started match MUST depend on the feed. With a feed covering the match, it says «بدأت المباراة، ستصلك تنبيهاتها حسب إعداداتك». With no feed, no alert will come, so it keeps today's «بدأت المباراة، فلن يصلك تذكير بها».
- **FR-061**: S5.2 rows MUST show the existing `ChangedBadge` when a frequency changed in the last 30 days (PB S5.2). The component exists, and no real screen uses it yet.
- **FR-062**: S15's عن التطبيق group MUST show this device's ID with a copy action, so an admin can save it as their test device.
- **FR-063**: S15 MUST gain its الإشعارات group (PB S15, app: S15 Settings): a master switch, a switch per type with SD §6.8's defaults, and the platform state (permission denied shows the steps to enable; an iPhone browser where the app isn't installed links to S1.5). Choices are saved through the existing device update and survive being offline. Turning the master off keeps the per-type choices. The default lead-time control stays on D8, because `lead_min` isn't honoured until then, and it MUST NOT be shown before it works.
- **FR-064**: Tests MUST cover timeline and lineups with widget and golden tests, RTL, both themes and 1.3×, with the flags on and off; the running-score rule; route handling; reduced motion; and S15's group in each platform state.

#### All lanes

- **FR-070**: Runbooks MUST change with the code: `push-notifications.md` (all types, composer, holds, stale rules, off switches), `staff-accounts.md` (A16), `remote-config.md` (both flags, how testers get them), `imports-and-sources.md` (both sources, the budget), `source-alerts.md` (the push failure alert), `secrets.md` (the API-Football key), and the `README.md` table.
- **FR-071**: `docs/owner-actions.md` MUST gain D6's section per lane when each lane finishes. PB §11, SD §6.8 and the delivery plan MUST be corrected in the same change where this spec extends them (see Assumptions).

### Key Entities *(include if feature involves data)*

- **Notification (outbox row)**: one event or announcement to send, with type, dedupe key, audience, due time, status and failure reason, recipient counts, and whether it is a test.
- **Notification preference**: a device's master switch and its on/off switch per type, saved on the server against the device, with SD §6.8's defaults when absent.
- **Frequency change**: one carriage's old and new frequency, polarization and symbol rate, with source and time. Feeds S6, A8, the badge and the push.
- **Announcement**: an admin's title, body, deep link target, audience and schedule, sent as a notification.
- **Test device**: the device an admin account saved for test sends.
- **Admin account**: name, email, role, active state, last login and whether a password change is due.
- **Audit entry**: who or which importer changed what, with both sides of the change, and the push it caused, if any.
- **Match event and lineup**: stored since D5. Shown for the first time here.
- **Other-sport match**: a match with its own sport, names as source text, and broadcaster entries instead of channel links.
- **Request budget**: the day's request count for API-Football and its limit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a real followed match, a goal push arrives on Android and on an installed iPhone PWA with the correct score. In a replay of the 2026-11-04 capture, every real goal sends one message, and Mouloudia Alger's false 2–0 sends none.
- **SC-002**: 95 % of `goal`, `match_started` and `final_score` messages are handed to the push service within 60 s of their trigger, even during an all-devices announcement. For a goal, the trigger is the bar being met.
- **SC-003**: In tests with retries, overlapping polls and restarts, no device receives one event twice.
- **SC-004**: A device with a type off receives 0 messages of that type, one with the master off receives 0 of any type, and one with no stored prefs receives exactly SD §6.8's defaults. A switch changed in S15 applies to every send after it reaches the server.
- **SC-005**: A frequency saved in A8 reaches its followers within 6 minutes (5-minute hold plus send), shows in S6's history within its cache time after that, and appears as a diff in A17 at once.
- **SC-006**: A stored event appears on an open S3 within 60 s, with no navigation.
- **SC-007**: A test send reaches the admin's device within 60 s, and no other device receives it.
- **SC-008**: An all-devices announcement to 50,000 devices finishes within 10 minutes.
- **SC-009**: Across a simulated day, API-Football requests never exceed the budget, and 0 go out after it is reached or without a key.
- **SC-010**: With other sports stored, football lists and `/v1/live` return 0 other-sport rows to any client that doesn't ask for them, and the poller polls 0 of them.
- **SC-011**: A deactivated account is refused on its very next request, and a search of logs and audit rows finds no temporary password or hash.
- **SC-012**: Every push type displays correctly on Android and on an installed iPhone PWA, with names, readouts and scores in the right order, checked by the owner.
- **SC-013**: S3 with `live_center` off is unchanged from today's goldens, and «أين تشاهد» remains reachable in ≤ 2 taps with it on (constitution I).
- **SC-014**: With the push service refusing every send, the owner gets one alert within 10 minutes and no repeat until it recovers. A normal day's dead tokens cause none.

## Assumptions

- **The revision is `0009`.** The brief's `0004` predates D2–D5's revisions.
- **Open items from 005 and 031 don't block the spec, but one blocks the done check.** Goal pushes rest on the score rule 031 built. The first real goal push needs the poller deployed and watching a live match. 031's capture from VPS-2 and the watched match remain the owner's open items.
- **D8's brief overlaps with this one.** D8's B1 lists the announcement send path and the dry-run count, and Appendix A's row 008 lists "per-type preferences respected by the dispatcher". All are built here because the composer and the producers need them. S15's notification group also moves here (Clarifications). D8 is left with the S10 sheet, the lead-time control and honouring `lead_min`. The delivery plan is corrected to match.
- **D7's contract row lists a `sport` filter on `/v1/matches`.** The parameter exists already, and D7 adds the switcher that uses it. Football-by-default (FR-022) holds after D7 too, for builds that don't ask.
- **SD §6.8's audiences win over S10's toggles.** S10 offers «الأهداف» for a competition follow, but SD sends goals only to match and team followers. Pushing every goal in a competition would be noise. D8 reconciles the sheet.
- **Two extensions to the docs.** The first-channel push (FR-010) extends SD §6.8 to keep S3's promise. Removed-channel copy (FR-012) extends PB §11, since SD's trigger includes removal and the catalog has no copy for it.
- **New copy for PB §11, approved by the owner on 2026-11-06** (S3's follow note is in FR-060):
  - channels, more than one: «أُضيفت ‹beIN SPORTS 1› على ‹نايل سات› و‹3› غيرها»;
  - channels, removed: title «تغيّرت قنوات مباراة ‹الأهلي› × ‹الزمالك›», body «لم تعد ‹beIN SPORTS 1› تنقل المباراة»;
  - own goal: «‹الأهلي› 1 – 0 ‹الزمالك› · ‹اسم اللاعب› عكسي 23′»;
  - final score with a shootout: «‹الأهلي› 1 – 1 ‹الزمالك› · بركلات الترجيح 4 – 3»;
  - correction: title «تصحيح النتيجة», body «‹الأهلي› 0 – 0 ‹الزمالك›».
- **Until a device has the new build,** pushes reach it as they do today (FR-021). A push received with the app open navigates straight to its screen instead of showing a banner (FR-059), and the fan has no S15 switches, so `goal`, `final_score`, `channels_updated` and `frequency_changed` arrive by their defaults and only the phone's own settings can stop them. A frequency push's tap opens the app without reaching S6. The PWA and the Android test build go out as soon as Lane M finishes, and the PWA reaches users on their next load.
- **The limits in FR-019 are this spec's defaults**, for the owner to adjust. Holds exist because editors work fast before kickoff, and a mistyped frequency sent to every follower makes people re-aim a dish.
- **The test device is a saved device ID.** Devices are anonymous, and no admin is linked to one. FR-062 shows the ID, and the admin saves it once. The board's "Pixel 7" is illustrative: device models aren't collected, so the composer shows platform and app version.
- **The A16 board's temporary password and first-login change are adopted**, since the docs are silent and it is the safer path. The change-password step has no board.
- **The A17 board's «استرجاع القيمة السابقة» isn't built** (Clarifications). It isn't in PB A17 or the brief, and a generic undo across every entity raises locks, conflicts and repeat pushes. Links to the entity's editor cover the need.
- **Roles.** SD §6.5 gives `admin` push broadcasts and users. A17 is `admin`-only here as the cautious reading; editors keep A4's history tab.
- **`live_center` "on for testers"** means a Remote Config condition on a tester build. Turning it on for everyone is an owner step after the done check.
- **API-Football's free plan is partly unverified.** The [pricing page](https://www.api-football.com/pricing) gives 100 requests a day, and a [beginner's guide](https://www.api-football.com/news/post/how-to-get-started-with-api-football-the-complete-beginners-guide) says the free plan covers recent seasons, with no cutoff stated. Current-season access must be confirmed with the account before B2 builds on it. If it isn't covered, the adapter ships off and the decision is recorded. The account is still missing (owner-actions, Gaps 9).
- **sporteventz's value is limited at first.** The old tool warns that its channels are foreign (Czech, Bulgarian, Croatian), with no Arabic ones. They're shown as they are, and D7 decides how they're presented. Its terms aren't reviewed here (R1).
- **Stats stay unread** (spec 031). `lead_min` stays stored and unused until D8.
- **Owner steps:** create the API-Football account and set the key; review the audience queries for every type; send a test push from the composer; set the Remote Config flags for testers; walk S3 and the pushes on a phone and an iPhone PWA; keep FR-021's off switch to hand during the first match night.

### Out of scope (later days)

- **D7:** the sport switcher and showing other sports (S13); checking sporteventz and API-Football imports live (Appendix A row 007).
- **D8:** the S10 follow sheet, S15's lead-time control and competition order, and honouring `lead_min`.
- **V2:** TOTP, S20's ongoing notification.
- **Later:** showing stats in the app; an undo action in A17.

### Dependencies between lanes today

- B1's contract PR merges first. Lanes A and M generate their clients from it, and B2 rebases on the revision.
- `backend/app/adapters/` is B2's, so B2 makes the calls FR-038 needs into B1's producer. They agree the interface in the plan.
- The broadcast lock (FR-031) touches B1's revision and A4's save path, and B2 honours it. B1 adds it.
- Lane A's test send needs B1's endpoint and Lane M's device ID row (FR-062). Until then it runs against the mock.
- Lane M needs only B1's contract, and can stub events until a live match has real ones.
- The done check's goal push needs B1 deployed, the FCM key on VPS-2 and a real match. Check the day's fixtures first.
