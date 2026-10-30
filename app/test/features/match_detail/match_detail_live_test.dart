import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/match_detail/domain/match_detail_live.dart';

import '../../fixtures/sample_match_detail.dart';

LiveState _live({bool estimated = false, Status status = Status.live}) => LiveState(
      matchId: 48213,
      status: status,
      statusLabel: null,
      period: Period.value2h,
      minute: '67',
      score: const Score(home: 1, away: 0, homePen: null, awayPen: null),
      estimated: estimated,
      statusUpdatedAt: DateTime.utc(2026, 10, 28, 18, 10),
    );

/// The same rule the match rows follow (SC-008): a live state comes only from `/v1/live`; a
/// cached in-play state is never shown as live; an estimated state has no score or minute.
void main() {
  const cachedScore = Score(home: 3, away: 2, homePen: null, awayPen: null);

  test('a live state from /v1/live replaces the cached status, score and minute', () {
    final cached = sampleMatchDetail(status: Status.scheduled);

    final merged = detailWithLiveState(cached, _live());

    expect(merged.status, Status.live);
    expect(merged.minute, '67');
    expect(merged.score?.home, 1);
    expect(merged.estimated, isFalse);
  });

  test('an estimated live state carries no score and no minute', () {
    final merged = detailWithLiveState(
      sampleMatchDetail(status: Status.live, score: cachedScore, minute: '12'),
      _live(estimated: true),
    );

    expect(merged.status, Status.live);
    expect(merged.estimated, isTrue);
    expect(merged.score, isNull);
    expect(merged.minute, isNull);
  });

  test('a cached in-play match with no live state is the quiet estimated «مباشر»', () {
    final merged = detailWithLiveState(
      sampleMatchDetail(status: Status.live, score: cachedScore, minute: '88'),
      null,
    );

    expect(merged.status, Status.live);
    expect(merged.estimated, isTrue);
    expect(merged.score, isNull);
    expect(merged.minute, isNull);
  });

  test('a match that is not in play is left as cached', () {
    final cached = sampleMatchDetail(status: Status.finished, score: cachedScore);

    final merged = detailWithLiveState(cached, null);

    expect(merged.status, Status.finished);
    expect(merged.score?.home, 3);
  });

  test('the channels and the rest of the detail are untouched by the merge', () {
    final cached = sampleMatchDetail(
      status: Status.live,
      carriages: [sampleCarriageEntry(id: 1)],
      stadium: 'استاد القاهرة الدولي',
    );

    final merged = detailWithLiveState(cached, _live());

    expect(merged.carriages, cached.carriages);
    expect(merged.stadium, 'استاد القاهرة الدولي');
    expect(merged.home, cached.home);
  });

  test('the summary view carries the fields live merging and polling read', () {
    final detail = sampleMatchDetail(status: Status.halftime, minute: '45');

    final summary = summaryOfDetail(detail);

    expect(summary.id, detail.id);
    expect(summary.status, Status.halftime);
    expect(summary.kickoffAt, detail.kickoffAt);
    expect(summary.competition, detail.competition);
  });
}
