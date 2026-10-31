import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/live/live_merge.dart';

import '../../fixtures/sample_models.dart';

LiveState _live({
  int matchId = 48213,
  Status status = Status.live,
  Score? score = const Score(home: 1, away: 0, homePen: null, awayPen: null),
  String? minute = '34',
  Period? period = Period.value1h,
  bool estimated = false,
}) =>
    LiveState(
      matchId: matchId,
      status: status,
      statusLabel: null,
      period: period,
      minute: minute,
      score: score,
      estimated: estimated,
      statusUpdatedAt: DateTime.utc(2026, 10, 28, 18, 34),
    );

/// Live states come only from `/v1/live`, in memory. A cached row never shows as live on
/// its own (FR-046, FR-047, SC-008).
void main() {
  group('applying a live state to a cached row', () {
    test('a live state overlays status, score, minute and period', () {
      final cached = sampleMatch();

      final merged = withLiveState(cached, _live());

      expect(merged.status, Status.live);
      expect(merged.score?.home, 1);
      expect(merged.minute, '34');
      expect(merged.period, Period.value1h);
      expect(merged.estimated, isFalse);
      // Everything else is the cached row.
      expect(merged.home, cached.home);
      expect(merged.broadcast, cached.broadcast);
    });

    test('an estimated live state keeps no score and no minute', () {
      final merged = withLiveState(sampleMatch(), _live(estimated: true));

      expect(merged.status, Status.live);
      expect(merged.estimated, isTrue);
      expect(merged.score, isNull);
      expect(merged.minute, isNull);
    });

    test('a finished state from /v1/live overlays a cached live row', () {
      final cached = sampleMatch(status: Status.live, minute: '88');

      final merged = withLiveState(
        cached,
        _live(status: Status.finished, minute: null, score: const Score(home: 2, away: 1, homePen: null, awayPen: null)),
      );

      expect(merged.status, Status.finished);
      expect(merged.score?.home, 2);
    });

    test('a scheduled row with no live state is left as it is', () {
      final cached = sampleMatch();

      expect(withLiveState(cached, null), cached);
    });

    test('a finished row with no live state is left as it is', () {
      final cached = sampleMatch(
        status: Status.finished,
        score: const Score(home: 3, away: 0, homePen: null, awayPen: null),
      );

      expect(withLiveState(cached, null), cached);
    });

    test('a cached live row with no live state is never shown as live', () {
      final cached = sampleMatch(
        status: Status.live,
        minute: '34',
        score: const Score(home: 1, away: 0, homePen: null, awayPen: null),
      );

      final merged = withLiveState(cached, null);

      // Non-live treatment: its kickoff time stands in, with no score and no minute.
      expect(merged.status, Status.scheduled);
      expect(merged.kickoffAt, cached.kickoffAt);
      expect(merged.score, isNull);
      expect(merged.minute, isNull);
      expect(merged.estimated, isFalse);
    });

    test('every cached in-play status is treated the same way', () {
      for (final status in [Status.live, Status.halftime, Status.extraTime, Status.penalties]) {
        final merged = withLiveState(
          sampleMatch(
            status: status,
            minute: '45',
            score: const Score(home: 1, away: 1, homePen: null, awayPen: null),
          ),
          null,
        );

        expect(merged.status, Status.scheduled, reason: '$status');
        expect(merged.score, isNull, reason: '$status');
        expect(merged.minute, isNull, reason: '$status');
        expect(merged.period, isNull, reason: '$status');
        expect(isInPlayStatus(merged.status), isFalse, reason: '$status: it counts as live nowhere');
      }
    });
  });

  group('applying many', () {
    test('matches each row to its own live state by id', () {
      final rows = [sampleMatch(id: 1), sampleMatch(id: 2), sampleMatch(id: 3)];

      final merged = applyLiveStates(rows, {2: _live(matchId: 2)});

      expect(merged.map((m) => m.status), [Status.scheduled, Status.live, Status.scheduled]);
    });
  });

  group('whether anything on screen is live or about to be', () {
    final now = DateTime.utc(2026, 10, 28, 18);

    test('a live row counts, whatever its kickoff', () {
      expect(
        hasLiveOrImminent([sampleMatch(status: Status.live)], now: now),
        isTrue,
      );
    });

    test('a kickoff within the hour counts', () {
      expect(
        hasLiveOrImminent([sampleMatch(kickoff: now.add(const Duration(minutes: 45)))], now: now),
        isTrue,
      );
    });

    test('a kickoff later than an hour, an unknown kickoff and a finished row do not', () {
      expect(
        hasLiveOrImminent(
          [
            sampleMatch(id: 1, kickoff: now.add(const Duration(minutes: 90))),
            sampleMatch(id: 2, timeTbd: true),
            sampleMatch(id: 3, status: Status.finished),
          ],
          now: now,
        ),
        isFalse,
      );
    });

    test('an empty list does not', () {
      expect(hasLiveOrImminent(const [], now: now), isFalse);
    });
  });
}
