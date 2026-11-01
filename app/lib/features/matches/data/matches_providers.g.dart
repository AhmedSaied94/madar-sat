// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matches_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One local day of matches from drift, revalidated against the server (FR-046).
///
/// A stream, because the repository emits the cached copy first and the answer after it.
/// There is no automatic retry: Riverpod would keep the state `AsyncLoading` for about
/// 38 s while it retries, hiding the error copy behind the skeleton (FR-048); the screen
/// offers «إعادة المحاولة» instead.

@ProviderFor(MatchesDay)
final matchesDayProvider = MatchesDayFamily._();

/// One local day of matches from drift, revalidated against the server (FR-046).
///
/// A stream, because the repository emits the cached copy first and the answer after it.
/// There is no automatic retry: Riverpod would keep the state `AsyncLoading` for about
/// 38 s while it retries, hiding the error copy behind the skeleton (FR-048); the screen
/// offers «إعادة المحاولة» instead.
final class MatchesDayProvider
    extends
        $StreamNotifierProvider<MatchesDay, SwrSnapshot<List<MatchSummary>>> {
  /// One local day of matches from drift, revalidated against the server (FR-046).
  ///
  /// A stream, because the repository emits the cached copy first and the answer after it.
  /// There is no automatic retry: Riverpod would keep the state `AsyncLoading` for about
  /// 38 s while it retries, hiding the error copy behind the skeleton (FR-048); the screen
  /// offers «إعادة المحاولة» instead.
  MatchesDayProvider._({
    required MatchesDayFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: _never,
         name: r'matchesDayProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$matchesDayHash();

  @override
  String toString() {
    return r'matchesDayProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MatchesDay create() => MatchesDay();

  @override
  bool operator ==(Object other) {
    return other is MatchesDayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$matchesDayHash() => r'30bdff99f0313d4ae0da1b9f36a1e35f61595491';

/// One local day of matches from drift, revalidated against the server (FR-046).
///
/// A stream, because the repository emits the cached copy first and the answer after it.
/// There is no automatic retry: Riverpod would keep the state `AsyncLoading` for about
/// 38 s while it retries, hiding the error copy behind the skeleton (FR-048); the screen
/// offers «إعادة المحاولة» instead.

final class MatchesDayFamily extends $Family
    with
        $ClassFamilyOverride<
          MatchesDay,
          AsyncValue<SwrSnapshot<List<MatchSummary>>>,
          SwrSnapshot<List<MatchSummary>>,
          Stream<SwrSnapshot<List<MatchSummary>>>,
          DateTime
        > {
  MatchesDayFamily._()
    : super(
        retry: _never,
        name: r'matchesDayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One local day of matches from drift, revalidated against the server (FR-046).
  ///
  /// A stream, because the repository emits the cached copy first and the answer after it.
  /// There is no automatic retry: Riverpod would keep the state `AsyncLoading` for about
  /// 38 s while it retries, hiding the error copy behind the skeleton (FR-048); the screen
  /// offers «إعادة المحاولة» instead.

  MatchesDayProvider call(DateTime day) =>
      MatchesDayProvider._(argument: day, from: this);

  @override
  String toString() => r'matchesDayProvider';
}

/// One local day of matches from drift, revalidated against the server (FR-046).
///
/// A stream, because the repository emits the cached copy first and the answer after it.
/// There is no automatic retry: Riverpod would keep the state `AsyncLoading` for about
/// 38 s while it retries, hiding the error copy behind the skeleton (FR-048); the screen
/// offers «إعادة المحاولة» instead.

abstract class _$MatchesDay
    extends $StreamNotifier<SwrSnapshot<List<MatchSummary>>> {
  late final _$args = ref.$arg as DateTime;
  DateTime get day => _$args;

  Stream<SwrSnapshot<List<MatchSummary>>> build(DateTime day);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<SwrSnapshot<List<MatchSummary>>>,
              SwrSnapshot<List<MatchSummary>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<SwrSnapshot<List<MatchSummary>>>,
                SwrSnapshot<List<MatchSummary>>
              >,
              AsyncValue<SwrSnapshot<List<MatchSummary>>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// A day's matches with the live states merged in (never a cached state as live, SC-008).
///
/// Merging happens here, on top of the stream, so a live update re-draws the rows without
/// re-reading drift or the network.

@ProviderFor(matchesDayState)
final matchesDayStateProvider = MatchesDayStateFamily._();

/// A day's matches with the live states merged in (never a cached state as live, SC-008).
///
/// Merging happens here, on top of the stream, so a live update re-draws the rows without
/// re-reading drift or the network.

final class MatchesDayStateProvider
    extends $FunctionalProvider<DayState, DayState, DayState>
    with $Provider<DayState> {
  /// A day's matches with the live states merged in (never a cached state as live, SC-008).
  ///
  /// Merging happens here, on top of the stream, so a live update re-draws the rows without
  /// re-reading drift or the network.
  MatchesDayStateProvider._({
    required MatchesDayStateFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'matchesDayStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$matchesDayStateHash();

  @override
  String toString() {
    return r'matchesDayStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<DayState> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DayState create(Ref ref) {
    final argument = this.argument as DateTime;
    return matchesDayState(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MatchesDayStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$matchesDayStateHash() => r'54bba6aec7b62a4962ef9b05f428e62d692320c9';

/// A day's matches with the live states merged in (never a cached state as live, SC-008).
///
/// Merging happens here, on top of the stream, so a live update re-draws the rows without
/// re-reading drift or the network.

final class MatchesDayStateFamily extends $Family
    with $FunctionalFamilyOverride<DayState, DateTime> {
  MatchesDayStateFamily._()
    : super(
        retry: null,
        name: r'matchesDayStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A day's matches with the live states merged in (never a cached state as live, SC-008).
  ///
  /// Merging happens here, on top of the stream, so a live update re-draws the rows without
  /// re-reading drift or the network.

  MatchesDayStateProvider call(DateTime day) =>
      MatchesDayStateProvider._(argument: day, from: this);

  @override
  String toString() => r'matchesDayStateProvider';
}

/// The local days S2 pages through, with the today they hang on.
///
/// A phone left with the app open past midnight comes back on yesterday's «اليوم» and a
/// window of days that starts a day late, so a resume asks this to recompute. Kept alive so
/// the selection's index means the same day across a rebuild. «اليوم» is the chosen zone's
/// day (M-R1-6), not the device's.

@ProviderFor(matchesWindow)
final matchesWindowProvider = MatchesWindowProvider._();

/// The local days S2 pages through, with the today they hang on.
///
/// A phone left with the app open past midnight comes back on yesterday's «اليوم» and a
/// window of days that starts a day late, so a resume asks this to recompute. Kept alive so
/// the selection's index means the same day across a rebuild. «اليوم» is the chosen zone's
/// day (M-R1-6), not the device's.

final class MatchesWindowProvider
    extends
        $FunctionalProvider<
          ({List<DateTime> days, DateTime today}),
          ({List<DateTime> days, DateTime today}),
          ({List<DateTime> days, DateTime today})
        >
    with $Provider<({List<DateTime> days, DateTime today})> {
  /// The local days S2 pages through, with the today they hang on.
  ///
  /// A phone left with the app open past midnight comes back on yesterday's «اليوم» and a
  /// window of days that starts a day late, so a resume asks this to recompute. Kept alive so
  /// the selection's index means the same day across a rebuild. «اليوم» is the chosen zone's
  /// day (M-R1-6), not the device's.
  MatchesWindowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matchesWindowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matchesWindowHash();

  @$internal
  @override
  $ProviderElement<({List<DateTime> days, DateTime today})> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ({List<DateTime> days, DateTime today}) create(Ref ref) {
    return matchesWindow(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({List<DateTime> days, DateTime today}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({List<DateTime> days, DateTime today})>(value),
    );
  }
}

String _$matchesWindowHash() => r'76c6c2d39f5f26fc504a615a11fab9a24c611f1d';
