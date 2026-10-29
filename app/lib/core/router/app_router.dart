import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/gallery/presentation/gallery_page.dart';
import '../../features/matches/presentation/matches_page.dart';
import '../../features/shell/presentation/stub_page.dart';

/// Every PB §8.4 route. Detail screens are stubs on D1; `/` is the matches route.
///
/// `/gallery` is registered only in debug builds (FR-045).
GoRouter createAppRouter({bool? includeGallery}) {
  final gallery = includeGallery ?? kDebugMode;
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MatchesPage()),
      GoRoute(path: '/live', builder: (context, state) => const StubPage(title: '/live')),
      GoRoute(
        path: '/day/:date',
        builder: (context, state) => StubPage(title: '/day/${state.pathParameters['date']}'),
      ),
      GoRoute(
        path: '/match/:id',
        builder: (context, state) => StubPage(title: '/match/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/my-satellites',
        builder: (context, state) => const StubPage(title: '/my-satellites'),
      ),
      GoRoute(
        path: '/satellites',
        builder: (context, state) => const StubPage(title: '/satellites'),
      ),
      GoRoute(
        path: '/satellites/:id',
        builder: (context, state) => StubPage(title: '/satellites/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/channel/:id',
        builder: (context, state) => StubPage(title: '/channel/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/team/:id',
        builder: (context, state) => StubPage(title: '/team/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/competition/:id',
        builder: (context, state) =>
            StubPage(title: '/competition/${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/favorites',
        builder: (context, state) => const StubPage(title: '/favorites'),
      ),
      GoRoute(path: '/rights', builder: (context, state) => const StubPage(title: '/rights')),
      GoRoute(
        path: '/rights/:id',
        builder: (context, state) => StubPage(title: '/rights/${state.pathParameters['id']}'),
      ),
      GoRoute(path: '/feeds', builder: (context, state) => const StubPage(title: '/feeds')),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            StubPage(title: '/search?q=${state.uri.queryParameters['q'] ?? ''}'),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const StubPage(title: '/settings')),
      GoRoute(
        path: '/settings/:section',
        builder: (context, state) =>
            StubPage(title: '/settings/${state.pathParameters['section']}'),
      ),
      GoRoute(path: '/install', builder: (context, state) => const StubPage(title: '/install')),
      if (gallery)
        GoRoute(path: '/gallery', builder: (context, state) => const GalleryPage()),
    ],
  );
}
