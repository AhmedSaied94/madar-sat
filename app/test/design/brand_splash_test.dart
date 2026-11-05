import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/design/components/brand_splash.dart';
import 'package:madar_sat/design/components/logo.dart';

import '../fixtures/test_app.dart';

void main() {
  const gated = BrandSplashGate(child: Text('الشاشة الأولى'));

  /// `testApp` turns animations off, which is the reduced-motion case.
  Widget gate() => testApp(gated);

  Widget animatedGate() => testApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: false),
            child: gated,
          ),
        ),
      );

  MadarMarkPainter markPainter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .whereType<MadarMarkPainter>()
      .single;

  testWidgets(
    'the splash shows the name and the tagline over the first screen',
    (tester) async {
      await tester.pumpWidget(gate());
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('مدار سات'), findsOneWidget);
      expect(find.text('أي قناة تنقل المباراة؟'), findsOneWidget);
      expect(find.text('والتردد جاهز.'), findsOneWidget);
      expect(find.text('الشاشة الأولى'), findsOneWidget);
    },
  );

  testWidgets('the satellite moves mid-orbit and returns to rest', (
    tester,
  ) async {
    await tester.pumpWidget(animatedGate());
    final orbit = markPainter(tester).orbit!;
    expect(orbit.value, 0);

    await tester.pump(const Duration(milliseconds: 900));
    expect(orbit.value, greaterThan(0));
    expect(orbit.value, lessThan(1));

    await tester.pump(const Duration(milliseconds: 1000));
    expect(orbit.value, 1);
  });

  testWidgets('the splash removes itself and hands over the screen', (
    tester,
  ) async {
    await tester.pumpWidget(animatedGate());
    await tester.pumpAndSettle();

    expect(find.byType(BrandSplash), findsNothing);
    expect(find.text('الشاشة الأولى'), findsOneWidget);
  });

  testWidgets('reduced motion keeps the mark still and ends sooner', (
    tester,
  ) async {
    await tester.pumpWidget(gate());
    await tester.pump(const Duration(milliseconds: 400));
    expect(markPainter(tester).orbit!.value, 0);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.byType(BrandSplash), findsNothing);
  });
}
