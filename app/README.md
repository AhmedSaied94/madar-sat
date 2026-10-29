# app/ — Madar Sat (Flutter)

The Android app and the web PWA. See [CLAUDE.md](CLAUDE.md) for running, codegen, tokens,
goldens and the UI rules, and `../AGENTS.md` for the repository workflow.

```bash
flutter pub get
flutter run -t lib/main_dev.dart --dart-define-from-file=env/dev.json --flavor dev
flutter analyze && flutter test
```

D1 scope: three flavors, the token-built theme and Arabic copy, the 11 signature
components with goldens, every PB §8.4 route as a stub (plus a debug-only `/gallery`),
and the matches route reading `/v1/matches`.
