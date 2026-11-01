import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/db/database_provider.dart';
import 'package:madar_sat/features/follows/data/follows_repository.dart';
import 'package:madar_sat/features/follows/domain/follow_set.dart';

/// The device's follow set (research R27, US2 scenario 6): every change lands in drift at
/// once and flags `sync_state.follows`; the local set stays the source of truth, so a failed
/// send changes nothing here. The send itself is T133's, against B1's device client.
void main() {
  late AppDatabase database;
  late ProviderContainer container;

  FollowsRepository repository() => container.read(followsRepositoryProvider);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    container.listen(followsSetProvider, (_, _) {});
  });

  Future<FollowSet> read() => repository().read();

  test('a toggle writes drift and flags the set for the server', () async {
    await repository().toggle(FollowKind.team, 7);

    expect((await read()).teams, {7});
    final sync = await database.readSyncState('follows');
    expect(sync!.dirty, isTrue);

    await repository().toggle(FollowKind.team, 7);
    expect((await read()).teams, isEmpty);
    expect((await database.readSyncState('follows'))!.dirty, isTrue);
  });

  test('the full set is written per kind, and the last full set wins', () async {
    await repository().replace(FollowKind.team, {1, 2, 3});
    await repository().replace(FollowKind.team, {31, 32});
    await repository().replace(FollowKind.match, {900});

    final follows = await read();
    expect(follows.teams, {31, 32}, reason: 'the last full set wins');
    expect(follows.matches, {900});
    expect(follows.total, 3);
  });

  test('a write makes the set provider read again, so S9 redraws without a refresh',
      () async {
    await container.read(followsSetProvider.future);
    expect(container.read(followSetValueProvider).total, 0);

    await repository().toggle(FollowKind.team, 4);
    await pumpEventQueue();
    await container.read(followsSetProvider.future);
    expect(container.read(followSetValueProvider).total, 1);

    await repository().toggle(FollowKind.competition, 9);
    await pumpEventQueue();
    await container.read(followsSetProvider.future);
    expect(container.read(followSetValueProvider).total, 2);
  });

  test('clearing the device leaves an empty set and no pending sync', () async {
    await repository().replace(FollowKind.team, {5});

    await repository().clear();

    expect(await read(), FollowSet.empty);
    expect(await database.readSyncState('follows'), isNull);
  });
}
