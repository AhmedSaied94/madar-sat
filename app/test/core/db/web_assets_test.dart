import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The PWA opens the drift database, so both WebAssembly pieces it needs ship in `web/`
/// (M-R1-2, FR-049, SC-009). They are served from the app's own host, never a CDN, the same
/// way the web build already avoids one for CanvasKit.
void main() {
  group('the web database assets', () {
    test('the SQLite WebAssembly module and the drift worker are shipped', () {
      for (final name in ['sqlite3.wasm', 'drift_worker.js']) {
        final file = File('web/$name');
        expect(file.existsSync(), isTrue, reason: 'web/$name is missing');
        expect(file.lengthSync(), greaterThan(0), reason: 'web/$name is empty');
      }
    });

    test('opening the database passes the web options', () {
      // A source pin: without `web:` drift_flutter throws `ArgumentError` on the web and
      // every D2 screen shows the load-failed state. The wasm URL follows the release the
      // bootstrap stamped (release_assets_test.dart).
      final source = File('lib/core/db/app_database.dart').readAsStringSync();
      expect(source, contains('DriftWebOptions('));
      expect(source, contains('sqlite3Wasm: sqlite3WasmUri('));
      expect(source, contains("driftWorker: Uri.parse('drift_worker.js')"));
    });
  });
}
