import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/core/format/clock.dart';
import 'package:madar_sat/core/network/generated/models/match_summary.dart';
import 'package:madar_sat/core/settings/app_settings.dart';
import 'package:madar_sat/core/settings/settings_providers.dart';
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
  Stream<SwrSnapshot<List<MatchSummary>>> watchDay(
    DateTime day, {
    Set<int> mySatelliteIds = const {},
  }) {
    dayReads += 1;
    return super.watchDay(day, mySatelliteIds: mySatelliteIds);
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
      overrides: [
        swrRepositoryProvider.overrideWithValue(repo),
        // The day provider reads My satellites and the zone, which are settings.
        appDatabaseProvider.overrideWithValue(database),
      ],
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
  group('S2 follows My satellites and the chosen zone (M-R1-5, M-R1-6)', () {
    /// A container over [database] with the app's settings and a pinned clock.
    ProviderContainer zoneContainer({required DateTime clock}) {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          clockProvider.overrideWithValue(() => clock),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('with satellites chosen, the day request carries my_satellite_ids', () async {
      await database.writeSetting(SettingsKeys.satelliteIds, '3,7');
      final http = FakeHttpAdapter()..enqueueData([_json(match)], etag: '"v1"');
      final repository = _CountingRepository(dio: fakeDio(http), database: database);
      final container = ProviderContainer(
        overrides: [
          swrRepositoryProvider.overrideWithValue(repository),
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      container.listen(matchesDayProvider(day), (_, _) {});
      await container.read(matchesDayProvider(day).future);
      await pumpEventQueue();

      expect(http.requests.last.uri.queryParameters['my_satellite_ids'], '3,7');
    });

    test('changing the selection re-reads instead of reusing the old ETag', () async {
      await database.writeSetting(SettingsKeys.satelliteIds, '3,7');
      final http = FakeHttpAdapter()
        ..enqueueData([_json(match)], etag: '"v1"')
        ..enqueueData([_json(match)], etag: '"v2"');
      final repository = _CountingRepository(dio: fakeDio(http), database: database);
      final container = ProviderContainer(
        overrides: [
          swrRepositoryProvider.overrideWithValue(repository),
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appSettingsProvider.future);

      container.listen(matchesDayProvider(day), (_, _) {});
      await container.read(matchesDayProvider(day).future);
      await pumpEventQueue();
      expect(http.requests.single.uri.queryParameters['my_satellite_ids'], '3,7');

      await container.read(appSettingsProvider.notifier).setSatellites({5});
      await container.read(appSettingsProvider.future);
      await container.read(matchesDayProvider(day).future);
      await pumpEventQueue();

      final changed = http.requests.last;
      expect(changed.uri.queryParameters['my_satellite_ids'], '5');
      expect(http.ifNoneMatch(http.requests.length - 1), isNull,
          reason: 'the old selection\'s ETag cannot confirm the new ranking');
    });

    test('the local day is the chosen zone\'s, not the device\'s', () async {
      // 22:30 UTC: 01:30 the next day at GMT+3, 10:30 the same day at GMT−12.
      final container = zoneContainer(clock: DateTime.utc(2026, 10, 28, 22, 30));
      await container.read(appSettingsProvider.future);

      await container.read(appSettingsProvider.notifier).setZone(const MadarZone.fixed(Duration(hours: 3)));
      await container.read(appSettingsProvider.future);
      final east = container.read(matchesWindowProvider).today;
      expect(east, DateTime(2026, 10, 29));

      await container
          .read(appSettingsProvider.notifier)
          .setZone(const MadarZone.fixed(Duration(hours: -12)));
      await container.read(appSettingsProvider.future);
      final west = container.read(matchesWindowProvider).today;
      expect(west, DateTime(2026, 10, 28));
    });

    test('the drift layer groups days in the chosen zone', () async {
      final container = zoneContainer(clock: DateTime.utc(2026, 10, 28, 22, 30));
      await container.read(appSettingsProvider.future);
      await container
          .read(appSettingsProvider.notifier)
          .setZone(const MadarZone.fixed(Duration(hours: 3)));
      await container.read(appSettingsProvider.future);

      final selected = container.read(appDatabaseProvider);
      final window = selected.dayWindow(DateTime(2026, 10, 29));
      expect(window.from, DateTime.utc(2026, 10, 28, 21));
      expect(window.to, DateTime.utc(2026, 10, 29, 21));
    });
  });

}
