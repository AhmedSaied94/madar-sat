import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

/// Renders [builder] in RTL × {light, dark} × text scale {1.0, 1.3} and compares each
/// variant with its golden (research R18). Component states are static: reduced motion.
Future<void> goldenVariants(
  WidgetTester tester,
  String name,
  WidgetBuilder builder, {
  Size size = const Size(360, 800),
}) async {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final scale in [1.0, 1.3]) {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: brightness == Brightness.dark ? MadarTheme.dark : MadarTheme.light,
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
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('${name}_${brightness.name}_${scale.toStringAsFixed(1)}.png'),
      );
    }
  }
}
