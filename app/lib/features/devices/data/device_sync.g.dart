// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Brings the server's copy of this device up to date (US2 scenarios 4, 6, 7; FR-041).
///
/// Three things reach `/v1/devices`: the registration (once), `PUT /v1/devices/me` when the
/// sync state says `device` is dirty (a push id, the satellite choice or the app version
/// changed) and `PUT /v1/devices/me/follows` when `follows` is dirty. A failure changes
/// nothing locally: the dirty flag stays and the next launch, resume, reconnect or change
/// tries again. A `401` drops the token, so the next attempt registers the same install id
/// again.

@ProviderFor(DeviceSync)
final deviceSyncProvider = DeviceSyncProvider._();

/// Brings the server's copy of this device up to date (US2 scenarios 4, 6, 7; FR-041).
///
/// Three things reach `/v1/devices`: the registration (once), `PUT /v1/devices/me` when the
/// sync state says `device` is dirty (a push id, the satellite choice or the app version
/// changed) and `PUT /v1/devices/me/follows` when `follows` is dirty. A failure changes
/// nothing locally: the dirty flag stays and the next launch, resume, reconnect or change
/// tries again. A `401` drops the token, so the next attempt registers the same install id
/// again.
final class DeviceSyncProvider
    extends $AsyncNotifierProvider<DeviceSync, void> {
  /// Brings the server's copy of this device up to date (US2 scenarios 4, 6, 7; FR-041).
  ///
  /// Three things reach `/v1/devices`: the registration (once), `PUT /v1/devices/me` when the
  /// sync state says `device` is dirty (a push id, the satellite choice or the app version
  /// changed) and `PUT /v1/devices/me/follows` when `follows` is dirty. A failure changes
  /// nothing locally: the dirty flag stays and the next launch, resume, reconnect or change
  /// tries again. A `401` drops the token, so the next attempt registers the same install id
  /// again.
  DeviceSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceSyncHash();

  @$internal
  @override
  DeviceSync create() => DeviceSync();
}

String _$deviceSyncHash() => r'129f4f0de48b54f9a69c0041c04bc66470af16c1';

/// Brings the server's copy of this device up to date (US2 scenarios 4, 6, 7; FR-041).
///
/// Three things reach `/v1/devices`: the registration (once), `PUT /v1/devices/me` when the
/// sync state says `device` is dirty (a push id, the satellite choice or the app version
/// changed) and `PUT /v1/devices/me/follows` when `follows` is dirty. A failure changes
/// nothing locally: the dirty flag stays and the next launch, resume, reconnect or change
/// tries again. A `401` drops the token, so the next attempt registers the same install id
/// again.

abstract class _$DeviceSync extends $AsyncNotifier<void> {
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

/// The `device` row of `sync_state`, watched: its `dirty` flag is what makes
/// [DeviceSync] send `PUT /v1/devices/me`.

@ProviderFor(deviceSyncState)
final deviceSyncStateProvider = DeviceSyncStateProvider._();

/// The `device` row of `sync_state`, watched: its `dirty` flag is what makes
/// [DeviceSync] send `PUT /v1/devices/me`.

final class DeviceSyncStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncRecord?>,
          SyncRecord?,
          Stream<SyncRecord?>
        >
    with $FutureModifier<SyncRecord?>, $StreamProvider<SyncRecord?> {
  /// The `device` row of `sync_state`, watched: its `dirty` flag is what makes
  /// [DeviceSync] send `PUT /v1/devices/me`.
  DeviceSyncStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceSyncStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceSyncStateHash();

  @$internal
  @override
  $StreamProviderElement<SyncRecord?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SyncRecord?> create(Ref ref) {
    return deviceSyncState(ref);
  }
}

String _$deviceSyncStateHash() => r'6d3f2e0424182c6ae02419dd78d74bb0ada58ae1';

/// The `follows` row of `sync_state`, watched: `PUT /v1/devices/me/follows`.

@ProviderFor(followsSyncState)
final followsSyncStateProvider = FollowsSyncStateProvider._();

/// The `follows` row of `sync_state`, watched: `PUT /v1/devices/me/follows`.

final class FollowsSyncStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<SyncRecord?>,
          SyncRecord?,
          Stream<SyncRecord?>
        >
    with $FutureModifier<SyncRecord?>, $StreamProvider<SyncRecord?> {
  /// The `follows` row of `sync_state`, watched: `PUT /v1/devices/me/follows`.
  FollowsSyncStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followsSyncStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followsSyncStateHash();

  @$internal
  @override
  $StreamProviderElement<SyncRecord?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SyncRecord?> create(Ref ref) {
    return followsSyncState(ref);
  }
}

String _$followsSyncStateHash() => r'16c4a3ba52914d5fa952f989b02968a19f2a0e78';
