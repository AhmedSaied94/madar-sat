import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/dev_ca.dart';

/// M-T045-1 (research R14): a `dev` build can trust the local Caddy root through
/// `--dart-define=DEV_CA_PATH`, and a release build or a web build never reads that file.
void main() {
  group('the dev CA is a debug-native build value only', () {
    test('a release configuration ignores DEV_CA_PATH', () {
      expect(
        devCaPathFor('/tmp/root.crt', releaseMode: true, isWeb: false),
        isNull,
      );
    });

    test('the web ignores DEV_CA_PATH, whatever the mode says', () {
      expect(devCaPathFor('/tmp/root.crt', releaseMode: false, isWeb: true), isNull);
    });

    test('a debug native build keeps the path it was given', () {
      expect(
        devCaPathFor('/tmp/root.crt', releaseMode: false, isWeb: false),
        '/tmp/root.crt',
      );
    });

    test('no value, or only spaces, trusts nothing', () {
      for (final raw in ['', '   ']) {
        expect(devCaPathFor(raw, releaseMode: false, isWeb: false), isNull);
      }
    });

    test('surrounding spaces are trimmed, so a quoted define still resolves', () {
      expect(
        devCaPathFor(' /tmp/root.crt ', releaseMode: false, isWeb: false),
        '/tmp/root.crt',
      );
    });

    test('a test binary carries no DEV_CA_PATH, so the default is nothing to trust', () {
      // `flutter test` passes no dart-define: the running build must not look for a file.
      expect(devCaPath(), isNull);
    });
  });
}
