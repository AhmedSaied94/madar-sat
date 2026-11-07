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
///
/// A send clears its flag only for what it carried: it reads the key's revision first, and
/// the flag clears only if no change was flagged since (`markSyncCleanIfUnchanged`);
/// otherwise the loop in [sync] sends again.

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
///
/// A send clears its flag only for what it carried: it reads the key's revision first, and
/// the flag clears only if no change was flagged since (`markSyncCleanIfUnchanged`);
/// otherwise the loop in [sync] sends again.
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
  ///
  /// A send clears its flag only for what it carried: it reads the key's revision first, and
  /// the flag clears only if no change was flagged since (`markSyncCleanIfUnchanged`);
  /// otherwise the loop in [sync] sends again.
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

String _$deviceSyncHash() => r'73b15ce3710fd53be70a822bee20aa94f11c34d3';

/// Brings the server's copy of this device up to date (US2 scenarios 4, 6, 7; FR-041).
///
/// Three things reach `/v1/devices`: the registration (once), `PUT /v1/devices/me` when the
/// sync state says `device` is dirty (a push id, the satellite choice or the app version
/// changed) and `PUT /v1/devices/me/follows` when `follows` is dirty. A failure changes
/// nothing locally: the dirty flag stays and the next launch, resume, reconnect or change
/// tries again. A `401` drops the token, so the next attempt registers the same install id
/// again.
///
/// A send clears its flag only for what it carried: it reads the key's revision first, and
/// the flag clears only if no change was flagged since (`markSyncCleanIfUnchanged`);
/// otherwise the loop in [sync] sends again.

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
