// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_routes.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The routes pushes open (US2 scenario 7): `data.route` of a message received in the
/// foreground, or of the one that launched the app from a notification tap.
///
/// The service is the platform adapter; this only exposes it as a stream the router can
/// listen to, so a test overrides one provider.

@ProviderFor(pushRoutes)
final pushRoutesProvider = PushRoutesProvider._();

/// The routes pushes open (US2 scenario 7): `data.route` of a message received in the
/// foreground, or of the one that launched the app from a notification tap.
///
/// The service is the platform adapter; this only exposes it as a stream the router can
/// listen to, so a test overrides one provider.

final class PushRoutesProvider
    extends $FunctionalProvider<AsyncValue<String>, String, Stream<String>>
    with $FutureModifier<String>, $StreamProvider<String> {
  /// The routes pushes open (US2 scenario 7): `data.route` of a message received in the
  /// foreground, or of the one that launched the app from a notification tap.
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
  $StreamProviderElement<String> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<String> create(Ref ref) {
    return pushRoutes(ref);
  }
}

String _$pushRoutesHash() => r'294b61d3ce214fbd0a9dbf50dc03e3c735699c60';
