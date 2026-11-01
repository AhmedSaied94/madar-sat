import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The platform plugins stay behind their adapters (contract app-screens, T125): feature code
/// never imports `firebase_messaging`, `firebase_crashlytics`, `firebase_remote_config`,
/// `flutter_secure_storage` or `share_plus` directly, so a test can answer for push, crash
/// reporting, storage and sharing without a platform channel.
void main() {
  const forbidden = <String>[
    'package:firebase_messaging/',
    'package:firebase_crashlytics/',
    'package:firebase_remote_config/',
    'package:firebase_core/',
    'package:flutter_secure_storage/',
    'package:share_plus/',
  ];

  final clause = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');

  test('the rule catches a direct plugin import', () {
    for (final line in [
      "import 'package:firebase_messaging/firebase_messaging.dart';",
      "import 'package:firebase_crashlytics/firebase_crashlytics.dart';",
      "import 'package:flutter_secure_storage/flutter_secure_storage.dart';",
      "import 'package:share_plus/share_plus.dart';",
    ]) {
      expect(
        clause
            .allMatches(line)
            .any((match) => forbidden.any((prefix) => match.group(1)!.startsWith(prefix))),
        isTrue,
        reason: line,
      );
    }
  });

  test('only core/platform and core/config import a platform plugin', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.contains('/core/platform/') || path.contains('/core/config/')) continue;
      if (path.contains('/generated/')) continue;
      final source = entity.readAsStringSync();
      for (final match in clause.allMatches(source)) {
        if (forbidden.any((prefix) => match.group(1)!.startsWith(prefix))) {
          offenders.add('$path: ${match.group(1)}');
        }
      }
    }

    expect(offenders, isEmpty, reason: 'put the plugin behind an interface in core/platform/');
  });
}
