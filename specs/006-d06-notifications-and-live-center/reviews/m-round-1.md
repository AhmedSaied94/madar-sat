# Implementation review: 006-d06-notifications-and-live-center, lane M, round 1

- Date: 2026-11-09 · Reviewer: Claude Code (Opus 5.5, `claude-opus-5-5`), with two Sonnet layer reviewers; every HIGH re-checked on Opus
- Branch: `d06-m` · Base: `2df5090` (lane A's merge #48, which this branch was rebased on; the lane's own commits are `d5d4893`, `7f75c5c`) · Head: `7f75c5c`, plus 0 uncommitted files
- Change: 2 commits, 118 files (0 in another lane's folders; the 6 generated files are this lane's own `@riverpod` `.g.dart` outputs), +5 679 −237
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 2 · MEDIUM 7 · LOW 7

The lane is already merged into the spec branch (PR #49, 2026-11-08).

## Checks

| Check | Command | Result |
| --- | --- | --- |
| analyze | `flutter analyze` (local Flutter 3.47.7 = `.flutter-version`, clean copy of `d06-m`) | exit 0, "No issues found!" |
| token copy | `./tool/check_token_copy.sh` | exit 0 |
| literals | `./tool/check_literals.sh` | exit 0 |
| tests + goldens | `RTEST_HOST=flutter-tests rtest` (from `../madar-m/app`) | exit 0, 974 passed, 1 skipped (pre-existing `markTestSkipped`) |
| service worker | `node --test test_web/` | exit 0, 22/22 |
| generated code current | `dart run swagger_parser && dart run build_runner build -d && flutter gen-l10n`, then `git status -- app/lib` | exit 0, no diff |
| zones, apk and web builds | `./tool/test_all_zones.sh`, `flutter build apk/web` | NOT RUN (zones would run `flutter test` locally; builds need `env/prod.json`). CI `app` `check` passed on #49 |

## Findings

### CRITICAL

None.

### HIGH

#### M-R1-1: «تفعيل» and «عرض» are volt text on light surfaces, about 1.1:1
- Layer ui · Source constitution (WCAG AA in both themes), FR-059 (the banner's «عرض»), FR-063 (the platform state's action) · `app/lib/features/settings/presentation/notification_settings.dart:246`; `app/lib/features/notifications/presentation/foreground_banner.dart:126` · CONFIRMED
- Problem: both are bare `TextButton`s; the theme sets `primary: c.accent` (`madar_tokens.dart:512`) and no `textButtonTheme`, so the label is volt `#C8F542` on `postponedContainer` / `surface2`. The committed golden `settings_notifications_denied_light_1.0.png` shows «تفعيل» barely visible. The board draws a filled button (`FollowSheet.html:45`).
- Failure scenario: a light-theme fan who denied notifications can't see the only control that re-enables them; a goal banner's «عرض» is near invisible.
- Fix direction: a token foreground that passes AA in both themes (or `MadarButton`, as the board does); add a banner golden in both themes.

#### M-R1-2: The running score is a raw `1 – 0` string inside Arabic text
- Layer ui · Source constitution III ("A raw `1 - 0` string MUST NOT appear in RTL text … built from isolated parts, each number beside its own team") · `app/lib/design/components/event_timeline_item.dart:39-41`, `app/lib/core/l10n/app_ar.arb:337` (`"هدف · {score}"`) · CONFIRMED
- Problem: the caption and the Semantics label concatenate `'${home} – ${away}'` into the Arabic string. It renders in the right order today only through implicit bidi resolution (golden `event_timeline_light_1.3.png`), which the rule forbids relying on.
- Fix direction: build the caption from `ScoreParts` / `LtrIsland` beside the Arabic word, as the hero does, and give the Semantics label each team's number.

### MEDIUM

- **M-R1-3** (tests) The two wiring points have no test that fails if they break: `app_router.dart`'s `section: state.uri.queryParameters['section']` (tests build their own `GoRouter`), and `match_detail_page.dart`'s `highlightScore: ref.watch(liveCenterEnabledProvider)` (only `match_hero_test.dart` passes `highlight:` directly). T097 asks for the flash in `match_detail_page_test.dart` too.
- **M-R1-4** (tests/spec) T088's flag-off baseline landed in the same commit as the S3 code (`d5d4893`), so SC-013's "unchanged from today's goldens" can't be shown from git. No regression was found by reading and by opening `match_detail_flag_off_live_light_1.0.png`.
- **M-R1-5** (ui) The S3 tabs are about 40 dp wide (`live_center.dart:167-207`: `minHeight` only), under the 48 dp minimum.
- **M-R1-6** (ui) `Semantics(excludeSemantics: true)` without `onTap` on the tab buttons (`live_center.dart:179-185`) and the banner's dismiss (`foreground_banner.dart:128-131`): screen-reader users get a button with no action (the codebase's own `button.dart:99-101` notes this).
- **M-R1-7** (ops) No screenshot next to the PNGs for S3 live, lineups and S15 (delivery-plan §8.1 item 12), though T118's note says the comparison is done; PR #49 has none.
- **M-R1-8** (spec, PLAUSIBLE) New copy not on any board or in PB §14 («الأساسيون», «البدلاء», «معرّف الجهاز», «تم نسخ معرّف الجهاز», «سجّل هدفاً», «مركز المباراة», «الإشعارات متوقفة لهذا التطبيق»…) is recorded as approved only in agent-written text in owner-actions. Have the owner confirm it in the spec's Clarifications.
- **M-R1-9** (ops) `app/CLAUDE.md` is not updated: the push-route allowlist and its twin in `web/firebase-messaging-sw.js`, the no-navigate foreground rule and banner, `features.*` flags and `bundledJson`, the `notifications.prefs` and `device.id` settings keys, `PushPermissionState`, and the `event_count` re-read in "Polling".

### LOW

- **M-R1-10** A stale cached match with the flag on shows two `StaleHint`s (`match_detail_page.dart:353-363`, `live_center.dart:70-79`).
- **M-R1-11** `_PermissionOff`'s "stopped" copy also shows for `notAsked`.
- **M-R1-12** `channel_list.dart:17-28`: the new const sits between `ChannelList`'s doc comment and the class.
- **M-R1-13** `AppFeatures.bundledJson` is a hand-written string with no test tying it to `const AppFeatures()`.
- **M-R1-14** The permission read runs in `initState` before the install-steps branch (`notification_settings.dart:45`), unobserved on an iPhone browser (PLAUSIBLE unhandled error).
- **M-R1-15** The foreground banner never auto-dismisses, is a second banner implementation, and isn't coordinated with `OfflineBanner`; the lineups board's source note isn't built; the S15 master row lacks the board's accent tile.
- **M-R1-16** `forget()` writes `device.id` without invalidating `appSettingsProvider` (its one caller does today); the S3 re-read listens while S3 is covered; the first non-null live state is only a baseline.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US2-1 timeline order, minute, side, markers | `domain/timeline.dart`, `event_timeline_item.dart`, `live_center/` | `timeline_test`, `live_center_test`, goldens | OK (M-R1-2 on the running score) |
| US2-2 labels, red card `error` with icon | `_EventTile` | `live_center_test` | OK |
| US2-3 no player | `event_timeline_item.dart` | `live_center_test`, `timeline_test` | OK |
| US2-4 score flash | `match_hero.dart` `ScoreFlash` | `match_hero_test` | OK (page wiring untested, M-R1-3) |
| US2-5 / SC-006 event within 60 s | `_onLiveState` re-read | `match_detail_page_test` | OK (B1-R1-35 note) |
| US2-6 running score only when it adds up | `timeline.dart` | `timeline_test` | OK |
| US2-7 lineups tab | `lineup_layout.dart`, `live_center/` | `lineup_layout_test`, `live_center_test` | OK |
| US2-8 estimated: note only | `live_center.dart:51-52` | `live_center_test` | OK |
| US2-9 no feed / flag off: nothing | `LiveCenterSliver` | `live_center_test`, flag-off goldens | OK (M-R1-4) |
| US2-10 push routes | `core/platform/push_routes.dart`, SW | `push_routes_test`, `messaging_sw_routes_test` | OK (router wiring untested, M-R1-3) |
| US2-11 offline cached events | `detailWithLiveState`, `StaleHint` | `live_center_test` | OK (M-R1-10) |
| US2-12 S15 switches, offline sync | `notification_settings.dart`, `device_sync.dart` | `settings_screen_test`, `device_sync_test` | OK |
| US2-13 permission and iPhone states | `notification_settings.dart` | `settings_screen_test` | OK, but the action is unreadable in light (M-R1-1) |
| FR-050 flags | `remote_config.dart` | `remote_config_test` | OK |
| FR-059 routes, foreground banner | `push_service.dart`, `foreground_banner.dart` | `push_service_test`, `foreground_banner_test` | OK (M-R1-1 on «عرض») |
| FR-060 follow note | `match_follow_button.dart` | `follow_action_test` | OK |
| FR-061 S5.2 badge | `carriage_row.dart`, `channel_list.dart` | `frequencies_test` | OK |
| FR-062 device ID | `device_repository.dart`, `settings_page.dart` | `device_repository_test`, `settings_screen_test` | OK |
| FR-064 widget + golden coverage | four golden files, `goldenVariants` | 48 new PNGs | OK |
| SC-013 flag off unchanged | flag-off goldens | added with the code (M-R1-4) | Unprovable from git |

## Task audit

Ticked 31, verified 29, not done 0, partly done 2. T118 is unticked and correctly the owner's device walk.

| Task | Mismatch |
| --- | --- |
| T088 | Goldens committed with the S3 code, not before it (M-R1-4) |
| T097 | Flash not tested at page level (M-R1-3) |

## Owner must review

- S3 live center (`live_center/`, `event_timeline_item.dart`) next to `madar-design/app-flutter/screens/03-match-detail/Match-Live.png`, and lineups next to `Match-Lineups.png`, in both themes.
- S15's notification group (`notification_settings.dart`) next to `screens/06-more-settings-rights/Settings.png`, light theme especially (M-R1-1).
- `app/lib/core/platform/push_routes.dart` and `app/web/firebase-messaging-sw.js`: the route allowlist.

## Outside this change

- `bottom_nav.dart:76-82` has the same `excludeSemantics` without `onTap` pattern (pre-existing).
- Every pre-existing `TextButton` on a light surface inherits the volt foreground; a themed `textButtonTheme` would fix all of them along with M-R1-1.

## Not reviewed

- `./tool/test_all_zones.sh` and the apk/web release builds were not run (CI covered them on #49).
- The device walk on Android and an installed iPhone PWA (T118) is the owner's.
