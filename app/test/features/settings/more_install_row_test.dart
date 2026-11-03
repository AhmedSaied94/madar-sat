import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/platform/install_guide.dart';
import 'package:madar_sat/core/platform/install_guide_provider.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/features/more/presentation/more_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

/// S16's install row (FR-036, bug-bash F5): «تثبيت التطبيق» on an iPhone in Safari that has
/// not installed the PWA, opening S1.5, and nothing on Android, the web (Android/desktop)
/// or an installed app.
class _Guide implements InstallGuide {
  const _Guide({required this.isWeb, required this.isInstalled, required this.needsInstallSteps});

  @override
  final bool isWeb;
  @override
  final bool isInstalled;
  @override
  final bool needsInstallSteps;
}

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
  });
  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester, InstallGuide guide) async {
    final router = GoRouter(
      initialLocation: '/more',
      routes: [
        GoRoute(path: '/more', builder: (context, state) => const MorePage()),
        GoRoute(path: '/install', builder: (context, state) => const Text('S1.5')),
        GoRoute(path: '/settings', builder: (context, state) => const Text('settings')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          installGuideProvider.overrideWithValue(guide),
        ],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: MadarTheme.dark,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an uninstalled iPhone in Safari shows «تثبيت التطبيق» and opens S1.5', (
    tester,
  ) async {
    await pump(
      tester,
      const _Guide(isWeb: true, isInstalled: false, needsInstallSteps: true),
    );

    expect(find.text('تثبيت التطبيق'), findsOneWidget);
    expect(find.text('لتصلك تنبيهات المباريات وتغيّر الترددات'), findsOneWidget);

    await tester.tap(find.text('تثبيت التطبيق'));
    await tester.pumpAndSettle();

    expect(find.text('S1.5'), findsOneWidget, reason: 'the guide screen');
  });

  testWidgets('an installed PWA and a non-iOS browser show no install row', (tester) async {
    for (final guide in const [
      _Guide(isWeb: true, isInstalled: true, needsInstallSteps: false),
      _Guide(isWeb: true, isInstalled: false, needsInstallSteps: false),
      _Guide(isWeb: false, isInstalled: true, needsInstallSteps: false),
    ]) {
      await pump(tester, guide);
      expect(find.text('تثبيت التطبيق'), findsNothing);
    }
  });
}
