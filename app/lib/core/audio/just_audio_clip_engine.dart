import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'clip_controller.dart';

/// `just_audio` behind [ClipEngine] (SD §5.1; it works on web and Android).
///
/// The `AudioPlayer` is created on the first clip, so a screen that only contains a
/// commentator row never touches the plugin.
class JustAudioClipEngine implements ClipEngine {
  final StreamController<ClipEvent> _events = StreamController<ClipEvent>.broadcast();
  AudioPlayer? _player;

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    player.positionStream.listen((position) {
      final duration = player.duration;
      if (duration == null || duration <= Duration.zero) return;
      final fraction = position.inMilliseconds / duration.inMilliseconds;
      _events.add(ClipProgress(fraction.clamp(0.0, 1.0)));
    });
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _events.add(const ClipCompleted());
      }
    });
    return _player = player;
  }

  @override
  Stream<ClipEvent> get events => _events.stream;

  @override
  Future<void> start(String url) async {
    final player = _ensurePlayer();
    // A newer `setUrl` interrupts this one and this throws; the controller ignores it.
    await player.setUrl(url);
    // `play` completes when playback ends, so it is not awaited.
    unawaited(player.play());
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    await _events.close();
  }
}
