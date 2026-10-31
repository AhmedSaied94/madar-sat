import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/design/components/segmented.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  const two = [
    SegmentedOption(value: 'sports', label: 'رياضة'),
    SegmentedOption(value: 'entertainment', label: 'ترفيه'),
  ];
  const three = [
    SegmentedOption(value: 'all', label: 'الكل'),
    SegmentedOption(value: 'sports', label: 'رياضة'),
    SegmentedOption(value: 'entertainment', label: 'ترفيه'),
  ];

  testWidgets('Segmented golden variants', (tester) async {
    await goldenVariants(
      tester,
      'segmented',
      (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Segmented<String>(options: two, selected: 'sports', onChanged: (_) {}),
            const SizedBox(height: 12),
            Segmented<String>(options: two, selected: 'entertainment', onChanged: (_) {}),
            const SizedBox(height: 12),
            Segmented<String>(options: three, selected: 'all', onChanged: (_) {}),
          ],
        ),
      ),
    );
  });

  testWidgets('selecting a segment reports its value', (tester) async {
    String? picked;
    await tester.pumpWidget(
      testApp(
        Segmented<String>(options: two, selected: 'sports', onChanged: (v) => picked = v),
      ),
    );

    await tester.tap(find.text('ترفيه'));

    expect(picked, 'entertainment');
  });

  testWidgets('the selected segment is announced as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(Segmented<String>(options: two, selected: 'sports', onChanged: (_) {})),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('رياضة')),
      isSemantics(
        label: 'رياضة',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });
}
