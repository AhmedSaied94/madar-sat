import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/features/onboarding/presentation/install_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

/// S1.5: pushed from S1.4 it takes that step's place, so «فهمت» finishes onboarding and
/// opens home; pushed from S16 it only goes back.
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      now: () => DateTime.utc(2026, 11, 1, 9),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpFrom(WidgetTester tester, String from) async {
    final router = GoRouter(
      initialLocation: from,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Text('home')),
        GoRoute(
          path: from,
          builder: (context, state) => TextButton(
            onPressed: () => context.push('/install'),
            child: Text(from),
          ),
        ),
        GoRoute(
          path: '/install',
          builder: (context, state) => const InstallPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          theme: MadarTheme.dark,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(from));
    await tester.pumpAndSettle();
  }

  testWidgets('from S1.4, «فهمت» finishes onboarding and opens home', (
    tester,
  ) async {
    await pumpFrom(tester, '/onboarding/notifications');

    await tester.tap(find.text('فهمت'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('/onboarding/notifications'), findsNothing);
    expect(await database.readSetting('onboarding.done'), 'true');
  });

  testWidgets('from S16, «فهمت» goes back', (tester) async {
    await database.writeSetting('onboarding.done', 'true');
    await pumpFrom(tester, '/more');

    await tester.tap(find.text('فهمت'));
    await tester.pumpAndSettle();

    expect(find.text('/more'), findsOneWidget);
  });
}
