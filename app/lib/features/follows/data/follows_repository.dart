import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/database_provider.dart';
import '../domain/follow_set.dart';

part 'follows_repository.g.dart';

/// The device's follow set in drift (research R27, P1).
///
/// Every change writes drift first, flags `sync_state.follows` dirty and asks
/// [followsSetProvider] to read again, so the device stays the source of truth and the
/// screen redraws without a refresh. The server copy is brought up to it by T133's send; a
/// failed send changes nothing here (US2 scenario 6).
class FollowsRepository {
  const FollowsRepository(this._db, this._onChanged);

  final AppDatabase _db;

  /// Bumped after every write, so [followsSetProvider] reads drift again.
  final void Function() _onChanged;

  Future<FollowSet> read() async => toSet(await _db.readFollows());

  /// Follows or unfollows one target, then flags the set for the server.
  Future<void> set(FollowKind kind, int id, {required bool follow}) async {
    await _db.setFollow(kind: kind.name, targetId: id, on: follow);
    await _db.markSyncDirty('follows');
    _reload();
  }

  Future<void> toggle(FollowKind kind, int id) async {
    final current = await read();
    await set(kind, id, follow: !current.contains(kind, id));
  }

  /// A picker's whole selection for one kind, in one write.
  Future<void> replace(FollowKind kind, Set<int> ids) async {
    await _db.replaceFollowsOfKind(kind.name, ids);
    await _db.markSyncDirty('follows');
    _reload();
  }

  /// «حذف بيانات جهازي»: the server answered, so both sides start clean.
  Future<void> clear() async {
    await _db.clearDeviceData();
    _reload();
  }

  void _reload() => _onChanged();

  /// Rows back into the typed set. An unknown kind from a newer build is read as a team so
  /// the row still shows instead of disappearing.
  static FollowSet toSet(List<StoredFollow> rows) {
    final byKind = <FollowKind, Set<int>>{};
    for (final row in rows) {
      final kind = FollowKind.values.firstWhere(
        (value) => value.name == row.kind,
        orElse: () => FollowKind.team,
      );
      (byKind[kind] ??= {}).add(row.targetId);
    }
    var set = FollowSet.empty;
    for (final entry in byKind.entries) {
      set = set.withKind(entry.key, entry.value);
    }
    return set;
  }
}

@Riverpod(keepAlive: true)
FollowsRepository followsRepository(Ref ref) => FollowsRepository(
      ref.watch(appDatabaseProvider),
      () => ref.read(followsRevisionProvider.notifier).bump(),
    );

/// Counts writes to the follow set. [followsSetProvider] watches it, so a follow made in S3
/// redraws S9 without a refresh and without a provider invalidating its own dependency.
@Riverpod(keepAlive: true)
class FollowsRevision extends _$FollowsRevision {
  @override
  int build() => 0;

  void bump() => state++;
}

/// The follow set, read from drift.
@Riverpod(keepAlive: true)
Future<FollowSet> followsSet(Ref ref) {
  ref.watch(followsRevisionProvider);
  return ref.watch(followsRepositoryProvider).read();
}

/// The set as a plain value, for a widget that only reads membership and counts.
@riverpod
FollowSet followSetValue(Ref ref) =>
    ref.watch(followsSetProvider).value ?? FollowSet.empty;
