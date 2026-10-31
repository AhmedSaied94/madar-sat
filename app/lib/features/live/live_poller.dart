import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_failure.dart';
import '../../core/network/dio_provider.dart';
import '../../core/network/generated/models/live_state.dart';

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

final liveFetcherProvider = Provider<LiveFetcher>((ref) {
  final client = ref.watch(madarApiClientProvider);
  return () async {
    final envelope = await client.getLiveV1LiveGet();
    final data = envelope.data;
    if (!envelope.success || data == null) {
      throw ApiFailure(code: envelope.error?.code);
    }
    return data;
  };
});

/// The live states by match id: in memory only, never in drift (FR-047), replaced whole by
/// each answer so a match that left `/v1/live` drops out.
///
/// A state is only as good as the answer that brought it, so the whole map expires
/// [PollIntervals.liveStateTtl] after the last answer. Offline, a failing poll, or the app
/// in the background while a match ended therefore leaves the quiet estimated «مباشر» (or
/// the row's own status), never an old score (constitution II, SC-008).
class LiveStates extends Notifier<Map<int, LiveState>> {
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

final liveStatesProvider = NotifierProvider<LiveStates, Map<int, LiveState>>(LiveStates.new);

/// Keeps one screen's data current while it can be seen (FR-047, research R26).
///
/// While the screen's route is visible and the app is `resumed`:
///
/// * [onRevalidate] runs every [PollIntervals.matches];
/// * `/v1/live` is fetched every [PollIntervals.live], and at once when polling starts,
///   but only while [hasLiveOrImminent] is true.
///
/// Both stop when the app is paused or another route covers this one, and restart when it
/// is visible again. Put it around a screen's body; it adds nothing to the layout.
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

class _LivePollingScopeState extends ConsumerState<LivePollingScope> with WidgetsBindingObserver {
  Timer? _matchesTimer;
  Timer? _liveTimer;
  bool _visible = true;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchesTimer?.cancel();
    _liveTimer?.cancel();
    super.dispose();
  }

  void _sync() {
    final active = _visible && _resumed;

    if (active) {
      _matchesTimer ??= Timer.periodic(PollIntervals.matches, (_) => widget.onRevalidate?.call());
    } else {
      _matchesTimer?.cancel();
      _matchesTimer = null;
    }

    if (active && widget.hasLiveOrImminent) {
      if (_liveTimer == null) {
        _liveTimer = Timer.periodic(PollIntervals.live, (_) => _fetchLive());
        unawaited(_fetchLive());
      }
    } else {
      _liveTimer?.cancel();
      _liveTimer = null;
    }
  }

  Future<void> _fetchLive() async {
    try {
      final states = await ref.read(liveFetcherProvider)();
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) => widget.child;
}
