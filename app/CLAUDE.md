# app/ — Lane M (Flutter)

The Madar Sat app: Android and the web PWA. Feature-first `data/domain/presentation`,
Riverpod, go_router, Dio + Retrofit from the generated client, drift for the cache.
Read `../AGENTS.md`, `../CLAUDE.md` and the constitution before changing anything here.

## Run

```bash
flutter pub get
cp env/example.json env/dev.json   # once per flavor and checkout, then fill in the values
flutter run -t lib/main_dev.dart --dart-define-from-file=env/dev.json --flavor dev
flutter run -t lib/main_staging.dart --dart-define-from-file=env/staging.json --flavor staging
flutter run -t lib/main_prod.dart --dart-define-from-file=env/prod.json --flavor prod
```

- Flavors: `dev`, `staging`, `prod` (`com.madarsat.app`, `.dev`, `.staging`).
- `env/*.json` holds public values only (hosts, links, Firebase identifiers), and is not in
  the repo: only `env/example.json`, which lists the keys, is committed. CI writes
  `env/prod.json` from the `APP_ENV_PROD` secret with `tool/write_env.sh`; a new key goes into
  `example.json`, your local files and that secret together
  (`../docs/runbooks/secrets.md`, "Update the app's flavor values"). There is no cleartext HTTP.
  `MIRROR_BASE_URL` is one of those keys: the PWA's release host, read by the stage script
  below and not by Dart (the page's bootstrap passes it to the app).
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
flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
  -t lib/main_prod.dart --dart-define-from-file=env/prod.json
./tool/stage_web_release.sh env/prod.json build/web_release   # the PWA's release layout
node --test test_web/                                          # the service worker's logic
```

- The PWA ships as a hashed release: `tool/stage_web_release.sh <env-file> <out-dir>` moves
  everything but the shell into `r/<hash>/`, writes `release.json`, stamps the hash and
  `MIRROR_BASE_URL` into `flutter_bootstrap.js`, `sw.js` and the `drift_worker.js` shim, and
  writes `.br`/`.gz` beside every release file (contract in
  `../specs/004-d04-mvp-launch/contracts/web-release.md`). Staging needs `brotli` and
  `gzip`; the same build always gives the same hash.
- The pinned Flutter 3.47.7 accepts `--pwa-strategy=none` even though `flutter build web --help`
  hides it, and it still emits `flutter_service_worker.js` (and a standalone `flutter.js`) either
  way — the flag changes nothing here. The stage script deletes both: `web/sw.js` is the app's
  worker, and the bootstrap carries Flutter's loader inline. Keep the flag in the command so it
  matches `pwa.yml`.
- Test the worker with `node --test test_web/` (Node 22 and `python3`, no install). It never
  caches API data: only the shell and the release files.
- `web/sw.js` imports `sw_core.mjs` so the core can be tested as a module, but the bootstrap
  registers `/sw.js` as a **classic** worker (Firefox has no module service workers), so the
  stage script inlines the core with `tool/classic_sw.py`. An unstaged build (`flutter run`)
  registers no worker. `test_web/sw_classic.test.mjs` loads the staged form the way it is
  registered.
- `flutter_bootstrap.js` probes the mirror (a HEAD of `main.dart.js`, 3 s) and catches a
  failed entrypoint script, then loads once from the own origin: Flutter's `load()` never
  rejects on a failed script. Only the first entrypoint starts the app
  (`test_web/bootstrap.test.mjs`).

## Code generation (never hand-edit the output)

- `dart run swagger_parser` reads `../backend/openapi/public.json` (the `contract-v1`
  tag) and writes `lib/core/network/generated/` — Retrofit client plus Freezed models.
  `use_freezed3: true` is required: Freezed 3/4 model classes are `abstract`.
  `original_http_response: true` makes each operation return `HttpResponse<Envelope…>`, so a
  caller can read the status and the `ETag`.
- `dart run build_runner build -d` generates Freezed, json_serializable, drift, Retrofit
  and `@riverpod` parts. Run it after any change to a model, table or annotated provider.
- Generated folders are `lib/core/network/generated/`, `lib/l10n/`,
  `lib/core/db/*.g.dart`, `lib/core/theme/madar_tokens.dart` and every `*.g.dart` beside an
  annotated provider. Never edit them by hand, and keep them current: the `.g.dart` beside a
  provider carries a hash of its source and its doc comments, so a stale one shows up as an
  unrelated diff in the next person's change. `backend.yml`'s `clients` job regenerates and
  fails on a diff for the generated clients only; a check for `app/lib/**/*.g.dart` is still
  Lane B2's open step in `app.yml` (M-R3-2), so run `dart run build_runner build -d` before
  committing.

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
`swrRepositoryProvider`), never through Dio directly. Every request goes through the
**generated client** (`MadarApiClient`): the paths and query names are the contract's, so a
renamed operation breaks the build. `test/core/network/generated_client_test.dart` fails on
a hand-written `/v1` path or a raw `Dio.get` anywhere in `lib/` outside `generated/`.

- A stream emits the drift copy first, then revalidates with `If-None-Match`. A `200`
  replaces the data and its ETag in one transaction and emits again. A `304` only moves
  `fetched_at`, and emits the same data again with the time the server confirmed it (so a
  screen's age hint clears; never patch this in a provider). A failure with a cache emits
  the cached data with `snapshot.failure` set, never an empty list over a cached one; a
  failure with no cache is a stream error carrying an `ApiFailure` (its `code` maps to
  Arabic copy). Screen providers set `retry: (_, _) => null`: Riverpod's automatic retry
  would hold the state at loading for about 38 s and hide the error copy, and every error
  state has its own «إعادة المحاولة».
- The ETag lives in drift, so each request gets a request-scoped view of the app's Dio
  (`_requestDio`) carrying only its own `If-None-Match`: two screens revalidating at once
  never swap headers, and `EtagInterceptor`'s memory cache is not involved. That view keeps
  every other interceptor `dioProvider` carries (read at request time), so a token or a log
  added there reaches the cached reads too. Calls that are not cached in drift keep
  `EtagInterceptor`.
- Errors: `DioException` and `ApiFailure` are mapped to the envelope's `error.code`, read
  with the generated `ErrorEnvelope`; any other throw (a `TypeError` from contract drift, a
  storage failure) is logged through `dart:developer` and still yields the fetched data,
  never a silent empty state.
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
  to drift. They expire `PollIntervals.liveStateTtl` (60 s) after the last answer. **Live
  states come only from `/v1/live`:** a cached row whose stored status is in play, with no
  current live state, is shown by its kickoff time — no «مباشر», no score, no minute, not
  counted in «مباشر ‹n›», not in the live filter (`withLiveState`; constitution II, SC-008).
  A screen decides whether to poll `/v1/live` from the **cached** rows, before the merge.
- Domain is pure: no file under `features/**/domain/` imports `data/`, drift, Dio or
  Riverpod (`test/architecture/domain_imports_test.dart`). Cache keys, freshness targets and
  the kept-days window live in `core/` (`swr_snapshot.dart`, `format/retention.dart`).

## Drift schema

`AppDatabase.schemaVersion` is 3 (D2 added `match_windows` and `cached_documents`; D3 added
`app_settings`, `follows` and `sync_state`). Changing
a table means: bump the version, add the step to `onUpgrade`, run
`dart run build_runner build -d`, and add a migration test that builds the previous
version's DDL by hand, opens it at the new version and checks the rows survived
(`test/core/db/migration_v2_test.dart` is the pattern). Local days outside
today−1 … today+6 and documents not revalidated for 14 days are pruned every time the
database opens (`core/format/retention.dart`).

On the web the database needs two assets in `web/`, served from the app's own host (no CDN):
`sqlite3.wasm` and `drift_worker.js`. Both are copied from drift 2.35.3
(`$PUB_CACHE/hosted/pub.dev/drift-2.35.3/extension/devtools/build/sqlite3.wasm` and
`.../drift-2.35.3/drift_worker.js`); re-copy them when drift is upgraded, and keep
`test/core/db/web_assets_test.dart` green. `AppDatabase.open()` passes them as
`DriftWebOptions`; without them `drift_flutter` throws and every screen shows the
load-failed state in the PWA.

Device and follow sync (D3): a change write calls `markSyncDirty`, which moves the key's
in-memory `syncRevision` and announces it on `syncChanges`, so every change leads to a send.
`DeviceSync` reads the revision before reading what it sends, and clears the durable `dirty`
flag only through `markSyncCleanIfUnchanged`; a change made while a PUT is in flight keeps the
flag set and sends again. A flag left set by an earlier run is sent at launch.

## Providers

Every provider in `lib/` is generated with `@riverpod` (or `@Riverpod(keepAlive: true)`),
D1's included; never hand-write `Provider(`, `NotifierProvider(`, `StreamProvider(`,
`FutureProvider(`, `StateNotifierProvider(`, `ChangeNotifierProvider(` or their
`.autoDispose`/`.family` forms. The generated base lives in the `*.g.dart` beside the file,
so `dart run build_runner build -d` runs after every provider change.
`test/architecture/providers_test.dart` fails on a hand-written one, as part of
`flutter test`; no CI step of its own is needed.

## Polling

Matches revalidate every 60 s and `/v1/live` is polled every 30 s, only while the screen's
route is visible, the app is `resumed`, and (for `/v1/live`) a live or imminent match is on
screen. The policy is a provider (`livePollingProvider`, `features/live/live_poller.dart`);
`LivePollingScope` only feeds it visibility (`TickerMode`), lifecycle (`AppLifecycleListener`)
and whether a live answer matters. Never start a periodic timer in a widget.

Each mounted screen holds its **own claim** on that one policy (`sync`/`release`, keyed by
an object the scope owns), and only the claims of visible, resumed screens drive the timers:
covering S2 with S3 stops S2's claim and leaves S3 polling, and a screen that goes away
releases its claim in `dispose`.

A screen's data provider exposes both entry points:

- `revalidate()` — the poll and a retry: `invalidateSelf`, one conditional request;
- `refresh()` — pull to refresh: runs the whole cache, revalidate and write cycle and waits
  for the server before asking the provider to read again.

The intervals are bundled defaults (`PollIntervals`) until Remote Config arrives on D3.

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
