# app/ — Lane M (Flutter)

The Madar Sat app: Android and the web PWA. Feature-first `data/domain/presentation`,
Riverpod, go_router, Dio + Retrofit from the generated client, drift for the cache.
Read `../AGENTS.md`, `../CLAUDE.md` and the constitution before changing anything here.

## Run

```bash
flutter pub get
flutter run -t lib/main_dev.dart --dart-define-from-file=env/dev.json --flavor dev
flutter run -t lib/main_staging.dart --dart-define-from-file=env/staging.json --flavor staging
flutter run -t lib/main_prod.dart --dart-define-from-file=env/prod.json --flavor prod
```

- Flavors: `dev`, `staging`, `prod` (`com.madarsat.app`, `.dev`, `.staging`).
- `env/*.json` holds public values only. There is no cleartext HTTP.
- `dev` points at `infra/compose/dev.yml`'s Caddy (`https://localhost:8443`); from a
  device use `adb reverse tcp:8443 tcp:8443`. Debug builds trust user CAs for its root
  CA; release builds trust the system CAs only
  (`android/app/src/main/res/xml/network_security_config.xml`).
- `/gallery` is registered only when `kDebugMode` is true.

## Checks

```bash
flutter analyze
./tool/check_token_copy.sh      # cmp against madar-design/design-system
./tool/check_literals.sh        # no raw colours, font families or layout numbers
flutter test                    # goldens included; needs the Flutter in .flutter-version
./tool/test_all_zones.sh        # the whole suite under TZ=UTC, then TZ=Africa/Cairo
flutter build apk --debug --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json
flutter build web --release --no-web-resources-cdn -t lib/main_prod.dart --dart-define-from-file=env/prod.json
```

## Code generation (never hand-edit the output)

- `dart run swagger_parser` reads `../backend/openapi/public.json` (the `contract-v1`
  tag) and writes `lib/core/network/generated/` — Retrofit client plus Freezed models.
  `use_freezed3: true` is required: Freezed 3/4 model classes are `abstract`.
- `dart run build_runner build -d` generates Freezed, json_serializable, drift and
  Retrofit parts. Run it after any change to a model, table or `@riverpod` provider.
- Generated folders are `lib/core/network/generated/`, `lib/l10n/`,
  `lib/core/db/*.g.dart` and `lib/core/theme/madar_tokens.dart`. CI regenerates and
  fails on a diff; never edit them by hand.

## Tokens and fonts

`../madar-design/design-system/` is the source of truth. Tokens and TTFs are copied
verbatim; change `tokens.json`, run `generate_tokens.py`, then re-copy and rerun
`./tool/check_token_copy.sh`. Widgets use `context.madarColors`, `MadarText`,
`MadarSpace` and `MadarRadii` only.

## UI work

- Find the screen's row in `../madar-design/app-flutter/SCREENS.md`, open its PNG, and
  read the HTML for structure, Arabic copy and states. Rebuild it; never paste mockup
  HTML.
- Every component in `design-system/components/INDEX.md` is built once under its
  design name (`MatchRow`, `StatusBlock`, `FrequencyReadout`, ...). `Logo` includes
  `BrandMark`, `TeamCrest` and `LogoTile`.
- RTL first: back arrows point right, home is on the right, Latin names and frequencies
  are `LtrIsland`s, digits are Western and tabular. One `accent` element per screen;
  `live` red only for live.
- Composite rows carry one merged Arabic semantics label (§13.8). Copy lives in
  `lib/core/l10n/app_ar.arb`; API `error.code`s map through `lib/core/l10n/error_copy.dart`.
- Platform-only capabilities (ads, local notifications, widgets, crash reporting,
  install guide) sit behind interfaces with web no-ops chosen by conditional import.
  Feature code never imports those plugins directly.

## Goldens

Goldens are rendered by the Flutter version in `.flutter-version` with the bundled fonts
(`test/flutter_test_config.dart`). CI (`app.yml`) checks them with that version on
`ubuntu-24.04`, and that run is the reference (research R18). Update them only with that
version, on Linux x64:

```bash
flutter --version                # must print the version in .flutter-version
flutter test --update-goldens
```

Never update them with another Flutter version, or on macOS or Windows. If CI reports
pixel diffs that your host doesn't, take the goldens from the CI runner
(`../docs/runbooks/ci-workflows.md`, "Goldens and the Flutter pin").

Every variant is RTL × {light, dark} × text scale {1.0, 1.3}; the harness sets
`disableAnimations` so pulses and shimmers are static.

## Data: stale-while-revalidate (D2, FR-046)

Every D2 screen reads through `SwrRepository` (`lib/core/network/swr_repository.dart`,
`swrRepositoryProvider`), never through Dio or the generated client directly.

- A stream emits the drift copy first, then revalidates with `If-None-Match`. A `200`
  replaces the data and its ETag in one transaction and emits again. A `304` only moves
  `fetched_at`, and emits the same data again with the time the server confirmed it (so a
  screen's age hint clears; never patch this in a provider). A failure with a cache emits
  the cached data with `snapshot.failure` set, never an empty list over a cached one; a
  failure with no cache is a stream error carrying an `ApiFailure` (its `code` maps to
  Arabic copy). Screen providers set `retry: (_, _) => null`: Riverpod's automatic retry
  would hold the state at loading for about 38 s and hide the error copy, and every error
  state has its own «إعادة المحاولة».
- ETags live in drift, so the repository's requests opt out of `EtagInterceptor`'s memory
  cache (`EtagInterceptor.bypassKey`). Calls that are not cached in drift keep it.
- Matches are typed rows (`matches` + `match_windows`) per **device-local day**, grouped
  with `LocalDays` from `kickoff_at`, never from `match_date`. Everything else (match
  detail, `/v1/satellites`, a satellite's channels, S4's satellite-filtered day) is a JSON
  document in `cached_documents` under a `DocumentKeys` key. S4's filtered day is a
  document and never rows: do not filter S2's cached rows locally (a row's channel line
  holds at most 2 carriages) and do not write it through `matches` or `match_windows`.
- `StaleHint` shows once a copy is older than its target: `Freshness.matches` and
  `matchDetail` 5 minutes, `satellites` and `channels` 24 hours. The one rule is
  `SwrSnapshot.staleAge(freshness, now:)`, which returns the age to show or null; every
  screen uses it, so a failed revalidation of a copy still inside its target says nothing.
- Live states from `/v1/live` stay in memory (`liveStatesProvider`) and are never written
  to drift. They expire `PollIntervals.liveStateTtl` (60 s) after the last answer, so a feed
  that stops answering cannot keep an old score on screen. A cached in-play row with no live state renders as the quiet estimated
  «مباشر» with no score or minute (`applyLiveStates`): no cached state is ever shown as live.

## Drift schema

`AppDatabase.schemaVersion` is 2 (D2 added `match_windows` and `cached_documents`). Changing
a table means: bump the version, add the step to `onUpgrade`, run
`dart run build_runner build -d`, and add a migration test that builds the previous
version's DDL by hand, opens it at the new version and checks the rows survived
(`test/core/db/migration_v2_test.dart` is the pattern). Local days outside
today−1 … today+6 (and documents not revalidated for 14 days) are pruned every time the
database opens.

## Polling

Matches revalidate every 60 s and `/v1/live` is polled every 30 s, only while the screen's
route is visible, the app is `resumed`, and (for `/v1/live`) a live or imminent match is on
screen. `LivePollingScope` is the one place that runs these timers; wrap a screen's body
in it, and never start a periodic timer in a provider or a page. The intervals are bundled
defaults (`PollIntervals`) until Remote Config arrives on D3.

## Links

Links that come from the API (the reception video) are opened only through
`urlOpenerProvider` (`lib/core/links/url_opener.dart`) after `httpsUri`, which keeps an
absolute `https` address and turns anything else into "no link" (cleartext, other schemes,
userinfo, a port outside 1-65535, over 2048 characters). The opener checks it again and
answers `false` when the platform refuses, so a failed open is a snack bar, never a thrown
error. A clip address goes through the same check inside `ClipController.play`. Feature code
never imports `url_launcher`; tests override the provider with `FakeUrlOpener`.

## Audio

There is one player for the whole app: `clipControllerProvider`. Starting a clip stops the
other, a clip starts only from a tap (the web blocks anything else), and a failed load is
the row's error state. The plugin sits behind `ClipEngine`; feature code and widgets never
import `just_audio`, and tests override `clipEngineProvider` with `FakeClipEngine`.

## Zones

Tests never read the host zone: kickoffs are built from local wall-clock times or injected
offsets, and `./tool/test_all_zones.sh` runs the suite under `TZ=UTC` and
`TZ=Africa/Cairo` to catch a test that does. CI keeps its single run.
