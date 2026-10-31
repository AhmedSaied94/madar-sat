// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'where_to_watch_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Each match's screen has its own: the family key is the match id.

@ProviderFor(WhereToWatchController)
final whereToWatchProvider = WhereToWatchControllerFamily._();

/// Each match's screen has its own: the family key is the match id.
final class WhereToWatchControllerProvider
    extends $NotifierProvider<WhereToWatchController, WhereToWatchState> {
  /// Each match's screen has its own: the family key is the match id.
  WhereToWatchControllerProvider._({
    required WhereToWatchControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'whereToWatchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$whereToWatchControllerHash();

  @override
  String toString() {
    return r'whereToWatchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WhereToWatchController create() => WhereToWatchController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WhereToWatchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WhereToWatchState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WhereToWatchControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$whereToWatchControllerHash() =>
    r'089cfda6b13acb1e7f9692046397ac72c607c7cc';

/// Each match's screen has its own: the family key is the match id.

final class WhereToWatchControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          WhereToWatchController,
          WhereToWatchState,
          WhereToWatchState,
          WhereToWatchState,
          int
        > {
  WhereToWatchControllerFamily._()
    : super(
        retry: null,
        name: r'whereToWatchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Each match's screen has its own: the family key is the match id.

  WhereToWatchControllerProvider call(int matchId) =>
      WhereToWatchControllerProvider._(argument: matchId, from: this);

  @override
  String toString() => r'whereToWatchProvider';
}

/// Each match's screen has its own: the family key is the match id.

abstract class _$WhereToWatchController extends $Notifier<WhereToWatchState> {
  late final _$args = ref.$arg as int;
  int get matchId => _$args;

  WhereToWatchState build(int matchId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WhereToWatchState, WhereToWatchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WhereToWatchState, WhereToWatchState>,
              WhereToWatchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
