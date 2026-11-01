import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/audio/clip_controller.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/bidi.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/links/url_opener.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/design/components/carriage_row.dart';
import 'package:madar_sat/design/components/empty_state.dart';
import 'package:madar_sat/design/components/search_field.dart';
import 'package:madar_sat/design/components/skeleton.dart';
import 'package:madar_sat/design/components/stale_hint.dart';
import 'package:madar_sat/features/live/live_poller.dart';
import 'package:madar_sat/features/match_detail/presentation/match_detail_page.dart';
import 'package:madar_sat/features/my_satellites/data/my_satellites_provider.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_clip_engine.dart';
import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/fake_url_opener.dart';
import '../../fixtures/sample_match_detail.dart';
import '../../fixtures/sample_models.dart';

const int _matchId = 48213;
const String _matchPath = '/v1/matches/$_matchId';
const String _satellitesPath = '/v1/satellites';
const String _receptionUrl = 'https://video.test/reception/hotbird';

/// S3 (FR-042, FR-043, FR-046, FR-047, SC-006, SC-008): the hero, the three-part "where to
/// watch", `CarriageRow` and its actions, the cards, the no-channels state, a long list that
/// builds lazily, and the stale and offline copies. Requests go through the real repository
/// and drift, answered by path; no network, no audio plugin, no launcher.
void main() {
  late AppDatabase db;
  late RoutedApi api;
  late FakeUrlOpener opener;
  late FakeClipEngine engine;
  late GoRouter router;
  late List<LiveState> liveAnswer;

  setUp(() {
    api = RoutedApi();
    opener = FakeUrlOpener();
    engine = FakeClipEngine();
    liveAnswer = [];
    db = AppDatabase(
      NativeDatabase.memory(),
      now: sampleNow,
      offsetAt: (_) => const Duration(hours: 3),
    );
  });

  tearDown(() => db.close());

  /// Nilesat and Badr are mine; Hotbird has a reception video, Nilesat does not.
  void answerSatellites() => api.answer(
        _satellitesPath,
        satellitesJson([
          sampleSatelliteEntry(sampleSatellite),
          sampleSatelliteEntry(badrSatellite),
          sampleSatelliteEntry(hotbirdSatellite, receptionUrl: _receptionUrl),
          sampleSatelliteEntry(eutelSatellite),
        ]),
      );

  void answerDetail(MatchDetail detail, {String? etag = '"v1"'}) =>
      api.answer(_matchPath, matchDetailJson(detail), etag: etag);

  /// A channel row may sit below the fold (my satellites, then the other groups); scroll to
  /// it before tapping, as a person would.
  Future<void> tapChannel(WidgetTester tester, String name) async {
    final finder = find.text(name);
    if (finder.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        finder,
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> seedCache(MatchDetail detail, {required Duration age}) => db.putDocument(
        key: DocumentKeys.matchDetail(_matchId),
        etag: '"v1"',
        body: jsonEncode(matchDetailJson(detail)),
        fetchedAt: sampleNow().subtract(age).toUtc(),
      );

  /// Opens S3 on a phone-wide view. The default is tall enough to build everything in the
  /// standard match; the long-list tests pass the real 800 so virtualization shows.
  Future<void> open(
    WidgetTester tester, {
    bool settle = true,
    double height = 2400,
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
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('home-stub'))),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) =>
              MatchDetailPage(matchId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          swrRepositoryProvider.overrideWithValue(SwrRepository(dio: api.dio, database: db)),
          clockProvider.overrideWithValue(() => sampleNow()),
          clipEngineProvider.overrideWithValue(engine),
          urlOpenerProvider.overrideWithValue(opener),
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
    unawaited(router.push('/match/$_matchId'));
    if (settle) await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MatchDetailPage)));

  /// Mocks the platform clipboard and returns what was copied.
  String? Function() mockClipboard(WidgetTester tester) {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return () => copied;
  }

  /// The page's own vertical scrollable (the chip row and the search field have theirs too).
  Finder page() => find.byType(Scrollable).first;

  double scrollOffset(WidgetTester tester) =>
      tester.state<ScrollableState>(page()).position.pixels;

  /// Two on my satellites (Nilesat free, Badr encrypted with a commentator), three on other
  /// satellites (two Hotbird, one Eutel), and three platforms in two regions.
  MatchDetail standard({
    Status status = Status.scheduled,
    List<BroadcastEntry> broadcasts = const [],
    String? stadium,
    String? localBroadcasterEg,
    CommentatorRef? commentator,
  }) =>
      sampleMatchDetail(
        status: status,
        broadcasts: broadcasts,
        stadium: stadium,
        localBroadcasterEg: localBroadcasterEg,
        commentator: commentator,
        carriages: [
          sampleCarriageEntry(
            id: 1,
            name: 'ON Sport HD',
            access: Access.free,
            frequency: const Frequency(mhz: 11977, pol: Polarization.v, sr: 27500),
          ),
          sampleCarriageEntry(
            id: 2,
            name: 'beIN SPORTS 1',
            satellite: badrSatellite,
            provider: 'beIN',
            package: 'beIN Sports',
            frequency: const Frequency(mhz: 10810, pol: Polarization.h, sr: 27500),
            commentators: const [sampleCommentator],
          ),
          sampleCarriageEntry(
            id: 3,
            name: 'DAZN 1 HD',
            satellite: hotbirdSatellite,
            frequency: const Frequency(mhz: 11843, pol: Polarization.v, sr: 29900),
          ),
          sampleCarriageEntry(
            id: 4,
            name: 'Eleven Sports 1 HD',
            satellite: hotbirdSatellite,
            changedAt: DateTime.utc(2026, 10, 20),
            frequency: const Frequency(mhz: 10796, pol: Polarization.v, sr: 27500),
          ),
          sampleCarriageEntry(
            id: 5,
            name: 'Eutel One',
            satellite: eutelSatellite,
            frequency: const Frequency(mhz: 11117, pol: Polarization.h, sr: 27500),
          ),
        ],
        platforms: [
          samplePlatformGroup('الشرق الأوسط', ['STC TV', 'Shasha'], country: 'السعودية'),
          samplePlatformGroup('أوروبا', ['Sky Go'], country: 'ألمانيا'),
        ],
      );

  group('the hero', () {
    testWidgets('shows both teams, the competition, its stage and the kickoff date in words',
        (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      expect(find.text('الأهلي'), findsOneWidget);
      expect(find.text('الزمالك'), findsOneWidget);
      expect(find.text('الدوري المصري الممتاز'), findsOneWidget);
      expect(find.text('الجولة 9'), findsOneWidget);
      // 21:00 on the device, written out: the weekday, the day and the month, then the time.
      expect(find.text('الأربعاء 28 أكتوبر · 9:00 م'), findsOneWidget);
    });

    testWidgets('three hours before kickoff the hero counts down to it', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      // The pinned clock says 18:00 and the kickoff 21:00, outside the status block's hour.
      expect(find.text('تبدأ بعد 3 ساعات'), findsOneWidget);
    });

    testWidgets('the home team sits on the right in RTL', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      expect(
        tester.getCenter(find.text('الأهلي')).dx,
        greaterThan(tester.getCenter(find.text('الزمالك')).dx),
      );
    });

    testWidgets('a match with no kickoff says the time is not set, never a guessed time',
        (tester) async {
      answerSatellites();
      answerDetail(sampleMatchDetail(timeTbd: true));
      await open(tester);

      expect(find.text('الأربعاء 28 أكتوبر · لم يُحدد'), findsOneWidget);
    });

    testWidgets('one merged Arabic label reads the match, its status and its date', (tester) async {
      final handle = tester.ensureSemantics();
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      expect(
        find.bySemanticsLabel(
          'الأهلي ضد الزمالك، 9:00 م، الدوري المصري الممتاز، الجولة 9، الأربعاء 28 أكتوبر، تبدأ بعد 3 ساعات',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the back arrow pops to the screen below', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(find.text('home-stub'), findsOneWidget);
      expect(find.byType(MatchDetailPage), findsNothing);
    });

    testWidgets('a live match shows the score and minute /v1/live gave it', (tester) async {
      liveAnswer = [
        const LiveState(
          matchId: _matchId,
          status: Status.live,
          estimated: false,
          minute: '67',
          period: Period.value2h,
          score: Score(home: 1, away: 0, homePen: null, awayPen: null),
          statusLabel: null,
          statusUpdatedAt: null,
        ),
      ];
      answerSatellites();
      answerDetail(standard(status: Status.live));
      await open(tester);

      expect(find.text('67′'), findsOneWidget);
      final score = find.byType(ScoreParts);
      expect(find.descendant(of: score, matching: find.text('1')), findsOneWidget);
      expect(find.descendant(of: score, matching: find.text('0')), findsOneWidget);
    });

    testWidgets('a cached in-play match with no live state shows its kickoff, never «مباشر»',
        (tester) async {
      // The detail says live with a score, but only /v1/live may say that (SC-008).
      answerSatellites();
      answerDetail(
        sampleMatchDetail(
          status: Status.live,
          minute: '88',
          score: const Score(home: 3, away: 2, homePen: null, awayPen: null),
        ),
      );
      await open(tester);

      expect(find.text('مباشر'), findsNothing);
      expect(find.text('88′'), findsNothing);
      expect(find.byType(ScoreParts), findsNothing);
      // The hero still says when it was due to start.
      expect(find.text('الأربعاء 28 أكتوبر · 9:00 م'), findsOneWidget);
    });

    testWidgets('an estimated live state from /v1/live shows no score and no minute', (tester) async {
      liveAnswer = [
        const LiveState(
          matchId: _matchId,
          status: Status.live,
          estimated: true,
          minute: '12',
          period: null,
          score: Score(home: 1, away: 1, homePen: null, awayPen: null),
          statusLabel: null,
          statusUpdatedAt: null,
        ),
      ];
      answerSatellites();
      answerDetail(sampleMatchDetail(status: Status.live));
      await open(tester);

      expect(find.text('مباشر'), findsOneWidget);
      expect(find.text('12′'), findsNothing);
      expect(find.byType(ScoreParts), findsNothing);
    });
  });

  group('both themes at 1.3× (FR-048)', () {
    testWidgets('the light theme draws S3 without an overflow', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester, brightness: Brightness.light, textScale: 1.3);

      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow at 1.3×');
      expect(find.text('الأهلي'), findsOneWidget);
      expect(find.text('أين تشاهد'), findsOneWidget);
      expect(find.byType(CarriageRow), findsWidgets);
    });

    testWidgets('the dark theme draws S3 without an overflow', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester, textScale: 1.3);

      expect(tester.takeException(), isNull);
      expect(find.text('الزمالك'), findsOneWidget);
    });
  });

  group('where to watch', () {
    testWidgets('the toolbar names the section and counts every way to watch', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      expect(find.text('أين تشاهد'), findsOneWidget);
      // 5 carriages + 3 platforms.
      expect(find.text('8 قنوات'), findsOneWidget);
      expect(find.text('المجانية فقط'), findsOneWidget);
      expect(find.byType(SearchField), findsOneWidget);
    });

    testWidgets('my satellites first, then the other satellites, then platforms', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      final mine = tester.getTopLeft(find.byKey(const ValueKey('group:mine'))).dy;
      final hotbird = tester.getTopLeft(find.byKey(ValueKey('group:sat:${hotbirdSatellite.id}'))).dy;
      expect(find.text('على نايل سات وبدر'), findsOneWidget);
      expect(find.text('نايل سات · بدر'), findsOneWidget);
      expect(find.text('أقمار أخرى'), findsOneWidget);
      expect(find.text('3 قنوات على قمرين'), findsOneWidget);
      expect(find.text('منصات وقنوات أخرى'), findsOneWidget);
      expect(mine, lessThan(hotbird));
      expect(
        tester.getTopLeft(find.text('أقمار أخرى')).dy,
        lessThan(tester.getTopLeft(find.text('منصات وقنوات أخرى')).dy),
      );
    });

    testWidgets('once the user has chosen satellites the part reads «على أقمارك»', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester, overrides: [chosenSatelliteIdsProvider.overrideWithValue({2, 5})]);

      expect(find.text('على أقمارك'), findsOneWidget);
      expect(find.text('على نايل سات وبدر'), findsNothing);
    });

    testWidgets('free before encrypted inside my satellites', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      // Badr's beIN is encrypted and ON Sport on Nilesat is free: ON Sport is listed first.
      expect(
        tester.getTopLeft(find.text('ON Sport HD')).dy,
        lessThan(tester.getTopLeft(find.text('beIN SPORTS 1')).dy),
      );
    });

    testWidgets('my satellites and the first other satellite are open, the rest collapsed',
        (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      expect(find.text('ON Sport HD'), findsOneWidget);
      expect(find.text('beIN SPORTS 1'), findsOneWidget);
      expect(find.text('DAZN 1 HD'), findsOneWidget);
      // Eutel's group is collapsed: only its header is built.
      expect(find.byKey(ValueKey('group:sat:${eutelSatellite.id}')), findsOneWidget);
      expect(find.text('Eutel One'), findsNothing);
    });

    testWidgets('tapping a group header opens it, and again closes it', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);
      final eutel = find.byKey(ValueKey('group:sat:${eutelSatellite.id}'));

      await tester.tap(eutel);
      await tester.pumpAndSettle();
      expect(find.text('Eutel One'), findsOneWidget);

      await tester.tap(eutel);
      await tester.pumpAndSettle();
      expect(find.text('Eutel One'), findsNothing);
    });

    testWidgets('a group header is one merged label with its count and its open state',
        (tester) async {
      final handle = tester.ensureSemantics();
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      expect(find.bySemanticsLabel('هوت بيرد، Hotbird 13.0E، قناتان'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('platforms are grouped by region and collapsed until opened', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);
      final region = find.byKey(const ValueKey('group:region:الشرق الأوسط'));

      expect(find.text('STC TV'), findsNothing);
      expect(find.text('منصتان'), findsOneWidget);
      expect(find.text('منصة واحدة'), findsOneWidget);

      await tester.tap(region);
      await tester.pumpAndSettle();

      expect(find.text('STC TV'), findsOneWidget);
      expect(find.text('Shasha'), findsOneWidget);
      expect(find.text('السعودية'), findsNWidgets(2));
    });

    testWidgets('«المجانية فقط» keeps only free links and hides the platforms', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tester.tap(find.text('المجانية فقط'));
      await tester.pumpAndSettle();

      expect(find.text('ON Sport HD'), findsOneWidget);
      expect(find.text('beIN SPORTS 1'), findsNothing);
      expect(find.text('DAZN 1 HD'), findsNothing);
      expect(find.text('منصات وقنوات أخرى'), findsNothing);
    });

    testWidgets('a search opens the groups it matches and finds frequencies by digits',
        (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tester.enterText(find.byType(TextField), '11117');
      await tester.pumpAndSettle();

      // Eutel's group was collapsed; the search shows its match anyway.
      expect(find.text('Eutel One'), findsOneWidget);
      expect(find.text('ON Sport HD'), findsNothing);
    });

    testWidgets('a search with no match says so and offers the way back', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('لا توجد قنوات مطابقة لبحثك'), findsOneWidget);
      expect(find.byType(CarriageRow), findsNothing);
    });

    testWidgets('the search field appears only when there are more than six ways to watch',
        (tester) async {
      answerSatellites();
      answerDetail(
        sampleMatchDetail(carriages: [for (var i = 1; i <= 6; i++) sampleCarriageEntry(id: i)]),
      );
      await open(tester);

      expect(find.byType(SearchField), findsNothing);
    });

    testWidgets('when nothing is on my satellites it says so instead of hiding the part',
        (tester) async {
      answerSatellites();
      answerDetail(
        sampleMatchDetail(
          carriages: [sampleCarriageEntry(id: 3, satellite: hotbirdSatellite)],
        ),
      );
      await open(tester);

      expect(find.text('لا توجد قنوات على أقمارك لهذه المباراة'), findsOneWidget);
      expect(find.text('DAZN 1 HD'), findsNothing);
      expect(find.text('Channel 3'), findsOneWidget);
    });
  });

  group('CarriageRow', () {
    testWidgets('collapsed it shows the readout, the access badge and the satellite',
        (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      // Mine: ON Sport and beIN. The first other satellite is open: DAZN and Eleven.
      expect(find.byType(CarriageRow), findsNWidgets(4));
      expect(find.text('11977'), findsOneWidget);
      expect(find.text('27500'), findsWidgets);
      expect(find.text('مجانية'), findsOneWidget);
      expect(find.text('نسخ التردد'), findsNothing);
    });

    testWidgets('expanded it keeps the readout and adds the details and the actions',
        (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tester.tap(find.text('ON Sport HD'));
      await tester.pumpAndSettle();

      // The readout stays on the open row: it is the answer the screen exists for.
      expect(find.text('11977'), findsOneWidget);
      // The details: the satellite with its English name (which carries the position), the
      // tuning in words, access, then the category.
      expect(find.text('11977 MHz'), findsOneWidget);
      expect(find.text('معدل الترميز'), findsOneWidget);
      expect(find.text('نايل سات'), findsWidgets);
      expect(find.text('Nilesat 7.0W'), findsOneWidget);
      expect(find.text('7.0W'), findsNothing, reason: 'the English name already carries it');
      expect(
        Directionality.of(tester.element(find.text('11977 MHz'))),
        TextDirection.ltr,
        reason: 'the number before its unit (M-R2-1)',
      );
      expect(find.text('الوصول'), findsOneWidget);
      expect(find.text('الفئة'), findsOneWidget);
      expect(find.text('نسخ التردد'), findsOneWidget);
      // No follow action exists before D3, so none is drawn.
      expect(find.text('تابع'), findsNothing);

      await tester.tap(find.text('ON Sport HD'));
      await tester.pumpAndSettle();
      expect(find.text('نسخ التردد'), findsNothing);
    });

    testWidgets('the access row names the provider and the package when there are any',
        (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tester.tap(find.text('beIN SPORTS 1'));
      await tester.pumpAndSettle();

      expect(
        find.text('مشفرة · beIN'),
        findsWidgets,
        reason: 'the collapsed badge and the access row',
      );
      expect(find.text('beIN Sports'), findsOneWidget, reason: 'the package');
      expect(
        Directionality.of(tester.element(find.text('beIN Sports'))),
        TextDirection.ltr,
        reason: 'a Latin package is an island',
      );
    });

    testWidgets('copy puts «11977 V 27500» on the clipboard and says so', (tester) async {
      final copied = mockClipboard(tester);
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tester.tap(find.text('ON Sport HD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('نسخ التردد'));
      await tester.pump();

      expect(copied(), '11977 V 27500');
      expect(find.text('تم نسخ التردد'), findsOneWidget);
    });

    testWidgets('the reception video opens the satellite\'s link outside the app', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tapChannel(tester, 'DAZN 1 HD');
      await tester.tap(find.text('فيديو الاستقبال'));
      await tester.pumpAndSettle();

      expect(opener.opened, [Uri.parse(_receptionUrl)]);
    });

    testWidgets('a satellite with no reception video has no such action', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      // Nilesat's catalogue entry has no reception_url.
      await tester.tap(find.text('ON Sport HD'));
      await tester.pumpAndSettle();

      expect(find.text('نسخ التردد'), findsOneWidget);
      expect(find.text('فيديو الاستقبال'), findsNothing);
    });

    testWidgets('a reception link that is not https is never offered', (tester) async {
      api.answer(
        _satellitesPath,
        satellitesJson([
          sampleSatelliteEntry(sampleSatellite),
          sampleSatelliteEntry(hotbirdSatellite, receptionUrl: 'http://video.test/plain'),
        ]),
      );
      answerDetail(standard());
      await open(
        tester,
        overrides: [
          chosenSatelliteIdsProvider.overrideWithValue({sampleSatellite.id, badrSatellite.id}),
        ],
      );

      await tapChannel(tester, 'DAZN 1 HD');

      expect(find.text('نسخ التردد'), findsOneWidget);
      expect(find.text('فيديو الاستقبال'), findsNothing);
    });

    testWidgets('a link the device cannot open says so', (tester) async {
      opener.succeeds = false;
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tapChannel(tester, 'DAZN 1 HD');
      await tester.tap(find.text('فيديو الاستقبال'));
      await tester.pumpAndSettle();

      expect(find.text('تعذّر فتح الرابط'), findsOneWidget);
    });

    testWidgets('the satellite list failing does not hide the channels', (tester) async {
      api.offline(_satellitesPath);
      answerDetail(standard());
      await open(
        tester,
        overrides: [
          chosenSatelliteIdsProvider.overrideWithValue({sampleSatellite.id, badrSatellite.id}),
        ],
      );

      expect(find.byType(CarriageRow), findsWidgets);
      await tapChannel(tester, 'DAZN 1 HD');
      expect(find.text('فيديو الاستقبال'), findsNothing);
    });
  });

  group('commentators', () {
    testWidgets('a carriage lists its commentators with a voice clip, one clip at a time',
        (tester) async {
      const other = CommentatorRef(
        id: 32,
        name: 'خالد الغندور',
        image: null,
        audio: 'https://media.test/clips/ghandour.mp3',
      );
      answerSatellites();
      answerDetail(
        sampleMatchDetail(
          carriages: [
            sampleCarriageEntry(id: 1, commentators: [sampleCommentator]),
            sampleCarriageEntry(id: 2, commentators: [other], name: 'Second'),
          ],
        ),
      );
      await open(tester);

      expect(find.text('عصام الشوالي'), findsOneWidget);
      expect(find.text('خالد الغندور'), findsOneWidget);

      await tester.tap(find.byTooltip('تشغيل مقطع صوتي لـ عصام الشوالي'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('إيقاف المقطع'), findsOneWidget);

      await tester.tap(find.byTooltip('تشغيل مقطع صوتي لـ خالد الغندور'));
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('إيقاف المقطع'), findsOneWidget);
      expect(engine.started, [sampleCommentator.audio, other.audio]);
    });

    testWidgets('leaving the screen stops a clip that is playing', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);
      final scope = container(tester);

      await tester.tap(find.byTooltip('تشغيل مقطع صوتي لـ عصام الشوالي'));
      await tester.pump();
      await tester.pump();
      expect(scope.read(clipControllerProvider).phase, ClipPhase.playing);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();

      expect(scope.read(clipControllerProvider).phase, ClipPhase.idle);
      expect(engine.calls.last, 'stop');
    });
  });

  group('the other cards', () {
    testWidgets('manual broadcasters: the first is «يعرض على», the rest «يعرض أيضاً على»',
        (tester) async {
      answerSatellites();
      answerDetail(
        standard(
          broadcasts: [
            sampleCustomBroadcast('أون سبورت', access: Access.free, commentators: const [sampleCommentator]),
            sampleCustomBroadcast('قناة الشباب'),
            // A channel entry repeats a carriage already listed below: no second card.
            const BroadcastEntry(
              kind: BroadcastEntryKind.channel,
              channelId: 1,
              label: 'ON Sport HD Entry',
              logo: null,
              access: Access.free,
              satellite: null,
              frequency: null,
              commentators: [],
            ),
          ],
        ),
      );
      await open(tester);

      expect(find.text('يعرض على'), findsOneWidget);
      expect(find.text('يعرض أيضاً على'), findsOneWidget);
      expect(find.text('أون سبورت'), findsOneWidget);
      expect(find.text('قناة الشباب'), findsOneWidget);
      expect(find.text('ON Sport HD Entry'), findsNothing);
    });

    testWidgets('the stadium, the Egyptian broadcaster and the match commentator show with data',
        (tester) async {
      answerSatellites();
      answerDetail(
        sampleMatchDetail(
          stadium: 'استاد القاهرة الدولي',
          localBroadcasterEg: 'أون سبورت',
          commentator: sampleCommentator,
        ),
      );
      await open(tester);

      expect(find.text('معلومات المباراة'), findsOneWidget);
      expect(find.text('الملعب'), findsOneWidget);
      expect(find.text('استاد القاهرة الدولي'), findsOneWidget);
      expect(find.text('القناة الناقلة في مصر'), findsOneWidget);
      expect(find.text('أون سبورت'), findsOneWidget);
      expect(find.text('عصام الشوالي'), findsOneWidget);
    });

    testWidgets('none of them show without data, and neither does their heading', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      expect(find.text('معلومات المباراة'), findsNothing);
      expect(find.text('الملعب'), findsNothing);
      expect(find.text('القناة الناقلة في مصر'), findsNothing);
      expect(find.text('يعرض على'), findsNothing);
    });

    testWidgets('a match commentator already shown inside a card is not listed a second time',
        (tester) async {
      answerSatellites();
      answerDetail(
        sampleMatchDetail(
          commentator: sampleCommentator,
          broadcasts: [sampleCustomBroadcast('أون سبورت', commentators: const [sampleCommentator])],
        ),
      );
      await open(tester);

      expect(find.text('عصام الشوالي'), findsOneWidget);
    });
  });

  group('no channels yet', () {
    testWidgets('says so and offers «تابع المباراة», which follows the match (D3)', (tester) async {
      answerSatellites();
      answerDetail(sampleMatchDetail());
      await open(tester);

      expect(find.text('لم تُضف القنوات الناقلة بعد'), findsOneWidget);
      expect(find.text('ستظهر القنوات والترددات هنا فور إضافتها.'), findsOneWidget);
      expect(find.byType(CarriageRow), findsNothing);

      await tester.tap(find.text('تابع المباراة').last);
      await tester.pumpAndSettle();

      // The follow lands in drift: the reminder will name this match when a channel appears.
      expect(
        (await db.readFollows()).where((row) => row.kind == 'match'),
        hasLength(1),
      );
      expect(find.text('تتابع المباراة'), findsWidgets);
    });

    testWidgets('the toolbar and its filters are not shown with nothing to filter', (tester) async {
      answerSatellites();
      answerDetail(sampleMatchDetail());
      await open(tester);

      expect(find.text('المجانية فقط'), findsNothing);
      expect(find.byType(SearchField), findsNothing);
    });
  });

  group('a long list', () {
    MatchDetail long() => sampleMatchDetail(
          carriages: [
            for (var i = 1; i <= 171; i++)
              sampleCarriageEntry(id: i, satellite: hotbirdSatellite),
          ],
        );

    testWidgets('171 links are built lazily: a screenful while open, none while collapsed',
        (tester) async {
      answerSatellites();
      answerDetail(long());
      await open(tester, height: 800);

      expect(find.byType(CarriageRow).evaluate().length, lessThan(20));
      expect(find.byType(CarriageRow), findsWidgets);

      final group = find.byKey(ValueKey('group:sat:${hotbirdSatellite.id}'));
      await tester.tap(group);
      await tester.pumpAndSettle();
      expect(find.byType(CarriageRow), findsNothing);

      await tester.tap(group);
      await tester.pumpAndSettle();
      expect(find.byType(CarriageRow).evaluate().length, lessThan(20));
    });

    testWidgets('scrolling reaches the last link', (tester) async {
      answerSatellites();
      answerDetail(long());
      await open(tester, height: 800);

      await tester.scrollUntilVisible(find.text('Channel 171'), 1000, scrollable: page());

      expect(find.text('Channel 171'), findsOneWidget);
    });

    testWidgets('the back-to-top button appears after two screen heights and scrolls to the top',
        (tester) async {
      answerSatellites();
      answerDetail(long());
      await open(tester, height: 800);
      final button = find.text('العودة لأعلى القنوات');
      expect(button, findsNothing);

      // One screen of scrolling (the view is 800 high) is not enough.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(button, findsNothing);

      // Past two screens (1600) it shows.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(scrollOffset(tester), greaterThan(1600));
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(scrollOffset(tester), 0);
      expect(button, findsNothing);
    });

    testWidgets('a short list never shows the button', (tester) async {
      answerSatellites();
      answerDetail(standard());
      await open(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('العودة لأعلى القنوات'), findsNothing);
    });
  });

  group('freshness, offline and failure', () {
    testWidgets('shows a skeleton until the first answer', (tester) async {
      final gate = Completer<void>();
      answerSatellites();
      api.respond(_matchPath, (_) async {
        await gate.future;
        return FakeHttpAdapter.envelope(matchDetailJson(standard()), etag: '"v1"');
      });
      await open(tester, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.byType(Skeleton), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('أين تشاهد'), findsOneWidget);
    });

    testWidgets('a copy older than five minutes shows its age', (tester) async {
      await seedCache(standard(), age: const Duration(minutes: 10));
      answerSatellites();
      api.offline(_matchPath);
      await open(tester);

      expect(find.byType(StaleHint), findsOneWidget);
      expect(find.text('آخر تحديث منذ 10 د'), findsOneWidget);
    });

    testWidgets('a fresh copy shows no age', (tester) async {
      await seedCache(standard(), age: const Duration(minutes: 1));
      answerSatellites();
      api.offline(_matchPath);
      await open(tester);

      expect(find.byType(StaleHint), findsNothing);
    });

    testWidgets('a 304 confirms an old copy, so its age goes away', (tester) async {
      await seedCache(standard(), age: const Duration(hours: 2));
      answerSatellites();
      api.notModified(_matchPath);
      await open(tester);

      expect(find.byType(StaleHint), findsNothing);
      expect(api.requestsTo(_matchPath), hasLength(1));
      final sent = api.requestsTo(_matchPath).single.headers.entries.firstWhere(
            (entry) => entry.key.toLowerCase() == 'if-none-match',
          );
      expect(sent.value, '"v1"');
    });

    testWidgets('offline with a copy keeps the copy on screen', (tester) async {
      await seedCache(standard(), age: const Duration(minutes: 30));
      answerSatellites();
      api.offline(_matchPath);
      await open(tester);

      expect(find.text('ON Sport HD'), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
      expect(find.text('آخر تحديث منذ 30 د'), findsOneWidget);
    });

    testWidgets('offline with no copy says there is no connection and can retry', (tester) async {
      answerSatellites();
      api.offline(_matchPath);
      answerDetail(standard());
      await open(tester);

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.byType(CarriageRow), findsNothing);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
      expect(find.text('ON Sport HD'), findsOneWidget);
      expect(api.requestsTo(_matchPath), hasLength(2));
    });

    testWidgets('an API error is shown as Arabic copy for its code, never its message',
        (tester) async {
      answerSatellites();
      api.failWith(_matchPath, 'match_not_found');
      await open(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('تعذّر تحميل البيانات'), findsOneWidget);
      expect(find.text('لم نجد ما تبحث عنه'), findsOneWidget);
      expect(find.textContaining('for logs only'), findsNothing);
    });

    testWidgets('the match is revalidated every 60 seconds while the screen is open',
        (tester) async {
      answerSatellites();
      answerDetail(standard());
      api.notModified(_matchPath);
      await open(tester);
      expect(api.requestsTo(_matchPath), hasLength(1));

      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();

      expect(api.requestsTo(_matchPath), hasLength(2));
      expect(find.text('ON Sport HD'), findsOneWidget);
    });

    testWidgets('a satellite catalogue that failed to load is asked for again on the next poll',
        (tester) async {
      // Opened offline: the match is cached or served, but the catalogue fails once.
      api.offline(_satellitesPath);
      answerSatellites();
      answerDetail(standard());
      api.notModified(_matchPath);
      await open(
        tester,
        overrides: [
          chosenSatelliteIdsProvider.overrideWithValue({sampleSatellite.id, badrSatellite.id}),
        ],
      );
      await tapChannel(tester, 'DAZN 1 HD');
      expect(find.text('فيديو الاستقبال'), findsNothing);

      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();

      // Without the retry the reception links would stay off for the whole session.
      expect(api.requestsTo(_satellitesPath), hasLength(2));
      expect(find.text('فيديو الاستقبال'), findsOneWidget);
    });
  });

  testWidgets('every number is a Western digit', (tester) async {
    answerSatellites();
    answerDetail(
      standard(stadium: 'استاد القاهرة الدولي'),
    );
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
