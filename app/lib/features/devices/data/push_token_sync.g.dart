// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Keeps the device's push token in secure storage and flags the change for the server
/// (research R27, US2 scenario 7).
///
/// A token arrives on first start and again whenever FCM rotates it. Each new value is
/// written once and marks `sync_state.device` dirty, which is what `PUT /v1/devices/me` acts
/// on (T133); repeating the same token does nothing, so a resume does not re-send it.

@ProviderFor(PushTokenSync)
final pushTokenSyncProvider = PushTokenSyncProvider._();

/// Keeps the device's push token in secure storage and flags the change for the server
/// (research R27, US2 scenario 7).
///
/// A token arrives on first start and again whenever FCM rotates it. Each new value is
/// written once and marks `sync_state.device` dirty, which is what `PUT /v1/devices/me` acts
/// on (T133); repeating the same token does nothing, so a resume does not re-send it.
final class PushTokenSyncProvider
    extends $AsyncNotifierProvider<PushTokenSync, void> {
  /// Keeps the device's push token in secure storage and flags the change for the server
  /// (research R27, US2 scenario 7).
  ///
  /// A token arrives on first start and again whenever FCM rotates it. Each new value is
  /// written once and marks `sync_state.device` dirty, which is what `PUT /v1/devices/me` acts
  /// on (T133); repeating the same token does nothing, so a resume does not re-send it.
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

String _$pushTokenSyncHash() => r'12f2b191616c42b967a54b1eb4e44e19507b8464';

/// Keeps the device's push token in secure storage and flags the change for the server
/// (research R27, US2 scenario 7).
///
/// A token arrives on first start and again whenever FCM rotates it. Each new value is
/// written once and marks `sync_state.device` dirty, which is what `PUT /v1/devices/me` acts
/// on (T133); repeating the same token does nothing, so a resume does not re-send it.

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
