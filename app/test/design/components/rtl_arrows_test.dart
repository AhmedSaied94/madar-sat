import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/design/components/button.dart';
import 'package:madar_sat/design/components/list_row.dart';
import 'package:madar_sat/features/onboarding/domain/onboarding_step.dart';
import 'package:madar_sat/features/onboarding/presentation/onboarding_page.dart';

import '../../fixtures/test_app.dart';

/// Direction in RTL (constitution III, product doc §13.4, M-R1-11). `chevron_right`,
/// `arrow_forward` and `arrow_back` all carry `matchTextDirection`, so the material name is
/// already the RTL meaning; the row and the onboarding footer must use the right one.
void main() {
  testWidgets('a navigation row points forward with chevron_right', (tester) async {
    await tester.pumpWidget(
      testApp(
        MadarListRow(
          title: 'الإعدادات',
          showChevron: true,
          onTap: () {},
        ),
      ),
    );

    final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
    expect(chevron.icon?.matchTextDirection, isTrue);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    addTearDown(database.close);
  });

  Future<void> pumpStep(WidgetTester tester, OnboardingStep step) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: testApp(OnboardingPage(step: step)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('«التالي» carries a forward arrow after its label', (tester) async {
    await pumpStep(tester, OnboardingStep.welcome);

    final button = tester.widget<MadarButton>(find.byType(MadarButton));
    expect(button.trailingIcon, Icons.arrow_forward);
    expect(button.icon, isNull, reason: 'the arrow must not sit before the label');

    // RTL: the end of the row is on the left, so the trailing arrow is left of the label.
    final arrow = tester.getCenter(find.byIcon(Icons.arrow_forward));
    final label = tester.getCenter(find.text('التالي'));
    expect(arrow.dx, lessThan(label.dx));
  });

  testWidgets('«رجوع» points back with arrow_back', (tester) async {
    await pumpStep(tester, OnboardingStep.teams);

    // The back control is an IconButton; its glyph must be `arrow_back`, which mirrors in
    // RTL to point right. `arrow_forward` there would point left, the way forward reads.
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byIcon(Icons.arrow_back),
      ),
    );
    expect(icon.icon?.matchTextDirection, isTrue);
  });
}
