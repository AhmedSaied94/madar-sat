import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../features/channel/presentation/channel_sheet.dart';
import '../../features/competition/presentation/competition_page.dart';
import '../../features/favorites/presentation/favorites_page.dart';
import '../../features/frequencies/presentation/frequencies_page.dart';
import '../../features/frequencies/presentation/satellite_channels_page.dart';
import '../../features/gallery/presentation/gallery_page.dart';
import '../../features/match_detail/presentation/match_detail_page.dart';
import '../../features/matches/presentation/matches_page.dart';
import '../../features/more/presentation/more_page.dart';
import '../../features/my_satellites/presentation/my_satellites_page.dart';
import '../../features/onboarding/domain/onboarding_step.dart';
import '../../features/onboarding/presentation/install_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/presentation/stub_page.dart';
import '../../features/system/presentation/system_views.dart';
import '../../features/team/presentation/team_page.dart';

/// Ids are positive whole numbers of at most ten digits. `int.tryParse` alone would also
/// take `-5`, `+5`, ` 5` and `0x10`.
final RegExp _idPattern = RegExp(r'^[1-9]\d{0,9}$');

/// A path whose `:id` is not an id is a dead link: it goes home instead of building a
/// screen with an id it cannot use.
String? _requireIntegerId(BuildContext context, GoRouterState state) =>
    _idPattern.hasMatch(state.pathParameters['id'] ?? '') ? null : '/';

int _idOf(GoRouterState state) => int.parse(state.pathParameters['id']!);

/// Every PB §8.4 route. S2–S5 are D2's; D3 adds onboarding, S9, S15, S16, S1.5, the forced
/// update and pushes' `/match/:id`.
///
/// [guard] decides where a location must really go: a build below `min_supported_build`
/// goes to the forced-update screen, and a first launch to the stored onboarding step. It is
/// re-run on settings changes through the router's refresh listener.
///
/// `/gallery` is registered only in debug builds (FR-045).
GoRouter createAppRouter({
  bool? includeGallery,
  String? Function(String location)? guard,
  Listenable? refreshListenable,
}) {
  final gallery = includeGallery ?? kDebugMode;
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) => guard?.call(state.matchedLocation),
    routes: [
      // The five root tabs carry S0's exit rule: a back press on any of them shows the
      // snackbar, and a second press within the window leaves the app (US2 scenario 13).
      GoRoute(
        path: '/',
        builder: (context, state) => const ExitGuard(child: MatchesPage()),
      ),
      GoRoute(path: '/live', builder: (context, state) => const StubPage(title: '/live')),
      GoRoute(
        path: '/day/:date',
        builder: (context, state) => StubPage(title: '/day/${state.pathParameters['date']}'),
      ),
      GoRoute(
        path: '/match/:id',
        redirect: _requireIntegerId,
        builder: (context, state) => MatchDetailPage(
          matchId: _idOf(state),
          section: state.uri.queryParameters['section'],
        ),
      ),
      GoRoute(
        path: '/my-satellites',
        builder: (context, state) => const ExitGuard(child: MySatellitesPage()),
      ),
      GoRoute(
        path: '/satellites',
        builder: (context, state) => const ExitGuard(child: FrequenciesPage()),
      ),
      GoRoute(
        path: '/satellites/:id',
        redirect: _requireIntegerId,
        builder: (context, state) => SatelliteChannelsPage(satelliteId: _idOf(state)),
      ),
      GoRoute(
        path: '/channel/:id',
        redirect: _requireIntegerId,
        // A modal sheet, not a pushed page: the screen it was opened from stays behind it, and
        // the sheet rises from the bottom. It is still a route, so `/channel/12` is a deep link
        // a notification can open (§S6).
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          opaque: false,
          child: ChannelSheetPage(channelId: _idOf(state)),
          transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic)),
            ),
            child: child,
          ),
        ),
      ),
      GoRoute(
        path: '/team/:id',
        redirect: _requireIntegerId,
        builder: (context, state) => TeamPage(teamId: _idOf(state)),
      ),
      GoRoute(
        path: '/competition/:id',
        redirect: _requireIntegerId,
        builder: (context, state) => CompetitionPage(competitionId: _idOf(state)),
      ),
      // S9 and S16 carry the same rule inside their pages; these three are wrapped here, so
      // every root tab answers a back press the same way.
      GoRoute(path: '/favorites', builder: (context, state) => const FavoritesPage()),
      GoRoute(path: '/more', builder: (context, state) => const MorePage()),
      GoRoute(
        path: '/rights',
        builder: (context, state) => const StubPage(title: '/rights'),
      ),
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
      GoRoute(path: '/settings', builder: (context, state) => const SettingsPage()),
      GoRoute(
        path: '/settings/:section',
        builder: (context, state) =>
            SettingsPage(section: state.pathParameters['section']),
      ),
      GoRoute(
        path: '/onboarding/:step',
        builder: (context, state) =>
            OnboardingPage(step: OnboardingStep.fromSlug(state.pathParameters['step'])),
      ),
      GoRoute(path: '/install', builder: (context, state) => const InstallPage()),
      GoRoute(path: '/update-required', builder: (context, state) => const ForcedUpdatePage()),
      if (gallery)
        GoRoute(path: '/gallery', builder: (context, state) => const GalleryPage()),
    ],
  );
}
