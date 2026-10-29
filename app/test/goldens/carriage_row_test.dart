import 'package:flutter/material.dart';
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
}
