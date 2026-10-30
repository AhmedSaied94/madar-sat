import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/router/app_router.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/features/gallery/presentation/gallery_page.dart';
import 'package:madar_sat/features/matches/data/matches_api.dart';
import 'package:madar_sat/features/matches/presentation/matches_page.dart';
import 'package:madar_sat/features/matches/presentation/matches_providers.dart';
import 'package:madar_sat/features/shell/presentation/stub_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/fake_api_client.dart';
import '../../fixtures/sample_models.dart';

Widget _app(GoRouter router, {List<MatchSummary> rows = const []}) => ProviderScope(
      overrides: [
        matchesApiProvider.overrideWithValue(MatchesApi(FakeApiClient(rows: rows))),
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

void main() {
  const routes = [
    '/live',
    '/day/2026-10-28',
    '/match/1',
    '/my-satellites',
    '/satellites',
    '/satellites/1',
    '/channel/1',
    '/team/1',
    '/competition/1',
    '/favorites',
    '/rights',
    '/rights/1',
    '/feeds',
    '/search?q=الأهلي',
    '/settings',
    '/settings/theme',
    '/install',
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

    expect(find.byType(StubPage), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(MatchesPage), findsOneWidget);
    expect(find.byType(StubPage), findsNothing);
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
