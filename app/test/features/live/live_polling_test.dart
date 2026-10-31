import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/live/live_poller.dart';

import '../../fixtures/test_app.dart';

LiveState _state(int id, {int home = 0}) => LiveState(
      matchId: id,
      status: Status.live,
      statusLabel: null,
      period: Period.value1h,
      minute: '12',
      score: Score(home: home, away: 0, homePen: null, awayPen: null),
      estimated: false,
      statusUpdatedAt: DateTime.utc(2026, 10, 28, 18, 12),
    );

/// FR-047: matches revalidate every 60 s and `/v1/live` every 30 s, only while the route is
/// visible, the app is resumed, and (for `/v1/live`) a live or imminent match is on screen.
/// Time is the test's fake clock, so nothing here waits.
void main() {
  late List<List<LiveState>> answers;
  late int liveCalls;
  late int revalidations;
  late AppDatabase database;

  setUp(() {
    answers = [
      [_state(1)],
    ];
    liveCalls = 0;
    revalidations = 0;
    database = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() => database.close());

  Future<List<LiveState>> fetchLive() async {
    liveCalls += 1;
    return answers.length > 1 ? answers.removeAt(0) : answers.first;
  }

  ProviderScope scoped(Widget child) => ProviderScope(
        overrides: [
          liveFetcherProvider.overrideWithValue(fetchLive),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: child,
      );

  Widget scope({required bool live, Widget child = const SizedBox()}) => scoped(
        testApp(
          LivePollingScope(
            hasLiveOrImminent: live,
            onRevalidate: () => revalidations += 1,
            child: child,
          ),
        ),
      );

  Future<void> elapse(WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
    await tester.pump();
  }

  testWidgets('the bundled defaults are 60 s and 30 s', (tester) async {
    expect(PollIntervals.matches, const Duration(seconds: 60));
    expect(PollIntervals.live, const Duration(seconds: 30));
  });

  testWidgets('with a live match on screen: live every 30 s, matches every 60 s', (tester) async {
    await tester.pumpWidget(scope(live: true));
    await tester.pump();
    // The live state is fetched as soon as it is wanted, so the row is not stale for 30 s.
    expect(liveCalls, 1);

    await elapse(tester, const Duration(seconds: 30));
    expect(liveCalls, 2);
    expect(revalidations, 0);

    await elapse(tester, const Duration(seconds: 30));
    expect(liveCalls, 3);
    expect(revalidations, 1);

    await elapse(tester, const Duration(seconds: 60));
    expect(liveCalls, 5);
    expect(revalidations, 2);
  });

  testWidgets('with nothing live or imminent, only the matches revalidate', (tester) async {
    await tester.pumpWidget(scope(live: false));

    await elapse(tester, const Duration(seconds: 120));

    expect(liveCalls, 0);
    expect(revalidations, 2);
  });

  testWidgets('both stop while the app is paused, and start again when it resumes',
      (tester) async {
    await tester.pumpWidget(scope(live: true));
    await tester.pump();
    final callsBefore = liveCalls;

    // The lifecycle listener follows the platform's state machine, so backgrounding goes
    // through each step, as a real device reports it.
    for (final state in const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await elapse(tester, const Duration(seconds: 180));
    expect(liveCalls, callsBefore);
    expect(revalidations, 0);

    for (final state in const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(liveCalls, callsBefore + 1, reason: 'resuming fetches the live state again');
    await elapse(tester, const Duration(seconds: 60));
    expect(revalidations, 1);
  });

  testWidgets('both stop while another route covers this one', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      scoped(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: LivePollingScope(
            hasLiveOrImminent: true,
            onRevalidate: () => revalidations += 1,
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(liveCalls, 1);

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('detail'))),
    );
    await tester.pumpAndSettle();
    final callsCovered = liveCalls;
    final revalidationsCovered = revalidations;

    await elapse(tester, const Duration(seconds: 180));
    expect(liveCalls, callsCovered);
    expect(revalidations, revalidationsCovered);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await elapse(tester, const Duration(seconds: 60));
    expect(revalidations, greaterThan(revalidationsCovered));
  });

  testWidgets('turning live off stops the live poll but not the matches', (tester) async {
    await tester.pumpWidget(scope(live: true));
    await tester.pump();

    await tester.pumpWidget(scope(live: false));
    final calls = liveCalls;
    await elapse(tester, const Duration(seconds: 60));

    expect(liveCalls, calls);
    expect(revalidations, 1);
  });

  testWidgets('leaving the screen cancels both timers', (tester) async {
    await tester.pumpWidget(scope(live: true));
    await tester.pump();
    await tester.pumpWidget(scoped(testApp(const SizedBox())));
    final calls = liveCalls;

    await elapse(tester, const Duration(seconds: 180));

    expect(liveCalls, calls);
    expect(revalidations, 0);
  });

  testWidgets('live states are kept in memory and replaced by each answer', (tester) async {
    answers = [
      [_state(1), _state(2)],
      [_state(1, home: 1)],
    ];
    late ProviderContainer container;
    await tester.pumpWidget(
      scoped(
        Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return testApp(
              LivePollingScope(
                hasLiveOrImminent: true,
                onRevalidate: () {},
                child: const SizedBox(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(container.read(liveStatesProvider).keys, {1, 2});

    await elapse(tester, const Duration(seconds: 30));

    // Match 2 left /v1/live, so it is gone; match 1 has its new score.
    expect(container.read(liveStatesProvider).keys, {1});
    expect(container.read(liveStatesProvider)[1]!.score?.home, 1);
  });

  testWidgets('live states are never written to drift (FR-047)', (tester) async {
    await tester.pumpWidget(scope(live: true));
    await tester.pump();
    await elapse(tester, const Duration(seconds: 60));

    expect(await database.readAll(), isEmpty);
    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE '%live%'")
        .get();
    expect(tables, isEmpty);
  });

  testWidgets('the poll policy is a notifier: its timers follow the three inputs',
      (tester) async {
    var liveCalls = 0;
    var revalidations = 0;
    final container = ProviderContainer(
      overrides: [
        liveFetcherProvider.overrideWithValue(() async {
          liveCalls += 1;
          return [_state(1)];
        }),
      ],
    );
    addTearDown(container.dispose);
    // A listener, as a screen has: Riverpod 3 pauses a provider nobody listens to.
    container.listen(livePollingProvider, (previous, next) {});

    container.read(livePollingProvider.notifier).sync(
          visible: true,
          resumed: true,
          hasLiveOrImminent: true,
          onRevalidate: () => revalidations += 1,
        );
    await tester.pump();
    expect(liveCalls, 1, reason: 'the live state is fetched as soon as it is wanted');

    await tester.pump(const Duration(seconds: 60));
    expect(revalidations, 1);

    container.read(livePollingProvider.notifier).sync(
          visible: false,
          resumed: true,
          hasLiveOrImminent: true,
        );
    final callsAtHide = liveCalls;
    final revalidationsAtHide = revalidations;
    await tester.pump(const Duration(seconds: 180));
    expect(liveCalls, callsAtHide, reason: 'a covered route polls nothing');
    expect(revalidations, revalidationsAtHide);
  });

  testWidgets('a failed live fetch keeps the last states and the next tick tries again',
      (tester) async {
    var calls = 0;
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveFetcherProvider.overrideWithValue(() async {
            calls += 1;
            if (calls == 2) throw StateError('offline');
            return [_state(1, home: calls)];
          }),
          appDatabaseProvider.overrideWithValue(database),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return testApp(
              LivePollingScope(
                hasLiveOrImminent: true,
                onRevalidate: () {},
                child: const SizedBox(),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    expect(container.read(liveStatesProvider)[1]!.score?.home, 1);

    await elapse(tester, const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
    expect(container.read(liveStatesProvider)[1]!.score?.home, 1, reason: 'kept');

    await elapse(tester, const Duration(seconds: 30));
    expect(container.read(liveStatesProvider)[1]!.score?.home, 3);
  });
}
