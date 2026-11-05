import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/theme/madar_tokens.dart';
import 'package:madar_sat/design/components/segmented.dart';
import 'package:madar_sat/features/competition/presentation/competition_sections.dart';
import 'package:madar_sat/features/matches/domain/match_days.dart';
import 'package:madar_sat/features/matches/presentation/match_days_list.dart';
import 'package:madar_sat/l10n/app_localizations.dart';

import '../fixtures/sample_details.dart';
import '../fixtures/sample_match_detail.dart';
import '../fixtures/sample_models.dart';
import 'golden_harness.dart';

/// S8 Competition as the board draws it, in RTL × {light, dark} × {1.0, 1.3} (T081, FR-044).
void main() {
  testWidgets('S8 competition page golden variants', (tester) async {
    final detail = sampleCompetitionDetail(
      upcoming: [
        sampleTeamMatch(
          id: 301,
          kickoff: sampleKickoffAt(hour: 20, minute: 30),
          home: 'ميلان',
          away: 'بولونيا',
        ),
        sampleTeamMatch(
          id: 302,
          kickoff: sampleKickoffAt(hour: 22, minute: 30),
          home: 'فينيسا',
          away: 'إنتر ميلان',
        ),
      ],
      rightsHolders: const [
        RightsHolderRef(
          id: 3,
          name: 'Eleven Sports',
          logo: null,
          satellites: [hotbirdSatellite],
          competitionCount: 9,
        ),
        RightsHolderRef(
          id: 4,
          name: 'beIN Sports',
          logo: null,
          satellites: [sampleSatellite, badrSatellite],
          competitionCount: 25,
        ),
      ],
    );
    final days = matchDays(detail.upcoming, tab: MatchTab.upcoming);

    await goldenVariants(
      tester,
      's8_competition',
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CompetitionHeader(
            detail: detail,
            logo: null,
            following: true,
            onFollow: () {},
            showRightsShortcut: true,
            onOpenRights: () {},
          ),
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
          MatchDaysList(days: days, now: sampleNow(), followedTeams: const {}, onOpen: (_) {}),
          RightsHoldersSection(holders: detail.rightsHolders),
        ],
      ),
      size: const Size(360, 1000),
    );
  });
}
