import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/clock.dart';
import '../../../design/components/banner.dart';
import '../../../design/components/button.dart';
import '../../../l10n/app_localizations.dart';
import '../../follows/data/follows_repository.dart';
import '../../follows/domain/follow_set.dart';

/// «تابع المباراة» on S3. The reminder goes out before kickoff, so following a match that has
/// already started still follows it, and says that no reminder is coming.
class MatchFollowButton extends ConsumerWidget {
  const MatchFollowButton({super.key, required this.matchId, required this.kickoffAt});

  final int matchId;

  /// Null while the kickoff is unknown: a reminder can still come once it has a time.
  final DateTime? kickoffAt;

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
          MadarSnackbar.show(context, l.s3FollowStartedNote);
        }
      },
    );
  }
}
