import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/design/components/search_field.dart';

import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  testWidgets('SearchField golden variants', (tester) async {
    await goldenVariants(
      tester,
      'search_field',
      (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SearchField(hint: 'ابحث عن قناة أو تردد'),
            const SizedBox(height: 12),
            SearchField(
              hint: 'ابحث عن قناة أو تردد',
              controller: TextEditingController(text: 'beIN'),
            ),
            const SizedBox(height: 12),
            SearchField(
              hint: 'ابحث عن قناة أو تردد',
              dense: true,
              controller: TextEditingController(text: '11843'),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('the clear button appears with text and empties the field', (tester) async {
    final controller = TextEditingController();
    String? last;
    await tester.pumpWidget(
      testApp(SearchField(hint: 'بحث', controller: controller, onChanged: (v) => last = v)),
    );
    expect(find.byTooltip('مسح البحث'), findsNothing);

    await tester.enterText(find.byType(TextField), 'نايل');
    await tester.pump();
    expect(find.byTooltip('مسح البحث'), findsOneWidget);
    expect(last, 'نايل');

    await tester.tap(find.byTooltip('مسح البحث'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(last, '');
    expect(find.byTooltip('مسح البحث'), findsNothing);
  });

  testWidgets('submitting reports the text', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      testApp(SearchField(hint: 'بحث', onSubmitted: (v) => submitted = v)),
    );

    await tester.enterText(find.byType(TextField), '11843');
    await tester.testTextInput.receiveAction(TextInputAction.search);

    expect(submitted, '11843');
  });

  testWidgets('a field it did not create is never disposed by it', (tester) async {
    final controller = TextEditingController(text: 'x');
    await tester.pumpWidget(testApp(SearchField(hint: 'بحث', controller: controller)));
    await tester.pumpWidget(testApp(const SizedBox.shrink()));

    // Would throw "used after being disposed" if the field had disposed it.
    controller.text = 'y';
    controller.dispose();
  });

  testWidgets('the placeholder names the field for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(testApp(const SearchField(hint: 'ابحث عن قناة أو تردد')));

    // The label merges into the text field's own node, so match it as a part.
    expect(find.bySemanticsLabel(RegExp('ابحث عن قناة أو تردد')), findsWidgets);
    handle.dispose();
  });
}
