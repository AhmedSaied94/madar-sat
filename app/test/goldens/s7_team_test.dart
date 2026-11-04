import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/segmented.dart';
import 'package:madar_sat/features/team/domain/team_matches.dart';
import 'package:madar_sat/features/team/presentation/team_header.dart';
import 'package:madar_sat/features/team/presentation/team_matches_list.dart';
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
    final days = teamMatchDays(rows, tab: TeamTab.upcoming);

    await goldenVariants(
      tester,
      's7_team',
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeamHeader(detail: detail, logo: null, following: true, onFollow: () {}),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: MadarSpace.s4),
            child: Segmented<TeamTab>(
              options: [
                SegmentedOption(value: TeamTab.upcoming, label: AppLocalizations.of(context).s7Upcoming),
                SegmentedOption(value: TeamTab.results, label: AppLocalizations.of(context).s7Results),
              ],
              selected: TeamTab.upcoming,
              onChanged: (_) {},
            ),
          ),
          TeamMatchesList(
            days: days,
            tab: TeamTab.upcoming,
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
