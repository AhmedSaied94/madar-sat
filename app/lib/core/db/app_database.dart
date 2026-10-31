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
/// Schema 2 (D2) adds [MatchWindows] and [CachedDocuments]. [now] and [offsetAt] are the
/// device clock and zone, injectable so day windows and pruning are testable without the
/// host zone; [offsetAt] has the shape `MadarTime.dayWindow` takes.
@DriftDatabase(tables: [Matches, MatchWindows, CachedDocuments])
class AppDatabase extends _$AppDatabase {
  AppDatabase(
    super.e, {
    DateTime Function()? now,
    this._offsetAt,
  }) : now = now ?? DateTime.now;

  /// Opens the app's database. The web needs both assets shipped in `web/` (no CDN): the
  /// SQLite WebAssembly module and drift's worker (see `app/CLAUDE.md`).
  AppDatabase.open()
      : this(
          driftDatabase(
            name: 'madar',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            ),
          ),
        );

  /// The device's local wall clock.
  final DateTime Function() now;
  final Duration Function(DateTime local)? _offsetAt;

  /// A document nobody has revalidated for this long is dropped on start, so match-detail
  /// copies of long-gone matches do not pile up.
  static const Duration documentRetention = Retention.documents;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(matchWindows);
            await migrator.createTable(cachedDocuments);
          }
        },
        beforeOpen: (details) => pruneOutsideWindow(),
      );

  /// The UTC bounds of the local [day].
  DayWindow dayWindow(DateTime day) => MadarTime.dayWindow(day, offsetAt: _offsetAt);

  DateTime get today {
    final wall = now();
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
  }) {
    final window = dayWindow(day);
    final key = LocalDays.key(day);
    return transaction(() async {
      await (delete(matches)..where((t) => _inDay(t, window, key))).go();
      await batch((batch) {
        batch.insertAllOnConflictUpdate(matches, rows.map(_toRow).toList());
      });
      await _writeWindow(key, etag, fetchedAt);
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
      await (delete(matchWindows)
            ..where((t) => t.day.isSmallerThanValue(firstKey) | t.day.isBiggerThanValue(lastKey)))
          .go();

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

  Future<void> _writeWindow(String day, String? etag, DateTime fetchedAt) =>
      into(matchWindows).insertOnConflictUpdate(
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
