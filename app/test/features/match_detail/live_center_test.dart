import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/config/remote_config.dart';
import 'package:madar_sat/core/format/bidi.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/event_timeline_item.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/features/match_detail/domain/lineup_layout.dart';
import 'package:madar_sat/features/match_detail/domain/match_detail_live.dart';
import 'package:madar_sat/features/match_detail/presentation/live_center/lineups_pitch.dart';
import 'package:madar_sat/features/match_detail/presentation/live_center/live_center.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/sample_match_detail.dart';

RemoteConfigValues _config({bool liveCenter = true, bool lineups = true}) => RemoteConfigValues(
      apiBaseUrl: 'https://api.test',
      mediaBaseUrl: 'https://media.test',
      minSupportedBuild: 0,
      latestBuild: 0,
      livePollIntervalSeconds: 30,
      features: AppFeatures(liveCenter: liveCenter, lineups: lineups),
    );

const _goal = MatchEvent(
  type: MatchEventType.goal,
  side: MatchEventSide.home,
  minute: '23',
  player: 'محمد صلاح',
);
const _red = MatchEvent(
  type: MatchEventType.redCard,
  side: MatchEventSide.away,
  minute: '61',
  player: 'مويسيس كايسيدو',
);

LineupSide _lists() => const LineupSide(
      formation: '4-3-3',
      players: [
        LineupPlayer(name: 'أليسون', isStarter: true, number: 1, position: null),
        LineupPlayer(name: 'إندو', isStarter: false, number: 3, position: null),
      ],
    );

MatchDetail _live({
  List<MatchEvent> events = const [_goal, _red],
  MatchLineups? lineups,
  bool estimated = false,
  Status status = Status.live,
  Score? score = const Score(home: 1, away: 0, homePen: null, awayPen: null),
}) =>
    sampleMatchDetail(
      status: status,
      estimated: estimated,
      score: score,
      events: events,
      lineups: lineups,
    );

/// S3's live center, one row of [the states table] each (FR-051, FR-056–FR-058).
void main() {
  Future<void> pump(
    WidgetTester tester,
    MatchDetail match, {
    bool liveCenter = true,
    bool lineups = true,
    Duration? age,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteConfigProvider.overrideWithValue(_config(liveCenter: liveCenter, lineups: lineups)),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: MadarTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [LiveCenterSliver(match: match, age: age)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('nothing shows', () {
    testWidgets('with the flag off, whatever the match holds', (tester) async {
      await pump(
        tester,
        _live(lineups: MatchLineups(home: _lists(), away: null)),
        liveCenter: false,
      );
      expect(find.byType(EventTimelineItem), findsNothing);
      expect(find.text('الأحداث'), findsNothing);
      expect(find.text('التشكيل'), findsNothing);
    });

    testWidgets('with no events and no lineups, not even an empty frame', (tester) async {
      await pump(tester, _live(events: const []));
      final sliver = tester.renderObject<RenderSliver>(find.byType(LiveCenterSliver, skipOffstage: false));
      expect(sliver.geometry!.scrollExtent, 0);
      expect(find.text('الأحداث'), findsNothing);
    });

    testWidgets('and an estimated match with no data still has its note', (tester) async {
      await pump(tester, _live(events: const [], estimated: true, score: null));
      expect(find.text('بدون نتيجة'), findsOneWidget);
    });
  });

  group('the timeline', () {
    testWidgets('alone, with no tabs, when lineups do not show', (tester) async {
      await pump(tester, _live());
      expect(find.text('محمد صلاح'), findsOneWidget);
      expect(find.text('الأحداث'), findsNothing);
      expect(find.text('التشكيل'), findsNothing);
    });

    testWidgets('newest first while live, with markers', (tester) async {
      await pump(tester, _live());
      expect(
        tester.getTopLeft(find.text('مويسيس كايسيدو')).dy,
        lessThan(tester.getTopLeft(find.text('محمد صلاح')).dy),
      );
      expect(find.text('الشوط الثاني'), findsOneWidget);
      expect(find.text('بداية المباراة'), findsOneWidget);
    });

    testWidgets('home sits on the right, away on the left', (tester) async {
      await pump(tester, _live());
      final middle = tester.getCenter(find.byType(CustomScrollView)).dx;
      expect(tester.getCenter(find.text('محمد صلاح')).dx, greaterThan(middle));
      expect(tester.getCenter(find.text('مويسيس كايسيدو')).dx, lessThan(middle));
    });

    testWidgets('a goal row carries the running score only when it adds up', (tester) async {
      await pump(tester, _live());
      final goalRow = find.byWidgetPredicate(
        (w) => w is EventTimelineItem && w.event.type == MatchEventType.goal,
      );
      expect(find.descendant(of: goalRow, matching: find.byType(ScoreParts)), findsOneWidget);
      final score = tester.widget<ScoreParts>(
        find.descendant(of: goalRow, matching: find.byType(ScoreParts)),
      );
      expect((score.home, score.away), ('1', '0'));

      await pump(tester, _live(score: const Score(home: 2, away: 0, homePen: null, awayPen: null)));
      expect(find.text('هدف'), findsOneWidget);
      expect(find.byType(ScoreParts), findsNothing);
    });

    testWidgets('no player shows type and minute only', (tester) async {
      await pump(
        tester,
        _live(
          events: const [
            MatchEvent(
              type: MatchEventType.redCard,
              side: MatchEventSide.away,
              minute: '61',
              player: null,
            ),
          ],
        ),
      );
      expect(find.text('بطاقة حمراء'), findsOneWidget);
      expect(find.text('61′'), findsOneWidget);
    });

    testWidgets('a red card uses error with an icon, so colour never stands alone',
        (tester) async {
      await pump(tester, _live());
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is EventTimelineItem && w.event.type == MatchEventType.redCard,
          ),
          matching: find.byType(Icon),
        ),
      );
      final colors = tester.element(find.byType(CustomScrollView)).madarColors;
      expect(icon.color, colors.error);
      expect(icon.color, isNot(colors.live));
    });

    testWidgets('a stoppage minute is never cut, even at 1.3×', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: MadarTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Scaffold(
            body: EventTimelineItem(
              event: MatchEvent(
                type: MatchEventType.redCard,
                side: MatchEventSide.home,
                minute: '90+12',
                player: null,
              ),
              homeName: 'الأهلي',
              awayName: 'الزمالك',
            ),
          ),
        ),
      );

      final minute = tester.renderObject<RenderParagraph>(find.text('90+12′'));
      expect(minute.didExceedMaxLines, isFalse);
      expect(minute.size.width, greaterThanOrEqualTo(minute.getMaxIntrinsicWidth(double.infinity)));
    });

    testWidgets('no text in a goal row holds a raw score run (constitution III)', (tester) async {
      await pump(tester, _live());
      final goalRow = find.byWidgetPredicate(
        (w) => w is EventTimelineItem && w.event.type == MatchEventType.goal,
      );
      final rawScore = RegExp(r'\d\s*[-–—]\s*\d');
      final texts = tester
          .widgetList<Text>(find.descendant(of: goalRow, matching: find.byType(Text)))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .toList();
      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(rawScore.hasMatch(text), isFalse, reason: '«$text» is a raw score inside RTL text');
      }
    });

    testWidgets('each row has one Arabic screen-reader label', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, _live());

      expect(
        find.bySemanticsLabel('هدف، النتيجة الأهلي 1 والزمالك 0، محمد صلاح، الأهلي، الدقيقة 23'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('بطاقة حمراء، مويسيس كايسيدو، الزمالك، الدقيقة 61'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a long timeline builds only what is on screen', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        _live(
          events: [
            for (var i = 1; i <= 90; i++)
              MatchEvent(
                type: MatchEventType.redCard,
                side: MatchEventSide.home,
                minute: '$i',
                player: 'لاعب $i',
              ),
          ],
          score: null,
        ),
      );
      expect(find.byType(EventTimelineItem).evaluate().length, lessThan(40));
    });
  });

  group('the tabs', () {
    final lineups = MatchLineups(home: _lists(), away: null);

    testWidgets('appear with lineups on and data for one side', (tester) async {
      await pump(tester, _live(lineups: lineups));
      expect(find.text('الأحداث'), findsOneWidget);
      expect(find.text('التشكيل'), findsOneWidget);
    });

    testWidgets('stay away with the lineups flag off, and the timeline shows', (tester) async {
      await pump(tester, _live(lineups: lineups), lineups: false);
      expect(find.text('التشكيل'), findsNothing);
      expect(find.text('محمد صلاح'), findsOneWidget);
    });

    testWidgets('lineups with no events still show, with the tabs', (tester) async {
      await pump(tester, _live(events: const [], lineups: lineups));
      expect(find.text('التشكيل'), findsOneWidget);

      await tester.tap(find.text('التشكيل'));
      await tester.pumpAndSettle();
      expect(find.text('أليسون'), findsOneWidget);
    });

    testWidgets('the first event does not flip the panel under someone reading lineups',
        (tester) async {
      await pump(tester, _live(events: const [], lineups: lineups));
      expect(find.text('أليسون'), findsOneWidget);

      await pump(tester, _live(lineups: lineups));

      expect(find.text('أليسون'), findsOneWidget);
      expect(find.text('محمد صلاح'), findsNothing);
    });

    testWidgets('«الأحداث» with no events stays out of reach, never a blank panel',
        (tester) async {
      await pump(tester, _live(events: const [], lineups: lineups));

      await tester.tap(find.text('الأحداث'));
      await tester.pumpAndSettle();

      expect(find.text('أليسون'), findsOneWidget);
    });

    testWidgets('switching shows two lists for a side with no positions', (tester) async {
      await pump(tester, _live(lineups: lineups));

      await tester.tap(find.text('التشكيل'));
      await tester.pumpAndSettle();

      expect(find.text('محمد صلاح'), findsNothing);
      expect(find.text('الأساسيون'), findsOneWidget);
      expect(find.text('البدلاء'), findsOneWidget);
      expect(find.text('أليسون'), findsOneWidget);
      expect(find.text('إندو'), findsOneWidget);
      expect(find.text('4-3-3'), findsOneWidget);
    });
  });

  testWidgets('the pitch says who scored and who was sent off', (tester) async {
    final handle = tester.ensureSemantics();
    List<LineupPlayer> eleven(String goalkeeper, String forward) => [
          LineupPlayer(name: goalkeeper, isStarter: true, number: 1, position: 'حارس مرمى'),
          for (var i = 0; i < 9; i++)
            LineupPlayer(name: '$goalkeeper $i', isStarter: true, number: i, position: 'مدافع'),
          LineupPlayer(name: forward, isStarter: true, number: 9, position: 'مهاجم'),
        ];
    final match = _live().copyWith(
      lineups: MatchLineups(
        home: LineupSide(formation: '4-3-3', players: eleven('أليسون', 'محمد صلاح')),
        away: LineupSide(formation: null, players: eleven('سانشيز', 'مويسيس كايسيدو')),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: MadarTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: LineupsPitch(
              match: match,
              layout: layoutLineups(match.lineups)! as LineupPitch,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel(RegExp(r'محمد صلاح \(سجّل هدفاً\)')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'مويسيس كايسيدو \(بطاقة حمراء\)')), findsOneWidget);
    handle.dispose();
  });

  group('estimated', () {
    testWidgets('shows only the note, though the detail keeps its events', (tester) async {
      const live = LiveState(
        matchId: 48213,
        status: Status.live,
        estimated: true,
        minute: '12',
        period: null,
        score: Score(home: 1, away: 1, homePen: null, awayPen: null),
        statusLabel: null,
        statusUpdatedAt: null,
      );
      final shown = detailWithLiveState(_live(), live);
      expect(shown.events, isNotEmpty);

      await pump(tester, shown);

      expect(find.text('بدون نتيجة'), findsOneWidget);
      expect(find.byType(EventTimelineItem), findsNothing);
      expect(find.text('محمد صلاح'), findsNothing);
      expect(find.textContaining('′'), findsNothing);
    });
  });

  group('offline', () {
    testWidgets('a cached in-play match shows its events with their age, and nothing live',
        (tester) async {
      // No live state: the merge turns the cached in-play copy into a plain one.
      final shown = detailWithLiveState(_live(), null);

      await pump(tester, shown, age: const Duration(minutes: 12));

      expect(find.byType(StaleHint), findsOneWidget);
      expect(find.text('محمد صلاح'), findsOneWidget);
      // Chronological, and no running score from a score it can't vouch for.
      expect(
        tester.getTopLeft(find.text('محمد صلاح')).dy,
        lessThan(tester.getTopLeft(find.text('مويسيس كايسيدو')).dy),
      );
      expect(find.text('هدف'), findsOneWidget);
      expect(find.byType(ScoreParts), findsNothing);
    });
  });
}
