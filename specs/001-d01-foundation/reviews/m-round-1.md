# Review: Lane M, round 1

- Spec: `specs/001-d01-foundation` (US3, FR-040..048, SC-007, SC-008)
- Lane: M (`app/`), branch `d01-m`
- Base: `origin/master` @ `231c221a2b02` (merge base) · Head: `02cc383a91e5`
- Change set: 1 commit (`feat(app): add the D1 Flutter lane (T092-T135)`), 314 files, +28835 −48
- Reviewed with: `flutter` 3.47.7 on the host (time zone EET), plus a scratch copy of `app/` for the drift experiment

**Verdict: CHANGES REQUESTED.** 4 HIGH, 3 MEDIUM, 4 LOW. No CRITICAL.

## Checks

| Check | Command (in `app/`) | Result |
| --- | --- | --- |
| Analyze | `flutter analyze` | exit 0, no issues |
| Unit + widget + golden tests, host zone | `flutter test` | exit 0, 63 passed |
| Same suite, UTC (what a container uses by default) | `TZ=UTC flutter test` | **FAIL**: 60 passed, 3 failed (8 goldens in `match_row_test.dart` and `status_block_test.dart`, plus the spring-forward test in `time_test.dart`) |
| drift round trip, whole object | scratch test `expect(read, fixture)` in a copy of `app/` | **FAIL**: `kickoffAt` and `updatedAt` come back as local time (`isUtc` false) |
| Token copy | `./tool/check_token_copy.sh` | **NOT RUN**: blocked by the lean-ctx shell allowlist; owner to run `lean-ctx allow check_token_copy.sh` |
| Literal scan | `./tool/check_literals.sh` | **NOT RUN**: same, `lean-ctx allow check_literals.sh` |
| Goldens in the pinned image | `docker run … ghcr.io/cirruslabs/flutter:3.47.7 flutter test` | **NOT RUN**: the tag in `app/.flutter-version` does not exist (see M-R1-7) |
| `flutter build apk --debug --flavor prod …` | | **NOT RUN** |
| `flutter build web --release …` | | **NOT RUN** |
| T136 steps 3–6 (device, screenshots, DevTools Network) | | **NOT RUN**: need a phone and a browser; T136 is correctly left unticked |

No skipped tests, `// ignore:` additions or lint-config changes were found in the diff.

## Findings

### HIGH

**M-R1-1 · CONFIRMED · Every "dark" golden is a light render, so the dark theme is untested.**
`app/test/goldens/golden_harness.dart:20-39`. For each of `match_row`, `status_block` and `carriage_row`, the light and dark PNGs have the same MD5 (for example `8f052238…` for `match_row_light_1.0.png` and `match_row_dark_1.0.png`), and `match_row_dark_1.0.png` shows a light surface. The harness calls `pumpWidget` with a new `theme:` and then one `tester.pump()`; `MaterialApp` animates theme changes, so a single zero-duration pump most likely leaves the previous theme on screen (this cause is PLAUSIBLE; the identical images are not in doubt).
Rule: FR-044, SC-007, US3 scenario 4 ("in both themes"), research R18. Half of the golden matrix proves nothing, and the committed goldens would hide a real dark-theme regression.

**M-R1-2 · CONFIRMED · The goldens and the DST test depend on the host time zone, so they fail in a UTC container.**
Under `TZ=UTC`, `match_row_{light,dark}_{1.0,1.3}` fail (0.08%–0.13% pixel diff), and so do `status_block_{light,dark}_{1.0,1.3}` (1.47%–1.55%). The rendered kickoff is `.toLocal()` (`app/lib/core/format/time.dart`, `MadarTime.kickoff`), so the committed PNGs show the author's zone (`9:00 م` for a fixture at `18:00Z`, which is EET plus 3). `app/test/core/format/time_test.dart:54-73,108-110` ("a spring-forward day is 23 hours in Cairo") also fails in UTC. Its fake `_cairo2026` offset compares host-zone `DateTime(...)` values, so it passes only on a host whose zone matches Cairo's.
`app.yml` runs `flutter test` in the pinned container, where the default zone is UTC (not verified here), so the first CI run would go red.
Rule: constitution quality gates (CI green on `app/`), US3 scenario 4.

**M-R1-3 · CONFIRMED · The drift table does not round-trip a `MatchSummary` unchanged.**
`app/lib/core/db/app_database.dart:24,26,38` use plain `dateTime()` columns and `readAll` (line 64 onwards) returns what drift gives back. In the scratch test, a `MatchSummary` with `kickoffAt: 2026-10-28 18:00Z` came back as `2026-10-28 21:00:00.000` (local, `isUtc` false); `updatedAt` too; `expect(read, fixture)` fails. `app/test/core/db/matches_table_test.dart` passes only because it calls `.toUtc()` on each field and never compares the whole object. Lines 71 and 75 also write `sport.json ?? ''` and `status.json ?? ''`, so an unknown enum value is stored as an empty string and cannot be read back.
Rule: FR-047, US3 scenario 7 ("round-trips unchanged"), constitution II (honest data): D2's offline cache would show shifted kickoff times.

**M-R1-4 · CONFIRMED · A failing matches request shows a skeleton for about 38 seconds before the error state.**
`app/lib/features/matches/presentation/matches_providers.dart:13` declares `matchesProvider = FutureProvider<List<MatchSummary>>(…)` with no `retry:` override. Riverpod 3.4.3 retries a failing provider up to 10 times (200 ms doubling to 6.4 s, about 38 s in total) and keeps the state `AsyncLoading` while it does (read from Riverpod's source; not run against a dead server). `matches_page.dart:37-47` therefore stays on `Skeleton` and the error copy by `error.code` is unreachable during that time.
Rule: FR-048 ("an error state chosen by `error.code` on failure"), constitution II.

### MEDIUM

**M-R1-5 · CONFIRMED · The goldens bake in missing glyphs and the debug banner.**
`match_row_dark_1.0.png` shows `67▯` where `status_block.dart:93` and `:122` build `'$minute′'` (U+2032 is not drawn), empty squares in place of the icons beside "مجانية" and the channel name, and the red "DEBUG" ribbon in the top-left corner (`debugShowCheckedModeBanner` is left on in the harness). Goldens that accept tofu cannot catch an icon or glyph regression, and the minute notation may show a box in the bundled fonts on web (this last point is PLAUSIBLE; check the glyph in IBM Plex Sans Arabic or use a localized minute string).
Rule: FR-044, product doc §14 (Arabic voice).

**M-R1-6 · CONFIRMED · The release manifest has no `INTERNET` permission, and release builds are signed with the debug key.**
`app/android/app/src/main/AndroidManifest.xml` has no `<uses-permission android:name="android.permission.INTERNET"/>`; only `src/debug/AndroidManifest.xml:6` has it, so a release APK could not reach the API. `app/android/app/build.gradle.kts:56-58` signs release with `signingConfigs.getByName("debug")` under a `// TODO`. D1 ships only the debug APK, so nothing breaks yet; the release build was not run.
Rule: FR-040 (`prod` flavor points at VPS-1), constitution (release hygiene).

**M-R1-7 · CONFIRMED · `app/.flutter-version` pins `3.47.7`, which has no `ghcr.io/cirruslabs/flutter` image, so the pinned-container golden check cannot run.**
`app/.flutter-version` is read by `.github/workflows/app.yml:40-48` and `pwa.yml:35-43` as the image tag, and by `app/CLAUDE.md` (Checks, Goldens). Earlier in this review I found that no image with that tag exists (re-verify with `docker manifest inspect ghcr.io/cirruslabs/flutter:3.47.7`, which I did not re-run), so CI's `flutter test` job and the documented golden workflow would fail at the image pull. This is the lane's own file; `docs/owner-actions.md` lists the container tag as an open item, but no task fixes it.
Rule: US3 scenario 4, `app/CLAUDE.md` Goldens section.

### LOW (no task; PLAUSIBLE unless stated)

- **M-R1-8 · PLAUSIBLE · `flutter build web` in `app/CLAUDE.md:34` and `pwa.yml` has no `--no-web-resources-cdn`.** Flutter's web renderer can fetch CanvasKit from `gstatic`, which would break the "no network fetch, including on web" rule in FR-042 and US3 scenario 3. `pwa.yml` is lane B2's file; T136 step 5 (DevTools Network) is where this will show.
- **M-R1-9 · PLAUSIBLE · `carriage_row.dart:43-47` wraps the row in `Semantics(button: true, expanded: …, excludeSemantics: true)` with no `onTap`.** Screen readers announce a button they cannot activate. `match_row.dart:77` passes `followed` only to the home `_Team`.
- **M-R1-10 · PLAUSIBLE · `matches_page.dart:59` and `:34,72-76` navigate with `context.go`.** On the match detail stub, `stub_page.dart:24` shows the back arrow only when `context.canPop()` is true, which it is not after `go`. Use `push` for detail routes.
- **M-R1-11 · PLAUSIBLE · Literals the scan may miss.** `matches_page.dart:54` (`Divider(height: 1, …)`) and `app/lib/core/format/bidi.dart:67` (`EdgeInsetsDirectional.symmetric(horizontal: 6)`). By reading `tool/check_literals.sh`, its `EdgeInsets(.|()` pattern does not match `EdgeInsetsDirectional`; I could not run the script (SC-008).

## Previous round

None (round 1).

## Requirements

| Requirement | Status | Evidence |
| --- | --- | --- |
| US3-1 / FR-040 flavors and `env/*.json` | Built | `app/env/*.json`, three `main_*.dart`; builds not run |
| US3-2 / FR-041 router, all PB §8.4 routes stubbed | Built | `app/lib/core/router/app_router.dart` has the 17 routes plus `/settings/:section`; `/gallery` only when `kDebugMode` |
| US3-3 / FR-042 tokens and bundled fonts | Partly | tokens and fonts copied; `check_token_copy.sh` / `check_literals.sh` NOT RUN; web CDN question open (M-R1-8) |
| US3-4 / FR-044 / SC-007 goldens, both themes, 1.0×/1.3× | **Not met** | M-R1-1, M-R1-2, M-R1-5, M-R1-7 |
| US3-5 / FR-045 gallery | Built | `gallery_page.dart`, debug only; opening it on a device is T136 step 3 (NOT RUN) |
| US3-6 / FR-048 matches route | Partly | local-day UTC window and `EmptyState` built; error state delayed (M-R1-4) |
| US3-7 / FR-047 drift round trip | **Not met** | M-R1-3 |
| FR-043 components built once | Built | all named components under `app/lib/design/components/` |
| FR-046 generated client only | Built | `lib/core/network/generated/`, no hand-written DTOs found |
| SC-008 zero literals | NOT RUN | scripts blocked by allowlist; see M-R1-11 |

## Task audit

- **T092–T135 (44 tasks, ticked):** the work exists in the files the tasks name. Ticked but deficient: the golden-test tasks (dark goldens are light, M-R1-1; zone-dependent, M-R1-2), the drift table task (M-R1-3), **T135** (error state, M-R1-4), and the Flutter version pin (M-R1-7). I did not map these to individual task numbers beyond T135.
- **T136 (unticked):** correctly open; steps 1 and 2 cannot pass until M-R1-2 and M-R1-7 are fixed, steps 3–6 need the owner.
- Test-first ordering cannot be judged from a single commit (see Not reviewed).

## Owner must review

- `app/android/app/build.gradle.kts` (release signing) and `app/android/app/src/main/AndroidManifest.xml` (permissions)
- `app/.flutter-version` and the image tag it selects
- `app/lib/app.dart:32` forces `themeMode: ThemeMode.dark`; confirm that dark-only is intended for D1
- `docs/owner-actions.md` (open items T136 steps 3–6, staging host, golden container tag)

## Outside this change

- `.claude/settings.json` is untracked: an agent setup file, not reviewed.
- `admin/` is untracked: lane A's work in progress, not reviewed. Its `node_modules` contains a broken symlink that crashes `review-scope.sh`; I worked around it with a temporary `core.excludesFile` through `GIT_CONFIG_*` environment variables (no repository files changed).
- `app/test/goldens/failures/` is untracked golden-failure output (it was already untracked at the start of the review; my `TZ=UTC` run also writes there). Don't commit it; consider ignoring it.

## Not reviewed

- Test-first ordering: the lane arrived as one commit, so the red-then-green order cannot be checked.
- Licences of the pub.dev packages.
- CSP and web hosting headers (lane B2).
