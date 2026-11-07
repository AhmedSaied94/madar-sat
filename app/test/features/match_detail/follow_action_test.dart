import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/network/generated/models/status.dart';
import 'package:madar_sat/features/match_detail/presentation/match_follow_button.dart';
import 'package:madar_sat/features/follows/data/follows_repository.dart';
import 'package:madar_sat/features/match_detail/domain/carriage_order.dart';
import 'package:madar_sat/features/match_detail/presentation/where_to_watch_slivers.dart';
import 'package:madar_sat/features/match_detail/presentation/where_to_watch_state.dart';
import 'package:madar_sat/l10n/app_localizations.dart';
import 'package:madar_sat/core/theme/madar_theme.dart';

/// S3's follow actions (US2 scenario 9, contract app-screens): with no channels the next
/// action is «تابع المباراة», which follows the match; while the O10 defaults stand in the
/// «حدد أقمارك» chip opens the picker.
void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 1, 9)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<void> pump(
    WidgetTester tester, {
    required String matchId,
    bool showChooseSatellites = false,
    VoidCallback? onChooseSatellites,
  }) async {
    final l = await _localizations();
    final slivers = WhereToWatchSlivers(
      l: l,
      all: const WhereToWatch(),
      shown: const WhereToWatch(),
      state: const WhereToWatchState(),
      controller: container.read(whereToWatchProvider(1).notifier),
      mineTitle: 'على نايل سات وبدر',
      receptionOf: (satellite) => null,
      onWatchReception: (_) {},
      onRefresh: () {},
      matchId: int.parse(matchId),
      kickoffAt: null,
      status: Status.scheduled,
      estimated: false,
      showChooseSatellites: showChooseSatellites,
      onChooseSatellites: onChooseSatellites,
    ).build();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: MadarTheme.dark,
          home: Scaffold(body: CustomScrollView(slivers: slivers)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no channels offers «تابع المباراة», which writes the follow', (tester) async {
    await pump(tester, matchId: '7');

    expect(find.text('لم تُضف القنوات الناقلة بعد'), findsOneWidget);
    expect(find.text('تابع المباراة'), findsOneWidget);

    await tester.tap(find.text('تابع المباراة'));
    await tester.pumpAndSettle();

    expect(
      (await database.readFollows()).where((row) => row.kind == 'match' && row.targetId == 7),
      hasLength(1),
    );
  });

  testWidgets('following again says «تتابع المباراة» and removes the follow', (tester) async {
    await database.setFollow(kind: 'match', targetId: 7, on: true);
    container.listen(followsSetProvider, (_, _) {});
    await pump(tester, matchId: '7');

    expect(find.text('تتابع المباراة'), findsOneWidget);
    await tester.tap(find.text('تتابع المباراة'));
    await tester.pumpAndSettle();

    expect(await database.readFollows(), isEmpty);
  });

  testWidgets('the «حدد أقمارك» chip shows only while the defaults stand in', (tester) async {
    var opened = 0;
    await pump(
      tester,
      matchId: '7',
      showChooseSatellites: true,
      onChooseSatellites: () => opened++,
    );

    expect(find.text('حدد أقمارك'), findsOneWidget);
    await tester.tap(find.text('حدد أقمارك'));
    expect(opened, 1);

    await pump(tester, matchId: '7');
    expect(find.text('حدد أقمارك'), findsNothing);
  });

  group('following a started match (FR-060)', () {
    final kickoff = DateTime.utc(2026, 11, 1, 8);

    Future<void> tapFollow(
      WidgetTester tester, {
      required Status status,
      required bool estimated,
      DateTime? kickoffAt,
    }) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: MadarTheme.dark,
            home: Scaffold(
              body: MatchFollowButton(
                matchId: 7,
                kickoffAt: kickoffAt ?? kickoff,
                status: status,
                estimated: estimated,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تابع المباراة'));
      await tester.pump();
    }

    const alerts = 'بدأت المباراة، ستصلك تنبيهاتها حسب إعداداتك';
    const noReminder = 'بدأت المباراة، فلن يصلك تذكير بها';

    for (final status in [Status.live, Status.halftime, Status.extraTime, Status.penalties]) {
      testWidgets('in play as $status with a feed: the alerts note', (tester) async {
        await tapFollow(tester, status: status, estimated: false);
        expect(find.text(alerts), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
      });
    }

    testWidgets('estimated: today\'s note, because no alert will come', (tester) async {
      await tapFollow(tester, status: Status.live, estimated: true);
      expect(find.text(noReminder), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('finished: today\'s note', (tester) async {
      await tapFollow(tester, status: Status.finished, estimated: false);
      expect(find.text(noReminder), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('no live state, so shown as scheduled after kickoff: today\'s note',
        (tester) async {
      await tapFollow(tester, status: Status.scheduled, estimated: false);
      expect(find.text(noReminder), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('before kickoff there is no note', (tester) async {
      await tapFollow(
        tester,
        status: Status.scheduled,
        estimated: false,
        kickoffAt: DateTime.utc(2026, 11, 1, 20),
      );
      expect(find.text(alerts), findsNothing);
      expect(find.text(noReminder), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}

/// FR-060: following a started match says what will really come.
Future<AppLocalizations> _localizations() async {
  final delegate = AppLocalizations.delegate;
  return delegate.load(const Locale('ar'));
}
