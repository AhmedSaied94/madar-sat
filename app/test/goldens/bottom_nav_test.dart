import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/bottom_nav.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  testWidgets('MadarBottomNav golden variants', (tester) async {
    await goldenVariants(
      tester,
      'bottom_nav',
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MadarBottomNav(
            current: MadarTab.matches,
            onSelect: (_) {},
            favoritesBadge: 2,
          ),
          const SizedBox(height: MadarSpace.s4),
          MadarBottomNav(current: MadarTab.mySatellites, onSelect: (_) {}),
          const SizedBox(height: MadarSpace.s4),
          MadarBottomNav(current: MadarTab.frequencies, onSelect: (_) {}),
          const SizedBox(height: MadarSpace.s4),
          MadarBottomNav(current: MadarTab.favorites, onSelect: (_) {}, favoritesBadge: 2),
          const SizedBox(height: MadarSpace.s4),
          MadarBottomNav(current: MadarTab.more, onSelect: (_) {}),
        ],
      ),
    );
  });

  testWidgets('five destinations in RTL order with 48 dp targets', (tester) async {
    MadarTab? selected;
    await tester.pumpWidget(
      testApp(
        const SizedBox.shrink(),
        bottomNavigationBar: MadarBottomNav(
          current: MadarTab.matches,
          onSelect: (tab) => selected = tab,
        ),
      ),
    );

    final matches = tester.getCenter(find.text('المباريات')).dx;
    final more = tester.getCenter(find.text('المزيد')).dx;
    expect(matches, greaterThan(more));

    for (final label in ['المباريات', 'أقماري', 'الترددات', 'المفضلة', 'المزيد']) {
      final size = tester.getSize(
        find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
      );
      expect(size.height, greaterThanOrEqualTo(MadarLayout.touchMin));
    }

    await tester.tap(find.text('المفضلة'));
    expect(selected, MadarTab.favorites);
  });
}
