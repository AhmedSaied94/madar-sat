// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'swr_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The stale-while-revalidate repository every D2 screen reads through (research R25).
/// Tests override it, or `appDatabaseProvider` and `dioProvider` underneath it.

@ProviderFor(swrRepository)
final swrRepositoryProvider = SwrRepositoryProvider._();

/// The stale-while-revalidate repository every D2 screen reads through (research R25).
/// Tests override it, or `appDatabaseProvider` and `dioProvider` underneath it.

final class SwrRepositoryProvider
    extends $FunctionalProvider<SwrRepository, SwrRepository, SwrRepository>
    with $Provider<SwrRepository> {
  /// The stale-while-revalidate repository every D2 screen reads through (research R25).
  /// Tests override it, or `appDatabaseProvider` and `dioProvider` underneath it.
  SwrRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'swrRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$swrRepositoryHash();

  @$internal
  @override
  $ProviderElement<SwrRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SwrRepository create(Ref ref) {
    return swrRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SwrRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SwrRepository>(value),
    );
  }
}

String _$swrRepositoryHash() => r'fee607823a7df3afe82c7750d96da675cb14388a';
