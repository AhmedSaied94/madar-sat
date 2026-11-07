// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveState _$LiveStateFromJson(Map<String, dynamic> json) => _LiveState(
  estimated: json['estimated'] as bool,
  matchId: (json['match_id'] as num).toInt(),
  minute: json['minute'] as String?,
  period: json['period'] == null
      ? null
      : Period.fromJson(json['period'] as String),
  score: json['score'] == null
      ? null
      : Score.fromJson(json['score'] as Map<String, dynamic>),
  status: Status.fromJson(json['status'] as String),
  statusLabel: json['status_label'] as String?,
  statusUpdatedAt: json['status_updated_at'] == null
      ? null
      : DateTime.parse(json['status_updated_at'] as String),
  eventCount: (json['event_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$LiveStateToJson(_LiveState instance) =>
    <String, dynamic>{
      'estimated': instance.estimated,
      'match_id': instance.matchId,
      'minute': ?instance.minute,
      'period': ?_$PeriodEnumMap[instance.period],
      'score': ?instance.score,
      'status': _$StatusEnumMap[instance.status]!,
      'status_label': ?instance.statusLabel,
      'status_updated_at': ?instance.statusUpdatedAt?.toIso8601String(),
      'event_count': instance.eventCount,
    };

const _$PeriodEnumMap = {
  Period.value1h: '1H',
  Period.value2h: '2H',
  Period.et1: 'ET1',
  Period.et2: 'ET2',
  Period.$unknown: r'$unknown',
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
