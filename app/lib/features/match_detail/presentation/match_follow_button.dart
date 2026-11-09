import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/clock.dart';
import '../../../core/network/generated/models/status.dart';
import '../../../design/components/banner.dart';
import '../../../design/components/button.dart';
import '../../../l10n/app_localizations.dart';
import '../../follows/data/follows_repository.dart';
import '../../follows/domain/follow_set.dart';
import '../../live/live_merge.dart';

/// «تابع المباراة» on S3. The reminder goes out before kickoff, so following a match that has
/// already started still follows it. The note says what will really come (FR-060): a feed
/// covers the match when it's in play and not estimated, so its alerts are on the way, and
/// otherwise no alert will come.
class MatchFollowButton extends ConsumerWidget {
  const MatchFollowButton({
    super.key,
    required this.matchId,
    required this.kickoffAt,
    required this.status,
    required this.estimated,
  });

  final int matchId;

  /// Null while the kickoff is unknown: a reminder can still come once it has a time.
  final DateTime? kickoffAt;

  /// The match's status and estimate as the user may see them, after the live merge.
  final Status status;
  final bool estimated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final following = ref.watch(followSetValueProvider).matches.contains(matchId);
    return FollowButton(
      following: following,
      label: l.followMatch,
      followingLabel: l.followingMatch,
      onPressed: () {
        unawaited(ref.read(followsRepositoryProvider).toggle(FollowKind.match, matchId));
        final kickoff = kickoffAt;
        if (!following && kickoff != null && !kickoff.isAfter(ref.read(clockProvider)())) {
          final covered = isInPlayStatus(status) && !estimated;
          MadarSnackbar.show(context, covered ? l.s3FollowStartedAlertsNote : l.s3FollowStartedNote);
        }
      },
    );
  }
}
