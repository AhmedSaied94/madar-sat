# Implementation Plan: D6 · Notifications and live center

**Branch**: `006-d06-notifications-and-live-center` (lanes: `d06-b1`, `d06-b2`, `d06-a`, `d06-m`) | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-d06-notifications-and-live-center/spec.md`

## Summary

The kickoff reminder is the only push today. This plan adds every other SD §6.8 type through the existing outbox, gives S3 its live center and S15 its switches, builds A15, A16 and A17, and adds two importers that fans don't see yet.

- **B1:** Producers insert outbox rows in the same transaction as the change behind them. A pure goal bar, replayed on the 2026-11-04 capture, judges each goal per side: two sources agreeing, or one source holding a value unbroken for 3 minutes. The replay gives 58 goal messages, no corrections and no false 2–0. The dispatcher sends one row at a time, live types first, so a big announcement can't hold a goal. The admin API adds the outbox log, composer, accounts and audit. Other sports stay off football reads.
- **M:** S3's live center sits behind `live_center` and `lineups`. S15 gains its notification group. Pushes open only known routes, and a push received while the app is open shows a banner instead of navigating.
- **A:** A15, A16, A17, the forced password change, and A8's frequency history.
- **B2:** `sporteventz` and `api_football`, with a daily budget that stops requests and a run status for stopping on purpose.

Evidence and choices are in [research.md](research.md), storage in [data-model.md](data-model.md), and the rules each lane builds against in [contracts/](contracts/).

## Technical Context

**Language/Version**: Python 3.13 (backend), Dart with Flutter stable (app), TypeScript strict with React 18 (admin), Bash and Docker Compose v2 (infra).

**Primary Dependencies**: None added. `firebase-admin`, `lxml`, Riverpod, go_router, drift, React Query, RHF + Zod and Orval are already in place.

**Storage**: PostgreSQL 16, one expand-only revision `0009` ([data-model.md](data-model.md)). Redis 7 for the dispatch lock, the API-Football counter and the account lock marker. Drift `app_settings` for prefs and the device ID, needing no migration.

**Testing**: pytest on PostgreSQL 16, including the capture replay, and contract tests for each admin endpoint. Vitest with MSW, plus Playwright screenshots, for the admin. Flutter widget and golden tests through `RTEST_HOST=flutter-tests rtest` only. A test comes first in every task.

**Target Platform**: VPS-1 (API, Postgres, Redis), VPS-2 (workers), Android closed test, the installed iPhone PWA, the admin on WireGuard.

**Project Type**: The D1 monorepo: API, workers, mobile and PWA client, admin SPA.

**Performance Goals**: 95 % of live pushes handed to FCM within 60 s of their trigger, even during an all-devices send (SC-002). A 50,000-device announcement finishes within 10 minutes (SC-008). A stored event reaches an open S3 within 60 s, with no added polling (SC-006). A frequency save reaches followers within 6 minutes (SC-005).

**Constraints**: $0/month. VPS-1 failed its load test and can't be resized, so S3 adds no polling. `/v1` stays compatible with builds in the field. API-Football stays under 90 of its 100 free requests a day, and nothing goes out without the counter. `live_center` and `lineups` are off in the bundle.

**Scale/Scope**: About 30 matches at once, up to 50,000 devices in one send, 17–97 matches a day, 40 other-sport events in two weeks. 4 lanes, 15 new endpoints, 2 new tables, 2 adapters.

No unknowns remain open in the design. Five facts about API-Football's free plan are unverified and need the account: they're owner checks with a recorded fallback ([R22](research.md#r22-api-football)).

## Constitution Check

*Checked before research and again after design, against the constitution, 1.4.0. That amendment concerns ads and the Android stores. The one line that touches this spec is S15's no-Google-Play state, which its delivery-plan row schedules with that work ([app-screens](contracts/app-screens.md#platform-state)).*

| Principle | Check | Result |
|---|---|---|
| I. The Answer First | The live center sits above «أين تشاهد» as the boards draw it, and is off in the bundle. With it off, S3 is unchanged against today's goldens. The ≤ 2 taps rule still holds, and a push for channels opens at the channels | Pass, with the long-timeline risk [below](#risks) |
| II. Honest Data | A goal push carries the score that met the bar, never a score still in doubt. An estimated status shows no timeline, score or minute. A row too late to be true is cancelled. Scorer and running score appear only when the data adds up. The pitch appears only with reported positions. Cached events show their age. A match finished at the limit sends no `final_score` (FR-007) | **One exception, in [Complexity Tracking](#complexity-tracking)**, decided by the owner |
| III. Arabic-Native, RTL | Every part of a push is isolated, each score beside its team, with an exact-text test per type and an owner check on devices. Readouts and minutes are LTR islands. Timeline rows carry Arabic labels. Copy is approved and goes in ARB and `ar.ts` | Pass |
| IV. Tokens and Components | `EventTimeline` is built once under its name, and `FormControls` once in the admin. `ConflictDialog` already renders the diff, so it's extracted as `DiffView` and shared with A17, not built twice. Red cards use `error`, not `live`. Tabs and the pitch aren't in `INDEX.md`, so they stay screen-local | Pass |
| V. Trust on the Server | Admin routes stay on `wg0`, with a role check on every one, including `auth/me` and `auth/change-password`, which skip only the password-change flag. Temporary passwords are returned once, stored as argon2id, and kept out of logs and audit by an explicit allowlist with a test. The API-Football key stays in VPS-2's `.env`, with a test for logs and raw pages. Three audience queries are fixed text with bound parameters. Deep links are built by the server. New hosts are allowlisted | Pass |
| VI. Contract-First | All `/v1` changes are additive, with `oasdiff` clean. Clients are generated. Every `GET` has an `ETag`. Mutations with a row need `If-Match`, write audit and bump datasets, the test-device `PUT` included. Log, reach and audit `ETag`s add a short time bucket to their dataset, because producers don't bump one per row | **One exception, in [Complexity Tracking](#complexity-tracking)** |
| VII. Pipelines | Producers only insert, each with a unique key, and only `sender.py` talks to FCM. `SKIP LOCKED` stays. Follows use `SELECT DISTINCT`. `all` and `device` have no follows to de-duplicate. Tags extend beyond `match_<id>` for types with no match, as PB §11 says. Both adapters have allowlists, buckets, backoff, breaker, zero-items alarm, `import_runs`, raw pages and `parse` tests. sporteventz's alarm allows 7 quiet days because of its volume, and a page change still alarms at once. Locked broadcast entries are never written | Pass |
| VIII. Lean Clients | Both features are behind flags in Remote Config with bundled values. No polling added. Pure rules live in `domain`, and platform differences behind `PushMessaging` and `InstallGuide`. The 45 s budget is untouched. Prefs and the device ID stay in drift | Pass |
| IX. Zero Cost | API-Football's free plan with a hard stop. No new container or paid service. `worker-notify`'s existing 2 processes do the work | Pass |
| Quality gates | Tests first in every task, runbooks and owner-actions in the same change, and expand-only migration with a tested downgrade | Pass |

**Legal note (SD §13 R1):** sporteventz's terms and API-Football's aren't reviewed. sporteventz's `robots.txt` allows the paths used as of 2026-11-06. API-Football's terms are one of the owner's five checks.

**After design.** The design adds nothing the check above doesn't cover. Re-checking found and fixed three points: `EventTimeline` was first planned as a local widget, and its README's order for finished matches was missed; the poller's producers needed a savepoint so a push bug can't stop a score (FR-008); and every new `GET` needed a stated `ETag`.

## Project Structure

### Documentation (this feature)

```text
specs/006-d06-notifications-and-live-center/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── push-pipeline.md      # producers, goal bar, dispatcher, audiences, copy
│   ├── public-api.md
│   ├── admin-api.md
│   ├── importers.md
│   ├── app-screens.md
│   └── admin-screens.md
├── checklists/requirements.md
└── tasks.md                  # /speckit-tasks
```

### Source Code

```text
backend/                                       # Lane B1, except adapters
├── alembic/versions/0009_notifications_and_accounts.py
├── app/notifications/
│   ├── goal_bar.py, policy.py                 # new, pure
│   ├── producers.py, channel_changes.py       # new
│   ├── messages.py, dispatcher.py, tasks.py   # every type, ordering, page budget
│   ├── sender.py                              # the failure reason
├── app/live/cycle.py, problems.py, types.py   # hooks, push problem
├── app/services/admin/
│   ├── notifications.py, users.py, audit.py   # new
│   ├── channels.py, matches.py, dashboard.py, versions.py, writer.py
├── app/services/live.py, channels.py          # football only, event_count, history
├── app/api/admin/notifications.py, users.py, audit.py  # new
├── app/api/admin/auth.py, channels.py
├── app/api/public/matches.py
├── app/auth/roles.py, admins.py, limits.py    # the flag, async revoke, lock marker
├── app/schemas/public.py, admin.py, admin_examples.py
├── app/domain/lockable.py
├── app/cli.py                                 # repair-matches sport
├── openapi/                                   # exported
└── tests/notifications/, tests/admin/, tests/live/

backend/app/adapters/                          # Lane B2
├── sporteventz.py, api_football.py, budget.py  # new
├── base.py, upsert.py, tasks.py, schedule.py, ratelimit.py, raw_store.py
├── messages.py, health.py, report.py, config.py, fetcher.py
├── livesoccertv.py, livesoccertv_links.py
backend/tests/adapters/, backend/tests/fixtures/{sporteventz,api_football}/
infra/compose/example.env                      # Lane B2: PUSH_TYPES_OFF, API_FOOTBALL_*
.github/workflows/                             # only if a new check is needed

admin/src/                                     # Lane A
├── features/notifications/, users/, audit/    # new
├── features/auth/ChangePasswordPage.tsx (new), session.ts
├── features/channels/ChannelEditor.tsx, features/sources/
├── features/matches/ChannelPicker.tsx
├── components/                                # FormControls, not-permitted: new. ConfirmDialog/DiffView: extracted, shared
├── api/generated/                             # Orval, unedited
├── api/http.ts, app/App.tsx, i18n/ar.ts

app/lib/                                       # Lane M
├── core/config/remote_config.dart, remote_config_repository.dart
├── core/platform/push_service.dart, push_routes.dart (new)
├── core/db/app_database.dart                  # new settings keys, no migration
├── core/network/generated/                    # generated, unedited
├── design/components/event_timeline_item.dart # new
├── features/devices/data/device_sync.dart, device_repository.dart
├── features/match_detail/domain/timeline.dart, lineup_layout.dart  # new, pure
├── features/match_detail/presentation/live_center/  # new
├── features/match_detail/presentation/match_detail_page.dart, match_hero.dart
├── features/frequencies/presentation/channel_list.dart
├── features/settings/presentation/settings_page.dart, notification_settings.dart (new)
└── features/notifications/presentation/push_route_listener.dart, foreground_banner.dart (new)
app/web/firebase-messaging-sw.js, app/test/

docs/runbooks/{push-notifications,staff-accounts,remote-config,imports-and-sources,
  source-alerts,secrets,load-testing,deploy-and-rollback,README}.md
docs/{system-design,product-business,delivery-plan,owner-actions}.md
```

Exact file names inside `features/` follow what each lane finds when it starts.

**Structure decision:** extend `backend/app/notifications/` rather than adding a framework: pure rules next to the dispatcher, thin producers, and one insert path. B2 calls B1's `report_link_change`, its only import from outside `adapters/` that's new today. Runbook rows follow the lane that changes the behaviour.

## Order of work

1. **Docs and spec reach the lanes.** PB §11 gains the approved copy. SD §6.7's goal bar wording, §6.8's key example and first-channel rule are corrected. D7, D8 and Appendix A's rows move to match. This is FR-071.
2. **B1's contract PR merges first:** `0009`, schemas, both OpenAPI documents, and handlers that validate and persist. Both clients regenerate here. A and M build from this, and B2 rebases on it. Every merge to `master` deploys, so this PR must be inert for push: the dispatcher keeps claiming only `kickoff_reminder` until B1's push PR.
3. **In parallel:**
   - **B1:** goal bar and replay first, since they're pure and pin the design. Then messages, policy, dispatcher, producers, frequency, channels, then the admin services.
   - **M:** flags, routes and the foreground banner, then the timeline, S15 and lineups.
   - **A:** forced password change first, as it changes the shell. Then A15, A16, A17 and A8's history.
   - **B2:** upsert changes and `sporteventz`, with pages captured from the host.
4. **B2's `api_football`** starts after the owner's checks in the [quickstart](quickstart.md#before-lane-b2-builds-on-api-football). If the account isn't ready, its adapter waits and the rest of the day doesn't.
5. **Deploy in the [order in the quickstart](quickstart.md#deploy-order):** B1's push PR starts every automatic type for every follower when it deploys, on whichever build they have (FR-021). The PWA and Android build follow as soon as Lane M finishes.
6. **The done check** on a real match, by the owner.

### What crosses lanes

| Needs | From | Interface |
|---|---|---|
| B2 reports link changes | B1 | [`report_link_change`](contracts/push-pipeline.md#the-call-importers-make) |
| B2 honours the broadcast lock, `stopped` | B1 | `0009`, `MATCH_LOCKABLE` |
| B2 ships `PUSH_TYPES_OFF` and `API_FOOTBALL_*` in `example.env` | B1 reads the first | Names in the contracts |
| A's test send | M's device ID row, B1's endpoints | Mock until they land |
| A2's football filter | B1 | `dashboard.py` |
| M and A stubs | B1's contract PR | Generated clients |

## Runbooks and owner actions

| Runbook | Change |
|---|---|
| `push-notifications.md` | All types, composer, holds, lateness, the off switch within a minute, reading the log |
| `staff-accounts.md` | A16, temporary passwords, the CLI for the first admin only |
| `remote-config.md` | Both flags, the tester condition, and turning it on for everyone |
| `imports-and-sources.md` | Both sources, the budget, `stopped` runs, `repair-matches sport` |
| `source-alerts.md` | The push failure alert, sporteventz's quiet days |
| `secrets.md` | `API_FOOTBALL_KEY`, plus `PUSH_TYPES_OFF` as a non-secret setting |
| `load-testing.md` | The all-devices send, with `FCM_DRY_RUN` |
| `deploy-and-rollback.md` | D6's deploy order, and prefs during a rollback |
| `README.md` | Setup order and "After setup" table |

`docs/owner-actions.md` gains D6's section per lane when each lane finishes. Known owner items: the API-Football account and its five checks; reviewing the audience queries; counting old sporteventz rows on the host and approving their repair; setting the tester flags; walking every push on Android and an installed iPhone PWA; the done check on a real match.

## Risks

| Risk | What we do |
|---|---|
| A false goal reaches every follower on the first night, since there's no tester stage | The bar, the correction, and the off switch within a minute |
| Until a device updates, a push received with the app open navigates it, and the fan has no S15 switches | Accepted by the owner (FR-021). Merge B1's push PR when Lane M's PWA is close, and release that PWA as soon as M finishes. It reaches users on their next load, and Android testers update through the closed test |
| A bug in push work stops the live score | Producers run in a savepoint, with a test (FR-008) |
| Followers of a match finished at the limit hear no ending | Accepted (FR-007). The owner's alert is the prompt to check the score and finish it by hand, which sends `final_score` |
| `password_hash` reaches `audit_log` through the generic writer | An explicit state allowlist, with a test on every route |
| A flagged account can't refresh and loses its session | `auth/*` is exempt from the check, with a client test on the flow |
| A big send starves goals, or slows VPS-2 | One row at a time, a page budget, and a recorded 50,000-device dry run |
| `/v1/live` costs more with `event_count` | It's computed in the cached rebuild, over at most about 30 matches. Checked in the load test |
| Sport-aware merging changes football merges | The default stays football, and the existing upsert tests must pass unchanged |
| A long timeline pushes «أين تشاهد» down the screen | Checked on a real match at the done check. If it's far, collapse to the latest rows, as a follow-up with the owner |
| sporteventz gives little value, about 40 events in two weeks with foreign channels | Built because the brief asks. The owner can drop it, since no fan sees it before D7 |
| API-Football's free plan may not cover the current season | Five checks first. The adapter ships off if it fails, and nothing else depends on it |
| Other-sport events can't be followed by team | Accepted for now, and D7 and later decide |
| The first real goal push depends on 031's open owner items | Listed in the spec's Assumptions. Check the fixtures, and see `owner-actions` before the done check |

## Complexity Tracking

| Exception | Why needed | Simpler alternative rejected because |
|---|---|---|
| **II:** sporteventz's team and competition names stay as text, with no `unresolved_names` entry | No other-sport catalog exists, and the owner decided this on 2026-11-06. Nothing is guessed, but constitution II sends unmatched names to the queue | Queueing every name would bury the football queue under names nobody can resolve. Adding rows would create teams from one source's text |
| **VI:** `POST auth/change-password` takes no `If-Match`, though it changes the caller's row. It writes audit and bumps `admin_users` | It acts only on the caller's own account and proves the current password, which is a stronger check than a version. `auth/*` has never carried a version, and the forced step runs before anything else has loaded. The owner accepted this on 2026-11-06 | Requiring it would make the client read a version before the one form that must not fail, with nothing to protect against |
