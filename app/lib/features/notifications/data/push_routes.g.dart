// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_routes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The tapped pushes (FR-059): `data.route` of a message tapped in the background, or of the
/// one that launched the app.
///
/// The service is the platform adapter; this only exposes it as a stream the router can
/// listen to, so a test overrides one provider.

@ProviderFor(pushRoutes)
final pushRoutesProvider = PushRoutesProvider._();

/// The tapped pushes (FR-059): `data.route` of a message tapped in the background, or of the
/// one that launched the app.
///
/// The service is the platform adapter; this only exposes it as a stream the router can
/// listen to, so a test overrides one provider.

final class PushRoutesProvider
    extends $FunctionalProvider<AsyncValue<PushTap>, PushTap, Stream<PushTap>>
    with $FutureModifier<PushTap>, $StreamProvider<PushTap> {
  /// The tapped pushes (FR-059): `data.route` of a message tapped in the background, or of the
  /// one that launched the app.
  ///
  /// The service is the platform adapter; this only exposes it as a stream the router can
  /// listen to, so a test overrides one provider.
  PushRoutesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushRoutesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushRoutesHash();

  @$internal
  @override
  $StreamProviderElement<PushTap> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<PushTap> create(Ref ref) {
    return pushRoutes(ref);
  }
}

String _$pushRoutesHash() => r'301eaaeb88f9ad6982cc04d6ee4f89cfcf3ac365';

/// Pushes received with the app open: a banner each, and no navigation (FR-059).

@ProviderFor(foregroundPushes)
final foregroundPushesProvider = ForegroundPushesProvider._();

/// Pushes received with the app open: a banner each, and no navigation (FR-059).

final class ForegroundPushesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ForegroundPush>,
          ForegroundPush,
          Stream<ForegroundPush>
        >
    with $FutureModifier<ForegroundPush>, $StreamProvider<ForegroundPush> {
  /// Pushes received with the app open: a banner each, and no navigation (FR-059).
  ForegroundPushesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foregroundPushesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foregroundPushesHash();

  @$internal
  @override
  $StreamProviderElement<ForegroundPush> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ForegroundPush> create(Ref ref) {
    return foregroundPushes(ref);
  }
}

String _$foregroundPushesHash() => r'2efab4dba821eb426fa18556dd1c6d1283155fba';
