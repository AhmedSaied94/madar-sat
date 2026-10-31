// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'satellite_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The chips on S4: my satellites that the server lists, in the server's order.

@ProviderFor(mySatelliteChips)
final mySatelliteChipsProvider = MySatelliteChipsProvider._();

/// The chips on S4: my satellites that the server lists, in the server's order.

final class MySatelliteChipsProvider
    extends
        $FunctionalProvider<List<Satellite>, List<Satellite>, List<Satellite>>
    with $Provider<List<Satellite>> {
  /// The chips on S4: my satellites that the server lists, in the server's order.
  MySatelliteChipsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mySatelliteChipsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mySatelliteChipsHash();

  @$internal
  @override
  $ProviderElement<List<Satellite>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Satellite> create(Ref ref) {
    return mySatelliteChips(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Satellite> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Satellite>>(value),
    );
  }
}

String _$mySatelliteChipsHash() => r'31cbefd960fcda6d9b41a7992b998955d4427a04';

/// Which of my satellites S4 shows. `null` is every one of them: the default, and what
/// «الكل» returns to. D3 replaces "my satellites" with the user's saved choice (S1.3, S15);
/// until then the toggles live only for the session.

@ProviderFor(SatelliteSelection)
final satelliteSelectionProvider = SatelliteSelectionProvider._();

/// Which of my satellites S4 shows. `null` is every one of them: the default, and what
/// «الكل» returns to. D3 replaces "my satellites" with the user's saved choice (S1.3, S15);
/// until then the toggles live only for the session.
final class SatelliteSelectionProvider
    extends $NotifierProvider<SatelliteSelection, Set<int>?> {
  /// Which of my satellites S4 shows. `null` is every one of them: the default, and what
  /// «الكل» returns to. D3 replaces "my satellites" with the user's saved choice (S1.3, S15);
  /// until then the toggles live only for the session.
  SatelliteSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'satelliteSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$satelliteSelectionHash();

  @$internal
  @override
  SatelliteSelection create() => SatelliteSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>?>(value),
    );
  }
}

String _$satelliteSelectionHash() =>
    r'e0d0edb398924725b01bfdb245870629d5223ac2';

/// Which of my satellites S4 shows. `null` is every one of them: the default, and what
/// «الكل» returns to. D3 replaces "my satellites" with the user's saved choice (S1.3, S15);
/// until then the toggles live only for the session.

abstract class _$SatelliteSelection extends $Notifier<Set<int>?> {
  Set<int>? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<int>?, Set<int>?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<int>?, Set<int>?>,
              Set<int>?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The ids S4 asks the server about: the selection inside my satellites. Empty means nothing
/// is chosen, and S4 then asks for nothing rather than for "no filter".

@ProviderFor(selectedSatelliteIds)
final selectedSatelliteIdsProvider = SelectedSatelliteIdsProvider._();

/// The ids S4 asks the server about: the selection inside my satellites. Empty means nothing
/// is chosen, and S4 then asks for nothing rather than for "no filter".

final class SelectedSatelliteIdsProvider
    extends $FunctionalProvider<Set<int>, Set<int>, Set<int>>
    with $Provider<Set<int>> {
  /// The ids S4 asks the server about: the selection inside my satellites. Empty means nothing
  /// is chosen, and S4 then asks for nothing rather than for "no filter".
  SelectedSatelliteIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedSatelliteIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedSatelliteIdsHash();

  @$internal
  @override
  $ProviderElement<Set<int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Set<int> create(Ref ref) {
    return selectedSatelliteIds(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>>(value),
    );
  }
}

String _$selectedSatelliteIdsHash() =>
    r'dc76acc28f46019efa4b5b293415ecb001a70b2d';
