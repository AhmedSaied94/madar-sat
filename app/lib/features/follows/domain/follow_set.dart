/// What a device can follow (data-model, drift v3). The wire value is the name.
enum FollowKind { team, competition, channel, commentator, match }

/// The device's follow set, the source of truth (P1): what S9 lists, what onboarding's
/// picker fills and what `FollowsRenderer` writes when this build knows the whole set.
class FollowSet {
  const FollowSet({
    this.teams = const {},
    this.competitions = const {},
    this.channels = const {},
    this.commentators = const {},
    this.matches = const {},
  });

  static const FollowSet empty = FollowSet();

  final Set<int> teams;
  final Set<int> competitions;
  final Set<int> channels;
  final Set<int> commentators;
  final Set<int> matches;

  Set<int> of(FollowKind kind) => switch (kind) {
        FollowKind.team => teams,
        FollowKind.competition => competitions,
        FollowKind.channel => channels,
        FollowKind.commentator => commentators,
        FollowKind.match => matches,
      };

  bool contains(FollowKind kind, int id) => of(kind).contains(id);

  bool get isEmpty => total == 0;

  int get total =>
      teams.length + competitions.length + channels.length + commentators.length + matches.length;

  FollowSet withKind(FollowKind kind, Set<int> ids) => switch (kind) {
        FollowKind.team => FollowSet(
            teams: ids,
            competitions: competitions,
            channels: channels,
            commentators: commentators,
            matches: matches,
          ),
        FollowKind.competition => FollowSet(
            teams: teams,
            competitions: ids,
            channels: channels,
            commentators: commentators,
            matches: matches,
          ),
        FollowKind.channel => FollowSet(
            teams: teams,
            competitions: competitions,
            channels: ids,
            commentators: commentators,
            matches: matches,
          ),
        FollowKind.commentator => FollowSet(
            teams: teams,
            competitions: competitions,
            channels: channels,
            commentators: ids,
            matches: matches,
          ),
        FollowKind.match => FollowSet(
            teams: teams,
            competitions: competitions,
            channels: channels,
            commentators: commentators,
            matches: ids,
          ),
      };

  FollowSet toggled(FollowKind kind, int id) {
    final next = {...of(kind)};
    if (!next.remove(id)) next.add(id);
    return withKind(kind, next);
  }
}
