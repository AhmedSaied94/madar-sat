import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:madar_sat/core/platform/push_routes.dart';
import 'package:madar_sat/core/platform/push_service.dart';
import 'package:madar_sat/features/notifications/presentation/push_route_listener.dart';

import 'push_route_table.dart';

class _FakePushService extends NoPushService {
  const _FakePushService(this._routes);

  final Stream<String> _routes;

  @override
  Stream<String> get openedRoutes => _routes;
}

/// A tapped push names a route and the app opens it (FR-059, contract app-screens): only the
/// four exact shapes, and anything else opens the app and goes nowhere.
void main() {
  group('parsePushRoute', () {
    for (final route in acceptedPushRoutes) {
      test('accepts $route', () => expect(parsePushRoute(route)?.location, route));
    }
    for (final route in refusedPushRoutes) {
      test('refuses "$route"', () => expect(parsePushRoute(route), isNull));
    }

    test('only a channel route needs a screen under it', () {
      expect(parsePushRoute('/channel/5')!.opensAsSheet, isTrue);
      expect(parsePushRoute('/match/5')!.opensAsSheet, isFalse);
      expect(parsePushRoute('/')!.opensAsSheet, isFalse);
    });
  });

  Future<GoRouter> pump(WidgetTester tester, Stream<String> routes) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Text('home')),
        GoRoute(
          path: '/match/:id',
          builder: (context, state) => Text(
            'match ${state.pathParameters['id']} ${state.uri.queryParameters['section'] ?? ''}'
                .trim(),
          ),
        ),
        GoRoute(
          path: '/channel/:id',
          builder: (context, state) => Text('channel ${state.pathParameters['id']}'),
        ),
        GoRoute(path: '/more', builder: (context, state) => const Text('more')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pushServiceProvider.overrideWithValue(_FakePushService(routes))],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => PushRouteListener(router: router, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a match route opens S3, keeping its section', (tester) async {
    final routes = StreamController<String>();
    addTearDown(routes.close);
    await pump(tester, routes.stream);

    routes.add('/match/7?section=channels');
    await tester.pumpAndSettle();

    expect(find.text('match 7 channels'), findsOneWidget);
  });

  testWidgets('a channel route opens S6 with S1 under it', (tester) async {
    final routes = StreamController<String>();
    addTearDown(routes.close);
    final router = await pump(tester, routes.stream);
    router.go('/more');
    await tester.pumpAndSettle();

    routes.add('/channel/5');
    await tester.pumpAndSettle();

    expect(find.text('channel 5'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a second tap on the same route opens it again', (tester) async {
    final routes = StreamController<String>();
    addTearDown(routes.close);
    final router = await pump(tester, routes.stream);

    routes.add('/match/7');
    await tester.pumpAndSettle();
    router.go('/more');
    await tester.pumpAndSettle();
    expect(find.text('more'), findsOneWidget);

    routes.add('/match/7');
    await tester.pumpAndSettle();

    expect(find.text('match 7'), findsOneWidget);
  });

  testWidgets('a route this build does not know opens nothing', (tester) async {
    final routes = StreamController<String>();
    addTearDown(routes.close);
    await pump(tester, routes.stream);

    for (final route in ['not-a-route', '/more', '/match/5/x', '//host', 'https://x']) {
      routes.add(route);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget, reason: route);
    }
  });
}
