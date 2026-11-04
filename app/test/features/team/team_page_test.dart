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
import 'package:madar_sat/design/components/empty_state.dart';
import 'package:madar_sat/design/components/logo.dart';
import 'package:madar_sat/design/components/match_row.dart';
import 'package:madar_sat/design/components/skeleton.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/features/live/live_poller.dart';
import 'package:madar_sat/features/team/presentation/team_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/sample_details.dart';
import '../../fixtures/sample_match_detail.dart';
import '../../fixtures/sample_models.dart';

const int _teamId = 1;
final String _teamPath = '/v1/teams/$_teamId';

/// S7 (FR-016, FR-042, FR-046, SC-008): the team header, the follow toggle, the two tabs with
/// their local-day groups, the empty copies, and the live merge. Requests go through the real
/// repository and drift, answered by path.
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

  void answerTeam(TeamDetail detail, {String? etag = '"v1"'}) =>
      api.answer(_teamPath, teamDetailJson(detail), etag: etag);

  Future<void> seed(TeamDetail detail, {required Duration age}) => db.putDocument(
        key: DocumentKeys.team(_teamId),
        etag: '"v1"',
        body: jsonEncode(teamDetailJson(detail)),
        fetchedAt: sampleNow().subtract(age).toUtc(),
      );

  /// Two days of upcoming matches, and one played match.
  TeamDetail standard() => sampleTeamDetail(
        upcoming: [
          sampleTeamMatch(id: 201, kickoff: DateTime.utc(2026, 10, 29, 16)),
          sampleTeamMatch(id: 202, kickoff: DateTime.utc(2026, 10, 29, 19)),
          sampleTeamMatch(id: 203, kickoff: DateTime.utc(2026, 10, 30, 16)),
        ],
        recent: [
          sampleTeamMatch(
            id: 200,
            kickoff: DateTime.utc(2026, 10, 20, 17),
            status: Status.finished,
            score: const Score(home: 2, away: 0, homePen: null, awayPen: null),
          ),
        ],
      );

  Future<void> open(
    WidgetTester tester, {
    bool settle = true,
    double height = 1400,
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
          path: '/team/:id',
          builder: (context, state) => TeamPage(teamId: int.parse(state.pathParameters['id']!)),
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
    unawaited(router.push('/team/$_teamId'));
    if (settle) await tester.pumpAndSettle();
  }

  group('the header', () {
    testWidgets('name, crest, main competition and stadium', (tester) async {
      answerTeam(standard());
      await open(tester);

      expect(find.text('الأهلي'), findsWidgets);
      expect(find.byType(TeamCrest), findsWidgets);
      expect(find.text('الدوري المصري الممتاز'), findsOneWidget);
      expect(find.text('استاد القاهرة الدولي'), findsOneWidget);
    });

    testWidgets('a team with no stadium or competition draws neither line', (tester) async {
      answerTeam(
        sampleTeamDetail(stadium: null, primaryCompetition: null),
      );
      await open(tester);

      expect(find.text('استاد القاهرة الدولي'), findsNothing);
      expect(find.text('الدوري المصري الممتاز'), findsNothing);
    });

    testWidgets('the back arrow returns to the screen below', (tester) async {
      answerTeam(standard());
      await open(tester);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.text('home-stub'), findsOneWidget);
      expect(find.byType(TeamPage), findsNothing);
    });
  });

  group('follow', () {
    testWidgets('the toggle writes the team into drift and flips its label', (tester) async {
      answerTeam(standard());
      await open(tester);

      expect(find.text('تابع الفريق'), findsOneWidget);
      await tester.tap(find.text('تابع الفريق'));
      await tester.pumpAndSettle();

      expect(
        (await db.readFollows()).where((row) => row.kind == 'team').map((row) => row.targetId),
        [_teamId],
      );
      expect(find.text('تتابع الفريق'), findsOneWidget);
    });

    testWidgets('a followed team opens as followed', (tester) async {
      await db.setFollow(kind: 'team', targetId: _teamId, on: true);
      answerTeam(standard());
      await open(tester);

      expect(find.text('تتابع الفريق'), findsOneWidget);
    });
  });

  group('the tabs', () {
    testWidgets('«القادمة» is selected and lists the upcoming matches by day', (tester) async {
      answerTeam(standard());
      await open(tester);

      expect(find.text('القادمة'), findsOneWidget);
      expect(find.text('النتائج'), findsOneWidget);
      expect(find.byType(MatchRow), findsNWidgets(3));
      // The 29th first, then the 30th.
      expect(find.text('الخميس 29 أكتوبر'), findsOneWidget);
      expect(find.text('الجمعة 30 أكتوبر'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('الخميس 29 أكتوبر')).dy,
        lessThan(tester.getTopLeft(find.text('الجمعة 30 أكتوبر')).dy),
      );
      expect(find.text('تظهر المباريات التالية فور إعلان الجدول'), findsOneWidget);
    });

    testWidgets('«النتائج» swaps the list for the played matches', (tester) async {
      answerTeam(standard());
      await open(tester);

      await tester.tap(find.text('النتائج'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchRow), findsOneWidget);
      expect(find.text('الثلاثاء 20 أكتوبر'), findsOneWidget);
      expect(find.text('تظهر المباريات التالية فور إعلان الجدول'), findsNothing);
    });

    testWidgets('an upcoming tab with nothing says so', (tester) async {
      answerTeam(sampleTeamDetail(recent: standard().recent));
      await open(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('لا توجد مباريات قادمة'), findsOneWidget);
      expect(find.byType(MatchRow), findsNothing);
    });

    testWidgets('a results tab with nothing says so', (tester) async {
      answerTeam(sampleTeamDetail(upcoming: standard().upcoming));
      await open(tester);

      await tester.tap(find.text('النتائج'));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد نتائج'), findsOneWidget);
    });
  });

  group('the rows', () {
    testWidgets('tapping one opens S3, never S7', (tester) async {
      answerTeam(standard());
      await open(tester);

      await tester.tap(find.byType(MatchRow).first);
      await tester.pumpAndSettle();

      expect(find.text('match-201'), findsOneWidget);
    });

    testWidgets('a live state gives the row the score and the minute', (tester) async {
      liveAnswer = [
        const LiveState(
          matchId: 201,
          status: Status.live,
          estimated: false,
          minute: '67',
          period: Period.value2h,
          score: Score(home: 1, away: 0, homePen: null, awayPen: null),
          statusLabel: null,
          statusUpdatedAt: null,
        ),
      ];
      answerTeam(
        sampleTeamDetail(
          upcoming: [
            sampleTeamMatch(
              id: 201,
              kickoff: DateTime.utc(2026, 10, 29, 16),
              status: Status.live,
            ),
          ],
          recent: standard().recent,
        ),
      );
      await open(tester);

      expect(find.text('67′'), findsOneWidget);
    });

    testWidgets('an estimated match is drawn with no score at all', (tester) async {
      liveAnswer = [
        const LiveState(
          matchId: 201,
          status: Status.live,
          estimated: true,
          minute: '12',
          period: null,
          score: Score(home: 0, away: 0, homePen: null, awayPen: null),
          statusLabel: null,
          statusUpdatedAt: null,
        ),
      ];
      answerTeam(
        sampleTeamDetail(
          upcoming: [
            sampleTeamMatch(
              id: 201,
              kickoff: DateTime.utc(2026, 10, 29, 16),
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
      answerTeam(standard());
      await open(tester);

      expect(
        find.bySemanticsLabel('مودرن سبورت ضد الأهلي، 7:00 م، على ON Sport 1'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('freshness, offline and failure', () {
    testWidgets('shows a skeleton until the first answer', (tester) async {
      final gate = Completer<void>();
      api.respond(_teamPath, (_) async {
        await gate.future;
        return FakeHttpAdapter.envelope(teamDetailJson(standard()), etag: '"v1"');
      });
      await open(tester, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.byType(Skeleton), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('الدوري المصري الممتاز'), findsOneWidget);
    });

    testWidgets('a copy older than its five minutes shows its age', (tester) async {
      await seed(standard(), age: const Duration(minutes: 10));
      api.offline(_teamPath);
      await open(tester);

      expect(find.byType(StaleHint), findsOneWidget);
      expect(find.text('آخر تحديث منذ 10 د'), findsOneWidget);
    });

    testWidgets('offline with a copy keeps the page', (tester) async {
      await seed(standard(), age: const Duration(minutes: 30));
      api.offline(_teamPath);
      await open(tester);

      expect(find.byType(MatchRow), findsWidgets);
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('offline with no copy says there is no connection, and the retry reads again',
        (tester) async {
      api.offline(_teamPath);
      answerTeam(standard());
      await open(tester);

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchRow), findsWidgets);
      expect(api.requestsTo(_teamPath), hasLength(2));
    });

    testWidgets('an API error is shown as Arabic copy for its code', (tester) async {
      api.failWith(_teamPath, 'not_found');
      await open(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
    });
  });

  group('both themes at 1.3×', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('the ${brightness.name} theme draws the page without an overflow',
          (tester) async {
        answerTeam(standard());
        await open(tester, brightness: brightness, textScale: 1.3);

        expect(tester.takeException(), isNull);
        expect(find.byType(MatchRow), findsWidgets);
      });
    }
  });

  testWidgets('every number is a Western digit', (tester) async {
    answerTeam(standard());
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
