import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/features/team/domain/team_matches.dart';

import '../../fixtures/sample_details.dart';
import '../../fixtures/sample_models.dart';

/// S7's pure rules: two tabs, one local day per group, soonest first on «القادمة» and latest
/// first on «النتائج» (contract app-screens §S7, FR-041).
void main() {
  // 18:00 on Oct 28 in the device's own zone, and +03 for the grouping.
  final now = sampleNow();
  const zone = Duration(hours: 3);
  final today = DateTime.utc(2026, 10, 28, 19); // 22:00 +03, Oct 28
  final tomorrow = DateTime.utc(2026, 10, 29, 16); // 19:00 +03, Oct 29
  final lateNight = DateTime.utc(2026, 10, 28, 21, 30); // 00:30 +03, Oct 29

  group('«القادمة»', () {
    test('soonest first, grouped by the local day of the kickoff', () {
      final days = teamMatchDays(
        [
          sampleTeamMatch(id: 3, kickoff: tomorrow),
          sampleTeamMatch(id: 1, kickoff: today),
          sampleTeamMatch(id: 2, kickoff: lateNight),
        ],
        tab: TeamTab.upcoming,
        offsetAt: (_) => zone,
      );

      expect(days.map((day) => day.day), [DateTime(2026, 10, 28), DateTime(2026, 10, 29)]);
      // 22:00 on Oct 28 is its own day; 00:30 and 19:00 both read Oct 29 at +03.
      expect(days.first.matches.map((m) => m.id), [1]);
      expect(days.last.matches.map((m) => m.id), [2, 3]);
    });

    test('a kickoff with no time keeps its match_date day and sits last in it', () {
      final days = teamMatchDays(
        [
          sampleTeamMatch(id: 1, kickoff: null, timeTbd: true),
          sampleTeamMatch(id: 2, kickoff: today),
        ],
        tab: TeamTab.upcoming,
        offsetAt: (_) => zone,
      );

      expect(days.single.matches.map((m) => m.id), [2, 1]);
    });

    test('an empty list has nothing to draw', () {
      expect(teamMatchDays(const [], tab: TeamTab.upcoming), isEmpty);
      expect(hasTeamMatches(const []), isFalse);
    });
  });

  group('«النتائج»', () {
    test('latest first, with the days descending too', () {
      final days = teamMatchDays(
        [
          sampleTeamMatch(id: 1, kickoff: today),
          sampleTeamMatch(id: 2, kickoff: tomorrow),
        ],
        tab: TeamTab.results,
        offsetAt: (_) => zone,
      );

      expect(days.map((day) => day.day), [DateTime(2026, 10, 29), DateTime(2026, 10, 28)]);
      expect(days.first.matches.map((m) => m.id), [2]);
      expect(days.last.matches.map((m) => m.id), [1]);
    });

    test('two matches at the same minute keep a stable order', () {
      final days = teamMatchDays(
        [
          sampleTeamMatch(id: 5, kickoff: today),
          sampleTeamMatch(id: 4, kickoff: today),
        ],
        tab: TeamTab.results,
        offsetAt: (_) => zone,
      );

      expect(days.single.matches.map((m) => m.id), [5, 4]);
    });
  });

  test('a fixed zone decides the day, not the device', () {
    // 23:30 UTC is 02:30 the next day at +03 and still Oct 28 at UTC.
    final at = DateTime.utc(2026, 10, 28, 23, 30);

    final inCairo = teamMatchDays(
      [sampleTeamMatch(id: 1, kickoff: at)],
      tab: TeamTab.upcoming,
      offsetAt: (_) => zone,
    );
    final inUtc = teamMatchDays(
      [sampleTeamMatch(id: 1, kickoff: at)],
      tab: TeamTab.upcoming,
      offsetAt: (_) => Duration.zero,
    );

    expect(inCairo.single.day, DateTime(2026, 10, 29));
    expect(inUtc.single.day, DateTime(2026, 10, 28));
    expect(inCairo.single.day.isAfter(now), isTrue);
  });
}
