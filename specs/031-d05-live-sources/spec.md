# Feature Specification: D5 follow-up · Live sources after the capture, and Goal.com

**Planning docs**: in PR #39, on `005-d05-live-and-discovery`. **Lane branches**: `d05-b1`, `d05-b2`

**Created**: 2026-11-05

**Status**: Draft

**Input**: The owner's request to add Goal.com to the plan, trace what Lane B1 built for live data, and put the changes the 2026-11-04 capture calls for into new spec tasks.

| | |
| --- | --- |
| Goal | The live poller works on real live pages, fans see goals quickly and truthfully, and Goal.com runs as the third source |
| Phase | V1. Runs after spec 005's lanes and before D6. The number 031 is out of day order because 006 belongs to D6, and it keeps the `d05` lane branches |
| Starts from | Spec 005's merged lanes and round 1 review fixes on `005-d05-live-and-discovery` (PR #39), and the 2026-11-04 capture. The replay's results are the same after those fixes |
| Contract | One expand-only revision for stats storage. No change to what clients read |
| Flags | Goal.com's reader setting, on by default so it can be switched off if approval changes. `live_center` stays off until D6 |
| Implements | SD §3.3 (O7), §6.2.3, §6.7, §11, §13 (R1) · closes spec 005's T020, T021, T022, T038, T039 |

Shorthand: **SD** = `docs/system-design.md`, **PB** = `docs/product-business.md`.

## Clarifications

### Session 2026-11-05

- Q: When one source shows a higher score, when should fans see it? → A: In the first poll that shows it. The replay gives about 6 s after the first source and 40 s at worst, with 0 backward moves and all 11 final scores right. A false goal like Mouloudia's 2–0 shows for about 9 minutes, and D6's goal push uses a stricter bar (FR-019).
- Q: What happens to a match no source ever closes? → A: If it was in the second half and nothing has changed by kickoff + 150 min, it's marked finished with its last score, and the owner gets one alert.
- Q: What does FootballCo's approval cover? → A: The owner reports approval dated 2026-11-05 for scraping, covering goals, match stats and everything else this spec plans, with no conditions or exceptions.
- Q: What role does Goal.com take? → A: The owner asked to start with Goal.com enabled. It runs as an equal third source: its score counts under the same rule, it fills the minute, events and lineups where FilGoal has none, and it's the only stats source. FilGoal stays first for status.

## What the capture found

On 2026-11-04, FilGoal and YallaKora were read for 3.6 hours from a home connection: 16 FilGoal matches, 11 of them also on YallaKora, and no blocks. Goal.com was read for only 15 minutes, because the capture script crashed. The saved data was replayed through B1's parsers and cross-check.

| # | Finding | What it would do in production |
|---|---|---|
| 1 | YallaKora's parser knows no live status: `الشوط الأول`, `استراحة` and `الشوط الثاني` on the list, `مباشر` on 64 of 75 live match pages | The first live row stops YallaKora for every match, with a false format alert |
| 2 | FilGoal's elapsed time comes back negative, for example −98 at minute 22, because its start time is shifted by whole hours and flips between server groups | The minute is empty for almost the whole match |
| 3 | The "both sources must agree" rule is slow on real data: median 112 s after the first source, maximum 428 s, 10 of 36 scores over 3 minutes, 7 scores never shown, 7 false disagreement alerts | Porto v Napoli would have stayed on 1–1 for 18 minutes. Final scores were all right |
| 4 | FilGoal goes backward in 26 of 124 score changes, across 12 of 16 matches. 25 recovered within 193 s. Statuses went backward in 10 of 16 matches, and 5 went from finished back to second half | With one source up, a backward score that lasts 2 polls reaches fans |
| 5 | Sources can leave a finished match open: Bristol City v Wolves stayed live on FilGoal for about 45 minutes after the end, and YallaKora never closed one match | At kickoff + 210 min the watchdog turns the match back to scheduled and wipes its score |
| 6 | FilGoal's red card (4), own goal (20) and missed penalty (9) aren't mapped | The timeline loses them, and an own goal's score has no matching event |
| 7 | FilGoal has no stats in any match. YallaKora has only goals and cards, with corners, offsides and shots at 0 and no block on 4 of 11 pages | Goal.com is the only source of real live stats |
| 8 | List pages weren't saved, the connection was a home one, and up to 16 FilGoal matches were live against a cap of 8 | Live list parsing and datacenter access are still unproven, and the caps are unchecked |

Goal.com's list page gives status, period, minute and score for 89 matches in one request. Its match pages add events, lineups and 5–8 live stats in the bigger competitions, and none in lesser ones. Pages were about 21 s old (44 s at most), and responses averaged 5 s. Its `robots.txt` allows everything, but its terms forbid scraping and commercial use without FootballCo's written consent.

All of these figures come from one evening and one connection.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Lane B1: a fan sees a goal quickly and never sees the score go backward by mistake (Priority: P1)

As a fan, when a goal is scored, the score changes soon after any source has it, and a source's glitch doesn't take it away again.

**Why this priority**: Without this, the feature doesn't work on a live match: YallaKora stops itself at the first live row, and a goal can take minutes to appear.

**Independent Test**: Replay the 2026-11-04 score timelines through the poller's rules, and check the delays, backward moves, alerts and final scores against SC-001 to SC-004.

**Acceptance Scenarios**:

1. **Given** a live match on YallaKora, **When** its list or match page shows any live status from the capture, **Then** the source stays usable and reports the right status.
2. **Given** FilGoal reports a negative elapsed time, **When** the page is read, **Then** the minute shown is the real match minute, in both server groups' forms.
3. **Given** one source shows a higher score, **When** the rule in FR-004 is met, **Then** that score goes out without waiting for the other source.
4. **Given** the confirmed score is 2–1 and FilGoal drops to 1–1, **When** the drop lasts under 5 minutes or any source still shows 2–1 or higher, **Then** fans keep seeing 2–1.
5. **Given** a score drop that no source contradicts for 5 minutes, **Then** the lower score goes out and the withdrawn goal leaves the timeline.
6. **Given** the sources differ only because one is behind, **Then** no disagreement alert goes out unless it lasts past the limit in FR-006.

---

### User Story 2 - Lane B1: a finished match stays finished, with its score and full timeline (Priority: P2)

As a fan, after full time I see the final score, even when a source forgets to close the match, and the timeline shows own goals, red cards and missed penalties.

**Why this priority**: Wiping a finished match's score is a visible error, but it only shows at the end of a match, and only where sources fail to close it.

**Independent Test**: Run the stuck matches from the capture and each mapped event type through the poller, and check the final state.

**Acceptance Scenarios**:

1. **Given** any usable source reports full time, no score drop is in progress and the sources show the same score, **Then** the match is finished, whichever source said it.
2. **Given** FilGoal goes from finished back to second half, **Then** the match stays finished.
3. **Given** no source ever closes a match, **Then** FR-009 applies, and the match never returns to scheduled and never loses its score.
4. **Given** a FilGoal page with a red card, an own goal and a missed penalty, **Then** each is stored with its correct type, side and minute.

---

### User Story 3 - Lane B1: Goal.com runs as the third source, and can be switched off (Priority: P2)

As a fan, I get the score sooner and a minute more often because a third source is read. As the owner, I can switch it off with one setting if its approval changes.

**Why this priority**: It adds the only real live stats and a third opinion, and only 15 minutes of its live behaviour has been seen, so the product must also keep working without it.

**Independent Test**: With the setting on, saved Goal.com pages produce readings, stats and unresolved names, and take part in the rules. With it off, a poll sends Goal.com 0 requests and the other two sources work as before.

**Acceptance Scenarios**:

1. **Given** the setting is on, **When** Goal.com's pages are read, **Then** its readings take the role in FR-017, and a changed format stops only that source.
2. **Given** the setting is off, **Then** the poller sends Goal.com no request and stores nothing new from it.
3. **Given** a Goal.com team name that isn't known, **Then** it reaches the unresolved queue under its own source, and no team is created.
4. **Given** a Goal.com match page with stats, **Then** they're stored, and no client reads them yet.
5. **Given** FootballCo's approval ends or its terms rule a use out, **Then** the setting goes off the same day, and the runbook says how to remove the stored data.

---

### User Story 4 - Lanes B1 and B2: the changes are proven on a real match from a datacenter (Priority: P1)

As the owner, I want proof from a production-like host that the sources answer it and the deployed poller gets a real match right.

**Why this priority**: The whole choice of free sources assumes a datacenter host isn't blocked, and that's still untested on live matches.

**Independent Test**: A capture on VPS-2 saves list and match pages from all three sources across a real match, and a report compares them. A later match is watched against the broadcast.

**Acceptance Scenarios**:

1. **Given** a real match night, **When** the capture runs on VPS-2, **Then** list and match pages from FilGoal, YallaKora and Goal.com are saved across pre-match, each half, half-time, a goal and full time, and one source failing doesn't stop the others.
2. **Given** a source blocks the host or the capture stops, **Then** the owner is told during the capture, not after it. A block isn't evaded, and it stops the work on that source until the owner decides.
3. **Given** the capture is finished, **Then** a report records each source's delays, errors, reversals, status strings and page sizes, and the values the settings take.
4. **Given** the deployed poller with all three sources, **When** the owner watches a real match, **Then** status, minute and score match the broadcast from kickoff to full time, within the delays in SC-001.

### Edge Cases

- **A source's false goal.** A rise can be wrong, as Mouloudia Alger's 2–0 probably was. It stays until the drop rule corrects it. No goal push exists yet, and FR-019 sets a stricter bar for D6.
- **A flapping source and a lagging one agree on the old score.** That's not a real drop. Agreement alone never lowers a score; replay showed it would.
- **A score that both rises and falls on different sides.** For example 1–1 to 0–2. It counts as a drop for the side that fell, so it needs the drop rule.
- **Penalty shoot-outs.** Penalty scores follow the same rise and drop rules. They're compared only between sources that carry them, and a source without them never erases them (spec 005 review B1-R1-2).
- **`مباشر` on a YallaKora match page has no half.** The half comes from its list row, or stays empty if it has none.
- **A goal event before its score is accepted.** It's held until the score is accepted, as in spec 005.
- **An event missing from one older response.** It isn't deleted until it has been gone for as long as the drop rule requires.
- **Goal.com is slow.** Its 5 s responses must not use up the time FilGoal and YallaKora need in a cycle.
- **A manual status or locked field.** These still win, as in spec 005.
- **A match a source doesn't cover.** It's left out of that source's opinion and isn't a disagreement.

## Requirements *(mandatory)*

### Functional Requirements

#### Parsers (Lane B1)

- **FR-001**: The YallaKora reader MUST map every live status from the capture on its list and match pages. A status nobody has seen fails validation for that row only: the match gets no reading from this source this poll, and the owner gets one alert. A page without the expected structure still stops the source.
- **FR-002**: The FilGoal reader MUST give the real match minute when its elapsed time is shifted by whole hours, in both forms the capture saw, and show no minute when it can't work one out. It MUST never show a negative minute.
- **FR-003**: The FilGoal reader MUST store red cards, own goals and missed penalties with the right type. An event's side MUST be the side the goal counts for, so an own goal's side is the opposite of FilGoal's team, as the capture shows (Leipzig's own goal made it 0–1).

#### Score and status rules (Lane B1)

These rules are replayed on `replay-timelines-2026-11-04.json`, in this folder.

- **FR-004**: A higher score from any usable source MUST go out in the first poll that shows it. This replaces "only when both sources show it" in SD §6.7 and spec 005.
- **FR-005**: A lower score MUST go out only when no usable source shows the current score or higher for 5 minutes in a row. Two sources agreeing on a lower score MUST NOT be enough on its own.
- **FR-006**: A disagreement alert MUST go out only when two usable sources still differ after 10 minutes, or differ on a finished match. Each problem gets one alert, and one more on recovery.
- **FR-007**: A status MUST NOT move backward unless no usable source shows the later status for 5 minutes in a row. A finished match stays finished unless a person changes it.
- **FR-008**: Any usable source reporting full time MUST finish a match, unless a score drop is in progress or usable sources show different scores. In those cases it MUST wait until they agree or 5 minutes pass, because polling ends at full time and a wrong score would stay for good (spec 005 review B1-R1-1). If they still differ, it finishes on the accepted score and alerts the owner.
- **FR-009**: A match in its second half with no change in score or status by kickoff + 150 min, which no source has closed, MUST be marked finished. It MUST keep its last accepted score, MUST NOT return to scheduled, and MUST alert the owner once. A match in extra time or penalties isn't covered by this limit and keeps spec 005's kickoff + 210 min.
- **FR-010**: The watchdog's clock fallback for a dead worker stays as in spec 005 up to kickoff + 150 min, so a stale score is never shown as live. Past that, a match that reached its second half MUST follow FR-009 and MUST NOT be sent back to the clock.
- **FR-011**: An event missing from a response MUST stay until it has been gone for 5 minutes in a row, with goal events following the score that holds them. Repeated polls MUST NOT add an event twice.
- **FR-012**: These rules MUST stay one pure, table-tested function. The clock fallback MUST apply only when every enabled source is down or invalid, and with one usable source left it MUST use FR-004 and FR-005.

#### Goal.com (Lane B1)

- **FR-013**: A Goal.com reader MUST read its list and match pages for status, period, minute, score, events, lineups and stats, and nothing written, such as commentary or articles. Every response is validated, and a failure stops only this source.
- **FR-014**: A setting, on by default, MUST control the reader. When it's off, the poller MUST send Goal.com no request and store nothing new from it. `docs/owner-actions.md` MUST hold the approval record: FootballCo's approval dated 2026-11-05, as the owner reports it, covering this spec's use with no conditions.
- **FR-015**: Requests MUST identify us as the other sources do, MUST use their rate limit, backoff and block rules, and MUST NOT be disguised. It MUST read one list page a poll and a capped number of match pages. Its slow answers MUST NOT stop the other sources' reads in that cycle.
- **FR-016**: Goal.com names MUST link through the same resolver and unresolved queue, under their own source.
- **FR-017**: Goal.com MUST count as an equal third source for a higher score, a lower score and full time. Status and minute come from FilGoal when it's usable, and otherwise from Goal.com, then YallaKora. Goal.com MUST fill the minute when FilGoal has none, and supply events and lineups for a match where FilGoal has none. Events from different sources MUST NOT show the same goal twice.
- **FR-018**: Match stats from Goal.com MUST be stored per match, source and time, through an expand-only revision that leaves `/v1` unchanged. YallaKora's stats aren't stored, because the capture shows them to be incomplete.

#### For D6 (Lane B1)

- **FR-019**: This spec MUST state the bar for D6's goal push: a rise that a second source has shown, or that its source has held for 3 minutes with no other source covering the match. A rise a usable source contradicts by going lower MUST NOT push. D6 owns the producer, and FR-014 of spec 005 still applies until then.

#### Capture and proof (Lanes B1 and B2)

- **FR-020**: `capture-live` MUST read all three sources, save list pages as well as match pages, keep one source's failure from stopping the others, and treat any read error as a logged result. It runs from VPS-2.
- **FR-021**: B2 MUST add Goal.com's rate limit, pass any new settings through to the live worker and give B1 a way to run the capture on VPS-2. The owner MUST be told if a source stops or goes quiet during the capture.
- **FR-022**: A trimmed set of captured pages MUST be committed as test fixtures, with no personal data and no commentary, covering each status and each mapped event type. Parser tests MUST run on real live rows from all three list pages.
- **FR-023**: `specs/031-d05-live-sources/capture-report.md` MUST record what T021 of spec 005 asks for, plus Goal.com, the datacenter result and the values chosen for the page caps and any timer in this spec.
- **FR-024**: The deployed poller MUST be watched against the broadcast on one real match, later than the capture's, with all three sources on (T038 of spec 005).
- **FR-025**: If the capture shows that a rule or limit here is wrong, the report MUST say so and the rule, this spec and SD §6.7 MUST change together.

#### Documents and ownership

- **FR-026**: SD §3.3 and §6.7, delivery-plan, PB O7, the live-poller runbook and `docs/owner-actions.md` MUST be updated with this work, including the new rule, the capture's results, Goal.com's approval state and how to switch it off or remove it. SD §13 R1 MUST record the legal risk.
- **FR-027**: Spec 005's T020, T021, T022, T038 and T039 MUST be marked as moved to this spec, so they're done once.
- **FR-028**: B1 owns `backend/` except `backend/app/adapters/`. B2 owns `infra/`, `backend/app/adapters/` and CI. No lane edits another's folder or a generated file. No admin or app work is in this spec.

### Key Entities

- **Source reading**: as in spec 005, with Goal.com added as a source.
- **Accepted score**: the score fans see, with the source that first showed it and when, so that delays can be measured and D6 can judge a goal.
- **Drop in progress**: a lower score or earlier status, with when it began, so a brief glitch can be told from a real correction.
- **Match stats**: figures per match, source and time, such as possession and shots, from Goal.com only.
- **Approval record**: the owner's note of FootballCo's answer: dated 2026-11-05, covering everything this spec plans, with no conditions.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a replay of the 2026-11-04 timelines, every new score reaches fans within 60 s of the first source showing it, with 0 scores shown backward and all 11 final scores right.
- **SC-002**: In the same replay, disagreement alerts fall from 7 to at most 1 across the 11 matches.
- **SC-003**: Every live status in the capture is accepted, and no source stops itself on a real live page.
- **SC-004**: A real match minute appears in at least 95 % of FilGoal's live readings in the replay, and is never negative.
- **SC-005**: Every match that reached full time in the capture ends finished with its right score, and none returns to scheduled or loses its score.
- **SC-006**: With Goal.com's setting off, it receives 0 requests in a replayed match night, and the same replay gives the results in SC-001 to SC-005.
- **SC-007**: A capture from VPS-2 covers a whole match from all three sources, or the report names the source that blocked it.
- **SC-008**: On a watched match from the deployed hosts, status, minute and score match the broadcast from kickoff to full time, and an accepted score reaches the app within 45 s, as in spec 005's SC-005.

## Assumptions

- **Scope is backend and capture.** Clients already read `/v1/live`, so they get the improvement without a release. No client reads stats on D5 or D6.
- **The evidence is thin.** One evening, one home connection, and only 15 minutes of Goal.com. FR-025 lets the next capture change any rule here.
- **FootballCo's approval is as the owner reported it.** It's dated 2026-11-05 and covers this spec's use with no conditions or exceptions, so no credit or rate limit is planned. Its text isn't in this repo, and the owner keeps it.
- **The owner accepts a brief false goal as the price of speed** (Clarifications). The Mouloudia case shows a false score can last minutes. No push is sent on D5, which limits the harm, and FR-019 protects pushes.
- **Numbering.** 006 belongs to D6, and lane branches need the `NNN-dNN-` form, so this is `031-d05-live-sources`. Its planning docs ship in PR #39, and its code doesn't. B1 continues on `d05-b1` and B2 on `d05-b2`, and the delivery plan records that it runs before D6.
- **Stats have nowhere to show yet.** A later spec adds the screen and the contract.
- **The owner handles FootballCo.** This spec only records the result.
- **Other carry-over stays in spec 005:** T037 and T040 and their owner items aren't part of this spec.

### Out of scope

- **D6:** goal, kickoff and full-time pushes, and the live center UI.
- **Later:** showing stats in the app, and Goal.com's TV channels.
- **Not planned:** proxies or any other way around a block, and storing written commentary.
