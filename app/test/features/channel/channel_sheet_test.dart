import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/core/platform/share_service.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/empty_state.dart';
import 'package:madar_sat/design/components/frequency_readout.dart';
import 'package:madar_sat/design/components/skeleton.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/features/channel/presentation/channel_sections.dart';
import 'package:madar_sat/features/channel/presentation/channel_sheet.dart';
import 'package:madar_sat/features/live/live_poller.dart';
import 'package:madar_sat/features/my_satellites/data/my_satellites_provider.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/fake_share.dart';
import '../../fixtures/sample_details.dart';
import '../../fixtures/sample_match_detail.dart';
import '../../fixtures/sample_models.dart';
import '../../fixtures/semantics_actions.dart';
const int _channelId = 5512;
final String _channelPath = '/v1/channels/$_channelId';

/// S6 (FR-016, FR-046, SC-008): the channel sheet over its scrim, the carriage card with the
/// readout visible without a tap, the follow toggle, the other carriages, the upcoming
/// matches and the frequency history. Requests go through the real repository and drift,
/// answered by path; no network and no share sheet.
void main() {
  late AppDatabase db;
  late RoutedApi api;
  late FakeShareService share;
  late GoRouter router;
  late List<LiveState> liveAnswer;

  setUp(() {
    api = RoutedApi();
    share = FakeShareService();
    liveAnswer = [];
    db = AppDatabase(
      NativeDatabase.memory(),
      now: sampleNow,
      offsetAt: (_) => const Duration(hours: 3),
    );
  });

  tearDown(() => db.close());

  void answerChannel(ChannelDetail detail, {String? etag = '"v1"'}) =>
      api.answer(_channelPath, channelDetailJson(detail), etag: etag);

  Future<void> seed(ChannelDetail detail, {required Duration age}) => db.putDocument(
        key: DocumentKeys.channel(_channelId),
        etag: '"v1"',
        body: jsonEncode(channelDetailJson(detail)),
        fetchedAt: sampleNow().subtract(age).toUtc(),
      );

  /// beIN SPORTS 1 on Nilesat, one carriage on Badr, and two upcoming matches.
  ChannelDetail standard({List<MatchSummary> upcoming = const []}) => sampleChannelDetail(
        otherCarriages: [
          sampleOtherCarriage(id: 2, name: 'beIN SPORTS 1 · Badr', satellite: badrSatellite),
          sampleOtherCarriage(
            id: 3,
            name: 'beIN Free · Hotbird',
            satellite: hotbirdSatellite,
            access: Access.free,
          ),
        ],
        upcomingMatches: upcoming.isEmpty
            ? [
                sampleTeamMatch(id: 101, kickoff: sampleKickoffAt(hour: 16)),
                sampleTeamMatch(id: 102, kickoff: DateTime(2026, 10, 29, 17).toUtc()),
              ]
            : upcoming,
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
          path: '/channel/:id',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: ChannelSheetPage(channelId: int.parse(state.pathParameters['id']!)),
          ),
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
          shareServiceProvider.overrideWithValue(share),
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
    unawaited(router.push('/channel/$_channelId'));
    if (settle) await tester.pumpAndSettle();
  }

  group('the sheet', () {
    testWidgets('shows the header: name, category and country', (tester) async {
      answerChannel(standard());
      await open(tester);

      expect(find.text('beIN SPORTS 1'), findsOneWidget);
      expect(find.text('رياضة'), findsOneWidget);
      expect(find.text('قطر'), findsOneWidget);
    });

    testWidgets('the readout is visible with no tap, dark and LTR', (tester) async {
      answerChannel(standard());
      await open(tester);

      final readout = tester.widget<FrequencyReadout>(find.byType(FrequencyReadout).first);
      expect(readout.mhz, 11013);
      expect(
        Directionality.of(tester.element(find.byType(FrequencyReadout).first)),
        TextDirection.rtl,
        reason: 'the component keeps its own LTR well inside an RTL screen',
      );
      expect(find.text('11013'), findsOneWidget);
    });

    testWidgets('copy puts the tuning on the clipboard and says so', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      answerChannel(standard());
      await open(tester);

      await tester.tap(find.text('نسخ'));
      await tester.pump();

      expect(copied, '11013 H 27500');
      expect(find.text('تم نسخ التردد'), findsOneWidget);
    });

    testWidgets('the share action shares the channel', (tester) async {
      answerChannel(standard());
      await open(tester);

      await tester.tap(find.byTooltip('مشاركة القناة'));
      await tester.pump();

      expect(share.shared.single, contains('beIN SPORTS 1'));
    });

    testWidgets('a screen reader can reach share, outside the header label (M-R1-1)',
        (tester) async {
      final handle = tester.ensureSemantics();
      answerChannel(standard());
      await open(tester);

      expect(semanticAction('مشاركة القناة'), findsOne);

      tapSemanticAction(tester, 'مشاركة القناة');
      await tester.pump();

      expect(share.shared.single, contains('beIN SPORTS 1'));
      handle.dispose();
    });

    testWidgets('the satellite row marks a satellite of mine', (tester) async {
      answerChannel(standard());
      await open(tester, overrides: [chosenSatelliteIdsProvider.overrideWithValue({2, 5})]);

      expect(find.text('طبقي'), findsOneWidget);
    });
  });

  group('follow', () {
    testWidgets('the toggle writes the channel into drift and says so', (tester) async {
      answerChannel(standard());
      await open(tester);

      expect(find.text('تابع القناة'), findsOneWidget);
      await tester.tap(find.text('تابع القناة'));
      await tester.pumpAndSettle();

      expect(
        (await db.readFollows()).where((row) => row.kind == 'channel').map((row) => row.targetId),
        [_channelId],
      );
      expect(find.text('تتابع القناة'), findsOneWidget);
    });

    testWidgets('a followed channel opens as followed', (tester) async {
      await db.setFollow(kind: 'channel', targetId: _channelId, on: true);
      answerChannel(standard());
      await open(tester);

      expect(find.text('تتابع القناة'), findsOneWidget);
    });
  });

  group('other carriages', () {
    testWidgets('mine first, then the free one', (tester) async {
      answerChannel(standard());
      await open(tester, overrides: [chosenSatelliteIdsProvider.overrideWithValue({5})]);

      expect(find.text('على أقمار أخرى'), findsOneWidget);
      // The rows name the satellite the channel is also carried on, as the board draws them.
      expect(
        tester.getTopLeft(find.text('بدر')).dy,
        lessThan(tester.getTopLeft(find.text('هوت بيرد')).dy),
      );
    });

    testWidgets('the part is absent when a channel airs on one satellite only', (tester) async {
      answerChannel(sampleChannelDetail());
      await open(tester);

      expect(find.text('على أقمار أخرى'), findsNothing);
    });
  });

  group('upcoming matches', () {
    testWidgets('one row per match, with its day, time, teams and competition', (tester) async {
      answerChannel(standard());
      await open(tester);

      expect(find.text('المباريات القادمة على القناة'), findsOneWidget);
      expect(find.text('مودرن سبورت × الأهلي'), findsNWidgets(2));
      // 16:00 and 17:00 on the device's own clock, as the fixtures build them.
      expect(find.text('4:00 م'), findsOneWidget);
      expect(find.text('5:00 م'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('الخميس 29'), findsOneWidget);
    });

    testWidgets('tapping a match opens S3', (tester) async {
      answerChannel(standard());
      await open(tester);

      await tester.tap(find.text('مودرن سبورت × الأهلي').first);
      await tester.pumpAndSettle();

      expect(find.text('match-101'), findsOneWidget);
    });

    testWidgets('none upcoming says so under the heading', (tester) async {
      answerChannel(sampleChannelDetail());
      await open(tester);

      expect(find.text('المباريات القادمة على القناة'), findsOneWidget);
      expect(find.text('لا توجد مباريات قادمة'), findsOneWidget);
    });

    testWidgets('a live state updates the row, never the cached copy', (tester) async {
      liveAnswer = [
        const LiveState(
          matchId: 101,
          status: Status.live,
          estimated: false,
          minute: '67',
          period: Period.value2h,
          score: Score(home: 1, away: 0, homePen: null, awayPen: null),
          statusLabel: null,
          statusUpdatedAt: null,
        ),
      ];
      answerChannel(
        standard(
          upcoming: [
            sampleTeamMatch(
              id: 101,
              kickoff: sampleKickoffAt(hour: 16),
              status: Status.live,
            ),
            sampleTeamMatch(id: 102, kickoff: DateTime(2026, 10, 29, 17).toUtc()),
          ],
        ),
      );
      await open(tester);

      // The minute pill is the live proof: without the state the row shows its kickoff.
      expect(find.text('67′'), findsOneWidget);
      expect(find.text('4:00 م'), findsNothing);
    });
  });

  group('frequency history', () {
    testWidgets('is hidden while the contract sends no changes', (tester) async {
      answerChannel(standard());
      await open(tester);

      expect(find.text('سجل التردد'), findsNothing);
    });

    testWidgets('lists at most three changes, newest first', (tester) async {
      answerChannel(
        sampleChannelDetail(
          recentFrequencyChanges: [
            sampleFrequencyChange(detectedAt: '2026-10-20T09:12:00Z', from: 11766, to: 11013),
            sampleFrequencyChange(detectedAt: '2026-09-02T09:00:00Z', from: 11861, to: 11766),
            sampleFrequencyChange(detectedAt: '2026-08-01T09:00:00Z', from: 11820, to: 11861),
            sampleFrequencyChange(detectedAt: '2026-07-01T09:00:00Z', from: 11900, to: 11820),
          ],
        ),
      );
      await open(tester);

      final history = find.byType(FrequencyHistorySection);
      expect(find.text('سجل التردد'), findsOneWidget);
      expect(find.descendant(of: history, matching: find.text('20 أكتوبر')), findsOneWidget);
      expect(find.descendant(of: history, matching: find.text('2 سبتمبر')), findsOneWidget);
      expect(find.descendant(of: history, matching: find.text('1 أغسطس')), findsOneWidget);
      expect(find.text('1 يوليو'), findsNothing, reason: 'the last three only');
      // The newest change reads old → new; in RTL the old tuning sits on the right.
      expect(
        tester.getTopLeft(find.descendant(of: history, matching: find.text('11766')).first).dx,
        greaterThan(tester.getTopLeft(find.descendant(of: history, matching: find.text('11013'))).dx),
      );
    });
  });

  group('freshness, offline and failure', () {
    testWidgets('shows a skeleton until the first answer', (tester) async {
      final gate = Completer<void>();
      api.respond(_channelPath, (_) async {
        await gate.future;
        return FakeHttpAdapter.envelope(channelDetailJson(standard()), etag: '"v1"');
      });
      await open(tester, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.byType(Skeleton), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('beIN SPORTS 1'), findsOneWidget);
    });

    testWidgets('a copy older than a day shows its age', (tester) async {
      await seed(standard(), age: const Duration(days: 2));
      api.offline(_channelPath);
      await open(tester);

      expect(find.byType(StaleHint), findsOneWidget);
      expect(find.text('آخر تحديث منذ 2 يوم'), findsOneWidget);
    });

    testWidgets('a 304 confirms the copy, so its age goes away', (tester) async {
      await seed(standard(), age: const Duration(days: 2));
      api.notModified(_channelPath);
      await open(tester);

      expect(find.byType(StaleHint), findsNothing);
      expect(api.requestsTo(_channelPath).single.headers['If-None-Match'], '"v1"');
    });

    testWidgets('offline with a copy keeps the sheet', (tester) async {
      await seed(standard(), age: const Duration(days: 3));
      api.offline(_channelPath);
      await open(tester);

      expect(find.text('beIN SPORTS 1'), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('offline with no copy says there is no connection, and the retry reads again',
        (tester) async {
      api.offline(_channelPath);
      answerChannel(standard());
      await open(tester);

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.text('beIN SPORTS 1'), findsOneWidget);
      expect(api.requestsTo(_channelPath), hasLength(2));
    });

    testWidgets('an API error is shown as Arabic copy for its code', (tester) async {
      api.failWith(_channelPath, 'not_found');
      await open(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
      expect(find.textContaining('for logs only'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('the deep link opens the sheet, and back closes it', (tester) async {
      answerChannel(standard());
      await open(tester);

      expect(find.byType(ChannelSheetPage), findsOneWidget);
      expect(find.text('home-stub'), findsNothing, reason: 'the scrim covers the screen below');

      await tester.tapAt(const Offset(180, 8));
      await tester.pumpAndSettle();

      expect(find.byType(ChannelSheetPage), findsNothing);
      expect(find.text('home-stub'), findsOneWidget);
    });
  });

  group('both themes at 1.3×', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('the ${brightness.name} theme draws the sheet without an overflow',
          (tester) async {
        answerChannel(
          sampleChannelDetail(
            otherCarriages: [sampleOtherCarriage(id: 2, name: 'beIN on Badr')],
            recentFrequencyChanges: [
              sampleFrequencyChange(detectedAt: '2026-10-20T09:12:00Z', from: 11766, to: 11013),
            ],
          ),
        );
        await open(tester, brightness: brightness, textScale: 1.3);

        expect(tester.takeException(), isNull);
        expect(find.text('beIN SPORTS 1'), findsOneWidget);
      });
    }
  });

  testWidgets('every number is a Western digit', (tester) async {
    answerChannel(standard());
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
