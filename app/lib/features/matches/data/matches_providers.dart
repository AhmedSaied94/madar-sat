import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/format/clock.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/generated/models/match_summary.dart';
import '../../../core/network/swr_providers.dart';
import '../../../core/network/swr_repository.dart';
import '../../live/live_merge.dart';
import '../../live/live_poller.dart';
import '../domain/matches_day.dart';

part 'matches_providers.g.dart';

/// One local day of matches from drift, revalidated against the server (FR-046).
///
/// A stream, because the repository emits the cached copy first and the answer after it.
/// There is no automatic retry: Riverpod would keep the state `AsyncLoading` for about
/// 38 s while it retries, hiding the error copy behind the skeleton (FR-048); the screen
/// offers «إعادة المحاولة» instead.
@Riverpod(retry: _never)
class MatchesDay extends _$MatchesDay {
  @override
  Stream<SwrSnapshot<List<MatchSummary>>> build(DateTime day) =>
      ref.watch(swrRepositoryProvider).watchDay(day);

  /// The poll: read the day again. The provider's stream revalidates with `If-None-Match`,
  /// so this costs one request and never doubles the pull to refresh's cycle.
  void revalidate() => ref.invalidateSelf();

  /// Pull to refresh: run the whole cache, revalidate, write cycle and wait for the answer,
  /// then re-read drift so the screen shows what was written (R25). A failure with nothing
  /// cached is shown by the day's own error state after the re-read.
  Future<void> refresh() async {
    try {
      await ref.read(swrRepositoryProvider).watchDay(day).drain<void>();
    } on ApiFailure {
      // Shown by the day's state below: with a cache it keeps its rows and its age, without
      // one it fails again on the re-read.
    }
    // The screen may be gone while the cycle ran: `ref.invalidateSelf()` throws
    // `UnmountedRefException` on a disposed provider, and the pull to refresh's future
    // would fail with nothing to catch it (M-R2-2).
    if (!ref.mounted) return;
    ref.invalidateSelf();
  }
}

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
@riverpod
DayState matchesDayState(Ref ref, DateTime day) {
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
}

/// The local days S2 pages through, with the today they hang on.
///
/// A phone left with the app open past midnight comes back on yesterday's «اليوم» and a
/// window of days that starts a day late, so a resume asks this to recompute. Kept alive so
/// the selection's index means the same day across a rebuild.
@Riverpod(keepAlive: true)
({DateTime today, List<DateTime> days}) matchesWindow(Ref ref) {
  final now = ref.watch(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  return (today: today, days: MatchesDays.kept(today));
}

/// Never retry automatically: the screens carry their own «إعادة المحاولة».
Duration? _never(int retryCount, Object error) => null;
