import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/release_assets.dart';

/// drift opens `sqlite3.wasm` inside the release folder, at the address the bootstrap
/// stamped on the page (T067, research R11). Without the stamp the app keeps the plain
/// `sqlite3.wasm` of `web/`, so a debug run and every test still work.
void main() {
  group('the release assets the page stamps', () {
    test('a staged release resolves inside its hash folder on the mirror', () {
      expect(
        sqlite3WasmUri(base: 'https://app.198.51.100.7.sslip.io', hash: '0123456789abcdef'),
        Uri.parse('https://app.198.51.100.7.sslip.io/r/0123456789abcdef/sqlite3.wasm'),
      );
    });

    test('a preview build (own origin) resolves to the same path without a base', () {
      expect(
        sqlite3WasmUri(base: '', hash: '0123456789abcdef'),
        Uri.parse('/r/0123456789abcdef/sqlite3.wasm'),
      );
    });

    test('a trailing slash on the base does not double up', () {
      expect(
        sqlite3WasmUri(base: 'https://app.example.test/', hash: '0123456789abcdef'),
        Uri.parse('https://app.example.test/r/0123456789abcdef/sqlite3.wasm'),
      );
    });

    test('no stamp keeps web/sqlite3.wasm, as debug and the tests need', () {
      expect(sqlite3WasmUri(), Uri.parse('sqlite3.wasm'));
      expect(sqlite3WasmUri(base: 'https://app.example.test'), Uri.parse('sqlite3.wasm'));
      expect(sqlite3WasmUri(hash: ''), Uri.parse('sqlite3.wasm'));
    });

    test('this test binary carries no release, so the helper agrees with the page', () {
      expect(madarRelease(), isNull);
      expect(
        sqlite3WasmUri(base: madarRelease()?.base, hash: madarRelease()?.hash),
        Uri.parse('sqlite3.wasm'),
      );
    });

    test('the database passes both stamped values to drift', () {
      // A source pin: reading `window.MADAR_RELEASE` only in the test would leave the PWA
      // asking Firebase for a wasm the release folder holds (SC-008a).
      final source = File('lib/core/db/app_database.dart').readAsStringSync();
      expect(source, contains('sqlite3Wasm: sqlite3WasmUri('));
      expect(source, contains('base: madarRelease()?.base'));
      expect(source, contains('hash: madarRelease()?.hash'));
      expect(source, contains("driftWorker: Uri.parse('drift_worker.js')"));
    });
  });
}
