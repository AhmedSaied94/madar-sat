# Implementation review: 003-d03-follow-push-sources, lane M, round 1

- Date: 2026-11-01 · Reviewer: Claude Sonnet 5.5 (lead) with three Sonnet 5.5 layer reviewers (app/security; UI/RTL; spec/tests), the first two run twice. The lead re-opened every HIGH finding below; MEDIUM and LOW findings are the reviewers' own (read in code, marked PLAUSIBLE when only running would settle them). The reviewers viewed 14 design PNGs and 6 golden PNGs by eye in the second pass.
- Branch: 003-d03-follow-push-sources (all four lane PRs merged; no lane branch was checked out, at the owner's request) · Base: origin/master (merge base 5323669) · Head: 8405dd2, plus 0 uncommitted files
- Change: Lane M's commits `53cca0a` (D3 onboarding, favorites, settings, S0, Remote Config and the push adapters) and `b669c49` (docs), merged by PR #19; 187 files owned by M (+16,180 −191), of which about 90 are generator output (`app/lib/core/network/generated/**`, `*.g.dart`, `*.freezed.dart`, `app/lib/l10n/*`) and 24 are new golden PNGs. Lane M touched nothing outside `app/`, `docs/runbooks` and its own `docs/owner-actions.md` section.
- Verdict: **CHANGES REQUESTED** · CRITICAL 0 · HIGH 12 · MEDIUM 30 · LOW 14

## Checks

| Check | Command | Result |
| --- | --- | --- |
| analyze | `cd app && flutter analyze` | exit 0, "No issues found" |
| literals | `./tool/check_literals.sh` | exit 0 (but see MEDIUM: raw layout numbers dodge its patterns) |
| token copy | `./tool/check_token_copy.sh` | exit 0, "token and font copies match the design package" |
| flutter test | `RTEST_HOST=flutter-tests rtest` (from `app/`, as your CLAUDE.md requires; never run locally) | **NOT COMPLETE.** The first run reached 304 tests with 0 failures and was cut off when the session ended. Every rerun since stops at "another run for madar_sat is in progress": that first run still holds the remote lock on the test box. A background retry is still polling; `scratchpad/chk-m-rtest4.log` will hold the result. Until then the suite is unproven; the reviewers did not run it either |
| `./tool/test_all_zones.sh`, `flutter build apk`, `flutter build web` | — | NOT RUN: need the remote suite and a build toolchain; `app.yml` and `pwa.yml` run them |
| Generated client matches the spec | `dart run swagger_parser`, `dart run build_runner build -d` and a diff | NOT RUN: rewrites tracked files. The `generated/` diff looks like generator output and matches `backend/openapi/public.json` fields |

Ways around the checks: none found. No new `skip:`, `.only`, `@Skip`, `// ignore:` or TODO/FIXME in hand-written code; no change to `analysis_options`, `flutter_test_config` or coverage settings; no existing golden was rewritten (the diff has only added files). Edits to existing tests follow UI changes (S3 «تحديث» became «تابع المباراة», stub routes became screens).

## Previous round

Round 1: none.

## Findings

### CRITICAL

None.

### HIGH

#### M-R1-1: The network half of the story is not built: no registration, device update, follow sync or server delete
- Layer: spec/app · Source: spec US2 scenarios 4 (server half), 6, 7 (send), 10 (delete); FR-041; SC-001; Clarification "the app sends its satellite ids with `PUT /v1/devices/me`"; tasks T114, T115, T133 (all unticked) · `app/lib/features/devices/data/device_identity_provider.dart:28` ("Registration itself (POST /v1/devices) is T133's"), `app/lib/features/follows/data/follows_repository.dart:13,28,40`, `app/lib/features/devices/data/push_token_sync.dart:15-16`, `app/lib/features/settings/presentation/settings_page.dart:309` · CONFIRMED (the lead's grep finds no caller of the four generated operations outside `generated/`; `markSyncDirty` sets flags that nothing reads)
- Problem: follows, satellites and the push id live only on the phone. `follows_repository.dart` only calls `markSyncDirty('follows')`, `markSyncClean` is never called from `lib`, and `device_repository_test.dart` does not exist. Commit `b669c49` only relabelled the tasks "unblocked".
- Failure scenario: a fresh install picks teams and allows push. The server has no device row and no follows, so B1's scheduler never queues a reminder, and the done check's first clause ("a kickoff reminder arrives on Android and on an installed iPhone PWA") cannot pass. tasks.md is honest about it; it is a missing acceptance scenario, not a false tick.
- Fix direction: build the device repository and follow sync on the generated client (register once, `PUT /devices/me` with push token, tz, locale, app version and satellite ids, `PUT …/follows` with the full set), with retry on launch, resume and reconnect; an omitted `DeviceUpdate` field must not serialize as `null` (`null` clears it on the server); write `device_repository_test.dart` and the follow-send half of `follows_repository_test.dart` first. Task `M-R1-1`.

#### M-R1-2: The FCM id is stored as the device auth token
- Layer: security/app · Source: research R27 ("the device token lives only in secure storage"), FR-041, contracts/public-devices.md:8 · `app/lib/features/devices/data/push_token_sync.dart:29-31`, `app/lib/features/devices/data/device_identity_provider.dart:48-54`, `app/lib/core/network/device_auth_interceptor.dart:25`, `app/test/features/devices/push_token_sync_test.dart:96,112` · CONFIRMED (the lead read `apply(token)` → `setToken(token)` → `SecureKeys.deviceToken`)
- Problem: `PushTokenSync.apply` takes the value from `PushService.currentToken()` / `tokenChanges` (the FCM installation id) and writes it with `setToken`, which writes `SecureKeys.deviceToken`, the key `DeviceIdentity.token` and `DeviceAuthInterceptor` read. The test asserts `store.values[SecureKeys.deviceToken] == 'token-1'`, so the bug is locked in.
- Failure scenario: today every `/v1` request after permission is granted carries `Authorization: Device <FID>`, an unknown token. Once T133 stores the real server-issued token, the next token event sees `identity.token != fid` and overwrites it, so the device is unauthenticated, `/devices/me*` returns 401, and re-registering loops.
- Fix direction: keep the push id in its own field or key (or not persisted at all) and send it with `PUT /v1/devices/me`; rewrite the test to assert the separation. Task `M-R1-2`.

#### M-R1-3: «حذف بيانات جهازي» deletes nothing on the server, and the copy says it does
- Layer: spec/ui · Source: spec US2 scenario 10, FR-041, T121 (ticked "calls DELETE /devices/me"), constitution II and V · `app/lib/features/settings/presentation/settings_page.dart:300-315` · CONFIRMED (the lead read the handler: a comment says the server call "ships with T133", then `followsRepository.clear()` and `identity.forget()` only)
- Problem: the dialog and its golden say «سنحذف متابعاتك ورمز الإشعارات من الخادم» (untrue until T133); `s15Deleted` is never shown; the test asserts only local state. The local wipe drops the install id and token before any DELETE could use them, and `appSettingsProvider` (keepAlive) is never invalidated, so theme, zone and satellites stay active and `onboardingDone` stays true until a restart.
- Failure scenario: once registration exists, the server keeps the device row, its follows and push token after the user chose to delete, and reminders keep arriving.
- Fix direction: send `DELETE /v1/devices/me` first, wipe locally only on success (keep local data and show the error if it fails), invalidate the settings provider; reword the dialog until then; test the call. Task `M-R1-3`.

#### M-R1-4: The forced-update button does nothing on Android
- Layer: ui/app · Source: spec US2 scenario 12, research R29, product doc S0 ("CTA Play Store; on the PWA reload"), T132 (ticked) · `app/lib/features/system/presentation/system_views.dart:100,134,145`, `app/lib/core/platform/reload_page_native.dart` · CONFIRMED (the lead read `onPressed: () => reloadPage()`, `reloadPage() async => false`, and that `playStoreUrl` is declared and never referenced)
- Problem: the result is ignored and the store is never opened, while the screen prints «يفتح صفحة التطبيق على Google Play». `BuildInfo.buildNumber` also defaults to 1 and `app-release.yml` passes `--build-number` but not `--dart-define=APP_BUILD_NUMBER`, so any `min_supported_build ≥ 2` locks out every released build (documented in owner-actions).
- Failure scenario: an Android build below `min_supported_build` hits a blocking screen whose only action is a no-op; the router guard redirects every route back to it. `system_screens_test.dart` only asserts the button exists.
- Fix direction: open `playStoreUrl` through `urlOpenerProvider` on non-web when `reloadPage()` is false; pass the build number as a dart-define in the release workflow (B2's file, asked below); test with `FakeUrlOpener`. Task `M-R1-4`.

#### M-R1-5: The S2 channel line ignores My satellites (T134 is ticked)
- Layer: spec · Source: spec US2 scenario 4 ("S3, S4, S5 and the S2 channel line put them first"), constitution I, T134 · `app/lib/core/network/swr_repository.dart:71-74` · CONFIRMED (the lead read `listMatchesV1MatchesGet(from:, to:)` with no satellite ids; the server supports `my_satellite_ids` ranking and D2's tasks.md deferred this to D3)
- Problem: S3, S4 and S5 use the chosen set, but S2's `broadcast.headline` stays in server default order.
- Failure scenario: a user who chose Hotbird sees the Nilesat channel on every S2 row, while S3 for the same match leads with Hotbird.
- Fix direction: pass the ids and key the cached day and its ETag per selection (D2 removed the parameter because it shared one ETag); test it. Task `M-R1-5`.

#### M-R1-6: The time zone setting changes clock text only, not the local day
- Layer: spec · Source: spec US2 scenario 10, FR-044, constitution II ("group matches by the user's local date") · `app/lib/core/db/database_provider.dart:10` (`AppDatabase.open()` with no `offsetAt`), `app/lib/core/settings/settings_providers.dart:69` (`appZoneProvider`, referenced nowhere outside generated code), `app/lib/features/match_detail/presentation/match_hero.dart:130` · CONFIRMED (the lead's grep finds no use of `appZoneProvider`)
- Problem: only `MadarDisplayScope` (`app.dart:93`) carries the zone, into `StatusBlock`, `MatchRow`, the hero time and S9 cards; `matchesWindow` uses `DateTime.now()` and `toLocal()`.
- Failure scenario: choosing GMT−12 groups a match under the device's "today" while its time shows the previous day's clock. Only the zone label and `wallClock` are tested.
- Fix direction: give the drift layer and the day grouping the chosen offset; test grouping across zones. Task `M-R1-6`.

#### M-R1-7: The exit snackbar covers 2 of the 5 root tabs (T119 is ticked)
- Layer: spec/tests · Source: spec US2 scenario 13 ("Back on a root tab on Android shows the exit snackbar"), T119 · `app/lib/features/system/presentation/system_views.dart:161-197`, `favorites_page.dart:43`, `more_page.dart:31` · CONFIRMED (the lead's grep finds `ExitGuard` only in those two pages; `PopScope` only inside `ExitGuard`)
- Problem: S2, S4 and S5 have no guard, so Back on the home tab exits at once. The "exit snackbar" test calls `MadarSnackbar.show` from a button, so deleting `ExitGuard` would not fail it.
- Fix direction: wrap every root tab (or the shell), and test that a back press on each shows the snackbar and a second press exits. Task `M-R1-7`.

#### M-R1-8: The four new error codes have no Arabic copy (T111 is ticked)
- Layer: app · Source: constitution III (clients map `error.code` to Arabic copy), T111 · `app/lib/core/l10n/error_copy.dart:19`, `app/lib/core/l10n/app_ar.arb` · CONFIRMED (the lead's grep for `rate_limited|unknown_follow_target|too_many_follows|unknown_satellite` in `core/l10n` and `features` is empty)
- Problem: unknown codes map to the network-failure copy.
- Failure scenario: a 429 `rate_limited` reads «تحقق من اتصالك» (check your connection); a refused follow set reads the same.
- Fix direction: add the four codes (with `retry_after_s` where useful) to the ARB and `error_copy.dart`; test the mapping. Task `M-R1-8`.

#### M-R1-9: T118 is ticked but its test file does not exist
- Layer: tests · Source: T118, FR-053, spec scenarios 5 and 7 · expected `app/test/core/platform/push_service_test.dart` · CONFIRMED (`ls app/test/core/platform` fails; `git ls-files app/test` has no push_service test; `push_token_sync_test.dart` and `push_routes_test.dart` use a fake `PushService`)
- Problem: nothing tests `FirebasePushService`: "a token is sent once per change", "on web the permission prompt is only from a user action", "`canRequestPermission` is false on iOS Safari not standalone", the empty-VAPID guard. There are also no tests for `install_guide`, `crash_reporter`, `secure_store` or the interceptor on a foreign host.
- Fix direction: write the test (or untick T118 and say what is covered). Task `M-R1-9`.

#### M-R1-10: A web or iPhone-PWA notification tap lands on the home screen, not the match
- Layer: app · Source: spec US2 scenario 7, FR-042, contracts/public-devices.md:87-89, SC-001 · `app/web/firebase-messaging-sw.js:36-46` (`client.navigate(route)` / `clients.openWindow(route)` with `/match/<id>`), `backend/app/notifications/messages.py:113` (link `<pwa origin>/match/<id>`) · CONFIRMED (the lead's grep finds no `usePathUrlStrategy` / `setUrlStrategy` in `app/lib` or `app/web` and no `flutter_web_plugins` in `pubspec.yaml`; Flutter web defaults to the hash strategy; Firebase Hosting rewrites `**` to `index.html`, so the URL loads)
- Problem: with the hash strategy the router reads the route from the `#` fragment; a path URL opens `/`.
- Failure scenario: the installed iPhone PWA receives the reminder, the user taps it, and the app opens on S2 instead of S3. This is the done-check path (T137).
- Fix direction: call `usePathUrlStrategy()` in the web entrypoints (add `flutter_web_plugins: sdk: flutter`), or emit `/#/match/<id>` consistently from the worker and the backend link; add a web-routing test or an owner step in the quickstart. Task `M-R1-10`.

#### M-R1-11: Forward chevrons and the onboarding Back/Next arrows point the wrong way in RTL
- Layer: ui · Source: constitution III ("forward chevrons point left, back arrows point right"), product doc §13.4; boards `More.png`, `Onb-Teams/Satellites/Notifications` · `app/lib/design/components/list_row.dart:103`, `app/lib/features/more/presentation/more_page.dart:104` (both `Icons.chevron_left` with the comment "RTL: go points left"), `app/lib/features/onboarding/presentation/onboarding_page.dart:78` (Next uses `Icons.arrow_back`) and `:115` (Back uses `Icons.arrow_forward`) · CONFIRMED (the lead read the Flutter SDK at `/opt/flutter/packages/flutter/lib/src/material/icons.dart:5482-5486,2290-2294,2482-2486`: `chevron_left`, `arrow_back` and `arrow_forward` all have `matchTextDirection: true`, so in RTL `chevron_left` and `arrow_back` draw right-pointing and `arrow_forward` draws left-pointing; the committed `list_row_light_1.0.png` shows ">" at the left end of the rows)
- Problem: every Settings and More navigation row shows a back-pointing chevron; S1.2–S1.4 show a left-pointing Back and a Next whose arrow points right and sits before the label (the board puts it after, pointing left; `MadarButton` has only a leading icon slot). D2's `satellite_card.dart:101` (`chevron_right`) and `top_bar.dart` (`arrow_back` for back) are correct.
- Fix direction: use `chevron_right` for rows, swap the onboarding icons, add a trailing-icon option to `MadarButton`, then regenerate the `list_row_*` goldens on the pinned Flutter and Linux. Task `M-R1-11`.

#### M-R1-12: The follow button and small buttons are below the 48 dp target
- Layer: ui · Source: constitution IV ("touch targets ≥ 48 dp", a MUST), Button README ("all keep a 48 px target"), product doc §13.7 · `app/lib/design/components/button.dart:51-56,154` (`FollowButton` is an `InkWell` around a `Container(height: MadarSpace.s8 - MadarSpace.s1)`, 28 dp; `small` is `s8 + s1` = 36 dp, the README says 40; `extraSmall` is 32 dp), used at `where_to_watch_slivers.dart:681` and `match_detail_page.dart:176` · CONFIRMED (the lead read the heights and the `InkWell`; the doc comment's "every size keeps a 48 dp target" has no `ConstrainedBox` or padding behind it)
- Problem: «تابع المباراة», the main next action of S3 with no channels, is a 28 dp target.
- Failure scenario: miss-taps on the primary follow CTA on a low-end phone.
- Fix direction: wrap the hit area in a minimum 48 dp box (keep the visual size), size `small` to 40 dp, and test the hit-test size. Task `M-R1-12`.

### MEDIUM

- **A foreground push navigates on arrival with no tap** (`push_service.dart:112-113` `onMessage` → `_addRoute`, `push_route_listener.dart:24-36` `router.go`): the user browsing S4 or Settings is thrown to S3 with no back stack; show an in-app banner and navigate on tap.
- **`DeviceAuthInterceptor`'s doc, code and test disagree** (`device_auth_interceptor.dart:5-8` vs `:22-24`): `isPublicApi = options.path.isNotEmpty` is vacuously true, so the rule is "same host" only, ignoring scheme and port; `push_token_sync_test.dart:136-138` asserts `/healthz` gets the header; dev and staging use one host for API and media. Require `https`, matching host and port and a `/v1` prefix; add foreign-host and cleartext tests.
- **Push route validation is a prefix allow-list, not `/match/<int>`** (`push_route_listener.dart:26-35`, `push_service.dart:130`): `/match/abc` and `/match/../x` pass; the worker's click handler (`firebase-messaging-sw.js:37-46`) validates nothing. Allow only `^/match/\d+$` in one shared validator.
- **`PushTokenSync` runs at every cold start** (`app.dart:74` → `push_token_sync.dart:35` → `push_service.dart:91` `register()`) before S1.4 and without checking `canRequestPermission`: on web this may raise the browser prompt without a gesture (R26 forbids it), and iOS rejects it without one. PLAUSIBLE; gate on `Notification.permission == granted`.
- **The production PWA ships an empty Firebase web config** (`.github/workflows/pwa.yml:55` runs `flutter build web` without `tool/write_firebase_config.sh`; `check_web_assets.sh` tests only `-s` and the tracked placeholder `self.MADAR_FIREBASE_CONFIG = {};` is non-empty): after the owner fills `env/prod.json` the CI-deployed PWA still has an empty `apiKey` and `firebase-messaging-sw.js:16` registers nothing, so web push is silently off. `pwa.yml` is B2's file: ask B2.
- **The Android notification channel and small icon are never shipped:** the backend sends channel `reminders` and icon `ic_stat_madar` (`messages.py:18-19`); `app/android` has neither, and `docs/runbooks/store-releases.md:104` names a different channel (`madar_reminders`) and says the first notification creates it. FCM falls back to the default channel and launcher icon (expected, not run).
- **FR-046 "bundled defaults for every SD §5.1 key" is met for 5 of 8** (`remote_config.dart:18-24`, `remote_config_repository.dart:27-33,50-56`: `maintenance`, `ads`, `features` have none and are never read); `RemoteConfigRepository.load()`'s failure path is untested (only `fromRaw`).
- **A follow and its dirty flag are two separate writes** (`follows_repository.dart:27-28,39-40`: `setFollow` then `markSyncDirty`, no shared transaction): a process death between them leaves a follow that is never sent (P1 data-loss shape). One drift transaction.
- **S1.4 on iPhone Safari (not installed) does not "show S1.5 instead"** (`notifications_step.dart:36-42`: the priming card shows and `/install` is pushed only after the tap; the test at `:103` encodes it); the spec and quickstart step 7 say S1.4 shows the guide.
- **S1.2 team picker deviates from the board:** before typing it shows an empty `_Prompt` where the board shows competition groups with popular teams (root cause may be the backend: whether `/v1/teams` can list without `q`); selection is shown only by fill and border colour (the board has a check badge); tray chips have no × and no «إزالة …» name; `_chosenNames` is in-memory, so after a quit and resume the «التالي (2)» counts saved teams but the tray is empty and they cannot be removed; a search error shows no retry; the tray has no widget test.
- **S9 Favorites deviates and has data gaps** (`favorites_page.dart`, `favorites_providers.dart`): the Teams group is edge-to-edge (the board has a 12 dp margin); team rows have no crest; the bell is a non-tappable outline icon on teams whose reminders are on; both providers show a skeleton on every follow change (not a "true first load"); `favoriteUpcoming` reads only drift's cached days, so a team that plays tomorrow shows nothing on a fresh install; `favoriteTeams` swallows errors, so an unreadable team vanishes while the header count stays and offline it cannot be removed; `final today = DateTime.now()` is compared with `zone.wallClock(kickoff)`, so «اليوم» is wrong when the chosen zone differs from the device zone; the row semantics label duplicates the home team; raw `height: 160` and `168` dodge `check_literals`; a team row opens `/team/:id`, D1's stub page showing the raw text `/team/5`.
- **«أضف فرقاً» and the "+" reuse the onboarding chrome** (`/onboarding/teams`): progress dots, «تخطي», «التالي (n)» and a Back to S1.1 show, and Next continues to S1.3 and S1.4 and ends at `go('/')`, never back to S9; the router guard does not block `/onboarding/*` after done.
- **The offline banner exists on S2 only** (`matches_page.dart:115`); product doc S0 says "any screen" (S3, S4, S5, S9 show nothing); with `age == null` it renders «آخر تحديث الآن» (`banner.dart:23`), which is false while offline (constitution II); copy is «12 د» where the board says «12 دقيقة».
- **S0 forced update and no connection use the red `error` kind** (`EmptyStateKind.error`, `error_outline`): the board has a volt download glyph for the update and a neutral wifi-off tile for no connection (`error` is not for updates).
- **`MadarButton.expanded` is dead** (declared at `button.dart:24,38`, never read): every button spans the full width in the goldens, the dialog's cancel/delete stack (README: side by side at the end), and ghost/outline get a `surface1` fill (README: ghost is text only).
- **`Semantics(excludeSemantics: true)` without `onTap`** on `MadarButton`, `FollowButton`, `BellButton`, `_TeamTile`, `_SatelliteRow`, `_ThemeTile` (D2's rows pass `onTap:`): the descendant `InkWell`'s tap action is dropped, so a screen-reader user may see the control but not activate it. PLAUSIBLE; a semantics test settles it.
- **Bottom-nav «المزيد» from S4 and S5 still routes to `/settings`** (`my_satellites_page.dart:87`, `frequencies_page.dart:91`; D3 changed only `matches_page`): S16 (share, the iOS install row) is unreachable from them.
- **Splash is not built:** the contract lists the Android 12 splash API (icon on solid colour) and the web mark; `launch_background.xml` is Flutter's template (white, no mark, no `values-v31`), `web/index.html` has no mark, and the dark launch flashes white. No task covers it.
- **S3 follow actions differ from the board:** the header has a star `FollowButton` pill (board: bell icon button plus share), the no-channels CTA is the same outline pill (board: accent button with a bell) and both show at once; the body copy still reads «ستظهر القنوات...» (board: «تابع المباراة وسننبهك عند إضافتها...»); the «حدد أقمارك» chip joins a non-flexible `Row` (PLAUSIBLE overflow at 1.3× on 320 dp).
- **The S15 font-size row is squeezed** (`settings_page.dart`: a 192 dp `Segmented` as trailing in a `MadarListRow` leaves about 44 dp for the title at 360 dp; at 1.3× «كبير جداً» ellipsizes); the board puts it under the title at full width; no 1.3× test of S15. Arithmetic confirmed, visual PLAUSIBLE.
- **The toggle knob direction is reversed against the board** (`form_controls.dart`: on = `AlignmentDirectional.centerStart`, which is the right in RTL; the board's `.tg` has on = knob left); size 48×24 vs the board's 46×28.
- **S1.3 shows the wrong orbital position** (`satellites_step.dart`: `'${MadarDigits.plain(position.toInt())}°'`): Nilesat 7.0W shows «-7°», Astra 19.2E «19°», E/W are lost; the board shows «7.0W» in a cyan well and D2's `OrbitalPosition.label` and `PositionWell` already exist.
- **Hard-coded copy and LTR concatenation in presentation:** `notifications_step.dart:152-154` («تغيّر تردد beIN SPORTS 1», «على نايل سات: 11013 H 27500», «ليفربول 1 – 0 تشيلسي · محمد صلاح 23′»: not in the ARB, no LTR islands, and a raw `1 – 0` score inside Arabic); `install_page.dart:207,209` («نسخ», «إضافة إشارة مرجعية»); the highlighted sheet row reuses `onbInstallStep2`; steps 1 and 3 have no highlight on the share and Madar icons.
- **The S16 and S0 version lines force LTR on a whole Arabic string** (`more_page.dart`: `l.s16Version(BuildInfo.label)` with `textDirection: ltr` puts «الإصدار» on the left of the number; `s0YourVersion` the same); the board shows the label on the right and the number as a mono LTR island. The S16 install card title reuses `onbInstallTitle` («ثبّت مدار على iPhone»; the board says «ثبّت التطبيق على iPhone»).
- **Component states are not all drawn or implemented** (FR-049 "every README state"): the `buttons` golden has no disabled, busy, pressed, focus, ghost or xs/sm; `list_row` draws only default, value, toggle and danger and `MadarListRow` has no disabled parameter; `form_controls` has no focus or disabled radio/checkbox; the `form_controls` and `progress_dots` 1.0 and 1.3 goldens are byte-identical in size (no text), so their 1.3× variants add no evidence.
- **No screenshot next to the design PNGs** (delivery-plan §8.1 item 12): T136 and T137 are honestly open and in owner-actions.
- **Test breadth gaps** (4.I): the new screens' widget tests (S9, S15, S1.4, S3 follow, S0) run dark and 1.0× only; no tests for S16, S1.1 theme tiles, S1.3, `InstallPage`, `CrashReporter`, the router `_guard` (resume at the stored step, forced update) or `MadarApp` applying theme, scale and zone; the S9 "next 3" test asserts count only; the zone sheet test checks GMT−12 and +2 only; the T123 tray has no widget test.
- **The privacy row on S15/S16 is hidden until `PRIVACY_URL` is set** (owner-gated, documented); spec scenario 11 lists it as a row.
- **`app/CLAUDE.md` is stale:** it says `schemaVersion` is 2 (it is 3, `app_database.dart:194`) and that intervals are bundled "until Remote Config arrives on D3".

### LOW

- `_gmt` uses `inHours`, so a +5:30 zone shows "GMT+5", and the label has no LTR island; S15's `_sample()` calls `.toLocal()`, so the "9:00 م / 21:00" samples shift with the device zone.
- An unknown follow kind is read as a team (`follows_repository.dart:60`) and would be sent as one; `OnboardingController.restart()` is unused; `PushPermission` is set but never read (S15 says nothing about enabling notifications when denied).
- `notifications_step.dart:46-48` writes `notificationsAsked` straight to drift from a widget, bypassing the `AppSettings` notifier.
- `core/network/dio_provider.dart` imports `features/devices` and `features/system` (layering).
- `main_*.dart` block the first frame on `Firebase.initializeApp` and a Remote Config fetch of up to 10 s on a stalled network.
- `push_token_sync.dart:35-36`: if the provider is invalidated while `currentToken()` is awaited, two listeners can be assigned and the first leaks.
- `favoriteTeams` fires one uncapped `/v1/teams/{id}` request per followed team on first open (device limit 120/min); `mediaImageFor` compares host only, not port.
- Rapid double taps in `teams_step.dart:90-97` compute `contains` from a stale snapshot, so a second tap can fail to unfollow.
- `MadarDialog` uses the default `AlertDialog` elevation, not the `shadow-raised` token; `MadarSwitch` has no `AlignmentDirectional` mismatch beyond the knob direction above.
- Raw layout numbers dodge `check_literals.sh` (its patterns cover `EdgeInsets`/`SizedBox`/`BorderRadius`/`Divider`, `fontSize`/`strokeWidth`/`thickness`, and a token directly followed by `+`/`-` digit): `Icon(size: 14)`, `width: selected ? 2 : …`, `Duration(milliseconds: 150)`, `+ 4` / `+ 3` on `fontSize ?? 0`.
- Disabled button fill is `surface2` where the README says `surface-3`; no explicit focus ring on `MadarButton`/`FollowButton`.
- No `dart:io` import exists in `app/lib` (the browser imports sit in `*_web.dart` behind conditional imports), but `platform_plugins_test.dart` would not catch one; it does fail on a feature import of a listed plugin.
- There is no red-first evidence: Lane M's work is one commit.
- `S1.3` rows have no hairline and per-row `xl` rounding on the highlight; the S16 privacy row has a chevron where the board has an external-link icon.

## Requirements

| Requirement | Built in | Proven by | Status |
| --- | --- | --- | --- |
| AS1 splash, S1.1, dots/back/skip, resume at the same step, never reshown | `app.dart:37-54` `_guard`, `onboarding_page.dart`, `settings_providers.dart:27-35` | `onboarding_controller_test.dart` (controller and drift only) | Built; guard and widgets untested; splash not built |
| AS1 each step reopenable from S15 | `settings_page.dart` (one row to the flow, plus «أقماري») | `settings_screen_test` | Partial (whole flow, not per step) |
| AS2 theme at once and kept | `welcome_step.dart`, `app.dart:81` | S15 theme write only | Built; untested at S1.1 |
| AS3 «الاهلي»/«الأهلي», grouping, tray | `team_search_provider.dart`, `team_groups.dart`, `teams_step.dart` | `teams_step_test.dart` (both spellings send the same `q`; grouping) | Built; tray lost after resume and untested |
| AS4 S3/S4/S5 put my satellites first | `my_satellites_provider.dart`, `match_detail_page.dart:241` | provider overrides only | Built |
| AS4 S2 channel line | none | none | **Missing (M-R1-5)** |
| AS4 satellites sent to the server | none | none | **Missing (M-R1-1)** |
| AS4 skip keeps default, «حدد أقمارك» | `where_to_watch_slivers.dart` | `follow_action_test` | Built |
| AS5 prompt only from the tap; «ليس الآن» opens no dialog | `notifications_step.dart` | `notifications_step_test` | Built |
| AS5 iPhone Safari shows S1.5 | `install_guide_web.dart`, `notifications_step.dart:39` | fake-service test (post-tap) | Partial |
| AS6 register once, token in secure storage | `device_identity_provider.dart` (install id only) | none | **Missing (M-R1-1)** |
| AS6 full follow set sent, retried | `follows_repository.dart` (local only) | local half only | **Missing (M-R1-1)** |
| AS7 push token via `PUT /devices/me` | none (token goes to the wrong key) | test asserts the wrong key | **Missing / wrong (M-R1-1, M-R1-2)** |
| AS7 push tap opens the match | `push_route_listener.dart`, `push_service.dart:117` | `push_routes_test` (Android path) | Built (native); **web lands on home (M-R1-10)** |
| AS8 S9 sections and empty state | `favorites_page.dart`, `favorites_providers.dart` | `favorites_screen_test` (5 tests) | Built; order and cache limits weak; change does not reach the server |
| AS9 S3 «تابع المباراة» | `where_to_watch_slivers.dart` | `follow_action_test`, `match_detail_page_test` | Built; 28 dp target (M-R1-12) |
| AS10 zone, 12/24 h, theme, font, my satellites | `settings_page.dart`, `app_settings.dart`, `app.dart:95-99` | `settings_screen_test`, `app_settings_test` | Built; **zone is display-only (M-R1-6)** |
| AS10 delete device | `settings_page.dart:309` | local-state test only | **Partial: no server call (M-R1-3)** |
| AS11 S16 rows, install only on the iOS PWA | `more_page.dart` | route-exists test only | Built, untested; privacy row env-gated; unreachable from S4/S5 |
| AS12 Remote Config defaults, `min_supported_build`, hosts, media host | `remote_config*.dart`, `media_image.dart`, `main_*.dart` | `remote_config_test`, `media_image_test`, `live_polling_test` | Built (https-only validation, clamped interval, router guard); 3 keys lack defaults; **forced-update button dead on Android (M-R1-4)** |
| AS13 no-connection, load-failed, banner with age, exit snackbar | `system_views.dart`, `banner.dart`, `ExitGuard` | component-level only | **Partial (M-R1-7; banner on S2 only)** |
| AS14 Crashlytics native only | `crash_reporter*.dart`, `firebase_bootstrap.dart` | none | Built, untested |
| FR-041 device registration and sync | — | — | **Missing (M-R1-1)** |
| FR-042 service worker at the origin root | `web/firebase-messaging-sw.js`, `check_web_assets.sh` | none | Built; web tap lands on home; possible duplicate (PLAUSIBLE) |
| FR-046 Remote Config defaults for every key | `remote_config*.dart` | tests above | Partial (5 of 8) |
| FR-049 components with every state | `design/components/*` | `components_d3_test.dart`: 24 PNGs, RTL × light/dark × 1.0/1.3, with a dark ≠ light guard | Partial (states) |

## Task audit

Ticked 26, verified 18, not done 0, partly done 8. Open: T114, T115, T133 (the network half, now unblocked), T136, T137 (owner).

| Task | Mismatch |
| --- | --- |
| T111 `[x]` | The four new error codes are not in `error_copy.dart` or the ARB (M-R1-8). |
| T116 `[x]` | `RemoteConfigRepository.load()`'s failure path and the bundled defaults for 3 keys are untested/absent. |
| T118 `[x]` | `app/test/core/platform/push_service_test.dart` does not exist (M-R1-9). |
| T119 `[x]` | The exit snackbar covers 2 of 5 root tabs and its test would pass without `ExitGuard` (M-R1-7). |
| T121 `[x]` | "calls DELETE /devices/me" is not done (M-R1-3). |
| T123 `[x]` | The tray is empty after a resume and has no widget test. |
| T132 `[x]` | The forced-update button is a no-op on Android (M-R1-4). |
| T134 `[x]` | The S2 channel line ignores My satellites (M-R1-5). |
| T114, T115, T133 `[ ]` | Honestly open; commit `b669c49` relabelled them "unblocked", but nothing was built. |

## Owner must review

- `app/lib/features/devices/**`, `app/lib/core/network/device_auth_interceptor.dart` and `app/lib/core/platform/secure_store.dart`: where the device token lives and where it is sent (M-R1-2). Once T133 lands, the registration and sync code.
- `app/web/firebase-messaging-sw.js` and `app/web/firebase-config.js` (public values only; no secret found in `app/`, no service-account JSON, keystore or `google-services.json` tracked).
- Each screen next to its design PNG once T136/T137's screenshots exist: Splash, S1.1–S1.5, S9 Favorites, S15 Settings, S16 More, S0 system screens, S3 CTA (`madar-design/app-flutter/screens/`).
- `app/lib/core/db/app_database.dart` (`schemaVersion` 3 and `if (from < 3)`; `migration_v3_test.dart` builds the v2 DDL by hand, opens at 3 and asserts rows, ETags and documents survive; `migration_v2_test` only bumped its version expectation).
- `app/lib/core/config/remote_config*.dart`: the Remote Config host is the trust boundary for where the device token is sent (by design, owner-controlled).

## Outside this change

- `pwa.yml` and `app.yml` are B2's files: the PWA build lacks the Firebase config writer (MEDIUM above), and `app-release.yml` does not pass `APP_BUILD_NUMBER` (M-R1-4). To be raised with B2 by the owner.
- D1's `StubPage` for `/team/:id`; the `satellite_card.dart` chevron is correct.
- The backend gaps flagged for B1 in B1's round (empty push tokens, `INVALID_ARGUMENT` wiping tokens) change what the app must send; they do not change M's findings.

## Not reviewed

- `flutter test`: not completed (see Checks). Nothing in this round depends on a green suite, but none of the Lane M tests has been seen to pass.
- Real devices: the Firebase JS SDK's behaviour for a duplicate notification (the backend sends a `notification` block and the worker's `data.tag` is never set, so one reminder may show twice, tagged `match_<id>` and `-`) and for the register-time permission prompt; whether Safari honours `fcm_options.link`; FCM accepting the installation id as a send target; Crashlytics without `google-services.json`. T137 settles them.
- A real 1.3× render of S9/S15/S1.x (conclusions are from layout code and arithmetic); `progress_dots_*` and the other golden PNGs by eye; Desktop-web layouts; whether `/v1/teams` can list popular teams without `q`.
