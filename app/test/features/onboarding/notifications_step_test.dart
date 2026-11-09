import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/features/onboarding/presentation/steps/notifications_step.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

class _FakePush implements PushService {
  _FakePush({required this.canRequestPermission, required this.granted});

  @override
  final bool canRequestPermission;
  final bool granted;

  @override
  Future<PushPermissionState> permission() async => PushPermissionState.allowed;

  @override
  Stream<ForegroundPush> get foregroundMessages => const Stream.empty();
  int prompts = 0;

  @override
  Future<bool> requestPermission() async {
    prompts++;
    return granted;
  }

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String?> get tokenChanges => const Stream.empty();

  @override
  Stream<String> get openedRoutes => const Stream.empty();
}

/// S1.4 (US2 scenario 5, research R26): the OS prompt comes only from the tap, «ليس الآن»
/// finishes without one, and an iPhone Safari tab that cannot be granted push is sent to
/// S1.5 instead.
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pump(WidgetTester tester, _FakePush push, {required String initial}) async {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/notifications', builder: (context, state) => const NotificationsStep()),
        GoRoute(path: '/', builder: (context, state) => const Text('home')),
        GoRoute(path: '/install', builder: (context, state) => const Text('install guide')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          pushServiceProvider.overrideWithValue(push),
        ],
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
  }

  testWidgets('building the step asks for nothing; the tap asks once', (tester) async {
    final push = _FakePush(canRequestPermission: true, granted: true);
    await pump(tester, push, initial: '/notifications');

    expect(push.prompts, 0, reason: 'a prompt must never come from merely opening the step');

    await tester.tap(find.text('تفعيل التنبيهات'));
    await tester.pumpAndSettle();

    expect(push.prompts, 1);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('«ليس الآن» finishes without prompting', (tester) async {
    final push = _FakePush(canRequestPermission: true, granted: true);
    await pump(tester, push, initial: '/notifications');

    await tester.tap(find.text('ليس الآن'));
    await tester.pumpAndSettle();

    expect(push.prompts, 0);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('an iPhone tab that cannot be granted push is sent to S1.5', (tester) async {
    final push = _FakePush(canRequestPermission: false, granted: false);
    await pump(tester, push, initial: '/notifications');

    await tester.tap(find.text('تفعيل التنبيهات'));
    await tester.pumpAndSettle();

    expect(push.prompts, 0);
    expect(find.text('install guide'), findsOneWidget);
  });

  testWidgets('the step marks onboarding done once it finishes', (tester) async {
    final push = _FakePush(canRequestPermission: true, granted: true);
    await pump(tester, push, initial: '/notifications');

    await tester.tap(find.text('ليس الآن'));
    await tester.pumpAndSettle();

    expect(await database.readSetting('onboarding.done'), 'true');
  });
}
