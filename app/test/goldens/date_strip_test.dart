import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/date_strip.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  final week = [
    DateTime(2026, 10, 26),
    DateTime(2026, 10, 27),
    DateTime(2026, 10, 28),
    DateTime(2026, 10, 29),
    DateTime(2026, 10, 30),
    DateTime(2026, 10, 31),
    DateTime(2026, 11, 1),
  ];

  testWidgets('DateStrip golden variants', (tester) async {
    await goldenVariants(
      tester,
      'date_strip',
      (context) => Padding(
        padding: const EdgeInsets.all(MadarSpace.s4),
        child: DateStrip(
          days: week,
          selected: week[2],
          today: week[2],
          onSelect: (_) {},
        ),
      ),
    );
  });

  testWidgets('today carries a marker and the selected day is filled', (tester) async {
    DateTime? selected;
    await tester.pumpWidget(
      testApp(
        DateStrip(
          days: week,
          selected: week[3],
          today: week[2],
          onSelect: (day) => selected = day,
        ),
      ),
    );

    expect(find.text('اليوم'), findsOneWidget);
    await tester.tap(find.text('اليوم'));
    expect(selected, week[2]);
  });
}
