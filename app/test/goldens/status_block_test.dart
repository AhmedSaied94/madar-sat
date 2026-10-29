import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/status_block.dart';

import 'golden_harness.dart';

void main() {
  testWidgets('StatusBlock golden variants', (tester) async {
    final now = DateTime.utc(2026, 10, 28, 18);
    const score = Score(home: 1, away: 0, homePen: null, awayPen: null);
    const shootout = Score(home: 2, away: 2, homePen: 3, awayPen: 4);

    await goldenVariants(
      tester,
      'status_block',
      (context) => Wrap(
        spacing: MadarSpace.s4,
        runSpacing: MadarSpace.s4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusBlock(status: Status.scheduled, kickoff: now.add(const Duration(hours: 3)), now: now),
          StatusBlock(
            status: Status.scheduled,
            kickoff: now.add(const Duration(hours: 3)),
            use24h: true,
            now: now,
          ),
          StatusBlock(
            status: Status.scheduled,
            kickoff: now.add(const Duration(minutes: 25)),
            now: now,
          ),
          const StatusBlock(status: Status.live, score: score, minute: '67', estimated: true),
          const StatusBlock(status: Status.live, score: score, minute: '45+2'),
          const StatusBlock(status: Status.halftime, score: score),
          const StatusBlock(status: Status.extraTime, score: score, minute: '105'),
          const StatusBlock(status: Status.penalties, score: shootout),
          const StatusBlock(status: Status.finished, score: score),
          const StatusBlock(status: Status.postponed),
          const StatusBlock(status: Status.cancelled),
          const StatusBlock(status: Status.abandoned),
          const StatusBlock(status: Status.scheduled, timeTbd: true),
        ],
      ),
    );
  });
}
