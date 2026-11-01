import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/network/generated/models/match_summary.dart';

import '../../fixtures/sample_models.dart';

/// D2 shipped schema version 2 (`matches`, `match_windows`, `cached_documents`). D3 adds
/// `app_settings`, `follows` and `sync_state` at version 3 without losing what people
/// already have, and without touching D2's tables (data-model, research R27).
void main() {
  final now = DateTime(2026, 11, 1, 9);
  final kept = sampleMatch(id: 1, kickoff: DateTime.utc(2026, 11, 1, 18));

  AppDatabase openV2(List<MatchSummary> rows) => AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(_v2MatchesDdl);
            raw.execute(_v2MatchWindowsDdl);
            raw.execute(_v2CachedDocumentsDdl);
            for (final match in rows) {
              raw.execute(_insertV2Match, [
                match.id,
                match.sport.json,
                match.kickoffAt == null ? null : match.kickoffAt!.millisecondsSinceEpoch ~/ 1000,
                match.timeTbd ? 1 : 0,
                _dateText(match.matchDate),
                match.status.json,
                match.estimated ? 1 : 0,
                null,
                match.minute,
                null,
                match.statusLabel,
                jsonEncode(match.competition.toJson()),
                jsonEncode(match.home.toJson()),
                jsonEncode(match.away.toJson()),
                jsonEncode(match.broadcast.toJson()),
                null,
                match.updatedAt.millisecondsSinceEpoch ~/ 1000,
              ]);
            }
            raw.execute(
              'INSERT INTO match_windows (day, etag, fetched_at) VALUES (?, ?, ?)',
              ['2026-11-01', '"etag-v2"', now.millisecondsSinceEpoch ~/ 1000],
            );
            raw.execute(
              'INSERT INTO cached_documents (key, etag, body, fetched_at) VALUES (?, ?, ?, ?)',
              ['satellites', '"etag-doc"', '[]', now.millisecondsSinceEpoch ~/ 1000],
            );
            raw.execute('PRAGMA user_version = 2');
          },
        ),
        now: () => DateTime.utc(2026, 11, 1, 9),
        offsetAt: (_) => const Duration(hours: 3),
      );

  test('a version-2 database opens at version 3 with its rows intact', () async {
    final database = openV2([kept]);
    addTearDown(database.close);

    expect(database.schemaVersion, 3);
    final rows = await database.readAll();
    expect(rows.map((m) => m.id), [1]);
    expect(rows.single.home.name, kept.home.name);
    expect((await database.windowFor('2026-11-01'))?.etag, '"etag-v2"');
    expect((await database.documentFor('satellites'))?.etag, '"etag-doc"');

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 3);
  });

  test('app_settings is key, value and updated_at, keyed by key', () async {
    final database = openV2(const []);
    addTearDown(database.close);

    final columns = await _columns(database, 'app_settings');
    expect(columns.keys, containsAll(['key', 'value', 'updated_at']));
    expect(columns['key']!.primaryKey, isTrue);
    expect(columns['value']!.notNull, isTrue);
  });

  test('follows is keyed by kind and target_id', () async {
    final database = openV2(const []);
    addTearDown(database.close);

    final columns = await _columns(database, 'follows');
    expect(columns.keys, containsAll(['kind', 'target_id', 'created_at']));
    expect(columns['kind']!.primaryKey, isTrue);
    expect(columns['target_id']!.primaryKey, isTrue);
  });

  test('sync_state is keyed by key, with dirty, last_error and attempted_at', () async {
    final database = openV2(const []);
    addTearDown(database.close);

    final columns = await _columns(database, 'sync_state');
    expect(columns.keys, containsAll(['key', 'dirty', 'last_error', 'attempted_at']));
    expect(columns['key']!.primaryKey, isTrue);
    expect(columns['dirty']!.notNull, isTrue);
  });

  test('a setting is written, read, re-emitted, and removed by null', () async {
    final database = openV2(const []);
    addTearDown(database.close);

    await database.writeSetting('onboarding.step', '2');
    expect(await database.readSetting('onboarding.step'), '2');
    expect(await database.readSettings(), containsPair('onboarding.step', '2'));

    await database.writeSettings({'onboarding.step': '3', 'onboarding.done': 'true'});
    final streamed = await database.watchSettings().first;
    expect(streamed['onboarding.step'], '3');
    expect(streamed['onboarding.done'], 'true');

    await database.writeSetting('onboarding.step', null);
    expect(await database.readSetting('onboarding.step'), isNull);
    expect(await database.readSettings(), {'onboarding.done': 'true'});
  });

  test('follows add, remove and replace one kind without touching another', () async {
    final database = openV2(const []);
    addTearDown(database.close);

    await database.setFollow(kind: 'team', targetId: 7, on: true);
    await database.setFollow(kind: 'team', targetId: 9, on: true);
    await database.setFollow(kind: 'match', targetId: 70, on: true);
    await database.setFollow(kind: 'team', targetId: 9, on: true);
    expect(
      (await database.readFollows()).map((f) => '${f.kind}:${f.targetId}'),
      ['team:7', 'team:9', 'match:70'],
    );

    await database.setFollow(kind: 'team', targetId: 7, on: false);
    expect(
      (await database.readFollows()).map((f) => '${f.kind}:${f.targetId}'),
      ['team:9', 'match:70'],
    );

    await database.replaceFollowsOfKind('team', {31, 32});
    expect(
      (await database.watchFollows().first).map((f) => '${f.kind}:${f.targetId}'),
      unorderedEquals(['team:31', 'team:32', 'match:70']),
    );
  });

  test('sync state flags a pending send and clears it', () async {
    final database = openV2(const []);
    addTearDown(database.close);

    await database.markSyncDirty('follows', error: 'offline');
    final dirty = await database.readSyncState('follows');
    expect(dirty!.dirty, isTrue);
    expect(dirty.lastError, 'offline');

    await database.markSyncClean('follows');
    final clean = await database.watchSyncState('follows').first;
    expect(clean!.dirty, isFalse);
    expect(clean.lastError, isNull);
  });

  test('clearing the device data empties the three D3 tables', () async {
    final database = openV2(const []);
    addTearDown(database.close);

    await database.writeSetting('theme', 'dark');
    await database.setFollow(kind: 'team', targetId: 3, on: true);
    await database.markSyncDirty('device');

    await database.clearDeviceData();

    expect(await database.readSettings(), isEmpty);
    expect(await database.readFollows(), isEmpty);
    expect(await database.readSyncState('device'), isNull);
  });
}

String _dateText(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _Column {
  const _Column({required this.primaryKey, required this.notNull});

  final bool primaryKey;
  final bool notNull;
}

Future<Map<String, _Column>> _columns(AppDatabase database, String table) async {
  final rows = await database.customSelect('PRAGMA table_info($table)').get();
  return {
    for (final row in rows)
      row.read<String>('name'): _Column(
        primaryKey: row.read<int>('pk') > 0,
        notNull: row.read<int>('notnull') > 0,
      ),
  };
}

/// The three tables as D2 (schema version 2) created them.
const _v2MatchesDdl = '''
CREATE TABLE matches (
  id INTEGER NOT NULL PRIMARY KEY,
  sport TEXT NOT NULL,
  kickoff_at INTEGER NULL,
  time_tbd INTEGER NOT NULL CHECK (time_tbd IN (0, 1)),
  match_date TEXT NOT NULL,
  status TEXT NOT NULL,
  estimated INTEGER NOT NULL CHECK (estimated IN (0, 1)),
  period TEXT NULL,
  minute TEXT NULL,
  score_json TEXT NULL,
  status_label TEXT NULL,
  competition_json TEXT NOT NULL,
  home_json TEXT NOT NULL,
  away_json TEXT NOT NULL,
  broadcast_json TEXT NOT NULL,
  commentator_json TEXT NULL,
  updated_at INTEGER NOT NULL
)''';

const _v2MatchWindowsDdl = '''
CREATE TABLE match_windows (
  day TEXT NOT NULL PRIMARY KEY,
  etag TEXT NULL,
  fetched_at INTEGER NOT NULL
)''';

const _v2CachedDocumentsDdl = '''
CREATE TABLE cached_documents (
  key TEXT NOT NULL PRIMARY KEY,
  etag TEXT NULL,
  body TEXT NOT NULL,
  fetched_at INTEGER NOT NULL
)''';

const _insertV2Match = '''
INSERT INTO matches (
  id, sport, kickoff_at, time_tbd, match_date, status, estimated, period, minute,
  score_json, status_label, competition_json, home_json, away_json, broadcast_json,
  commentator_json, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''';
