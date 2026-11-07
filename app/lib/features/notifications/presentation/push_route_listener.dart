import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/push_routes.dart';
import '../data/push_routes.dart';

/// Goes where a push names. S6 is a sheet, so it opens over S1 rather than alone (R14).
void openPushRoute(GoRouter router, PushRoute route) {
  if (route.opensAsSheet) {
    router.go('/');
    unawaited(router.push<void>(route.location));
  } else {
    router.go(route.location);
  }
}

/// Opens the route a tapped push names (FR-059, contract app-screens), and nothing for a
/// message with no route or one this build refuses.
///
/// It sits inside the router's builder, so a deep link lands on the screen it names whatever
/// tab was open.
class PushRouteListener extends ConsumerWidget {
  const PushRouteListener({super.key, required this.child, required this.router});

  final Widget child;

  /// The app's router, passed in rather than read from the context: a message can arrive
  /// before the first frame of a pushed route, and the router is the one thing that is
  /// always there.
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(pushRoutesProvider, (_, next) {
      final tap = next.value;
      final route = tap == null ? null : parsePushRoute(tap.route);
      if (route != null) openPushRoute(router, route);
    });
    return child;
  }
}
