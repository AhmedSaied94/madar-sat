import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/features/favorites/data/favorites_providers.dart';
import 'package:madar_sat/features/favorites/presentation/favorites_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../../fixtures/sample_models.dart';

/// S9 (US2 scenario 8, contract app-screens): «مبارياتي القادمة» shows the next three
/// matches of the followed teams and matches, the Teams and Competitions sections list them
/// with a remove and open S7 and S8, and the sections whose follow actions do not exist yet
/// stay hidden.
void main() {
  final now = sampleNow();
  final today = DateTime(now.year, now.month, now.day);

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      now: () => now,
      offsetAt: (_) => const Duration(hours: 3),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seed() async {
    await database.replaceDay(
      today,
      [
        for (var i = 0; i < 4; i++)
          sampleMatch(id: 100 + i, kickoff: now.add(Duration(hours: 2 + i)).toUtc()),
      ],
      etag: null,
      fetchedAt: now.toUtc(),
    );
  }

  CompetitionDetail competition(int id, String name) => CompetitionDetail(
        id: id,
        sport: Sport.football,
        name: name,
        logo: null,
        priority: 1,
        upcoming: const [],
        recent: const [],
        rightsHolders: const [],
      );

  TeamDetail team(int id, String name) => TeamDetail(
        competitions: const [],
        country: null,
        id: id,
        logo: null,
        name: name,
        primaryCompetition: const PrimaryCompetitionRef(id: 3, name: 'الدوري المصري الممتاز'),
        recent: const [],
        sport: Sport.football,
        stadium: null,
        upcoming: const [],
      );

  Widget app() {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const FavoritesPage()),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) => Text('match ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/onboarding/teams',
          builder: (context, state) => const Text('teams picker'),
        ),
        GoRoute(path: '/team/:id', builder: (context, state) => Text('team ${state.pathParameters['id']}')),
        GoRoute(
          path: '/competition/:id',
          builder: (context, state) => Text('competition ${state.pathParameters['id']}'),
        ),
        GoRoute(path: '/more', builder: (context, state) => const Text('more')),
        GoRoute(path: '/settings', builder: (context, state) => const Text('settings')),
      ],
    );
    return MaterialApp.router(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: MadarTheme.dark,
      routerConfig: router,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    List<TeamDetail> teams = const [],
    List<CompetitionDetail> competitions = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => now),
          favoriteTeamsProvider.overrideWith((ref) async => teams),
          favoriteCompetitionsProvider.overrideWith((ref) async => competitions),
        ],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing followed, the empty state offers «أضف فرقاً»', (tester) async {
    await pump(tester);

    expect(find.text('لم تتابع شيئاً بعد'), findsOneWidget);
    expect(find.text('أضف فرقاً'), findsOneWidget);
  });

  testWidgets('the next three matches of a followed team show, and no other sections',
      (tester) async {
    await seed();
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    await pump(tester, teams: [team(1, 'الأهلي')]);

    expect(find.text('مبارياتي القادمة'), findsOneWidget);
    // Three of the four seeded matches: the next three by kickoff.
    expect(find.textContaining('×'), findsNWidgets(3));
    expect(find.text('الفرق'), findsOneWidget);
    expect(find.text('الأهلي'), findsOneWidget);

    // A competition is not followed, so its section stays absent (not an empty heading).
    expect(find.text('البطولات'), findsNothing);
    expect(find.text('القنوات'), findsNothing);
    expect(find.text('المعلّقون'), findsNothing);
  });

  testWidgets('a followed competition is listed and opens S8', (tester) async {
    await database.setFollow(kind: 'competition', targetId: 12, on: true);
    await pump(tester, competitions: [competition(12, 'الدوري المصري الممتاز')]);

    expect(find.text('البطولات'), findsOneWidget);
    expect(find.text('الدوري المصري الممتاز'), findsOneWidget);

    await tester.tap(find.text('الدوري المصري الممتاز'));
    await tester.pumpAndSettle();

    expect(find.text('competition 12'), findsOneWidget);
  });

  testWidgets('a followed team is listed and opens S7 (T086, M-R1-2)', (tester) async {
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    await pump(tester, teams: [team(1, 'الأهلي')]);

    await tester.tap(find.text('الأهلي'));
    await tester.pumpAndSettle();

    expect(find.text('team 1'), findsOneWidget);
  });

  testWidgets('removing a competition unfollows it', (tester) async {
    await database.setFollow(kind: 'competition', targetId: 12, on: true);
    await pump(tester, competitions: [competition(12, 'الدوري المصري الممتاز')]);

    await tester.tap(find.byTooltip('إزالة الدوري المصري الممتاز من المفضلة'));
    await tester.pumpAndSettle();

    expect(
      (await database.readFollows()).where((row) => row.kind == 'competition'),
      isEmpty,
    );
    expect(find.text('البطولات'), findsNothing);
  });

  testWidgets('a followed match is in the list too, even without a followed team',
      (tester) async {
    await seed();
    await database.setFollow(kind: 'match', targetId: 102, on: true);
    await pump(tester);

    expect(find.textContaining('×'), findsOneWidget);
  });

  testWidgets('removing a team unfollows it and empties the screen', (tester) async {
    await seed();
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    await pump(tester, teams: [team(1, 'الأهلي')]);

    await tester.tap(find.byTooltip('إزالة الأهلي من المفضلة'));
    await tester.pumpAndSettle();

    expect(
      (await database.readFollows()).where((row) => row.kind == 'team'),
      isEmpty,
    );
    expect(find.text('لم تتابع شيئاً بعد'), findsOneWidget);
  });

  testWidgets('a card opens its match', (tester) async {
    await seed();
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    await pump(tester);

    await tester.tap(find.textContaining('×').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('match '), findsOneWidget);
  });
}
