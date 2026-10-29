import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled TTFs so goldens rasterize the real Changa, IBM Plex Sans Arabic and
/// IBM Plex Mono instead of the test fallback (research R18).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _load('Changa', ['Changa-Regular.ttf', 'Changa-Bold.ttf']);
  await _load('IBM Plex Sans Arabic', [
    'IBMPlexSansArabic-Regular.ttf',
    'IBMPlexSansArabic-SemiBold.ttf',
  ]);
  await _load('IBM Plex Mono', ['IBMPlexMono-Regular.ttf', 'IBMPlexMono-SemiBold.ttf']);
  await testMain();
}

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await loader.load();
}
