# Research: D5 follow-up · Live sources

All figures come from one evening (2026-11-04) on one home connection. Goal.com has only 15 minutes. The raw data and scripts are outside the repo, in `~/madar-capture/2026-11-04/`, on the owner's laptop. The score and status changes are in [replay-timelines-2026-11-04.json](replay-timelines-2026-11-04.json).

## R1. What Lane B1 has built, against the capture

The code on `005-d05-live-and-discovery` was replayed with `replay.py`, using its real parsers and `decide()`, and again after round 1's review fixes, with the same results.

| Part | State | Finding |
|---|---|---|
| Poll cycle, locks, backoff, per-match transaction, raw pages, `import_runs` | Keep | Nothing in the capture contradicts it |
| Watchdog for a dead worker | Keep, change the past-limit case | `to_clock()` wipes a finished match's score at + 210 min |
| Linking, aliases, unresolved queue | Keep | Used by Goal.com under its own source |
| Page slots and caps | Keep, re-measure | 16 FilGoal matches live at peak, cap 8 |
| `filgoal.parse_match` fields, statuses | Keep | 540 of 540 saved models parse; all 5 statuses known |
| `filgoal._minute` | **Fix** | `TimeElapsed.Minutes` is negative, so the minute is empty almost always |
| `filgoal` event map | **Fix** | Types 4, 20 and 9 are ignored |
| `yallakora` status map | **Fix** | The three list statuses and `مباشر` are unknown: 64 of 75 live pages fail |
| Unknown status handling | **Change** | One odd row stops a source for every match |
| `crosscheck.decide` | **Rewrite the score and status rules** | Median 112 s, max 428 s, 7 false alerts |
| `apply` events and lineups | **Change** | Written per reading, so a third source would duplicate events and alternate lineups |
| `capture-live` | **Extend** | Two sources, fixed targets, no alert |
| Hard-coded two sources | **Generalize** | `decide(state, filgoal, yallakora)`, `HOSTS`, `LIST_PATHS`, `_side` |
| FilGoal and YallaKora list parsing of live rows | **Unverified** | List pages weren't saved. The next capture settles it |
| Spec 005 T020–T022, T038, T039 | Moved here | See spec FR-027 |

## R2. The score rule

**Decision:** a rise from any usable source goes out in the first poll that shows it. A drop goes out only when no usable source shows the current score or higher for 5 minutes in a row. The owner chose this on 2026-11-05.

| Rule | Median after first source | Worst | Backward | Finals right | False alerts |
|---|---|---|---|---|---|
| Both must agree (spec 005) | 112 s | 428 s | 0 | 11/11 | 7 |
| Any source, first poll, chosen | 5.5 s | 40 s | 0 | 11/11 | not yet measured |
| Any source, 2 polls | 66 s | 201 s | 0 | 11/11 | not yet measured |

**Why the drop rule looks at "the current score or higher":** FilGoal's older servers undo a goal for about a minute, and the longest of 25 such drops lasted 193 s. 5 minutes covers them with room to spare.

**Rejected: a drop when both sources agree.** A flapping FilGoal and a lagging YallaKora can both show the old score. This made 3 false drops in the replay.

**Accepted cost:** a false rise stays until the drop rule ends it. Mouloudia Alger's probable false 2–0 would have shown for about 9 minutes, because it came back once and restarted the timer.

## R3. The disagreement alert

**Decision:** alert only when two usable sources still differ after 10 minutes, or differ on a finished match. Replay measures it (SC-002). The longest ordinary lag between sources was 7 minutes. Porto v Napoli's 18 minutes is worth an alert.

**Rejected:** spec 005's 3-minute wait, because 9 of 36 ordinary lags pass it.

## R4. FilGoal's minute

**Decision:** when `TimeElapsed.Minutes` is negative, use `Minutes mod 60`, then add the period's base.

**Why:** the capture shows the start time shifted by whole hours and flipping between groups, for example `Minutes = −98` at minute 22 and `−104` at 16. The mod handles any whole-hour offset, including a daylight-saving change. If the result is more than `MatchStatusMaxTime` + 15, no minute is shown.

**Rejected:** using our own clock against `StartAt`, because `StartAt` is the shifted value, and the parser must stay pure.

A minute MUST NOT move backward inside a period, because older servers can answer late.

## R5. Status and finishing

- **Status comes from the first usable source in the order FilGoal, Goal.com, YallaKora.** FilGoal stays first, as in spec 005, and has the most capture behind it.
- **A later status wins at once.** A backward status needs all sources to agree for 5 minutes, as with a score drop. 10 of 16 matches went backward.
- **Any source's full time finishes the match**, unless a drop is in progress or usable scores differ. Then it waits until they agree or 5 minutes pass. In the capture, no goal followed any source's full time. The wait keeps spec 005's review finding B1-R1-1 fixed: polling ends at full time, so a wrong score would stay for good.
- **A cancelled, abandoned or postponed status** comes only from the status source, as in spec 005. A postponed match stays as stored, unpolled (B1-R1-5).
- **Stuck matches:** at kickoff + 150 min, a `live` match in the second half with no score change for 15 minutes is marked finished, alerting once as `stuck:<match_id>`. The normal end is about + 115 min, so a long delay has room. The 15 minutes keeps a match that's still scoring open.
- **`estimated` doesn't apply to it.** The row stays on `feed` with its last accepted score. The owner chose this and gets the alert (constitution II is checked in the plan).

## R6. Unknown statuses

**Decision:** an unknown status drops that row only. The source stays usable and one `unknown_status:<source>` alert opens, saving the page. Structure failures still stop the source.

**Why:** Goal.com's list has 89 matches and FilGoal's and YallaKora's have many too, so a rare status such as extra time on a minor match shouldn't stop live scores everywhere. Skipping the row still can't publish a wrong score.

## R7. Own goals and event sides

**Decision:** `match_events.side` is the side the goal counts for.

**Why:** FilGoal's `TeamId` is the player's team: Leipzig's Lukeba, with the score at 0–1 to Manchester City. Goal.com's `side` is already the side it counts for: `GOAL_OWN` on `TEAM_B` with the score going 2–0 to 2–1. FilGoal's own goal side flips.

## R8. Goal.com's reader

- **Reads:** `__NEXT_DATA__` → `props.pageProps`. The list has `content` with match objects (`id`, `status`, `teamA`, `teamB`, `score`, `period`, `startDate`), and links come from `href`s ending in the match ID. A match page has `content.match`.
- **Statuses seen:** `LIVE` with `FIRST_HALF`, `HALF_TIME`, `SECOND_HALF`, and `RESULT`, `FIXTURE`. Others in `capture_goal.py` (`POSTPONED`, `CANCELLED`, `SUSPENDED`) weren't seen, so their row is dropped until seen (R6). `penalty` and `extraTime` are unconfirmed, and the capture settles them.
- **Events:** `GOAL`, `GOAL_OWN`, `GOAL_PENALTY` map to ours. `PERIOD_*` and `CARD_YELLOW` are skipped, others are logged, not guessed. Events have no ID, so `external_id` is the stable hash data-model already allows.
- **Lineups:** `lineups.teamA.formation` and `.lineup[].person.name`, `.shirtNumber`. Player ratings (`score`) aren't stored.
- **Never read:** `tabsInfo.commentary`, `venue`, articles and images.
- **Requests:** one list page a poll, plus a page cap that starts at 4. Average 5 s responses make the list page the real source and the match page a bonus for events, lineups and stats.

**Order in a cycle:** FilGoal and YallaKora first, then Goal.com, for lists and for pages. A slow Goal.com can then only use time left over.

## R9. Events and lineups with three sources

**Decision:**
- Each source's events stay stored under their own source, as the unique key already allows.
- `/v1` serves events from one source per match: FilGoal if it has any stored, otherwise Goal.com. A match's timeline never mixes sources, so a goal can't appear twice.
- Lineups are written from the first source in that order that has them, so two sources don't overwrite each other each poll.
- An event's deletion waits for 5 minutes of absence (`missing_since`), since an older FilGoal server can drop events.

**Rejected:** merging events across sources by minute and player. Names and minutes differ, and nothing needs it yet.

## R10. Stats

**Decision:** `match_stats (match_id, source, stats jsonb, updated_at)`, from R16 of spec 005, filled from Goal.com's `stats.summary` only, and only when the value changes. No client reads it. The other groups (`attacking`, `passing` and so on) wait for a screen that needs them.

**Why not YallaKora:** corners, offsides and shots stayed 0 in every saved page, and 4 of 11 pages had no block.

## R11. Goal.com's approval

The owner reports FootballCo's approval dated 2026-11-05, for scraping and everything this spec plans, with no conditions or exceptions. The text isn't in the repo. So:

- The setting is on by default and can go off in one environment change.
- `docs/owner-actions.md` holds the record.
- No credit or rate limit is planned, and this spec has no app work.

## R12. Capture

**Decision:** extend `capture-live` instead of keeping the throwaway scripts. It reads all three list pages, chooses live match pages itself from each list up to a cap, saves everything gzipped, catches every read error, and sends one Telegram alert through `send_alert` when a source fails 5 rounds in a row, and one on recovery.

**Why:** the throwaway Goal.com script died on an uncaught `IncompleteRead`, and nobody knew. `capture_once` already catches read errors by type, so `http.client.HTTPException` must be covered too (the fetcher may wrap it; a test proves it).
