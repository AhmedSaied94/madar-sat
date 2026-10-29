import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/format/bidi.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: MadarTheme.dark,
      builder: (context, appChild) => Directionality(
        textDirection: TextDirection.rtl,
        child: appChild ?? const SizedBox.shrink(),
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  test('isolateLtr wraps in LRI … PDI', () {
    final isolated = isolateLtr('11843 H 27500');
    expect(isolated.startsWith('\u2066'), isTrue);
    expect(isolated.endsWith('\u2069'), isTrue);
  });

  testWidgets('a frequency and a Latin name are LTR islands in an RTL tree', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            LtrIsland('11843 H 27500', style: MadarText.readout),
            LtrIsland('beIN SPORTS 1', style: MadarText.textStrong),
          ],
        ),
      ),
    );

    final directions = tester
        .widgetList<Directionality>(find.byType(Directionality))
        .map((widget) => widget.textDirection)
        .toList();
    expect(directions.where((d) => d == TextDirection.rtl), isNotEmpty);
    expect(directions.where((d) => d == TextDirection.ltr), hasLength(2));
  });

  testWidgets('a score is isolated parts, never a raw string', (tester) async {
    await tester.pumpWidget(
      _host(
        const ScoreParts(home: '1', away: '0', separator: '-', style: MadarText.rowScore),
      ),
    );

    expect(find.text('1 - 0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    // In RTL the home number sits on the right, beside the home team.
    final homeX = tester.getCenter(find.text('1')).dx;
    final awayX = tester.getCenter(find.text('0')).dx;
    expect(homeX, greaterThan(awayX));
  });
}
