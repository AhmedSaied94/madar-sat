import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/bidi.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/button.dart';
import 'package:madar_sat/design/components/empty_state.dart';
import 'package:madar_sat/design/components/match_row.dart';
import 'package:madar_sat/design/components/skeleton.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/features/competition/presentation/competition_page.dart';
import 'package:madar_sat/features/live/live_poller.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/sample_details.dart';
import '../../fixtures/sample_match_detail.dart';
import '../../fixtures/sample_models.dart';
import '../../fixtures/semantics_actions.dart';

const int _competitionId = 12;
final String _competitionPath = '/v1/competitions/$_competitionId';

/// S8 (FR-016, FR-042, FR-046, SC-008): the competition header, the follow toggle, the
/// matches by local day on both tabs, the «حقوق البث» section and its shortcut. Requests go
/// through the real repository and drift, answered by path.
void main() {
  late AppDatabase db;
  late RoutedApi api;
  late GoRouter router;
  late List<LiveState> liveAnswer;

  setUp(() {
    api = RoutedApi();
    liveAnswer = [];
    db = AppDatabase(
      NativeDatabase.memory(),
      now: sampleNow,
      offsetAt: (_) => const Duration(hours: 3),
    );
  });

  tearDown(() => db.close());

  void answerCompetition(CompetitionDetail detail, {String? etag = '"v1"'}) =>
      api.answer(_competitionPath, competitionDetailJson(detail), etag: etag);

  Future<void> seed(CompetitionDetail detail, {required Duration age}) => db.putDocument(
        key: DocumentKeys.competition(_competitionId),
        etag: '"v1"',
        body: jsonEncode(competitionDetailJson(detail)),
        fetchedAt: sampleNow().subtract(age).toUtc(),
      );

  /// Two days of upcoming matches, one played match, and one rights holder on two satellites.
  CompetitionDetail standard({
    List<MatchSummary>? upcoming,
    List<RightsHolderRef> rightsHolders = const [
      RightsHolderRef(
        id: 3,
        name: 'Eleven Sports',
        logo: null,
        satellites: [sampleSatellite, badrSatellite],
        competitionCount: 9,
      ),
    ],
  }) =>
      sampleCompetitionDetail(
        upcoming: upcoming ??
            [
              sampleTeamMatch(id: 301, kickoff: sampleKickoffAt(hour: 20, minute: 30)),
              sampleTeamMatch(id: 302, kickoff: sampleKickoffAt(hour: 22, minute: 30)),
              sampleTeamMatch(id: 303, kickoff: DateTime(2026, 10, 29, 20).toUtc()),
            ],
        recent: [
          sampleTeamMatch(
            id: 300,
            kickoff: DateTime(2026, 10, 20, 20).toUtc(),
            status: Status.finished,
            score: const Score(home: 1, away: 1, homePen: null, awayPen: null),
          ),
        ],
        rightsHolders: rightsHolders,
      );

  Future<void> open(
    WidgetTester tester, {
    bool settle = true,
    double height = 1600,
    Brightness brightness = Brightness.dark,
    double textScale = 1,
    List<Override> overrides = const [],
  }) async {
    tester.view
      ..physicalSize = Size(360, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home-stub')),
        ),
        GoRoute(
          path: '/competition/:id',
          builder: (context, state) =>
              CompetitionPage(competitionId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) =>
              Scaffold(body: Text('match-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          swrRepositoryProvider.overrideWithValue(SwrRepository(dio: api.dio, database: db)),
          clockProvider.overrideWithValue(() => sampleNow()),
          liveFetcherProvider.overrideWithValue(() async => liveAnswer),
          ...overrides,
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: brightness == Brightness.dark ? MadarTheme.dark : MadarTheme.light,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/competition/$_competitionId'));
    if (settle) await tester.pumpAndSettle();
  }

  /// The page's own scroll offset, read from its controller: the match cards carry a
  /// non-scrolling `ListView` of their own, so `find.byType(Scrollable)` is ambiguous.
  double scrollOffset(WidgetTester tester) =>
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!.offset;

  group('the header', () {
    testWidgets('names the competition and offers the follow toggle', (tester) async {
      answerCompetition(standard());
      await open(tester);

      expect(find.text('الدوري المصري الممتاز'), findsWidgets);
      expect(find.text('تابع البطولة'), findsOneWidget);
    });

    testWidgets('a screen reader can reach follow and the rights shortcut (M-R1-1)',
        (tester) async {
      final handle = tester.ensureSemantics();
      answerCompetition(standard());
      await open(tester, height: 480);

      expect(semanticAction('تابع البطولة'), findsOne);
      expect(semanticAction('حقوق البث'), findsOne);

      tapSemanticAction(tester, 'تابع البطولة');
      await tester.pumpAndSettle();
      expect(find.text('تتابع البطولة'), findsOneWidget);

      tapSemanticAction(tester, 'حقوق البث');
      await tester.pumpAndSettle();
      expect(scrollOffset(tester), greaterThan(0));
      handle.dispose();
    });

    testWidgets('a followed competition opens as followed', (tester) async {
      await db.setFollow(kind: 'competition', targetId: _competitionId, on: true);
      answerCompetition(standard());
      await open(tester);

      expect(find.text('تتابع البطولة'), findsOneWidget);
    });

    testWidgets('the back arrow returns to the screen below', (tester) async {
      answerCompetition(standard());
      await open(tester);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.text('home-stub'), findsOneWidget);
      expect(find.byType(CompetitionPage), findsNothing);
    });
  });

  group('follow', () {
    testWidgets('the toggle writes the competition into drift', (tester) async {
      answerCompetition(standard());
      await open(tester);

      await tester.tap(find.text('تابع البطولة'));
      await tester.pumpAndSettle();

      expect(
        (await db.readFollows())
            .where((row) => row.kind == 'competition')
            .map((row) => row.targetId),
        [_competitionId],
      );
      expect(find.text('تتابع البطولة'), findsOneWidget);
    });
  });

  group('the tabs', () {
    testWidgets('«القادمة» groups the matches by local day, soonest first', (tester) async {
      answerCompetition(standard());
      await open(tester);

      expect(find.byType(MatchRow), findsNWidgets(3));
      expect(find.text('الأربعاء 28 أكتوبر'), findsOneWidget);
      expect(find.text('الخميس 29 أكتوبر'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('الأربعاء 28 أكتوبر')).dy,
        lessThan(tester.getTopLeft(find.text('الخميس 29 أكتوبر')).dy),
      );
    });

    testWidgets('«النتائج» swaps the list for the played matches', (tester) async {
      answerCompetition(standard());
      await open(tester);

      await tester.tap(find.text('النتائج'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchRow), findsOneWidget);
      expect(find.text('الثلاثاء 20 أكتوبر'), findsOneWidget);
    });

    testWidgets('a match with no kickoff says «لم يُحدد», never a guessed time', (tester) async {
      answerCompetition(
        standard(
          upcoming: [sampleTeamMatch(id: 304, kickoff: null, timeTbd: true)],
        ),
      );
      await open(tester);

      expect(find.text('لم يُحدد'), findsOneWidget);
    });

    testWidgets('an empty upcoming tab says so', (tester) async {
      answerCompetition(sampleCompetitionDetail(recent: standard().recent));
      await open(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('لا توجد مباريات قادمة'), findsOneWidget);
    });

    testWidgets('an empty results tab says so', (tester) async {
      answerCompetition(sampleCompetitionDetail(upcoming: standard().upcoming));
      await open(tester);

      await tester.tap(find.text('النتائج'));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد نتائج'), findsOneWidget);
    });
  });

  group('the rows', () {
    testWidgets('tapping one opens S3', (tester) async {
      answerCompetition(standard());
      await open(tester);

      await tester.tap(find.byType(MatchRow).first);
      await tester.pumpAndSettle();

      expect(find.text('match-301'), findsOneWidget);
    });

    testWidgets('an estimated match is drawn with no score at all', (tester) async {
      liveAnswer = [
        const LiveState(
          matchId: 301,
          status: Status.live,
          estimated: true,
          minute: '12',
          period: null,
          score: Score(home: 0, away: 0, homePen: null, awayPen: null),
          statusLabel: null,
          statusUpdatedAt: null,
        ),
      ];
      answerCompetition(
        standard(
          upcoming: [
            sampleTeamMatch(
              id: 301,
              kickoff: sampleKickoffAt(hour: 20, minute: 30),
              status: Status.live,
            ),
          ],
        ),
      );
      await open(tester);

      expect(find.text('مباشر'), findsOneWidget);
      expect(find.byType(ScoreParts), findsNothing);
      expect(find.text('12′'), findsNothing);
    });

    testWidgets('one merged Arabic label reads the row, its status and its channel', (tester) async {
      final handle = tester.ensureSemantics();
      answerCompetition(standard());
      await open(tester);

      expect(
        find.bySemanticsLabel('مودرن سبورت ضد الأهلي، 8:30 م، على ON Sport 1'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('حقوق البث', () {
    testWidgets('lists the holder with its satellites and its competition count', (tester) async {
      answerCompetition(standard());
      await open(tester);

      expect(find.text('حقوق البث'), findsWidgets, reason: 'the shortcut and the section');
      expect(find.text('جهة واحدة'), findsOneWidget);
      expect(find.text('Eleven Sports'), findsOneWidget);
      expect(find.text('نايل سات، بدر · 9 بطولات'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Eleven Sports'))),
        TextDirection.ltr,
        reason: 'a Latin name is an LTR island',
      );
    });

    testWidgets('a row has no chevron and opens nothing: S11 arrives on D7', (tester) async {
      answerCompetition(standard());
      await open(tester);

      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.tap(find.text('Eleven Sports'));
      await tester.pumpAndSettle();

      expect(find.byType(CompetitionPage), findsOneWidget);
    });

    testWidgets('the shortcut scrolls down to the section', (tester) async {
      answerCompetition(standard());
      await open(tester, height: 480);
      expect(scrollOffset(tester), 0);

      await tester.tap(find.widgetWithText(MadarButton, 'حقوق البث'));
      await tester.pumpAndSettle();

      expect(scrollOffset(tester), greaterThan(0));
      expect(find.text('Eleven Sports'), findsOneWidget);
    });

    testWidgets('a competition with no rights holders draws neither the section nor the shortcut',
        (tester) async {
      answerCompetition(standard(rightsHolders: const []));
      await open(tester);

      expect(find.text('حقوق البث'), findsNothing);
      expect(find.text('جهة واحدة'), findsNothing);
    });
  });

  group('freshness, offline and failure', () {
    testWidgets('shows a skeleton until the first answer', (tester) async {
      final gate = Completer<void>();
      api.respond(_competitionPath, (_) async {
        await gate.future;
        return FakeHttpAdapter.envelope(competitionDetailJson(standard()), etag: '"v1"');
      });
      await open(tester, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.byType(Skeleton), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.byType(MatchRow), findsWidgets);
    });

    testWidgets('a copy older than its five minutes shows its age', (tester) async {
      await seed(standard(), age: const Duration(minutes: 10));
      api.offline(_competitionPath);
      await open(tester);

      expect(find.byType(StaleHint), findsOneWidget);
      expect(find.text('آخر تحديث منذ 10 د'), findsOneWidget);
    });

    testWidgets('a 304 confirms the copy, so its age goes away', (tester) async {
      await seed(standard(), age: const Duration(hours: 2));
      api.notModified(_competitionPath);
      await open(tester);

      expect(find.byType(StaleHint), findsNothing);
    });

    testWidgets('offline with a copy keeps the page', (tester) async {
      await seed(standard(), age: const Duration(minutes: 30));
      api.offline(_competitionPath);
      await open(tester);

      expect(find.byType(MatchRow), findsWidgets);
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('offline with no copy says there is no connection, and the retry reads again',
        (tester) async {
      api.offline(_competitionPath);
      answerCompetition(standard());
      await open(tester);

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchRow), findsWidgets);
      expect(api.requestsTo(_competitionPath), hasLength(2));
    });

    testWidgets('an API error is shown as Arabic copy for its code', (tester) async {
      api.failWith(_competitionPath, 'not_found');
      await open(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
    });
  });

  group('both themes at 1.3×', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('the ${brightness.name} theme draws the page without an overflow',
          (tester) async {
        answerCompetition(standard());
        await open(tester, brightness: brightness, textScale: 1.3);

        expect(tester.takeException(), isNull);
        expect(find.byType(MatchRow), findsWidgets);
        expect(find.text('Eleven Sports'), findsOneWidget);
      });
    }
  });

  testWidgets('every number is a Western digit', (tester) async {
    answerCompetition(standard());
    await open(tester);

    final text = StringBuffer();
    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      text.write(widget.data ?? widget.textSpan?.toPlainText() ?? '');
      text.write(' ');
    }
    expect(RegExp('[٠-٩۰-۹]').hasMatch(text.toString()), isFalse);
    expect(RegExp('[0-9]').hasMatch(text.toString()), isTrue);
  });
}
