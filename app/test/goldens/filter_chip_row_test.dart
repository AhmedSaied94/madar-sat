import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/design/components/filter_chip_row.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  const withLiveCount = [
    FilterChipItem(value: 'all', label: 'الكل'),
    FilterChipItem(value: 'live', label: 'مباشر', count: 3, isLive: true),
  ];

  testWidgets('FilterChipRow golden variants', (tester) async {
    await goldenVariants(
      tester,
      'filter_chip_row',
      (context) => Column(
        children: [
          FilterChipRow<String>(items: withLiveCount, selected: 'all', onSelected: (_) {}),
          FilterChipRow<String>(items: withLiveCount, selected: 'live', onSelected: (_) {}),
          // A count of zero is hidden, not shown as 0.
          FilterChipRow<String>(
            items: const [
              FilterChipItem(value: 'all', label: 'الكل', count: 14),
              FilterChipItem(value: 'live', label: 'مباشر', count: 0, isLive: true),
            ],
            selected: 'all',
            onSelected: (_) {},
          ),
        ],
      ),
    );
  });

  testWidgets('a count of zero is not drawn', (tester) async {
    await tester.pumpWidget(
      testApp(
        FilterChipRow<String>(
          items: const [FilterChipItem(value: 'live', label: 'مباشر', count: 0)],
          selected: 'live',
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
  });

  testWidgets('counts use Western digits', (tester) async {
    await tester.pumpWidget(
      testApp(
        FilterChipRow<String>(
          items: const [FilterChipItem(value: 'live', label: 'مباشر', count: 12)],
          selected: 'live',
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its value', (tester) async {
    String? picked;
    await tester.pumpWidget(
      testApp(
        FilterChipRow<String>(items: withLiveCount, selected: 'all', onSelected: (v) => picked = v),
      ),
    );

    await tester.tap(find.text('مباشر'));

    expect(picked, 'live');
  });

  testWidgets('a chip reads as one label with its count, and says whether it is selected',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        FilterChipRow<String>(items: withLiveCount, selected: 'live', onSelected: (_) {}),
      ),
    );

    expect(find.bySemanticsLabel('مباشر، 3'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('مباشر، 3')),
      isSemantics(
        label: 'مباشر، 3',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a long row scrolls instead of wrapping', (tester) async {
    await tester.pumpWidget(
      testApp(
        SizedBox(
          width: 200,
          child: FilterChipRow<int>(
            items: [for (var i = 0; i < 8; i++) FilterChipItem(value: i, label: 'دوري $i')],
            selected: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
