# Implementation review: 001-d01-foundation, lane M, round 2

- Date: 2026-10-30 · Reviewer: Claude Code, Sonnet 5.5 (`claude-sonnet-5-5`)
- Branch: `d01-m` · Base: `origin/master` (merge base `231c221`) · Head: `0da4438`, plus 1 uncommitted file (`reviews/m-round-1.md`; `admin/` and `.claude/settings.json` are untracked and excluded)
- Change: 2 commits, 315 files (0 in another lane's folders: 311 `app/`, 4 shared), +29142 −49
- Verdict: **APPROVE WITH NOTES** · CRITICAL 0 · HIGH 0 · MEDIUM 3 · LOW 4

Round 1's four HIGH findings are fixed and verified here. Three MEDIUM findings remain: one is the owner's open decision on the golden image (M-R1-7), and two are new (M-R2-1, M-R2-2). The lane's `app` CI job stays red until the owner decides on the image.

## Checks

Run in `app/` with Flutter 3.47.7 on the host (zone EET) unless stated.

| Check | Command | Result |
| --- | --- | --- |
| Analyze | `flutter analyze` | exit 0, no issues |
| Tests, host zone | `flutter test` | exit 0, 66 passed |
| Tests, UTC | `TZ=UTC flutter test` | exit 0, 66 passed |
| Tests, Cairo | `TZ=Africa/Cairo flutter test` | exit 0, 66 passed |
| Tests, Tokyo | `TZ=Asia/Tokyo flutter test` | exit 0, 66 passed |
| Tests, New York | `TZ=America/New_York flutter test` | exit 0, 66 passed |
| Goldens unchanged by those runs | `git status --short app/` after all five runs | clean; no `test/goldens/failures/` |
| Light ≠ dark goldens | `md5sum` of every `*_light_*.png` / `*_dark_*.png` pair (22 pairs) | all pairs differ |
| Golden PNGs read by eye | `match_row_dark_1.0.png`, `status_block_dark_1.0.png` | dark surface, icons and `67′` drawn, no empty squares, no DEBUG banner |
| Web release build | `flutter build web --release -t lib/main_prod.dart --dart-define-from-file=env/prod.json` | exit 0; `main.dart.js` loads CanvasKit from `www.gstatic.com/flutter-canvaskit/…` (M-R1-8) |
| `matchDate` round trip, real parse | scratch `dart` script outside `app/` under `TZ=Africa/Cairo`, `Asia/Tokyo`, `UTC` | `DateTime.parse('2026-10-28')` ≠ its drift read-back in all three zones (see M-R2-1) |
| Golden image exists | `docker manifest inspect ghcr.io/cirruslabs/flutter:<tag>` for 3.44.0 / 3.44.1 / 3.45.0 / 3.46.0 / 3.47.0 / 3.47.7 | 3.44.0 exit 0; all others exit 1 |
| Token copy | `./tool/check_token_copy.sh` | **NOT RUN**: blocked by the lean-ctx shell allowlist; owner to run `lean-ctx allow check_token_copy.sh` |
| Literal scan | `./tool/check_literals.sh` | **NOT RUN**: same, `lean-ctx allow check_literals.sh`. I scanned `app/lib` by hand with `ctx_search` instead (M-R2-2); that is a review aid, not the script |
| Goldens in the pinned image | `docker run … ghcr.io/cirruslabs/flutter:3.47.7 flutter test` | **NOT RUN**: the image does not exist (M-R1-7) |
| `flutter build apk --debug --flavor prod …` | | **NOT RUN**: needs the Android SDK and a long build; CI is the gate |
| T136 steps 3–6 | | **NOT RUN**: need a phone and a browser; T136 is correctly left unticked |

Diff scan for ways around the checks: no `skip`, `xfail`, `.only(`, `// ignore:`, `ignore_for_file`, lint-config or coverage-config changes, and no hand-edited generated files found in the lane's commits.

## Previous round

| Finding | Now |
| --- | --- |
| M-R1-1 dark goldens are light | **Fixed.** `golden_harness.dart:32-33,47` sets `themeAnimationDuration: Duration.zero`, `debugShowCheckedModeBanner: false` and `pumpAndSettle`; `:55-64` fails if a dark PNG is byte-identical to its light PNG. All 22 pairs differ and the dark PNGs are dark. |
| M-R1-2 goldens and DST test depend on the host zone | **Fixed.** Five zones, exit 0, no golden diff. `time_test.dart` builds kickoffs from a local `DateTime(...).toUtc()` and passes `offsetAt: _cairo2026` for the DST days; I checked its 23 h and 25 h windows against Egypt's rule (last Friday of April, last Thursday of October). |
| M-R1-3 drift does not round-trip | **Partly fixed.** `kickoffAt` and `updatedAt` read back as UTC, an unknown enum is stored as `$unknown` and reads back, and the test compares the whole object. `matchDate` still does not round-trip real data: **M-R2-1**. |
| M-R1-4 skeleton for 38 s on failure | **Fixed.** `matches_providers.dart:19` has `retry: (retryCount, error) => null`; `matches_page_test.dart:66-79` expects `EmptyState` after one `pump()` and no `Skeleton`. |
| M-R1-5 tofu and debug banner in goldens | **Fixed.** `flutter_test_config.dart` loads `MaterialIcons` from the SDK; `status_block.dart` renders the minute from the ARB `minuteShort` as an `LtrIsland` in IBM Plex Mono, where U+2032 exists (visible in the PNGs). |
| M-R1-6 INTERNET permission and signing | **Fixed.** `AndroidManifest.xml:3` has the permission; release signing is named in `docs/owner-actions.md` as "Release signing (before the first release)". |
| M-R1-7 `.flutter-version` has no image | **Still open, owner decision (documented, as the task allowed).** The pin has no image; `3.44.0` exists but ships a Dart below `sdk: ^3.13.5` (not re-run here). `app.yml` and `pwa.yml` fail at the image pull until the owner picks an option in `docs/owner-actions.md`. No new task. |
| M-R1-8 CanvasKit CDN | **Still open, now CONFIRMED.** See LOW below. |
| M-R1-9 `CarriageRow` button semantics | **No longer applies.** `carriage_row.dart:45` is `button: onTap != null`. |
| M-R1-10 `context.go` for detail routes | **Still open** (LOW below). |
| M-R1-11 literals the scan misses | **Confirmed and promoted to MEDIUM: M-R2-2.** |

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

#### M-R2-1: `matchDate` does not round-trip a parsed `MatchSummary`; the day shifts in zones east of UTC
- Layer `db` · Source FR-047, US3 scenario 7 (round-trips unchanged), constitution II, round-1 task M-R1-3 · `app/lib/core/db/app_database.dart:26,74,106`; `app/test/fixtures/sample_models.dart:34` · CONFIRMED
- Problem: `match_date` is `format: date` in `backend/openapi/public.json:1816`, so the generated model parses `'2026-10-28'` with `DateTime.parse`, which is local midnight (`isUtc` false). `_toRow` writes `matchDate.toUtc()` and `_fromRow` reads `.toUtc()`. A calendar date is not an instant, so converting it to UTC changes its day. The fix for M-R1-3 made the test pass by building the fixture with `DateTime.utc(2026, 10, 28)` (`sample_models.dart:34`), a value the real JSON parse never produces.
- Failure scenario: a scratch script under `TZ=Africa/Cairo` parses `'2026-10-28'` (day 28), stores `.toUtc()` and reads it back as `2026-10-27 21:00Z` (day 27); Tokyo gives `2026-10-27 15:00Z`. Under `TZ=UTC` the day is right but `parsed == readBack` is still false because `isUtc` differs. Nothing in `lib/` reads `matchDate` or calls `replaceDay` yet, so no screen is wrong today. D2's cached list would show the previous day for a `time_tbd` match in Cairo.
- Fix direction: store the date as `yyyy-MM-dd` text (or a drift converter) and read it back as `DateTime(y, m, d)`, the same value the generated parse builds. Build the test fixture from `MatchSummary.fromJson` so the fixture matches what the app really holds. No D1 database has shipped (nothing calls `replaceDay`), so `schemaVersion` can stay 1; add a migration step if that changes before this lands.

#### M-R2-2: layout literals reach `lib/` and the SC-008 script cannot see them
- Layer `ui` · Source FR-042, SC-008, constitution IV, round-1 finding M-R1-11 · `app/lib/core/format/bidi.dart:67`; `app/lib/design/components/status_block.dart:309-310,333,337-338`; `app/lib/features/matches/presentation/matches_page.dart:54`; `app/tool/check_literals.sh:29-32` · CONFIRMED
- Problem: `bidi.dart:67` has `EdgeInsetsDirectional.symmetric(horizontal: 6)`, and `MadarSpace` has no 6 (`madar_tokens.dart:409-423`). `status_block.dart` has `MadarSpace.s1 + 2` (twice), `strokeWidth = 1`, `dash = 4.0` and `gap = 3.0`. `matches_page.dart:54` has `Divider(height: 1, …)`. `check_literals.sh` matches `EdgeInsets(\.|\()`, `SizedBox(`, `BorderRadius.circular(` and `fontSize:` followed by a number, so `EdgeInsetsDirectional`, `Divider(height:`, `strokeWidth` and arithmetic on a token all pass.
- Failure scenario: the lane's SC-008 gate (`check_literals.sh`) would exit 0 on this tree, although the spec says an automated check finds zero pixel-size literals in app widget code. I read the script's regex; I could not run it (allowlist).
- Fix direction: replace each literal with a token (`MadarSpace.s2`, a hairline token if the design package has one) or ask the owner whether the design needs a 6 dp step added through `tokens.json` and `generate_tokens.py`, never in the copied file. Then widen the script to `EdgeInsets\w*`, `Divider(`, `strokeWidth` and `token \+ \d`, and confirm it fails on the old tree before it passes on the new one.

#### M-R1-7 (carried): the golden image does not exist, so the pinned-container check cannot run
- Layer `ops` · Source US3 scenario 4, `app/CLAUDE.md` Goldens · `app/.flutter-version`, `.github/workflows/app.yml:48`, `pwa.yml:43` · CONFIRMED
- State: I re-ran `docker manifest inspect` on `3.44.1`, `3.45.0`, `3.46.0`, `3.47.0` and `3.47.7` (all exit 1) and on `3.44.0` (exit 0). The goldens were regenerated on the host with Flutter 3.47.7, so they pass here in five zones but have never been rendered in an image. T136 step 2 and the lane's Independent Test ("the goldens pass in the pinned image") cannot pass until the owner picks an option listed in `docs/owner-actions.md` and `docs/runbooks/ci-workflows.md`. This is an owner decision, so no task is appended.

### LOW (no task)

- **M-R1-8 (carried) · CONFIRMED · web build loads CanvasKit from `www.gstatic.com`.** `build/web/main.dart.js` and `flutter_bootstrap.js` reference `www.gstatic.com/flutter-canvaskit/…`. Fonts are bundled, so FR-042's font rule holds, but `app/CLAUDE.md:34` (this lane's file) and `.github/workflows/pwa.yml:53` (lane B2's) both build without `--no-web-resources-cdn`. `docs/owner-actions.md` already says B2 owns the workflow line; change the documented command in `app/CLAUDE.md` too.
- **M-R1-10 (carried) · PLAUSIBLE · `matches_page.dart:34,59,72-76` navigates with `context.go`.** On the match detail stub the back arrow shows only when `context.canPop()` is true, which it is not after `go`. Use `push` for detail routes when S2 is built on D2.
- **M-R2-3 · CONFIRMED · `EtagInterceptor` has no test.** `app/lib/core/network/etag_interceptor.dart` stores ETags, sends `If-None-Match` and turns a 304 into the cached body; nothing under `app/test/` mentions it (search for `EtagInterceptor|If-None-Match|etag|304` returns 0 matches). No task requires one on D1, and the coverage bar starts at D11, but the 304 path is the only one that returns data the server did not just send. Add a test with Dio's `HttpClientAdapter` stub when the SWR repository lands on D2.
- **M-R2-4 · CONFIRMED · the "Open now" row for lane M in `docs/owner-actions.md` is inaccurate.** It says "implemented and uncommitted" (the lane has two commits) and "45 of 45 tasks … ticked" while also listing T136 as open (T136 is unticked: 44 of 45, plus the 7 round-1 fixes).

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| US3-1 / FR-040 flavors, `env/*.json` | `app/env/*.json`, `main_{dev,staging,prod}.dart`, `build.gradle.kts` flavors, `AndroidManifest.xml` | web release build exit 0 (prod); apk build NOT RUN | Built; apk unverified |
| US3-2 / FR-041 router, PB §8.4 routes | `app/lib/core/router/app_router.dart` (17 routes plus `/settings/:section`) | `router_test.dart` (all routes RTL, back arrow right) | Built, tested |
| US3-3 / FR-042 tokens, bundled fonts | `core/theme/madar_tokens.dart`, `assets/fonts/` | token copy NOT RUN; literals NOT RUN; web build has no font fetch, CanvasKit CDN remains (M-R1-8) | **Partly**: M-R2-2 |
| US3-4 / FR-044 / SC-007 goldens, both themes, 1.0×/1.3× | `app/test/goldens/*`, harness | `flutter test` exit 0 in five zones; 22 light/dark pairs differ; PNGs inspected | Met on the host; **not in the pinned image** (M-R1-7) |
| US3-5 / FR-045 gallery | `gallery_page.dart`, `app_router.dart` `kDebugMode` guard | `router_test.dart` (gallery only when enabled); opening it on a device is T136 step 3 | Built; device check open |
| US3-6 / FR-048 matches route | `matches_api.dart`, `matches_page.dart`, `matches_providers.dart` | `matches_page_test.dart` (rows, empty, error by code, first-frame error, local-day window) | Built, tested |
| US3-7 / FR-047 drift round trip | `app_database.dart` | `matches_table_test.dart` | **Partly**: M-R2-1 |
| FR-043 components built once | `app/lib/design/components/*` | goldens plus semantics tests | Built |
| FR-046 generated client only | `core/network/generated/`, `matches_api.dart` | no hand-written DTOs found | Built |
| SC-008 zero literals | `tool/check_literals.sh` | NOT RUN; by hand: M-R2-2 | **Not met** until M-R2-2 |

## Task audit

Ticked 44 (T092–T135) plus 7 round-1 fix tasks. Verified 49 of 51, partly done 2.

| Task | Mismatch |
| --- | --- |
| M-R1-3 | Ticked; `matchDate` still does not round-trip real data (M-R2-1) |
| M-R1-7 | Ticked on the task's "say so and ask the owner" path; the decision is still open (M-R1-7 carried) |
| T136 | Unticked, correctly: steps 1–2 depend on the open items above, steps 3–6 need the owner |

The `tasks.md` diff touches only lines 658–786, inside the `## Lane M` section.

## Owner must review

- `app/.flutter-version` and the image decision in `docs/owner-actions.md` (golden container tag): the lane's CI is red until it is made.
- `app/android/app/build.gradle.kts` (release still signs with the debug key, now listed as an owner action) and `AndroidManifest.xml` (INTERNET permission added).
- `app/lib/app.dart:32` forces `themeMode: ThemeMode.dark`; `docs/product-business.md:168` adds a "follow the system" theme option later, so dark-only on D1 looks intended: confirm.
- `app/lib/core/db/app_database.dart`: the drift schema, once M-R2-1 is fixed.
- Each UI screen next to its design PNG (T136 step 4): the gallery in both themes against the four design-system PNGs, and the matches route against `Matches.png`.

## Outside this change

- `.claude/settings.json` is untracked: agent setup, not reviewed.
- `admin/` is untracked and holds only `node_modules` and `dist` (lane A). A broken symlink under `admin/node_modules` makes `review-scope.sh` exit 1 (`Could not access … @types/json-schema/null`). I ran it with a temporary `core.excludesFile` passed as `GIT_CONFIG_*` environment variables, as round 1 did; no repository file changed. Lane A should ignore `admin/node_modules` and `admin/dist` in `.gitignore`.
- The web build warns "Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons)". It comes from the framework, `cupertino_icons` is not a dependency, and I did not trace which widget triggers it.

## Not reviewed

- Test-first ordering (the lane arrived as two commits).
- Licences of the pub.dev packages.
- CSP and web hosting headers (lane B2). The backend's CORS middleware (`backend/app/public.py:37-41`) allows `If-None-Match` and exposes `ETag`, which is what the interceptor needs on web.
- `flutter build apk`, the `3.44.0` image's Dart version claim, and T136 steps 3–6.
