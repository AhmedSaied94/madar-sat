import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/platform/push_service.dart';
import 'device_identity_provider.dart';

part 'push_token_sync.g.dart';

/// Keeps the device's push token in secure storage and flags the change for the server
/// (research R27, US2 scenario 7).
///
/// A token arrives on first start and again whenever FCM rotates it. Each new value is
/// written once and marks `sync_state.device` dirty, which is what `PUT /v1/devices/me` acts
/// on (T133); repeating the same token does nothing, so a resume does not re-send it.
@Riverpod(keepAlive: true)
class PushTokenSync extends _$PushTokenSync {
  StreamSubscription<String?>? _subscription;

  @override
  Future<void> build() async {
    final service = ref.watch(pushServiceProvider);
    final database = ref.watch(appDatabaseProvider);
    ref.onDispose(() => _subscription?.cancel());

    Future<void> apply(String? token) async {
      if (token == null || token.isEmpty) return;
      final identity = await ref.read(deviceIdentityControllerProvider.future);
      if (identity.token == token) return;
      await ref.read(deviceIdentityControllerProvider.notifier).setToken(token);
      await database.markSyncDirty('device');
    }

    await apply(await service.currentToken());
    _subscription = service.tokenChanges.listen((token) => unawaited(apply(token)));
  }
}
