import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/api_failure.dart';
import '../../core/network/dio_provider.dart';
import '../../core/network/generated/models/live_state.dart';

part 'live_poller.g.dart';

/// The polling intervals (FR-047). These are the bundled defaults until Remote Config
/// arrives on D3 (plan.md Complexity Tracking), so changing one is a new build.
abstract final class PollIntervals {
  static const Duration matches = Duration(seconds: 60);
  static const Duration live = Duration(seconds: 30);

  /// How long a live state may stand without a newer `/v1/live` answer: two intervals, so
  /// one missed poll does not blank a score but a feed that stopped answering cannot keep a
  /// finished match "live" on screen.
  static const Duration liveStateTtl = Duration(seconds: 60);
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

  @override
  Map<int, LiveState> build() {
    ref.onDispose(() => _expiry?.cancel());
    return const {};
  }

  void replaceAll(List<LiveState> states) {
    state = {for (final live in states) live.matchId: live};
    _expiry?.cancel();
    _expiry = states.isEmpty ? null : Timer(PollIntervals.liveStateTtl, clear);
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
/// While the screen's route is visible and the app is `resumed`:
///
/// * [onRevalidate] runs every [PollIntervals.matches];
/// * `/v1/live` is fetched every [PollIntervals.live], and at once when polling starts,
///   but only while a live or imminent match is on screen.
///
/// Both stop when the app is paused or another route covers this one, and restart when it
/// is visible again. `LivePollingScope` feeds the three inputs; nothing about the policy
/// lives in the widget.
@riverpod
class LivePolling extends _$LivePolling {
  Timer? _matchesTimer;
  Timer? _liveTimer;
  bool _visible = true;
  bool _resumed = true;
  bool _hasLiveOrImminent = false;
  VoidCallback? _onRevalidate;

  @override
  void build() => ref.onDispose(_stopAll);

  /// The widget's inputs: whether its route is visible, whether the app is resumed, and
  /// whether `/v1/live` is worth asking. [onRevalidate] refreshes the screen's own data.
  void sync({
    required bool visible,
    required bool resumed,
    required bool hasLiveOrImminent,
    VoidCallback? onRevalidate,
  }) {
    _visible = visible;
    _resumed = resumed;
    _hasLiveOrImminent = hasLiveOrImminent;
    _onRevalidate = onRevalidate ?? _onRevalidate;
    _apply();
  }

  void _apply() {
    final active = _visible && _resumed;

    if (active) {
      _matchesTimer ??= Timer.periodic(PollIntervals.matches, (_) => _onRevalidate?.call());
    } else {
      _matchesTimer?.cancel();
      _matchesTimer = null;
    }

    if (active && _hasLiveOrImminent) {
      if (_liveTimer == null) {
        _liveTimer = Timer.periodic(PollIntervals.live, (_) => unawaited(_fetchLive()));
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
    super.dispose();
  }

  void _sync() => ref.read(livePollingProvider.notifier).sync(
        visible: _visible,
        resumed: _resumed,
        hasLiveOrImminent: widget.hasLiveOrImminent,
        onRevalidate: widget.onRevalidate,
      );

  @override
  Widget build(BuildContext context) {
    // Watched so the poller lives exactly as long as this scope does: the policy's timers
    // are cancelled when the provider is disposed.
    ref.watch(livePollingProvider);
    return widget.child;
  }
}
