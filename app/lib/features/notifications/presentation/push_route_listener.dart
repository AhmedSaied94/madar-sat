import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/push_routes.dart';

/// Opens the route a push names (US2 scenario 7, contract app-screens): `/match/:id` for a
/// kickoff reminder, and nothing for a message with no route or one this build cannot route.
///
/// It sits inside the router's builder, so `context.go` moves the app and a deep link lands
/// on the screen it names whatever tab was open.
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
      final route = next.value;
      if (route == null || !route.startsWith('/')) return;
      final path = route.split('?').first;
      final known = path == '/' ||
          path.startsWith('/match/') ||
          path.startsWith('/favorites') ||
          path.startsWith('/more') ||
          path.startsWith('/settings') ||
          path.startsWith('/my-satellites') ||
          path.startsWith('/satellites');
      if (!known) return;
      router.go(route);
    });
    return child;
  }
}
