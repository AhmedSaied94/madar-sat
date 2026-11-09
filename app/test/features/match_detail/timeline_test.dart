import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/match_detail/domain/timeline.dart';

MatchEvent _event(
  MatchEventType type,
  String minute, {
  MatchEventSide side = MatchEventSide.home,
  String? player = 'لاعب',
}) =>
    MatchEvent(type: type, side: side, minute: minute, player: player);

Score _score(int home, int away) => Score(home: home, away: away, homePen: null, awayPen: null);

/// What the rows say, in order, so a test reads as the screen does.
List<String> _shape(List<TimelineRow> rows) => [
      for (final row in rows)
        switch (row) {
          TimelineMarker(:final kind) => '[${kind.name}]',
          TimelineEventRow(:final event, :final runningScore) => runningScore == null
              ? event.minute
              : '${event.minute} ${runningScore.home}-${runningScore.away}',
        },
    ];

/// `buildTimeline` (FR-052, FR-053, R17): the order `EventTimeline`'s README asks for, markers
/// from the minute, and a running score only when the known goals add up to the score.
void main() {
  final events = [
    _event(MatchEventType.goal, '23'),
    _event(MatchEventType.missedPenalty, '52', side: MatchEventSide.away),
    _event(MatchEventType.redCard, '61', side: MatchEventSide.away),
  ];

  test('newest first while live, the board\'s order', () {
    expect(_shape(buildTimeline(events, _score(1, 0), Status.live)), [
      '61',
      '52',
      '[secondHalf]',
      '23 1-0',
      '[kickoff]',
    ]);
  });

  test('every in-play status counts as live', () {
    for (final status in [Status.halftime, Status.extraTime, Status.penalties]) {
      expect(_shape(buildTimeline(events, _score(1, 0), status)).first, '61', reason: '$status');
    }
  });

  test('chronological once finished', () {
    expect(_shape(buildTimeline(events, _score(1, 0), Status.finished)), [
      '[kickoff]',
      '23 1-0',
      '[secondHalf]',
      '52',
      '61',
    ]);
  });

  test('no events give no rows, not a lone marker', () {
    expect(buildTimeline(const [], _score(0, 0), Status.live), isEmpty);
  });

  test('a stoppage minute stays in its half', () {
    final rows = buildTimeline(
      [
        _event(MatchEventType.redCard, '45+2'),
        _event(MatchEventType.redCard, '46'),
        _event(MatchEventType.redCard, '90+3'),
        _event(MatchEventType.redCard, '91'),
      ],
      null,
      Status.finished,
    );
    expect(_shape(rows), [
      '[kickoff]',
      '45+2',
      '[secondHalf]',
      '46',
      '90+3',
      '[extraTime]',
      '91',
    ]);
  });

  test('a first event in extra time still passes the second half\'s marker', () {
    expect(
      _shape(buildTimeline([_event(MatchEventType.redCard, '95')], null, Status.finished)),
      ['[kickoff]', '[secondHalf]', '[extraTime]', '95'],
    );
  });

  test('sorts by minute, with a stoppage minute after its base', () {
    final rows = buildTimeline(
      [
        _event(MatchEventType.redCard, '50'),
        _event(MatchEventType.redCard, '45+1'),
        _event(MatchEventType.redCard, '45'),
      ],
      null,
      Status.finished,
    );
    expect(_shape(rows), ['[kickoff]', '45', '45+1', '[secondHalf]', '50']);
  });

  group('the running score', () {
    test('counts each side, in match order, however the rows are shown', () {
      final goals = [
        _event(MatchEventType.goal, '10'),
        _event(MatchEventType.penalty, '20', side: MatchEventSide.away),
        _event(MatchEventType.ownGoal, '30'),
      ];
      expect(_shape(buildTimeline(goals, _score(2, 1), Status.live)), [
        '30 2-1',
        '20 1-1',
        '10 1-0',
        '[kickoff]',
      ]);
    });

    test('2–0 with one known goal shows none, and invents no row', () {
      final rows = buildTimeline(
        [_event(MatchEventType.goal, '10')],
        _score(2, 0),
        Status.live,
      );
      expect(_shape(rows), ['10', '[kickoff]']);
    });

    test('a known side that adds up isn\'t enough when the other doesn\'t', () {
      final rows = buildTimeline(
        [_event(MatchEventType.goal, '10')],
        _score(1, 1),
        Status.live,
      );
      expect(_shape(rows), ['10', '[kickoff]']);
    });

    test('no score shows none', () {
      expect(
        _shape(buildTimeline([_event(MatchEventType.goal, '10')], null, Status.scheduled)),
        ['[kickoff]', '10'],
      );
    });

    test('a missed penalty and a red card never count, or carry one', () {
      final rows = buildTimeline(
        [
          _event(MatchEventType.goal, '10'),
          _event(MatchEventType.missedPenalty, '20'),
          _event(MatchEventType.redCard, '30'),
        ],
        _score(1, 0),
        Status.finished,
      );
      expect(_shape(rows), ['[kickoff]', '10 1-0', '20', '30']);
    });
  });

  test('an own goal stays on the side it was credited to', () {
    final rows = buildTimeline(
      [_event(MatchEventType.ownGoal, '10', side: MatchEventSide.away)],
      _score(0, 1),
      Status.live,
    );
    final row = rows.first as TimelineEventRow;
    expect(row.event.side, MatchEventSide.away);
    expect(row.runningScore, (home: 0, away: 1));
  });

  test('a type or side from a newer API is left out, so a row is never guessed', () {
    final rows = buildTimeline(
      [
        _event(MatchEventType.$unknown, '10'),
        _event(MatchEventType.goal, '12', side: MatchEventSide.$unknown),
      ],
      null,
      Status.live,
    );
    expect(rows, isEmpty);
  });

  test('a minute it can\'t read keeps its place in the list', () {
    final rows = buildTimeline(
      [
        _event(MatchEventType.redCard, '10'),
        _event(MatchEventType.redCard, '?'),
        _event(MatchEventType.redCard, '20'),
      ],
      null,
      Status.finished,
    );
    expect(_shape(rows), ['[kickoff]', '10', '?', '20']);
  });
}
