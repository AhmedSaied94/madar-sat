import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/design/components/button.dart';

import '../../fixtures/test_app.dart';

/// Touch targets (constitution IV, Button README, M-R1-12): every size keeps a 48 dp target
/// whatever it draws, and a tap at the edge of that box still reaches the action.
void main() {
  for (final (size, visual) in [
    (MadarButtonSize.regular, 48.0),
    (MadarButtonSize.small, 40.0),
    (MadarButtonSize.extraSmall, 32.0),
  ]) {
    testWidgets('${size.name} draws $visual dp and takes a 48 dp target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        testApp(
          MadarButton(
            label: 'حفظ',
            size: size,
            onPressed: () => taps++,
          ),
        ),
      );

      final target = tester.getRect(find.byType(InkWell));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(target.width, greaterThanOrEqualTo(48));

      final body = tester.getRect(
        find.descendant(of: find.byType(MadarButton), matching: find.byType(Container)),
      );
      expect(body.height, visual);

      // A tap at the start of the box, outside the drawn body but inside the target (the
      // corners are rounded, so the probe is at the vertical middle).
      await tester.tapAt(target.centerLeft + const Offset(4, 0));
      expect(taps, 1);
    });
  }

  testWidgets('FollowButton draws 28 dp inside a 48 dp target', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      testApp(
        FollowButton(
          following: false,
          label: 'تابع',
          followingLabel: 'تتابعه',
          onPressed: () => taps++,
        ),
      ),
    );

    final target = tester.getRect(find.byType(InkWell));
    expect(target.height, greaterThanOrEqualTo(48));
    expect(target.width, greaterThanOrEqualTo(48));

    final pill = tester.getRect(find.byType(Container).last);
    expect(pill.height, 28);

    await tester.tapAt(target.centerLeft + const Offset(4, 0));
    expect(taps, 1, reason: 'the whole 48 dp box is tappable');
  });
}
