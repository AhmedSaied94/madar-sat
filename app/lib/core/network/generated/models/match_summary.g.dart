// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MatchSummary _$MatchSummaryFromJson(Map<String, dynamic> json) =>
    _MatchSummary(
      away: TeamRef.fromJson(json['away'] as Map<String, dynamic>),
      broadcast: Broadcast.fromJson(json['broadcast'] as Map<String, dynamic>),
      commentator: json['commentator'] == null
          ? null
          : CommentatorRef.fromJson(
              json['commentator'] as Map<String, dynamic>,
            ),
      competition: CompetitionRef.fromJson(
        json['competition'] as Map<String, dynamic>,
      ),
      estimated: json['estimated'] as bool,
      home: TeamRef.fromJson(json['home'] as Map<String, dynamic>),
      id: (json['id'] as num).toInt(),
      kickoffAt: json['kickoff_at'] == null
          ? null
          : DateTime.parse(json['kickoff_at'] as String),
      matchDate: DateTime.parse(json['match_date'] as String),
      minute: json['minute'] as String?,
      period: json['period'] == null
          ? null
          : Period.fromJson(json['period'] as String),
      score: json['score'] == null
          ? null
          : Score.fromJson(json['score'] as Map<String, dynamic>),
      sport: Sport.fromJson(json['sport'] as String),
      status: Status.fromJson(json['status'] as String),
      statusLabel: json['status_label'] as String?,
      timeTbd: json['time_tbd'] as bool,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$MatchSummaryToJson(_MatchSummary instance) =>
    <String, dynamic>{
      'away': instance.away,
      'broadcast': instance.broadcast,
      'commentator': instance.commentator,
      'competition': instance.competition,
      'estimated': instance.estimated,
      'home': instance.home,
      'id': instance.id,
      'kickoff_at': instance.kickoffAt?.toIso8601String(),
      'match_date': instance.matchDate.toIso8601String(),
      'minute': instance.minute,
      'period': _$PeriodEnumMap[instance.period],
      'score': instance.score,
      'sport': _$SportEnumMap[instance.sport]!,
      'status': _$StatusEnumMap[instance.status]!,
      'status_label': instance.statusLabel,
      'time_tbd': instance.timeTbd,
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$PeriodEnumMap = {
  Period.value1h: '1H',
  Period.value2h: '2H',
  Period.et1: 'ET1',
  Period.et2: 'ET2',
  Period.$unknown: r'$unknown',
};

const _$SportEnumMap = {
  Sport.football: 'football',
  Sport.basketball: 'basketball',
  Sport.handball: 'handball',
  Sport.volleyball: 'volleyball',
  Sport.tennis: 'tennis',
  Sport.$unknown: r'$unknown',
};

const _$StatusEnumMap = {
  Status.scheduled: 'scheduled',
  Status.live: 'live',
  Status.halftime: 'halftime',
  Status.extraTime: 'extra_time',
  Status.penalties: 'penalties',
  Status.finished: 'finished',
  Status.postponed: 'postponed',
  Status.cancelled: 'cancelled',
  Status.abandoned: 'abandoned',
  Status.$unknown: r'$unknown',
};
