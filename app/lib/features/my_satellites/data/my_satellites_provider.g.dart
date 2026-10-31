// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_satellites_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `/v1/satellites`, stale-while-revalidate (24 h freshness). Shared by S4, S5.1 and the
/// satellite resolution below. No automatic retry: Riverpod would hold the state at loading
/// for about 38 s, hiding the error copy of a screen that has its own «إعادة المحاولة».

@ProviderFor(Satellites)
final satellitesProvider = SatellitesProvider._();

/// `/v1/satellites`, stale-while-revalidate (24 h freshness). Shared by S4, S5.1 and the
/// satellite resolution below. No automatic retry: Riverpod would hold the state at loading
/// for about 38 s, hiding the error copy of a screen that has its own «إعادة المحاولة».
final class SatellitesProvider
    extends $StreamNotifierProvider<Satellites, SwrSnapshot<List<Satellite>>> {
  /// `/v1/satellites`, stale-while-revalidate (24 h freshness). Shared by S4, S5.1 and the
  /// satellite resolution below. No automatic retry: Riverpod would hold the state at loading
  /// for about 38 s, hiding the error copy of a screen that has its own «إعادة المحاولة».
  SatellitesProvider._()
    : super(
        from: null,
        argument: null,
        retry: _never,
        name: r'satellitesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$satellitesHash();

  @$internal
  @override
  Satellites create() => Satellites();
}

String _$satellitesHash() => r'108aaa2cbe69f4f8f3f7ca8171e003f93439c327';

/// `/v1/satellites`, stale-while-revalidate (24 h freshness). Shared by S4, S5.1 and the
/// satellite resolution below. No automatic retry: Riverpod would hold the state at loading
/// for about 38 s, hiding the error copy of a screen that has its own «إعادة المحاولة».

abstract class _$Satellites
    extends $StreamNotifier<SwrSnapshot<List<Satellite>>> {
  Stream<SwrSnapshot<List<Satellite>>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SwrSnapshot<List<Satellite>>>,
              SwrSnapshot<List<Satellite>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SwrSnapshot<List<Satellite>>>,
                SwrSnapshot<List<Satellite>>
              >,
              AsyncValue<SwrSnapshot<List<Satellite>>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The ids of my satellites, resolved from [satellitesProvider]. Empty until the list has
/// loaded (or when the server lists neither), never a guess.

@ProviderFor(mySatelliteIds)
final mySatelliteIdsProvider = MySatelliteIdsProvider._();

/// The ids of my satellites, resolved from [satellitesProvider]. Empty until the list has
/// loaded (or when the server lists neither), never a guess.

final class MySatelliteIdsProvider
    extends $FunctionalProvider<Set<int>, Set<int>, Set<int>>
    with $Provider<Set<int>> {
  /// The ids of my satellites, resolved from [satellitesProvider]. Empty until the list has
  /// loaded (or when the server lists neither), never a guess.
  MySatelliteIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mySatelliteIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mySatelliteIdsHash();

  @$internal
  @override
  $ProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<int> create(Ref ref) {
    return mySatelliteIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>>(value),
    );
  }
}

String _$mySatelliteIdsHash() => r'6a91781ef7a96d70e299f1c9fa4d34de54a8539f';

/// My satellites as the catalogue lists them, in its order.

@ProviderFor(mySatelliteEntries)
final mySatelliteEntriesProvider = MySatelliteEntriesProvider._();

/// My satellites as the catalogue lists them, in its order.

final class MySatelliteEntriesProvider
    extends
        $FunctionalProvider<List<Satellite>, List<Satellite>, List<Satellite>>
    with $Provider<List<Satellite>> {
  /// My satellites as the catalogue lists them, in its order.
  MySatelliteEntriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mySatelliteEntriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mySatelliteEntriesHash();

  @$internal
  @override
  $ProviderElement<List<Satellite>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Satellite> create(Ref ref) {
    return mySatelliteEntries(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Satellite> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Satellite>>(value),
    );
  }
}

String _$mySatelliteEntriesHash() =>
    r'21498d9e033fe18242780fac5b4b6c415aa302f9';

/// Their Arabic names, for a title that names them: «على نايل سات وبدر».

@ProviderFor(mySatelliteNames)
final mySatelliteNamesProvider = MySatelliteNamesProvider._();

/// Their Arabic names, for a title that names them: «على نايل سات وبدر».

final class MySatelliteNamesProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// Their Arabic names, for a title that names them: «على نايل سات وبدر».
  MySatelliteNamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mySatelliteNamesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mySatelliteNamesHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return mySatelliteNames(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$mySatelliteNamesHash() => r'ae8f42c7ece008f57088c9afd8c4235162eff005';

/// The satellites the user chose, or null until D3 stores a choice. While it is null the
/// O10 default set stands in, and S3 titles it by name rather than as «على أقمارك»
/// (constitution I: the screen may not call two bundled defaults "yours").

@ProviderFor(chosenSatelliteIds)
final chosenSatelliteIdsProvider = ChosenSatelliteIdsProvider._();

/// The satellites the user chose, or null until D3 stores a choice. While it is null the
/// O10 default set stands in, and S3 titles it by name rather than as «على أقمارك»
/// (constitution I: the screen may not call two bundled defaults "yours").

final class ChosenSatelliteIdsProvider
    extends $FunctionalProvider<Set<int>?, Set<int>?, Set<int>?>
    with $Provider<Set<int>?> {
  /// The satellites the user chose, or null until D3 stores a choice. While it is null the
  /// O10 default set stands in, and S3 titles it by name rather than as «على أقمارك»
  /// (constitution I: the screen may not call two bundled defaults "yours").
  ChosenSatelliteIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chosenSatelliteIdsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chosenSatelliteIdsHash();

  @$internal
  @override
  $ProviderElement<Set<int>?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<int>? create(Ref ref) {
    return chosenSatelliteIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>?>(value),
    );
  }
}

String _$chosenSatelliteIdsHash() =>
    r'9a92ea4838b5c26377ca654a38876b3542922e8b';
