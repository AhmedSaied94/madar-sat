import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../links/url_opener.dart';
import 'just_audio_clip_engine.dart';

/// Where a clip is in its life: nothing, loading, playing, or failed to load.
enum ClipPhase { idle, loading, playing, error }

/// The shared player's state: which clip it holds, and how far through it is.
class ClipState {
  const ClipState({this.url, this.phase = ClipPhase.idle, this.progress = 0});

  final String? url;
  final ClipPhase phase;

  /// 0…1 through the clip, while [phase] is playing.
  final double progress;

  /// The phase as seen by the row that owns [clipUrl]: idle unless the player holds it.
  ClipPhase phaseOf(String clipUrl) => url == clipUrl ? phase : ClipPhase.idle;

  ClipState withProgress(double value) => ClipState(url: url, phase: phase, progress: value);
}

sealed class ClipEvent {
  const ClipEvent();
}

class ClipProgress extends ClipEvent {
  const ClipProgress(this.fraction);

  final double fraction;
}

class ClipCompleted extends ClipEvent {
  const ClipCompleted();
}

/// The audio plugin behind the controller (`just_audio` in the app, a fake in tests).
/// Feature code never imports the plugin directly (app/CLAUDE.md).
abstract interface class ClipEngine {
  /// Loads [url] and starts playing it. Throws when the clip cannot be loaded, or when a
  /// later [start] or [stop] interrupted this load.
  Future<void> start(String url);

  Future<void> stop();

  /// Progress and completion of whatever is playing.
  Stream<ClipEvent> get events;

  Future<void> dispose();
}

final clipEngineProvider = Provider<ClipEngine>((ref) {
  final engine = JustAudioClipEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

/// The one player for the whole app (research R26): starting a clip stops the other, and a
/// clip only ever starts from a tap (web blocks anything else).
class ClipController extends Notifier<ClipState> {
  int _generation = 0;
  StreamSubscription<ClipEvent>? _events;

  @override
  ClipState build() {
    _events = ref.watch(clipEngineProvider).events.listen(_onEvent);
    ref.onDispose(() => _events?.cancel());
    return const ClipState();
  }

  ClipEngine get _engine => ref.read(clipEngineProvider);

  /// Tap on a clip: stop it if it is the one in progress, otherwise play it.
  Future<void> toggle(String url) {
    final busy = state.phase == ClipPhase.playing || state.phase == ClipPhase.loading;
    return state.url == url && busy ? stop() : play(url);
  }

  Future<void> play(String url) async {
    final generation = ++_generation;
    await _engine.stop();
    if (generation != _generation) return;
    // The address is admin data and just_audio also opens `file:`, `content:` and `asset:`,
    // so only an `https` clip reaches the engine; anything else is the row's error state.
    final address = httpsUri(url);
    if (address == null) {
      state = ClipState(url: url, phase: ClipPhase.error);
      return;
    }
    state = ClipState(url: url, phase: ClipPhase.loading);
    try {
      await _engine.start(address.toString());
      if (generation != _generation) return;
      state = ClipState(url: url, phase: ClipPhase.playing);
    } catch (_) {
      // Also reached when a newer clip interrupted this load; the generation says which.
      if (generation != _generation) return;
      state = ClipState(url: url, phase: ClipPhase.error);
    }
  }

  Future<void> stop() async {
    _generation += 1;
    await _engine.stop();
    state = const ClipState();
  }

  void _onEvent(ClipEvent event) {
    switch (event) {
      case ClipProgress(:final fraction) when state.phase == ClipPhase.playing:
        state = state.withProgress(fraction);
      case ClipCompleted() when state.phase == ClipPhase.playing:
        state = const ClipState();
      default:
    }
  }
}

final clipControllerProvider = NotifierProvider<ClipController, ClipState>(ClipController.new);
