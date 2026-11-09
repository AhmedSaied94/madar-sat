import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/network/generated/export.dart';
import 'package:madar_sat/features/match_detail/domain/lineup_layout.dart';

LineupPlayer _player(String name, String? position, {bool starter = true, int? number}) =>
    LineupPlayer(name: name, isStarter: starter, number: number, position: position);

/// A usable FilGoal eleven, 4-3-3, plus one substitute.
List<LineupPlayer> _eleven() => [
      _player('حارس', 'حارس مرمى'),
      for (var i = 0; i < 4; i++) _player('مدافع $i', 'مدافع'),
      for (var i = 0; i < 3; i++) _player('وسط $i', 'وسط'),
      for (var i = 0; i < 3; i++) _player('مهاجم $i', 'مهاجم'),
      _player('بديل', 'مهاجم', starter: false),
    ];

LineupSide _side(List<LineupPlayer> players, {String? formation = '4-3-3'}) =>
    LineupSide(formation: formation, players: players);

/// The pitch rule (FR-056, R16): a pitch only when positions are really known, because placing
/// players by list order would state a position nobody reported.
void main() {
  test('no lineups, or empty sides, give no layout', () {
    expect(layoutLineups(null), isNull);
    expect(layoutLineups(const MatchLineups(home: null, away: null)), isNull);
    expect(
      layoutLineups(MatchLineups(home: _side(const []), away: _side(const []))),
      isNull,
    );
  });

  test('two usable sides give a pitch, with lines from goalkeeper out', () {
    final layout = layoutLineups(MatchLineups(home: _side(_eleven()), away: _side(_eleven())));

    final pitch = layout! as LineupPitch;
    expect([for (final line in pitch.home.lines) line.length], [1, 4, 3, 3]);
    expect([for (final line in pitch.away.lines) line.group], [
      PositionGroup.goalkeeper,
      PositionGroup.defender,
      PositionGroup.midfielder,
      PositionGroup.forward,
    ]);
    expect(pitch.home.lines.first.players.single.name, 'حارس');
  });

  test('a substitute is never on the pitch', () {
    final pitch = layoutLineups(
      MatchLineups(home: _side(_eleven()), away: _side(_eleven())),
    )! as LineupPitch;
    final names = [for (final line in pitch.home.lines) ...line.players.map((p) => p.name)];
    expect(names, isNot(contains('بديل')));
  });

  group('anything else gives two lists', () {
    void expectLists(MatchLineups lineups, String reason) {
      expect(layoutLineups(lineups), isA<LineupLists>(), reason: reason);
    }

    test('a Goal.com lineup, whose positions are all null', () {
      final nulls = [for (var i = 0; i < 11; i++) _player('لاعب $i', null)];
      expectLists(MatchLineups(home: _side(nulls), away: _side(nulls)), 'null positions');
    });

    test('ten or twelve starters', () {
      final ten = _eleven()..removeAt(1);
      final twelve = [..._eleven(), _player('زائد', 'وسط')];
      expectLists(MatchLineups(home: _side(ten), away: _side(_eleven())), 'ten');
      expectLists(MatchLineups(home: _side(_eleven()), away: _side(twelve)), 'twelve');
    });

    test('no goalkeeper, or two', () {
      final none = [
        for (var i = 0; i < 11; i++) _player('مدافع $i', 'مدافع'),
      ];
      final two = _eleven()..[1] = _player('حارس 2', 'حارس مرمى');
      expectLists(MatchLineups(home: _side(none), away: _side(_eleven())), 'none');
      expectLists(MatchLineups(home: _side(two), away: _side(_eleven())), 'two');
    });

    test('a starter with a position outside the four groups', () {
      final odd = _eleven()..[1] = _player('لاعب', 'جناح');
      expectLists(MatchLineups(home: _side(odd), away: _side(_eleven())), 'odd');
    });

    test('only one side known', () {
      expectLists(MatchLineups(home: _side(_eleven()), away: null), 'one side');
    });
  });

  test('two lists hold starters then substitutes, per side', () {
    final layout = layoutLineups(
      MatchLineups(home: _side(_eleven()), away: null),
    )! as LineupLists;

    expect(layout.home!.starters, hasLength(11));
    expect(layout.home!.substitutes.single.name, 'بديل');
    expect(layout.away, isNull);
  });

  test('an empty formation is no label', () {
    expect(formationLabel('4-3-3'), '4-3-3');
    expect(formationLabel(''), isNull);
    expect(formationLabel('  '), isNull);
    expect(formationLabel(null), isNull);
  });

  group('marks', () {
    const events = [
      MatchEvent(type: MatchEventType.goal, side: MatchEventSide.home, minute: '1', player: 'صلاح'),
      MatchEvent(type: MatchEventType.penalty, side: MatchEventSide.home, minute: '2', player: 'جونز'),
      MatchEvent(type: MatchEventType.redCard, side: MatchEventSide.away, minute: '3', player: 'كايسيدو'),
      MatchEvent(type: MatchEventType.ownGoal, side: MatchEventSide.home, minute: '4', player: 'فوفانا'),
      MatchEvent(type: MatchEventType.missedPenalty, side: MatchEventSide.home, minute: '5', player: 'نونيز'),
    ];

    test('appear on an exact name match, on the same side', () {
      expect(marksFor('صلاح', MatchEventSide.home, events), {LineupMark.goal});
      expect(marksFor('جونز', MatchEventSide.home, events), {LineupMark.goal});
      expect(marksFor('كايسيدو', MatchEventSide.away, events), {LineupMark.redCard});
    });

    test('never on a near name, or on the other side', () {
      expect(marksFor('محمد صلاح', MatchEventSide.home, events), isEmpty);
      expect(marksFor('صلاح', MatchEventSide.away, events), isEmpty);
    });

    test('an own goal and a miss earn no goal mark', () {
      expect(marksFor('فوفانا', MatchEventSide.home, events), isEmpty);
      expect(marksFor('نونيز', MatchEventSide.home, events), isEmpty);
    });
  });
}
