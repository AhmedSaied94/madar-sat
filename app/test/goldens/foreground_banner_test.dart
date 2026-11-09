import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/platform/push_routes.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/features/notifications/presentation/foreground_banner.dart';

import 'golden_harness.dart';

/// The foreground banner with «عرض» and without, RTL × {light, dark} × {1.0, 1.3}
/// (FR-059, review M-R1-1: «عرض» reads in both themes).
void main() {
  testWidgets('foreground banner', (tester) async {
    await goldenVariants(
      tester,
      'foreground_banner',
      (context) => SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ForegroundBanner(
              push: ForegroundPush(
                title: 'هدف للأهلي',
                body: 'محمد صلاح في الدقيقة 23',
                route: parsePushRoute('/match/7'),
              ),
              onView: () {},
              onDismiss: () {},
            ),
            const SizedBox(height: MadarSpace.s3),
            ForegroundBanner(
              push: const ForegroundPush(
                title: 'تحديث القنوات',
                body: 'أضيفت قناة جديدة للمباراة',
              ),
              onView: () {},
              onDismiss: () {},
            ),
          ],
        ),
      ),
      size: const Size(360, 320),
    );
  });
}
