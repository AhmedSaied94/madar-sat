import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/skeleton.dart';

import 'golden_harness.dart';

void main() {
  testWidgets('Skeleton golden variants', (tester) async {
    await goldenVariants(tester, 'skeleton', (context) => const Skeleton());
  });

  testWidgets('the skeleton is static when reduced motion is on', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MadarTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: Skeleton()),
        ),
      ),
    );
    await tester.pump();
    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition).first);
    final before = fade.opacity.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(fade.opacity.value, before);
  });
}
