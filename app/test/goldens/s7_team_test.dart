import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/segmented.dart';
import 'package:madar_sat/features/matches/domain/match_days.dart';
import 'package:madar_sat/features/matches/presentation/match_days_list.dart';
import 'package:madar_sat/features/team/presentation/team_header.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../fixtures/sample_details.dart';
import '../fixtures/sample_models.dart';
import 'golden_harness.dart';

/// S7 Team as the board draws it, in RTL × {light, dark} × {1.0, 1.3} (T081, FR-044).
void main() {
  testWidgets('S7 team page golden variants', (tester) async {
    final detail = sampleTeamDetail();
    final rows = [
      sampleTeamMatch(id: 201, kickoff: sampleKickoffAt(hour: 16)),
      sampleTeamMatch(id: 202, kickoff: DateTime(2026, 10, 29, 19).toUtc(), home: 'الزمالك', away: 'بيراميدز'),
    ];
    final days = matchDays(rows, tab: MatchTab.upcoming);

    await goldenVariants(
      tester,
      's7_team',
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeamHeader(detail: detail, logo: null, following: true, onFollow: () {}),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
            child: Segmented<MatchTab>(
              options: [
                SegmentedOption(
                  value: MatchTab.upcoming,
                  label: AppLocalizations.of(context).matchTabUpcoming,
                ),
                SegmentedOption(
                  value: MatchTab.results,
                  label: AppLocalizations.of(context).matchTabResults,
                ),
              ],
              selected: MatchTab.upcoming,
              onChanged: (_) {},
            ),
          ),
          MatchDaysList(
            days: days,
            now: sampleNow(),
            followedTeams: {detail.id},
            onOpen: (_) {},
          ),
        ],
      ),
      size: const Size(360, 900),
    );
  });
}
