// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MatchEvent _$MatchEventFromJson(Map<String, dynamic> json) => _MatchEvent(
  minute: json['minute'] as String,
  player: json['player'] as String?,
  side: MatchEventSide.fromJson(json['side'] as String),
  type: MatchEventType.fromJson(json['type'] as String),
);

Map<String, dynamic> _$MatchEventToJson(_MatchEvent instance) =>
    <String, dynamic>{
      'minute': instance.minute,
      'player': ?instance.player,
      'side': _$MatchEventSideEnumMap[instance.side]!,
      'type': _$MatchEventTypeEnumMap[instance.type]!,
    };

const _$MatchEventSideEnumMap = {
  MatchEventSide.home: 'home',
  MatchEventSide.away: 'away',
  MatchEventSide.$unknown: r'$unknown',
};

const _$MatchEventTypeEnumMap = {
  MatchEventType.goal: 'goal',
  MatchEventType.ownGoal: 'own_goal',
  MatchEventType.penalty: 'penalty',
  MatchEventType.missedPenalty: 'missed_penalty',
  MatchEventType.redCard: 'red_card',
  MatchEventType.$unknown: r'$unknown',
};
