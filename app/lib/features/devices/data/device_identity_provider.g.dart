// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_identity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The identity in force, read from secure storage on start.
///
/// Registration (`POST /v1/devices`) is [DeviceRepository]'s, and it writes the token this
/// holds; the interceptor reads it on every `/v1` request.

@ProviderFor(DeviceIdentityController)
final deviceIdentityControllerProvider = DeviceIdentityControllerProvider._();

/// The identity in force, read from secure storage on start.
///
/// Registration (`POST /v1/devices`) is [DeviceRepository]'s, and it writes the token this
/// holds; the interceptor reads it on every `/v1` request.
final class DeviceIdentityControllerProvider
    extends $AsyncNotifierProvider<DeviceIdentityController, DeviceIdentity> {
  /// The identity in force, read from secure storage on start.
  ///
  /// Registration (`POST /v1/devices`) is [DeviceRepository]'s, and it writes the token this
  /// holds; the interceptor reads it on every `/v1` request.
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
    r'20b6c615e0eef07fd529efb06d7e9ceb3a36c91e';

/// The identity in force, read from secure storage on start.
///
/// Registration (`POST /v1/devices`) is [DeviceRepository]'s, and it writes the token this
/// holds; the interceptor reads it on every `/v1` request.

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
