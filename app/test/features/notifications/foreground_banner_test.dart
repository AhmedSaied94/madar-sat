import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/platform/push_routes.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';
import 'package:madar_sat/features/notifications/presentation/foreground_banner.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

class _FakePushService extends NoPushService {
  const _FakePushService(this._messages);

  final Stream<ForegroundPush> _messages;

  @override
  Stream<ForegroundPush> get foregroundMessages => _messages;
}

/// A push received with the app open never moves the fan: it shows a banner, and only «عرض»
/// navigates (FR-059, R14).
class _Counting extends StatefulWidget {
  const _Counting();

  static int created = 0;

  @override
  State<_Counting> createState() => _CountingState();
}

class _CountingState extends State<_Counting> {
  @override
  void initState() {
    super.initState();
    _Counting.created++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  late StreamController<ForegroundPush> messages;
  late GoRouter router;

  setUp(() => messages = StreamController<ForegroundPush>());
  tearDown(() => messages.close());

  Future<void> pump(WidgetTester tester) async {
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('home'))),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) => Scaffold(body: Text('match ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pushServiceProvider.overrideWithValue(_FakePushService(messages.stream))],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: MadarTheme.dark,
          builder: (context, child) => ForegroundBannerHost(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ForegroundPush goal({String? route = '/match/7'}) => ForegroundPush(
        title: 'هدف للأهلي',
        body: 'الأهلي 1 – 0 الزمالك',
        route: route == null ? null : parsePushRoute(route),
      );

  testWidgets('shows the title and body, and stays on the screen', (tester) async {
    await pump(tester);

    messages.add(goal());
    await tester.pumpAndSettle();

    expect(find.text('هدف للأهلي'), findsOneWidget);
    expect(find.text('الأهلي 1 – 0 الزمالك'), findsOneWidget);
    expect(find.text('عرض'), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('only «عرض» navigates', (tester) async {
    await pump(tester);
    messages.add(goal());
    await tester.pumpAndSettle();

    await tester.tap(find.text('هدف للأهلي'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    await tester.tap(find.text('عرض'));
    await tester.pumpAndSettle();
    expect(find.text('match 7'), findsOneWidget);
    expect(find.text('هدف للأهلي'), findsNothing);
  });

  testWidgets('dismissing does not navigate', (tester) async {
    await pump(tester);
    messages.add(goal());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('هدف للأهلي'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('one banner at a time: the newest replaces it', (tester) async {
    await pump(tester);
    messages.add(goal());
    await tester.pumpAndSettle();

    messages.add(const ForegroundPush(title: 'نهاية المباراة', body: 'الأهلي 2 – 0 الزمالك'));
    await tester.pumpAndSettle();

    expect(find.text('هدف للأهلي'), findsNothing);
    expect(find.text('نهاية المباراة'), findsOneWidget);
  });

  testWidgets('showing and dismissing keeps the app under it, so nothing restarts', (tester) async {
    _Counting.created = 0;
    router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink())]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pushServiceProvider.overrideWithValue(_FakePushService(messages.stream))],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: MadarTheme.dark,
          builder: (context, child) =>
              ForegroundBannerHost(router: router, child: const _Counting()),
          home: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_Counting.created, 1);

    messages.add(goal());
    await tester.pumpAndSettle();
    expect(find.text('هدف للأهلي'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(_Counting.created, 1);
  });

  testWidgets('a message with no usable route has no «عرض»', (tester) async {
    await pump(tester);

    messages.add(goal(route: null));
    await tester.pumpAndSettle();

    expect(find.text('هدف للأهلي'), findsOneWidget);
    expect(find.text('عرض'), findsNothing);
  });
}
