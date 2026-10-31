import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/models/match_detail.dart';
import 'package:madar_sat/core/network/generated/models/status.dart';
import 'package:madar_sat/features/match_detail/presentation/match_hero.dart';

import '../../fixtures/sample_match_detail.dart';
import '../../fixtures/sample_models.dart';
import '../../fixtures/test_app.dart';

/// The hero's countdown line: «تبدأ بعد …» only while the match is scheduled, has a kickoff,
/// and that kickoff is more than an hour away. Inside the hour the status block counts it,
/// and after kickoff there is nothing to count (M-R1-8, M-R2-10).
void main() {
  // The fixture's kickoff: 21:00 on the device, on 2026-10-28.
  final kickoff = sampleKickoffAt();

  Future<void> pump(WidgetTester tester, MatchDetail match, DateTime now) =>
      tester.pumpWidget(testApp(MatchHero(match: match, now: now)));

  testWidgets('three hours before kickoff it counts the wait', (tester) async {
    await pump(tester, sampleMatchDetail(), kickoff.subtract(const Duration(hours: 3)));

    expect(find.text('تبدأ بعد 3 ساعات'), findsOneWidget);
  });

  testWidgets('inside the last hour the status block counts, so the line is gone',
      (tester) async {
    await pump(tester, sampleMatchDetail(), kickoff.subtract(const Duration(minutes: 25)));

    expect(find.textContaining('تبدأ بعد'), findsNothing);
  });

  testWidgets('after kickoff there is nothing left to count', (tester) async {
    await pump(tester, sampleMatchDetail(), kickoff.add(const Duration(minutes: 30)));

    expect(find.textContaining('تبدأ بعد'), findsNothing);
  });

  testWidgets('a match with no set time has nothing to count', (tester) async {
    // A time-tbd match keeps a kickoff in this fixture, so this pins the `timeTbd` guard
    // and not the null one.
    await pump(
      tester,
      sampleMatchDetail().copyWith(timeTbd: true),
      DateTime(2026, 10, 28, 18),
    );

    expect(find.textContaining('تبدأ بعد'), findsNothing);
    expect(find.text('الأربعاء 28 أكتوبر · لم يُحدد'), findsOneWidget);
  });

  testWidgets('a match with no kickoff at all has nothing to count', (tester) async {
    await pump(tester, sampleMatchDetail(timeTbd: true), DateTime(2026, 10, 28, 18));

    expect(find.textContaining('تبدأ بعد'), findsNothing);
  });

  testWidgets('a match that is no longer scheduled has nothing to count', (tester) async {
    await pump(
      tester,
      sampleMatchDetail(status: Status.live, minute: '12'),
      DateTime(2026, 10, 28, 18),
    );

    expect(find.textContaining('تبدأ بعد'), findsNothing);
  });
}
