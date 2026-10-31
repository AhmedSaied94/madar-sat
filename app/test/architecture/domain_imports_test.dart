import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The domain layer is pure (constitution VIII, 4.E): no `data/`, no drift, no Dio, no
/// Riverpod, no `flutter/` and no `dart:ui`. A rule a later change can break silently is
/// pinned here rather than left to a reviewer to spot.
///
/// The patterns match the whole import clause, quoted either way, `import` and `export`
/// alike, and relative paths as well as `package:` ones: two of the three violations round 1
/// found were relative (`../../../core/db/app_database.dart`), which a `/data/`-only pattern
/// misses (M-R2-6).
void main() {
  /// What no `domain/` file may pull in: a layer above it, a storage or transport library,
  /// a Flutter widget.
  const forbidden = <String>[
    '/data/',
    '/presentation/',
    'package:dio/',
    'package:drift/',
    'package:drift_flutter/',
    'package:flutter/',
    'package:flutter_riverpod/',
    'package:riverpod_annotation/',
    'package:url_launcher/',
    'package:just_audio/',
    'dart:ui',
    // `core/` files that are not pure: the database, the SWR cache and the Dio mapping.
    'core/db/',
    'core/network/swr_repository',
    'core/network/dio_',
  ];

  /// Every import or export clause of [source], without its quotes.
  final clause = RegExp(r'''(?:import|export)\s+['"]([^'"]+)['"]''');

  bool violates(String source) => clause
      .allMatches(source)
      .map((match) => match.group(1)!)
      .any((uri) => forbidden.any(uri.contains));

  test('the rule catches each kind of violation, relative or package-quoted', () {
    // The fixtures: the exact lines round 1 found, then each shape the old pattern missed.
    const offenders = <String>[
      "import '../../../core/db/app_database.dart';",
      "import '../../../core/network/swr_repository.dart';",
      "import '../../data/matches_repository.dart';",
      'import "../../presentation/matches_page.dart";',
      "import 'package:dio/dio.dart';",
      "import 'dart:ui' as ui;",
      "import 'package:flutter/material.dart';",
      "export '../../../data/matches_repository.dart';",
      "export 'package:flutter_riverpod/flutter_riverpod.dart';",
    ];
    for (final source in offenders) {
      expect(violates(source), isTrue, reason: source);
    }

    const allowed = <String>[
      "import 'dart:math';",
      "import '../../../core/format/bidi.dart';",
      "import '../../../core/format/retention.dart';",
      "import '../domain/competition_groups.dart';",
      "import 'package:collection/collection.dart';",
      "import 'match_summary.dart';",
    ];
    for (final source in allowed) {
      expect(violates(source), isFalse, reason: source);
    }
  });

  test('no file under features/**/domain/ imports a layer above it or a plugin', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.contains('${Platform.pathSeparator}domain${Platform.pathSeparator}')) {
        continue;
      }
      if (!entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (violates(source)) offenders.add(entity.path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'domain/ stays pure: no data, drift, Dio, Riverpod, Flutter or non-pure core',
    );
  });
}
