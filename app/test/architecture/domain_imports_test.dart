import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The domain layer is pure (constitution VIII, 4.E): no `data/` import, no drift, no Dio,
/// no Riverpod. A rule a later change can break silently is pinned here rather than left to
/// a reviewer to spot.
void main() {
  test('no file under features/**/domain/ imports data, drift, Dio or Riverpod', () {
    final forbidden = RegExp(
      r"import\s+'[^']*(/data/|package:dio/|package:drift/|package:drift_flutter/|"
      r"package:flutter_riverpod/|package:riverpod_annotation/)",
    );

    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.contains('${Platform.pathSeparator}domain${Platform.pathSeparator}')) {
        continue;
      }
      if (!entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (forbidden.hasMatch(source)) offenders.add(entity.path);
    }

    expect(offenders, isEmpty, reason: 'domain/ must stay free of data, drift, Dio and Riverpod');
  });
}
