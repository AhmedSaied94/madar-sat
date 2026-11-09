# Implementation review: 006-d06-notifications-and-live-center, lane M, round 2

- Date: 2026-11-09 · Reviewer: Claude Code (Opus 5.5, `claude-opus-5-5`), layers reviewed directly (the round's new code is one commit)
- Branch: `d06-m` · Base: `origin/master` (merge base `b7fd7d9`); lane M's own work is `2df5090..6d2d0e7` (`d5d4893`, `7f75c5c`, and the round-1 fix `6d2d0e7`) · Head: `6d2d0e7`, plus 0 uncommitted files
- Change: 19 commits, 316 files against `origin/master`, of which 162 are in other lanes' folders. All 162 come from the B1, B2 and A PRs merged into the spec branch (#46, #47, #48) before this lane branched at `2df5090`; none is a lane M edit. Lane M's own change: 3 commits, 126 files (122 under `app/`, plus `docs/owner-actions.md`, `docs/runbooks/remote-config.md`, `reviews/m-round-1.md`, `tasks.md`), +6 160 −238. Round-1 fix commit `6d2d0e7`: 34 files, +529 −49.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 0 · LOW 1

## Checks

| Check | Command | Result |
| --- | --- | --- |
| analyze | `flutter analyze` (local Flutter 3.47.7 = `.flutter-version`, in a `git archive HEAD` copy so the worktree stays untouched) | exit 0, "No issues found!" |
| token copy | `./tool/check_token_copy.sh` | exit 0, "token and font copies match the design package" |
| literals | `./tool/check_literals.sh` | exit 0 |
| tests + goldens | `RTEST_HOST=flutter-tests rtest` (from `../madar-m/app`) | exit 0, 980 passed, 1 skipped (pre-existing `markTestSkipped` in `write_env_test.dart`, `env/example.json` not synced) |
| service worker | `node --test test_web/` | exit 0, 22/22 |
| generated code current | `dart run swagger_parser && dart run build_runner build -d && flutter gen-l10n` in the archive copy, then `diff -rq lib <worktree>/app/lib` | each exit 0; diff exit 0 (no change) |
| ways around the checks | `git show 6d2d0e7` read for `skip`, `ignore`, analysis or coverage config, weakened assertions | none; goldens rewritten (`event_timeline_*`, `live_center_live_*`, `live_center_finished_*`, `settings_notifications_denied_*`) all follow the UI change of M-R1-1 / M-R1-2; `foreground_banner_*` are new |
| zones, apk and web builds | `./tool/test_all_zones.sh`, `flutter build apk/web` | NOT RUN: the zones script runs `flutter test` locally, which is not allowed on the laptop; the release builds need `env/prod.json`, which isn't in the checkout. CI `app` covers both |

## Previous round

| Finding | Now |
| --- | --- |
| M-R1-1 (HIGH) «تفعيل» and «عرض» volt on light | **fixed**. «تفعيل» is a filled `xs` `MadarButton` with `postponed` fill and `bg` text (`notification_settings.dart:249-256`), as `FollowSheet.html:45` draws it: #955200 on #F2F3EF ≈ 5.4:1 light, #FFB627 on #07090C ≈ 11:1 dark. «عرض» is a ghost `MadarButton`, `accentText` #3F6A06 light (`foreground_banner.dart:129-134`). `test/design/components/action_contrast_test.dart` asserts ≥ 4.5:1 and not `accent` in light, both themes, both labels; it passes on the box. Goldens `settings_notifications_denied_light_1.0.png` and the new `foreground_banner_*` show both readable. See M-R2-1 for the ghost button's look. |
| M-R1-2 (HIGH) raw `1 – 0` in Arabic text | **fixed**. `_Caption` (`event_timeline_item.dart:246-277`) lays out «هدف», «·» and `ScoreParts` (two `LtrIsland`s, home's number first so it sits on the right in RTL). `tlGoalWithScore` is gone (no reference left in `lib/` or `test/`). The Semantics label names each team beside its own number (`tlRunningScoreSemantics`). `live_center_test.dart` has a digit–dash–digit guard on every `Text` in a goal row and checks `ScoreParts` home/away; the golden `event_timeline_light_1.0.png` reads «هدف · 1 - 0» with home's 1 on the right. |
| M-R1-3 (MEDIUM) router `section` and `highlightScore` wiring untested | still open: `match_detail_page_test.dart:127-135` still builds its own `GoRouter`; `match_detail_page.dart:370` `highlightScore` is not exercised at page level. |
| M-R1-4 (MEDIUM) T088 baseline not provable from git | no longer actionable (history is fixed); note stands. |
| M-R1-5 (MEDIUM) S3 tabs ~40 dp wide | still open (`live_center.dart:186-187`, `minHeight` only). |
| M-R1-6 (MEDIUM) `excludeSemantics` without `onTap` | partly fixed: «عرض» is now a `MadarButton`, whose node carries `onTap`. Still open on the banner's dismiss (`foreground_banner.dart:136-141`) and the S3 tabs (`live_center.dart:178-184`). |
| M-R1-7 (MEDIUM) no screenshot beside the PNGs | still open: none added in this round. |
| M-R1-8 (MEDIUM, PLAUSIBLE) new copy not owner-confirmed | still open; this round adds «النتيجة {home} {homeScore} و{away} {awayScore}» (spoken only) and «·». |
| M-R1-9 (MEDIUM) `app/CLAUDE.md` not updated | still open (`git diff 2df5090 HEAD -- app/CLAUDE.md` is empty). |
| M-R1-10 … M-R1-16 (LOW) | still open; `6d2d0e7` touches none of them. |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

None new.

### LOW

#### M-R2-1: The banner's «عرض» draws as a white tile, not a ghost button

- Layer ui · Source `madar-design/design-system/components.css:356` (`.btn-g` has no fill), Button README ghost variant · `app/lib/features/notifications/presentation/foreground_banner.dart:129-134`, via `app/lib/design/components/button.dart:114` · CONFIRMED
- Problem: `MadarButton` paints `background ?? colors.surface1` for every variant, so the ghost variant has a `surface1` fill. On the banner's `surface2` row «عرض» becomes a 32 dp white tile (golden `foreground_banner_light_1.0.png`). The fill predates this change; the round-1 fix newly relies on it.
- Failure scenario: a goal banner in light theme shows a raised white box where the design has a text-only action. Readable, but off the design.
- Fix direction: give the ghost variant a transparent fill in `MadarButton` (check the other four ghost uses' goldens), or pass `background: colors.surface2` here.

## Requirements

Unchanged from round 1 except the two rows the fixes close:

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US2-1 timeline, running score from isolated parts (constitution III) | `event_timeline_item.dart` `_Caption` | `live_center_test` (raw-score guard, `ScoreParts` values), `event_timeline_*` goldens | OK |
| US2-13 / FR-063 permission state action readable | `notification_settings.dart:249-256` | `action_contrast_test`, `settings_notifications_denied_*` goldens | OK |
| FR-059 foreground banner «عرض» readable | `foreground_banner.dart:129-134` | `action_contrast_test`, `foreground_banner_*` goldens, `foreground_banner_test` | OK (M-R2-1 on its look) |
| All other rows of round 1 | as round 1 | as round 1 | as round 1 (M-R1-3, M-R1-4 notes stand) |

## Task audit

Ticked 33, verified 31, not done 0, partly done 2. M-R1-1 and M-R1-2 are done as written (files, behaviour, tests, goldens). T088–T119 keep round 1's audit: T088 and T097 partly done, as notes (M-R1-4, M-R1-3). T118 is unticked and correctly the owner's device walk.

## Owner must review

- S15's notification group (`app/lib/features/settings/presentation/notification_settings.dart`) next to `madar-design/app-flutter/screens/06-more-settings-rights/Settings.png` and `05-follow-and-search/FollowSheet.png`, both themes: the new «تفعيل» button.
- The foreground banner (`app/lib/features/notifications/presentation/foreground_banner.dart`, goldens `foreground_banner_*`) against the Banner component: «عرض»'s white tile (M-R2-1).
- S3 live center (`event_timeline_item.dart`, `live_center/`) next to `screens/03-match-detail/Match-Live.png` and `Match-Lineups.png`, both themes: the running-score caption.
- `app/lib/core/platform/push_routes.dart` and `app/web/firebase-messaging-sw.js` (the route allowlist), unchanged since round 1.

## Outside this change

- `6d2d0e7` also carries the B1, B2 and A `### Review fixes (round 1)` blocks in `tasks.md` (lines 224, 284, 332), written by those lanes' reviews, not by lane M. They are the same text as on the spec branch (`c744e10`), which has them ticked since; the merge `c744e10` already resolved this. No lane M edit to another section.
- `MadarButton`'s ghost fill (`button.dart:114`, from `53cca0a`) affects every ghost button in the app, not only M-R2-1's.
- Round 1's notes stand: `bottom_nav.dart:76-82` `excludeSemantics` without `onTap`; pre-existing bare `TextButton`s on light surfaces inherit volt.

## Not reviewed

- Code unchanged since round 1 (`d5d4893`, `7f75c5c`) was not re-reviewed beyond re-checking each round-1 finding; the round-1 report covers it.
- `./tool/test_all_zones.sh` and the apk/web release builds (see Checks).
- The device walk on Android and an installed iPhone PWA (T118) is the owner's.
- No screenshot was taken beside the design PNGs; the goldens were compared instead (M-R1-7 stands).
