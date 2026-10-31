// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matches_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lives as long as the screen does: leaving S2 for a root tab starts again on today.

@ProviderFor(MatchesSelectionNotifier)
final matchesSelectionProvider = MatchesSelectionNotifierProvider._();

/// Lives as long as the screen does: leaving S2 for a root tab starts again on today.
final class MatchesSelectionNotifierProvider
    extends $NotifierProvider<MatchesSelectionNotifier, MatchesSelection> {
  /// Lives as long as the screen does: leaving S2 for a root tab starts again on today.
  MatchesSelectionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matchesSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matchesSelectionNotifierHash();

  @$internal
  @override
  MatchesSelectionNotifier create() => MatchesSelectionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MatchesSelection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MatchesSelection>(value),
    );
  }
}

String _$matchesSelectionNotifierHash() =>
    r'6fe533f9d8e355daa649dfac1343cb8ec279a847';

/// Lives as long as the screen does: leaving S2 for a root tab starts again on today.

abstract class _$MatchesSelectionNotifier extends $Notifier<MatchesSelection> {
  MatchesSelection build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MatchesSelection, MatchesSelection>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MatchesSelection, MatchesSelection>,
              MatchesSelection,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
