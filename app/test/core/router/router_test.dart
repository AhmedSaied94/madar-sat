import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/core/router/app_router.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/features/gallery/presentation/gallery_page.dart';
import 'package:madar_sat/features/frequencies/presentation/frequencies_page.dart';
import 'package:madar_sat/features/frequencies/presentation/satellite_channels_page.dart';
import 'package:madar_sat/features/live/live_poller.dart';
import 'package:madar_sat/features/favorites/data/favorites_providers.dart';
import 'package:madar_sat/features/favorites/presentation/favorites_page.dart';
import 'package:madar_sat/features/match_detail/presentation/match_detail_page.dart';
import 'package:madar_sat/features/more/presentation/more_page.dart';
import 'package:madar_sat/features/onboarding/presentation/install_page.dart';
import 'package:madar_sat/features/onboarding/presentation/onboarding_page.dart';
import 'package:madar_sat/features/settings/presentation/settings_page.dart';
import 'package:madar_sat/features/matches/presentation/matches_page.dart';
import 'package:madar_sat/features/my_satellites/presentation/my_satellites_page.dart';
import 'package:madar_sat/features/shell/presentation/stub_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/sample_models.dart';

/// S2 reads today through the stale-while-revalidate repository: an in-memory database and
/// a scripted adapter that answers every revalidation with [rows], on a pinned clock.
Widget _app(GoRouter router, {List<MatchSummary> rows = const []}) {
  final clock = sampleNow();
  final database = AppDatabase(NativeDatabase.memory(), now: () => clock);
  addTearDown(database.close);
  final http = FakeHttpAdapter();
  final body = jsonDecode(jsonEncode([for (final row in rows) row.toJson()])) as List<Object?>;
  for (var answer = 0; answer < 20; answer++) {
    http.enqueueData(body, etag: '"v$answer"');
  }
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      swrRepositoryProvider.overrideWithValue(
        SwrRepository(dio: fakeDio(http), database: database),
      ),
      clockProvider.overrideWithValue(() => clock),
      // S9's two sections answer at once, so no skeleton is animating when the route test
      // settles (a repeating skeleton never settles).
      favoriteUpcomingProvider.overrideWith((ref) async => const <MatchSummary>[]),
      favoriteTeamsProvider.overrideWith((ref) async => const <TeamDetail>[]),
      liveFetcherProvider.overrideWithValue(() async => const []),
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
  );
}

void main() {
  // The gallery test builds two apps, so two in-memory databases, one after the other.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const routes = [
    '/live',
    '/day/2026-10-28',
    '/channel/1',
    '/team/1',
    '/competition/1',
    '/rights',
    '/rights/1',
    '/feeds',
    '/search?q=الأهلي',
  ];

  for (final route in routes) {
    testWidgets('$route resolves to a stub screen in RTL', (tester) async {
      final router = createAppRouter(includeGallery: false);
      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      router.go(route);
      await tester.pumpAndSettle();

      expect(find.byType(StubPage), findsOneWidget);
      expect(
        tester.widget<StubPage>(find.byType(StubPage)).title,
        startsWith(route.split('?').first),
      );
      final rtl = tester
          .widgetList<Directionality>(find.byType(Directionality))
          .where((widget) => widget.textDirection == TextDirection.rtl);
      expect(rtl, isNotEmpty);
    });
  }

  group('the D2 routes open their screens', () {
    final screens = <String, void Function(WidgetTester tester)>{
      '/match/7': (tester) => expect(
            tester.widget<MatchDetailPage>(find.byType(MatchDetailPage)).matchId,
            7,
          ),
      '/my-satellites': (tester) => expect(find.byType(MySatellitesPage), findsOneWidget),
      '/satellites': (tester) => expect(find.byType(FrequenciesPage), findsOneWidget),
      '/satellites/3': (tester) => expect(
            tester
                .widget<SatelliteChannelsPage>(find.byType(SatelliteChannelsPage))
                .satelliteId,
            3,
          ),
      '/favorites': (tester) => expect(find.byType(FavoritesPage), findsOneWidget),
      '/more': (tester) => expect(find.byType(MorePage), findsOneWidget),
      '/settings': (tester) => expect(find.byType(SettingsPage), findsOneWidget),
      '/settings/theme': (tester) => expect(
            tester.widget<SettingsPage>(find.byType(SettingsPage)).section,
            'theme',
          ),
      '/install': (tester) => expect(find.byType(InstallPage), findsOneWidget),
      '/onboarding/welcome': (tester) => expect(find.byType(OnboardingPage), findsOneWidget),
      '/onboarding/teams': (tester) => expect(find.byType(OnboardingPage), findsOneWidget),
    };

    screens.forEach((route, expectScreen) {
      testWidgets('$route is its own screen, not a stub', (tester) async {
        final router = createAppRouter(includeGallery: false);
        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();

        router.go(route);
        await tester.pumpAndSettle();

        expectScreen(tester);
        expect(find.byType(StubPage), findsNothing);
      });
    });

    // `int.tryParse` alone would let `-5`, `+5`, ` 5` and `0x10` (16) through, and ids are
    // positive whole numbers.
    for (final route in [
      '/match/abc',
      '/match/-5',
      '/match/+5',
      '/match/0x10',
      '/match/0',
      '/match/12345678901',
      '/satellites/abc',
      '/satellites/-1',
      '/satellites/0x2',
    ]) {
      testWidgets('$route has no whole-number id, so it goes home', (tester) async {
        final router = createAppRouter(includeGallery: false);
        await tester.pumpWidget(_app(router));
        await tester.pumpAndSettle();

        router.go(route);
        await tester.pumpAndSettle();

        expect(find.byType(MatchesPage), findsOneWidget);
        expect(router.state.uri.path, '/');
      });
    }
  });

  testWidgets('the detail back arrow points right in RTL', (tester) async {
    final router = createAppRouter(includeGallery: false);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.go('/live');
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_back));
    expect(icon.icon?.matchTextDirection, isTrue);
  });

  testWidgets('a match row opens its detail with a back arrow that returns to the list',
      (tester) async {
    final router = createAppRouter(includeGallery: false);
    await tester.pumpWidget(_app(router, rows: [sampleMatch()]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الأهلي'));
    await tester.pumpAndSettle();

    expect(tester.widget<MatchDetailPage>(find.byType(MatchDetailPage)).matchId, 48213);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(MatchesPage), findsOneWidget);
    expect(find.byType(MatchDetailPage), findsNothing);
  });

  testWidgets('the gallery route exists only when enabled', (tester) async {
    final withoutGallery = createAppRouter(includeGallery: false);
    await tester.pumpWidget(_app(withoutGallery));
    await tester.pumpAndSettle();
    withoutGallery.go('/gallery');
    await tester.pumpAndSettle();
    expect(find.byType(GalleryPage), findsNothing);

    final withGallery = createAppRouter(includeGallery: true);
    await tester.pumpWidget(_app(withGallery));
    await tester.pumpAndSettle();
    withGallery.go('/gallery');
    await tester.pumpAndSettle();
    expect(find.byType(GalleryPage), findsOneWidget);
  });
}
