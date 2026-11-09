import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/match_detail/domain/lineup_layout.dart';
import 'package:madar_sat/features/match_detail/presentation/live_center/lineups_pitch.dart';

import '../fixtures/sample_match_detail.dart';
import 'golden_harness.dart';
import 'live_center_harness.dart';

LineupPlayer _player(String name, int number, String? position, {bool starter = true}) =>
    LineupPlayer(name: name, isStarter: starter, number: number, position: position);

List<LineupPlayer> _eleven(List<String> names) => [
      _player(names[0], 1, 'حارس مرمى'),
      for (var i = 1; i <= 4; i++) _player(names[i], i + 1, 'مدافع'),
      for (var i = 5; i <= 7; i++) _player(names[i], i + 1, 'وسط'),
      for (var i = 8; i <= 10; i++) _player(names[i], i + 1, 'مهاجم'),
    ];

const _homeNames = [
  'أليسون', 'كيركيز', 'فان دايك', 'كوناتي', 'فريمبونغ',
  'ماك أليستر', 'غرافنبيرخ', 'فيرتس', 'غاكبو', 'إيساك', 'صلاح',
];
const _awayNames = [
  'سانشيز', 'جيمس', 'فوفانا', 'كولويل', 'كوكوريا',
  'كايسيدو', 'إنزو', 'بالمر', 'إستيفاو', 'جواو بيدرو', 'نيتو',
];

const _score = Score(home: 1, away: 0, homePen: null, awayPen: null);

const _events = [
  MatchEvent(type: MatchEventType.goal, side: MatchEventSide.home, minute: '23', player: 'صلاح'),
  MatchEvent(
    type: MatchEventType.redCard,
    side: MatchEventSide.away,
    minute: '61',
    player: 'كايسيدو',
  ),
];

/// The التشكيل tab, as a pitch (`Match-Lineups.html`) and as two lists, which no board draws
/// (T102, FR-056, FR-064). The pitch is drawn directly so it can carry its goal and red-card
/// marks; the lists are reached with no events, where the tab opens by itself.
void main() {
  testWidgets('a pitch when positions are usable', (tester) async {
    const size = Size(360, 520);
    final match = sampleMatchDetail(
      status: Status.finished,
      score: _score,
      home: 'ليفربول',
      away: 'تشيلسي',
      events: _events,
      lineups: MatchLineups(
        home: LineupSide(formation: '4-3-3', players: _eleven(_homeNames)),
        away: LineupSide(formation: '', players: _eleven(_awayNames)),
      ),
    );
    await goldenVariants(
      tester,
      'lineups_pitch',
      (context) => LineupsPitch(
        match: match,
        layout: layoutLineups(match.lineups)! as LineupPitch,
      ),
      size: size,
    );
  });

  testWidgets('two lists when they are not', (tester) async {
    const size = Size(360, 420);
    await goldenVariants(
      tester,
      'lineups_lists',
      (context) => liveCenterGolden(
        sampleMatchDetail(
          status: Status.finished,
          score: _score,
          home: 'ليفربول',
          away: 'تشيلسي',
          lineups: MatchLineups(
            home: LineupSide(
              formation: '4-3-3',
              players: [
                _player('أليسون', 1, null),
                _player('صلاح', 11, null),
                _player('إندو', 3, null, starter: false),
              ],
            ),
            away: LineupSide(
              formation: null,
              players: [_player('سانشيز', 1, null), _player('كايسيدو', 25, null)],
            ),
          ),
        ),
        size: size,
      ),
      size: size,
    );
  });
}
