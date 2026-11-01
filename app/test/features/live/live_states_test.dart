import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/config/remote_config.dart';
import 'package:madar_sat/features/live/live_poller.dart';

LiveState _state(int id, {int home = 0}) => LiveState(
      matchId: id,
      status: Status.live,
      statusLabel: null,
      period: Period.value1h,
      minute: '67',
      score: Score(home: home, away: 0, homePen: null, awayPen: null),
      estimated: false,
      statusUpdatedAt: DateTime.utc(2026, 10, 28, 18, 12),
    );

/// A live score is only as good as the last `/v1/live` answer. If no answer refreshes it
/// (offline, a failing poll, the app in the background while the match ended), it must not
/// stay on screen: constitution II, SC-008.
void main() {
  late ProviderContainer container;

  Map<int, LiveState> states() => container.read(liveStatesProvider);
  LiveStates notifier() => container.read(liveStatesProvider.notifier);

  setUp(() {
    container = ProviderContainer();
    // Hold the provider the way a screen watching it would.
    container.listen(liveStatesProvider, (_, _) {});
    addTearDown(container.dispose);
  });

  const live = Duration(seconds: RemoteConfigValues.defaultLivePollSeconds);
  const ttl = Duration(seconds: RemoteConfigValues.defaultLivePollSeconds * 2);

  test('the expiry is two poll intervals, so one missed poll does not blank the score', () {
    expect(PollIntervals.liveStateTtl(live), ttl);
  });

  testWidgets('states expire when no answer refreshes them in time', (tester) async {
    notifier().replaceAll([_state(1)]);

    await tester.pump(ttl - const Duration(seconds: 1));
    expect(states(), isNotEmpty);

    await tester.pump(const Duration(seconds: 2));
    expect(states(), isEmpty);
  });

  testWidgets('each answer starts the clock again', (tester) async {
    notifier().replaceAll([_state(1)]);
    await tester.pump(live);

    notifier().replaceAll([_state(1, home: 1)]);
    await tester.pump(ttl - const Duration(seconds: 1));
    expect(states()[1]!.score!.home, 1, reason: 'the second answer is still inside its own time');

    await tester.pump(const Duration(seconds: 2));
    expect(states(), isEmpty);
  });

  testWidgets('an empty answer clears at once and leaves no timer behind', (tester) async {
    notifier().replaceAll([_state(1)]);

    notifier().replaceAll(const []);

    expect(states(), isEmpty);
    // A pending timer would fail this test when it ends.
  });

  testWidgets('clear drops every state and the pending expiry', (tester) async {
    notifier().replaceAll([_state(1), _state(2)]);

    notifier().clear();

    expect(states(), isEmpty);
  });
}
