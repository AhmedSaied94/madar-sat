import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/models/match_detail.dart';
import 'package:madar_sat/core/network/generated/models/score.dart';
import 'package:madar_sat/core/network/generated/models/status.dart';
import 'package:madar_sat/core/settings/app_settings.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/display_scope.dart';
import 'package:madar_sat/features/match_detail/presentation/match_hero.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/sample_match_detail.dart';
import '../../fixtures/sample_models.dart';
import '../../fixtures/semantics_actions.dart';
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

  group('a screen reader (M-R1-1, §13.8)', () {
    final now = kickoff.subtract(const Duration(hours: 3));

    testWidgets('the hero stays one merged label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(MatchHero(match: sampleMatchDetail(), now: now, onOpenTeam: (_) {}, onOpenCompetition: (_) {})),
      );

      final label = tester.getSemantics(find.byType(MatchHero)).label;
      for (final part in ['الأهلي', 'الزمالك', 'الدوري المصري الممتاز', 'تبدأ بعد 3 ساعات']) {
        expect(label, contains(part));
      }
      // The date line and the countdown are in that label, not nodes of their own.
      expect(find.semantics.byLabel('تبدأ بعد 3 ساعات'), findsNothing);
      handle.dispose();
    });

    testWidgets('each team and the competition is a button of its own', (tester) async {
      final handle = tester.ensureSemantics();
      final teams = <int>[];
      final competitions = <int>[];
      await tester.pumpWidget(
        testApp(
          MatchHero(
            match: sampleMatchDetail(),
            now: now,
            onOpenTeam: teams.add,
            onOpenCompetition: competitions.add,
          ),
        ),
      );

      tapSemanticAction(tester, 'الأهلي');
      tapSemanticAction(tester, 'الزمالك');
      tapSemanticAction(tester, 'الدوري المصري الممتاز');

      expect(teams, [1, 2]);
      expect(competitions, [12]);
      handle.dispose();
    });

    testWidgets('with no actions it offers no buttons, only the merged label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(testApp(MatchHero(match: sampleMatchDetail(), now: now)));

      expect(semanticAction('الأهلي'), findsNothing);
      expect(semanticAction('الدوري المصري الممتاز'), findsNothing);
      expect(find.semantics.byLabel('الأهلي'), findsNothing);
      expect(find.semantics.byLabel('الدوري المصري الممتاز'), findsNothing);
      handle.dispose();
    });
  });

  group('the date follows the chosen zone (M-R2-3)', () {
    // 00:30 on Thursday 12 November by the device's own clock, whatever zone the host runs
    // in. The chosen zone sits 14 hours behind the device (GMT−12 on a UTC+2 phone), so
    // there it is still 10:30 on Wednesday 11 November.
    final deviceMidnight = DateTime(2026, 11, 12, 0, 30);
    final chosen = MadarZone.fixed(
      deviceMidnight.timeZoneOffset - const Duration(hours: 14),
    );

    Future<void> pumpIn(WidgetTester tester, MatchDetail match, MadarZone zone) =>
        tester.pumpWidget(
          testApp(
            MadarDisplayScope(zone: zone, use24h: false, child: MatchHero(match: match)),
          ),
        );

    testWidgets('the date beside the time is the chosen zone\'s day, not the device\'s',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpIn(tester, sampleMatchDetail(kickoff: deviceMidnight), chosen);

      expect(find.text('الأربعاء 11 نوفمبر · 10:30 ص'), findsOneWidget);
      expect(find.text('الخميس 12 نوفمبر · 10:30 ص'), findsNothing);
      // The spoken label carries the same day.
      expect(
        tester.getSemantics(find.byType(MatchHero)).label,
        contains('الأربعاء 11 نوفمبر'),
      );
      handle.dispose();
    });

    testWidgets('with the automatic zone the date is the device\'s day', (tester) async {
      await pumpIn(
        tester,
        sampleMatchDetail(kickoff: deviceMidnight),
        const MadarZone.auto(),
      );

      expect(find.text('الخميس 12 نوفمبر · 12:30 ص'), findsOneWidget);
    });

    testWidgets('a match with no time shows its own date in any zone', (tester) async {
      // `matchDate` is a calendar date, not an instant: no zone moves it.
      await pumpIn(
        tester,
        sampleMatchDetail(timeTbd: true).copyWith(matchDate: DateTime.utc(2026, 10, 28)),
        chosen,
      );

      expect(find.text('الأربعاء 28 أكتوبر · لم يُحدد'), findsOneWidget);
    });
  });

  group('the score highlight (FR-054)', () {
    MatchDetail withScore(int home, int away) => sampleMatchDetail(
          status: Status.live,
          score: Score(home: home, away: away, homePen: null, awayPen: null),
          minute: '67',
        );

    Future<void> pumpScore(
      WidgetTester tester,
      MatchDetail match, {
      bool reducedMotion = false,
      bool highlight = true,
    }) =>
        tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: MadarTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
              child: child!,
            ),
            home: Scaffold(
              body: MatchHero(match: match, now: kickoff, highlightScore: highlight),
            ),
          ),
        );

    /// The highlight's colour right now; transparent at rest.
    Color? surface(WidgetTester tester) {
      final box = tester.widget<DecoratedBox>(find.byKey(ScoreFlash.surfaceKey));
      return (box.decoration as BoxDecoration).color;
    }

    testWidgets('nothing on first paint', (tester) async {
      await pumpScore(tester, withScore(1, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(surface(tester)?.a, 0);
    });

    testWidgets('once on a rise, for 1.2 s', (tester) async {
      await pumpScore(tester, withScore(1, 0));
      await pumpScore(tester, withScore(2, 0));

      await tester.pump(const Duration(milliseconds: 100));
      expect(surface(tester)!.a, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 1200));
      expect(surface(tester)?.a, 0);

      // A rebuild with the same score does not flash again.
      await pumpScore(tester, withScore(2, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(surface(tester)?.a, 0);
    });

    testWidgets('on a rise of either side', (tester) async {
      await pumpScore(tester, withScore(1, 0));
      await pumpScore(tester, withScore(1, 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(surface(tester)!.a, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a score appearing where there was none counts as first paint', (tester) async {
      await pumpScore(tester, sampleMatchDetail());
      await pumpScore(tester, withScore(1, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(surface(tester)?.a, 0);
    });

    testWidgets('nothing on a fall', (tester) async {
      await pumpScore(tester, withScore(2, 0));
      await pumpScore(tester, withScore(1, 0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(surface(tester)?.a, 0);
    });

    testWidgets('nothing under reduced motion', (tester) async {
      await pumpScore(tester, withScore(1, 0), reducedMotion: true);
      await pumpScore(tester, withScore(2, 0), reducedMotion: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(surface(tester)?.a, 0);
    });

    testWidgets('nothing with the live center off', (tester) async {
      await pumpScore(tester, withScore(1, 0), highlight: false);
      await pumpScore(tester, withScore(2, 0), highlight: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(surface(tester)?.a, 0);
    });
  });
}
