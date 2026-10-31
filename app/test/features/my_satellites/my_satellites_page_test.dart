import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' show ResponseBody;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/bottom_nav.dart';
import 'package:madar_sat/design/components/empty_state.dart';
import 'package:madar_sat/design/components/frequency_readout.dart';
import 'package:madar_sat/design/components/match_row.dart';
import 'package:madar_sat/design/components/skeleton.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/features/live/live_poller.dart';
import 'package:madar_sat/features/my_satellites/presentation/my_satellites_page.dart';
import 'package:madar_sat/features/my_satellites/presentation/satellite_chips.dart';
import 'package:madar_sat/features/my_satellites/presentation/satellite_match_row.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/sample_models.dart';
import '../../fixtures/sample_satellites.dart';

/// S4 «أقماري» (FR-043, FR-044, FR-046): the day's matches carried on my satellites, asked
/// of the server for exactly those satellites and kept apart from S2's day.
///
/// The device is on a fixed +03 zone (the database's `offsetAt`) and its clock says
/// 2026-10-28 18:00, so no assertion reads the host zone.

final _day = DateTime(2026, 10, 28);

final _onMax = headlineEntry(
  channelId: 11,
  name: 'ON Sport Max HD',
  mhz: 11977,
  pol: Polarization.v,
  access: Access.free,
);
final _onSport = headlineEntry(
  channelId: 12,
  name: 'ON Sport HD',
  mhz: 11977,
  pol: Polarization.v,
  access: Access.free,
);
final _bein = headlineEntry(channelId: 13, name: 'beIN SPORTS 1', mhz: 11013);
final _alKass = headlineEntry(
  channelId: 14,
  name: 'Al Kass Five HD',
  satellite: badrRef,
  mhz: 10770,
);
final _varzesh = headlineEntry(
  channelId: 15,
  name: 'Varzesh TV HD',
  satellite: badrRef,
  mhz: 11881,
  access: Access.free,
);

/// Four matches in three competitions, deliberately not in display order.
final List<MatchSummary> _matches = [
  satelliteMatch(
    id: 1,
    status: Status.finished,
    hour: 15,
    home: 'الأهلي',
    away: 'الزمالك',
    score: const Score(home: 2, away: 1, homePen: null, awayPen: null),
    headline: [_onMax],
  ),
  satelliteMatch(
    id: 2,
    hour: 20,
    home: 'المصري',
    away: 'المقاولون العرب',
    headline: [_onSport],
  ),
  satelliteMatch(
    id: 3,
    competitionId: 30,
    competition: 'دوري أبطال آسيا 2',
    priority: 1,
    stage: 'الجولة 3 - الذهاب',
    hour: 19,
    home: 'النهضة',
    away: 'الريان',
    headline: [_bein, _alKass],
  ),
  satelliteMatch(
    id: 4,
    competitionId: 40,
    competition: 'الدوري الإيطالي',
    priority: null,
    stage: 'الجولة 9',
    hour: 21,
    home: 'ميلان',
    away: 'بولونيا',
    headline: [_varzesh],
  ),
];

class _Env {
  _Env() {
    database = AppDatabase(
      NativeDatabase.memory(),
      now: () => clock,
      offsetAt: (_) => const Duration(hours: 3),
    );
    adapter = FakeHttpAdapter();
    http = RoutedHttp(adapter);
    repository = SwrRepository(dio: fakeDio(adapter), database: database);
  }

  DateTime clock = sampleNow();
  late final AppDatabase database;
  late final FakeHttpAdapter adapter;
  late final RoutedHttp http;
  late final SwrRepository repository;
  List<LiveState> live = const [];

  /// The server: the satellites, and the day for whichever satellites were asked.
  void serve({List<MatchSummary>? matches, List<Satellite>? satellites}) {
    http.data('/v1/satellites', satellitesWire(satellites ?? sampleSatellites()), etag: '"sat1"');
    http.on('/v1/matches', (options) {
      final rows = matches ?? _matches;
      return FakeHttpAdapter.envelope(matchesWire(rows), etag: '"m-${options.queryParameters['satellite_ids']}"');
    });
  }

  String get matchesKey => DocumentKeys.matchesBySatellites(_day, {2, 5});

  Future<void> seedSatellites({Duration age = Duration.zero}) => database.putDocument(
        key: DocumentKeys.satellites,
        etag: '"sat1"',
        body: jsonEncode(satellitesWire(sampleSatellites())),
        fetchedAt: clock.subtract(age).toUtc(),
      );

  Future<void> seedMatches({Duration age = Duration.zero, String etag = '"m1"'}) =>
      database.putDocument(
        key: matchesKey,
        etag: etag,
        body: jsonEncode(matchesWire(_matches)),
        fetchedAt: clock.subtract(age).toUtc(),
      );
}

Future<void> _pump(WidgetTester tester, _Env env) async {
  tester.view
    ..physicalSize = const Size(1080, 4800)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  addTearDown(env.database.close);

  Widget stub(String text) => Scaffold(body: Center(child: Text(text)));
  final router = GoRouter(
    initialLocation: '/my-satellites',
    routes: [
      GoRoute(path: '/', builder: (_, _) => stub('home')),
      GoRoute(path: '/my-satellites', builder: (_, _) => const MySatellitesPage()),
      GoRoute(path: '/satellites', builder: (_, _) => stub('frequencies')),
      GoRoute(path: '/favorites', builder: (_, _) => stub('favorites')),
      GoRoute(path: '/settings', builder: (_, _) => stub('settings')),
      GoRoute(path: '/search', builder: (_, _) => stub('search')),
      GoRoute(
        path: '/match/:id',
        builder: (_, state) => stub('match ${state.pathParameters['id']}'),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        swrRepositoryProvider.overrideWithValue(env.repository),
        appDatabaseProvider.overrideWithValue(env.database),
        clockProvider.overrideWithValue(() => env.clock),
        liveFetcherProvider.overrideWithValue(() async => env.live),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: MadarTheme.dark,
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _chip(int satelliteId) =>
    find.byWidgetPredicate((widget) => widget is SatelliteChip && widget.satellite.id == satelliteId);

bool _selected(WidgetTester tester, int satelliteId) =>
    tester.widget<SatelliteChip>(_chip(satelliteId)).selected;

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

String _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .join(' ');

void main() {
  group('the satellite chips', () {
    testWidgets('are my satellites, all on, and never another satellite', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      expect(find.byType(SatelliteChip), findsNWidgets(2));
      expect(_chip(2), findsOneWidget);
      expect(_chip(5), findsOneWidget);
      expect(_chip(7), findsNothing, reason: 'Hotbird is not one of my satellites');
      expect(_selected(tester, 2), isTrue);
      expect(_selected(tester, 5), isTrue);
      expect(find.text('الكل'), findsOneWidget);
    });

    testWidgets('a chip toggles its satellite and asks the server for the others', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      await tester.tap(_chip(5));
      await tester.pumpAndSettle();

      expect(_selected(tester, 5), isFalse);
      expect(_selected(tester, 2), isTrue);
      final asked = env.http.requestsTo('/v1/matches').map((r) => r.queryParameters['satellite_ids']);
      expect(asked, ['2,5', '2']);
    });

    testWidgets('«الكل» selects every one of my satellites again', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);
      await tester.tap(_chip(5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('الكل'));
      await tester.pumpAndSettle();

      expect(_selected(tester, 5), isTrue);
      expect(env.http.requestsTo('/v1/matches').last.queryParameters['satellite_ids'], '2,5');
    });
  });

  group('the request (T130)', () {
    testWidgets('carries the selected ids sorted and the local day as UTC bounds', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      final request = env.http.requestsTo('/v1/matches').single;
      expect(request.queryParameters['satellite_ids'], '2,5');
      // 00:00 +03 on Oct 28 to 00:00 +03 on Oct 29.
      expect(request.queryParameters['from'], '2026-10-27T21:00:00.000Z');
      expect(request.queryParameters['to'], '2026-10-28T21:00:00.000Z');
      expect(request.queryParameters.containsKey('my_satellite_ids'), isFalse);
    });

    testWidgets('is stored as its own document and leaves S2 alone', (tester) async {
      final env = _Env()..serve();
      // S2 already holds the full day, with a match that is on Hotbird only.
      await env.database.replaceDay(
        _day,
        [sampleMatch(id: 99, kickoff: sampleKickoffAt(hour: 20), home: 'ليفربول', away: 'تشيلسي')],
        etag: '"s2"',
        fetchedAt: env.clock.toUtc(),
      );
      await _pump(tester, env);

      expect(find.text('ليفربول'), findsNothing, reason: 'S4 never filters or shows S2 rows');
      expect(find.byType(MatchRow), findsNWidgets(4));

      final stored = await env.database.documentFor(env.matchesKey);
      expect(stored, isNotNull);
      expect(stored!.etag, '"m-2,5"');
      expect((await env.database.readAll()).map((m) => m.id), [99]);
      expect((await env.database.windowFor('2026-10-28'))!.etag, '"s2"');
    });
  });

  group('the list (FR-044)', () {
    testWidgets('groups by competition: priority first, finished matches last in a group',
        (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      expect(_top(tester, 'دوري أبطال آسيا 2'), lessThan(_top(tester, 'الدوري المصري الممتاز')));
      expect(_top(tester, 'الدوري المصري الممتاز'), lessThan(_top(tester, 'الدوري الإيطالي')));
      // The Egyptian league: the scheduled match above the finished one that kicked off earlier.
      expect(_top(tester, 'المصري'), lessThan(_top(tester, 'الأهلي')));
      expect(find.text('الجولة 3 - الذهاب'), findsOneWidget);
    });

    testWidgets('each row lists its carriages with satellite, access and readout', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      expect(find.byType(SatelliteMatchRow), findsNWidgets(4));
      expect(find.byType(FrequencyReadout), findsNWidgets(5));
      expect(find.text('beIN SPORTS 1'), findsOneWidget);
      expect(find.text('Al Kass Five HD'), findsOneWidget);
      expect(find.text('11013'), findsOneWidget);
      expect(find.text('10770'), findsOneWidget);
      // The carriage is on the satellite it was asked on.
      expect(find.text('بدر'), findsWidgets);
      expect(find.text('نايل سات'), findsWidgets);
    });

    testWidgets('a row opens the match', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      await tester.tap(find.text('النهضة'));
      await tester.pumpAndSettle();

      expect(find.text('match 3'), findsOneWidget);
    });

    testWidgets('a row reads as one merged screen-reader node', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);
      final handle = tester.ensureSemantics();
      await tester.pump();

      // The merged node's own label is empty; what a screen reader reads is its data, which
      // folds in every descendant merged up into it.
      final label =
          tester.getSemantics(find.byType(SatelliteMatchRow).first).getSemanticsData().label;

      // The match and each carriage with its satellite and frequency, in one node.
      expect(label, contains('النهضة'));
      expect(label, contains('beIN SPORTS 1'));
      expect(label, contains('11013'));
      expect(label, contains('Al Kass Five HD'));
      handle.dispose();
    });

    testWidgets('a cached in-play row shows its kickoff, never a live score or «مباشر»',
        (tester) async {
      final live = satelliteMatch(
        id: 5,
        status: Status.live,
        hour: 18,
        home: 'الاتحاد',
        away: 'الهلال',
        score: const Score(home: 1, away: 0, homePen: null, awayPen: null),
        matchMinute: '68',
        headline: [_bein],
      );
      final env = _Env()..serve(matches: [live]);

      await _pump(tester, env);

      expect(find.textContaining('68'), findsNothing, reason: 'a cached copy is never shown as live');
      expect(find.text('مباشر'), findsNothing, reason: 'SC-008: only /v1/live may say live');
      expect(find.text('6:00 م'), findsOneWidget, reason: 'its kickoff time stands in');

      env.live = [
        LiveState(
          matchId: 5,
          status: Status.live,
          statusLabel: null,
          period: Period.value2h,
          minute: '70',
          score: const Score(home: 2, away: 0, homePen: null, awayPen: null),
          estimated: false,
          statusUpdatedAt: DateTime.utc(2026, 10, 28, 18, 30),
        ),
      ];
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();

      expect(find.textContaining('70'), findsWidgets);
    });

    testWidgets('revalidates every minute while it is on screen', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);
      final before = env.http.requestsTo('/v1/matches').length;

      await tester.pump(const Duration(seconds: 60));
      await tester.pumpAndSettle();

      expect(env.http.requestsTo('/v1/matches').length, before + 1);
    });

    testWidgets('pull to refresh revalidates with the stored ETag', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);
      env.http.notModified('/v1/matches');
      final before = env.adapter.requests.length;

      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      final refreshed = env.adapter.requests.sublist(before).where((r) => r.path == '/v1/matches');
      expect(refreshed, isNotEmpty);
      expect(env.adapter.ifNoneMatch(env.adapter.requests.indexOf(refreshed.first)), '"m-2,5"');
    });
  });

  group('the empty states', () {
    testWidgets('no match on these satellites today names them and says how to refresh',
        (tester) async {
      final env = _Env()..serve(matches: const []);

      await _pump(tester, env);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('لا توجد مباريات على نايل سات، بدر لهذا اليوم'), findsOneWidget);
      expect(find.byType(MatchRow), findsNothing);
    });

    testWidgets('no satellite chosen explains itself and offers «اختر أقمارك»', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);
      final asked = env.http.requestsTo('/v1/matches').length;

      await tester.tap(_chip(2));
      await tester.pumpAndSettle();
      await tester.tap(_chip(5));
      await tester.pumpAndSettle();

      expect(find.text('لم تختر أقماراً بعد'), findsOneWidget);
      expect(find.text('اختر أقمارك'), findsOneWidget);
      expect(find.byType(MatchRow), findsNothing);
      // Asking for no satellite at all would return every match: the app never sends that.
      final sent = env.http.requestsTo('/v1/matches');
      expect(sent.map((r) => r.queryParameters['satellite_ids']), isNot(contains('')));
      expect(sent.length, asked + 1, reason: 'one request for the single satellite, none for none');

      await tester.tap(find.text('اختر أقمارك'));
      await tester.pumpAndSettle();

      expect(_selected(tester, 2), isTrue);
      expect(_selected(tester, 5), isTrue);
      expect(find.byType(MatchRow), findsNWidgets(4));
    });

    testWidgets('a server without Nilesat or Badr leaves nothing to choose: the same state',
        (tester) async {
      final env = _Env()..serve(satellites: [satelliteEntry(hotbirdRef)]);

      await _pump(tester, env);

      expect(find.byType(SatelliteChip), findsNothing);
      expect(find.text('لم تختر أقماراً بعد'), findsOneWidget);
      expect(env.http.requestsTo('/v1/matches'), isEmpty);

      await tester.tap(find.text('اختر أقمارك'));
      await tester.pumpAndSettle();

      expect(find.text('frequencies'), findsOneWidget, reason: 'the satellite list is the way to choose');
    });

    testWidgets('satellites not loaded yet: a skeleton, not an empty state', (tester) async {
      final env = _Env();
      env.http.on('/v1/satellites', (_) => Completer<ResponseBody>().future);

      await _pump(tester, env);

      expect(find.byType(Skeleton), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(env.http.requestsTo('/v1/matches'), isEmpty);
    });

    testWidgets('satellites that fail with nothing cached show the error copy and retry',
        (tester) async {
      final env = _Env();
      env.http
        ..offline('/v1/satellites')
        ..data('/v1/satellites', satellitesWire(sampleSatellites()), etag: '"sat1"')
        ..on('/v1/matches', (_) => FakeHttpAdapter.envelope(matchesWire(_matches)));

      await _pump(tester, env);

      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
      expect(find.text('تعذّر الاتصال بالخادم'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(SatelliteChip), findsNWidgets(2));
      expect(find.byType(MatchRow), findsNWidgets(4));
    });

    testWidgets('the day failing with nothing cached shows the error copy and retry', (tester) async {
      final env = _Env();
      env.http
        ..data('/v1/satellites', satellitesWire(sampleSatellites()), etag: '"sat1"')
        ..offline('/v1/matches')
        ..on('/v1/matches', (_) => FakeHttpAdapter.envelope(matchesWire(_matches)));

      await _pump(tester, env);

      expect(find.byType(SatelliteChip), findsNWidgets(2), reason: 'the chips do not wait for the day');
      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchRow), findsNWidgets(4));
    });
  });

  group('freshness and the cache (FR-046)', () {
    testWidgets('offline, a copy past 5 minutes shows its data and its age', (tester) async {
      final env = _Env();
      await env.seedSatellites();
      await env.seedMatches(age: const Duration(minutes: 10));
      env.http
        ..notModified('/v1/satellites')
        ..offline('/v1/matches');

      await _pump(tester, env);

      expect(find.byType(MatchRow), findsNWidgets(4));
      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(StaleHint), findsOneWidget);
      expect(find.text('آخر تحديث منذ 10 د'), findsOneWidget);
    });

    testWidgets('offline, a copy inside 5 minutes shows no hint', (tester) async {
      final env = _Env();
      await env.seedSatellites();
      await env.seedMatches(age: const Duration(minutes: 2));
      env.http
        ..notModified('/v1/satellites')
        ..offline('/v1/matches');

      await _pump(tester, env);

      expect(find.byType(MatchRow), findsNWidgets(4));
      expect(find.byType(StaleHint), findsNothing);
    });

    testWidgets('an old copy the server just confirmed with a 304 shows no hint', (tester) async {
      final env = _Env();
      await env.seedSatellites();
      await env.seedMatches(age: const Duration(hours: 3));
      env.http
        ..notModified('/v1/satellites')
        ..notModified('/v1/matches');

      await _pump(tester, env);

      expect(find.byType(MatchRow), findsNWidgets(4));
      expect(find.byType(StaleHint), findsNothing);
      expect(env.adapter.ifNoneMatch(env.adapter.requests.indexWhere((r) => r.path == '/v1/matches')), '"m1"');
    });

    testWidgets('the cached day shows at once, and the answer replaces it', (tester) async {
      final env = _Env();
      await env.seedSatellites();
      await env.seedMatches(age: const Duration(minutes: 1));
      final answer = Completer<ResponseBody>();
      env.http
        ..notModified('/v1/satellites')
        ..on('/v1/matches', (_) => answer.future);

      await _pump(tester, env);

      expect(find.byType(MatchRow), findsNWidgets(4), reason: 'the drift copy, before the answer');

      answer.complete(FakeHttpAdapter.envelope(matchesWire([_matches[2]]), etag: '"m2"'));
      await tester.pumpAndSettle();

      expect(find.byType(MatchRow), findsOneWidget);
      expect(find.text('النهضة'), findsOneWidget);
      expect((await env.database.documentFor(env.matchesKey))!.etag, '"m2"');
    });
  });

  group('the screen', () {
    testWidgets('has the title, the search action and the bottom navigation on «أقماري»',
        (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      expect(find.text('أقماري'), findsWidgets);
      expect(tester.widget<MadarBottomNav>(find.byType(MadarBottomNav)).current, MadarTab.mySatellites);

      await tester.tap(find.byTooltip('بحث'));
      await tester.pumpAndSettle();
      expect(find.text('search'), findsOneWidget);
    });

    testWidgets('the bottom navigation moves between the root screens', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      await tester.tap(find.text('الترددات'));
      await tester.pumpAndSettle();

      expect(find.text('frequencies'), findsOneWidget);
    });

    testWidgets('shows Western digits only', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      expect(RegExp('[٠-٩۰-۹]').hasMatch(_allText(tester)), isFalse);
    });

    testWidgets('lays out at 1.3x text without overflowing', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final env = _Env()..serve();

      await _pump(tester, env);

      expect(find.byType(MatchRow), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });
}
