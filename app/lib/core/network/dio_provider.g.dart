// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One Dio for the app: base URL from the bundled flavor config, timeouts, and the
/// ETag interceptor (research R17).

@ProviderFor(dio)
final dioProvider = DioProvider._();

/// One Dio for the app: base URL from the bundled flavor config, timeouts, and the
/// ETag interceptor (research R17).

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// One Dio for the app: base URL from the bundled flavor config, timeouts, and the
  /// ETag interceptor (research R17).
  DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dioHash() => r'4b9bbd31ceddce8a480a2314c94d7907774ccc21';

/// The generated client (swagger_parser, never hand-edited).

@ProviderFor(madarApi)
final madarApiProvider = MadarApiProvider._();

/// The generated client (swagger_parser, never hand-edited).

final class MadarApiProvider
    extends $FunctionalProvider<MadarApi, MadarApi, MadarApi>
    with $Provider<MadarApi> {
  /// The generated client (swagger_parser, never hand-edited).
  MadarApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'madarApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$madarApiHash();

  @$internal
  @override
  $ProviderElement<MadarApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MadarApi create(Ref ref) {
    return madarApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MadarApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MadarApi>(value),
    );
  }
}

String _$madarApiHash() => r'98178418a66e7251e66c6038dc8ae7a4eaf5a160';

@ProviderFor(madarApiClient)
final madarApiClientProvider = MadarApiClientProvider._();

final class MadarApiClientProvider
    extends $FunctionalProvider<MadarApiClient, MadarApiClient, MadarApiClient>
    with $Provider<MadarApiClient> {
  MadarApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'madarApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$madarApiClientHash();

  @$internal
  @override
  $ProviderElement<MadarApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MadarApiClient create(Ref ref) {
    return madarApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MadarApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MadarApiClient>(value),
    );
  }
}

String _$madarApiClientHash() => r'd1f971f0073e31f99ea4aa076007e2b416de29d8';
