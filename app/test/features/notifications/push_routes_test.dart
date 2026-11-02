import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/features/notifications/presentation/push_route_listener.dart';

/// A push names a route and the app opens it (US2 scenario 7, contract app-screens): the
/// foreground message and the one that launched the app both arrive on `openedRoutes`.
class _FakePushService implements PushService {
  _FakePushService(this._routes);

  final Stream<String> _routes;

  @override
  bool get canRequestPermission => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String?> get tokenChanges => const Stream.empty();

  @override
  Stream<String> get openedRoutes => _routes;
}

void main() {
  testWidgets('a message route opens its screen through go_router', (tester) async {
    final routes = StreamController<String>();
    addTearDown(routes.close);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Text('home')),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) => Text('match ${state.pathParameters['id']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushServiceProvider.overrideWithValue(_FakePushService(routes.stream)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PushRouteListener(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);

    routes.add('/match/7');
    await tester.pumpAndSettle();

    expect(find.text('match 7'), findsOneWidget);
  });

  testWidgets('a message with no route, or one this build cannot route, changes nothing',
      (tester) async {
    final routes = StreamController<String>();
    addTearDown(routes.close);
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (context, state) => const Text('home'))],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushServiceProvider.overrideWithValue(_FakePushService(routes.stream)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PushRouteListener(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();

    routes.add('not-a-route');
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
