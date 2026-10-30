import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/badges.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  testWidgets('Badges golden variants', (tester) async {
    await goldenVariants(
      tester,
      'access_badge',
      (context) => Wrap(
        spacing: MadarSpace.s2,
        runSpacing: MadarSpace.s2,
        children: [
          const AccessBadge(access: Access.free),
          const AccessBadge(access: Access.encrypted),
          const AccessBadge(access: Access.encrypted, provider: 'beIN'),
          const SatelliteBadge(name: 'نايل سات'),
          const SatelliteBadge(name: 'Nilesat 7.0W'),
          // A local wall clock, so the day-month label is the same in every host zone.
          ChangedBadge(changedAt: DateTime(2026, 10, 20, 12)),
          const CategoryBadge(sports: true),
          const CategoryBadge(sports: false),
          const CountBadge(count: 171),
        ],
      ),
    );
  });

  testWidgets('access meaning is a word and a glyph, not colour alone', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Column(
          children: [
            AccessBadge(access: Access.free),
            AccessBadge(access: Access.encrypted),
          ],
        ),
      ),
    );
    expect(find.text('مجانية'), findsOneWidget);
    expect(find.text('مشفرة'), findsOneWidget);
    expect(find.byIcon(Icons.lock_open_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}
