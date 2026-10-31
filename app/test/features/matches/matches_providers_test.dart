import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/network/generated/models/match_summary.dart';
import 'package:madar_sat/core/network/swr_providers.dart';
import 'package:madar_sat/core/network/swr_repository.dart';
import 'package:madar_sat/features/matches/data/matches_providers.dart';

import '../../fixtures/fake_http_adapter.dart';
import '../../fixtures/sample_models.dart';

/// A repository that counts the reads, so a test can see that a screen's pull to refresh
/// reached it (FR-046, M-R1-14: the cycle lives in the provider, not in the widget).
class _CountingRepository extends SwrRepository {
  _CountingRepository({required super.dio, required super.database});

  int dayReads = 0;

  @override
  Stream<SwrSnapshot<List<MatchSummary>>> watchDay(DateTime day) {
    dayReads += 1;
    return super.watchDay(day);
  }
}

Map<String, Object?> _json(MatchSummary match) =>
    jsonDecode(jsonEncode(match.toJson())) as Map<String, Object?>;

/// The provider that owns a day's cache, revalidation and write cycle.
void main() {
  final day = DateTime(2026, 10, 28);
  final match = sampleMatch(id: 1, kickoff: DateTime.utc(2026, 10, 28, 17));

  late AppDatabase database;

  setUp(() {
    database = AppDatabase(
      NativeDatabase.memory(),
      now: () => DateTime(2026, 10, 28, 12),
      offsetAt: (_) => const Duration(hours: 3),
    );
  });
  tearDown(() => database.close());

  /// A container listening to [matchesDayProvider], collecting each snapshot it emits.
  (ProviderContainer, List<SwrSnapshot<List<MatchSummary>>>) listening(SwrRepository repo) {
    final container = ProviderContainer(
      overrides: [swrRepositoryProvider.overrideWithValue(repo)],
    );
    final snapshots = <SwrSnapshot<List<MatchSummary>>>[];
    container.listen(matchesDayProvider(day), (previous, next) {
      final value = next.value;
      if (value != null) snapshots.add(value);
    }, fireImmediately: true);
    return (container, snapshots);
  }

  test('MatchesDay.refresh() runs the whole cache, revalidate and write cycle again', () async {
    final http = FakeHttpAdapter()
      ..enqueueData([_json(match)], etag: '"v1"')
      ..enqueueData([_json(match)], etag: '"v2"');
    final repository = _CountingRepository(dio: fakeDio(http), database: database);
    final (container, snapshots) = listening(repository);
    addTearDown(container.dispose);

    await container.read(matchesDayProvider(day).future);
    expect(repository.dayReads, 1);
    expect((await database.windowFor('2026-10-28'))!.etag, '"v1"');

    await container.read(matchesDayProvider(day).notifier).refresh();
    await container.read(matchesDayProvider(day).future);

    // The explicit cycle, then the re-subscription that reads the freshly written day.
    expect(repository.dayReads, greaterThan(1));
    expect((await database.windowFor('2026-10-28'))!.etag, '"v2"');
    expect(snapshots.last.data!.map((m) => m.id), [1]);
    expect(container.read(matchesDayStateProvider(day)), isA<DayLoaded>());
  });

  test('a refresh whose screen goes away mid-cycle does not throw (M-R2-2)', () async {
    final pending = Completer<void>();
    final http = FakeHttpAdapter()
      ..enqueueData([_json(match)], etag: '"v1"')
      ..enqueue((_) async {
        await pending.future;
        return FakeHttpAdapter.envelope([_json(match)], etag: '"v2"');
      });
    final repository = _CountingRepository(dio: fakeDio(http), database: database);
    final (container, _) = listening(repository);

    await container.read(matchesDayProvider(day).future);
    final refresh = container.read(matchesDayProvider(day).notifier).refresh();
    // The user leaves the screen while the cycle is in flight.
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    pending.complete();

    await expectLater(refresh, completes);
  });

  test('a refresh that fails keeps the cached day and carries the failure', () async {
    final http = FakeHttpAdapter()
      ..enqueueData([_json(match)], etag: '"v1"')
      ..enqueueOffline()
      ..enqueueOffline();
    final repository = _CountingRepository(dio: fakeDio(http), database: database);
    final (container, snapshots) = listening(repository);
    addTearDown(container.dispose);

    await container.read(matchesDayProvider(day).future);
    await container.read(matchesDayProvider(day).notifier).refresh();
    await container.read(matchesDayProvider(day).future);
    // Let the failing revalidation of the re-read stream land.
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(snapshots.last.data!.map((m) => m.id), [1],
        reason: 'the cache is never replaced by nothing');
    expect(snapshots.last.failure, isNotNull);
    expect((container.read(matchesDayStateProvider(day)) as DayLoaded).view.rows.map((m) => m.id), [1]);
  });
}
