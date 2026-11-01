import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/platform/secure_store.dart';
import 'package:madar_sat/core/settings/app_settings.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/features/settings/presentation/settings_page.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

class _MemoryStore implements SecureStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// S15 core (US2 scenario 10, contract app-screens): the time zone, the clock format, the
/// theme and the font size are written to drift and read back; deleting the device data asks
/// first, then clears everything and starts the app over.
void main() {
  late AppDatabase database;
  late _MemoryStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    store = _MemoryStore();
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, {String? section}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          secureStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: MadarTheme.dark,
          routerConfig: GoRouter(
            initialLocation: '/settings',
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => SettingsPage(section: section),
              ),
              GoRoute(
                path: '/settings/satellites',
                builder: (context, state) => const SettingsPage(section: 'satellites'),
              ),
              GoRoute(
                path: '/onboarding/welcome',
                builder: (context, state) => const Text('onboarding'),
              ),
              GoRoute(path: '/more', builder: (context, state) => const Text('more')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the clock format follows the segmented control at once', (tester) async {
    await pump(tester);

    await tester.tap(find.textContaining('24 ساعة'));
    await tester.pumpAndSettle();

    expect(await database.readSetting(SettingsKeys.timeFormat), 'h24');
  });

  testWidgets('the theme and the font size are written', (tester) async {
    await pump(tester);

    await tester.tap(find.text('فاتح'));
    await tester.pumpAndSettle();
    expect(await database.readSetting(SettingsKeys.theme), 'light');

    await tester.tap(find.text('كبير جداً'));
    await tester.pumpAndSettle();
    expect(await database.readSetting(SettingsKeys.fontScale), 'xlarge');
  });

  testWidgets('the time zone sheet offers automatic and every GMT hour', (tester) async {
    await pump(tester);

    await tester.tap(find.text('المنطقة الزمنية'));
    await tester.pumpAndSettle();

    expect(find.text('GMT−12'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('GMT+2'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('GMT+2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GMT+2'));
    await tester.pumpAndSettle();

    expect(await database.readSetting(SettingsKeys.zoneOffsetMinutes), '120');
    expect(find.textContaining('GMT+2'), findsOneWidget);
  });

  testWidgets('my satellites opens S1.3 as a settings section', (tester) async {
    await pump(tester);

    await tester.tap(find.text('اختر أقماري'));
    await tester.pumpAndSettle();

    expect(find.text('اختر الأقمار التي يستقبلها طبقك'), findsOneWidget);
  });

  testWidgets('deleting the device asks first, then clears drift and storage', (tester) async {
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    await database.writeSetting(SettingsKeys.theme, 'light');
    store.values[SecureKeys.deviceToken] = 'token-1';
    await pump(tester);

    await scrollTo(tester, 'حذف بيانات جهازي');
    await tester.tap(find.text('حذف بيانات جهازي'));
    await tester.pumpAndSettle();

    expect(find.text('حذف بيانات جهازي؟'), findsOneWidget);
    expect(
      find.text('سنحذف متابعاتك ورمز الإشعارات من الخادم، وسيبدأ التطبيق من جديد.'),
      findsOneWidget,
    );

    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();

    expect(await database.readFollows(), isEmpty);
    expect(await database.readSettings(), isEmpty);
    expect(store.values[SecureKeys.deviceToken], isNull);
    expect(find.text('onboarding'), findsOneWidget);
  });

  testWidgets('cancelling the dialog keeps everything', (tester) async {
    await database.setFollow(kind: 'team', targetId: 1, on: true);
    await pump(tester);

    await scrollTo(tester, 'حذف بيانات جهازي');
    await tester.tap(find.text('حذف بيانات جهازي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect((await database.readFollows()).length, 1);
  });

  testWidgets('reopening the onboarding steps never resets the flag', (tester) async {
    await database.writeSetting(SettingsKeys.onboardingDone, 'true');
    await pump(tester);

    await scrollTo(tester, 'إعادة خطوات البداية');
    await tester.tap(find.text('إعادة خطوات البداية'));
    await tester.pumpAndSettle();

    expect(find.text('onboarding'), findsOneWidget);
    expect(await database.readSetting(SettingsKeys.onboardingDone), 'true');
  });
}
