import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/url_opener.dart';
import '../../../core/network/generated/models/match_detail.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';
import '../../my_satellites/data/my_satellites_provider.dart';

MatchDetail parseMatchDetail(Object? data) =>
    MatchDetail.fromJson((data! as Map).cast<String, Object?>());

/// `GET /v1/matches/{id}`, stale-while-revalidate from `cached_documents` (FR-046): the
/// cached copy first, then the revalidated one.
///
/// Invalidate it to revalidate again (the poll, «تحديث», the retry). No automatic retry:
/// Riverpod would hold the state at loading for about 38 s, hiding the error copy.
final matchDetailProvider = StreamProvider.autoDispose.family<SwrSnapshot<MatchDetail>, int>(
  (ref, matchId) => ref.watch(swrRepositoryProvider).watchDocument<MatchDetail>(
        key: DocumentKeys.matchDetail(matchId),
        path: '/v1/matches/$matchId',
        parse: parseMatchDetail,
      ),
  retry: (retryCount, error) => null,
);

/// The reception video of each satellite by id, from the catalogue (`/v1/satellites`).
///
/// A satellite with no link, or with one that is not an `https` address, has no entry, so
/// its carriages have no reception action. Empty until the catalogue has loaded; the
/// channels never wait for it.
final receptionUrlsProvider = Provider<Map<int, Uri>>((ref) {
  final satellites = ref.watch(satellitesProvider).value?.data;
  if (satellites == null) return const {};
  return {
    for (final satellite in satellites) satellite.id: ?httpsUri(satellite.receptionUrl),
  };
});
