// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the device's push id in secure storage and flags the change for the server
/// (research R27, US2 scenario 7, M-R1-2).
///
/// A token arrives on first start and again whenever FCM rotates it. Each new value is
/// written once under [SecureKeys.pushToken] — never under [SecureKeys.deviceToken], which
/// carries the server's auth token — and marks `sync_state.device` dirty, which
/// [DeviceSync] sends in `PUT /v1/devices/me`'s body. Repeating the same token does nothing,
/// so a resume does not re-send it.

@ProviderFor(PushTokenSync)
final pushTokenSyncProvider = PushTokenSyncProvider._();

/// Keeps the device's push id in secure storage and flags the change for the server
/// (research R27, US2 scenario 7, M-R1-2).
///
/// A token arrives on first start and again whenever FCM rotates it. Each new value is
/// written once under [SecureKeys.pushToken] — never under [SecureKeys.deviceToken], which
/// carries the server's auth token — and marks `sync_state.device` dirty, which
/// [DeviceSync] sends in `PUT /v1/devices/me`'s body. Repeating the same token does nothing,
/// so a resume does not re-send it.
final class PushTokenSyncProvider
    extends $AsyncNotifierProvider<PushTokenSync, void> {
  /// Keeps the device's push id in secure storage and flags the change for the server
  /// (research R27, US2 scenario 7, M-R1-2).
  ///
  /// A token arrives on first start and again whenever FCM rotates it. Each new value is
  /// written once under [SecureKeys.pushToken] — never under [SecureKeys.deviceToken], which
  /// carries the server's auth token — and marks `sync_state.device` dirty, which
  /// [DeviceSync] sends in `PUT /v1/devices/me`'s body. Repeating the same token does nothing,
  /// so a resume does not re-send it.
  PushTokenSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushTokenSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushTokenSyncHash();

  @$internal
  @override
  PushTokenSync create() => PushTokenSync();
}

String _$pushTokenSyncHash() => r'd877d01ab02000a295499b3b08989d6063d4e7c5';

/// Keeps the device's push id in secure storage and flags the change for the server
/// (research R27, US2 scenario 7, M-R1-2).
///
/// A token arrives on first start and again whenever FCM rotates it. Each new value is
/// written once under [SecureKeys.pushToken] — never under [SecureKeys.deviceToken], which
/// carries the server's auth token — and marks `sync_state.device` dirty, which
/// [DeviceSync] sends in `PUT /v1/devices/me`'s body. Repeating the same token does nothing,
/// so a resume does not re-send it.

abstract class _$PushTokenSync extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
