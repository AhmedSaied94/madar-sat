import 'dart:async';

import 'package:madar_sat/core/audio/clip_controller.dart';

/// A scripted [ClipEngine]: it records what was started and stopped, and lets a test hold a
/// load open, fail it, or push progress, without any audio plugin.
class FakeClipEngine implements ClipEngine {
  final List<String> started = [];
  int stops = 0;

  /// Order of calls, as `start:<url>` and `stop`, to assert that one clip stops the other.
  final List<String> calls = [];

  /// URLs whose next `start` fails, as a clip that cannot be loaded does.
  final Set<String> failing = {};

  /// While set, `start` waits for it: the clip stays in its loading state.
  Completer<void>? gate;

  final StreamController<ClipEvent> _events = StreamController<ClipEvent>.broadcast(sync: true);

  void emitProgress(double fraction) => _events.add(ClipProgress(fraction));

  void complete() => _events.add(const ClipCompleted());

  @override
  Stream<ClipEvent> get events => _events.stream;

  @override
  Future<void> start(String url) async {
    calls.add('start:$url');
    final hold = gate;
    if (hold != null) await hold.future;
    if (failing.remove(url)) throw StateError('cannot load $url');
    started.add(url);
  }

  @override
  Future<void> stop() async {
    stops += 1;
    calls.add('stop');
  }

  @override
  Future<void> dispose() => _events.close();
}
