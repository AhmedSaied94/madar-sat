# Implementation review: 002-d02-core-flows, lane M, round 3

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); a layer subagent on Sonnet, every finding re-checked here
- Branch: `d02-features` (round 2 reviewed `2383482` from `d02-m`; that work is in `3ac2bf5` here) · Base: `origin/master` (merge base `68f1752`) · Head: `635919d`, plus 158 uncommitted files across the four lanes
- Change (lane M, this round): 1 commit (`635919d`, deletes `satellite_matches_repository.dart`) and the round-2 fixes, uncommitted: 11 files under `app/lib/`, `app/CLAUDE.md`, 15 test files (3 new: `architecture/providers_test.dart`, `core/network/dio_failure_test.dart`, `features/match_detail/match_hero_test.dart`), 8 regenerated goldens (`carriage_row_*`, `segmented_*`), and the deletion of `app/tool/check_providers.sh`. Nothing in another lane's folder.
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 2 · LOW 3 (2 PLAUSIBLE)

The three round-2 HIGHs are fixed, each with a test that fails on revert: the tuning line reads «11843 MHz», every `refresh()` checks `ref.mounted` before `invalidateSelf()`, and each `LivePollingScope` holds its own claim. The test suite ran on the test box this round, and all 480 tests passed. Two MEDIUMs remain. The new providers guard misses the `.autoDispose` and `.family` forms. Six provider `*.g.dart` files were not regenerated after their sources changed.

## Checks

App checks ran in a snapshot of this working tree (`git ls-files -co --exclude-standard`).

| Check | Command | Result |
| --- | --- | --- |
| deps | `flutter pub get` | exit 0 |
| analyze | `flutter analyze` | exit 0, no issues |
| client current | `dart run swagger_parser && dart run build_runner build -d`, then `diff -rq lib` against the working tree | `lib/core/network/generated`: no diff. **Six provider `*.g.dart` differ** (M-R3-2) |
| token copy | `./tool/check_token_copy.sh` | exit 0 |
| literals | `./tool/check_literals.sh` | exit 0 |
| tests | `RTEST_HOST=flutter-tests rtest` from the snapshot's `app/` (on the test box) | exit 0: **480 passed**. These ran on the regenerated `*.g.dart`, whose only difference is the hashes and doc comments |
| web assets | `./tool/check_web_assets.sh` | **NOT RUN** here; CI runs it now (`app.yml:69-73`) |
| zones | `./tool/test_all_zones.sh` | **NOT RUN**: it runs `flutter test` on the laptop, which the owner's rule forbids |
| goldens | compared old and new PNGs for `carriage_row_dark_1.0`, `carriage_row_light_1.3`, `segmented_light_1.0` | changed for the reasons the fixes give (MHz order, one position, provider and package lines; track 56 → 48 dp). The other five were not viewed |
| secrets | gitleaks v8.30.1 `dir .` from the snapshot root | exit 0 |

Ways around the checks: no `// ignore`, `ignore_for_file`, `@Skip` or `.skip(` in hand-written code. `analysis_options.yaml` and `pubspec.yaml` are untouched. `check_providers.sh` was replaced by a test that runs under `flutter test`; see M-R3-1 for what it misses.

## Previous round

| Finding | Now |
| --- | --- |
| M-R2-1 HIGH, «MHz 11843» | fixed: `carriage_row.dart:~290` one `LtrIsland`; the goldens read «11843 MHz»; three tests read the text's `Directionality` |
| M-R2-2 HIGH, `invalidateSelf()` after unmount | fixed in all five notifiers; tested for one (M-R3-3) |
| M-R2-3 HIGH, one shared poll controller | fixed: `live_poller.dart:100-157` claims keyed per scope, released in `dispose`; "a screen pushed over another keeps its own polling" |
| M-R2-4 raw error map | fixed: `dio_failure.dart:33-41` uses `ErrorEnvelope.fromJson`; `dio_failure_test.dart` |
| M-R2-5 SWR bypasses interceptors | fixed: `swr_repository.dart:~279-308` copies the app Dio's options and interceptors (except `EtagInterceptor`); the deviation from the task's `extra` design is in `app/CLAUDE.md` |
| M-R2-6 relative imports missed | fixed: `domain_imports_test.dart` matches every import form; fixture of 9 offenders |
| M-R2-7 `check_providers.sh` | replaced by `test/architecture/providers_test.dart`, run by `flutter test` in CI; misses modifier forms (M-R3-1) |
| M-R2-8 position twice | fixed: `_extraPosition` (see M-R3-4) |
| M-R2-9 segmented 56 dp | fixed: `segmented.dart:~31`, golden shows 48 dp |
| M-R2-10 access row and countdown untested | fixed: fixtures, goldens and `match_hero_test.dart`'s six cases |
| M-R2-11 … -13 (PLAUSIBLE), -14 … -21 (LOW) | still open, not tasked; M-R2-15 partly fixed (`app/CLAUDE.md`), the stale comments in `etag_interceptor.dart:6-8`, `where_to_watch_state.dart`, `match_detail_live.dart:28-32` and `matches_providers.dart:26-27` remain |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

#### M-R3-1: the providers guard misses `.autoDispose` and `.family`
- tests · constitution VIII, M-R2-7 · `app/test/architecture/providers_test.dart:15-21` · CONFIRMED
- Problem: the pattern needs `<` or `(` right after the class name. `FutureProvider.autoDispose((ref) …)`, `Provider.family<…>(…)`, `NotifierProvider.autoDispose<A, B>(…)` have a `.` there, and none of them match. The `AutoDispose*` names in the pattern are Riverpod 2 classes. The app is on `flutter_riverpod ^3.4.3`, where the modifiers are the usual way to write these. The fixtures have no modifier form.
- Failure scenario: someone adds `final xProvider = FutureProvider.autoDispose((ref) async => …);` and `flutter test` stays green. That is the hole M-R1-16 and M-R2-7 were meant to close.
- Fix direction: allow `(\.(autoDispose|family))*` between the class name and `<`/`(`, drop or keep the Riverpod 2 names, and add one fixture per modifier form. Also narrow the `path.contains('generated')` skip (`:~31`) to `lib/core/network/generated/`.

#### M-R3-2: six provider `*.g.dart` files were not regenerated after their sources changed
- app · constitution (generated files come from their generator) · `app/lib/features/{frequencies/data/satellite_channels_provider,live/live_poller,match_detail/data/match_detail_providers,matches/data/matches_providers,my_satellites/data/my_satellites_provider,my_satellites/data/satellite_matches_provider}.g.dart` · CONFIRMED
- Problem: `dart run build_runner build -d` on this tree changes all six. The provider hashes differ (for example `_$matchesDayHash`), and so do the doc comments copied from the sources, such as `livePolling`'s M-R2-3 text. CI's stale check (`backend.yml:209`) covers only `lib/core/network/generated` and `admin/src/api/generated`, so nothing catches this.
- Failure scenario: the next lane or day that runs `build_runner` gets six unrelated diffs in its change. A real mismatch between a provider and its generated code would also pass CI, because these files are never compared.
- Fix direction: run `dart run build_runner build -d` and keep its output. Ask Lane B2 to add a stale check for `app/lib/**/*.g.dart` to `app.yml`, which is B2's file. That check needs a step that runs `build_runner` and then `git diff --exit-code`.

### LOW

#### M-R3-3: the `ref.mounted` guard is tested in one of five notifiers
- tests · M-R2-2 task text · `app/test/features/matches/matches_providers_test.dart` only · CONFIRMED
- Problem: reverting the guard in `SatelliteMatches`, `Satellites`, `MatchDetailSource` or `SatelliteChannels` fails no test.
- Fix direction: one dispose-mid-cycle test per notifier.

#### M-R3-4: the position de-duplication is a substring test
- ui · `carriage_row.dart` (`_extraPosition`, `nameEn.contains(label)`) · PLAUSIBLE
- Problem: a `nameEn` of «Hotbird 13°E» doesn't contain `13.0E`, so the position prints twice. The board and contract examples use the «7.0W» form.

#### M-R3-5: the 304 check runs after the generated client has parsed the body
- app · `swr_repository.dart:~262` · PLAUSIBLE
- Problem: if an interceptor resolves a 304 with a body that isn't a full envelope, parsing throws before the status check. The cached copy is kept, but the screen reports a failure.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| FR-04x, frequency readout LTR, «11843 MHz» | `carriage_row.dart` | `carriage_row_test.dart`, goldens, `match_detail_page_test.dart:~595`, `frequencies_test.dart:~655` | met |
| live polling per visible screen (S2, S3, S4) | `live_poller.dart` | `live_polling_test.dart` | met |
| SWR through the app's Dio, 304 changes nothing | `swr_repository.dart` | `swr_repository_test.dart` | met |
| errors mapped from `error.code` | `dio_failure.dart` | `dio_failure_test.dart` | met |
| constitution VIII, generated providers only | `providers_test.dart` | itself | partly met (M-R3-1, M-R3-2) |
| the countdown and the access row | `match_hero.dart`, `carriage_row.dart` | `match_hero_test.dart`, goldens | met |

Round 2's table for the rest of US3 still holds.

## Task audit

Ticked 10 (round-2 block), verified 9, not done 0, partly done 1:

| Task | Gap |
| --- | --- |
| M-R2-7 | the replacement misses the modifier forms (M-R3-1) |

## Owner must review

- The changed goldens `app/test/goldens/carriage_row_*` and `segmented_*`, next to the CarriageRow and Segmented boards in `madar-design/`.

## Outside this change

- Agent setup in `.specify/`, `.claude/` and `.opencode/`: none changed.

## Not reviewed

- Five of the eight changed goldens were not viewed.
- `tool/test_all_zones.sh` (the owner's rule), and `check_web_assets.sh` here (CI runs it).
