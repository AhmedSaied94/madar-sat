# Implementation review: 002-d02-core-flows, lane M, round 2

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); layer subagents on Sonnet (architecture, UI), every finding re-checked here
- Branch: reviewed as `2383482` on `d02-m`; that work now lives on `d02-features` (committed in `3ac2bf5`), and `d02-m` is back at `b30684d` · Base: `master` (merge base `68f1752`) · Head: `3ac2bf5`. This checkout's `app/` is byte-identical to `2383482`, including one uncommitted deletion (`satellite_matches_repository.dart`). Round 1 reviewed `b30684d`, merged as PR #11.
- Change (this round): 1 commit (`2383482`), 101 files (+18405 −814). 98 under `app/`: 17 regenerated `*.g.dart`, 16 goldens, `web/sqlite3.wasm` and `web/drift_worker.js`, the rest code and tests. Plus `docs/owner-actions.md`, `docs/runbooks/ci-workflows.md` and the lane's own `tasks.md` section. Nothing in another lane's folder.
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 3 · MEDIUM 10 (3 PLAUSIBLE) · LOW 8 (2 PLAUSIBLE)

Round 1's CRITICAL is fixed. A cached in-play row now shows its kickoff, never «مباشر», until `/v1/live` answers, and each screen has a test that fails on revert. The architecture moves are real too: every provider uses the generator, the generated client is the only path to `/v1`, `domain/` is pure, and the PWA ships its drift worker and wasm. Three new defects block approval:

- The tuning line in the expanded carriage row now reads «MHz 11843».
- The new provider `refresh()` methods use `ref` after an `await`, and Riverpod throws there once the screen is gone.
- The three screens share one live-poll controller, so pushing S3 over S2 can switch S3's polling off.

The app's tests were not run (see Checks).

## Checks

App checks ran in a `git archive` of `2383482`.

| Check | Command | Result |
| --- | --- | --- |
| deps | `flutter pub get` | exit 0 |
| analyze | `flutter analyze` | exit 0, no issues |
| client current | `dart run swagger_parser && dart run build_runner build -d && git status --porcelain -- lib` | exit 0, no diff; also no diff when regenerated from `d02-features`' `public.json` |
| token copy | `./tool/check_token_copy.sh` | exit 0 |
| literals | `./tool/check_literals.sh` | exit 0 |
| providers, web assets | `./tool/check_providers.sh`, `./tool/check_web_assets.sh` | **NOT RUN**: not on the lean-ctx shell allowlist, and the run was declined. The owner can allow them with `lean-ctx allow check_providers.sh` and `lean-ctx allow check_web_assets.sh` |
| web build | `flutter build web --release --no-web-resources-cdn -t lib/main_prod.dart --dart-define-from-file=env/prod.json` | exit 0; `build/web/sqlite3.wasm` and `build/web/drift_worker.js` present |
| web assets match drift | `cmp` against `~/.pub-cache/…/drift-2.35.3/` | `drift_worker.js` is byte-identical to the package's; `sqlite3.wasm` is drift's DevTools build (M-R2-14) |
| secrets | gitleaks v8.30.1 over the snapshot | exit 0 |
| tests | `RTEST_HOST=flutter-tests rtest` from `app/` (the owner's rule: never `flutter test` on the laptop) | **NOT RUN**: `rtest` is not on the lean-ctx shell allowlist, and the run was declined. The owner can allow it with `lean-ctx allow rtest`. The commit message reports 460 green on the test box, but that is a claim, not evidence |
| zones | `./tool/test_all_zones.sh` | **NOT RUN**: it runs `flutter test` on the laptop, which the owner's rule forbids |
| goldens | compared the old and new PNGs of every regenerated golden by eye | 4 changed for a reason the delta explains (carriage row, commentator row, search field, segmented); 2 of them show defects (M-R2-1, M-R2-9) |

Ways around the checks: no `// ignore`, `ignore_for_file`, `@Skip` or `.skip(` in hand-written code (the hits are in `*.g.dart`), and `analysis_options.yaml` and `pubspec.yaml` are untouched. Four goldens were regenerated. Two of those regenerations accept a regression (M-R2-1, M-R2-9).

## Previous round

| Finding | Now |
| --- | --- |
| M-R1-1 CRITICAL cached in-play shown as live | **Fixed.** `live_merge.dart:20-43` turns a cached in-play row into `scheduled` until a live state arrives; counts, filters, S3 and S4 use the merged rows; polling still starts from the cached rows. `live_merge_test.dart:81-115` and the S2, S3 and S4 page tests fail on revert |
| M-R1-2 drift web assets | **Fixed** statically (`app_database.dart:118-127`, `web_assets_test.dart`); run-time open unproven (M-R2-14); CI step not added (B2-R2-13) |
| M-R1-3 generated client only | **Partly fixed**: every `/v1` call goes through the generated client (`generated_client_test.dart`); errors are still hand-parsed (M-R2-4), and SWR requests bypass the app's interceptors (M-R2-5) |
| M-R1-4 the expanded carriage row | **Partly fixed**: names, position and «الوصول» are built; the MHz line is reversed (M-R2-1), the position is doubled (M-R2-8), provider and package are untested (M-R2-10) |
| M-R1-5 «على أقمارك» by default | **Fixed** (decided: the «حدد أقمارك» chip is deferred, plan row I) |
| M-R1-6 the live badge at zero | **Fixed** |
| M-R1-7 48 dp targets | **Partly fixed**: the segmented track grew to 56 dp (M-R2-9); the dense clear button is 48 × 40 (M-R2-12) |
| M-R1-8 the pre-match countdown | **Fixed**; it doesn't tick (M-R2-13) and its negative cases are untested (M-R2-10) |
| M-R1-9 to M-R1-12 | **Fixed**, each with a test that fails on revert |
| M-R1-13 `domain/` purity | **Fixed**; the guard test misses relative imports (M-R2-6) |
| M-R1-14 logic out of widgets | **Partly fixed**: refresh and timers live in providers now, with two new defects (M-R2-2, M-R2-3) |
| M-R1-15 storage failures | **Fixed** for writes; reads before a request are unguarded (M-R2-11) |
| M-R1-16 the Riverpod generator | **Fixed** in `lib/` (no hand-written provider); the guard script is weak and not in CI (M-R2-7, B2-R2-13) |
| M-R1-17 light theme at 1.3× | **Fixed** for S2 and S3; S4 and S5 still dark only |
| M-R1-18 to M-R1-29 (LOW and PLAUSIBLE, not tasked) | Still open: one `Column` for every row (`match_group_section.dart`), no period text in the hero, several carriage rows open at once (and a comment now says otherwise, M-R2-15), no disabled or hover states, `catch (_)` in `open_reception.dart:15`, abbreviated ages («منذ {count} د»), no offline branch on S4 and S5, «اليوم» stale across midnight, clip errors unsurfaced, S4's failure state outside `LivePollingScope`, dead API (`SwrSnapshot.isStale`, `watchWindow`, and now `MatchDetailSource.refresh`, `SatelliteChannels.refresh`, `Satellites.revalidate`), `_document` error paths untested and `NetworkImage` for logos |

## Findings

### HIGH

#### M-R2-1: the expanded carriage row prints the tuning line backwards, «MHz 11843»
- Layer `ui` · Source the root `CLAUDE.md` client rules (frequencies are LTR islands; never concatenate a Latin value into Arabic text), FR-048, the `Match-Channels` board (`11843  MHz`) · `app/lib/design/components/carriage_row.dart:285` (`Text('${MadarDigits.plain(frequency.mhz)} MHz', style: valueStyle)`); `test/goldens/carriage_row_dark_1.0.png`, `carriage_row_light_1.3.png` · CONFIRMED (golden)
- Problem: a number and a Latin unit in a plain `Text` inside an RTL row are laid out right to left. The old golden, built with `EntityName`, drew «11843 MHz». The lane regenerated the golden and accepted the reversal.
- Failure scenario: a fan expands a satellite row on S3 or S5.2 and reads the unit before the number, which is the one line they copy onto their receiver.
- Fix direction: render the line with `LtrIsland`, as `:276-278` does for the English name. The tests (`match_detail_page_test.dart:591`, `frequencies_test.dart:653,660`) use `find.text('11977 MHz')`, which passes in either order. Assert the text's `Directionality` is LTR, and regenerate the golden.

#### M-R2-2: the new `refresh()` methods call `ref.invalidateSelf()` after an `await`, which throws once the screen is gone
- Layer `app` · Source the async rule (no `ref` or `context` use after an `await` without a mounted check), M-R1-14 · `app/lib/features/matches/data/matches_providers.dart:33-41`, `features/my_satellites/data/satellite_matches_provider.dart:57-67`, `my_satellites_provider.dart:24-31`, `features/match_detail/data/match_detail_providers.dart:31-40`, `features/frequencies/data/satellite_channels_provider.dart:21-30`; Riverpod 3.4.3 `lib/src/core/ref.dart:232-241,346-349` (`_throwIfInvalidUsage` throws `UnmountedRefException`) · CONFIRMED
- Problem: all five are auto-dispose notifiers, and each awaits a full network cycle (up to the 20 s receive timeout) before `invalidateSelf()`. The old S5.1 widget code guarded this with `if (!ref.context.mounted) return;`, and the move into providers dropped it. `LivePolling._fetchLive` (`live_poller.dart:142`) shows the right pattern.
- Failure scenario: the user pulls to refresh on S2, S4 or S5.1 and taps another tab before the answer. The provider is disposed, `invalidateSelf()` throws, and `RefreshIndicator`'s future fails with nothing to catch it, so an uncaught error reaches the crash reporter.
- Fix direction: `if (!ref.mounted) return;` before each `invalidateSelf()`. Add a provider test that disposes the container during the drain and expects no error.

#### M-R2-3: S2, S3 and S4 share one live-poll controller, so the covered screen can switch off the visible screen's polling
- Layer `app` · Source FR-047, US3 scenario 12, research R26 ("polling only while the route is visible") · `app/lib/features/live/live_poller.dart:84-131` (one auto-dispose `LivePolling` with one set of fields; `sync` overwrites all four, and `_onRevalidate = onRevalidate ?? _onRevalidate`), `:198-219` (`LivePollingScope` reads visibility from `TickerMode`); scopes at `matches_page.dart:101`, `my_satellites_page.dart:166`, `match_detail_page.dart:169` · CONFIRMED by reading
- Problem: S3 is pushed over S2 and S4, so two scopes are mounted at once and drive the same instance. The last `sync` wins. The covered route's `TickerMode` turns off only when the push transition ends, so S2's `visible: false` arrives after S3 has started its timers.
- Failure scenario: the user taps a live match on S2. S3's scope starts the 30 s `/v1/live` poll and the 60 s revalidation. About 300 ms later, S2's `visible: false` cancels both and puts S2's revalidate callback in place. S3 stays unpolled until something rebuilds its scope. After `liveStateTtl` (60 s) the live state expires, and the live match drops back to its kickoff time. `go('/my-satellites')` over S2 has the same race.
- Fix direction: give each scope its own controller (a family keyed by the scope, or a controller the scope owns), or make a hidden scope release its claim instead of stopping the timers, so only the visible scope drives them. Add a widget test with S3 pushed over S2 and the transition completed, and assert S3's timers still fire.

### MEDIUM

#### M-R2-4: errors are still read from a raw map, not the generated `ErrorEnvelope`
- Layer `app` · Source research R25 as amended for M-R1-3 ("read errors with the generated `ErrorEnvelope`"), constitution VI · `app/lib/core/network/dio_failure.dart:19,26-33` (`errorCodeOf` walks `body['error']['code']`); no `ErrorEnvelope` use in `lib/` outside `generated/` · CONFIRMED
- Problem: the owner's M-R1-3 decision is half done: the calls are generated, the error read is not.
- Failure scenario: B1 restructures `error` in a later contract. The app still compiles and maps every code to the generic copy, with no failing test.
- Fix direction: parse the body with `ErrorEnvelope.fromJson` behind a type check, and test an error body the generated model reads.

#### M-R2-5: SWR requests bypass every interceptor on the app's Dio
- Layer `app` · Source research R25 ("the existing ETag interceptor or `Options`"), the root `CLAUDE.md` contract (`Authorization: Device <token>`) · `app/lib/core/network/swr_repository.dart:274-294` (`_requestDio` builds a new `Dio` with copied options and only `_ConditionalEtag`) · CONFIRMED
- Problem: anything added to `dioProvider` later (the device token in D3, logging, a retry policy) never reaches the cached reads, while the live poll and other generated calls get it. It is also a second ETag interceptor next to `EtagInterceptor`.
- Failure scenario: D3 adds the token interceptor, and every SWR request goes out without `Authorization`. Nothing fails at compile time.
- Fix direction: send the conditional header through `RequestOptions.extra` on the app's Dio, read by one interceptor, or copy the app Dio's interceptors except `EtagInterceptor`. Test that an interceptor added to `dioProvider` sees an SWR request.

#### M-R2-6: the domain-imports test misses relative imports, the kind round 1 found
- Layer `tests` · Source M-R1-13 · `app/test/architecture/domain_imports_test.dart:11-14` · CONFIRMED
- Problem: the regex matches `/data/` and a few `package:` prefixes. Two of the three original violations were relative (`../../../core/db/app_database.dart`, `../../../core/network/swr_repository.dart`) and match neither. It also ignores `/presentation/`, `package:flutter/` and `dart:ui`.
- Failure scenario: re-adding `matches_day.dart`'s old imports passes the test.
- Fix direction: also forbid `core/db/`, `core/network/swr_repository`, `core/network/dio_`, `/presentation/`, `package:flutter/` and `dart:ui`, and match `export` and double-quoted forms. Prove it with a fixture string for each.

#### M-R2-7: `check_providers.sh` misses common hand-written providers, and nothing runs it
- Layer `tests` · Source M-R1-16, constitution (Riverpod with the generator) · `app/tool/check_providers.sh:11`; `.github/workflows/app.yml:63-70` (no step) · CONFIRMED (regex read; the CI part is B2-R2-13)
- Problem: the pattern needs a name ending in `Provider` and one of a short list of constructors on the same line. It misses `StateNotifierProvider<A, B>(`, `ChangeNotifierProvider(`, a name without the suffix, and a two-line declaration.
- Failure scenario: a hand-written `StateNotifierProvider` comes back and no check fails.
- Fix direction: write the check as a `flutter test` file like `domain_imports_test.dart`, which Lane M ships without B2, scanning `lib/**` outside `*.g.dart` for `Provider(`, `Provider<` and `Notifier(` constructors. Then the CI ask to B2 is only for the web assets.

#### M-R2-8: the expanded row prints the orbital position twice, without its degree sign
- Layer `ui` · Source the `Match-Channels` board («هوت بيرد · Hotbird 13.0E»), M-R1-4 · `app/lib/design/components/carriage_row.dart:270-280` (`nameEn` then `OrbitalPosition.label(...)`) · CONFIRMED (golden)
- Problem: `name_en` already carries the position ("Nilesat 7.0W", "Hotbird 13.0E" in the contract examples), so the row reads «نايل سات  Nilesat 7.0W  7.0W». At 1.3× the second one wraps to its own line. `OrbitalPosition.label` gives `7.0W`; the satellite header uses `OrbitalPosition.degrees`.
- Failure scenario: every expanded row on S3 and S5.2 repeats the position.
- Fix direction: drop the separate position as the board does, or show it only when `nameEn` lacks it, using `degrees()`. Update the golden and the tests at `carriage_row_test.dart:72-84`.

#### M-R2-9: the segmented track grew from 44 to 56 dp
- Layer `ui` · Source M-R1-7 ("keep the visible size, grow only the hit area"), the FormControls board · `app/lib/design/components/segmented.dart:30-31,80-84`; `test/goldens/segmented_light_1.0.png` before and after · CONFIRMED (golden)
- Problem: the pills stay 36 dp, but the `surface2` track's 4 dp padding now wraps 48 dp segments, so the visible control grew. The golden shows about 10 dp of empty track above and below each pill, where there were 4.
- Failure scenario: the category tabs on S3 and S5.2 look looser than the board, and the regenerated golden carries no note accepting the change.
- Fix direction: drop the track padding and inset the 36 dp pill inside each 48 dp segment, so the track is 48 dp. Or record the new size as accepted.

#### M-R2-10: the access row's provider and package, and the countdown's negative cases, are untested
- Layer `tests` · Source M-R1-4, M-R1-8 · `app/test/fixtures/sample_models.dart:117-118` (`provider: null, package: null`); `test/goldens/carriage_row_test.dart:72-84`; `test/features/frequencies/frequencies_test.dart:644-662`; `app/lib/features/match_detail/presentation/match_hero.dart:133-143` · CONFIRMED
- Problem: no fixture or golden has a provider and a package, so `AccessBadge`'s provider text and the Latin package line (`carriage_row.dart:298-312`) are in no assertion. `match_detail_page_test.dart:196` sets a provider, but only on S3, and the S5.2 test wasn't touched. Inside the hour, after kickoff, TBD and not-scheduled are the countdown's four null cases. None is tested.
- Failure scenario: reverting the provider line or any countdown guard passes the suite.
- Fix direction: add a carriage with provider and package to the expanded-row test, the golden and the S5.2 test, and one test for each countdown null case.

#### M-R2-11: a drift read that fails before the request kills the stream
- Layer `app` · Source M-R1-15, FR-046 · `app/lib/core/network/swr_repository.dart:51` (`windowFor`), `:182` (`documentFor`), `:79,201` (`touchWindow`, `touchDocument` after a 304) · PLAUSIBLE
- Problem: write failures after a 200 are handled now. Reads before the request, and the touch after a 304, are not.
- Failure scenario: on a browser where the wasm database can't open, every screen shows «تعذر التحميل» though the API answers. A failed touch after a good 304 reports a failed revalidation.
- Fix direction: treat an unreadable cache as no cache and still fetch; keep the confirmed copy when a touch fails. Test both.

#### M-R2-12: the dense search field's clear button is 48 × 40, not 48 × 48
- Layer `ui` · Source constitution IV (48 dp), M-R1-7 · `app/lib/design/components/search_field.dart:85-87,122-131`; `test/goldens/search_field_test.dart:35-41` · PLAUSIBLE (layout reading)
- Problem: the button asks for 48 × 48 inside a `Container(height: 40)`, so it gets 40 dp of height. The new opaque `GestureDetector` takes the band around it, and the test measures the outer box only.
- Failure scenario: a tap just above or below the "x" focuses the field instead of clearing it.
- Fix direction: draw the 40 dp field inside a 48 dp box that holds the button. Test a tap 4 dp off the button's centre.

#### M-R2-13: the countdown doesn't tick
- Layer `ui` · Source constitution II (state shown as it is), M-R1-8 · `app/lib/features/match_detail/presentation/match_hero.dart:133-143`, `match_detail_page.dart:139` (`now` read once per build) · PLAUSIBLE
- Problem: nothing rebuilds the hero over time, and polling starts only inside the last hour.
- Failure scenario: S3 left open from «تبدأ بعد 3 ساعات» keeps saying three hours as kickoff passes, until something else rebuilds the page.
- Fix direction: rebuild the hero on a minute tick while it is visible. Test with a fake clock.

### LOW

- M-R2-14 `app/web/sqlite3.wasm` is drift 2.35.3's DevTools build (byte-identical to `drift-2.35.3/extension/devtools/build/sqlite3.wasm`), while the app resolves `sqlite3` 3.5.2. Nothing opens the database in a browser in this lane; T137 (the owner's PWA preview) will. Take the wasm from the matching `sqlite3` release, or add a browser smoke test. PLAUSIBLE.
- M-R2-15 comments that are now false: `where_to_watch_state.dart:40-41,67-75` ("one row open at a time"; `toggleCarriage` still opens many, M-R1-22); `match_detail_live.dart:28-32` (says the quiet «مباشر»; the code returns `scheduled`); `etag_interceptor.dart:6-8` (`bypassKey` is set by tests only); `app/CLAUDE.md` "Providers" ("`app/tool/` will carry a check", which exists); `matches_providers.dart:26-27` ("costs one request", see M-R2-16). CONFIRMED.
- M-R2-16 `matches_providers.dart:33-41` and its siblings: a pull drains one cycle and then `invalidateSelf()` runs another, so one pull sends two requests (the test enqueues two answers, `matches_providers_test.dart:61-81`). CONFIRMED.
- M-R2-17 test quality: `matches_providers_test.dart:96` waits a real 20 ms; the new light-theme 1.3× test on S2 no longer draws a live score (no live state is set, so row 1 shows as scheduled, and `find.text('مباشر')` is met by the chip). CONFIRMED.
- M-R2-18 `app/lib/design/components/badges.dart:71`: `'${l.encrypted} · $provider'` puts a Latin provider in an Arabic string, now on the main path through `carriage_row.dart:303`. Build it from an Arabic label and an `LtrIsland`. CONFIRMED.
- M-R2-19 S3: the countdown uses `accentText` while S3 already has the volt "mine" group and copy actions (one accent per screen; PLAUSIBLE), and in the default state the title «على نايل سات وبدر» and subtitle «نايل سات · بدر» name the same satellites (CONFIRMED).
- M-R2-20 docs from `2383482` (now in this checkout): `docs/runbooks/ci-workflows.md` inserts a paragraph between table rows, so the `app-release.yml`, `pwa.yml` and `admin.yml` rows fall out of the table; `docs/owner-actions.md` lists T133 twice, and "Lane M: 6 items" doesn't match its list. CONFIRMED.
- M-R2-21 `swr_repository.dart` and the providers: `MatchDetailSource.refresh`, `SatelliteChannels.refresh` and `Satellites.revalidate` have no caller in `lib/` (added to M-R1-28's dead API). CONFIRMED.

## Requirements

Only the rows that changed since round 1. Every other row of `m-round-1.md` stands.

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| constitution II, SC-008 a cached in-play row is never live | `features/live/live_merge.dart`, the three pages | `live_merge_test.dart`, the S2, S3 and S4 page tests | **Met** |
| FR-042 S3 where to watch | `match_detail_page.dart`, `carriage_row.dart` | `match_detail_page_test.dart`, `carriage_row_test.dart` | **Partial**: MHz reversed (M-R2-1), position doubled (M-R2-8), provider and package untested (M-R2-10) |
| FR-046 stale-while-revalidate | `core/network/swr_repository.dart` | `swr_repository_test.dart` | **Partial**: errors hand-parsed (M-R2-4), interceptors bypassed (M-R2-5), reads unguarded (M-R2-11) |
| FR-047, US3-12 polling only while visible | `features/live/live_poller.dart` | `live_polling_test.dart` (one scope only) | **Not met** with two screens stacked (M-R2-3) |
| FR-048 new components, 48 dp | `design/components/` | goldens | **Partial** (M-R2-9, M-R2-12) |
| constitution (Riverpod generator), M-R1-16 | every provider | `check_providers.sh` (not run, not in CI) | **Met** in `lib/`; the guard is weak (M-R2-7) |
| SC-009 the PWA preview loads S2 and S3 | `web/`, `app_database.dart:118-127` | `web_assets_test.dart` | **Partial**: not opened in a browser (M-R2-14) |

## Task audit

Round-1 fix tasks: all 17 ticked with "Done" notes. 10 verified, 5 partly done (M-R1-3, M-R1-4, M-R1-7, M-R1-14, M-R1-16), and 2 done with a new defect (M-R1-13's guard and M-R1-15's reads, both MEDIUM).

| Task | Mismatch |
| --- | --- |
| M-R1-3 | errors not read with `ErrorEnvelope` (M-R2-4); interceptors bypassed (M-R2-5) |
| M-R1-4 | the MHz line (M-R2-1), the doubled position (M-R2-8), provider and package untested (M-R2-10) |
| M-R1-7 | the track grew (M-R2-9); the clear button (M-R2-12) |
| M-R1-14 | `ref` after an `await` (M-R2-2); the shared controller (M-R2-3) |
| M-R1-16 | the guard misses cases and doesn't run in CI (M-R2-7) |

## Owner must review

- S3 next to `Match-Channels.png` and `Match-Prematch.png`, with a carriage row expanded: the MHz line and the doubled position (M-R2-1, M-R2-8). The goldens are the only screenshots; delivery-plan §8.1 item 12 asks for one per screen.
- S3 and S5.2 tabs next to the FormControls board (M-R2-9).
- `app/lib/features/live/live_poller.dart`: the polling policy (M-R2-3).
- `app/web/sqlite3.wasm` and `drift_worker.js`: their source (M-R2-14), at T137.

## Outside this change

- The CI steps for `check_web_assets.sh` and `check_providers.sh` are B2's (`b2-round-2.md` B2-R2-13).
- Lane M's round-2 fix block is in this checkout's `tasks.md` only. A first copy written in `../madar-m` went away when `d02-m` was reset to `b30684d`.

## Not reviewed

- The Flutter test suite and the zone runs (see Checks). Every "fails on revert" claim above comes from reading the test, not from running it.
- Run-time behaviour in a browser (drift on the web, focus, layout), and on a device.
- The generated `*.g.dart` and Retrofit files: checked by regeneration (no diff), not read.
