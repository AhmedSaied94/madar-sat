import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/audio/clip_controller.dart';
import 'package:madar_sat/design/components/commentator_row.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  testWidgets('CommentatorRow golden variants: idle, loading, playing, error, no sample',
      (tester) async {
    await goldenVariants(
      tester,
      'commentator_row',
      (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CommentatorRowView(name: 'عصام الشوالي', onTap: () {}),
            const SizedBox(height: 8),
            CommentatorRowView(name: 'عصام الشوالي', phase: ClipPhase.loading, onTap: () {}),
            const SizedBox(height: 8),
            CommentatorRowView(
              name: 'عصام الشوالي',
              phase: ClipPhase.playing,
              progress: 0.4,
              onTap: () {},
            ),
            const SizedBox(height: 8),
            CommentatorRowView(name: 'عصام الشوالي', phase: ClipPhase.error, onTap: () {}),
            const SizedBox(height: 8),
            const CommentatorRowView(name: 'عصام الشوالي', hasSample: false),
          ],
        ),
      ),
    );
  });

  testWidgets('the play button is a 48 dp target around a 40 dp control', (tester) async {
    await tester.pumpWidget(testApp(CommentatorRowView(name: 'عصام الشوالي', onTap: () {})));

    final target = tester.getSize(find.byType(IconButton));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the row reads as one Arabic label, with the state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        const CommentatorRowView(name: 'عصام الشوالي', phase: ClipPhase.playing, progress: 0.4),
      ),
    );

    expect(find.bySemanticsLabel('المعلّق، عصام الشوالي، يُشغَّل الآن'), findsOneWidget);
    handle.dispose();
  });
}
