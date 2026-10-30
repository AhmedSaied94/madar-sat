import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled TTFs so goldens rasterize the real Changa, IBM Plex Sans Arabic and
/// IBM Plex Mono instead of the test fallback (research R18).
///
/// The Material Icons font comes from the Flutter SDK: like any other font it is not
/// registered in a widget test, so every `Icon` would draw an empty square and a golden
/// could never catch an icon regression (FR-044).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _load('Changa', ['Changa-Regular.ttf', 'Changa-Bold.ttf']);
  await _load('IBM Plex Sans Arabic', [
    'IBMPlexSansArabic-Regular.ttf',
    'IBMPlexSansArabic-SemiBold.ttf',
  ]);
  await _load('IBM Plex Mono', ['IBMPlexMono-Regular.ttf', 'IBMPlexMono-SemiBold.ttf']);
  await _loadFromDisk('MaterialIcons', _materialIconsFont());
  await testMain();
}

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(rootBundle.load('assets/fonts/$file'));
  }
  await loader.load();
}

Future<void> _loadFromDisk(String family, File file) async {
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// Finds `MaterialIcons-Regular.otf` in the Flutter SDK that is running this test.
File _materialIconsFont() {
  for (final root in _sdkRoots()) {
    final font = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (font.existsSync()) return font;
  }
  throw StateError(
    'MaterialIcons-Regular.otf not found in the Flutter SDK; goldens would draw empty '
    'icon squares. Run the tests through `flutter test`.',
  );
}

Iterable<String> _sdkRoots() sync* {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) yield env;
  // flutter_tester runs from <flutter>/bin/cache/artifacts/engine/<platform>/.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i += 1) {
    yield dir.path;
    dir = dir.parent;
  }
}
