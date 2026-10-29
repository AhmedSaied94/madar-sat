import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/match_row.dart';

import '../fixtures/sample_models.dart';
import '../fixtures/test_app.dart';
import 'golden_harness.dart';

void main() {
  testWidgets('MatchRow golden variants', (tester) async {
    final kickoff = DateTime.utc(2026, 10, 28, 18);
    const score = Score(home: 1, away: 0, homePen: null, awayPen: null);

    await goldenVariants(
      tester,
      'match_row',
      (context) => Column(
        children: [
          MatchRow(match: sampleMatch(kickoff: kickoff)),
          Divider(height: 1, color: context.madarColors.divider),
          MatchRow(
            match: sampleMatch(status: Status.live, score: score, minute: '67'),
          ),
          Divider(height: 1, color: context.madarColors.divider),
          MatchRow(
            match: sampleMatch(status: Status.live, estimated: true),
          ),
          Divider(height: 1, color: context.madarColors.divider),
          MatchRow(
            match: sampleMatch(status: Status.finished, score: score),
          ),
          Divider(height: 1, color: context.madarColors.divider),
          MatchRow(match: sampleMatch(kickoff: kickoff, withChannels: false)),
          Divider(height: 1, color: context.madarColors.divider),
          MatchRow(
            match: sampleMatch(
              kickoff: kickoff,
              sport: Sport.tennis,
              home: 'نوفاك ديوكوفيتش',
              away: 'كارلوس ألكاراز',
            ),
          ),
          Divider(height: 1, color: context.madarColors.divider),
          MatchRow(
            match: sampleMatch(
              kickoff: kickoff,
              home: 'المقاولون العرب الرياضي',
              away: 'الاتحاد السكندري',
            ),
            followed: true,
            reminder: true,
          ),
        ],
      ),
    );
  });

  testWidgets('MatchRow carries one merged Arabic label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        MatchRow(
          match: sampleMatch(
            status: Status.live,
            score: const Score(home: 1, away: 0, homePen: null, awayPen: null),
            minute: '67',
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'الأهلي ضد الزمالك، مباشر، الدقيقة 67، النتيجة 1 مقابل 0، على ON Sport 1',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('an estimated-live label has no score or minute', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(MatchRow(match: sampleMatch(status: Status.live, estimated: true))),
    );

    expect(
      find.bySemanticsLabel('الأهلي ضد الزمالك، مباشر، على ON Sport 1'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
