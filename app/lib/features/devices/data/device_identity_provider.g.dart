// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_identity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The identity in force, read from secure storage on start.
///
/// Registration itself (`POST /v1/devices`) is T133's, against B1's regenerated client; this
/// holds the state it writes and the interceptor reads.

@ProviderFor(DeviceIdentityController)
final deviceIdentityControllerProvider = DeviceIdentityControllerProvider._();

/// The identity in force, read from secure storage on start.
///
/// Registration itself (`POST /v1/devices`) is T133's, against B1's regenerated client; this
/// holds the state it writes and the interceptor reads.
final class DeviceIdentityControllerProvider
    extends $AsyncNotifierProvider<DeviceIdentityController, DeviceIdentity> {
  /// The identity in force, read from secure storage on start.
  ///
  /// Registration itself (`POST /v1/devices`) is T133's, against B1's regenerated client; this
  /// holds the state it writes and the interceptor reads.
  DeviceIdentityControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceIdentityControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceIdentityControllerHash();

  @$internal
  @override
  DeviceIdentityController create() => DeviceIdentityController();
}

String _$deviceIdentityControllerHash() =>
    r'1296e13052bd17c9d0352e99f976695497c6e52f';

/// The identity in force, read from secure storage on start.
///
/// Registration itself (`POST /v1/devices`) is T133's, against B1's regenerated client; this
/// holds the state it writes and the interceptor reads.

abstract class _$DeviceIdentityController
    extends $AsyncNotifier<DeviceIdentity> {
  FutureOr<DeviceIdentity> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<DeviceIdentity>, DeviceIdentity>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DeviceIdentity>, DeviceIdentity>,
              AsyncValue<DeviceIdentity>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
