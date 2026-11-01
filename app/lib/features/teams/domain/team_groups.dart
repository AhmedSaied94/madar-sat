import '../../../core/network/generated/models/team_search_item.dart';

/// The teams of S1.2, grouped under their competition (contract app-screens).
///
/// The server returns them popular first (D1's ordering), and grouping keeps the order the
/// server gave: a competition appears where its first team did, so the popular ones stay on
/// top instead of being re-sorted by name.
class TeamGroup {
  const TeamGroup({required this.competition, required this.teams});

  final String competition;
  final List<TeamSearchItem> teams;
}

List<TeamGroup> groupTeams(List<TeamSearchItem> items) {
  final order = <String>[];
  final byCompetition = <String, List<TeamSearchItem>>{};
  for (final team in items) {
    final name = team.primaryCompetition?.name ?? '';
    final groups = byCompetition[name] ??= [];
    if (groups.isEmpty) order.add(name);
    groups.add(team);
  }
  return [
    for (final name in order) TeamGroup(competition: name, teams: byCompetition[name]!),
  ];
}
