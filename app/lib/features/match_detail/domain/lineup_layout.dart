import '../../../core/network/generated/models/lineup_player.dart';
import '../../../core/network/generated/models/lineup_side.dart';
import '../../../core/network/generated/models/match_event.dart';
import '../../../core/network/generated/models/match_event_side.dart';
import '../../../core/network/generated/models/match_event_type.dart';
import '../../../core/network/generated/models/match_lineups.dart';

/// FilGoal's four position groups, from the goalkeeper out (R16).
enum PositionGroup {
  goalkeeper('حارس مرمى'),
  defender('مدافع'),
  midfielder('وسط'),
  forward('مهاجم');

  const PositionGroup(this.source);

  /// The value the source sends, matched exactly.
  final String source;
}

const int _startersOnAPitch = 11;

/// How S3 draws a match's lineups.
sealed class LineupLayout {
  const LineupLayout();
}

/// Both sides have usable positions.
final class LineupPitch extends LineupLayout {
  const LineupPitch({required this.home, required this.away});

  final PitchSide home;
  final PitchSide away;
}

/// Anything else, including all of Goal.com, whose `position` is null. Placing players by list
/// order would state a position nobody reported (constitution II).
final class LineupLists extends LineupLayout {
  const LineupLists({required this.home, required this.away});

  final ListSide? home;
  final ListSide? away;
}

class PitchLine {
  const PitchLine(this.group, this.players);

  final PositionGroup group;
  final List<LineupPlayer> players;

  int get length => players.length;
}

class PitchSide {
  const PitchSide({required this.formation, required this.lines});

  final String? formation;

  /// From the goalkeeper out, leaving out a group with no starter.
  final List<PitchLine> lines;
}

class ListSide {
  const ListSide({required this.formation, required this.starters, required this.substitutes});

  final String? formation;
  final List<LineupPlayer> starters;
  final List<LineupPlayer> substitutes;
}

/// The layout for [lineups], or null when no side has a player, so the tab doesn't show.
LineupLayout? layoutLineups(MatchLineups? lineups) {
  final home = lineups?.home;
  final away = lineups?.away;
  final hasHome = home != null && home.players.isNotEmpty;
  final hasAway = away != null && away.players.isNotEmpty;
  if (!hasHome && !hasAway) return null;

  final homePitch = hasHome ? _pitchSide(home) : null;
  final awayPitch = hasAway ? _pitchSide(away) : null;
  if (homePitch != null && awayPitch != null) {
    return LineupPitch(home: homePitch, away: awayPitch);
  }
  return LineupLists(home: hasHome ? _listSide(home) : null, away: hasAway ? _listSide(away) : null);
}

PitchSide? _pitchSide(LineupSide side) {
  final starters = side.players.where((player) => player.isStarter).toList();
  if (starters.length != _startersOnAPitch) return null;
  final byGroup = {for (final group in PositionGroup.values) group: <LineupPlayer>[]};
  for (final player in starters) {
    final group = _groupOf(player.position);
    if (group == null) return null;
    byGroup[group]!.add(player);
  }
  if (byGroup[PositionGroup.goalkeeper]!.length != 1) return null;
  return PitchSide(
    formation: formationLabel(side.formation),
    lines: [
      for (final group in PositionGroup.values)
        if (byGroup[group]!.isNotEmpty) PitchLine(group, byGroup[group]!),
    ],
  );
}

PositionGroup? _groupOf(String? position) {
  for (final group in PositionGroup.values) {
    if (group.source == position) return group;
  }
  return null;
}

ListSide _listSide(LineupSide side) => ListSide(
      formation: formationLabel(side.formation),
      starters: [
        for (final player in side.players)
          if (player.isStarter) player,
      ],
      substitutes: [
        for (final player in side.players)
          if (!player.isStarter) player,
      ],
    );

/// The formation as a label, or null for an empty one, which isn't shown.
String? formationLabel(String? formation) {
  final label = formation?.trim();
  return label == null || label.isEmpty ? null : label;
}

enum LineupMark { goal, redCard }

/// The marks on [name], only on an exact match with an event on [side] (R16). An own goal and a
/// missed penalty earn none.
Set<LineupMark> marksFor(String name, MatchEventSide side, List<MatchEvent> events) => {
      for (final event in events)
        if (event.player == name && event.side == side)
          if (event.type == MatchEventType.goal || event.type == MatchEventType.penalty)
            LineupMark.goal
          else if (event.type == MatchEventType.redCard)
            LineupMark.redCard,
    };
