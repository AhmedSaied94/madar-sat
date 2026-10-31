import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  testWidgets('StaleHint golden variants', (tester) async {
    await goldenVariants(
      tester,
      'stale_hint',
      (context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StaleHint(age: Duration(seconds: 20)),
            SizedBox(height: 12),
            StaleHint(age: Duration(minutes: 7)),
            SizedBox(height: 12),
            StaleHint(age: Duration(hours: 3)),
            SizedBox(height: 12),
            StaleHint(age: Duration(days: 2)),
          ],
        ),
      ),
    );
  });

  group('the age in words', () {
    late AppLocalizations l;

    setUp(() async {
      l = await AppLocalizations.delegate.load(const Locale('ar'));
    });

    test('under a minute is «الآن»', () {
      expect(StaleHint.ageText(l, const Duration(seconds: 59)), 'الآن');
    });

    test('minutes, hours and days, in Western digits', () {
      expect(StaleHint.ageText(l, const Duration(minutes: 5)), 'منذ 5 د');
      expect(StaleHint.ageText(l, const Duration(minutes: 59)), 'منذ 59 د');
      expect(StaleHint.ageText(l, const Duration(hours: 1)), 'منذ 1 س');
      expect(StaleHint.ageText(l, const Duration(hours: 23, minutes: 59)), 'منذ 23 س');
      expect(StaleHint.ageText(l, const Duration(hours: 24)), 'منذ 1 يوم');
      expect(StaleHint.ageText(l, const Duration(days: 12)), 'منذ 12 يوم');
    });
  });

  testWidgets('reads as one Arabic label with the age', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(testApp(const StaleHint(age: Duration(minutes: 7))));

    expect(find.bySemanticsLabel('آخر تحديث منذ 7 د'), findsOneWidget);
    handle.dispose();
  });
}
