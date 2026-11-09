import 'package:flutter/foundation.dart';

/// The route shapes a push may name (contract public-api, research R14): `/`, `/match/<id>`,
/// `/match/<id>?section=channels` and `/channel/<id>`.
///
/// An id follows the router's own rule (`app_router.dart`): a positive whole number of at most
/// ten digits. `web/firebase-messaging-sw.js` mirrors this pattern, and
/// `test/web/messaging_sw_routes_test.dart` holds the two together. Change both.
final RegExp _pushRoutePattern = RegExp(
  r'^/(?:match/[1-9][0-9]{0,9}(?:\?section=channels)?|channel/[1-9][0-9]{0,9})?$',
);

/// A route a push may open.
@immutable
class PushRoute {
  const PushRoute._(this.location);

  /// Where to go, exactly as the push named it.
  final String location;

  /// S6 is a sheet, so it needs a screen under it (`go('/')`, then `push`).
  bool get opensAsSheet => location.startsWith('/channel/');

  @override
  bool operator ==(Object other) => other is PushRoute && other.location == location;

  @override
  int get hashCode => location.hashCode;
}

/// [route] when it's one of the known shapes. Anything else is null: the app opens and goes
/// nowhere (FR-059).
PushRoute? parsePushRoute(String route) =>
    _pushRoutePattern.hasMatch(route) ? PushRoute._(route) : null;
