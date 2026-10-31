import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/my_satellites/domain/competition_groups.dart';

import '../../fixtures/sample_models.dart';
import '../../fixtures/sample_satellites.dart';

List<int> _ids(Iterable<MatchSummary> matches) => [for (final match in matches) match.id];

/// S4 groups its day by competition: admin priority first (1 is the top), then the group's
/// earliest kickoff; inside a group the finished matches sink to the bottom (PB S4).
void main() {
  group('competition order', () {
    test('admin priority first, a lower rank on top', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 1, competitionId: 12, competition: 'الدوري المصري', priority: 3, hour: 15),
        satelliteMatch(id: 2, competitionId: 30, competition: 'دوري أبطال آسيا', priority: 1, hour: 20),
      ]);

      expect([for (final g in groups) g.competition.name], ['دوري أبطال آسيا', 'الدوري المصري']);
    });

    test('a competition without a priority comes after the ranked ones', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 1, competitionId: 40, competition: 'الدوري الإيطالي', priority: null, hour: 14),
        satelliteMatch(id: 2, competitionId: 12, competition: 'الدوري المصري', priority: 9, hour: 22),
      ]);

      expect([for (final g in groups) g.competition.id], [12, 40]);
    });

    test('the same priority is ordered by the earliest kickoff in the group', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 1, competitionId: 12, competition: 'ب', priority: 2, hour: 21),
        satelliteMatch(id: 2, competitionId: 30, competition: 'أ', priority: 2, hour: 17),
        satelliteMatch(id: 3, competitionId: 30, competition: 'أ', priority: 2, hour: 23),
      ]);

      expect([for (final g in groups) g.competition.id], [30, 12]);
      expect(_ids(groups.first.matches), [2, 3]);
    });

    test('matches of one competition share one group, whatever order they arrive in', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 1, competitionId: 12, hour: 21),
        satelliteMatch(id: 2, competitionId: 30, competition: 'دوري آخر', priority: 5, hour: 18),
        satelliteMatch(id: 3, competitionId: 12, hour: 19),
      ]);

      expect(groups, hasLength(2));
      expect(_ids(groups.first.matches), [3, 1]);
    });

    test('a competition with no id is grouped by its name', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 1, competitionId: 12, competition: 'ودية').copyWith(
          competition: const CompetitionRef(
            id: null,
            logo: null,
            name: 'ودية',
            priority: null,
            stage: null,
          ),
        ),
        satelliteMatch(id: 2, competitionId: 13, competition: 'ودية').copyWith(
          competition: const CompetitionRef(
            id: null,
            logo: null,
            name: 'ودية',
            priority: null,
            stage: null,
          ),
        ),
      ]);

      expect(groups, hasLength(1));
      expect(_ids(groups.single.matches), [1, 2]);
    });
  });

  group('inside a group', () {
    test('finished matches sink to the bottom, the rest keep their kickoff order', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 1, status: Status.finished, hour: 14),
        satelliteMatch(id: 2, hour: 21),
        satelliteMatch(id: 3, status: Status.live, hour: 18),
        satelliteMatch(id: 4, status: Status.finished, hour: 16),
      ]);

      expect(_ids(groups.single.matches), [3, 2, 1, 4]);
    });

    test('a match with no kickoff follows the timed ones but stays above the finished', () {
      final timeUnknown = sampleMatch(id: 9, timeTbd: true).copyWith(
        competition: satelliteMatch(id: 9).competition,
      );
      final groups = groupByCompetition([
        satelliteMatch(id: 1, status: Status.finished, hour: 13),
        timeUnknown,
        satelliteMatch(id: 2, hour: 22),
      ]);

      expect(_ids(groups.single.matches), [2, 9, 1]);
    });

    test('the same kickoff is ordered by id, so the list never shuffles on refresh', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 8, hour: 20),
        satelliteMatch(id: 3, hour: 20),
      ]);

      expect(_ids(groups.single.matches), [3, 8]);
    });
  });

  group('the round shown on the header', () {
    test('is shown when every match of the group is in the same round', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 1, stage: 'الجولة 8'),
        satelliteMatch(id: 2, stage: 'الجولة 8', hour: 22),
      ]);

      expect(groups.single.stage, 'الجولة 8');
    });

    test('is left out when the matches are in different rounds', () {
      final groups = groupByCompetition([
        satelliteMatch(id: 1, stage: 'الجولة 8'),
        satelliteMatch(id: 2, stage: 'الجولة 9', hour: 22),
      ]);

      expect(groups.single.stage, isNull);
    });
  });

  test('no matches, no groups', () {
    expect(groupByCompetition(const []), isEmpty);
  });
}
