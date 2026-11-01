import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/remote_config.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/dio_provider.dart';
import '../../core/network/generated/models/live_state.dart';

part 'live_poller.g.dart';

/// The polling intervals (FR-047). `/v1/live`'s interval comes from Remote Config on D3
/// ([livePollIntervalProvider], 30 s by default, R28); the matches revalidation keeps its
/// bundled 60 s.
abstract final class PollIntervals {
  static const Duration matches = Duration(seconds: 60);

  /// How long a live state may stand without a newer `/v1/live` answer: two intervals, so
  /// one missed poll does not blank a score but a feed that stopped answering cannot keep a
  /// finished match "live" on screen.
  static Duration liveStateTtl(Duration interval) => interval * 2;
}

/// Fetches `/v1/live`. A provider so a test can answer without a server.
typedef LiveFetcher = Future<List<LiveState>> Function();

@Riverpod(keepAlive: true)
LiveFetcher liveFetcher(Ref ref) {
  final client = ref.watch(madarApiClientProvider);
  return () async {
    final envelope = (await client.getLiveV1LiveGet()).data;
    final data = envelope.data;
    if (!envelope.success || data == null) {
      throw ApiFailure(code: envelope.error?.code);
    }
    return data;
  };
}

/// The live states by match id: in memory only, never in drift (FR-047), replaced whole by
/// each answer so a match that left `/v1/live` drops out.
///
/// A state is only as good as the answer that brought it, so the whole map expires
/// [PollIntervals.liveStateTtl] after the last answer. Offline, a failing poll, or the app
/// in the background while a match ended therefore leaves the row's own status, never an
/// old score (constitution II, SC-008).
@Riverpod(keepAlive: true)
class LiveStates extends _$LiveStates {
  Timer? _expiry;
  Duration _ttl = PollIntervals.liveStateTtl(
    const Duration(seconds: RemoteConfigValues.defaultLivePollSeconds),
  );

  @override
  Map<int, LiveState> build() {
    _ttl = PollIntervals.liveStateTtl(ref.watch(livePollIntervalProvider));
    ref.onDispose(() => _expiry?.cancel());
    return const {};
  }

  void replaceAll(List<LiveState> states) {
    state = {for (final live in states) live.matchId: live};
    _expiry?.cancel();
    _expiry = states.isEmpty ? null : Timer(_ttl, clear);
  }

  void clear() {
    _expiry?.cancel();
    _expiry = null;
    state = const {};
  }
}

/// The poll policy (FR-047, research R26, constitution VIII: the timers live in a provider,
/// not in a widget).
///
/// While a screen's route is visible and the app is `resumed`:
///
/// * [onRevalidate] runs every [PollIntervals.matches];
/// * `/v1/live` is fetched every Remote Config interval (`livePollIntervalProvider`), and
///   at once when polling starts, but only while a live or imminent match is on screen.
///
/// Each mounted screen holds its own claim (`sync`, keyed by an object the scope owns), so
/// two screens stacked by the navigator never share one set of inputs: covering S2 with S3
/// stops S2's claim only, and the visible screen keeps polling (M-R2-3). Both stop when the
/// app is paused or when every claim is hidden, and restart when one is visible again.
/// `LivePollingScope` feeds the three inputs; nothing about the policy lives in the widget.
@riverpod
class LivePolling extends _$LivePolling {
  Timer? _matchesTimer;
  Timer? _liveTimer;
  Duration _liveInterval = const Duration(seconds: RemoteConfigValues.defaultLivePollSeconds);
  final Map<Object, _Claim> _claims = {};

  @override
  void build() {
    _liveInterval = ref.watch(livePollIntervalProvider);
    ref.onDispose(() {
      _stopAll();
      _claims.clear();
    });
  }

  /// One screen's inputs: whether its route is visible, whether the app is resumed, whether
  /// `/v1/live` is worth asking, and how to refresh the screen's own data.
  void sync(
    Object scope, {
    required bool visible,
    required bool resumed,
    required bool hasLiveOrImminent,
    VoidCallback? onRevalidate,
  }) {
    if (!ref.mounted) return;
    final claim = _claims.putIfAbsent(scope, _Claim.new);
    claim
      ..visible = visible
      ..resumed = resumed
      ..hasLiveOrImminent = hasLiveOrImminent
      ..onRevalidate = onRevalidate ?? claim.onRevalidate;
    _apply();
  }

  /// A screen that is gone polls nothing, and its callback is never called again.
  void release(Object scope) {
    if (!ref.mounted) return;
    _claims.remove(scope);
    _apply();
  }

  /// Every claim of a screen that is on screen: only these drive the timers.
  Iterable<_Claim> get _active => _claims.values.where((claim) => claim.visible && claim.resumed);

  void _apply() {
    if (!ref.mounted) return;
    final active = _active.toList();
    if (active.isEmpty) {
      _stopAll();
      return;
    }

    _matchesTimer ??= Timer.periodic(PollIntervals.matches, (_) {
      for (final claim in _active) {
        claim.onRevalidate?.call();
      }
    });

    if (active.any((claim) => claim.hasLiveOrImminent)) {
      if (_liveTimer == null) {
        _liveTimer = Timer.periodic(_liveInterval, (_) => unawaited(_fetchLive()));
        unawaited(_fetchLive());
      }
    } else {
      _liveTimer?.cancel();
      _liveTimer = null;
    }
  }

  void _stopAll() {
    _matchesTimer?.cancel();
    _liveTimer?.cancel();
    _matchesTimer = null;
    _liveTimer = null;
  }

  Future<void> _fetchLive() async {
    try {
      final states = await ref.read(liveFetcherProvider)();
      if (!ref.mounted) return;
      ref.read(liveStatesProvider.notifier).replaceAll(states);
    } catch (error, stackTrace) {
      // The last states stay until they expire (`LiveStates`) and the next tick tries
      // again. Crash reporting arrives on D3, behind its interface; until then the failure
      // is in the developer log.
      developer.log(
        'live poll failed',
        name: 'madar.live',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// One screen's inputs to [LivePolling].
class _Claim {
  bool visible = true;
  bool resumed = true;
  bool hasLiveOrImminent = false;
  VoidCallback? onRevalidate;
}

/// Keeps one screen's data current while it can be seen. It adds nothing to the layout, and
/// only feeds [LivePolling] the three things it cannot know: visibility, lifecycle and
/// whether a live answer would matter.
class LivePollingScope extends ConsumerStatefulWidget {
  const LivePollingScope({
    super.key,
    required this.child,
    required this.hasLiveOrImminent,
    this.onRevalidate,
  });

  final Widget child;
  final bool hasLiveOrImminent;

  /// Revalidate this screen's matches (usually `ref.invalidate` on its provider).
  final VoidCallback? onRevalidate;

  @override
  ConsumerState<LivePollingScope> createState() => _LivePollingScopeState();
}

class _LivePollingScopeState extends ConsumerState<LivePollingScope> {
  late final AppLifecycleListener _lifecycle;

  /// This screen's own claim on [LivePolling], so covering it never stops another screen's
  /// timers (M-R2-3).
  final Object _claim = Object();
  LivePolling? _polling;
  bool _visible = true;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _resumed = state == null || state == AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _resumed = state == AppLifecycleState.resumed;
        _sync();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route that another one covers is built with its tickers off, which is the
    // framework's own "this is not on screen" signal.
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(LivePollingScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // The claim goes with the screen; if this was the last one, the policy's own dispose
    // cancels the timers.
    _polling?.release(_claim);
    super.dispose();
  }

  void _sync() {
    final polling = ref.read(livePollingProvider.notifier);
    _polling = polling;
    polling.sync(
      _claim,
      visible: _visible,
      resumed: _resumed,
      hasLiveOrImminent: widget.hasLiveOrImminent,
      onRevalidate: widget.onRevalidate,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the poller lives exactly as long as this scope does: the policy's timers
    // are cancelled when the provider is disposed.
    ref.watch(livePollingProvider);
    return widget.child;
  }
}
