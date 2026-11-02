# Implementation review: 003-d03-follow-push-sources, lane M, round 2

- Date: 2026-11-01 · Reviewer: Claude Code (Opus 5.5 lead; Sonnet flutter-reviewer subagent; every CRITICAL/HIGH re-read by the lead)
- Branch: 003-d03-follow-push-sources (all four lanes' round-1 fixes merged; no lane branch checked out, as in round 1) · Base: master (merge base 5323669) · Head: 5cd804f, plus 0 uncommitted files
- Change: 31 commits, 485 files in all (255 lane M), +54040 −957. Round-1 fix commit: e1a442e (119 files)
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 4 · MEDIUM 7 new (plus round-1 ones open) · LOW 4 new

## Checks
| Check | Command | Result |
| --- | --- | --- |
| analyze | `cd app && flutter analyze` | exit 0, "No issues found!" |
| literals | `./tool/check_literals.sh` | exit 0 |
| token copy | `./tool/check_token_copy.sh` | exit 0 |
| flutter test | `RTEST_HOST=flutter-tests rtest` (from `app/`) | first attempt: "another run for madar_sat is in progress" — an orphaned `flutter_tester` (parent 1, ~6 h old) held `~/rtest/.lock-madar_sat`; the lead killed it. Rerun: exit 0, **605 tests, "All tests passed!"** |
| `./tool/test_all_zones.sh`, `flutter build apk`, `flutter build web` | — | NOT RUN: `app.yml` / `pwa.yml` run them |
| Generated code | `git show e1a442e -- app/lib/core/network/generated` | 49 `*.g.dart` files changed consistently (`'x': ?instance.x`) from `app/build.yaml`'s new `include_if_null: false`: generator output, not hand edits. Regeneration diff NOT RUN (rewrites tracked files) |
| Ways around the checks | diff scan of e1a442e | none: no `skip:`, `.only`, `@Skip`, hand `// ignore:`; goldens rewritten only for `list_row`, `buttons`, `madar_dialog`, which M-R1-11/-12 changed |

## Previous round
| Finding | Now |
| --- | --- |
| M-R1-1 no registration / update / follow sync | fixed in code (`device_repository.dart:35-63`, `device_sync.dart`, generated client, `Authorization: Device`); new defects M-R2-1, M-R2-2, M-R2-4 |
| M-R1-2 FCM id stored as auth token | fixed: `SecureKeys.pushToken`, `push_token_sync.dart:30-35`; tests |
| M-R1-3 delete did nothing on the server | fixed: DELETE first, wipe only on success, honest offline copy; edge cases MEDIUM M-R2-6 |
| M-R1-4 forced update on Android | fixed app side (`system_views.dart:110-118,152`); B2's `APP_BUILD_NUMBER` half still open (`app-release.yml:67`) — do not raise `min_supported_build` before it lands |
| M-R1-5 S2 ignores My satellites | fixed: `swr_repository.dart:51-103`, `matches_providers.dart:29-34`; tests |
| M-R1-6 zone changes clock text only | **partly fixed**: lists and S9 follow the zone; the S3 hero date does not — M-R2-3 |
| M-R1-7 exit snackbar on 2 of 5 tabs | fixed: `app_router.dart:50-73`; `router_test.dart:243` |
| M-R1-8 four error codes without copy | fixed (mapping, `error_copy.dart:23-28`); reachability/honesty is M-R2-2 |
| M-R1-9 T118 test missing | fixed: `test/core/platform/push_service_test.dart` (8 tests) |
| M-R1-10 web tap lands on home | fixed in code (`url_strategy*.dart`, `applyUrlStrategy()` in all mains); its test is vacuous (MEDIUM M-R2-5) |
| M-R1-11 RTL arrows | fixed: `list_row.dart:102-105`, `more_page.dart:104`, onboarding; `rtl_arrows_test.dart` |
| M-R1-12 48 dp targets | fixed for hit targets; visual size grew (MEDIUM M-R2-7) |
| Round-1 MEDIUM/LOW | fixed: interceptor doc/code/test; S9 «اليوم». Still open: foreground push navigates on arrival; push route allow-list; `register()` at cold start (web prompt); Android channel/icon; Remote Config defaults 5 of 8; follow + dirty flag as two writes (now consequential, M-R2-9); S1.4 on iPhone Safari, S1.2 picker, rest of S9; offline banner on S2 only; S0 `EmptyStateKind.error`; dead `MadarButton.expanded`; «المزيد» → `/settings`; splash; T136/T137 screenshots (owner); stale `app/CLAUDE.md`; the `PushTokenSync` double-listener LOW |

## Findings
### CRITICAL
None.

### HIGH
#### M-R2-1: A follow or push id changed while a sync is in flight is never sent
- Layer app · Source spec US2 scenarios 6–7 (the device's set is the source of truth), FR-041, the class's own contract at `device_sync.dart:76-77` ("a change made during a send is never lost") · Location `app/lib/features/devices/data/device_sync.dart:43-48,157,174`; `app/lib/features/follows/data/follows_repository.dart:27-28,39-40`; `app/lib/features/devices/data/push_token_sync.dart:35` · CONFIRMED
- Problem: the listeners call `sync()` only on the dirty flag's false→true edge, and `_sendDevice`/`_sendFollows` call `markSyncClean` unconditionally after the PUT. A `markSyncDirty` while the flag is already true produces no edge, so `_again` is never set, and the clean then erases it.
- Failure scenario: follow team A → `PUT …/follows {A}` starts; follow team B before it returns → flag already dirty, no edge; the PUT returns and the flag is cleared → the server has {A} only, and no later launch, resume or reconnect re-sends (the flag is clean) → no reminders for B until some other follow changes. Same for the push id arriving during `PUT /devices/me` on the web/PWA first run: the server never gets a push token, so no reminder is ever delivered.
- Fix direction: clear the flag only if nothing changed since the read (a revision counter or the `attemptedAt` compare-and-clear in one drift statement), or clear before sending and re-flag on failure; trigger `sync()` on every dirty write. Test with a held fake response (Completer): change a follow, the push id and a satellite mid-send and expect a second PUT.

#### M-R2-2: `422 unknown_follow_target` is not handled, so one stale id blocks every later follow (T115 ticked)
- Layer app · Source T115 ("a `422 unknown_follow_target` drops those ids locally"), `contracts/public-api.md` follows, constitution II (honest copy) · Location `app/lib/features/devices/data/device_sync.dart:123-131`; `app/lib/core/l10n/app_ar.arb` `errorUnknownFollowTarget`; the code appears only in `app/lib/core/l10n/error_copy.dart:26` · CONFIRMED
- Problem: the PUT is atomic on the server; the app records the code, keeps the flag dirty and re-sends the same set forever. The Arabic copy says the ids were removed («أزلناها من متابعاتك»), which nothing does, and nothing shows it.
- Failure scenario: a followed match is merged away by an importer dedupe → every later `PUT …/follows` returns 422 → no new follow ever reaches the server, so none of them gets a reminder, silently.
- Fix direction: read the unknown ids from the error meta, drop them from drift in one transaction, re-send, and test it; make the copy true where it is shown.

#### M-R2-3: The S3 hero date still uses the device zone (rest of M-R1-6)
- Layer ui · Source spec US2 scenario 10 ("every screen follows the chosen zone"), constitution II · Location `app/lib/features/match_detail/presentation/match_hero.dart:130,151,194` (`_localDay => (match.kickoffAt ?? match.matchDate).toLocal()`) · CONFIRMED
- Problem: the hero's time follows the chosen zone, but the date next to it comes from `toLocal()`.
- Failure scenario: chosen zone GMT−12 on a UTC+2 phone, kickoff 22:30 UTC → S3 shows Thursday's date beside a 10:30 time that is Wednesday in the chosen zone: the match appears a day late.
- Fix direction: derive the day from the chosen zone's wall clock (`MadarDisplayScope.zoneOf(context).wallClock(kickoffAt)`); for a TBD kickoff use `matchDate` without `toLocal()`; add a widget test at the day boundary.

#### M-R2-4: The resume retry never runs, and the device-sync paths T114 names have no tests (T114 ticked)
- Layer app/tests · Source T114 ("a 401 re-registers with the same install id; push token, settings and satellite changes send `PUT /devices/me`; a failure … retries on resume"), FR-041, constitution test-first · Location `app/lib/app.dart:43,48-50,77`; `app/test/features/devices/device_repository_test.dart:218-225` · CONFIRMED
- Problem: `late final AppLifecycleListener _lifecycle = …` is lazy and first touched in `dispose()`, so no `onResume` listener exists while the app runs. The launch `sync()` in `initState` returns at once while `appSettingsProvider` has no value yet. No test reaches `_sendDevice` (satellites, push id, version), the 401 re-register or any retry trigger; dropping `satelliteIds` or `pushToken` from the body fails nothing.
- Failure scenario: a follow sync fails offline in the background; the user returns to the app (resume) → nothing retries until a connectivity edge or another change; satellites chosen in S1.3 never reach the server unchanged by any test.
- Fix direction: assign the listener in `initState`; await `appSettingsProvider.future` for the launch attempt; add tests for `PUT /devices/me`'s body, the 401 re-register with the same install id, and resume/reconnect retries.

### MEDIUM
- **M-R2-5 Tests that cannot fail.** `matches_providers_test.dart:218` builds its DB with the same fixed offset it asserts (reverting `ZoneHolder` fails nothing); `DayView.offsetAt` is unpinned; `router_test.dart:228` boots `/match/42`, which worked under the hash strategy too.
- **M-R2-6 «حذف بيانات جهازي» edges** (`settings_page.dart:301-331`): with no local token it skips the DELETE and says the server row is gone; a 401 on DELETE never wipes; `ref.read` after the await without a `mounted` check.
- **M-R2-7 `small`/`extraSmall` buttons paint 48 dp, not 40/32** (`button.dart:101-134`): the fill wraps the hit box; `button_targets_test.dart:31-34` measures the inner box. Put fill and shape on the visual box as `FollowButton` does.
- **M-R2-8 Clearing all satellites is never sent** (`device_sync.dart:153` sends null, omitted by `include_if_null:false`): reminders keep naming a satellite the user removed. Send `[]`. `tz` is almost never sent (`ianaTimeZoneName()` gets an abbreviation on Android).
- **M-R2-9 Follow write and dirty flag are two writes** (`follows_repository.dart:27-28`): a process death between them loses the follow for the server, now that the flag has a reader. One transaction.
- **M-R2-10 Docs and tasks:** `owner-actions.md` (T136) cites `python -m app.cli devices`, which `backend/app/cli.py` does not have; T114/T115 keep "lands with T133"; `app/CLAUDE.md` still says schemaVersion 2 and omits `build.yaml`'s `include_if_null:false` and `ZoneHolder`.
- **M-R2-11 Web DB assets are relative URIs under the path strategy** (`app_database.dart:175-178`) — PLAUSIBLE; check a cold `/match/42` deep link in T137.

### LOW
- `PushTokenSync` can attach two listeners if invalidated during `currentToken()`.
- DB pruning at open uses the device zone (holder defaults to auto before settings load).
- `sync()` swallows every error (`device_sync.dart:94`), documented.
- One extra S2 request on cold start from the satellites null→value flip.

## Requirements
| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US2 sc. 1–3 onboarding, favorites, settings | onboarding/favorites/settings features | widget tests | Built |
| US2 sc. 4 satellites sent to the server | `device_sync.dart:_sendDevice` | none | **Partial (M-R2-4, M-R2-8)** |
| US2 sc. 6–7 follows reach the server | `device_sync.dart:_sendFollows` | `device_repository_test.dart:81-158` | **Partial (M-R2-1, M-R2-2)** |
| US2 sc. 8 delete my device | `settings_page.dart:301-331` | `settings_screen_test.dart` | Built (edges M-R2-6) |
| US2 sc. 10 chosen zone everywhere | `ZoneHolder`, `database_provider.dart` | `matches_providers_test.dart` (vacuous) | **Partial (M-R2-3, M-R2-5)** |
| Notification tap opens the match (web, Android) | `url_strategy*.dart`, `push_service.dart` | `router_test.dart:228` (vacuous on web) | Built |
| S0 forced update | `system_views.dart` | `system_screens_test.dart` | Built (B2 half open) |

## Task audit
Round-1 tasks: ticked 12, verified 10, partly done 2 (M-R1-6 → M-R2-3; M-R1-1's sync → M-R2-1/-4). Original tasks: T114 and T115 ticked but partly not done (M-R2-4, M-R2-2).

## Owner must review
- `app/lib/features/devices/data/device_sync.dart`, `device_repository.dart`: what the app sends to `/v1/devices` and when.
- `app/lib/features/settings/presentation/settings_page.dart:301-331`: «حذف بيانات جهازي».
- S3 hero, S15 settings and the S1 onboarding screens next to their PNGs (T136/T137 screenshots still owner-open).

## Outside this change
- `app-release.yml:67` (lane B2) passes only `--build-number`; see M-R1-4.

## Not reviewed
- Real-device push, the web build and PWA deep links, the zones script, the regeneration diff.
