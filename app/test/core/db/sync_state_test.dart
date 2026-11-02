import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';

/// `sync_state` (research R27): the durable flag says *something* still has to reach the
/// server; the revision says whether *that* something changed while a send was in flight,
/// so a send clears the flag only for the state it actually carried (M-R2-1).
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory(), now: () => DateTime.utc(2026, 11, 1, 9));
    addTearDown(database.close);
  });

  test('a change moves the revision and tells the listeners; a failed attempt does neither',
      () async {
    final changed = <String>[];
    final subscription = database.syncChanges.listen(changed.add);
    addTearDown(subscription.cancel);
    final before = database.syncRevision('follows');

    await database.markSyncDirty('follows');
    await pumpEventQueue();
    expect(database.syncRevision('follows'), before + 1);
    expect(changed, ['follows']);

    // The record of a failure is not a change: it must not wake a sync, or a server that
    // keeps refusing would be retried in a loop.
    await database.markSyncDirty('follows', error: 'network');
    await pumpEventQueue();
    expect(database.syncRevision('follows'), before + 1);
    expect(changed, ['follows']);
    expect((await database.readSyncState('follows'))!.lastError, 'network');
  });

  test('the flag clears when nothing was flagged since the revision was read', () async {
    await database.markSyncDirty('follows');
    final read = database.syncRevision('follows');

    expect(await database.markSyncCleanIfUnchanged('follows', read), isTrue);
    expect((await database.readSyncState('follows'))!.dirty, isFalse);
  });

  test('the flag stays set when something was flagged after the revision was read', () async {
    await database.markSyncDirty('follows');
    final read = database.syncRevision('follows');
    await database.markSyncDirty('follows');

    expect(await database.markSyncCleanIfUnchanged('follows', read), isFalse);
    expect((await database.readSyncState('follows'))!.dirty, isTrue);
  });

  test('a revision is per key: a device change does not hold back the follows', () async {
    await database.markSyncDirty('follows');
    final read = database.syncRevision('follows');
    await database.markSyncDirty('device');

    expect(await database.markSyncCleanIfUnchanged('follows', read), isTrue);
    expect((await database.readSyncState('device'))!.dirty, isTrue);
  });
}
