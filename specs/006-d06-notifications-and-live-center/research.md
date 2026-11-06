# Research: D6 · Notifications and live center

Decisions behind [plan.md](plan.md). Each records what was chosen, why, and what was rejected. Evidence comes from reading the code on `master` at 2eda168, from the committed 2026-11-04 capture, and from the live sporteventz site on 2026-11-06.

## R1. The goal bar, judged per goal

**Decision.** Each poll, per side, the value that passes the bar is:

- with 2 or more sources showing a score: the second-highest value for that side, capped at the accepted score, and never below what was last pushed;
- with 1 source: the lowest value above what was last pushed that the source has shown without a break for 3 minutes;
- with none: nothing.

A value above what was last pushed gives one message per side, carrying the bar's score (not the accepted score). The floor matters when a source falls behind a score already pushed: with 2–0 pushed and sources at 2–1 and 1–1, the push must say 2–1, not 1–1. The capture holds no such case, and removing the floor gives the same totals, so only `evaluate`'s table test can pin it.

**Rationale.** A scratch replay of the 2026-11-04 capture through `decide` compared three forms of the rule:

| Form | Goal messages | Mouloudia's false 2–0 | Mouloudia's real 1–0 | Delay from first source |
|---|---|---|---|---|
| Whole accepted score must be covered | 54 | No push, but only by seconds at 19:42 | +837 s | median 136.5 s, max 837 s |
| Per side, hold not checked for breaks | 57 | No push | +837 s | median 177 s, max 837 s |
| **Per side, unbroken hold (chosen)** | 58 | **No push** | **+240 s** | median 177 s, p90 365 s, max 580 s |

All three give 0 corrections. Mouloudia is a FilGoal-only match whose feed flipped between 1–0 and 2–0 every minute, so `score_changed_at` can't judge a hold: the accepted 2–0 kept its timestamp while the source went back to 1–0. A value that was never held without a break must not pass.

A consequence: Porto v Napoli sends 2–1, 3–1 and 4–1 as separate pushes when the slower source catches up, rather than one 4–1. They replace each other on the device through the match tag.

**Three sources.** Spec 031 FR-019 says a rise a usable source contradicts by going lower must not push. Read literally, one slow third source would hold a goal two sources agree on, and YallaKora has lagged by up to 428 s. Two of three is enough here, and the contradiction clause applies to one source's word. SD §6.7's own summary has no such clause. The capture has two sources, so this case can't be replayed. **The owner confirmed this reading on 2026-11-06.**

**Rejected.** Comparing whole scores (a false goal on one side held back a real goal). Pushing the accepted score (it would leak the false 2–0 once a real goal passed the bar).

## R2. What the bar remembers

**Decision.** One column, `match_live_state.push_memory` (JSONB, default `{}`): the last pushed `home` and `away`, the generation, and each side's held value and its start. A pure function takes the memory, the poll's readings and `now`, and returns the new memory and the messages due. It is unit-tested on the capture.

**Rationale.** A restart must lose no goal (FR-004). `match_live_state` already holds the rules' memory in the same transaction. Empty memory means "no baseline yet": the first evaluation stores the accepted score and sends nothing, which gives FR-002 with no backfill. A manual status or a locked score moves the baseline and sends no goal (FR-006). If it lowers the score below what was pushed, the correction still goes out first (FR-009), because the followers were told a score that's now wrong.

**Rejected.** Typed columns: seven more, read by one function. Using `match_source_readings.changed_at` for the hold: it moves whenever the minute does.

## R3. Where producers run

**Decision.** `app/notifications/producers.py` holds the decisions and the row inserts. `_apply_match` in `app/live/cycle.py` calls it inside the match's transaction, after `apply_decision`. The watchdog's `_finish` doesn't, because a finish at the limit sends no `final_score` (FR-007). A row exists only if its state change committed. After commit, a poll that wrote a row queues `dispatch_due`, the way the scheduler already does, through a new `Deps.kick_dispatch`. Admin saves use the same decisions from `AsyncSession`, through a thin async twin of the insert, as `bump_datasets` already has, and reach it through `save_update`'s `then`, so the audit row's ID is known and the bump stays last ([push-pipeline](contracts/push-pipeline.md#frequency-changes)).

**Inside a savepoint.** The poller's producers run in `session.begin_nested()`. An error there rolls back only the push work and is logged as an error, and the score still commits. `push_memory` rolled back too, so the next poll tries again. Without this, a bug in copy or memory would stop the live score for that match, which FR-008 forbids. `match_started` reads `push_memory.live_seen` rather than comparing the poll's before and after, so a failed poll doesn't lose it, and a match already in play at the first evaluation only sets the flag (FR-002).

**Rationale.** FR-001 and SC-002. A one-minute beat alone can't meet 60 s.

## R4. Dedupe keys

| Row | Key |
|---|---|
| `match_started` | `match_started:<match>` |
| `goal` | `goal:<match>:<generation>:<side>:<value>` |
| correction (type `goal`) | `goal_correction:<match>:<generation>` |
| `final_score` | `final_score:<match>` |
| `channels_updated` | `channels_updated:<match>:<first change id>` |
| `frequency_changed` | `frequency_changed:<channel>:<first save's audit id>` |
| `announcement` | `announcement:<uuid>` |
| test send | `test:<uuid>` |

The generation rises with each correction, so a goal scored again after a reversal gets a new key. SD §6.8's example `goal:48213:23:home` isn't used, because sources disagree on the minute. SD's text changes to match.

**A correction stays under type `goal`** with `payload.kind = "correction"`, so no new type or preference is added.

## R5. Merging channel changes

**Decision.** A new append-only table, `match_channel_changes`, unique on `(match, channel, action)`. Every writer adds its changes in its own transaction: A4's `reconcile_links` (including a hidden flag turned on or off) and importers through FR-038. If no row is pending for the match, one is inserted with `due_at = now + 5 min`. At dispatch, unannounced changes are netted against the links visible now, stored on the row's payload and marked announced in one transaction, so a retry sends the same message. Nothing left means cancelled, reason `no_net_change`.

**Rationale.** The unique key gives FR's "one push per direction, per channel, per match". A fixed window from the first change means a wait of at most 5 minutes (clarified). Computing visibility at dispatch keeps hidden names and placeholders out, which matters because `apply_broadcasts`'s `added` includes hidden placeholders.

**First channels.** Outside the 6-hour window, a change is recorded only when the match had no visible link before it. That row's audience is `match_only`.

**Accepted gap.** A placeholder an editor promotes, or a hidden-names edit, can change visibility without a link change, and sends nothing.

**Rejected.** Diffing against a snapshot of announced links: no baseline exists when a match enters the window, and it can't express "one push per direction".

## R6. The frequency hold

**Decision.** A save that changes one complete set of values to another adds a row with `payload.old` and `due_at = now + 5 min`, unless one is pending for the channel. When due, the row compares `old` with the current values. Equal or incomplete cancels it. Otherwise it writes the `channel_frequency_changes` row, sets `frequency_changed_at`, bumps the channel datasets, then sends. The history row has `outbox_id UNIQUE`, so a retry can't write it twice.

**Rationale.** History records what followers were told, so a typo fixed within the hold leaves no public trace (clarified). `frequency_changed_at` joins `NOT_HASHED`, so a hold ending doesn't make an open A8 stale: the editor did nothing wrong, and the conflict dialog would blame someone who isn't there. The history row keeps its own `audit_log_id`, because `prune_outbox` removes the outbox row at 30 days and A8 must still name the editor.

**Off switch.** History is written even when the type is off, so stopping pushes never loses history.

## R7. The audience

**Decision.** Three fixed queries with bound parameters: `AUDIENCE` (followers, `SELECT DISTINCT`), `AUDIENCE_ALL` (all devices, no join) and `AUDIENCE_DEVICE` (one device, prefs ignored). `audience.kind` picks the query and which parameters are set. The reach count uses the same conditions. `devices.prefs` gains `enabled`, checked in SQL alongside the type's switch: `COALESCE((d.prefs ->> 'enabled')::boolean, true)` and `COALESCE((d.prefs -> 'types' -> :type ->> 'on')::boolean, :default_on)`. The full text is in [contracts/push-pipeline.md](contracts/push-pipeline.md), for the owner's review.

**Rationale.** Constitution V forbids string-built SQL, so a query assembled from fragments is out. Constitution VII asks for `SELECT DISTINCT` over follows. An `all` audience has no follows, so it has nothing to de-duplicate. The partial indexes on `device_follows` already exist.

## R8. A big send must not hold a goal

**Decision.** `dispatch_due` works one row at a time, always claiming the best row next: `goal`, `match_started` and `final_score` first, then the rest by due time. A row sends at most 20 pages per turn (10,000 devices), then goes back to `pending` with its cursor. The run ends after 50 s and queues itself if work remains. The 4-minute Redis lock stays.

**Rationale.** Today's run claims 10 rows and sends each to completion, so a 50,000-device announcement holds the lock for the whole send, and a goal row queued meanwhile finds `lock_held` and waits for the next beat. The cursor already resumes safely.

**Rejected.** A second worker or queue for live pushes: more memory on a 1-OCPU host for what ordering solves.

## R9. Late pushes and reasons

**Decision.** A pure `policy.py` decides per type at dispatch, using the limits in FR-019. The existing reminder rule is unchanged. A goal row whose side has since fallen below its value is cancelled, because the message would be false. `notification_outbox.error` holds a short reason: `late`, `match_finished`, `type_off`, `no_net_change`, `score_fell`, or the push service's code (`FCM 503`). A15 maps known reasons to Arabic and shows others as an LTR island.

**Correction guard.** A correction is produced only if a `goal` or `final_score` row of the current generation was actually sent, so nobody is corrected about a goal they never heard.

## R10. The off switch

**Decision.** `PUSH_TYPES_OFF`, a comma-separated list in VPS-2's `.env`, read only by the dispatcher. A listed type's rows are cancelled, reason `type_off`. Recreating `worker-notify` (`up -d`, since `restart` doesn't re-read `.env`) takes effect in under a minute, with no release.

**Rationale.** Admin saves produce rows on VPS-1 and the dispatcher runs on VPS-2, so one setting on one host covers every producer. Cancelled rows stay in the log, which makes "why did nothing go out?" answerable. The poller's memory moves on either way, so FR-002 holds when the type returns. The spec's wording changed from "nothing is produced" to "nothing is sent".

**Rejected.** A Redis key: instant, but invisible, and lost on a flush.

## R11. Failure alerts

**Decision.** Reuse `app/live/problems.py` (`LiveProblem`, `sync_problems`) with one problem key, `push`. It opens when a row ends `failed`, or when a finished row with at least 10 devices had more than 20 % fail. It closes on the next finished row under that rate. Test sends and cancelled rows are ignored. Dead tokens are already outside `failed` in `SendOutcome`.

**Rationale.** It already gives one alert per problem and one on recovery, with a table, in Arabic, sent after commit. The minimum of 10 stops 1 failure in 3 from alerting.

## R12. Keeping other sports off football

**Decision.** `sport` absent means football in `GET /v1/matches`. `live_window_query` gains `Match.sport == 'football'`, which covers `/v1/live`, the scheduler, the poller and the watchdog. `plan_targets` in `livesoccertv.py` and the dashboard query gain the same filter. `_apply` and the merge lookups in `upsert.py` write and compare the record's sport.

**Rationale.** The code forces football in `Match(...)`, and `_may_be_a_near_row` and the name-based merge ignore sport, so an English-named row could merge across sports. Every build in the field sends no sport, so the default must stay football after D7 too.

## R13. Showing events quickly without more polling

**Decision.** `LiveState` gains `event_count`. S3 re-reads the match once when score, status or `event_count` changes. Its 60 s timer stays.

**Rationale.** The timer alone misses SC-006 for a red card, which moves no score: up to 60 s of timer plus 15 s of cache. Polling the detail every 30 s would add a request per viewer to a VPS-1 that failed its load test and can't be resized. `/v1/live` is shared and cached. A new event reaches S3 in about 15 s of rebuild, 30 s of poll and one read. An edit that doesn't change the count, such as a scorer filled in later, waits for the timer.

## R14. Pushes in the app

Facts from the code:

- `onMessage` emits a route, so a push received in the foreground navigates with no tap, and a test pins that behaviour.
- `push_route_listener.dart` allows prefixes that exclude `/channel/`, so S6 pushes are dropped today, and `/match/5/x` reaches go_router's default error page.
- `firebase-messaging-sw.js` passes `data.route` unvalidated to `navigate` or `openWindow`, and has no test. `navigate` probably rejects on a client this worker doesn't control (unverified).
- `/match/123?section=channels` is safe on old builds: the path passes and the query is ignored.

**Decision.** One allowlist of exact shapes, in the app and mirrored in the worker: `/`, `/match/<id>`, `/match/<id>?section=channels`, `/channel/<id>`. A foreground message shows a banner with «عرض», and only a tap navigates. A channel route goes to `/` and then pushes, so the sheet has something under it. The worker falls back to `openWindow` and gains tests. S3 scrolls to its channels with a one-shot `ensureVisible` on a key at the toolbar, after load.

**Rationale.** D3's behaviour was harmless with one reminder before kickoff. With goal pushes it would pull fans off their screen during a match.

## R15. Feature flags and "on for testers"

**Decision.** `RemoteConfigValues` gains `features`, parsed from JSON with a bundled `{live_center: false, lineups: false}`; bad JSON keeps the bundle. Testers get it through a Remote Config condition on platform = Android, while Android is closed-test only and the public is on the PWA. Turning it on for everyone removes the condition. Values apply at the next launch, as all Remote Config does here.

**Rationale.** No user properties or tester lists exist, and anonymous devices can't be targeted. SD §5.1's example value (`true`) stays wrong until that last step.

## R16. Lineups: pitch or two lists

**Decision.** The pitch is drawn when a side has exactly 11 starters, one goalkeeper, and a known position group for each (FilGoal: حارس مرمى, مدافع, وسط, مهاجم). Lines come from the groups, and the formation is only a label. Anything else, including all of Goal.com (`position` is `None`), gets two lists. Circles use tokens for home and away, since `TeamRef` has no colours. Goal and red-card marks appear only on an exact name match with an event.

**Rationale.** The board hand-places players, and the data has no coordinates. Placing players by list order would state a position nobody reported (constitution II). No board draws two lists, so it follows S3's row style.

## R17. The timeline

**Decision.** `/v1` already returns events sorted by minute. A pure Dart function orders them as `EventTimeline`'s README says (newest first while live, chronological once finished) and adds markers from the minute: «بداية المباراة», «الشوط الثاني» before the first minute above 45+, «إضافي» before the first above 90+, using the string the app already has for extra time. A goal row shows a running score only when the known goal-type events add up to the current score.

**Rationale.** The API has no period on an event, and adding one would need every parser to agree. `side` on an own goal already means the credited team, because the score rule counts it that way.

## R18. Device ID and permission state

**Decision.** `PUT /v1/devices/me`'s response already carries `device_id`, and `update` discards it. It's kept in `app_settings` (it isn't a secret), cleared by `forget()`, and one sync is forced when it's missing, because existing installs return early from `ensureRegistered`. The S15 row hides until it's known. `PushMessaging` gains a permission getter, and four fakes change with it.

## R19. Admin accounts

**Decision.**

- `admin_users` gains `must_change_password` and `test_device_id`.
- A16 passes an explicit allowlist (`email`, `name`, `role`, `is_active`) to the writer. `versions.row_state` hashes every stored column and `save_update` diffs it, so the generic path would put `password_hash` into `audit_log`. This is the day's sharpest trap, and a test pins it.
- `require_role` refuses with `403 password_change_required` while the flag is set. `auth/me` and `auth/change-password` use a variant that keeps the role check and skips only the flag, since constitution V wants a role on every admin route. Refresh stays exempt, because a `403` on refresh ends the admin's session.
- A temporary password comes from `secrets`, is returned once with `no-store`, and is revoked with the old refresh tokens on reset.
- The CLI's `set-admin-password` clears the flag, and first-admin creation doesn't set it.
- A16's "temporarily locked" needs one more Redis key. `auth/limits.py` locks an email and IP pair (`auth:lock:<h>:<ip>`), so no key says an account is locked. The lock script also sets `auth:locked:<h>` with the same expiry, and A16 reads its TTL. An account locked from one address therefore shows as locked with time left, though it can still sign in from another. A `SCAN` over the first key was rejected, since it walks all of Redis on every list.

**Client.** `Session.admin` gains the flag. `requestWithRetry` is the one catch point in `http.ts`: it reports the code through `bindSession`, and `SignedInShell` redirects to `/change-password`.

## R20. The audit log and the outbox log

**Decision.** `notification_outbox.audit_log_id` links a push to the save that started it, so A17 can show its counts. A later save merged into the same hold has no link. A17 renders `[old, new]` pairs side by side and anything else raw, because the CLI writes shapes like `{"password": "changed"}`. Both logs use cursor pagination, on the `SourcesPage` pattern, since `DataTable` has none. ETags use `dataset_versions` plus a short bucket: new `outbox` and `admin_users` names, and a 30 s bucket over the content datasets for audit, since six places write audit rows and not all bump one name. The log refreshes every 30 s, as A13 does.

**Recipients.** `sent + failed` once sending has begun. A pending row shows a live count from the reach query.

## R21. sporteventz

Facts: the sport pages are `https://www.sporteventz.com/en/other-sport/<slug>.html`, which answered 200 on 2026-11-06. Data comes from a second request, `index.php?option=com_magictable&...&accesskey=<n>`, a JSON `Result`/`Records` with `Sport, Begin, Team1, Team2, Tournament, Category, @id, Channels`. The access key dies on the next page load. `robots.txt` disallows neither path for `*`. The old tool saw about 40 events in two weeks across 28 sports, and notes that its channels are foreign. No saved pages exist.

**Decision.** Read only the four sports, as page then data per sport, so `MAX_PAGES` becomes per-source (8 here). Send a fixed `client_tz_offset` and convert from that offset, because the old tool's `+0300` is labelled Cairo and is wrong in winter. Rank channels as the old tool does, but write the slots through the FR-038 checks. Name resolution is skipped through a per-source flag in `_apply` (FR-032).

**Zero items.** A valid response with no events is normal at this volume, so the alarm waits 7 days for this source. A missing access key or `Records` key is a changed page and counts at once.

**Open.** Saved pages must be captured from the host before `parse` tests are written. Its terms aren't read (R1 in SD §13). The value is modest until D7 shows it, and the owner may prefer to drop this source.

## R22. API-Football

**Decision.** Source name `api_football`, already seeded in `0001` and used by `MatchesPage.tsx`, not the brief's `apifootball`, which would fail the `import_runs.source` foreign key. Host `v3.football.api-sports.io` with its own bucket. One request per date for today to +3, filtered locally by an allowlist of league IDs, starting with the old tool's defaults 233, 39 and 2. Twice a day is 8 requests against a budget of 90. If the plan refuses a date alone, `date` + `league` gives 24 a day and still fits. `timezone=UTC`.

**Strict creation.** English names won't match an Arabic catalog. `upsert.py` records a 75-row incident from this shape of problem. So a fixture creates a match only when both teams and the competition resolve, and it freezes other sources' fields (`upsert.py`'s strict probe and freezing, as the bridge uses). Otherwise only unmatched names reach the queue.

**The budget.** A hook in `fetcher._request`'s retry loop counts every attempt before it is sent, in a Redis key per UTC date, expiring after 48 h. Redis failing means no request. Reaching the budget raises a dedicated error that ends the run as `stopped`.

**A stopped run** is a new `import_runs.status` value, `stopped`, with its reason in `error` (`budget_reached`, `not_configured`). Today's `tasks.py:386` fails any run with an error or no pages, and `_bridge_configured` reads `api-admin`'s env on VPS-1, which can't see a key on VPS-2. A13 reads the last run instead, so no field is added to `SourceHealth`.

**Unverified, and blocking.** The official docs and pricing page return 403 to automated fetches, so nothing below is confirmed from them, and no way around that was tried. Secondary sources give 100 requests a day and "recent seasons" with no cutoff. These are checked with the account, by one request and reading the docs in a browser, before B2 builds on them ([quickstart](quickstart.md#before-lane-b2-builds-on-api-football)):

1. Does the free plan return current-season fixtures for today?
2. Does `date` work alone?
3. When does the daily count reset, and which header reports it?
4. What does a refused request look like? The old tool treats a non-empty `errors` in a 200 as failure.
5. Do the terms allow showing fixtures in a free app?

If 1 fails, the adapter ships off and the decision is recorded.

## R23. The broadcast lock and old rows

**Decision.** `MATCH_LOCKABLE` and `ck_matches_locked_fields` gain `broadcasts`, on the pattern in `0007`. `lock_changed_fields` works on columns and slots aren't columns, so `matches.py` sets it explicitly when the slots change. The downgrade strips the value before restoring the old CHECK.

**Old rows.** `repair-matches sport` with no input lists rows with a `sporteventz` external ID labelled `football`, and changes nothing. The containers don't hold the snapshot, and `read_snapshot` needs a `--snapshot-dir` nobody has on the host, so the command doesn't read it. It takes a reviewed map instead, the way `merge` takes reviewed pairs: `{"<match id>": "<sport>"}` on stdin, built by the owner from the snapshot's `sport` wherever `old_app/migration/data/` is kept, and never committed. It's a dry run unless `--apply`, and all or nothing: a listed ID that isn't such a row is refused. A row left out of the map stays as it is and is reported. Nothing guesses a sport. The committed fixture has one such row with no `sport` key, and the real snapshot isn't on this machine, so the count and the map are owner steps.

## R24. Boundaries with later days

D8's B1 row and Appendix A's row 008 list work this spec builds, and S15's notification group moved here (Clarifications). D7's contract row lists a `sport` filter that already exists. These are corrected in the delivery plan with this change. Editors can see A13 today though the A16 board calls sources admin-only: SD §6.5 agrees with the board, but gating it isn't in this brief, so it's left as it is and noted for the owner. A2's «من N مباراة اليوم» sums the missing groups rather than the day's total; that's an existing bug, outside this spec.
