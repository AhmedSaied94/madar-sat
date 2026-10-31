# Implementation review: 002-d02-core-flows, lane M, round 1

- Date: 2026-10-31 · Reviewer: Claude Code, Opus 5.5 (`claude-opus-5-5`); layer subagents on Sonnet, every finding re-checked here
- Branch: `d02-features` (the four D2 lane PRs, #8–#11, merged into it; not yet on `master`) · Base: `master` (merge base `68f1752`) · Head: `6f81c90`, clean tree
- Change (lane M): 3 commits (`4b4d2b5`, `cd63313`, `b30684d`; merged as PR #11). 132 files under `app/` (+16543 −414), plus `docs/runbooks/store-releases.md`, `docs/runbooks/README.md`, `docs/owner-actions.md` and Lane M's section of `tasks.md`. Nothing is in another lane's folder; the generated `error_envelope*` files came from B1's regeneration (`da17913`).
- Verdict: **BLOCK** · CRITICAL 1 · HIGH 6 · MEDIUM 11 (1 PLAUSIBLE) · LOW 11 (2 PLAUSIBLE)

The data layer is careful:
- drift schema v2 with a tested migration;
- one transaction per write;
- `If-None-Match` sent only when the cached copy is readable;
- local days from `kickoff_at`, tested across three zones and both DST days;
- live states kept in memory with a TTL;
- polling gated by visibility and lifecycle.

The screens are close to the boards. One rule is broken, and it blocks: a cached in-play row shows as «مباشر» and counts in the live chip, even offline, hours after the match ended. The PWA can't open its database at all. The cache layer calls the API by hand instead of through the generated client. The expanded carriage row, the main path of the app, shows a wrong satellite position.

## Checks

The checks ran in `app/` with the pinned Flutter 3.47.7 on Linux x64, in a `git archive` copy of HEAD `6f81c90`.

| Check | Command | Result |
| --- | --- | --- |
| deps | `flutter pub get` | exit 0 |
| analyze | `flutter analyze` | exit 0, no issues |
| test | `flutter test --coverage` | exit 0: 436 tests, goldens included |
| coverage | lcov over hand-written `lib/`, generated parts excluded (scratch `lcov_sum.py`) | 94.0 % (3725 of 3963 lines, 77 files) |
| client current | `dart run swagger_parser && dart run build_runner build -d && git status --porcelain -- lib/core/network/generated` | exit 0, no diff |
| web build | `flutter build web --release --no-web-resources-cdn -t lib/main_prod.dart --dart-define-from-file=env/prod.json` | exit 0. It compiles; M-R1-2 fails at run time. `pwa.yml` runs only on `master`, so no PR built it |
| token copy, literals, zones (T133) | `./tool/check_token_copy.sh`, `./tool/check_literals.sh`, `./tool/test_all_zones.sh` | **NOT RUN**: the lean-ctx shell allowlist blocks them. To run them, the owner adds `lean-ctx allow check_token_copy.sh`, `lean-ctx allow check_literals.sh` and `lean-ctx allow test_all_zones.sh` |
| debug APK | `flutter build apk --debug --flavor prod …` | **NOT RUN** here; `app.yml` built it on PR #11 and it passed |
| T135–T137 (release, device walk, PWA preview) | | **NOT RUN**: owner steps |

I scanned the diff for ways around the checks. Hand-written code has no `// ignore`, `ignore_for_file`, `skip:`, `@Skip`, `.skip(` or `.only(`. The 14 hits are the generator's headers in `error_envelope*.dart`. `analysis_options.yaml`, `check_literals.sh` and the golden harness are unchanged. The four rewritten `match_row_*.png` goldens differ only by `13+` → `+13`, which `match_row.dart:283-287` and its new test explain.

## Findings

### CRITICAL

#### M-R1-1: a cached in-play match shows as «مباشر» and counts as live, even offline after it has ended
- Layer `app` · Source: constitution II (NON-NEGOTIABLE: "Cached data MUST NEVER be presented as live"), FR-046, SC-008, US3 scenario 11, research R25 ("`StatusBlock` uses the cached status only for non-live states, and live states come only from `/v1/live`") · `app/lib/features/live/live_merge.dart:18-41`; `app/lib/features/matches/domain/matches_day.dart:13,110` (`liveCount` and the live filter count merged rows); `app/lib/features/match_detail/domain/match_detail_live.dart:34-42`. The behaviour is pinned by a test: `app/test/features/matches/matches_page_test.dart:625-644`, titled "never show a cached in-play row as live", which asserts that «مباشر» *is* shown · CONFIRMED
- Problem: `withLiveState` turns any drift row whose stored status is live, half-time, extra time or penalties, and that has no `/v1/live` state, into `Status.live, estimated: true`. There is no clock or age check. Score and minute are stripped, but the row still says «مباشر», still counts in «مباشر ‹n›» with its red dot, and still passes the live filter. S3 and S4 do the same.
- Failure scenario: a match was live when cached at 21:00 and ended at 21:50. At 23:00 the user opens the app offline, so `/v1/live` has no answer. S2 shows the match as «مباشر», and the chip reads «مباشر 1» with a red dot. S3 and S4 agree. Only the StaleHint line above the list hints that anything is old. This is the "live for two hours whatever happened" failure that the constitution's rationale names. The same rows also show as live online, until the first `/v1/live` answer.
- Fix direction: take live states only from `/v1/live`, as R25 says. A cached in-play row with no current live state gets a non-live treatment: its kickoff time and the StaleHint age, with no «مباشر», no live count and no live filter. Correct the test to assert that. If the owner wants specific copy for "was live, unconfirmed", that is copy only; the rule itself is not open.

### HIGH

#### M-R1-2: the PWA can't open the drift database, so every D2 screen fails on the web
- Layer `db` · Source: FR-049, SC-009 (the PWA loads S2 and S3), T137, constitution VIII ("native and web both go through `drift_flutter`") · `app/lib/core/db/app_database.dart:115` (`AppDatabase.open() : this(driftDatabase(name: 'madar'));`); `app/lib/core/db/database_provider.dart:6-8` · CONFIRMED by reading `drift_flutter-0.3.1/lib/src/web.dart:11-16`, which throws `ArgumentError` when `web == null`
- Problem: no `DriftWebOptions` is passed, and the repo ships no `sqlite3.wasm` or drift worker. D1's S2 called the API directly and never touched the database, so this is new in D2. Every test uses `NativeDatabase.memory()`.
- Failure scenario: the PWA opens S2. Creating `swrRepositoryProvider` reads `appDatabaseProvider` and throws, and the screen shows «تعذّر تحميل البيانات» with a retry that can never succeed. S3, S4 and S5 fail the same way.
- Fix direction: pass `DriftWebOptions` with the wasm and worker URIs, ship both assets in `app/web/` (no CDN, as the web build already avoids for CanvasKit), and say where they come from in `app/CLAUDE.md`. Add a check that fails before the fix: a `flutter test --platform chrome` smoke test that opens the database, or a CI step that looks for the assets in `build/web`.

#### M-R1-3: the cache layer calls the API by hand instead of through the generated client
- Layer `app` · Source: constitution VI (the Dart client "MUST be generated"), the 4.E check "Networking only through the generated Retrofit client" · `app/lib/core/network/swr_repository.dart:108-218` (`_dio.get<Object?>(path, …)`; `_unwrap` reads `body['success']` and `error['code']`); `app/lib/core/network/api_failure.dart:111-117`; literal paths at `swr_repository.dart:114`, `match_detail_providers.dart:20`, `satellite_channels_provider.dart:23`, `my_satellites_provider.dart:29`, `satellite_matches_repository.dart:57` and `frequencies_page.dart:177`; hand-typed query names at `satellite_matches_repository.dart:57-62` · CONFIRMED
- Problem: six `/v1` paths and their query names are string literals, and the envelope is parsed from a `Map`. The generated `ErrorEnvelope` is used nowhere. Only the live poll goes through the generated client. There is no Complexity Tracking row for this.
- Failure scenario: a renamed path or parameter regenerates cleanly, still compiles, and fails at run time with a 404 or 422. The app shows that as a connection problem. CI's stale-client check can't catch it.
- Fix direction: keep the ETag and 304 handling, but issue each request through the generated operation, passing headers via `Options` or the existing interceptor and reading the raw response for the status and `ETag`. Parse errors with the generated `ErrorEnvelope`. If the owner accepts the deviation instead, record it in `plan.md` Complexity Tracking; that is the owner's call. Either way, a test must fail when a generated path changes.

#### M-R1-4: the expanded carriage row shows a wrong satellite position, no English name, no package, and a mislabelled category
- Layer `ui` · Source: US3 scenario 5 ("the satellite in Arabic and English with its position … access, provider and package, and category"), FR-042, FR-048 (orbital positions are LTR islands), constitution III, `Match-Channels.png` · `app/lib/design/components/carriage_row.dart:210-216` (`'${satellite.nameAr} · ${MadarDigits.decimal(satellite.orbitalPosition!)}'`), `:242-255` (the category sits under `l.details` «التفاصيل», at `:249`); the golden `app/test/goldens/carriage_row_dark_1.0.png` shows the result; the test `app/test/features/match_detail/match_detail_page_test.dart:521-538` checks only `'11977 MHz'` and `'معدل الترميز'` · CONFIRMED (code and golden)
- Problem: the API sends degrees east as a signed number, so Nilesat is `-7`. The row prints «7.0- · نايل سات»: the sign is reordered by the bidi algorithm and there is no E/W. `OrbitalPosition.label` (`features/frequencies/domain/orbital_position.dart`) already formats it correctly. `SatelliteRef.nameEn` and `ChannelCarriage.package` are never rendered. There is no access · provider · package row.
- Failure scenario: a fan expands the Nilesat row on S3 or S5.2, the default and main path, and reads "7.0-". They can't tell which way to point the dish.
- Fix direction: build the satellite row from isolated parts: the Arabic name, `nameEn` as an LTR island, and `OrbitalPosition.label` as an LTR island. Add the «الوصول» row (access, provider, package) and the «الفئة» label. Assert those rows in the expanded-row test and regenerate the golden in the pinned image.

#### M-R1-5: with no satellites chosen, S3 shows «على أقمارك» and no «حدد أقمارك»
- Layer `ui` · Source: constitution I (the UI prompts «حدد أقمارك» until the user chooses), US3 scenario 4 («على نايل سات وبدر» with «حدد أقمارك» when none are chosen), the spec edge case "No satellites chosen", PB S3 · `app/lib/features/match_detail/presentation/where_to_watch_slivers.dart:82-100` (the title is always `l.onMySatellites`; `s3NothingOnMySatellites` replaces the prompt); `app_ar.arb` has no «حدد أقمارك» string · CONFIRMED
- Problem: in D2 nobody can choose satellites, so every user sees the defaults titled as *their* satellites. The lane recorded dropping the chip in `tasks.md` ("D3 adds … the user's own satellites"), but neither `plan.md` nor the spec records an approval. The title is wrong whether or not the chip stays.
- Fix direction: while the user hasn't chosen, title the part «على نايل سات وبدر», with the satellite names from the defaults. For the chip, either show «حدد أقمارك» linking to the `/settings` stub, or have the owner record the deferral in `plan.md` Complexity Tracking. Test both states.

#### M-R1-6: the live chip's red dot shows when nothing is live
- Layer `ui` · Source: US3 scenario 1 ("with a red dot while any match is live"), FR-040, constitution IV and the root `CLAUDE.md` ("`live` red is only for live matches") · `app/lib/features/matches/presentation/matches_page.dart:145-150` (`isLive: true` unconditionally); `app/lib/design/components/filter_chip_row.dart:116-119`; the golden test `filter_chip_row_test.dart:26` draws the dot at `count: 0` · CONFIRMED
- Failure scenario: on a quiet day, «مباشر» carries a pulsing red dot with zero live matches.
- Fix direction: pass `isLive: liveCount > 0`. Add a page test that asserts no `LiveDot` at zero and one at one or more.

#### M-R1-7: touch targets below 48 dp: `Segmented` at 36 dp, the dense `SearchField` at 40 dp
- Layer `ui` · Source: constitution IV ("touch targets ≥ 48 dp", MUST), PB §13.7, the FormControls README (the search field is 48 px) · `app/lib/design/components/segmented.dart:79` (`MadarSpace.s8 + MadarSpace.s1`, and the `InkWell` is the same box); `app/lib/design/components/search_field.dart:85` (`dense ? s8 + s2`); used at `satellite_channels_page.dart:221,233` and `where_to_watch_slivers.dart:300-305` · CONFIRMED
- Problem: the lane lists these as "Not fixed, on purpose … a design decision". The constitution overrides the design package, and the README itself says 48 px for the search field. Nothing records an approval.
- Fix direction: keep the visible 36 and 40 dp, and grow each hit area to `MadarLayout.touchMin`, the same pattern as `CommentatorRow`'s 40-in-48 play button. Add tests that the tappable size is at least 48 dp.

### MEDIUM

- **M-R1-8** `app/lib/features/match_detail/presentation/match_hero.dart:54-81,109-114`: the S3 hero has no countdown outside `StatusBlock`'s 60-minute window. Three hours before kickoff it shows `9:00 م` and a date, with no «تبدأ بعد …». The lane's "no countdown boxes" departure drops even the text form (US3 scenario 4, PB S3, `Match-Prematch.png`). Fix: a one-line text countdown from the existing time helpers, with a test. CONFIRMED.
- **M-R1-9** `app/lib/core/l10n/app_ar.arb:114`: `commentatorPlaying` is «يُشغَّل الآن». US3 scenario 6, PB S3 and `Match-Live.png` say «جاري التشغيل...». `app/test/goldens/commentator_row_test.dart:54` pins the wrong copy. Fix: change the ARB string and the test. CONFIRMED.
- **M-R1-10** `app/lib/features/matches/domain/matches_day.dart:52` (`competition: matches.first.competition`), `match_group_section.dart:31`: the S2 group header takes its stage from the group's first match. A round-5 match listed before two round-8 matches puts «الجولة 5» over all three (constitution II). S4 shows a stage only when every match shares it (`my_satellites/domain/competition_groups.dart:44-48`). Fix: use S4's rule and add a mixed-stage test. CONFIRMED.
- **M-R1-11** `app/lib/design/components/carriage_row.dart:104,168-182`: the expanded row hides the `FrequencyReadout` (`!expanded && …`) and replaces it with plain «11977 MHz". Copying uses a default `SnackBar` instead of the readout's own "copied" state. The `FrequencyReadout` and `CarriageRow` READMEs and `Match-Channels.png` keep the readout and copy on tap. `match_detail_page_test.dart:533` asserts the readout is gone (FR-042: "expanded with the details", not instead of the readout). Fix: keep the readout in the expanded row, with tap-to-copy and its copied state. CONFIRMED.
- **M-R1-12** `app/lib/design/components/carriage_row.dart:157`: «تابع» is always drawn in volt, like the working «نسخ التردد», and no caller passes `onFollow`. Tapping it does nothing (constitution I and II, honest states). The lane removed the bell for the same D3 reason. Fix: hide it until follows exist. CONFIRMED.
- **M-R1-13**: `domain/` imports `data/`, drift and Dio (4.E, constitution VIII):
  - `app/lib/features/match_detail/domain/carriage_order.dart:5` imports `my_satellites/data/my_satellites_provider.dart`, which pulls in `flutter_riverpod`;
  - `app/lib/features/matches/domain/matches_day.dart:1` imports `core/db/app_database.dart`;
  - `matches_day.dart:5` imports `core/network/swr_repository.dart`.

  Fix: move the default slugs, the kept-days window and the freshness constants into `domain/` or a neutral core file, and pass them in. CONFIRMED.
- **M-R1-14**: revalidation and polling logic lives in widgets (constitution VIII: "business logic lives in providers, not in widgets or `setState`"):
  - pull-to-refresh is widget code in `app/lib/features/matches/presentation/day_page.dart:119-129`, `my_satellites_page.dart:217-226` and `frequencies_page.dart:170-187`;
  - S5.1 re-declares its cache key, path and parser inline;
  - the date rollover is `setState` in `matches_page.dart:55-65`;
  - T128 says the timers live "in a Riverpod provider … `AppLifecycleListener`", but `live_poller.dart:97-159` is a `ConsumerStatefulWidget` with `WidgetsBindingObserver`, and that departure isn't recorded.

  Fix: expose `refresh()` on the providers, move the poll policy into a notifier that takes visibility and lifecycle as inputs, and record what stays in the widget. CONFIRMED.
- **M-R1-15** `app/lib/core/network/swr_repository.dart:131,175,225`: `catch (error)` turns any throw, including a `TypeError` from contract drift or a storage error, into `const ApiFailure()` with no log. A storage failure after a good `200` also discards the fresh body. Fix: catch `DioException` and `ApiFailure` explicitly, log the rest through `dart:developer`, and still emit fetched data when the write fails. Masking: CONFIRMED; storage case: PLAUSIBLE.
- **M-R1-16** `app/pubspec.yaml:18,38`: `riverpod_annotation` and `riverpod_generator` are declared, but `lib/` has no `@riverpod`. About 25 providers are hand-written (constitution VIII, "Riverpod (+ generator)"; `app/CLAUDE.md`). This was inherited from D1, and D2 adds most of them. Fix: adopt `@riverpod` for the new providers, or have the owner amend the constitution and drop the dependency. CONFIRMED.
- **M-R1-17** `app/test/features/matches/matches_page_test.dart:248`, `app/test/features/match_detail/match_detail_page_test.dart:117`: S2 and S3 are pumped only in `MadarTheme.dark` and only at 1.0×. `AGENTS.md` asks for RTL at 1.3× in both themes, and FR-048 asks the same of components. S4 and S5 have 1.3× tests, but dark only. Fix: add light-theme and 1.3× pumps for S2 and S3, checking for overflow. CONFIRMED.
- **M-R1-18** `app/lib/features/matches/presentation/match_group_section.dart:107-125`: each competition's rows are built in a `Column` inside the lazy list, so a 30–60 match group builds every row on the first frame (constitution VIII: "lists that can grow MUST be virtualized"). The lane lists it as "not measured". Fix: flatten into header and row items, as S4 does. PLAUSIBLE.

### LOW

- M-R1-19 `matches_page.dart:55-65`: «اليوم» is corrected only on a resume event, so it stays stale across midnight while the app stays in the foreground. PLAUSIBLE.
- M-R1-20 `commentator_row.dart:41`, `core/audio/just_audio_clip_engine.dart:42`: the tap returns `toggle(url)`'s future without `unawaited`, and `unawaited(player.play())` swallows a failed play. `ClipEvent` has no error variant, so a stream that fails after starting stays «playing» (US3 scenario 6, edge case "A clip fails"). PLAUSIBLE.
- M-R1-21 `match_hero.dart:65-73`: the hero shows no period («الشوط الثاني»), and it uses the small `StatusBlock` where the board has the large score. CONFIRMED.
- M-R1-22 `where_to_watch_state.dart:33,70-74`: S3 lets several carriage rows open at once. The `CarriageRow` README says one at a time, which S5.2 already does. CONFIRMED.
- M-R1-23: `FilterChipRow`, `Segmented` and `SearchField` have no disabled or hover state, and their goldens draw default and selected only. The README states aren't all built (FR-048). CONFIRMED.
- M-R1-24 `features/frequencies/presentation/open_reception.dart:15`: `catch (_)` around an opener that never throws. CONFIRMED.
- M-R1-25 `app_ar.arb:107-109`: the `StaleHint` copy «منذ 12 د» / «منذ 2 يوم» differs from the design's «منذ 12 دقيقة» / «منذ دقيقتين». CONFIRMED.
- M-R1-26: the `_Failure` states on S4, S5.1 and S5.2 ignore `failureTitle` and `failureCopy`, so offline shows «تعذّر الاتصال بالخادم» where S2 and S3 show «لا يوجد اتصال». CONFIRMED.
- M-R1-27 `my_satellites_page.dart:152-166`: `LivePollingScope` is built only once a snapshot exists, so S4 stops revalidating while it shows its error state (FR-047). CONFIRMED.
- M-R1-28: unused or duplicated API surface:
  - `AppDatabase.watchWindow`, `putWindow` and `readAll`, and `SwrSnapshot.isStale`, are used only by tests. `isStale` contradicts `staleAge`. `putWindow` being public lets non-owners write `match_windows`.
  - `CompetitionGroup` is defined twice.

  CONFIRMED.
- M-R1-29 tests and process:
  - `watchDocument`'s error branches are untested (an unparseable 200, an unreadable cached body, no cache plus an error).
  - S2 and S4 logos use `NetworkImage`, so they have no offline disk cache (the deferral to D3 is recorded).
  - A v1 database opened offline after the upgrade shows the load-failed state.
  - The lane is one commit (`4b4d2b5`), so test-first (FR-053) can't be shown.

  CONFIRMED.

## Requirements

| Requirement | Status | Where | Test |
| --- | --- | --- | --- |
| FR-040 / US3-1 S2 | **Partial** | `matches_page.dart`, `matches_day.dart` | `matches_page_test.dart`; M-R1-6, M-R1-10 |
| US3-2, US3-3 rows, refresh, swipe, skeleton, empty | Built | `match_group_section.dart`, `day_page.dart` | `matches_page_test.dart` |
| FR-041 local-day grouping | Built (`match_date` only for TBD rows, per the contract) | `local_day.dart`, `app_database.dart` | `local_day_test.dart`, `matches_day_test.dart` |
| FR-042 / US3-4 S3 hero and where to watch | **Partial** | `match_hero.dart`, `where_to_watch_slivers.dart` | `match_detail_page_test.dart`; M-R1-5, M-R1-8 |
| US3-5 `CarriageRow` | Collapsed built; expanded **partial** | `carriage_row.dart` | M-R1-4, M-R1-11 |
| US3-6 `CommentatorRow` | Built; copy wrong | `commentator_row.dart`, `core/audio` | `commentator_row_test.dart`; M-R1-9 |
| US3-7, US3-8 cards, no channels, virtualized, back to top | Built | `match_info_cards.dart`, `where_to_watch_slivers.dart` | `match_detail_page_test.dart` (171 links) |
| FR-043 defaults Nilesat + Badr, mine first, free first | Built | `my_satellites_provider.dart`, `carriage_order.dart` | `carriage_order_test.dart` |
| FR-044 / US3-9 S4 | Built | `my_satellites_page.dart` | `my_satellites_page_test.dart` |
| FR-045 / US3-10 S5.1, S5.2 | Built, except the shared expanded details | `frequencies_page.dart`, `satellite_channels_page.dart` | `frequencies_test.dart`; M-R1-4 |
| FR-046 / US3-11 SWR, never live from cache | **Not met** | `swr_repository.dart`, `live_merge.dart` | `swr_repository_test.dart`; M-R1-1, M-R1-2, M-R1-3 |
| FR-047 / US3-12 polling | Built | `live_poller.dart` | `live_polling_test.dart`; M-R1-14, M-R1-27 |
| FR-048 components, goldens, islands | **Partial** | five new components | `test/goldens/`; M-R1-4, M-R1-23 |
| SC-008 no estimated score, no cache shown as live | **Not met** | | M-R1-1 |
| SC-009 Play closed track, PWA loads S2 and S3 | **Not met** on the PWA | | M-R1-2 |
| FR-049 release pipeline | Built (`store-releases.md`) | `app-release.yml` | T135 open (owner) |
| constitution IV touch targets ≥ 48 dp | **Not met** | `segmented.dart`, `search_field.dart` | M-R1-7 |
| FR-053 tests first | Not shown | | M-R1-29 |

## Task audit

- **Ticked but not done:**
  - T128: the timers are in a widget, and the departure isn't recorded (M-R1-14).
  - T124: the SWR base is built on raw Dio (M-R1-3).
  - T114: the document-path error branches are untested (M-R1-29).
  - T123 is done, but the web open fails (M-R1-2).
  - T125 (components) ships the expanded `CarriageRow` and the sub-48 dp controls (M-R1-4, M-R1-7, M-R1-11, M-R1-12).
  - T127 (S2) ships the live dot and the stage rule (M-R1-6, M-R1-10).
  - T129 (S3) ships without the countdown and the «حدد أقمارك» prompt (M-R1-5, M-R1-8).
  - T110 (copy) has the wrong playing string (M-R1-9).
  - T119 and T120 pin two of these: the cached in-play row as live (M-R1-1), and the readout gone (M-R1-11).
- **Verified done:** T109, T111–T113, T115–T117, T122, T126, T130–T132, T134 and T138.
- **Open, correctly:**
  - T133: its three scripts are blocked by the allowlist here and were not run.
  - T135–T137: the owner's release, device and PWA steps.

## Owner must review

- Each screen next to its PNG, both themes, at 360 dp (T136): S2 `Matches.png`, S3 `Match-Prematch.png`, `Match-Live.png`, `Match-Channels.png`, `Match-NoChannels.png`, S4 `MySatellites.png`, S5.1 `Frequencies.png`, S5.2 `Satellite.png`. No screenshots are in the repo.
- M-R1-3: **decided 2026-10-31**. The app uses the generated client, with `original_http_response: true`, and records no exception (research.md R25 "Requests").
- M-R1-5: **decided 2026-10-31**. S3 titles the default set «على نايل سات وبدر» now, and the «حدد أقمارك» chip is deferred to D3 with its picker (plan.md Complexity Tracking, row I; research.md R26).
- M-R1-16: **decided 2026-10-31**. The app adopts `@riverpod` for every provider, D1's included, alongside M-R1-14, and the constitution is unchanged (research.md R26 "Providers").

## Outside this change

- `app/lib/design/components/badges.dart:71` (D1) builds `'${l.encrypted} · $provider'`, concatenating a Latin provider into Arabic (constitution III). D2's real provider data now reaches it.

## Not reviewed

- Behaviour on a phone or in a browser (T136, T137).
- The goldens inside the pinned image (`test_all_zones.sh` NOT RUN).
