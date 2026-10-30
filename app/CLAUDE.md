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

## D1 scope

The matches route reads `/v1/matches` directly; the stale-while-revalidate repository
from drift arrives on D2 (see `../specs/001-d01-foundation/plan.md` Complexity
Tracking).
