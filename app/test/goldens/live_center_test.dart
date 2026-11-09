import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';

import '../fixtures/sample_match_detail.dart';
import 'golden_harness.dart';
import 'live_center_harness.dart';

const Size _size = Size(360, 520);

const _events = [
  MatchEvent(
    type: MatchEventType.goal,
    side: MatchEventSide.home,
    minute: '23',
    player: 'محمد صلاح',
  ),
  MatchEvent(
    type: MatchEventType.missedPenalty,
    side: MatchEventSide.away,
    minute: '52',
    player: 'كول بالمر',
  ),
  MatchEvent(
    type: MatchEventType.redCard,
    side: MatchEventSide.away,
    minute: '61',
    player: 'مويسيس كايسيدو',
  ),
];

const _score = Score(home: 1, away: 0, homePen: null, awayPen: null);

/// S3's live center with the flags on, as `Match-Live.html` draws it (T102, FR-064). The flag
/// off is `match_detail_flag_off_test.dart`.
void main() {
  testWidgets('the timeline while live', (tester) async {
    await goldenVariants(
      tester,
      'live_center_live',
      (context) => liveCenterGolden(
        sampleMatchDetail(status: Status.live, score: _score, events: _events),
        size: _size,
      ),
      size: _size,
    );
  });

  testWidgets('the timeline once finished, with its tabs', (tester) async {
    await goldenVariants(
      tester,
      'live_center_finished',
      (context) => liveCenterGolden(
        sampleMatchDetail(
          status: Status.finished,
          score: _score,
          events: _events,
          lineups: const MatchLineups(
            home: LineupSide(
              formation: '4-3-3',
              players: [LineupPlayer(name: 'أليسون', isStarter: true, number: 1, position: null)],
            ),
            away: null,
          ),
        ),
        size: _size,
      ),
      size: _size,
    );
  });

  testWidgets('estimated: only the note', (tester) async {
    await goldenVariants(
      tester,
      'live_center_estimated',
      (context) => liveCenterGolden(
        sampleMatchDetail(status: Status.live, estimated: true, events: _events),
        size: const Size(360, 120),
      ),
      size: const Size(360, 120),
    );
  });
}
