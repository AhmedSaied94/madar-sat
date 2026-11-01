import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../format/local_day.dart';
import '../format/retention.dart';
import '../format/time.dart';
import '../network/generated/models/broadcast.dart';
import '../network/generated/models/commentator_ref.dart';
import '../network/generated/models/competition_ref.dart';
import '../network/generated/models/match_summary.dart';
import '../network/generated/models/period.dart';
import '../network/generated/models/score.dart';
import '../network/generated/models/sport.dart';
import '../network/generated/models/status.dart';
import '../network/generated/models/team_ref.dart';

part 'app_database.g.dart';

/// One row per match summary. Scalar fields are columns; the nested parts are JSON
/// columns, so a refreshed contract adds fields without a migration here.
@DataClassName('StoredMatch')
class Matches extends Table {
  IntColumn get id => integer()();
  TextColumn get sport => text()();
  DateTimeColumn get kickoffAt => dateTime().nullable()();
  BoolColumn get timeTbd => boolean()();

  /// A calendar date, not an instant: `format: date` in the contract, so it is stored as
  /// `yyyy-MM-dd` text and read back as the same local `DateTime` the generated
  /// `fromJson` builds (FR-047).
  TextColumn get matchDate => text()();
  TextColumn get status => text()();
  BoolColumn get estimated => boolean()();
  TextColumn get period => text().nullable()();
  TextColumn get minute => text().nullable()();
  TextColumn get scoreJson => text().nullable()();
  TextColumn get statusLabel => text().nullable()();
  TextColumn get competitionJson => text()();
  TextColumn get homeJson => text()();
  TextColumn get awayJson => text()();
  TextColumn get broadcastJson => text()();
  TextColumn get commentatorJson => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// When each local day of matches was last revalidated, and the ETag that revalidation
/// stored (research R25). The rows themselves live in [Matches]; a day's rows are the ones
/// whose kickoff falls in its UTC window.
@DataClassName('StoredWindow')
class MatchWindows extends Table {
  /// `yyyy-MM-dd`, the device's local day.
  TextColumn get day => text()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {day};
}

/// Whole JSON documents with their ETag: match detail, `/v1/satellites`, a satellite's
/// channels, and S4's day filtered by satellite (R25). `body` is the envelope's `data` as
/// JSON text.
@DataClassName('StoredDocument')
class CachedDocuments extends Table {
  TextColumn get key => text()();
  TextColumn get etag => text().nullable()();
  TextColumn get body => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The device's own settings: onboarding progress, theme, time zone, clock format, font
/// scale and my satellites (D3, research R27). Values are text; the typed accessors and the
/// enums live in `core/settings/app_settings.dart`, so a new setting needs no migration.
@DataClassName('StoredSetting')
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The device's follow set: the source of truth (P1), mirrored to the server by
/// `FollowsRepository`. [kind] is one of `team`, `competition`, `channel`, `commentator`
/// and `match`; [targetId] is the server id.
@DataClassName('StoredFollow')
class Follows extends Table {
  TextColumn get kind => text()();
  IntColumn get targetId => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {kind, targetId};
}

/// What still needs sending, and what happened to the last attempt: `follows` and `device`
/// (research R27). Retried on launch, on resume and on reconnect.
@DataClassName('StoredSyncState')
class SyncState extends Table {
  TextColumn get key => text()();
  BoolColumn get dirty => boolean()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get attemptedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// One `sync_state` row. [attemptedAt] is UTC.
class SyncRecord {
  const SyncRecord({required this.dirty, this.lastError, this.attemptedAt});

  final bool dirty;
  final String? lastError;
  final DateTime? attemptedAt;
}

/// A day's revalidation record. [fetchedAt] is UTC.
class CachedWindow {
  const CachedWindow({required this.day, required this.etag, required this.fetchedAt});

  final String day;
  final String? etag;
  final DateTime fetchedAt;
}

/// One cached document. [fetchedAt] is UTC.
class CachedDocument {
  const CachedDocument({
    required this.key,
    required this.etag,
    required this.body,
    required this.fetchedAt,
  });

  final String key;
  final String? etag;
  final String body;
  final DateTime fetchedAt;
}

/// The app's drift database (P6). Native and web both go through `drift_flutter`.
///
/// Schema 2 (D2) adds [MatchWindows] and [CachedDocuments]; schema 3 (D3) adds
/// [AppSettingsTable], [Follows] and [SyncState] (research R27). [now] and [offsetAt] are the
/// device clock and zone, injectable so day windows and pruning are testable without the
/// host zone; [offsetAt] has the shape `MadarTime.dayWindow` takes. D3 passes the user's
/// chosen zone here, so every local day and every wall clock follows it.
@DriftDatabase(
  tables: [Matches, MatchWindows, CachedDocuments, AppSettingsTable, Follows, SyncState],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(
    super.e, {
    DateTime Function()? now,
    this._offsetAt,
  }) : now = now ?? DateTime.now;

  /// Opens the app's database. The web needs both assets shipped in `web/` (no CDN): the
  /// SQLite WebAssembly module and drift's worker (see `app/CLAUDE.md`).
  AppDatabase.open({Duration Function(DateTime local)? offsetAt})
      : this(
          driftDatabase(
            name: 'madar',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            ),
          ),
          offsetAt: offsetAt,
        );

  /// The device's local wall clock.
  final DateTime Function() now;
  final Duration Function(DateTime local)? _offsetAt;

  /// A document nobody has revalidated for this long is dropped on start, so match-detail
  /// copies of long-gone matches do not pile up.
  static const Duration documentRetention = Retention.documents;

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(matchWindows);
            await migrator.createTable(cachedDocuments);
          }
          if (from < 3) {
            await migrator.createTable(appSettingsTable);
            await migrator.createTable(follows);
            await migrator.createTable(syncState);
          }
        },
        beforeOpen: (details) => pruneOutsideWindow(),
      );

  /// The UTC bounds of the local [day].
  DayWindow dayWindow(DateTime day) => MadarTime.dayWindow(day, offsetAt: zoneAt);

  /// The zone offset in force: the user's choice (D3) or the device's own.
  Duration zoneAt(DateTime local) => _offsetAt?.call(local) ?? local.timeZoneOffset;

  /// The wall clock of the zone the app is set to, built from the device's instant.
  DateTime get wallClockNow => now().toUtc().add(zoneAt(now()));

  DateTime get today {
    final wall = wallClockNow;
    return DateTime(wall.year, wall.month, wall.day);
  }

  /// Every cached match, in no particular order.
  Future<List<MatchSummary>> readAll() async {
    final rows = await select(matches).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  /// The cached rows of the local [day]: kickoffs inside its UTC window, plus matches with
  /// no kickoff whose date is that day.
  Future<List<MatchSummary>> readDay(DateTime day) async {
    final window = dayWindow(day);
    final key = LocalDays.key(day);
    final query = select(matches)
      ..where((t) => _inDay(t, window, key))
      ..orderBy([(t) => OrderingTerm.asc(t.kickoffAt), (t) => OrderingTerm.asc(t.id)]);
    return (await query.get()).map(_fromRow).toList(growable: false);
  }

  /// Replaces the local [day]'s rows and its ETag in one transaction (R25).
  ///
  /// Only that day's rows are removed; rows of other days stay. A match that moved to
  /// another day is simply overwritten by id when that day is fetched.
  Future<void> replaceDay(
    DateTime day,
    List<MatchSummary> rows, {
    required String? etag,
    required DateTime fetchedAt,
    String? windowKey,
  }) {
    final window = dayWindow(day);
    final key = LocalDays.key(day);
    // Under [windowKey], which is the day alone or the day with the ranking it was fetched
    // for (M-R1-5). The rows belong to that answer, so no other ETag may confirm them.
    final etagKey = windowKey ?? key;
    return transaction(() async {
      await (delete(matches)..where((t) => _inDay(t, window, key))).go();
      await batch((batch) {
        batch.insertAllOnConflictUpdate(matches, rows.map(_toRow).toList());
      });
      await (delete(matchWindows)
            ..where((t) => t.day.equals(key) | t.day.like('$key|%')))
          .go();
      await _writeWindow(etagKey, etag, fetchedAt);
    });
  }

  Future<CachedWindow?> windowFor(String day) async {
    final row = await (select(matchWindows)..where((t) => t.day.equals(day))).getSingleOrNull();
    return row == null ? null : _toWindow(row);
  }

  Stream<CachedWindow?> watchWindow(String day) => (select(matchWindows)
        ..where((t) => t.day.equals(day)))
      .watchSingleOrNull()
      .map((row) => row == null ? null : _toWindow(row));

  Future<void> putWindow({
    required String day,
    required String? etag,
    required DateTime fetchedAt,
  }) =>
      _writeWindow(day, etag, fetchedAt);

  /// A `304`: only the fetch time moves.
  Future<void> touchWindow(String day, DateTime fetchedAt) =>
      (update(matchWindows)..where((t) => t.day.equals(day)))
          .write(MatchWindowsCompanion(fetchedAt: Value(fetchedAt.toUtc())));

  Future<CachedDocument?> documentFor(String key) async {
    final row =
        await (select(cachedDocuments)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? null : _toDocument(row);
  }

  Stream<CachedDocument?> watchDocument(String key) => (select(cachedDocuments)
        ..where((t) => t.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row == null ? null : _toDocument(row));

  Future<void> putDocument({
    required String key,
    required String? etag,
    required String body,
    required DateTime fetchedAt,
  }) =>
      into(cachedDocuments).insertOnConflictUpdate(
        CachedDocumentsCompanion.insert(
          key: key,
          etag: Value(etag),
          body: body,
          fetchedAt: fetchedAt.toUtc(),
        ),
      );

  /// A `304`: only the fetch time moves.
  Future<void> touchDocument(String key, DateTime fetchedAt) =>
      (update(cachedDocuments)..where((t) => t.key.equals(key)))
          .write(CachedDocumentsCompanion(fetchedAt: Value(fetchedAt.toUtc())));

  /// Drops matches, windows and day-keyed documents outside yesterday … today + 6, and
  /// documents that have not been revalidated within [documentRetention].
  Future<void> pruneOutsideWindow() async {
    final first = LocalDays.add(today, -Retention.daysBack);
    final last = LocalDays.add(today, Retention.daysAhead);
    final from = dayWindow(first).from;
    final to = dayWindow(last).to;
    final firstKey = LocalDays.key(first);
    final lastKey = LocalDays.key(last);

    await transaction(() async {
      await (delete(matches)
            ..where(
              (t) =>
                  (t.kickoffAt.isNotNull() &
                      (t.kickoffAt.isSmallerThanValue(from) |
                          t.kickoffAt.isBiggerOrEqualValue(to))) |
                  (t.kickoffAt.isNull() &
                      (t.matchDate.isSmallerThanValue(firstKey) |
                          t.matchDate.isBiggerThanValue(lastKey))),
            ))
          .go();
      // A window's key is the day, or the day with the ranking it was fetched for
      // (`2026-11-01|3,7`): prune on the day part, so today's keyed window stays.
      final windows = await (select(matchWindows)).map((row) => row.day).get();
      for (final window in windows) {
        final day = window.split('|').first;
        if (day.compareTo(firstKey) < 0 || day.compareTo(lastKey) > 0) {
          await (delete(matchWindows)..where((t) => t.day.equals(window))).go();
        }
      }

      final dayKeyed = await (select(cachedDocuments)..where((t) => t.key.like('matches:%')))
          .map((row) => row.key)
          .get();
      for (final key in dayKeyed) {
        final day = key.split(':')[1];
        if (day.compareTo(firstKey) < 0 || day.compareTo(lastKey) > 0) {
          await (delete(cachedDocuments)..where((t) => t.key.equals(key))).go();
        }
      }
      final cutoff = now().toUtc().subtract(documentRetention);
      await (delete(cachedDocuments)..where((t) => t.fetchedAt.isSmallerThanValue(cutoff))).go();
    });
  }

  // D3: the device's own state (research R27). The follows and the settings are drift's;
  // the device token and install id are in `flutter_secure_storage`, never here.

  /// Every stored setting, as text.
  Future<Map<String, String>> readSettings() async {
    final rows = await select(appSettingsTable).get();
    return {for (final row in rows) row.key: row.value};
  }

  /// Every stored setting, re-emitted on each write.
  Stream<Map<String, String>> watchSettings() =>
      select(appSettingsTable).watch().map(
            (rows) => {for (final row in rows) row.key: row.value},
          );

  Future<String?> readSetting(String key) async {
    final row = await (select(appSettingsTable)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watchSetting(String key) => (select(appSettingsTable)
        ..where((t) => t.key.equals(key)))
      .watchSingleOrNull()
      .map((row) => row?.value);

  /// Writes one setting; a null [value] removes it, so the bundled default applies again.
  Future<void> writeSetting(String key, String? value) => transaction(() async {
        if (value == null) {
          await (delete(appSettingsTable)..where((t) => t.key.equals(key))).go();
        } else {
          await into(appSettingsTable).insertOnConflictUpdate(
            AppSettingsTableCompanion.insert(
              key: key,
              value: value,
              updatedAt: now().toUtc(),
            ),
          );
        }
      });

  /// Several settings in one transaction: onboarding writes its step and its flag together.
  Future<void> writeSettings(Map<String, String?> values) => transaction(() async {
        for (final entry in values.entries) {
          await writeSettingNoTransaction(entry.key, entry.value);
        }
      });

  /// The body of [writeSetting] without opening a transaction of its own.
  Future<void> writeSettingNoTransaction(String key, String? value) async {
    if (value == null) {
      await (delete(appSettingsTable)..where((t) => t.key.equals(key))).go();
      return;
    }
    await into(appSettingsTable).insertOnConflictUpdate(
      AppSettingsTableCompanion.insert(
        key: key,
        value: value,
        updatedAt: now().toUtc(),
      ),
    );
  }

  /// The follow set, oldest first.
  Future<List<StoredFollow>> readFollows() =>
      (select(follows)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();

  Stream<List<StoredFollow>> watchFollows() => (select(follows)
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .watch();

  /// Adds or removes one follow. Repeating it is harmless; the local set stays the source
  /// of truth (P1).
  Future<void> setFollow({
    required String kind,
    required int targetId,
    required bool on,
  }) async {
    if (!on) {
      await (delete(follows)
            ..where((t) => t.kind.equals(kind) & t.targetId.equals(targetId)))
          .go();
      return;
    }
    await into(follows).insertOnConflictUpdate(
      FollowsCompanion.insert(
        kind: kind,
        targetId: targetId,
        createdAt: now().toUtc(),
      ),
    );
  }

  /// Replaces one kind's whole set, so a picker's result is written in one step.
  Future<void> replaceFollowsOfKind(String kind, Set<int> targetIds) => transaction(() async {
        await (delete(follows)..where((t) => t.kind.equals(kind))).go();
        await batch((batch) {
          batch.insertAll(
            follows,
            [
              for (final id in targetIds)
                FollowsCompanion.insert(
                  kind: kind,
                  targetId: id,
                  createdAt: now().toUtc(),
                ),
            ],
          );
        });
      });

  /// `DELETE /devices/me` clears the device's own data after the server answered.
  Future<void> clearDeviceData() => transaction(() async {
        await delete(follows).go();
        await delete(appSettingsTable).go();
        await delete(syncState).go();
      });

  Future<SyncRecord?> readSyncState(String key) async {
    final row =
        await (select(syncState)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null
        ? null
        : SyncRecord(
            dirty: row.dirty,
            lastError: row.lastError,
            attemptedAt: row.attemptedAt?.toUtc(),
          );
  }

  Stream<SyncRecord?> watchSyncState(String key) => (select(syncState)
        ..where((t) => t.key.equals(key)))
      .watchSingleOrNull()
      .map(
        (row) => row == null
            ? null
            : SyncRecord(
                dirty: row.dirty,
                lastError: row.lastError,
                attemptedAt: row.attemptedAt?.toUtc(),
              ),
      );

  /// Flags a sync that still has to reach the server, with the reason the last try failed.
  Future<void> markSyncDirty(String key, {String? error}) =>
      into(syncState).insertOnConflictUpdate(
        SyncStateCompanion.insert(
          key: key,
          dirty: true,
          lastError: Value(error),
          attemptedAt: Value(now().toUtc()),
        ),
      );

  /// Flags a sync the server accepted.
  Future<void> markSyncClean(String key) => into(syncState).insertOnConflictUpdate(
        SyncStateCompanion.insert(
          key: key,
          dirty: false,
          lastError: const Value(null),
          attemptedAt: Value(now().toUtc()),
        ),
      );

  Future<void> _writeWindow(String day, String? etag, DateTime fetchedAt) =>      into(matchWindows).insertOnConflictUpdate(
        MatchWindowsCompanion.insert(day: day, etag: Value(etag), fetchedAt: fetchedAt.toUtc()),
      );

  static Expression<bool> _inDay($MatchesTable t, DayWindow window, String key) =>
      (t.kickoffAt.isBiggerOrEqualValue(window.from) & t.kickoffAt.isSmallerThanValue(window.to)) |
      (t.kickoffAt.isNull() & t.matchDate.equals(key));

  static CachedWindow _toWindow(StoredWindow row) =>
      CachedWindow(day: row.day, etag: row.etag, fetchedAt: row.fetchedAt.toUtc());

  static CachedDocument _toDocument(StoredDocument row) => CachedDocument(
        key: row.key,
        etag: row.etag,
        body: row.body,
        fetchedAt: row.fetchedAt.toUtc(),
      );

  MatchesCompanion _toRow(MatchSummary match) => MatchesCompanion.insert(
        id: Value(match.id),
        sport: _enumText(match.sport),
        kickoffAt: Value(match.kickoffAt?.toUtc()),
        timeTbd: match.timeTbd,
        matchDate: _dateText(match.matchDate),
        status: _enumText(match.status),
        estimated: match.estimated,
        period: Value(match.period == null ? null : _enumText(match.period!)),
        minute: Value(match.minute),
        scoreJson: Value(match.score == null ? null : jsonEncode(match.score!.toJson())),
        statusLabel: Value(match.statusLabel),
        competitionJson: jsonEncode(match.competition.toJson()),
        homeJson: jsonEncode(match.home.toJson()),
        awayJson: jsonEncode(match.away.toJson()),
        broadcastJson: jsonEncode(match.broadcast.toJson()),
        commentatorJson: Value(
          match.commentator == null ? null : jsonEncode(match.commentator!.toJson()),
        ),
        updatedAt: match.updatedAt.toUtc(),
      );

  /// `yyyy-MM-dd` for a calendar date; a full ISO string would carry a zone the date
  /// does not have.
  static String _dateText(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// The generated enums keep the contract value in `json` and fall back to `$unknown` for
  /// a value this build does not know; `name` keeps that fallback readable instead of
  /// storing an empty string (FR-047).
  static String _enumText(Object value) => switch (value) {
        final Sport sport => sport.json ?? sport.name,
        final Status status => status.json ?? status.name,
        final Period period => period.json ?? period.name,
        _ => '$value',
      };

  MatchSummary _fromRow(StoredMatch row) => MatchSummary(
        id: row.id,
        sport: Sport.fromJson(row.sport),
        kickoffAt: row.kickoffAt?.toUtc(),
        timeTbd: row.timeTbd,
        matchDate: DateTime.parse(row.matchDate),
        status: Status.fromJson(row.status),
        estimated: row.estimated,
        period: row.period == null ? null : Period.fromJson(row.period!),
        minute: row.minute,
        score: row.scoreJson == null
            ? null
            : Score.fromJson(jsonDecode(row.scoreJson!) as Map<String, Object?>),
        statusLabel: row.statusLabel,
        competition: CompetitionRef.fromJson(
          jsonDecode(row.competitionJson) as Map<String, Object?>,
        ),
        home: TeamRef.fromJson(jsonDecode(row.homeJson) as Map<String, Object?>),
        away: TeamRef.fromJson(jsonDecode(row.awayJson) as Map<String, Object?>),
        broadcast: Broadcast.fromJson(
          jsonDecode(row.broadcastJson) as Map<String, Object?>,
        ),
        commentator: row.commentatorJson == null
            ? null
            : CommentatorRef.fromJson(
                jsonDecode(row.commentatorJson!) as Map<String, Object?>,
              ),
        updatedAt: row.updatedAt.toUtc(),
      );
}
