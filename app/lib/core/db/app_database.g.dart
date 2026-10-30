// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MatchesTable extends Matches with TableInfo<$MatchesTable, StoredMatch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sportMeta = const VerificationMeta('sport');
  @override
  late final GeneratedColumn<String> sport = GeneratedColumn<String>(
    'sport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kickoffAtMeta = const VerificationMeta(
    'kickoffAt',
  );
  @override
  late final GeneratedColumn<DateTime> kickoffAt = GeneratedColumn<DateTime>(
    'kickoff_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeTbdMeta = const VerificationMeta(
    'timeTbd',
  );
  @override
  late final GeneratedColumn<bool> timeTbd = GeneratedColumn<bool>(
    'time_tbd',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("time_tbd" IN (0, 1))',
    ),
  );
  static const VerificationMeta _matchDateMeta = const VerificationMeta(
    'matchDate',
  );
  @override
  late final GeneratedColumn<String> matchDate = GeneratedColumn<String>(
    'match_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estimatedMeta = const VerificationMeta(
    'estimated',
  );
  @override
  late final GeneratedColumn<bool> estimated = GeneratedColumn<bool>(
    'estimated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("estimated" IN (0, 1))',
    ),
  );
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
    'period',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<String> minute = GeneratedColumn<String>(
    'minute',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreJsonMeta = const VerificationMeta(
    'scoreJson',
  );
  @override
  late final GeneratedColumn<String> scoreJson = GeneratedColumn<String>(
    'score_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusLabelMeta = const VerificationMeta(
    'statusLabel',
  );
  @override
  late final GeneratedColumn<String> statusLabel = GeneratedColumn<String>(
    'status_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _competitionJsonMeta = const VerificationMeta(
    'competitionJson',
  );
  @override
  late final GeneratedColumn<String> competitionJson = GeneratedColumn<String>(
    'competition_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homeJsonMeta = const VerificationMeta(
    'homeJson',
  );
  @override
  late final GeneratedColumn<String> homeJson = GeneratedColumn<String>(
    'home_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _awayJsonMeta = const VerificationMeta(
    'awayJson',
  );
  @override
  late final GeneratedColumn<String> awayJson = GeneratedColumn<String>(
    'away_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _broadcastJsonMeta = const VerificationMeta(
    'broadcastJson',
  );
  @override
  late final GeneratedColumn<String> broadcastJson = GeneratedColumn<String>(
    'broadcast_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commentatorJsonMeta = const VerificationMeta(
    'commentatorJson',
  );
  @override
  late final GeneratedColumn<String> commentatorJson = GeneratedColumn<String>(
    'commentator_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sport,
    kickoffAt,
    timeTbd,
    matchDate,
    status,
    estimated,
    period,
    minute,
    scoreJson,
    statusLabel,
    competitionJson,
    homeJson,
    awayJson,
    broadcastJson,
    commentatorJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredMatch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sport')) {
      context.handle(
        _sportMeta,
        sport.isAcceptableOrUnknown(data['sport']!, _sportMeta),
      );
    } else if (isInserting) {
      context.missing(_sportMeta);
    }
    if (data.containsKey('kickoff_at')) {
      context.handle(
        _kickoffAtMeta,
        kickoffAt.isAcceptableOrUnknown(data['kickoff_at']!, _kickoffAtMeta),
      );
    }
    if (data.containsKey('time_tbd')) {
      context.handle(
        _timeTbdMeta,
        timeTbd.isAcceptableOrUnknown(data['time_tbd']!, _timeTbdMeta),
      );
    } else if (isInserting) {
      context.missing(_timeTbdMeta);
    }
    if (data.containsKey('match_date')) {
      context.handle(
        _matchDateMeta,
        matchDate.isAcceptableOrUnknown(data['match_date']!, _matchDateMeta),
      );
    } else if (isInserting) {
      context.missing(_matchDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('estimated')) {
      context.handle(
        _estimatedMeta,
        estimated.isAcceptableOrUnknown(data['estimated']!, _estimatedMeta),
      );
    } else if (isInserting) {
      context.missing(_estimatedMeta);
    }
    if (data.containsKey('period')) {
      context.handle(
        _periodMeta,
        period.isAcceptableOrUnknown(data['period']!, _periodMeta),
      );
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    }
    if (data.containsKey('score_json')) {
      context.handle(
        _scoreJsonMeta,
        scoreJson.isAcceptableOrUnknown(data['score_json']!, _scoreJsonMeta),
      );
    }
    if (data.containsKey('status_label')) {
      context.handle(
        _statusLabelMeta,
        statusLabel.isAcceptableOrUnknown(
          data['status_label']!,
          _statusLabelMeta,
        ),
      );
    }
    if (data.containsKey('competition_json')) {
      context.handle(
        _competitionJsonMeta,
        competitionJson.isAcceptableOrUnknown(
          data['competition_json']!,
          _competitionJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_competitionJsonMeta);
    }
    if (data.containsKey('home_json')) {
      context.handle(
        _homeJsonMeta,
        homeJson.isAcceptableOrUnknown(data['home_json']!, _homeJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_homeJsonMeta);
    }
    if (data.containsKey('away_json')) {
      context.handle(
        _awayJsonMeta,
        awayJson.isAcceptableOrUnknown(data['away_json']!, _awayJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_awayJsonMeta);
    }
    if (data.containsKey('broadcast_json')) {
      context.handle(
        _broadcastJsonMeta,
        broadcastJson.isAcceptableOrUnknown(
          data['broadcast_json']!,
          _broadcastJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_broadcastJsonMeta);
    }
    if (data.containsKey('commentator_json')) {
      context.handle(
        _commentatorJsonMeta,
        commentatorJson.isAcceptableOrUnknown(
          data['commentator_json']!,
          _commentatorJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredMatch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredMatch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sport'],
      )!,
      kickoffAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}kickoff_at'],
      ),
      timeTbd: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}time_tbd'],
      )!,
      matchDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      estimated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}estimated'],
      )!,
      period: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period'],
      ),
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}minute'],
      ),
      scoreJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}score_json'],
      ),
      statusLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_label'],
      ),
      competitionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}competition_json'],
      )!,
      homeJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_json'],
      )!,
      awayJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}away_json'],
      )!,
      broadcastJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}broadcast_json'],
      )!,
      commentatorJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commentator_json'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MatchesTable createAlias(String alias) {
    return $MatchesTable(attachedDatabase, alias);
  }
}

class StoredMatch extends DataClass implements Insertable<StoredMatch> {
  final int id;
  final String sport;
  final DateTime? kickoffAt;
  final bool timeTbd;

  /// A calendar date, not an instant: `format: date` in the contract, so it is stored as
  /// `yyyy-MM-dd` text and read back as the same local `DateTime` the generated
  /// `fromJson` builds (FR-047).
  final String matchDate;
  final String status;
  final bool estimated;
  final String? period;
  final String? minute;
  final String? scoreJson;
  final String? statusLabel;
  final String competitionJson;
  final String homeJson;
  final String awayJson;
  final String broadcastJson;
  final String? commentatorJson;
  final DateTime updatedAt;
  const StoredMatch({
    required this.id,
    required this.sport,
    this.kickoffAt,
    required this.timeTbd,
    required this.matchDate,
    required this.status,
    required this.estimated,
    this.period,
    this.minute,
    this.scoreJson,
    this.statusLabel,
    required this.competitionJson,
    required this.homeJson,
    required this.awayJson,
    required this.broadcastJson,
    this.commentatorJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sport'] = Variable<String>(sport);
    if (!nullToAbsent || kickoffAt != null) {
      map['kickoff_at'] = Variable<DateTime>(kickoffAt);
    }
    map['time_tbd'] = Variable<bool>(timeTbd);
    map['match_date'] = Variable<String>(matchDate);
    map['status'] = Variable<String>(status);
    map['estimated'] = Variable<bool>(estimated);
    if (!nullToAbsent || period != null) {
      map['period'] = Variable<String>(period);
    }
    if (!nullToAbsent || minute != null) {
      map['minute'] = Variable<String>(minute);
    }
    if (!nullToAbsent || scoreJson != null) {
      map['score_json'] = Variable<String>(scoreJson);
    }
    if (!nullToAbsent || statusLabel != null) {
      map['status_label'] = Variable<String>(statusLabel);
    }
    map['competition_json'] = Variable<String>(competitionJson);
    map['home_json'] = Variable<String>(homeJson);
    map['away_json'] = Variable<String>(awayJson);
    map['broadcast_json'] = Variable<String>(broadcastJson);
    if (!nullToAbsent || commentatorJson != null) {
      map['commentator_json'] = Variable<String>(commentatorJson);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MatchesCompanion toCompanion(bool nullToAbsent) {
    return MatchesCompanion(
      id: Value(id),
      sport: Value(sport),
      kickoffAt: kickoffAt == null && nullToAbsent
          ? const Value.absent()
          : Value(kickoffAt),
      timeTbd: Value(timeTbd),
      matchDate: Value(matchDate),
      status: Value(status),
      estimated: Value(estimated),
      period: period == null && nullToAbsent
          ? const Value.absent()
          : Value(period),
      minute: minute == null && nullToAbsent
          ? const Value.absent()
          : Value(minute),
      scoreJson: scoreJson == null && nullToAbsent
          ? const Value.absent()
          : Value(scoreJson),
      statusLabel: statusLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(statusLabel),
      competitionJson: Value(competitionJson),
      homeJson: Value(homeJson),
      awayJson: Value(awayJson),
      broadcastJson: Value(broadcastJson),
      commentatorJson: commentatorJson == null && nullToAbsent
          ? const Value.absent()
          : Value(commentatorJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredMatch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredMatch(
      id: serializer.fromJson<int>(json['id']),
      sport: serializer.fromJson<String>(json['sport']),
      kickoffAt: serializer.fromJson<DateTime?>(json['kickoffAt']),
      timeTbd: serializer.fromJson<bool>(json['timeTbd']),
      matchDate: serializer.fromJson<String>(json['matchDate']),
      status: serializer.fromJson<String>(json['status']),
      estimated: serializer.fromJson<bool>(json['estimated']),
      period: serializer.fromJson<String?>(json['period']),
      minute: serializer.fromJson<String?>(json['minute']),
      scoreJson: serializer.fromJson<String?>(json['scoreJson']),
      statusLabel: serializer.fromJson<String?>(json['statusLabel']),
      competitionJson: serializer.fromJson<String>(json['competitionJson']),
      homeJson: serializer.fromJson<String>(json['homeJson']),
      awayJson: serializer.fromJson<String>(json['awayJson']),
      broadcastJson: serializer.fromJson<String>(json['broadcastJson']),
      commentatorJson: serializer.fromJson<String?>(json['commentatorJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sport': serializer.toJson<String>(sport),
      'kickoffAt': serializer.toJson<DateTime?>(kickoffAt),
      'timeTbd': serializer.toJson<bool>(timeTbd),
      'matchDate': serializer.toJson<String>(matchDate),
      'status': serializer.toJson<String>(status),
      'estimated': serializer.toJson<bool>(estimated),
      'period': serializer.toJson<String?>(period),
      'minute': serializer.toJson<String?>(minute),
      'scoreJson': serializer.toJson<String?>(scoreJson),
      'statusLabel': serializer.toJson<String?>(statusLabel),
      'competitionJson': serializer.toJson<String>(competitionJson),
      'homeJson': serializer.toJson<String>(homeJson),
      'awayJson': serializer.toJson<String>(awayJson),
      'broadcastJson': serializer.toJson<String>(broadcastJson),
      'commentatorJson': serializer.toJson<String?>(commentatorJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredMatch copyWith({
    int? id,
    String? sport,
    Value<DateTime?> kickoffAt = const Value.absent(),
    bool? timeTbd,
    String? matchDate,
    String? status,
    bool? estimated,
    Value<String?> period = const Value.absent(),
    Value<String?> minute = const Value.absent(),
    Value<String?> scoreJson = const Value.absent(),
    Value<String?> statusLabel = const Value.absent(),
    String? competitionJson,
    String? homeJson,
    String? awayJson,
    String? broadcastJson,
    Value<String?> commentatorJson = const Value.absent(),
    DateTime? updatedAt,
  }) => StoredMatch(
    id: id ?? this.id,
    sport: sport ?? this.sport,
    kickoffAt: kickoffAt.present ? kickoffAt.value : this.kickoffAt,
    timeTbd: timeTbd ?? this.timeTbd,
    matchDate: matchDate ?? this.matchDate,
    status: status ?? this.status,
    estimated: estimated ?? this.estimated,
    period: period.present ? period.value : this.period,
    minute: minute.present ? minute.value : this.minute,
    scoreJson: scoreJson.present ? scoreJson.value : this.scoreJson,
    statusLabel: statusLabel.present ? statusLabel.value : this.statusLabel,
    competitionJson: competitionJson ?? this.competitionJson,
    homeJson: homeJson ?? this.homeJson,
    awayJson: awayJson ?? this.awayJson,
    broadcastJson: broadcastJson ?? this.broadcastJson,
    commentatorJson: commentatorJson.present
        ? commentatorJson.value
        : this.commentatorJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredMatch copyWithCompanion(MatchesCompanion data) {
    return StoredMatch(
      id: data.id.present ? data.id.value : this.id,
      sport: data.sport.present ? data.sport.value : this.sport,
      kickoffAt: data.kickoffAt.present ? data.kickoffAt.value : this.kickoffAt,
      timeTbd: data.timeTbd.present ? data.timeTbd.value : this.timeTbd,
      matchDate: data.matchDate.present ? data.matchDate.value : this.matchDate,
      status: data.status.present ? data.status.value : this.status,
      estimated: data.estimated.present ? data.estimated.value : this.estimated,
      period: data.period.present ? data.period.value : this.period,
      minute: data.minute.present ? data.minute.value : this.minute,
      scoreJson: data.scoreJson.present ? data.scoreJson.value : this.scoreJson,
      statusLabel: data.statusLabel.present
          ? data.statusLabel.value
          : this.statusLabel,
      competitionJson: data.competitionJson.present
          ? data.competitionJson.value
          : this.competitionJson,
      homeJson: data.homeJson.present ? data.homeJson.value : this.homeJson,
      awayJson: data.awayJson.present ? data.awayJson.value : this.awayJson,
      broadcastJson: data.broadcastJson.present
          ? data.broadcastJson.value
          : this.broadcastJson,
      commentatorJson: data.commentatorJson.present
          ? data.commentatorJson.value
          : this.commentatorJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredMatch(')
          ..write('id: $id, ')
          ..write('sport: $sport, ')
          ..write('kickoffAt: $kickoffAt, ')
          ..write('timeTbd: $timeTbd, ')
          ..write('matchDate: $matchDate, ')
          ..write('status: $status, ')
          ..write('estimated: $estimated, ')
          ..write('period: $period, ')
          ..write('minute: $minute, ')
          ..write('scoreJson: $scoreJson, ')
          ..write('statusLabel: $statusLabel, ')
          ..write('competitionJson: $competitionJson, ')
          ..write('homeJson: $homeJson, ')
          ..write('awayJson: $awayJson, ')
          ..write('broadcastJson: $broadcastJson, ')
          ..write('commentatorJson: $commentatorJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sport,
    kickoffAt,
    timeTbd,
    matchDate,
    status,
    estimated,
    period,
    minute,
    scoreJson,
    statusLabel,
    competitionJson,
    homeJson,
    awayJson,
    broadcastJson,
    commentatorJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredMatch &&
          other.id == this.id &&
          other.sport == this.sport &&
          other.kickoffAt == this.kickoffAt &&
          other.timeTbd == this.timeTbd &&
          other.matchDate == this.matchDate &&
          other.status == this.status &&
          other.estimated == this.estimated &&
          other.period == this.period &&
          other.minute == this.minute &&
          other.scoreJson == this.scoreJson &&
          other.statusLabel == this.statusLabel &&
          other.competitionJson == this.competitionJson &&
          other.homeJson == this.homeJson &&
          other.awayJson == this.awayJson &&
          other.broadcastJson == this.broadcastJson &&
          other.commentatorJson == this.commentatorJson &&
          other.updatedAt == this.updatedAt);
}

class MatchesCompanion extends UpdateCompanion<StoredMatch> {
  final Value<int> id;
  final Value<String> sport;
  final Value<DateTime?> kickoffAt;
  final Value<bool> timeTbd;
  final Value<String> matchDate;
  final Value<String> status;
  final Value<bool> estimated;
  final Value<String?> period;
  final Value<String?> minute;
  final Value<String?> scoreJson;
  final Value<String?> statusLabel;
  final Value<String> competitionJson;
  final Value<String> homeJson;
  final Value<String> awayJson;
  final Value<String> broadcastJson;
  final Value<String?> commentatorJson;
  final Value<DateTime> updatedAt;
  const MatchesCompanion({
    this.id = const Value.absent(),
    this.sport = const Value.absent(),
    this.kickoffAt = const Value.absent(),
    this.timeTbd = const Value.absent(),
    this.matchDate = const Value.absent(),
    this.status = const Value.absent(),
    this.estimated = const Value.absent(),
    this.period = const Value.absent(),
    this.minute = const Value.absent(),
    this.scoreJson = const Value.absent(),
    this.statusLabel = const Value.absent(),
    this.competitionJson = const Value.absent(),
    this.homeJson = const Value.absent(),
    this.awayJson = const Value.absent(),
    this.broadcastJson = const Value.absent(),
    this.commentatorJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MatchesCompanion.insert({
    this.id = const Value.absent(),
    required String sport,
    this.kickoffAt = const Value.absent(),
    required bool timeTbd,
    required String matchDate,
    required String status,
    required bool estimated,
    this.period = const Value.absent(),
    this.minute = const Value.absent(),
    this.scoreJson = const Value.absent(),
    this.statusLabel = const Value.absent(),
    required String competitionJson,
    required String homeJson,
    required String awayJson,
    required String broadcastJson,
    this.commentatorJson = const Value.absent(),
    required DateTime updatedAt,
  }) : sport = Value(sport),
       timeTbd = Value(timeTbd),
       matchDate = Value(matchDate),
       status = Value(status),
       estimated = Value(estimated),
       competitionJson = Value(competitionJson),
       homeJson = Value(homeJson),
       awayJson = Value(awayJson),
       broadcastJson = Value(broadcastJson),
       updatedAt = Value(updatedAt);
  static Insertable<StoredMatch> custom({
    Expression<int>? id,
    Expression<String>? sport,
    Expression<DateTime>? kickoffAt,
    Expression<bool>? timeTbd,
    Expression<String>? matchDate,
    Expression<String>? status,
    Expression<bool>? estimated,
    Expression<String>? period,
    Expression<String>? minute,
    Expression<String>? scoreJson,
    Expression<String>? statusLabel,
    Expression<String>? competitionJson,
    Expression<String>? homeJson,
    Expression<String>? awayJson,
    Expression<String>? broadcastJson,
    Expression<String>? commentatorJson,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sport != null) 'sport': sport,
      if (kickoffAt != null) 'kickoff_at': kickoffAt,
      if (timeTbd != null) 'time_tbd': timeTbd,
      if (matchDate != null) 'match_date': matchDate,
      if (status != null) 'status': status,
      if (estimated != null) 'estimated': estimated,
      if (period != null) 'period': period,
      if (minute != null) 'minute': minute,
      if (scoreJson != null) 'score_json': scoreJson,
      if (statusLabel != null) 'status_label': statusLabel,
      if (competitionJson != null) 'competition_json': competitionJson,
      if (homeJson != null) 'home_json': homeJson,
      if (awayJson != null) 'away_json': awayJson,
      if (broadcastJson != null) 'broadcast_json': broadcastJson,
      if (commentatorJson != null) 'commentator_json': commentatorJson,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MatchesCompanion copyWith({
    Value<int>? id,
    Value<String>? sport,
    Value<DateTime?>? kickoffAt,
    Value<bool>? timeTbd,
    Value<String>? matchDate,
    Value<String>? status,
    Value<bool>? estimated,
    Value<String?>? period,
    Value<String?>? minute,
    Value<String?>? scoreJson,
    Value<String?>? statusLabel,
    Value<String>? competitionJson,
    Value<String>? homeJson,
    Value<String>? awayJson,
    Value<String>? broadcastJson,
    Value<String?>? commentatorJson,
    Value<DateTime>? updatedAt,
  }) {
    return MatchesCompanion(
      id: id ?? this.id,
      sport: sport ?? this.sport,
      kickoffAt: kickoffAt ?? this.kickoffAt,
      timeTbd: timeTbd ?? this.timeTbd,
      matchDate: matchDate ?? this.matchDate,
      status: status ?? this.status,
      estimated: estimated ?? this.estimated,
      period: period ?? this.period,
      minute: minute ?? this.minute,
      scoreJson: scoreJson ?? this.scoreJson,
      statusLabel: statusLabel ?? this.statusLabel,
      competitionJson: competitionJson ?? this.competitionJson,
      homeJson: homeJson ?? this.homeJson,
      awayJson: awayJson ?? this.awayJson,
      broadcastJson: broadcastJson ?? this.broadcastJson,
      commentatorJson: commentatorJson ?? this.commentatorJson,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sport.present) {
      map['sport'] = Variable<String>(sport.value);
    }
    if (kickoffAt.present) {
      map['kickoff_at'] = Variable<DateTime>(kickoffAt.value);
    }
    if (timeTbd.present) {
      map['time_tbd'] = Variable<bool>(timeTbd.value);
    }
    if (matchDate.present) {
      map['match_date'] = Variable<String>(matchDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (estimated.present) {
      map['estimated'] = Variable<bool>(estimated.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (minute.present) {
      map['minute'] = Variable<String>(minute.value);
    }
    if (scoreJson.present) {
      map['score_json'] = Variable<String>(scoreJson.value);
    }
    if (statusLabel.present) {
      map['status_label'] = Variable<String>(statusLabel.value);
    }
    if (competitionJson.present) {
      map['competition_json'] = Variable<String>(competitionJson.value);
    }
    if (homeJson.present) {
      map['home_json'] = Variable<String>(homeJson.value);
    }
    if (awayJson.present) {
      map['away_json'] = Variable<String>(awayJson.value);
    }
    if (broadcastJson.present) {
      map['broadcast_json'] = Variable<String>(broadcastJson.value);
    }
    if (commentatorJson.present) {
      map['commentator_json'] = Variable<String>(commentatorJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchesCompanion(')
          ..write('id: $id, ')
          ..write('sport: $sport, ')
          ..write('kickoffAt: $kickoffAt, ')
          ..write('timeTbd: $timeTbd, ')
          ..write('matchDate: $matchDate, ')
          ..write('status: $status, ')
          ..write('estimated: $estimated, ')
          ..write('period: $period, ')
          ..write('minute: $minute, ')
          ..write('scoreJson: $scoreJson, ')
          ..write('statusLabel: $statusLabel, ')
          ..write('competitionJson: $competitionJson, ')
          ..write('homeJson: $homeJson, ')
          ..write('awayJson: $awayJson, ')
          ..write('broadcastJson: $broadcastJson, ')
          ..write('commentatorJson: $commentatorJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MatchesTable matches = $MatchesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [matches];
}

typedef $$MatchesTableCreateCompanionBuilder = MatchesCompanion Function({
  Value<int> id,
  required String sport,
  Value<DateTime?> kickoffAt,
  required bool timeTbd,
  required String matchDate,
  required String status,
  required bool estimated,
  Value<String?> period,
  Value<String?> minute,
  Value<String?> scoreJson,
  Value<String?> statusLabel,
  required String competitionJson,
  required String homeJson,
  required String awayJson,
  required String broadcastJson,
  Value<String?> commentatorJson,
  required DateTime updatedAt,
});
typedef $$MatchesTableUpdateCompanionBuilder = MatchesCompanion Function({
  Value<int> id,
  Value<String> sport,
  Value<DateTime?> kickoffAt,
  Value<bool> timeTbd,
  Value<String> matchDate,
  Value<String> status,
  Value<bool> estimated,
  Value<String?> period,
  Value<String?> minute,
  Value<String?> scoreJson,
  Value<String?> statusLabel,
  Value<String> competitionJson,
  Value<String> homeJson,
  Value<String> awayJson,
  Value<String> broadcastJson,
  Value<String?> commentatorJson,
  Value<DateTime> updatedAt,
});

class $$MatchesTableFilterComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sport => $composableBuilder(
    column: $table.sport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get kickoffAt => $composableBuilder(
    column: $table.kickoffAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get timeTbd => $composableBuilder(
    column: $table.timeTbd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchDate => $composableBuilder(
    column: $table.matchDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get estimated => $composableBuilder(
    column: $table.estimated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoreJson => $composableBuilder(
    column: $table.scoreJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusLabel => $composableBuilder(
    column: $table.statusLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get competitionJson => $composableBuilder(
    column: $table.competitionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeJson => $composableBuilder(
    column: $table.homeJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get awayJson => $composableBuilder(
    column: $table.awayJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get broadcastJson => $composableBuilder(
    column: $table.broadcastJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commentatorJson => $composableBuilder(
    column: $table.commentatorJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sport => $composableBuilder(
    column: $table.sport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get kickoffAt => $composableBuilder(
    column: $table.kickoffAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get timeTbd => $composableBuilder(
    column: $table.timeTbd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchDate => $composableBuilder(
    column: $table.matchDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get estimated => $composableBuilder(
    column: $table.estimated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoreJson => $composableBuilder(
    column: $table.scoreJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusLabel => $composableBuilder(
    column: $table.statusLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get competitionJson => $composableBuilder(
    column: $table.competitionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeJson => $composableBuilder(
    column: $table.homeJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get awayJson => $composableBuilder(
    column: $table.awayJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get broadcastJson => $composableBuilder(
    column: $table.broadcastJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commentatorJson => $composableBuilder(
    column: $table.commentatorJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sport =>
      $composableBuilder(column: $table.sport, builder: (column) => column);

  GeneratedColumn<DateTime> get kickoffAt =>
      $composableBuilder(column: $table.kickoffAt, builder: (column) => column);

  GeneratedColumn<bool> get timeTbd =>
      $composableBuilder(column: $table.timeTbd, builder: (column) => column);

  GeneratedColumn<String> get matchDate =>
      $composableBuilder(column: $table.matchDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get estimated =>
      $composableBuilder(column: $table.estimated, builder: (column) => column);

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<String> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get scoreJson =>
      $composableBuilder(column: $table.scoreJson, builder: (column) => column);

  GeneratedColumn<String> get statusLabel => $composableBuilder(
    column: $table.statusLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get competitionJson => $composableBuilder(
    column: $table.competitionJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get homeJson =>
      $composableBuilder(column: $table.homeJson, builder: (column) => column);

  GeneratedColumn<String> get awayJson =>
      $composableBuilder(column: $table.awayJson, builder: (column) => column);

  GeneratedColumn<String> get broadcastJson => $composableBuilder(
    column: $table.broadcastJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commentatorJson => $composableBuilder(
    column: $table.commentatorJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchesTable,
          StoredMatch,
          $$MatchesTableFilterComposer,
          $$MatchesTableOrderingComposer,
          $$MatchesTableAnnotationComposer,
          $$MatchesTableCreateCompanionBuilder,
          $$MatchesTableUpdateCompanionBuilder,
          (
            StoredMatch,
            BaseReferences<_$AppDatabase, $MatchesTable, StoredMatch>,
          ),
          StoredMatch,
          PrefetchHooks Function()
        > {
  $$MatchesTableTableManager(_$AppDatabase db, $MatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sport = const Value.absent(),
                Value<DateTime?> kickoffAt = const Value.absent(),
                Value<bool> timeTbd = const Value.absent(),
                Value<String> matchDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> estimated = const Value.absent(),
                Value<String?> period = const Value.absent(),
                Value<String?> minute = const Value.absent(),
                Value<String?> scoreJson = const Value.absent(),
                Value<String?> statusLabel = const Value.absent(),
                Value<String> competitionJson = const Value.absent(),
                Value<String> homeJson = const Value.absent(),
                Value<String> awayJson = const Value.absent(),
                Value<String> broadcastJson = const Value.absent(),
                Value<String?> commentatorJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => MatchesCompanion(
                id: id,
                sport: sport,
                kickoffAt: kickoffAt,
                timeTbd: timeTbd,
                matchDate: matchDate,
                status: status,
                estimated: estimated,
                period: period,
                minute: minute,
                scoreJson: scoreJson,
                statusLabel: statusLabel,
                competitionJson: competitionJson,
                homeJson: homeJson,
                awayJson: awayJson,
                broadcastJson: broadcastJson,
                commentatorJson: commentatorJson,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sport,
                Value<DateTime?> kickoffAt = const Value.absent(),
                required bool timeTbd,
                required String matchDate,
                required String status,
                required bool estimated,
                Value<String?> period = const Value.absent(),
                Value<String?> minute = const Value.absent(),
                Value<String?> scoreJson = const Value.absent(),
                Value<String?> statusLabel = const Value.absent(),
                required String competitionJson,
                required String homeJson,
                required String awayJson,
                required String broadcastJson,
                Value<String?> commentatorJson = const Value.absent(),
                required DateTime updatedAt,
              }) => MatchesCompanion.insert(
                id: id,
                sport: sport,
                kickoffAt: kickoffAt,
                timeTbd: timeTbd,
                matchDate: matchDate,
                status: status,
                estimated: estimated,
                period: period,
                minute: minute,
                scoreJson: scoreJson,
                statusLabel: statusLabel,
                competitionJson: competitionJson,
                homeJson: homeJson,
                awayJson: awayJson,
                broadcastJson: broadcastJson,
                commentatorJson: commentatorJson,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MatchesTable, StoredMatch>(table),
                  BaseReferences<_$AppDatabase, $MatchesTable, StoredMatch>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchesTable,
      StoredMatch,
      $$MatchesTableFilterComposer,
      $$MatchesTableOrderingComposer,
      $$MatchesTableAnnotationComposer,
      $$MatchesTableCreateCompanionBuilder,
      $$MatchesTableUpdateCompanionBuilder,
      (StoredMatch, BaseReferences<_$AppDatabase, $MatchesTable, StoredMatch>),
      StoredMatch,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MatchesTableTableManager get matches =>
      $$MatchesTableTableManager(_db, _db.matches);
}
