import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

final RegExp _arabic = RegExp(r'[؀-ۿ]');

bool _isActionNamed(SemanticsNode node, String name) {
  final data = node.getSemanticsData();
  return (data.label == name || data.tooltip == name) &&
      data.flagsCollection.isButton &&
      data.hasAction(SemanticsAction.tap);
}

/// What a screen reader can reach and activate: one node of its own named [name] (in Arabic),
/// with the button role and a tap action. `find.text` and `find.byTooltip` ignore semantics, so
/// they can't prove this. The test must hold `tester.ensureSemantics()`.
FinderBase<SemanticsNode> semanticAction(String name) {
  expect(_arabic.hasMatch(name), isTrue, reason: '«$name» must be Arabic');
  return find.semantics.byPredicate(
    (node) => _isActionNamed(node, name),
    describeMatch: (_) => 'a button node named «$name» with a tap action',
  );
}

/// Double-taps [name] as a screen reader does.
void tapSemanticAction(WidgetTester tester, String name) =>
    tester.semantics.tap(semanticAction(name));
