import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/carriage_row.dart';

import '../fixtures/sample_models.dart';
import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  testWidgets('CarriageRow golden variants', (tester) async {
    await goldenVariants(
      tester,
      'carriage_row',
      (context) => Column(
        children: [
          CarriageRow(carriage: sampleCarriage()),
          Divider(height: 1, color: context.madarColors.divider),
          CarriageRow(carriage: sampleCarriage(), expanded: true),
          Divider(height: 1, color: context.madarColors.divider),
          CarriageRow(carriage: sampleCarriage(access: Access.free)),
          Divider(height: 1, color: context.madarColors.divider),
          CarriageRow(carriage: sampleCarriage(withSatellite: false)),
        ],
      ),
    );
  });

  testWidgets('copying a frequency puts «11843 H 27500» on the clipboard and says so',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(testApp(CarriageRow(carriage: sampleCarriage(), expanded: true)));

    await tester.tap(find.text('نسخ التردد'));
    await tester.pump();

    expect(copied, '11843 H 27500');
    expect(find.text('تم نسخ التردد'), findsOneWidget);
  });

  testWidgets('the reception video action shows only when it can be opened', (tester) async {
    await tester.pumpWidget(testApp(CarriageRow(carriage: sampleCarriage(), expanded: true)));
    expect(find.text('فيديو الاستقبال'), findsNothing);

    var opened = 0;
    await tester.pumpWidget(
      testApp(
        CarriageRow(
          carriage: sampleCarriage(),
          expanded: true,
          onWatchReception: () => opened += 1,
        ),
      ),
    );
    await tester.tap(find.text('فيديو الاستقبال'));

    expect(opened, 1);
  });

  testWidgets('a collapsed row is one merged Arabic label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(CarriageRow(carriage: sampleCarriage(access: Access.free))),
    );

    expect(
      find.bySemanticsLabel('beIN SPORTS 1 HD، مجانية، نايل سات، 11843 H 27500'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a screen reader can activate the row, not only hear it called a button',
      (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      testApp(CarriageRow(carriage: sampleCarriage(access: Access.free), onTap: () => taps += 1)),
    );

    tester.semantics.tap(
      find.semantics.byLabel('beIN SPORTS 1 HD، مجانية، نايل سات، 11843 H 27500'),
    );

    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('an expanded row keeps its actions reachable for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    var opened = 0;
    await tester.pumpWidget(
      testApp(
        CarriageRow(
          carriage: sampleCarriage(),
          expanded: true,
          onTap: () {},
          onWatchReception: () => opened += 1,
        ),
      ),
    );

    expect(find.bySemanticsLabel('نسخ التردد'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('فيديو الاستقبال'));

    expect(opened, 1);
    handle.dispose();
  });
}
