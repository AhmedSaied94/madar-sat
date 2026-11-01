// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The service in force.

@ProviderFor(pushService)
final pushServiceProvider = PushServiceProvider._();

/// The service in force.

final class PushServiceProvider
    extends $FunctionalProvider<PushService, PushService, PushService>
    with $Provider<PushService> {
  /// The service in force.
  PushServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushServiceHash();

  @$internal
  @override
  $ProviderElement<PushService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushService create(Ref ref) {
    return pushService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushService>(value),
    );
  }
}

String _$pushServiceHash() => r'4647c74563077e80f63b95978fdcb87435ddad10';

/// Whether notifications were granted on this device. Set by the onboarding step and read
/// by S15; the OS remains the authority, this only mirrors the last answer.

@ProviderFor(PushPermission)
final pushPermissionProvider = PushPermissionProvider._();

/// Whether notifications were granted on this device. Set by the onboarding step and read
/// by S15; the OS remains the authority, this only mirrors the last answer.
final class PushPermissionProvider
    extends $NotifierProvider<PushPermission, bool> {
  /// Whether notifications were granted on this device. Set by the onboarding step and read
  /// by S15; the OS remains the authority, this only mirrors the last answer.
  PushPermissionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushPermissionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushPermissionHash();

  @$internal
  @override
  PushPermission create() => PushPermission();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$pushPermissionHash() => r'ddb08c80ea899bd0f63d694dad2c1206bdc5d7ac';

/// Whether notifications were granted on this device. Set by the onboarding step and read
/// by S15; the OS remains the authority, this only mirrors the last answer.

abstract class _$PushPermission extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
