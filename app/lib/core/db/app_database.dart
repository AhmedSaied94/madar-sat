import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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
  DateTimeColumn get matchDate => dateTime()();
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

/// The app's drift database (P6). Native and web both go through `drift_flutter`.
@DriftDatabase(tables: [Matches])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.open() : super(driftDatabase(name: 'madar'));

  @override
  int get schemaVersion => 1;

  /// Replaces the cached day in one transaction.
  Future<void> replaceDay(List<MatchSummary> rows) {
    return transaction(() async {
      await delete(matches).go();
      await batch((batch) {
        batch.insertAll(matches, rows.map(_toRow).toList());
      });
    });
  }

  Future<List<MatchSummary>> readAll() async {
    final rows = await select(matches).get();
    return rows.map(_fromRow).toList(growable: false);
  }

  MatchesCompanion _toRow(MatchSummary match) => MatchesCompanion.insert(
        id: Value(match.id),
        sport: _enumText(match.sport),
        kickoffAt: Value(match.kickoffAt?.toUtc()),
        timeTbd: match.timeTbd,
        matchDate: match.matchDate.toUtc(),
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
        matchDate: row.matchDate.toUtc(),
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
