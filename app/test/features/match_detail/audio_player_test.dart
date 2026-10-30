import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/audio/clip_controller.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/design/components/commentator_row.dart';

import '../../fixtures/fake_clip_engine.dart';
import '../../fixtures/test_app.dart';

/// One shared player (research R26): starting a clip stops the other, and a row moves
/// through idle, loading, playing and error. No audio plugin runs: [FakeClipEngine] stands in.
void main() {
  const urlA = 'https://media.test/clips/a.mp3';
  const urlB = 'https://media.test/clips/b.mp3';

  late FakeClipEngine engine;
  late ProviderContainer container;

  ClipState state() => container.read(clipControllerProvider);
  ClipController controller() => container.read(clipControllerProvider.notifier);

  setUp(() {
    engine = FakeClipEngine();
    container = ProviderContainer(overrides: [clipEngineProvider.overrideWithValue(engine)]);
    addTearDown(container.dispose);
  });

  group('the shared player', () {
    test('starts idle with nothing loaded', () {
      expect(state().phase, ClipPhase.idle);
      expect(state().url, isNull);
    });

    test('a clip is loading while the engine loads it, then playing', () async {
      engine.gate = Completer<void>();

      final playing = controller().play(urlA);
      await Future<void>.delayed(Duration.zero);
      expect(state().phaseOf(urlA), ClipPhase.loading);

      engine.gate!.complete();
      await playing;
      expect(state().phaseOf(urlA), ClipPhase.playing);
      expect(engine.started, [urlA]);
    });

    test('starting a clip stops the one that was playing', () async {
      await controller().play(urlA);
      await controller().play(urlB);

      expect(state().url, urlB);
      expect(state().phaseOf(urlA), ClipPhase.idle);
      expect(state().phaseOf(urlB), ClipPhase.playing);
      // The engine was told to stop before B started, so the two never overlap.
      expect(engine.calls, ['stop', 'start:$urlA', 'stop', 'start:$urlB']);
    });

    test('tapping the playing clip again stops it', () async {
      await controller().toggle(urlA);
      expect(state().phaseOf(urlA), ClipPhase.playing);

      await controller().toggle(urlA);

      expect(state().phase, ClipPhase.idle);
      expect(state().url, isNull);
    });

    test('a clip that cannot load is in the error state, and a retry can succeed', () async {
      engine.failing.add(urlA);

      await controller().play(urlA);
      expect(state().phaseOf(urlA), ClipPhase.error);
      expect(state().phaseOf(urlB), ClipPhase.idle);

      await controller().play(urlA);
      expect(state().phaseOf(urlA), ClipPhase.playing);
    });

    test('a clip address that is not https fails closed and never reaches the engine', () async {
      for (final url in [
        'http://media.test/clips/a.mp3',
        'file:///sdcard/clip.mp3',
        'content://media/external/audio/1',
        'asset:///clips/a.mp3',
        'not a link',
      ]) {
        await controller().play(url);

        expect(state().phaseOf(url), ClipPhase.error, reason: url);
      }
      expect(engine.started, isEmpty);
      expect(engine.calls.where((call) => call.startsWith('start:')), isEmpty);
    });

    test('progress moves while playing, and finishing returns to idle', () async {
      await controller().play(urlA);

      engine.emitProgress(0.4);
      expect(state().progress, closeTo(0.4, 0.0001));

      engine.complete();
      expect(state().phase, ClipPhase.idle);
      expect(state().progress, 0);
    });

    test('a slow load that was replaced cannot overwrite the clip that replaced it', () async {
      engine.gate = Completer<void>();
      final slowA = controller().play(urlA);
      await Future<void>.delayed(Duration.zero);

      final gateForA = engine.gate!;
      engine.gate = null;
      await controller().play(urlB);
      expect(state().phaseOf(urlB), ClipPhase.playing);

      gateForA.complete();
      await slowA;

      expect(state().url, urlB);
      expect(state().phaseOf(urlB), ClipPhase.playing);
    });

    test('stop clears the clip', () async {
      await controller().play(urlA);

      await controller().stop();

      expect(state().phase, ClipPhase.idle);
    });
  });

  group('CommentatorRow', () {
    CommentatorRef commentator({String? audio = urlA}) =>
        CommentatorRef(id: 1, name: 'عصام الشوالي', image: null, audio: audio);

    Widget row(CommentatorRef value, {String? url = urlA}) => UncontrolledProviderScope(
          container: container,
          child: testApp(
            CommentatorRow(commentator: value, sampleUrl: url),
          ),
        );

    testWidgets('shows the name and a play button when there is a sample', (tester) async {
      await tester.pumpWidget(row(commentator()));

      expect(find.text('عصام الشوالي'), findsOneWidget);
      expect(find.byTooltip('تشغيل مقطع صوتي لـ عصام الشوالي'), findsOneWidget);
    });

    testWidgets('with no sample it shows the name only, without a play button', (tester) async {
      await tester.pumpWidget(row(commentator(audio: null), url: null));

      expect(find.text('عصام الشوالي'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('a tap plays, shows the playing state, and a second tap stops it', (tester) async {
      await tester.pumpWidget(row(commentator()));

      await tester.tap(find.byTooltip('تشغيل مقطع صوتي لـ عصام الشوالي'));
      await tester.pump();
      await tester.pump();

      expect(state().phaseOf(urlA), ClipPhase.playing);
      expect(find.text('يُشغَّل الآن'), findsOneWidget);
      expect(find.byTooltip('إيقاف المقطع'), findsOneWidget);

      await tester.tap(find.byTooltip('إيقاف المقطع'));
      await tester.pump();
      await tester.pump();

      expect(state().phase, ClipPhase.idle);
      expect(find.text('يُشغَّل الآن'), findsNothing);
    });

    testWidgets('a failed load shows the error state, and tapping retries', (tester) async {
      engine.failing.add(urlA);
      await tester.pumpWidget(row(commentator()));

      await tester.tap(find.byTooltip('تشغيل مقطع صوتي لـ عصام الشوالي'));
      await tester.pump();
      await tester.pump();

      expect(find.text('تعذّر تشغيل المقطع'), findsOneWidget);

      await tester.tap(find.byTooltip('إعادة المحاولة'));
      await tester.pump();
      await tester.pump();

      expect(find.text('تعذّر تشغيل المقطع'), findsNothing);
      expect(state().phaseOf(urlA), ClipPhase.playing);
    });

    testWidgets('starting the second row stops the first', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: testApp(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CommentatorRow(commentator: commentator(), sampleUrl: urlA),
                const CommentatorRow(
                  commentator: CommentatorRef(id: 2, name: 'خالد الغندور', image: null, audio: urlB),
                  sampleUrl: urlB,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('تشغيل مقطع صوتي لـ عصام الشوالي'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('إيقاف المقطع'), findsOneWidget);

      await tester.tap(find.byTooltip('تشغيل مقطع صوتي لـ خالد الغندور'));
      await tester.pump();
      await tester.pump();

      // Exactly one row is playing, and it is the second.
      expect(find.byTooltip('إيقاف المقطع'), findsOneWidget);
      expect(find.byTooltip('تشغيل مقطع صوتي لـ عصام الشوالي'), findsOneWidget);
      expect(state().url, urlB);
    });
  });
}
