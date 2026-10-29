import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/frequency_readout.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  testWidgets('FrequencyReadout golden variants', (tester) async {
    await goldenVariants(
      tester,
      'frequency_readout',
      (context) => const Wrap(
        spacing: MadarSpace.s3,
        runSpacing: MadarSpace.s3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FrequencyReadout(mhz: 11843, polarization: Polarization.h, symbolRate: 27500),
          FrequencyReadout(
            mhz: 11843,
            polarization: Polarization.h,
            symbolRate: 27500,
            size: FrequencyReadoutSize.lg,
          ),
          FrequencyReadout(
            mhz: 11843,
            polarization: Polarization.h,
            symbolRate: 27500,
            size: FrequencyReadoutSize.xl,
          ),
          FrequencyReadout(
            mhz: 11843,
            polarization: Polarization.h,
            symbolRate: 27500,
            state: FrequencyReadoutState.dim,
          ),
          FrequencyReadout(
            mhz: 12054,
            polarization: Polarization.v,
            symbolRate: 27500,
            state: FrequencyReadoutState.good,
          ),
          FrequencyReadout(
            mhz: 12188,
            polarization: Polarization.l,
            symbolRate: 27500,
            state: FrequencyReadoutState.bad,
          ),
          FrequencyReadout(note: 'UHF 32', state: FrequencyReadoutState.note),
        ],
      ),
    );
  });

  testWidgets('the readout stays dark and LTR in the light theme', (tester) async {
    await tester.pumpWidget(
      testApp(
        const FrequencyReadout(
          mhz: 11843,
          polarization: Polarization.h,
          symbolRate: 27500,
        ),
        brightness: Brightness.light,
      ),
    );
    final ltr = tester
        .widgetList<Directionality>(find.byType(Directionality))
        .where((widget) => widget.textDirection == TextDirection.ltr);
    expect(ltr, isNotEmpty);
    expect(find.text('11843'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.text('27500'), findsOneWidget);
  });
}
