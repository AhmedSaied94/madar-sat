import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/carriage_row.dart';
import 'package:madar_sat/design/components/frequency_readout.dart';

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
          // Open, with a provider and a package: the two lines the access row adds (M-R2-10).
          CarriageRow(
            carriage: sampleCarriage(provider: 'beIN', package: 'beIN Sports'),
            expanded: true,
          ),
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

  testWidgets('the expanded row names the satellite once, position included in its name',
      (tester) async {
    await tester.pumpWidget(testApp(CarriageRow(carriage: sampleCarriage(), expanded: true)));

    expect(find.text('نايل سات'), findsWidgets);
    expect(find.text('Nilesat 7.0W'), findsOneWidget);
    expect(find.text('7.0W'), findsNothing, reason: 'the English name already carries it');
    expect(find.text('-7'), findsNothing, reason: 'E/W, never the signed -7');
    expect(find.text('الوصول'), findsOneWidget);
    expect(find.text('الفئة'), findsOneWidget);
    expect(find.text('رياضة'), findsOneWidget);
  });

  testWidgets('a satellite whose name leaves the position out gets it, with its degree sign',
      (tester) async {
    await tester.pumpWidget(
      testApp(
        CarriageRow(
          carriage: sampleCarriage().copyWith(
            satellite: const SatelliteRef(
              id: 7,
              slug: 'hotbird-13-0e',
              nameAr: 'هوت بيرد',
              nameEn: 'Hotbird',
              orbitalPosition: 13,
            ),
          ),
          expanded: true,
        ),
      ),
    );

    expect(find.text('Hotbird'), findsOneWidget);
    expect(find.text('13.0°E'), findsOneWidget, reason: 'islanded, east of the meridian');
  });

  testWidgets('the tuning line reads left to right: the number, then MHz', (tester) async {
    await tester.pumpWidget(testApp(CarriageRow(carriage: sampleCarriage(), expanded: true)));

    final text = find.text('11843 MHz');
    expect(text, findsOneWidget);
    expect(
      Directionality.of(tester.element(text)),
      TextDirection.ltr,
      reason: 'a plain Text in the RTL row would draw «MHz 11843» (M-R2-1)',
    );
  });

  testWidgets('the access row names the provider and the package when there are any',
      (tester) async {
    await tester.pumpWidget(
      testApp(
        CarriageRow(
          carriage: sampleCarriage(provider: 'beIN', package: 'beIN Sports'),
          expanded: true,
        ),
      ),
    );

    expect(find.textContaining('beIN'), findsWidgets);
    expect(find.text('beIN Sports'), findsOneWidget, reason: 'the package, as a Latin island');
    expect(
      Directionality.of(tester.element(find.text('beIN Sports'))),
      TextDirection.ltr,
    );
  });

  testWidgets('the follow action shows only when a caller can follow', (tester) async {
    await tester.pumpWidget(testApp(CarriageRow(carriage: sampleCarriage(), expanded: true)));
    expect(find.text('تابع'), findsNothing);

    await tester.pumpWidget(
      testApp(CarriageRow(carriage: sampleCarriage(), expanded: true, onFollow: () {})),
    );
    expect(find.text('تابع'), findsOneWidget);
  });

  testWidgets('tapping the readout copies it and outlines it in success', (tester) async {
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

    await tester.tap(find.byType(FrequencyReadout));
    await tester.pump();

    expect(copied, '11843 H 27500');
    expect(find.text('تم نسخ التردد'), findsOneWidget);
    expect(
      tester.widget<FrequencyReadout>(find.byType(FrequencyReadout)).state,
      FrequencyReadoutState.good,
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
