// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_poller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(liveFetcher)
final liveFetcherProvider = LiveFetcherProvider._();

final class LiveFetcherProvider
    extends $FunctionalProvider<LiveFetcher, LiveFetcher, LiveFetcher>
    with $Provider<LiveFetcher> {
  LiveFetcherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveFetcherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveFetcherHash();

  @$internal
  @override
  $ProviderElement<LiveFetcher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LiveFetcher create(Ref ref) {
    return liveFetcher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LiveFetcher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LiveFetcher>(value),
    );
  }
}

String _$liveFetcherHash() => r'ad79a1dfd139124bcf6204e14b8edc444f0a29b7';

/// The live states by match id: in memory only, never in drift (FR-047), replaced whole by
/// each answer so a match that left `/v1/live` drops out.
///
/// A state is only as good as the answer that brought it, so the whole map expires
/// [PollIntervals.liveStateTtl] after the last answer. Offline, a failing poll, or the app
/// in the background while a match ended therefore leaves the row's own status, never an
/// old score (constitution II, SC-008).

@ProviderFor(LiveStates)
final liveStatesProvider = LiveStatesProvider._();

/// The live states by match id: in memory only, never in drift (FR-047), replaced whole by
/// each answer so a match that left `/v1/live` drops out.
///
/// A state is only as good as the answer that brought it, so the whole map expires
/// [PollIntervals.liveStateTtl] after the last answer. Offline, a failing poll, or the app
/// in the background while a match ended therefore leaves the row's own status, never an
/// old score (constitution II, SC-008).
final class LiveStatesProvider
    extends $NotifierProvider<LiveStates, Map<int, LiveState>> {
  /// The live states by match id: in memory only, never in drift (FR-047), replaced whole by
  /// each answer so a match that left `/v1/live` drops out.
  ///
  /// A state is only as good as the answer that brought it, so the whole map expires
  /// [PollIntervals.liveStateTtl] after the last answer. Offline, a failing poll, or the app
  /// in the background while a match ended therefore leaves the row's own status, never an
  /// old score (constitution II, SC-008).
  LiveStatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveStatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveStatesHash();

  @$internal
  @override
  LiveStates create() => LiveStates();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<int, LiveState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<int, LiveState>>(value),
    );
  }
}

String _$liveStatesHash() => r'60fcc049de6553f50324d388fcd9d74265528a5a';

/// The live states by match id: in memory only, never in drift (FR-047), replaced whole by
/// each answer so a match that left `/v1/live` drops out.
///
/// A state is only as good as the answer that brought it, so the whole map expires
/// [PollIntervals.liveStateTtl] after the last answer. Offline, a failing poll, or the app
/// in the background while a match ended therefore leaves the row's own status, never an
/// old score (constitution II, SC-008).

abstract class _$LiveStates extends $Notifier<Map<int, LiveState>> {
  Map<int, LiveState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<int, LiveState>, Map<int, LiveState>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<int, LiveState>, Map<int, LiveState>>,
              Map<int, LiveState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The poll policy (FR-047, research R26, constitution VIII: the timers live in a provider,
/// not in a widget).
///
/// While a screen's route is visible and the app is `resumed`:
///
/// * [onRevalidate] runs every [PollIntervals.matches];
/// * `/v1/live` is fetched every [PollIntervals.live], and at once when polling starts,
///   but only while a live or imminent match is on screen.
///
/// Each mounted screen holds its own claim (`sync`, keyed by an object the scope owns), so
/// two screens stacked by the navigator never share one set of inputs: covering S2 with S3
/// stops S2's claim only, and the visible screen keeps polling (M-R2-3). Both stop when the
/// app is paused or when every claim is hidden, and restart when one is visible again.
/// `LivePollingScope` feeds the three inputs; nothing about the policy lives in the widget.

@ProviderFor(LivePolling)
final livePollingProvider = LivePollingProvider._();

/// The poll policy (FR-047, research R26, constitution VIII: the timers live in a provider,
/// not in a widget).
///
/// While a screen's route is visible and the app is `resumed`:
///
/// * [onRevalidate] runs every [PollIntervals.matches];
/// * `/v1/live` is fetched every [PollIntervals.live], and at once when polling starts,
///   but only while a live or imminent match is on screen.
///
/// Each mounted screen holds its own claim (`sync`, keyed by an object the scope owns), so
/// two screens stacked by the navigator never share one set of inputs: covering S2 with S3
/// stops S2's claim only, and the visible screen keeps polling (M-R2-3). Both stop when the
/// app is paused or when every claim is hidden, and restart when one is visible again.
/// `LivePollingScope` feeds the three inputs; nothing about the policy lives in the widget.
final class LivePollingProvider extends $NotifierProvider<LivePolling, void> {
  /// The poll policy (FR-047, research R26, constitution VIII: the timers live in a provider,
  /// not in a widget).
  ///
  /// While a screen's route is visible and the app is `resumed`:
  ///
  /// * [onRevalidate] runs every [PollIntervals.matches];
  /// * `/v1/live` is fetched every [PollIntervals.live], and at once when polling starts,
  ///   but only while a live or imminent match is on screen.
  ///
  /// Each mounted screen holds its own claim (`sync`, keyed by an object the scope owns), so
  /// two screens stacked by the navigator never share one set of inputs: covering S2 with S3
  /// stops S2's claim only, and the visible screen keeps polling (M-R2-3). Both stop when the
  /// app is paused or when every claim is hidden, and restart when one is visible again.
  /// `LivePollingScope` feeds the three inputs; nothing about the policy lives in the widget.
  LivePollingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'livePollingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$livePollingHash();

  @$internal
  @override
  LivePolling create() => LivePolling();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$livePollingHash() => r'01aaed9aed18026ef9d1414cc1cf95a38d8a4a01';

/// The poll policy (FR-047, research R26, constitution VIII: the timers live in a provider,
/// not in a widget).
///
/// While a screen's route is visible and the app is `resumed`:
///
/// * [onRevalidate] runs every [PollIntervals.matches];
/// * `/v1/live` is fetched every [PollIntervals.live], and at once when polling starts,
///   but only while a live or imminent match is on screen.
///
/// Each mounted screen holds its own claim (`sync`, keyed by an object the scope owns), so
/// two screens stacked by the navigator never share one set of inputs: covering S2 with S3
/// stops S2's claim only, and the visible screen keeps polling (M-R2-3). Both stop when the
/// app is paused or when every claim is hidden, and restart when one is visible again.
/// `LivePollingScope` feeds the three inputs; nothing about the policy lives in the widget.

abstract class _$LivePolling extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
