import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar_sat/core/db/app_database.dart';
import 'package:madar_sat/core/network/generated/models/match_summary.dart';

import '../../fixtures/sample_models.dart';

/// D1 shipped schema version 1 (only `matches`). D2 adds `match_windows` and
/// `cached_documents` at version 2 without losing the rows people already have (R25).
void main() {
  // Pinned so the retention window does not depend on the day the test runs, and the
  // zone is a fixed +03 so it does not depend on the host either: every instant below is
  // written in UTC and its +03 wall clock is in the comment.
  final now = DateTime(2026, 10, 28, 12);
  final inWindow = sampleMatch(id: 1, kickoff: DateTime.utc(2026, 10, 28, 18));
  final tooOld = sampleMatch(id: 2, kickoff: DateTime.utc(2026, 10, 20, 18));
  final tooFar = sampleMatch(id: 3, kickoff: DateTime.utc(2026, 11, 20, 18));
  // Oct 27 00:30 +03: the first half hour of yesterday.
  final edgeYesterday = sampleMatch(id: 4, kickoff: DateTime.utc(2026, 10, 26, 21, 30));
  // Nov 3 23:30 +03: the last half hour of today + 6.
  final edgeSixthDay = sampleMatch(id: 5, kickoff: DateTime.utc(2026, 11, 3, 20, 30));
  // Nov 4 00:30 +03: today + 7, outside.
  final edgeSeventhDay = sampleMatch(id: 6, kickoff: DateTime.utc(2026, 11, 3, 21, 30));

  AppDatabase openV1(List<MatchSummary> rows) => AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(_v1MatchesDdl);
            for (final match in rows) {
              raw.execute(_insertV1, [
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
            raw.execute('PRAGMA user_version = 1');
          },
        ),
        now: () => now,
        offsetAt: (_) => const Duration(hours: 3),
      );

  test('a version-1 database opens at version 2 with its rows intact', () async {
    final database = openV1([inWindow]);
    addTearDown(database.close);

    expect(database.schemaVersion, 2);
    final rows = await database.readAll();
    expect(rows, hasLength(1));
    expect(rows.single.id, inWindow.id);
    expect(rows.single.home.name, inWindow.home.name);
    expect(rows.single.kickoffAt, inWindow.kickoffAt!.toUtc());

    final version = await database.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 2);
  });

  test('match_windows has day (primary key), etag and fetched_at', () async {
    final database = openV1(const []);
    addTearDown(database.close);

    final columns = await _columns(database, 'match_windows');

    expect(columns.keys, containsAll(['day', 'etag', 'fetched_at']));
    expect(columns['day']!.primaryKey, isTrue);
    expect(columns['etag']!.primaryKey, isFalse);
    expect(columns['fetched_at']!.notNull, isTrue);
  });

  test('cached_documents has key (primary key), etag, body and fetched_at', () async {
    final database = openV1(const []);
    addTearDown(database.close);

    final columns = await _columns(database, 'cached_documents');

    expect(columns.keys, containsAll(['key', 'etag', 'body', 'fetched_at']));
    expect(columns['key']!.primaryKey, isTrue);
    expect(columns['body']!.notNull, isTrue);
    expect(columns['fetched_at']!.notNull, isTrue);
  });

  test('local days outside today-1 … today+6 are pruned on start', () async {
    final database = openV1([
      inWindow,
      tooOld,
      tooFar,
      edgeYesterday,
      edgeSixthDay,
      edgeSeventhDay,
    ]);
    addTearDown(database.close);

    final ids = (await database.readAll()).map((m) => m.id).toSet();

    // Oct 27 (yesterday) through Nov 3 (today + 6) stay; Oct 20, Nov 4 and Nov 20 go.
    expect(ids, {1, 4, 5});
  });

  test('a match with an unknown kickoff is kept or pruned by its match date', () async {
    final tbdToday = sampleMatchFromJson(nullKickoff: true).copyWith(id: 7);
    final tbdOld = sampleMatchFromJson(matchDate: '2026-10-01', nullKickoff: true).copyWith(id: 8);
    final database = openV1([tbdToday, tbdOld]);
    addTearDown(database.close);

    expect((await database.readAll()).map((m) => m.id), [7]);
  });

  test('windows and documents outside the window are pruned on start too', () async {
    final database = openV1(const []);
    addTearDown(database.close);
    await database.putWindow(day: '2026-10-20', etag: '"a"', fetchedAt: now);
    await database.putWindow(day: '2026-10-28', etag: '"b"', fetchedAt: now);
    await database.putDocument(
      key: 'matches:2026-10-20:sat:2,5',
      etag: '"c"',
      body: '[]',
      fetchedAt: now,
    );
    await database.putDocument(key: 'satellites', etag: '"d"', body: '[]', fetchedAt: now);

    await database.pruneOutsideWindow();

    expect((await database.windowFor('2026-10-20')), isNull);
    expect((await database.windowFor('2026-10-28')), isNotNull);
    expect(await database.documentFor('matches:2026-10-20:sat:2,5'), isNull);
    expect(await database.documentFor('satellites'), isNotNull);
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

/// The `matches` table as D1 (schema version 1) created it.
const _v1MatchesDdl = '''
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

const _insertV1 = '''
INSERT INTO matches (
  id, sport, kickoff_at, time_tbd, match_date, status, estimated, period, minute,
  score_json, status_label, competition_json, home_json, away_json, broadcast_json,
  commentator_json, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''';
