import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:go_router/go_router.dart';

import '../../features/frequencies/presentation/frequencies_page.dart';
import '../../features/frequencies/presentation/satellite_channels_page.dart';
import '../../features/gallery/presentation/gallery_page.dart';
import '../../features/match_detail/presentation/match_detail_page.dart';
import '../../features/matches/presentation/matches_page.dart';
import '../../features/my_satellites/presentation/my_satellites_page.dart';
import '../../features/shell/presentation/stub_page.dart';

/// Ids are positive whole numbers of at most ten digits. `int.tryParse` alone would also
/// take `-5`, `+5`, ` 5` and `0x10`.
final RegExp _idPattern = RegExp(r'^[1-9]\d{0,9}$');

/// A path whose `:id` is not an id is a dead link: it goes home instead of building a
/// screen with an id it cannot use.
String? _requireIntegerId(BuildContext context, GoRouterState state) =>
    _idPattern.hasMatch(state.pathParameters['id'] ?? '') ? null : '/';

int _idOf(GoRouterState state) => int.parse(state.pathParameters['id']!);

/// Every PB §8.4 route. `/`, `/match/:id`, `/my-satellites`, `/satellites` and
/// `/satellites/:id` are the D2 screens (S2–S5); the rest are stubs until their day.
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
        redirect: _requireIntegerId,
        builder: (context, state) => MatchDetailPage(matchId: _idOf(state)),
      ),
      GoRoute(path: '/my-satellites', builder: (context, state) => const MySatellitesPage()),
      GoRoute(path: '/satellites', builder: (context, state) => const FrequenciesPage()),
      GoRoute(
        path: '/satellites/:id',
        redirect: _requireIntegerId,
        builder: (context, state) => SatelliteChannelsPage(satelliteId: _idOf(state)),
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
