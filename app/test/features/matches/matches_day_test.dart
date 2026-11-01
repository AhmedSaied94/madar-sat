import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/api_failure.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/features/matches/domain/matches_day.dart';

import '../../fixtures/sample_models.dart';

CompetitionRef _competition(int? id, String name, int? priority) =>
    CompetitionRef(id: id, logo: null, name: name, priority: priority, stage: null);

MatchSummary _match(
  int id,
  CompetitionRef competition, {
  int hour = 21,
  int minute = 0,
  int dayOffset = 0,
  Status status = Status.scheduled,
  bool timeTbd = false,
  DateTime? matchDate,
}) =>
    sampleMatch(
      id: id,
      status: status,
      timeTbd: timeTbd,
      kickoff: DateTime(2026, 10, 28 + dayOffset, hour, minute).toUtc(),
    ).copyWith(competition: competition, matchDate: matchDate ?? DateTime(2026, 10, 28));

/// The grouping and day rules S2 shows (FR-040, FR-041). Everything is built from local
/// wall-clock times, so it holds in any host zone.
void main() {
  final day = DateTime(2026, 10, 28);
  final asia = _competition(2, 'دوري أبطال آسيا', 1);
  final egypt = _competition(1, 'الدوري المصري', 2);
  final cup = _competition(4, 'كأس مصر', 2);
  final italy = _competition(3, 'الدوري الإيطالي', null);

  group('competition groups', () {
    test('are ordered by admin priority, then the earliest kickoff, with no priority last', () {
      final groups = groupDay(day, [
        _match(1, italy, hour: 16),
        _match(2, egypt, hour: 21),
        _match(3, egypt, hour: 19),
        _match(4, cup, hour: 18, minute: 30),
        _match(5, asia, hour: 22),
      ]);

      expect(groups.competitions.map((g) => g.competition.id), [2, 4, 1, 3]);
    });

    test('rows inside a group run by kickoff, then id', () {
      final groups = groupDay(day, [
        _match(9, egypt, hour: 21),
        _match(3, egypt, hour: 19),
        _match(2, egypt, hour: 19),
      ]);

      expect(groups.competitions.single.matches.map((m) => m.id), [2, 3, 9]);
    });

    test('two competitions with the same priority and kickoff keep a stable order by name', () {
      final first = _competition(7, 'ب', 2);
      final second = _competition(8, 'أ', 2);

      final groups = groupDay(day, [_match(1, first), _match(2, second)]);

      expect(groups.competitions.map((g) => g.competition.name), ['أ', 'ب']);
    });

    test('a competition without an id is grouped by its name', () {
      final anonymous = _competition(null, 'ودية', 5);

      final groups = groupDay(day, [_match(1, anonymous), _match(2, anonymous, hour: 22)]);

      expect(groups.competitions, hasLength(1));
      expect(groups.competitions.single.matches, hasLength(2));
    });
  });

  group('the local day (FR-041)', () {
    test('a match belongs to the local date of its kickoff, never to match_date', () {
      final lateTonight = _match(1, egypt, hour: 23, minute: 30, matchDate: DateTime(2026, 10, 29));
      final earlyTomorrow = _match(2, egypt, hour: 0, minute: 30, dayOffset: 1);

      final today = groupDay(day, [lateTonight, earlyTomorrow]);

      expect(today.competitions.single.matches.map((m) => m.id), [1]);
      expect(
        groupDay(DateTime(2026, 10, 29), [lateTonight, earlyTomorrow])
            .competitions
            .single
            .matches
            .map((m) => m.id),
        [2],
      );
    });

    test('matches with no kickoff form one group for the end of the day, by match_date', () {
      final tbd = _match(7, egypt, timeTbd: true);
      final otherDay = _match(8, egypt, timeTbd: true, matchDate: DateTime(2026, 10, 29));

      final groups = groupDay(day, [_match(1, egypt), tbd, otherDay]);

      expect(groups.tbd.map((m) => m.id), [7]);
      expect(groups.competitions.single.matches.map((m) => m.id), [1]);
      expect(groups.matchCount, 2);
      expect(groups.isEmpty, isFalse);
    });

    test('an empty day is empty', () {
      expect(groupDay(day, const []).isEmpty, isTrue);
    });

    test('a group shows a round only when every match in it shares one', () {
      final round5 = egypt.copyWith(stage: 'الجولة 5');
      final round8 = egypt.copyWith(stage: 'الجولة 8');

      final mixed = groupDay(day, [
        _match(1, round5, hour: 18),
        _match(2, round8, hour: 20),
        _match(3, round8, hour: 22),
      ]);
      expect(mixed.competitions.single.stage, isNull, reason: 'no single round to name');

      final same = groupDay(day, [
        _match(4, round8, hour: 18),
        _match(5, round8, hour: 20),
      ]);
      expect(same.competitions.single.stage, 'الجولة 8');
    });
  });

  group('live rows', () {
    test('live, halftime, extra time and penalties are in play; the rest are not', () {
      bool inPlay(Status status) => isInPlay(_match(1, egypt, status: status));

      expect(inPlay(Status.live), isTrue);
      expect(inPlay(Status.halftime), isTrue);
      expect(inPlay(Status.extraTime), isTrue);
      expect(inPlay(Status.penalties), isTrue);
      expect(inPlay(Status.scheduled), isFalse);
      expect(inPlay(Status.finished), isFalse);
      expect(inPlay(Status.postponed), isFalse);
      expect(inPlay(Status.cancelled), isFalse);
    });

    test('the live view keeps only in-play rows and drops groups left empty', () {
      final view = DayView(
        day: day,
        snapshot: SwrSnapshot(data: const [], fetchedAt: DateTime.utc(2026, 10, 28, 15)),
        rows: [
          _match(1, egypt, status: Status.live),
          _match(2, egypt),
          _match(3, asia, status: Status.finished),
          _match(4, cup, hour: 20, status: Status.halftime),
        ],
      );

      expect(view.liveCount, 2);
      expect(view.groups(MatchesFilter.all).matchCount, 4);
      final live = view.groups(MatchesFilter.live);
      expect(live.competitions.map((g) => g.competition.id), [4, 1]);
      expect(live.matchCount, 2);
    });
  });

  group('the kept days and the strip', () {
    final today = DateTime(2026, 10, 28);

    test('are yesterday through today + 6, by calendar day across a DST change', () {
      final days = MatchesDays.kept(DateTime(2026, 10, 25));

      expect(days, hasLength(8));
      expect(days.first, DateTime(2026, 10, 24));
      expect(days.last, DateTime(2026, 10, 31));
      expect(MatchesDays.kept(today)[MatchesDays.todayIndex], today);
      // Every entry is a midnight, so a 25-hour day cannot repeat or skip a date.
      expect(days.every((d) => d.hour == 0 && d.minute == 0), isTrue);
    });

    test('the strip has seven cells and slides only to keep the selected day in view', () {
      final days = MatchesDays.kept(today);

      expect(MatchesDays.stripWindow(days, 0), days.sublist(0, 7));
      expect(MatchesDays.stripWindow(days, 1), days.sublist(0, 7));
      expect(MatchesDays.stripWindow(days, 6), days.sublist(0, 7));
      expect(MatchesDays.stripWindow(days, 7), days.sublist(1, 8));
    });
  });

  group('stale hint', () {
    DayView view({required DateTime fetchedAt, ApiFailure? failure}) => DayView(
          day: day,
          snapshot: SwrSnapshot(data: const [], fetchedAt: fetchedAt, failure: failure),
          rows: const [],
        );
    final now = DateTime.utc(2026, 10, 28, 15);

    test('shows once the copy is older than five minutes, not before', () {
      expect(view(fetchedAt: now.subtract(const Duration(minutes: 4))).staleAge(now), isNull);
      expect(view(fetchedAt: now.subtract(const Duration(minutes: 5))).staleAge(now), isNull);
      expect(
        view(fetchedAt: now.subtract(const Duration(minutes: 6))).staleAge(now),
        const Duration(minutes: 6),
      );
    });

    test('a failed revalidation of a young copy shows nothing, an old one shows its age', () {
      final young = view(
        fetchedAt: now.subtract(const Duration(minutes: 1)),
        failure: const ApiFailure(isOffline: true),
      );
      final old = view(
        fetchedAt: now.subtract(const Duration(hours: 3)),
        failure: const ApiFailure(isOffline: true),
      );

      expect(young.staleAge(now), isNull);
      expect(old.staleAge(now), const Duration(hours: 3));
    });
  });
  group('the chosen zone (M-R1-6)', () {
    test('the same set of matches groups into different days under two zones', () {
      // 22:30 UTC is 01:30 the next day at GMT+3 and 10:30 the same day at GMT−12.
      final late = sampleMatch(id: 90, kickoff: DateTime.utc(2026, 10, 28, 22, 30));
      Duration plus3(DateTime _) => const Duration(hours: 3);
      Duration minus12(DateTime _) => const Duration(hours: -12);

      expect(groupDay(DateTime(2026, 10, 28), [late], offsetAt: plus3).matchCount, 0);
      expect(groupDay(DateTime(2026, 10, 29), [late], offsetAt: plus3).matchCount, 1);
      expect(groupDay(DateTime(2026, 10, 28), [late], offsetAt: minus12).matchCount, 1);
      expect(groupDay(DateTime(2026, 10, 29), [late], offsetAt: minus12).matchCount, 0);
    });

    test('a match shown at 23:30 in the chosen zone appears under that day', () {
      // 20:30 UTC is 23:30 at GMT+3 and 08:30 at GMT−12: the clock it shows and the day it
      // is listed under must be the same zone's.
      final evening = sampleMatch(id: 91, kickoff: DateTime.utc(2026, 10, 28, 20, 30));

      final groups = groupDay(
        DateTime(2026, 10, 28),
        [evening],
        offsetAt: (_) => const Duration(hours: 3),
      );

      expect(groups.matchCount, 1);
      expect(groups.competitions.single.matches.single.id, 91);
    });
  });

}
