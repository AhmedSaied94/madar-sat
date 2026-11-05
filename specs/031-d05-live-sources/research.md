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
| Any source, first poll, chosen | 5.5 s | 40 s | 0 | 11/11 | 1 ([R13](#r13-the-final-rules-replayed)) |
| Any source, 2 polls | 66 s | 201 s | 0 | 11/11 | not yet measured |

**Why the drop rule looks at "the current score or higher":** FilGoal's older servers undo a goal for about a minute, and the longest of 25 such drops lasted 193 s. 5 minutes covers them with room to spare.

**Rejected: a drop when both sources agree.** A flapping FilGoal and a lagging YallaKora can both show the old score. This made 3 false drops in the replay.

**Accepted cost:** a false rise stays until the drop rule ends it. Mouloudia Alger's probable false 2–0 would have shown for about 9 minutes, because it came back once and restarted the timer.

## R3. The disagreement alert

**Decision:** alert only when two usable sources still differ after 10 minutes, or differ on a finished match. The replay gives 1 alert across all 16 matches, on Porto v Napoli (SC-002, [R13](#r13-the-final-rules-replayed)). The longest ordinary lag between sources was 7 minutes. Porto v Napoli's 18 minutes is worth an alert.

**Rejected:** spec 005's 3-minute wait, because 9 of 36 ordinary lags pass it.

## R4. FilGoal's minute

**Decision:** when `TimeElapsed.Minutes` is negative, use `Minutes mod 60`, then add the period's base.

**Why:** the capture shows the start time shifted by whole hours and flipping between groups, for example `Minutes = −98` at minute 22 and `−104` at 16. The mod handles any whole-hour offset, including a daylight-saving change. If the elapsed time in the period, after the mod and before the base is added, is more than `MatchStatusMaxTime` + 15, no minute is shown. Past `MatchStatusMaxTime` it shows as stoppage time: `45+n` in the first half and `90+n` in the second.

**The limit is on elapsed time, not on the result.** Of the capture's 1,367 live readings, 99.2% give a minute this way. Comparing after adding the base would give 57.7%, because every second-half minute past 60 would disappear, and SC-004 would fail.

**Rejected:** using our own clock against `StartAt`, because `StartAt` is the shifted value, and the parser must stay pure.

A minute MUST NOT move backward inside a period, because older servers can answer late.

**The wrap (found while planning FR-009):** FilGoal's elapsed time keeps counting from the wall clock, even after a match ends, so the mod gives a wrong low minute once a period's elapsed time passes 60. Bristol City v Wolves reached 104 at 22:03, read 46 at 22:05, and read 70–76 from 22:29 to 22:35, around its kickoff + 150. In the other form the same clock gives a figure past the limit, so no minute shows. During a real match this doesn't arise: a period's elapsed time stays under 60.

**Decision:** keep the mod, and store `peak_minute` per match and source, with `peak_period`, the period it was reached in. The stuck check reads the minute. Every one of the 15 FilGoal matches read to the end reached a peak of 94–104 by the rule above, and the peak can't fall.

**What fans see:** a minute more than 5 below its source's peak in the same period counts as no minute. The no-backward rule alone doesn't hide the wrap, because a reading with no minute clears the stored one, and the next wrapped minute then shows.

| Rule, on the capture's 1,367 live readings | Show a minute | Wrong minutes shown | Real-play readings blanked for a poll |
|---|---|---|---|
| No peak rule | 99.2%, 1,356 | 10, all on the stuck match | 0 |
| Peak for the whole match | 98.0%, 1,339 | 0 | 4 |
| **Peak in the same period, chosen** | **98.2%, 1,343** | **0** | **0** |

A wrong minute here is one shown more than 5 below the highest in its period. The whole-match peak is wrong because first-half stoppage counts towards it: 47 early in the second half is correct after a first half that reached 53, and that's all 4 of its blanks.

The 5 needs no fine tuning. Within a period, late answers fell 1 below the peak (7 readings), and wrapped minutes fell 25–59 below (13 readings, all on the stuck match). So 3 and 10 give the same figures as 5.

**Rejected:** the current minute, as first written in FR-009. On Bristol City v Wolves, 5 of the 9 polls after kickoff + 150 read 72–79 and would have blocked the finish. It passed at 22:33 only because that poll got the other form, which shows no minute. So the result would depend on which server answered, and a source answering only in the negative form would block it until the wrapped minute reached 90 again. Also rejected: keeping a history of each source's minutes, because the peak answers the same question with one column.

## R5. Status and finishing

- **A later status from any usable source wins at once**, except full time. The owner chose this on 2026-11-05, replacing "FilGoal's status stands while it's usable", so a lagging FilGoal can't hold back half-time or the second half. When sources show the same stage, the order is FilGoal, Goal.com, YallaKora. No status move had to be undone in the replay.
- **A backward status** needs all sources to agree for 5 minutes, as with a score drop. 10 of 16 matches went backward.
- **`live` with no period says nothing about the half.** Spec 005 ranks it with the first half, so a YallaKora match page's `مباشر` would look like a backward move from the second half, and could take a match back after 5 minutes.
- **Full time from one source waits.** The owner chose this on 2026-11-05: finish when a second usable source also shows it, or when one has held it for 10 minutes, and don't count a lone full time while any source shows extra time or penalties. The capture has no extra time or penalties at all, so "no goal followed any source's full time" says nothing about cup matches. A failed request doesn't restart the 10 minutes, but a reading of anything else does.
- **Two full times beat a stuck source.** Applied on every poll, the extra-time check would let one source stuck on extra time hold a match open until + 210, however many others said full time. The capture saw sources get stuck on other stages. The cost: two sources wrongly showing full time at 90 minutes would close a cup match, and a person would have to reopen it.
- **While a lone full time waits, the match shows no minute.** A frozen `90+6` would look current for up to about 15 minutes.
- **Then the score wait.** Once that's met, with a drop in progress or usable scores differing, it waits until they agree or 5 minutes pass. This keeps spec 005's review finding B1-R1-1 fixed: polling ends at full time, so a wrong score would stay for good.
- **The cost for D6:** `final_score` follows the finished status, so that push can be up to 10 minutes late, or about 15 where a source flaps ([R13](#r13-the-final-rules-replayed)).
- **A cancelled, abandoned or postponed status** comes only from the status source, as in spec 005. A postponed match stays as stored, unpolled (B1-R1-5).
- **Stuck matches:** at kickoff + 150 min, a `live` match in the second half with no score change for 15 minutes and no usable source's peak minute below 90 is marked finished, alerting once as `stuck:<match_id>`. The normal end is about + 115 min, so a long delay has room, and the peak minute protects a match that kicked off late. The 15 minutes keeps a match that's still scoring open. A second-half match that fails these checks finishes the same way at + 210.
- **`estimated` doesn't apply to it.** The row stays on `feed` with its last accepted score. The owner chose this and gets the alert. It's an exception to constitution II, recorded in the plan's [Complexity Tracking](plan.md#complexity-tracking).
- **Past + 150, nothing sends a second-half match to the clock.** `to_clock` wipes the score, and it has three callers: the watchdog's stale branch, `decide`'s all-sources-down fallback and `pause_feed_rows`. Guarding it in one place covers them all. A match past that point is almost certainly over, so keeping its score is better than wiping it, and the stuck step finishes it. This is also in Complexity Tracking.

## R6. Unknown statuses

**Decision:** the owner chose this on 2026-11-05. An unknown status affects that row only: a higher score on it counts, and its status, minute and any lower score are ignored. A score on it keeps the match from going stale, so with every source in this state the match shows no minute, as a frozen one would look current. The source stays usable and one `unknown_status:<source>` alert opens, saving the page. Structure failures still stop the source.

**Why:** Goal.com's list has 89 matches and FilGoal's and YallaKora's have many too, so a rare status such as extra time on a minor match shouldn't stop live scores everywhere. The capture holds no extra-time or penalty wording from any source, so the first cup night will meet this rule.

**Rejected:** dropping the whole row. If every source did that during extra time, the match would reach the stale limit and go to the clock estimate, which shows no score, until a parser is fixed. Also rejected: guessing each source's extra-time wording now, because a miss behaves the same and nothing could check it.

**Accepted cost:** a wrong score on an unknown row is treated like any false rise, and the drop rule corrects it.

## R7. Own goals and event sides

**Decision:** `match_events.side` is the side the goal counts for.

**Why:** FilGoal's `TeamId` is the player's team: Leipzig's Lukeba, with the score at 0–1 to Manchester City. Goal.com's `side` is already the side it counts for: `GOAL_OWN` on `TEAM_B` with the score going 2–0 to 2–1. FilGoal's own goal side flips.

## R8. Goal.com's reader

- **No list page was saved.** The first capture kept match pages, list counts and a few list fields, so the list shape below comes from `capture_goal.py`, not from a saved page. T005 saves one before writing the parser.
- **Reads:** `__NEXT_DATA__` → `props.pageProps`. The list has `content` with match objects (`id`, `status`, `teamA`, `teamB`, `score`, `period`, `startDate`), and links come from `href`s ending in the match ID. A match page has `content.match`.
- **Statuses seen:** `LIVE` with `FIRST_HALF`, `HALF_TIME`, `SECOND_HALF`, and `RESULT`, `FIXTURE`. `POSTPONED` appeared on the list page T005 saved, with a score of 0–0, so it's mapped and its score isn't read. The others in `capture_goal.py` (`CANCELLED`, `SUSPENDED`) weren't seen, so they count as unknown until seen (R6). `penalty` and `extraTime` are unconfirmed, and the capture settles them.
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

**Telling the owner when the capture itself stops:** a dead process can't send its own alert, so something else has to notice. Each round, `capture-live` writes the time to a Redis key, and it deletes the key at a normal end. `live.watchdog` runs every 2 minutes on the `maintenance` queue, which survives the capture dying, and sends one alert if the key is more than 5 minutes old. The capture also sends one alert when it starts, naming its expected end, and one when it ends. A failed heartbeat write is logged and doesn't stop the capture. If VPS-2 itself goes down, the existing Kuma monitor for the `maintenance` queue reports it.

**A source going quiet:** its list reads fine, but it shows no live rows for 5 rounds in a row while another source shows some. That's what a changed status wording looks like during a capture.

**Rejected:** an Uptime Kuma push monitor, as the other heartbeats use. `capture-live` is a one-off command, so the monitor would be red between captures unless someone paused and resumed it each time.

## R13. The final rules replayed

**What this is:** the rules as clarified on 2026-11-05, replayed by a throwaway script on [the committed timelines](replay-timelines-2026-11-04.json) and the capture's FilGoal clock records. `test_replay.py` must reproduce these results against the real `decide`. The replay has two sources, because Goal.com has only 15 minutes of data.

| Check | Result |
|---|---|
| Final scores | All 16 end on the last score their sources showed |
| Drops applied | 1, Mouloudia's false 2–0 going to 1–0 |
| Status moves undone | 0 |
| Disagreement alerts | 1, Porto v Napoli |
| Matches finished by FR-008 | 14 of 16 |
| How they finished | 10 by a second source, 4 by the 10-minute hold |
| Delay after the first full time | Median 2 minutes, 5 at most with a second source, and 14.9 at most on the hold |
| FilGoal live readings showing a minute | 98.2%, 1,343 of 1,367, with no wrapped minute shown ([R4](#r4-filgoals-minute)). T011 gets 97.9%, 1,338, through the real `decide`: the other 5 are polls where FilGoal flapped from half-time back to the first half, and the status correctly stayed on half-time |

**The two left:** Bristol City v Wolves is the stuck match, and FR-009 finishes it at kickoff + 150, about 22:30, with its 1–2. Mouloudia's last page read came before its end, because the capture capped pages at 12 a poll, so the replay can't tell.

**The holds that ran long:** a flapping source restarts the 10 minutes, as FR-008 asks. Three of the 4 held matches took 13–15 minutes for this reason, and the fourth, Cardiff v West Ham, took 10.5. None of them had any later change of score.

**How far to trust it:** the capture stopped reading a match's page when the match left FilGoal's live list, and list pages weren't saved. So the finish results assume that a match out of that list, whose last page showed the second half or later, reads full time. That's an inference, and it carries the 3 FilGoal-only matches that finished and some of the others, such as the match YallaKora never closed. The next capture saves list pages, which settles it. If the capture shows otherwise, FR-025 applies.

**Not tested:** extra time and penalties, which no source showed. FR-008's protection for them is a precaution, and a capture of a cup match is the first real test.
