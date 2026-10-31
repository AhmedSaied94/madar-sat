import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/format/local_day.dart';
import 'package:madar_sat/core/format/time.dart';

import '../../fixtures/sample_models.dart';

/// Matches group by the device's local date of `kickoff_at`, never by `match_date`
/// (FR-041). Every zone here is injected, as D1's time tests do: the host zone is never read.
void main() {
  group('the local day of a kickoff', () {
    test('Cairo: a late kickoff in UTC is already the next day', () {
      // 22:30Z on Oct 28 is 01:30 on Oct 29 in Cairo (+03 until the fall-back).
      final day = LocalDays.of(DateTime.utc(2026, 10, 28, 22, 30), offsetAt: _cairo);
      expect(day, DateTime(2026, 10, 29));
    });

    test('Casablanca (+01) and Riyadh (+03) split the same instant across two days', () {
      final instant = DateTime.utc(2026, 10, 28, 22, 30);
      expect(LocalDays.of(instant, offsetAt: _casablanca), DateTime(2026, 10, 28));
      expect(LocalDays.of(instant, offsetAt: _riyadh), DateTime(2026, 10, 29));
    });

    test('one minute before local midnight is still the same day', () {
      final instant = DateTime.utc(2026, 10, 28, 20, 59);
      expect(LocalDays.of(instant, offsetAt: _riyadh), DateTime(2026, 10, 28));
      expect(
        LocalDays.of(instant.add(const Duration(minutes: 1)), offsetAt: _riyadh),
        DateTime(2026, 10, 29),
      );
    });

    test('the 25-hour fall-back day keeps both sides of the jump on one day', () {
      // Cairo returns to +02 at 00:00 local on Oct 30 (21:00Z on Oct 29).
      expect(
        LocalDays.of(DateTime.utc(2026, 10, 29, 20, 30), offsetAt: _cairo),
        DateTime(2026, 10, 29),
      );
      expect(
        LocalDays.of(DateTime.utc(2026, 10, 29, 21, 30), offsetAt: _cairo),
        DateTime(2026, 10, 29),
      );
      expect(
        LocalDays.of(DateTime.utc(2026, 10, 29, 22, 0), offsetAt: _cairo),
        DateTime(2026, 10, 30),
      );
    });

    test('is a plain calendar day: local, midnight, no time part', () {
      final day = LocalDays.of(DateTime.utc(2026, 10, 28, 12, 34), offsetAt: _riyadh);
      expect(day.isUtc, isFalse);
      expect(day.hour, 0);
      expect(day.minute, 0);
    });
  });

  group('grouping matches', () {
    test('uses kickoff_at, never match_date', () {
      // The server's `match_date` says Oct 28; the Riyadh fan's kickoff is on Oct 29.
      final match = sampleMatch(kickoff: DateTime.utc(2026, 10, 28, 22, 30));
      expect(match.matchDate, DateTime(2026, 10, 28));

      final groups = LocalDays.group([match], offsetAt: _riyadh);

      expect(groups.keys, [DateTime(2026, 10, 29)]);
      expect(groups[DateTime(2026, 10, 29)]!.timed.single.id, match.id);
    });

    test('the same match falls on a different day for a different zone', () {
      final match = sampleMatch(kickoff: DateTime.utc(2026, 10, 28, 22, 30));

      expect(LocalDays.group([match], offsetAt: _casablanca).keys, [DateTime(2026, 10, 28)]);
      expect(LocalDays.group([match], offsetAt: _cairo).keys, [DateTime(2026, 10, 29)]);
    });

    test('a match with an unknown kickoff goes to the «موعد لم يُحدد» group of its date', () {
      final timed = sampleMatch(id: 1, kickoff: DateTime.utc(2026, 10, 28, 18));
      final tbd = sampleMatch(id: 2, timeTbd: true);

      final groups = LocalDays.group([timed, tbd], offsetAt: _cairo);
      final day = groups[DateTime(2026, 10, 28)]!;

      expect(day.timed.map((m) => m.id), [1]);
      expect(day.tbd.map((m) => m.id), [2]);
      expect(day.tbd.single.kickoffAt, isNull);
    });

    test('a day with only unknown kickoffs still exists', () {
      final groups = LocalDays.group([sampleMatch(id: 2, timeTbd: true)], offsetAt: _cairo);

      expect(groups.keys, [DateTime(2026, 10, 28)]);
      expect(groups.values.single.timed, isEmpty);
      expect(groups.values.single.tbd, hasLength(1));
    });

    test('timed matches are ordered by kickoff, then id', () {
      final late = sampleMatch(id: 3, kickoff: DateTime.utc(2026, 10, 28, 19));
      final early = sampleMatch(id: 9, kickoff: DateTime.utc(2026, 10, 28, 17));
      final sameTime = sampleMatch(id: 4, kickoff: DateTime.utc(2026, 10, 28, 17));

      final day = LocalDays.group([late, early, sameTime], offsetAt: _cairo).values.single;

      expect(day.timed.map((m) => m.id), [4, 9, 3]);
    });
  });

  group('the UTC window of a local day (TimeFormat.dayWindow)', () {
    test('a 25-hour fall-back day covers exactly the kickoffs that group onto it', () {
      final window = MadarTime.dayWindow(DateTime(2026, 10, 29, 12), offsetAt: _cairoWall);

      expect(window.from, DateTime.utc(2026, 10, 28, 21));
      expect(window.to, DateTime.utc(2026, 10, 29, 22));
      expect(window.length, const Duration(hours: 25));
      expect(LocalDays.of(window.from, offsetAt: _cairo), DateTime(2026, 10, 29));
      expect(
        LocalDays.of(window.to.subtract(const Duration(minutes: 1)), offsetAt: _cairo),
        DateTime(2026, 10, 29),
      );
      expect(LocalDays.of(window.to, offsetAt: _cairo), DateTime(2026, 10, 30));
    });

    test('a 23-hour spring-forward day is bounded the same way', () {
      final window = MadarTime.dayWindow(DateTime(2026, 4, 24, 12), offsetAt: _cairoWall);

      expect(window.length, const Duration(hours: 23));
      expect(LocalDays.of(window.from, offsetAt: _cairo), DateTime(2026, 4, 24));
      expect(LocalDays.of(window.to, offsetAt: _cairo), DateTime(2026, 4, 25));
    });
  });

  group('day keys', () {
    test('format as yyyy-MM-dd and parse back', () {
      expect(LocalDays.key(DateTime(2026, 1, 5)), '2026-01-05');
      expect(LocalDays.parse('2026-01-05'), DateTime(2026, 1, 5));
    });

    test('adding days crosses month and year ends', () {
      expect(LocalDays.add(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(LocalDays.add(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });
  });
}

Duration _casablanca(DateTime utc) => const Duration(hours: 1);

Duration _riyadh(DateTime utc) => const Duration(hours: 3);

/// Cairo's 2026 offset at a UTC instant: +03 from the spring jump to the autumn return.
Duration _cairo(DateTime utc) {
  final instant = utc.toUtc();
  final springForward = DateTime.utc(2026, 4, 23, 22);
  final fallBack = DateTime.utc(2026, 10, 29, 21);
  final summer = !instant.isBefore(springForward) && instant.isBefore(fallBack);
  return Duration(hours: summer ? 3 : 2);
}

/// The same offsets looked up by wall clock, for `MadarTime.dayWindow`.
Duration _cairoWall(DateTime wallClock) {
  final wall = DateTime.utc(wallClock.year, wallClock.month, wallClock.day, wallClock.hour);
  final springForward = DateTime.utc(2026, 4, 24);
  final fallBack = DateTime.utc(2026, 10, 30);
  if (!wall.isAfter(springForward)) return const Duration(hours: 2);
  if (wall.isBefore(fallBack)) return const Duration(hours: 3);
  return const Duration(hours: 2);
}
