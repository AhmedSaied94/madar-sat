import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';
import '../../live/live_merge.dart';
import '../../live/live_poller.dart';
import '../domain/matches_day.dart';

/// One local day of matches from drift, revalidated against the server (FR-046).
///
/// A stream, because the repository emits the cached copy first and the answer after it.
/// There is no automatic retry: Riverpod would keep the state `AsyncLoading` for about
/// 38 s while it retries, hiding the error copy behind the skeleton (FR-048); the screen
/// offers «إعادة المحاولة» instead.
final matchesDayProvider = StreamProvider.autoDispose
    .family<SwrSnapshot<List<MatchSummary>>, DateTime>(
  (ref, day) => ref.watch(swrRepositoryProvider).watchDay(day),
  retry: (retryCount, error) => null,
);

/// What one day's page can show.
sealed class DayState {
  const DayState();
}

/// The first load has nothing to show yet.
class DayLoading extends DayState {
  const DayLoading();
}

/// The first load failed and nothing is cached.
class DayFailed extends DayState {
  const DayFailed(this.failure, {this.isRetrying = false});

  final ApiFailure failure;

  /// Another attempt is out. The error stays on screen meanwhile: a skeleton would flash
  /// on every poll of a day that cannot load.
  final bool isRetrying;
}

class DayLoaded extends DayState {
  const DayLoaded(this.view);

  final DayView view;
}

/// A day's matches with the live states merged in (never a cached state as live, SC-008).
///
/// Merging happens here, on top of the stream, so a live update re-draws the rows without
/// re-reading drift or the network.
final matchesDayStateProvider = Provider.autoDispose.family<DayState, DateTime>((ref, day) {
  final source = ref.watch(matchesDayProvider(day));
  final live = ref.watch(liveStatesProvider);

  // While a day reloads, its last copy stays (`value` keeps the previous data), so a
  // revalidation never flashes the skeleton.
  final snapshot = source.value;
  final rows = snapshot?.data;
  if (snapshot != null && rows != null) {
    return DayLoaded(
      DayView(day: day, snapshot: snapshot, rows: applyLiveStates(rows, live)),
    );
  }
  if (source.hasError) {
    final error = source.error;
    return DayFailed(
      error is ApiFailure ? error : const ApiFailure(),
      isRetrying: source.isLoading,
    );
  }
  return const DayLoading();
});
