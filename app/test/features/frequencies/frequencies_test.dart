import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' show Headers, ResponseBody;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/bidi.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/links/url_opener.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/badges.dart';
import 'package:madar_sat/design/components/bottom_nav.dart';
import 'package:madar_sat/design/components/carriage_row.dart';
import 'package:madar_sat/design/components/empty_state.dart';
import 'package:madar_sat/design/components/frequency_readout.dart';
import 'package:madar_sat/design/components/segmented.dart';
import 'package:madar_sat/design/components/skeleton.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/features/frequencies/presentation/frequencies_page.dart';
import 'package:madar_sat/features/frequencies/presentation/satellite_card.dart';
import 'package:madar_sat/features/frequencies/presentation/satellite_channels_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/fake_url_opener.dart';
import '../../fixtures/sample_models.dart';
import '../../fixtures/sample_satellites.dart';

/// S5.1 «الترددات» and S5.2 one satellite's channels (FR-045, FR-046).
///
/// The clock says 2026-10-28 18:00 and no assertion reads the host zone.

final List<ChannelCarriage> _channels = [
  channelEntry(id: 1, name: 'beIN SPORTS 5', mhz: 12188, provider: 'beIN'),
  channelEntry(id: 2, name: 'beIN SPORTS 1', mhz: 11013, provider: 'beIN', package: 'beIN Sports'),
  channelEntry(
    id: 3,
    name: 'ON Sport HD',
    mhz: 11977,
    pol: Polarization.v,
    access: Access.free,
  ),
  channelEntry(id: 4, name: 'Al Kass One HD', mhz: 11919, access: Access.free),
  channelEntry(id: 5, name: 'Nile Sports', mhz: 11843, access: Access.free),
  channelEntry(
    id: 6,
    name: 'Rotana Cinema',
    category: Category.entertainment,
    mhz: 11843,
    pol: Polarization.v,
    access: Access.free,
  ),
  channelEntry(id: 7, name: 'MBC 4', category: Category.entertainment, mhz: 12188, provider: 'MBC'),
  channelEntry(
    id: 8,
    name: 'Mazzika',
    displayName: 'مزيكا',
    category: Category.entertainment,
    mhz: 11747,
    access: Access.free,
  ),
];

/// Nilesat with its alignment aids and its reception video; the other two as in S4.
List<Satellite> _satellites({String? receptionUrl = 'https://www.youtube.com/watch?v=nilesat-reception'}) => [
      satelliteEntry(hotbirdRef, channelCount: 189),
      satelliteEntry(
        nilesatRef,
        channelCount: _channels.length,
        best: const Frequency(mhz: 12054, pol: Polarization.v, sr: 27500),
        worst: const Frequency(mhz: 11373, pol: Polarization.h, sr: 27500),
        receptionUrl: receptionUrl,
      ),
      satelliteEntry(badrRef, channelCount: 69),
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
  final FakeUrlOpener opener = FakeUrlOpener();
  final List<String> clipboard = [];

  void serve({
    List<Satellite>? satellites,
    List<ChannelCarriage>? channels,
    int satelliteId = 2,
  }) {
    http.data('/v1/satellites', satellitesWire(satellites ?? _satellites()), etag: '"sat1"');
    http.data(
      '/v1/satellites/$satelliteId/channels',
      channelsWire(channels ?? _channels),
      etag: '"ch1"',
    );
  }

  Future<void> seedSatellites({Duration age = Duration.zero}) => database.putDocument(
        key: DocumentKeys.satellites,
        etag: '"sat1"',
        body: jsonEncode(satellitesWire(_satellites())),
        fetchedAt: clock.subtract(age).toUtc(),
      );

  Future<void> seedChannels({Duration age = Duration.zero}) => database.putDocument(
        key: DocumentKeys.satelliteChannels(2),
        etag: '"ch1"',
        body: jsonEncode(channelsWire(_channels)),
        fetchedAt: clock.subtract(age).toUtc(),
      );
}

GoRouter _router(String initial) {
  Widget stub(String text) => Scaffold(body: Center(child: Text(text)));
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => stub('home')),
      GoRoute(path: '/my-satellites', builder: (_, _) => stub('my satellites')),
      GoRoute(path: '/satellites', builder: (_, _) => const FrequenciesPage()),
      GoRoute(
        path: '/satellites/:id',
        builder: (_, state) =>
            SatelliteChannelsPage(satelliteId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/favorites', builder: (_, _) => stub('favorites')),
      GoRoute(path: '/settings', builder: (_, _) => stub('settings')),
      GoRoute(path: '/search', builder: (_, _) => stub('search')),
    ],
  );
}

Future<GoRouter> _pump(WidgetTester tester, _Env env, {String initial = '/satellites'}) async {
  tester.view
    ..physicalSize = const Size(1080, 4800)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  addTearDown(env.database.close);

  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      env.clipboard.add((call.arguments as Map<Object?, Object?>)['text']! as String);
    }
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );

  final router = _router(initial);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        swrRepositoryProvider.overrideWithValue(env.repository),
        appDatabaseProvider.overrideWithValue(env.database),
        clockProvider.overrideWithValue(() => env.clock),
        urlOpenerProvider.overrideWithValue(env.opener),
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
  return router;
}

/// Opens S5.2 the way the app does: pushed on top of another screen, so it has a back arrow.
Future<GoRouter> _pumpDetail(WidgetTester tester, _Env env, {int satelliteId = 2}) async {
  final router = await _pump(tester, env, initial: '/');
  unawaited(router.push('/satellites/$satelliteId'));
  await tester.pumpAndSettle();
  return router;
}

String _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .join(' ');

bool _noEasternDigits(WidgetTester tester) =>
    !RegExp('[٠-٩۰-۹]').hasMatch(_allText(tester));

Finder _card(int satelliteId) => find.byWidgetPredicate(
      (widget) => widget is SatelliteCard && widget.satellite.id == satelliteId,
    );

Finder _carriage(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byType(CarriageRow),
    );

Finder _search() => find.byType(TextField);

void main() {
  group('S5.1 the satellite list', () {
    testWidgets('lists the satellites with position, English name and channel count', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      expect(find.byType(SatelliteCard), findsNWidgets(3));
      expect(find.text('3 قمراً'), findsOneWidget);
      expect(find.widgetWithText(LtrIsland, '7.0W'), findsOneWidget);
      expect(find.widgetWithText(LtrIsland, '26.0E'), findsOneWidget);
      expect(find.widgetWithText(LtrIsland, 'Hotbird 13.0E'), findsOneWidget);
      expect(find.text('189 قناة'), findsOneWidget);
      expect(find.text('69 قناة'), findsOneWidget);
      expect(_noEasternDigits(tester), isTrue);
    });

    testWidgets('my satellites are pinned first under their own heading, with a marker',
        (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      // The server lists Hotbird first; Nilesat and Badr are pinned above it.
      expect(top(_card(2)), lessThan(top(_card(5))));
      expect(top(_card(5)), lessThan(top(_card(7))));
      expect(find.text('كل الأقمار'), findsOneWidget);
      expect(find.text('طبقي'), findsNWidgets(2));
      expect(
        find.descendant(of: _card(7), matching: find.text('طبقي')),
        findsNothing,
        reason: 'Hotbird is not mine',
      );
    });

    testWidgets('search finds a satellite by its Arabic name, its English name or its position',
        (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      await tester.enterText(_search(), 'نايل');
      await tester.pumpAndSettle();
      expect(find.byType(SatelliteCard), findsOneWidget);
      expect(_card(2), findsOneWidget);

      await tester.enterText(_search(), 'HOTBIRD');
      await tester.pumpAndSettle();
      expect(_card(7), findsOneWidget);
      expect(find.byType(SatelliteCard), findsOneWidget);

      await tester.enterText(_search(), '26');
      await tester.pumpAndSettle();
      expect(_card(5), findsOneWidget);
      expect(find.byType(SatelliteCard), findsOneWidget);

      await tester.enterText(_search(), '');
      await tester.pumpAndSettle();
      expect(find.byType(SatelliteCard), findsNWidgets(3));
    });

    testWidgets('a search with no match says so', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      await tester.enterText(_search(), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.byType(SatelliteCard), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('لا توجد أقمار مطابقة'), findsOneWidget);
    });

    testWidgets('a card opens that satellite', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      await tester.tap(_card(2));
      await tester.pumpAndSettle();

      expect(find.byType(SatelliteChannelsPage), findsOneWidget);
      expect(tester.widget<SatelliteChannelsPage>(find.byType(SatelliteChannelsPage)).satelliteId, 2);
    });

    testWidgets('has «الترددات» selected in the bottom navigation, which moves between roots',
        (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);

      expect(tester.widget<MadarBottomNav>(find.byType(MadarBottomNav)).current, MadarTab.frequencies);

      await tester.tap(
        find.descendant(of: find.byType(MadarBottomNav), matching: find.text('أقماري')),
      );
      await tester.pumpAndSettle();
      expect(find.text('my satellites'), findsOneWidget);
    });

    testWidgets('a card reads as one screen-reader node', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);
      final handle = tester.ensureSemantics();

      final label = tester.getSemantics(_card(2)).label;

      expect(label, contains('نايل سات'));
      expect(label, contains('Nilesat 7.0W'));
      expect(label, contains('8 قناة'));
      handle.dispose();
    });

    testWidgets('shows the cached list with its age when offline and past 24 hours', (tester) async {
      final env = _Env();
      await env.seedSatellites(age: const Duration(hours: 30));
      env.http.offline('/v1/satellites');

      await _pump(tester, env);

      expect(find.byType(SatelliteCard), findsNWidgets(3));
      expect(find.byType(StaleHint), findsOneWidget);
      expect(find.text('آخر تحديث منذ 1 يوم'), findsOneWidget);
    });

    testWidgets('offline inside 24 hours shows the list and no hint', (tester) async {
      final env = _Env();
      await env.seedSatellites(age: const Duration(hours: 3));
      env.http.offline('/v1/satellites');

      await _pump(tester, env);

      expect(find.byType(SatelliteCard), findsNWidgets(3));
      expect(find.byType(StaleHint), findsNothing);
    });

    testWidgets('an old copy the server confirmed with a 304 shows no hint', (tester) async {
      final env = _Env();
      await env.seedSatellites(age: const Duration(days: 3));
      env.http.notModified('/v1/satellites');

      await _pump(tester, env);

      expect(find.byType(SatelliteCard), findsNWidgets(3));
      expect(find.byType(StaleHint), findsNothing);
      expect(env.adapter.ifNoneMatch(0), '"sat1"');
    });

    testWidgets('pull to refresh revalidates the list', (tester) async {
      final env = _Env()..serve();
      await _pump(tester, env);
      final before = env.http.requestsTo('/v1/satellites').length;

      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(env.http.requestsTo('/v1/satellites').length, greaterThan(before));
    });

    testWidgets('shows a skeleton while nothing has arrived', (tester) async {
      final env = _Env();
      env.http.on('/v1/satellites', (_) => Completer<ResponseBody>().future);

      await _pump(tester, env);

      expect(find.byType(Skeleton), findsOneWidget);
      expect(find.byType(SatelliteCard), findsNothing);
    });

    testWidgets('lays out at 1.3x text without overflowing', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final env = _Env()..serve();

      await _pump(tester, env);

      expect(find.byType(SatelliteCard), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failure with nothing cached shows the error copy and retry works', (tester) async {
      final env = _Env();
      env.http
        ..offline('/v1/satellites')
        ..data('/v1/satellites', satellitesWire(_satellites()), etag: '"sat1"');

      await _pump(tester, env);

      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
      expect(find.text('تعذّر الاتصال بالخادم'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(SatelliteCard), findsNWidgets(3));
    });
  });

  group('S5.2 the satellite header', () {
    testWidgets('names the satellite with its position as an LTR island and its channel count',
        (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      expect(find.text('نايل سات'), findsOneWidget);
      expect(find.widgetWithText(LtrIsland, '7.0°W'), findsOneWidget);
      expect(find.widgetWithText(LtrIsland, 'Nilesat 7.0W'), findsOneWidget);
      expect(find.text('8 قناة'), findsOneWidget);
    });

    testWidgets('has a back arrow that returns to where it was opened from', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('shows the strongest and the weakest frequency to align the dish', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      expect(find.text('أقوى تردد'), findsOneWidget);
      expect(find.text('أضعف تردد'), findsOneWidget);
      final strongest = tester.widget<FrequencyReadout>(
        find.byWidgetPredicate(
          (w) => w is FrequencyReadout && w.state == FrequencyReadoutState.good,
        ),
      );
      final weakest = tester.widget<FrequencyReadout>(
        find.byWidgetPredicate(
          (w) => w is FrequencyReadout && w.state == FrequencyReadoutState.bad,
        ),
      );
      expect(strongest.mhz, 12054);
      expect(strongest.polarization, Polarization.v);
      expect(weakest.mhz, 11373);
      expect(weakest.polarization, Polarization.h);
    });

    testWidgets('leaves the aids out when the satellite has none', (tester) async {
      final env = _Env()
        ..serve(
          satellites: [satelliteEntry(nilesatRef, channelCount: 8)],
        );
      await _pumpDetail(tester, env);

      expect(find.text('أقوى تردد'), findsNothing);
      expect(find.text('أضعف تردد'), findsNothing);
      expect(find.text('طريقة استقبال القمر'), findsNothing);
    });

    testWidgets('opens the reception video through url_launcher', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      await tester.tap(find.text('طريقة استقبال القمر'));
      await tester.pumpAndSettle();

      expect(env.opener.opened, [Uri.parse('https://www.youtube.com/watch?v=nilesat-reception')]);
    });

    testWidgets('never offers a video that is not an https link', (tester) async {
      final cleartext = _Env()..serve(satellites: _satellites(receptionUrl: 'http://example.com/v'));
      await _pumpDetail(tester, cleartext);
      expect(find.text('طريقة استقبال القمر'), findsNothing);
    });

    testWidgets('falls back to the satellite named by its channels when the list lacks it',
        (tester) async {
      final env = _Env()..serve(satellites: const []);
      await _pumpDetail(tester, env);

      expect(find.text('نايل سات'), findsOneWidget);
      expect(find.widgetWithText(LtrIsland, '7.0°W'), findsOneWidget);
      expect(find.text('أقوى تردد'), findsNothing);
    });
  });

  group('S5.2 the channels', () {
    testWidgets('fetches the whole list once, with no category or search in the request',
        (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      final request = env.http.requestsTo('/v1/satellites/2/channels').single;
      expect(request.queryParameters, isEmpty);

      await tester.enterText(_search(), 'bein');
      await tester.tap(find.text('ترفيه 3'));
      await tester.pumpAndSettle();
      expect(env.http.requestsTo('/v1/satellites/2/channels'), hasLength(1));
    });

    testWidgets('starts on sports, with the count of each tab', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      expect(find.byType(Segmented<Category>), findsOneWidget);
      expect(find.text('رياضة 5'), findsOneWidget);
      expect(find.text('ترفيه 3'), findsOneWidget);
      expect(find.text('beIN SPORTS 5'), findsOneWidget);
      expect(find.text('Nile Sports'), findsOneWidget);
      expect(find.text('Rotana Cinema'), findsNothing);
    });

    testWidgets('the segmented control switches to entertainment and back', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      await tester.tap(find.text('ترفيه 3'));
      await tester.pumpAndSettle();

      expect(find.text('Rotana Cinema'), findsOneWidget);
      expect(find.text('مزيكا'), findsOneWidget);
      expect(find.text('beIN SPORTS 5'), findsNothing);

      await tester.tap(find.text('رياضة 5'));
      await tester.pumpAndSettle();
      expect(find.text('beIN SPORTS 5'), findsOneWidget);
      expect(find.text('Rotana Cinema'), findsNothing);
    });

    testWidgets('swiping switches the category in reading order, and the segment follows',
        (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      // In RTL the next page is on the left: the finger moves to the right.
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
      await tester.pumpAndSettle();

      expect(find.text('Rotana Cinema'), findsOneWidget);
      expect(find.text('beIN SPORTS 5'), findsNothing);
      expect(tester.widget<Segmented<Category>>(find.byType(Segmented<Category>)).selected, Category.entertainment);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
      await tester.pumpAndSettle();

      expect(find.text('beIN SPORTS 5'), findsOneWidget);
      expect(tester.widget<Segmented<Category>>(find.byType(Segmented<Category>)).selected, Category.sports);
    });

    testWidgets('every row shows its readout and access badge without being opened', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      expect(find.byType(CarriageRow), findsNWidgets(5));
      expect(find.byType(FrequencyReadout), findsNWidgets(5 + 2), reason: 'five rows and the two aids');
      expect(find.byType(AccessBadge), findsNWidgets(5));
      expect(find.descendant(of: _carriage('beIN SPORTS 1'), matching: find.text('11013')), findsOneWidget);
      expect(find.descendant(of: _carriage('beIN SPORTS 1'), matching: find.text('مشفرة · beIN')), findsOneWidget);
      expect(find.descendant(of: _carriage('ON Sport HD'), matching: find.text('11977')), findsOneWidget);
      expect(find.descendant(of: _carriage('ON Sport HD'), matching: find.text('مجانية')), findsOneWidget);
    });

    testWidgets('search matches a name in any case', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      await tester.enterText(_search(), 'BEIN');
      await tester.pumpAndSettle();

      expect(find.byType(CarriageRow), findsNWidgets(2));
      expect(find.text('beIN SPORTS 5'), findsOneWidget);
      expect(find.text('beIN SPORTS 1'), findsOneWidget);
      expect(find.text('ON Sport HD'), findsNothing);
    });

    testWidgets('search by frequency digits: 11843 finds the 11843 MHz channel', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      await tester.enterText(_search(), '11843');
      await tester.pumpAndSettle();

      expect(find.byType(CarriageRow), findsOneWidget);
      expect(find.text('Nile Sports'), findsOneWidget);

      // The same search follows the user to the other tab.
      await tester.tap(find.text('ترفيه 3'));
      await tester.pumpAndSettle();
      expect(find.byType(CarriageRow), findsOneWidget);
      expect(find.text('Rotana Cinema'), findsOneWidget);
    });

    testWidgets('search finds an Arabic display name', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);
      await tester.tap(find.text('ترفيه 3'));
      await tester.pumpAndSettle();

      await tester.enterText(_search(), 'مزيكا');
      await tester.pumpAndSettle();

      expect(find.byType(CarriageRow), findsOneWidget);
      expect(
        find.descendant(of: find.byType(CarriageRow), matching: find.text('مزيكا')),
        findsOneWidget,
      );
    });

    testWidgets('a search with no match says so, and clearing it brings the list back',
        (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      await tester.enterText(_search(), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.byType(CarriageRow), findsNothing);
      expect(find.text('لا توجد قنوات مطابقة'), findsOneWidget);

      await tester.tap(find.byTooltip('مسح البحث'));
      await tester.pumpAndSettle();
      expect(find.byType(CarriageRow), findsNWidgets(5));
    });

    testWidgets('a row opens in place with the S3 details, one at a time', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      await tester.tap(find.text('beIN SPORTS 1'));
      await tester.pumpAndSettle();

      expect(find.text('نسخ التردد'), findsOneWidget);
      expect(find.text('فيديو الاستقبال'), findsOneWidget);
      expect(find.text('11013 MHz'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('11013 MHz'))),
        TextDirection.ltr,
        reason: 'the number before its unit (M-R2-1)',
      );
      expect(find.text('أفقي'), findsOneWidget);
      expect(find.text('مشفرة · beIN'), findsWidgets);
      expect(find.text('beIN Sports'), findsOneWidget, reason: 'the package (M-R2-10)');

      await tester.tap(find.text('ON Sport HD'));
      await tester.pumpAndSettle();

      expect(find.text('نسخ التردد'), findsOneWidget, reason: 'the first row closed');
      expect(find.text('11977 MHz'), findsOneWidget);
      expect(find.text('11013 MHz'), findsNothing);
    });

    testWidgets('an opened row copies its frequency and plays the reception video', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);
      await tester.tap(find.text('beIN SPORTS 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('نسخ التردد'));
      await tester.pumpAndSettle();
      expect(env.clipboard, ['11013 H 27500']);
      expect(find.text('تم نسخ التردد'), findsOneWidget);

      await tester.tap(find.text('فيديو الاستقبال'));
      await tester.pumpAndSettle();
      expect(env.opener.opened, [Uri.parse('https://www.youtube.com/watch?v=nilesat-reception')]);
    });

    testWidgets('a satellite without sports channels says so on that tab', (tester) async {
      final env = _Env()
        ..serve(
          channels: [
            channelEntry(id: 6, name: 'Rotana Cinema', category: Category.entertainment, mhz: 11843),
          ],
        );
      await _pumpDetail(tester, env);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('لا توجد قنوات رياضة على هذا القمر'), findsOneWidget);
      expect(find.byType(CarriageRow), findsNothing);

      await tester.tap(find.text('ترفيه 1'));
      await tester.pumpAndSettle();
      expect(find.byType(CarriageRow), findsOneWidget);
    });

    testWidgets('a satellite without entertainment channels says so on that tab', (tester) async {
      final env = _Env()..serve(channels: [_channels.first]);
      await _pumpDetail(tester, env);

      // A tab with nothing in it carries no count rather than a «0».
      await tester.tap(find.text('ترفيه'));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد قنوات ترفيه على هذا القمر'), findsOneWidget);
    });

    testWidgets('builds a long list lazily', (tester) async {
      // A hundred rows are far more than the 1600 dp screen holds. (Dio decodes a body over
      // 50 KB on a real isolate, which a widget test's fake clock never reaches, so the
      // fixture stays under it.)
      final many = [
        for (var i = 0; i < 100; i++)
          channelEntry(id: 1000 + i, name: 'Channel $i', mhz: 10000 + i, access: Access.free),
      ];
      final env = _Env()..serve(channels: many);
      await _pumpDetail(tester, env);

      expect(find.text('رياضة 100'), findsOneWidget);
      expect(find.byType(CarriageRow), findsWidgets);
      expect(find.byType(CarriageRow).evaluate().length, lessThan(40));
      expect(find.text('Channel 99'), findsNothing);

      // The header scrolls away with the list, and the last row is reachable.
      await tester.dragUntilVisible(
        find.text('Channel 99'),
        find.byType(ListView),
        const Offset(0, -600),
      );
      expect(find.text('Channel 99'), findsOneWidget);
    });

    testWidgets('shows the cached list when offline, with its age past 24 hours', (tester) async {
      final env = _Env();
      await env.seedSatellites(age: const Duration(hours: 1));
      await env.seedChannels(age: const Duration(hours: 49));
      env.http
        ..notModified('/v1/satellites')
        ..offline('/v1/satellites/2/channels');

      await _pumpDetail(tester, env);

      expect(find.byType(CarriageRow), findsNWidgets(5));
      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('آخر تحديث منذ 2 يوم'), findsOneWidget);
    });

    testWidgets('a copy confirmed by a 304 shows no hint', (tester) async {
      final env = _Env();
      await env.seedSatellites(age: const Duration(hours: 1));
      await env.seedChannels(age: const Duration(days: 3));
      env.http
        ..notModified('/v1/satellites')
        ..notModified('/v1/satellites/2/channels');

      await _pumpDetail(tester, env);

      expect(find.byType(CarriageRow), findsNWidgets(5));
      expect(find.byType(StaleHint), findsNothing);
    });

    testWidgets('a failure with nothing cached shows the error copy and retry works', (tester) async {
      final env = _Env();
      env.http.data('/v1/satellites', satellitesWire(_satellites()), etag: '"sat1"');
      env.http
        ..offline('/v1/satellites/2/channels')
        ..data('/v1/satellites/2/channels', channelsWire(_channels), etag: '"ch1"');

      await _pumpDetail(tester, env);

      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
      expect(find.text('نايل سات'), findsOneWidget, reason: 'the header does not wait for the channels');

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.byType(CarriageRow), findsNWidgets(5));
    });

    testWidgets('a satellite that does not exist shows the error copy', (tester) async {
      final env = _Env();
      env.http.data('/v1/satellites', satellitesWire(_satellites()), etag: '"sat1"');
      env.http.on(
        '/v1/satellites/99/channels',
        (_) => ResponseBody.fromString(
          jsonEncode({
            'success': false,
            'data': null,
            'error': {'code': 'satellite_not_found', 'message': 'for logs only'},
            'meta': <String, Object?>{},
          }),
          404,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );

      await _pumpDetail(tester, env, satelliteId: 99);

      expect(find.text('لم نجد ما تبحث عنه'), findsOneWidget);
      expect(find.textContaining('for logs only'), findsNothing);
    });

    testWidgets('shows Western digits only', (tester) async {
      final env = _Env()..serve();
      await _pumpDetail(tester, env);
      await tester.tap(find.text('beIN SPORTS 1'));
      await tester.pumpAndSettle();

      expect(_noEasternDigits(tester), isTrue);
    });

    testWidgets('lays out at 1.3x text without overflowing, opened row included', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final env = _Env()..serve();
      await _pumpDetail(tester, env);

      await tester.tap(find.text('beIN SPORTS 1'));
      await tester.pumpAndSettle();

      expect(find.byType(CarriageRow), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    });
  });
}
