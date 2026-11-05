import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/brand_splash.dart';
import 'package:madar_sat/design/components/logo.dart';

import 'golden_harness.dart';

void main() {
  testWidgets('BrandSplash golden variants', (tester) async {
    await goldenVariants(
      tester,
      'brand_splash',
      (context) => const SizedBox(
        width: 360,
        height: 700,
        child: BrandSplash(progress: AlwaysStoppedAnimation<double>(0.5)),
      ),
    );
  });

  testWidgets('the satellite passes behind the planet, then in front of it', (tester) async {
    await goldenVariants(
      tester,
      'brand_orbit',
      (context) => ColoredBox(
        color: MadarColors.dark.bg,
        child: Wrap(
          children: [
            for (final progress in const [0.0, 0.2, 0.35, 0.5, 0.65, 0.8])
              SizedBox.square(
                dimension: 100,
                child: CustomPaint(
                  painter: MadarMarkPainter(
                    ring: MadarColors.dark.accent,
                    body: MadarColors.dark.textPrimary,
                    orbit: AlwaysStoppedAnimation<double>(progress),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  });
}
