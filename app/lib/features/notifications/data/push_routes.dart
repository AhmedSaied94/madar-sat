import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/platform/push_service.dart';

part 'push_routes.g.dart';

/// The routes pushes open (US2 scenario 7): `data.route` of a message received in the
/// foreground, or of the one that launched the app from a notification tap.
///
/// The service is the platform adapter; this only exposes it as a stream the router can
/// listen to, so a test overrides one provider.
@riverpod
Stream<String> pushRoutes(Ref ref) => ref.watch(pushServiceProvider).openedRoutes;
