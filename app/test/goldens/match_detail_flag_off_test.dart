import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/features/live/live_poller.dart';
import 'package:madar_sat/features/match_detail/presentation/match_detail_page.dart';

import '../fixtures/sample_match_detail.dart';
import '../fixtures/sample_models.dart';
import 'golden_harness.dart';

const int _matchId = 48213;
const Size _size = Size(360, 1000);

/// S3 as it was before D6, in RTL × {light, dark} × {1.0, 1.3} (T088, SC-013).
///
/// These PNGs were generated from the page before any D6 code touched it, and they never
/// change in Lane M. Both matches carry events and lineups, so with `live_center` and
/// `lineups` at their bundled `false` the live center must add nothing to them.
void main() {
  late AppDatabase db;
  late RoutedApi api;

  setUp(() {
    api = RoutedApi();
    db = AppDatabase(
      NativeDatabase.memory(),
      now: sampleNow,
      offsetAt: (_) => const Duration(hours: 3),
    );
  });

  tearDown(() => db.close());

  Future<void> golden(
    WidgetTester tester,
    String name,
    MatchDetail detail, {
    List<LiveState> live = const [],
  }) async {
    api
      ..answer('/v1/matches/$_matchId', matchDetailJson(detail), etag: '"v1"')
      ..answer('/v1/satellites', satellitesJson([sampleSatelliteEntry(sampleSatellite)]));
    await goldenVariants(
      tester,
      name,
      (context) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          swrRepositoryProvider.overrideWithValue(SwrRepository(dio: api.dio, database: db)),
          clockProvider.overrideWithValue(() => sampleNow()),
          liveFetcherProvider.overrideWithValue(() async => live),
        ],
        child: SizedBox.fromSize(size: _size, child: const MatchDetailPage(matchId: _matchId)),
      ),
      size: _size,
    );
  }

  testWidgets('a live match with a feed', (tester) async {
    await golden(
      tester,
      'match_detail_flag_off_live',
      _withFeed(status: Status.live, score: _score(2, 1), minute: '67'),
      live: const [
        LiveState(
          matchId: _matchId,
          status: Status.live,
          estimated: false,
          minute: '67',
          period: Period.value2h,
          score: Score(home: 2, away: 1, homePen: null, awayPen: null),
          statusLabel: null,
          statusUpdatedAt: null,
        ),
      ],
    );
  });

  testWidgets('a finished match with a feed', (tester) async {
    await golden(
      tester,
      'match_detail_flag_off_finished',
      _withFeed(status: Status.finished, score: _score(2, 1)),
    );
  });
}

Score _score(int home, int away) => Score(home: home, away: away, homePen: null, awayPen: null);

MatchDetail _withFeed({required Status status, required Score score, String? minute}) =>
    sampleMatchDetail(
      status: status,
      score: score,
      minute: minute,
      kickoff: sampleKickoffAt(hour: 16),
      stadium: 'ستاد القاهرة',
      carriages: [
        sampleCarriageEntry(id: 1, name: 'ON Sport HD', access: Access.free),
        sampleCarriageEntry(
          id: 2,
          name: 'beIN SPORTS 1',
          satellite: badrSatellite,
          frequency: const Frequency(mhz: 10810, pol: Polarization.h, sr: 27500),
          commentators: const [sampleCommentator],
        ),
      ],
      events: const [
        MatchEvent(type: MatchEventType.goal, side: MatchEventSide.home, minute: '12', player: 'محمود كهربا'),
        MatchEvent(type: MatchEventType.redCard, side: MatchEventSide.away, minute: '45+2', player: 'محمد عواد'),
      ],
      lineups: const MatchLineups(
        home: LineupSide(
          formation: '4-3-3',
          players: [LineupPlayer(name: 'محمود كهربا', isStarter: true, number: 9, position: 'مهاجم')],
        ),
        away: null,
      ),
    );
