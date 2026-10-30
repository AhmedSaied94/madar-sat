import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

/// Renders [builder] in RTL × {light, dark} × text scale {1.0, 1.3} and compares each
/// variant with its golden (research R18). Component states are static: reduced motion.
///
/// The theme is applied before the capture: `MaterialApp` animates a theme change, so a
/// single zero-duration pump would leave the previous theme on screen and every "dark"
/// PNG would be a light render (FR-044, SC-007).
Future<void> goldenVariants(
  WidgetTester tester,
  String name,
  WidgetBuilder builder, {
  Size size = const Size(360, 800),
}) async {
  for (final scale in [1.0, 1.3]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: brightness == Brightness.dark ? MadarTheme.dark : MadarTheme.light,
          themeAnimationDuration: Duration.zero,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: Scaffold(body: Center(child: SingleChildScrollView(child: Builder(builder: builder)))),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(_name(name, brightness, scale)),
      );
    }

    // A dark capture that is byte-identical to the light one proves the dark theme was
    // never applied, which is what FR-044 forbids.
    final light = _committedGolden(_name(name, Brightness.light, scale)).readAsBytesSync();
    final dark = _committedGolden(_name(name, Brightness.dark, scale)).readAsBytesSync();
    expect(
      dark,
      isNot(equals(light)),
      reason: '${_name(name, Brightness.dark, scale)} is identical to the light capture: '
          'the dark theme was not applied (FR-044, SC-007)',
    );
  }
}

String _name(String name, Brightness brightness, double scale) =>
    '${name}_${brightness.name}_${scale.toStringAsFixed(1)}.png';

/// The golden file as committed: `matchesGoldenFile` resolves next to the test file, while
/// `File` would resolve against the process directory.
File _committedGolden(String name) {
  final comparator = goldenFileComparator;
  final base = comparator is LocalFileComparator
      ? comparator.basedir
      : Directory.current.uri;
  return File.fromUri(base.resolve(name));
}
