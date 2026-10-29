import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../data/matches_api.dart';

/// The matches data source for the route (overridden in tests).
final matchesApiProvider = Provider<MatchesApi>(
  (ref) => MatchesApi(ref.watch(madarApiClientProvider)),
);

/// Today's matches for the device's local day.
final matchesProvider = FutureProvider<List<MatchSummary>>(
  (ref) => ref.watch(matchesApiProvider).day(),
);
