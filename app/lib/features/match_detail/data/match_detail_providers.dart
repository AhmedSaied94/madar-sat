import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/links/url_opener.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/match_detail.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';
import '../../my_satellites/data/my_satellites_provider.dart';

part 'match_detail_providers.g.dart';

/// `GET /v1/matches/{id}`, stale-while-revalidate from `cached_documents` (FR-046): the
/// cached copy first, then the revalidated one.
///
/// Invalidate it to revalidate again (the poll, «تحديث», the retry). No automatic retry:
/// Riverpod would hold the state at loading for about 38 s, hiding the error copy.
@Riverpod(name: 'matchDetailProvider', retry: _never)
class MatchDetailSource extends _$MatchDetailSource {
  @override
  Stream<SwrSnapshot<MatchDetail>> build(int matchId) =>
      ref.watch(swrRepositoryProvider).watchMatchDetail(matchId);

  /// The poll and the retry: read again. The catalogue is asked again too when its first
  /// load failed (opened offline), so reception links do not stay off for the session.
  void revalidate() {
    if (ref.read(satellitesProvider).hasError) ref.invalidate(satellitesProvider);
    ref.invalidateSelf();
  }

  /// A user-initiated refresh («تحديث», the retry): revalidate this match and the
  /// catalogue if its first load failed, waiting for the answer.
  Future<void> refresh() async {
    if (ref.read(satellitesProvider).hasError) ref.invalidate(satellitesProvider);
    try {
      await ref.read(swrRepositoryProvider).watchMatchDetail(matchId).drain<void>();
    } on ApiFailure {
      // The state keeps the cached copy or its error; the screen says which.
    }
    // A disposed provider throws here; the screen that pulled may already be gone (M-R2-2).
    if (!ref.mounted) return;
    ref.invalidateSelf();
  }
}

/// The reception video of each satellite by id, from the catalogue (`/v1/satellites`).
///
/// A satellite with no link, or with one that is not an `https` address, has no entry, so
/// its carriages have no reception action. Empty until the catalogue has loaded; the
/// channels never wait for it.
@riverpod
Map<int, Uri> receptionUrls(Ref ref) {
  final satellites = ref.watch(satellitesProvider).value?.data;
  if (satellites == null) return const {};
  return {
    for (final satellite in satellites) satellite.id: ?httpsUri(satellite.receptionUrl),
  };
}

Duration? _never(int retryCount, Object error) => null;
