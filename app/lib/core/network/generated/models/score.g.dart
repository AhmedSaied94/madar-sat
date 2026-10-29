// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'score.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Score _$ScoreFromJson(Map<String, dynamic> json) => _Score(
  away: (json['away'] as num).toInt(),
  awayPen: (json['away_pen'] as num?)?.toInt(),
  home: (json['home'] as num).toInt(),
  homePen: (json['home_pen'] as num?)?.toInt(),
);

Map<String, dynamic> _$ScoreToJson(_Score instance) => <String, dynamic>{
  'away': instance.away,
  'away_pen': instance.awayPen,
  'home': instance.home,
  'home_pen': instance.homePen,
};
