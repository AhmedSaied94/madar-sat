import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/event_timeline_item.dart';

import 'golden_harness.dart';

MatchEvent _event(MatchEventType type, MatchEventSide side, String minute, String? player) =>
    MatchEvent(type: type, side: side, minute: minute, player: player);

/// `EventTimelineItem` in every event type, on both sides, RTL × {light, dark} × {1.0, 1.3}
/// (T102, FR-064).
void main() {
  testWidgets('EventTimelineItem golden variants', (tester) async {
    await goldenVariants(
      tester,
      'event_timeline',
      (context) => Padding(
        padding: const EdgeInsetsDirectional.all(MadarSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TimelineMarkerRow(label: 'إضافي'),
            EventTimelineItem(
              event: _event(MatchEventType.goal, MatchEventSide.home, '12', 'محمد صلاح'),
              homeName: 'ليفربول',
              awayName: 'تشيلسي',
              runningScore: (home: 1, away: 0),
            ),
            EventTimelineItem(
              event: _event(MatchEventType.goal, MatchEventSide.away, '23', 'كول بالمر'),
              homeName: 'ليفربول',
              awayName: 'تشيلسي',
              runningScore: (home: 1, away: 1),
            ),
            EventTimelineItem(
              event: _event(MatchEventType.ownGoal, MatchEventSide.home, '30', 'ليفي كولويل'),
              homeName: 'ليفربول',
              awayName: 'تشيلسي',
            ),
            const TimelineMarkerRow(label: 'الشوط الثاني'),
            EventTimelineItem(
              event: _event(MatchEventType.penalty, MatchEventSide.away, '45+2', 'إنزو فرنانديز'),
              homeName: 'ليفربول',
              awayName: 'تشيلسي',
            ),
            EventTimelineItem(
              event: _event(MatchEventType.missedPenalty, MatchEventSide.home, '52', 'داروين نونيز'),
              homeName: 'ليفربول',
              awayName: 'تشيلسي',
            ),
            EventTimelineItem(
              event: _event(MatchEventType.redCard, MatchEventSide.away, '61', 'مويسيس كايسيدو'),
              homeName: 'ليفربول',
              awayName: 'تشيلسي',
            ),
            EventTimelineItem(
              event: _event(MatchEventType.redCard, MatchEventSide.home, '90+3', null),
              homeName: 'ليفربول',
              awayName: 'تشيلسي',
            ),
          ],
        ),
      ),
    );
  });
}
