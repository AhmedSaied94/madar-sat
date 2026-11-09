import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/platform/push_service.dart';

part 'push_routes.g.dart';

/// One tap on a push. It has no value equality on purpose: Riverpod drops a value equal to the
/// last, and every push of a match names the same route, so a second tap would open nothing.
class PushTap {
  const PushTap(this.route);

  final String route;
}

/// The tapped pushes (FR-059): `data.route` of a message tapped in the background, or of the
/// one that launched the app.
///
/// The service is the platform adapter; this only exposes it as a stream the router can
/// listen to, so a test overrides one provider.
@riverpod
Stream<PushTap> pushRoutes(Ref ref) => ref.watch(pushServiceProvider).openedRoutes.map(PushTap.new);

/// Pushes received with the app open: a banner each, and no navigation (FR-059).
@riverpod
Stream<ForegroundPush> foregroundPushes(Ref ref) =>
    ref.watch(pushServiceProvider).foregroundMessages;
