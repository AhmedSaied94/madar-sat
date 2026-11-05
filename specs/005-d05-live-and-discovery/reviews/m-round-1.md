# Implementation review: 005-d05-live-and-discovery, lane M, round 1

- Date: 2026-11-04 · Reviewer: Claude Code (claude-opus-5-5), layer review by a Sonnet subagent, every HIGH re-checked on Opus
- Branch: d05-m · Base: d25db29 (the lane's own parent) · Head: 01ae9d2, plus 0 uncommitted files
- Change: 2 commits, 63 files (0 in another lane's folders), +5984 −50
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 3 · MEDIUM 10 · LOW 4

## Checks

| Check | Command | Result |
| --- | --- | --- |
| Analyze | `flutter analyze` | exit 0, no issues |
| Literals, tokens | `./tool/check_literals.sh`, `./tool/check_token_copy.sh` | exit 0 |
| Tests and goldens | `RTEST_HOST=flutter-tests rtest` | exit 0, 789 passed, 1 skipped. The first two attempts failed on an SSH connect timeout, and it ran once a connection was open |
| Client current | `dart run swagger_parser`, `dart run build_runner build -d` on a clean export of a9b4bed | exit 0, no diff in `lib/core/network/generated/` |
| `*.g.dart` beside providers | none | NOT RUN as a diff: only the generated client folder was compared |
| Coverage ≥ 80 % | none | NOT RUN: `rtest` wasn't run with coverage |
| PR #38 CI | `gh pr view 38` | green |
| Bypass scan | diff searched for ignore, skip; existing goldens | none; no existing golden changed |

## Findings

### HIGH

#### M-R1-1: follow, share and the S3 entry points are unreachable by screen reader

- ui · FR-041, FR-042, FR-044, §13.8, constitution III and IV · `app/lib/features/team/presentation/team_header.dart:36-39` (button at `:80-84`), `app/lib/features/competition/presentation/competition_sections.dart:43-46`, `app/lib/features/channel/presentation/channel_sections.dart:52-55` (share at `:94`), `app/lib/features/match_detail/presentation/match_hero.dart:48-51` · CONFIRMED (read)
- Problem: each header is wrapped in `Semantics(excludeSemantics: true)` and holds the action buttons inside it.
- Failure scenario: a TalkBack user opens S7 and can't reach Follow, and can't get from S3's hero to S7 or S8 at all. The widget tests use `find.text` and `find.byTooltip`, which ignore semantics, so they pass.
- Fix direction: keep the merged label on the text block only, with the buttons outside. Add a semantics test per screen.

#### M-R1-2: the entry points have no tests, and T081 is ticked

- tests · T081 ("router tests for the three paths and the entry points"), FR-040 to FR-042 · `app/test/core/router/router_test.dart` (paths only) · CONFIRMED (the change touches no test under `test/features/match_detail/` or `test/features/frequencies/`, and no test taps through to the three paths from S2, S3 or S5)
- Failure scenario: removing `onOpenChannel` from `where_to_watch_slivers.dart:547` or the hero's tap to S7 fails no test.
- Fix direction: a test for each of T086's entry points: S3 carriage row and S5 row to S6, S3 hero to S7 and S8, S2 header to S8.

#### M-R1-3: S6 is two taps from S3, against SC-008 and US2 scenario 1

- ui · SC-008 ("reaches S6 and S7 in one tap from S3"), US2-1 ("a channel in S3… tapped… S6 opens") · `app/lib/design/components/carriage_row.dart:165-205` · CONFIRMED (read)
- Problem: «عرض القناة» appears only when the row is expanded. PB S5.2 describes that for S5 ("Expanding a row shows the S3 details plus عرض القناة"), and PB outranks the spec, so the documents disagree. DC4's device check will trip on it.
- Fix direction: ask the owner which holds. If the spec does, S3's row needs a one-tap way to S6. If PB does, change SC-008.

### MEDIUM

- **M-R1-4** · `app/lib/features/matches/presentation/match_days_list.dart:67`, `app/lib/design/components/match_row.dart:242` · CONFIRMED. One `followed` flag covers both teams, and the star is drawn only beside the home team, so a followed away team puts the star on its opponent. The S7 golden shows this.
- **M-R1-5** · `app/lib/features/competition/presentation/competition_sections.dart:~203` · CONFIRMED. `RightsHolderRow` never passes `RightsHolderRef.logo`, so S8 always shows the text fallback. Tests use `logo: null`.
- **M-R1-6** · `app/lib/features/channel/presentation/channel_sections.dart:523-530` · CONFIRMED. S6's match rows have a label with no time, status or score, and `excludeSemantics` hides the rest. `:523` also joins names with no bidi isolation for Latin names.
- **M-R1-7** · `app/lib/core/router/app_router.dart:88`, `app/CLAUDE.md` · CONFIRMED. A deep link gives a stack of only the sheet, so its scrim sits over nothing, while `app/CLAUDE.md` says it opens over S2. `channel_sheet_test.dart` uses an opaque page and `push`, so it doesn't test this.
- **M-R1-8** · `app/lib/features/favorites/data/favorites_providers.dart:28-30` · CONFIRMED. PB S9's «مبارياتي القادمة» is for followed items, but a followed competition adds nothing.
- **M-R1-9** · `app/lib/features/channel/presentation/channel_sheet.dart:232` · CONFIRMED. S6 uses the 24 h target, though the document carries upcoming matches, so an offline copy under a day old shows no age (US2-5). The contract allows "the existing rules", so this may be a judgment call.
- **M-R1-10** · `channel_sheet.dart:236`, `match_days_list.dart:49` · CONFIRMED. `ListView(children)`, and a `shrinkWrap` builder per day inside a sliver, build every row. Rows are bounded at 20 and 30, so it's a cost, not a failure (constitution VIII, T083).
- **M-R1-11** · `app/test/features/channel/channel_sheet_test.dart:166-178` · CONFIRMED. "Dark and LTR" asserts the ambient direction is RTL, so it can't fail if the readout changes. S8's local-day grouping has no widget test with `match_date` differing from the local day. The new screens have no test that polling is released on dispose.
- **M-R1-12** · `match_hero.dart`, `match_group_section.dart` · PLAUSIBLE. The new tap targets look about 24–28 dp tall, under the 48 dp minimum, and the hero's fill may hide the ripple.
- **M-R1-13** · T090 · PLAUSIBLE. The note lists two differences from the boards. The review saw more: S8's tabs are underlined on the board and `Segmented` here, its subtitle is missing, S6's readout and copy order is reversed, and the follow hint is split from its button. Goldens compose sections only, with no top bar, handle or scrim.

### LOW

- **M-R1-14** · `channel_sections.dart` is 734 lines with 8+ widgets, and `_FailureView`, `_Empty` and `refresh()` are copied three times.
- **M-R1-15** · `competition_page.dart:77`: a raw 300 ms. `channel_sections.dart:634`: `.toLocal()` rather than the display zone.
- **M-R1-16** · Pull to refresh fires two requests (`drain`, then `invalidateSelf`). `l.details` is now unused.
- **M-R1-17** · `favoriteCompetitions` shows an icon rather than the logo, and its doc says it revalidates, though `firstWhere` stops at the cached copy.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US2-1 S6 | `channel_sheet.dart`, `channel_sections.dart` | `channel_sheet_test.dart`, `s6_channel` goldens | Built; **two taps: M-R1-3** |
| US2-2 history | `channel_sections.dart` | `channel_sections_test.dart` | Done |
| US2-3 S7 | `team_page.dart` | `team_page_test.dart`, goldens | Done; no entry test (M-R1-2) |
| US2-4 S8 | `competition_page.dart` | `competition_page_test.dart`, goldens | Done, except M-R1-5 |
| US2-5 offline | `SwrRepository`, screens | `document_swr_cases.dart`, widget tests | Done, except M-R1-9 |
| US2-6 local day, unknown, estimated | `match_days.dart` | `match_days_test.dart`, widget tests | Done. S8 can't get TBD rows until B1-R1-15 |
| FR-043 cached, age, RTL | all | tests, goldens | Done |
| FR-044 follow | `follows_repository` | widget tests | Done by touch; **not by screen reader: M-R1-1** |
| FR-045 no flag code | none | grep | Done |
| SC-008 device | none | none | Owner's walk (DC4) |

## Task audit

Ticked 14, verified 12, not done 0, partly done 2.

| Task | Ticked | Finding |
| --- | --- | --- |
| T081 | yes | No entry-point tests (M-R1-2), weak readout test (M-R1-11) |
| T090 | yes | More differences from the boards than it lists (M-R1-13) |

## Owner must review

- S6, S7 and S8 next to `Channel.png`, `Team.png` and `Competition.png`, in both themes (M-R1-13).
- The choice in M-R1-3.

## Outside this change

- `MatchRow`'s single `followed` flag comes from an earlier day; D5 is the first screen to set it for either team.

## Not reviewed

- The device walk (owner, DC4).
- Coverage, and whether `*.g.dart` files beside providers are current.
