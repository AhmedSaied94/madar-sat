// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'follows_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(followsRepository)
final followsRepositoryProvider = FollowsRepositoryProvider._();

final class FollowsRepositoryProvider
    extends
        $FunctionalProvider<
          FollowsRepository,
          FollowsRepository,
          FollowsRepository
        >
    with $Provider<FollowsRepository> {
  FollowsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followsRepositoryHash();

  @$internal
  @override
  $ProviderElement<FollowsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FollowsRepository create(Ref ref) {
    return followsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FollowsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FollowsRepository>(value),
    );
  }
}

String _$followsRepositoryHash() => r'd340e5172e3b2c38ac0ef39ca462b2c845d90b2b';

/// Counts writes to the follow set. [followsSetProvider] watches it, so a follow made in S3
/// redraws S9 without a refresh and without a provider invalidating its own dependency.

@ProviderFor(FollowsRevision)
final followsRevisionProvider = FollowsRevisionProvider._();

/// Counts writes to the follow set. [followsSetProvider] watches it, so a follow made in S3
/// redraws S9 without a refresh and without a provider invalidating its own dependency.
final class FollowsRevisionProvider
    extends $NotifierProvider<FollowsRevision, int> {
  /// Counts writes to the follow set. [followsSetProvider] watches it, so a follow made in S3
  /// redraws S9 without a refresh and without a provider invalidating its own dependency.
  FollowsRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followsRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followsRevisionHash();

  @$internal
  @override
  FollowsRevision create() => FollowsRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$followsRevisionHash() => r'91ccd74ccd1aa6f7a8e9c524eec4297369070c7d';

/// Counts writes to the follow set. [followsSetProvider] watches it, so a follow made in S3
/// redraws S9 without a refresh and without a provider invalidating its own dependency.

abstract class _$FollowsRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The follow set, read from drift.

@ProviderFor(followsSet)
final followsSetProvider = FollowsSetProvider._();

/// The follow set, read from drift.

final class FollowsSetProvider
    extends
        $FunctionalProvider<
          AsyncValue<FollowSet>,
          FollowSet,
          FutureOr<FollowSet>
        >
    with $FutureModifier<FollowSet>, $FutureProvider<FollowSet> {
  /// The follow set, read from drift.
  FollowsSetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followsSetProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followsSetHash();

  @$internal
  @override
  $FutureProviderElement<FollowSet> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FollowSet> create(Ref ref) {
    return followsSet(ref);
  }
}

String _$followsSetHash() => r'c8502aa084a9629d7299a626bd50207bab0128f8';

/// The set as a plain value, for a widget that only reads membership and counts.

@ProviderFor(followSetValue)
final followSetValueProvider = FollowSetValueProvider._();

/// The set as a plain value, for a widget that only reads membership and counts.

final class FollowSetValueProvider
    extends $FunctionalProvider<FollowSet, FollowSet, FollowSet>
    with $Provider<FollowSet> {
  /// The set as a plain value, for a widget that only reads membership and counts.
  FollowSetValueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'followSetValueProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$followSetValueHash();

  @$internal
  @override
  $ProviderElement<FollowSet> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FollowSet create(Ref ref) {
    return followSetValue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FollowSet value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FollowSet>(value),
    );
  }
}

String _$followSetValueHash() => r'1e65e4c262618a69cf050ab53da13d90195d0b79';
