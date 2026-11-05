import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/team_detail.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';

part 'team_providers.g.dart';

/// `GET /v1/teams/{id}`, stale-while-revalidate from `cached_documents` under `team:<id>`:
/// the cached copy first, then the revalidated one (§S7, FR-046).
///
/// Invalidate it to revalidate again (the poll, the retry). No automatic retry: Riverpod
/// would hold the state at loading for about 38 s and hide the error copy.
@Riverpod(name: 'teamDetailProvider', retry: _never)
class TeamDetailSource extends _$TeamDetailSource {
  @override
  Stream<SwrSnapshot<TeamDetail>> build(int teamId) =>
      ref.watch(swrRepositoryProvider).watchTeamDetail(teamId);

  /// The poll and the retry: read again.
  void revalidate() => ref.invalidateSelf();

  /// A user-initiated refresh («تحديث», the retry): revalidate and wait for the answer.
  Future<void> refresh() async {
    try {
      await ref.read(swrRepositoryProvider).watchTeamDetail(teamId).drain<void>();
    } on ApiFailure {
      // The state keeps the cached copy or its error; the page says which.
    }
    if (!ref.mounted) return;
    ref.invalidateSelf();
  }
}

Duration? _never(int retryCount, Object error) => null;
