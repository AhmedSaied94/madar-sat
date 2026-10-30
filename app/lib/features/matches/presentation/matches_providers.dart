import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../data/matches_api.dart';

/// The matches data source for the route (overridden in tests).
final matchesApiProvider = Provider<MatchesApi>(
  (ref) => MatchesApi(ref.watch(madarApiClientProvider)),
);

/// Today's matches for the device's local day.
///
/// Riverpod retries a failing provider ten times (about 38 s) and keeps the state
/// `AsyncLoading` while it does, so the `error.code` copy in FR-048 would not show for
/// half a minute. The route offers «إعادة المحاولة» instead: no automatic retry.
final matchesProvider = FutureProvider<List<MatchSummary>>(
  (ref) => ref.watch(matchesApiProvider).day(),
  retry: (retryCount, error) => null,
);
