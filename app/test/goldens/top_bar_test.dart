import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/top_bar.dart';

import 'golden_harness.dart';

void main() {
  testWidgets('MadarTopBar golden variants', (tester) async {
    await goldenVariants(
      tester,
      'top_bar',
      (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: MadarSpace.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MadarTopBar.root(onSearch: () {}),
            const SizedBox(height: MadarSpace.s4),
            MadarTopBar.detail(
              title: 'نايل سات',
              onBack: () {},
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.notifications_outlined, color: context.madarColors.accentText),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.share_outlined, color: context.madarColors.textPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  });
}
